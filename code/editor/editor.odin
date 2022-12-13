package editor

import logger "core:log"
import "shared:render"
import math "shared:base/math"

editor_context :: struct
{
  IsInitialized :bool,
  MainFont :font,
}

UpdateAndRender :: proc(EditorCtx :^editor_context, Renderer : ^render.renderer_context)
{
  if !EditorCtx.IsInitialized
  {
    EditorCtx.IsInitialized = true;
    
    Ok :bool;
    EditorCtx.MainFont, Ok = LoadFont(Renderer, "data/fonts/arial.ttf", 70);
    if !Ok do logger.log(.Error, "Couldn't Load Font");
  }
  
  Width  := f32(Renderer.ScreenDim.x);
  Height := f32(Renderer.ScreenDim.y);
  Proj := math.Orthographic(0, Width, 0, Height, -100, 100);
  
  render.PushClearColor(Renderer, 0, 0, 0, 1);
  render.PushClipMatrix(Renderer, Proj);
  
  RenderText(Renderer, &EditorCtx.MainFont, "Hello there", math.V2(500, 200), render.MakeColor(1));
}
