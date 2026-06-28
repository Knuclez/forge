#version 450

layout (binding = 0) uniform UniformBufferObject{
    mat4 model;
    mat4 view;
    mat4 proj;
} ubo;

layout (location = 0) in vec3 inPos;

layout(location = 0) out vec3 worldPos;

void main() {
    vec4 wp = ubo.model * vec4(inPos,1);
    worldPos = wp.xyz;
    gl_Position = ubo.proj * ubo.view * wp;
}
