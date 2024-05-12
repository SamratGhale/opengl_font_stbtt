#version 450 core

layout(location=0) uniform vec2 half_viewport_size;

layout(location=0) in uvec2 ltrb_index;
layout(location=1) in vec4  rect_ltrb;
layout(location=2) in vec4  rect_tex_ltrb;
layout(location=3) in vec4  rect_color;
layout(location=4) in float rect_subpixel_shift;

out vec2  tex_coords;
out vec4  color;
out float subpixel_shift;

void main(){
  //Convert color to pre-multipled alpha

  color = vec4(rect_color.rgb * rect_color.a, rect_color.a);

  vec2 pos   = vec2(rect_ltrb[ltrb_index.x],     rect_ltrb[ltrb_index.y]);
  tex_coords = vec2(rect_tex_ltrb[ltrb_index.x], rect_tex_ltrb[ltrb_index.y]);
  subpixel_shift = rect_subpixel_shift;

  vec2 axes_flip  = vec2(1, -1); // to flip y axis from bottom up
  vec2 pos_in_ndc = (pos / half_viewport_size - 1.0) * axes_flip;
  gl_Position = vec4(pos_in_ndc, 0, 1);
}
