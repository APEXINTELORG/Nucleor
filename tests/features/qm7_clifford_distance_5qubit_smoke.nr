// QM-7 Phase 2a - Clifford stabilizer-distance smoke.
//
// Locks a known [[5,1,3]] perfect-code stabilizer set:
//   X Z Z X I
//   I X Z Z X
//   X I X Z Z
//   Z X I X Z
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

fn main() -> i64 {
    let h: i64 = cliff_init_code(5);
    if h == 0 { return 1; };

    if cliff_add_stabilizer(h, pauli_xzzxi()) != 1 { cliff_free(h); return 2; };
    if cliff_add_stabilizer(h, pauli_ixzzx()) != 1 { cliff_free(h); return 3; };
    if cliff_add_stabilizer(h, pauli_xixzz()) != 1 { cliff_free(h); return 4; };
    if cliff_add_stabilizer(h, pauli_zxixz()) != 1 { cliff_free(h); return 5; };

    if cliff_num_stabilizers(h) != 4 { cliff_free(h); return 6; };
    if cliff_distance(h, 1) != 3 { cliff_free(h); return 7; };
    if cliff_count_errors(h) != 15 { cliff_free(h); return 8; };

    cliff_free(h);
    return 0;
}
