// EXPECT: rc=0
// v0845 Lane 5 / Queue 5A — composition chain test.
// Compose Transform<Frame_Base, Frame_Camera> with
// Transform<Frame_Camera, Frame_Gripper> and assert the result
// types as Transform<Frame_Base, Frame_Gripper>. Phantom-frame
// types are zero-cost; the compiler accepts the inferred
// composition signature and the build runs cleanly.

import "stdlib/rods/kinematics_frame.nr"
import "stdlib/rods/kinematics.nr"
import "stdlib/rods/kinematics_transform.nr"

fn main() -> i32 {
    let t1: i64 = vec3(f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let q1: i64 = quat_identity();
    let bc: Transform<Frame_Base, Frame_Camera> = transform_new(t1, q1);

    let t2: i64 = vec3(f64_to_bits(0.0), f64_to_bits(2.0), f64_to_bits(0.0));
    let q2: i64 = quat_identity();
    let cg: Transform<Frame_Camera, Frame_Gripper> = transform_new(t2, q2);

    let bg: Transform<Frame_Base, Frame_Gripper> = transform_compose(bc, cg);

    if transform_translation(bg) == 0 { return 1; };
    if transform_rotation(bg) == 0 { return 2; };
    return 0;
}
