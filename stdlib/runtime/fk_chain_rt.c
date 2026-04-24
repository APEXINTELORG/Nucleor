// fk_chain_rt.c — Forward kinematics for a serial joint chain.
//
// Encapsulates a list of joints, each with a fixed parent-to-child
// pose offset and a joint-axis (revolute or prismatic). Given the
// joint variable values, computes the world-frame pose of every
// link via cumulative pose composition.
//
// Companion to `kinematics_rt.c` (Vec3, quaternion, Pose
// primitives). RFC-0013 (URDF static frame chain verification)
// uses this runtime as the compute target; the URDF parser +
// frame-chain check land in v0.5.
//
// Compile: clang -c stdlib/runtime/fk_chain_rt.c -o target/fk_chain.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

#define FK_REVOLUTE  0
#define FK_PRISMATIC 1
#define FK_FIXED     2

typedef struct {
    int joint_type;       // FK_REVOLUTE | FK_PRISMATIC | FK_FIXED
    double offset_pos[3]; // parent-to-child base offset
    double offset_quat[4]; // parent-to-child base orientation
    double axis[3];       // joint axis (in joint-local frame)
} FKJoint;

typedef struct {
    FKJoint *joints;
    int count;
    int capacity;
    double *world_pos;    // 3 doubles per joint, computed at update
    double *world_quat;   // 4 doubles per joint, computed at update
} FKChain;

static void _q_normalize(double *q) {
    double n = sqrt(q[0]*q[0] + q[1]*q[1] + q[2]*q[2] + q[3]*q[3]);
    if (n == 0.0) { q[0] = 1; q[1] = 0; q[2] = 0; q[3] = 0; return; }
    q[0] /= n; q[1] /= n; q[2] /= n; q[3] /= n;
}

static void _q_mul(const double *a, const double *b, double *out) {
    out[0] = a[0]*b[0] - a[1]*b[1] - a[2]*b[2] - a[3]*b[3];
    out[1] = a[0]*b[1] + a[1]*b[0] + a[2]*b[3] - a[3]*b[2];
    out[2] = a[0]*b[2] - a[1]*b[3] + a[2]*b[0] + a[3]*b[1];
    out[3] = a[0]*b[3] + a[1]*b[2] - a[2]*b[1] + a[3]*b[0];
}

static void _q_rot_v(const double *q, const double *v, double *out) {
    double rw = -q[1]*v[0] - q[2]*v[1] - q[3]*v[2];
    double rx =  q[0]*v[0] + q[2]*v[2] - q[3]*v[1];
    double ry =  q[0]*v[1] - q[1]*v[2] + q[3]*v[0];
    double rz =  q[0]*v[2] + q[1]*v[1] - q[2]*v[0];
    out[0] = rw*(-q[1]) + rx*q[0] + ry*(-q[3]) - rz*(-q[2]);
    out[1] = rw*(-q[2]) - rx*(-q[3]) + ry*q[0] + rz*(-q[1]);
    out[2] = rw*(-q[3]) + rx*(-q[2]) - ry*(-q[1]) + rz*q[0];
}

long long nuc_fk_chain_new(void) {
    FKChain *c = (FKChain *)malloc(sizeof(FKChain));
    c->joints = NULL;
    c->count = 0;
    c->capacity = 0;
    c->world_pos = NULL;
    c->world_quat = NULL;
    return (long long)(size_t)c;
}

// Add a joint. axis[xyz] are doubles (i64-bit-cast). offset_pos and
// offset_quat each take three / four bit-cast doubles. joint_type:
// 0 = revolute, 1 = prismatic, 2 = fixed.
long long nuc_fk_chain_add_joint(
    long long ch,
    long long joint_type,
    long long off_x_bits, long long off_y_bits, long long off_z_bits,
    long long off_qw_bits, long long off_qx_bits, long long off_qy_bits, long long off_qz_bits,
    long long axis_x_bits, long long axis_y_bits, long long axis_z_bits)
{
    FKChain *c = (FKChain *)(void *)(size_t)ch;
    if (!c) return -1;
    if (c->count >= c->capacity) {
        c->capacity = c->capacity == 0 ? 8 : c->capacity * 2;
        c->joints = (FKJoint *)realloc(c->joints, c->capacity * sizeof(FKJoint));
        c->world_pos = (double *)realloc(c->world_pos, c->capacity * 3 * sizeof(double));
        c->world_quat = (double *)realloc(c->world_quat, c->capacity * 4 * sizeof(double));
    }
    FKJoint *j = &c->joints[c->count];
    j->joint_type = (int)joint_type;
    j->offset_pos[0] = _i2f(off_x_bits);
    j->offset_pos[1] = _i2f(off_y_bits);
    j->offset_pos[2] = _i2f(off_z_bits);
    j->offset_quat[0] = _i2f(off_qw_bits);
    j->offset_quat[1] = _i2f(off_qx_bits);
    j->offset_quat[2] = _i2f(off_qy_bits);
    j->offset_quat[3] = _i2f(off_qz_bits);
    _q_normalize(j->offset_quat);
    j->axis[0] = _i2f(axis_x_bits);
    j->axis[1] = _i2f(axis_y_bits);
    j->axis[2] = _i2f(axis_z_bits);
    return (long long)(c->count++);
}

long long nuc_fk_chain_count(long long ch) {
    FKChain *c = (FKChain *)(void *)(size_t)ch;
    return (long long)c->count;
}

// Compute world-frame poses given a flat array of joint variables.
// `vars_ptr` is a malloc'd double[count] (caller passes its handle).
// FIXED joints ignore the corresponding variable (caller can pass 0).
// Returns 0 on success, -1 on null/empty chain.
long long nuc_fk_chain_update(long long ch, long long vars_ptr) {
    FKChain *c = (FKChain *)(void *)(size_t)ch;
    if (!c || c->count == 0) return -1;
    double *vars = (double *)(void *)(size_t)vars_ptr;
    double cur_pos[3] = {0, 0, 0};
    double cur_quat[4] = {1, 0, 0, 0};
    for (int i = 0; i < c->count; i++) {
        FKJoint *j = &c->joints[i];
        // Joint-local rotation/translation from the variable.
        double j_pos[3] = {0, 0, 0};
        double j_quat[4] = {1, 0, 0, 0};
        double v = vars[i];
        if (j->joint_type == FK_REVOLUTE) {
            double half = v * 0.5;
            double s = sin(half);
            double cc = cos(half);
            j_quat[0] = cc;
            j_quat[1] = j->axis[0] * s;
            j_quat[2] = j->axis[1] * s;
            j_quat[3] = j->axis[2] * s;
        } else if (j->joint_type == FK_PRISMATIC) {
            j_pos[0] = j->axis[0] * v;
            j_pos[1] = j->axis[1] * v;
            j_pos[2] = j->axis[2] * v;
        }
        // Compose: cur = cur ∘ offset ∘ joint_local
        // Step 1: cur_after_off = cur ∘ offset
        double off_pos_world[3];
        _q_rot_v(cur_quat, j->offset_pos, off_pos_world);
        double new_pos[3] = {
            cur_pos[0] + off_pos_world[0],
            cur_pos[1] + off_pos_world[1],
            cur_pos[2] + off_pos_world[2]
        };
        double new_quat[4];
        _q_mul(cur_quat, j->offset_quat, new_quat);
        // Step 2: now apply the joint-local motion.
        double joint_pos_world[3];
        _q_rot_v(new_quat, j_pos, joint_pos_world);
        new_pos[0] += joint_pos_world[0];
        new_pos[1] += joint_pos_world[1];
        new_pos[2] += joint_pos_world[2];
        double final_quat[4];
        _q_mul(new_quat, j_quat, final_quat);
        cur_pos[0] = new_pos[0]; cur_pos[1] = new_pos[1]; cur_pos[2] = new_pos[2];
        cur_quat[0] = final_quat[0]; cur_quat[1] = final_quat[1];
        cur_quat[2] = final_quat[2]; cur_quat[3] = final_quat[3];
        // Cache.
        c->world_pos[i*3 + 0] = cur_pos[0];
        c->world_pos[i*3 + 1] = cur_pos[1];
        c->world_pos[i*3 + 2] = cur_pos[2];
        c->world_quat[i*4 + 0] = cur_quat[0];
        c->world_quat[i*4 + 1] = cur_quat[1];
        c->world_quat[i*4 + 2] = cur_quat[2];
        c->world_quat[i*4 + 3] = cur_quat[3];
    }
    return 0;
}

// Read out a single link's world-frame pose component. After
// nuc_fk_chain_update has been called, returns the world position
// or quaternion components for the i-th link (0-indexed).
long long nuc_fk_chain_link_pos_x(long long ch, long long i) {
    FKChain *c = (FKChain *)(void *)(size_t)ch;
    if (!c || i < 0 || i >= c->count) return 0;
    return _f2i(c->world_pos[i*3 + 0]);
}
long long nuc_fk_chain_link_pos_y(long long ch, long long i) {
    FKChain *c = (FKChain *)(void *)(size_t)ch;
    if (!c || i < 0 || i >= c->count) return 0;
    return _f2i(c->world_pos[i*3 + 1]);
}
long long nuc_fk_chain_link_pos_z(long long ch, long long i) {
    FKChain *c = (FKChain *)(void *)(size_t)ch;
    if (!c || i < 0 || i >= c->count) return 0;
    return _f2i(c->world_pos[i*3 + 2]);
}
long long nuc_fk_chain_link_quat_w(long long ch, long long i) {
    FKChain *c = (FKChain *)(void *)(size_t)ch;
    if (!c || i < 0 || i >= c->count) return 0;
    return _f2i(c->world_quat[i*4 + 0]);
}

void nuc_fk_chain_free(long long ch) {
    FKChain *c = (FKChain *)(void *)(size_t)ch;
    if (!c) return;
    if (c->joints) free(c->joints);
    if (c->world_pos) free(c->world_pos);
    if (c->world_quat) free(c->world_quat);
    free(c);
}

// Add a joint described by Denavit-Hartenberg parameters (modified
// DH convention as taught in Spong's Robot Modeling and Control).
//   alpha — twist angle about previous x (rad)
//   a     — link length along previous x (m)
//   d     — link offset along previous z (m)
//   theta — joint angle about previous z (rad); for revolute joints
//           this is the variable, but we store the value here as the
//           STATIC offset (the joint variable adds to this at FK time)
//
// Returns the joint slot index (0-based), -1 on null chain.
//
// The DH transform is:
//   T = Rot_x(alpha) · Trans_x(a) · Trans_z(d) · Rot_z(theta)
// We split into a base offset pose (with theta=0) and the
// joint variable, encoded as a revolute joint about z.
long long nuc_fk_chain_add_dh_joint(
    long long ch,
    long long alpha_bits, long long a_bits,
    long long d_bits,     long long theta_bits)
{
    FKChain *c = (FKChain *)(void *)(size_t)ch;
    if (!c) return -1;
    double alpha = _i2f(alpha_bits);
    double a = _i2f(a_bits);
    double d = _i2f(d_bits);
    double theta = _i2f(theta_bits);
    // Compose T = Rot_x(alpha) · Trans_x(a) · Trans_z(d) · Rot_z(theta).
    // The base pose stored in the joint is everything EXCEPT the
    // joint variable's contribution.
    // Rotation: Rot_x(alpha) · Rot_z(theta). As a quaternion:
    double half_a = alpha * 0.5;
    double half_t = theta * 0.5;
    double qa_w = cos(half_a), qa_x = sin(half_a), qa_y = 0, qa_z = 0;
    double qt_w = cos(half_t), qt_x = 0, qt_y = 0, qt_z = sin(half_t);
    // q = qa * qt
    double qw = qa_w*qt_w - qa_x*qt_x - qa_y*qt_y - qa_z*qt_z;
    double qx = qa_w*qt_x + qa_x*qt_w + qa_y*qt_z - qa_z*qt_y;
    double qy = qa_w*qt_y - qa_x*qt_z + qa_y*qt_w + qa_z*qt_x;
    double qz = qa_w*qt_z + qa_x*qt_y - qa_y*qt_x + qa_z*qt_w;
    // Translation: Rot_x(alpha) applied to (a, 0, d) plus 0.
    // Rot_x(alpha): y'=cos(α)y - sin(α)z, z'=sin(α)y + cos(α)z.
    double ca = cos(alpha), sa = sin(alpha);
    double off_x = a;
    double off_y = -sa * d;
    double off_z =  ca * d;
    // Forward to add_joint with joint type = revolute and axis = z.
    return nuc_fk_chain_add_joint(ch, FK_REVOLUTE,
        _f2i(off_x), _f2i(off_y), _f2i(off_z),
        _f2i(qw), _f2i(qx), _f2i(qy), _f2i(qz),
        _f2i(0.0), _f2i(0.0), _f2i(1.0));
}
