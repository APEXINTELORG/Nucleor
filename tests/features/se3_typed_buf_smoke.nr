// EXPECT: rc=0
// v0845 Lane 5 / Queue 5C — typed SE(3) buffer wrappers smoke.
// Construct Se3Buf<Frame_Base, Frame_Camera> and
// Se3Buf<Frame_Camera, Frame_Gripper>, compose to
// Se3Buf<Frame_Base, Frame_Gripper>, invert
// Se3Buf<Frame_Base, Frame_Camera> -> Se3Buf<Frame_Camera, Frame_Base>.
// Frame swap and middle-frame match are enforced by the phantom
// signatures.

import "stdlib/rods/se3.nr"
import "stdlib/rods/kinematics_frame.nr"
import "stdlib/rods/kinematics.nr"

fn main() -> i32 {
    // Build pointer pairs.
    let t_bc: i64 = vec3(f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let q_bc: i64 = quat_identity();
    let bc: Se3Buf<Frame_Base, Frame_Camera> = se3_buf_new(t_bc, q_bc);

    let t_cg: i64 = vec3(f64_to_bits(0.0), f64_to_bits(1.0), f64_to_bits(0.0));
    let q_cg: i64 = quat_identity();
    let cg: Se3Buf<Frame_Camera, Frame_Gripper> = se3_buf_new(t_cg, q_cg);

    let t_bg: i64 = vec3(f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let q_bg: i64 = quat_identity();
    let bg_out: Se3Buf<Frame_Base, Frame_Gripper> = se3_buf_new(t_bg, q_bg);

    // Compose Frame_Base→Frame_Camera with Frame_Camera→Frame_Gripper
    se3_compose_typed(bc, cg, bg_out);

    // Invert Frame_Base→Frame_Camera to Frame_Camera→Frame_Base
    let t_cb: i64 = vec3(f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let q_cb: i64 = quat_identity();
    let cb_out: Se3Buf<Frame_Camera, Frame_Base> = se3_buf_new(t_cb, q_cb);
    se3_inverse_typed(bc, cb_out);

    // Confirm accessors return the original pointer values
    if se3_buf_t(bc) != t_bc { return 1; };
    if se3_buf_q(bc) != q_bc { return 2; };

    return 0;
}
