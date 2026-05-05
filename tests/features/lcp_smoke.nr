// v0.8.209 stdlib/rods/lcp.nr first test coverage.
//
// Box LCP solver via Projected Gauss-Seidel. The iteration that
// underlies MuJoCo / Bullet / ODE rigid-body contact solvers.
// Pre-v0.8.209: zero coverage on the standalone rod.
//
// Locks four 1-D LCP invariants — the n=1 case admits closed-form
// solutions that PGS must reach exactly:
//
//   1. **Construction** — lcp_pgs_new(n) returns non-zero handle.
//   2. **Interior solution** — M=1, q=-2, λ ∈ [0, ∞):
//      w = 1·λ + (-2) = 0 at λ=2, all in interior → λ=2.
//   3. **Clamped at lower bound** — M=1, q=5, λ ∈ [0, ∞):
//      w(λ=0) = 5 ≥ 0 satisfies complementarity at lo → λ=0.
//   4. **Solver does iterations** — non-trivial solve returns
//      iters > 0 (proves PGS loop is exercised, not no-op).
//
// Expected: rc=0.

import "stdlib/rods/lcp.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_construction() -> i64 {
    let h: i64 = lcp_pgs_new(3);
    if h == 0 { return 1; };
    lcp_pgs_free(h);
    return 0;
}

fn check_interior_solution() -> i64 {
    let h: i64 = lcp_pgs_new(1);
    lcp_pgs_set_M(h, 0, 0, f64_to_bits(1.0));
    lcp_pgs_set_q(h, 0, f64_to_bits(0.0 - 2.0));
    lcp_pgs_solve(h, 1000, f64_to_bits(1e-12));
    let lam: i64 = lcp_pgs_get(h, 0);
    lcp_pgs_free(h);
    if close(lam, f64_to_bits(2.0), 1e-6) != 1 { return 2; };
    return 0;
}

fn check_clamped_at_lo() -> i64 {
    let h: i64 = lcp_pgs_new(1);
    lcp_pgs_set_M(h, 0, 0, f64_to_bits(1.0));
    lcp_pgs_set_q(h, 0, f64_to_bits(5.0));
    lcp_pgs_solve(h, 1000, f64_to_bits(1e-12));
    let lam: i64 = lcp_pgs_get(h, 0);
    lcp_pgs_free(h);
    if close(lam, f64_to_bits(0.0), 1e-6) != 1 { return 4; };
    return 0;
}

fn check_iters_positive() -> i64 {
    let h: i64 = lcp_pgs_new(1);
    lcp_pgs_set_M(h, 0, 0, f64_to_bits(1.0));
    lcp_pgs_set_q(h, 0, f64_to_bits(0.0 - 2.0));
    let iters: i64 = lcp_pgs_solve(h, 1000, f64_to_bits(1e-12));
    lcp_pgs_free(h);
    if iters <= 0 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_construction();
    fails = fails + check_interior_solution();
    fails = fails + check_clamped_at_lo();
    fails = fails + check_iters_positive();
    return fails;
}
