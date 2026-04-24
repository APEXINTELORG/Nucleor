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

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

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
