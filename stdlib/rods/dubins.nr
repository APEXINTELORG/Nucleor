// rods/dubins — Shortest path for a car-like robot with minimum
// turning radius (Dubins 1957; Shkel & Lumelsky 2001 classification).
//
// Given start pose `(x0, y0, θ0)`, goal pose `(x1, y1, θ1)`, and
// minimum turning radius `R`, computes the length of the shortest
// forward-only path among the 6 Dubins word types:
//
//   0: LSL (left-straight-left)     3: RSR
//   1: LSR                            4: RLR (left-right-left — CCC)
//   2: RSL                            5: LRL
//
// "L"/"R" are turns at minimum radius; "S" is a straight segment.
//
// Use cases:
//   - Car-like steering function for Dubins-RRT / Dubins-PRM.
//   - Shortest-path oracle for global planners on Ackermann robots.
//   - Heuristic for A* over pose-graph nodes.
//
// Workflow:
//
//   import "stdlib/rods/dubins.nr"
//
//   // Shortest length only:
//   let type_out: i64;
//   let length_b = dubins_shortest(x0_b, y0_b, t0_b,
//                                   x1_b, y1_b, t1_b,
//                                   R_b, &type_out as i64);
//
//   // Length + 3 segment lengths:
//   let segs: double[3];
//   let length_b = dubins_shortest_with_segments(x0_b, y0_b, t0_b,
//                                                 x1_b, y1_b, t1_b,
//                                                 R_b, type_out_ptr,
//                                                 segs_out_ptr);
//
// Returns `-1.0` (as bit-cast f64) on infeasible (zero R or no
// valid type — should not happen for positive R and reachable goals).
//
// Limitations (path sampling / Reeds-Shepp with reverse /
// curvature-bounded smoothing land in v0.6 if needed):
// - Forward-only (no reverse motion). Use Reeds-Shepp for reverse.
// - Returns lengths and segment parameters; does not sample the
//   path into a pose sequence.
//
// See `stdlib/runtime/dubins_rt.c`.
#cfile "../runtime/dubins_rt.c"

extern fn nuc_dubins_shortest(x0_b: i64, y0_b: i64, t0_b: i64,
    x1_b: i64, y1_b: i64, t1_b: i64,
    R_b: i64, type_out_ptr: i64) -> i64;

extern fn nuc_dubins_shortest_with_segments(x0_b: i64, y0_b: i64, t0_b: i64,
    x1_b: i64, y1_b: i64, t1_b: i64,
    R_b: i64, type_out_ptr: i64, params_out_ptr: i64) -> i64;

// Shortest Dubins path length. Writes type index (0..5) to
// `type_out_ptr` (i64). Returns length as bit-cast f64, or -1.0
// on infeasible.
fn dubins_shortest(x0_b: i64, y0_b: i64, t0_b: i64,
    x1_b: i64, y1_b: i64, t1_b: i64,
    R_b: i64, type_out_ptr: i64) -> i64
{
    return nuc_dubins_shortest(x0_b, y0_b, t0_b, x1_b, y1_b, t1_b,
        R_b, type_out_ptr);
}

// Same but also writes the 3 segment lengths (in world units) to
// `params_out_ptr` (double[3]). For CSC types (0..3) the middle
// segment is a straight distance; for CCC types (4..5) all three
// are arc lengths.
fn dubins_shortest_with_segments(x0_b: i64, y0_b: i64, t0_b: i64,
    x1_b: i64, y1_b: i64, t1_b: i64,
    R_b: i64, type_out_ptr: i64, params_out_ptr: i64) -> i64
{
    return nuc_dubins_shortest_with_segments(x0_b, y0_b, t0_b,
        x1_b, y1_b, t1_b,
        R_b, type_out_ptr, params_out_ptr);
}
