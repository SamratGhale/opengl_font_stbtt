package main

import      "core:fmt"
import strings "core:strings"
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
* Unify where the inputs are handled
* 
* Make the editor useable for viewing files
* Have boxes to hold buffers and render them accordingly
*/

window : glfw.WindowHandle

rect4i16 :: struct { l, t, r, b: f32 }
color_t :: [4]f32
vec3 :: [3]f32
vec2 :: [3]f32


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
    program_id : u32,
	cursor_buf, vao : u32,
	cursor          : Cursor,
}

Cursor :: struct {
	x, y : f32,
	color: color_t,
}

app : app_state

app_state :: struct{
	index_rect   : rect_instance,

	open_file : string,

    cursor  : CursorGl,
	input   : Input,
	console : Console,
    gap_buf : GapBuf,

	using vim_state : VimState,
	using glyph     : GlyphState, //For font rendering
	
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
    	app.pos.y += f32(y * 20)
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
	//io.Fonts->AddFontFromFileTTF();
	im.FontAtlas_AddFontFromFileTTF(io.Fonts, "C:/Windows/Fonts/Consola.ttf", 17)

	io.ConfigFlags += {.NavEnableKeyboard}

	im.StyleColorsDark()

	imgui_impl_glfw.InitForOpenGL(window, true)
	imgui_impl_opengl3.Init("#version 150")
}

//only use the x distance of the current index
render_cursor :: proc(){
	using app.cursor
	ret : rect4i16 
	ret.l = cursor.x
	ret.b = cursor.y + 6 

	if app.gap_buf.front == 0{
	}
	if app.mode == .Insert{
		ret.r = ret.l + 2
	}else{
		ret.r = ret.l + 10
	}

	ret.t = ret.b - 25

	cursor.color = {0,1,1,1}
    a :f32= 2.0 / f32(window_width)
    b :f32= 2.0 / f32(window_height)
	proj : [16]f32 = {
		a, 0, 0, 0, 0, b, 0, 0, 0, 0, 1, 0, -1, -1, 0, 1,
	};
	//put cursor_program_id inside CursorGL

	color := color_t{1, 0, 0, 1}

    gl.UseProgram(app.cursor.program_id)

	vertices := []f32 {
	    ret.l, ret.t, 0.0, color.r, color.g, color.b, color.a, // top right
	    ret.l, ret.b, 0.0, color.r, color.g, color.b, color.a, // bottom right
	    ret.r, ret.t, 0.0, color.r, color.g, color.b, color.a, // top left 

	    ret.l,  ret.b, 0.0, color.r, color.g, color.b, color.a, // bottom right
	    ret.r,  ret.b, 0.0, color.r, color.g, color.b, color.a, // bottom left
	    ret.r,  ret.t, 0.0, color.r, color.g, color.b, color.a // top left 
	};


	//gl.ProgramUniform2f(program_id, 0, f32(window_width) / 2.0, f32(window_height) / 2.0);
	gl.ProgramUniformMatrix4fv(app.cursor.program_id, 0, 1, gl.FALSE,  &proj[0]);
    gl.NamedBufferData(cursor_buf, size_of(f32) * 6 * 7, &vertices[0], gl.DYNAMIC_DRAW)
    gl.BindVertexArray(vao)
	gl.Disable(gl.BLEND);
    gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, 6)
	gl.Enable(gl.BLEND);
    //gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil);

    gl.UseProgram(0)
    gl.BindVertexArray(0)

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

    if app.mode == .Normal{
        vim_process_char_normal_mode(codepoint);
	}
	else if app.mode == .Insert{
		gapbuf_insert(&app.gap_buf, u8(codepoint))
		redraw = true
	}
}

render_status_bar :: proc(){

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

    if len(os.args) > 1{
    	fmt.println(os.args[1])
    	gapbuf_init_file(&gap_buf, os.args[1])
    	app.open_file = os.args[1]
    }else{
    	gapbuf_init(&gap_buf, 200)
    }


    glyph_atlas_width  = 512
    glyph_atlas_height = 512
    font_size_pt = 14

    program_id, _ = gl.load_shaders_file("font_vert.glsl", "font_frag.glsl")

    cursor.program_id, _ = gl.load_shaders_file("cursor_vert.glsl", "cursor_frag.glsl")

    gl.CreateBuffers(1, &rect_instances_vbo)
    gl.CreateVertexArrays(1, &vao)
    //gl.VertexArrayVertexBuffer(vao, 0, rect_vertices_vbo, 0, size_of(index_xy))
    gl.VertexArrayVertexBuffer(vao, 0, rect_instances_vbo, 0, size_of(rect_instance));   // Set data source 1 to rect_instances_vbo, with offset 0 and proper stride
    gl.VertexArrayBindingDivisor(vao, 0, 1);  // Advance data source 1 every 1 instance instead of for every vertex (3rd argument is 1 instead of 0)
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

    gl.VertexArrayAttribFormat( vao, 2, 4, gl.FLOAT, false, u32(offset_of(rect_instance, color)));  


    gl.EnableVertexArrayAttrib (vao, 3);     // read it from a data source
    gl.VertexArrayAttribBinding(vao, 3, 0);  // read from data source 1
    gl.VertexArrayAttribFormat (vao, 3, 1, gl.FLOAT, false , u32(offset_of(rect_instance, subpixel_shift)));



    gl.CreateTextures(gl.TEXTURE_RECTANGLE, 1, &glyph_atlas_texture)
    gl.TextureStorage2D(glyph_atlas_texture, 1, gl.RGB8, glyph_atlas_width , glyph_atlas_height)


	init_cursor()
	init_imgui()

	redraw = true
    font_data, _ := os.read_entire_file_from_filename("C:/Windows/Fonts/Consola.ttf")
    stbtt.InitFont(&font_info, &font_data[0], 0)



    //Console

    init_console(&app.console)


    
	for !glfw.WindowShouldClose(window){
		glfw.WaitEvents()

		process_inputs()
        vim_process_key()




	    text := get_string(&app.gap_buf)
	    render_font(&app.glyph, text, app.gap_buf.front)

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

			    im.TableNextRow()
			    im.TableSetColumnIndex(0)
			    im.Text("Pos ")
			    im.TableSetColumnIndex(1)
			    row, column := gapbuf_get_curr_pos(&app.gap_buf)
			    im.Text("%d, %d\n", row, column)

			    im.TableNextRow()
			    im.TableSetColumnIndex(0)
			    im.Text("Vim Mode")
			    im.TableSetColumnIndex(1)

                vim_val, _ := fmt.enum_value_to_string(mode)
			    im.Text(strings.unsafe_string_to_cstring(vim_val))
			    //row, column := gapbuf_get_curr_pos(&app.gap_buf)
                /*
                im.Text("%f\n", app.cursor.cursor.x)
                im.Text("%f\n", app.cursor.cursor.y)
                */
                
            }

		    im.EndTable()

        }
        im.End()

	    open_console:= true


	    if(mode == .Command || mode == .ListFiles){
		    console_draw(&app.console, "Command",&open_console)
	    }

	    im.Render()
	    imgui_impl_opengl3.RenderDrawData(im.GetDrawData())
	    glfw.SwapBuffers(window)

    }
}







