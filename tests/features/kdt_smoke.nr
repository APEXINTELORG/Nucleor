// v0.8.233 stdlib/rods/kdt.nr first test coverage.
//
// 3-D KD-tree for fast nearest-neighbor queries (median-split,
// O(log n) avg query). Pre-v0.8.233: zero coverage on the
// standalone rod (sister to kdtree.nr n-D, sgrid.nr uniform
// hash, hnsw.nr approximate ANN).
//
// Insert 4 cube corners: (0,0,0), (1,0,0), (0,1,0), (1,1,1)
// with assigned indices 0..3.
//
// Locks four invariants (k-NN uses raw out-ptrs; deferred):
//
//   1. Empty tree — count == 0; nearest returns -1 before
//      any insert.
//   2. Insert tracks count — 4 inserts → count = 4.
//   3. Build returns indexed count — kdt_build → 4.
//   4. Self-match query — nearest of inserted point
//      (1, 1, 1) is index 3.
//
// Expected: rc=0.

import "stdlib/rods/kdt.nr"

fn check_empty() -> i64 {
    let h: i64 = kdt_new(8);
    if kdt_count(h) != 0 { kdt_free(h); return 1; };
    if kdt_nearest_f64(h, 0.0, 0.0, 0.0) != (0 - 1) { kdt_free(h); return 2; };
    kdt_free(h);
    return 0;
}

fn check_insert_tracks_count() -> i64 {
    let h: i64 = kdt_new(8);
    kdt_insert_f64(h, 0.0, 0.0, 0.0);
    kdt_insert_f64(h, 1.0, 0.0, 0.0);
    kdt_insert_f64(h, 0.0, 1.0, 0.0);
    kdt_insert_f64(h, 1.0, 1.0, 1.0);
    if kdt_count(h) != 4 { kdt_free(h); return 4; };
    kdt_free(h);
    return 0;
}

fn check_build_returns_count() -> i64 {
    let h: i64 = kdt_new(8);
    kdt_insert_f64(h, 0.0, 0.0, 0.0);
    kdt_insert_f64(h, 1.0, 0.0, 0.0);
    kdt_insert_f64(h, 0.0, 1.0, 0.0);
    kdt_insert_f64(h, 1.0, 1.0, 1.0);
    let r: i64 = kdt_build(h);
    kdt_free(h);
    if r != 4 { return 8; };
    return 0;
}

fn check_self_match() -> i64 {
    let h: i64 = kdt_new(8);
    kdt_insert_f64(h, 0.0, 0.0, 0.0);
    kdt_insert_f64(h, 1.0, 0.0, 0.0);
    kdt_insert_f64(h, 0.0, 1.0, 0.0);
    let last_idx: i64 = kdt_insert_f64(h, 1.0, 1.0, 1.0);
    kdt_build(h);
    let nn: i64 = kdt_nearest_f64(h, 1.0, 1.0, 1.0);
    kdt_free(h);
    if nn != last_idx { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_insert_tracks_count();
    fails = fails + check_build_returns_count();
    fails = fails + check_self_match();
    return fails;
}
