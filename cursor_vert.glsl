#version 450 core

layout(location=0) uniform vec2 half_viewport_size;

out vec2 tex_coords;
out vec4 color;
out float subpixel_shift;
out uint index_out;








void main(){

  vec2 pos_in_ndc = (pos / half_viewport_size - 1.0) * axes_flip;
	gl_Position = vec4(pos_in_ndc)
}
