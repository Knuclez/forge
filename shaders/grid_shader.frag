#version 450

layout(location = 0) in vec3 worldPos;

layout(location = 0) out vec4 outColor;

void main()
{
    // Coordenadas sobre el plano XZ
    vec2 coord = worldPos.xz;

    // Parte decimal de cada coordenada
    vec2 cell = fract(coord);

    float lineWidth = 0.02;

    if (cell.x < lineWidth ||
        cell.y < lineWidth)
    {
        outColor = vec4(0.6, 0.6, 0.6, 1.0);
    }
    else
    {
        outColor = vec4(0.15, 0.15, 0.15, 1.0);
    }
}
