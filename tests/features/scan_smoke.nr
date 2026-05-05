// v0.8.200 stdlib/rods/scan.nr first test coverage.
//
// Parallel scan / prefix-sum / SSM kernels. Pre-v0.8.200: zero
// coverage.
//
// Locks four textbook prefix-scan invariants on [1, 2, 3, 4]:
//   1. **Inclusive prefix sum**: [1, 2, 3, 4] → [1, 3, 6, 10].
//   2. **Exclusive prefix sum**: [1, 2, 3, 4] → [0, 1, 3, 6]
//      (each cell is the sum of strict prefix).
//   3. **Prefix product**: [1, 2, 3, 4] → [1, 2, 6, 24].
//   4. **Prefix max**: [3, 1, 4, 1, 5, 9] → [3, 3, 4, 4, 5, 9].
//
// Expected: rc=0.

import "stdlib/rods/scan.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_v(a: f64, b: f64, c: f64, d: f64) -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(a));
    v.push(f64_to_bits(b));
    v.push(f64_to_bits(c));
    v.push(f64_to_bits(d));
    return v;
}

fn check_prefix_sum() -> i64 {
    let v: Vec<i64> = make_v(1.0, 2.0, 3.0, 4.0);
    let s: i64 = scan_sum(v);
    if close(vec_get(s, 0), f64_to_bits(1.0), 1e-9) != 1 { return 1; };
    if close(vec_get(s, 1), f64_to_bits(3.0), 1e-9) != 1 { return 2; };
    if close(vec_get(s, 2), f64_to_bits(6.0), 1e-9) != 1 { return 4; };
    if close(vec_get(s, 3), f64_to_bits(10.0), 1e-9) != 1 { return 8; };
    return 0;
}

fn check_prefix_sum_exclusive() -> i64 {
    let v: Vec<i64> = make_v(1.0, 2.0, 3.0, 4.0);
    let s: i64 = scan_sum_exclusive(v);
    if close(vec_get(s, 0), f64_to_bits(0.0), 1e-9) != 1 { return 16; };
    if close(vec_get(s, 1), f64_to_bits(1.0), 1e-9) != 1 { return 32; };
    if close(vec_get(s, 2), f64_to_bits(3.0), 1e-9) != 1 { return 64; };
    if close(vec_get(s, 3), f64_to_bits(6.0), 1e-9) != 1 { return 128; };
    return 0;
}

fn check_prefix_prod() -> i64 {
    let v: Vec<i64> = make_v(1.0, 2.0, 3.0, 4.0);
    let s: i64 = scan_prod(v);
    if close(vec_get(s, 0), f64_to_bits(1.0), 1e-9) != 1 { return 256; };
    if close(vec_get(s, 1), f64_to_bits(2.0), 1e-9) != 1 { return 512; };
    if close(vec_get(s, 2), f64_to_bits(6.0), 1e-9) != 1 { return 1024; };
    if close(vec_get(s, 3), f64_to_bits(24.0), 1e-9) != 1 { return 2048; };
    return 0;
}

fn check_prefix_max() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(3.0));
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(4.0));
    v.push(f64_to_bits(1.0));
    v.push(f64_to_bits(5.0));
    v.push(f64_to_bits(9.0));
    let s: i64 = scan_max(v);
    if close(vec_get(s, 0), f64_to_bits(3.0), 1e-9) != 1 { return 4096; };
    if close(vec_get(s, 1), f64_to_bits(3.0), 1e-9) != 1 { return 8192; };
    if close(vec_get(s, 2), f64_to_bits(4.0), 1e-9) != 1 { return 16384; };
    if close(vec_get(s, 3), f64_to_bits(4.0), 1e-9) != 1 { return 32768; };
    if close(vec_get(s, 4), f64_to_bits(5.0), 1e-9) != 1 { return 65536; };
    if close(vec_get(s, 5), f64_to_bits(9.0), 1e-9) != 1 { return 131072; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_prefix_sum();
    fails = fails + check_prefix_sum_exclusive();
    fails = fails + check_prefix_prod();
    fails = fails + check_prefix_max();
    return fails;
}
