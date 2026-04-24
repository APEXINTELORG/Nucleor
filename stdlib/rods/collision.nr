// rods/collision — Geometric collision primitives for robotics.
//
// Sphere-sphere, sphere-capsule, capsule-capsule, AABB-AABB
// overlap. Each test returns 1 (collision) or 0 (no collision).
//
// Foundation for collision-aware motion planning (v0.5 follow-on
// of RFC-0013). Use as a leaf primitive in BVH / spatial-hash
// broad-phase + this narrow-phase pipeline.
//
// All inputs are i64-bit-cast doubles (xyz components and radii).
// No allocation; each call is pure compute.
//
// See `stdlib/runtime/collision_rt.c`.
#cfile "../runtime/collision_rt.c"

extern fn nuc_coll_sphere_sphere(
    ax: i64, ay: i64, az: i64, ar: i64,
    bx: i64, by: i64, bz: i64, br: i64) -> i64;

extern fn nuc_coll_sphere_capsule(
    sx: i64, sy: i64, sz: i64, sr: i64,
    c_ax: i64, c_ay: i64, c_az: i64,
    c_bx: i64, c_by: i64, c_bz: i64, cr: i64) -> i64;

extern fn nuc_coll_capsule_capsule(
    a_ax: i64, a_ay: i64, a_az: i64,
    a_bx: i64, a_by: i64, a_bz: i64, ar: i64,
    b_ax: i64, b_ay: i64, b_az: i64,
    b_bx: i64, b_by: i64, b_bz: i64, br: i64) -> i64;

extern fn nuc_coll_aabb_aabb(
    a_minx: i64, a_miny: i64, a_minz: i64,
    a_maxx: i64, a_maxy: i64, a_maxz: i64,
    b_minx: i64, b_miny: i64, b_minz: i64,
    b_maxx: i64, b_maxy: i64, b_maxz: i64) -> i64;

fn coll_sphere_sphere(
    ax: i64, ay: i64, az: i64, ar: i64,
    bx: i64, by: i64, bz: i64, br: i64) -> i64 {
    return nuc_coll_sphere_sphere(ax, ay, az, ar, bx, by, bz, br);
}

fn coll_sphere_capsule(
    sx: i64, sy: i64, sz: i64, sr: i64,
    c_ax: i64, c_ay: i64, c_az: i64,
    c_bx: i64, c_by: i64, c_bz: i64, cr: i64) -> i64 {
    return nuc_coll_sphere_capsule(sx, sy, sz, sr, c_ax, c_ay, c_az, c_bx, c_by, c_bz, cr);
}

fn coll_capsule_capsule(
    a_ax: i64, a_ay: i64, a_az: i64,
    a_bx: i64, a_by: i64, a_bz: i64, ar: i64,
    b_ax: i64, b_ay: i64, b_az: i64,
    b_bx: i64, b_by: i64, b_bz: i64, br: i64) -> i64 {
    return nuc_coll_capsule_capsule(
        a_ax, a_ay, a_az, a_bx, a_by, a_bz, ar,
        b_ax, b_ay, b_az, b_bx, b_by, b_bz, br);
}

fn coll_aabb_aabb(
    a_minx: i64, a_miny: i64, a_minz: i64,
    a_maxx: i64, a_maxy: i64, a_maxz: i64,
    b_minx: i64, b_miny: i64, b_minz: i64,
    b_maxx: i64, b_maxy: i64, b_maxz: i64) -> i64 {
    return nuc_coll_aabb_aabb(
        a_minx, a_miny, a_minz, a_maxx, a_maxy, a_maxz,
        b_minx, b_miny, b_minz, b_maxx, b_maxy, b_maxz);
}
