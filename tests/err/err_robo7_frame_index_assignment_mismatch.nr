// EXPECT: error[FRAME-001] cannot assign indexed element of 'poses': declared frame `Frame_Camera` does not match value frame `Frame_Base`
//
// ROBO-7 / RFC-0046 Phase B step 3: indexed assignment into a
// frame-tagged Vec should surface FRAME-001 for frame mismatches.

import "stdlib/rods/kinematics_frame.nr"

struct Pose { translation: i64, rotation: i64 }

fn make_pose() -> Pose {
    return Pose { translation: 0, rotation: 0 };
}

fn main() -> i64 {
    let mut poses: Vec<Pose<Frame_Camera>> = Vec::new();
    let p_camera: Pose<Frame_Camera> = make_pose();
    let p_base: Pose<Frame_Base> = make_pose();
    poses.push(p_camera);
    poses[0] = p_base;
    return 0;
}
