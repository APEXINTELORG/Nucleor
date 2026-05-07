// QM-7 Phase 2c - bounded Clifford weight-enumerator smoke.
//
// Locks the public stabilizer/logical weight-count surface on the existing
// rotated Surface-17 d=3 fixture. The expected counts are exhaustive internal
// consistency counts over the explicit generator set below; they are not
// marketed as external published enumerator parity.
//
// Citation chain (v0845): the Surface-17 stabilizer set used here is the
// SAME set carried by qm7_clifford_surface_d3_smoke.nr, whose generators
// are taken from Tomita and Svore, "Low-distance surface codes under
// realistic quantum noise," Phys. Rev. A 90, 062320 (2014), Table II.
// The weight-enumerator counts asserted by check_surface17_stabilizer_counts
// and check_surface17_logical_counts are exhaustive deterministic
// consequences of that cited generator set, computed by
// cliff_stabilizer_weight_count / cliff_logical_weight_count over all 2^k
// stabilizer / logical-coset elements respectively. No separate external
// published enumerator value is asserted here; the citation is for the
// generator set, and the runtime math is the source of truth for the counts.
//
// Pauli Vec layout is [x0, z0, x1, z1, ...]. Expected rc=0.

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

fn check_surface17_stabilizer_counts(h: i64) -> i64 {
    if cliff_stabilizer_weight_count(h, 0) != 1 { return 10; };
    if cliff_stabilizer_weight_count(h, 1) != 0 { return 11; };
    if cliff_stabilizer_weight_count(h, 2) != 4 { return 12; };
    if cliff_stabilizer_weight_count(h, 3) != 0 { return 13; };
    if cliff_stabilizer_weight_count(h, 4) != 22 { return 14; };
    if cliff_stabilizer_weight_count(h, 5) != 0 { return 15; };
    if cliff_stabilizer_weight_count(h, 6) != 100 { return 16; };
    if cliff_stabilizer_weight_count(h, 7) != 0 { return 17; };
    if cliff_stabilizer_weight_count(h, 8) != 129 { return 18; };
    if cliff_stabilizer_weight_count(h, 9) != 0 { return 19; };

    let total: i64 =
        cliff_stabilizer_weight_count(h, 0) +
        cliff_stabilizer_weight_count(h, 2) +
        cliff_stabilizer_weight_count(h, 4) +
        cliff_stabilizer_weight_count(h, 6) +
        cliff_stabilizer_weight_count(h, 8);
    if total != 256 { return 20; };
    return 0;
}

fn check_surface17_logical_counts(h: i64) -> i64 {
    if cliff_logical_weight_count(h, 1, 0) != 0 { return 30; };
    if cliff_logical_weight_count(h, 1, 1) != 0 { return 31; };
    if cliff_logical_weight_count(h, 1, 2) != 0 { return 32; };
    if cliff_logical_weight_count(h, 1, 3) != 24 { return 33; };
    if cliff_logical_weight_count(h, 1, 4) != 0 { return 34; };
    if cliff_logical_weight_count(h, 1, 5) != 192 { return 35; };
    if cliff_logical_weight_count(h, 1, 6) != 0 { return 36; };
    if cliff_logical_weight_count(h, 1, 7) != 408 { return 37; };
    if cliff_logical_weight_count(h, 1, 8) != 0 { return 38; };
    if cliff_logical_weight_count(h, 1, 9) != 144 { return 39; };

    let total: i64 =
        cliff_logical_weight_count(h, 1, 3) +
        cliff_logical_weight_count(h, 1, 5) +
        cliff_logical_weight_count(h, 1, 7) +
        cliff_logical_weight_count(h, 1, 9);
    if total != 768 { return 40; };
    return 0;
}

fn main() -> i64 {
    if cliff_weight_enumerator_max_qubits() < 9 { return 1; };

    let h: i64 = build_surface17();
    if h == 0 { return 2; };
    if cliff_num_stabilizers(h) != 8 { cliff_free(h); return 3; };
    if cliff_distance(h, 1) != 3 { cliff_free(h); return 4; };

    let sr: i64 = check_surface17_stabilizer_counts(h);
    if sr != 0 { cliff_free(h); return sr; };
    let lr: i64 = check_surface17_logical_counts(h);
    if lr != 0 { cliff_free(h); return lr; };

    cliff_free(h);
    return 0;
}
