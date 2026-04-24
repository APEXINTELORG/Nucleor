// rods/se3 — Pointer-based SE(3) operations on raw `(t ∈ ℝ³,
// q ∈ S³)` buffers. Compose, inverse, apply, log/exp, interp,
// distance.
//
// Complement to `kinematics.nr`'s allocated-handle Pose; like
// `qutil.nr` for rotations, this rod takes pointers directly so
// inner loops (controllers, trajectory composition, frame chains)
// can avoid per-call allocation.
//
// Convention: scalar-first quaternions `q = (w, x, y, z)`,
// Hamilton product. A pose `(t, q)` represents rotation by `q`
// followed by translation by `t`: `world_pt = q · body_pt · q⁻¹ + t`.
//
// Workflow:
//
//   import "stdlib/rods/se3.nr"
//
//   // T_C = T_A · T_B
//   se3_compose(tA_ptr, qA_ptr, tB_ptr, qB_ptr, tC_ptr, qC_ptr);
//
//   // T_inv = T⁻¹
//   se3_inverse(t_ptr, q_ptr, t_inv_ptr, q_inv_ptr);
//
//   // p_world = T · p_body
//   se3_apply(t_ptr, q_ptr, p_body_ptr, p_world_ptr);
//
//   // T_AB = T_A⁻¹ · T_B  (B in A's frame)
//   se3_relative(tA, qA, tB, qB, tAB, qAB);
//
//   // Smooth interpolation between two poses (lerp t, slerp q)
//   se3_interpolate(t1, q1, t2, q2, alpha_b, t_out, q_out);
//
//   // 6-vec twist log/exp
//   se3_log(t, q, twist_out_ptr);     // double[6] = (ρ_x, ρ_y, ρ_z, ω_x, ω_y, ω_z)
//   se3_exp(twist_ptr, t_out, q_out);
//
//   // Combined translation + rotation distance
//   let d_b = se3_distance(tA, qA, tB, qB);
//
// **Limitations** (dual quaternions / motor algebra / Plücker
// coordinates land in v0.6 if needed):
// - Translation + quaternion only.
// - SE(3) log/exp uses small-angle Taylor below 1e-9.
//
// See `stdlib/runtime/se3_rt.c`.
#cfile "../runtime/se3_rt.c"

extern fn nuc_se3_compose(t1_ptr: i64, q1_ptr: i64, t2_ptr: i64, q2_ptr: i64,
    t_out_ptr: i64, q_out_ptr: i64);
extern fn nuc_se3_inverse(t_ptr: i64, q_ptr: i64, t_out_ptr: i64, q_out_ptr: i64);
extern fn nuc_se3_apply(t_ptr: i64, q_ptr: i64, p_ptr: i64, p_out_ptr: i64);
extern fn nuc_se3_relative(tA_ptr: i64, qA_ptr: i64, tB_ptr: i64, qB_ptr: i64,
    t_out_ptr: i64, q_out_ptr: i64);
extern fn nuc_se3_interpolate(t1_ptr: i64, q1_ptr: i64, t2_ptr: i64, q2_ptr: i64,
    alpha_b: i64, t_out_ptr: i64, q_out_ptr: i64);
extern fn nuc_se3_log(t_ptr: i64, q_ptr: i64, twist_out_ptr: i64);
extern fn nuc_se3_exp(twist_ptr: i64, t_out_ptr: i64, q_out_ptr: i64);
extern fn nuc_se3_distance(tA_ptr: i64, qA_ptr: i64, tB_ptr: i64, qB_ptr: i64) -> i64;

fn se3_compose(t1_ptr: i64, q1_ptr: i64, t2_ptr: i64, q2_ptr: i64,
    t_out_ptr: i64, q_out_ptr: i64) {
    nuc_se3_compose(t1_ptr, q1_ptr, t2_ptr, q2_ptr, t_out_ptr, q_out_ptr);
}

fn se3_inverse(t_ptr: i64, q_ptr: i64, t_out_ptr: i64, q_out_ptr: i64) {
    nuc_se3_inverse(t_ptr, q_ptr, t_out_ptr, q_out_ptr);
}

fn se3_apply(t_ptr: i64, q_ptr: i64, p_ptr: i64, p_out_ptr: i64) {
    nuc_se3_apply(t_ptr, q_ptr, p_ptr, p_out_ptr);
}

fn se3_relative(tA_ptr: i64, qA_ptr: i64, tB_ptr: i64, qB_ptr: i64,
    t_out_ptr: i64, q_out_ptr: i64) {
    nuc_se3_relative(tA_ptr, qA_ptr, tB_ptr, qB_ptr, t_out_ptr, q_out_ptr);
}

fn se3_interpolate(t1_ptr: i64, q1_ptr: i64, t2_ptr: i64, q2_ptr: i64,
    alpha_b: i64, t_out_ptr: i64, q_out_ptr: i64) {
    nuc_se3_interpolate(t1_ptr, q1_ptr, t2_ptr, q2_ptr, alpha_b, t_out_ptr, q_out_ptr);
}

// SE(3) log: pose → 6-vec twist `(ρ, ω)` where ω is the rotation
// vector and ρ = V⁻¹·t with V the SO(3) left-Jacobian.
fn se3_log(t_ptr: i64, q_ptr: i64, twist_out_ptr: i64) {
    nuc_se3_log(t_ptr, q_ptr, twist_out_ptr);
}

// SE(3) exp: 6-vec twist `(ρ, ω)` → pose `(t, q)`.
fn se3_exp(twist_ptr: i64, t_out_ptr: i64, q_out_ptr: i64) {
    nuc_se3_exp(twist_ptr, t_out_ptr, q_out_ptr);
}

// Combined distance: `‖t_A − t_B‖ + 2·acos(|qA·qB|)`.
fn se3_distance(tA_ptr: i64, qA_ptr: i64, tB_ptr: i64, qB_ptr: i64) -> i64 {
    return nuc_se3_distance(tA_ptr, qA_ptr, tB_ptr, qB_ptr);
}
