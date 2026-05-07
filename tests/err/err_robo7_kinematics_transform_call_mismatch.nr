// EXPECT: error[FRAME-001] cannot pass argument 0 to 'kinematics_transform_camera_to_base': declared frame `Frame_Camera` does not match value frame `Frame_Base`
//
// ROBO-7 v0841 stdlib migration negative.
//
// A base-frame pose cannot be consumed by the camera-to-base explicit
// transform helper. Pre-ROBO-7 this silently collapsed to bare Pose.

import "stdlib/rods/kinematics.nr"
import "stdlib/rods/kinematics_frame.nr"

fn make_typed_pose() -> Pose<Frame_Unknown> {
    let pos: i64 = vec3(f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let rot: i64 = quat_identity();
    return kinematics_pose(pos, rot);
}

fn main() -> i64 {
    let p_base: Pose<Frame_Base> = make_typed_pose();
    let camera_to_base: Pose<Frame_Unknown> = make_typed_pose();
    let p_out: Pose<Frame_Base> = kinematics_transform_camera_to_base(p_base, camera_to_base);
    return kinematics_pose_pos(p_out);
}
