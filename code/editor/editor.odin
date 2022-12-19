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

text_position :: struct
{
  Row, Col : int,
}

cursor :: struct
{
  Offset :int,
  using Pos : text_position,
}

text_buffer :: struct
{
  Data : [512]u8,
  Size : int,
}

editor_context :: struct
{
  IsInitialized :bool,
  MainFont : font,
  Input  : editor_input,
  
  Buffer : text_buffer,
  // NOTE(fakhri): offset into the buffer
  Cursor : cursor,
}

AdjustCursorPos :: proc(Text : string, Cursor : ^cursor)
{
  SafeOffset := 0;
  SafePos, NextPos :text_position;
  for Ch, Index in Text
  {
    if SafePos.Col == Cursor.Col && SafePos.Row == Cursor.Row do break;
    if Ch == '\r' || Ch == '\n'
    {
      NextPos.Row += 1;
      NextPos.Col  = 0;
      if NextPos.Row > Cursor.Row do break;
    }
    else do NextPos.Col += TAB_WIDTH if Ch == '\t' else 1;
    SafePos = NextPos;
    SafeOffset = Index + 1;
  }
  
  Cursor.Pos    = SafePos;
  Cursor.Offset = SafeOffset;
}

MoveCursorRight :: proc(Text : string, Cursor : ^cursor)
{
  if Cursor.Offset < len(Text)
  {
    CharAtCursor := Text[Cursor.Offset];
    
    Cursor.Offset += 1;
    Cursor.Col += TAB_WIDTH if CharAtCursor == '\t' else 1;
    if CharAtCursor == '\r' || CharAtCursor == '\n'
    {
      Cursor.Col = 0;
      Cursor.Row += 1;
    }
  }
}

MoveCursorLeft :: proc(Text : string, Cursor : ^cursor)
{
  if Cursor.Offset > 0
  {
    CharBeforeCursor := Text[Cursor.Offset - 1];
    Cursor.Col -= TAB_WIDTH if CharBeforeCursor == '\t' else 1;
    Cursor.Offset -= 1;
    
    if Cursor.Col < 0
    {
      // TODO(fakhri): pick a safe big number
      Cursor.Col = 100_000;
      if Cursor.Row > 0 do Cursor.Row -= 1;
      AdjustCursorPos(Text, Cursor);
    }
  }
}

InsertCharaterToBuffer :: proc(Buffer : ^text_buffer, Offset : int, Char : u8)
{
  if Offset + 1 < len(Buffer.Data)
  {
    mem.copy(dst = &Buffer.Data[Offset + 1],
             src = &Buffer.Data[Offset],
             len = Buffer.Size - Offset); 
  }
  Buffer.Size += 1;
  Buffer.Data[Offset] = Char;
}

DeleteCharacterFromBuffer :: proc(Buffer : ^text_buffer, Offset : int)
{
  if Offset + 1 < len(Buffer.Data)
  {
    mem.copy(dst = &Buffer.Data[Offset],
             src = &Buffer.Data[Offset + 1],
             len = Buffer.Size - Offset); 
  }
  Buffer.Size -= 1;
}

UpdateAndRender :: proc(Editor :^editor_context, Renderer : ^render.renderer_context)
{
  if !Editor.IsInitialized
  {
    Editor.IsInitialized = true;
    
    Ok :bool;
    Editor.MainFont, Ok = LoadFont(Renderer, "data/fonts/consola.ttf", 20);
    if !Ok do logger.log(.Error, "Couldn't Load Font");
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
          if Editor.Buffer.Size < len(Editor.Buffer.Data)
          {
            InsertCharaterToBuffer(&Editor.Buffer, Editor.Cursor.Offset, u8(Event.Char));
            MoveCursorRight(string(Editor.Buffer.Data[:Editor.Buffer.Size]), &Editor.Cursor);
          }
        }
        case .KeyPress:
        {
#partial switch Event.Key
          {
            case .Key_Backspace:
            {
              if Editor.Buffer.Size > 0 && Editor.Cursor.Offset > 0
              {
                MoveCursorLeft(string(Editor.Buffer.Data[:Editor.Buffer.Size]), &Editor.Cursor);
                DeleteCharacterFromBuffer(&Editor.Buffer, Editor.Cursor.Offset);
              }
            }
            case .Key_Up:
            {
              if Editor.Cursor.Row > 0 do Editor.Cursor.Row -= 1;
              AdjustCursorPos(string(Editor.Buffer.Data[:Editor.Buffer.Size]), &Editor.Cursor);
            }
            case .Key_Down:
            {
              Editor.Cursor.Row += 1;
              AdjustCursorPos(string(Editor.Buffer.Data[:Editor.Buffer.Size]), &Editor.Cursor);
            }
            case .Key_Right:
            {
              MoveCursorRight(string(Editor.Buffer.Data[:Editor.Buffer.Size]), &Editor.Cursor)
            }
            case .Key_Left:
            {
              MoveCursorLeft(string(Editor.Buffer.Data[:Editor.Buffer.Size]), &Editor.Cursor)
            }
            case .Key_LeftMouse:
            {
              Editor.Cursor.Col = int(Event.MouseP.x / Font.GlyphWidth);
              Editor.Cursor.Row = int(Event.MouseP.y / Font.LineAdvance);
              AdjustCursorPos(string(Editor.Buffer.Data[:Editor.Buffer.Size]), &Editor.Cursor);
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
             string(Editor.Buffer.Data[:Editor.Buffer.Size]), 
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
    
    if Editor.Cursor.Offset < Editor.Buffer.Size 
    {
      CharPos := math.V2((f32(Pos.Col)) * Font.GlyphWidth, (f32(Pos.Row) + 0.5) * Font.LineAdvance + LineGap);
      CharAtCursor := Editor.Buffer.Data[Editor.Cursor.Offset];
      RenderCharacter(Renderer, Font, rune(CharAtCursor), CharPos, render.MakeColor(0, 0, 0, 1));
    }
  }
}
