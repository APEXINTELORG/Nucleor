// v0.8.250 stdlib/rods/canny.nr first test coverage.
//
// Canny edge detector (4-stage Sobel/NMS/double-threshold/
// hysteresis pipeline). Pre-v0.8.250: zero coverage on the
// standalone rod. The algorithmic path needs raw double[]
// image / output arrays.
//
// Locks four bad-input invariants — the runtime null-checks
// img+edges and requires W ≥ 3 and H ≥ 3 (NMS / Sobel windows
// need a 3×3 minimum):
//
//   1. Null img returns 0 — bad input.
//   2. Null edges returns 0 — bad output buffer.
//   3. W < 3 returns 0 — degenerate width.
//   4. H < 3 returns 0 — degenerate height.
//
// Expected: rc=0.

import "stdlib/rods/canny.nr"

fn check_null_img() -> i64 {
    let r: i64 = canny(0, 10, 10, f64_to_bits(50.0), f64_to_bits(150.0), 1);
    if r != 0 { return 1; };
    return 0;
}

fn check_null_edges() -> i64 {
    let r: i64 = canny(1, 10, 10, f64_to_bits(50.0), f64_to_bits(150.0), 0);
    if r != 0 { return 2; };
    return 0;
}

fn check_W_lt_3() -> i64 {
    let r: i64 = canny(1, 2, 10, f64_to_bits(50.0), f64_to_bits(150.0), 1);
    if r != 0 { return 4; };
    let r0: i64 = canny(1, 0, 10, f64_to_bits(50.0), f64_to_bits(150.0), 1);
    if r0 != 0 { return 8; };
    return 0;
}

fn check_H_lt_3() -> i64 {
    let r: i64 = canny(1, 10, 2, f64_to_bits(50.0), f64_to_bits(150.0), 1);
    if r != 0 { return 16; };
    let r0: i64 = canny(1, 10, 0, f64_to_bits(50.0), f64_to_bits(150.0), 1);
    if r0 != 0 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_null_img();
    fails = fails + check_null_edges();
    fails = fails + check_W_lt_3();
    fails = fails + check_H_lt_3();
    return fails;
}
