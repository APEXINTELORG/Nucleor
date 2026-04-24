// rods/reach — Monte Carlo reachability mapper for arm robots.
//
// Samples N joint configurations uniformly within per-joint bounds,
// runs a user-supplied forward-kinematics callback on each, stores
// the resulting end-effector positions as a workspace cloud.
//
// Foundation for:
//   - Workspace volume estimation (sample density × cell volume).
//   - Reachable-region queries ("can the end-effector reach this
//     position at all?").
//   - Manipulability shaping (combine with `kdt.nr` or `sgrid.nr`
//     for spatial queries).
//
// FK callback signature:
//   `fn(joints_ptr, ee_xyz_out_ptr) -> i64`
//   - `joints_ptr`: `double[n_joints]` joint values
//   - `ee_xyz_out_ptr`: `double[3]` for end-effector (X, Y, Z) output
//
// Workflow:
//
//   import "stdlib/rods/reach.nr"
//
//   let h = reach_new(n_joints, n_samples, seed);
//   for j in 0..n_joints {
//       reach_set_joint_limit(h, j, lo_j_b, hi_j_b);
//   }
//   reach_compute(h, fk_fp);
//
//   let n = reach_count(h);
//   for s in 0..n {
//       let x_b = reach_get_ee(h, s, 0);
//       let y_b = reach_get_ee(h, s, 1);
//       let z_b = reach_get_ee(h, s, 2);
//   }
//
//   // Density query:
//   let n_in = reach_density_in_sphere(h, x_b, y_b, z_b, radius_b);
//
//   // Workspace bounding-box extent on axis 0/1/2 (writes [min, max]):
//   reach_workspace_extent(h, axis, out_ptr);
//
//   reach_free(h);
//
// **Limitations** (joint-limit-aware sampling / non-uniform priors /
// KD-tree-accelerated queries land in v0.6 if needed):
// - Uniform sampling within per-joint bounds (no manifold sampling
//   for closed kinematic chains).
// - Brute-force density query: `O(N)` per query. For many queries,
//   pipe the EE samples through `kdt.nr` or `sgrid.nr`.
// - End-effector POSITION only (no orientation). 6-D variant in v0.6.
//
// See `stdlib/runtime/reach_rt.c`.
#cfile "../runtime/reach_rt.c"

extern fn nuc_reach_new(n_joints: i64, n_samples: i64, seed: i64) -> i64;
extern fn nuc_reach_set_joint_limit(h: i64, j: i64, lo_b: i64, hi_b: i64);
extern fn nuc_reach_compute(h: i64, fk_fp: i64) -> i64;
extern fn nuc_reach_count(h: i64) -> i64;
extern fn nuc_reach_get_ee(h: i64, sample: i64, dim: i64) -> i64;
extern fn nuc_reach_density_in_sphere(h: i64, x_b: i64, y_b: i64, z_b: i64, r_b: i64) -> i64;
extern fn nuc_reach_workspace_extent(h: i64, axis: i64, out_ptr: i64);
extern fn nuc_reach_free(h: i64);

fn reach_new(n_joints: i64, n_samples: i64, seed: i64) -> i64 {
    return nuc_reach_new(n_joints, n_samples, seed);
}
fn reach_set_joint_limit(h: i64, j: i64, lo_b: i64, hi_b: i64) {
    nuc_reach_set_joint_limit(h, j, lo_b, hi_b);
}

// Run the sampling. Returns the number of samples computed.
fn reach_compute(h: i64, fk_fp: i64) -> i64 {
    return nuc_reach_compute(h, fk_fp);
}

fn reach_count(h: i64) -> i64 { return nuc_reach_count(h); }

// End-effector coordinate of sample s, axis dim ∈ {0, 1, 2}.
fn reach_get_ee(h: i64, sample: i64, dim: i64) -> i64 {
    return nuc_reach_get_ee(h, sample, dim);
}

// Count of samples within a sphere of radius r at (x, y, z).
fn reach_density_in_sphere(h: i64, x_b: i64, y_b: i64, z_b: i64, r_b: i64) -> i64 {
    return nuc_reach_density_in_sphere(h, x_b, y_b, z_b, r_b);
}

// Writes (min, max) of EE positions on `axis` ∈ {0, 1, 2} to
// `out_ptr` (double[2]).
fn reach_workspace_extent(h: i64, axis: i64, out_ptr: i64) {
    nuc_reach_workspace_extent(h, axis, out_ptr);
}

fn reach_free(h: i64) { nuc_reach_free(h); }
