// EXPECT: rc=0
//
// ROBO-7 / RFC-0046 Phase B v0838 — positive coverage for the
// compiler-visible coordinate-frame phantom-tag check.
//
// Locks four invariants on the new frame-aware path in
// `types_compatible` (see `frame_mismatch_visible` in
// `compiler/nucleor_s1_compiler.nr`):
//
//   1. **Same-frame let binding compiles** — `let p1: Pose<Frame_Camera>`
//      bound to a value already typed `Pose<Frame_Camera>` type-checks
//      cleanly (no FRAME-001, no TYP-008).
//   2. **Frame_Unknown is migration-compatible** — `Pose<Frame_Unknown>`
//      bound to `Pose<Frame_Camera>` (and the reverse) type-checks
//      cleanly. RFC-0046 §migration documents this sentinel as the
//      backwards-compat escape so existing untagged-pose code keeps
//      compiling while adopters migrate field by field.
//   3. **Untagged Pose flows into a tagged binding** — `let p: Pose<Frame_Base>
//      = make_pose()` (where `make_pose()` returns the bare `Pose`)
//      type-checks cleanly. The check is intentionally one-sided:
//      adopters opt INTO frame typing without breaking every existing
//      `Pose`-typed call site.
//   4. **Frame tags carry through chained bindings** — a chain of
//      same-frame `let`s preserves the tag through each link.
//
// Negative coverage for the cross-frame rejection lives at
// `tests/err/err_robo7_frame_mismatch.nr`.

import "stdlib/rods/kinematics_frame.nr"

struct Pose { translation: i64, rotation: i64 }

fn make_pose() -> Pose {
    return Pose { translation: 0, rotation: 0 };
}

fn check_same_frame() -> i64 {
    let p1: Pose<Frame_Camera> = make_pose();
    let p2: Pose<Frame_Camera> = p1;
    if p2.translation != 0 { return 1; };
    return 0;
}

fn check_unknown_left() -> i64 {
    let p_unk: Pose<Frame_Unknown> = make_pose();
    let p_cam: Pose<Frame_Camera> = p_unk;
    if p_cam.rotation != 0 { return 2; };
    return 0;
}

fn check_unknown_right() -> i64 {
    let p_lid: Pose<Frame_Lidar> = make_pose();
    let p_unk: Pose<Frame_Unknown> = p_lid;
    if p_unk.translation != 0 { return 4; };
    return 0;
}

fn check_untagged_into_tagged() -> i64 {
    let p_base: Pose<Frame_Base> = make_pose();
    if p_base.rotation != 0 { return 8; };
    return 0;
}

fn check_chain_preserves_tag() -> i64 {
    let p1: Pose<Frame_Gripper> = make_pose();
    let p2: Pose<Frame_Gripper> = p1;
    let p3: Pose<Frame_Gripper> = p2;
    if p3.translation != 0 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_same_frame();
    fails = fails + check_unknown_left();
    fails = fails + check_unknown_right();
    fails = fails + check_untagged_into_tagged();
    fails = fails + check_chain_preserves_tag();
    return fails;
}
