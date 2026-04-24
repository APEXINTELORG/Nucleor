// se3_rt.c — Pointer-based SE(3) operations on raw `(t ∈ ℝ³,
// q ∈ S³)` buffers. Complement to `kinematics_rt.c`, which uses
// allocated handles. These functions take pointers directly so
// inner loops (controllers, trajectory composition, frame chains)
// avoid per-call allocation.
//
// Convention: scalar-first quaternions `q = (w, x, y, z)`.
// Hamilton product. A pose `(t, q)` represents the rotation by `q`
// followed by translation by `t` (right-handed: world point of a
// body point `b` is `world = q · b · q⁻¹ + t`).
//
// Exports:
//   - `se3_compose(T1, T2, T_out)` — `T_out = T1 · T2` (apply T2 first)
//   - `se3_inverse(T, T_inv)`
//   - `se3_apply(T, p, p_out)`     — world point of body point p
//   - `se3_relative(T_A, T_B, T_AB)` — `T_AB = T_A⁻¹ · T_B`
//   - `se3_interpolate(T1, T2, α, T_out)` — lerp t, slerp q
//   - `se3_log(T, twist_out)` — SE(3) log → 6-vec `(ρ, ω)`
//   - `se3_exp(twist, T_out)` — SE(3) exp from 6-vec `(ρ, ω)`
//   - `se3_distance(T_A, T_B)` — combined translation + rotation distance
//
// SE(3) log/exp use the standard Lie-algebra parameterization with
// the exact left-Jacobian for the translation part.
//
// **Limitations** (dual quaternions / motor algebra / Plücker
// coordinates land in v0.6 if needed):
// - Translation + quaternion representation only.
// - SE(3) log/exp uses small-angle Taylor for the rotation
//   denominator below 1e-9; otherwise full series.
//
// Compile: clang -c stdlib/runtime/se3_rt.c -o target/se3.obj -O2

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
static void _q_rotate(const double *q, const double *v, double *o) {
    double tx = 2.0*(q[2]*v[2] - q[3]*v[1]);
    double ty = 2.0*(q[3]*v[0] - q[1]*v[2]);
    double tz = 2.0*(q[1]*v[1] - q[2]*v[0]);
    o[0] = v[0] + q[0]*tx + (q[2]*tz - q[3]*ty);
    o[1] = v[1] + q[0]*ty + (q[3]*tx - q[1]*tz);
    o[2] = v[2] + q[0]*tz + (q[1]*ty - q[2]*tx);
}

// === T_out = T1 · T2 (apply T2 first, then T1) ===
//
// A point p in body B is taken to world as:
//   p_world = T1 · (T2 · p) = q1·(q2·p·q2⁻¹ + t2)·q1⁻¹ + t1
// So:
//   q_out = q1 · q2
//   t_out = q1·t2·q1⁻¹ + t1
void nuc_se3_compose(long long t1_ptr, long long q1_ptr,
                      long long t2_ptr, long long q2_ptr,
                      long long t_out_ptr, long long q_out_ptr)
{
    const double *t1 = (const double *)(void *)(size_t)t1_ptr;
    const double *q1 = (const double *)(void *)(size_t)q1_ptr;
    const double *t2 = (const double *)(void *)(size_t)t2_ptr;
    const double *q2 = (const double *)(void *)(size_t)q2_ptr;
    double *to = (double *)(void *)(size_t)t_out_ptr;
    double *qo = (double *)(void *)(size_t)q_out_ptr;
    if (!t1 || !q1 || !t2 || !q2 || !to || !qo) return;
    double t2_rot[3];
    _q_rotate(q1, t2, t2_rot);
    to[0] = t2_rot[0] + t1[0];
    to[1] = t2_rot[1] + t1[1];
    to[2] = t2_rot[2] + t1[2];
    _q_mul(q1, q2, qo);
    _q_normalize(qo);
}

// T_inv: translation = -q⁻¹·t, rotation = q⁻¹.
void nuc_se3_inverse(long long t_ptr, long long q_ptr,
                      long long t_out_ptr, long long q_out_ptr)
{
    const double *t = (const double *)(void *)(size_t)t_ptr;
    const double *q = (const double *)(void *)(size_t)q_ptr;
    double *to = (double *)(void *)(size_t)t_out_ptr;
    double *qo = (double *)(void *)(size_t)q_out_ptr;
    if (!t || !q || !to || !qo) return;
    double q_inv[4]; _q_conj(q, q_inv);
    double neg_t[3] = { -t[0], -t[1], -t[2] };
    _q_rotate(q_inv, neg_t, to);
    qo[0] = q_inv[0]; qo[1] = q_inv[1]; qo[2] = q_inv[2]; qo[3] = q_inv[3];
}

// p_out = T · p = q · p · q⁻¹ + t
void nuc_se3_apply(long long t_ptr, long long q_ptr,
                    long long p_ptr, long long p_out_ptr)
{
    const double *t = (const double *)(void *)(size_t)t_ptr;
    const double *q = (const double *)(void *)(size_t)q_ptr;
    const double *p = (const double *)(void *)(size_t)p_ptr;
    double *po = (double *)(void *)(size_t)p_out_ptr;
    if (!t || !q || !p || !po) return;
    double rot[3];
    _q_rotate(q, p, rot);
    po[0] = rot[0] + t[0];
    po[1] = rot[1] + t[1];
    po[2] = rot[2] + t[2];
}

// T_AB = T_A⁻¹ · T_B (the pose of B in A's frame).
void nuc_se3_relative(long long tA_ptr, long long qA_ptr,
                       long long tB_ptr, long long qB_ptr,
                       long long t_out_ptr, long long q_out_ptr)
{
    double tA_inv[3], qA_inv[4];
    nuc_se3_inverse(tA_ptr, qA_ptr,
                     (long long)(size_t)tA_inv, (long long)(size_t)qA_inv);
    nuc_se3_compose((long long)(size_t)tA_inv, (long long)(size_t)qA_inv,
                     tB_ptr, qB_ptr, t_out_ptr, q_out_ptr);
}

// Linear interpolation of translation, SLERP of rotation.
void nuc_se3_interpolate(long long t1_ptr, long long q1_ptr,
                          long long t2_ptr, long long q2_ptr,
                          long long alpha_b,
                          long long t_out_ptr, long long q_out_ptr)
{
    const double *t1 = (const double *)(void *)(size_t)t1_ptr;
    const double *q1 = (const double *)(void *)(size_t)q1_ptr;
    const double *t2 = (const double *)(void *)(size_t)t2_ptr;
    const double *q2 = (const double *)(void *)(size_t)q2_ptr;
    double *to = (double *)(void *)(size_t)t_out_ptr;
    double *qo = (double *)(void *)(size_t)q_out_ptr;
    if (!t1 || !q1 || !t2 || !q2 || !to || !qo) return;
    double a = _i2f(alpha_b);
    to[0] = (1.0 - a) * t1[0] + a * t2[0];
    to[1] = (1.0 - a) * t1[1] + a * t2[1];
    to[2] = (1.0 - a) * t1[2] + a * t2[2];

    // SLERP (shorter arc).
    double cos_half = q1[0]*q2[0] + q1[1]*q2[1] + q1[2]*q2[2] + q1[3]*q2[3];
    double q2c[4] = { q2[0], q2[1], q2[2], q2[3] };
    if (cos_half < 0) {
        cos_half = -cos_half;
        q2c[0] = -q2c[0]; q2c[1] = -q2c[1]; q2c[2] = -q2c[2]; q2c[3] = -q2c[3];
    }
    if (cos_half > 0.9995) {
        for (int i = 0; i < 4; i++) qo[i] = (1.0 - a) * q1[i] + a * q2c[i];
    } else {
        double half = acos(cos_half);
        double sh = sin(half);
        double w1 = sin((1.0 - a) * half) / sh;
        double w2 = sin(a * half) / sh;
        for (int i = 0; i < 4; i++) qo[i] = w1 * q1[i] + w2 * q2c[i];
    }
    _q_normalize(qo);
}

// SE(3) log: pose → 6-vec twist (ρ, ω) where ω is the rotation
// vector and ρ = V⁻¹ · t with V the SO(3) left-Jacobian.
void nuc_se3_log(long long t_ptr, long long q_ptr, long long twist_out_ptr) {
    const double *t = (const double *)(void *)(size_t)t_ptr;
    const double *q = (const double *)(void *)(size_t)q_ptr;
    double *out = (double *)(void *)(size_t)twist_out_ptr;
    if (!t || !q || !out) return;

    // Compute ω from quaternion.
    double qw = q[0], vx = q[1], vy = q[2], vz = q[3];
    if (qw < 0) { qw = -qw; vx = -vx; vy = -vy; vz = -vz; }
    double vnorm = sqrt(vx*vx + vy*vy + vz*vz);
    double omega[3];
    double theta;
    if (vnorm < 1e-9) {
        theta = 2.0 * vnorm;
        omega[0] = 2.0 * vx;
        omega[1] = 2.0 * vy;
        omega[2] = 2.0 * vz;
    } else {
        theta = 2.0 * atan2(vnorm, qw);
        double k = theta / vnorm;
        omega[0] = vx * k;
        omega[1] = vy * k;
        omega[2] = vz * k;
    }

    // V⁻¹ · t. Standard SE(3) Lie-algebra inverse left-Jacobian.
    // For small θ, V⁻¹ ≈ I (with leading correction). Full form:
    //   V⁻¹ = I − ½·[ω]× + (1/θ²)·(1 − (θ/2)·cot(θ/2))·[ω]×²
    // where [ω]× is the skew.
    double half = 0.5;
    double rho[3];
    if (theta < 1e-6) {
        // V⁻¹ ≈ I − ½[ω]× + (1/12)[ω]×²
        // For tiny θ this is good enough.
        double sk_t[3] = {
            omega[1]*t[2] - omega[2]*t[1],
            omega[2]*t[0] - omega[0]*t[2],
            omega[0]*t[1] - omega[1]*t[0]
        };
        double sk2_t[3] = {
            omega[1]*sk_t[2] - omega[2]*sk_t[1],
            omega[2]*sk_t[0] - omega[0]*sk_t[2],
            omega[0]*sk_t[1] - omega[1]*sk_t[0]
        };
        rho[0] = t[0] - half*sk_t[0] + (1.0/12.0)*sk2_t[0];
        rho[1] = t[1] - half*sk_t[1] + (1.0/12.0)*sk2_t[1];
        rho[2] = t[2] - half*sk_t[2] + (1.0/12.0)*sk2_t[2];
    } else {
        double inv_t2 = 1.0 / (theta * theta);
        double cot_half_theta = cos(theta * 0.5) / sin(theta * 0.5);
        double coef = inv_t2 * (1.0 - 0.5 * theta * cot_half_theta);
        double sk_t[3] = {
            omega[1]*t[2] - omega[2]*t[1],
            omega[2]*t[0] - omega[0]*t[2],
            omega[0]*t[1] - omega[1]*t[0]
        };
        double sk2_t[3] = {
            omega[1]*sk_t[2] - omega[2]*sk_t[1],
            omega[2]*sk_t[0] - omega[0]*sk_t[2],
            omega[0]*sk_t[1] - omega[1]*sk_t[0]
        };
        rho[0] = t[0] - half*sk_t[0] + coef*sk2_t[0];
        rho[1] = t[1] - half*sk_t[1] + coef*sk2_t[1];
        rho[2] = t[2] - half*sk_t[2] + coef*sk2_t[2];
    }
    out[0] = rho[0]; out[1] = rho[1]; out[2] = rho[2];
    out[3] = omega[0]; out[4] = omega[1]; out[5] = omega[2];
}

// SE(3) exp: 6-vec twist (ρ, ω) → pose (t, q).
void nuc_se3_exp(long long twist_ptr, long long t_out_ptr, long long q_out_ptr) {
    const double *tw = (const double *)(void *)(size_t)twist_ptr;
    double *to = (double *)(void *)(size_t)t_out_ptr;
    double *qo = (double *)(void *)(size_t)q_out_ptr;
    if (!tw || !to || !qo) return;
    double rho[3] = { tw[0], tw[1], tw[2] };
    double w[3]   = { tw[3], tw[4], tw[5] };
    double theta = sqrt(w[0]*w[0] + w[1]*w[1] + w[2]*w[2]);

    // Rotation from axis-angle.
    if (theta < 1e-9) {
        qo[0] = 1.0;
        qo[1] = w[0] * 0.5; qo[2] = w[1] * 0.5; qo[3] = w[2] * 0.5;
    } else {
        double half = theta * 0.5;
        double s = sin(half) / theta;
        qo[0] = cos(half);
        qo[1] = w[0] * s; qo[2] = w[1] * s; qo[3] = w[2] * s;
    }
    _q_normalize(qo);

    // Translation: t = V · ρ where V is the SO(3) left-Jacobian.
    // V = I + ((1−cos θ)/θ²)·[ω]× + ((θ−sin θ)/θ³)·[ω]×²
    if (theta < 1e-9) {
        // V ≈ I + ½[ω]× + (1/6)[ω]×² for small θ.
        double sk_r[3] = {
            w[1]*rho[2] - w[2]*rho[1],
            w[2]*rho[0] - w[0]*rho[2],
            w[0]*rho[1] - w[1]*rho[0]
        };
        double sk2_r[3] = {
            w[1]*sk_r[2] - w[2]*sk_r[1],
            w[2]*sk_r[0] - w[0]*sk_r[2],
            w[0]*sk_r[1] - w[1]*sk_r[0]
        };
        to[0] = rho[0] + 0.5*sk_r[0] + (1.0/6.0)*sk2_r[0];
        to[1] = rho[1] + 0.5*sk_r[1] + (1.0/6.0)*sk2_r[1];
        to[2] = rho[2] + 0.5*sk_r[2] + (1.0/6.0)*sk2_r[2];
    } else {
        double sk_r[3] = {
            w[1]*rho[2] - w[2]*rho[1],
            w[2]*rho[0] - w[0]*rho[2],
            w[0]*rho[1] - w[1]*rho[0]
        };
        double sk2_r[3] = {
            w[1]*sk_r[2] - w[2]*sk_r[1],
            w[2]*sk_r[0] - w[0]*sk_r[2],
            w[0]*sk_r[1] - w[1]*sk_r[0]
        };
        double t2 = theta*theta, t3 = t2*theta;
        double a = (1.0 - cos(theta)) / t2;
        double b = (theta - sin(theta)) / t3;
        to[0] = rho[0] + a*sk_r[0] + b*sk2_r[0];
        to[1] = rho[1] + a*sk_r[1] + b*sk2_r[1];
        to[2] = rho[2] + a*sk_r[2] + b*sk2_r[2];
    }
}

// Combined SE(3) distance: ‖t_A − t_B‖ + λ · angular_distance(q_A, q_B)
// with λ = 1 by default. For mixed translation/rotation distances
// see textbook "kinematic distance" definitions.
long long nuc_se3_distance(long long tA_ptr, long long qA_ptr,
                            long long tB_ptr, long long qB_ptr)
{
    const double *tA = (const double *)(void *)(size_t)tA_ptr;
    const double *qA = (const double *)(void *)(size_t)qA_ptr;
    const double *tB = (const double *)(void *)(size_t)tB_ptr;
    const double *qB = (const double *)(void *)(size_t)qB_ptr;
    if (!tA || !qA || !tB || !qB) return _f2i(0.0);
    double dx = tA[0] - tB[0], dy = tA[1] - tB[1], dz = tA[2] - tB[2];
    double dt = sqrt(dx*dx + dy*dy + dz*dz);
    double d = qA[0]*qB[0] + qA[1]*qB[1] + qA[2]*qB[2] + qA[3]*qB[3];
    if (d < 0) d = -d;
    if (d > 1.0) d = 1.0;
    double dr = 2.0 * acos(d);
    return _f2i(dt + dr);
}
