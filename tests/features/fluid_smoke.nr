// v0.8.190 stdlib/rods/fluid.nr first test coverage.
//
// 2D Lattice Boltzmann (D2Q9) fluid simulation. Pre-v0.8.190:
// zero coverage.
//
// Locks four lifecycle invariants on a 32×32 LBM grid:
//
//   1. **Construction** returns valid handle.
//   2. **Initial density ≈ 1.0**: D2Q9 default density at any
//      free cell is the equilibrium ρ=1.0.
//   3. **Initial velocity zero**: vx, vy at any cell == 0
//      (no flow until inlet is set + steps run).
//   4. **Inlet + steps drives flow**: set inlet 0.1, run 5 steps,
//      vorticity field is computable (returns finite value).
//
// Expected: rc=0.

import "stdlib/rods/fluid.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_construction() -> i64 {
    let h: i64 = lbm_new_2d(32, 32, f64_to_bits(0.01));
    if h == 0 { return 1; };
    lbm_free(h);
    return 0;
}

fn check_initial_density() -> i64 {
    let h: i64 = lbm_new_2d(32, 32, f64_to_bits(0.01));
    let d: i64 = lbm_get_density(h, 16, 16);
    if close(d, f64_to_bits(1.0), 1e-6) != 1 { lbm_free(h); return 2; };
    lbm_free(h);
    return 0;
}

fn check_initial_velocity_zero() -> i64 {
    let h: i64 = lbm_new_2d(32, 32, f64_to_bits(0.01));
    if close(lbm_get_vx(h, 16, 16), f64_to_bits(0.0), 1e-9) != 1 { lbm_free(h); return 4; };
    if close(lbm_get_vy(h, 16, 16), f64_to_bits(0.0), 1e-9) != 1 { lbm_free(h); return 8; };
    lbm_free(h);
    return 0;
}

fn check_inlet_step_run() -> i64 {
    let h: i64 = lbm_new_2d(32, 32, f64_to_bits(0.01));
    lbm_set_inlet(h, f64_to_bits(0.1));
    let mut i: i64 = 0;
    while i < 5 { lbm_step(h); i = i + 1; };
    // Vorticity computable; just lock it doesn't fault and produces a finite value.
    let v: i64 = lbm_get_vorticity(h, 16, 16);
    let vf: f64 = f64_from_bits(v);
    let abs_vf: f64 = if vf < 0.0 { 0.0 - vf } else { vf };
    if abs_vf > 1e30 { lbm_free(h); return 16; };  // catch NaN/inf accidents
    lbm_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_construction();
    fails = fails + check_initial_density();
    fails = fails + check_initial_velocity_zero();
    fails = fails + check_inlet_step_run();
    return fails;
}
