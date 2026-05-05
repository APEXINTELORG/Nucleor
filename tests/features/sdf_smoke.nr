// v0.8.199 stdlib/rods/sdf.nr first test coverage.
//
// 2D Signed Distance Field on a regular grid. Pre-v0.8.199:
// zero coverage.
//
// Locks four invariants on a 10×10 grid at dx=1.0 origin (0,0):
//   1. **Construction shape**: width=10, height=10, dx=1.0.
//   2. **Set + get round-trip**: per-cell f64 value preserves.
//   3. **Initial all-free**: fresh grid cells default to +1e18
//      (large positive — "free everywhere").
//   4. **Query interpolates**: setting 4 corner cells uniformly
//      to value V → query at center returns V (within tolerance).
//
// Expected: rc=0.

import "stdlib/rods/sdf.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_construction() -> i64 {
    let h: i64 = sdf_new(10, 10, f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    if h == 0 { return 1; };
    if sdf_width(h) != 10 { sdf_free(h); return 2; };
    if sdf_height(h) != 10 { sdf_free(h); return 4; };
    if close(sdf_dx(h), f64_to_bits(1.0), 1e-9) != 1 { sdf_free(h); return 8; };
    sdf_free(h);
    return 0;
}

fn check_set_get_round_trip() -> i64 {
    let h: i64 = sdf_new(10, 10, f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    sdf_set(h, 3, 4, f64_to_bits(7.5));
    if close(sdf_get(h, 3, 4), f64_to_bits(7.5), 1e-9) != 1 { sdf_free(h); return 16; };
    sdf_free(h);
    return 0;
}

fn check_initial_all_free() -> i64 {
    let h: i64 = sdf_new(10, 10, f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let v: i64 = sdf_get(h, 5, 5);
    let vf: f64 = f64_from_bits(v);
    sdf_free(h);
    // Default is +1e18 — anything > 1e10 confirms "free"
    if vf < 1e10 { return 32; };
    return 0;
}

fn check_query_interpolates() -> i64 {
    let h: i64 = sdf_new(10, 10, f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    // Set the 2x2 cluster around (1.5, 1.5) all to value 5.0
    sdf_set(h, 1, 1, f64_to_bits(5.0));
    sdf_set(h, 1, 2, f64_to_bits(5.0));
    sdf_set(h, 2, 1, f64_to_bits(5.0));
    sdf_set(h, 2, 2, f64_to_bits(5.0));
    let q: i64 = sdf_query(h, f64_to_bits(1.5), f64_to_bits(1.5));
    sdf_free(h);
    // Bilinear interp of all-5.0 corners → 5.0
    if close(q, f64_to_bits(5.0), 1e-6) != 1 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_construction();
    fails = fails + check_set_get_round_trip();
    fails = fails + check_initial_all_free();
    fails = fails + check_query_interpolates();
    return fails;
}
