// rods/occgrid — 2D log-odds probabilistic occupancy grid.
//
// Each cell stores log-odds: `0` = unknown (`p = 0.5`), positive
// = occupied, negative = free. Sensor updates use the standard
// inverse-sensor model with Bresenham-traced rays.
//
// Foundation for:
//   - 2D mobile-robot SLAM / mapping (Hector, gmapping).
//   - Free-space planning (cells with `p > 0.5` = obstacles).
//   - Frontier exploration (boundary between free and unknown).
//
// Workflow:
//
//   import "stdlib/rods/occgrid.nr"
//
//   let m = occgrid_new(W, H, cell_size_b, ox_b, oy_b);
//   occgrid_set_prior(m, log_odds_b);          // optional, default 0
//
//   // Each lidar/depth ray:
//   for ray {
//       occgrid_update_ray(m, sx_b, sy_b,
//                           range_b, bearing_b,
//                           l_free_b, l_occ_b, max_range_b);
//   }
//
//   // Query:
//   let p_b = occgrid_probability(m, x_b, y_b);
//   let is_occ = occgrid_is_occupied(m, x_b, y_b, threshold_b);
//
//   occgrid_free(m);
//
// Typical inverse-sensor parameters: `l_free = 0.4`, `l_occ = 0.85`
// (`p_free ≈ 0.40`, `p_occ ≈ 0.70` per observation), threshold 0.65.
//
// **Limitations** (3D voxel grid / probabilistic forward sensor
// model land in v0.6 if needed):
// - 2D only (use `octree.nr` for 3D occupancy).
// - Bresenham raycast (axis-aligned discretization).
// - Per-cell log-odds clamped to ±20 to avoid runaway saturation.
//
// See `stdlib/runtime/occgrid_rt.c`.
#cfile "../runtime/occgrid_rt.c"

extern fn nuc_occgrid_new(W: i64, H: i64, cell_b: i64, ox_b: i64, oy_b: i64) -> i64;
extern fn nuc_occgrid_set_prior(h: i64, lo_b: i64);
extern fn nuc_occgrid_clear(h: i64);
extern fn nuc_occgrid_update_ray(h: i64, sx_b: i64, sy_b: i64,
    range_b: i64, bearing_b: i64,
    l_free_b: i64, l_occ_b: i64, max_range_b: i64);
extern fn nuc_occgrid_log_odds(h: i64, x_b: i64, y_b: i64) -> i64;
extern fn nuc_occgrid_probability(h: i64, x_b: i64, y_b: i64) -> i64;
extern fn nuc_occgrid_is_occupied(h: i64, x_b: i64, y_b: i64, thresh_b: i64) -> i64;
extern fn nuc_occgrid_cell_log_odds(h: i64, ix: i64, iy: i64) -> i64;
extern fn nuc_occgrid_width(h: i64) -> i64;
extern fn nuc_occgrid_height(h: i64) -> i64;
extern fn nuc_occgrid_cell_size(h: i64) -> i64;
extern fn nuc_occgrid_find_frontiers(h: i64, free_thresh_b: i64,
    unknown_eps_b: i64, out_x_ptr: i64, out_y_ptr: i64, max_n: i64) -> i64;
extern fn nuc_occgrid_update_scan(h: i64,
    sx_b: i64, sy_b: i64, stheta_b: i64,
    bearings_ptr: i64, ranges_ptr: i64, n_beams: i64,
    l_free_b: i64, l_occ_b: i64, max_range_b: i64);
extern fn nuc_occgrid_free(h: i64);

// Create a `W × H` grid with `cell_size` (m), with the lower-left
// corner of cell (0, 0) at world `(ox, oy)`. All cells start at
// log-odds 0 (= unknown, `p = 0.5`).
fn occgrid_new(W: i64, H: i64, cell_b: i64, ox_b: i64, oy_b: i64) -> i64 {
    return nuc_occgrid_new(W, H, cell_b, ox_b, oy_b);
}

// Reset all cells to a given prior log-odds (default 0).
fn occgrid_set_prior(h: i64, lo_b: i64) { nuc_occgrid_set_prior(h, lo_b); }

// Reset all cells to the current prior.
fn occgrid_clear(h: i64) { nuc_occgrid_clear(h); }

// Update from a single ray emitted from sensor at `(sx, sy)` with
// world-frame bearing `bearing` (rad) and measured `range` (m).
// Cells along the ray are marked free; cell at `range` is occupied
// (if `range < max_range`, else also free / unknown).
//   `l_free_b`: per-observation free log-odds increment (typical 0.4).
//   `l_occ_b` : per-observation occupied log-odds increment (typical 0.85).
fn occgrid_update_ray(h: i64, sx_b: i64, sy_b: i64,
    range_b: i64, bearing_b: i64,
    l_free_b: i64, l_occ_b: i64, max_range_b: i64)
{
    nuc_occgrid_update_ray(h, sx_b, sy_b, range_b, bearing_b,
        l_free_b, l_occ_b, max_range_b);
}

// Query: log-odds, probability, or boolean occupancy at world (x, y).
fn occgrid_log_odds(h: i64, x_b: i64, y_b: i64) -> i64 {
    return nuc_occgrid_log_odds(h, x_b, y_b);
}
fn occgrid_probability(h: i64, x_b: i64, y_b: i64) -> i64 {
    return nuc_occgrid_probability(h, x_b, y_b);
}
fn occgrid_is_occupied(h: i64, x_b: i64, y_b: i64, thresh_b: i64) -> i64 {
    return nuc_occgrid_is_occupied(h, x_b, y_b, thresh_b);
}

// Direct cell-index accessors for grid-iteration use cases.
fn occgrid_cell_log_odds(h: i64, ix: i64, iy: i64) -> i64 {
    return nuc_occgrid_cell_log_odds(h, ix, iy);
}
fn occgrid_width(h: i64)  -> i64 { return nuc_occgrid_width(h); }
fn occgrid_height(h: i64) -> i64 { return nuc_occgrid_height(h); }
fn occgrid_cell_size(h: i64) -> i64 { return nuc_occgrid_cell_size(h); }

// Frontier detection (v0.2.290): find "free" cells with at least
// one "unknown" 4-neighbor. These are natural exploration targets.
//
// A cell is "free" iff `log-odds < free_thresh_b` (typical −0.4).
// A cell is "unknown" iff `|log-odds| < unknown_eps_b` (typical 0.05).
//
// Writes cell-center world coords to `out_x_ptr` / `out_y_ptr`
// (both `double[max_n]`). Returns the count (capped at max_n).
fn occgrid_find_frontiers(h: i64, free_thresh_b: i64,
    unknown_eps_b: i64, out_x_ptr: i64, out_y_ptr: i64, max_n: i64) -> i64
{
    return nuc_occgrid_find_frontiers(h, free_thresh_b, unknown_eps_b,
        out_x_ptr, out_y_ptr, max_n);
}

// LiDAR scan update (v0.2.292): apply every beam of a scan in one
// call. Sensor at world `(sx, sy)` with heading `stheta`.
// `bearings_ptr` (double[n_beams]) holds per-beam SENSOR-frame
// bearings (rad); `ranges_ptr` (double[n_beams]) holds measured
// ranges. Each beam's world bearing is `stheta + bearings[i]`.
//
// Internally calls `occgrid_update_ray` per beam with the shared
// `(l_free, l_occ, max_range)` parameters.
fn occgrid_update_scan(h: i64,
    sx_b: i64, sy_b: i64, stheta_b: i64,
    bearings_ptr: i64, ranges_ptr: i64, n_beams: i64,
    l_free_b: i64, l_occ_b: i64, max_range_b: i64)
{
    nuc_occgrid_update_scan(h, sx_b, sy_b, stheta_b,
        bearings_ptr, ranges_ptr, n_beams,
        l_free_b, l_occ_b, max_range_b);
}

fn occgrid_free(h: i64) { nuc_occgrid_free(h); }
