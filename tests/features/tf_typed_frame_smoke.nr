// v0.8.268 R07-D2 Phase 1 — typed TF wrappers coverage.
//
// Per audit `BUILD_PLAN_R07_robotics_control.md` §1 R07-D2 (HIGH):
// pre-v0.8.268 TF rod accepted any i64 as frame_id, so adopters
// could pass arbitrary out-of-range integers outside the type
// checker's visibility. Phase 1 adds runtime-validated typed
// wrappers that restrict callers to canonical kinematics_frame
// IDs (0..7 or -1).
//
// Phase 1 acceptance criteria (this ship):
//   - typed wrapper fixture passes;
//   - raw ID path remains available with explicit warning (still
//     callable; doc + comment marks it audited);
//   - cold compile <= 4s (preserved — rod-only edit).
//
// Phase 2 (per build plan §1 R07-D2): compile-time type-checked
// Pose<F> per RFC-0046 Phase B.
//
// Locks 8 invariants on `tf_is_canonical_frame_id` (the validation
// predicate; testing it directly avoids the raw-double* construction
// problem that motivated the existing tf_smoke lifecycle-only
// coverage):
//
//   1. **0 (world)** is canonical.
//   2. **7 (odom)** is canonical (last in-range).
//   3. **-1 (unknown sentinel)** is canonical.
//   4. **8** is NOT canonical (just past in-range).
//   5. **999** is NOT canonical.
//   6. **-2** is NOT canonical (only -1 is the sentinel).
//   7. **out-of-range frame_id rejected by `tf_add_frame_typed`** —
//      returns 0 without invoking the raw API.
//   8. **out-of-range parent_id rejected by `tf_add_frame_typed`**.
//
// Expected: rc=0.

import "stdlib/rods/tf.nr"
import "stdlib/rods/kinematics_frame.nr"

fn check_canonical_zero() -> i64 {
    if tf_is_canonical_frame_id(0) != 1 { return 1; };
    return 0;
}

fn check_canonical_seven() -> i64 {
    if tf_is_canonical_frame_id(7) != 1 { return 2; };
    return 0;
}

fn check_canonical_unknown_sentinel() -> i64 {
    if tf_is_canonical_frame_id(0 - 1) != 1 { return 4; };
    return 0;
}

fn check_eight_rejected() -> i64 {
    if tf_is_canonical_frame_id(8) != 0 { return 8; };
    return 0;
}

fn check_999_rejected() -> i64 {
    if tf_is_canonical_frame_id(999) != 0 { return 16; };
    return 0;
}

fn check_negative_two_rejected() -> i64 {
    // Only -1 is the canonical sentinel. -2 must reject.
    if tf_is_canonical_frame_id(0 - 2) != 0 { return 32; };
    return 0;
}

fn check_typed_frame_id_rejected() -> i64 {
    let h: i64 = tf_new(16);
    if h == 0 { return 64; };
    // Pass null ptrs because we're testing rejection path BEFORE
    // raw API invocation. Validation rejects 999 -> returns 0
    // without calling nuc_tf_add_frame.
    let r: i64 = tf_add_frame_typed(h, 999, 0 - 1, 0, 0);
    if r != 0 { tf_free(h); return 128; };
    tf_free(h);
    return 0;
}

fn check_typed_parent_id_rejected() -> i64 {
    let h: i64 = tf_new(16);
    let cam: i64 = kinematics_frame_id_camera();
    let r: i64 = tf_add_frame_typed(h, cam, 999, 0, 0);
    if r != 0 { tf_free(h); return 256; };
    tf_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_canonical_zero();
    fails = fails + check_canonical_seven();
    fails = fails + check_canonical_unknown_sentinel();
    fails = fails + check_eight_rejected();
    fails = fails + check_999_rejected();
    fails = fails + check_negative_two_rejected();
    fails = fails + check_typed_frame_id_rejected();
    fails = fails + check_typed_parent_id_rejected();
    return fails;
}
