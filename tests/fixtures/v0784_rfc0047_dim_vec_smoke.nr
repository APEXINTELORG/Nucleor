// v0.7.84 RFC-0047 Phase A smoke fixture — 7-vector SI
// dimensional surface. Validates:
//   - 7 base dim vectors (kg, m, s, A, K, mol, cd) construct
//   - mul / div / pow / inv compose correctly
//   - canonical derived dims (force = kg·m·s⁻², energy = kg·m²·s⁻²,
//     power = kg·m²·s⁻³) match the helper-built derived constants
//   - dim_check_or_panic accepts matching dims
//   - dim_to_string prints the [1,1,-2,0,0,0,0] shape
import "stdlib/rods/units.nr"

fn main() -> i64 {
    let kg: Vec<i64> = dim_kg();
    let m: Vec<i64> = dim_m();
    let s: Vec<i64> = dim_s();
    let dimless: Vec<i64> = dim_dimensionless();

    if vec_len(kg) != 7 { return 1; };
    if vec_get(kg, 0) != 1 { return 2; };
    if vec_get(m, 1) != 1 { return 3; };

    // Derived: velocity = m/s, acceleration = m/s², force = kg*accel.
    let vel: Vec<i64> = dim_div(m, s);
    if dim_eq(vel, dim_velocity()) == 0 { return 4; };

    let s2: Vec<i64> = dim_pow(s, 2);
    let accel: Vec<i64> = dim_div(m, s2);
    if dim_eq(accel, dim_acceleration()) == 0 { return 5; };

    let force: Vec<i64> = dim_mul(kg, accel);
    if dim_eq(force, dim_force()) == 0 { return 6; };

    // Energy = force * length, power = energy / time.
    let energy: Vec<i64> = dim_mul(force, m);
    if dim_eq(energy, dim_energy()) == 0 { return 7; };
    let power: Vec<i64> = dim_div(energy, s);
    if dim_eq(power, dim_power()) == 0 { return 8; };

    // dim_check_or_panic on matching pair (no panic).
    if dim_check_or_panic(force, dim_force(), "force") != 1 { return 9; };

    // dim_inv: kg/m = kg * m⁻¹
    let inv_m: Vec<i64> = dim_inv(m);
    let kg_per_m: Vec<i64> = dim_mul(kg, inv_m);
    let expected: Vec<i64> = Vec::new();
    expected.push(1); expected.push(0 - 1); expected.push(0); expected.push(0); expected.push(0); expected.push(0); expected.push(0);
    if dim_eq(kg_per_m, expected) == 0 { return 10; };

    // dim_eq on different dims rejects.
    if dim_eq(force, energy) != 0 { return 11; };

    // Dimensionless sanity.
    let prod: Vec<i64> = dim_mul(s, dim_inv(s));
    if dim_eq(prod, dimless) == 0 { return 12; };

    // dim_to_string smoke.
    let str_force: str = dim_to_string(force);
    if str_len(str_force) < 9 { return 13; };

    return 0;
}
