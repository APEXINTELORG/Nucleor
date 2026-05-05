// v0.8.232 stdlib/rods/lqr.nr first test coverage.
//
// Discrete infinite-horizon LQR via Riccati iteration. Pre-
// v0.8.232: zero coverage on the standalone rod (sister to
// ilqr.nr / ddp.nr finite-horizon nonlinear).
//
// Setup: 1-D system A=B=Q=R=1. The discrete algebraic Riccati
// equation
//   P = A²P − A²PB(R + B²P)⁻¹BPA + Q
// reduces to P² − P − 1 = 0 → **P = φ = (1+√5)/2 ≈ 1.618**
// (golden ratio).
//
// The optimal feedback gain
//   K = (R + B²P)⁻¹ B P A = P/(1+P) = 1/φ ≈ 0.618
// (golden ratio reciprocal).
//
// Locks four invariants (compute_u uses raw ptrs; deferred):
//
//   1. **lqr_new returns valid handle**.
//   2. **solve runs at least one iteration** for a stabilizable
//      system.
//   3. **Riccati P solves to the golden ratio φ ≈ 1.618**.
//   4. **Optimal gain K = 1/φ ≈ 0.618**.
//
// Expected: rc=0.

import "stdlib/rods/lqr.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_new_valid() -> i64 {
    let h: i64 = lqr_new(1, 1);
    if h == 0 { return 1; };
    lqr_free(h);
    return 0;
}

fn check_solve_iters_positive() -> i64 {
    let h: i64 = lqr_new(1, 1);
    lqr_set_A(h, 0, 0, f64_to_bits(1.0));
    lqr_set_B(h, 0, 0, f64_to_bits(1.0));
    lqr_set_Q(h, 0, 0, f64_to_bits(1.0));
    lqr_set_R(h, 0, 0, f64_to_bits(1.0));
    let iters: i64 = lqr_solve(h, 1000, f64_to_bits(1e-12));
    lqr_free(h);
    if iters <= 0 { return 2; };
    return 0;
}

fn check_riccati_golden_ratio() -> i64 {
    let h: i64 = lqr_new(1, 1);
    lqr_set_A(h, 0, 0, f64_to_bits(1.0));
    lqr_set_B(h, 0, 0, f64_to_bits(1.0));
    lqr_set_Q(h, 0, 0, f64_to_bits(1.0));
    lqr_set_R(h, 0, 0, f64_to_bits(1.0));
    lqr_solve(h, 1000, f64_to_bits(1e-12));
    let p: i64 = lqr_P(h, 0, 0);
    lqr_free(h);
    if close(p, f64_to_bits(1.618033988749895), 1e-6) != 1 { return 4; };
    return 0;
}

fn check_optimal_gain() -> i64 {
    let h: i64 = lqr_new(1, 1);
    lqr_set_A(h, 0, 0, f64_to_bits(1.0));
    lqr_set_B(h, 0, 0, f64_to_bits(1.0));
    lqr_set_Q(h, 0, 0, f64_to_bits(1.0));
    lqr_set_R(h, 0, 0, f64_to_bits(1.0));
    lqr_solve(h, 1000, f64_to_bits(1e-12));
    let k: i64 = lqr_K(h, 0, 0);
    lqr_free(h);
    if close(k, f64_to_bits(0.6180339887498949), 1e-6) != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_solve_iters_positive();
    fails = fails + check_riccati_golden_ratio();
    fails = fails + check_optimal_gain();
    return fails;
}
