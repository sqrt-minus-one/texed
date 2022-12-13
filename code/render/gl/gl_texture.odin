// +private
package editor_render_gl

import "shared:render"
import "shared:base/math"
import gl "vendor:OpenGL"

gl_texture_2d :: struct 
{
  Handle :u32,
  Size   :math.v2u,
  Format :render.texture_format_2d,
}

GetTextureRefByID :: proc(using GLContext :^gl_context, TextureID :render.texture_id) -> (Result :^gl_texture_2d)
{
  assert(u32(TextureID) < TexturesCount);
  Result = &Textures[u32(TextureID)];
  return;
}

GetTextureByID :: proc(using GLContext :^gl_context, TextureID :render.texture_id) -> (Result :gl_texture_2d)
{
  Result = GetTextureRefByID(GLContext, TextureID)^;
  return;
}


CreateTextureID :: proc(using GLContext :^gl_context) -> (Result :render.texture_id)
{
  assert(TexturesCount < len(Textures));
  Result = render.texture_id(TexturesCount);
  TexturesCount += 1;
  return;
}

ReserveTexture2D :: proc(Renderer :^render.renderer_context, Size :math.v2u, Format :render.texture_format_2d) -> render.texture_id
{
  GLContext := cast(^gl_context)Renderer;
  TextureID := CreateTextureID(GLContext);
  Texture := GetTextureRefByID(GLContext, TextureID); 
  
  gl.GenTextures(1, &Texture.Handle);
  assert(Texture.Handle != 0);
  gl.BindTexture(gl.TEXTURE_2D, Texture.Handle);
#partial switch(Format)
  {
    case .R8:
    {
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_R, gl.ONE);
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_G, gl.ONE);
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_B, gl.ONE);
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_A, gl.RED);
    }
    case .RGB8:
    {
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_R, gl.RED);
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_G, gl.GREEN);
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_B, gl.BLUE);
      gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_SWIZZLE_A, gl.ONE);
    }
  }
  gl.BindTexture(gl.TEXTURE_2D, 0);
  
  Texture.Format = Format;
  Texture.Size = Size;
  
  return TextureID;
}

BaseTypeFromTextureFormat2D :: proc(Format : render.texture_format_2d) -> (Result :u32)
{
  switch(Format)
  {
    case .R8:    Result = gl.UNSIGNED_BYTE;
    case .RGB8:  Result = gl.UNSIGNED_BYTE;
    case .RGBA8: Result = gl.UNSIGNED_BYTE;
  }
  return;
}

GenericFormatFromTextureFormat2D :: proc(Format : render.texture_format_2d) -> (Result :u32)
{
  switch(Format)
  {
    case .R8:    Result = gl.RED;
    case .RGB8:  Result = gl.RGBA;
    case .RGBA8: Result = gl.RGBA;
  }
  return Result;
}



FillTexture2D :: proc(Renderer :^render.renderer_context, TextureID :render.texture_id, Size :math.v2u, Data :rawptr)
{
  GLContext := cast(^gl_context)Renderer;
  Texture := GetTextureRefByID(GLContext, TextureID); 
  
  gl.BindTexture(gl.TEXTURE_2D, Texture.Handle);
  GenericFormat := GenericFormatFromTextureFormat2D(Texture.Format);
  BaseType := BaseTypeFromTextureFormat2D(Texture.Format);
  gl.TexImage2D(gl.TEXTURE_2D, 0, i32(GenericFormat), i32(Size.x), i32(Size.y), 0, GenericFormat, BaseType, Data);
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.GenerateMipmap(gl.TEXTURE_2D);
}
