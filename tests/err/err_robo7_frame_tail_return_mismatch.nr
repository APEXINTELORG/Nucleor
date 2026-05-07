// EXPECT: error[FRAME-001] cannot use tail expression for fn 'make_camera_tail': declared frame `Frame_Camera` does not match value frame `Frame_Base`
//
// ROBO-7 / RFC-0046 Phase B step 3: tail-expression return
// diagnostics should surface FRAME-001 for frame-tag-only mismatches.

import "stdlib/rods/kinematics_frame.nr"

struct Pose { translation: i64, rotation: i64 }

fn make_pose() -> Pose {
    return Pose { translation: 0, rotation: 0 };
}

fn make_camera_tail() -> Pose<Frame_Camera> {
    let p_base: Pose<Frame_Base> = make_pose();
    p_base
}

fn main() -> i64 {
    let p: Pose<Frame_Camera> = make_camera_tail();
    return p.translation;
}
