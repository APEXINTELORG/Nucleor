// ahrs_rt.c — Attitude & Heading Reference System via the
// Mahony quaternion complementary filter (Mahony, Hamel & Pflimlin
// 2008).
//
// Maintains a unit quaternion q (body → world rotation) from IMU
// readings:
//   - Gyroscope: angular velocity ω (rad/s, body frame)
//   - Accelerometer: gravity vector a (m/s² or normalized, body
//     frame)
//
// Each update tick:
//
//   g_pred_body = qᵀ · (0, 0, 1)                      // predicted gravity in body frame
//   error       = g_pred_body × â                      // cross prod gives axis to rotate
//   ω_corr      = ω + Kp · error  +  Ki · ∫ error dt   // PI correction
//   q̇          = 0.5 · q · (0, ω_corr)
//   q           = q + q̇ · dt
//   q           = q / ‖q‖
//
// The Kp term provides instantaneous accel→tilt correction; the Ki
// term cancels gyro bias drift over time. With Kp = 1.0, Ki = 0.0
// (default) the filter reduces to a pure complementary filter.
//
// **Limitations** (magnetometer fusion / Madgwick variant land
// in v0.6 if needed):
// - Pitch and roll are observable from accelerometer; yaw is NOT
//   (gravity is yaw-invariant). Yaw drifts at the gyro bias rate
//   without an additional sensor (magnetometer or VO).
// - Assumes the body is not undergoing significant linear
//   acceleration — when it is, the accel reads `g + a_motion` and
//   the filter is biased. Common workaround: detect high accel
//   magnitude and drop accel correction temporarily.
// - No magnetometer fusion (would add a yaw correction term).
//
// Compile: clang -c stdlib/runtime/ahrs_rt.c -o target/ahrs.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    double q[4];           // body→world quaternion (qw, qx, qy, qz)
    double Kp, Ki;
    double bias[3];        // estimated gyro bias (integrated correction)
} NAHRS;

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

static void _world_to_body(const double *q, double vx, double vy, double vz, double *out) {
    double qc[4] = { q[0], -q[1], -q[2], -q[3] };
    double vq[4] = { 0, vx, vy, vz };
    double tmp[4], res[4];
    _q_mul(qc, vq, tmp);
    _q_mul(tmp, q, res);
    out[0] = res[1]; out[1] = res[2]; out[2] = res[3];
}

static int _norm3(double *v) {
    double n = sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    if (n <= 1e-9) return 0;
    v[0] /= n; v[1] /= n; v[2] /= n;
    return 1;
}

static void _cross(const double *a, const double *b, double *o) {
    o[0] = a[1]*b[2] - a[2]*b[1];
    o[1] = a[2]*b[0] - a[0]*b[2];
    o[2] = a[0]*b[1] - a[1]*b[0];
}

long long nuc_ahrs_new(long long Kp_b, long long Ki_b) {
    NAHRS *p = (NAHRS *)calloc(1, sizeof(NAHRS));
    p->q[0] = 1; p->q[1] = p->q[2] = p->q[3] = 0;
    double Kp = _i2f(Kp_b);
    double Ki = _i2f(Ki_b);
    p->Kp = (Kp >= 0) ? Kp : 1.0;
    p->Ki = (Ki >= 0) ? Ki : 0.0;
    return (long long)(size_t)p;
}

void nuc_ahrs_set_gains(long long h, long long Kp_b, long long Ki_b) {
    NAHRS *p = (NAHRS *)(void *)(size_t)h;
    if (!p) return;
    double Kp = _i2f(Kp_b), Ki = _i2f(Ki_b);
    if (Kp >= 0) p->Kp = Kp;
    if (Ki >= 0) p->Ki = Ki;
}

void nuc_ahrs_set_orientation(long long h, long long q_ptr) {
    NAHRS *p = (NAHRS *)(void *)(size_t)h;
    if (!p) return;
    double *q = (double *)(void *)(size_t)q_ptr;
    if (!q) return;
    p->q[0] = q[0]; p->q[1] = q[1]; p->q[2] = q[2]; p->q[3] = q[3];
    _q_normalize(p->q);
}

void nuc_ahrs_get_orientation(long long h, long long q_ptr) {
    NAHRS *p = (NAHRS *)(void *)(size_t)h;
    if (!p) return;
    double *q = (double *)(void *)(size_t)q_ptr;
    if (!q) return;
    q[0] = p->q[0]; q[1] = p->q[1]; q[2] = p->q[2]; q[3] = p->q[3];
}

// Convert internal quaternion to ZYX Euler (yaw, pitch, roll), in radians.
// rpy_out is double[3] = (roll, pitch, yaw).
void nuc_ahrs_get_euler(long long h, long long rpy_ptr) {
    NAHRS *p = (NAHRS *)(void *)(size_t)h;
    if (!p) return;
    double *rpy = (double *)(void *)(size_t)rpy_ptr;
    if (!rpy) return;
    double qw = p->q[0], qx = p->q[1], qy = p->q[2], qz = p->q[3];
    // ZYX intrinsic
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

static void _ahrs_update_inner(NAHRS *p, double *g, double *a, double *m, double dt) {
    if (!p || !g || dt <= 0) return;

    double wx = g[0], wy = g[1], wz = g[2];
    double ex = 0.0, ey = 0.0, ez = 0.0;
    int have_accel = 0;
    double a_meas[3] = {0, 0, 0};
    double g_pred[3] = {0, 0, 1};

    // Accel correction (skip if accel reading is degenerate).
    if (a) {
        a_meas[0] = a[0]; a_meas[1] = a[1]; a_meas[2] = a[2];
        if (_norm3(a_meas)) {
            have_accel = 1;
            _world_to_body(p->q, 0.0, 0.0, 1.0, g_pred);
            _norm3(g_pred);
            double e[3];
            _cross(g_pred, a_meas, e);
            ex += e[0]; ey += e[1]; ez += e[2];
        }
    }

    // Magnetometer yaw correction. The public contract uses a calibrated
    // body-frame magnetic vector whose world reference is +X. If accel is
    // present, both measured and predicted magnetic vectors are projected
    // into the horizontal plane so the correction is heading-only.
    if (m) {
        double m_meas[3] = { m[0], m[1], m[2] };
        if (_norm3(m_meas)) {
            double m_pred[3];
            _world_to_body(p->q, 1.0, 0.0, 0.0, m_pred);
            _norm3(m_pred);
            if (have_accel) {
                double dm = m_meas[0]*a_meas[0] + m_meas[1]*a_meas[1] + m_meas[2]*a_meas[2];
                m_meas[0] -= dm * a_meas[0];
                m_meas[1] -= dm * a_meas[1];
                m_meas[2] -= dm * a_meas[2];
                double dp = m_pred[0]*g_pred[0] + m_pred[1]*g_pred[1] + m_pred[2]*g_pred[2];
                m_pred[0] -= dp * g_pred[0];
                m_pred[1] -= dp * g_pred[1];
                m_pred[2] -= dp * g_pred[2];
            }
            if (_norm3(m_meas) && _norm3(m_pred)) {
                double e[3];
                _cross(m_meas, m_pred, e);
                ex += e[0]; ey += e[1]; ez += e[2];
            }
        }
    }

    // Integrate gyro bias (Ki) and apply PI correction.
    if ((have_accel || m) && p->Ki > 0) {
        p->bias[0] += p->Ki * ex * dt;
        p->bias[1] += p->Ki * ey * dt;
        p->bias[2] += p->Ki * ez * dt;
    }
    wx += p->Kp * ex + p->bias[0];
    wy += p->Kp * ey + p->bias[1];
    wz += p->Kp * ez + p->bias[2];

    // Quaternion derivative: q̇ = 0.5 * q * (0, wx, wy, wz).
    double qw = p->q[0], qx = p->q[1], qy = p->q[2], qz = p->q[3];
    double qdot[4];
    qdot[0] = 0.5 * (-qx*wx - qy*wy - qz*wz);
    qdot[1] = 0.5 * ( qw*wx + qy*wz - qz*wy);
    qdot[2] = 0.5 * ( qw*wy - qx*wz + qz*wx);
    qdot[3] = 0.5 * ( qw*wz + qx*wy - qy*wx);
    p->q[0] += qdot[0] * dt;
    p->q[1] += qdot[1] * dt;
    p->q[2] += qdot[2] * dt;
    p->q[3] += qdot[3] * dt;
    _q_normalize(p->q);
}

// One IMU step. gyro_ptr is double[3] (rad/s body frame), accel_ptr
// is double[3] (gravity vector in body frame; will be normalized).
// dt_b is timestep in seconds.
void nuc_ahrs_update(long long h, long long gyro_ptr, long long accel_ptr, long long dt_b) {
    NAHRS *p = (NAHRS *)(void *)(size_t)h;
    if (!p) return;
    double *g = (double *)(void *)(size_t)gyro_ptr;
    double *a = (double *)(void *)(size_t)accel_ptr;
    double dt = _i2f(dt_b);
    _ahrs_update_inner(p, g, a, NULL, dt);
}

// 9-DOF update with magnetometer heading correction. mag_ptr is a
// calibrated body-frame magnetic vector; the world reference field is +X.
void nuc_ahrs_update_mag(long long h, long long gyro_ptr, long long accel_ptr,
                         long long mag_ptr, long long dt_b) {
    NAHRS *p = (NAHRS *)(void *)(size_t)h;
    if (!p) return;
    double *g = (double *)(void *)(size_t)gyro_ptr;
    double *a = (double *)(void *)(size_t)accel_ptr;
    double *m = (double *)(void *)(size_t)mag_ptr;
    double dt = _i2f(dt_b);
    _ahrs_update_inner(p, g, a, m, dt);
}

// Read estimated gyro bias (integrated by Ki).  bias_ptr is double[3].
void nuc_ahrs_get_bias(long long h, long long bias_ptr) {
    NAHRS *p = (NAHRS *)(void *)(size_t)h;
    if (!p) return;
    double *b = (double *)(void *)(size_t)bias_ptr;
    if (!b) return;
    b[0] = p->bias[0]; b[1] = p->bias[1]; b[2] = p->bias[2];
}

void nuc_ahrs_free(long long h) {
    NAHRS *p = (NAHRS *)(void *)(size_t)h;
    if (!p) return;
    free(p);
}
