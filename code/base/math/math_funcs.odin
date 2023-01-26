package base_math

import "core:math"
import alg "core:math/linalg"

V3 :: proc (X, Y, Z : f32) -> (Out: v3)
{
  Out = {X, Y, Z};
  return;
}

V2 :: proc (X, Y : f32) -> (Out: v2)
{
  Out = {X, Y};
  return;
}

V2iToV2 :: proc(In : v2i) -> (Out : v2)
{
  Out = V2(f32(In.x), f32(In.y));;
  return;
}

V2uToV2 :: proc(In : v2u) -> (Out : v2)
{
  Out = V2(f32(In.x), f32(In.y));
  return;
}

ToV2 :: proc{V2uToV2, V2iToV2};


V2i :: proc (X, Y : i32) -> (Out: v2i)
{
  Out = {X, Y};
  return;
}

V2ToV2i :: proc(In : v2) -> (Out : v2i)
{
  Out = V2i(i32(In.x), i32(In.y));
  return;
}

V2uToV2i :: proc(In : v2u) -> (Out : v2i)
{
  Out = V2i(i32(In.x), i32(In.y));
  return;
}

ToV2i :: proc{V2uToV2i, V2ToV2i};


V2u :: proc (X, Y : u32) -> (Out: v2u)
{
  Out = {X, Y};
  return;
}

V2ToV2u :: proc(In : v2) -> (Out : v2u)
{
  Out = V2u(u32(In.x), u32(In.y));
  return;
}

V2iToV2u :: proc(In : v2i) -> (Out : v2u)
{
  Out = V2u(u32(In.x), u32(In.y));
  return;
}

ToV2u :: proc{V2iToV2u, V2ToV2u};


Orthographic :: proc(Left, Right, Bottom, Top, Near, Far: f32, FlipZAxis := true) -> (Result: m4x4)
{
  Result = m4x4(alg.matrix_ortho3d(Left, Right, Bottom, Top, Near, Far, FlipZAxis));
  return;
}


Translate:: proc(T : v3) -> (Result: m4x4)
{
  Result = alg.matrix4_translate(alg.Vector3f32(T));
  return;
}

Scale :: proc(S : v3) -> (Result: m4x4)
{
  Result = alg.matrix4_scale(alg.Vector3f32(S));
  return;
}

Sin :: proc(In: f32) -> (Out: f32)
{
  Out = math.sin(In);
  return;
}

Square :: proc(In: f32) -> (Out: f32)
{
  Out = In * In;
  return;
}