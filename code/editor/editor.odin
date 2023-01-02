package editor

import logger "core:log"
import "core:fmt"
import "core:mem"
import "shared:render"
import math "shared:base/math"

/*
 ** TODO(fakhri): things to think about:
**  - handle TABs
**  - scrolling
**  - better cr/lf handling
**  - better buffer rendering
**  - history
*/

buffer_position :: struct
{
  Row, Col : int,
}

editor_context :: struct
{
  IsInitialized :bool,
  MainFont : font,
  Input  : editor_input,
  Buffer : ^text_buffer,
  FreeChunks :^buffer_chunk,
}

UpdateAndRender :: proc(Editor :^editor_context, Renderer : ^render.renderer_context)
{
  if !Editor.IsInitialized
  {
    Editor.IsInitialized = true;
    
    Ok :bool;
    Editor.MainFont, Ok = LoadFont(Renderer, "data/fonts/consola.ttf", 14);
    if !Ok do logger.log(.Error, "Couldn't Load Font");
    Editor.Buffer, Ok = LoadBufferFromDisk(Editor, "test.c");
    assert(Ok)
  }
  
  Font := &Editor.MainFont;
  Buffer := Editor.Buffer;
  // NOTE(fakhri): process input events
  {
    for Event := Editor.Input.First; Event != nil; Event = Event.Next
    {
      switch Event.Kind
      {
        case .Text:
        {
          InsertCharaterToBuffer(Editor, Buffer, u8(Event.Char));
        }
        case .KeyPress:
        {
#partial switch Event.Key
          {
            case .Key_Backspace:
            {
              DeleteCharacterFromBuffer(Editor, Buffer);
            }
            case .Key_Up:
            {
              MoveCursorUp(Buffer);
            }
            case .Key_Down:
            {
              MoveCursorDown(Buffer);
            }
            case .Key_Right:
            {
              MoveCursorRight(Buffer)
            }
            case .Key_Left:
            {
              MoveCursorLeft(Buffer)
            }
            case .Key_LeftMouse:
            {
              Col := int(Event.MouseP.x / Font.GlyphWidth);
              Row := int(Event.MouseP.y / Font.LineAdvance);
              Buffer.Cursor = OffsetFromRowCol(Buffer, Row, Col);
            }
            case .Key_Esc:
            {
              SaveBufferToDisk(Editor, Buffer);
            }
          }
        }
        case .KeyRelease:
      }
    }
  }
  
  render.PushClearColor(Renderer, 0, 0, 0, 1);
  
  Width  := f32(Renderer.ScreenDim.x);
  Height := f32(Renderer.ScreenDim.y);
  render.PushClipMatrix(Renderer, math.Orthographic(0, Width, Height, 0, -100, 100));
  
  // NOTE(fakhri): render buffer content
  P := math.V2(0, 0);
  RenderBuffer(Renderer,
               Font,
               Buffer, 
               math.ToV2u(P),
               render.MakeColor(1));
  
  // NOTE(fakhri): render cursor
  {
    LineGap := Font.LineAdvance - (Font.Ascent - Font.Descent);
    Pos := GetBufferPos(Buffer, Buffer.Cursor);
    CursorPos := math.V2((f32(Pos.Col) + 0.5) * Font.GlyphWidth, (f32(Pos.Row) + 0.5) * Font.LineAdvance - LineGap);
    render.PushRect(RenderCommands = Renderer, 
                    P  = CursorPos,
                    Size = math.V2(Font.GlyphWidth, Font.Ascent - Font.Descent),
                    Color = render.MakeColor(1));
    
    if Buffer.Cursor < Buffer.Size 
    {
      ChunkOffset := GetBufferOffsetFromCursor(Buffer);
      Chunk  := ChunkOffset.Chunk;
      Offset := ChunkOffset.Offset;
      
      CharPos := math.V2((f32(Pos.Col)) * Font.GlyphWidth, (f32(Pos.Row) + 0.5) * Font.LineAdvance + LineGap);
      CharAtCursor := Chunk.Data[Offset];
      RenderCharacter(Renderer, Font, rune(CharAtCursor), CharPos, render.MakeColor(0, 0, 0, 1));
    }
  }
}
