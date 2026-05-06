// QM-7 Phase 2b - rotated surface-code d=3 Surface-17 smoke.
//
// Stabilizers/logicals are from Tomita/Svore PRA 90, 062320 (2014),
// Table II for surface-13/surface-17:
//   X checks: X0 X1 X3 X4, X1 X2, X4 X5 X7 X8, X6 X7
//   Z checks: Z0 Z3, Z1 Z2 Z4 Z5, Z3 Z4 Z6 Z7, Z5 Z8
//   logicals: XL = X2 X4 X6, ZL = Z0 Z4 Z8
//
// The Pauli Vec layout is [x0, z0, x1, z1, ...]. Expected rc=0.

import "stdlib/rods/clifford.nr"

fn pauli_surface17_x0134() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(1); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    return p;
}

fn pauli_surface17_x12() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    return p;
}

fn pauli_surface17_x4578() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(1); p.push(0);
    return p;
}

fn pauli_surface17_x67() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    return p;
}

fn pauli_surface17_z03() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(1);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(1);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    return p;
}

fn pauli_surface17_z1245() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(0);
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    p.push(0); p.push(0);
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    return p;
}

fn pauli_surface17_z3467() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    p.push(0); p.push(0);
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    p.push(0); p.push(0);
    return p;
}

fn pauli_surface17_z58() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(1);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(1);
    return p;
}

fn logical_surface17_x246() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    return p;
}

fn logical_surface17_z048() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(1);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(1);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(1);
    return p;
}

fn single_x0() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    return p;
}

fn build_surface17() -> i64 {
    let h: i64 = cliff_init_code(9);
    if h == 0 { return 0; };

    if cliff_add_stabilizer(h, pauli_surface17_x0134()) != 1 { cliff_free(h); return 0; };
    if cliff_add_stabilizer(h, pauli_surface17_x12()) != 1 { cliff_free(h); return 0; };
    if cliff_add_stabilizer(h, pauli_surface17_x4578()) != 1 { cliff_free(h); return 0; };
    if cliff_add_stabilizer(h, pauli_surface17_x67()) != 1 { cliff_free(h); return 0; };
    if cliff_add_stabilizer(h, pauli_surface17_z03()) != 1 { cliff_free(h); return 0; };
    if cliff_add_stabilizer(h, pauli_surface17_z1245()) != 1 { cliff_free(h); return 0; };
    if cliff_add_stabilizer(h, pauli_surface17_z3467()) != 1 { cliff_free(h); return 0; };
    if cliff_add_stabilizer(h, pauli_surface17_z58()) != 1 { cliff_free(h); return 0; };

    return h;
}

fn main() -> i64 {
    let h: i64 = build_surface17();
    if h == 0 { return 1; };

    if cliff_nq(h) != 9 { cliff_free(h); return 2; };
    if cliff_num_stabilizers(h) != 8 { cliff_free(h); return 3; };
    if cliff_distance(h, 1) != 3 { cliff_free(h); return 4; };
    if cliff_count_errors(h) != 27 { cliff_free(h); return 5; };
    if cliff_error_detectable(h, logical_surface17_x246()) != 0 { cliff_free(h); return 7; };
    if cliff_error_detectable(h, logical_surface17_z048()) != 0 { cliff_free(h); return 8; };
    if cliff_error_detectable(h, single_x0()) != 1 { cliff_free(h); return 9; };

    cliff_free(h);
    return 0;
}
