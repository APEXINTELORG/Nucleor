// v0.8.141 stdlib/rods/control.nr first test coverage.
//
// PID controller, state-space, Kalman filter. Foundational for
// any robotics, signal-processing, or guidance-control workload.
// Pre-v0.8.141: zero coverage.
//
// Locks three textbook PID invariants:
//   1. Pure-proportional: pid_new(Kp=2, Ki=0, Kd=0) →
//      update(setpoint=10, measurement=4, dt=*) returns Kp*error
//      = 2*6 = 12.
//   2. Zero error → zero output: setpoint == measurement, fresh
//      controller (no accumulated integral, no prior derivative)
//      → output ≈ 0.
//   3. Reset clears integral: a saturated integral does not
//      survive `pid_reset`. After reset, zero-error update
//      returns ≈ 0 even if integral was previously wound up.
//
// State-space + Kalman take Vec<i64> matrix handles which need
// matrix-flatten setup outside the smoke scope.
//
// Expected: rc=0.

import "stdlib/rods/control.nr"

fn close_bits(a: i64, b: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_pure_proportional() -> i64 {
    let pid: i64 = pid_new(f64_to_bits(2.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let out: i64 = pid_update(pid, f64_to_bits(10.0), f64_to_bits(4.0), f64_to_bits(0.01));
    // Expect Kp * (10 - 4) = 12
    if close_bits(out, f64_to_bits(12.0), 1e-6) != 1 { return 1; };
    return 0;
}

fn check_zero_error_zero_output() -> i64 {
    let pid: i64 = pid_new(f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));
    let out: i64 = pid_update(pid, f64_to_bits(5.0), f64_to_bits(5.0), f64_to_bits(0.1));
    if close_bits(out, f64_to_bits(0.0), 1e-6) != 1 { return 2; };
    return 0;
}

fn check_reset_clears_integral() -> i64 {
    let pid: i64 = pid_new(f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(0.0));
    // Wind up the integral with several non-zero-error updates.
    let mut i: i64 = 0;
    while i < 10 {
        pid_update(pid, f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.1));
        i = i + 1;
    };
    // At this point integral is large.
    pid_reset(pid);
    // After reset, a zero-error update should produce ≈ 0 output.
    let out: i64 = pid_update(pid, f64_to_bits(5.0), f64_to_bits(5.0), f64_to_bits(0.1));
    if close_bits(out, f64_to_bits(0.0), 1e-6) != 1 { return 4; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_pure_proportional();
    fails = fails + check_zero_error_zero_output();
    fails = fails + check_reset_clears_integral();
    return fails;
}
