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

// === v0845 Lane 5 / Queue 5C — typed SE(3) buffer wrappers ===
//
// Pointer-based SE(3) is the right choice for inner loops (no
// per-call allocation), but the raw API loses the frame-typing
// the v0840 ROBO-7 Wave 2 compiler check provides for
// Pose<Frame_*> / Transform<From, To>. The typed wrappers below
// preserve the pointer-based hot-path while exposing a phantom
// Se3Buf<From, To> facade — adopters who want compile-time frame
// safety on inner loops bind their pointer pairs into
// Se3Buf<Frame_X, Frame_Y> and use the typed compose / inverse /
// apply / relative / distance helpers.
//
// Memory layout: Se3Buf is two i64 fields (the existing t and q
// pointers); the From/To phantoms are compile-time-only signatures
// matching the kinematics_transform.nr Transform pattern. Same
// loads, same stores, no allocation, zero-cost vs raw nuc_se3_*.
//
// Adopter pattern (pointer-based + typed):
//
//   import "stdlib/rods/se3.nr"
//   import "stdlib/rods/kinematics_frame.nr"
//
//   let bc: Se3Buf<Frame_Base, Frame_Camera> = se3_buf_new(t_bc, q_bc);
//   let cg: Se3Buf<Frame_Camera, Frame_Gripper> = se3_buf_new(t_cg, q_cg);
//   let bg_out: Se3Buf<Frame_Base, Frame_Gripper> = se3_buf_new(t_bg, q_bg);
//   se3_compose_typed(bc, cg, bg_out);
//
// Raw `se3_compose` / `se3_inverse` / `se3_apply` / `se3_relative` /
// `se3_distance` remain available for adopters who manage their own
// frame discipline; treat them as migration surfaces and prefer the
// typed forms when new code starts.

struct Se3Buf { t_ptr: i64, q_ptr: i64 }

fn se3_buf_new<F, T>(t: i64, q: i64) -> Se3Buf<F, T> {
    return Se3Buf { t_ptr: t, q_ptr: q };
}

fn se3_buf_t<F, T>(b: Se3Buf<F, T>) -> i64 { return b.t_ptr; }
fn se3_buf_q<F, T>(b: Se3Buf<F, T>) -> i64 { return b.q_ptr; }

// T_AC = T_AB · T_BC. The middle frame B must match across the two
// inputs; the v0840 ROBO-7 Wave 2 check enforces this on the
// adopter's let-binding sites for concrete frame pairs (and the
// generic-phantom-unification residual from Queue 5A applies to
// generic call sites).
fn se3_compose_typed<A, B, C>(
    ab: Se3Buf<A, B>,
    bc: Se3Buf<B, C>,
    out: Se3Buf<A, C>
) {
    nuc_se3_compose(ab.t_ptr, ab.q_ptr, bc.t_ptr, bc.q_ptr, out.t_ptr, out.q_ptr);
}

// T_inv : Se3Buf<F, T> -> Se3Buf<T, F>. Frame swap is enforced by
// the phantom-type signature; out's frames must be (T, F) at the
// adopter's let-binding site.
fn se3_inverse_typed<F, T>(in_buf: Se3Buf<F, T>, out: Se3Buf<T, F>) {
    nuc_se3_inverse(in_buf.t_ptr, in_buf.q_ptr, out.t_ptr, out.q_ptr);
}

// p_to = T_from_to · p_from. Apply a frame-To transform to a point
// expressed in the From frame.
fn se3_apply_typed<F, T>(
    tf: Se3Buf<F, T>,
    p_from_ptr: i64,
    p_to_ptr: i64
) {
    nuc_se3_apply(tf.t_ptr, tf.q_ptr, p_from_ptr, p_to_ptr);
}

// T_AB : Se3Buf<World, A> + Se3Buf<World, B> -> Se3Buf<A, B>.
// "Pose of B in A's frame" — the standard relative-pose
// computation.
fn se3_relative_typed<W, A, B>(
    a_in_w: Se3Buf<W, A>,
    b_in_w: Se3Buf<W, B>,
    out: Se3Buf<A, B>
) {
    nuc_se3_relative(a_in_w.t_ptr, a_in_w.q_ptr, b_in_w.t_ptr, b_in_w.q_ptr,
                     out.t_ptr, out.q_ptr);
}

// Distance is symmetric in the inputs but the type signature still
// pins both Se3Buf<W, A> and Se3Buf<W, B> to the same world frame
// W — adopter must use buffers expressed in the same frame.
fn se3_distance_typed<W, A, B>(
    a_in_w: Se3Buf<W, A>,
    b_in_w: Se3Buf<W, B>
) -> i64 {
    return nuc_se3_distance(a_in_w.t_ptr, a_in_w.q_ptr, b_in_w.t_ptr, b_in_w.q_ptr);
}
