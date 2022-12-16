package editor

import "core:mem"
import "shared:base/math"

input_event_kind :: enum
{
  KeyPress,
  KeyRelease,
  Text,
}

key :: enum 
{
  Key_Uknown,
  Key_Esc,
  Key_F1,
  Key_F2,
  Key_F3,
  Key_F4,
  Key_F5,
  Key_F6,
  Key_F7,
  Key_F8,
  Key_F9,
  Key_F10,
  Key_F11,
  Key_F12,
  Key_F13,
  Key_F14,
  Key_F15,
  Key_F16,
  Key_F17,
  Key_F18,
  Key_F19,
  Key_F20,
  Key_F21,
  Key_F22,
  Key_F23,
  Key_F24,
  Key_GraveAccent,
  Key_0,
  Key_1,
  Key_2,
  Key_3,
  Key_4,
  Key_5,
  Key_6,
  Key_7,
  Key_8,
  Key_9,
  Key_Minus,
  Key_Plus,
  Key_Backspace,
  Key_Delete,
  Key_Tab,
  Key_A,
  Key_B,
  Key_C,
  Key_D,
  Key_E,
  Key_F,
  Key_G,
  Key_H,
  Key_I,
  Key_J,
  Key_K,
  Key_L,
  Key_M,
  Key_N,
  Key_O,
  Key_P,
  Key_Q,
  Key_R,
  Key_S,
  Key_T,
  Key_U,
  Key_V,
  Key_W,
  Key_X,
  Key_Y,
  Key_Z,
  Key_Space,
  Key_Enter,
  Key_Ctrl,
  Key_Shift,
  Key_Alt,
  Key_Up,
  Key_Left,
  Key_Down,
  Key_Right,
  Key_PageUp,
  Key_PageDown,
  Key_Home,
  Key_End,
  Key_ForwardSlash,
  Key_Period,
  Key_Comma,
  Key_Quote,
  Key_LeftBracket,
  Key_RightBracket,
  
  Key_LeftMouse,
  Key_MiddleMouse,
  Key_RightMouse,
}

key_modifier :: enum
{
  Ctrl,
  Shift,
  Alt,
}

input_event :: struct
{
  Next : ^input_event,
  Kind : input_event_kind,
  Key  : key,
  Char : rune,
  Modifiers :bit_set[key_modifier],
  MouseP : math.v2,
}

editor_input :: struct
{
  First : ^input_event,
  Last  : ^input_event,
  Free  : ^input_event,
  Mouse : math.v2,
}

MakeInputEvent :: proc(Input :^editor_input, Allocator :mem.Allocator) -> (Result : ^input_event)
{
  if Input.Free != nil
  {
    Result = Input.Free;
    Input.Free = Input.Free.Next;
  }
  
  if Result == nil
  {
    Result = new(input_event, Allocator);
  }
  
  if Result != nil
  {
    Result^ = input_event{};
  }
  
  return;
}

PushEvent :: proc(Input :^editor_input, Event :^input_event)
{
  if Input.First == nil
  {
    Input.First = Event;
    Input.Last  = Event;
  }
  else
  {
    assert(Input.Last != nil);
    Input.Last.Next = Event;
    Input.Last = Event;
  }
}

ClearAllEvents :: proc(Input :^editor_input)
{
  if Input.First != nil
  {
    assert(Input.Last != nil);
    Input.Last.Next = Input.Free;
    Input.Free = Input.First;
    
    Input.First = nil;
    Input.Last = nil;
  }
}