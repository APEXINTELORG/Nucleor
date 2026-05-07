// UNIT-1 positive typed-unit API smoke.
//
// Locks the stdlib nominal UnitVelocity surface: m/s and km/hr
// constructors, distance-over-time construction, accessors, explicit
// conversion, same-dimension arithmetic, and dimension-vector identity.

import "stdlib/rods/units.nr"

fn main() -> i32 {
    let v1: UnitVelocity = unit_velocity_mps(10.0);
    let v2: UnitVelocity = unit_velocity_km_per_hr(36.0);

    if unit_velocity_distance_unit(&v1) != unit_m() { return 1; };
    if unit_velocity_time_unit(&v1) != unit_s() { return 2; };
    if (unit_velocity_value(&v1) as i32) != 10 { return 3; };

    let v2_mps: f64 = unit_velocity_value_mps(&v2);
    if (v2_mps as i32) != 10 { return 4; };

    let v1_kmh: f64 = unit_velocity_value_as(&v1, unit_km(), unit_hr());
    if (v1_kmh as i32) != 36 { return 5; };

    let d: UnitDistance = unit_distance_m(30.0);
    let v3: UnitVelocity = unit_velocity_from_distance_time(&d, 3.0, unit_s());
    if (unit_velocity_value_mps(&v3) as i32) != 10 { return 6; };

    let sum: UnitVelocity = unit_velocity_add(&v1, &v2);
    if (unit_velocity_value_mps(&sum) as i32) != 20 { return 7; };

    let diff: UnitVelocity = unit_velocity_sub(&sum, &v3);
    if (unit_velocity_value_mps(&diff) as i32) != 10 { return 8; };

    if dim_eq(unit_velocity_dim(), dim_velocity()) == 0 { return 9; };

    print("OK unit_velocity_positive_smoke");
    return 0;
}
