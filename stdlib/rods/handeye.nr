// rods/handeye — Hand-eye calibration: solve AX = XB for the
// unknown end-effector → camera transform.
//
// Given a sequence of robot motion / camera motion pairs
// (A_i, B_i), where:
//   A_i = relative robot motion (between end-effector poses i and i+1)
//   B_i = relative camera motion (between camera views i and i+1)
//   X   = unknown end-effector → camera transform
//
// the AX = XB constraint pins down X to within a scaling/sign
// ambiguity. Two-step solver:
//   1. Rotation: Procrustes / Horn quaternion alignment between
//      rotation axes of A and B.
//   2. Translation: linear LS on (R_a − I)·t_x = R_x·t_b − t_a.
//
// Foundation for any vision-in-the-loop robot control where the
// camera is mounted on the end-effector — visual servoing
// (`vision.nr` IBVS), object pose estimation, eye-in-hand
// tracking. The result X is what relates the camera observation
// frame to the robot's kinematic chain.
//
// Workflow:
//   // Collect at least 3 (≥ 5 recommended) motion pairs by
//   // moving the robot to known poses while observing a fixed
//   // calibration target with the camera.
//   // Ra/Rb arrays are double[N * 9] row-major rotations.
//   // ta/tb arrays are double[N * 3] translations.
//   handeye_calibrate(Ra_array_ptr, ta_array_ptr,
//                     Rb_array_ptr, tb_array_ptr, n_motions,
//                     Rx_out_ptr, tx_out_ptr);
//
// **Limitations** (joint rotation+translation optimization
// (Daniilidis 1999 dual quaternion form) lands in v0.6 if needed):
// - Two-step solve. The dual-quaternion joint solver couples
//   rotation and translation; can be marginally more accurate
//   when the two have correlated errors.
// - Requires ≥ 3 motion pairs with non-collinear rotation axes
//   for the rotation step to be well-conditioned.
//
// See `stdlib/runtime/handeye_rt.c`.
#cfile "../runtime/handeye_rt.c"

extern fn nuc_handeye_calibrate(
    Ra_array_ptr: i64, ta_array_ptr: i64,
    Rb_array_ptr: i64, tb_array_ptr: i64,
    n_motions: i64,
    Rx_out_ptr: i64, tx_out_ptr: i64) -> i64;

// Solve AX = XB. `Ra_array_ptr` / `Rb_array_ptr` are
// `double[n_motions * 9]` row-major rotation arrays. `ta_array_ptr`
// / `tb_array_ptr` are `double[n_motions * 3]` translation arrays.
// `Rx_out_ptr` is `double[9]` (row-major) and `tx_out_ptr` is
// `double[3]`. Returns 0 on success, -1 on bad input or singular
// translation system.
fn handeye_calibrate(
    Ra_array_ptr: i64, ta_array_ptr: i64,
    Rb_array_ptr: i64, tb_array_ptr: i64,
    n_motions: i64,
    Rx_out_ptr: i64, tx_out_ptr: i64) -> i64
{
    return nuc_handeye_calibrate(Ra_array_ptr, ta_array_ptr,
        Rb_array_ptr, tb_array_ptr, n_motions,
        Rx_out_ptr, tx_out_ptr);
}
