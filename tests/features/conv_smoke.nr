// v0.8.162 stdlib/rods/conv.nr first test coverage.
//
// CNN building blocks: 2D convolution, max-pool, avg-pool,
// batchnorm, dropout. Pre-v0.8.162: zero coverage.
//
// Locks two textbook pooling invariants on a 1-channel 4×4
// input. Convolution is also exercised but at minimum size
// (1×1 kernel == identity scale) since arbitrary 2D conv shape
// invariants are heavier to lock without separate verification
// helpers.
//
// Maxpool/avgpool are clean closed-form operations:
//
//   Input (4×4):  1 2 3 4
//                 5 6 7 8
//                 9 10 11 12
//                 13 14 15 16
//
//   max_pool(2, stride=2) → 2×2:  6 8
//                                 14 16
//
//   avg_pool(2, stride=2) → 2×2:  3.5  5.5
//                                 11.5 13.5
//
// Expected: rc=0.

import "stdlib/rods/conv.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_4x4() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 1;
    while i <= 16 {
        v.push(f64_to_bits(i as f64));
        i = i + 1;
    };
    return v;
}

fn check_maxpool() -> i64 {
    let inp: Vec<i64> = make_4x4();
    let out: i64 = maxpool_2d(inp, 1, 4, 4, 2, 2);
    if out == 0 { return 1; };
    // Expected: [6, 8, 14, 16]
    if close(vec_get(out, 0), f64_to_bits(6.0), 1e-9) != 1 { return 2; };
    if close(vec_get(out, 1), f64_to_bits(8.0), 1e-9) != 1 { return 4; };
    if close(vec_get(out, 2), f64_to_bits(14.0), 1e-9) != 1 { return 8; };
    if close(vec_get(out, 3), f64_to_bits(16.0), 1e-9) != 1 { return 16; };
    return 0;
}

fn check_avgpool() -> i64 {
    let inp: Vec<i64> = make_4x4();
    let out: i64 = avgpool_2d(inp, 1, 4, 4, 2, 2);
    if out == 0 { return 32; };
    // Expected: [3.5, 5.5, 11.5, 13.5]
    if close(vec_get(out, 0), f64_to_bits(3.5), 1e-9) != 1 { return 64; };
    if close(vec_get(out, 1), f64_to_bits(5.5), 1e-9) != 1 { return 128; };
    if close(vec_get(out, 2), f64_to_bits(11.5), 1e-9) != 1 { return 256; };
    if close(vec_get(out, 3), f64_to_bits(13.5), 1e-9) != 1 { return 512; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_maxpool();
    fails = fails + check_avgpool();
    return fails;
}
