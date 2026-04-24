// rods/urdf — Minimal URDF parser + FK chain integration.
//
// URDF (Unified Robot Description Format) is the de-facto standard
// for describing robot kinematics. This rod parses a subset of
// URDF that's sufficient to construct an FK chain for IK, motion
// planning, and trajectory work.
//
// Supported per-joint:
//   <joint name="..." type="revolute|prismatic|fixed|continuous">
//     <origin xyz="x y z" rpy="r p y"/>
//     <axis xyz="x y z"/>
//     <limit lower="..." upper="..." effort="..." velocity="..."/>
//   </joint>
//
// **Limitations** (full URDF compliance lands in v0.6 if needed):
// - Linear-chain assumption: joints are loaded in source order
//   from base to tip. <parent>/<child> link relationships are NOT
//   used to reconstruct the topology — branching trees (humanoids)
//   are flattened to source-order. Fine for serial arms.
// - "continuous" joint type treated as "revolute".
// - Mesh / visual / collision / inertial subtrees skipped.
// - xacro <xacro:include> NOT resolved — preprocess to plain URDF.
//
// Workflow:
//   let urdf = urdf_new();
//   urdf_parse(urdf, str_to_ptr(my_urdf_string));
//   let chain = urdf_to_fk_chain(urdf);   // FK chain handle
//   // ... use chain for IK / planning / trajectories ...
//
// See `stdlib/runtime/urdf_rt.c`.
#cfile "../runtime/urdf_rt.c"

// fk_chain.nr provides the FK chain primitives we build into and
// chains its #cfile so urdf_to_fk_chain links correctly.
import "stdlib/rods/fk_chain.nr"

extern fn nuc_urdf_new() -> i64;
extern fn nuc_urdf_parse(h: i64, src_ptr: i64) -> i64;
extern fn nuc_urdf_joint_count(h: i64) -> i64;
extern fn nuc_urdf_joint_type(h: i64, i: i64) -> i64;
extern fn nuc_urdf_joint_axis(h: i64, i: i64, dim: i64) -> i64;
extern fn nuc_urdf_joint_origin_xyz(h: i64, i: i64, dim: i64) -> i64;
extern fn nuc_urdf_joint_origin_rpy(h: i64, i: i64, dim: i64) -> i64;
extern fn nuc_urdf_joint_limit_lo(h: i64, i: i64) -> i64;
extern fn nuc_urdf_joint_limit_hi(h: i64, i: i64) -> i64;
extern fn nuc_urdf_joint_has_limit(h: i64, i: i64) -> i64;
extern fn nuc_urdf_to_fk_chain(h: i64) -> i64;
extern fn nuc_urdf_free(h: i64);

fn urdf_new() -> i64 { return nuc_urdf_new(); }

// Parse a URDF string. The source is provided as a raw NUL-
// terminated text buffer pointer (caller-owned). Joints are
// appended in source-order. Returns the number of joints parsed.
fn urdf_parse(h: i64, src_ptr: i64) -> i64 {
    return nuc_urdf_parse(h, src_ptr);
}

fn urdf_joint_count(h: i64) -> i64 { return nuc_urdf_joint_count(h); }

// Joint type: 0 = revolute (or continuous), 1 = prismatic, 2 = fixed.
fn urdf_joint_type(h: i64, i: i64) -> i64 { return nuc_urdf_joint_type(h, i); }

// Per-axis components of the joint's axis-of-motion (bit-cast f64).
// dim = 0 (x) / 1 (y) / 2 (z).
fn urdf_joint_axis(h: i64, i: i64, dim: i64) -> i64 {
    return nuc_urdf_joint_axis(h, i, dim);
}

// Per-axis components of the joint's parent-to-child position offset
// (bit-cast f64). dim = 0 (x) / 1 (y) / 2 (z).
fn urdf_joint_origin_xyz(h: i64, i: i64, dim: i64) -> i64 {
    return nuc_urdf_joint_origin_xyz(h, i, dim);
}

// Per-axis components of the joint's RPY rotation (bit-cast f64).
// dim = 0 (roll) / 1 (pitch) / 2 (yaw). Rotation convention is
// R_z(yaw) · R_y(pitch) · R_x(roll), the URDF default.
fn urdf_joint_origin_rpy(h: i64, i: i64, dim: i64) -> i64 {
    return nuc_urdf_joint_origin_rpy(h, i, dim);
}

// Joint-variable lower/upper limit if specified in <limit>;
// undefined (returns 0) if the joint has no <limit> element.
// Use `urdf_joint_has_limit` to disambiguate.
fn urdf_joint_limit_lo(h: i64, i: i64) -> i64 { return nuc_urdf_joint_limit_lo(h, i); }
fn urdf_joint_limit_hi(h: i64, i: i64) -> i64 { return nuc_urdf_joint_limit_hi(h, i); }
fn urdf_joint_has_limit(h: i64, i: i64) -> i64 { return nuc_urdf_joint_has_limit(h, i); }

// Construct an FK chain (see `fk_chain.nr`) from the parsed URDF,
// treating the joint sequence as a serial chain. Returns the FK
// chain handle. RPY origin rotations are converted to quaternions
// internally.
fn urdf_to_fk_chain(h: i64) -> i64 { return nuc_urdf_to_fk_chain(h); }

fn urdf_free(h: i64) { nuc_urdf_free(h); }
