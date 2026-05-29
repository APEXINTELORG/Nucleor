// v0.8.166 stdlib/rods/units.nr first test coverage.
//
// Runtime SI-unit conversion: length, mass, time, temperature.
// Pre-v0.8.166: zero coverage on the units rod (sister to the
// V2.2 RFC-0047 typed-dim audit at v0.8.146 — the audit
// surfaces type-position usage; THIS rod converts values).
//
// Locks five textbook unit-conversion invariants:
//   1. 1 km == 1000 m (length scale).
//   2. 1 kg == 1000 g (mass scale).
//   3. 1 hr == 3600 s (time scale).
//   4. 0 °C == 273.15 K (temperature offset, NOT scale).
//   5. 32 °F == 0 °C (Fahrenheit zero point).
//
// All compares are within 1e-6 absolute tolerance.
//
// Expected: rc=0.

import "stdlib/rods/units.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_length() -> i64 {
    let r: i64 = nuc_unit_convert(f64_to_bits(1.0), unit_km(), unit_m());
    if close(r, f64_to_bits(1000.0), 1e-6) != 1 { return 1; };
    return 0;
}

fn check_mass() -> i64 {
    let r: i64 = nuc_unit_convert(f64_to_bits(1.0), unit_kg(), unit_g());
    if close(r, f64_to_bits(1000.0), 1e-6) != 1 { return 2; };
    return 0;
}

fn check_time() -> i64 {
    let r: i64 = nuc_unit_convert(f64_to_bits(1.0), unit_hr(), unit_s());
    if close(r, f64_to_bits(3600.0), 1e-6) != 1 { return 4; };
    return 0;
}

fn check_celsius_to_kelvin() -> i64 {
    let r: i64 = nuc_unit_convert(f64_to_bits(0.0), unit_C(), unit_K());
    if close(r, f64_to_bits(273.15), 1e-6) != 1 { return 8; };
    return 0;
}

fn check_fahrenheit_to_celsius() -> i64 {
    let r: i64 = nuc_unit_convert(f64_to_bits(32.0), unit_F(), unit_C());
    if close(r, f64_to_bits(0.0), 1e-6) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_length();
    fails = fails + check_mass();
    fails = fails + check_time();
    fails = fails + check_celsius_to_kelvin();
    fails = fails + check_fahrenheit_to_celsius();
    return fails;
}
