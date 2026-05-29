// v0.8.208 stdlib/rods/math_typed.nr first test coverage.
//
// Typed f64 elementary math wrappers (sqrt, exp, log, tanh,
// sin, cos, pow). Pre-v0.8.208: zero coverage. Sister to
// math_typed_special (v0.8.205).
//
// Locks four textbook elementary-function fixed points:
//
//   1. sqrt(4) == 2 — square-root of perfect square.
//   2. exp(0) == 1 — e⁰ = 1.
//   3. log(1) == 0 — ln(1) = 0.
//   4. pow(2, 10) == 1024 — base^exp identity.
//
// Trig identities (sin(0)=0, cos(0)=1) are deferred to a
// dedicated trig fixture if needed.
//
// Expected: rc=0.

import "stdlib/rods/math_typed.nr"

fn close(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_sqrt() -> i64 {
    if close(sqrt_f64(4.0), 2.0, 1e-12) != 1 { return 1; };
    if close(sqrt_f64(9.0), 3.0, 1e-12) != 1 { return 2; };
    return 0;
}

fn check_exp() -> i64 {
    if close(exp_f64(0.0), 1.0, 1e-12) != 1 { return 4; };
    return 0;
}

fn check_log() -> i64 {
    if close(log_f64(1.0), 0.0, 1e-12) != 1 { return 8; };
    return 0;
}

fn check_pow() -> i64 {
    if close(pow_f64(2.0, 10.0), 1024.0, 1e-9) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_sqrt();
    fails = fails + check_exp();
    fails = fails + check_log();
    fails = fails + check_pow();
    return fails;
}
