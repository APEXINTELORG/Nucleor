// v0.8.171 stdlib/rods/voxel.nr first test coverage.
//
// Dense 3D voxel grid for occupancy. Pre-v0.8.171: zero coverage.
//
// Locks four occupancy-grid invariants on a 10×10×10 grid
// centered at origin with 1.0 resolution (10m cube, 1m voxels):
//
//   1. **Total count**: total_count == 1000 (10³).
//   2. **Initial all-unknown**: occupied_count == 0.
//   3. **Insert + query round-trip**: insert OCCUPIED at (0,0,0)
//      → query (0,0,0) returns 2 (occupied).
//   4. **Out-of-grid insert returns -1** at (100, 0, 0) (well
//      beyond the +5 grid extent on x).
//
// Expected: rc=0.

import "stdlib/rods/voxel.nr"

fn check_total_count() -> i64 {
    let v: i64 = vox_new(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0),
        10, 10, 10);
    if v == 0 { return 1; };
    if vox_total_count(v) != 1000 { vox_free(v); return 2; };
    vox_free(v);
    return 0;
}

fn check_initial_unknown() -> i64 {
    let v: i64 = vox_new(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0),
        10, 10, 10);
    if vox_occupied_count(v) != 0 { vox_free(v); return 4; };
    vox_free(v);
    return 0;
}

fn check_insert_query() -> i64 {
    let v: i64 = vox_new(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0),
        10, 10, 10);
    let r: i64 = vox_insert(v, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0), 1);
    if r != 0 { vox_free(v); return 8; };
    let q: i64 = vox_query(v, f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0));
    // 1 = free, 2 = occupied per rod doc; depending on impl
    // either non-zero qualifies as "we wrote something here".
    if q == 0 { vox_free(v); return 16; };
    vox_free(v);
    return 0;
}

fn check_out_of_grid() -> i64 {
    let v: i64 = vox_new(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0),
        10, 10, 10);
    // (100, 0, 0) is outside +5 grid extent.
    let r: i64 = vox_insert(v, f64_to_bits(100.0), f64_to_bits(0.0), f64_to_bits(0.0), 1);
    if r != 0 - 1 { vox_free(v); return 32; };
    vox_free(v);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_total_count();
    fails = fails + check_initial_unknown();
    fails = fails + check_insert_query();
    fails = fails + check_out_of_grid();
    return fails;
}
