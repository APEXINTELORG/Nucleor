// rods/kinematics — 3D math primitives for robotics.
//
// Vec3, quaternion, and Pose (position + orientation) with the
// usual algebra: dot/cross/norm, axis-angle quaternion build,
// Hamilton product, conjugate, vec rotation, pose composition,
// pose inverse, point-by-pose application.
//
// All values are heap-allocated (handles are i64). Caller frees
// with the matching `*_free` when done.
//
// **Frame tagging** — RFC-0003 (typed coordinate frames) calls
// for `Pose<F: Frame>` with compile-time frame correctness. The
// generic version ships in v0.4 once Nucleor has generics
// (RFC-0024). v0.2 ships the underlying math here so the
// compute path is ready; the type-system overlay is purely
// additive.
//
// See `stdlib/runtime/kinematics_rt.c`.
#cfile "../runtime/kinematics_rt.c"

extern fn nuc_vec3_new(x_bits: i64, y_bits: i64, z_bits: i64) -> i64;
extern fn nuc_vec3_get_x(h: i64) -> i64;
extern fn nuc_vec3_get_y(h: i64) -> i64;
extern fn nuc_vec3_get_z(h: i64) -> i64;
extern fn nuc_vec3_dot(a: i64, b: i64) -> i64;
extern fn nuc_vec3_cross(a: i64, b: i64) -> i64;
extern fn nuc_vec3_norm(h: i64) -> i64;
extern fn nuc_vec3_add(a: i64, b: i64) -> i64;
extern fn nuc_vec3_scale(a: i64, s_bits: i64) -> i64;
extern fn nuc_vec3_free(h: i64);

extern fn nuc_quat_new(w_bits: i64, x_bits: i64, y_bits: i64, z_bits: i64) -> i64;
extern fn nuc_quat_identity() -> i64;
extern fn nuc_kin_quat_from_axis_angle(axis: i64, angle_bits: i64) -> i64;
extern fn nuc_quat_get_w(h: i64) -> i64;
extern fn nuc_quat_get_x(h: i64) -> i64;
extern fn nuc_quat_get_y(h: i64) -> i64;
extern fn nuc_quat_get_z(h: i64) -> i64;
extern fn nuc_kin_quat_mul(a: i64, b: i64) -> i64;
extern fn nuc_quat_conjugate(h: i64) -> i64;
extern fn nuc_quat_rotate(q: i64, v: i64) -> i64;
extern fn nuc_quat_free(h: i64);

extern fn nuc_pose_new(pos: i64, quat: i64) -> i64;
extern fn nuc_pose_identity() -> i64;
extern fn nuc_pose_get_pos(h: i64) -> i64;
extern fn nuc_pose_get_quat(h: i64) -> i64;
extern fn nuc_pose_compose(a: i64, b: i64) -> i64;
extern fn nuc_pose_inverse(h: i64) -> i64;
extern fn nuc_pose_apply(p: i64, v: i64) -> i64;
extern fn nuc_pose_free(h: i64);

// === Vec3 ===
fn vec3(x_bits: i64, y_bits: i64, z_bits: i64) -> i64 { return nuc_vec3_new(x_bits, y_bits, z_bits); }
fn vec3_x(v: i64) -> i64 { return nuc_vec3_get_x(v); }
fn vec3_y(v: i64) -> i64 { return nuc_vec3_get_y(v); }
fn vec3_z(v: i64) -> i64 { return nuc_vec3_get_z(v); }
fn vec3_dot(a: i64, b: i64) -> i64 { return nuc_vec3_dot(a, b); }
fn vec3_cross(a: i64, b: i64) -> i64 { return nuc_vec3_cross(a, b); }
fn vec3_norm(v: i64) -> i64 { return nuc_vec3_norm(v); }
fn vec3_add(a: i64, b: i64) -> i64 { return nuc_vec3_add(a, b); }
fn vec3_scale(v: i64, s_bits: i64) -> i64 { return nuc_vec3_scale(v, s_bits); }
fn vec3_free(v: i64) { nuc_vec3_free(v); }

// === Quaternion ===
fn quat(w_bits: i64, x_bits: i64, y_bits: i64, z_bits: i64) -> i64 {
    return nuc_quat_new(w_bits, x_bits, y_bits, z_bits);
}
fn quat_identity() -> i64 { return nuc_quat_identity(); }
// Renamed from `quat_from_axis_angle` 2026-05-05 to break the
// Nucleor-level + C-level symbol collision with quat.nr.
fn kin_quat_from_axis_angle(axis: i64, angle_bits: i64) -> i64 {
    return nuc_kin_quat_from_axis_angle(axis, angle_bits);
}
fn quat_w(q: i64) -> i64 { return nuc_quat_get_w(q); }
fn quat_x(q: i64) -> i64 { return nuc_quat_get_x(q); }
fn quat_y(q: i64) -> i64 { return nuc_quat_get_y(q); }
fn quat_z(q: i64) -> i64 { return nuc_quat_get_z(q); }
// Renamed from `quat_mul` 2026-05-05 to break the Nucleor-level +
// C-level symbol collision with quat.nr.
fn kin_quat_mul(a: i64, b: i64) -> i64 { return nuc_kin_quat_mul(a, b); }
fn quat_conjugate(q: i64) -> i64 { return nuc_quat_conjugate(q); }
fn quat_rotate(q: i64, v: i64) -> i64 { return nuc_quat_rotate(q, v); }
fn quat_free(q: i64) { nuc_quat_free(q); }

// === Pose ===
fn pose(pos: i64, quat: i64) -> i64 { return nuc_pose_new(pos, quat); }
fn pose_identity() -> i64 { return nuc_pose_identity(); }
fn pose_pos(p: i64) -> i64 { return nuc_pose_get_pos(p); }
fn pose_quat(p: i64) -> i64 { return nuc_pose_get_quat(p); }
fn pose_compose(a: i64, b: i64) -> i64 { return nuc_pose_compose(a, b); }
fn pose_inverse(p: i64) -> i64 { return nuc_pose_inverse(p); }
fn pose_apply(p: i64, v: i64) -> i64 { return nuc_pose_apply(p, v); }
fn pose_free(p: i64) { nuc_pose_free(p); }

// === Ergonomic f64 wrappers (v0.4.261) ===
//
// The `*_bits: i64` and `-> i64` (where the i64 is f64-bit-pattern)
// shape across the rod above matches the i64-everywhere FFI ABI.
// These wrappers hide the bits plumbing so adopters write
// `vec3_f64(1.0, 2.0, 3.0)` instead of
// `vec3(f64_to_bits(1.0), f64_to_bits(2.0), f64_to_bits(3.0))`.
// The bits-ABI fns above remain — purely additive.

// --- Vec3 ---
fn vec3_f64(x: f64, y: f64, z: f64) -> i64 {
    return nuc_vec3_new(f64_to_bits(x), f64_to_bits(y), f64_to_bits(z));
}
fn vec3_x_f64(v: i64) -> f64 { return f64_from_bits(nuc_vec3_get_x(v)); }
fn vec3_y_f64(v: i64) -> f64 { return f64_from_bits(nuc_vec3_get_y(v)); }
fn vec3_z_f64(v: i64) -> f64 { return f64_from_bits(nuc_vec3_get_z(v)); }
fn vec3_dot_f64(a: i64, b: i64) -> f64 { return f64_from_bits(nuc_vec3_dot(a, b)); }
fn vec3_norm_f64(v: i64) -> f64 { return f64_from_bits(nuc_vec3_norm(v)); }
fn vec3_scale_f64(v: i64, s: f64) -> i64 {
    return nuc_vec3_scale(v, f64_to_bits(s));
}

// --- Quaternion ---
fn quat_f64(w: f64, x: f64, y: f64, z: f64) -> i64 {
    return nuc_quat_new(f64_to_bits(w), f64_to_bits(x), f64_to_bits(y), f64_to_bits(z));
}
fn quat_from_axis_angle_f64(axis: i64, angle: f64) -> i64 {
    return nuc_kin_quat_from_axis_angle(axis, f64_to_bits(angle));
}
fn quat_w_f64(q: i64) -> f64 { return f64_from_bits(nuc_quat_get_w(q)); }
fn quat_x_f64(q: i64) -> f64 { return f64_from_bits(nuc_quat_get_x(q)); }
fn quat_y_f64(q: i64) -> f64 { return f64_from_bits(nuc_quat_get_y(q)); }
fn quat_z_f64(q: i64) -> f64 { return f64_from_bits(nuc_quat_get_z(q)); }
