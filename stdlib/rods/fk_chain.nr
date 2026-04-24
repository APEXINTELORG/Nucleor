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
extern fn nuc_fk_chain_free(ch: i64);

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
fn fk_chain_free(ch: i64) { nuc_fk_chain_free(ch); }

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
