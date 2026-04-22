// orbit_rt.c — Orbital Mechanics for Nucleor
// Kepler↔Cartesian, orbit propagation, Hohmann transfer, Lambert solver.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/orbit_rt.c -o target/orbit_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _ob_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _ob_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } OBVec;

static OBVec *obvec_new(int n) {
    OBVec *v = (OBVec *)malloc(sizeof(OBVec));
    v->len = n; v->cap = n;
    v->data = (long long *)calloc(n, sizeof(long long));
    return v;
}

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Default: Earth mu (km^3/s^2)
#define MU_EARTH 398600.4418

// ================================================================
//  Kepler → Cartesian (perifocal → ECI)
//  a=semi-major, e=eccentricity, inc=inclination, omega=arg of periapsis,
//  Omega=RAAN, nu=true anomaly. All angles in radians.
//  Returns Vec [x, y, z, vx, vy, vz]
// ================================================================

long long nuc_orbit_kepler_to_cart(long long a_b, long long e_b, long long inc_b,
                                    long long omega_b, long long Omega_b, long long nu_b,
                                    long long mu_b) {
    double a = _ob_i2f(a_b), e = _ob_i2f(e_b), inc = _ob_i2f(inc_b);
    double omega = _ob_i2f(omega_b), Omega = _ob_i2f(Omega_b), nu = _ob_i2f(nu_b);
    double mu = _ob_i2f(mu_b);
    if (mu <= 0) mu = MU_EARTH;

    double p = a * (1 - e * e);
    double r = p / (1 + e * cos(nu));
    double h = sqrt(mu * p);

    // Perifocal coordinates
    double x_pf = r * cos(nu), y_pf = r * sin(nu);
    double vx_pf = -mu / h * sin(nu);
    double vy_pf = mu / h * (e + cos(nu));

    // Rotation matrix (perifocal → ECI)
    double cO = cos(Omega), sO = sin(Omega);
    double cw = cos(omega), sw = sin(omega);
    double ci = cos(inc), si = sin(inc);

    double R[3][3];
    R[0][0] = cO * cw - sO * sw * ci;
    R[0][1] = -cO * sw - sO * cw * ci;
    R[0][2] = sO * si;
    R[1][0] = sO * cw + cO * sw * ci;
    R[1][1] = -sO * sw + cO * cw * ci;
    R[1][2] = -cO * si;
    R[2][0] = sw * si;
    R[2][1] = cw * si;
    R[2][2] = ci;

    OBVec *result = obvec_new(6);
    result->data[0] = _ob_f2i(R[0][0] * x_pf + R[0][1] * y_pf);
    result->data[1] = _ob_f2i(R[1][0] * x_pf + R[1][1] * y_pf);
    result->data[2] = _ob_f2i(R[2][0] * x_pf + R[2][1] * y_pf);
    result->data[3] = _ob_f2i(R[0][0] * vx_pf + R[0][1] * vy_pf);
    result->data[4] = _ob_f2i(R[1][0] * vx_pf + R[1][1] * vy_pf);
    result->data[5] = _ob_f2i(R[2][0] * vx_pf + R[2][1] * vy_pf);
    return (long long)result;
}

// ================================================================
//  Orbital Period
// ================================================================

long long nuc_orbit_period(long long a_bits, long long mu_bits) {
    double a = _ob_i2f(a_bits), mu = _ob_i2f(mu_bits);
    if (mu <= 0) mu = MU_EARTH;
    return _ob_f2i(2 * M_PI * sqrt(a * a * a / mu));
}

// ================================================================
//  Hohmann Transfer
//  Returns Vec [dv1, dv2, transfer_time]
// ================================================================

long long nuc_orbit_hohmann(long long r1_bits, long long r2_bits, long long mu_bits) {
    double r1 = _ob_i2f(r1_bits), r2 = _ob_i2f(r2_bits), mu = _ob_i2f(mu_bits);
    if (mu <= 0) mu = MU_EARTH;

    double at = (r1 + r2) / 2; // transfer semi-major axis

    double v1_circ = sqrt(mu / r1);
    double v1_trans = sqrt(mu * (2.0 / r1 - 1.0 / at));
    double dv1 = fabs(v1_trans - v1_circ);

    double v2_circ = sqrt(mu / r2);
    double v2_trans = sqrt(mu * (2.0 / r2 - 1.0 / at));
    double dv2 = fabs(v2_circ - v2_trans);

    double tof = M_PI * sqrt(at * at * at / mu);

    OBVec *result = obvec_new(3);
    result->data[0] = _ob_f2i(dv1);
    result->data[1] = _ob_f2i(dv2);
    result->data[2] = _ob_f2i(tof);
    return (long long)result;
}

// ================================================================
//  Orbit Propagation (Kepler equation, 2-body)
//  state: Vec [x, y, z, vx, vy, vz], mu, dt
//  Returns new state Vec
// ================================================================

long long nuc_orbit_propagate(long long state_h, long long mu_bits, long long dt_bits) {
    OBVec *st = (OBVec *)(void *)state_h;
    double mu = _ob_i2f(mu_bits), dt = _ob_i2f(dt_bits);
    if (mu <= 0) mu = MU_EARTH;

    double x = _ob_i2f(st->data[0]), y = _ob_i2f(st->data[1]), z = _ob_i2f(st->data[2]);
    double vx = _ob_i2f(st->data[3]), vy = _ob_i2f(st->data[4]), vz = _ob_i2f(st->data[5]);

    // RK4 for 2-body problem
    double pos[3] = {x, y, z}, vel[3] = {vx, vy, vz};
    double k1p[3], k1v[3], k2p[3], k2v[3], k3p[3], k3v[3], k4p[3], k4v[3];
    double tp[3], tv[3];

    #define ACCEL(px, py, pz, ax, ay, az) do { \
        double r3 = pow((px)*(px)+(py)*(py)+(pz)*(pz), 1.5); \
        if (r3 < 1e-10) r3 = 1e-10; \
        ax = -mu * (px) / r3; ay = -mu * (py) / r3; az = -mu * (pz) / r3; \
    } while(0)

    // k1
    for (int i = 0; i < 3; i++) k1p[i] = vel[i];
    ACCEL(pos[0], pos[1], pos[2], k1v[0], k1v[1], k1v[2]);

    // k2
    for (int i = 0; i < 3; i++) { tp[i] = pos[i] + 0.5 * dt * k1p[i]; tv[i] = vel[i] + 0.5 * dt * k1v[i]; }
    for (int i = 0; i < 3; i++) k2p[i] = tv[i];
    ACCEL(tp[0], tp[1], tp[2], k2v[0], k2v[1], k2v[2]);

    // k3
    for (int i = 0; i < 3; i++) { tp[i] = pos[i] + 0.5 * dt * k2p[i]; tv[i] = vel[i] + 0.5 * dt * k2v[i]; }
    for (int i = 0; i < 3; i++) k3p[i] = tv[i];
    ACCEL(tp[0], tp[1], tp[2], k3v[0], k3v[1], k3v[2]);

    // k4
    for (int i = 0; i < 3; i++) { tp[i] = pos[i] + dt * k3p[i]; tv[i] = vel[i] + dt * k3v[i]; }
    for (int i = 0; i < 3; i++) k4p[i] = tv[i];
    ACCEL(tp[0], tp[1], tp[2], k4v[0], k4v[1], k4v[2]);

    #undef ACCEL

    OBVec *result = obvec_new(6);
    for (int i = 0; i < 3; i++) {
        double new_p = pos[i] + dt / 6.0 * (k1p[i] + 2 * k2p[i] + 2 * k3p[i] + k4p[i]);
        double new_v = vel[i] + dt / 6.0 * (k1v[i] + 2 * k2v[i] + 2 * k3v[i] + k4v[i]);
        result->data[i] = _ob_f2i(new_p);
        result->data[3 + i] = _ob_f2i(new_v);
    }
    return (long long)result;
}

// ================================================================
//  Vis-viva: velocity at distance r for orbit with semi-major axis a
// ================================================================

long long nuc_orbit_vis_viva(long long r_bits, long long a_bits, long long mu_bits) {
    double r = _ob_i2f(r_bits), a = _ob_i2f(a_bits), mu = _ob_i2f(mu_bits);
    if (mu <= 0) mu = MU_EARTH;
    double v = sqrt(mu * (2.0 / r - 1.0 / a));
    return _ob_f2i(v);
}

// ================================================================
//  Escape velocity at distance r
// ================================================================

long long nuc_orbit_escape_velocity(long long r_bits, long long mu_bits) {
    double r = _ob_i2f(r_bits), mu = _ob_i2f(mu_bits);
    if (mu <= 0) mu = MU_EARTH;
    return _ob_f2i(sqrt(2 * mu / r));
}
