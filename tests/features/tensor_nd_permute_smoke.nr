// Helper1 v0857: ML-3 tensor_nd general permutation coverage.
//
// Locks:
//   1. tensor_permute accepts a valid 3D axes Vec.
//   2. Shape [2,3,4] with axes [1,0,2] becomes [3,2,4].
//   3. Representative row-major values map to the expected source cells.
//   4. Duplicate and short axes return 0.
//   5. tensor_limitations names tensor_permute.
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

fn make_tensor_234() -> i64 {
    let t: i64 = tensor_new_3d(2, 3, 4);
    let mut i: i64 = 0;
    while i < 24 {
        tensor_set_flat(t, i, f64_to_bits(i as f64));
        i = i + 1;
    };
    return t;
}

fn axes_102() -> Vec<i64> {
    let mut axes: Vec<i64> = Vec::new();
    axes.push(1);
    axes.push(0);
    axes.push(2);
    return axes;
}

fn check_permute_3d() -> i64 {
    let t: i64 = make_tensor_234();
    let axes: Vec<i64> = axes_102();
    let p: i64 = tensor_permute(t, axes);
    if p == 0 { tensor_free(t); return 1; };
    if tensor_ndim(p) != 3 { tensor_free(t); tensor_free(p); return 2; };
    if tensor_shape(p, 0) != 3 { tensor_free(t); tensor_free(p); return 4; };
    if tensor_shape(p, 1) != 2 { tensor_free(t); tensor_free(p); return 8; };
    if tensor_shape(p, 2) != 4 { tensor_free(t); tensor_free(p); return 16; };
    if close(tensor_get_flat(p, 0), f64_to_bits(0.0), 1e-9) != 1 { tensor_free(t); tensor_free(p); return 32; };
    if close(tensor_get_flat(p, 4), f64_to_bits(12.0), 1e-9) != 1 { tensor_free(t); tensor_free(p); return 64; };
    if close(tensor_get_flat(p, 8), f64_to_bits(4.0), 1e-9) != 1 { tensor_free(t); tensor_free(p); return 128; };
    if close(tensor_get_flat(p, 12), f64_to_bits(16.0), 1e-9) != 1 { tensor_free(t); tensor_free(p); return 256; };
    if close(tensor_get_flat(p, 23), f64_to_bits(23.0), 1e-9) != 1 { tensor_free(t); tensor_free(p); return 512; };
    tensor_free(t);
    tensor_free(p);
    return 0;
}

fn check_invalid_axes() -> i64 {
    let t: i64 = make_tensor_234();
    let mut dup: Vec<i64> = Vec::new();
    dup.push(0);
    dup.push(0);
    dup.push(2);
    let bad_dup: i64 = tensor_permute(t, dup);
    if bad_dup != 0 { tensor_free(t); tensor_free(bad_dup); return 1024; };

    let mut short_axes: Vec<i64> = Vec::new();
    short_axes.push(0);
    short_axes.push(1);
    let bad_short: i64 = tensor_permute(t, short_axes);
    if bad_short != 0 { tensor_free(t); tensor_free(bad_short); return 2048; };

    tensor_free(t);
    return 0;
}

fn check_limitations() -> i64 {
    let s: str = tensor_limitations();
    if str_index_of(s, "tensor_permute") < 0 { return 4096; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_permute_3d();
    fails = fails + check_invalid_axes();
    fails = fails + check_limitations();
    return fails;
}
