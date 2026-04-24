// rods/dstar — D* Lite incremental replanner on a 2-D 8-connected
// grid (Koenig & Likhachev 2002).
//
// Solves the same single-source shortest-path problem as A*, but is
// designed for **repeated planning** when only a small fraction of
// edge costs change between queries — typical in mobile-robot
// navigation where new obstacles appear / disappear and you don't
// want to rebuild the whole plan from scratch every time.
//
// Workflow:
//
//   import "stdlib/rods/dstar.nr"
//
//   let h = dstar_new(W, H);
//
//   // Set per-cell traversal costs (default 1.0). Use very large
//   // values for obstacles or pass a negative cost as shorthand
//   // for "obstacle" (∞).
//   for y in 0..H { for x in 0..W {
//       dstar_set_cost(h, x, y, c_b);
//   }}
//   dstar_set_start(h, sx, sy);
//   dstar_set_goal(h, gx, gy);
//
//   // Initial plan from scratch.
//   dstar_plan(h);
//   for i in 0..dstar_path_len(h) {
//       let x = dstar_path_x(h, i);
//       let y = dstar_path_y(h, i);
//   }
//
//   // World changes — update affected cells, then incremental replan.
//   dstar_update_cost(h, ox1, oy1, new_c1_b);
//   dstar_update_cost(h, ox2, oy2, new_c2_b);
//   ...
//   dstar_replan(h);                  // cheap if few edges changed
//
//   dstar_free(h);
//
// Edge cost between two adjacent cells is `max(c[s], c[s'])` times
// `√2` for diagonal moves, `1` for cardinal — i.e. moving INTO an
// obstacle is forbidden. Heuristic is the octile distance, which
// is admissible AND consistent for 8-connected uniform grids.
//
// **Limitations** (any-angle planning / 3-D / continuous costs land
// in v0.6 if needed):
// - 8-connected grid only.
// - Per-cell traversal cost (uniform across all 8 incident edges
//   from that cell on the "into" side); use very large costs for
//   obstacles.
//
// See `stdlib/runtime/dstar_rt.c`.
#cfile "../runtime/dstar_rt.c"

extern fn nuc_dstar_new(W: i64, H: i64) -> i64;
extern fn nuc_dstar_set_cost(h: i64, x: i64, y: i64, c_b: i64);
extern fn nuc_dstar_set_start(h: i64, x: i64, y: i64);
extern fn nuc_dstar_set_goal(h: i64, x: i64, y: i64);
extern fn nuc_dstar_plan(h: i64) -> i64;
extern fn nuc_dstar_update_cost(h: i64, x: i64, y: i64, c_b: i64);
extern fn nuc_dstar_replan(h: i64) -> i64;
extern fn nuc_dstar_path_len(h: i64) -> i64;
extern fn nuc_dstar_path_x(h: i64, i: i64) -> i64;
extern fn nuc_dstar_path_y(h: i64, i: i64) -> i64;
extern fn nuc_dstar_path_cost(h: i64) -> i64;
extern fn nuc_dstar_free(h: i64);

// Create a W × H grid. All cells default to traversal cost 1.0.
fn dstar_new(W: i64, H: i64) -> i64 { return nuc_dstar_new(W, H); }

// Set a cell's base traversal cost. Pass a negative value as
// shorthand for "obstacle" (cost = ∞).
fn dstar_set_cost(h: i64, x: i64, y: i64, c_b: i64) {
    nuc_dstar_set_cost(h, x, y, c_b);
}

fn dstar_set_start(h: i64, x: i64, y: i64) { nuc_dstar_set_start(h, x, y); }
fn dstar_set_goal(h: i64, x: i64, y: i64)  { nuc_dstar_set_goal(h, x, y);  }

// Initial plan from scratch. Returns 1 if a path was found.
fn dstar_plan(h: i64) -> i64 { return nuc_dstar_plan(h); }

// Update a cell's traversal cost. Marks the cell + 8-neighbors as
// inconsistent so that the next `dstar_replan` does a localized
// repair instead of a full rebuild.
fn dstar_update_cost(h: i64, x: i64, y: i64, c_b: i64) {
    nuc_dstar_update_cost(h, x, y, c_b);
}

// Incremental replan after one or more `dstar_update_cost` calls.
// Returns 1 if a path is still available.
fn dstar_replan(h: i64) -> i64 { return nuc_dstar_replan(h); }

fn dstar_path_len(h: i64) -> i64 { return nuc_dstar_path_len(h); }
fn dstar_path_x(h: i64, i: i64) -> i64 { return nuc_dstar_path_x(h, i); }
fn dstar_path_y(h: i64, i: i64) -> i64 { return nuc_dstar_path_y(h, i); }

// Total cost of the current path (g(s_start)).
fn dstar_path_cost(h: i64) -> i64 { return nuc_dstar_path_cost(h); }

fn dstar_free(h: i64) { nuc_dstar_free(h); }
