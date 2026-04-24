// rods/vgraph — 2D Visibility Graph planner.
//
// Builds a graph whose vertices are the start, the goal, and every
// vertex of every (convex) polygonal obstacle. Two vertices are
// connected by an edge of weight = Euclidean distance iff the
// straight segment between them is collision-free. Then runs
// Dijkstra from start to goal.
//
// Foundation for:
//   - 2D mobile-robot path planning with known polygonal world.
//   - Optimal-path baseline against sampling planners (RRT/PRM).
//   - Pre-processing for hierarchical planners.
//
// Workflow:
//
//   import "stdlib/rods/vgraph.nr"
//
//   let h = vgraph_new();
//
//   // Add convex obstacles. `vertices_ptr` is double[n_vert * 2]
//   // (x, y interleaved) in counter-clockwise order. Vertices are
//   // copied internally.
//   vgraph_add_obstacle(h, vertices_ptr, n_vert);
//   ...
//
//   vgraph_set_start(h, sx_b, sy_b);
//   vgraph_set_goal(h,  gx_b, gy_b);
//
//   let n = vgraph_plan(h);   // returns path length (≥ 2 on success)
//
//   for i in 0..n {
//       let x_b = vgraph_path_x(h, i);
//       let y_b = vgraph_path_y(h, i);
//   }
//
//   vgraph_free(h);
//
// **Limitations** (concave obstacles / inflation / 3D / dynamic
// obstacles land in v0.6 if needed):
// - Convex obstacles only (vertex order: counter-clockwise).
//   Concave obstacles need decomposition first.
// - Brute-force visibility check: `O(V² · E_obs)`. Fine for ≤ ~100
//   total vertices.
// - No vertex inflation — caller is responsible for inflating
//   obstacles to account for robot size.
//
// See `stdlib/runtime/vgraph_rt.c`.
#cfile "../runtime/vgraph_rt.c"

extern fn nuc_vgraph_new() -> i64;
extern fn nuc_vgraph_add_obstacle(h: i64, vertices_ptr: i64, n_vert: i64) -> i64;
extern fn nuc_vgraph_set_start(h: i64, x_b: i64, y_b: i64);
extern fn nuc_vgraph_set_goal(h: i64, x_b: i64, y_b: i64);
extern fn nuc_vgraph_plan(h: i64) -> i64;
extern fn nuc_vgraph_path_len(h: i64) -> i64;
extern fn nuc_vgraph_path_x(h: i64, i: i64) -> i64;
extern fn nuc_vgraph_path_y(h: i64, i: i64) -> i64;
extern fn nuc_vgraph_path_cost(h: i64) -> i64;
extern fn nuc_vgraph_free(h: i64);

fn vgraph_new() -> i64 { return nuc_vgraph_new(); }

fn vgraph_add_obstacle(h: i64, vertices_ptr: i64, n_vert: i64) -> i64 {
    return nuc_vgraph_add_obstacle(h, vertices_ptr, n_vert);
}

fn vgraph_set_start(h: i64, x_b: i64, y_b: i64) { nuc_vgraph_set_start(h, x_b, y_b); }
fn vgraph_set_goal(h: i64, x_b: i64, y_b: i64)  { nuc_vgraph_set_goal(h, x_b, y_b); }

// Plan from start to goal. Returns path length (number of waypoints
// including start and goal; ≥ 2 on success; 0 if no path).
fn vgraph_plan(h: i64) -> i64 { return nuc_vgraph_plan(h); }

fn vgraph_path_len(h: i64) -> i64 { return nuc_vgraph_path_len(h); }
fn vgraph_path_x(h: i64, i: i64) -> i64 { return nuc_vgraph_path_x(h, i); }
fn vgraph_path_y(h: i64, i: i64) -> i64 { return nuc_vgraph_path_y(h, i); }
fn vgraph_path_cost(h: i64) -> i64 { return nuc_vgraph_path_cost(h); }

fn vgraph_free(h: i64) { nuc_vgraph_free(h); }
