// rods/qutil — Quaternion utilities (SLERP, log/exp, conversions)
// on raw `double[4]` buffers.
//
// Convention: scalar-first quaternions `q = (w, x, y, z)`, Hamilton
// product, body→world rotation when used with the rest of the
// robotics stack (`kinematics.nr`, `ahrs.nr`, `pgs3.nr`, `ba.nr`).
//
// Complement to `kinematics.nr`, which uses allocated handles for
// each Vec3 / Quat / Pose. This rod takes pointers directly so
// inner loops (controllers, trajectory interpolation) avoid per-
// call allocation.
//
// Exports:
//   - `qutil_slerp` — constant-angular-velocity interpolation
//   - `qutil_squad` — smooth cubic interpolation through control points
//   - `qutil_log`  — unit quaternion → axis-angle (3-vec)
//   - `qutil_exp`  — axis-angle → unit quaternion
//   - `qutil_from_axis_angle` / `qutil_to_axis_angle`
//   - `qutil_from_euler` (ZYX) / `qutil_to_euler`
//   - `qutil_relative` — `q12 = q1⁻¹ · q2`
//   - `qutil_angular_distance` — radian distance ∈ [0, π]
//
// Workflow:
//
//   import "stdlib/rods/qutil.nr"
//
//   let q1: double[4];   // start
//   let q2: double[4];   // end
//   let q:  double[4];   // interpolated
//   qutil_slerp(q1_ptr, q2_ptr, t_b, q_out_ptr);
//
//   let omega: double[3];
//   qutil_log(q_ptr, omega_ptr);     // rotation vector
//   qutil_exp(omega_ptr, q_ptr);     // back to quaternion
//
// **Limitations** (rotation matrices / 9-DOF tangent splines /
// dual quaternions land in v0.6 if needed):
// - Caller must allocate all input/output buffers (3 doubles for
//   axis-angle / Euler, 4 doubles for quaternions).
// - Quaternions are normalized internally where required (slerp
//   output, exp output, etc.) but the input is trusted to be a
//   valid unit quaternion for log / Euler conversion.
//
// See `stdlib/runtime/qutil_rt.c`.
#cfile "../runtime/qutil_rt.c"

extern fn nuc_qutil_slerp(q1_ptr: i64, q2_ptr: i64, t_b: i64, out_ptr: i64);
extern fn nuc_qutil_squad(p_ptr: i64, a_ptr: i64, b_ptr: i64, q_ptr: i64,
    t_b: i64, out_ptr: i64);
extern fn nuc_qutil_exp(omega_ptr: i64, q_out_ptr: i64);
extern fn nuc_qutil_log(q_ptr: i64, omega_out_ptr: i64);
extern fn nuc_qutil_from_axis_angle(axis_ptr: i64, angle_b: i64, q_out_ptr: i64);
extern fn nuc_qutil_to_axis_angle(q_ptr: i64, axis_out_ptr: i64) -> i64;
extern fn nuc_qutil_from_euler(roll_b: i64, pitch_b: i64, yaw_b: i64, q_out_ptr: i64);
extern fn nuc_qutil_to_euler(q_ptr: i64, rpy_out_ptr: i64);
extern fn nuc_qutil_relative(q1_ptr: i64, q2_ptr: i64, q_out_ptr: i64);
extern fn nuc_qutil_angular_distance(q1_ptr: i64, q2_ptr: i64) -> i64;

// SLERP — spherical linear interpolation. Caller-supplied
// double[4] inputs and output. Picks the shorter arc by flipping
// q2 when needed; falls back to lerp+normalize when the two
// quaternions are within 1.8° to avoid div-by-tiny-sin.
fn qutil_slerp(q1_ptr: i64, q2_ptr: i64, t_b: i64, out_ptr: i64) {
    nuc_qutil_slerp(q1_ptr, q2_ptr, t_b, out_ptr);
}

// SQUAD — Shoemake's smooth interpolation through control points.
// (a, b) are intermediate "tangent" quaternions typically computed
// from neighboring segments to ensure C1 continuity.
fn qutil_squad(p_ptr: i64, a_ptr: i64, b_ptr: i64, q_ptr: i64,
    t_b: i64, out_ptr: i64) {
    nuc_qutil_squad(p_ptr, a_ptr, b_ptr, q_ptr, t_b, out_ptr);
}

// SO(3) exp: 3-vec axis-angle (|ω| = angle, ω̂ = axis) → unit quaternion.
fn qutil_exp(omega_ptr: i64, q_out_ptr: i64) {
    nuc_qutil_exp(omega_ptr, q_out_ptr);
}

// SO(3) log: unit quaternion → 3-vec axis-angle. Picks the shorter
// rotation (negates input quaternion if its scalar part is negative).
fn qutil_log(q_ptr: i64, omega_out_ptr: i64) {
    nuc_qutil_log(q_ptr, omega_out_ptr);
}

// Build quaternion from axis (3-vec, normalized internally) +
// scalar angle in radians.
fn qutil_from_axis_angle(axis_ptr: i64, angle_b: i64, q_out_ptr: i64) {
    nuc_qutil_from_axis_angle(axis_ptr, angle_b, q_out_ptr);
}

// Decompose a unit quaternion to (axis, angle). Writes the unit
// rotation axis to axis_out_ptr and returns the angle in radians.
fn qutil_to_axis_angle(q_ptr: i64, axis_out_ptr: i64) -> i64 {
    return nuc_qutil_to_axis_angle(q_ptr, axis_out_ptr);
}

// ZYX intrinsic Euler angles (roll about x, pitch about y,
// yaw about z) → quaternion.
fn qutil_from_euler(roll_b: i64, pitch_b: i64, yaw_b: i64, q_out_ptr: i64) {
    nuc_qutil_from_euler(roll_b, pitch_b, yaw_b, q_out_ptr);
}

// Quaternion → ZYX Euler angles. Writes (roll, pitch, yaw) to
// rpy_out_ptr (3 doubles).
fn qutil_to_euler(q_ptr: i64, rpy_out_ptr: i64) {
    nuc_qutil_to_euler(q_ptr, rpy_out_ptr);
}

// q12 = q1⁻¹ · q2 — the rotation taking q1 to q2 in q1's frame.
fn qutil_relative(q1_ptr: i64, q2_ptr: i64, q_out_ptr: i64) {
    nuc_qutil_relative(q1_ptr, q2_ptr, q_out_ptr);
}

// Angular distance between two unit quaternions (radians, in
// [0, π]).
fn qutil_angular_distance(q1_ptr: i64, q2_ptr: i64) -> i64 {
    return nuc_qutil_angular_distance(q1_ptr, q2_ptr);
}
