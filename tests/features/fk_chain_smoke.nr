// v0.8.235 stdlib/rods/fk_chain.nr first test coverage.
//
// Forward kinematics for a serial joint chain. Pre-v0.8.235:
// zero coverage on the standalone rod (the URDF + RFC-0013
// frame-chain check both build on top of this).
//
// Locks four invariants. fk_chain_update / link_pos / workspace
// sampling all use raw vars_ptr / out_ptr; deferred to dedicated
// IK ships.
//
//   1. **Stable joint type IDs** — revolute=0, prismatic=1,
//      fixed=2 (RFC-0013 + URDF parser depend on this).
//   2. **Empty chain** — fk_chain_new → count == 0.
//   3. **add_joint tracks count** — 3 joints → count 3.
//   4. **joint_type round-trip** — revolute / prismatic / fixed
//      slots preserved per index.
//
// Expected: rc=0.

import "stdlib/rods/fk_chain.nr"

fn check_joint_type_ids() -> i64 {
    if fk_revolute() != 0 { return 1; };
    if fk_prismatic() != 1 { return 2; };
    if fk_fixed() != 2 { return 4; };
    return 0;
}

fn add_zero_axis_joint(ch: i64, jtype: i64) -> i64 {
    return nuc_fk_chain_add_joint(ch, jtype,
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0)
    );
}

fn check_empty_chain() -> i64 {
    let ch: i64 = fk_chain_new();
    if fk_chain_count(ch) != 0 { fk_chain_free(ch); return 8; };
    fk_chain_free(ch);
    return 0;
}

fn check_add_joint_count() -> i64 {
    let ch: i64 = fk_chain_new();
    add_zero_axis_joint(ch, fk_revolute());
    add_zero_axis_joint(ch, fk_prismatic());
    add_zero_axis_joint(ch, fk_fixed());
    if fk_chain_count(ch) != 3 { fk_chain_free(ch); return 16; };
    fk_chain_free(ch);
    return 0;
}

fn check_joint_type_round_trip() -> i64 {
    let ch: i64 = fk_chain_new();
    add_zero_axis_joint(ch, fk_revolute());
    add_zero_axis_joint(ch, fk_prismatic());
    add_zero_axis_joint(ch, fk_fixed());
    if fk_chain_joint_type(ch, 0) != fk_revolute() { fk_chain_free(ch); return 32; };
    if fk_chain_joint_type(ch, 1) != fk_prismatic() { fk_chain_free(ch); return 64; };
    if fk_chain_joint_type(ch, 2) != fk_fixed() { fk_chain_free(ch); return 128; };
    fk_chain_free(ch);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_joint_type_ids();
    fails = fails + check_empty_chain();
    fails = fails + check_add_joint_count();
    fails = fails + check_joint_type_round_trip();
    return fails;
}
