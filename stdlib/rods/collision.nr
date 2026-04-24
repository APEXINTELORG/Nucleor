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

// GJK (Gilbert-Johnson-Keerthi) — convex-convex overlap test for
// arbitrary convex shapes. The user supplies two support function
// pointers; each takes a Vec3 direction handle (allocated by GJK,
// 3 doubles malloc'd) and returns a Vec3 point handle (the point
// on the shape farthest in that direction). The user fn is
// responsible for freeing the direction Vec3 it received and
// returning a freshly malloc'd point Vec3 (GJK frees the point).
//
// Returns 1 (overlap), 0 (clear), or -1 if convergence failed.
extern fn nuc_coll_gjk(support_a_fp: i64, support_b_fp: i64) -> i64;

// Sphere-OBB cross-pair (v0.2.197). Oriented bounding box has
// center, half-extents, and orientation quaternion. The sphere
// center is rotated into the OBB's local frame, then the standard
// sphere-AABB clamp test runs against the half-extents.
extern fn nuc_coll_sphere_obb(
    sx: i64, sy: i64, sz: i64, sr: i64,
    cx: i64, cy: i64, cz: i64,
    hx: i64, hy: i64, hz: i64,
    qw: i64, qx: i64, qy: i64, qz: i64) -> i64;

// CCD: continuous sphere-sphere (v0.2.196). Two moving spheres
// from (a0, ar) → (a1, ar) and (b0, br) → (b1, br) over a unit
// time interval. Returns the earliest collision time t ∈ [0, 1]
// as a bit-cast f64; returns -1.0 (bit-cast) if no collision.
extern fn nuc_coll_ccd_sphere_sphere(
    a0x: i64, a0y: i64, a0z: i64,
    a1x: i64, a1y: i64, a1z: i64, ar: i64,
    b0x: i64, b0y: i64, b0z: i64,
    b1x: i64, b1y: i64, b1z: i64, br: i64) -> i64;

// Sphere-AABB cross-pair (v0.2.195).
extern fn nuc_coll_sphere_aabb(
    sx: i64, sy: i64, sz: i64, sr: i64,
    minx: i64, miny: i64, minz: i64,
    maxx: i64, maxy: i64, maxz: i64) -> i64;

// Capsule-AABB cross-pair (v0.2.195). Slightly conservative
// at the rounded corners of the AABB-Minkowski-expanded box;
// exact rounded-corner rejection ships in v0.5.
extern fn nuc_coll_capsule_aabb(
    c_ax: i64, c_ay: i64, c_az: i64,
    c_bx: i64, c_by: i64, c_bz: i64, cr: i64,
    minx: i64, miny: i64, minz: i64,
    maxx: i64, maxy: i64, maxz: i64) -> i64;

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

fn coll_gjk(support_a_fp: i64, support_b_fp: i64) -> i64 {
    return nuc_coll_gjk(support_a_fp, support_b_fp);
}

fn coll_sphere_obb(
    sx: i64, sy: i64, sz: i64, sr: i64,
    cx: i64, cy: i64, cz: i64,
    hx: i64, hy: i64, hz: i64,
    qw: i64, qx: i64, qy: i64, qz: i64) -> i64 {
    return nuc_coll_sphere_obb(sx, sy, sz, sr, cx, cy, cz, hx, hy, hz, qw, qx, qy, qz);
}

fn coll_ccd_sphere_sphere(
    a0x: i64, a0y: i64, a0z: i64,
    a1x: i64, a1y: i64, a1z: i64, ar: i64,
    b0x: i64, b0y: i64, b0z: i64,
    b1x: i64, b1y: i64, b1z: i64, br: i64) -> i64 {
    return nuc_coll_ccd_sphere_sphere(a0x, a0y, a0z, a1x, a1y, a1z, ar,
                                       b0x, b0y, b0z, b1x, b1y, b1z, br);
}

fn coll_sphere_aabb(
    sx: i64, sy: i64, sz: i64, sr: i64,
    minx: i64, miny: i64, minz: i64,
    maxx: i64, maxy: i64, maxz: i64) -> i64 {
    return nuc_coll_sphere_aabb(sx, sy, sz, sr, minx, miny, minz, maxx, maxy, maxz);
}

fn coll_capsule_aabb(
    c_ax: i64, c_ay: i64, c_az: i64,
    c_bx: i64, c_by: i64, c_bz: i64, cr: i64,
    minx: i64, miny: i64, minz: i64,
    maxx: i64, maxy: i64, maxz: i64) -> i64 {
    return nuc_coll_capsule_aabb(c_ax, c_ay, c_az, c_bx, c_by, c_bz, cr,
                                  minx, miny, minz, maxx, maxy, maxz);
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
