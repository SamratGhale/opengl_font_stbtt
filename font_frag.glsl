#version 450 core
#extension GL_ARB_texture_rectangle: enable

layout(location=1) uniform uint coverage_adjustment;
layout(location=2) uniform uint  front_index; //gap buffer front

layout(binding  = 0) uniform sampler2DRect glyph_atlas;

in vec2 tex_coords;
in flat vec4 color;
in flat float subpixel_shift;
in flat uint index_out;


layout(location = 0, index = 0) out vec4 fragment_color;
layout(location = 0, index = 1) out vec4 blend_weights;

void main (){



    vec3 current  = texelFetch(glyph_atlas, ivec2(tex_coords) + ivec2( 0, 0)).rgb;
    vec3 previous = texelFetch(glyph_atlas, ivec2(tex_coords) + ivec2(-1, 0)).rgb;
    float r = current.r, g = current.g, b = current.b;
    if (subpixel_shift <= 1.0/3.0) {
      float z = 3.0 * subpixel_shift;
      r = mix(current.r, previous.b, z);
      g = mix(current.g, current.r, z);
      b = mix(current.b, current.g, z);
    } else if (subpixel_shift <= 2.0/3.0) {
      float z = 3.0 * subpixel_shift - 1.0;
      r = mix(previous.b, previous.g, z);
      g = mix(current.r,  previous.b, z);
      b = mix(current.g,  current.r,  z);
    } else if (subpixel_shift < 1.0) {
      float z = 3.0 * subpixel_shift - 2.0;
      r = mix(previous.g, previous.r, z);
      g = mix(previous.b, previous.g, z);
      b = mix(current.r,  previous.b, z);
    }

    vec3 pixel_coverages = vec3(r, g, b);

    if(coverage_adjustment >= 0){
      pixel_coverages = min(pixel_coverages * (1 + coverage_adjustment), 1);
    }else{
      pixel_coverages = max((1 - (1 - pixel_coverages) * (1 + -coverage_adjustment)), 0);
    }

    fragment_color = color * vec4(pixel_coverages, 1);
    blend_weights  = vec4(color.a * pixel_coverages, color.a);
}
