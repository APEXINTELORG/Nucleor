// v0.8.218 stdlib/rods/orbit.nr first test coverage.
//
// Orbital mechanics — Kepler ↔ Cartesian, period, Hohmann
// transfer, vis-viva, escape velocity. Pre-v0.8.218: zero
// coverage on the standalone rod.
//
// Uses Earth's μ = 398600.4418 km³/s². Reference values are
// textbook (e.g., Vallado §1.4, §6.3).
//
// Locks four classical-orbit-mechanics fixed points:
//
//   1. Kepler 3rd law — period of a=7000km circular orbit
//      ≈ 5829s (LEO ~97 min).
//   2. Vis-viva at circular — v = sqrt(μ/r); for r=a=7000km
//      gives ≈ 7.546 km/s.
//   3. Escape velocity at Earth surface — v_esc =
//      sqrt(2μ/r); for r=6378km gives ≈ 11.18 km/s.
//   4. Hohmann transfer Δv positive — non-trivial transfer
//      from r1=7000 to r2=10000 has Δv > 0.
//
// Expected: rc=0.

import "stdlib/rods/orbit.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_period() -> i64 {
    let mu: i64 = f64_to_bits(398600.4418);
    let a: i64 = f64_to_bits(7000.0);
    let t: i64 = orbit_period(a, mu);
    let tf: f64 = f64_from_bits(t);
    if tf < 5800.0 { return 1; };
    if tf > 5860.0 { return 2; };
    return 0;
}

fn check_vis_viva_circular() -> i64 {
    let mu: i64 = f64_to_bits(398600.4418);
    let r: i64 = f64_to_bits(7000.0);
    let a: i64 = f64_to_bits(7000.0);
    let v: i64 = orbit_vis_viva(r, a, mu);
    if close(v, f64_to_bits(7.546), 1e-2) != 1 { return 4; };
    return 0;
}

fn check_escape_velocity() -> i64 {
    let mu: i64 = f64_to_bits(398600.4418);
    let r: i64 = f64_to_bits(6378.0);
    let v: i64 = orbit_escape_velocity(r, mu);
    if close(v, f64_to_bits(11.18), 1e-2) != 1 { return 8; };
    return 0;
}

fn check_hohmann_positive() -> i64 {
    let mu: i64 = f64_to_bits(398600.4418);
    let r1: i64 = f64_to_bits(7000.0);
    let r2: i64 = f64_to_bits(10000.0);
    let dv: i64 = orbit_hohmann(r1, r2, mu);
    let dvf: f64 = f64_from_bits(dv);
    if dvf <= 0.0 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_period();
    fails = fails + check_vis_viva_circular();
    fails = fails + check_escape_velocity();
    fails = fails + check_hohmann_positive();
    return fails;
}
