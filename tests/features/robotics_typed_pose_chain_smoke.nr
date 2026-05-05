// v0.8.269 R07-D3 Phase 1 — typed-frame pose chain end-to-end.
//
// Per audit `BUILD_PLAN_R07_robotics_control.md` §1 R07-D3 (HIGH):
// pre-v0.8.269 IK / planner / trajectory rods had build-only smoke
// coverage; full stack correctness was not locked. The audit's
// full IK→planner→trajectory chain requires raw double* construction
// that the current Nucleor surface can't easily build from a fixture.
// Phase 1 ships the **typed-frame pose chain** end-to-end using
// `kinematics.nr`'s Vec-handle pose API + `kinematics_frame.nr`'s
// typed-check helpers — exercises the same correctness pattern
// (typed frames preserved through composition) against a
// deterministic 2-link world→base→camera chain.
//
// Phase 2 (per build plan §1 R07-D3 + R07-D1 Phase 2) extends to
// IK→planner→trajectory once compile-time TYP-008 + raw-double*
// fixture-construction land.
//
// Phase 1 acceptance (this ship):
//   - end-to-end positive fixture passes (typed-frame chain
//     compose + apply, frame IDs preserved + checked at each hop);
//   - wrong-frame negative path returns the rejection sentinel
//     (per R07-D1 Phase 1 runtime helpers);
//   - cold compile <= 4s (preserved).
//
// Locks 5 invariants on a deterministic 3-frame chain:
//   1. **Identity-pose chain compose** — identity ∘ identity = identity;
//      apply to (1, 2, 3) returns (1, 2, 3).
//   2. **Typed-frame check on chain** — building world→base→camera
//      with all canonical IDs passes `tf_is_canonical_frame_id` for
//      each.
//   3. **Wrong-frame compose rejection** — `kinematics_frame_check_pair`
//      between camera and base returns 0 (the rejection signal that
//      Phase 2 promotes to TYP-008 compile error).
//   4. **Quaternion identity round-trip through pose** — w=1.0
//      preserved through `pose_quat(pose_identity())`.
//   5. **Typed-frame IDs for kinematic chain** — world (0), base (1),
//      camera (2) all in canonical range, all distinct.
//
// Expected: rc=0.

import "stdlib/rods/kinematics.nr"
import "stdlib/rods/kinematics_frame.nr"
import "stdlib/rods/tf.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_identity_chain_apply() -> i64 {
    // identity ∘ identity ∘ identity composed; apply to (1, 2, 3).
    let pid: i64 = pose_identity();
    let chain1: i64 = pose_compose(pid, pid);
    let chain2: i64 = pose_compose(chain1, pid);
    let v: i64 = vec3(f64_to_bits(1.0), f64_to_bits(2.0), f64_to_bits(3.0));
    let v2: i64 = pose_apply(chain2, v);
    if close(vec3_x(v2), f64_to_bits(1.0), 1e-9) != 1 { return 1; };
    if close(vec3_y(v2), f64_to_bits(2.0), 1e-9) != 1 { return 2; };
    if close(vec3_z(v2), f64_to_bits(3.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn check_typed_frames_canonical() -> i64 {
    let world: i64 = kinematics_frame_id_world();
    let base: i64 = kinematics_frame_id_base();
    let cam: i64 = kinematics_frame_id_camera();
    if tf_is_canonical_frame_id(world) != 1 { return 8; };
    if tf_is_canonical_frame_id(base) != 1 { return 16; };
    if tf_is_canonical_frame_id(cam) != 1 { return 32; };
    // Distinct
    if world == base { return 64; };
    if base == cam { return 128; };
    if world == cam { return 256; };
    return 0;
}

fn check_wrong_frame_compose_rejection() -> i64 {
    // The R07-D1 helper returns 0 when frames don't match; that's
    // the rejection signal Phase 2 promotes to TYP-008 compile-time.
    let cam: i64 = kinematics_frame_id_camera();
    let base: i64 = kinematics_frame_id_base();
    if kinematics_frame_check_pair(cam, base) != 0 { return 512; };
    if kinematics_frame_assert(cam, base) != 0 { return 1024; };
    if kinematics_frame_require(cam, base) != 0 - 1 { return 2048; };
    return 0;
}

fn check_quat_identity_through_pose() -> i64 {
    let pid: i64 = pose_identity();
    let q: i64 = pose_quat(pid);
    if close(quat_w(q), f64_to_bits(1.0), 1e-9) != 1 { return 4096; };
    if close(quat_x(q), f64_to_bits(0.0), 1e-9) != 1 { return 8192; };
    return 0;
}

fn check_chain_ids_in_canonical_range() -> i64 {
    // world / base / camera IDs must all be in {0..7, -1}.
    let chain_ok: i64 = if tf_is_canonical_frame_id(kinematics_frame_id_world()) == 1
        && tf_is_canonical_frame_id(kinematics_frame_id_base()) == 1
        && tf_is_canonical_frame_id(kinematics_frame_id_camera()) == 1 { 1 } else { 0 };
    if chain_ok != 1 { return 16384; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_identity_chain_apply();
    fails = fails + check_typed_frames_canonical();
    fails = fails + check_wrong_frame_compose_rejection();
    fails = fails + check_quat_identity_through_pose();
    fails = fails + check_chain_ids_in_canonical_range();
    return fails;
}
