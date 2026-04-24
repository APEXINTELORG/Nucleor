// rods/quat — Unit-quaternion utilities for 3-D rotation.
//
// Quaternions stored as `double[4]` packed `(w, x, y, z)` with
// `w` the scalar part. Foundational primitives for 3-D robotics:
// IMU sensor fusion, robot arm joint orientations, smooth
// orientation interpolation, SLAM rotation parameterization.
//
// Operations:
//   `quat_from_axis_angle(axis_xyz, theta, q_out)` — build q
//   `quat_to_axis_angle(q, axis_out, theta_out)` — invert
//   `quat_mul(a, b, out)` — Hamilton product
//   `quat_normalize(q_inplace)` — re-unit-norm
//   `quat_slerp(a, b, t, out)` — spherical linear interpolation
//   `quat_rotate_vec(q, v, out)` — apply rotation q to vector v
//
// Workflow:
//
//   import "stdlib/rods/quat.nr"
//
//   let q: [4]double;
//   let _ = quat_from_axis_angle(f64_ptr(&axis[0]), theta_b,
//                                  f64_ptr(&q[0]));
//
//   let q_mid: [4]double;
//   let _ = quat_slerp(f64_ptr(&q_a[0]), f64_ptr(&q_b[0]),
//                       t_b, f64_ptr(&q_mid[0]));
//
// **Limitations** (rotor / dual-quaternion / quaternion exp+log
// land in v0.6 if needed):
// - Caller responsible for normalizing inputs.
// - No rotation-matrix conversion (use `stdlib/rods/rotation.nr`
//   if you need 3x3 matrices).
//
// See `stdlib/runtime/quat_rt.c`.
#cfile "../runtime/quat_rt.c"

extern fn nuc_quat_from_axis_angle(axis_ptr: i64, theta_b: i64, q_out_ptr: i64) -> i64;
extern fn nuc_quat_to_axis_angle(q_ptr: i64, axis_out_ptr: i64, theta_out_ptr: i64) -> i64;
extern fn nuc_quat_mul(a_ptr: i64, b_ptr: i64, out_ptr: i64) -> i64;
extern fn nuc_quat_normalize(q_ptr: i64) -> i64;
extern fn nuc_quat_slerp(a_ptr: i64, b_ptr: i64, t_b: i64, out_ptr: i64) -> i64;
extern fn nuc_quat_rotate_vec(q_ptr: i64, v_ptr: i64, out_ptr: i64) -> i64;

// Build a unit quaternion from a normalized rotation axis (3 doubles)
// and a rotation angle (radians). Writes 4 doubles (w, x, y, z) to q_out.
fn quat_from_axis_angle(axis_ptr: i64, theta_b: i64, q_out_ptr: i64) -> i64 {
    return nuc_quat_from_axis_angle(axis_ptr, theta_b, q_out_ptr);
}

// Decompose a unit quaternion into (axis, angle). Writes axis to
// `axis_out_ptr` (3 doubles) and angle to `theta_out_ptr` (1 double).
fn quat_to_axis_angle(q_ptr: i64, axis_out_ptr: i64, theta_out_ptr: i64) -> i64 {
    return nuc_quat_to_axis_angle(q_ptr, axis_out_ptr, theta_out_ptr);
}

// Hamilton product: `out = a * b`. Equivalent to "rotate by b then by a"
// when applied to a vector via `quat_rotate_vec`.
fn quat_mul(a_ptr: i64, b_ptr: i64, out_ptr: i64) -> i64 {
    return nuc_quat_mul(a_ptr, b_ptr, out_ptr);
}

// Renormalize q in place to unit length. Returns 0 if q was the
// zero quaternion (fills with identity (1, 0, 0, 0) in that case).
fn quat_normalize(q_ptr: i64) -> i64 {
    return nuc_quat_normalize(q_ptr);
}

// Spherical linear interpolation between two unit quaternions at
// parameter t ∈ [0, 1]. Picks the shorter arc; falls back to
// normalized linear interpolation when q's are nearly parallel.
fn quat_slerp(a_ptr: i64, b_ptr: i64, t_b: i64, out_ptr: i64) -> i64 {
    return nuc_quat_slerp(a_ptr, b_ptr, t_b, out_ptr);
}

// Apply rotation q to vector v: `out = q * v * q⁻¹`. Optimized
// formula (no quaternion-vector multiplication); ~15 flops.
fn quat_rotate_vec(q_ptr: i64, v_ptr: i64, out_ptr: i64) -> i64 {
    return nuc_quat_rotate_vec(q_ptr, v_ptr, out_ptr);
}
