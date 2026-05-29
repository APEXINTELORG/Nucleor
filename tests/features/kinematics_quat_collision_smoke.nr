// v0.8.260 stdlib/rods/kinematics.nr <-> stdlib/rods/quat.nr collision rename.
//
// Pre-v0.8.260 BOTH rods exported `nuc_quat_from_axis_angle` and
// `nuc_quat_mul` from their respective C runtime files with
// incompatible signatures:
//
//   kinematics_rt.c::nuc_quat_from_axis_angle  2-arg, Vec-handle API
//   quat_rt.c     ::nuc_quat_from_axis_angle  3-arg, raw double*  API
//   kinematics_rt.c::nuc_quat_mul              2-arg, Vec-handle API
//   quat_rt.c     ::nuc_quat_mul              3-arg, raw double*  API
//
// Importing both rods in one program was a duplicate-symbol link
// error or a silent wrong-target call. The Nucleor-level wrapper
// names (`quat_from_axis_angle`, `quat_mul`) ALSO collided.
// Surfaced by TRACK A
// `extern_arity_drift_duplicate_symbol_collisions_2026-05-05`.
//
// Fix (kinematics rod renames; quat rod keeps canonical namespace):
// - kinematics_rt.c::nuc_quat_from_axis_angle (2-arg) → `nuc_kin_quat_from_axis_angle`
// - kinematics_rt.c::nuc_quat_mul             (2-arg) → `nuc_kin_quat_mul`
// - kinematics.nr externs renamed to match C.
// - kinematics.nr Nucleor wrappers renamed:
//     `quat_from_axis_angle` → `kin_quat_from_axis_angle`
//     `quat_mul` → `kin_quat_mul`
// - kinematics.nr `quat_from_axis_angle_f64` (convenience) keeps
//   its unique name; body now calls `nuc_kin_quat_from_axis_angle`.
// - tests/rods/kinematics_smoke.nr `quat_mul` → `kin_quat_mul`.
// - quat.nr (3-arg, raw-pointer API) untouched.
//
// Breaking for any Nucleor adopter that imported kinematics.nr
// and called `quat_from_axis_angle(axis, angle_bits)` 2-arg or
// `quat_mul(a, b)` 2-arg. Migrate to `kin_quat_*`. Only one in-tree
// caller existed (tests/rods/kinematics_smoke.nr); updated in this
// ship.
//
// Locks two invariants on the rename:
//   1. kin_quat_mul identity composition — `kin_quat_mul(qid, qid)`
//      returns a quat whose `quat_w` non-zero (proves the renamed
//      runtime entry is reached).
//   2. Both rods can be imported together (this fixture imports
//      kinematics + quat; if the link still collided, this fixture
//      would fail at link/load time before main runs).
//
// Expected: rc=0.

import "stdlib/rods/kinematics.nr"
import "stdlib/rods/quat.nr"

fn check_kin_quat_mul_identity() -> i64 {
    let qid: i64 = quat_identity();
    let qid2: i64 = kin_quat_mul(qid, qid);
    let w_bits: i64 = quat_w(qid2);
    if w_bits == 0 { return 1; };
    return 0;
}

fn check_kin_quat_from_axis_angle_zero_angle() -> i64 {
    let zhat: i64 = vec3(f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0));
    let q: i64 = kin_quat_from_axis_angle(zhat, f64_to_bits(0.0));
    if q == 0 { return 2; };
    let w: i64 = quat_w(q);
    if w == 0 { return 4; };
    return 0;
}

fn check_both_rods_link() -> i64 {
    // If the symbol collision still existed, importing both
    // kinematics.nr and quat.nr would trigger a linker error before
    // main runs. Reaching this line proves the rename worked.
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_kin_quat_mul_identity();
    fails = fails + check_kin_quat_from_axis_angle_zero_angle();
    fails = fails + check_both_rods_link();
    return fails;
}
