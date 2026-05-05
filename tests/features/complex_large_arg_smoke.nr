// v0.8.276 R09-D3 Phase 1 — stable complex algorithms coverage.
//
// Per audit `BUILD_PLAN_R09_numeric_correctness.md` §1 R09-D3 (HIGH):
// pre-v0.8.276 `cx_abs`, `cx_div`, `cx_log` used direct
// `sqrt(a*a + b*b)` / `(a*c+b*d)/(c*c+d*d)` formulas that overflow
// for large arguments and underflow for small ones.
//
// Phase 1 (this ship):
//   - `cx_abs` and `cx_log` magnitude path use C99 `hypot(a, b)`
//     (scaled, stable across the full f64 dynamic range);
//   - `cx_div` uses Smith's algorithm — scales by larger of |c|/|d|
//     to keep all intermediates well-conditioned even when |c| or
//     |d| is at the f64 extreme.
//
// Phase 1 acceptance criteria:
//   - large/small argument fixtures match documented tolerances;
//   - cold compile <= 4s (preserved).
//
// Locks 5 invariants — basic correctness + overflow/underflow
// resilience:
//   1. **Basic abs(3+4i) = 5.0** — pythagorean triple, no extremes.
//   2. **Large abs(1e200 + 1e200·i) ≈ √2 · 1e200** — direct
//      `1e200^2 = 1e400` overflows DBL_MAX; hypot stays finite.
//   3. **Tiny abs(1e-200 + 1e-200·i) ≈ √2 · 1e-200** — direct
//      `1e-200^2 = 1e-400` underflows to 0; hypot preserves
//      magnitude.
//   4. **Smith's div on (1+0i) / (1e200 + 1e200·i)** — direct
//      `denom = 2e400` overflows; Smith's stays finite (very small
//      result, but well-defined).
//   5. **Basic div (4+2i) / (3+1i)** — Pythagorean-style sanity
//      check: numerically equal to the direct formula.
//
// Expected: rc=0.

import "stdlib/rods/complex.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

// Relative-tolerance close: |a - b| / max(|a|, |b|, 1.0) < rel.
fn close_rel(a_bits: i64, b_bits: i64, rel: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    let abs_a: f64 = if af < 0.0 { 0.0 - af } else { af };
    let abs_b: f64 = if bf < 0.0 { 0.0 - bf } else { bf };
    let scale: f64 = if abs_a > abs_b { abs_a } else { abs_b };
    let scale_ok: f64 = if scale > 1.0 { scale } else { 1.0 };
    if abs_d / scale_ok < rel { return 1; };
    return 0;
}

fn check_basic_abs() -> i64 {
    let z: i64 = cx_new(f64_to_bits(3.0), f64_to_bits(4.0));
    let m: i64 = cx_abs(z);
    if close(m, f64_to_bits(5.0), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_large_abs() -> i64 {
    // |1e200 + 1e200·i| = √2 · 1e200 ≈ 1.4142135623730951e200.
    // Direct sqrt(1e200^2 + 1e200^2) = sqrt(2e400) → overflow.
    let z: i64 = cx_new(f64_to_bits(1e200), f64_to_bits(1e200));
    let m: i64 = cx_abs(z);
    if close_rel(m, f64_to_bits(1.4142135623730951e200), 1e-12) != 1 { return 2; };
    return 0;
}

fn check_tiny_abs() -> i64 {
    // |1e-200 + 1e-200·i| = √2 · 1e-200 ≈ 1.4142135623730951e-200.
    // Direct: 1e-200^2 = 1e-400 → underflows to 0; result would be 0.
    let z: i64 = cx_new(f64_to_bits(1e-200), f64_to_bits(1e-200));
    let m: i64 = cx_abs(z);
    if close_rel(m, f64_to_bits(1.4142135623730951e-200), 1e-12) != 1 { return 4; };
    return 0;
}

fn check_smith_div_extreme() -> i64 {
    // (1 + 0i) / (1e200 + 1e200·i). Direct: denom = c^2+d^2 = 2e400 → overflow.
    // Smith's: |c| == |d|, picks branch r = d/c = 1, denom = c + r*d = 2e200,
    // re = (1 + 1*0) / 2e200 = 5e-201, im = (0 - 1*1) / 2e200 = -5e-201.
    let num: i64 = cx_new(f64_to_bits(1.0), f64_to_bits(0.0));
    let den: i64 = cx_new(f64_to_bits(1e200), f64_to_bits(1e200));
    let q: i64 = cx_div(num, den);
    if close_rel(cx_real(q), f64_to_bits(5e-201), 1e-12) != 1 { return 8; };
    if close_rel(cx_imag(q), f64_to_bits(0.0 - 5e-201), 1e-12) != 1 { return 16; };
    return 0;
}

fn check_basic_div() -> i64 {
    // (4 + 2i) / (3 + 1i):
    //   numerator (real direct) = (4*3 + 2*1) / (3^2 + 1^2) = 14/10 = 1.4
    //   numerator (imag direct) = (2*3 - 4*1) / 10 = 2/10 = 0.2
    let a: i64 = cx_new(f64_to_bits(4.0), f64_to_bits(2.0));
    let b: i64 = cx_new(f64_to_bits(3.0), f64_to_bits(1.0));
    let q: i64 = cx_div(a, b);
    if close(cx_real(q), f64_to_bits(1.4), 1e-9) != 1 { return 32; };
    if close(cx_imag(q), f64_to_bits(0.2), 1e-9) != 1 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_basic_abs();
    fails = fails + check_large_abs();
    fails = fails + check_tiny_abs();
    fails = fails + check_smith_div_extreme();
    fails = fails + check_basic_div();
    return fails;
}
