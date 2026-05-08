// Lane 6 / F-NUM-002 (audit 2026-05-08): same-dimension conversions
// must continue to work after the runtime dim-check wiring. The
// negative path (cross-dim panic) is exercised by the standalone
// runtime-fail probe; this test pins the positive path.
import "stdlib/rods/units.nr"

fn approx_eq(a: f64, b: f64, eps: f64) -> i64 {
    let d: f64 = a - b;
    let ad: f64 = if d < 0.0 { 0.0 - d } else { d };
    if ad <= eps { return 1; };
    return 0;
}

fn main() -> i64 {
    let mut fail: i64 = 0;
    // Length: meters <-> millimeters
    let mm: f64 = unit_convert_f64(2.5, unit_m(), unit_mm());
    if approx_eq(mm, 2500.0, 1e-9) == 0 { fail = fail + 1; print("FAIL m->mm"); };
    // Time: hours -> seconds
    let s: f64 = unit_convert_f64(1.0, unit_hr(), unit_s());
    if approx_eq(s, 3600.0, 1e-9) == 0 { fail = fail + 1; print("FAIL hr->s"); };
    // Pressure: kPa -> Pa
    let pa: f64 = unit_convert_f64(101.325, unit_kPa(), unit_Pa());
    if approx_eq(pa, 101325.0, 1e-6) == 0 { fail = fail + 1; print("FAIL kPa->Pa"); };
    if fail == 0 { print("OK lane6_units_legit"); };
    return fail;
}
