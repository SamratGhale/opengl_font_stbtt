#version 450 core

layout (location = 0) uniform mat4 mat;
layout (location = 0) in vec3 pos;
layout (location = 1) in vec4 o_color;

out     vec2 v_pos;
out     vec4 obj_color;


void main(){
	gl_Position = mat * vec4(pos, 1.0);
	v_pos = vec2(pos.x, pos.y);
	obj_color = o_color;
}
