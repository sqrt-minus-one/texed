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
  if (Msg == WM_CLOSE)
  {
    GlobalRequestClose = true;
  }
  return DefWindowProcW(HWnd, Msg, wParam, lParam);
}


ProcessPendingMessages :: proc()
{
  using win32;
  Msg :MSG;
  for PeekMessageW(&Msg, nil, 0, 0, PM_REMOVE)
  {
    switch Msg.message
    {
      case WM_QUIT: GlobalRequestClose = true;
      case:
      {
        TranslateMessage(&Msg);
        DispatchMessageW(&Msg);
      }
    }
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
    EditorCtx := new(ed.editor_context);
    
    for 
    {
      free_all(context.temp_allocator);
      ProcessPendingMessages();
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
      ed.UpdateAndRender(EditorCtx, Renderer);
      renderer.EndRendererFrame(Renderer);
      
    }
  }
}
