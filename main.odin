package main

import      "core:fmt"
import      "base:runtime"
import      "core:mem"
import gl   "vendor:OpenGl"
import      "core:strings"
import      "core:os"
import      "core:math"
import glfw "vendor:glfw"
import stbtt "vendor:stb/truetype"

/*
  Create a memory (u8 array) to store text 


*/

window : glfw.WindowHandle

rect4i16 :: [4]i16
color_t :: [4]u8


window_height :i32= 800
window_width  :i32= 1000


rect_instance :: struct  #packed {
    pos        : rect4i16,
    tex_coords : rect4i16,
    color           : color_t,
    subpixel_shift  : f32,
}

app : app_state



app_state :: struct{
    builder : strings.Builder,
    font_info : stbtt.fontinfo,
    glyph_atlas_items : [127]glyph_atlas_item,
    glyph_atlas_width  : i32 ,
    glyph_atlas_height : i32 ,
    glyph_atlas_texture : u32,
    rect_buffer : [25500]rect_instance,
    rect_buffer_filled : i32,
    rect_instances_vbo : u32,
    vao : u32,
    program_id: u32,
    pos_x  :f32,
    pos_y  :f32,
    font_size_pt : f32,
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

render_font :: proc (){

    using app
    text := strings.to_string(builder)
    coverage_adjustment  :f32 =  0.0
    text_color : color_t = {218, 218 , 218, 255}
    font_data, _ := os.read_entire_file_from_filename("C:/Windows/Fonts/Consola.ttf")
    stbtt.InitFont(&font_info, &font_data[0], 0)

    //text : string = "The quick brown fox \n jumps over the lazy dog.i Appple mangoe fwejalfjwlf w g rjl \n fjewlfwe"

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
	current_x, current_y : f32 = pos_x, f32(pos_y) + math.round(baseline)


	//iterate over the UTF-8 text codepoint by codepoint. A codepoint is basically 32 bit ID of a character as defined by Unicode

	prev_codepoint : rune = 0

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
			glyph_atlas.tex_coords[0]     = i16(atlas_item_x)
			glyph_atlas.tex_coords[1]     = i16(atlas_item_y)
			glyph_atlas.tex_coords[2]     = i16(atlas_item_x + padded_glyph_width_px)
			glyph_atlas.tex_coords[3]     = i16(atlas_item_y + padded_glyph_height_px)
		    } else {
			glyph_atlas.tex_coords[0]  = -1 
			glyph_atlas.tex_coords[1]  = -1 
			glyph_atlas.tex_coords[2]  = -1 
			glyph_atlas.tex_coords[3]  = -1 
		    }

		    glyph_atlas.glyph_index = glyph_index
		    glyph_atlas.distance_from_baseline_to_top_px = distance_from_baseline_to_top_px
		    glyph_atlas.filled      = true
		    glyph_atlas_items[codepoint] = glyph_atlas
		}

		glyph_advance_width, glyph_left_side_bearing : i32 = 0, 0

		stbtt.GetGlyphHMetrics(&font_info, glyph_atlas.glyph_index, &glyph_advance_width, &glyph_left_side_bearing)

		if glyph_atlas.tex_coords[0] != -1{

		    glyph_pos_x    :f32 = current_x + (f32(glyph_left_side_bearing) * font_scale) 

		    glyph_pos_x_px, glyph_pos_x_subpixel_shift :f32= math.modf_f32(glyph_pos_x)


		    glyph_pos_y_px :f32 = current_y - f32(glyph_atlas.distance_from_baseline_to_top_px)
		    glyph_width_with_horiz_filter_padding :i32 = i32(glyph_atlas.tex_coords[2] - glyph_atlas.tex_coords[0])
		    glyph_height    :i32 = i32(glyph_atlas.tex_coords[3] - glyph_atlas.tex_coords[1])

		    r :  rect_instance 

		    r.pos[0] = i16(glyph_pos_x_px - f32(subpixel_positioning_left_padding + horizontal_filter_padding));;
		    r.pos[1] = i16(glyph_pos_y_px);
		    r.pos[2] = i16(glyph_pos_x_px - f32(subpixel_positioning_left_padding + horizontal_filter_padding) + f32(glyph_width_with_horiz_filter_padding))
		    r.pos[3] = i16(glyph_pos_y_px + f32(glyph_height));

		    r.subpixel_shift = glyph_pos_x_subpixel_shift;
		    r.tex_coords     = glyph_atlas.tex_coords;
		    r.color          = text_color;
		    rect_buffer[rect_buffer_filled] = r
		    rect_buffer_filled += 1
		}

		current_x += f32(glyph_advance_width) * font_scale
	    }
	}
    }
    {
	gl.ClearColor(0.25, 0.25, 0.25, 1.0);

	gl.Clear(gl.COLOR_BUFFER_BIT);


	
	// Upload the rect buffer to the GPU.
	// Allow the GPU driver to create a new buffer storage for each draw command. That way it doesn't have to wait for
	// the previous draw command to finish to reuse the same buffer storage.
	gl.NamedBufferData(rect_instances_vbo, int(rect_buffer_filled * size_of(rect_buffer[0])), &rect_buffer, gl.DYNAMIC_DRAW);
	
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
	gl.ProgramUniform1f(program_id, 1, coverage_adjustment);
	gl.BindTextureUnit(0, glyph_atlas_texture);
	gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, rect_buffer_filled);
	gl.UseProgram(0);
	gl.BindVertexArray(0);
	
	// We don't need the contents of the CPU or GPU buffer anymore
	gl.InvalidateBufferData(rect_instances_vbo);
	rect_buffer_filled = 0;
	glfw.SwapBuffers(window)
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

    strings.write_rune(&app.builder, codepoint)
    redraw = true
}

keyboard_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods : i32){
    context = runtime.default_context()
    if key == glfw.KEY_BACKSPACE && action == glfw.PRESS{
	strings.pop_rune(&app.builder)
    }
    if key == glfw.KEY_ENTER && action == glfw.PRESS{
	strings.write_rune(&app.builder, '\n')
    }

    redraw = true
}


main :: proc(){

    if !bool(glfw.Init()){
	return
    }

    //sdl.Init({.VIDEO})

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 5)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    window = glfw.CreateWindow(window_width, window_height, "Font stuffs!", nil, nil) 

    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(1)
    glfw.SetWindowSizeCallback(window, viewport_callback)
    glfw.SetScrollCallback(window, scroll_callback);
    glfw.SetCharCallback(window, char_callback)
    glfw.SetKeyCallback(window, keyboard_callback)



    gl.load_up_to(4, 5, glfw.gl_set_proc_address)

    gl.Viewport(0, 0, window_width, window_height)
    gl.DebugMessageCallback(gl_debug_callback, nil);
    gl.DebugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, nil, gl.TRUE);


    using app

    glyph_atlas_width  = 512
    glyph_atlas_height = 512
    font_size_pt = 10

    program_id, _ = gl.load_shaders_file("vert.glsl", "frag.glsl")


    index_xy :: struct {
	ltrb_index_y : u16,
	ltrb_index_x : u16,
    }

    rect_vertices : [6] index_xy = {
	{0, 1}, //left top
	{0, 3}, //left buttom
	{2, 1}, //right top
	{0, 3}, //Left buttom
	{2, 3}, //right bottom
	{2, 1}, //right top
    }

    rect_vertices_vbo : u32 = 0
    gl.CreateBuffers(1, &rect_vertices_vbo)
    gl.NamedBufferStorage(rect_vertices_vbo, size_of(rect_vertices), &rect_vertices[0], 0)




    gl.CreateBuffers(1, &rect_instances_vbo)

    gl.CreateVertexArrays(1, &vao)
    gl.VertexArrayVertexBuffer(vao, 0, rect_vertices_vbo, 0, size_of(rect_vertices[0]))
    gl.VertexArrayVertexBuffer(vao, 1, rect_instances_vbo, 0, size_of(rect_instance));   // Set data source 1 to rect_instances_vbo, with offset 0 and proper stride
    gl.VertexArrayBindingDivisor(vao, 1, 1);  // Advance data source 1 every 1 instance instead of for every vertex (3rd argument is 1 instead of 0)
    // layout(location = 0) in uvec2 ltrb_index
    gl.EnableVertexArrayAttrib( vao, 0);     // read ltrb_index from a data source
    gl.VertexArrayAttribBinding(vao, 0, 0);  // read from data source 0
    gl.VertexArrayAttribIFormat(vao, 0, 2, gl.UNSIGNED_SHORT, 0);  // read 2 unsigned shorts starting at offset 0 and feed it into the vertex shader as integers instead of float (that's what the I means in glVertexArrayAttribIFormat)
    // layout(location = 1) in vec4  rect_ltrb
    gl.EnableVertexArrayAttrib( vao, 1);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 1, 1);  // read from data source 1
    gl.VertexArrayAttribFormat( vao, 1, 4, gl.SHORT, false , 0);
    // layout(location = 2) in vec4  rect_tex_ltrb

    gl.EnableVertexArrayAttrib( vao, 2);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 2, 1);  // read from data source 1

    gl.VertexArrayAttribFormat( vao, 2, 4, gl.SHORT, false , u32(offset_of(rect_instance, tex_coords)));

    // layout(location = 3) in vec4  rect_color
    gl.EnableVertexArrayAttrib( vao, 3);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 3, 1);  // read from data source 1

    // read 4 unsigned bytes starting at the offset of the "color" member, convert them to float and normalize the value range 0..255 to 0..1.
    gl.VertexArrayAttribFormat( vao, 3, 4, gl.UNSIGNED_BYTE, true, u32(offset_of(rect_instance, color)));  
    // layout(location = 4) in float rect_subpixel_shift
    gl.EnableVertexArrayAttrib( vao, 4);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 4, 1);  // read from data source 1
    gl.VertexArrayAttribFormat( vao, 4, 1, gl.FLOAT, false , u32(offset_of(rect_instance, subpixel_shift)));



    gl.CreateTextures(gl.TEXTURE_RECTANGLE, 1, &glyph_atlas_texture)
    gl.TextureStorage2D(glyph_atlas_texture, 1, gl.RGB8, glyph_atlas_width , glyph_atlas_height)





    //strings
    strings.builder_init_none(&builder)

    file_data, _ := os.read_entire_file_from_filename("main.odin")
    strings.write_bytes(&builder, file_data)


    
    for !glfw.WindowShouldClose(window){
	glfw.PollEvents()



	if redraw{
	    render_font()
	}

	// Draw all the rects in the rect_buffer 

    }
}







