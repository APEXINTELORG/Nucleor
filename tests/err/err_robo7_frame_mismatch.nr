// EXPECT: FRAME-001 cannot initialize binding 'p_camera': declared frame `Frame_Camera` does not match value frame `Frame_Base`
//
// ROBO-7 / RFC-0046 Phase B v0838 — negative coverage for the
// compiler-visible coordinate-frame phantom-tag check.
//
// The Mars-Climate-Orbiter failure mode in robotics: a value
// produced in the base frame is silently consumed where a
// camera-frame value is expected. Pre-Phase-B Nucleor's type
// checker collapsed `Pose<Frame_Camera>` and `Pose<Frame_Base>`
// to the same shape via the `same-base-name = compatible`
// catch-all in `types_compatible`, so this assignment
// type-checked clean and the camera-frame planner happily
// consumed base-frame coordinates.
//
// Phase B (this slice) inserts `frame_mismatch_visible` ahead of
// the catch-all so distinct `Frame_*` phantom tags on matching
// base names reject at type-check. The let-binding site
// upgrades the diagnostic from generic TYP-008 to FRAME-001 with
// the canonical Mars-Climate framing and a fix pointer
// (`kinematics_transform`).
//
// Adopter fix path:
//   * Apply an explicit transform (e.g. via `stdlib/rods/kinematics.nr`).
//   * OR retag the source binding to the destination frame at the
//     point of inspection-and-cast (`Pose<Frame_Unknown>` is the
//     migration sentinel that always passes — RFC-0046 §migration).

import "stdlib/rods/kinematics_frame.nr"

struct Pose { translation: i64, rotation: i64 }

fn make_pose() -> Pose {
    return Pose { translation: 0, rotation: 0 };
}

fn main() -> i64 {
    let p_base: Pose<Frame_Base> = make_pose();
    let p_camera: Pose<Frame_Camera> = p_base;
    return p_camera.translation;
}
