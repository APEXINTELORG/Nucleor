// pgs_rt.c — 2D pose graph SLAM optimizer (Gauss-Newton).
//
// Standard SLAM back-end: minimize the sum of squared edge errors
// over a graph of relative-pose constraints between robot poses.
//
//   Nodes: robot poses p_i = (x_i, y_i, θ_i)
//   Edges: relative measurements z_ij with information matrix Ω
//          (typically inverse of the measurement covariance)
//
//   Cost = Σ e_ij^T · Ω · e_ij   where  e_ij = inv(p_i) ⊞ p_j ⊟ z_ij
//
// In 2D, the pose-composition operator ⊞ is rigid-body composition;
// the residual e_ij is the difference between the predicted relative
// pose (from current node estimates) and the measurement z_ij,
// expressed in node i's frame.
//
// Algorithm: Gauss-Newton iterations.
//   1. Linearize each edge residual around current estimates.
//   2. Build the sparse normal equations H·δx = -b from the Jacobians.
//      (Implemented as dense H here — fine for ≤ 200 nodes; for big
//      graphs, the v0.6 sparse-Cholesky variant scales further.)
//   3. Solve for δx, apply to nodes (skipping the gauge-fixed node 0).
//   4. Repeat until ‖δx‖ drops below tolerance.
//
// Foundation for SLAM systems where:
// - The front-end (e.g., scan-matching, visual odometry) produces
//   relative-pose measurements between poses.
// - Loop closures introduce additional edges between non-adjacent
//   poses, fixing accumulated drift.
//
// **Limitations** (3D pose graphs / sparse Cholesky / robust-cost
// kernels land in v0.6 if needed):
// - 2D only (3D extension uses quaternions + 6-DOF residuals).
// - Dense linear solve via Gauss-Jordan: O(n³) per iter. Fine for
//   n ≤ 200; for large graphs, sparse Cholesky is required.
// - L₂ cost only — no robust kernels (Huber, Cauchy) for outlier
//   rejection.
//
// Compile: clang -c stdlib/runtime/pgs_rt.c -o target/pgs.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int i, j;                  // node indices
    double dx, dy, dtheta;     // measured relative pose (j in i's frame)
    double info_xx, info_yy, info_tt;  // diagonal information weights
} _PGSEdge;

typedef struct {
    int n_nodes;
    int cap_nodes;
    double *nodes;             // n_nodes × 3 (x, y, θ)
    int n_edges;
    int cap_edges;
    _PGSEdge *edges;
} NPGS;

// In-place Gauss-Jordan inverse (n×n).
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
            double a1 = fabs(aug[r*aug_w + i]);
            double a2 = fabs(aug[piv*aug_w + i]);
            if (a1 > a2) piv = r;
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

long long nuc_pgs_new(long long n_nodes) {
    int n = (int)n_nodes;
    if (n <= 0) return 0;
    NPGS *p = (NPGS *)calloc(1, sizeof(NPGS));
    p->n_nodes = n;
    p->cap_nodes = n;
    p->nodes = (double *)calloc(n * 3, sizeof(double));
    p->cap_edges = 16;
    p->edges = (_PGSEdge *)calloc(p->cap_edges, sizeof(_PGSEdge));
    return (long long)(size_t)p;
}

void nuc_pgs_set_node(long long h, long long i,
    long long x_b, long long y_b, long long theta_b)
{
    NPGS *p = (NPGS *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n_nodes) return;
    p->nodes[i*3+0] = _i2f(x_b);
    p->nodes[i*3+1] = _i2f(y_b);
    p->nodes[i*3+2] = _i2f(theta_b);
}

void nuc_pgs_get_node(long long h, long long i,
    long long x_out_ptr, long long y_out_ptr, long long theta_out_ptr)
{
    NPGS *p = (NPGS *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n_nodes) return;
    double *xo = (double *)(void *)(size_t)x_out_ptr;
    double *yo = (double *)(void *)(size_t)y_out_ptr;
    double *to = (double *)(void *)(size_t)theta_out_ptr;
    if (xo) *xo = p->nodes[i*3+0];
    if (yo) *yo = p->nodes[i*3+1];
    if (to) *to = p->nodes[i*3+2];
}

long long nuc_pgs_add_edge(long long h, long long i, long long j,
    long long dx_b, long long dy_b, long long dtheta_b,
    long long info_xx_b, long long info_yy_b, long long info_tt_b)
{
    NPGS *p = (NPGS *)(void *)(size_t)h;
    if (!p) return -1;
    if (i < 0 || i >= (long long)p->n_nodes) return -1;
    if (j < 0 || j >= (long long)p->n_nodes) return -1;
    if (i == j) return -1;
    if (p->n_edges >= p->cap_edges) {
        p->cap_edges *= 2;
        p->edges = (_PGSEdge *)realloc(p->edges, p->cap_edges * sizeof(_PGSEdge));
    }
    _PGSEdge *e = &p->edges[p->n_edges];
    e->i = (int)i;
    e->j = (int)j;
    e->dx = _i2f(dx_b);
    e->dy = _i2f(dy_b);
    e->dtheta = _i2f(dtheta_b);
    e->info_xx = _i2f(info_xx_b);
    e->info_yy = _i2f(info_yy_b);
    e->info_tt = _i2f(info_tt_b);
    return (long long)(p->n_edges++);
}

// Wrap angle to [-π, π].
static double _wrap_angle(double a) {
    while (a >  M_PI) a -= 2.0 * M_PI;
    while (a < -M_PI) a += 2.0 * M_PI;
    return a;
}

// Run Gauss-Newton iterations. Node 0 is gauge-fixed (never moves)
// to break the global rigid-motion ambiguity. Returns the number of
// iterations actually performed.
long long nuc_pgs_optimize(long long h, long long max_iters, long long tol_b) {
    NPGS *p = (NPGS *)(void *)(size_t)h;
    if (!p || p->n_nodes < 2) return -1;
    int N = p->n_nodes;
    int dof = 3 * (N - 1);     // node 0 fixed
    double tol = _i2f(tol_b);

    double *H_mat = (double *)calloc(dof * dof, sizeof(double));
    double *b_vec = (double *)calloc(dof, sizeof(double));
    double *Hinv  = (double *)malloc(dof * dof * sizeof(double));
    double *delta = (double *)malloc(dof * sizeof(double));

    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        memset(H_mat, 0, dof * dof * sizeof(double));
        memset(b_vec, 0, dof * sizeof(double));

        for (int e_idx = 0; e_idx < p->n_edges; e_idx++) {
            _PGSEdge *e = &p->edges[e_idx];
            double xi = p->nodes[e->i*3+0], yi = p->nodes[e->i*3+1], ti = p->nodes[e->i*3+2];
            double xj = p->nodes[e->j*3+0], yj = p->nodes[e->j*3+1], tj = p->nodes[e->j*3+2];
            double si = sin(ti), ci = cos(ti);

            // Predicted relative pose: j in i's frame.
            //   p_pred = inv(p_i) · p_j
            //   p_pred.x = ci·(xj−xi) + si·(yj−yi)
            //   p_pred.y = −si·(xj−xi) + ci·(yj−yi)
            //   p_pred.t = tj − ti
            double dx_pred = ci*(xj-xi) + si*(yj-yi);
            double dy_pred = -si*(xj-xi) + ci*(yj-yi);
            double dt_pred = tj - ti;

            // Residual e = p_pred − z (in node i's frame).
            double er_x = dx_pred - e->dx;
            double er_y = dy_pred - e->dy;
            double er_t = _wrap_angle(dt_pred - e->dtheta);

            // Jacobians wrt node i (3 cols) and node j (3 cols).
            // For 2D pose graph (Grisetti et al. tutorial form):
            //   ∂er/∂xi = [-ci, -si, -si·(xj-xi) + ci·(yj-yi)]
            //   ∂er/∂yi = [ si, -ci, -ci·(xj-xi) - si·(yj-yi)]
            //   ∂er/∂ti = [  0,   0,   -1                  ]
            //   ∂er/∂xj = [ ci,  si,    0]
            //   ∂er/∂yj = [-si,  ci,    0]
            //   ∂er/∂tj = [  0,   0,    1]
            double dxd = xj - xi, dyd = yj - yi;
            // Build per-node 3×3 Jacobian blocks.
            // A_i[3][3]: rows index residual, cols index pose params.
            double A_i[3][3] = {
                { -ci,  -si,  -si*dxd + ci*dyd },
                {  si,  -ci,  -ci*dxd - si*dyd },
                {  0,    0,   -1                }
            };
            double A_j[3][3] = {
                {  ci,   si,   0 },
                { -si,   ci,   0 },
                {  0,    0,    1 }
            };
            double Omega[3] = { e->info_xx, e->info_yy, e->info_tt };  // diag

            // Helper indices: node i contributes to global indices
            // 3*(e->i - 1)..3*(e->i - 1)+2 if e->i > 0; node 0 is fixed.
            int gi = (e->i == 0) ? -1 : 3 * (e->i - 1);
            int gj = (e->j == 0) ? -1 : 3 * (e->j - 1);

            // For each pair (a, b) of involved nodes, accumulate
            // H[a, b] += A_aᵀ · Ω · A_b   and   b[a] += A_aᵀ · Ω · er.
            // Inline both i-i, i-j, j-i, j-j blocks (skip rows for fixed nodes).

            // i-i block.
            if (gi >= 0) {
                for (int r = 0; r < 3; r++)
                    for (int c = 0; c < 3; c++) {
                        double s = 0;
                        for (int k = 0; k < 3; k++) s += A_i[k][r] * Omega[k] * A_i[k][c];
                        H_mat[(gi + r) * dof + (gi + c)] += s;
                    }
                for (int r = 0; r < 3; r++) {
                    double s = 0;
                    s += A_i[0][r] * Omega[0] * er_x;
                    s += A_i[1][r] * Omega[1] * er_y;
                    s += A_i[2][r] * Omega[2] * er_t;
                    b_vec[gi + r] += s;
                }
            }
            // j-j block.
            if (gj >= 0) {
                for (int r = 0; r < 3; r++)
                    for (int c = 0; c < 3; c++) {
                        double s = 0;
                        for (int k = 0; k < 3; k++) s += A_j[k][r] * Omega[k] * A_j[k][c];
                        H_mat[(gj + r) * dof + (gj + c)] += s;
                    }
                for (int r = 0; r < 3; r++) {
                    double s = 0;
                    s += A_j[0][r] * Omega[0] * er_x;
                    s += A_j[1][r] * Omega[1] * er_y;
                    s += A_j[2][r] * Omega[2] * er_t;
                    b_vec[gj + r] += s;
                }
            }
            // i-j and j-i blocks.
            if (gi >= 0 && gj >= 0) {
                for (int r = 0; r < 3; r++)
                    for (int c = 0; c < 3; c++) {
                        double s = 0;
                        for (int k = 0; k < 3; k++) s += A_i[k][r] * Omega[k] * A_j[k][c];
                        H_mat[(gi + r) * dof + (gj + c)] += s;
                        H_mat[(gj + c) * dof + (gi + r)] += s;
                    }
            }
        }

        // Add small Levenberg-Marquardt-style damping to H to keep
        // the linear solve stable when some nodes are under-
        // constrained.
        for (int i = 0; i < dof; i++) H_mat[i*dof + i] += 1e-9;

        if (!_gj_inv(H_mat, dof, Hinv)) break;
        // δx = -Hinv · b.
        for (int i = 0; i < dof; i++) {
            double s = 0;
            for (int j = 0; j < dof; j++) s += Hinv[i*dof + j] * b_vec[j];
            delta[i] = -s;
        }

        // Apply update; track magnitude for convergence.
        double max_step = 0;
        for (int i = 1; i < N; i++) {
            int g = 3 * (i - 1);
            p->nodes[i*3+0] += delta[g + 0];
            p->nodes[i*3+1] += delta[g + 1];
            p->nodes[i*3+2] = _wrap_angle(p->nodes[i*3+2] + delta[g + 2]);
            for (int k = 0; k < 3; k++) {
                double v = fabs(delta[g + k]);
                if (v > max_step) max_step = v;
            }
        }
        if (max_step < tol) { iter++; break; }
    }

    free(H_mat); free(b_vec); free(Hinv); free(delta);
    return iter;
}

// === Huber-robust optimize variant (v0.2.277) ===
//
// Same Gauss-Newton iteration as nuc_pgs_optimize, but each edge's
// contribution is down-weighted using the Huber loss:
//
//   ρ_δ(e) = ½ e²              if |e| ≤ δ
//          = δ (|e| − ½ δ)      otherwise
//
// In iteratively-reweighted least squares (IRLS) form, this means
// scaling H and b accumulations by w_i = 1 if |e_i|² ≤ δ²; else
// w_i = δ / |e_i|. This caps the influence of outliers (typically
// bad loop-closures) without dropping them outright.
//
// `delta_b` is the Huber threshold (typical 0.5–2.0 for distance
// residuals; tune to ~3σ of the noise model). Pass 0 to disable
// Huber and reduce to vanilla L2 (matches nuc_pgs_optimize).
//
// The residual norm² used for the weight is the FULL information-
// weighted residual: e^T Ω e.
long long nuc_pgs_optimize_huber(long long h, long long max_iters, long long tol_b,
                                  long long delta_b)
{
    NPGS *p = (NPGS *)(void *)(size_t)h;
    if (!p || p->n_nodes < 2) return -1;
    int N = p->n_nodes;
    int dof = 3 * (N - 1);
    double tol = _i2f(tol_b);
    double delta = _i2f(delta_b);
    double delta2 = (delta > 0) ? delta * delta : 0.0;

    double *H_mat = (double *)calloc(dof * dof, sizeof(double));
    double *b_vec = (double *)calloc(dof, sizeof(double));
    double *Hinv  = (double *)malloc(dof * dof * sizeof(double));
    double *delta_v = (double *)malloc(dof * sizeof(double));

    long long iter;
    for (iter = 0; iter < max_iters; iter++) {
        memset(H_mat, 0, dof * dof * sizeof(double));
        memset(b_vec, 0, dof * sizeof(double));

        for (int e_idx = 0; e_idx < p->n_edges; e_idx++) {
            _PGSEdge *e = &p->edges[e_idx];
            double xi = p->nodes[e->i*3+0], yi = p->nodes[e->i*3+1], ti = p->nodes[e->i*3+2];
            double xj = p->nodes[e->j*3+0], yj = p->nodes[e->j*3+1], tj = p->nodes[e->j*3+2];
            double si = sin(ti), ci = cos(ti);
            double dx_pred = ci*(xj-xi) + si*(yj-yi);
            double dy_pred = -si*(xj-xi) + ci*(yj-yi);
            double dt_pred = tj - ti;
            double er_x = dx_pred - e->dx;
            double er_y = dy_pred - e->dy;
            double er_t = _wrap_angle(dt_pred - e->dtheta);

            // Information-weighted residual norm²
            double r2 = er_x*er_x*e->info_xx + er_y*er_y*e->info_yy + er_t*er_t*e->info_tt;
            double w = 1.0;
            if (delta > 0 && r2 > delta2) {
                w = delta / sqrt(r2);
            }

            double dxd = xj - xi, dyd = yj - yi;
            double A_i[3][3] = {
                { -ci,  -si,  -si*dxd + ci*dyd },
                {  si,  -ci,  -ci*dxd - si*dyd },
                {  0,    0,   -1                }
            };
            double A_j[3][3] = {
                {  ci,   si,   0 },
                { -si,   ci,   0 },
                {  0,    0,    1 }
            };
            // Apply Huber weight to information directly.
            double Omega[3] = { w * e->info_xx, w * e->info_yy, w * e->info_tt };

            int gi = (e->i == 0) ? -1 : 3 * (e->i - 1);
            int gj = (e->j == 0) ? -1 : 3 * (e->j - 1);

            if (gi >= 0) {
                for (int r = 0; r < 3; r++)
                    for (int c = 0; c < 3; c++) {
                        double s = 0;
                        for (int k = 0; k < 3; k++) s += A_i[k][r] * Omega[k] * A_i[k][c];
                        H_mat[(gi + r) * dof + (gi + c)] += s;
                    }
                for (int r = 0; r < 3; r++) {
                    double s = 0;
                    s += A_i[0][r] * Omega[0] * er_x;
                    s += A_i[1][r] * Omega[1] * er_y;
                    s += A_i[2][r] * Omega[2] * er_t;
                    b_vec[gi + r] += s;
                }
            }
            if (gj >= 0) {
                for (int r = 0; r < 3; r++)
                    for (int c = 0; c < 3; c++) {
                        double s = 0;
                        for (int k = 0; k < 3; k++) s += A_j[k][r] * Omega[k] * A_j[k][c];
                        H_mat[(gj + r) * dof + (gj + c)] += s;
                    }
                for (int r = 0; r < 3; r++) {
                    double s = 0;
                    s += A_j[0][r] * Omega[0] * er_x;
                    s += A_j[1][r] * Omega[1] * er_y;
                    s += A_j[2][r] * Omega[2] * er_t;
                    b_vec[gj + r] += s;
                }
            }
            if (gi >= 0 && gj >= 0) {
                for (int r = 0; r < 3; r++)
                    for (int c = 0; c < 3; c++) {
                        double s = 0;
                        for (int k = 0; k < 3; k++) s += A_i[k][r] * Omega[k] * A_j[k][c];
                        H_mat[(gi + r) * dof + (gj + c)] += s;
                        H_mat[(gj + c) * dof + (gi + r)] += s;
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
        for (int i = 1; i < N; i++) {
            int g = 3 * (i - 1);
            p->nodes[i*3+0] += delta_v[g + 0];
            p->nodes[i*3+1] += delta_v[g + 1];
            p->nodes[i*3+2] = _wrap_angle(p->nodes[i*3+2] + delta_v[g + 2]);
            for (int k = 0; k < 3; k++) {
                double v = fabs(delta_v[g + k]);
                if (v > max_step) max_step = v;
            }
        }
        if (max_step < tol) { iter++; break; }
    }

    free(H_mat); free(b_vec); free(Hinv); free(delta_v);
    return iter;
}

// Total residual cost (sum of squared edge errors weighted by
// information). Useful for verifying convergence.
long long nuc_pgs_total_cost(long long h) {
    NPGS *p = (NPGS *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double total = 0;
    for (int e_idx = 0; e_idx < p->n_edges; e_idx++) {
        _PGSEdge *e = &p->edges[e_idx];
        double xi = p->nodes[e->i*3+0], yi = p->nodes[e->i*3+1], ti = p->nodes[e->i*3+2];
        double xj = p->nodes[e->j*3+0], yj = p->nodes[e->j*3+1], tj = p->nodes[e->j*3+2];
        double si = sin(ti), ci = cos(ti);
        double dx_pred = ci*(xj-xi) + si*(yj-yi);
        double dy_pred = -si*(xj-xi) + ci*(yj-yi);
        double dt_pred = tj - ti;
        double er_x = dx_pred - e->dx;
        double er_y = dy_pred - e->dy;
        double er_t = _wrap_angle(dt_pred - e->dtheta);
        total += er_x*er_x*e->info_xx + er_y*er_y*e->info_yy + er_t*er_t*e->info_tt;
    }
    return _f2i(total);
}

void nuc_pgs_free(long long h) {
    NPGS *p = (NPGS *)(void *)(size_t)h;
    if (!p) return;
    if (p->nodes) free(p->nodes);
    if (p->edges) free(p->edges);
    free(p);
}
