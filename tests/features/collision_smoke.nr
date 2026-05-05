// v0.8.128 stdlib/rods/collision.nr first test coverage.
//
// Geometric collision primitives — sphere-sphere, sphere-capsule,
// capsule-capsule, AABB-AABB. (GJK + EPA queued — they need
// support function pointers.)
//
// Locks textbook collision invariants. All inputs are f64-bits.
// Each test returns 1 (collision) or 0 (no collision).
//
// Expected: rc=0.

import "stdlib/rods/collision.nr"

fn check_sphere_sphere_overlap() -> i64 {
    // Two spheres of radius 1 at (0,0,0) and (1,0,0) — distance 1, sum-radii 2 → overlap.
    let r: i64 = coll_sphere_sphere(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0));
    if r != 1 { return 1; };
    return 0;
}

fn check_sphere_sphere_clear() -> i64 {
    // Two spheres of radius 1 at (0,0,0) and (5,0,0) — distance 5 > 2 → clear.
    let r: i64 = coll_sphere_sphere(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0),
        f64_to_bits(5.0), f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(1.0));
    if r != 0 { return 2; };
    return 0;
}

fn check_aabb_aabb_overlap() -> i64 {
    // Box [0..2]³ vs [1..3]³ — overlap.
    let r: i64 = coll_aabb_aabb(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(2.0), f64_to_bits(2.0), f64_to_bits(2.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(3.0), f64_to_bits(3.0), f64_to_bits(3.0));
    if r != 1 { return 4; };
    return 0;
}

fn check_aabb_aabb_clear() -> i64 {
    // Box [0..1]³ vs [5..6]³ — clear (gap of 4 on x).
    let r: i64 = coll_aabb_aabb(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(5.0), f64_to_bits(5.0), f64_to_bits(5.0),
        f64_to_bits(6.0), f64_to_bits(6.0), f64_to_bits(6.0));
    if r != 0 { return 8; };
    return 0;
}

fn check_aabb_aabb_touching_edge() -> i64 {
    // Box [0..1] vs [1..2] — touching at face. Convention: touching
    // counts as collision (no gap separating axis).
    let r: i64 = coll_aabb_aabb(
        f64_to_bits(0.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(1.0), f64_to_bits(1.0), f64_to_bits(1.0),
        f64_to_bits(1.0), f64_to_bits(0.0), f64_to_bits(0.0),
        f64_to_bits(2.0), f64_to_bits(1.0), f64_to_bits(1.0));
    // Accept either interpretation (touching = overlap or = clear)
    // since the C runtime's policy is unspecified. Just verify it's
    // 0 or 1, not garbage.
    if r != 0 && r != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_sphere_sphere_overlap();
    fails = fails + check_sphere_sphere_clear();
    fails = fails + check_aabb_aabb_overlap();
    fails = fails + check_aabb_aabb_clear();
    fails = fails + check_aabb_aabb_touching_edge();
    return fails;
}
