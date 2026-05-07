// UNIT-1 positive typed-unit API smoke.
//
// Locks the stdlib nominal UnitDistance surface: constructors,
// accessors, same-dimension add/sub helpers, explicit conversion,
// and dimension-vector identity. This is library-level coverage over
// f64 + unit-ID storage, not parser-level `unit<T, dim>` algebra.

import "stdlib/rods/units.nr"

fn main() -> i32 {
    let a: UnitDistance = unit_distance_m(2.0);
    let b: UnitDistance = unit_distance_km(1.0);

    if unit_distance_unit(&a) != unit_m() { return 1; };
    if (unit_distance_value(&a) as i32) != 2 { return 2; };

    let b_m: f64 = unit_distance_value_as(&b, unit_m());
    if (b_m as i32) != 1000 { return 3; };

    let sum: UnitDistance = unit_distance_add(&a, &b);
    if unit_distance_unit(&sum) != unit_m() { return 4; };
    if (unit_distance_value(&sum) as i32) != 1002 { return 5; };

    let c: UnitDistance = unit_distance_cm(250.0);
    let diff: UnitDistance = unit_distance_sub(&a, &c);
    let diff_mm: f64 = unit_distance_value_as(&diff, unit_mm());
    if (diff_mm as i32) != -500 { return 6; };

    if dim_eq(unit_distance_dim(), dim_m()) == 0 { return 7; };

    print("OK unit_distance_positive_smoke");
    return 0;
}
