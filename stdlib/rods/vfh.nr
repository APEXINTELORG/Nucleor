// rods/vfh — Vector Field Histogram local obstacle avoidance.
//
// Polar histogram of obstacle density around the robot, valley
// detection, choose the valley nearest the goal bearing.
// Borenstein & Koren 1991 (simplified VFH/VFH+ flavor).
//
// Algorithm:
//   1. For each occupied cell within `window_radius`, add a
//      weighted contribution to a polar histogram bin keyed by
//      cell bearing. Weight `= a − b · d²` (zero at window edge).
//   2. Smooth the histogram (3-bin circular box).
//   3. Threshold: bins below `density_threshold` are FREE.
//   4. Pick the contiguous free run ("valley") whose center
//      bearing is closest to the goal bearing; return its center
//      bearing as the steered heading.
//
// Use:
//   - Reactive obstacle-avoidance layer underneath any global
//     planner (RRT, A*, vgraph) that re-plans more slowly than
//     the local control loop.
//   - Pair with `bicycle.nr` / `purepursuit.nr` to track the
//     VFH heading.
//
// Workflow:
//
//   import "stdlib/rods/vfh.nr"
//
//   let steer_bearing: double;
//   let ok = vfh_step(occ_ptr, W, H, cell_size_b,
//                     ox_b, oy_b,
//                     occ_threshold_b,
//                     robot_x_b, robot_y_b,
//                     goal_x_b, goal_y_b,
//                     window_radius_b,
//                     n_bins,
//                     density_threshold_b,
//                     f64_ptr(&steer_bearing));
//
// **Limitations** (full VFH+ pre-thresholding masks / VFH*
// multi-step lookahead / dynamic-window cost combination land
// in v0.6 if needed):
// - 2-D occupancy only.
// - Robot modelled as a point (caller inflates the underlying
//   occupancy grid to account for vehicle radius).
// - Histogram smoothing is a simple 3-bin box.
//
// See `stdlib/runtime/vfh_rt.c`.
#cfile "../runtime/vfh_rt.c"

extern fn nuc_vfh_step(occ_ptr: i64, W_: i64, H_: i64, cell_size_b: i64,
    ox_b: i64, oy_b: i64,
    occ_threshold_b: i64,
    robot_x_b: i64, robot_y_b: i64,
    goal_x_b: i64, goal_y_b: i64,
    window_radius_b: i64, n_bins_: i64,
    density_threshold_b: i64,
    steer_bearing_out_ptr: i64) -> i64;

// Compute next steering bearing. `occ` is `double[H][W]` row-major.
// A cell is "occupied" iff its value `>= occ_threshold_b`.
// Returns 1 on success, 0 if no valley found (fully blocked) or
// bad input.
fn vfh_step(occ_ptr: i64, W_: i64, H_: i64, cell_size_b: i64,
    ox_b: i64, oy_b: i64,
    occ_threshold_b: i64,
    robot_x_b: i64, robot_y_b: i64,
    goal_x_b: i64, goal_y_b: i64,
    window_radius_b: i64, n_bins_: i64,
    density_threshold_b: i64,
    steer_bearing_out_ptr: i64) -> i64
{
    return nuc_vfh_step(occ_ptr, W_, H_, cell_size_b, ox_b, oy_b,
        occ_threshold_b, robot_x_b, robot_y_b, goal_x_b, goal_y_b,
        window_radius_b, n_bins_, density_threshold_b,
        steer_bearing_out_ptr);
}
