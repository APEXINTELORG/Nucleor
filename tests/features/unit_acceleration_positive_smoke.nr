// UNIT-1 v0845 positive typed-unit API smoke — UnitAcceleration.
//
// Locks the stdlib nominal UnitAcceleration surface: canonical-mps2
// constructor, dimension-safe construction from a UnitVelocity / elapsed
// time pair, accessors, same-dimension add/sub helpers, explicit
// conversion to non-canonical (distance, time) views, and dimension-vector
// identity. Library-level coverage over f64 + unit-ID storage, not
// parser-level `unit<T, dim>` algebra.

import "stdlib/rods/units.nr"

fn main() -> i32 {
    // Canonical mps^2 constructor.
    let g: UnitAcceleration = unit_acceleration_mps2(10.0);
    if unit_acceleration_distance_unit(&g) != unit_m() { return 1; };
    if unit_acceleration_time_unit(&g) != unit_s() { return 2; };
    if (unit_acceleration_value(&g) as i32) != 10 { return 3; };

    if dim_eq(unit_acceleration_dim(), dim_acceleration()) == 0 { return 4; };

    // Dimension-safe construction: 20 m/s velocity reached in 2 s = 10 m/s^2.
    let v: UnitVelocity = unit_velocity_mps(20.0);
    let a_from_vt: UnitAcceleration = unit_acceleration_from_velocity_time(&v, 2.0, unit_s());
    if (unit_acceleration_value_mps2(&a_from_vt) as i32) != 10 { return 5; };

    // Same construction from a non-canonical time unit (1000 ms = 1 s).
    let a_from_vt_ms: UnitAcceleration = unit_acceleration_from_velocity_time(&v, 1000.0, unit_ms());
    if (unit_acceleration_value_mps2(&a_from_vt_ms) as i32) != 20 { return 6; };

    // Explicit conversion to a non-canonical pair: m/s^2 -> km/(min^2).
    // 10 m/s^2 = 10 * (60^2) / 1000 km/min^2 = 36 km/min^2.
    let g_km_min2: f64 = unit_acceleration_value_as(&g, unit_km(), unit_min());
    if (g_km_min2 as i32) != 36 { return 7; };

    // Same-dimension add via different (distance, time) views.
    let g2: UnitAcceleration = unit_acceleration_mps2(2.0);
    let total: UnitAcceleration = unit_acceleration_add(&g, &g2);
    if (unit_acceleration_value_mps2(&total) as i32) != 12 { return 8; };

    let g3: UnitAcceleration = unit_acceleration_mps2(3.0);
    let diff: UnitAcceleration = unit_acceleration_sub(&g, &g3);
    if (unit_acceleration_value_mps2(&diff) as i32) != 7 { return 9; };

    print("OK unit_acceleration_positive_smoke");
    return 0;
}
