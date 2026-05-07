// EXPECT: rc=0
//
// ROBO-7 v0841 stdlib migration smoke.
//
// Proves the kinematics rod now exposes adopter-facing Pose<Frame_*>
// helpers while preserving Frame_Unknown migration compatibility and
// the existing handle-level pose math.

import "stdlib/rods/kinematics.nr"
import "stdlib/rods/kinematics_frame.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn make_typed_pose(x: f64) -> Pose<Frame_Unknown> {
    let pos: i64 = vec3(f64_to_bits(x), f64_to_bits(0.0), f64_to_bits(0.0));
    let rot: i64 = quat_identity();
    return kinematics_pose(pos, rot);
}

fn check_unknown_migration() -> i64 {
    let p_unknown: Pose<Frame_Unknown> = make_typed_pose(1.0);
    let p_camera: Pose<Frame_Camera> = p_unknown;
    let p_back: Pose<Frame_Unknown> = p_camera;
    let pos: i64 = kinematics_pose_pos(p_back);
    if close(vec3_x(pos), f64_to_bits(1.0), 1e-9) != 1 { return 1; };
    return 0;
}

fn check_camera_to_base_transform() -> i64 {
    let p_camera: Pose<Frame_Camera> = make_typed_pose(1.0);
    let camera_to_base: Pose<Frame_Unknown> = make_typed_pose(10.0);
    let p_base: Pose<Frame_Base> = kinematics_transform_camera_to_base(p_camera, camera_to_base);
    let pos: i64 = kinematics_pose_pos(p_base);
    if close(vec3_x(pos), f64_to_bits(11.0), 1e-9) != 1 { return 2; };
    return 0;
}

fn check_base_to_camera_transform() -> i64 {
    let p_base: Pose<Frame_Base> = make_typed_pose(4.0);
    let base_to_camera: Pose<Frame_Unknown> = make_typed_pose(3.0);
    let p_camera: Pose<Frame_Camera> = kinematics_transform_base_to_camera(p_base, base_to_camera);
    let pos: i64 = kinematics_pose_pos(p_camera);
    if close(vec3_x(pos), f64_to_bits(7.0), 1e-9) != 1 { return 4; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_unknown_migration();
    fails = fails + check_camera_to_base_transform();
    fails = fails + check_base_to_camera_transform();
    return fails;
}
