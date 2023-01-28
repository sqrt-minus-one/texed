package editor

import "shared:base/math"
import "core:math/linalg"

camera :: struct
{
  P, dP: math.v2,
  TargetP: math.v2,
}

UpdateCameraPos :: proc(Camera: ^camera, dt: f32)
{
  Freq := f32(3.0);
  Zeta := f32(1.0);
  K1 := Zeta / (f32(linalg.PI) * Freq);
  K2 := 1.0 / math.Square(2 * f32(linalg.PI) * Freq);
  ddP := (1.0 / K2) * (Camera.TargetP - Camera.P - K1 * Camera.dP);
  Camera.dP += dt * ddP;
  Camera.P += dt * Camera.dP + 0.5 * math.Square(dt) * ddP;
}

GetClipMatrix :: proc(CameraP: math.v2, Width, Height: f32) -> math.m4x4
{
  Proj := math.Orthographic(0, Width, Height, 0, -100, 100);
  View := math.Translate(math.V3(CameraP.x, CameraP.y, 0));
  
  Clip := Proj * View;
  return Clip;
}