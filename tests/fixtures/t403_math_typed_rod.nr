// t403_math_typed_rod.nr — v0.3.127 NUC-IMPROVE-005 fixture.
//
// Pins the `stdlib/rods/math_typed.nr` typed-f64 elementary math
// rod requested by the ML suite in NUC-IMPROVE-005. The rod
// wraps the existing bit-pattern math runtime helpers (`sqrt`,
// `exp`, `log`, `tanh`, `sin`, `cos`, `pow`) with explicit
// `f64 -> f64` signatures so ML/scientific code using typed
// arithmetic can call elementary functions directly.
//
// At the runtime ABI level Nucleor's f64 IS the i64 bit pattern,
// so each wrapper is a one-line identity around the existing
// helper. The named entries document intent at the call site.
//
// Returns 0 when sqrt(2) ≈ 1.414 within tolerance. Non-zero
// diagnostic codes pinpoint which wrapper miscomputed.

import "stdlib/rods/math_typed.nr"

fn main() -> i64 {
    let r1: f64 = sqrt_f64(2.0);
    if r1 < 1.41 { return 1; };
    if r1 > 1.42 { return 2; };
    let r2: f64 = exp_f64(0.0);
    if r2 < 0.99 { return 3; };
    if r2 > 1.01 { return 4; };
    let r3: f64 = log_f64(1.0);
    if r3 < 0.0 - 0.001 { return 5; };
    if r3 > 0.001 { return 6; };
    return 0;
}
