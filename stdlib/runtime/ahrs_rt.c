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

// One IMU step. gyro_ptr is double[3] (rad/s body frame), accel_ptr
// is double[3] (gravity vector in body frame; will be normalized).
// dt_b is timestep in seconds.
void nuc_ahrs_update(long long h, long long gyro_ptr, long long accel_ptr, long long dt_b) {
    NAHRS *p = (NAHRS *)(void *)(size_t)h;
    if (!p) return;
    double *g = (double *)(void *)(size_t)gyro_ptr;
    double *a = (double *)(void *)(size_t)accel_ptr;
    double dt = _i2f(dt_b);
    if (!g || dt <= 0) return;

    double wx = g[0], wy = g[1], wz = g[2];

    // Accel correction (skip if accel reading is degenerate).
    if (a) {
        double an = sqrt(a[0]*a[0] + a[1]*a[1] + a[2]*a[2]);
        if (an > 1e-9) {
            double ax = a[0]/an, ay = a[1]/an, az = a[2]/an;
            // Predicted gravity in body frame = q^T · (0, 0, 1).
            // For body-to-world quaternion q, world vector v in body frame is
            //   v_body = q* · (0, v) · q.
            // Compact form for v = (0, 0, 1):
            double qw = p->q[0], qx = p->q[1], qy = p->q[2], qz = p->q[3];
            double gx = 2.0 * (qx*qz - qw*qy);
            double gy = 2.0 * (qw*qx + qy*qz);
            double gz = qw*qw - qx*qx - qy*qy + qz*qz;
            // Error = predicted × measured  (axis to rotate predicted into measured).
            double ex = gy*az - gz*ay;
            double ey = gz*ax - gx*az;
            double ez = gx*ay - gy*ax;
            // Integrate gyro bias (Ki).
            if (p->Ki > 0) {
                p->bias[0] += p->Ki * ex * dt;
                p->bias[1] += p->Ki * ey * dt;
                p->bias[2] += p->Ki * ez * dt;
            }
            // Apply PI correction.
            wx += p->Kp * ex + p->bias[0];
            wy += p->Kp * ey + p->bias[1];
            wz += p->Kp * ez + p->bias[2];
        }
    }

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
