// rods/bvh — Bounding Volume Hierarchy for broad-phase collision.
//
// Stores N axis-aligned bounding boxes (AABBs); builds a binary
// tree where each internal node's box contains the boxes of its
// children. Supports two queries:
//
//   - **Overlap query**: given an AABB, return all stored AABB
//     indices whose boxes overlap.
//   - **Self-pair query**: return all (i, j) i < j where stored
//     boxes overlap each other. Use this to enumerate the
//     candidate object pairs to check with narrow-phase tests.
//
// Companion to `collision.nr`'s narrow-phase primitives — use
// BVH to cull non-overlapping pairs cheaply (O(N log N) typical),
// then apply narrow-phase to the survivors.
//
// Build is top-down median split along the longest axis (object
// median). Foundation for collision-aware motion planning at
// scale (v0.5 follow-on of RFC-0013).
//
// See `stdlib/runtime/bvh_rt.c`.
#cfile "../runtime/bvh_rt.c"

extern fn nuc_bvh_new() -> i64;
extern fn nuc_bvh_add(h: i64,
    minx_b: i64, miny_b: i64, minz_b: i64,
    maxx_b: i64, maxy_b: i64, maxz_b: i64) -> i64;
extern fn nuc_bvh_build(h: i64) -> i64;
extern fn nuc_bvh_query(h: i64,
    minx_b: i64, miny_b: i64, minz_b: i64,
    maxx_b: i64, maxy_b: i64, maxz_b: i64) -> i64;
extern fn nuc_bvh_query_at(h: i64, i: i64) -> i64;
extern fn nuc_bvh_self_pairs(h: i64) -> i64;
extern fn nuc_bvh_pair_lo(h: i64, i: i64) -> i64;
extern fn nuc_bvh_pair_hi(h: i64, i: i64) -> i64;
extern fn nuc_bvh_free(h: i64);

fn bvh_new() -> i64 { return nuc_bvh_new(); }
fn bvh_add(h: i64,
    minx: i64, miny: i64, minz: i64,
    maxx: i64, maxy: i64, maxz: i64) -> i64 {
    return nuc_bvh_add(h, minx, miny, minz, maxx, maxy, maxz);
}
fn bvh_build(h: i64) -> i64 { return nuc_bvh_build(h); }
fn bvh_query(h: i64,
    minx: i64, miny: i64, minz: i64,
    maxx: i64, maxy: i64, maxz: i64) -> i64 {
    return nuc_bvh_query(h, minx, miny, minz, maxx, maxy, maxz);
}
fn bvh_query_at(h: i64, i: i64) -> i64 { return nuc_bvh_query_at(h, i); }
fn bvh_self_pairs(h: i64) -> i64 { return nuc_bvh_self_pairs(h); }
fn bvh_pair_lo(h: i64, i: i64) -> i64 { return nuc_bvh_pair_lo(h, i); }
fn bvh_pair_hi(h: i64, i: i64) -> i64 { return nuc_bvh_pair_hi(h, i); }
fn bvh_free(h: i64) { nuc_bvh_free(h); }
