// EXPECT: rc=0
// v0845 Lane 5 / Queue 5A — inversion test.
// Invert Transform<Frame_Base, Frame_Camera> and assert the result
// types as Transform<Frame_Camera, Frame_Base>. Frame swap is
// enforced by the phantom-type signature on transform_invert.

import "stdlib/rods/kinematics_frame.nr"
import "stdlib/rods/kinematics.nr"
import "stdlib/rods/kinematics_transform.nr"

fn main() -> i32 {
    let t: i64 = vec3(f64_to_bits(3.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let q: i64 = quat_identity();
    let bc: Transform<Frame_Base, Frame_Camera> = transform_new(t, q);
    let cb: Transform<Frame_Camera, Frame_Base> = transform_invert(bc);
    if transform_translation(cb) == 0 { return 1; };
    if transform_rotation(cb) == 0 { return 2; };
    return 0;
}
