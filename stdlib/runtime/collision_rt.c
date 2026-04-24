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
