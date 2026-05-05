// v0.8.216 stdlib/rods/octree.nr first test coverage.
//
// Sparse octree for 3-D occupancy + broad-phase collision pruning.
// Pre-v0.8.216: zero coverage on the standalone rod.
//
// Setup: root at origin, half-size 10m, max_depth 6 →
// leaf resolution = 20/2^6 ≈ 0.3125m.
//
// Locks four invariants on the occupancy state machine:
//
//   1. **Unknown before insert** — query of a never-inserted
//      point returns 0 (unknown).
//   2. **Insert + query round-trip** — insert (2.5, 1.0, 0.5)
//      as occupied → query at same point returns 2.
//   3. **Free vs occupied tracked separately** — distinct
//      points stay distinct: inserted-as-free returns 1.
//   4. **Out-of-bounds insert returns -1** — point at (50, 0, 0)
//      lies outside half-size 10m root cube.
//
// Expected: rc=0.

import "stdlib/rods/octree.nr"

fn check_unknown_before_insert() -> i64 {
    let oct: i64 = oct_new(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(10.0), 6
    );
    let q: i64 = oct_query(oct,
        f64_to_bits(2.5), f64_to_bits(1.0), f64_to_bits(0.5)
    );
    oct_free(oct);
    if q != 0 { return 1; };
    return 0;
}

fn check_insert_query_occupied() -> i64 {
    let oct: i64 = oct_new(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(10.0), 6
    );
    oct_insert(oct,
        f64_to_bits(2.5), f64_to_bits(1.0), f64_to_bits(0.5), 1
    );
    let q: i64 = oct_query(oct,
        f64_to_bits(2.5), f64_to_bits(1.0), f64_to_bits(0.5)
    );
    oct_free(oct);
    if q != 2 { return 2; };
    return 0;
}

fn check_free_vs_occupied() -> i64 {
    let oct: i64 = oct_new(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(10.0), 6
    );
    oct_insert(oct,
        f64_to_bits(2.5), f64_to_bits(1.0), f64_to_bits(0.5), 1
    );
    oct_insert(oct,
        f64_to_bits(0.0 - 5.0), f64_to_bits(0.0 - 5.0), f64_to_bits(0.0 - 5.0), 0
    );
    let q_occ: i64 = oct_query(oct,
        f64_to_bits(2.5), f64_to_bits(1.0), f64_to_bits(0.5)
    );
    let q_free: i64 = oct_query(oct,
        f64_to_bits(0.0 - 5.0), f64_to_bits(0.0 - 5.0), f64_to_bits(0.0 - 5.0)
    );
    oct_free(oct);
    if q_occ != 2 { return 4; };
    if q_free != 1 { return 8; };
    return 0;
}

fn check_out_of_bounds() -> i64 {
    let oct: i64 = oct_new(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(10.0), 6
    );
    let r: i64 = oct_insert(oct,
        f64_to_bits(50.0), f64_to_bits(0.0), f64_to_bits(0.0), 1
    );
    oct_free(oct);
    if r != (0 - 1) { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_unknown_before_insert();
    fails = fails + check_insert_query_occupied();
    fails = fails + check_free_vs_occupied();
    fails = fails + check_out_of_bounds();
    return fails;
}
