#version 450 core

in vec2 v_pos;
in vec4 obj_color;

out vec4 color;

void main(){
	color = obj_color;
}