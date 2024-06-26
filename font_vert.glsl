#version 450 core
#extension GL_ARB_texture_rectangle: enable


layout(location=0) uniform vec2 half_viewport_size;

//layout(location=0) in uvec2 ltrb_index;
layout(location=0) in vec4  rect_ltrb;
layout(location=1) in vec4  rect_tex_ltrb;
layout(location=2) in vec4  rect_color;
//layout(location=4) in uint  index;
layout(location=3) in float rect_subpixel_shift;


flat out vec2  tex_coords;
flat out vec4  color;
flat out float subpixel_shift;
flat out uint   index_out;


void main(){
  uvec2[6] rect_vertices = {
    {0, 1}, //left top
    {0, 3}, //left buttom
    {2, 1}, //right top
    {0, 3}, //Left buttom
    {2, 3}, //right bottom
    {2, 1}, //right top
  };
  //Convert color to pre-multipled alpha

  uvec2 indexx =  rect_vertices[gl_VertexID];

  color = vec4(rect_color.rgb * rect_color.a, rect_color.a);

  vec2 pos   = vec2(    rect_ltrb[indexx.x],     rect_ltrb[indexx.y]);
  tex_coords = vec2(rect_tex_ltrb[indexx.x], rect_tex_ltrb[indexx.y]);
  subpixel_shift = rect_subpixel_shift;
  //index_out      = index;


  vec2 axes_flip  = vec2(1, -1); // to flip y axis from bottom up
  vec2 pos_in_ndc = (pos / half_viewport_size - 1.0) * axes_flip;
  gl_Position = vec4(pos_in_ndc, 0, 1);
}
