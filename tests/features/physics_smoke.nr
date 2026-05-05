// v0.8.221 stdlib/rods/physics.nr first test coverage.
//
// CODATA 2018 physical constants (speed of light, Planck,
// Boltzmann, electron mass, etc.). Pre-v0.8.221: zero coverage
// on the standalone rod.
//
// Locks four CODATA-2018 invariants. Reference values (SI):
//   c     = 299792458 m/s (exact, defined)
//   h     = 6.62607015e-34 J·s (exact, defined since 2019)
//   kb    = 1.380649e-23 J/K (exact, defined since 2019)
//   π     = 3.14159265358979...
//
// Locks:
//
//   1. **Speed of light c is exact** — exactly 299792458 m/s
//      (1983 SI redefinition).
//   2. **Planck h ≈ 6.626e-34** — exact since 2019 redefinition.
//   3. **Boltzmann kb ≈ 1.381e-23** — exact since 2019.
//   4. **π matches std math** — within 1e-15 of 3.14159265358979.
//
// Expected: rc=0.

import "stdlib/rods/physics.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_speed_of_light() -> i64 {
    let c: i64 = const_c();
    if close(c, f64_to_bits(299792458.0), 1.0) != 1 { return 1; };
    return 0;
}

fn check_planck() -> i64 {
    let h: f64 = f64_from_bits(const_h());
    // h ≈ 6.62607e-34 — relative tolerance, scale by 1e-34
    if h < 6.62e-34 { return 2; };
    if h > 6.63e-34 { return 4; };
    return 0;
}

fn check_boltzmann() -> i64 {
    let kb: f64 = f64_from_bits(const_kb());
    // kb ≈ 1.380649e-23
    if kb < 1.380e-23 { return 8; };
    if kb > 1.381e-23 { return 16; };
    return 0;
}

fn check_pi() -> i64 {
    if close(const_pi(), f64_to_bits(3.141592653589793), 1e-15) != 1 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_speed_of_light();
    fails = fails + check_planck();
    fails = fails + check_boltzmann();
    fails = fails + check_pi();
    return fails;
}
