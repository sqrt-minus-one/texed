package main

import "core:fmt"
import "core:mem"
import virt "core:mem/virtual"
import "core:os"
import "core:runtime"
import "core:intrinsics"
import win32 "core:sys/windows"
import "shared:base"
import "shared:base/math"
import ed "shared:editor"

import renderer "shared:render/gl"

const_utf16 :: intrinsics.constant_utf16_cstring
GlobalRequestClose :bool;

WindowCallback :: proc "stdcall" (HWnd :win32.HWND, Msg :win32.UINT, wParam :win32.WPARAM, lParam :win32.LPARAM) -> win32.LRESULT
{
  using win32;
  switch Msg
  {
    case WM_CLOSE:
    {
      GlobalRequestClose = true;
    }
  }
  return DefWindowProcW(HWnd, Msg, wParam, lParam);
}

Win32ResolveVKCode :: proc(VK : win32.WPARAM) -> (Result : ed.key)
{
  using win32;
  switch VK
  {
    case VK_ESCAPE : Result = .Key_Esc;
    case VK_F1..=VK_F24 : Result = .Key_F1 + ed.key(VK - VK_F1);
    case VK_OEM_3 : Result = .Key_GraveAccent;
    case '0'..='9' : Result = .Key_0 + ed.key(VK - '0');
    case VK_OEM_MINUS : Result = .Key_Minus;
    case VK_OEM_PLUS : Result = .Key_Plus;
    case VK_BACK : Result = .Key_Backspace;
    case VK_DELETE : Result = .Key_Delete;
    case VK_TAB : Result = .Key_Tab;
    case 'A' : Result = .Key_A + ed.key(VK - 'A');
    case VK_SPACE : Result = .Key_Space;
    case VK_RETURN : Result = .Key_Enter;
    case VK_CONTROL : Result = .Key_Ctrl;
    case VK_SHIFT : Result = .Key_Shift;
    case VK_MENU : Result = .Key_Alt;
    case VK_UP : Result = .Key_Up;
    case VK_LEFT : Result = .Key_Left;
    case VK_DOWN : Result = .Key_Down;
    case VK_RIGHT : Result = .Key_Right;
    case VK_PRIOR : Result = .Key_PageUp;
    case VK_NEXT : Result = .Key_PageDown;
    case VK_HOME : Result = .Key_Home;
    case VK_END : Result = .Key_End;
    case VK_OEM_2 : Result = .Key_ForwardSlash;
    case VK_OEM_PERIOD : Result = .Key_Period;
    case VK_OEM_COMMA : Result = .Key_Comma;
    case VK_OEM_7 : Result = .Key_Quote;
    case VK_OEM_4 : Result = .Key_LeftBracket;
    case VK_OEM_6 : Result = .Key_RightBracket;
  }
  return;
}


ProcessPendingMessages :: proc(Input :^ed.editor_input, Allocator :mem.Allocator = context.allocator)
{
  using win32;
  Msg :MSG;
  for PeekMessageW(&Msg, nil, 0, 0, PM_REMOVE)
  {
    Event :^ed.input_event;
    
    switch Msg.message
    {
      case WM_QUIT: GlobalRequestClose = true;
      case WM_MOUSEMOVE: Input.Mouse = math.V2(f32(GET_X_LPARAM(Msg.lParam)), f32(GET_Y_LPARAM(Msg.lParam)));
      case WM_LBUTTONUP, WM_LBUTTONDOWN:
      {
        Event = ed.MakeInputEvent(Input, Allocator);
        Event.Kind = .KeyPress if WM_LBUTTONDOWN == Msg.message else .KeyRelease;
        Event.Key = .Key_LeftMouse;
        Event.MouseP = Input.Mouse;
      }
      case WM_RBUTTONUP, WM_RBUTTONDOWN:
      {
        Event = ed.MakeInputEvent(Input, Allocator);
        Event.Kind = .KeyPress if WM_RBUTTONDOWN == Msg.message else .KeyRelease;
        Event.Key = .Key_RightMouse;
        Event.MouseP = Input.Mouse;
      }
      case WM_MBUTTONUP, WM_MBUTTONDOWN:
      {
        Event = ed.MakeInputEvent(Input, Allocator);
        Event.Kind = .KeyPress if WM_MBUTTONDOWN == Msg.message else .KeyRelease;
        Event.Key = .Key_RightMouse;
        Event.MouseP = Input.Mouse;
      }
      case WM_KEYDOWN, WM_KEYUP:
      {
        IsDown :=  (Msg.lParam & (1 << 31)) == 0;
        WasDown := (Msg.lParam & (1 << 30)) != 0;
        Event = ed.MakeInputEvent(Input, Allocator);
        
        Event.Kind = .KeyPress if IsDown  else .KeyRelease;
        Event.Key = Win32ResolveVKCode(Msg.wParam);
      }
      
      case WM_CHAR, WM_SYSCHAR:
      {
        CharInput := rune(Msg.wParam);
        
        if (CharInput >= 32 && CharInput != 127) || CharInput == '\t' || CharInput == '\n' || CharInput == '\r'
        {
          Event = ed.MakeInputEvent(Input, Allocator);
          Event.Kind = .Text;
          Event.Char = CharInput;
        }
      }
    }
    
    if Event != nil
    {
      if (u16(GetKeyState(VK_CONTROL)) & u16(0x8000)) != 0
      {
        incl(&Event.Modifiers, ed.key_modifier.Ctrl);
      }
      if (u16(GetKeyState(VK_SHIFT)) & u16(0x8000)) != 0
      {
        incl(&Event.Modifiers, ed.key_modifier.Shift);
      }
      if (u16(GetKeyState(VK_MENU)) & u16(0x8000)) != 0
      {
        incl(&Event.Modifiers, ed.key_modifier.Alt);
      }
      ed.PushEvent(Input, Event);
    }
    
    TranslateMessage(&Msg);
    DispatchMessageW(&Msg);
  }
}

main:: proc()
{
  PermanantArena :virt.Arena;
  if virt.arena_init_growing(&PermanantArena, 128 * base.Megabyte) != .None
  {
    // TODO(fakhri): Log issue
    os.exit(1);
  }
  
  context.allocator = virt.arena_allocator(&PermanantArena);
  
  using win32;
  // -- Create a window -- //
  // call this to get the current instance
  Instance := cast(HINSTANCE)(GetModuleHandleW(nil));
  assert(Instance != nil);
  
  // windows so nice you have to do this to get the actual size you want
  // paid OS btw
  _dummy_rect := RECT{
    left = 0, top = 0,
    right = 1280, bottom = 720,
  }
  
  AdjustWindowRectEx(&_dummy_rect, WS_OVERLAPPEDWINDOW, true, 0);
  window_width  := _dummy_rect.right - _dummy_rect.left;
  window_height := _dummy_rect.bottom - _dummy_rect.top;
  
  window_class := WNDCLASSW {
    style = CS_HREDRAW | CS_OWNDC,
    lpfnWndProc = WindowCallback,
    hInstance = Instance,
    lpszClassName = const_utf16("EDITOR_CLASS"),
    hCursor = LoadCursorA(nil, IDC_ARROW),
  }
  
  if RegisterClassW(&window_class) != 0
  {
    WindowHandle := CreateWindowExW(dwExStyle = {},
                                    lpClassName = window_class.lpszClassName,
                                    lpWindowName = const_utf16("Editor"),
                                    dwStyle = WS_OVERLAPPEDWINDOW,
                                    X = CW_USEDEFAULT,
                                    Y = CW_USEDEFAULT,
                                    nWidth  = window_width,
                                    nHeight = window_height,
                                    hWndParent = nil,
                                    hMenu = nil,
                                    lpParam = nil,
                                    hInstance = Instance,
                                    );
    assert(WindowHandle != nil);
    defer DestroyWindow(WindowHandle);
    
    WindowDC := GetDC(WindowHandle);
    defer ReleaseDC(WindowHandle, WindowDC);
    
    Renderer := renderer.MakeRenderer(Instance, WindowDC, context.allocator);
    ShowWindow(WindowHandle, 1);
    EdCtx := new(ed.editor_context);
    
    for 
    {
      free_all(context.temp_allocator);
      ProcessPendingMessages(&EdCtx.Input);
      if GlobalRequestClose
      {
        break;
      }
      
      ScreenDim :math.v2i;
      
      // NOTE(fakhri): Update window size
      {
        ClientRect :RECT;
        GetClientRect(WindowHandle, &ClientRect);
        ScreenDim.x  = ClientRect.right - ClientRect.left;
        ScreenDim.y = ClientRect.bottom - ClientRect.top;
      }
      
      renderer.BeginRendererFrame(Renderer, ScreenDim);
      ed.UpdateAndRender(EdCtx, Renderer);
      renderer.EndRendererFrame(Renderer);
      
      ed.ClearAllEvents(&EdCtx.Input);
    }
  }
}
