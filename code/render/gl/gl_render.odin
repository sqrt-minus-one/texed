package editor_render_gl

import "shared:render"
import gl "vendor:OpenGL"
import "core:mem"
import "shared:base/math"

MAX_TEXTURE_COUNT :: 65536

gl_context :: struct
{
  using Renderer: render.renderer_context,
  Textures :[MAX_TEXTURE_COUNT]gl_texture_2d,
  TexturesCount :u32,
  RectShaderProgram : rect_shader,
}

InitGL :: proc(GLContext : ^gl_context, allocator :mem.Allocator)
{
  LoadShaders(GLContext);
  // NOTE(fakhri): texture 0 is reserved
  GLContext.TexturesCount = 1;
  render.ReserveTexture2D = ReserveTexture2D;
  render.FillTexture2D    = FillTexture2D;
  render.InitRenderer(GLContext, allocator);
  
  TextureSize := math.v2u{1, 1};
  WhiteColor :u32= 0xFF_FF_FF_FF;
  GLContext.RenderCommands.WhiteTexture = ReserveTexture2D(GLContext, TextureSize, .RGB8);
  FillTexture2D(GLContext, GLContext.RenderCommands.WhiteTexture, TextureSize, &WhiteColor);
}

BeginFrame :: proc(GLContext : ^gl_context, ScreenDim :math.v2i)
{
  GLContext.ScreenDim = ScreenDim;
  GLContext.Offset = 0;
}

EndFrame :: proc(GLContext : ^gl_context)
{
  using render;
  RenderCommands := &GLContext.RenderCommands;
  
  gl.Enable(gl.BLEND);
  gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
  gl.ClearColor(1, 0, 1, 1);
  gl.Clear(gl.COLOR_BUFFER_BIT);
  
  gl.Viewport(x = 0, y = 0, width = RenderCommands.ScreenDim.x, height = RenderCommands.ScreenDim.y);
  
  HeaderOffset :u32; 
  Clip := math.M4x4_IDENTITY;
  for HeaderOffset < RenderCommands.Offset
  {
    Header := cast(^command_header)(&RenderCommands.Memory[HeaderOffset]);
    // NOTE(fakhri): update HeaderOffset
    switch Header.Kind
    {
      case .ClearColor:   HeaderOffset += size_of(command_clear);
      case .TexturedRect: HeaderOffset += size_of(command_rect);
      case .ClipMatrix:   HeaderOffset += size_of(command_clip_matrix);
    }
    
    // NOTE(fakhri): execute command
    switch Header.Kind
    {
      case .ClearColor:
      {
        ClearCommand := cast(^command_clear)Header;
        gl.ClearColor(ClearCommand.r, ClearCommand.g, ClearCommand.b, ClearCommand.a);
        gl.Clear(gl.COLOR_BUFFER_BIT);
      }
      case .ClipMatrix:
      {
        Command := cast(^command_clip_matrix)Header;
        Clip = Command.Clip;
      }
      case .TexturedRect:
      {
        Command := cast(^command_rect)Header;
        
        TransM := math.Translate(math.V3(Command.P.x, Command.P.y, 0.0));
        ScaleM := math.Scale(math.V3(Command.Size.x, Command.Size.y, 0.0));
        Model := TransM * ScaleM;
        
        using GLContext;
        gl.UseProgram(RectShaderProgram.ID);
        
        gl.UniformMatrix4fv(gl.GetUniformLocation(RectShaderProgram.ID, "Clip"),  1, gl.FALSE, cast(^f32)&Clip);
        gl.UniformMatrix4fv(gl.GetUniformLocation(RectShaderProgram.ID, "Model"), 1, gl.FALSE, cast(^f32)&Model);
        gl.Uniform2f(gl.GetUniformLocation(RectShaderProgram.ID, "UVOffset"), Command.UVOffset.x, Command.UVOffset.y);
        gl.Uniform2f(gl.GetUniformLocation(RectShaderProgram.ID, "UVScale"), Command.UVScale.x, Command.UVScale.y);
        gl.Uniform4f(gl.GetUniformLocation(RectShaderProgram.ID, "Color"), Command.Color.r, Command.Color.g, Command.Color.b, Command.Color.a);
        
        GlTexture := GetTextureByID(GLContext, Command.Texture);
        gl.ActiveTexture(gl.TEXTURE0);
        gl.BindTexture(gl.TEXTURE_2D, GlTexture.Handle);
        
        gl.BindVertexArray(RectShaderProgram.VAO);
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil);
        
        gl.UseProgram(0);
        gl.BindVertexArray(0);
        gl.BindTexture(gl.TEXTURE_2D, 0);
        
      }
    }
  }
  assert(HeaderOffset == RenderCommands.Offset);
}