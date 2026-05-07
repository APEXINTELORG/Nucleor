// EXPECT: error[FRAME-001] cannot assign field 'target.pose': declared frame `Frame_Camera` does not match value frame `Frame_Base`
//
// ROBO-7 / RFC-0046 Phase B step 3: struct field assignment should
// surface FRAME-001 for frame-tag-only mismatches.

import "stdlib/rods/kinematics_frame.nr"

struct Pose { translation: i64, rotation: i64 }
struct Target { pose: Pose<Frame_Camera> }

fn make_pose() -> Pose {
    return Pose { translation: 0, rotation: 0 };
}

fn main() -> i64 {
    let p_camera: Pose<Frame_Camera> = make_pose();
    let p_base: Pose<Frame_Base> = make_pose();
    let mut target: Target = Target { pose: p_camera };
    target.pose = p_base;
    return target.pose.translation;
}
