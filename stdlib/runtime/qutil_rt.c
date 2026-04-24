// qutil_rt.c — Quaternion utilities (SLERP, log/exp, conversions)
// on raw `double[4]` buffers. Complement to `kinematics_rt.c`,
// which uses allocated handles. These functions take pointers
// directly so the caller can avoid per-call allocation in tight
// inner loops (controllers, trajectory interpolation).
//
// Convention: scalar-first quaternions `q = (w, x, y, z)`.
// Hamilton product. Body→world rotation when used with rotate
// helpers in `kinematics_rt.c` / `ahrs_rt.c`.
//
// API surface (all functions take/return pointers):
//   - SLERP (constant angular velocity between unit quaternions)
//   - SQUAD (smooth cubic interpolation through control points)
//   - log: unit quaternion → 3-vector axis-angle (rotation vector)
//   - exp: 3-vector axis-angle → unit quaternion
//   - axis-angle ↔ quaternion explicit converters
//   - ZYX Euler ↔ quaternion converters
//   - relative rotation `q12 = q1⁻¹ · q2` and angular distance
//
// Compile: clang -c stdlib/runtime/qutil_rt.c -o target/qutil.obj -O2

#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

static void _q_normalize(double *q) {
    double n = sqrt(q[0]*q[0]+q[1]*q[1]+q[2]*q[2]+q[3]*q[3]);
    if (n > 1e-12) { q[0]/=n; q[1]/=n; q[2]/=n; q[3]/=n; }
    else { q[0]=1; q[1]=q[2]=q[3]=0; }
}
static void _q_mul(const double *a, const double *b, double *o) {
    o[0] = a[0]*b[0] - a[1]*b[1] - a[2]*b[2] - a[3]*b[3];
    o[1] = a[0]*b[1] + a[1]*b[0] + a[2]*b[3] - a[3]*b[2];
    o[2] = a[0]*b[2] - a[1]*b[3] + a[2]*b[0] + a[3]*b[1];
    o[3] = a[0]*b[3] + a[1]*b[2] - a[2]*b[1] + a[3]*b[0];
}
static void _q_conj(const double *q, double *o) {
    o[0]=q[0]; o[1]=-q[1]; o[2]=-q[2]; o[3]=-q[3];
}

// === SLERP (Shoemake 1985) ===
//
// Constant-angular-velocity interpolation along the great-circle
// arc on S³. Caller-supplied output buffer (double[4]).
void nuc_qutil_slerp(long long q1_ptr, long long q2_ptr, long long t_b, long long out_ptr) {
    double *q1 = (double *)(void *)(size_t)q1_ptr;
    double *q2 = (double *)(void *)(size_t)q2_ptr;
    double *o  = (double *)(void *)(size_t)out_ptr;
    double t = _i2f(t_b);
    if (!q1 || !q2 || !o) return;

    // Cosine of half-angle (4-D dot product).
    double cos_half = q1[0]*q2[0] + q1[1]*q2[1] + q1[2]*q2[2] + q1[3]*q2[3];
    double q2c[4] = { q2[0], q2[1], q2[2], q2[3] };
    // Pick the shorter arc by flipping q2 if needed.
    if (cos_half < 0) {
        cos_half = -cos_half;
        q2c[0] = -q2c[0]; q2c[1] = -q2c[1]; q2c[2] = -q2c[2]; q2c[3] = -q2c[3];
    }
    if (cos_half > 0.9995) {
        // Very close — fall back to lerp + normalize to avoid div-by-tiny-sin.
        for (int i = 0; i < 4; i++) o[i] = (1.0 - t) * q1[i] + t * q2c[i];
        _q_normalize(o);
        return;
    }
    double half_angle = acos(cos_half);
    double sin_half   = sin(half_angle);
    double a = sin((1.0 - t) * half_angle) / sin_half;
    double b = sin(t * half_angle) / sin_half;
    for (int i = 0; i < 4; i++) o[i] = a * q1[i] + b * q2c[i];
    _q_normalize(o);
}

// === SO(3) exp/log ===

// exp: axis-angle ω ∈ ℝ³ (rotation vector, |ω| = angle in rad)
// → unit quaternion.
void nuc_qutil_exp(long long omega_ptr, long long q_out_ptr) {
    double *w = (double *)(void *)(size_t)omega_ptr;
    double *o = (double *)(void *)(size_t)q_out_ptr;
    if (!w || !o) return;
    double a = sqrt(w[0]*w[0] + w[1]*w[1] + w[2]*w[2]);
    if (a < 1e-9) {
        o[0] = 1.0;
        o[1] = w[0] * 0.5;
        o[2] = w[1] * 0.5;
        o[3] = w[2] * 0.5;
        _q_normalize(o);
        return;
    }
    double ha = a * 0.5;
    double s_over_a = sin(ha) / a;
    o[0] = cos(ha);
    o[1] = w[0] * s_over_a;
    o[2] = w[1] * s_over_a;
    o[3] = w[2] * s_over_a;
}

// log: unit quaternion → axis-angle ω ∈ ℝ³.
void nuc_qutil_log(long long q_ptr, long long omega_out_ptr) {
    double *q = (double *)(void *)(size_t)q_ptr;
    double *o = (double *)(void *)(size_t)omega_out_ptr;
    if (!q || !o) return;
    double qw = q[0], vx = q[1], vy = q[2], vz = q[3];
    if (qw < 0) { qw = -qw; vx = -vx; vy = -vy; vz = -vz; }   // shorter rotation
    double vnorm = sqrt(vx*vx + vy*vy + vz*vz);
    if (vnorm < 1e-9) {
        o[0] = 2.0 * vx;
        o[1] = 2.0 * vy;
        o[2] = 2.0 * vz;
        return;
    }
    double theta = 2.0 * atan2(vnorm, qw);
    double k = theta / vnorm;
    o[0] = vx * k;
    o[1] = vy * k;
    o[2] = vz * k;
}

// === Axis-angle (3-vec axis + scalar angle) ↔ quaternion ===

void nuc_qutil_from_axis_angle(long long axis_ptr, long long angle_b, long long q_out_ptr) {
    double *a = (double *)(void *)(size_t)axis_ptr;
    double *o = (double *)(void *)(size_t)q_out_ptr;
    double angle = _i2f(angle_b);
    if (!a || !o) return;
    double n = sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2]);
    if (n < 1e-12) { o[0] = 1; o[1] = o[2] = o[3] = 0; return; }
    double s = sin(angle * 0.5) / n;
    o[0] = cos(angle * 0.5);
    o[1] = a[0] * s;
    o[2] = a[1] * s;
    o[3] = a[2] * s;
}

// Returns the rotation angle (radians); writes the rotation axis
// (unit vector) into axis_out.
long long nuc_qutil_to_axis_angle(long long q_ptr, long long axis_out_ptr) {
    double *q  = (double *)(void *)(size_t)q_ptr;
    double *ax = (double *)(void *)(size_t)axis_out_ptr;
    if (!q) return _f2i(0.0);
    double qw = q[0], vx = q[1], vy = q[2], vz = q[3];
    if (qw < 0) { qw = -qw; vx = -vx; vy = -vy; vz = -vz; }
    double vnorm = sqrt(vx*vx + vy*vy + vz*vz);
    if (vnorm < 1e-9) {
        if (ax) { ax[0] = 1; ax[1] = ax[2] = 0; }
        return _f2i(0.0);
    }
    double theta = 2.0 * atan2(vnorm, qw);
    if (ax) { ax[0] = vx / vnorm; ax[1] = vy / vnorm; ax[2] = vz / vnorm; }
    return _f2i(theta);
}

// === Euler ZYX (roll, pitch, yaw) ↔ quaternion ===

void nuc_qutil_from_euler(long long roll_b, long long pitch_b, long long yaw_b, long long q_out_ptr) {
    double r = _i2f(roll_b), p = _i2f(pitch_b), y = _i2f(yaw_b);
    double *o = (double *)(void *)(size_t)q_out_ptr;
    if (!o) return;
    double cr = cos(r * 0.5), sr = sin(r * 0.5);
    double cp = cos(p * 0.5), sp = sin(p * 0.5);
    double cy = cos(y * 0.5), sy = sin(y * 0.5);
    o[0] = cr*cp*cy + sr*sp*sy;
    o[1] = sr*cp*cy - cr*sp*sy;
    o[2] = cr*sp*cy + sr*cp*sy;
    o[3] = cr*cp*sy - sr*sp*cy;
}

// Writes (roll, pitch, yaw) into rpy_out (3 doubles).
void nuc_qutil_to_euler(long long q_ptr, long long rpy_out_ptr) {
    double *q = (double *)(void *)(size_t)q_ptr;
    double *rpy = (double *)(void *)(size_t)rpy_out_ptr;
    if (!q || !rpy) return;
    double qw = q[0], qx = q[1], qy = q[2], qz = q[3];
    double sinr_cosp = 2.0 * (qw*qx + qy*qz);
    double cosr_cosp = 1.0 - 2.0 * (qx*qx + qy*qy);
    rpy[0] = atan2(sinr_cosp, cosr_cosp);
    double sinp = 2.0 * (qw*qy - qz*qx);
    if (fabs(sinp) >= 1.0) rpy[1] = (sinp > 0 ? 1 : -1) * (M_PI / 2.0);
    else                   rpy[1] = asin(sinp);
    double siny_cosp = 2.0 * (qw*qz + qx*qy);
    double cosy_cosp = 1.0 - 2.0 * (qy*qy + qz*qz);
    rpy[2] = atan2(siny_cosp, cosy_cosp);
}

// === Relative rotation + angular distance ===

// q12 = q1⁻¹ · q2 (the rotation that takes q1 to q2 in q1's frame).
void nuc_qutil_relative(long long q1_ptr, long long q2_ptr, long long q_out_ptr) {
    double *q1 = (double *)(void *)(size_t)q1_ptr;
    double *q2 = (double *)(void *)(size_t)q2_ptr;
    double *o  = (double *)(void *)(size_t)q_out_ptr;
    if (!q1 || !q2 || !o) return;
    double q1i[4]; _q_conj(q1, q1i);
    _q_mul(q1i, q2, o);
}

// Angular distance between two unit quaternions (radians, in [0, π]).
long long nuc_qutil_angular_distance(long long q1_ptr, long long q2_ptr) {
    double *q1 = (double *)(void *)(size_t)q1_ptr;
    double *q2 = (double *)(void *)(size_t)q2_ptr;
    if (!q1 || !q2) return _f2i(0.0);
    double d = q1[0]*q2[0] + q1[1]*q2[1] + q1[2]*q2[2] + q1[3]*q2[3];
    if (d < 0) d = -d;
    if (d > 1.0) d = 1.0;
    return _f2i(2.0 * acos(d));
}

// SQUAD: smooth interpolation through quaternion control points.
// Standard Shoemake formulation:
//   squad(p, a, b, q, t) = slerp( slerp(p, q, t), slerp(a, b, t), 2t(1-t) )
// where the user supplies p, q (segment endpoints) and a, b (the
// "tangent" intermediate control quaternions, typically computed
// from neighboring segments).
void nuc_qutil_squad(long long p_ptr, long long a_ptr, long long b_ptr, long long q_ptr,
                     long long t_b, long long out_ptr)
{
    double *p = (double *)(void *)(size_t)p_ptr;
    double *a = (double *)(void *)(size_t)a_ptr;
    double *b = (double *)(void *)(size_t)b_ptr;
    double *q = (double *)(void *)(size_t)q_ptr;
    double *o = (double *)(void *)(size_t)out_ptr;
    double t = _i2f(t_b);
    if (!p || !a || !b || !q || !o) return;
    double s1[4], s2[4];
    long long t_bb = _f2i(t);
    nuc_qutil_slerp((long long)(size_t)p, (long long)(size_t)q, t_bb, (long long)(size_t)s1);
    nuc_qutil_slerp((long long)(size_t)a, (long long)(size_t)b, t_bb, (long long)(size_t)s2);
    long long s_b = _f2i(2.0 * t * (1.0 - t));
    nuc_qutil_slerp((long long)(size_t)s1, (long long)(size_t)s2, s_b, (long long)(size_t)o);
}
