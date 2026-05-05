// v0.8.232 stdlib/rods/occgrid.nr first test coverage.
//
// 2-D log-odds probabilistic occupancy grid. Pre-v0.8.232: zero
// coverage on the standalone rod (sister to octree.nr 3-D
// occupancy).
//
// Setup: 10×20 grid, cell size 0.5 m, world origin at (0, 0).
//
// Locks four invariants (find_frontiers and update_scan use raw
// out-ptrs / array-ptrs; deferred):
//
//   1. **Topology round-trip** — width=10, height=20, cell=0.5.
//   2. **Initial probability is 0.5** — fresh grid has log-odds 0.
//   3. **update_ray drives p > 0.5 at the hit cell** — sensor
//      at (0.25, 0.25) firing a ray of range 1.0 along the
//      x-axis bearing makes the cell at (1.25, 0.25) occupied.
//   4. **clear restores p = 0.5** — after clearing the grid,
//      probability at any cell is 0.5 again.
//
// Expected: rc=0.

import "stdlib/rods/occgrid.nr"

fn close(a_bits: i64, b_bits: i64, eps: f64) -> i64 {
    let af: f64 = f64_from_bits(a_bits);
    let bf: f64 = f64_from_bits(b_bits);
    let d: f64 = af - bf;
    let abs_d: f64 = if d < 0.0 { 0.0 - d } else { d };
    if abs_d < eps { return 1; };
    return 0;
}

fn check_topology() -> i64 {
    let m: i64 = occgrid_new(10, 20, f64_to_bits(0.5),
        f64_to_bits(0.0), f64_to_bits(0.0));
    if occgrid_width(m) != 10 { occgrid_free(m); return 1; };
    if occgrid_height(m) != 20 { occgrid_free(m); return 2; };
    if close(occgrid_cell_size(m), f64_to_bits(0.5), 1e-9) != 1 {
        occgrid_free(m); return 4;
    };
    occgrid_free(m);
    return 0;
}

fn check_initial_unknown() -> i64 {
    let m: i64 = occgrid_new(10, 20, f64_to_bits(0.5),
        f64_to_bits(0.0), f64_to_bits(0.0));
    let p: i64 = occgrid_probability(m, f64_to_bits(1.0), f64_to_bits(1.0));
    occgrid_free(m);
    if close(p, f64_to_bits(0.5), 1e-6) != 1 { return 8; };
    return 0;
}

fn check_update_ray_increases_p() -> i64 {
    let m: i64 = occgrid_new(10, 20, f64_to_bits(0.5),
        f64_to_bits(0.0), f64_to_bits(0.0));
    // Sensor at (0.25, 0.25) firing along bearing 0 (x-axis) at
    // range 1.0. The hit cell is at world ≈ (1.25, 0.25).
    occgrid_update_ray(m,
        f64_to_bits(0.25), f64_to_bits(0.25),
        f64_to_bits(1.0), f64_to_bits(0.0),
        f64_to_bits(0.4), f64_to_bits(0.85), f64_to_bits(5.0)
    );
    let p: i64 = occgrid_probability(m, f64_to_bits(1.25), f64_to_bits(0.25));
    occgrid_free(m);
    let pf: f64 = f64_from_bits(p);
    if pf <= 0.5 { return 16; };
    return 0;
}

fn check_clear_restores_prior() -> i64 {
    let m: i64 = occgrid_new(10, 20, f64_to_bits(0.5),
        f64_to_bits(0.0), f64_to_bits(0.0));
    occgrid_update_ray(m,
        f64_to_bits(0.25), f64_to_bits(0.25),
        f64_to_bits(1.0), f64_to_bits(0.0),
        f64_to_bits(0.4), f64_to_bits(0.85), f64_to_bits(5.0)
    );
    occgrid_clear(m);
    let p: i64 = occgrid_probability(m, f64_to_bits(1.25), f64_to_bits(0.25));
    occgrid_free(m);
    if close(p, f64_to_bits(0.5), 1e-6) != 1 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_topology();
    fails = fails + check_initial_unknown();
    fails = fails + check_update_ray_increases_p();
    fails = fails + check_clear_restores_prior();
    return fails;
}
