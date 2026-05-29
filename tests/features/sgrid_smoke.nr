// v0.8.171 stdlib/rods/sgrid.nr first test coverage.
//
// Spatial hash grid for fast 3D nearest-neighbor queries.
// Pre-v0.8.171: zero coverage.
//
// Locks four NN-query invariants on a small 3D point cloud:
//   1. Empty grid returns -1: nearest on empty grid → -1.
//   2. Insert returns index: first insert returns 0, second
//      returns 1, etc.
//   3. count tracks insertions: 5 inserts → count == 5.
//   4. Nearest correctness: 3 points at origin / x=10 / y=10;
//      query at (1, 0, 0) → nearest is index 0 (origin point).
//
// Expected: rc=0.

import "stdlib/rods/sgrid.nr"

fn check_empty_grid() -> i64 {
    let g: i64 = sgrid_new(f64_to_bits(1.0), 16);
    if sgrid_count(g) != 0 { sgrid_free(g); return 1; };
    if sgrid_nearest(g, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0)) != 0 - 1 {
        sgrid_free(g); return 2;
    };
    sgrid_free(g);
    return 0;
}

fn check_insert_indices() -> i64 {
    let g: i64 = sgrid_new(f64_to_bits(1.0), 16);
    let i0: i64 = sgrid_insert(g, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    let i1: i64 = sgrid_insert(g, f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0));
    if i0 != 0 { sgrid_free(g); return 4; };
    if i1 != 1 { sgrid_free(g); return 8; };
    sgrid_free(g);
    return 0;
}

fn check_count() -> i64 {
    let g: i64 = sgrid_new(f64_to_bits(1.0), 16);
    let mut i: i64 = 0;
    while i < 5 {
        sgrid_insert(g, f64_to_bits(i as f64), f64_to_bits(0.0), f64_to_bits(0.0));
        i = i + 1;
    };
    if sgrid_count(g) != 5 { sgrid_free(g); return 16; };
    sgrid_free(g);
    return 0;
}

fn check_nearest_correctness() -> i64 {
    let g: i64 = sgrid_new(f64_to_bits(1.0), 16);
    sgrid_insert(g, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    sgrid_insert(g, f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0));
    sgrid_insert(g, f64_to_bits(0.0), f64_to_bits(10.0), f64_to_bits(0.0));
    // Query at (1, 0, 0): nearest is point 0 (origin)
    let nn: i64 = sgrid_nearest(g, f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0));
    if nn != 0 { sgrid_free(g); return 32; };
    // Query at (9, 0, 0): nearest is point 1 (x=10)
    let nn2: i64 = sgrid_nearest(g, f64_to_bits(9.0), f64_to_bits(0.0), f64_to_bits(0.0));
    if nn2 != 1 { sgrid_free(g); return 64; };
    sgrid_free(g);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty_grid();
    fails = fails + check_insert_indices();
    fails = fails + check_count();
    fails = fails + check_nearest_correctness();
    return fails;
}
