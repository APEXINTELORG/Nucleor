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

// Forward declare the FK chain runtime symbols (defined in
// fk_chain_rt.c). Only takes long-long and returns long-long, so
// the calling convention works without a header.
long long nuc_fk_chain_count(long long ch);
long long nuc_fk_chain_update(long long ch, long long vars_ptr);
long long nuc_fk_chain_link_pos_x(long long ch, long long i);
long long nuc_fk_chain_link_pos_y(long long ch, long long i);
long long nuc_fk_chain_link_pos_z(long long ch, long long i);

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
        if (fabs(det) < 1e-12) break;
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
