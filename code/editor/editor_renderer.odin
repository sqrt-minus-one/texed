package editor

import "shared:render"
import "shared:base/math"

TAB_WIDTH :: 2;

RenderCharacter :: proc(Renderer : ^render.renderer_context, 
                        Font : ^font, 
                        Char : rune, 
                        P      :math.v2,
                        Color  :render.color_rgba,) -> (Advance :f32)
{
  Glyph := GetGlyphFromRune(Font, Char);
  GlyphP := P + Glyph.Offset;
  
  render.PushImage(RenderCommands = Renderer, 
                   P  = GlyphP, 
                   Size = Glyph.Size,
                   Texture = Font.AtlasTexture,
                   Color = Color, 
                   UVScale = Glyph.UVScale, 
                   UVOffset = Glyph.UVOffset);
  Advance = Glyph.Advance;
  return;
}

RenderText :: proc(Renderer : ^render.renderer_context, 
                   Font : ^font, 
                   Text : string, 
                   P      :math.v2u,
                   Color  :render.color_rgba,)
{
  TextPos := math.V2((f32(P.x)) * Font.GlyphWidth, (f32(P.y) + 0.6) * Font.LineAdvance);
  
  // NOTE(fakhri): render each character
  {
    for Ch in Text
    {
      CharColor := Color;
      if Ch == '\r' || Ch == '\n'
      {
        TextPos.y += Font.LineAdvance;
        TextPos.x  = 0;
        continue;
      }
      if Ch == '\t'
      {
        TextPos.x  += TAB_WIDTH * Font.GlyphWidth;
        continue;
      }
      
      TextPos.x += RenderCharacter(Renderer = Renderer,
                                   Font = Font, 
                                   Char = Ch, 
                                   P    = TextPos,
                                   Color=CharColor);
    }
  }
}

RenderOutLine :: proc(Renderer : ^render.renderer_context, 
                      P        : math.v2, // Top-Left
                      Size     : math.v2,
                      Color    : render.color_rgba,
                      Thickness: f32)
{
  TopP    := P + math.V2(0.0, 0.5 * Size.y);
  BottomP := P + math.V2(0, -0.5 * Size.y);
  LeftP   := P + math.V2(-0.5 * Size.x, 0);
  RightP  := P + math.V2(0.5 * Size.x, 0);
  
  render.PushRect(Renderer, TopP, math.V2(Size.x, Thickness), Color);
  render.PushRect(Renderer, BottomP, math.V2(Size.x, Thickness), Color);
  render.PushRect(Renderer, RightP, math.V2(Thickness, Size.y), Color);
  render.PushRect(Renderer, LeftP, math.V2(Thickness, Size.y), Color);
}