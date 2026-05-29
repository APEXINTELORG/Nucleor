// v0.8.218 stdlib/rods/pca.nr first test coverage.
//
// Principal Component Analysis — covariance + Jacobi
// eigendecomposition + projection. Pre-v0.8.218: zero coverage
// on the standalone rod.
//
// Test data: perfectly correlated 4-sample 2-feature matrix
// (1,1) (2,2) (3,3) (4,4). Both features along the y=x line.
// After standardization both columns become identical, so the
// covariance matrix [[1,1],[1,1]] has eigenvalues 2 and 0.
//
// Locks four foundational PCA invariants:
//
//   1. PC1 captures 100% of variance — variance_ratio(0) ≈ 1.0
//      for perfectly correlated 2-D data.
//   2. Variance ratios sum to 1 — across all components.
//   3. Eigenvalues sorted descending — eig(0) ≥ eig(1).
//   4. Eigenvalues non-negative — covariance matrix is
//      positive semi-definite.
//
// Expected: rc=0.

import "stdlib/rods/pca.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn build_x() -> i64 {
    let mut x: Vec<i64> = Vec::new();
    x.push(f64_to_bits(1.0)); x.push(f64_to_bits(1.0));
    x.push(f64_to_bits(2.0)); x.push(f64_to_bits(2.0));
    x.push(f64_to_bits(3.0)); x.push(f64_to_bits(3.0));
    x.push(f64_to_bits(4.0)); x.push(f64_to_bits(4.0));
    return x;
}

fn check_pc1_dominant() -> i64 {
    let p: i64 = pca_fit(build_x(), 4, 2);
    let r0: i64 = pca_variance_ratio(p, 0);
    pca_free(p);
    if close(r0, f64_to_bits(1.0), 1e-6) != 1 { return 1; };
    return 0;
}

fn check_ratios_sum_to_one() -> i64 {
    let p: i64 = pca_fit(build_x(), 4, 2);
    let r0: i64 = pca_variance_ratio(p, 0);
    let r1: i64 = pca_variance_ratio(p, 1);
    let s: f64 = f64_from_bits(r0) + f64_from_bits(r1);
    pca_free(p);
    if close(f64_to_bits(s), f64_to_bits(1.0), 1e-6) != 1 { return 2; };
    return 0;
}

fn check_eigs_descending() -> i64 {
    let p: i64 = pca_fit(build_x(), 4, 2);
    let e0: f64 = f64_from_bits(pca_eigenvalue(p, 0));
    let e1: f64 = f64_from_bits(pca_eigenvalue(p, 1));
    pca_free(p);
    if e0 < e1 { return 4; };
    return 0;
}

fn check_eigs_nonneg() -> i64 {
    let p: i64 = pca_fit(build_x(), 4, 2);
    let e0: f64 = f64_from_bits(pca_eigenvalue(p, 0));
    let e1: f64 = f64_from_bits(pca_eigenvalue(p, 1));
    pca_free(p);
    // PC2 may be slightly negative due to Jacobi numerical error
    // for a degenerate (rank-1) covariance; allow -1e-9.
    if e0 < 0.0 - 1.0e-9 { return 8; };
    if e1 < 0.0 - 1.0e-9 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_pc1_dominant();
    fails = fails + check_ratios_sum_to_one();
    fails = fails + check_eigs_descending();
    fails = fails + check_eigs_nonneg();
    return fails;
}
