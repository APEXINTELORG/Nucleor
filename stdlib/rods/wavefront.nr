// rods/wavefront — 2D BFS / Dijkstra-lite distance transform.
//
// Given a `W × H` traversability grid and one or more start cells,
// compute the shortest per-cell distance to any start, propagated
// along traversable cells. Two connectivity modes: 4-neighbor
// (unit cost) or 8-neighbor (unit cardinal + √2 diagonal).
//
// Foundation for:
//   - Navigation cost field for mobile robots (nearest-obstacle or
//     nearest-goal distance).
//   - Frontier utility scoring (distance from robot to each
//     frontier from `occgrid_find_frontiers`).
//   - Connected-component analysis.
//   - Path shape smoothing via gradient descent on the field.
//
// Workflow:
//
//   import "stdlib/rods/wavefront.nr"
//
//   // trav: i64[W*H]  (1 = traversable, 0 = obstacle)
//   // starts: i64[n_starts * 2]  (ix, iy interleaved)
//   // dist_out: double[W*H]  (written with distances; ∞ = unreachable)
//
//   let reached = wavefront_compute(W, H,
//                                    trav_ptr,
//                                    n_starts, starts_ptr,
//                                    dist_out_ptr,
//                                    connectivity);
//
// **Limitations** (fast-sweeping Eikonal / anisotropic costs land
// in v0.6 if needed):
// - Unit-ish cost per step only (with √2 diagonal bonus).
// - Output is cell-count distance (multiply by cell size for metres).
// - Single field per call.
//
// See `stdlib/runtime/wavefront_rt.c`.
#cfile "../runtime/wavefront_rt.c"

extern fn nuc_wavefront_compute(W: i64, H: i64,
    trav_ptr: i64,
    n_starts: i64, starts_ptr: i64,
    dist_out_ptr: i64,
    connectivity: i64) -> i64;

// Compute the wavefront distance field. Returns the number of
// cells reachable from any start.
//
// `connectivity` is 4 or 8.
fn wavefront_compute(W: i64, H: i64,
    trav_ptr: i64,
    n_starts: i64, starts_ptr: i64,
    dist_out_ptr: i64,
    connectivity: i64) -> i64
{
    return nuc_wavefront_compute(W, H, trav_ptr,
        n_starts, starts_ptr,
        dist_out_ptr, connectivity);
}
