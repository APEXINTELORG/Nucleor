// rods/kdt — 3D KD-tree for fast nearest-neighbor queries.
//
// Complementary to:
// - `sgrid.nr` — uniform-cell spatial hash grid. Best when point
//   distribution is roughly uniform and cell size can be picked up
//   front. Constant-time average lookup; cell size is fixed.
// - `kdtree.nr` — general n-dimensional kd-tree with a separate
//   point-vector handle. Best for ML/clustering where points are
//   already in a `vec` and dimensionality varies.
// - `kdt.nr` (this rod) — 3D-specific kd-tree with the same
//   insert/query workflow as `sgrid.nr`. Adapts to non-uniform
//   point distributions via median-split instead of fixed binning.
//   Best when the workspace has dense + sparse regions and you
//   don't want to tune a cell size.
//
// Performance: O(n log² n) build (qsort-based median-split) +
// O(log n) average-case nearest-neighbor query with bounding-box
// pruning. Heap-based k-NN with proper splitting-plane pruning.
//
// Workflow:
//
//   import "stdlib/rods/kdt.nr"
//
//   let h = kdt_new(n_pts_hint);
//   for each point (x, y, z) {
//       kdt_insert(h, f64_to_bits(x), f64_to_bits(y), f64_to_bits(z));
//   }
//   kdt_build(h);                  // call ONCE after all inserts
//
//   // Nearest-neighbor:
//   let nn_idx = kdt_nearest(h, qx_b, qy_b, qz_b);
//
//   // k-Nearest:
//   //   `out_indices_ptr` — caller-allocated `i64[k]` (or 0 to skip)
//   //   `out_dist2_ptr`   — caller-allocated `double[k]` (or 0 to skip)
//   let n = kdt_knearest(h, qx_b, qy_b, qz_b, k,
//                        out_indices_ptr, out_dist2_ptr);
//
//   kdt_free(h);
//
// Inserting after `kdt_build` invalidates the tree; call `kdt_build`
// again before further queries.
//
// **Limitations** (incremental rebuild / R*-tree / approximate-NN
// land in v0.6 if needed):
// - Static tree: must rebuild after any insert.
// - 3D only.
//
// See `stdlib/runtime/kdt_rt.c`.
#cfile "../runtime/kdt_rt.c"

extern fn nuc_kdt_new(n_pts_hint: i64) -> i64;
extern fn nuc_kdt_insert(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64;
extern fn nuc_kdt_count(h: i64) -> i64;
extern fn nuc_kdt_build(h: i64) -> i64;
extern fn nuc_kdt_nearest(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64;
extern fn nuc_kdt_knearest(h: i64, x_b: i64, y_b: i64, z_b: i64,
    k: i64, out_indices_ptr: i64, out_dist2_ptr: i64) -> i64;
extern fn nuc_kdt_free(h: i64);

// Create an empty 3D KD-tree. `n_pts_hint` reserves capacity (the
// tree grows dynamically beyond it as needed).
fn kdt_new(n_pts_hint: i64) -> i64 { return nuc_kdt_new(n_pts_hint); }

// Insert a 3D point. Coordinates are bit-cast f64s. Returns the
// assigned point index. Inserting after `kdt_build` invalidates the
// tree (you must call `kdt_build` again before querying).
fn kdt_insert(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64 {
    return nuc_kdt_insert(h, x_b, y_b, z_b);
}

fn kdt_count(h: i64) -> i64 { return nuc_kdt_count(h); }

// Build the tree from currently-inserted points. Call once after
// all `kdt_insert` calls and before any query. Returns the number
// of points indexed.
fn kdt_build(h: i64) -> i64 { return nuc_kdt_build(h); }

// Return the index of the nearest stored point to (x, y, z), or
// -1 if the tree is empty or hasn't been built. Average O(log n).
fn kdt_nearest(h: i64, x_b: i64, y_b: i64, z_b: i64) -> i64 {
    return nuc_kdt_nearest(h, x_b, y_b, z_b);
}

// k-nearest-neighbor query. `out_indices_ptr` is a caller-allocated
// `i64[k]` buffer (or 0 to skip indices output); `out_dist2_ptr` is
// a caller-allocated `double[k]` buffer (or 0 to skip distances
// output). Results are sorted nearest-first. Returns the number
// of neighbors actually filled (≤ k; less than k only if the tree
// has fewer than k points).
fn kdt_knearest(h: i64, x_b: i64, y_b: i64, z_b: i64,
    k: i64, out_indices_ptr: i64, out_dist2_ptr: i64) -> i64
{
    return nuc_kdt_knearest(h, x_b, y_b, z_b, k,
        out_indices_ptr, out_dist2_ptr);
}

fn kdt_free(h: i64) { nuc_kdt_free(h); }
