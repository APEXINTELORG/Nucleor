// EXPECT: error[FRAME-001] cannot pass argument 0 to 'consume_camera': declared frame `Frame_Camera` does not match value frame `Frame_Base`
//
// ROBO-7 / RFC-0046 Phase B step 3: call-argument diagnostics
// should surface FRAME-001, not generic TYP-006, when the only
// mismatch is a Pose<Frame_*> phantom tag.

import "stdlib/rods/kinematics_frame.nr"

struct Pose { translation: i64, rotation: i64 }

fn make_pose() -> Pose {
    return Pose { translation: 0, rotation: 0 };
}

fn consume_camera(p: Pose<Frame_Camera>) -> i64 {
    return p.translation;
}

fn main() -> i64 {
    let p_base: Pose<Frame_Base> = make_pose();
    return consume_camera(p_base);
}
