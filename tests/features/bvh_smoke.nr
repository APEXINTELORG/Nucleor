// v0.8.160 stdlib/rods/bvh.nr first test coverage.
//
// Bounding Volume Hierarchy for broad-phase collision. Stores
// AABBs in a tree, supports overlap and self-pair queries.
// Pre-v0.8.160: zero coverage.
//
// Locks three textbook BVH invariants:
//   1. Overlap query: a query AABB that contains box[2] but
//      not box[0] returns 1 hit (index 2).
//   2. Disjoint pairs: 3 spatially-separated AABBs produce 0
//      self-pairs.
//   3. Overlapping pairs: 2 overlapping AABBs produce
//      exactly 1 self-pair (the pair (0, 1)).
//
// All bounding-box coordinates are f64-bits.
//
// Expected: rc=0.

import "stdlib/rods/bvh.nr"

fn check_overlap_query() -> i64 {
    let h: i64 = bvh_new();
    // 3 disjoint unit cubes at origin, x=10, y=10
    bvh_add(h,
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));
    bvh_add(h,
        f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(11.0), f64_to_bits(1.0), f64_to_bits(1.0));
    bvh_add(h,
        f64_to_bits(0.0), f64_to_bits(10.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(11.0), f64_to_bits(1.0));
    bvh_build(h);
    // Query a box that overlaps only box[2] (the y=10 cube)
    let n: i64 = bvh_query(h,
        f64_to_bits(0.5), f64_to_bits(10.5), f64_to_bits(0.5),
        f64_to_bits(0.6), f64_to_bits(10.6), f64_to_bits(0.6));
    if n != 1 { bvh_free(h); return 1; };
    let hit: i64 = bvh_query_at(h, 0);
    if hit != 2 { bvh_free(h); return 2; };
    bvh_free(h);
    return 0;
}

fn check_disjoint_self_pairs() -> i64 {
    let h: i64 = bvh_new();
    // 3 disjoint cubes — should produce 0 pairs
    bvh_add(h,
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0));
    bvh_add(h,
        f64_to_bits(10.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(11.0), f64_to_bits(1.0), f64_to_bits(1.0));
    bvh_add(h,
        f64_to_bits(20.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(21.0), f64_to_bits(1.0), f64_to_bits(1.0));
    bvh_build(h);
    let n_pairs: i64 = bvh_self_pairs(h);
    if n_pairs != 0 { bvh_free(h); return 4; };
    bvh_free(h);
    return 0;
}

fn check_overlapping_self_pairs() -> i64 {
    let h: i64 = bvh_new();
    // Two overlapping cubes
    bvh_add(h,
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(2.0), f64_to_bits(2.0), f64_to_bits(2.0));
    bvh_add(h,
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(3.0), f64_to_bits(3.0), f64_to_bits(3.0));
    bvh_build(h);
    let n_pairs: i64 = bvh_self_pairs(h);
    if n_pairs != 1 { bvh_free(h); return 8; };
    let lo: i64 = bvh_pair_lo(h, 0);
    let hi: i64 = bvh_pair_hi(h, 0);
    // Exactly one pair: (0, 1)
    if lo != 0 { bvh_free(h); return 16; };
    if hi != 1 { bvh_free(h); return 32; };
    bvh_free(h);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_overlap_query();
    fails = fails + check_disjoint_self_pairs();
    fails = fails + check_overlapping_self_pairs();
    return fails;
}
