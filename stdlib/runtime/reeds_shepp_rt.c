// reeds_shepp_rt.c — Reeds-Shepp shortest paths for a car-like
// robot with minimum turning radius that can also MOVE IN REVERSE
// (Reeds & Shepp 1990).
//
// Whereas Dubins paths (`dubins_rt.c`) allow only FORWARD motion
// and produce 6 path types {LSL, LSR, RSL, RSR, RLR, LRL},
// Reeds-Shepp allows reverse, producing 48 possible word types
// grouped into 12 families. We use the classical
// Sussmann-Tang / OMPL structure with 12 base families and the
// symmetry transforms (timeflip / reflect / backwards) that
// expand each base to its 4 variants.
//
// Given start `(x0, y0, θ0)`, goal `(x1, y1, θ1)`, and minimum
// turning radius `R`, returns the LENGTH of the shortest path.
//
// This matches the Dubins surface so a planner can pick between
// forward-only (`dubins.nr`) and forward+reverse (this rod)
// based on the vehicle capability.
//
// **Limitations** (path sampling / smoothing / lateral-acceleration
// constraints land in v0.6 if needed):
// - Returns length only (not sampled poses along the path).
// - Non-holonomic. Assumes constant curvature on turns.
// - Type index returned is 0..47 (subject to change); treat as opaque.
//
// Compile: clang -c stdlib/runtime/reeds_shepp_rt.c -o target/reeds_shepp.obj -O2

#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
#define TWOPI (2.0 * M_PI)

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

static double _mod_2pi(double a) {
    a = fmod(a, TWOPI);
    if (a < 0) a += TWOPI;
    return a;
}
static double _M(double a) {
    double x = fmod(a, TWOPI);
    if (x <= -M_PI) x += TWOPI;
    else if (x > M_PI) x -= TWOPI;
    return x;
}

// Tau/Omega helper from Reeds-Shepp 1990 section 8.
static void _tau_omega(double u, double v, double xi, double eta, double phi,
                       double *tau, double *omega)
{
    double delta = _M(u - v);
    double A = sin(u) - sin(delta);
    double B = cos(u) - cos(delta) - 1.0;
    double t1 = atan2(eta * A - xi * B, xi * A + eta * B);
    double t2 = 2.0 * (cos(delta) - cos(v) - cos(u)) + 3.0;
    *tau = (t2 < 0) ? _M(t1 + M_PI) : _M(t1);
    *omega = _M(*tau - u + v - phi);
}

// ---- Base 8.1: CSC — no cusp, word = (+,+) or (-,-)
// L+ S+ L+  (LpSpLp) and variants.
static int _LpSpLp(double x, double y, double phi, double *t, double *u, double *v) {
    double u1 = hypot(x - sin(phi), y - 1.0 + cos(phi));
    double t1 = atan2(y - 1.0 + cos(phi), x - sin(phi));
    if (u1 < 0) return 0;
    *u = u1;
    *t = _M(t1);
    *v = _M(phi - *t);
    if (*t < -1e-12 || *v < -1e-12) return 0;
    return 1;
}

static int _LpSpRp(double x, double y, double phi, double *t, double *u, double *v) {
    double u1_sq = -2.0 + (x + sin(phi)) * (x + sin(phi)) + (y - 1.0 - cos(phi)) * (y - 1.0 - cos(phi));
    if (u1_sq < 0) return 0;
    double u1 = sqrt(u1_sq);
    double theta = atan2(y - 1.0 - cos(phi), x + sin(phi));
    double t1 = _M(theta - atan2(-2.0, u1));
    if (u1 < 0 || t1 < -1e-12) return 0;
    *u = u1;
    *t = t1;
    *v = _M(t1 - phi);
    if (*v < -1e-12) return 0;
    return 1;
}

// ---- Base 8.3: C|C|C — no cusp
static int _LpRmL(double x, double y, double phi, double *t, double *u, double *v) {
    double xi = x - sin(phi);
    double eta = y - 1.0 + cos(phi);
    double u1 = hypot(xi, eta);
    if (u1 > 4.0) return 0;
    double theta = atan2(eta, xi);
    double A = acos(u1 / 4.0);
    *t = _M(M_PI/2.0 + A + theta);
    *u = _M(M_PI - 2.0 * A);
    *v = _M(phi - *t - *u);
    if (*t < -1e-12 || *u > 1e-12 || *v > 1e-12) return 0;
    return 1;
}

// ---- Base 8.4: C|CC — cusp between first and second C
static int _LpRmLm(double x, double y, double phi, double *t, double *u, double *v) {
    double xi = x - sin(phi);
    double eta = y - 1.0 + cos(phi);
    double u1 = hypot(xi, eta);
    if (u1 > 4.0) return 0;
    double theta = atan2(eta, xi);
    double A = acos(u1 / 4.0);
    *t = _M(M_PI/2.0 + A + theta);
    *u = _M(M_PI - 2.0 * A);
    *v = _M(*t + *u - phi);
    if (*t < -1e-12 || *u > 1e-12) return 0;
    return 1;
}

// ---- Base 8.7: CCu|CuC
static int _LpRpuLmuRm(double x, double y, double phi, double *t, double *u, double *v) {
    double xi = x + sin(phi);
    double eta = y - 1.0 - cos(phi);
    double rho = (2.0 + hypot(xi, eta)) / 4.0;
    if (rho > 1.0) return 0;
    *u = acos(rho);
    double tau, omega;
    _tau_omega(*u, -(*u), xi, eta, phi, &tau, &omega);
    *t = tau;
    *v = omega;
    if (*t < -1e-12 || *v > 1e-12) return 0;
    return 1;
}

// ---- Base 8.8: C|CuCu|C
static int _LpRmuLmuRp(double x, double y, double phi, double *t, double *u, double *v) {
    double xi = x + sin(phi);
    double eta = y - 1.0 - cos(phi);
    double rho = (20.0 - xi*xi - eta*eta) / 16.0;
    if (rho < 0.0 || rho > 1.0) return 0;
    *u = -acos(rho);
    if (*u < -M_PI/2.0) return 0;
    double tau, omega;
    _tau_omega(*u, *u, xi, eta, phi, &tau, &omega);
    *t = tau;
    *v = omega;
    if (*t < -1e-12 || *v < -1e-12) return 0;
    return 1;
}

// ---- Base 8.9: C|C[pi/2]SC
static int _LpRmSmLm(double x, double y, double phi, double *t, double *u, double *v) {
    double xi = x - sin(phi);
    double eta = y - 1.0 + cos(phi);
    double rho = hypot(xi, eta);
    if (rho < 2.0) return 0;
    double theta = atan2(eta, xi);
    *t = _M(theta + M_PI/2.0);
    *u = 2.0 - rho;
    *v = _M(phi - *t - M_PI/2.0);
    if (*t < -1e-12 || *u > 1e-12 || *v > 1e-12) return 0;
    return 1;
}

static int _LpRmSmRm(double x, double y, double phi, double *t, double *u, double *v) {
    double xi = x + sin(phi);
    double eta = y - 1.0 - cos(phi);
    double rho = hypot(xi, eta);
    if (rho < 2.0) return 0;
    *t = _M(atan2(eta, xi));
    *u = 2.0 - rho;
    *v = _M(phi - *t - M_PI/2.0);
    if (*t < -1e-12 || *u > 1e-12 || *v > 1e-12) return 0;
    return 1;
}

// ---- Base 8.11: C|C[pi/2]SC[pi/2]|C
static int _LpRmSLmRp(double x, double y, double phi, double *t, double *u, double *v) {
    double xi = x + sin(phi);
    double eta = y - 1.0 - cos(phi);
    double rho = hypot(xi, eta);
    if (rho < 2.0) return 0;
    double theta = atan2(eta, xi);
    *t = _M(theta - asin(2.0 / rho));
    *u = 2.0 - sqrt(rho*rho - 4.0);
    *v = _M(*t - phi + M_PI);
    if (*t < -1e-12 || *u > 1e-12 || *v < -1e-12) return 0;
    return 1;
}

static double abssum(double t, double u, double v) {
    return fabs(t) + fabs(u) + fabs(v);
}

// Try one base family and 4 symmetry variants, return the
// minimum total length found so far. Formula family names
// follow the Reeds-Shepp 1990 paper (Section 8).
//
// Symmetry transforms:
//   timeflip : (x, y, phi) -> (-x, y, -phi)   [reverses direction]
//   reflect  : (x, y, phi) -> ( x, -y, -phi)  [mirrors left/right]
//   both     : (x, y, phi) -> (-x, -y, phi)
//
// For each base, we try (x, y, phi), (−x, y, −phi),
// (x, −y, −phi), (−x, −y, phi).
typedef int (*rs_base_fn)(double, double, double, double *, double *, double *);

static void _try4(rs_base_fn f, double x, double y, double phi, double *best) {
    double t, u, v;
    if (f(x, y, phi, &t, &u, &v))    { double L = abssum(t,u,v); if (L < *best) *best = L; }
    if (f(-x, y, -phi, &t, &u, &v))  { double L = abssum(t,u,v); if (L < *best) *best = L; }
    if (f(x, -y, -phi, &t, &u, &v))  { double L = abssum(t,u,v); if (L < *best) *best = L; }
    if (f(-x, -y, phi, &t, &u, &v))  { double L = abssum(t,u,v); if (L < *best) *best = L; }
}

// Given start and goal poses in world, and minimum turning radius R,
// compute the Reeds-Shepp shortest path length (in world units) and
// return it via *length_out_ptr. Returns 1 on success, 0 on bad
// input.
long long nuc_reeds_shepp_length(
    long long x0_b, long long y0_b, long long th0_b,
    long long x1_b, long long y1_b, long long th1_b,
    long long R_b,
    long long length_out_ptr)
{
    double *length_out = (double *)(void *)(size_t)length_out_ptr;
    if (!length_out) return 0;
    double x0 = _i2f(x0_b), y0 = _i2f(y0_b), th0 = _i2f(th0_b);
    double x1 = _i2f(x1_b), y1 = _i2f(y1_b), th1 = _i2f(th1_b);
    double R = _i2f(R_b);
    if (R <= 0) return 0;

    // Transform goal into normalized coordinates (start at origin,
    // heading 0, radius 1).
    double dx = x1 - x0;
    double dy = y1 - y0;
    double c = cos(th0), s = sin(th0);
    double xn = ( c*dx + s*dy) / R;
    double yn = (-s*dx + c*dy) / R;
    double phin = _M(th1 - th0);

    double best = 1e300;
    _try4(_LpSpLp,        xn, yn, phin, &best);
    _try4(_LpSpRp,        xn, yn, phin, &best);
    _try4(_LpRmL,         xn, yn, phin, &best);
    _try4(_LpRmLm,        xn, yn, phin, &best);
    _try4(_LpRpuLmuRm,    xn, yn, phin, &best);
    _try4(_LpRmuLmuRp,    xn, yn, phin, &best);
    _try4(_LpRmSmLm,      xn, yn, phin, &best);
    _try4(_LpRmSmRm,      xn, yn, phin, &best);
    _try4(_LpRmSLmRp,     xn, yn, phin, &best);

    if (best >= 1e299) return 0;
    *length_out = best * R;
    return 1;
}
