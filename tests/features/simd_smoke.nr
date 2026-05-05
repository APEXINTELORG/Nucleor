// v0.8.177 stdlib/rods/simd.nr first test coverage.
//
// Software-emulated packed SIMD primitives — f32x4 + i32x4 with
// arithmetic, lane access, dot product, horizontal sum.
// Pre-v0.8.177: zero coverage.
//
// Locks four invariants on the i32x4 lane (cleaner than f32x4
// for unit testing — no f32 bit-cast machinery required):
//   1. **Lane access**: i32x4(1,2,3,4) → lane(0)=1, lane(3)=4.
//   2. **Splat**: splat(7) → all 4 lanes are 7.
//   3. **Add (vectorwise)**: i32x4(1,2,3,4) + i32x4(10,20,30,40)
//      → lane-wise (11,22,33,44).
//   4. **Horizontal sum**: i32x4(1,2,3,4) → 10.
//
// Expected: rc=0.

import "stdlib/rods/simd.nr"

fn check_lane_access() -> i64 {
    let v: i64 = simd_i32x4_lit(1, 2, 3, 4);
    if simd_i32x4_lane(v, 0) != 1 { simd_i32x4_drop(v); return 1; };
    if simd_i32x4_lane(v, 1) != 2 { simd_i32x4_drop(v); return 2; };
    if simd_i32x4_lane(v, 2) != 3 { simd_i32x4_drop(v); return 4; };
    if simd_i32x4_lane(v, 3) != 4 { simd_i32x4_drop(v); return 8; };
    simd_i32x4_drop(v);
    return 0;
}

fn check_splat() -> i64 {
    let v: i64 = simd_i32x4_splat_v(7);
    if simd_i32x4_lane(v, 0) != 7 { simd_i32x4_drop(v); return 16; };
    if simd_i32x4_lane(v, 1) != 7 { simd_i32x4_drop(v); return 32; };
    if simd_i32x4_lane(v, 2) != 7 { simd_i32x4_drop(v); return 64; };
    if simd_i32x4_lane(v, 3) != 7 { simd_i32x4_drop(v); return 128; };
    simd_i32x4_drop(v);
    return 0;
}

fn check_add_lanewise() -> i64 {
    let a: i64 = simd_i32x4_lit(1, 2, 3, 4);
    let b: i64 = simd_i32x4_lit(10, 20, 30, 40);
    let c: i64 = simd_i32x4_plus(a, b);
    if simd_i32x4_lane(c, 0) != 11 { return 256; };
    if simd_i32x4_lane(c, 1) != 22 { return 512; };
    if simd_i32x4_lane(c, 2) != 33 { return 1024; };
    if simd_i32x4_lane(c, 3) != 44 { return 2048; };
    simd_i32x4_drop(a);
    simd_i32x4_drop(b);
    simd_i32x4_drop(c);
    return 0;
}

fn check_horizontal_sum() -> i64 {
    let v: i64 = simd_i32x4_lit(1, 2, 3, 4);
    let s: i64 = simd_i32x4_horizontal_sum(v);
    if s != 10 { simd_i32x4_drop(v); return 4096; };
    simd_i32x4_drop(v);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_lane_access();
    fails = fails + check_splat();
    fails = fails + check_add_lanewise();
    fails = fails + check_horizontal_sum();
    return fails;
}
