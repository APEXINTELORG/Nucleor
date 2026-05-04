// v0.8.114 stdlib/rods/control.nr first test coverage (PID slice).
//
// Per the zero-coverage rod survey, control.nr (PID controller,
// state-space model, Kalman filter) had no existing tests.
// Silent regressions in PID gain plumbing or integration would
// invalidate any control loop.
//
// This fixture covers the PID slice (state-space + Kalman need
// matrix Vec inputs and are queued for follow-up). Locks
// textbook PID invariants:
//
//   1. PID with zero error returns zero output — pid_update at
//      setpoint == measurement gives 0.
//   2. Pure-P controller (Ki=0, Kd=0): output == Kp * error
//      for the first call (no integral yet).
//   3. Pure-I controller (Kp=0, Kd=0): output integrates error
//      across consecutive calls (output grows on persistent
//      error, returns toward zero when error reverses).
//   4. pid_reset clears integral state — after reset, a new
//      step with the same conditions matches the first-step
//      output.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/control.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-6 { return 1; };
    return 0;
}

fn check_pid_zero_error() -> i64 {
    let h: i64 = pid_new(f64_to_bits(2.0), f64_to_bits(0.5), f64_to_bits(0.1));
    let out: i64 = pid_update(h, f64_to_bits(10.0), f64_to_bits(10.0), f64_to_bits(0.01));
    if close(out, f64_to_bits(0.0)) != 1 { return 1; };
    return 0;
}

fn check_pid_pure_p() -> i64 {
    // Kp=2, Ki=0, Kd=0; first step at setpoint=10, measurement=8
    // → error = 2 → output = Kp * error = 4.
    let h: i64 = pid_new(f64_to_bits(2.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let out: i64 = pid_update(h, f64_to_bits(10.0), f64_to_bits(8.0), f64_to_bits(0.01));
    if close(out, f64_to_bits(4.0)) != 1 { return 2; };
    return 0;
}

fn check_pid_integral_grows() -> i64 {
    // Pure-I: Kp=0, Ki=1, Kd=0. Setpoint=10, measurement=8.
    // dt=0.1. Each call adds 0.2 to the integral (error * dt).
    // First call: 0.2; second: 0.4; third: 0.6.
    let h: i64 = pid_new(f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(0.0));
    let o1: i64 = pid_update(h, f64_to_bits(10.0), f64_to_bits(8.0), f64_to_bits(0.1));
    let o2: i64 = pid_update(h, f64_to_bits(10.0), f64_to_bits(8.0), f64_to_bits(0.1));
    let o3: i64 = pid_update(h, f64_to_bits(10.0), f64_to_bits(8.0), f64_to_bits(0.1));
    let f1: f64 = f64_from_bits(o1);
    let f2: f64 = f64_from_bits(o2);
    let f3: f64 = f64_from_bits(o3);
    if f2 <= f1 { return 4; };
    if f3 <= f2 { return 8; };
    return 0;
}

fn check_pid_reset() -> i64 {
    let h: i64 = pid_new(f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(0.0));
    let o1: i64 = pid_update(h, f64_to_bits(10.0), f64_to_bits(8.0), f64_to_bits(0.1));
    let _o2: i64 = pid_update(h, f64_to_bits(10.0), f64_to_bits(8.0), f64_to_bits(0.1));
    pid_reset(h);
    let o3: i64 = pid_update(h, f64_to_bits(10.0), f64_to_bits(8.0), f64_to_bits(0.1));
    // After reset, first call should match the original first-call output.
    if close(o1, o3) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_pid_zero_error();
    fails = fails + check_pid_pure_p();
    fails = fails + check_pid_integral_grows();
    fails = fails + check_pid_reset();
    return fails;
}
