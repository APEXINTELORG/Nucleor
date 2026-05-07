// UNIT-1 v0845 positive typed-unit API smoke — UnitTime.
//
// Locks the stdlib nominal UnitTime surface: constructors, accessors,
// same-dimension add/sub helpers via unit_convert_f64, explicit conversion,
// and dimension-vector identity. Library-level coverage over f64 + unit-ID
// storage, not parser-level `unit<T, dim>` algebra.

import "stdlib/rods/units.nr"

fn main() -> i32 {
    let a: UnitTime = unit_time_s(2.0);
    let b: UnitTime = unit_time_min(1.0);

    if unit_time_unit(&a) != unit_s() { return 1; };
    if (unit_time_value(&a) as i32) != 2 { return 2; };

    let b_s: f64 = unit_time_value_as(&b, unit_s());
    if (b_s as i32) != 60 { return 3; };

    let sum: UnitTime = unit_time_add(&a, &b);
    if unit_time_unit(&sum) != unit_s() { return 4; };
    if (unit_time_value(&sum) as i32) != 62 { return 5; };

    let c: UnitTime = unit_time_ms(500.0);
    let diff: UnitTime = unit_time_sub(&a, &c);
    let diff_ms: f64 = unit_time_value_as(&diff, unit_ms());
    if (diff_ms as i32) != 1500 { return 6; };

    if dim_eq(unit_time_dim(), dim_s()) == 0 { return 7; };

    print("OK unit_time_positive_smoke");
    return 0;
}
