// v0.8.212 stdlib/rods/kdtree.nr first test coverage.
//
// k-d tree spatial index with k-NN and range search.
// Pre-v0.8.212: zero coverage on the standalone rod.
//
// Builds a 4-point 2-D tree at the corners of a unit square:
//   index 0: (0, 0)
//   index 1: (1, 0)
//   index 2: (0, 1)
//   index 3: (1, 1)
//
// Locks four invariants:
//
//   1. Build returns valid handle — non-zero for valid input.
//   2. k=1 query at (0,0) returns index 0 — querying a tree
//      point itself returns that point as nearest.
//   3. k=2 returns 2 results — k-NN size matches request.
//   4. Range search at (0.5, 0.5) with r=0.8 covers all 4 —
//      diagonal half = √(0.5²+0.5²) ≈ 0.707 < 0.8 → all in.
//
// Expected: rc=0.

import "stdlib/rods/kdtree.nr"

fn check_build_valid() -> i64 {
    let mut pts: Vec<i64> = Vec::new();
    pts.push(f64_to_bits(0.0)); pts.push(f64_to_bits(0.0));
    pts.push(f64_to_bits(1.0)); pts.push(f64_to_bits(0.0));
    pts.push(f64_to_bits(0.0)); pts.push(f64_to_bits(1.0));
    pts.push(f64_to_bits(1.0)); pts.push(f64_to_bits(1.0));
    let t: i64 = kd_build(pts, 4, 2);
    if t == 0 { return 1; };
    kd_free(t);
    return 0;
}

fn check_nearest_self_match() -> i64 {
    let mut pts: Vec<i64> = Vec::new();
    pts.push(f64_to_bits(0.0)); pts.push(f64_to_bits(0.0));
    pts.push(f64_to_bits(1.0)); pts.push(f64_to_bits(0.0));
    pts.push(f64_to_bits(0.0)); pts.push(f64_to_bits(1.0));
    pts.push(f64_to_bits(1.0)); pts.push(f64_to_bits(1.0));
    let t: i64 = kd_build(pts, 4, 2);
    let mut q: Vec<i64> = Vec::new();
    q.push(f64_to_bits(0.0)); q.push(f64_to_bits(0.0));
    let res: i64 = kd_nearest(t, q, 1);
    let idx0: i64 = vec_get(res, 0);
    kd_free(t);
    if idx0 != 0 { return 2; };
    return 0;
}

fn check_knn_size() -> i64 {
    let mut pts: Vec<i64> = Vec::new();
    pts.push(f64_to_bits(0.0)); pts.push(f64_to_bits(0.0));
    pts.push(f64_to_bits(1.0)); pts.push(f64_to_bits(0.0));
    pts.push(f64_to_bits(0.0)); pts.push(f64_to_bits(1.0));
    pts.push(f64_to_bits(1.0)); pts.push(f64_to_bits(1.0));
    let t: i64 = kd_build(pts, 4, 2);
    let mut q: Vec<i64> = Vec::new();
    q.push(f64_to_bits(0.5)); q.push(f64_to_bits(0.5));
    let res: i64 = kd_nearest(t, q, 2);
    let n: i64 = vec_len(res);
    kd_free(t);
    if n != 2 { return 4; };
    return 0;
}

fn check_range_covers_all() -> i64 {
    let mut pts: Vec<i64> = Vec::new();
    pts.push(f64_to_bits(0.0)); pts.push(f64_to_bits(0.0));
    pts.push(f64_to_bits(1.0)); pts.push(f64_to_bits(0.0));
    pts.push(f64_to_bits(0.0)); pts.push(f64_to_bits(1.0));
    pts.push(f64_to_bits(1.0)); pts.push(f64_to_bits(1.0));
    let t: i64 = kd_build(pts, 4, 2);
    let mut center: Vec<i64> = Vec::new();
    center.push(f64_to_bits(0.5)); center.push(f64_to_bits(0.5));
    let res: i64 = kd_range(t, center, f64_to_bits(0.8));
    let n: i64 = vec_len(res);
    kd_free(t);
    if n != 4 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_build_valid();
    fails = fails + check_nearest_self_match();
    fails = fails + check_knn_size();
    fails = fails + check_range_covers_all();
    return fails;
}
