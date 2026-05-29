// v0.8.188 stdlib/rods/dstar.nr first test coverage.
//
// D* Lite incremental replanner on a 2-D 8-connected grid.
// Pre-v0.8.188: zero coverage.
//
// Locks four textbook D* invariants on a 5×5 grid:
//   1. Plan succeeds on open grid: start (0,0) → goal (4,4)
//      → plan returns 1 + non-empty path.
//   2. Path starts at goal end (D* paths walk from start to
//      goal; first/last cells correspond to those positions —
//      most impls return path_x[0] = start, path_x[end] = goal).
//   3. Replan after obstacle update: drop a wall in the middle
//      → replan succeeds and yields a different (possibly longer)
//      path.
//   4. Unreachable goal: enclose goal with full-row obstacles
//      → plan returns 0 (no path).
//
// Expected: rc=0.

import "stdlib/rods/dstar.nr"

fn check_plan_open_grid() -> i64 {
    let h: i64 = dstar_new(5, 5);
    dstar_set_start(h, 0, 0);
    dstar_set_goal(h, 4, 4);
    let r: i64 = dstar_plan(h);
    if r != 1 { dstar_free(h); return 1; };
    if dstar_path_len(h) <= 0 { dstar_free(h); return 2; };
    dstar_free(h);
    return 0;
}

fn check_replan_after_obstacle() -> i64 {
    let h: i64 = dstar_new(5, 5);
    dstar_set_start(h, 0, 0);
    dstar_set_goal(h, 4, 4);
    dstar_plan(h);
    let len_before: i64 = dstar_path_len(h);
    if len_before <= 0 { dstar_free(h); return 4; };
    // Drop an obstacle in the middle; -1 = obstacle shorthand
    dstar_update_cost(h, 2, 2, f64_to_bits(0.0 - 1.0));
    let r: i64 = dstar_replan(h);
    if r != 1 { dstar_free(h); return 8; };
    if dstar_path_len(h) <= 0 { dstar_free(h); return 16; };
    dstar_free(h);
    return 0;
}

fn check_unreachable_goal() -> i64 {
    let h: i64 = dstar_new(5, 5);
    dstar_set_start(h, 0, 0);
    dstar_set_goal(h, 4, 4);
    // Wall off entire row 3 (impassable for goal at (4,4) since
    // start is at (0,0))
    let mut x: i64 = 0;
    while x < 5 {
        dstar_set_cost(h, x, 3, f64_to_bits(0.0 - 1.0));
        x = x + 1;
    };
    let r: i64 = dstar_plan(h);
    if r != 0 { dstar_free(h); return 32; };
    dstar_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_plan_open_grid();
    fails = fails + check_replan_after_obstacle();
    fails = fails + check_unreachable_goal();
    return fails;
}
