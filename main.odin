package main

import      "core:fmt"
import      "base:runtime"
import      "core:mem"
import gl   "vendor:OpenGl"
import "core:time"
import      "core:os"
import      "core:math"
import glfw "vendor:glfw"
import stbtt "vendor:stb/truetype"
import im "./odin-imgui"
import "./odin-imgui/imgui_impl_glfw"
import "./odin-imgui/imgui_impl_opengl3"

/*
	How do we find the cursor position

	if front == 0 just rendr on top left

	instead of looking at the font at the location of the gap front
	calculate the width of the character (same for everyone) and multiply by it
*/

window : glfw.WindowHandle

rect4i16 :: struct {
	l, t, r, b: f32
}
color_t :: [4]f32

vec3 :: [3]f32


window_height :i32= 800
window_width  :i32= 1000


rect_instance :: struct  #packed {
    pos        : rect4i16,
    tex_coords : rect4i16,
    color      : color_t,
    index      : u32,
    subpixel_shift  : f32,
}

CursorGl :: struct {
	cursor_buf, vao : u32,
	cursor          : Cursor,
}

Cursor :: struct {
	x, y : f32,
	color: color_t,
}

app : app_state

app_state :: struct{
    font_info : stbtt.fontinfo,

    glyph_atlas_items : [127]glyph_atlas_item,
    glyph_atlas_width  : i32 ,
    glyph_atlas_height : i32 ,
    glyph_atlas_texture : u32,

    rect_buffer : [dynamic]rect_instance,
    rect_instances_vbo : u32,

    vao : u32,
    program_id: u32,
    pos_x  :f32,
    pos_y  :f32,
    font_size_pt : f32,
    gap_buf      : GapBuf,

    cursor_program_id : u32,

    cursor : CursorGl,
	index_rect : rect_instance,

	current_x, current_y : f32,

	input : Input,
}



glyph_atlas_item :: struct {
    filled: bool ,
    tex_coords: rect4i16,
    glyph_index: i32, 
    distance_from_baseline_to_top_px: i32,
}

recalc := false
scroll_callback :: proc "c" (window: glfw.WindowHandle, x, y: f64){
    //state.pos = {x, y}
    //gl.Viewport(0, 0, x, y);

    //if ctrol is down
    if glfw.GetKey(window, glfw.KEY_LEFT_CONTROL) == glfw.PRESS{
	app.font_size_pt += f32(y)
	recalc = true
    }else{
	app.pos_y += f32(y * 20)
    }



    //state.world.scale.z += f32(y) * 0.05
    redraw = true
}

init_cursor :: proc(){
	using app.cursor

	gl.CreateBuffers(1, &cursor_buf)
    gl.CreateVertexArrays(1, &vao)
    gl.VertexArrayVertexBuffer(vao, 0, cursor_buf, 0, size_of(f32) * 7 ); 
    //gl.VertexArrayBindingDivisor(vao, 0, 1);

    //POS
    gl.EnableVertexArrayAttrib( vao, 0);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 0, 0);  // read from data source 0
    gl.VertexArrayAttribFormat( vao, 0, 3, gl.FLOAT, false , 0);

    gl.EnableVertexArrayAttrib( vao, 1);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 1, 0);  // read from data source 1
    gl.VertexArrayAttribFormat( vao, 1, 4, gl.FLOAT, true, size_of(f32) * 3);  

}

init_imgui :: proc (){
	im.CHECKVERSION()
	im.CreateContext()
	io := im.GetIO()
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad}

	im.StyleColorsDark()

	imgui_impl_glfw.InitForOpenGL(window, true)
	imgui_impl_opengl3.Init("#version 150")
}

//only use the x distance of the current index
render_cursor :: proc(){


	using app.cursor

	ret : rect4i16 // ret_i.pos

	ret.l = cursor.x
	ret.b = cursor.y + 3 


	if app.gap_buf.front == 0{
		ret.l =0
	}

	ret.r = ret.l + 10
	ret.t = ret.b - 15
	//ret.b = ret.t + 15


	cursor.color = {1,1,1,1}
    a :f32= 2.0 / f32(window_width)
    b :f32= 2.0 / f32(window_height)
	proj : [16]f32 = {
		a, 0, 0, 0, 0, b, 0, 0, 0, 0, 1, 0, -1, -1, 0, 1,
	};
	//put cursor_program_id inside CursorGL

	color := color_t{0, 1, 0, 1}

    gl.UseProgram(app.cursor_program_id)
	vertices := []f32 {
	    ret.l, ret.t, 0.0, color.r, color.g, color.b, color.a, // top right
	    ret.l, ret.b, 0.0, color.r, color.g, color.b, color.a, // bottom right
	    ret.r, ret.t, 0.0, color.r, color.g, color.b, color.a, // top left 

	    ret.l,  ret.b, 0.0, color.r, color.g, color.b, color.a, // bottom right
	    ret.r,  ret.b, 0.0, color.r, color.g, color.b, color.a, // bottom left
	    ret.r,  ret.t, 0.0, color.r, color.g, color.b, color.a // top left 
	};


	//gl.ProgramUniform2f(program_id, 0, f32(window_width) / 2.0, f32(window_height) / 2.0);
	gl.ProgramUniformMatrix4fv(app.cursor_program_id, 0, 1, gl.FALSE,  &proj[0]);
    gl.NamedBufferData(cursor_buf, size_of(f32) * 6 * 7, &vertices[0], gl.DYNAMIC_DRAW)
    gl.BindVertexArray(vao)
    gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, 6)
    //gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil);

    gl.UseProgram(0)
    gl.BindVertexArray(0)

}

render_font :: proc (){

    using app
    text := get_string(&gap_buf)

    coverage_adjustment  :f32 =  0.0
    text_color : color_t = {1, 1, 1, 1}
    font_data, _ := os.read_entire_file_from_filename("UbuntuMono-R.ttf")
    stbtt.InitFont(&font_info, &font_data[0], 0)


	if redraw{

    rect_buffer = make([dynamic]rect_instance, 0, 1000)
    {
	//put every glyph in text into rect_buffer

	//Get the font metrics, the stbtt_ScaleForMappingEmToPixels() and stbtt_GetFontVMetrics() documentation for details

	//From "Font size in pixels or points" in stb_truetype

	font_size_px := font_size_pt * 1.3333
	font_scale   := stbtt.ScaleForMappingEmToPixels(&font_info, font_size_px)

	font_ascent, font_descent, font_line_gap :i32= 0, 0, 0
	stbtt.GetFontVMetrics(&font_info, &font_ascent, &font_descent, &font_line_gap)
	line_height := f32(font_ascent - font_descent + font_line_gap) * font_scale
	baseline    := f32(font_ascent) * font_scale


	//Keep track of the current position while we process glyph after glyph
	current_x, current_y = pos_x, f32(pos_y) + math.round(baseline)



	//iterate over the UTF-8 text codepoint by codepoint. A codepoint is basically 32 bit ID of a character as defined by Unicode

	prev_codepoint : rune = 0

	if recalc{
	    delete(rect_buffer)
	    rect_buffer = make([dynamic]rect_instance, 0, 1000)
	}

	for c, i in text {
	    codepoint := u32(c)

	    //Apply kerning
	    if prev_codepoint != 0{
	    	current_x += f32(stbtt.GetCodepointKernAdvance(&font_info, prev_codepoint, c)) * font_scale
	    }

	    prev_codepoint = c

	    if c == '\n'{
		//Handle line breaks
		current_x = pos_x
		current_y += math.round(line_height)


	    } else if c == '\t'{
		current_x +=  4 * font_size_pt
	    }else{

		horizontal_filter_padding, subpixel_positioning_left_padding : i32 = 1 , 1

		assert(codepoint <=127)

		glyph_atlas := glyph_atlas_items[codepoint] 

		if glyph_atlas.filled && !recalc{
		    //The atlas item for this codepoint is already filled so we already rasterized the glyph, put it in the relevane data in an atlas item. Everything is already done, so just use the atlas item

		}else
		{
		    glyph_index := stbtt.FindGlyphIndex(&font_info, c)

		    x0, y0, x1, y1 :i32 = 0, 0, 0, 0

		    stbtt.GetGlyphBitmapBox(&font_info, glyph_index, font_scale, font_scale, &x0, &y0, &x1, &y1)

		    glyph_width_px  : i32 = x1 - x0
		    glyph_height_px : i32 = y1 - y0

		    distance_from_baseline_to_top_px : i32 = -y0

		    //Only render glyphs that actually have some visual representation (skip spaces, etc.)

		    
		    if glyph_width_px > 0 && glyph_height_px > 0{
			padded_glyph_width_px : i32 = subpixel_positioning_left_padding + horizontal_filter_padding + glyph_width_px + horizontal_filter_padding

			padded_glyph_height_px : i32 = glyph_height_px

			//Don't use this for anything other than demonstration purposes

			atlas_item_width, atlas_item_height : i32 = 32, 32

			atlas_item_x : i32 = i32(codepoint % u32(glyph_atlas_width / atlas_item_width)) * atlas_item_width
			atlas_item_y : i32 = i32(codepoint / u32(glyph_atlas_height / atlas_item_height)) * atlas_item_height

			assert(padded_glyph_width_px <= atlas_item_width && padded_glyph_height_px <= atlas_item_height);


			horizontal_resolution : i32 = 3

			bitmap_stride : i32 = atlas_item_width * horizontal_resolution
			bitmap_size   : uint = uint(bitmap_stride * atlas_item_height)
			glyph_bitmap, _  :=  mem.alloc_bytes(int(bitmap_size))

			glyph_offset_x := (subpixel_positioning_left_padding + horizontal_filter_padding) * horizontal_resolution

			stbtt.MakeGlyphBitmap(&font_info,
					      &glyph_bitmap[glyph_offset_x],
					      atlas_item_width * horizontal_resolution,
					      atlas_item_height,
					      bitmap_stride,
					      font_scale * f32(horizontal_resolution),
					      font_scale,
					      glyph_index
					     )

			atlas_item_bitmap, _ := mem.alloc_bytes(int(bitmap_size))


			filter_weights : [5]u8 = { 0x08, 0x4D, 0x56, 0x4D, 0x08 };



			for y in 0..<padded_glyph_height_px{

			    x_end : i32 = padded_glyph_width_px * horizontal_resolution -1

			    for x in 4..<x_end{
				filter_weight_index : i32 =  0
				sum :  i32
				kernel_x_end : i32 = (x == x_end -1)  ? x + 1 : x + 2



				for kernel_x in x-2..=kernel_x_end{

				    assert(kernel_x >= 0 && kernel_x < x_end + 1)
				    assert(y        >= 0 && y        < padded_glyph_height_px)

				    offset :i32 = kernel_x + y * bitmap_stride
				    assert(offset >= 0 && uint(offset) < bitmap_size)


				    //fmt.println(i32(glyph_bitmap[offset]) * filter_weights[filter_weight_index])

				    sum += i32(i32(glyph_bitmap[offset]) * i32(filter_weights[filter_weight_index]))
				    filter_weight_index += 1
				}
				sum = sum / 255
				atlas_item_bitmap[x + y * bitmap_stride] = ( sum> 255) ? 255: u8(sum)
			    }
			}

			mem.free_bytes(glyph_bitmap)

			gl.TextureSubImage2D(glyph_atlas_texture, 0, atlas_item_x, atlas_item_y, atlas_item_width, atlas_item_height, gl.RGB, gl.UNSIGNED_BYTE, rawptr(&atlas_item_bitmap[0]))

			mem.free_bytes(atlas_item_bitmap)
			glyph_atlas.tex_coords.l     = f32(atlas_item_x)
			glyph_atlas.tex_coords.t     = f32(atlas_item_y)
			glyph_atlas.tex_coords.r     = f32(atlas_item_x + padded_glyph_width_px)
			glyph_atlas.tex_coords.b     = f32(atlas_item_y + padded_glyph_height_px)
		    } else {
			glyph_atlas.tex_coords.l  = -1 
			glyph_atlas.tex_coords.t  = -1 
			glyph_atlas.tex_coords.r  = -1 
			glyph_atlas.tex_coords.b  = -1 
		    }

		    glyph_atlas.glyph_index = glyph_index
		    glyph_atlas.distance_from_baseline_to_top_px = distance_from_baseline_to_top_px
		    glyph_atlas.filled      = true
		    glyph_atlas_items[codepoint] = glyph_atlas
		}

		glyph_advance_width, glyph_left_side_bearing : i32 = 0, 0

		stbtt.GetGlyphHMetrics(&font_info, glyph_atlas.glyph_index, &glyph_advance_width, &glyph_left_side_bearing)

		if glyph_atlas.tex_coords.l != -1{

		    glyph_pos_x    :f32 = current_x + (f32(glyph_left_side_bearing) * font_scale) 

		    glyph_pos_x_px, glyph_pos_x_subpixel_shift :f32= math.modf_f32(glyph_pos_x)


		    glyph_pos_y_px :f32 = current_y - f32(glyph_atlas.distance_from_baseline_to_top_px)
		    glyph_width_with_horiz_filter_padding :i32 = i32(glyph_atlas.tex_coords.r - glyph_atlas.tex_coords.l)
		    glyph_height    :i32 = i32(glyph_atlas.tex_coords.b - glyph_atlas.tex_coords.t)

		    r :  rect_instance 

		    r.pos.l = f32(glyph_pos_x_px - f32(subpixel_positioning_left_padding + horizontal_filter_padding));;
		    r.pos.t = f32(glyph_pos_y_px);
		    r.pos.r = f32(glyph_pos_x_px - f32(subpixel_positioning_left_padding + horizontal_filter_padding) + f32(glyph_width_with_horiz_filter_padding))
		    r.pos.b = f32(glyph_pos_y_px + f32(glyph_height));

		    r.subpixel_shift = glyph_pos_x_subpixel_shift;
		    r.tex_coords     = glyph_atlas.tex_coords;
		    r.color          = text_color;
		    r.index          = u32(i+1)


		    append(&rect_buffer, r)
		}

		current_x += f32(glyph_advance_width) * font_scale
	    }
	    if u32(i) == gap_buf.front-1{
	    	app.cursor.cursor.x = current_x
	    	app.cursor.cursor.y = current_y
	    }
	}
    }
	}
	{
	gl.ClearColor(0.25, 0.25, 0.25, 1.0);
	gl.Clear(gl.COLOR_BUFFER_BIT);


	
	// Upload the rect buffer to the GPU.
	// Allow the GPU driver to create a new buffer storage for each draw command. That way it doesn't have to wait for
	// the previous draw command to finish to reuse the same buffer storage.

    if gap_buf.gap != gap_buf.total{
    	gl.NamedBufferData(rect_instances_vbo, int(len(rect_buffer) * size_of(rect_buffer[0])), &rect_buffer[0], gl.DYNAMIC_DRAW);
    }
	
	// Setup pre-multiplied alpha blending (that's why the source factor is GL_ONE) with dual source blending so we can blend
	// each subpixel individually for subpixel anti-aliased glyph rendering (that's what GL_ONE_MINUS_SRC1_COLOR does).
	gl.Enable(gl.BLEND);
	gl.BlendFunc(gl.ONE, gl.ONE_MINUS_SRC1_COLOR);


	
	gl.BindVertexArray(vao);
	// layout(location = 0) uniform vec2 half_viewport_size
	// Note: Do a float division on window_width and window_height to properly handle uneven window dimensions.
	// An integer division causes 1px artifacts in the middle of windows due to a wrong transform.
	// layout(location = 1) uniform float coverage_adjustment
	gl.UseProgram(program_id);
	gl.ProgramUniform2f(program_id, 0, f32(window_width) / 2.0, f32(window_height) / 2.0);
	gl.ProgramUniform1ui(program_id, 1, u32(coverage_adjustment));
	gl.ProgramUniform1ui(program_id, 2, app.gap_buf.front);
	gl.BindTextureUnit(0, glyph_atlas_texture);
	//gl.BindTexture(gl.TEXTURE_2D, glyph_atlas_texture);
	//gl.ProgramUniform1i(program_id, 3, i32(glyph_atlas_texture));
	gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, i32(len(rect_buffer)));
	gl.UseProgram(0);
	gl.BindVertexArray(0);
	
	// We don't need the contents of the CPU or GPU buffer anymore
	gl.InvalidateBufferData(rect_instances_vbo);
	render_cursor()



	//glfw.SwapBuffers(window)
    }
    redraw = false
    recalc = false
}


gl_debug_callback ::   proc "c" (src : u32, type: u32, id: u32, severity: u32, length: i32, msg: cstring, userParam: rawptr){
    src_str, type_str, severity_str  : cstring = "" , "", ""

    context = runtime.default_context()

    
    switch (src) {
    case gl.DEBUG_SOURCE_API:             src_str = "API";             
    case gl.DEBUG_SOURCE_WINDOW_SYSTEM:   src_str = "WINDOW SYSTEM";   
    case gl.DEBUG_SOURCE_SHADER_COMPILER: src_str = "SHADER COMPILER"; 
    case gl.DEBUG_SOURCE_THIRD_PARTY:     src_str = "THIRD PARTY";     
    case gl.DEBUG_SOURCE_APPLICATION:     src_str = "APPLICATION";     
    case gl.DEBUG_SOURCE_OTHER:           src_str = "OTHER";           
    }
    switch (type) {
    case gl.DEBUG_TYPE_ERROR:               type_str = "ERROR";               
    case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR: type_str = "DEPRECATED_BEHAVIOR"; 
    case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:  type_str = "UNDEFINED_BEHAVIOR";  
    case gl.DEBUG_TYPE_PORTABILITY:         type_str = "PORTABILITY";         
    case gl.DEBUG_TYPE_PERFORMANCE:         type_str = "PERFORMANCE";         
    case gl.DEBUG_TYPE_MARKER:              type_str = "MARKER";              
    case gl.DEBUG_TYPE_OTHER:               type_str = "OTHER";              
    }
    switch (severity) {
    case gl.DEBUG_SEVERITY_NOTIFICATION: severity_str = "NOTIFICATION"; 
    case gl.DEBUG_SEVERITY_LOW:          severity_str = "LOW";          
    case gl.DEBUG_SEVERITY_MEDIUM:       severity_str = "MEDIUM";       
    case gl.DEBUG_SEVERITY_HIGH:         severity_str = "HIGH";         
    }
    
    fmt.printf("[GL %s %s %s] %u: %s\n", src_str, type_str, severity_str, id, msg);
}
redraw := true

viewport_callback :: proc "c" (window: glfw.WindowHandle, x, y: i32){
    //state.pos = {x, y}
    window_width  = x
    window_height = y
    gl.Viewport(0, 0, x, y);
    redraw = true
}

char_callback :: proc "c" (window : glfw.WindowHandle, codepoint: rune){
    context = runtime.default_context()

    gapbuf_insert(&app.gap_buf, u8(codepoint))
    redraw = true
}



main :: proc(){

    if !bool(glfw.Init()){
	return
    }


    //sdl.Init({.VIDEO})

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
    glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, gl.TRUE);

    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 5)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    window = glfw.CreateWindow(window_width, window_height, "Nu code editor!", nil, nil) 

    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(1)
    glfw.SetWindowSizeCallback(window, viewport_callback)
    glfw.SetScrollCallback(window, scroll_callback);
    glfw.SetCharCallback(window, char_callback)



    //gl.load_up_to(3, 3, glfw.gl_set_proc_address)
    gl.load_up_to(4, 5, glfw.gl_set_proc_address)

    gl.Viewport(0, 0, window_width, window_height)
    //gl.DebugMessageCallback(gl_debug_callback, nil);
    gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, nil, gl.TRUE);


    using app

    gapbuf_init(&gap_buf, 200)

    glyph_atlas_width  = 512
    glyph_atlas_height = 512
    font_size_pt = 14

    program_id, _ = gl.load_shaders_file("font_vert.glsl", "font_frag.glsl")

    cursor_program_id, _ = gl.load_shaders_file("cursor_vert.glsl", "cursor_frag.glsl")


    //gl.CreateBuffers(1, &rect_vertices_vbo)
    //gl.NamedBufferStorage(rect_vertices_vbo, size_of(rect_vertices), &rect_vertices[0], 0)

    gl.CreateBuffers(1, &rect_instances_vbo)
    gl.CreateVertexArrays(1, &vao)
    //gl.VertexArrayVertexBuffer(vao, 0, rect_vertices_vbo, 0, size_of(index_xy))
    gl.VertexArrayVertexBuffer(vao, 0, rect_instances_vbo, 0, size_of(rect_instance));   // Set data source 1 to rect_instances_vbo, with offset 0 and proper stride
    gl.VertexArrayBindingDivisor(vao, 0, 1);  // Advance data source 1 every 1 instance instead of for every vertex (3rd argument is 1 instead of 0)
    // layout(location = 0) in uvec2 ltrb_index
    /*
    gl.EnableVertexArrayAttrib(vao, 0);     // read ltrb_index from a data source
    gl.VertexArrayAttribBinding(vao, 0, 0);  // read from data source 0
    gl.VertexArrayAttribIFormat(vao, 0, 2, gl.UNSIGNED_INT, 0);  // read 2 unsigned shorts starting at offset 0 and feed it into the vertex shader as integers instead of float (that's what the I means in glVertexArrayAttribIFormat)

    */
    // layout(location = 1) in vec4  rect_ltrb
    gl.EnableVertexArrayAttrib( vao, 0);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 0, 0);  // read from data source 1
    gl.VertexArrayAttribFormat( vao, 0, 4, gl.FLOAT, false , 0);
    // layout(location = 2) in vec4  rect_tex_ltrb

    gl.EnableVertexArrayAttrib( vao, 1);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 1, 0);  // read from data source 1

    gl.VertexArrayAttribFormat( vao, 1, 4, gl.FLOAT, false , u32(offset_of(rect_instance, tex_coords)));

    // layout(location = 3) in vec4  rect_color
    gl.EnableVertexArrayAttrib( vao, 2);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 2, 0);  // read from data source 1

    // read 4 unsigned bytes starting at the offset of the "color" member, convert them to float and normalize the value range 0..255 to 0..1.
    gl.VertexArrayAttribFormat( vao, 2, 4, gl.FLOAT, false, u32(offset_of(rect_instance, color)));  
    // layout(location = 4) in float rect_subpixel_shift
    /*
    gl.EnableVertexArrayAttrib( vao, 4);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 4, 1);  // read from data source 1
    gl.VertexArrayAttribIFormat( vao, 4, 1, gl.UNSIGNED_INT, u32(offset_of(rect_instance, index)));
    */


    gl.EnableVertexArrayAttrib( vao, 3);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 3, 0);  // read from data source 1
    gl.VertexArrayAttribFormat( vao, 3, 1, gl.FLOAT, false , u32(offset_of(rect_instance, subpixel_shift)));



    gl.CreateTextures(gl.TEXTURE_RECTANGLE, 1, &glyph_atlas_texture)
    gl.TextureStorage2D(glyph_atlas_texture, 1, gl.RGB8, glyph_atlas_width , glyph_atlas_height)


	init_cursor()
	init_imgui()

	redraw = true
    
	for !glfw.WindowShouldClose(window){
		glfw.PollEvents()

		process_inputs()
		//Handle events
		if is_down(.BACK){
			time.sleep(90000000)
			gapbuf_backspace(&app.gap_buf)
			redraw = true
		}
		if is_pressed(.ENTER){
			gapbuf_insert(&app.gap_buf, '\n')
			redraw = true
		}
		if is_pressed(.TAB){
			gapbuf_insert(&app.gap_buf, '\t')
			redraw = true
		}
		if is_down(.ACTION_LEFT){
			time.sleep(90000000)
			gapbuf_backward(&app.gap_buf)
			redraw = true
		}

		if is_down(.ACTION_RIGHT){
			time.sleep(90000000)
			gapbuf_frontward(&app.gap_buf)
			redraw = true
		}







	render_font()

	imgui_impl_opengl3.NewFrame()
	imgui_impl_glfw.NewFrame()
	im.NewFrame()


	if im.Begin("Info stuffs", nil, {}){

		flags := im.TableFlags_Borders | im.TableFlags_RowBg 

		if im.BeginTable("Info", 2, flags){
			io : = im.GetIO()
			im.TableSetupColumn("Front", nil)
			im.TableSetupColumn("Value", nil)
			im.TableNextRow()
			im.TableSetColumnIndex(0)
			im.Text("Front")
			im.TableSetColumnIndex(1)
			im.Text("%d\n", app.gap_buf.front)

			im.TableNextRow()
			im.TableSetColumnIndex(0)
			im.Text("Gap size")
			im.TableSetColumnIndex(1)
			im.Text("%d\n", app.gap_buf.gap)

			im.TableNextRow()
			im.TableSetColumnIndex(0)
			im.Text("Total size")
			im.TableSetColumnIndex(1)
			im.Text("%d\n", app.gap_buf.total)
		}

		im.EndTable()
	}
	im.End()



	im.Render()
	imgui_impl_opengl3.RenderDrawData(im.GetDrawData())
	glfw.SwapBuffers(window)


	// Draw all the rects in the rect_buffer 

    }
}







