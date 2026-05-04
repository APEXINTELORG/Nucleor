// v0.8.98 stdlib/rods/interval.nr first test coverage.
//
// Per the zero-coverage rod survey, interval.nr (rigorous
// numerical bounds — the foundation for computer-assisted
// proofs like Tucker's Lorenz proof) had no existing tests.
// Silent regressions in interval arithmetic would invalidate
// any downstream proof that relies on guaranteed containment.
//
// Locks (uses f64_to_bits / f64_from_bits since the i64-
// everywhere ABI passes f64s as bit-cast i64):
//
//   1. iv_new + iv_lo / iv_hi: round-trip endpoints.
//   2. iv_contains: an interior point IS contained.
//   3. iv_width([1.0, 5.0]) == 4.0.
//   4. iv_midpoint([2.0, 8.0]) == 5.0.
//   5. iv_add: [1,2] + [3,4] = [4,6].
//   6. iv_sub: [3,4] - [1,2] = [1,3].
//   7. iv_mul: [1,2] * [3,4] = [3,8] (positive×positive).
//   8. iv_neg: -[1,2] = [-2,-1].
//
// Float compares use a small epsilon (1e-9) since interval
// arithmetic emits rounded bounds.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/interval.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-9 { return 1; };
    return 0;
}

fn check_endpoints() -> i64 {
    let h: i64 = iv_new(f64_to_bits(2.0), f64_to_bits(7.0));
    if close(iv_lo(h), f64_to_bits(2.0)) != 1 { return 1; };
    if close(iv_hi(h), f64_to_bits(7.0)) != 1 { return 2; };
    return 0;
}

fn check_contains() -> i64 {
    let h: i64 = iv_new(f64_to_bits(0.0), f64_to_bits(1.0));
    if iv_contains(h, f64_to_bits(0.5)) != 1 { return 4; };
    return 0;
}

fn check_width() -> i64 {
    let h: i64 = iv_new(f64_to_bits(1.0), f64_to_bits(5.0));
    if close(iv_width(h), f64_to_bits(4.0)) != 1 { return 8; };
    return 0;
}

fn check_midpoint() -> i64 {
    let h: i64 = iv_new(f64_to_bits(2.0), f64_to_bits(8.0));
    if close(iv_mid(h), f64_to_bits(5.0)) != 1 { return 16; };
    return 0;
}

fn check_add() -> i64 {
    let a: i64 = iv_new(f64_to_bits(1.0), f64_to_bits(2.0));
    let b: i64 = iv_new(f64_to_bits(3.0), f64_to_bits(4.0));
    let r: i64 = iv_add(a, b);
    if close(iv_lo(r), f64_to_bits(4.0)) != 1 { return 32; };
    if close(iv_hi(r), f64_to_bits(6.0)) != 1 { return 64; };
    return 0;
}

fn check_sub() -> i64 {
    let a: i64 = iv_new(f64_to_bits(3.0), f64_to_bits(4.0));
    let b: i64 = iv_new(f64_to_bits(1.0), f64_to_bits(2.0));
    let r: i64 = iv_sub(a, b);
    if close(iv_lo(r), f64_to_bits(1.0)) != 1 { return 128; };
    if close(iv_hi(r), f64_to_bits(3.0)) != 1 { return 256; };
    return 0;
}

fn check_mul_positive() -> i64 {
    let a: i64 = iv_new(f64_to_bits(1.0), f64_to_bits(2.0));
    let b: i64 = iv_new(f64_to_bits(3.0), f64_to_bits(4.0));
    let r: i64 = iv_mul(a, b);
    if close(iv_lo(r), f64_to_bits(3.0)) != 1 { return 512; };
    if close(iv_hi(r), f64_to_bits(8.0)) != 1 { return 1024; };
    return 0;
}

fn check_neg() -> i64 {
    let a: i64 = iv_new(f64_to_bits(1.0), f64_to_bits(2.0));
    let r: i64 = iv_neg(a);
    if close(iv_lo(r), f64_to_bits(0.0 - 2.0)) != 1 { return 2048; };
    if close(iv_hi(r), f64_to_bits(0.0 - 1.0)) != 1 { return 4096; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_endpoints();
    fails = fails + check_contains();
    fails = fails + check_width();
    fails = fails + check_midpoint();
    fails = fails + check_add();
    fails = fails + check_sub();
    fails = fails + check_mul_positive();
    fails = fails + check_neg();
    return fails;
}
