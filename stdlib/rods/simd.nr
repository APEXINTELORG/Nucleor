// =====================================================
// rods/simd — SIMD vector types (RFC-0033 preview)
// =====================================================
// Import: import "stdlib/rods/simd.nr"
//
// Software-emulated packed SIMD primitives. Hardware vectorization
// (AVX/AVX2 → <4 x float> LLVM intrinsics) arrives in v0.4 with no
// API change.
//
// f32 lanes pass as i64 cells via complex.nr's f64 bitcast convention
// (use f32_from_int / f32_to_int for value translation).
// =====================================================

// ---- f32x4 (4 packed f32) ----
fn simd_f32x4_lit(a: i64, b: i64, c: i64, d: i64) -> i64 { return f32x4_new(a, b, c, d); }
fn simd_f32x4_splat_v(x: i64) -> i64 { return f32x4_splat(x); }
fn simd_f32x4_lane(v: i64, i: i64) -> i64 { return f32x4_get(v, i); }

fn simd_f32x4_plus(a: i64, b: i64) -> i64 { return f32x4_add(a, b); }
fn simd_f32x4_minus(a: i64, b: i64) -> i64 { return f32x4_sub(a, b); }
fn simd_f32x4_times(a: i64, b: i64) -> i64 { return f32x4_mul(a, b); }
fn simd_f32x4_divides(a: i64, b: i64) -> i64 { return f32x4_div(a, b); }
fn simd_f32x4_dot_product(a: i64, b: i64) -> i64 { return f32x4_dot(a, b); }
fn simd_f32x4_horizontal_sum(v: i64) -> i64 { return f32x4_sum(v); }
fn simd_f32x4_lane_max(v: i64) -> i64 { return f32x4_max(v); }
fn simd_f32x4_lane_min(v: i64) -> i64 { return f32x4_min(v); }
fn simd_f32x4_drop(v: i64) -> i64 { return f32x4_free(v); }

// ---- i32x4 (4 packed i32) ----
fn simd_i32x4_lit(a: i64, b: i64, c: i64, d: i64) -> i64 { return i32x4_new(a, b, c, d); }
fn simd_i32x4_splat_v(x: i64) -> i64 { return i32x4_splat(x); }
fn simd_i32x4_lane(v: i64, i: i64) -> i64 { return i32x4_get(v, i); }
fn simd_i32x4_plus(a: i64, b: i64) -> i64 { return i32x4_add(a, b); }
fn simd_i32x4_minus(a: i64, b: i64) -> i64 { return i32x4_sub(a, b); }
fn simd_i32x4_times(a: i64, b: i64) -> i64 { return i32x4_mul(a, b); }
fn simd_i32x4_horizontal_sum(v: i64) -> i64 { return i32x4_sum(v); }
fn simd_i32x4_drop(v: i64) -> i64 { return i32x4_free(v); }
