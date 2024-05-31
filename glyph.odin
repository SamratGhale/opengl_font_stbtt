package main
import stbtt "vendor:stb/truetype"

glyph_atlas_item :: struct {
    filled: bool ,
    tex_coords: rect4i16,
    glyph_index: i32, 
    distance_from_baseline_to_top_px: i32,
}

GlyphState :: struct{
	//program_id :u32,
    font_info    : stbtt.fontinfo,
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
}