// v0.8.202 stdlib/rods/autodiff.nr first test coverage.
//
// Reverse-mode automatic differentiation. Pre-v0.8.202: zero
// coverage on the standalone rod (some use through downstream
// rods is indirect).
//
// Locks four textbook calculus invariants:
//
//   1. **Forward value of x*y at (2,3) == 6** — multiplicative
//      forward pass.
//   2. **d/dx(x²) at x=3 == 6** — power rule (computed via x*x).
//   3. **d/dx(sin(x)) at x=0 == 1** — cos(0) = 1.
//   4. **d/dx(x+y) at any point == 1** — sum rule.
//
// Each test calls ad_reset() first to clear the tape.
//
// Expected: rc=0.

import "stdlib/rods/autodiff.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_forward_mul() -> i64 {
    ad_reset();
    let x: i64 = ad_var(f64_to_bits(2.0));
    let y: i64 = ad_var(f64_to_bits(3.0));
    let z: i64 = ad_mul(x, y);
    if close(ad_value(z), f64_to_bits(6.0), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_grad_x_squared() -> i64 {
    ad_reset();
    let x: i64 = ad_var(f64_to_bits(3.0));
    let xx: i64 = ad_mul(x, x);
    if close(ad_grad(xx, x), f64_to_bits(6.0), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_grad_sin_at_zero() -> i64 {
    ad_reset();
    let x: i64 = ad_var(f64_to_bits(0.0));
    let s: i64 = ad_sin(x);
    if close(ad_grad(s, x), f64_to_bits(1.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_grad_sum_rule() -> i64 {
    ad_reset();
    let x: i64 = ad_var(f64_to_bits(7.0));
    let y: i64 = ad_var(f64_to_bits(11.0));
    let s: i64 = ad_add(x, y);
    if close(ad_grad(s, x), f64_to_bits(1.0), 1e-9) != 1 { return 8; };
    if close(ad_grad(s, y), f64_to_bits(1.0), 1e-9) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_forward_mul();
    fails = fails + check_grad_x_squared();
    fails = fails + check_grad_sin_at_zero();
    fails = fails + check_grad_sum_rule();
    return fails;
}
