// ik_dls_rt.c — Damped Least Squares inverse kinematics solver.
//
// Given a forward-kinematics chain (`fk_chain_rt.c`) and a target
// end-effector position, iteratively adjust joint variables to
// minimize the position error. Uses the standard damped Jacobian
// pseudoinverse method (Wampler 1986, Buss 2009).
//
// The Jacobian is computed numerically via finite differences:
// for each joint, perturb its variable by `eps`, run forward
// kinematics, observe the change in end-effector position. This
// avoids hand-coding analytical derivatives at the cost of
// `n_joints + 1` extra FK evaluations per iteration.
//
// `damping` (lambda) trades off convergence speed against
// numerical stability near singularities. 0.01-0.1 is typical.
//
// Returns the number of iterations actually run (≤ max_iters).
//
// Compile: clang -c stdlib/runtime/ik_dls_rt.c -o target/ik.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(long long)); return x; }

// === Singularity-detection state (v0.2.199) =============================
//
// Tracks the smallest |det(J·Jᵀ + λ²I)| observed during the most
// recent solve call. A small value means the Jacobian is rank-
// deficient — the chain is near a singular configuration where
// small joint changes don't move the end-effector (or vice-versa).
//
// User reads `nuc_ik_get_last_singularity_metric` after the solve
// to decide whether to back off, request a different goal, or
// switch to a damped strategy.
static double _g_last_singularity = 1e30;

long long nuc_ik_get_last_singularity_metric(void) {
    return _f2i(_g_last_singularity);
}

// Forward declare the FK chain runtime symbols (defined in
// fk_chain_rt.c). Only takes long-long and returns long-long, so
// the calling convention works without a header.
long long nuc_fk_chain_count(long long ch);
long long nuc_fk_chain_update(long long ch, long long vars_ptr);
long long nuc_fk_chain_link_pos_x(long long ch, long long i);
long long nuc_fk_chain_link_pos_y(long long ch, long long i);
long long nuc_fk_chain_link_pos_z(long long ch, long long i);
long long nuc_fk_chain_link_quat_w(long long ch, long long i);
long long nuc_fk_chain_link_quat_x(long long ch, long long i);
long long nuc_fk_chain_link_quat_y(long long ch, long long i);
long long nuc_fk_chain_link_quat_z(long long ch, long long i);

static double _f_from_handle(long long bits) { double d; memcpy(&d, &bits, sizeof(double)); return d; }

// === Joint limits (v0.2.193) ===
//
// Per-joint min/max bounds. Set once per chain, applied during
// every IK iteration via clamping. Bounds are stored in a
// global table keyed by chain handle (simple linear-search
// lookup — for typical N≤10 joint chains this is fine).

typedef struct { long long ch; double *lo; double *hi; int n; } _IKLimits;
static _IKLimits *_g_limits = NULL;
static int _g_limits_count = 0, _g_limits_cap = 0;

static _IKLimits *_get_or_create_limits(long long ch, int n) {
    for (int i = 0; i < _g_limits_count; i++) {
        if (_g_limits[i].ch == ch) return &_g_limits[i];
    }
    if (_g_limits_count >= _g_limits_cap) {
        _g_limits_cap = _g_limits_cap == 0 ? 4 : _g_limits_cap * 2;
        _g_limits = (_IKLimits *)realloc(_g_limits, _g_limits_cap * sizeof(_IKLimits));
    }
    _IKLimits *L = &_g_limits[_g_limits_count++];
    L->ch = ch;
    L->n = n;
    L->lo = (double *)malloc(n * sizeof(double));
    L->hi = (double *)malloc(n * sizeof(double));
    for (int i = 0; i < n; i++) {
        L->lo[i] = -3.14159265358979 * 2.0;
        L->hi[i] =  3.14159265358979 * 2.0;
    }
    return L;
}

void nuc_ik_set_joint_limit(long long ch, long long joint_idx,
                             long long lo_b, long long hi_b)
{
    int n = (int)nuc_fk_chain_count(ch);
    if (n <= 0 || joint_idx < 0 || joint_idx >= n) return;
    _IKLimits *L = _get_or_create_limits(ch, n);
    L->lo[joint_idx] = _i2f(lo_b);
    L->hi[joint_idx] = _i2f(hi_b);
}

static _IKLimits *_lookup_limits(long long ch) {
    for (int i = 0; i < _g_limits_count; i++) {
        if (_g_limits[i].ch == ch) return &_g_limits[i];
    }
    return NULL;
}

// Solve in place: vars are read AND written through the same array.
// On entry, vars holds the current joint configuration; on exit,
// vars holds the (possibly improved) configuration.
//
//   ch          — fk_chain handle
//   vars_ptr    — handle to a malloc'd double[n_joints]
//   tx/ty/tz    — target end-effector position (i64-bit-cast f64)
//   max_iters   — cap iteration count
//   tolerance   — early-stop when ||error|| < tolerance (i64-bit-cast)
//   damping     — DLS lambda (i64-bit-cast); 0.01-0.1 typical
//
// Returns iterations actually performed.
long long nuc_ik_dls_solve(
    long long ch, long long vars_ptr,
    long long tx_bits, long long ty_bits, long long tz_bits,
    long long max_iters,
    long long tolerance_bits,
    long long damping_bits)
{
    int n = (int)nuc_fk_chain_count(ch);
    if (n <= 0) return 0;
    double *vars = (double *)(void *)(size_t)vars_ptr;
    double tx = _i2f(tx_bits), ty = _i2f(ty_bits), tz = _i2f(tz_bits);
    double tol = _i2f(tolerance_bits);
    double lambda = _i2f(damping_bits);
    double lambda2 = lambda * lambda;

    // Allocate scratch: Jacobian (3 × n), perturbed-vars copy.
    double *J = (double *)malloc(3 * n * sizeof(double));
    double *perturbed = (double *)malloc(n * sizeof(double));
    long long perturbed_h = (long long)(size_t)perturbed;
    double *JJt_plus_lam = (double *)malloc(9 * sizeof(double));
    double *invJJt = (double *)malloc(9 * sizeof(double));
    double *Jt_invJJt = (double *)malloc(3 * n * sizeof(double));

    int last = n - 1;
    double eps = 1e-5;
    int iter;
    _g_last_singularity = 1e30;  // reset for this solve

    for (iter = 0; iter < max_iters; iter++) {
        // Current end-effector position.
        nuc_fk_chain_update(ch, vars_ptr);
        double cx = _f_from_handle(nuc_fk_chain_link_pos_x(ch, last));
        double cy = _f_from_handle(nuc_fk_chain_link_pos_y(ch, last));
        double cz = _f_from_handle(nuc_fk_chain_link_pos_z(ch, last));
        double ex = tx - cx, ey = ty - cy, ez = tz - cz;
        double err2 = ex*ex + ey*ey + ez*ez;
        if (err2 < tol * tol) break;

        // Numerical Jacobian: 3 x n.
        for (int j = 0; j < n; j++) {
            memcpy(perturbed, vars, n * sizeof(double));
            perturbed[j] += eps;
            nuc_fk_chain_update(ch, perturbed_h);
            double px = _f_from_handle(nuc_fk_chain_link_pos_x(ch, last));
            double py = _f_from_handle(nuc_fk_chain_link_pos_y(ch, last));
            double pz = _f_from_handle(nuc_fk_chain_link_pos_z(ch, last));
            J[0*n + j] = (px - cx) / eps;
            J[1*n + j] = (py - cy) / eps;
            J[2*n + j] = (pz - cz) / eps;
        }

        // J J^T  (3x3) plus lambda^2 * I.
        for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 3; c++) {
                double s = 0;
                for (int k = 0; k < n; k++) s += J[r*n + k] * J[c*n + k];
                JJt_plus_lam[r*3 + c] = s + (r == c ? lambda2 : 0);
            }
        }

        // Inverse 3x3 via cofactor / determinant.
        double a = JJt_plus_lam[0], b = JJt_plus_lam[1], c2 = JJt_plus_lam[2];
        double d = JJt_plus_lam[3], e = JJt_plus_lam[4], f = JJt_plus_lam[5];
        double g = JJt_plus_lam[6], h = JJt_plus_lam[7], i = JJt_plus_lam[8];
        double det = a*(e*i - f*h) - b*(d*i - f*g) + c2*(d*h - e*g);
        // Track smallest |det| seen this solve (proxy for singularity).
        double abs_det = fabs(det);
        if (abs_det < _g_last_singularity) _g_last_singularity = abs_det;
        if (abs_det < 1e-12) break;
        double idet = 1.0 / det;
        invJJt[0] = (e*i - f*h) * idet;
        invJJt[1] = (c2*h - b*i) * idet;
        invJJt[2] = (b*f - c2*e) * idet;
        invJJt[3] = (f*g - d*i) * idet;
        invJJt[4] = (a*i - c2*g) * idet;
        invJJt[5] = (c2*d - a*f) * idet;
        invJJt[6] = (d*h - e*g) * idet;
        invJJt[7] = (b*g - a*h) * idet;
        invJJt[8] = (a*e - b*d) * idet;

        // J^T invJJt  (n x 3).
        for (int r = 0; r < n; r++) {
            for (int c = 0; c < 3; c++) {
                double s = 0;
                for (int k = 0; k < 3; k++) s += J[k*n + r] * invJJt[k*3 + c];
                Jt_invJJt[r*3 + c] = s;
            }
        }

        // delta_q = J^T invJJt * error.
        for (int r = 0; r < n; r++) {
            vars[r] += Jt_invJJt[r*3 + 0]*ex
                     + Jt_invJJt[r*3 + 1]*ey
                     + Jt_invJJt[r*3 + 2]*ez;
        }
        // Apply joint limits (v0.2.193). Clamp each var to its [lo, hi]
        // bound after the delta update. Simple clamp — for a more
        // sophisticated handling (gradient projection onto the
        // constraint manifold), see the v0.5 task-priority IK ship.
        _IKLimits *L = _lookup_limits(ch);
        if (L) {
            for (int r = 0; r < n && r < L->n; r++) {
                if (vars[r] < L->lo[r]) vars[r] = L->lo[r];
                if (vars[r] > L->hi[r]) vars[r] = L->hi[r];
            }
        }
    }

    free(J); free(perturbed); free(JJt_plus_lam); free(invJJt); free(Jt_invJJt);
    return (long long)iter;
}

// === 6-DOF orientation IK (v0.2.194) ====================================
//
// Extends the position-only DLS solver to a 6-DOF target (position
// + orientation). Jacobian becomes 6×n: 3 rows for position
// derivatives + 3 rows for angular-velocity derivatives. The
// 6×6 normal-equations matrix is inverted via Gauss-Jordan on a
// stack-allocated 6×7 augmented matrix.
//
// Angular error is the quaternion log-map of (q_target * q_current^-1):
// for two unit quaternions q1, q2, the angular error vector is
//   e = 2 · log(q1 · q2^-1)
// which is a 3-vector in axis-angle form (axis * angle). This is
// the correct local linearization for orientation correction.
//
// Inputs match the position-only solver plus four target-quaternion
// values (w, x, y, z, all i64-bit-cast f64) and a `weight_orient`
// scalar that scales the orientation error vs position error
// (1.0 = equal weight; <1.0 prioritize position; >1.0 prioritize
// orientation).

static void _quat_log_map(double qw, double qx, double qy, double qz, double *out3) {
    // Convert (almost-identity) unit quaternion to a 3-vector
    // (axis × angle). Equivalent to 2 · log(q).
    double sinhalf = sqrt(qx*qx + qy*qy + qz*qz);
    if (sinhalf < 1e-9) {
        out3[0] = 0; out3[1] = 0; out3[2] = 0;
        return;
    }
    double angle = 2.0 * atan2(sinhalf, qw);
    if (angle > 3.14159265358979) angle -= 2.0 * 3.14159265358979;
    double scale = angle / sinhalf;
    out3[0] = qx * scale;
    out3[1] = qy * scale;
    out3[2] = qz * scale;
}

// Compute (target_quat * current_quat^-1), then log-map it.
static void _angular_error(double tw, double tx, double ty, double tz,
                           double cw, double cx, double cy, double cz,
                           double *out3)
{
    // q_err = t * c^-1; conjugate of c is (cw, -cx, -cy, -cz).
    double qx_cnj = -cx, qy_cnj = -cy, qz_cnj = -cz;
    double w = tw*cw - tx*qx_cnj - ty*qy_cnj - tz*qz_cnj;
    double x = tw*qx_cnj + tx*cw + ty*qz_cnj - tz*qy_cnj;
    double y = tw*qy_cnj - tx*qz_cnj + ty*cw + tz*qx_cnj;
    double z = tw*qz_cnj + tx*qy_cnj - ty*qx_cnj + tz*cw;
    _quat_log_map(w, x, y, z, out3);
}

// 6×6 matrix inverse via Gauss-Jordan on an augmented 6×12.
// Returns 1 on success, 0 if singular.
static int _inverse_6x6(double *A, double *Ainv) {
    double aug[6][12];
    for (int i = 0; i < 6; i++) {
        for (int j = 0; j < 6; j++) aug[i][j] = A[i*6 + j];
        for (int j = 0; j < 6; j++) aug[i][6 + j] = (i == j) ? 1.0 : 0.0;
    }
    for (int i = 0; i < 6; i++) {
        // Find the pivot (max abs in column i, rows i..5).
        int pivot = i;
        for (int r = i + 1; r < 6; r++) {
            if (fabs(aug[r][i]) > fabs(aug[pivot][i])) pivot = r;
        }
        if (fabs(aug[pivot][i]) < 1e-12) return 0;
        if (pivot != i) {
            for (int j = 0; j < 12; j++) {
                double tmp = aug[i][j]; aug[i][j] = aug[pivot][j]; aug[pivot][j] = tmp;
            }
        }
        double inv = 1.0 / aug[i][i];
        for (int j = 0; j < 12; j++) aug[i][j] *= inv;
        for (int r = 0; r < 6; r++) {
            if (r == i) continue;
            double f = aug[r][i];
            for (int j = 0; j < 12; j++) aug[r][j] -= f * aug[i][j];
        }
    }
    for (int i = 0; i < 6; i++) {
        for (int j = 0; j < 6; j++) Ainv[i*6 + j] = aug[i][6 + j];
    }
    return 1;
}

long long nuc_ik_dls_solve_6d(
    long long ch, long long vars_ptr,
    long long tx_b, long long ty_b, long long tz_b,
    long long tqw_b, long long tqx_b, long long tqy_b, long long tqz_b,
    long long max_iters,
    long long tolerance_b,
    long long damping_b,
    long long weight_orient_b)
{
    int n = (int)nuc_fk_chain_count(ch);
    if (n <= 0) return 0;
    double *vars = (double *)(void *)(size_t)vars_ptr;
    double tx = _i2f(tx_b), ty = _i2f(ty_b), tz = _i2f(tz_b);
    double tqw = _i2f(tqw_b), tqx = _i2f(tqx_b), tqy = _i2f(tqy_b), tqz = _i2f(tqz_b);
    double tol = _i2f(tolerance_b);
    double lambda = _i2f(damping_b);
    double lambda2 = lambda * lambda;
    double w_orient = _i2f(weight_orient_b);
    if (w_orient <= 0) w_orient = 1.0;

    double *J = (double *)malloc(6 * n * sizeof(double));
    double *perturbed = (double *)malloc(n * sizeof(double));
    long long perturbed_h = (long long)(size_t)perturbed;
    double *JJt_plus_lam = (double *)malloc(36 * sizeof(double));
    double *invJJt = (double *)malloc(36 * sizeof(double));
    double *Jt_invJJt = (double *)malloc(6 * n * sizeof(double));
    int last = n - 1;
    double eps = 1e-5;
    int iter;
    for (iter = 0; iter < max_iters; iter++) {
        nuc_fk_chain_update(ch, vars_ptr);
        double cx = _i2f(nuc_fk_chain_link_pos_x(ch, last));
        double cy = _i2f(nuc_fk_chain_link_pos_y(ch, last));
        double cz = _i2f(nuc_fk_chain_link_pos_z(ch, last));
        double cqw = _i2f(nuc_fk_chain_link_quat_w(ch, last));
        double cqx = _i2f(nuc_fk_chain_link_quat_x(ch, last));
        double cqy = _i2f(nuc_fk_chain_link_quat_y(ch, last));
        double cqz = _i2f(nuc_fk_chain_link_quat_z(ch, last));

        double e_pos[3] = { tx - cx, ty - cy, tz - cz };
        double e_orient[3];
        _angular_error(tqw, tqx, tqy, tqz, cqw, cqx, cqy, cqz, e_orient);
        double e[6] = {
            e_pos[0], e_pos[1], e_pos[2],
            e_orient[0] * w_orient, e_orient[1] * w_orient, e_orient[2] * w_orient
        };
        double err2 = 0;
        for (int k = 0; k < 6; k++) err2 += e[k] * e[k];
        if (err2 < tol * tol) break;

        // Numerical 6×n Jacobian.
        for (int j = 0; j < n; j++) {
            memcpy(perturbed, vars, n * sizeof(double));
            perturbed[j] += eps;
            nuc_fk_chain_update(ch, perturbed_h);
            double px = _i2f(nuc_fk_chain_link_pos_x(ch, last));
            double py = _i2f(nuc_fk_chain_link_pos_y(ch, last));
            double pz = _i2f(nuc_fk_chain_link_pos_z(ch, last));
            double pqw = _i2f(nuc_fk_chain_link_quat_w(ch, last));
            double pqx = _i2f(nuc_fk_chain_link_quat_x(ch, last));
            double pqy = _i2f(nuc_fk_chain_link_quat_y(ch, last));
            double pqz = _i2f(nuc_fk_chain_link_quat_z(ch, last));
            J[0*n + j] = (px - cx) / eps;
            J[1*n + j] = (py - cy) / eps;
            J[2*n + j] = (pz - cz) / eps;
            // Angular Jacobian column: angular error from current to perturbed.
            double da[3];
            _angular_error(pqw, pqx, pqy, pqz, cqw, cqx, cqy, cqz, da);
            J[3*n + j] = da[0] / eps * w_orient;
            J[4*n + j] = da[1] / eps * w_orient;
            J[5*n + j] = da[2] / eps * w_orient;
        }

        // J J^T (6×6) + λ²I.
        for (int r = 0; r < 6; r++) {
            for (int c = 0; c < 6; c++) {
                double s = 0;
                for (int k = 0; k < n; k++) s += J[r*n + k] * J[c*n + k];
                JJt_plus_lam[r*6 + c] = s + (r == c ? lambda2 : 0);
            }
        }
        if (!_inverse_6x6(JJt_plus_lam, invJJt)) break;

        // Jt_invJJt (n × 6).
        for (int r = 0; r < n; r++) {
            for (int c = 0; c < 6; c++) {
                double s = 0;
                for (int k = 0; k < 6; k++) s += J[k*n + r] * invJJt[k*6 + c];
                Jt_invJJt[r*6 + c] = s;
            }
        }
        for (int r = 0; r < n; r++) {
            double dq = 0;
            for (int c = 0; c < 6; c++) dq += Jt_invJJt[r*6 + c] * e[c];
            vars[r] += dq;
        }
        _IKLimits *L = _lookup_limits(ch);
        if (L) {
            for (int r = 0; r < n && r < L->n; r++) {
                if (vars[r] < L->lo[r]) vars[r] = L->lo[r];
                if (vars[r] > L->hi[r]) vars[r] = L->hi[r];
            }
        }
    }
    free(J); free(perturbed); free(JJt_plus_lam); free(invJJt); free(Jt_invJJt);
    return (long long)iter;
}
