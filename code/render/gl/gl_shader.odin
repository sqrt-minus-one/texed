// +private
package editor_render_gl

import "shared:base/math"
import "core:runtime"
import Logger "core:log"
import gl "vendor:OpenGL"

shader_id        :: u32;
vertex_array_id  :: u32;
vertex_buffer_id :: u32;

RectShaderCode := cast(cstring)#load("rect_shader.glsl")

rect_shader :: struct
{
  ID :  shader_id,
  VAO : vertex_array_id,
  VBO, EBO : vertex_buffer_id,
};

CompileProgramShader :: proc(SourceCode :cstring) -> (ID: shader_id, Ok :bool)
{
  VertexShaderID   := gl.CreateShader(gl.VERTEX_SHADER);
  defer gl.DeleteShader(VertexShaderID);
  FragmentShaderID := gl.CreateShader(gl.FRAGMENT_SHADER);
  defer gl.DeleteShader(FragmentShaderID);
  
  Program := gl.CreateProgram();
  defer
  {
    if !Ok do gl.DeleteProgram(Program);
  }
  
  // NOTE(fakhri): compile vertex shader
  {
    VertexCode := []cstring{"#version 330 core\n", "#define VERTEX_SHADER\n", SourceCode};
    gl.ShaderSource(VertexShaderID, i32(len(VertexCode)), &VertexCode[0], nil);
    gl.CompileShader(VertexShaderID);
    
    Status :i32= 0;
    gl.GetShaderiv(VertexShaderID, gl.COMPILE_STATUS, &Status);
    if (Status == 0)
    {
      InfoLog:[512]u8;
      gl.GetShaderInfoLog(VertexShaderID, len(InfoLog), nil, &InfoLog[0]);
      
      Logger.log(.Error, "Couldn't compile vertex shader program", SourceCode);
      Logger.log(.Error, "shader error :\n", InfoLog);
      return;
    }
  }
  
  // NOTE(fakhri): compile frag shader
  {
    FragCode := []cstring{"#version 330 core\n", "#define FRAGMENT_SHADER\n", SourceCode};
    gl.ShaderSource(FragmentShaderID, i32(len(FragCode)), &FragCode[0], nil);
    gl.CompileShader(FragmentShaderID);
    
    Status :i32= 0;
    gl.GetShaderiv(FragmentShaderID, gl.COMPILE_STATUS, &Status);
    if (Status == 0)
    {
      InfoLog:[512]u8;
      gl.GetShaderInfoLog(FragmentShaderID, len(InfoLog), nil, &InfoLog[0]);
      
      Logger.log(.Error, "Couldn't compile vertex shader program", SourceCode);
      Logger.log(.Error, "shader error :\n", InfoLog);
      return;
    }
  }
  
  // NOTE(fakhri): link shader program
  {
    gl.AttachShader(Program, VertexShaderID);
    defer if !Ok do gl.DetachShader(Program, VertexShaderID);
    
    gl.AttachShader(Program, FragmentShaderID);
    defer if !Ok do gl.DetachShader(Program, FragmentShaderID);;
    
    gl.LinkProgram(Program);
    
    Status :i32= 0;
    gl.GetProgramiv(Program, gl.LINK_STATUS, &Status);
    if (Status == 1)
    {
      Ok = true;
      ID = Program;
    }
    else
    {
      InfoLog:[512]u8;
      gl.GetProgramInfoLog(Program, len(InfoLog), nil, &InfoLog[0]);
      
      Logger.log(.Error, "Couldn't link shader program", SourceCode);
      Logger.log(.Error, "shader error :\n", InfoLog);
    }
  }
  
  return;
}


rect_vertex_attribute :: struct
{
  Pos :math.v2,
  UV  :math.v2,
};

SetVertexAttribPointers :: proc($VertexType: typeid)
{
  // Assuming struct of arrays of float
  
  TypeInfoBase := runtime.type_info_base(type_info_of(VertexType));
  VertixTypeVariants := TypeInfoBase.variant.(runtime.Type_Info_Struct);
  AttribCount := len(VertixTypeVariants.types);
  for i := 0; i < AttribCount; i += 1 
  {
    AttribType := VertixTypeVariants.types[i].variant.(runtime.Type_Info_Array);
    gl.VertexAttribPointer(u32(i),
                           i32(AttribType.count),
                           gl.FLOAT,
                           gl.FALSE,
                           i32(TypeInfoBase.size),
                           VertixTypeVariants.offsets[i]);
    gl.EnableVertexAttribArray(u32(i));
  }
}

LoadShaders :: proc (using GLContext :^gl_context) -> (Ok : bool)
{
  RectShaderProgram.ID = CompileProgramShader(RectShaderCode) or_return;
  gl.UseProgram(RectShaderProgram.ID);
  
  RectVertices := [?]rect_vertex_attribute {
    rect_vertex_attribute{Pos = {-0.5,  0.5}, UV = {0.0, 1.0}}, // up-left
    rect_vertex_attribute{Pos = {-0.5, -0.5}, UV = {0.0, 0.0}}, // down-left
    rect_vertex_attribute{Pos = { 0.5, -0.5}, UV = {1.0, 0.0}}, // down-right
    rect_vertex_attribute{Pos = { 0.5,  0.5}, UV = {1.0, 1.0}}, // up-right
  }
  
  gl.GenVertexArrays(1, &RectShaderProgram.VAO);
  gl.BindVertexArray(RectShaderProgram.VAO);
  
  gl.GenBuffers(1, &RectShaderProgram.VBO);
  gl.BindBuffer(gl.ARRAY_BUFFER, RectShaderProgram.VBO);
  gl.BufferData(gl.ARRAY_BUFFER, size_of(RectVertices), &RectVertices, gl.STATIC_DRAW);
  
  SetVertexAttribPointers(rect_vertex_attribute);
  
  Indices := [?]u32 {
    0, 1, 2,
    0, 2, 3,
  };
  
  gl.GenBuffers(1, &RectShaderProgram.EBO);
  gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, RectShaderProgram.EBO);
  gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(Indices), &Indices, gl.STATIC_DRAW);
  
  gl.UseProgram(0);
  gl.BindVertexArray(0);
  gl.BindBuffer(gl.ARRAY_BUFFER, 0);
  gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
  return true;
}
