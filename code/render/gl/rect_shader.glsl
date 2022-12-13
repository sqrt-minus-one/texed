
#ifdef VERTEX_SHADER
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aUV;

out vec2 TexUV;
uniform mat4 Model;
uniform mat4 Clip;

uniform vec2 UVOffset = vec2(0, 0);
uniform vec2 UVScale  = vec2(1, 1);

void main()
{
  gl_Position = Clip * Model * vec4(aPos, 0, 1);
  TexUV = UVOffset + UVScale * aUV;
}

#endif

#ifdef FRAGMENT_SHADER

in vec2 TexUV;
out vec4 FragColor;

uniform sampler2D Tex0;
uniform vec4 Color;

void main()
{
  FragColor = Color * texture(Tex0, TexUV);
}

#endif
