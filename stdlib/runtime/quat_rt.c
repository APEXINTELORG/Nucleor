// quat_rt.c — Unit-quaternion utilities for 3-D rotation.
//
// Quaternions stored as 4 doubles (w, x, y, z) with w as the scalar
// part. All "unit" operations assume |q| = 1; a normalize helper is
// provided to enforce it.
//
// Operations:
//   nuc_quat_from_axis_angle(axis_xyz_ptr, theta, q_out)
//      Build q from a rotation axis (must be normalized) and angle.
//   nuc_quat_to_axis_angle(q_ptr, axis_out, theta_out)
//      Inverse of the above.
//   nuc_quat_mul(a_ptr, b_ptr, out_ptr)
//      Hamilton product q_out = a * b. Equivalent to "rotate by b
//      then by a" when applied to a vector.
//   nuc_quat_normalize(q_ptr_inplace)
//      Normalize q to unit length in place.
//   nuc_quat_slerp(a_ptr, b_ptr, t, out_ptr)
//      Spherical linear interpolation between a and b at t ∈ [0, 1].
//      Picks the shorter arc (handles q vs -q antipodal sign).
//   nuc_quat_rotate_vec(q_ptr, v_xyz_ptr, out_ptr)
//      Apply rotation q to vector v: out = q * v * q⁻¹.
//
// Use:
//   - Robot arm joint orientations.
//   - IMU sensor fusion (Madgwick / Mahony filters).
//   - Smooth orientation interpolation between keyframes.
//   - SLAM pose-graph rotation parameterization.
//
// **Limitations** (rotor / dual-quaternion / quaternion exp+log
// land in v0.6 if needed):
// - Caller responsible for normalizing inputs (slerp tolerates
//   small non-unit drift but won't correct it).
// - No rotation matrix conversion — use the existing rotation
//   helpers in stdlib/rods/rotation.nr if those are needed.
//
// Compile: clang -c stdlib/runtime/quat_rt.c -o target/quat.obj -O2

#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

long long nuc_quat_from_axis_angle(long long axis_ptr, long long theta_b,
                                     long long q_out_ptr)
{
    const double *axis = (const double *)(void *)(size_t)axis_ptr;
    double *q = (double *)(void *)(size_t)q_out_ptr;
    if (!axis || !q) return 0;
    double th = _i2f(theta_b);
    double half = 0.5 * th;
    double s = sin(half);
    q[0] = cos(half);     // w
    q[1] = axis[0] * s;   // x
    q[2] = axis[1] * s;
    q[3] = axis[2] * s;
    return 1;
}

long long nuc_quat_to_axis_angle(long long q_ptr,
                                   long long axis_out_ptr, long long theta_out_ptr)
{
    const double *q = (const double *)(void *)(size_t)q_ptr;
    double *axis = (double *)(void *)(size_t)axis_out_ptr;
    double *theta = (double *)(void *)(size_t)theta_out_ptr;
    if (!q || !axis || !theta) return 0;
    double w = q[0], x = q[1], y = q[2], z = q[3];
    double s = sqrt(x*x + y*y + z*z);
    if (s < 1e-18) {
        // Identity rotation: angle = 0, axis arbitrary (pick +x).
        *theta = 0;
        axis[0] = 1; axis[1] = 0; axis[2] = 0;
        return 1;
    }
    *theta = 2.0 * atan2(s, w);
    axis[0] = x / s;
    axis[1] = y / s;
    axis[2] = z / s;
    return 1;
}

long long nuc_quat_mul(long long a_ptr, long long b_ptr, long long out_ptr)
{
    const double *a = (const double *)(void *)(size_t)a_ptr;
    const double *b = (const double *)(void *)(size_t)b_ptr;
    double *o = (double *)(void *)(size_t)out_ptr;
    if (!a || !b || !o) return 0;
    double aw = a[0], ax = a[1], ay = a[2], az = a[3];
    double bw = b[0], bx = b[1], by = b[2], bz = b[3];
    o[0] = aw*bw - ax*bx - ay*by - az*bz;
    o[1] = aw*bx + ax*bw + ay*bz - az*by;
    o[2] = aw*by - ax*bz + ay*bw + az*bx;
    o[3] = aw*bz + ax*by - ay*bx + az*bw;
    return 1;
}

long long nuc_quat_normalize(long long q_ptr)
{
    double *q = (double *)(void *)(size_t)q_ptr;
    if (!q) return 0;
    double n = sqrt(q[0]*q[0] + q[1]*q[1] + q[2]*q[2] + q[3]*q[3]);
    if (n < 1e-18) {
        q[0] = 1; q[1] = 0; q[2] = 0; q[3] = 0;
        return 0;
    }
    double inv = 1.0 / n;
    q[0] *= inv; q[1] *= inv; q[2] *= inv; q[3] *= inv;
    return 1;
}

long long nuc_quat_slerp(long long a_ptr, long long b_ptr, long long t_b,
                          long long out_ptr)
{
    const double *a = (const double *)(void *)(size_t)a_ptr;
    const double *b = (const double *)(void *)(size_t)b_ptr;
    double *o = (double *)(void *)(size_t)out_ptr;
    if (!a || !b || !o) return 0;
    double t = _i2f(t_b);
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    double bw = b[0], bx = b[1], by = b[2], bz = b[3];
    double dot = a[0]*bw + a[1]*bx + a[2]*by + a[3]*bz;
    // Take shorter arc.
    if (dot < 0) {
        bw = -bw; bx = -bx; by = -by; bz = -bz;
        dot = -dot;
    }
    if (dot > 0.9995) {
        // Very close — fall back to nlerp to avoid div-by-zero in sin(omega).
        o[0] = a[0] + t * (bw - a[0]);
        o[1] = a[1] + t * (bx - a[1]);
        o[2] = a[2] + t * (by - a[2]);
        o[3] = a[3] + t * (bz - a[3]);
        // Normalize.
        double n = sqrt(o[0]*o[0]+o[1]*o[1]+o[2]*o[2]+o[3]*o[3]);
        if (n > 1e-18) { double iv = 1.0/n; o[0]*=iv; o[1]*=iv; o[2]*=iv; o[3]*=iv; }
        return 1;
    }
    double omega = acos(dot);
    double s = sin(omega);
    double k0 = sin((1.0 - t) * omega) / s;
    double k1 = sin(t * omega) / s;
    o[0] = k0 * a[0] + k1 * bw;
    o[1] = k0 * a[1] + k1 * bx;
    o[2] = k0 * a[2] + k1 * by;
    o[3] = k0 * a[3] + k1 * bz;
    return 1;
}

long long nuc_quat_rotate_vec(long long q_ptr, long long v_ptr, long long out_ptr)
{
    const double *q = (const double *)(void *)(size_t)q_ptr;
    const double *v = (const double *)(void *)(size_t)v_ptr;
    double *o = (double *)(void *)(size_t)out_ptr;
    if (!q || !v || !o) return 0;
    // Optimized formula: v' = v + 2 * cross(q.xyz, cross(q.xyz, v) + q.w * v)
    double qw = q[0], qx = q[1], qy = q[2], qz = q[3];
    double vx = v[0], vy = v[1], vz = v[2];
    // t = 2 * cross(qxyz, v)
    double tx = 2.0 * (qy * vz - qz * vy);
    double ty = 2.0 * (qz * vx - qx * vz);
    double tz = 2.0 * (qx * vy - qy * vx);
    // out = v + qw * t + cross(qxyz, t)
    o[0] = vx + qw * tx + (qy * tz - qz * ty);
    o[1] = vy + qw * ty + (qz * tx - qx * tz);
    o[2] = vz + qw * tz + (qx * ty - qy * tx);
    return 1;
}
