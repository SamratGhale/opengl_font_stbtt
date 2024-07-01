package main
import stbtt "vendor:stb/truetype"
import gl   "vendor:OpenGl"
import      "core:mem"
import      "core:math"

glyph_atlas_item :: struct {
    filled: bool ,
    tex_coords: rect4i16,
    glyph_index: i32, 
    distance_from_baseline_to_top_px: i32,
}

GlyphState :: struct{
    font_info    : stbtt.fontinfo, //This shouldn't be repeated for each box
    font_size_pt : f32,

    vao          : u32,

    program_id   : u32,
	current_x, current_y : f32,
    pos          : vec2,

    glyph_atlas_items : [127]glyph_atlas_item,
    glyph_atlas_width  : i32 ,
    glyph_atlas_height : i32 ,
    glyph_atlas_texture : u32,
    rect_buffer : [dynamic]rect_instance,
    rect_instances_vbo : u32,

    framebuf : u32,
}

/*
 This is a big function
*/

render_font :: proc (using glyph_state: ^GlyphState, text: string, front: u32){

    //using app
    //text := get_string(&gap_buf)

    coverage_adjustment  :f32 =  0.0
    text_color : color_t = {0, 0, 0, 1}


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
	current_x, current_y = pos.x, f32(pos.y) + math.round(baseline)

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
		current_x = pos.x
		current_y += math.round(line_height)


	    } else if c == '\t'{
			current_x +=  2 * font_size_pt
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
	    if u32(i) == front-1{
	    	app.cursor.cursor.x = current_x
	    	app.cursor.cursor.y = current_y
	    }
	}
    }
	}
	{

	if front == 0{
		app.cursor.cursor.x = 0
		app.cursor.cursor.y = 13
	}
	gl.ClearColor(0.8, 0.8, 0.8, 1.0);
	gl.Clear(gl.COLOR_BUFFER_BIT);

	render_cursor()


	
	// Upload the rect buffer to the GPU.
	// Allow the GPU driver to create a new buffer storage for each draw command. That way it doesn't have to wait for
	// the previous draw command to finish to reuse the same buffer storage.

    if len(text)>0{
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
	gl.ProgramUniform2f(program_id,  0, f32(window_width) / 2.0, f32(window_height) / 2.0);
	gl.ProgramUniform1ui(program_id, 1, u32(coverage_adjustment));
	gl.ProgramUniform1ui(program_id, 2, front);
	gl.BindTextureUnit(0, glyph_atlas_texture);
	//gl.BindTexture(gl.TEXTURE_2D, glyph_atlas_texture);
	//gl.ProgramUniform1i(program_id, 3, i32(glyph_atlas_texture));
	gl.DrawArraysInstanced(gl.TRIANGLES, 0, 6, i32(len(rect_buffer)));



	gl.UseProgram(0);
	gl.BindVertexArray(0);
	
	// We don't need the contents of the CPU or GPU buffer anymore
	gl.InvalidateBufferData(rect_instances_vbo);



	//glfw.SwapBuffers(window)
    }
    redraw = false
    recalc = false
}
