// EXPECT: error[FRAME-001] cannot use operator '==' with frame-mismatched operands: declared frame `Frame_Camera` does not match value frame `Frame_Base`
//
// ROBO-7 / RFC-0046 Phase B step 3: binary/operator diagnostics
// should surface FRAME-001 for frame-tag-only operand mismatches.

import "stdlib/rods/kinematics_frame.nr"

struct Pose { translation: i64, rotation: i64 }

fn make_pose() -> Pose {
    return Pose { translation: 0, rotation: 0 };
}

fn main() -> i64 {
    let p_camera: Pose<Frame_Camera> = make_pose();
    let p_base: Pose<Frame_Base> = make_pose();
    let same: bool = p_camera == p_base;
    if same { return 1; };
    return 0;
}
