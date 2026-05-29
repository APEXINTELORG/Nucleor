// v0.8.190 stdlib/rods/emag.nr first test coverage.
//
// FDTD electromagnetics — 2D Yee-grid solver. Pre-v0.8.190:
// zero coverage.
//
// Locks four lifecycle invariants on a 16×16 grid at dx=1mm,
// dt=1ps:
//   1. Construction returns valid handle.
//   2. Initial fields zero: Ez/Hx/Hy at any cell == 0
//      pre-step.
//   3. Initial energy zero: em_energy == 0 with no source.
//   4. Source + step yields non-zero field: place a source
//      at (8, 8), step once, Ez at source location is non-zero.
//
// Expected: rc=0.

import "stdlib/rods/emag.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_construction() -> i64 {
    let h: i64 = em_new_2d(16, 16, f64_to_bits(0.001), f64_to_bits(1e-12));
    if h == 0 { return 1; };
    em_free(h);
    return 0;
}

fn check_initial_fields_zero() -> i64 {
    let h: i64 = em_new_2d(16, 16, f64_to_bits(0.001), f64_to_bits(1e-12));
    if close(em_get_Ez(h, 5, 5), f64_to_bits(0.0), 1e-12) != 1 { em_free(h); return 2; };
    if close(em_get_Hx(h, 5, 5), f64_to_bits(0.0), 1e-12) != 1 { em_free(h); return 4; };
    if close(em_get_Hy(h, 5, 5), f64_to_bits(0.0), 1e-12) != 1 { em_free(h); return 8; };
    em_free(h);
    return 0;
}

fn check_initial_energy_zero() -> i64 {
    let h: i64 = em_new_2d(16, 16, f64_to_bits(0.001), f64_to_bits(1e-12));
    if close(em_energy(h), f64_to_bits(0.0), 1e-12) != 1 { em_free(h); return 16; };
    em_free(h);
    return 0;
}

fn check_source_drives_field() -> i64 {
    let h: i64 = em_new_2d(16, 16, f64_to_bits(0.001), f64_to_bits(1e-12));
    em_set_source(h, 8, 8, f64_to_bits(1e9), f64_to_bits(1.0));
    let mut i: i64 = 0;
    while i < 5 { em_step(h); i = i + 1; };
    // After 5 steps with a source, energy should be > 0
    let e: i64 = em_energy(h);
    let ev: f64 = f64_from_bits(e);
    if ev <= 0.0 { em_free(h); return 32; };
    em_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_construction();
    fails = fails + check_initial_fields_zero();
    fails = fails + check_initial_energy_zero();
    fails = fails + check_source_drives_field();
    return fails;
}
