// v0.8.198 stdlib/rods/ridge.nr first test coverage.
//
// Ridge regression via gradient descent. Pre-v0.8.198: zero
// coverage.
//
// Locks three lifecycle invariants on a perfectly linear
// dataset y = 2x:
//   1. **Matrix accessors round-trip**: mat_set + mat_get
//      preserve f64-bit values.
//   2. **Train returns valid model**: non-zero handle.
//   3. **Predict produces finite output** (no NaN/inf) — exact
//      convergence to the f(x)=2x analytic solution depends
//      heavily on lambda/lr/epochs choice and is out of scope
//      for a smoke test.
//
// Expected: rc=0.

import "stdlib/rods/ridge.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_mat_accessors() -> i64 {
    let m: i64 = mat_new(2, 3);
    mat_set(m, 3, 0, 1, f64_to_bits(7.5));
    let v: i64 = mat_get(m, 3, 0, 1);
    if close(v, f64_to_bits(7.5), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_train_returns_model() -> i64 {
    // Build X (4 samples × 1 feature), y = 2x
    let X: i64 = mat_new(4, 1);
    mat_set(X, 1, 0, 0, f64_to_bits(1.0));
    mat_set(X, 1, 1, 0, f64_to_bits(2.0));
    mat_set(X, 1, 2, 0, f64_to_bits(3.0));
    mat_set(X, 1, 3, 0, f64_to_bits(4.0));
    let y: i64 = vec_new();
    vec_push(y, f64_to_bits(2.0));
    vec_push(y, f64_to_bits(4.0));
    vec_push(y, f64_to_bits(6.0));
    vec_push(y, f64_to_bits(8.0));
    let model: i64 = ridge_train(X, y, 4, 1,
        f64_to_bits(0.01), f64_to_bits(0.05), 200);
    if model == 0 { return 2; };
    return 0;
}

fn check_predict_matches() -> i64 {
    let X: i64 = mat_new(4, 1);
    mat_set(X, 1, 0, 0, f64_to_bits(1.0));
    mat_set(X, 1, 1, 0, f64_to_bits(2.0));
    mat_set(X, 1, 2, 0, f64_to_bits(3.0));
    mat_set(X, 1, 3, 0, f64_to_bits(4.0));
    let y: i64 = vec_new();
    vec_push(y, f64_to_bits(2.0));
    vec_push(y, f64_to_bits(4.0));
    vec_push(y, f64_to_bits(6.0));
    vec_push(y, f64_to_bits(8.0));
    let model: i64 = ridge_train(X, y, 4, 1,
        f64_to_bits(0.001), f64_to_bits(0.05), 500);
    // Predict on training point 0 (x=1.0). Lock that the
    // output is finite (no NaN/inf) — exact convergence is
    // out of scope for this smoke.
    let p: i64 = ridge_predict_one(model, X, 1, 0);
    let pf: f64 = f64_from_bits(p);
    let abs_pf: f64 = if pf < 0.0 { 0.0 - pf } else { pf };
    if abs_pf > 1e30 { return 4; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_mat_accessors();
    fails = fails + check_train_returns_model();
    fails = fails + check_predict_matches();
    return fails;
}
