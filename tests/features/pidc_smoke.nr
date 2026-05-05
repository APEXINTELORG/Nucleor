// v0.8.222 stdlib/rods/pidc.nr first test coverage.
//
// Classic PID controller with anti-windup integral clamp +
// output clamp. Pre-v0.8.222: zero coverage on the standalone
// rod (sister to control.nr's simpler PID).
//
// Locks four control-theory invariants:
//
//   1. **P-only on zero error gives zero output** — setpoint ==
//      measurement → e = 0 → u = 0.
//   2. **P-only with kp=2, e=3 gives u=6** — first-step output
//      is purely proportional (i and d both 0 on first tick).
//   3. **Output clamp saturates** — kp=10, e=10, but u_clamp
//      [-1, 1] forces u=1 (the output's hard ceiling).
//   4. **Reset clears integral** — non-zero integral after a
//      step → reset → integral == 0.
//
// Expected: rc=0.

import "stdlib/rods/pidc.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_zero_error_zero_output() -> i64 {
    let p: i64 = pidc_new(f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let u: i64 = pidc_step(p, f64_to_bits(5.0), f64_to_bits(5.0), f64_to_bits(0.01));
    pidc_free(p);
    if close(u, f64_to_bits(0.0), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_p_only_step() -> i64 {
    let p: i64 = pidc_new(f64_to_bits(2.0), f64_to_bits(0.0), f64_to_bits(0.0));
    // setpoint=5, meas=2, e=3 → u = 2 * 3 = 6
    let u: i64 = pidc_step(p, f64_to_bits(5.0), f64_to_bits(2.0), f64_to_bits(0.01));
    pidc_free(p);
    if close(u, f64_to_bits(6.0), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_output_clamp() -> i64 {
    let p: i64 = pidc_new(f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0));
    pidc_set_output_clamp(p, f64_to_bits(0.0 - 1.0), f64_to_bits(1.0));
    // setpoint=10, meas=0, e=10, u_unclamped = 100, clamps to 1
    let u: i64 = pidc_step(p, f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.01));
    pidc_free(p);
    if close(u, f64_to_bits(1.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_reset_clears_integral() -> i64 {
    let p: i64 = pidc_new(f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(0.0));
    // Build up a non-zero integral
    pidc_step(p, f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.1));
    pidc_step(p, f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.1));
    let i_before: f64 = f64_from_bits(pidc_integral(p));
    if i_before == 0.0 { pidc_free(p); return 8; };
    pidc_reset(p);
    let i_after: i64 = pidc_integral(p);
    pidc_free(p);
    if close(i_after, f64_to_bits(0.0), 1e-9) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_zero_error_zero_output();
    fails = fails + check_p_only_step();
    fails = fails + check_output_clamp();
    fails = fails + check_reset_clears_integral();
    return fails;
}
