package editor

import logger "core:log"
import "core:fmt"
import "core:mem"
import "shared:render"
import math "shared:base/math"

/*
 ** TODO(fakhri): things to think about:
**  - handle big buffers
**  - save/load buffers
**  - history
**  - scrolling
*/

screen_position :: struct
{
  Row, Col : int,
}

editor_context :: struct
{
  IsInitialized :bool,
  MainFont : font,
  Input  : editor_input,
  Allocator : mem.Allocator,
  
  Buffer : buffer_chunk,
  Cursor : cursor,
}

UpdateAndRender :: proc(Editor :^editor_context, Renderer : ^render.renderer_context)
{
  if !Editor.IsInitialized
  {
    Editor.IsInitialized = true;
    
    Ok :bool;
    Editor.MainFont, Ok = LoadFont(Renderer, "data/fonts/consola.ttf", 20);
    if !Ok do logger.log(.Error, "Couldn't Load Font");
    Editor.Cursor.ChunkOffset.Offset = 0;
    Editor.Cursor.ChunkOffset.Chunk = &Editor.Buffer;
  }
  
  Font := &Editor.MainFont;
  
  // NOTE(fakhri): process input events
  {
    for Event := Editor.Input.First; Event != nil; Event = Event.Next
    {
      switch Event.Kind
      {
        case .Text:
        {
          InsertCharaterToBuffer(Editor, &Editor.Cursor, u8(Event.Char));
        }
        case .KeyPress:
        {
#partial switch Event.Key
          {
            case .Key_Backspace:
            {
              DeleteCharacterFromBuffer(Editor, &Editor.Cursor);
            }
            case .Key_Up:
            {
              if Editor.Cursor.Row > 0 do Editor.Cursor.Row -= 1;
              AdjustCursorPos(string(Editor.Buffer.Data[:Editor.Buffer.UsedSpace]), &Editor.Cursor);
            }
            case .Key_Down:
            {
              Editor.Cursor.Row += 1;
              AdjustCursorPos(string(Editor.Buffer.Data[:Editor.Buffer.UsedSpace]), &Editor.Cursor);
            }
            case .Key_Right:
            {
              MoveCursorRight(string(Editor.Buffer.Data[:Editor.Buffer.UsedSpace]), &Editor.Cursor)
            }
            case .Key_Left:
            {
              MoveCursorLeft(string(Editor.Buffer.Data[:Editor.Buffer.UsedSpace]), &Editor.Cursor)
            }
            case .Key_LeftMouse:
            {
              Editor.Cursor.Col = int(Event.MouseP.x / Font.GlyphWidth);
              Editor.Cursor.Row = int(Event.MouseP.y / Font.LineAdvance);
              AdjustCursorPos(string(Editor.Buffer.Data[:Editor.Buffer.UsedSpace]), &Editor.Cursor);
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
  RenderText(Renderer,
             Font,
             string(Editor.Buffer.Data[:Editor.Buffer.UsedSpace]), 
             math.ToV2u(P),
             render.MakeColor(1));
  
  // NOTE(fakhri): render cursor
  {
    LineGap := Font.LineAdvance - (Font.Ascent - Font.Descent);
    Pos := Editor.Cursor.Pos;
    CursorPos := math.V2((f32(Pos.Col) + 0.5) * Font.GlyphWidth, (f32(Pos.Row) + 0.5) * Font.LineAdvance - LineGap);
    render.PushRect(RenderCommands = Renderer, 
                    P  = CursorPos,
                    Size = math.V2(Font.GlyphWidth, Font.Ascent - Font.Descent),
                    Color = render.MakeColor(1));
    
    if Editor.Cursor.ChunkOffset.Offset < Editor.Buffer.UsedSpace 
    {
      CharPos := math.V2((f32(Pos.Col)) * Font.GlyphWidth, (f32(Pos.Row) + 0.5) * Font.LineAdvance + LineGap);
      CharAtCursor := Editor.Buffer.Data[Editor.Cursor.ChunkOffset.Offset];
      RenderCharacter(Renderer, Font, rune(CharAtCursor), CharPos, render.MakeColor(0, 0, 0, 1));
    }
  }
}
