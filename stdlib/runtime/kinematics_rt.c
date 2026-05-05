// kinematics_rt.c — 3D math primitives for robotics.
//
// Vec3, quaternion, and 4×4 pose composition. Per Nucleor's i64
// FFI convention, every f64 crosses the boundary as i64-bit-cast
// (caller and callee agree on the encoding). Vec3s and poses
// allocate flat malloc'd arrays whose handles are i64-as-ptr.
//
// Reference frame tagging is NOT enforced at the C level — it
// lives in the Nucleor wrapper (`stdlib/rods/kinematics.nr`) as
// an i64 frame tag stored alongside each pose. RFC-0003 lifts
// this to compile-time generic frames once Nucleor has generics
// (v0.4 RFC-0024 dependency).
//
// All functions return new heap-allocated results; caller is
// responsible for `nuc_kine_free` when done with a value.
//
// Compile: clang -c stdlib/runtime/kinematics_rt.c -o target/kine.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// === Vec3 (3 doubles, flat-malloc'd) =====================================

static double *_vec3_alloc(double x, double y, double z) {
    double *v = (double *)malloc(3 * sizeof(double));
    v[0] = x; v[1] = y; v[2] = z;
    return v;
}

long long nuc_vec3_new(long long x_bits, long long y_bits, long long z_bits) {
    return (long long)(size_t)_vec3_alloc(_i2f(x_bits), _i2f(y_bits), _i2f(z_bits));
}

long long nuc_vec3_get_x(long long h) { double *v = (double *)(void *)(size_t)h; return _f2i(v[0]); }
long long nuc_vec3_get_y(long long h) { double *v = (double *)(void *)(size_t)h; return _f2i(v[1]); }
long long nuc_vec3_get_z(long long h) { double *v = (double *)(void *)(size_t)h; return _f2i(v[2]); }

long long nuc_vec3_dot(long long ah, long long bh) {
    double *a = (double *)(void *)(size_t)ah;
    double *b = (double *)(void *)(size_t)bh;
    return _f2i(a[0]*b[0] + a[1]*b[1] + a[2]*b[2]);
}

long long nuc_vec3_cross(long long ah, long long bh) {
    double *a = (double *)(void *)(size_t)ah;
    double *b = (double *)(void *)(size_t)bh;
    return (long long)(size_t)_vec3_alloc(
        a[1]*b[2] - a[2]*b[1],
        a[2]*b[0] - a[0]*b[2],
        a[0]*b[1] - a[1]*b[0]
    );
}

long long nuc_vec3_norm(long long h) {
    double *v = (double *)(void *)(size_t)h;
    return _f2i(sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]));
}

long long nuc_vec3_add(long long ah, long long bh) {
    double *a = (double *)(void *)(size_t)ah;
    double *b = (double *)(void *)(size_t)bh;
    return (long long)(size_t)_vec3_alloc(a[0]+b[0], a[1]+b[1], a[2]+b[2]);
}

long long nuc_vec3_scale(long long ah, long long s_bits) {
    double *a = (double *)(void *)(size_t)ah;
    double s = _i2f(s_bits);
    return (long long)(size_t)_vec3_alloc(a[0]*s, a[1]*s, a[2]*s);
}

void nuc_vec3_free(long long h) {
    double *v = (double *)(void *)(size_t)h;
    if (v) free(v);
}

// === Quaternion (w, x, y, z) =============================================

static double *_quat_alloc(double w, double x, double y, double z) {
    double *q = (double *)malloc(4 * sizeof(double));
    q[0] = w; q[1] = x; q[2] = y; q[3] = z;
    return q;
}

long long nuc_quat_new(long long w_bits, long long x_bits, long long y_bits, long long z_bits) {
    return (long long)(size_t)_quat_alloc(_i2f(w_bits), _i2f(x_bits), _i2f(y_bits), _i2f(z_bits));
}

long long nuc_quat_identity(void) {
    return (long long)(size_t)_quat_alloc(1.0, 0.0, 0.0, 0.0);
}

// Build a quaternion from an axis (unit Vec3) and an angle (radians).
//
// Pre-v0.8.260 named `nuc_quat_from_axis_angle` — collided with
// `quat_rt.c::nuc_quat_from_axis_angle` (3-arg, raw-pointer API).
// Renamed to `nuc_kin_quat_from_axis_angle` per the kinematics rod's
// `nuc_kin_*` namespace.
long long nuc_kin_quat_from_axis_angle(long long axis_h, long long angle_bits) {
    double *a = (double *)(void *)(size_t)axis_h;
    double angle = _i2f(angle_bits);
    double half = angle * 0.5;
    double s = sin(half);
    double c = cos(half);
    return (long long)(size_t)_quat_alloc(c, a[0]*s, a[1]*s, a[2]*s);
}

long long nuc_quat_get_w(long long h) { double *q = (double *)(void *)(size_t)h; return _f2i(q[0]); }
long long nuc_quat_get_x(long long h) { double *q = (double *)(void *)(size_t)h; return _f2i(q[1]); }
long long nuc_quat_get_y(long long h) { double *q = (double *)(void *)(size_t)h; return _f2i(q[2]); }
long long nuc_quat_get_z(long long h) { double *q = (double *)(void *)(size_t)h; return _f2i(q[3]); }

// Hamilton product q1 * q2.
//
// Pre-v0.8.260 named `nuc_quat_mul` — collided with
// `quat_rt.c::nuc_quat_mul` (3-arg, raw-pointer API).
// Renamed to `nuc_kin_quat_mul` per the kinematics rod's namespace.
long long nuc_kin_quat_mul(long long ah, long long bh) {
    double *a = (double *)(void *)(size_t)ah;
    double *b = (double *)(void *)(size_t)bh;
    double w = a[0]*b[0] - a[1]*b[1] - a[2]*b[2] - a[3]*b[3];
    double x = a[0]*b[1] + a[1]*b[0] + a[2]*b[3] - a[3]*b[2];
    double y = a[0]*b[2] - a[1]*b[3] + a[2]*b[0] + a[3]*b[1];
    double z = a[0]*b[3] + a[1]*b[2] - a[2]*b[1] + a[3]*b[0];
    return (long long)(size_t)_quat_alloc(w, x, y, z);
}

// Conjugate (inverse for unit quaternions).
long long nuc_quat_conjugate(long long h) {
    double *q = (double *)(void *)(size_t)h;
    return (long long)(size_t)_quat_alloc(q[0], -q[1], -q[2], -q[3]);
}

// Rotate a Vec3 by a unit quaternion: v' = q * v * q^-1.
long long nuc_quat_rotate(long long qh, long long vh) {
    double *q = (double *)(void *)(size_t)qh;
    double *v = (double *)(void *)(size_t)vh;
    // Treat v as pure quaternion (0, v.x, v.y, v.z).
    double w = q[0], qx = q[1], qy = q[2], qz = q[3];
    // r = q * v
    double rw = -qx*v[0] - qy*v[1] - qz*v[2];
    double rx =  w*v[0] + qy*v[2] - qz*v[1];
    double ry =  w*v[1] - qx*v[2] + qz*v[0];
    double rz =  w*v[2] + qx*v[1] - qy*v[0];
    // out = r * q^-1
    double ox = rw*(-qx) + rx*w + ry*(-qz) - rz*(-qy);
    double oy = rw*(-qy) - rx*(-qz) + ry*w + rz*(-qx);
    double oz = rw*(-qz) + rx*(-qy) - ry*(-qx) + rz*w;
    return (long long)(size_t)_vec3_alloc(ox, oy, oz);
}

void nuc_quat_free(long long h) {
    double *q = (double *)(void *)(size_t)h;
    if (q) free(q);
}

// === Pose (position Vec3 + orientation quaternion) =======================

typedef struct { double pos[3]; double quat[4]; } NPose;

long long nuc_pose_new(long long pos_h, long long quat_h) {
    double *p = (double *)(void *)(size_t)pos_h;
    double *q = (double *)(void *)(size_t)quat_h;
    NPose *out = (NPose *)malloc(sizeof(NPose));
    out->pos[0] = p[0]; out->pos[1] = p[1]; out->pos[2] = p[2];
    out->quat[0] = q[0]; out->quat[1] = q[1]; out->quat[2] = q[2]; out->quat[3] = q[3];
    return (long long)(size_t)out;
}

long long nuc_pose_identity(void) {
    NPose *out = (NPose *)malloc(sizeof(NPose));
    out->pos[0] = 0; out->pos[1] = 0; out->pos[2] = 0;
    out->quat[0] = 1; out->quat[1] = 0; out->quat[2] = 0; out->quat[3] = 0;
    return (long long)(size_t)out;
}

long long nuc_pose_get_pos(long long h) {
    NPose *p = (NPose *)(void *)(size_t)h;
    return (long long)(size_t)_vec3_alloc(p->pos[0], p->pos[1], p->pos[2]);
}

long long nuc_pose_get_quat(long long h) {
    NPose *p = (NPose *)(void *)(size_t)h;
    return (long long)(size_t)_quat_alloc(p->quat[0], p->quat[1], p->quat[2], p->quat[3]);
}

// Compose: out = a then b (interpret as: apply a in world, then apply b
// in a's local frame). Position and orientation both compose.
long long nuc_pose_compose(long long ah, long long bh) {
    NPose *a = (NPose *)(void *)(size_t)ah;
    NPose *b = (NPose *)(void *)(size_t)bh;
    // out.quat = a.quat * b.quat
    double *aq = a->quat; double *bq = b->quat;
    double w = aq[0]*bq[0] - aq[1]*bq[1] - aq[2]*bq[2] - aq[3]*bq[3];
    double x = aq[0]*bq[1] + aq[1]*bq[0] + aq[2]*bq[3] - aq[3]*bq[2];
    double y = aq[0]*bq[2] - aq[1]*bq[3] + aq[2]*bq[0] + aq[3]*bq[1];
    double z = aq[0]*bq[3] + aq[1]*bq[2] - aq[2]*bq[1] + aq[3]*bq[0];
    // out.pos = a.pos + a.quat.rotate(b.pos)
    double bp[3] = { b->pos[0], b->pos[1], b->pos[2] };
    double qw = aq[0], qx = aq[1], qy = aq[2], qz = aq[3];
    double rw = -qx*bp[0] - qy*bp[1] - qz*bp[2];
    double rx =  qw*bp[0] + qy*bp[2] - qz*bp[1];
    double ry =  qw*bp[1] - qx*bp[2] + qz*bp[0];
    double rz =  qw*bp[2] + qx*bp[1] - qy*bp[0];
    double ox = rw*(-qx) + rx*qw + ry*(-qz) - rz*(-qy);
    double oy = rw*(-qy) - rx*(-qz) + ry*qw + rz*(-qx);
    double oz = rw*(-qz) + rx*(-qy) - ry*(-qx) + rz*qw;
    NPose *out = (NPose *)malloc(sizeof(NPose));
    out->pos[0] = a->pos[0] + ox;
    out->pos[1] = a->pos[1] + oy;
    out->pos[2] = a->pos[2] + oz;
    out->quat[0] = w; out->quat[1] = x; out->quat[2] = y; out->quat[3] = z;
    return (long long)(size_t)out;
}

// Inverse: assumes unit quaternion.
long long nuc_pose_inverse(long long h) {
    NPose *p = (NPose *)(void *)(size_t)h;
    double qw = p->quat[0], qx = -p->quat[1], qy = -p->quat[2], qz = -p->quat[3];
    // out.pos = -(q^-1 * p.pos)
    double bp[3] = { p->pos[0], p->pos[1], p->pos[2] };
    double rw = -qx*bp[0] - qy*bp[1] - qz*bp[2];
    double rx =  qw*bp[0] + qy*bp[2] - qz*bp[1];
    double ry =  qw*bp[1] - qx*bp[2] + qz*bp[0];
    double rz =  qw*bp[2] + qx*bp[1] - qy*bp[0];
    double ox = rw*(-qx) + rx*qw + ry*(-qz) - rz*(-qy);
    double oy = rw*(-qy) - rx*(-qz) + ry*qw + rz*(-qx);
    double oz = rw*(-qz) + rx*(-qy) - ry*(-qx) + rz*qw;
    NPose *out = (NPose *)malloc(sizeof(NPose));
    out->pos[0] = -ox; out->pos[1] = -oy; out->pos[2] = -oz;
    out->quat[0] = qw; out->quat[1] = qx; out->quat[2] = qy; out->quat[3] = qz;
    return (long long)(size_t)out;
}

// Apply a pose to a Vec3: result = pose.quat.rotate(v) + pose.pos.
long long nuc_pose_apply(long long ph, long long vh) {
    NPose *p = (NPose *)(void *)(size_t)ph;
    double *v = (double *)(void *)(size_t)vh;
    double qw = p->quat[0], qx = p->quat[1], qy = p->quat[2], qz = p->quat[3];
    double rw = -qx*v[0] - qy*v[1] - qz*v[2];
    double rx =  qw*v[0] + qy*v[2] - qz*v[1];
    double ry =  qw*v[1] - qx*v[2] + qz*v[0];
    double rz =  qw*v[2] + qx*v[1] - qy*v[0];
    double ox = rw*(-qx) + rx*qw + ry*(-qz) - rz*(-qy);
    double oy = rw*(-qy) - rx*(-qz) + ry*qw + rz*(-qx);
    double oz = rw*(-qz) + rx*(-qy) - ry*(-qx) + rz*qw;
    return (long long)(size_t)_vec3_alloc(ox + p->pos[0], oy + p->pos[1], oz + p->pos[2]);
}

void nuc_pose_free(long long h) {
    NPose *p = (NPose *)(void *)(size_t)h;
    if (p) free(p);
}
