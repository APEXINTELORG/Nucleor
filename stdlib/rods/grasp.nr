// rods/grasp — Grasp quality metrics for a 2-finger parallel-jaw
// gripper.
//
// A grasp is specified by two contact points and their outward-
// pointing surface normals (away from the object's interior). The
// metrics shipped:
//
// - **Antipodal score**: how aligned the grip-direction is with
//   the contact normals. Score in [-1, 1]; +1 = perfect antipodal,
//   0 = tangential, -1 = totally wrong direction. Use as a
//   continuous quality score during grasp synthesis.
//
// - **Force closure under Coulomb friction**: binary check that
//   the grasp can resist arbitrary external wrench given a
//   friction coefficient μ. For 2-contact grasps this reduces to
//   "both contact normals lie within the friction cone of the
//   grip line".
//
// - **Approach alignment**: how well-aligned an approach direction
//   is with the local surface normal. Useful for scoring candidate
//   grasps where the gripper's approach axis must avoid being
//   tangential to (or, worse, behind) the surface.
//
// **Limitations** (full convex-hull-of-friction-cone wrench-space
// metric, multi-finger generalizations, and grasp-stability
// margins land in v0.6 if needed):
// - 2-finger / 2-contact only.
// - Coulomb friction with single coefficient.
// - Point contacts (no soft / surface contacts).
//
// See `stdlib/runtime/grasp_rt.c`.
#cfile "../runtime/grasp_rt.c"

extern fn nuc_grasp_antipodal_score(
    c0_x: i64, c0_y: i64, c0_z: i64,
    n0_x: i64, n0_y: i64, n0_z: i64,
    c1_x: i64, c1_y: i64, c1_z: i64,
    n1_x: i64, n1_y: i64, n1_z: i64) -> i64;

extern fn nuc_grasp_force_closure(
    c0_x: i64, c0_y: i64, c0_z: i64,
    n0_x: i64, n0_y: i64, n0_z: i64,
    c1_x: i64, c1_y: i64, c1_z: i64,
    n1_x: i64, n1_y: i64, n1_z: i64,
    mu_b: i64) -> i64;

extern fn nuc_grasp_approach_alignment(
    n_x: i64, n_y: i64, n_z: i64,
    ax_x: i64, ax_y: i64, ax_z: i64) -> i64;

// Antipodal grasp quality score (bit-cast f64). Score in [-1, 1];
// +1 is perfect antipodal alignment.
fn grasp_antipodal_score(
    c0_x: i64, c0_y: i64, c0_z: i64,
    n0_x: i64, n0_y: i64, n0_z: i64,
    c1_x: i64, c1_y: i64, c1_z: i64,
    n1_x: i64, n1_y: i64, n1_z: i64) -> i64
{
    return nuc_grasp_antipodal_score(c0_x, c0_y, c0_z, n0_x, n0_y, n0_z,
                                      c1_x, c1_y, c1_z, n1_x, n1_y, n1_z);
}

// Returns 1 if the grasp is force-closure under coefficient μ; 0 if not.
fn grasp_force_closure(
    c0_x: i64, c0_y: i64, c0_z: i64,
    n0_x: i64, n0_y: i64, n0_z: i64,
    c1_x: i64, c1_y: i64, c1_z: i64,
    n1_x: i64, n1_y: i64, n1_z: i64,
    mu_b: i64) -> i64
{
    return nuc_grasp_force_closure(c0_x, c0_y, c0_z, n0_x, n0_y, n0_z,
                                    c1_x, c1_y, c1_z, n1_x, n1_y, n1_z, mu_b);
}

// Approach-vector alignment with surface normal: bit-cast f64 in
// [-1, 1]. +1 = head-on (approach antiparallel to normal); 0 =
// tangential; -1 = approaching from behind the surface.
fn grasp_approach_alignment(
    n_x: i64, n_y: i64, n_z: i64,
    ax_x: i64, ax_y: i64, ax_z: i64) -> i64
{
    return nuc_grasp_approach_alignment(n_x, n_y, n_z, ax_x, ax_y, ax_z);
}
