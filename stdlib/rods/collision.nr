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

// EPA (Expanding Polytope Algorithm) — penetration depth + contact
// normal for two overlapping convex shapes (v0.2.202). Same support-
// function contract as GJK. After determining the polytope of the
// Minkowski difference contains the origin, EPA expands it iteratively
// until it finds the face nearest the origin — the distance from the
// origin to that face is the penetration depth, and the face normal
// points along the minimum-translation vector to separate the shapes.
//
// `out_normal_h` is a handle to a caller-allocated `double[3]` that
// EPA fills with the unit contact normal (from B into A).
//
// Returns the penetration depth as a bit-cast f64; -1.0 (bit-cast) if
// the shapes are not overlapping (caller should have checked GJK
// first).
extern fn nuc_coll_gjk_epa(support_a_fp: i64, support_b_fp: i64,
                          out_normal_h: i64) -> i64;

// Convex-mesh GJK + EPA (v0.2.205). Convenience entry points
// for the common case where each shape is a convex polytope
// represented as a flat `double[n*3]` vertex array. No support-
// function pointer required — the runtime computes the support
// inline by scanning the vertices.
//
// For non-convex meshes, the caller must decompose the mesh into
// convex pieces (V-HACD or similar) and run pairwise queries.
extern fn nuc_coll_gjk_mesh_mesh(verts_a_ptr: i64, n_a: i64,
                                verts_b_ptr: i64, n_b: i64) -> i64;
extern fn nuc_coll_gjk_epa_mesh_mesh(verts_a_ptr: i64, n_a: i64,
                                    verts_b_ptr: i64, n_b: i64,
                                    out_normal_h: i64) -> i64;

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

// CCD: continuous capsule-capsule (v0.2.201). Both capsules sweep
// linearly between their starting and ending endpoint positions
// over a unit time interval. Uses 16-step bracket + 16-step
// bisection on segment-segment distance. Returns earliest
// collision time t ∈ [0, 1] as bit-cast f64; -1.0 if clear.
extern fn nuc_coll_ccd_capsule_capsule(
    a_a0x: i64, a_a0y: i64, a_a0z: i64,
    a_a1x: i64, a_a1y: i64, a_a1z: i64,
    a_b0x: i64, a_b0y: i64, a_b0z: i64,
    a_b1x: i64, a_b1y: i64, a_b1z: i64, ar: i64,
    b_a0x: i64, b_a0y: i64, b_a0z: i64,
    b_a1x: i64, b_a1y: i64, b_a1z: i64,
    b_b0x: i64, b_b0y: i64, b_b0z: i64,
    b_b1x: i64, b_b1y: i64, b_b1z: i64, br: i64) -> i64;

// CCD: moving sphere vs static AABB (v0.2.201). Sphere center
// linear-sweeps from s0 → s1 over a unit time interval. Same
// bracket + bisect approach.
extern fn nuc_coll_ccd_sphere_aabb(
    s0x: i64, s0y: i64, s0z: i64,
    s1x: i64, s1y: i64, s1z: i64, sr: i64,
    minx: i64, miny: i64, minz: i64,
    maxx: i64, maxy: i64, maxz: i64) -> i64;

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

// 2D polygon-polygon collision via SAT (v0.2.243). Convex,
// CCW-wound polygons only. Returns 1 if overlap, 0 if separated,
// -1 on bad input. Foundation for 2D mobile-robot footprint
// collision and planar gripper-jaw checks.
extern fn nuc_coll_poly2d_sat(
    pts_a_ptr: i64, na: i64,
    pts_b_ptr: i64, nb: i64) -> i64;

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

fn coll_gjk_epa(support_a_fp: i64, support_b_fp: i64, out_normal_h: i64) -> i64 {
    return nuc_coll_gjk_epa(support_a_fp, support_b_fp, out_normal_h);
}

fn coll_gjk_mesh_mesh(verts_a_ptr: i64, n_a: i64,
                     verts_b_ptr: i64, n_b: i64) -> i64 {
    return nuc_coll_gjk_mesh_mesh(verts_a_ptr, n_a, verts_b_ptr, n_b);
}

fn coll_gjk_epa_mesh_mesh(verts_a_ptr: i64, n_a: i64,
                         verts_b_ptr: i64, n_b: i64,
                         out_normal_h: i64) -> i64 {
    return nuc_coll_gjk_epa_mesh_mesh(verts_a_ptr, n_a,
                                       verts_b_ptr, n_b, out_normal_h);
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

fn coll_ccd_capsule_capsule(
    a_a0x: i64, a_a0y: i64, a_a0z: i64,
    a_a1x: i64, a_a1y: i64, a_a1z: i64,
    a_b0x: i64, a_b0y: i64, a_b0z: i64,
    a_b1x: i64, a_b1y: i64, a_b1z: i64, ar: i64,
    b_a0x: i64, b_a0y: i64, b_a0z: i64,
    b_a1x: i64, b_a1y: i64, b_a1z: i64,
    b_b0x: i64, b_b0y: i64, b_b0z: i64,
    b_b1x: i64, b_b1y: i64, b_b1z: i64, br: i64) -> i64 {
    return nuc_coll_ccd_capsule_capsule(
        a_a0x, a_a0y, a_a0z, a_a1x, a_a1y, a_a1z,
        a_b0x, a_b0y, a_b0z, a_b1x, a_b1y, a_b1z, ar,
        b_a0x, b_a0y, b_a0z, b_a1x, b_a1y, b_a1z,
        b_b0x, b_b0y, b_b0z, b_b1x, b_b1y, b_b1z, br);
}

fn coll_ccd_sphere_aabb(
    s0x: i64, s0y: i64, s0z: i64,
    s1x: i64, s1y: i64, s1z: i64, sr: i64,
    minx: i64, miny: i64, minz: i64,
    maxx: i64, maxy: i64, maxz: i64) -> i64 {
    return nuc_coll_ccd_sphere_aabb(s0x, s0y, s0z, s1x, s1y, s1z, sr,
                                     minx, miny, minz, maxx, maxy, maxz);
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

fn coll_poly2d_sat(pts_a_ptr: i64, na: i64,
    pts_b_ptr: i64, nb: i64) -> i64
{
    return nuc_coll_poly2d_sat(pts_a_ptr, na, pts_b_ptr, nb);
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
