package editor_render

import "core:mem"
import "shared:base/math"

renderer_context :: struct
{
  using RenderCommands : commands_buffer,
  allocator : mem.Allocator,
}

color_rgba :: [4]f32
texture_id :: distinct u32

texture_format_2d :: enum
{
  R8,
  RGB8,
  RGBA8,
}

InitRenderer :: proc(Renderer : ^renderer_context, allocator :mem.Allocator)
{
  Renderer.allocator = allocator;
}

MakeColor_RGBA :: proc(r, g, b, a :f32) -> (Color :color_rgba)
{
  Color = color_rgba{r, g, b, a};
  return;
}

MakeColor_C :: proc(c :f32) -> (Color :color_rgba)
{
  Color = color_rgba{c, c, c, c};
  return;
}

MakeColor :: proc{MakeColor_RGBA, MakeColor_C};


// NOTE(fakhri): renderer api specific procedures
ReserveTexture2D := ReserveTexture2D_Stub;
FillTexture2D    := FillTexture2D_Stub;

ReserveTexture2D_Stub :: proc(Renderer :^renderer_context, Size :math.v2u, Format :texture_format_2d) -> texture_id
{
  return 0;
}

FillTexture2D_Stub :: proc(Renderer :^renderer_context, TextureID :texture_id, Size :math.v2u, Data :rawptr) {}
