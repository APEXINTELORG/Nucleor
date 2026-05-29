// v0.8.233 stdlib/rods/vgraph.nr first test coverage.
//
// 2-D visibility graph planner — builds graph from start + goal +
// obstacle vertices and runs Dijkstra. Pre-v0.8.233: zero coverage
// on the standalone rod.
//
// Setup: empty obstacle list, start (0, 0), goal (3, 4). With no
// obstacles, the optimal path is the straight segment of length
// √(3² + 4²) = 5.
//
// Locks four invariants (add_obstacle uses raw vertices_ptr;
// deferred):
//
//   1. vgraph_new returns valid handle — non-zero.
//   2. Direct-line plan with no obstacles — path_len == 2
//      (just start + goal).
//   3. Path endpoints are start and goal — path[0] = start,
//      path[1] = goal.
//   4. Path cost = Euclidean distance — 3-4-5 triangle.
//
// Expected: rc=0.

import "stdlib/rods/vgraph.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_new_valid() -> i64 {
    let h: i64 = vgraph_new();
    if h == 0 { return 1; };
    vgraph_free(h);
    return 0;
}

fn check_direct_line_len() -> i64 {
    let h: i64 = vgraph_new();
    vgraph_set_start(h, f64_to_bits(0.0), f64_to_bits(0.0));
    vgraph_set_goal(h, f64_to_bits(3.0), f64_to_bits(4.0));
    let n: i64 = vgraph_plan(h);
    vgraph_free(h);
    if n != 2 { return 2; };
    return 0;
}

fn check_path_endpoints() -> i64 {
    let h: i64 = vgraph_new();
    vgraph_set_start(h, f64_to_bits(0.0), f64_to_bits(0.0));
    vgraph_set_goal(h, f64_to_bits(3.0), f64_to_bits(4.0));
    vgraph_plan(h);
    let x0: i64 = vgraph_path_x(h, 0);
    let y0: i64 = vgraph_path_y(h, 0);
    let x1: i64 = vgraph_path_x(h, 1);
    let y1: i64 = vgraph_path_y(h, 1);
    vgraph_free(h);
    if close(x0, f64_to_bits(0.0), 1e-9) != 1 { return 4; };
    if close(y0, f64_to_bits(0.0), 1e-9) != 1 { return 8; };
    if close(x1, f64_to_bits(3.0), 1e-9) != 1 { return 16; };
    if close(y1, f64_to_bits(4.0), 1e-9) != 1 { return 32; };
    return 0;
}

fn check_path_cost_euclidean() -> i64 {
    let h: i64 = vgraph_new();
    vgraph_set_start(h, f64_to_bits(0.0), f64_to_bits(0.0));
    vgraph_set_goal(h, f64_to_bits(3.0), f64_to_bits(4.0));
    vgraph_plan(h);
    let c: i64 = vgraph_path_cost(h);
    vgraph_free(h);
    if close(c, f64_to_bits(5.0), 1e-9) != 1 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_direct_line_len();
    fails = fails + check_path_endpoints();
    fails = fails + check_path_cost_euclidean();
    return fails;
}
