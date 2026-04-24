// collision_rt.c — Geometric collision primitives for robotics.
//
// Sphere-sphere, sphere-capsule, capsule-capsule, plus axis-
// aligned bounding-box (AABB) overlap. Each test returns:
//   1 = collision
//   0 = no collision
//
// Primitive shapes:
//   Sphere   = (center: Vec3, radius)
//   Capsule  = (segment: Vec3 a, Vec3 b, radius)
//   AABB     = (min: Vec3, max: Vec3)
//
// Foundation for collision-aware motion planning (v0.5 RFC-0013
// follow-on). All inputs are i64-bit-cast doubles; functions
// allocate nothing, just read inputs and return 0/1.
//
// Compile: clang -c stdlib/runtime/collision_rt.c -o target/coll.obj -O2

#include <math.h>
#include <string.h>
#include <stdlib.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// ---- Sphere-Sphere ----
long long nuc_coll_sphere_sphere(
    long long ax, long long ay, long long az, long long ar,
    long long bx, long long by, long long bz, long long br)
{
    double dx = _i2f(ax) - _i2f(bx);
    double dy = _i2f(ay) - _i2f(by);
    double dz = _i2f(az) - _i2f(bz);
    double sum_r = _i2f(ar) + _i2f(br);
    return (dx*dx + dy*dy + dz*dz <= sum_r*sum_r) ? 1 : 0;
}

// Helper: closest distance squared between point p and segment [a, b].
static double _point_segment_dist2(double px, double py, double pz,
                                   double ax, double ay, double az,
                                   double bx, double by, double bz)
{
    double abx = bx - ax, aby = by - ay, abz = bz - az;
    double apx = px - ax, apy = py - ay, apz = pz - az;
    double ab_dot_ab = abx*abx + aby*aby + abz*abz;
    if (ab_dot_ab == 0.0) {
        // Degenerate segment, just point-point.
        return apx*apx + apy*apy + apz*apz;
    }
    double t = (apx*abx + apy*aby + apz*abz) / ab_dot_ab;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    double cx = ax + t*abx, cy = ay + t*aby, cz = az + t*abz;
    double dx = px - cx, dy = py - cy, dz = pz - cz;
    return dx*dx + dy*dy + dz*dz;
}

// Helper: closest distance squared between two segments [a1, a2] and [b1, b2].
// Standard segment-segment closest-point algorithm (Real-Time Collision
// Detection, Ericson, sec 5.1.9).
static double _segment_segment_dist2(double a1x, double a1y, double a1z,
                                     double a2x, double a2y, double a2z,
                                     double b1x, double b1y, double b1z,
                                     double b2x, double b2y, double b2z)
{
    double dax = a2x - a1x, day = a2y - a1y, daz = a2z - a1z;
    double dbx = b2x - b1x, dby = b2y - b1y, dbz = b2z - b1z;
    double rx = a1x - b1x, ry = a1y - b1y, rz = a1z - b1z;
    double a = dax*dax + day*day + daz*daz; // |dA|^2
    double e = dbx*dbx + dby*dby + dbz*dbz; // |dB|^2
    double f = dbx*rx + dby*ry + dbz*rz;
    double s, t;
    if (a <= 1e-12 && e <= 1e-12) {
        // Both segments degenerate to points.
        s = t = 0;
    } else if (a <= 1e-12) {
        s = 0;
        t = f / e;
        if (t < 0) t = 0; if (t > 1) t = 1;
    } else {
        double c = dax*rx + day*ry + daz*rz;
        if (e <= 1e-12) {
            t = 0;
            s = -c / a;
            if (s < 0) s = 0; if (s > 1) s = 1;
        } else {
            double b = dax*dbx + day*dby + daz*dbz;
            double denom = a*e - b*b;
            if (denom != 0) {
                s = (b*f - c*e) / denom;
                if (s < 0) s = 0; if (s > 1) s = 1;
            } else {
                s = 0;
            }
            t = (b*s + f) / e;
            if (t < 0) {
                t = 0;
                s = -c / a;
                if (s < 0) s = 0; if (s > 1) s = 1;
            } else if (t > 1) {
                t = 1;
                s = (b - c) / a;
                if (s < 0) s = 0; if (s > 1) s = 1;
            }
        }
    }
    double cax = a1x + dax*s, cay = a1y + day*s, caz = a1z + daz*s;
    double cbx = b1x + dbx*t, cby = b1y + dby*t, cbz = b1z + dbz*t;
    double dx = cax - cbx, dy = cay - cby, dz = caz - cbz;
    return dx*dx + dy*dy + dz*dz;
}

// ---- Sphere-OBB (v0.2.197) ----
//
// Oriented bounding box: center + half-extents (hx, hy, hz) +
// orientation quaternion (qw, qx, qy, qz). Transform the sphere
// center into the OBB's local frame (inverse-rotate), then
// perform a sphere-AABB check against the half-extents.
//
// Conjugate of a unit quaternion is its inverse.
long long nuc_coll_sphere_obb(
    long long sx, long long sy, long long sz, long long sr,
    long long cx, long long cy, long long cz,
    long long hx, long long hy, long long hz,
    long long qw, long long qx, long long qy, long long qz)
{
    // Translate sphere center to OBB-local origin.
    double px = _i2f(sx) - _i2f(cx);
    double py = _i2f(sy) - _i2f(cy);
    double pz = _i2f(sz) - _i2f(cz);
    // Rotate (px, py, pz) by conj(q) into the OBB's local axis-
    // aligned frame: p_local = conj(q) · p_world · q.
    double qWv = _i2f(qw), qXv = _i2f(qx), qYv = _i2f(qy), qZv = _i2f(qz);
    // r = conj(q) · p   where conj(q) = (qW, -qX, -qY, -qZ).
    double rw = qXv*px + qYv*py + qZv*pz;
    double rx = qWv*px - qYv*pz + qZv*py;
    double ry = qWv*py + qXv*pz - qZv*px;
    double rz = qWv*pz - qXv*py + qYv*px;
    // out = r · q.
    double lx = rw*qXv + rx*qWv + ry*qZv - rz*qYv;
    double ly = rw*qYv - rx*qZv + ry*qWv + rz*qXv;
    double lz = rw*qZv + rx*qYv - ry*qXv + rz*qWv;
    // Clamp to the OBB's half-extents in local frame.
    double H[3] = { _i2f(hx), _i2f(hy), _i2f(hz) };
    double clx = lx < -H[0] ? -H[0] : (lx > H[0] ? H[0] : lx);
    double cly = ly < -H[1] ? -H[1] : (ly > H[1] ? H[1] : ly);
    double clz = lz < -H[2] ? -H[2] : (lz > H[2] ? H[2] : lz);
    double ddx = lx - clx, ddy = ly - cly, ddz = lz - clz;
    double r = _i2f(sr);
    return (ddx*ddx + ddy*ddy + ddz*ddz <= r*r) ? 1 : 0;
}

// ---- CCD: swept sphere-sphere (v0.2.196) ----
//
// A moving sphere from (a0, ar) to (a1, ar) sweeps a capsule.
// A moving sphere from (b0, br) to (b1, br) sweeps another.
// Two moving spheres collide iff the distance between their
// centers — as a function of time t ∈ [0, 1] — drops below
// (ar + br). Solve the quadratic in t and report the earliest
// hit time, or -1 if no collision in [0, 1].
//
// Returns:
//   t ∈ [0, 1]: collision at fraction t of the motion
//   -1.0     : no collision in the swept interval
long long nuc_coll_ccd_sphere_sphere(
    long long a0x, long long a0y, long long a0z,
    long long a1x, long long a1y, long long a1z, long long ar,
    long long b0x, long long b0y, long long b0z,
    long long b1x, long long b1y, long long b1z, long long br)
{
    double a0[3] = { _i2f(a0x), _i2f(a0y), _i2f(a0z) };
    double a1[3] = { _i2f(a1x), _i2f(a1y), _i2f(a1z) };
    double b0[3] = { _i2f(b0x), _i2f(b0y), _i2f(b0z) };
    double b1[3] = { _i2f(b1x), _i2f(b1y), _i2f(b1z) };
    double radius = _i2f(ar) + _i2f(br);
    double dx0 = a0[0] - b0[0], dy0 = a0[1] - b0[1], dz0 = a0[2] - b0[2];
    // Relative velocity (a relative to b) over the motion duration.
    double vx = (a1[0] - a0[0]) - (b1[0] - b0[0]);
    double vy = (a1[1] - a0[1]) - (b1[1] - b0[1]);
    double vz = (a1[2] - a0[2]) - (b1[2] - b0[2]);
    double A = vx*vx + vy*vy + vz*vz;
    double B = 2.0 * (dx0*vx + dy0*vy + dz0*vz);
    double C = dx0*dx0 + dy0*dy0 + dz0*dz0 - radius*radius;
    if (A < 1e-18) {
        // No relative motion; behaves as static sphere-sphere.
        return _f2i(C <= 0 ? 0.0 : -1.0);
    }
    double disc = B*B - 4*A*C;
    if (disc < 0) return _f2i(-1.0);
    double sd = sqrt(disc);
    double t0 = (-B - sd) / (2*A);
    double t1 = (-B + sd) / (2*A);
    // Earliest non-negative root in [0, 1].
    if (t0 >= 0 && t0 <= 1) return _f2i(t0);
    if (t1 >= 0 && t1 <= 1) {
        // Already overlapping at t=0 — t0 < 0, but exit at t1.
        return _f2i(t0 < 0 ? 0.0 : t1);
    }
    return _f2i(-1.0);
}

// ---- CCD: Capsule-Capsule (v0.2.201) ----
//
// Two moving capsules sweep over a unit time interval [0, 1]. Both
// the per-capsule endpoints are interpolated linearly between
// (a_*0 → a_*1) and (b_*0 → b_*1). At time t we evaluate the
// capsule centerlines and check against (a_radius + b_radius).
//
// Approach: 16-step uniform sweep to bracket the first overlap,
// then 16-step bisection to refine the impact time. Returns the
// earliest collision time t ∈ [0, 1] as bit-cast f64; -1.0 if
// no collision in the interval.
//
// Capsule-capsule CCD has no closed form (the segment-segment
// distance squared is a piecewise function of t). The bracket-
// then-bisect approach matches what most game/robotics engines
// actually ship in production. Sub-step exact rooting (solving
// the per-region quadratics) lands in v0.6 if needed.
static double _capcap_dist2_at(
    double t,
    double a_a0[3], double a_a1[3], double a_b0[3], double a_b1[3],
    double b_a0[3], double b_a1[3], double b_b0[3], double b_b1[3])
{
    double aax = a_a0[0] + t * (a_a1[0] - a_a0[0]);
    double aay = a_a0[1] + t * (a_a1[1] - a_a0[1]);
    double aaz = a_a0[2] + t * (a_a1[2] - a_a0[2]);
    double abx = a_b0[0] + t * (a_b1[0] - a_b0[0]);
    double aby = a_b0[1] + t * (a_b1[1] - a_b0[1]);
    double abz = a_b0[2] + t * (a_b1[2] - a_b0[2]);
    double bax = b_a0[0] + t * (b_a1[0] - b_a0[0]);
    double bay = b_a0[1] + t * (b_a1[1] - b_a0[1]);
    double baz = b_a0[2] + t * (b_a1[2] - b_a0[2]);
    double bbx = b_b0[0] + t * (b_b1[0] - b_b0[0]);
    double bby = b_b0[1] + t * (b_b1[1] - b_b0[1]);
    double bbz = b_b0[2] + t * (b_b1[2] - b_b0[2]);
    return _segment_segment_dist2(aax, aay, aaz, abx, aby, abz,
                                  bax, bay, baz, bbx, bby, bbz);
}

long long nuc_coll_ccd_capsule_capsule(
    long long a_a0x, long long a_a0y, long long a_a0z,
    long long a_a1x, long long a_a1y, long long a_a1z,
    long long a_b0x, long long a_b0y, long long a_b0z,
    long long a_b1x, long long a_b1y, long long a_b1z, long long ar,
    long long b_a0x, long long b_a0y, long long b_a0z,
    long long b_a1x, long long b_a1y, long long b_a1z,
    long long b_b0x, long long b_b0y, long long b_b0z,
    long long b_b1x, long long b_b1y, long long b_b1z, long long br)
{
    double a_a0[3] = { _i2f(a_a0x), _i2f(a_a0y), _i2f(a_a0z) };
    double a_a1[3] = { _i2f(a_a1x), _i2f(a_a1y), _i2f(a_a1z) };
    double a_b0[3] = { _i2f(a_b0x), _i2f(a_b0y), _i2f(a_b0z) };
    double a_b1[3] = { _i2f(a_b1x), _i2f(a_b1y), _i2f(a_b1z) };
    double b_a0[3] = { _i2f(b_a0x), _i2f(b_a0y), _i2f(b_a0z) };
    double b_a1[3] = { _i2f(b_a1x), _i2f(b_a1y), _i2f(b_a1z) };
    double b_b0[3] = { _i2f(b_b0x), _i2f(b_b0y), _i2f(b_b0z) };
    double b_b1[3] = { _i2f(b_b1x), _i2f(b_b1y), _i2f(b_b1z) };
    double rsum = _i2f(ar) + _i2f(br);
    double rsum2 = rsum * rsum;

    int N = 16;
    double t_prev = 0.0;
    double d2_prev = _capcap_dist2_at(0.0, a_a0, a_a1, a_b0, a_b1,
                                              b_a0, b_a1, b_b0, b_b1);
    if (d2_prev <= rsum2) return _f2i(0.0);
    for (int i = 1; i <= N; i++) {
        double t = (double)i / (double)N;
        double d2 = _capcap_dist2_at(t, a_a0, a_a1, a_b0, a_b1,
                                            b_a0, b_a1, b_b0, b_b1);
        if (d2 <= rsum2) {
            // Found a frame at/after impact. Bisect t_prev..t for
            // the impact time. Invariant: d2_prev > rsum2, d2 ≤ rsum2.
            double lo = t_prev, hi = t;
            for (int b = 0; b < 16; b++) {
                double mid = 0.5 * (lo + hi);
                double dm = _capcap_dist2_at(mid, a_a0, a_a1, a_b0, a_b1,
                                                    b_a0, b_a1, b_b0, b_b1);
                if (dm <= rsum2) hi = mid; else lo = mid;
            }
            return _f2i(hi);
        }
        t_prev = t; d2_prev = d2;
    }
    return _f2i(-1.0);
}

// ---- CCD: Sphere-AABB (v0.2.201) ----
//
// One moving sphere over a unit time interval [0, 1] vs a static
// AABB. Same bracket-then-bisect approach as capsule-capsule.
// Distance metric is sphere-center to AABB-clamp; collision is
// distance ≤ sphere radius.
static double _sph_aabb_dist2_at(
    double t, double s0[3], double s1[3],
    double bx, double by, double bz, double Bx, double By, double Bz)
{
    double cx = s0[0] + t * (s1[0] - s0[0]);
    double cy = s0[1] + t * (s1[1] - s0[1]);
    double cz = s0[2] + t * (s1[2] - s0[2]);
    double clx = cx < bx ? bx : (cx > Bx ? Bx : cx);
    double cly = cy < by ? by : (cy > By ? By : cy);
    double clz = cz < bz ? bz : (cz > Bz ? Bz : cz);
    double dx = cx - clx, dy = cy - cly, dz = cz - clz;
    return dx*dx + dy*dy + dz*dz;
}

long long nuc_coll_ccd_sphere_aabb(
    long long s0x, long long s0y, long long s0z,
    long long s1x, long long s1y, long long s1z, long long sr,
    long long minx, long long miny, long long minz,
    long long maxx, long long maxy, long long maxz)
{
    double s0[3] = { _i2f(s0x), _i2f(s0y), _i2f(s0z) };
    double s1[3] = { _i2f(s1x), _i2f(s1y), _i2f(s1z) };
    double r = _i2f(sr);
    double r2 = r * r;
    double bx = _i2f(minx), by = _i2f(miny), bz = _i2f(minz);
    double Bx = _i2f(maxx), By = _i2f(maxy), Bz = _i2f(maxz);

    double d2_0 = _sph_aabb_dist2_at(0.0, s0, s1, bx, by, bz, Bx, By, Bz);
    if (d2_0 <= r2) return _f2i(0.0);

    int N = 16;
    double t_prev = 0.0;
    for (int i = 1; i <= N; i++) {
        double t = (double)i / (double)N;
        double d2 = _sph_aabb_dist2_at(t, s0, s1, bx, by, bz, Bx, By, Bz);
        if (d2 <= r2) {
            double lo = t_prev, hi = t;
            for (int b = 0; b < 16; b++) {
                double mid = 0.5 * (lo + hi);
                double dm = _sph_aabb_dist2_at(mid, s0, s1, bx, by, bz, Bx, By, Bz);
                if (dm <= r2) hi = mid; else lo = mid;
            }
            return _f2i(hi);
        }
        t_prev = t;
    }
    return _f2i(-1.0);
}

// ---- Sphere-Capsule ----
long long nuc_coll_sphere_capsule(
    long long sx, long long sy, long long sz, long long sr,
    long long c_ax, long long c_ay, long long c_az,
    long long c_bx, long long c_by, long long c_bz, long long cr)
{
    double d2 = _point_segment_dist2(_i2f(sx), _i2f(sy), _i2f(sz),
                                      _i2f(c_ax), _i2f(c_ay), _i2f(c_az),
                                      _i2f(c_bx), _i2f(c_by), _i2f(c_bz));
    double sum_r = _i2f(sr) + _i2f(cr);
    return (d2 <= sum_r*sum_r) ? 1 : 0;
}

// ---- Capsule-Capsule ----
long long nuc_coll_capsule_capsule(
    long long a_ax, long long a_ay, long long a_az,
    long long a_bx, long long a_by, long long a_bz, long long ar,
    long long b_ax, long long b_ay, long long b_az,
    long long b_bx, long long b_by, long long b_bz, long long br)
{
    double d2 = _segment_segment_dist2(
        _i2f(a_ax), _i2f(a_ay), _i2f(a_az),
        _i2f(a_bx), _i2f(a_by), _i2f(a_bz),
        _i2f(b_ax), _i2f(b_ay), _i2f(b_az),
        _i2f(b_bx), _i2f(b_by), _i2f(b_bz)
    );
    double sum_r = _i2f(ar) + _i2f(br);
    return (d2 <= sum_r*sum_r) ? 1 : 0;
}

// ---- GJK (Gilbert-Johnson-Keerthi) — convex-convex overlap ----
//
// Generic convex-shape overlap test. The user supplies the support
// function for each shape (mapping from a direction to the
// point on the shape that's farthest in that direction). GJK
// then iteratively builds a simplex in Minkowski-difference
// space and asks whether it contains the origin.
//
// Returns 1 (overlap), 0 (clear), or -1 if convergence failed.
//
// The support functions are passed as i64 function pointers;
// each takes a Vec3 direction handle (3 doubles malloc'd) and
// returns a Vec3 point handle. The caller is responsible for
// the malloc of the direction Vec3 and for freeing the returned
// point Vec3.

typedef long long (*support_fn_t)(long long dir_h);

static void _vsub3(const double *a, const double *b, double *out) {
    out[0] = a[0] - b[0];
    out[1] = a[1] - b[1];
    out[2] = a[2] - b[2];
}
static double _vdot3(const double *a, const double *b) {
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
}
static void _vcross3(const double *a, const double *b, double *out) {
    out[0] = a[1]*b[2] - a[2]*b[1];
    out[1] = a[2]*b[0] - a[0]*b[2];
    out[2] = a[0]*b[1] - a[1]*b[0];
}
static void _vneg3(double *v) { v[0] = -v[0]; v[1] = -v[1]; v[2] = -v[2]; }
static void _vscale3(double *v, double s) { v[0]*=s; v[1]*=s; v[2]*=s; }

// Minkowski difference support: support_A(d) - support_B(-d).
static void _gjk_support(support_fn_t sa, support_fn_t sb,
                         const double *dir, double *out)
{
    double *dir_a = (double *)malloc(3 * sizeof(double));
    dir_a[0] = dir[0]; dir_a[1] = dir[1]; dir_a[2] = dir[2];
    long long pa_h = sa((long long)(size_t)dir_a);
    free(dir_a);
    double *dir_b = (double *)malloc(3 * sizeof(double));
    dir_b[0] = -dir[0]; dir_b[1] = -dir[1]; dir_b[2] = -dir[2];
    long long pb_h = sb((long long)(size_t)dir_b);
    free(dir_b);
    double *pa = (double *)(void *)(size_t)pa_h;
    double *pb = (double *)(void *)(size_t)pb_h;
    out[0] = pa[0] - pb[0];
    out[1] = pa[1] - pb[1];
    out[2] = pa[2] - pb[2];
    free(pa);
    free(pb);
}

// Triple product (a × b) × c.
static void _triple_cross(const double *a, const double *b, const double *c, double *out) {
    double ab[3]; _vcross3(a, b, ab);
    _vcross3(ab, c, out);
}

// Update simplex during GJK; returns 1 if origin inside.
// Modifies simplex (`simp`) and direction (`dir`).
// `n` is the current simplex size in/out.
static int _gjk_do_simplex(double simp[4][3], int *n, double *dir) {
    if (*n == 2) {
        // Line: A is the most recently added point, B is the other.
        double *A = simp[1];
        double *B = simp[0];
        double AB[3], AO[3];
        _vsub3(B, A, AB);
        _vsub3((double[]){0,0,0}, A, AO);
        if (_vdot3(AB, AO) > 0) {
            // Origin in direction perp to AB, in plane of AB,AO.
            _triple_cross(AB, AO, AB, dir);
            // If degenerate (AB parallel AO), pick any perp.
            if (_vdot3(dir, dir) < 1e-12) {
                // Fall back: use any axis perpendicular to AB.
                double axis[3] = {1, 0, 0};
                if (fabs(AB[0]) > 0.9) { axis[0] = 0; axis[1] = 1; }
                _vcross3(AB, axis, dir);
            }
        } else {
            // Origin behind A; drop B.
            simp[0][0] = A[0]; simp[0][1] = A[1]; simp[0][2] = A[2];
            *n = 1;
            dir[0] = AO[0]; dir[1] = AO[1]; dir[2] = AO[2];
        }
        return 0;
    }
    if (*n == 3) {
        // Triangle: A most recent, B, C earlier.
        double *A = simp[2];
        double *B = simp[1];
        double *C = simp[0];
        double AB[3], AC[3], AO[3], ABC[3];
        _vsub3(B, A, AB);
        _vsub3(C, A, AC);
        _vsub3((double[]){0,0,0}, A, AO);
        _vcross3(AB, AC, ABC);
        double tmp[3]; _vcross3(ABC, AC, tmp);
        if (_vdot3(tmp, AO) > 0) {
            if (_vdot3(AC, AO) > 0) {
                // Region AC.
                simp[1][0] = A[0]; simp[1][1] = A[1]; simp[1][2] = A[2];
                // C stays at simp[0], A moves to simp[1].
                *n = 2;
                _triple_cross(AC, AO, AC, dir);
                if (_vdot3(dir, dir) < 1e-12) { dir[0] = AO[0]; dir[1] = AO[1]; dir[2] = AO[2]; }
                return 0;
            }
            // Region AB or beyond — drop C, recurse as line.
            simp[0][0] = B[0]; simp[0][1] = B[1]; simp[0][2] = B[2];
            simp[1][0] = A[0]; simp[1][1] = A[1]; simp[1][2] = A[2];
            *n = 2;
            return _gjk_do_simplex(simp, n, dir);
        }
        _vcross3(AB, ABC, tmp);
        if (_vdot3(tmp, AO) > 0) {
            simp[0][0] = B[0]; simp[0][1] = B[1]; simp[0][2] = B[2];
            simp[1][0] = A[0]; simp[1][1] = A[1]; simp[1][2] = A[2];
            *n = 2;
            return _gjk_do_simplex(simp, n, dir);
        }
        // Origin inside the triangle prism — pick the side ABC faces.
        if (_vdot3(ABC, AO) > 0) {
            // Above: keep order C,B,A and use ABC as direction.
            dir[0] = ABC[0]; dir[1] = ABC[1]; dir[2] = ABC[2];
        } else {
            // Below: swap B,C so winding flips, use -ABC.
            simp[0][0] = B[0]; simp[0][1] = B[1]; simp[0][2] = B[2];
            simp[1][0] = C[0]; simp[1][1] = C[1]; simp[1][2] = C[2];
            simp[2][0] = A[0]; simp[2][1] = A[1]; simp[2][2] = A[2];
            dir[0] = -ABC[0]; dir[1] = -ABC[1]; dir[2] = -ABC[2];
        }
        return 0;
    }
    if (*n == 4) {
        // Tetrahedron: A most recent, B,C,D earlier.
        double *A = simp[3];
        double *B = simp[2];
        double *C = simp[1];
        double *D = simp[0];
        double AB[3], AC[3], AD[3], AO[3];
        _vsub3(B, A, AB);
        _vsub3(C, A, AC);
        _vsub3(D, A, AD);
        _vsub3((double[]){0,0,0}, A, AO);
        double ABC[3], ACD[3], ADB[3];
        _vcross3(AB, AC, ABC);
        _vcross3(AC, AD, ACD);
        _vcross3(AD, AB, ADB);
        if (_vdot3(ABC, AO) > 0) {
            // Drop D.
            simp[0][0] = C[0]; simp[0][1] = C[1]; simp[0][2] = C[2];
            simp[1][0] = B[0]; simp[1][1] = B[1]; simp[1][2] = B[2];
            simp[2][0] = A[0]; simp[2][1] = A[1]; simp[2][2] = A[2];
            *n = 3;
            return _gjk_do_simplex(simp, n, dir);
        }
        if (_vdot3(ACD, AO) > 0) {
            // Drop B.
            simp[0][0] = D[0]; simp[0][1] = D[1]; simp[0][2] = D[2];
            simp[1][0] = C[0]; simp[1][1] = C[1]; simp[1][2] = C[2];
            simp[2][0] = A[0]; simp[2][1] = A[1]; simp[2][2] = A[2];
            *n = 3;
            return _gjk_do_simplex(simp, n, dir);
        }
        if (_vdot3(ADB, AO) > 0) {
            // Drop C.
            simp[0][0] = B[0]; simp[0][1] = B[1]; simp[0][2] = B[2];
            simp[1][0] = D[0]; simp[1][1] = D[1]; simp[1][2] = D[2];
            simp[2][0] = A[0]; simp[2][1] = A[1]; simp[2][2] = A[2];
            *n = 3;
            return _gjk_do_simplex(simp, n, dir);
        }
        // Origin inside the tetrahedron.
        return 1;
    }
    return 0;
}

long long nuc_coll_gjk(long long support_a_fp, long long support_b_fp) {
    support_fn_t sa = (support_fn_t)(void *)(size_t)support_a_fp;
    support_fn_t sb = (support_fn_t)(void *)(size_t)support_b_fp;
    if (!sa || !sb) return -1;

    double simp[4][3];
    int n = 0;
    double dir[3] = {1, 0, 0};
    double sup[3];
    _gjk_support(sa, sb, dir, sup);
    if (_vdot3(sup, dir) <= 0) return 0;
    simp[0][0] = sup[0]; simp[0][1] = sup[1]; simp[0][2] = sup[2];
    n = 1;
    dir[0] = -sup[0]; dir[1] = -sup[1]; dir[2] = -sup[2];

    for (int iter = 0; iter < 32; iter++) {
        _gjk_support(sa, sb, dir, sup);
        if (_vdot3(sup, dir) <= 0) return 0;
        simp[n][0] = sup[0]; simp[n][1] = sup[1]; simp[n][2] = sup[2];
        n++;
        if (_gjk_do_simplex(simp, &n, dir)) return 1;
    }
    return -1;
}

// ---- GJK + EPA on convex meshes (v0.2.205) ==============================
//
// Convenience entry points: instead of accepting a user-supplied
// support function pointer (which is awkward when the support
// function needs to capture per-shape state and Nucleor doesn't
// have closures), accept a flat `double[n*3]` vertex array per
// shape directly. The support function is computed inline by
// scanning all vertices for the one with maximum dot-product
// against the query direction — O(n) per support, fine for
// typical convex hulls (10-100 verts).
//
// For non-convex meshes, the caller decomposes the mesh into
// convex pieces (V-HACD or similar) and runs pairwise mesh-mesh
// queries.

// Forward declarations for the EPA helpers defined in the next
// section — needed by `nuc_coll_gjk_epa_mesh_mesh` below.
#define _NEPA_MAX_VERT 64
#define _NEPA_MAX_FACE 128
typedef struct { int v[3]; double n[3]; double dist; } _EPAFace;
static void _epa_face_init(double *v0, double *v1, double *v2,
                           double *interior, _EPAFace *f, int i0, int i1, int i2);

static void _mesh_support(const double *verts, int n_verts,
                          const double *dir, double *out)
{
    int best = 0;
    double best_dot = _vdot3(verts + 0, dir);
    for (int i = 1; i < n_verts; i++) {
        double d = _vdot3(verts + i * 3, dir);
        if (d > best_dot) { best_dot = d; best = i; }
    }
    out[0] = verts[best * 3 + 0];
    out[1] = verts[best * 3 + 1];
    out[2] = verts[best * 3 + 2];
}

static void _gjk_support_mesh_mesh(const double *va, int na,
                                   const double *vb, int nb,
                                   const double *dir, double *out)
{
    double pa[3], pb[3];
    double neg[3] = { -dir[0], -dir[1], -dir[2] };
    _mesh_support(va, na, dir, pa);
    _mesh_support(vb, nb, neg, pb);
    out[0] = pa[0] - pb[0];
    out[1] = pa[1] - pb[1];
    out[2] = pa[2] - pb[2];
}

long long nuc_coll_gjk_mesh_mesh(long long verts_a_ptr, long long n_a,
                                 long long verts_b_ptr, long long n_b)
{
    const double *va = (const double *)(void *)(size_t)verts_a_ptr;
    const double *vb = (const double *)(void *)(size_t)verts_b_ptr;
    int na = (int)n_a, nb = (int)n_b;
    if (!va || !vb || na <= 0 || nb <= 0) return -1;

    double simp[4][3];
    int n = 0;
    double dir[3] = {1, 0, 0};
    double sup[3];
    _gjk_support_mesh_mesh(va, na, vb, nb, dir, sup);
    if (_vdot3(sup, dir) <= 0) return 0;
    simp[0][0] = sup[0]; simp[0][1] = sup[1]; simp[0][2] = sup[2];
    n = 1;
    dir[0] = -sup[0]; dir[1] = -sup[1]; dir[2] = -sup[2];

    for (int iter = 0; iter < 64; iter++) {
        _gjk_support_mesh_mesh(va, na, vb, nb, dir, sup);
        if (_vdot3(sup, dir) <= 0) return 0;
        simp[n][0] = sup[0]; simp[n][1] = sup[1]; simp[n][2] = sup[2];
        n++;
        if (_gjk_do_simplex(simp, &n, dir)) return 1;
    }
    return -1;
}

// EPA on mesh-mesh. Same algorithm as `nuc_coll_gjk_epa` (v0.2.202)
// but uses the mesh-direct support function. Returns penetration
// depth as bit-cast f64; -1.0 if shapes are not overlapping.
long long nuc_coll_gjk_epa_mesh_mesh(long long verts_a_ptr, long long n_a,
                                     long long verts_b_ptr, long long n_b,
                                     long long out_normal_h)
{
    const double *va = (const double *)(void *)(size_t)verts_a_ptr;
    const double *vb = (const double *)(void *)(size_t)verts_b_ptr;
    int na = (int)n_a, nb = (int)n_b;
    if (!va || !vb || na <= 0 || nb <= 0) return _f2i(-1.0);

    // First, capture the GJK terminating tetrahedron via an inline
    // GJK loop on the mesh-mesh support (same scheme as
    // `_gjk_capture_simplex` but with the mesh-mesh support fn).
    double tet[4][3];
    {
        double simp[4][3];
        int n = 0;
        double dir[3] = {1, 0, 0};
        double sup[3];
        _gjk_support_mesh_mesh(va, na, vb, nb, dir, sup);
        if (_vdot3(sup, dir) <= 0) return _f2i(-1.0);
        simp[0][0] = sup[0]; simp[0][1] = sup[1]; simp[0][2] = sup[2];
        n = 1;
        dir[0] = -sup[0]; dir[1] = -sup[1]; dir[2] = -sup[2];
        int captured = 0;
        for (int iter = 0; iter < 64; iter++) {
            _gjk_support_mesh_mesh(va, na, vb, nb, dir, sup);
            if (_vdot3(sup, dir) <= 0) return _f2i(-1.0);
            simp[n][0] = sup[0]; simp[n][1] = sup[1]; simp[n][2] = sup[2];
            n++;
            if (_gjk_do_simplex(simp, &n, dir)) {
                for (int i = 0; i < 4; i++)
                    for (int j = 0; j < 3; j++) tet[i][j] = simp[i][j];
                captured = 1;
                break;
            }
        }
        if (!captured) return _f2i(-1.0);
    }

    static double verts[_NEPA_MAX_VERT][3];
    static _EPAFace faces[_NEPA_MAX_FACE];
    int n_verts = 0, n_faces = 0;

    for (int i = 0; i < 4; i++) {
        verts[i][0] = tet[i][0]; verts[i][1] = tet[i][1]; verts[i][2] = tet[i][2];
    }
    n_verts = 4;
    double centroid[3] = {0,0,0};
    for (int i = 0; i < 4; i++) {
        centroid[0] += tet[i][0]; centroid[1] += tet[i][1]; centroid[2] += tet[i][2];
    }
    centroid[0] *= 0.25; centroid[1] *= 0.25; centroid[2] *= 0.25;

    _epa_face_init(verts[0], verts[1], verts[2], centroid, &faces[0], 0, 1, 2);
    _epa_face_init(verts[0], verts[1], verts[3], centroid, &faces[1], 0, 1, 3);
    _epa_face_init(verts[0], verts[2], verts[3], centroid, &faces[2], 0, 2, 3);
    _epa_face_init(verts[1], verts[2], verts[3], centroid, &faces[3], 1, 2, 3);
    n_faces = 4;

    double *out_normal = (double *)(void *)(size_t)out_normal_h;

    for (int iter = 0; iter < 64; iter++) {
        int best = 0;
        double best_dist = faces[0].dist;
        for (int i = 1; i < n_faces; i++) {
            if (faces[i].dist < best_dist) { best_dist = faces[i].dist; best = i; }
        }
        double *bn = faces[best].n;
        double sup[3];
        _gjk_support_mesh_mesh(va, na, vb, nb, bn, sup);
        double d_new = _vdot3(sup, bn);
        if (d_new - best_dist < 1e-9 || n_verts >= _NEPA_MAX_VERT) {
            if (out_normal) {
                out_normal[0] = bn[0]; out_normal[1] = bn[1]; out_normal[2] = bn[2];
            }
            return _f2i(best_dist);
        }
        int new_idx = n_verts;
        verts[n_verts][0] = sup[0]; verts[n_verts][1] = sup[1]; verts[n_verts][2] = sup[2];
        n_verts++;

        int visible[_NEPA_MAX_FACE];
        int n_visible = 0;
        for (int i = 0; i < n_faces; i++) {
            double diff[3];
            _vsub3(sup, verts[faces[i].v[0]], diff);
            if (_vdot3(faces[i].n, diff) > 1e-9) visible[n_visible++] = i;
        }
        if (n_visible == 0) {
            if (out_normal) {
                out_normal[0] = bn[0]; out_normal[1] = bn[1]; out_normal[2] = bn[2];
            }
            return _f2i(best_dist);
        }
        int edges[_NEPA_MAX_FACE * 3][2];
        int n_edges = 0;
        for (int vf = 0; vf < n_visible; vf++) {
            _EPAFace *f = &faces[visible[vf]];
            int e[3][2] = { {f->v[0], f->v[1]}, {f->v[1], f->v[2]}, {f->v[2], f->v[0]} };
            for (int k = 0; k < 3; k++) {
                int found = -1;
                for (int e2 = 0; e2 < n_edges; e2++) {
                    if (edges[e2][0] == e[k][1] && edges[e2][1] == e[k][0]) {
                        found = e2; break;
                    }
                }
                if (found >= 0) {
                    edges[found][0] = edges[n_edges - 1][0];
                    edges[found][1] = edges[n_edges - 1][1];
                    n_edges--;
                } else {
                    edges[n_edges][0] = e[k][0];
                    edges[n_edges][1] = e[k][1];
                    n_edges++;
                }
            }
        }
        int removed[_NEPA_MAX_FACE] = {0};
        for (int vf = 0; vf < n_visible; vf++) removed[visible[vf]] = 1;
        int dst = 0;
        for (int i = 0; i < n_faces; i++) {
            if (!removed[i]) {
                if (dst != i) faces[dst] = faces[i];
                dst++;
            }
        }
        n_faces = dst;
        for (int e = 0; e < n_edges; e++) {
            if (n_faces >= _NEPA_MAX_FACE) break;
            _epa_face_init(verts[edges[e][0]], verts[edges[e][1]], verts[new_idx],
                           centroid, &faces[n_faces], edges[e][0], edges[e][1], new_idx);
            n_faces++;
        }
    }
    int best = 0;
    double best_dist = faces[0].dist;
    for (int i = 1; i < n_faces; i++) {
        if (faces[i].dist < best_dist) { best_dist = faces[i].dist; best = i; }
    }
    if (out_normal) {
        double *bn = faces[best].n;
        out_normal[0] = bn[0]; out_normal[1] = bn[1]; out_normal[2] = bn[2];
    }
    return _f2i(best_dist);
}

// ---- GJK EPA: penetration depth + contact normal (v0.2.202) =============
//
// Once GJK reports overlap (returns 1), the closest face on the
// Minkowski-difference polytope to the origin gives the minimum-
// translation vector to separate the shapes. EPA (Expanding
// Polytope Algorithm, Van den Bergen 2001) expands the GJK
// terminating tetrahedron iteratively, looking for the support
// point that is "outside" the closest face — when no such point
// exists, the closest face is on the polytope boundary, and its
// distance to the origin is the penetration depth.
//
// Inputs are the same support function pointers as `nuc_coll_gjk`.
// Output: penetration depth as a bit-cast f64; the 3-double buffer
// at `out_normal_h` is filled with the unit contact-normal vector
// pointing from B into A. Returns -1.0 (bit-cast f64) if the shapes
// are not overlapping (caller should have checked GJK first).
//
// `_NEPA_MAX_VERT`, `_NEPA_MAX_FACE`, and `_EPAFace` are forward-
// declared in the v0.2.205 mesh-mesh section above so it can use
// them for its own EPA loop.

// Build the GJK terminating simplex (must be a tetrahedron with
// the origin inside). On success, fills `simp_out[4][3]` and
// returns 1; otherwise returns 0.
static int _gjk_capture_simplex(support_fn_t sa, support_fn_t sb,
                                double simp_out[4][3])
{
    double simp[4][3];
    int n = 0;
    double dir[3] = {1, 0, 0};
    double sup[3];
    _gjk_support(sa, sb, dir, sup);
    if (_vdot3(sup, dir) <= 0) return 0;
    simp[0][0] = sup[0]; simp[0][1] = sup[1]; simp[0][2] = sup[2];
    n = 1;
    dir[0] = -sup[0]; dir[1] = -sup[1]; dir[2] = -sup[2];

    for (int iter = 0; iter < 64; iter++) {
        _gjk_support(sa, sb, dir, sup);
        if (_vdot3(sup, dir) <= 0) return 0;
        simp[n][0] = sup[0]; simp[n][1] = sup[1]; simp[n][2] = sup[2];
        n++;
        if (_gjk_do_simplex(simp, &n, dir)) {
            // n is now 4; copy out the tetrahedron.
            for (int i = 0; i < 4; i++)
                for (int j = 0; j < 3; j++) simp_out[i][j] = simp[i][j];
            return 1;
        }
    }
    return 0;
}

// Compute outward face normal + distance for a triangle (v0, v1, v2).
// EPA polytope invariant: the origin is always inside, so we orient
// the normal so that (n · v0) ≥ 0 — that makes `n` point outward
// (away from the origin) and `dist = n · v0` is the positive distance
// from the origin to the face's supporting plane. The `interior`
// parameter is a centroid-like reference; unused in this formulation
// (kept in the signature so callers don't need to change).
// EPA face init: orient the (v0, v1, v2) winding so that the
// right-hand cross-product (v1-v0) × (v2-v0) points OUTWARD (away
// from the origin). Outward = origin is inside the polytope = face
// supporting plane has positive distance from origin along the
// winding-implied normal. If the cross-product points the wrong way,
// swap v1 ↔ v2 (instead of just flipping the normal vector) so the
// stored face winding stays consistent with the stored normal —
// this is essential for the silhouette-edge cancellation logic
// during EPA expansion.
static void _epa_face_init(double *v0, double *v1, double *v2,
                           double *interior, _EPAFace *f, int i0, int i1, int i2)
{
    (void)interior;
    double e1[3], e2[3], n[3];
    _vsub3(v1, v0, e1);
    _vsub3(v2, v0, e2);
    _vcross3(e1, e2, n);
    double nlen = sqrt(_vdot3(n, n));
    if (nlen < 1e-18) {
        f->v[0] = i0; f->v[1] = i1; f->v[2] = i2;
        f->n[0] = 0; f->n[1] = 0; f->n[2] = 1; f->dist = 1e30; return;
    }
    n[0] /= nlen; n[1] /= nlen; n[2] /= nlen;
    double d = _vdot3(n, v0);
    if (d < 0) {
        // Cross-product points inward; swap winding to flip it.
        n[0] = -n[0]; n[1] = -n[1]; n[2] = -n[2]; d = -d;
        f->v[0] = i0; f->v[1] = i2; f->v[2] = i1;
    } else {
        f->v[0] = i0; f->v[1] = i1; f->v[2] = i2;
    }
    f->n[0] = n[0]; f->n[1] = n[1]; f->n[2] = n[2];
    f->dist = d;
}

long long nuc_coll_gjk_epa(long long support_a_fp, long long support_b_fp,
                           long long out_normal_h)
{
    support_fn_t sa = (support_fn_t)(void *)(size_t)support_a_fp;
    support_fn_t sb = (support_fn_t)(void *)(size_t)support_b_fp;
    if (!sa || !sb) return _f2i(-1.0);

    // Capture the GJK terminating tetrahedron.
    double tet[4][3];
    if (!_gjk_capture_simplex(sa, sb, tet)) return _f2i(-1.0);

    static double verts[_NEPA_MAX_VERT][3];
    static _EPAFace faces[_NEPA_MAX_FACE];
    int n_verts = 0, n_faces = 0;

    for (int i = 0; i < 4; i++) {
        verts[i][0] = tet[i][0]; verts[i][1] = tet[i][1]; verts[i][2] = tet[i][2];
    }
    n_verts = 4;
    // Centroid of the tetrahedron — used to orient face normals outward.
    double centroid[3] = {0,0,0};
    for (int i = 0; i < 4; i++) {
        centroid[0] += tet[i][0]; centroid[1] += tet[i][1]; centroid[2] += tet[i][2];
    }
    centroid[0] *= 0.25; centroid[1] *= 0.25; centroid[2] *= 0.25;

    // 4 faces of the tetrahedron, each excluding one vertex; the
    // interior point for orientation is the excluded vertex (since
    // the centroid is inside the tetrahedron). Actually — the
    // interior of the polytope is the centroid; we use it as the
    // reference point and flip normals that point toward it.
    _epa_face_init(verts[0], verts[1], verts[2], centroid, &faces[0], 0, 1, 2);
    _epa_face_init(verts[0], verts[1], verts[3], centroid, &faces[1], 0, 1, 3);
    _epa_face_init(verts[0], verts[2], verts[3], centroid, &faces[2], 0, 2, 3);
    _epa_face_init(verts[1], verts[2], verts[3], centroid, &faces[3], 1, 2, 3);
    n_faces = 4;

    double *out_normal = (double *)(void *)(size_t)out_normal_h;

    for (int iter = 0; iter < 64; iter++) {
        // Find the face closest to the origin.
        int best = 0;
        double best_dist = faces[0].dist;
        for (int i = 1; i < n_faces; i++) {
            if (faces[i].dist < best_dist) { best_dist = faces[i].dist; best = i; }
        }
        double *bn = faces[best].n;
        double sup[3];
        _gjk_support(sa, sb, bn, sup);
        double d_new = _vdot3(sup, bn);
        if (d_new - best_dist < 1e-9 || n_verts >= _NEPA_MAX_VERT) {
            if (out_normal) {
                out_normal[0] = bn[0]; out_normal[1] = bn[1]; out_normal[2] = bn[2];
            }
            return _f2i(best_dist);
        }

        // Add the new vertex.
        int new_idx = n_verts;
        verts[n_verts][0] = sup[0]; verts[n_verts][1] = sup[1]; verts[n_verts][2] = sup[2];
        n_verts++;

        // Find all faces visible from `sup` (face normal points
        // toward sup). Collect their boundary edges as the silhouette.
        int visible[_NEPA_MAX_FACE];
        int n_visible = 0;
        for (int i = 0; i < n_faces; i++) {
            double diff[3];
            _vsub3(sup, verts[faces[i].v[0]], diff);
            if (_vdot3(faces[i].n, diff) > 1e-9) visible[n_visible++] = i;
        }
        if (n_visible == 0) {
            // Numerical issue — terminate with current best.
            if (out_normal) {
                out_normal[0] = bn[0]; out_normal[1] = bn[1]; out_normal[2] = bn[2];
            }
            return _f2i(best_dist);
        }

        // Edge collection: each visible face contributes 3 edges;
        // edges shared between two visible faces cancel (interior).
        // Remaining = silhouette.
        int edges[_NEPA_MAX_FACE * 3][2];
        int n_edges = 0;
        for (int vf = 0; vf < n_visible; vf++) {
            _EPAFace *f = &faces[visible[vf]];
            int e[3][2] = { {f->v[0], f->v[1]}, {f->v[1], f->v[2]}, {f->v[2], f->v[0]} };
            for (int k = 0; k < 3; k++) {
                int found = -1;
                for (int e2 = 0; e2 < n_edges; e2++) {
                    if ((edges[e2][0] == e[k][1] && edges[e2][1] == e[k][0])) {
                        found = e2; break;
                    }
                }
                if (found >= 0) {
                    edges[found][0] = edges[n_edges - 1][0];
                    edges[found][1] = edges[n_edges - 1][1];
                    n_edges--;
                } else {
                    edges[n_edges][0] = e[k][0];
                    edges[n_edges][1] = e[k][1];
                    n_edges++;
                }
            }
        }

        // Remove visible faces (compact face array).
        // Build a "removed" mask, then compact.
        int removed[_NEPA_MAX_FACE] = {0};
        for (int vf = 0; vf < n_visible; vf++) removed[visible[vf]] = 1;
        int dst = 0;
        for (int i = 0; i < n_faces; i++) {
            if (!removed[i]) {
                if (dst != i) faces[dst] = faces[i];
                dst++;
            }
        }
        n_faces = dst;

        // Add new faces from `sup` to each silhouette edge.
        for (int e = 0; e < n_edges; e++) {
            if (n_faces >= _NEPA_MAX_FACE) break;
            _epa_face_init(verts[edges[e][0]], verts[edges[e][1]], verts[new_idx],
                           centroid, &faces[n_faces], edges[e][0], edges[e][1], new_idx);
            n_faces++;
        }
    }
    // Hit iteration cap; return current best.
    int best = 0;
    double best_dist = faces[0].dist;
    for (int i = 1; i < n_faces; i++) {
        if (faces[i].dist < best_dist) { best_dist = faces[i].dist; best = i; }
    }
    if (out_normal) {
        double *bn = faces[best].n;
        out_normal[0] = bn[0]; out_normal[1] = bn[1]; out_normal[2] = bn[2];
    }
    return _f2i(best_dist);
}

// ---- Sphere-AABB (v0.2.195) ----
//
// Closest point on the AABB to the sphere center is the sphere
// center clamped to the AABB bounds. Collision iff that point is
// within `radius` of the center.
long long nuc_coll_sphere_aabb(
    long long sx, long long sy, long long sz, long long sr,
    long long minx, long long miny, long long minz,
    long long maxx, long long maxy, long long maxz)
{
    double cx = _i2f(sx), cy = _i2f(sy), cz = _i2f(sz);
    double r = _i2f(sr);
    double bx = _i2f(minx), by = _i2f(miny), bz = _i2f(minz);
    double Bx = _i2f(maxx), By = _i2f(maxy), Bz = _i2f(maxz);
    double clx = cx < bx ? bx : (cx > Bx ? Bx : cx);
    double cly = cy < by ? by : (cy > By ? By : cy);
    double clz = cz < bz ? bz : (cz > Bz ? Bz : cz);
    double dx = cx - clx, dy = cy - cly, dz = cz - clz;
    return (dx*dx + dy*dy + dz*dz <= r*r) ? 1 : 0;
}

// ---- Capsule-AABB (v0.2.195) ----
//
// Test the capsule's central segment against the AABB by
// expanding the AABB by the capsule's radius (Minkowski sum
// trick). Then we have segment vs expanded-AABB overlap. Use
// the standard slab-clip method for segment-AABB intersection;
// if the segment overlaps the expanded AABB, the capsule
// collides with the original AABB.
//
// Note: this is a sound but slightly conservative test for the
// rounded corners of the expanded AABB. For the rounded-corner
// rejection, we'd add a corner-distance test; deferred to v0.5
// alongside the GJK-based mesh paths.
long long nuc_coll_capsule_aabb(
    long long c_ax, long long c_ay, long long c_az,
    long long c_bx, long long c_by, long long c_bz, long long cr,
    long long minx, long long miny, long long minz,
    long long maxx, long long maxy, long long maxz)
{
    double r = _i2f(cr);
    double bx = _i2f(minx) - r, by = _i2f(miny) - r, bz = _i2f(minz) - r;
    double Bx = _i2f(maxx) + r, By = _i2f(maxy) + r, Bz = _i2f(maxz) + r;
    double ax = _i2f(c_ax), ay = _i2f(c_ay), az = _i2f(c_az);
    double bex = _i2f(c_bx), bey = _i2f(c_by), bez = _i2f(c_bz);
    double dx = bex - ax, dy = bey - ay, dz = bez - az;
    // Liang-Barsky-style segment vs slab clipping.
    double tmin = 0.0, tmax = 1.0;
    // X slab.
    if (fabs(dx) < 1e-12) {
        if (ax < bx || ax > Bx) return 0;
    } else {
        double t1 = (bx - ax) / dx, t2 = (Bx - ax) / dx;
        if (t1 > t2) { double t = t1; t1 = t2; t2 = t; }
        if (t1 > tmin) tmin = t1;
        if (t2 < tmax) tmax = t2;
        if (tmin > tmax) return 0;
    }
    // Y slab.
    if (fabs(dy) < 1e-12) {
        if (ay < by || ay > By) return 0;
    } else {
        double t1 = (by - ay) / dy, t2 = (By - ay) / dy;
        if (t1 > t2) { double t = t1; t1 = t2; t2 = t; }
        if (t1 > tmin) tmin = t1;
        if (t2 < tmax) tmax = t2;
        if (tmin > tmax) return 0;
    }
    // Z slab.
    if (fabs(dz) < 1e-12) {
        if (az < bz || az > Bz) return 0;
    } else {
        double t1 = (bz - az) / dz, t2 = (Bz - az) / dz;
        if (t1 > t2) { double t = t1; t1 = t2; t2 = t; }
        if (t1 > tmin) tmin = t1;
        if (t2 < tmax) tmax = t2;
        if (tmin > tmax) return 0;
    }
    return 1;
}

// ---- 2D polygon-polygon collision via SAT (v0.2.243) ----
//
// Separating Axis Theorem for convex 2D polygons. For each edge
// of either polygon, project both polygons onto the edge's
// perpendicular axis. If any projection pair doesn't overlap,
// the polygons are separated. If no such separating axis is
// found, they overlap.
//
// Foundation for 2D mobile-robot collision (e.g., AGV footprint
// vs obstacle polygons), planar gripper-jaw collision, board-game
// piece overlap. Complements the 3D GJK + EPA shipped earlier.
//
// Both polygons must be CONVEX and CCW-wound. For non-convex
// polygons, decompose into convex pieces first.

// Project a polygon onto an axis; writes (min, max) projections.
static void _project_poly(const double *pts, int n, double ax, double ay,
                          double *mn, double *mx) {
    double v = pts[0]*ax + pts[1]*ay;
    *mn = *mx = v;
    for (int i = 1; i < n; i++) {
        v = pts[i*2+0]*ax + pts[i*2+1]*ay;
        if (v < *mn) *mn = v;
        if (v > *mx) *mx = v;
    }
}

// Check separation along the perpendicular axes of polygon `a`.
// Returns 1 if any separating axis is found (no overlap).
static int _sat_separated(const double *a, int na, const double *b, int nb) {
    for (int i = 0; i < na; i++) {
        int j = (i + 1) % na;
        double ex = a[j*2+0] - a[i*2+0];
        double ey = a[j*2+1] - a[i*2+1];
        // Perpendicular axis: rotate edge 90°. Direction sign doesn't
        // matter for overlap test.
        double ax = -ey, ay = ex;
        double mag = sqrt(ax*ax + ay*ay);
        if (mag < 1e-12) continue;
        ax /= mag; ay /= mag;
        double a_min, a_max, b_min, b_max;
        _project_poly(a, na, ax, ay, &a_min, &a_max);
        _project_poly(b, nb, ax, ay, &b_min, &b_max);
        if (a_max < b_min || b_max < a_min) return 1;  // gap
    }
    return 0;
}

// Returns 1 if convex polygons A and B overlap, 0 otherwise.
// `pts_a_ptr` is `double[na * 2]`; same for B.
long long nuc_coll_poly2d_sat(
    long long pts_a_ptr, long long na_,
    long long pts_b_ptr, long long nb_)
{
    int na = (int)na_, nb = (int)nb_;
    if (na < 3 || nb < 3) return -1;
    const double *a = (const double *)(void *)(size_t)pts_a_ptr;
    const double *b = (const double *)(void *)(size_t)pts_b_ptr;
    if (!a || !b) return -1;
    if (_sat_separated(a, na, b, nb)) return 0;
    if (_sat_separated(b, nb, a, na)) return 0;
    return 1;
}

// ---- AABB-AABB overlap ----
long long nuc_coll_aabb_aabb(
    long long a_minx, long long a_miny, long long a_minz,
    long long a_maxx, long long a_maxy, long long a_maxz,
    long long b_minx, long long b_miny, long long b_minz,
    long long b_maxx, long long b_maxy, long long b_maxz)
{
    if (_i2f(a_maxx) < _i2f(b_minx) || _i2f(a_minx) > _i2f(b_maxx)) return 0;
    if (_i2f(a_maxy) < _i2f(b_miny) || _i2f(a_miny) > _i2f(b_maxy)) return 0;
    if (_i2f(a_maxz) < _i2f(b_minz) || _i2f(a_minz) > _i2f(b_maxz)) return 0;
    return 1;
}
