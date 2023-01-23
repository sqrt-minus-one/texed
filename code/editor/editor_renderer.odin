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

RenderBuffer :: proc(Renderer: ^render.renderer_context, 
                     Font:   ^font, 
                     Buffer: ^text_buffer, 
                     P:     math.v2u,
                     Color: render.color_rgba,)
{
  LineGap := Font.LineAdvance - (Font.Ascent - Font.Descent);
  TextPos := math.V2((f32(P.x)) * Font.GlyphWidth, 
                     LineGap + 0.5 * Font.LineAdvance + f32(P.y) * Font.LineAdvance);
  
  // NOTE(fakhri): render each character
  {
    ChOffset := 0;
    Text := string(Buffer.Data[:Buffer.Size]);
    for Ch in Text
    {
      // TODO(fakhri): utf8 support
      defer ChOffset += 1;
      
      CharColor := Color;
      
      if ChOffset == Buffer.Cursor
      {
        // NOTE(fakhri): render cursor
        CursorPos := math.V2(TextPos.x + 0.5 * Font.GlyphWidth, TextPos.y - 1.5 * LineGap);
        render.PushRect(RenderCommands = Renderer,
                        P  = CursorPos,
                        Size = math.V2(Font.GlyphWidth, Font.Ascent - Font.Descent),
                        Color = render.MakeColor(1));
        CharColor = render.MakeColor(0, 0, 0, 1);
      }
      
      if Ch == '\n'
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
                                   Color = CharColor);
      
    }
    
    
    if Buffer.Cursor == Buffer.Size
    {
      // NOTE(fakhri): render cursor in case it was at the end of the buffer
      CursorPos := math.V2(TextPos.x + 0.5 * Font.GlyphWidth, TextPos.y - 1.5 * LineGap);
      render.PushRect(RenderCommands = Renderer,
                      P  = CursorPos,
                      Size = math.V2(Font.GlyphWidth, Font.Ascent - Font.Descent),
                      Color = render.MakeColor(1));
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