package editor

import logger "core:log"
import "core:fmt"
import "core:mem"
import "shared:render"
import math "shared:base/math"

/*
 ** TODO(fakhri): things to think about:
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
  IsInitialized: bool,
  MainFont:    font,
  Input:       editor_input,
  Buffer:     ^text_buffer,
  Time: f32,
}

UpdateAndRender :: proc(Editor: ^editor_context, Renderer: ^render.renderer_context, dtForFrame: f32)
{
  if !Editor.IsInitialized
  {
    Editor.IsInitialized = true;
    
    Ok :bool;
    Editor.MainFont, Ok = LoadFont(Renderer, "data/fonts/consola.ttf", 40);
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
  
  Editor.Time += dtForFrame;
  
  // NOTE(fakhri): try to keep the camera following the cursor
  {
    VisibleLinesCount := Height / Font.LineAdvance;
    
    CursorPos := GetBufferPos(Buffer, Buffer.Cursor);
    Edge := Buffer.Camera.TargetP.y + VisibleLinesCount / 2;
    if Edge < f32(CursorPos.Row)
    {
      Buffer.Camera.TargetP.y = f32(CursorPos.Row - 5);
    }
    
    if f32(CursorPos.Row) < Buffer.Camera.TargetP.y
    {
      Buffer.Camera.TargetP.y = f32(CursorPos.Row);
    }
    UpdateCamera(&Buffer.Camera, dtForFrame);
  }
  
  CameraP := Buffer.Camera.P;
  CameraP.y *= -Font.LineAdvance;
  Clip := GetClipMatrix(CameraP, Width, Height);
  render.PushClipMatrix(Renderer, Clip);
  
  // NOTE(fakhri): render buffer content
  P := math.V2(0, 0);
  RenderBuffer(Renderer,
               Font,
               Buffer, 
               math.ToV2u(P),
               render.MakeColor(1));
  
}
