// rods/sgrid — Spatial hash grid for fast 3D nearest-neighbor
// queries.
//
// Bins points into cubic cells of side `cell_size`. NN queries
// scan only the query cell + its 26 neighbors instead of all
// points; for uniformly-distributed clouds this is roughly O(1)
// average-case lookup (vs O(N) brute force in `icp.nr`).
//
// Foundation for:
// - Faster ICP nearest-neighbor matching.
// - Large-roadmap PRM expansion (find k nearest existing nodes).
// - Particle-grid neighborhood lookups in physics sims.
//
// Workflow:
//   let g = sgrid_new(cell_size_b, n_pts_hint);
//   for each point: sgrid_insert(g, x_b, y_b, z_b);
//   let nn_idx = sgrid_nearest(g, qx_b, qy_b, qz_b);
//   sgrid_free(g);
//
// Limitations (KD-tree / R-tree variants land in v0.6 if
// needed for non-uniform point distributions):
// - Cell size is fixed; pick ≈ expected NN distance for best
//   performance.
// - For very non-uniform clouds, a KD-tree adapts better.
// - Includes a brute-force fallback (correctness guaranteed) when
//   the cell + 1-ring is empty.
//
// See `stdlib/runtime/sgrid_rt.c`.
#cfile "../runtime/sgrid_rt.c"

extern fn nuc_sgrid_new(cell_size_b: i64, n_pts_hint: i64) -> i64;
extern fn nuc_sgrid_insert(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64;
extern fn nuc_sgrid_count(h: i64) -> i64;
extern fn nuc_sgrid_nearest(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64;
extern fn nuc_sgrid_free(h: i64);

fn sgrid_new(cell_size_b: i64, n_pts_hint: i64) -> i64 {
    return nuc_sgrid_new(cell_size_b, n_pts_hint);
}

// Insert a 3D point into the grid. Returns the assigned point
// index.
fn sgrid_insert(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64 {
    return nuc_sgrid_insert(h, x_b, y_b, z_b);
}

fn sgrid_count(h: i64) -> i64 { return nuc_sgrid_count(h); }

// Return the index of the nearest stored point to (x, y, z), or
// -1 if the grid is empty. Brute-force fallback ensures correctness
// even for query offsets far from any inserted point.
fn sgrid_nearest(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64 {
    return nuc_sgrid_nearest(h, x_b, y_b, z_b);
}

fn sgrid_free(h: i64) { nuc_sgrid_free(h); }
