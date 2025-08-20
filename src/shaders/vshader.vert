#version 460 core
layout (location = 0) in vec3 aPos;

uniform mat4 gTranslation;

void main()
{
    gl_Position = gTranslation * vec4(aPos.x, aPos.y, aPos.z, 1.0);
}