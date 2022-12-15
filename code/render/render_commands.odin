package editor_render

import "shared:base"
import math "shared:base/math"


commands_buffer :: struct
{
  Memory :[64 * base.Megabyte]byte,
  Offset :u32,
  
  ScreenDim : math.v2i,
  WhiteTexture : texture_id,
}

command_kind :: enum 
{
  ClearColor,
  TexturedRect,
  ClipMatrix,
};

command_header :: struct
{
  Kind : command_kind,
}

command_clear :: struct
{
  using Header : command_header,
  using Color : color_rgba,
}

/// the anchor is at center of the rectangle
command_rect :: struct
{
  using Header : command_header,
  Texture  : texture_id,
  Color    : color_rgba,
  P        : math.v2,
  Size     : math.v2,
  UVScale  : math.v2,
  UVOffset : math.v2,
}

command_clip_matrix :: struct
{
  using Header : command_header,
  Clip : math.m4x4,
}


GetCommandKindFromTypeID :: proc(type :typeid) -> (Kind :command_kind)
{
  switch type
  {
    case typeid_of(command_clip_matrix): Kind = .ClipMatrix;
    case typeid_of(command_rect): Kind = .TexturedRect;
    case typeid_of(command_clear): Kind = .ClearColor;
    case : assert(false, "missing type");
  }
  return;
}

PushCommand :: proc (using RenderCommands : ^commands_buffer, $type : typeid) -> (Result :^type)
{
  assert(Offset + size_of(type) < len(Memory));
  if Offset + size_of(type) < len(Memory)
  {
    Result = cast(^type)(&Memory[Offset]);
    Offset += size_of(type);
    Result.Kind = GetCommandKindFromTypeID(type);
  }
  return
}


PushClipMatrix :: proc(RenderCommands :^commands_buffer, Clip : math.m4x4)
{
  Command := PushCommand(RenderCommands, command_clip_matrix);
  Command.Clip = Clip;
}

PushClearColor_S :: proc(RenderCommands : ^commands_buffer, R, G, B, A :f32)
{
  ClearCommand := PushCommand(RenderCommands, command_clear);
  ClearCommand.Color = color_rgba{R, G, B, A};
}

PushClearColor_V :: proc(RenderCommands : ^commands_buffer, Color : color_rgba)
{
  PushClearColor_S(RenderCommands, Color.r, Color.g, Color.b, Color.a);
}

PushClearColor :: proc{PushClearColor_S, PushClearColor_V};




PushImage :: proc(RenderCommands : ^commands_buffer, 
                  P        : math.v2,
                  Size     : math.v2,
                  Texture  : texture_id,
                  Color    : color_rgba,
                  UVScale  := math.v2(1),
                  UVOffset := math.v2(0))
{
  Command := PushCommand(RenderCommands, command_rect);
  Command.Texture  = Texture;
  Command.Color    = Color;
  Command.P        = P;
  Command.Size     = Size;
  Command.UVScale  = UVScale;
  Command.UVOffset = UVOffset;
}

PushRect :: proc(RenderCommands : ^commands_buffer, 
                 P       :math.v2,
                 Size    :math.v2,
                 Color   :color_rgba,)
{
  PushImage(RenderCommands, P, Size, RenderCommands.WhiteTexture, Color);
}