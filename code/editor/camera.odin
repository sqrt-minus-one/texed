package editor

import math "shared:base/math"


GetClipMatrix :: proc(CameraP: math.v2, Width, Height: f32) -> math.m4x4
{
  Proj := math.Orthographic(0, Width, Height, 0, -100, 100);
  View := math.Translate(math.V3(CameraP.x, CameraP.y, 0));
  
  Clip := Proj * View;
  return Clip;
}