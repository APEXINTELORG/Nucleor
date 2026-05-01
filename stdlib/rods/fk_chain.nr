// rods/fk_chain — Forward kinematics for a serial joint chain.
//
// Build a chain of joints (revolute / prismatic / fixed), each with
// a parent-to-child base offset (pose) and a joint axis (Vec3).
// Given a flat array of joint variables (one per joint), compute
// every link's world-frame pose via cumulative pose composition.
//
// Joint type tags:
//   0 = revolute  (variable = angle in radians about `axis`)
//   1 = prismatic (variable = displacement along `axis`)
//   2 = fixed     (variable ignored)
//
// Companion to `kinematics.nr` (the underlying Vec3 / quaternion /
// Pose primitives). RFC-0013 (URDF static frame chain
// verification) targets this runtime as the compute backend; the
// URDF parser + frame-chain check land in v0.5.
//
// See `stdlib/runtime/fk_chain_rt.c`.
#cfile "../runtime/fk_chain_rt.c"

extern fn nuc_fk_chain_new() -> i64;
extern fn nuc_fk_chain_add_joint(
    ch: i64,
    joint_type: i64,
    off_x_bits: i64, off_y_bits: i64, off_z_bits: i64,
    off_qw_bits: i64, off_qx_bits: i64, off_qy_bits: i64, off_qz_bits: i64,
    axis_x_bits: i64, axis_y_bits: i64, axis_z_bits: i64) -> i64;
extern fn nuc_fk_chain_count(ch: i64) -> i64;
extern fn nuc_fk_chain_update(ch: i64, vars_ptr: i64) -> i64;
extern fn nuc_fk_chain_link_pos_x(ch: i64, i: i64) -> i64;
extern fn nuc_fk_chain_link_pos_y(ch: i64, i: i64) -> i64;
extern fn nuc_fk_chain_link_pos_z(ch: i64, i: i64) -> i64;
extern fn nuc_fk_chain_link_quat_w(ch: i64, i: i64) -> i64;
extern fn nuc_fk_chain_link_quat_x(ch: i64, i: i64) -> i64;
extern fn nuc_fk_chain_link_quat_y(ch: i64, i: i64) -> i64;
extern fn nuc_fk_chain_link_quat_z(ch: i64, i: i64) -> i64;
extern fn nuc_fk_chain_add_dh_joint(ch: i64, alpha_bits: i64, a_bits: i64, d_bits: i64, theta_bits: i64) -> i64;
extern fn nuc_fk_chain_free(ch: i64);

// Per-joint metadata accessors (v0.2.207). Joint type is one of
// 0 = revolute, 1 = prismatic, 2 = fixed. Joint axis is the axis-
// of-motion in the joint's body frame.
extern fn nuc_fk_chain_joint_type(ch: i64, i: i64) -> i64;
extern fn nuc_fk_chain_joint_axis(ch: i64, i: i64, dim: i64) -> i64;

// Workspace sampling (v0.2.209). Sample n_samples uniformly random
// joint configurations within per-joint [lo, hi] bounds, run FK on
// each, and write end-effector world positions to a caller-allocated
// double[n_samples * 3] buffer. Useful for "what can this arm reach"
// visualization, reachable-set estimation, and seeding workspace-
// coordinate IK / RRT initialization. xorshift32 RNG seeded from
// `seed`. Returns the actual number of samples written.
extern fn nuc_fk_workspace_sample(
    ch: i64, n_samples: i64, seed: i64,
    lo_ptr: i64, hi_ptr: i64, out_xyz_ptr: i64) -> i64;
extern fn nuc_fk_workspace_aabb(
    positions_ptr: i64, n_positions: i64, out_aabb_ptr: i64) -> i64;
extern fn nuc_fk_workspace_aabb_volume(aabb_ptr: i64) -> i64;

// Joint type tags for fk_add_joint.
fn fk_revolute() -> i64 { return 0; }
fn fk_prismatic() -> i64 { return 1; }
fn fk_fixed() -> i64 { return 2; }

fn fk_chain_new() -> i64 { return nuc_fk_chain_new(); }
fn fk_chain_count(ch: i64) -> i64 { return nuc_fk_chain_count(ch); }
fn fk_chain_update(ch: i64, vars_ptr: i64) -> i64 { return nuc_fk_chain_update(ch, vars_ptr); }
fn fk_chain_link_pos_x(ch: i64, i: i64) -> i64 { return nuc_fk_chain_link_pos_x(ch, i); }
fn fk_chain_link_pos_y(ch: i64, i: i64) -> i64 { return nuc_fk_chain_link_pos_y(ch, i); }
fn fk_chain_link_pos_z(ch: i64, i: i64) -> i64 { return nuc_fk_chain_link_pos_z(ch, i); }
fn fk_chain_link_quat_w(ch: i64, i: i64) -> i64 { return nuc_fk_chain_link_quat_w(ch, i); }
fn fk_chain_link_quat_x(ch: i64, i: i64) -> i64 { return nuc_fk_chain_link_quat_x(ch, i); }
fn fk_chain_link_quat_y(ch: i64, i: i64) -> i64 { return nuc_fk_chain_link_quat_y(ch, i); }
fn fk_chain_link_quat_z(ch: i64, i: i64) -> i64 { return nuc_fk_chain_link_quat_z(ch, i); }
fn fk_chain_free(ch: i64) { nuc_fk_chain_free(ch); }

fn fk_chain_joint_type(ch: i64, i: i64) -> i64 {
    return nuc_fk_chain_joint_type(ch, i);
}
fn fk_chain_joint_axis(ch: i64, i: i64, dim: i64) -> i64 {
    return nuc_fk_chain_joint_axis(ch, i, dim);
}

// Workspace sampling primitives (v0.2.209). See extern doc above.
fn fk_workspace_sample(ch: i64, n_samples: i64, seed: i64,
    lo_ptr: i64, hi_ptr: i64, out_xyz_ptr: i64) -> i64 {
    return nuc_fk_workspace_sample(ch, n_samples, seed,
                                    lo_ptr, hi_ptr, out_xyz_ptr);
}
fn fk_workspace_aabb(positions_ptr: i64, n_positions: i64,
                     out_aabb_ptr: i64) -> i64 {
    return nuc_fk_workspace_aabb(positions_ptr, n_positions, out_aabb_ptr);
}
fn fk_workspace_aabb_volume(aabb_ptr: i64) -> i64 {
    return nuc_fk_workspace_aabb_volume(aabb_ptr);
}

// Add a joint described by Denavit-Hartenberg parameters (Spong's
// Robot Modeling and Control). Convenience wrapper for the common
// industrial-arm description format. Always creates a revolute
// joint about z; for prismatic, use fk_chain_add_joint with
// FK_PRISMATIC and a custom axis.
//
//   alpha — twist angle about previous x (rad)
//   a     — link length along previous x (m)
//   d     — link offset along previous z (m)
//   theta — joint angle about previous z (rad); the static offset
//           (joint variable adds to this at FK time)
fn fk_chain_add_dh_joint(ch: i64, alpha_bits: i64, a_bits: i64, d_bits: i64, theta_bits: i64) -> i64 {
    return nuc_fk_chain_add_dh_joint(ch, alpha_bits, a_bits, d_bits, theta_bits);
}

// Add a joint to the chain. Returns its 0-indexed slot.
//
//   - joint_type: 0 (revolute) | 1 (prismatic) | 2 (fixed)
//   - off_*: parent-to-child base offset (translation + quaternion)
//   - axis_*: joint axis (Vec3) — used for the variable's degree
//     of freedom; ignored for fixed joints
//
// All `*_bits` parameters are f64 reinterpreted as i64.
fn fk_chain_add_joint(
    ch: i64, joint_type: i64,
    off_x: i64, off_y: i64, off_z: i64,
    off_qw: i64, off_qx: i64, off_qy: i64, off_qz: i64,
    axis_x: i64, axis_y: i64, axis_z: i64) -> i64 {
    return nuc_fk_chain_add_joint(ch, joint_type,
        off_x, off_y, off_z, off_qw, off_qx, off_qy, off_qz,
        axis_x, axis_y, axis_z);
}

// === Ergonomic f64 wrappers (v0.4.266) ===
//
// Same pattern as units/kinematics/linalg/csv_table/kdt/
// trajectory/rrt — hide the i64-bits-ABI behind f64-typed
// surface for the eleven fk_chain fns whose i64 carries an
// f64 bit pattern (DH params, base offsets, joint axes, link
// pos/quat readers, joint-axis getter). Adopters writing
// kinematic-chain code skip the per-call `f64_to_bits` /
// `f64_from_bits` plumbing. The bits-ABI fns above remain —
// purely additive.

// --- DH joint constructor (4 bits-in) ---
fn fk_chain_add_dh_joint_f64(ch: i64,
    alpha: f64, a: f64, d: f64, theta: f64) -> i64
{
    return nuc_fk_chain_add_dh_joint(ch,
        f64_to_bits(alpha), f64_to_bits(a),
        f64_to_bits(d), f64_to_bits(theta));
}

// --- Generic joint constructor (10 bits-in) ---
fn fk_chain_add_joint_f64(
    ch: i64, joint_type: i64,
    off_x: f64, off_y: f64, off_z: f64,
    off_qw: f64, off_qx: f64, off_qy: f64, off_qz: f64,
    axis_x: f64, axis_y: f64, axis_z: f64) -> i64
{
    return nuc_fk_chain_add_joint(ch, joint_type,
        f64_to_bits(off_x), f64_to_bits(off_y), f64_to_bits(off_z),
        f64_to_bits(off_qw), f64_to_bits(off_qx),
        f64_to_bits(off_qy), f64_to_bits(off_qz),
        f64_to_bits(axis_x), f64_to_bits(axis_y), f64_to_bits(axis_z));
}

// --- Link pos / quat readers (7 bits-out) ---
fn fk_chain_link_pos_x_f64(ch: i64, i: i64) -> f64 {
    return f64_from_bits(nuc_fk_chain_link_pos_x(ch, i));
}
fn fk_chain_link_pos_y_f64(ch: i64, i: i64) -> f64 {
    return f64_from_bits(nuc_fk_chain_link_pos_y(ch, i));
}
fn fk_chain_link_pos_z_f64(ch: i64, i: i64) -> f64 {
    return f64_from_bits(nuc_fk_chain_link_pos_z(ch, i));
}
fn fk_chain_link_quat_w_f64(ch: i64, i: i64) -> f64 {
    return f64_from_bits(nuc_fk_chain_link_quat_w(ch, i));
}
fn fk_chain_link_quat_x_f64(ch: i64, i: i64) -> f64 {
    return f64_from_bits(nuc_fk_chain_link_quat_x(ch, i));
}
fn fk_chain_link_quat_y_f64(ch: i64, i: i64) -> f64 {
    return f64_from_bits(nuc_fk_chain_link_quat_y(ch, i));
}
fn fk_chain_link_quat_z_f64(ch: i64, i: i64) -> f64 {
    return f64_from_bits(nuc_fk_chain_link_quat_z(ch, i));
}

// --- Joint axis component reader (1 bits-out) ---
fn fk_chain_joint_axis_f64(ch: i64, i: i64, dim: i64) -> f64 {
    return f64_from_bits(nuc_fk_chain_joint_axis(ch, i, dim));
}
