// pgs3_rt.c — 3D pose graph SLAM optimizer (SE(3) Gauss-Newton).
//
// Three-dimensional generalization of `pgs_rt.c`. Each pose is an
// SE(3) element (translation in ℝ³ + rotation in SO(3), stored as
// a unit quaternion). Edges encode relative-pose measurements with
// per-DOF (diagonal) information weights — 3 translational + 3
// rotational weights per edge.
//
// The optimization variables are the 6-DOF Lie-algebra perturbations
// δ_i ∈ ℝ⁶ for i > 0 (node 0 is gauge-fixed). After each Gauss-
// Newton step, updates are applied as:
//   t_i ← t_i + δ_t
//   R_i ← R_i · exp(δ_θ)        (right-multiplied; SO(3) exponential)
//
// The edge residual between nodes i and j given measurement
// (t_meas, R_meas):
//
//   R_pred = R_iᵀ · R_j
//   t_pred = R_iᵀ · (t_j − t_i)
//   r_t    = t_pred − t_meas                          (ℝ³)
//   r_R    = log(R_measᵀ · R_pred)                    (ℝ³, axis-angle)
//
// Jacobians of r ∈ ℝ⁶ w.r.t. the 6-DOF perturbations of nodes i
// and j are computed by central finite differences. For 3D pose
// graphs with N ≤ ~100 and a typical sparsity, the dense Gauss-
// Jordan solve and FD Jacobians are fine; sparse Cholesky and
// closed-form Jacobians land in v0.6 if needed.
//
// **Limitations** (closed-form Jacobians, sparse Cholesky, robust
// kernels land in v0.6):
// - Numerical FD Jacobians (12 residual evaluations per edge per
//   iter); fine for hundreds of edges.
// - Dense Gauss-Jordan linear solve: O(dof³) where dof = 6·(N−1).
// - Diagonal information weights only (full 6×6 information lands
//   in v0.6 if needed).
// - L₂ cost only — no robust kernels (Huber, Cauchy).
//
// Compile: clang -c stdlib/runtime/pgs3_rt.c -o target/pgs3.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int i, j;
    double dt[3];        // measured relative translation (j in i's frame)
    double dq[4];        // measured relative rotation (qw, qx, qy, qz)
    double info[6];      // per-DOF diagonal info: t_x t_y t_z r_x r_y r_z
} _PGS3Edge;

typedef struct {
    int n_nodes;
    double *nodes;       // n_nodes × 7  (t[3], q[4]); q is unit quat
    int n_edges;
    int cap_edges;
    _PGS3Edge *edges;
} NPGS3;

// === Quaternion helpers ===

static void _q_normalize(double *q) {
    double n = sqrt(q[0]*q[0] + q[1]*q[1] + q[2]*q[2] + q[3]*q[3]);
    if (n > 1e-12) { q[0]/=n; q[1]/=n; q[2]/=n; q[3]/=n; }
    else { q[0]=1; q[1]=q[2]=q[3]=0; }
}

// q_out = q1 * q2  (Hamilton convention: scalar first).
static void _q_mul(const double *q1, const double *q2, double *q_out) {
    double w1=q1[0], x1=q1[1], y1=q1[2], z1=q1[3];
    double w2=q2[0], x2=q2[1], y2=q2[2], z2=q2[3];
    q_out[0] = w1*w2 - x1*x2 - y1*y2 - z1*z2;
    q_out[1] = w1*x2 + x1*w2 + y1*z2 - z1*y2;
    q_out[2] = w1*y2 - x1*z2 + y1*w2 + z1*x2;
    q_out[3] = w1*z2 + x1*y2 - y1*x2 + z1*w2;
}

static void _q_conj(const double *q, double *q_out) {
    q_out[0] = q[0]; q_out[1] = -q[1]; q_out[2] = -q[2]; q_out[3] = -q[3];
}

// Rotate vector v by quaternion q: v_out = q * (0, v) * q^-1.
// For a unit q, q^-1 == q_conj.
static void _q_rotate(const double *q, const double *v, double *v_out) {
    // Optimized: v' = v + 2 q_w (q_v × v) + 2 q_v × (q_v × v)
    double qw = q[0];
    double qx = q[1], qy = q[2], qz = q[3];
    double tx = 2.0 * (qy*v[2] - qz*v[1]);
    double ty = 2.0 * (qz*v[0] - qx*v[2]);
    double tz = 2.0 * (qx*v[1] - qy*v[0]);
    v_out[0] = v[0] + qw*tx + (qy*tz - qz*ty);
    v_out[1] = v[1] + qw*ty + (qz*tx - qx*tz);
    v_out[2] = v[2] + qw*tz + (qx*ty - qy*tx);
}

// SO(3) exp: axis-angle ω ∈ ℝ³ → unit quaternion.
static void _so3_exp(const double *omega, double *q_out) {
    double a = sqrt(omega[0]*omega[0] + omega[1]*omega[1] + omega[2]*omega[2]);
    if (a < 1e-9) {
        q_out[0] = 1.0;
        q_out[1] = omega[0] * 0.5;
        q_out[2] = omega[1] * 0.5;
        q_out[3] = omega[2] * 0.5;
        _q_normalize(q_out);
        return;
    }
    double ha = a * 0.5;
    double s_over_a = sin(ha) / a;
    q_out[0] = cos(ha);
    q_out[1] = omega[0] * s_over_a;
    q_out[2] = omega[1] * s_over_a;
    q_out[3] = omega[2] * s_over_a;
}

// SO(3) log: unit quaternion → axis-angle ω ∈ ℝ³.
static void _so3_log(const double *q, double *omega_out) {
    double qw = q[0];
    double vx = q[1], vy = q[2], vz = q[3];
    double vnorm = sqrt(vx*vx + vy*vy + vz*vz);
    // Handle sign: log is multivalued; we pick the branch with smaller magnitude.
    double w_eff = qw;
    double s = 1.0;
    if (qw < 0.0) {
        w_eff = -qw;
        s = -1.0;
        vx = -vx; vy = -vy; vz = -vz;
    }
    if (vnorm < 1e-9) {
        // Small-angle: ω ≈ 2 * (x, y, z) (with sign already absorbed)
        omega_out[0] = 2.0 * vx;
        omega_out[1] = 2.0 * vy;
        omega_out[2] = 2.0 * vz;
        (void)s;
        return;
    }
    double theta = 2.0 * atan2(vnorm, w_eff);
    double k = theta / vnorm;
    omega_out[0] = vx * k;
    omega_out[1] = vy * k;
    omega_out[2] = vz * k;
}

// === Linear solver ===

static int _gj_inv(const double *A, int n, double *Ainv) {
    int aug_w = 2 * n;
    double *aug = (double *)malloc(n * aug_w * sizeof(double));
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) aug[i*aug_w + j] = A[i*n + j];
        for (int j = 0; j < n; j++) aug[i*aug_w + n + j] = (i == j) ? 1.0 : 0.0;
    }
    for (int i = 0; i < n; i++) {
        int piv = i;
        for (int r = i + 1; r < n; r++) {
            if (fabs(aug[r*aug_w + i]) > fabs(aug[piv*aug_w + i])) piv = r;
        }
        if (fabs(aug[piv*aug_w + i]) < 1e-12) { free(aug); return 0; }
        if (piv != i) {
            for (int j = 0; j < aug_w; j++) {
                double t = aug[i*aug_w + j];
                aug[i*aug_w + j] = aug[piv*aug_w + j];
                aug[piv*aug_w + j] = t;
            }
        }
        double inv = 1.0 / aug[i*aug_w + i];
        for (int j = 0; j < aug_w; j++) aug[i*aug_w + j] *= inv;
        for (int r = 0; r < n; r++) {
            if (r == i) continue;
            double f = aug[r*aug_w + i];
            for (int j = 0; j < aug_w; j++) aug[r*aug_w + j] -= f * aug[i*aug_w + j];
        }
    }
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) Ainv[i*n + j] = aug[i*aug_w + n + j];
    free(aug);
    return 1;
}

// === API ===

long long nuc_pgs3_new(long long n_nodes) {
    int n = (int)n_nodes;
    if (n <= 0) return 0;
    NPGS3 *p = (NPGS3 *)calloc(1, sizeof(NPGS3));
    p->n_nodes = n;
    p->nodes = (double *)calloc(n * 7, sizeof(double));
    // Default identity poses.
    for (int i = 0; i < n; i++) p->nodes[i*7 + 3] = 1.0;
    p->cap_edges = 16;
    p->edges = (_PGS3Edge *)calloc(p->cap_edges, sizeof(_PGS3Edge));
    return (long long)(size_t)p;
}

void nuc_pgs3_set_node(long long h, long long i,
    long long t_ptr, long long q_ptr)
{
    NPGS3 *p = (NPGS3 *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n_nodes) return;
    double *t = (double *)(void *)(size_t)t_ptr;
    double *q = (double *)(void *)(size_t)q_ptr;
    if (t) {
        p->nodes[i*7+0] = t[0];
        p->nodes[i*7+1] = t[1];
        p->nodes[i*7+2] = t[2];
    }
    if (q) {
        p->nodes[i*7+3] = q[0];
        p->nodes[i*7+4] = q[1];
        p->nodes[i*7+5] = q[2];
        p->nodes[i*7+6] = q[3];
        _q_normalize(p->nodes + i*7 + 3);
    }
}

void nuc_pgs3_get_node(long long h, long long i,
    long long t_out_ptr, long long q_out_ptr)
{
    NPGS3 *p = (NPGS3 *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n_nodes) return;
    double *t = (double *)(void *)(size_t)t_out_ptr;
    double *q = (double *)(void *)(size_t)q_out_ptr;
    if (t) {
        t[0] = p->nodes[i*7+0]; t[1] = p->nodes[i*7+1]; t[2] = p->nodes[i*7+2];
    }
    if (q) {
        q[0] = p->nodes[i*7+3]; q[1] = p->nodes[i*7+4];
        q[2] = p->nodes[i*7+5]; q[3] = p->nodes[i*7+6];
    }
}

long long nuc_pgs3_add_edge(long long h, long long i, long long j,
    long long dt_ptr, long long dq_ptr, long long info_ptr)
{
    NPGS3 *p = (NPGS3 *)(void *)(size_t)h;
    if (!p) return -1;
    if (i < 0 || i >= (long long)p->n_nodes) return -1;
    if (j < 0 || j >= (long long)p->n_nodes) return -1;
    if (i == j) return -1;
    double *dt = (double *)(void *)(size_t)dt_ptr;
    double *dq = (double *)(void *)(size_t)dq_ptr;
    double *info = (double *)(void *)(size_t)info_ptr;
    if (!dt || !dq || !info) return -1;
    if (p->n_edges >= p->cap_edges) {
        p->cap_edges *= 2;
        p->edges = (_PGS3Edge *)realloc(p->edges, p->cap_edges * sizeof(_PGS3Edge));
    }
    _PGS3Edge *e = &p->edges[p->n_edges];
    e->i = (int)i; e->j = (int)j;
    e->dt[0] = dt[0]; e->dt[1] = dt[1]; e->dt[2] = dt[2];
    e->dq[0] = dq[0]; e->dq[1] = dq[1]; e->dq[2] = dq[2]; e->dq[3] = dq[3];
    {
        double n = sqrt(e->dq[0]*e->dq[0] + e->dq[1]*e->dq[1]
                      + e->dq[2]*e->dq[2] + e->dq[3]*e->dq[3]);
        if (n > 1e-12) { e->dq[0]/=n; e->dq[1]/=n; e->dq[2]/=n; e->dq[3]/=n; }
        else { e->dq[0] = 1.0; e->dq[1] = e->dq[2] = e->dq[3] = 0.0; }
    }
    for (int k = 0; k < 6; k++) e->info[k] = info[k];
    return (long long)(p->n_edges++);
}

// Compute the 6-vector residual for an edge given current poses.
//   r[0..3] = R_iᵀ · (t_j - t_i) - dt
//   r[3..6] = log( dq^-1 · R_iᵀ · R_j )
static void _edge_residual(const double *t_i, const double *q_i,
                           const double *t_j, const double *q_j,
                           const double *dt_meas, const double *dq_meas,
                           double *r_out)
{
    double t_diff[3] = { t_j[0]-t_i[0], t_j[1]-t_i[1], t_j[2]-t_i[2] };
    double qi_inv[4]; _q_conj(q_i, qi_inv);
    double t_pred[3]; _q_rotate(qi_inv, t_diff, t_pred);
    r_out[0] = t_pred[0] - dt_meas[0];
    r_out[1] = t_pred[1] - dt_meas[1];
    r_out[2] = t_pred[2] - dt_meas[2];

    double q_rel[4]; _q_mul(qi_inv, q_j, q_rel);          // R_iᵀ R_j
    double dq_inv[4]; _q_conj(dq_meas, dq_inv);
    double q_err[4]; _q_mul(dq_inv, q_rel, q_err);        // dq^-1 · R_iᵀ R_j
    _so3_log(q_err, r_out + 3);
}

// Apply a 6-DOF perturbation in-place to (t, q).
static void _apply_local(double *t, double *q, const double *delta) {
    t[0] += delta[0]; t[1] += delta[1]; t[2] += delta[2];
    double dq[4]; _so3_exp(delta + 3, dq);
    double q_new[4]; _q_mul(q, dq, q_new);
    q[0] = q_new[0]; q[1] = q_new[1]; q[2] = q_new[2]; q[3] = q_new[3];
    _q_normalize(q);
}

// Same as _apply_local but writes to a new buffer (doesn't touch original).
static void _perturb_into(const double *t, const double *q, const double *delta,
                          double *t_out, double *q_out)
{
    t_out[0] = t[0] + delta[0];
    t_out[1] = t[1] + delta[1];
    t_out[2] = t[2] + delta[2];
    double dq[4]; _so3_exp(delta + 3, dq);
    _q_mul(q, dq, q_out);
    _q_normalize(q_out);
}

// Numerical Jacobians J_i (6×6) and J_j (6×6) of the edge residual
// w.r.t. the local 6-DOF perturbation of nodes i and j respectively.
static void _edge_jacobians(const double *t_i, const double *q_i,
                            const double *t_j, const double *q_j,
                            const double *dt_meas, const double *dq_meas,
                            double *J_i, double *J_j)
{
    double eps = 1e-6;
    double r_p[6], r_m[6];
    double tp[3], qp[4];
    double delta[6];
    for (int k = 0; k < 6; k++) {
        for (int kk = 0; kk < 6; kk++) delta[kk] = 0;
        delta[k] = eps;
        _perturb_into(t_i, q_i, delta, tp, qp);
        _edge_residual(tp, qp, t_j, q_j, dt_meas, dq_meas, r_p);
        delta[k] = -eps;
        _perturb_into(t_i, q_i, delta, tp, qp);
        _edge_residual(tp, qp, t_j, q_j, dt_meas, dq_meas, r_m);
        for (int r = 0; r < 6; r++) J_i[r*6 + k] = (r_p[r] - r_m[r]) / (2.0 * eps);
    }
    for (int k = 0; k < 6; k++) {
        for (int kk = 0; kk < 6; kk++) delta[kk] = 0;
        delta[k] = eps;
        _perturb_into(t_j, q_j, delta, tp, qp);
        _edge_residual(t_i, q_i, tp, qp, dt_meas, dq_meas, r_p);
        delta[k] = -eps;
        _perturb_into(t_j, q_j, delta, tp, qp);
        _edge_residual(t_i, q_i, tp, qp, dt_meas, dq_meas, r_m);
        for (int r = 0; r < 6; r++) J_j[r*6 + k] = (r_p[r] - r_m[r]) / (2.0 * eps);
    }
}

long long nuc_pgs3_optimize(long long h, long long max_iters, long long tol_b) {
    NPGS3 *p = (NPGS3 *)(void *)(size_t)h;
    if (!p || p->n_nodes < 2) return -1;
    int N = p->n_nodes;
    int dof = 6 * (N - 1);
    double tol = _i2f(tol_b);

    double *H_mat = (double *)calloc(dof * dof, sizeof(double));
    double *b_vec = (double *)calloc(dof, sizeof(double));
    double *Hinv  = (double *)malloc(dof * dof * sizeof(double));
    double *delta = (double *)malloc(dof * sizeof(double));
    double J_i[36], J_j[36];
    double r0[6];

    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        memset(H_mat, 0, dof * dof * sizeof(double));
        memset(b_vec, 0, dof * sizeof(double));

        for (int e_idx = 0; e_idx < p->n_edges; e_idx++) {
            _PGS3Edge *e = &p->edges[e_idx];
            double *ni = p->nodes + e->i * 7;
            double *nj = p->nodes + e->j * 7;
            double *t_i = ni, *q_i = ni + 3;
            double *t_j = nj, *q_j = nj + 3;

            _edge_residual(t_i, q_i, t_j, q_j, e->dt, e->dq, r0);
            _edge_jacobians(t_i, q_i, t_j, q_j, e->dt, e->dq, J_i, J_j);

            int gi = (e->i == 0) ? -1 : 6 * (e->i - 1);
            int gj = (e->j == 0) ? -1 : 6 * (e->j - 1);

            // Per-DOF diagonal info weights.
            const double *Om = e->info;

            // Accumulate H[a,b] += J_aᵀ · diag(Ω) · J_b   and
            //              b[a] += J_aᵀ · diag(Ω) · r0.
            if (gi >= 0) {
                for (int r = 0; r < 6; r++) {
                    for (int c = 0; c < 6; c++) {
                        double s = 0;
                        for (int k = 0; k < 6; k++) s += J_i[k*6 + r] * Om[k] * J_i[k*6 + c];
                        H_mat[(gi+r)*dof + (gi+c)] += s;
                    }
                    double s = 0;
                    for (int k = 0; k < 6; k++) s += J_i[k*6 + r] * Om[k] * r0[k];
                    b_vec[gi + r] += s;
                }
            }
            if (gj >= 0) {
                for (int r = 0; r < 6; r++) {
                    for (int c = 0; c < 6; c++) {
                        double s = 0;
                        for (int k = 0; k < 6; k++) s += J_j[k*6 + r] * Om[k] * J_j[k*6 + c];
                        H_mat[(gj+r)*dof + (gj+c)] += s;
                    }
                    double s = 0;
                    for (int k = 0; k < 6; k++) s += J_j[k*6 + r] * Om[k] * r0[k];
                    b_vec[gj + r] += s;
                }
            }
            if (gi >= 0 && gj >= 0) {
                for (int r = 0; r < 6; r++) {
                    for (int c = 0; c < 6; c++) {
                        double s = 0;
                        for (int k = 0; k < 6; k++) s += J_i[k*6 + r] * Om[k] * J_j[k*6 + c];
                        H_mat[(gi+r)*dof + (gj+c)] += s;
                        H_mat[(gj+c)*dof + (gi+r)] += s;
                    }
                }
            }
        }

        // LM-style damping.
        for (int i = 0; i < dof; i++) H_mat[i*dof + i] += 1e-9;

        if (!_gj_inv(H_mat, dof, Hinv)) break;
        for (int i = 0; i < dof; i++) {
            double s = 0;
            for (int j = 0; j < dof; j++) s += Hinv[i*dof + j] * b_vec[j];
            delta[i] = -s;
        }

        double max_step = 0;
        for (int n = 1; n < N; n++) {
            int g = 6 * (n - 1);
            _apply_local(p->nodes + n*7, p->nodes + n*7 + 3, delta + g);
            for (int k = 0; k < 6; k++) {
                double v = fabs(delta[g + k]);
                if (v > max_step) max_step = v;
            }
        }
        if (max_step < tol) { iter++; break; }
    }

    free(H_mat); free(b_vec); free(Hinv); free(delta);
    return iter;
}

// === Huber-robust 3D PGS optimizer (v0.2.284) ===
//
// Same SE(3) Gauss-Newton iteration as nuc_pgs3_optimize, with
// per-edge Huber down-weighting in IRLS form:
//   r²    = Σ_k r0[k]² · info[k]    (info-weighted 6-D residual norm²)
//   w     = 1               if r² ≤ δ²
//   w     = δ / sqrt(r²)    if r² > δ²
// Edge contributions to H and b are scaled by w. `delta_b` is the
// Huber threshold; pass 0 to disable (matches `nuc_pgs3_optimize`).
//
// Same "Huber reverts to L2 once below threshold" caveat as
// `pgs.nr`'s 2D Huber — for stronger rejection consider a Cauchy
// kernel (planned for v0.6 on 3D).
long long nuc_pgs3_optimize_huber(long long h, long long max_iters, long long tol_b,
                                   long long delta_b)
{
    NPGS3 *p = (NPGS3 *)(void *)(size_t)h;
    if (!p || p->n_nodes < 2) return -1;
    int N = p->n_nodes;
    int dof = 6 * (N - 1);
    double tol = _i2f(tol_b);
    double delta = _i2f(delta_b);
    double delta2 = (delta > 0) ? delta * delta : 0.0;

    double *H_mat = (double *)calloc(dof * dof, sizeof(double));
    double *b_vec = (double *)calloc(dof, sizeof(double));
    double *Hinv  = (double *)malloc(dof * dof * sizeof(double));
    double *delta_v = (double *)malloc(dof * sizeof(double));
    double J_i[36], J_j[36];
    double r0[6];

    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        memset(H_mat, 0, dof * dof * sizeof(double));
        memset(b_vec, 0, dof * sizeof(double));

        for (int e_idx = 0; e_idx < p->n_edges; e_idx++) {
            _PGS3Edge *e = &p->edges[e_idx];
            double *ni = p->nodes + e->i * 7;
            double *nj = p->nodes + e->j * 7;
            double *t_i = ni, *q_i = ni + 3;
            double *t_j = nj, *q_j = nj + 3;

            _edge_residual(t_i, q_i, t_j, q_j, e->dt, e->dq, r0);
            _edge_jacobians(t_i, q_i, t_j, q_j, e->dt, e->dq, J_i, J_j);

            int gi = (e->i == 0) ? -1 : 6 * (e->i - 1);
            int gj = (e->j == 0) ? -1 : 6 * (e->j - 1);

            // Information-weighted residual norm²
            double r2 = 0;
            for (int k = 0; k < 6; k++) r2 += r0[k] * r0[k] * e->info[k];
            double w = 1.0;
            if (delta > 0 && r2 > delta2) w = delta / sqrt(r2);

            double Om[6];
            for (int k = 0; k < 6; k++) Om[k] = w * e->info[k];

            if (gi >= 0) {
                for (int r = 0; r < 6; r++) {
                    for (int c = 0; c < 6; c++) {
                        double s = 0;
                        for (int k = 0; k < 6; k++) s += J_i[k*6 + r] * Om[k] * J_i[k*6 + c];
                        H_mat[(gi+r)*dof + (gi+c)] += s;
                    }
                    double s = 0;
                    for (int k = 0; k < 6; k++) s += J_i[k*6 + r] * Om[k] * r0[k];
                    b_vec[gi + r] += s;
                }
            }
            if (gj >= 0) {
                for (int r = 0; r < 6; r++) {
                    for (int c = 0; c < 6; c++) {
                        double s = 0;
                        for (int k = 0; k < 6; k++) s += J_j[k*6 + r] * Om[k] * J_j[k*6 + c];
                        H_mat[(gj+r)*dof + (gj+c)] += s;
                    }
                    double s = 0;
                    for (int k = 0; k < 6; k++) s += J_j[k*6 + r] * Om[k] * r0[k];
                    b_vec[gj + r] += s;
                }
            }
            if (gi >= 0 && gj >= 0) {
                for (int r = 0; r < 6; r++) {
                    for (int c = 0; c < 6; c++) {
                        double s = 0;
                        for (int k = 0; k < 6; k++) s += J_i[k*6 + r] * Om[k] * J_j[k*6 + c];
                        H_mat[(gi+r)*dof + (gj+c)] += s;
                        H_mat[(gj+c)*dof + (gi+r)] += s;
                    }
                }
            }
        }

        for (int i = 0; i < dof; i++) H_mat[i*dof + i] += 1e-9;
        if (!_gj_inv(H_mat, dof, Hinv)) break;
        for (int i = 0; i < dof; i++) {
            double s = 0;
            for (int j = 0; j < dof; j++) s += Hinv[i*dof + j] * b_vec[j];
            delta_v[i] = -s;
        }

        double max_step = 0;
        for (int n = 1; n < N; n++) {
            int g = 6 * (n - 1);
            _apply_local(p->nodes + n*7, p->nodes + n*7 + 3, delta_v + g);
            for (int k = 0; k < 6; k++) {
                double v = fabs(delta_v[g + k]);
                if (v > max_step) max_step = v;
            }
        }
        if (max_step < tol) { iter++; break; }
    }

    free(H_mat); free(b_vec); free(Hinv); free(delta_v);
    return iter;
}

long long nuc_pgs3_total_cost(long long h) {
    NPGS3 *p = (NPGS3 *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double total = 0;
    double r[6];
    for (int e_idx = 0; e_idx < p->n_edges; e_idx++) {
        _PGS3Edge *e = &p->edges[e_idx];
        double *ni = p->nodes + e->i * 7;
        double *nj = p->nodes + e->j * 7;
        _edge_residual(ni, ni + 3, nj, nj + 3, e->dt, e->dq, r);
        for (int k = 0; k < 6; k++) total += r[k] * r[k] * e->info[k];
    }
    return _f2i(total);
}

void nuc_pgs3_free(long long h) {
    NPGS3 *p = (NPGS3 *)(void *)(size_t)h;
    if (!p) return;
    if (p->nodes) free(p->nodes);
    if (p->edges) free(p->edges);
    free(p);
}
