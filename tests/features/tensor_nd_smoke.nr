// v0.8.180 stdlib/rods/tensor_nd.nr first test coverage.
//
// 3D tensor construction, get/set, fill, total. Pre-v0.8.180:
// zero coverage.
//
// Locks five invariants on a 2×3×4 tensor:
//   1. Shape: ndim=3; shape(0)=2, shape(1)=3, shape(2)=4.
//   2. Total: total = 2*3*4 = 24.
//   3. Set + get round-trip: set(1,2,3, val=42.5) → get(1,2,3) == 42.5.
//   4. Fill: fill(7.0) → get_flat(0..N-1) all == 7.0.
//   5. Scale: scale(2.0) on a fill(3.0) tensor → 6.0 everywhere.
//
// Expected: rc=0.

import "stdlib/rods/tensor_nd.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_shape() -> i64 {
    let t: i64 = tensor_new_3d(2, 3, 4);
    if tensor_ndim(t) != 3 { tensor_free(t); return 1; };
    if tensor_shape(t, 0) != 2 { tensor_free(t); return 2; };
    if tensor_shape(t, 1) != 3 { tensor_free(t); return 4; };
    if tensor_shape(t, 2) != 4 { tensor_free(t); return 8; };
    tensor_free(t);
    return 0;
}

fn check_total() -> i64 {
    let t: i64 = tensor_new_3d(2, 3, 4);
    if tensor_total(t) != 24 { tensor_free(t); return 16; };
    tensor_free(t);
    return 0;
}

fn check_set_get() -> i64 {
    let t: i64 = tensor_new_3d(2, 3, 4);
    tensor_set_3d(t, 1, 2, 3, f64_to_bits(42.5));
    if close(tensor_get_3d(t, 1, 2, 3), f64_to_bits(42.5), 1e-9) != 1 { tensor_free(t); return 32; };
    tensor_free(t);
    return 0;
}

fn check_fill() -> i64 {
    let t: i64 = tensor_new_3d(2, 3, 4);
    tensor_fill(t, f64_to_bits(7.0));
    let mut i: i64 = 0;
    while i < 24 {
        if close(tensor_get_flat(t, i), f64_to_bits(7.0), 1e-9) != 1 {
            tensor_free(t);
            return 64;
        };
        i = i + 1;
    };
    tensor_free(t);
    return 0;
}

fn check_scale() -> i64 {
    let t: i64 = tensor_new_3d(2, 2, 2);
    tensor_fill(t, f64_to_bits(3.0));
    let s: i64 = nuc_t3_scale(t, f64_to_bits(2.0));
    let mut i: i64 = 0;
    while i < 8 {
        if close(tensor_get_flat(s, i), f64_to_bits(6.0), 1e-9) != 1 {
            tensor_free(t); tensor_free(s);
            return 128;
        };
        i = i + 1;
    };
    tensor_free(t);
    tensor_free(s);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_shape();
    fails = fails + check_total();
    fails = fails + check_set_get();
    fails = fails + check_fill();
    fails = fails + check_scale();
    return fails;
}
