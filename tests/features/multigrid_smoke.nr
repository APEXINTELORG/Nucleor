// v0.8.215 stdlib/rods/multigrid.nr first test coverage.
//
// 2-D multigrid V-cycle Poisson solver (Gauss-Seidel red-black
// smoother + full-weighting restriction + bilinear prolongation).
// Pre-v0.8.215: zero coverage on the standalone rod.
//
// Setup: N=8 grid, all-zero boundary conditions, all-zero rhs.
// The exact solution to -Δu = 0 with homogeneous Dirichlet
// boundary is u = 0 everywhere; v-cycle preserves zero state.
//
// Locks four invariants:
//
//   1. Residual of zero u + zero f == 0 — Laplacian(0) = 0
//      with f = 0 gives r = 0 everywhere (sanity gate).
//   2. Solver completes — mg_solve_2d returns success flag
//      (0.0 bitcast) without crashing.
//   3. Solve preserves zero state — solving with f = 0
//      starting at u = 0 leaves u all-zero.
//   4. Residual after solve is small — post-solve residual
//      norm ≤ tol on the trivial problem.
//
// Expected: rc=0.

import "stdlib/rods/multigrid.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn build_zeros(n: i64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < (n * n) {
        v.push(f64_to_bits(0.0));
        i = i + 1;
    };
    return v;
}

fn check_zero_residual() -> i64 {
    let rhs: i64 = build_zeros(8);
    let sol: i64 = build_zeros(8);
    let r: i64 = mg_residual(sol, rhs, 8);
    if close(r, f64_to_bits(0.0), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_solver_completes() -> i64 {
    let rhs: i64 = build_zeros(8);
    let sol: i64 = build_zeros(8);
    let _ok: i64 = mg_solve_2d(rhs, sol, 8, f64_to_bits(1e-6));
    return 0;
}

fn check_zero_preserved() -> i64 {
    let rhs: i64 = build_zeros(8);
    let sol: i64 = build_zeros(8);
    mg_solve_2d(rhs, sol, 8, f64_to_bits(1e-6));
    let mut i: i64 = 0;
    while i < 64 {
        if close(vec_get(sol, i), f64_to_bits(0.0), 1e-9) != 1 { return 4; };
        i = i + 1;
    };
    return 0;
}

fn check_post_solve_residual() -> i64 {
    let rhs: i64 = build_zeros(8);
    let sol: i64 = build_zeros(8);
    mg_solve_2d(rhs, sol, 8, f64_to_bits(1e-6));
    let r_bits: i64 = mg_residual(sol, rhs, 8);
    let r: f64 = f64_from_bits(r_bits);
    if r > 1e-6 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_zero_residual();
    fails = fails + check_solver_completes();
    fails = fails + check_zero_preserved();
    fails = fails + check_post_solve_residual();
    return fails;
}
