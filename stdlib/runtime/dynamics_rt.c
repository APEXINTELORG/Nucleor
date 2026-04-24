// dynamics_rt.c — Robot inverse dynamics via the Recursive Newton-
// Euler Algorithm (RNEA, Luh-Walker-Paul 1980).
//
// Given joint positions q, velocities qd, and accelerations qdd,
// computes the joint torques tau required to produce that motion
// against gravity. Standard equation:
//
//     tau = M(q)·qdd + C(q, qd)·qd + g(q)
//
// where M is the mass matrix, C the Coriolis/centrifugal terms,
// and g(q) the gravity-induced torques. RNEA computes tau directly
// in O(n) without explicitly forming M or C — much faster than the
// equation-of-motion form for small-to-medium chains.
//
// Two convenience entry points:
//
//   nuc_dyn_inverse(q, qd, qdd)  → tau         full RNEA
//   nuc_dyn_gravity(q)            → tau_grav   qd = qdd = 0 case
//
// The second is useful for gravity compensation (cancel g(q) so
// the user only commands desired-motion torques).
//
// **Limitations** (full Featherstone spatial-vector formulation
// lands in v0.6 if needed for big chains or deep recursion):
// - Serial chain only (no branching trees — same restriction as
//   the URDF parser).
// - Revolute and prismatic joints only (consistent with FK chain).
// - Inertia tensors must be expressed in the link's body-fixed
//   frame at the link's center of mass.
//
// See `stdlib/rods/dynamics.nr`.
//
// Compile: clang -c stdlib/runtime/dynamics_rt.c -o target/dyn.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// FK joint type constants — must match fk_chain_rt.c.
#define _DYN_REVOLUTE  0
#define _DYN_PRISMATIC 1
#define _DYN_FIXED     2

// Forward-declare the FK runtime symbols we read from.
long long nuc_fk_chain_count(long long ch);
long long nuc_fk_chain_update(long long ch, long long vars_ptr);
long long nuc_fk_chain_link_pos_x(long long ch, long long i);
long long nuc_fk_chain_link_pos_y(long long ch, long long i);
long long nuc_fk_chain_link_pos_z(long long ch, long long i);
long long nuc_fk_chain_link_quat_w(long long ch, long long i);
long long nuc_fk_chain_link_quat_x(long long ch, long long i);
long long nuc_fk_chain_link_quat_y(long long ch, long long i);
long long nuc_fk_chain_link_quat_z(long long ch, long long i);
// Internal accessors needed by RNEA — we need the joint-axis
// vector per joint and the joint type. These read from the same
// FKJoint struct fk_chain_rt.c uses; we forward-declare them here
// and provide a thin extern in fk_chain_rt.c (added in v0.2.207
// via `nuc_fk_chain_joint_type` / `nuc_fk_chain_joint_axis`).
long long nuc_fk_chain_joint_type(long long ch, long long i);
long long nuc_fk_chain_joint_axis(long long ch, long long i, long long dim);

typedef struct {
    int n_links;
    int cap_links;
    long long fk_handle;     // bound FK chain
    double *mass;            // n_links
    double *com;             // n_links × 3 (in link-local frame, at the CoM)
    double *inertia;         // n_links × 6 (Ixx, Iyy, Izz, Ixy, Ixz, Iyz, body-frame at CoM)
    double gravity[3];       // world-frame gravity (default 0, 0, -9.81)
} NDyn;

// === Quaternion helpers (link rotation handling) ===

static void _q_rot_vec(double qw, double qx, double qy, double qz,
                       const double *v, double *out)
{
    // out = q * v * q^-1, expressed via the cross-product form:
    // out = v + 2*qw*(q_xyz × v) + 2*(q_xyz × (q_xyz × v))
    double tx = 2*(qy*v[2] - qz*v[1]);
    double ty = 2*(qz*v[0] - qx*v[2]);
    double tz = 2*(qx*v[1] - qy*v[0]);
    out[0] = v[0] + qw*tx + (qy*tz - qz*ty);
    out[1] = v[1] + qw*ty + (qz*tx - qx*tz);
    out[2] = v[2] + qw*tz + (qx*ty - qy*tx);
}

static void _vsub(const double *a, const double *b, double *out) {
    out[0] = a[0] - b[0]; out[1] = a[1] - b[1]; out[2] = a[2] - b[2];
}
static void _vadd(const double *a, const double *b, double *out) {
    out[0] = a[0] + b[0]; out[1] = a[1] + b[1]; out[2] = a[2] + b[2];
}
static void _vcross(const double *a, const double *b, double *out) {
    out[0] = a[1]*b[2] - a[2]*b[1];
    out[1] = a[2]*b[0] - a[0]*b[2];
    out[2] = a[0]*b[1] - a[1]*b[0];
}
static double _vdot(const double *a, const double *b) {
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
}
static void _vscale(const double *a, double s, double *out) {
    out[0] = a[0]*s; out[1] = a[1]*s; out[2] = a[2]*s;
}
static void _vinit(double *v, double a, double b, double c) {
    v[0] = a; v[1] = b; v[2] = c;
}

// Multiply 3×3 inertia tensor (stored as upper triangle: Ixx, Iyy, Izz, Ixy, Ixz, Iyz)
// by a 3-vector, in the body frame.
static void _inertia_mul(const double *I6, const double *w, double *out) {
    double Ixx = I6[0], Iyy = I6[1], Izz = I6[2];
    double Ixy = I6[3], Ixz = I6[4], Iyz = I6[5];
    out[0] = Ixx*w[0] + Ixy*w[1] + Ixz*w[2];
    out[1] = Ixy*w[0] + Iyy*w[1] + Iyz*w[2];
    out[2] = Ixz*w[0] + Iyz*w[1] + Izz*w[2];
}

// === Rod surface ===

long long nuc_dyn_new(long long fk_handle) {
    int n = (int)nuc_fk_chain_count(fk_handle);
    if (n <= 0) return 0;
    NDyn *d = (NDyn *)calloc(1, sizeof(NDyn));
    d->n_links = n;
    d->cap_links = n;
    d->fk_handle = fk_handle;
    d->mass    = (double *)calloc(n, sizeof(double));
    d->com     = (double *)calloc(n * 3, sizeof(double));
    d->inertia = (double *)calloc(n * 6, sizeof(double));
    // Sensible defaults — unit mass at link origin, unit inertia.
    for (int i = 0; i < n; i++) {
        d->mass[i] = 1.0;
        d->inertia[i*6 + 0] = 0.01;  // Ixx
        d->inertia[i*6 + 1] = 0.01;  // Iyy
        d->inertia[i*6 + 2] = 0.01;  // Izz
    }
    d->gravity[0] = 0.0;
    d->gravity[1] = 0.0;
    d->gravity[2] = -9.81;
    return (long long)(size_t)d;
}

void nuc_dyn_set_link_mass(long long h, long long i, long long mass_b) {
    NDyn *d = (NDyn *)(void *)(size_t)h;
    if (!d || i < 0 || i >= (long long)d->n_links) return;
    d->mass[i] = _i2f(mass_b);
}

void nuc_dyn_set_link_com(long long h, long long i,
                          long long cx_b, long long cy_b, long long cz_b)
{
    NDyn *d = (NDyn *)(void *)(size_t)h;
    if (!d || i < 0 || i >= (long long)d->n_links) return;
    d->com[i*3 + 0] = _i2f(cx_b);
    d->com[i*3 + 1] = _i2f(cy_b);
    d->com[i*3 + 2] = _i2f(cz_b);
}

void nuc_dyn_set_link_inertia(long long h, long long i,
                              long long ixx_b, long long iyy_b, long long izz_b,
                              long long ixy_b, long long ixz_b, long long iyz_b)
{
    NDyn *d = (NDyn *)(void *)(size_t)h;
    if (!d || i < 0 || i >= (long long)d->n_links) return;
    d->inertia[i*6 + 0] = _i2f(ixx_b);
    d->inertia[i*6 + 1] = _i2f(iyy_b);
    d->inertia[i*6 + 2] = _i2f(izz_b);
    d->inertia[i*6 + 3] = _i2f(ixy_b);
    d->inertia[i*6 + 4] = _i2f(ixz_b);
    d->inertia[i*6 + 5] = _i2f(iyz_b);
}

void nuc_dyn_set_gravity(long long h, long long gx_b, long long gy_b, long long gz_b) {
    NDyn *d = (NDyn *)(void *)(size_t)h;
    if (!d) return;
    d->gravity[0] = _i2f(gx_b);
    d->gravity[1] = _i2f(gy_b);
    d->gravity[2] = _i2f(gz_b);
}

// Inverse dynamics: compute joint torques tau given (q, qd, qdd).
// All array handles are flat double[n_links] pointers (caller-owned).
//
// Implementation: world-frame two-pass RNEA. The forward pass
// propagates link kinematics (ω, ω̇, a) from base to tip; the
// backward pass propagates wrenches (force, torque) from tip to
// base, projecting onto the joint axis to extract the per-joint
// torque scalar.
long long nuc_dyn_inverse(long long h,
                         long long q_ptr, long long qd_ptr, long long qdd_ptr,
                         long long tau_out_ptr)
{
    NDyn *d = (NDyn *)(void *)(size_t)h;
    if (!d) return -1;
    int n = d->n_links;
    double *q   = (double *)(void *)(size_t)q_ptr;
    double *qd  = (double *)(void *)(size_t)qd_ptr;
    double *qdd = (double *)(void *)(size_t)qdd_ptr;
    double *tau = (double *)(void *)(size_t)tau_out_ptr;
    if (!q || !qd || !qdd || !tau) return -1;

    // Run FK to refresh the chain's link world-frame poses.
    nuc_fk_chain_update(d->fk_handle, q_ptr);

    // Cache per-link axis-in-world (computed by rotating the joint's
    // body-frame axis by the link's current world quaternion). For
    // revolute joints this is the rotation axis; for prismatic, the
    // translation axis.
    double (*axis_w)[3] = (double (*)[3])malloc(n * 3 * sizeof(double));
    double (*pos_w)[3]  = (double (*)[3])malloc(n * 3 * sizeof(double));
    int *jtype = (int *)malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) {
        jtype[i] = (int)nuc_fk_chain_joint_type(d->fk_handle, i);
        double ax[3] = {
            _i2f(nuc_fk_chain_joint_axis(d->fk_handle, i, 0)),
            _i2f(nuc_fk_chain_joint_axis(d->fk_handle, i, 1)),
            _i2f(nuc_fk_chain_joint_axis(d->fk_handle, i, 2))
        };
        double qw = _i2f(nuc_fk_chain_link_quat_w(d->fk_handle, i));
        double qx = _i2f(nuc_fk_chain_link_quat_x(d->fk_handle, i));
        double qy = _i2f(nuc_fk_chain_link_quat_y(d->fk_handle, i));
        double qz = _i2f(nuc_fk_chain_link_quat_z(d->fk_handle, i));
        _q_rot_vec(qw, qx, qy, qz, ax, axis_w[i]);
        pos_w[i][0] = _i2f(nuc_fk_chain_link_pos_x(d->fk_handle, i));
        pos_w[i][1] = _i2f(nuc_fk_chain_link_pos_y(d->fk_handle, i));
        pos_w[i][2] = _i2f(nuc_fk_chain_link_pos_z(d->fk_handle, i));
    }

    // Per-link kinematics (world frame): ω, ω̇, a (linear accel of origin),
    // a_com (linear accel of CoM).
    double (*w)[3]   = (double (*)[3])calloc(n, 3 * sizeof(double));
    double (*wd)[3]  = (double (*)[3])calloc(n, 3 * sizeof(double));
    double (*a)[3]   = (double (*)[3])calloc(n, 3 * sizeof(double));
    double (*acm)[3] = (double (*)[3])calloc(n, 3 * sizeof(double));

    // Base "frame" is implicit: the parent of link 0 has zero ω, zero
    // ω̇, and we account for gravity by setting a_0 = -g (so that
    // the "fictitious force" m·a_com cancels real gravity m·g, leaving
    // the wrenches as if gravity were absent — a standard RNEA trick).
    double base_a[3] = { -d->gravity[0], -d->gravity[1], -d->gravity[2] };
    double base_w[3] = {0,0,0}, base_wd[3] = {0,0,0};

    // World position of the previous (parent) frame; for link 0 this
    // is the world origin (the FK chain's base link is rooted there).
    double parent_pos[3] = {0,0,0};

    // Forward pass.
    for (int i = 0; i < n; i++) {
        double *pw = (i == 0) ? base_w  : w[i-1];
        double *pwd= (i == 0) ? base_wd : wd[i-1];
        double *pa = (i == 0) ? base_a  : a[i-1];
        double r[3];      // vector from parent origin to this link origin (world frame)
        _vsub(pos_w[i], parent_pos, r);

        if (jtype[i] == _DYN_PRISMATIC) {
            // Translation along axis: ω unchanged.
            w[i][0] = pw[0]; w[i][1] = pw[1]; w[i][2] = pw[2];
            wd[i][0]= pwd[0]; wd[i][1]= pwd[1]; wd[i][2]= pwd[2];
            // a_i = a_{i-1} + ω̇ × r + ω × (ω × r)
            //       + 2·ω × (qd_i·z) + qdd_i·z
            double tmp[3], wxr[3], wxwxr[3];
            _vcross(pwd, r, tmp);
            _vadd(pa, tmp, a[i]);
            _vcross(pw, r, wxr);
            _vcross(pw, wxr, wxwxr);
            _vadd(a[i], wxwxr, a[i]);
            double v_lin[3], coriolis[3], qddz[3];
            _vscale(axis_w[i], qd[i],  v_lin);
            _vcross(pw, v_lin, coriolis);
            _vscale(coriolis, 2.0, coriolis);
            _vadd(a[i], coriolis, a[i]);
            _vscale(axis_w[i], qdd[i], qddz);
            _vadd(a[i], qddz, a[i]);
        } else if (jtype[i] == _DYN_REVOLUTE) {
            // Rotation: ω_i = ω_{i-1} + qd_i · z
            double qdz[3]; _vscale(axis_w[i], qd[i], qdz);
            _vadd(pw, qdz, w[i]);
            // ω̇_i = ω̇_{i-1} + qdd_i · z + ω_{i-1} × (qd_i · z)
            double qddz[3]; _vscale(axis_w[i], qdd[i], qddz);
            double cross[3]; _vcross(pw, qdz, cross);
            _vadd(pwd, qddz, wd[i]);
            _vadd(wd[i], cross, wd[i]);
            // a_origin_i = a_parent + ω̇_PARENT × r + ω_PARENT × (ω_PARENT × r).
            // Use the PARENT's angular state — link i's frame origin is a
            // point fixed on the parent body (the revolute joint rotates
            // about it but doesn't move it). Using wd[i]/w[i] here would
            // double-count the joint's rotational contribution and break
            // the symmetry of M(q).
            double t1[3]; _vcross(pwd, r, t1);
            _vadd(pa, t1, a[i]);
            double wxr[3]; _vcross(pw, r, wxr);
            double wxwxr[3]; _vcross(pw, wxr, wxwxr);
            _vadd(a[i], wxwxr, a[i]);
        } else {
            // Fixed joint: kinematics propagate without joint contribution.
            w[i][0] = pw[0]; w[i][1] = pw[1]; w[i][2] = pw[2];
            wd[i][0]= pwd[0]; wd[i][1]= pwd[1]; wd[i][2]= pwd[2];
            double t1[3], wxr[3], wxwxr[3];
            _vcross(pwd, r, t1); _vadd(pa, t1, a[i]);
            _vcross(pw, r, wxr); _vcross(pw, wxr, wxwxr);
            _vadd(a[i], wxwxr, a[i]);
        }

        // a_com_i = a_i + ω̇_i × r_com + ω_i × (ω_i × r_com)
        // r_com is the CoM offset — stored in link-local frame, so we
        // rotate it into world frame first using the link's current orientation.
        double r_com_local[3] = { d->com[i*3+0], d->com[i*3+1], d->com[i*3+2] };
        double r_com_w[3];
        double qw_l = _i2f(nuc_fk_chain_link_quat_w(d->fk_handle, i));
        double qx_l = _i2f(nuc_fk_chain_link_quat_x(d->fk_handle, i));
        double qy_l = _i2f(nuc_fk_chain_link_quat_y(d->fk_handle, i));
        double qz_l = _i2f(nuc_fk_chain_link_quat_z(d->fk_handle, i));
        _q_rot_vec(qw_l, qx_l, qy_l, qz_l, r_com_local, r_com_w);
        double t2[3]; _vcross(wd[i], r_com_w, t2);
        _vadd(a[i], t2, acm[i]);
        double wxrc[3]; _vcross(w[i], r_com_w, wxrc);
        double wxwxrc[3]; _vcross(w[i], wxrc, wxwxrc);
        _vadd(acm[i], wxwxrc, acm[i]);

        parent_pos[0] = pos_w[i][0];
        parent_pos[1] = pos_w[i][1];
        parent_pos[2] = pos_w[i][2];
    }

    // Backward pass: wrenches.
    double f_next[3] = {0,0,0}, n_next[3] = {0,0,0};
    double next_pos[3] = {0,0,0};   // origin of link i+1 in world (for r_{i+1})

    for (int i = n - 1; i >= 0; i--) {
        // Inertial wrench at the link's CoM.
        double F[3]; _vscale(acm[i], d->mass[i], F);

        // Rotate ω, ω̇ into the link's body frame for the inertia
        // tensor evaluation (inertia is given in body frame).
        double qw_l = _i2f(nuc_fk_chain_link_quat_w(d->fk_handle, i));
        double qx_l = _i2f(nuc_fk_chain_link_quat_x(d->fk_handle, i));
        double qy_l = _i2f(nuc_fk_chain_link_quat_y(d->fk_handle, i));
        double qz_l = _i2f(nuc_fk_chain_link_quat_z(d->fk_handle, i));
        // body = q^-1 · world · q   (conjugate quaternion).
        double w_body[3], wd_body[3];
        _q_rot_vec(qw_l, -qx_l, -qy_l, -qz_l, w[i], w_body);
        _q_rot_vec(qw_l, -qx_l, -qy_l, -qz_l, wd[i], wd_body);
        // I·ω̇ + ω × (I·ω) in body frame, then rotate back to world.
        double Iwd_b[3], Iw_b[3], wxIw_b[3], N_body[3];
        _inertia_mul(&d->inertia[i*6], wd_body, Iwd_b);
        _inertia_mul(&d->inertia[i*6], w_body,  Iw_b);
        _vcross(w_body, Iw_b, wxIw_b);
        _vadd(Iwd_b, wxIw_b, N_body);
        double N[3];
        _q_rot_vec(qw_l, qx_l, qy_l, qz_l, N_body, N);

        // Force on link i = inertial force + force from link i+1.
        double f_i[3];
        _vadd(F, f_next, f_i);
        // Torque on link i = N + r_com × F + n_{i+1} + r_{i+1} × f_{i+1}.
        // r_{i+1} is the offset from link i origin to link i+1 origin,
        // in world frame.
        double r_com_local[3] = { d->com[i*3+0], d->com[i*3+1], d->com[i*3+2] };
        double r_com_w[3];
        _q_rot_vec(qw_l, qx_l, qy_l, qz_l, r_com_local, r_com_w);
        double rcxF[3]; _vcross(r_com_w, F, rcxF);
        double n_i[3];
        _vadd(N, rcxF, n_i);
        _vadd(n_i, n_next, n_i);
        if (i < n - 1) {
            double r_next[3];
            _vsub(next_pos, pos_w[i], r_next);
            double rxf[3]; _vcross(r_next, f_next, rxf);
            _vadd(n_i, rxf, n_i);
        }

        // Project onto joint axis to get tau_i.
        if (jtype[i] == _DYN_REVOLUTE) {
            tau[i] = _vdot(n_i, axis_w[i]);
        } else if (jtype[i] == _DYN_PRISMATIC) {
            tau[i] = _vdot(f_i, axis_w[i]);
        } else {
            tau[i] = 0.0;  // fixed joint
        }

        f_next[0] = f_i[0]; f_next[1] = f_i[1]; f_next[2] = f_i[2];
        n_next[0] = n_i[0]; n_next[1] = n_i[1]; n_next[2] = n_i[2];
        next_pos[0] = pos_w[i][0]; next_pos[1] = pos_w[i][1]; next_pos[2] = pos_w[i][2];
    }

    free(axis_w); free(pos_w); free(jtype);
    free(w); free(wd); free(a); free(acm);
    return 0;
}

// Gravity-compensation torques — the special case qd = qdd = 0.
// Allocates qd / qdd zero buffers internally so the caller doesn't
// have to.
long long nuc_dyn_gravity(long long h, long long q_ptr, long long tau_out_ptr) {
    NDyn *d = (NDyn *)(void *)(size_t)h;
    if (!d) return -1;
    int n = d->n_links;
    double *qd  = (double *)calloc(n, sizeof(double));
    double *qdd = (double *)calloc(n, sizeof(double));
    long long rc = nuc_dyn_inverse(h, q_ptr,
        (long long)(size_t)qd, (long long)(size_t)qdd, tau_out_ptr);
    free(qd); free(qdd);
    return rc;
}

// === Mass matrix M(q) and forward dynamics (v0.2.211) ===================
//
// Joint-space mass matrix. Standard derivation via the equation of
// motion: tau = M(q)·qdd + C(q,qd)·qd + g(q). With qd = 0, the
// Coriolis term vanishes and we get tau − g = M·qdd. Setting qdd
// to the i-th unit vector e_i extracts the i-th column of M:
//
//     M[:, i] = RNEA(q, 0, e_i) − RNEA(q, 0, 0)
//
// This requires n+1 RNEA calls (one for gravity bias + one per
// column). Slower than the composite-rigid-body algorithm but much
// simpler to implement correctly; for n ≤ 20 the constant factor
// is fine.
//
// `out_M_ptr` is the caller-allocated `double[n*n]` row-major
// matrix output buffer. Returns 0 on success.
long long nuc_dyn_mass_matrix(long long h, long long q_ptr, long long out_M_ptr) {
    NDyn *d = (NDyn *)(void *)(size_t)h;
    if (!d) return -1;
    int n = d->n_links;
    double *M = (double *)(void *)(size_t)out_M_ptr;
    if (!M) return -1;

    double *qd  = (double *)calloc(n, sizeof(double));
    double *qdd = (double *)calloc(n, sizeof(double));
    double *tau_g    = (double *)calloc(n, sizeof(double));
    double *tau_col  = (double *)calloc(n, sizeof(double));

    // Gravity bias g(q) = RNEA(q, 0, 0).
    nuc_dyn_inverse(h, q_ptr,
        (long long)(size_t)qd, (long long)(size_t)qdd,
        (long long)(size_t)tau_g);

    // Each column.
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) qdd[j] = (j == i) ? 1.0 : 0.0;
        nuc_dyn_inverse(h, q_ptr,
            (long long)(size_t)qd, (long long)(size_t)qdd,
            (long long)(size_t)tau_col);
        for (int j = 0; j < n; j++) M[j*n + i] = tau_col[j] - tau_g[j];
    }

    free(qd); free(qdd); free(tau_g); free(tau_col);
    return 0;
}

// In-place Gauss-Jordan inverse of an n×n matrix (row-major).
// Allocates a 2n×2n augmented buffer internally. Returns 1 on
// success, 0 if the matrix is singular.
static int _gj_invert(double *A, int n, double *Ainv) {
    double *aug = (double *)malloc(n * 2 * n * sizeof(double));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) aug[i*2*n + j] = A[i*n + j];
        for (int j = 0; j < n; j++) aug[i*2*n + n + j] = (i == j) ? 1.0 : 0.0;
    }
    for (int i = 0; i < n; i++) {
        // Pivot.
        int pivot = i;
        for (int r = i + 1; r < n; r++) {
            if (fabs(aug[r*2*n + i]) > fabs(aug[pivot*2*n + i])) pivot = r;
        }
        if (fabs(aug[pivot*2*n + i]) < 1e-12) { free(aug); return 0; }
        if (pivot != i) {
            for (int j = 0; j < 2*n; j++) {
                double t = aug[i*2*n + j];
                aug[i*2*n + j] = aug[pivot*2*n + j];
                aug[pivot*2*n + j] = t;
            }
        }
        double inv = 1.0 / aug[i*2*n + i];
        for (int j = 0; j < 2*n; j++) aug[i*2*n + j] *= inv;
        for (int r = 0; r < n; r++) {
            if (r == i) continue;
            double f = aug[r*2*n + i];
            for (int j = 0; j < 2*n; j++) aug[r*2*n + j] -= f * aug[i*2*n + j];
        }
    }
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) Ainv[i*n + j] = aug[i*2*n + n + j];
    free(aug);
    return 1;
}

// Forward dynamics: given joint torques `tau` (and current q, qd),
// compute the resulting joint accelerations `qdd` via
//
//     qdd = M(q)⁻¹ · (tau − C(q,qd)·qd − g(q))
//
// The bias `C·qd + g` is computed in one RNEA call by setting
// `qdd_input = 0`. The mass matrix is computed via
// `nuc_dyn_mass_matrix` and inverted by Gauss-Jordan.
//
// Returns 0 on success; -1 if the mass matrix turns out to be
// singular (very rare in practice — usually means inertia data is
// pathological).
long long nuc_dyn_forward(long long h,
                         long long q_ptr, long long qd_ptr, long long tau_ptr,
                         long long qdd_out_ptr)
{
    NDyn *d = (NDyn *)(void *)(size_t)h;
    if (!d) return -1;
    int n = d->n_links;
    double *tau = (double *)(void *)(size_t)tau_ptr;
    double *qdd_out = (double *)(void *)(size_t)qdd_out_ptr;
    if (!tau || !qdd_out) return -1;

    double *zero = (double *)calloc(n, sizeof(double));
    double *bias = (double *)calloc(n, sizeof(double));
    nuc_dyn_inverse(h, q_ptr, qd_ptr,
        (long long)(size_t)zero, (long long)(size_t)bias);

    double *M = (double *)malloc(n * n * sizeof(double));
    nuc_dyn_mass_matrix(h, q_ptr, (long long)(size_t)M);

    double *Minv = (double *)malloc(n * n * sizeof(double));
    if (!_gj_invert(M, n, Minv)) {
        free(zero); free(bias); free(M); free(Minv);
        return -1;
    }

    // qdd = Minv · (tau - bias).
    double *rhs = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) rhs[i] = tau[i] - bias[i];
    for (int i = 0; i < n; i++) {
        double s = 0;
        for (int j = 0; j < n; j++) s += Minv[i*n + j] * rhs[j];
        qdd_out[i] = s;
    }

    free(zero); free(bias); free(M); free(Minv); free(rhs);
    return 0;
}

void nuc_dyn_free(long long h) {
    NDyn *d = (NDyn *)(void *)(size_t)h;
    if (!d) return;
    if (d->mass) free(d->mass);
    if (d->com) free(d->com);
    if (d->inertia) free(d->inertia);
    free(d);
}
