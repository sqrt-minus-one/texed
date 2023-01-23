package base_math

m4x4 :: #type matrix[4,4]f32
v2   :: #type [2]f32
v2u  :: #type [2]u32
v2i  :: #type [2]i32
v3   :: #type [3]f32
v4   :: #type [4]f32

rectangle2u :: struct {Min, Max: v2u};

M4x4_IDENTITY :: m4x4(1);