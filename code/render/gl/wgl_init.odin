// +build windows
package editor_render_gl

import "shared:render"
import "core:mem"
import win32 "core:sys/windows"
import gl "vendor:OpenGL"
import "core:intrinsics"
import libc "core:c/libc"

const_utf16 :: intrinsics.constant_utf16_cstring
GL_EDITOR_VERSION_MAJOR :: 3
GL_EDITOR_VERSION_MINOR :: 3

wgl_context :: struct 
{
  using GL : gl_context,
  DeviceContext: win32.HDC,
}

OpenglDLL :win32.HMODULE;
wglChoosePixelFormatARB    :win32.ChoosePixelFormatARBType;
wglCreateContextAttribsARB :win32.CreateContextAttribsARBType;
wglSwapIntervalEXT         :win32.SwapIntervalEXTType;


MakeRenderer :: proc(Instance: win32.HINSTANCE, DeviceContext: win32.HDC, allocator : mem.Allocator) -> (Result :^render.renderer_context)
{
  if !InitOpenGL(Instance, DeviceContext) do panic("couldn't init opengl");
  OpenglDLL = win32.LoadLibraryW(const_utf16("opengl32.dll"));
  defer if OpenglDLL != nil do win32.FreeLibrary(OpenglDLL);
  gl.load_up_to(GL_EDITOR_VERSION_MAJOR, GL_EDITOR_VERSION_MINOR, LoadOpenglProc);
  
  WGL_Context := new(wgl_context, allocator);
  InitGL(WGL_Context, allocator);
  
  WGL_Context.DeviceContext = DeviceContext;
  Result = WGL_Context;
  return;
}

LoadOpenglProc :: proc(p: rawptr, name: cstring) 
{
  Addr := win32.wglGetProcAddress(name);
  if Addr == nil || cast(uintptr)Addr == 0x1 || cast(uintptr)p == 0x2 || cast(uintptr)p == 0x3 || cast(uintptr)p == cast(uintptr)libc.SIZE_MAX
  {
    Addr = nil;
  }
  if Addr == nil
  {
    Addr = win32.GetProcAddress(OpenglDLL, name);
  }
  (cast(^rawptr)p)^ = Addr;
}


LoadWGLFunctions :: proc()
{
  using win32;
  wglChoosePixelFormatARB    = cast(ChoosePixelFormatARBType)wglGetProcAddress("wglChoosePixelFormatARB");
  wglCreateContextAttribsARB = cast(CreateContextAttribsARBType)wglGetProcAddress("wglCreateContextAttribsARB");
  wglSwapIntervalEXT         = cast(SwapIntervalEXTType)wglGetProcAddress("wglSwapIntervalEXT");
}


InitOpenGL :: proc(Instance: win32.HINSTANCE, DeviceContext: win32.HDC) -> (Ok : bool)
{
  using win32;
  //- NOTE(fakhri): make global invisible window
  DummyHWND := CreateWindowExW(dwExStyle = {},
                               lpClassName = const_utf16("STATIC"),
                               lpWindowName = const_utf16(""),
                               dwStyle = WS_OVERLAPPEDWINDOW,
                               X = CW_USEDEFAULT,
                               Y = CW_USEDEFAULT,
                               nWidth  = 100,
                               nHeight = 100,
                               hWndParent = nil,
                               hMenu = nil,
                               lpParam = nil,
                               hInstance = Instance,
                               );
  assert(DummyHWND != nil);
  defer DestroyWindow(DummyHWND);
  
  DummyHDC := GetDC(DummyHWND);
  defer ReleaseDC(DummyHWND, DummyHDC);
  
  //- NOTE(fakhri): make dummy context
  DummyGLContext :HGLRC;
  DummyPixelFormat :c_int;
  {
    PFD := PIXELFORMATDESCRIPTOR {
      nSize           = size_of(PIXELFORMATDESCRIPTOR),
      nVersion        = 1,
      dwFlags         = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
      iPixelType      = PFD_TYPE_RGBA,
      cColorBits      = 32,
      cDepthBits      = 24,
      cStencilBits    = 8,
      iLayerType      = PFD_MAIN_PLANE,
    };
    
    DummyPixelFormat := ChoosePixelFormat(DummyHDC, &PFD) ;
    if DummyPixelFormat == 0 do return;
    
    SetPixelFormat(DummyHDC, DummyPixelFormat, &PFD);
    DummyGLContext = wglCreateContext(DummyHDC);
    defer wglDeleteContext(DummyGLContext);;
    
    wglMakeCurrent(DummyHDC, DummyGLContext);
    LoadWGLFunctions();
    wglMakeCurrent(nil, nil);
  }
  
  //- NOTE(fakhri): setup real pixel format
  PixelFormat :c_int;
  PixelFormatDescriptor :=PIXELFORMATDESCRIPTOR{nSize = size_of(PIXELFORMATDESCRIPTOR)};
  {
    PixelFormatAttributes := [?]c_int{
      WGL_DRAW_TO_WINDOW_ARB, 1,
      WGL_SUPPORT_OPENGL_ARB, 1,
      WGL_DOUBLE_BUFFER_ARB,  1,
      WGL_PIXEL_TYPE_ARB, WGL_TYPE_RGBA_ARB,
      WGL_ACCELERATION_ARB, WGL_FULL_ACCELERATION_ARB,
      WGL_COLOR_BITS_ARB, 24,
      WGL_DEPTH_BITS_ARB, 24,
      WGL_STENCIL_BITS_ARB, 8,
      WGL_SAMPLE_BUFFERS_ARB, 1,
      WGL_SAMPLES_ARB, 4,
      0,
    };
    
    FormatsCount :UINT;
    wglChoosePixelFormatARB(DeviceContext, &PixelFormatAttributes[0], nil, 1, &PixelFormat, &FormatsCount);
    SetPixelFormat(DeviceContext, PixelFormat, &PixelFormatDescriptor);
  }
  
  GLCtx :HGLRC;
  //- NOTE(fakhri): initialize real context
  {
    ContextAttribs := [?]c_int{
      WGL_CONTEXT_MAJOR_VERSION_ARB, GL_EDITOR_VERSION_MAJOR,
      WGL_CONTEXT_MINOR_VERSION_ARB, GL_EDITOR_VERSION_MINOR,
      WGL_CONTEXT_PROFILE_MASK_ARB,  WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
      WGL_CONTEXT_FLAGS_ARB,         WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB | WGL_CONTEXT_DEBUG_BIT_ARB,
      0,
    };
    
    GLCtx = wglCreateContextAttribsARB(DeviceContext, nil, &ContextAttribs[0]);
    
    if GLCtx != nil
    {
      Ok = true;
      wglMakeCurrent(DeviceContext, GLCtx);
      wglSwapIntervalEXT(1);
      SetPixelFormat(DeviceContext, PixelFormat, &PixelFormatDescriptor);
    }
  }
  
  return;
}
