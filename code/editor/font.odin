package editor

import "shared:base/math"
import "shared:render"
import "core:os"
import "core:mem"
import stbtt "vendor:stb/truetype"

arena :: mem.Arena

glyph :: struct
{
  UVScale  : math.v2,
  UVOffset : math.v2,
  Size     : math.v2,
  Offset   : math.v2,
  Advance  : f32,
}

// NOTE(fakhri): we assume mono spaced fonts only
font :: struct
{
  GlyphWidth    : f32,
  GlyphMapFirst : i32,
  GlyphMapOpl   : i32,
  LineAdvance   : f32,
  Ascent        : f32,
  Descent       : f32,
  AtlasTexture  : render.texture_id,
  PixelsData    : []u8,
  Glyphs        : []glyph,
}

LoadFont :: proc(Renderer :^render.renderer_context, FontPath :string, FontScale :f32) -> (Font :font, Ok :bool)
{
  using math;
  // NOTE(fakhri): constants
  AtlasSize  := V2i(1024, 1024);
  
  FontData := os.read_entire_file_from_filename(FontPath, context.temp_allocator) or_return;
  Pixels := make([]u8, AtlasSize.x * AtlasSize.y);
  defer if !Ok && Pixels != nil do delete(Pixels);
  assert(Pixels != nil);
  if Pixels == nil do return;
  
  // NOTE(fakhri): calculate basic metrics
  Ascent  := f32(0);
  Descent := f32(0);
  LineGap := f32(0);
  stbtt.GetScaledFontVMetrics(&FontData[0], 0, FontScale, &Ascent, &Descent, &LineGap);
  
  LineAdvance := Ascent - Descent + LineGap;
  
  DirectMapFirst := i32(' ');
  DirectMapOpl   := i32(128);
  
  Ctx :stbtt.pack_context;
  stbtt.PackBegin(&Ctx, &Pixels[0], AtlasSize.x, AtlasSize.y, 0, 1, nil);
  stbtt.PackSetOversampling(&Ctx, 1, 1);
  ChardataForRange := make([]stbtt.packedchar, DirectMapOpl-DirectMapFirst, context.temp_allocator);
  assert(ChardataForRange != nil);
  if ChardataForRange == nil do return;
  
  Rng := stbtt.pack_range {
    font_size = FontScale,
    first_unicode_codepoint_in_range = DirectMapFirst,
    array_of_unicode_codepoints = nil,
    num_chars = DirectMapOpl - DirectMapFirst,
    chardata_for_range = &ChardataForRange[0],
  }
  
  stbtt.PackFontRanges(&Ctx, &FontData[0], 0, &Rng, 1);
  stbtt.PackEnd(&Ctx);
  
  // NOTE(fakhri): build direct map
  Glyphs := make([]glyph, DirectMapOpl - DirectMapFirst);
  defer if !Ok && Glyphs != nil do delete(Glyphs);
  assert(Glyphs != nil);
  if Glyphs == nil do return;
  
  InvWidth  := 1.0 / f32(AtlasSize.x);
  InvHeight := 1.0 / f32(AtlasSize.y);
  
  Font.GlyphWidth = ChardataForRange[0].xadvance;
  
  for Glyph, Index in &Glyphs
  {
    OffsetX := f32(0);
    OffsetY := f32(0);
    
    s0 := f32(ChardataForRange[Index].x0) * InvWidth;
    t0 := f32(ChardataForRange[Index].y0) * InvHeight;
    s1 := f32(ChardataForRange[Index].x1) * InvWidth;
    t1 := f32(ChardataForRange[Index].y1) * InvHeight;
    
    Glyph.UVScale  = V2(abs(s1 - s0), abs(t1 - t0));
    Glyph.UVOffset = V2(s0, t0);
    Glyph.Size     = Glyph.UVScale * ToV2(AtlasSize);
    Glyph.Offset = V2(ChardataForRange[Index].xoff + 0.5 * Glyph.Size.x, ChardataForRange[Index].yoff2 - 0.5 * Glyph.Size.y);
    Glyph.Advance  = ChardataForRange[Index].xadvance;
    
    // TODO(fakhri): better recovery, like try a default monospaced font
    if Glyph.Advance != Font.GlyphWidth do panic("Mono spaced only");
  }
  
  Font.GlyphMapFirst = DirectMapFirst;
  Font.GlyphMapOpl   = DirectMapOpl;
  Font.Glyphs = Glyphs;
  Font.AtlasTexture = render.ReserveTexture2D(Renderer, ToV2u(AtlasSize), .R8);
  Font.LineAdvance = LineAdvance;
  Font.Ascent = Ascent;
  Font.Descent = Descent;
  Font.PixelsData = Pixels;
  render.FillTexture2D(Renderer, Font.AtlasTexture, ToV2u(AtlasSize), &Pixels[0]);
  Ok = true;
  
  return;
}

GetGlyphFromRune :: proc(Font :^font, Ch : rune) -> (Glyph : glyph)
{
  GlyphIndex := int(Ch) - int(Font.GlyphMapFirst);
  if GlyphIndex >= 0 && GlyphIndex < len(Font.Glyphs) do Glyph = Font.Glyphs[GlyphIndex];
  else
  {
    // TODO(fakhri): create a new glyph and bake it into the atlas
    Glyph = Font.Glyphs[' ' - Font.GlyphMapFirst];
  }
  return;
}

TextWidth :: proc(Font : ^font, Text : string) -> (Width : f32)
{
  for Ch in Text
  {
    Glyph := GetGlyphFromRune(Font, Ch);
    Width += Glyph.Advance;
  }
  return;
}