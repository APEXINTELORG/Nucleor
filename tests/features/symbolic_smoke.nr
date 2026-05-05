// v0.8.175 stdlib/rods/symbolic.nr first test coverage.
//
// Symbolic math — expression trees, arithmetic, transcendentals,
// symbolic differentiation, numerical evaluation. Pre-v0.8.175:
// zero coverage.
//
// Locks three symbolic-math invariants:
//   1. **Constant evaluation**: const(5) evaluates to 5.
//   2. **Arithmetic eval**: (x + 3) at x=2 → 5.
//   3. **Polynomial eval**: x² at x=4 → 16.
//
// Symbolic differentiation of `pow(x, n)` returns 0 in the
// current impl (the chain-rule case for pow isn't wired).
// Locking that invariant is deferred until the impl handles
// pow d/dx — surfaced while writing this fixture.
//
// Expected: rc=0.

import "stdlib/rods/symbolic.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_const_eval() -> i64 {
    let c: i64 = sym_const(f64_to_bits(5.0));
    let r: i64 = sym_eval(c, "x", f64_to_bits(0.0));
    if close(r, f64_to_bits(5.0), 1e-9) != 1 { sym_free(c); return 1; };
    sym_free(c);
    return 0;
}

fn check_arithmetic_eval() -> i64 {
    let x: i64 = sym_var("x");
    let three: i64 = sym_const(f64_to_bits(3.0));
    let expr: i64 = sym_add(x, three);
    // (x + 3) at x=2 → 5
    let r: i64 = sym_eval(expr, "x", f64_to_bits(2.0));
    if close(r, f64_to_bits(5.0), 1e-9) != 1 { sym_free(expr); return 2; };
    sym_free(expr);
    return 0;
}

fn check_polynomial_eval() -> i64 {
    let x: i64 = sym_var("x");
    let two: i64 = sym_const(f64_to_bits(2.0));
    let expr: i64 = sym_pow(x, two);
    // x² at x=4 → 16
    let r: i64 = sym_eval(expr, "x", f64_to_bits(4.0));
    if close(r, f64_to_bits(16.0), 1e-9) != 1 { sym_free(expr); return 4; };
    sym_free(expr);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_const_eval();
    fails = fails + check_arithmetic_eval();
    fails = fails + check_polynomial_eval();
    return fails;
}
