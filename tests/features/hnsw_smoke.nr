// v0.8.215 stdlib/rods/hnsw.nr first test coverage.
//
// HNSW vector index — approximate nearest neighbor over Vec<f64>.
// Pre-v0.8.215: zero coverage on the standalone rod (sister to
// kdtree.nr which is exact NN over k-d trees).
//
// Setup: 2-D index with M=4, ef_construct=16. Insert 4 corner
// points of the unit square with IDs 100, 101, 102, 103.
//
// Locks four invariants:
//
//   1. **Empty index** — hnsw_size == 0 right after construction.
//   2. **Insert tracks size** — 4 inserts → size 4.
//   3. **Self-match search** — querying one of the inserted
//      vectors returns its own ID as the nearest result.
//   4. **k=1 search returns 1 result** — vec_len(search result)
//      matches the requested k.
//
// Expected: rc=0.

import "stdlib/rods/hnsw.nr"

fn vec_xy(x: f64, y: f64) -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(f64_to_bits(x));
    v.push(f64_to_bits(y));
    return v;
}

fn check_empty() -> i64 {
    let h: i64 = hnsw_new(2, 4, 16);
    if hnsw_size(h) != 0 { hnsw_free(h); return 1; };
    hnsw_free(h);
    return 0;
}

fn check_insert_tracks_size() -> i64 {
    let h: i64 = hnsw_new(2, 4, 16);
    hnsw_insert(h, vec_xy(0.0, 0.0), 100);
    hnsw_insert(h, vec_xy(1.0, 0.0), 101);
    hnsw_insert(h, vec_xy(0.0, 1.0), 102);
    hnsw_insert(h, vec_xy(1.0, 1.0), 103);
    if hnsw_size(h) != 4 { hnsw_free(h); return 2; };
    hnsw_free(h);
    return 0;
}

fn check_self_match() -> i64 {
    let h: i64 = hnsw_new(2, 4, 16);
    hnsw_insert(h, vec_xy(0.0, 0.0), 100);
    hnsw_insert(h, vec_xy(1.0, 0.0), 101);
    hnsw_insert(h, vec_xy(0.0, 1.0), 102);
    hnsw_insert(h, vec_xy(1.0, 1.0), 103);
    let res: i64 = hnsw_search(h, vec_xy(0.0, 0.0), 16, 1);
    let id0: i64 = vec_get(res, 0);
    hnsw_free(h);
    if id0 != 100 { return 4; };
    return 0;
}

fn check_search_size_k() -> i64 {
    let h: i64 = hnsw_new(2, 4, 16);
    hnsw_insert(h, vec_xy(0.0, 0.0), 100);
    hnsw_insert(h, vec_xy(1.0, 0.0), 101);
    hnsw_insert(h, vec_xy(0.0, 1.0), 102);
    hnsw_insert(h, vec_xy(1.0, 1.0), 103);
    let res: i64 = hnsw_search(h, vec_xy(0.5, 0.5), 16, 1);
    let n: i64 = vec_len(res);
    hnsw_free(h);
    if n != 1 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_insert_tracks_size();
    fails = fails + check_self_match();
    fails = fails + check_search_size_k();
    return fails;
}
