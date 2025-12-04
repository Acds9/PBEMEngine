#version 460

#extension GL_GOOGLE_include_directive : require
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require 
#extension GL_EXT_shader_explicit_arithmetic_types : require  
#extension GL_EXT_scalar_block_layout : require

// Because ImGui doesn't know/care about alignement, we have to do it this way to not pad every struct we copy into the buffer
layout(buffer_reference, scalar) readonly buffer VertexBuffer {
    float data[];
};

layout(push_constant) uniform PushConstants {
    vec2 scale;
    vec2 translate;
    uint64_t vertex_buffer_addr;
    uint texture_index;
};

layout(location = 0) out vec2 frag_uv;
layout(location = 1) out vec4 frag_color;

void main() {
    VertexBuffer buf = VertexBuffer(vertex_buffer_addr);
    uint base = gl_VertexIndex * 5;  // 20 bytes = 5 floats
    
    vec2 pos = vec2(buf.data[base + 0], buf.data[base + 1]);
    vec2 uv = vec2(buf.data[base + 2], buf.data[base + 3]);
    uint color = floatBitsToUint(buf.data[base + 4]);
    gl_Position = vec4(pos * scale + translate, 0.0, 1.0);
    frag_uv = uv;
    frag_color = unpackUnorm4x8(color);
}