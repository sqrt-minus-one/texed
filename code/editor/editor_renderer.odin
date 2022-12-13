package editor

import "shared:render"
import "shared:base/math"

RenderText :: proc(Renderer : ^render.renderer_context, 
                   Font : ^font, 
                   Text : string, 
                   P     :math.v2,
                   Color :render.color_rgba) -> (Width : f32)
{
  
  TextPos := P;
  Width = TextWidth(Font, Text);
  TextPos.x -= 0.5 * Width;
  // NOTE(fakhri): render each character
  {
    for Ch in Text
    {
      Glyph := GetGlyphFromRune(Font, Ch);
      
      GlyphP := TextPos + (Glyph.Offset + 0.5 * Glyph.Size);
      render.PushImage(RenderCommands = Renderer, 
                       Center = GlyphP, 
                       Size = Glyph.Size, Texture = Font.AtlasTexture,
                       Color = Color, 
                       UVScale = Glyph.UVScale, 
                       UVOffset = Glyph.UVOffset);
      
      // TODO(fakhri): kerning
      TextPos.x += Glyph.Advance;
    }
  }
  return;
}