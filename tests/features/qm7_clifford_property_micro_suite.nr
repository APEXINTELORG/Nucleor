// QM-7 Phase 2d - bounded Clifford property micro-suite.
//
// Adds deterministic breadth without randomized search:
//   1. clone/reset isolation after Bell construction;
//   2. H^2, X^2, and CNOT^2 identity sequence on a small register;
//   3. [[5,1,3]] perfect-code distance and detectable-error stability;
//   4. logical XXXXX / ZZZZZ commute with stabilizers but are not stabilizers;
//   5. bounded stabilizer/logical weight counts stay consistent.
//
// Pauli Vec layout is [x0, z0, x1, z1, ...]. Expected rc=0.

import "stdlib/rods/clifford.nr"

fn pauli_xzzxi() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(1); p.push(0);
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    return p;
}

fn pauli_ixzzx() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    p.push(1); p.push(0);
    return p;
}

fn pauli_xixzz() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    return p;
}

fn pauli_zxixz() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(1);
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(1); p.push(0);
    p.push(0); p.push(1);
    return p;
}

fn logical_xxxxx() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(1); p.push(0);
    p.push(1); p.push(0);
    p.push(1); p.push(0);
    p.push(1); p.push(0);
    p.push(1); p.push(0);
    return p;
}

fn logical_zzzzz() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    p.push(0); p.push(1);
    return p;
}

fn single_x0_5q() -> Vec<i64> {
    let mut p: Vec<i64> = Vec::new();
    p.push(1); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    p.push(0); p.push(0);
    return p;
}

fn build_five_qubit_code() -> i64 {
    let h: i64 = cliff_init_code(5);
    if h == 0 { return 0; };

    if cliff_add_stabilizer(h, pauli_xzzxi()) != 1 { cliff_free(h); return 0; };
    if cliff_add_stabilizer(h, pauli_ixzzx()) != 1 { cliff_free(h); return 0; };
    if cliff_add_stabilizer(h, pauli_xixzz()) != 1 { cliff_free(h); return 0; };
    if cliff_add_stabilizer(h, pauli_zxixz()) != 1 { cliff_free(h); return 0; };
    return h;
}

fn check_clone_reset_isolation() -> i64 {
    let h: i64 = cliff_init(2);
    if h == 0 { return 1; };
    cliff_h(h, 0);
    cliff_cnot(h, 0, 1);

    let c: i64 = cliff_clone(h);
    if c == 0 { cliff_free(h); return 2; };

    cliff_reset(h);
    let r0: i64 = cliff_measure(h, 0);
    let r1: i64 = cliff_measure(h, 1);
    if r0 != 0 || r1 != 0 {
        cliff_free(c);
        cliff_free(h);
        return 3;
    };

    let m0: i64 = cliff_measure(c, 0);
    let m1: i64 = cliff_measure(c, 1);
    cliff_free(c);
    cliff_free(h);
    if m0 != m1 { return 4; };
    return 0;
}

fn check_gate_identity_sequence() -> i64 {
    let h: i64 = cliff_init(2);
    if h == 0 { return 10; };

    cliff_h(h, 0);
    cliff_h(h, 0);
    cliff_x(h, 1);
    cliff_x(h, 1);
    cliff_x(h, 0);
    cliff_cnot(h, 0, 1);
    cliff_cnot(h, 0, 1);

    let m0: i64 = cliff_measure(h, 0);
    let m1: i64 = cliff_measure(h, 1);
    cliff_free(h);
    if m0 != 1 || m1 != 0 { return 11; };
    return 0;
}

fn check_five_qubit_properties(base: i64) -> i64 {
    let h: i64 = build_five_qubit_code();
    if h == 0 { return base + 1; };

    if cliff_num_stabilizers(h) != 4 { cliff_free(h); return base + 2; };
    if cliff_distance(h, 1) != 3 { cliff_free(h); return base + 3; };
    if cliff_count_errors(h) != 15 { cliff_free(h); return base + 4; };
    if cliff_error_detectable(h, single_x0_5q()) != 1 { cliff_free(h); return base + 5; };
    if cliff_error_detectable(h, logical_xxxxx()) != 0 { cliff_free(h); return base + 6; };
    if cliff_error_detectable(h, logical_zzzzz()) != 0 { cliff_free(h); return base + 7; };

    if cliff_stabilizer_weight_count(h, 0) != 1 { cliff_free(h); return base + 8; };
    if cliff_stabilizer_weight_count(h, 4) != 15 { cliff_free(h); return base + 9; };
    if cliff_logical_weight_count(h, 1, 3) != 30 { cliff_free(h); return base + 10; };
    if cliff_logical_weight_count(h, 1, 5) != 18 { cliff_free(h); return base + 11; };

    let total_stab: i64 = cliff_stabilizer_weight_count(h, 0) + cliff_stabilizer_weight_count(h, 4);
    let total_logical: i64 = cliff_logical_weight_count(h, 1, 3) + cliff_logical_weight_count(h, 1, 5);
    if total_stab != 16 { cliff_free(h); return base + 12; };
    if total_logical != 48 { cliff_free(h); return base + 13; };

    cliff_free(h);
    return 0;
}

fn main() -> i64 {
    let clone_rc: i64 = check_clone_reset_isolation();
    if clone_rc != 0 { return clone_rc; };

    let gate_rc: i64 = check_gate_identity_sequence();
    if gate_rc != 0 { return gate_rc; };

    let first_code_rc: i64 = check_five_qubit_properties(20);
    if first_code_rc != 0 { return first_code_rc; };

    let second_code_rc: i64 = check_five_qubit_properties(50);
    if second_code_rc != 0 { return second_code_rc; };

    return 0;
}
