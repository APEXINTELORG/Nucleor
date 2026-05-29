// v0.8.179 stdlib/rods/taylor.nr first test coverage.
//
// Validated Taylor Model ODE integrator (Boussinesq /
// Navier-Stokes class). Pre-v0.8.179: zero coverage on the
// rod surface (the runtime is heavily exercised by the
// Boussinesq research workstream).
//
// Locks four lifecycle invariants — full numerical convergence
// is heavy and out-of-scope for a unit smoke. Here we lock
// that the integrator initializes, accepts initial-condition
// setters, and tracks step count + time.
//
//   1. Init returns success: tm_init(N=8, order=3) → 1.
//   2. Initial state: tm_get_steps() == 0, tm_get_time() ≈ 0.
//   3. Setters: set_nu, set_omega, set_theta complete without
//      faulting (no return code; lock by absence of crash).
//   4. Step advances: a single tm_step advances steps to 1.
//
// Expected: rc=0.

import "stdlib/rods/taylor.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_init() -> i64 {
    let r: i64 = tm_init(8, 3);
    if r != 1 { return 1; };
    return 0;
}

fn check_initial_state() -> i64 {
    tm_init(8, 3);
    if tm_get_steps() != 0 { return 2; };
    let t_bits: i64 = tm_get_time();
    if close(t_bits, f64_to_bits(0.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_setters() -> i64 {
    tm_init(8, 3);
    tm_set_nu(f64_to_bits(0.001));
    tm_set_omega(0, 0, f64_to_bits(0.5));
    tm_set_theta(0, 0, f64_to_bits(0.1));
    // No-fault is the lock; if any of the above crashed we
    // wouldn't reach here.
    return 0;
}

fn check_step_advances() -> i64 {
    tm_init(8, 3);
    tm_set_nu(f64_to_bits(0.01));
    let r: i64 = tm_step(f64_to_bits(0.001), 1);
    // Allow either 0 or 1 returned — different impls signal
    // success differently. Lock that steps counter increments.
    let _ = r;
    if tm_get_steps() < 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_init();
    fails = fails + check_initial_state();
    fails = fails + check_setters();
    fails = fails + check_step_advances();
    return fails;
}
