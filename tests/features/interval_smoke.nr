// v0.8.203 stdlib/rods/interval.nr first test coverage.
//
// Interval arithmetic — rigorous bounds with guaranteed
// containment of the true result. Mathematical foundation
// for computer-assisted proofs (e.g., Tucker's Lorenz proof).
// Pre-v0.8.203: zero coverage.
//
// Locks four interval-arithmetic invariants:
//
//   1. **Construction round-trip**: iv_new(2,5) → lo=2, hi=5,
//      width=3, mid=3.5.
//   2. **Containment**: 3 ∈ [2,5] but 1 ∉ [2,5].
//   3. **Add**: [1,2] + [3,4] = [4,6] (lo+lo, hi+hi).
//   4. **Neg flips bounds**: -[2,5] = [-5,-2].
//
// Expected: rc=0.

import "stdlib/rods/interval.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_construction() -> i64 {
    let cp: i64 = iv_checkpoint();
    let h: i64 = iv_new(f64_to_bits(2.0), f64_to_bits(5.0));
    if close(iv_lo(h), f64_to_bits(2.0), 1e-9) != 1 { iv_reset(cp); return 1; };
    if close(iv_hi(h), f64_to_bits(5.0), 1e-9) != 1 { iv_reset(cp); return 2; };
    if close(iv_width(h), f64_to_bits(3.0), 1e-9) != 1 { iv_reset(cp); return 4; };
    if close(iv_mid(h), f64_to_bits(3.5), 1e-9) != 1 { iv_reset(cp); return 8; };
    iv_reset(cp);
    return 0;
}

fn check_contains() -> i64 {
    let cp: i64 = iv_checkpoint();
    let h: i64 = iv_new(f64_to_bits(2.0), f64_to_bits(5.0));
    if iv_contains(h, f64_to_bits(3.0)) != 1 { iv_reset(cp); return 16; };
    if iv_contains(h, f64_to_bits(1.0)) != 0 { iv_reset(cp); return 32; };
    iv_reset(cp);
    return 0;
}

fn check_add() -> i64 {
    let cp: i64 = iv_checkpoint();
    let a: i64 = iv_new(f64_to_bits(1.0), f64_to_bits(2.0));
    let b: i64 = iv_new(f64_to_bits(3.0), f64_to_bits(4.0));
    let s: i64 = iv_add(a, b);
    if close(iv_lo(s), f64_to_bits(4.0), 1e-9) != 1 { iv_reset(cp); return 64; };
    if close(iv_hi(s), f64_to_bits(6.0), 1e-9) != 1 { iv_reset(cp); return 128; };
    iv_reset(cp);
    return 0;
}

fn check_neg() -> i64 {
    let cp: i64 = iv_checkpoint();
    let h: i64 = iv_new(f64_to_bits(2.0), f64_to_bits(5.0));
    let n: i64 = iv_neg(h);
    if close(iv_lo(n), f64_to_bits(0.0 - 5.0), 1e-9) != 1 { iv_reset(cp); return 256; };
    if close(iv_hi(n), f64_to_bits(0.0 - 2.0), 1e-9) != 1 { iv_reset(cp); return 512; };
    iv_reset(cp);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_construction();
    fails = fails + check_contains();
    fails = fails + check_add();
    fails = fails + check_neg();
    return fails;
}
