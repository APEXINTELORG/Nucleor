// UNIT-1 v0845 positive typed-unit API smoke — UnitMass.
//
// Locks the stdlib nominal UnitMass surface: constructors, accessors,
// same-dimension add/sub helpers via unit_convert_f64, explicit conversion,
// and dimension-vector identity. Library-level coverage over f64 + unit-ID
// storage, not parser-level `unit<T, dim>` algebra.

import "stdlib/rods/units.nr"

fn main() -> i32 {
    let a: UnitMass = unit_mass_kg(2.0);
    let b: UnitMass = unit_mass_g(500.0);

    if unit_mass_unit(&a) != unit_kg() { return 1; };
    if (unit_mass_value(&a) as i32) != 2 { return 2; };

    let b_kg: f64 = unit_mass_value_as(&b, unit_kg());
    let b_g_back: f64 = unit_mass_value_as(&b, unit_g());
    if (b_g_back as i32) != 500 { return 3; };

    let sum: UnitMass = unit_mass_add(&a, &b);
    if unit_mass_unit(&sum) != unit_kg() { return 4; };
    let sum_g: f64 = unit_mass_value_as(&sum, unit_g());
    if (sum_g as i32) != 2500 { return 5; };

    let c: UnitMass = unit_mass_g(500.0);
    let diff: UnitMass = unit_mass_sub(&a, &c);
    let diff_g: f64 = unit_mass_value_as(&diff, unit_g());
    if (diff_g as i32) != 1500 { return 6; };

    if dim_eq(unit_mass_dim(), dim_kg()) == 0 { return 7; };

    if (b_kg * 1000.0) as i32 != 500 { return 8; };

    print("OK unit_mass_positive_smoke");
    return 0;
}
