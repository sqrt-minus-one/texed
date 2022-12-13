// +build windows
package editor_render_gl

import win32 "core:sys/windows"
import "shared:render"
import "shared:base/math"


BeginRendererFrame :: proc (Renderer :^render.renderer_context, ScreenDim :math.v2i)
{
  WGL_Context := cast(^wgl_context)Renderer;
  
  // TODO(fakhri): do windows begin frame things
  
  BeginFrame(WGL_Context, ScreenDim);
}


EndRendererFrame :: proc (Renderer :^render.renderer_context)
{
  WGL_Context := cast(^wgl_context)Renderer;
  EndFrame(WGL_Context);
  win32.SwapBuffers(WGL_Context.DeviceContext);
}
