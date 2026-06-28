#version 450

layout(location = 0) in vec3 worldPos;

layout(location = 0) out vec4 outColor;

void main() {
    vec2 uv = worldPos.xz;
    vec2 cell = fract(uv);
    outColor = vec4(cell, 0.0, 1.0);
}
