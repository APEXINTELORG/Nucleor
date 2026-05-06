// QM-7 Phase 2a - Clifford reset/rebuild smoke.
//
// Locks two targeted invariants without turning this into a randomized suite:
//   1. cliff_reset returns a live handle to |000> and the handle can be reused.
//   2. The known [[5,1,3]] perfect-code stabilizer set rebuilds deterministically
//      on separate fresh code handles.
//
// The Pauli Vec layout is [x0, z0, x1, z1, ...]. Expected rc=0.

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

fn check_reset_then_reuse() -> i64 {
    let h: i64 = cliff_init(3);
    if h == 0 { return 1; };

    cliff_x(h, 0);
    cliff_x(h, 1);
    cliff_x(h, 2);
    cliff_reset(h);

    let z0: i64 = cliff_measure(h, 0);
    let z1: i64 = cliff_measure(h, 1);
    let z2: i64 = cliff_measure(h, 2);
    if z0 != 0 || z1 != 0 || z2 != 0 {
        cliff_free(h);
        return 2;
    };

    cliff_x(h, 1);
    let r0: i64 = cliff_measure(h, 0);
    let r1: i64 = cliff_measure(h, 1);
    let r2: i64 = cliff_measure(h, 2);
    cliff_free(h);

    if r0 != 0 || r1 != 1 || r2 != 0 { return 3; };
    return 0;
}

fn check_five_qubit_code_once(base: i64) -> i64 {
    let h: i64 = cliff_init_code(5);
    if h == 0 { return base + 1; };

    if cliff_add_stabilizer(h, pauli_xzzxi()) != 1 { cliff_free(h); return base + 2; };
    if cliff_add_stabilizer(h, pauli_ixzzx()) != 1 { cliff_free(h); return base + 3; };
    if cliff_add_stabilizer(h, pauli_xixzz()) != 1 { cliff_free(h); return base + 4; };
    if cliff_add_stabilizer(h, pauli_zxixz()) != 1 { cliff_free(h); return base + 5; };

    if cliff_num_stabilizers(h) != 4 { cliff_free(h); return base + 6; };
    if cliff_distance(h, 1) != 3 { cliff_free(h); return base + 7; };
    if cliff_count_errors(h) != 15 { cliff_free(h); return base + 8; };

    cliff_free(h);
    return 0;
}

fn main() -> i64 {
    let reset_rc: i64 = check_reset_then_reuse();
    if reset_rc != 0 { return reset_rc; };

    let first_rc: i64 = check_five_qubit_code_once(10);
    if first_rc != 0 { return first_rc; };

    let second_rc: i64 = check_five_qubit_code_once(30);
    if second_rc != 0 { return second_rc; };

    return 0;
}
