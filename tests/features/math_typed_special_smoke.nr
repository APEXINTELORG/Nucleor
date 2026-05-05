// v0.8.205 stdlib/rods/math_typed_special.nr first test coverage.
//
// Typed f64 wrappers around SciPy-style special functions
// (erf, erfc, gamma, lgamma, betainc, Student-t SF, normal CDF/SF).
// Pre-v0.8.205: zero coverage on the standalone rod.
//
// Locks four textbook special-function fixed points:
//
//   1. **erf(0) == 0** — odd function through origin.
//   2. **erfc(0) == 1** — erfc(x) = 1 - erf(x).
//   3. **gamma(5) == 24** — Γ(n) = (n-1)! for integer n; 4! = 24.
//   4. **norm_cdf(0) == 0.5** — standard normal at zero.
//
// Expected: rc=0.

import "stdlib/rods/math_typed_special.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_erf_zero() -> i64 {
    if close(erf_f64(0.0), 0.0, 1e-12) != 1 { return 1; };
    return 0;
}

fn check_erfc_zero() -> i64 {
    if close(erfc_f64(0.0), 1.0, 1e-12) != 1 { return 2; };
    return 0;
}

fn check_gamma_5() -> i64 {
    if close(gamma_f64(5.0), 24.0, 1e-9) != 1 { return 4; };
    return 0;
}

fn check_norm_cdf_zero() -> i64 {
    if close(norm_cdf_f64(0.0), 0.5, 1e-9) != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_erf_zero();
    fails = fails + check_erfc_zero();
    fails = fails + check_gamma_5();
    fails = fails + check_norm_cdf_zero();
    return fails;
}
