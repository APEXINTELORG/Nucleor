// hwbc_rt.c — Hierarchical (strict-priority) whole-body controller
// via Siciliano-Slotine null-space projection (Siciliano & Slotine
// 1991).
//
// Where `wbc.nr` solves a single weighted QP that gives all tasks
// soft priorities, this rod processes tasks in **strict** priority
// order: each subsequent task is constrained to the null space of
// all higher-priority Jacobians, so it can never undo or compromise
// a higher-priority task — only refine within the residual freedom.
//
// Algorithm (per control tick):
//   q̇₀ = 0,  N₀ = I_n
//   for i = 1..K (priority order, 1 = highest):
//     J̃_i = J_i · N_{i-1}                 (effective Jacobian)
//     Δq̇ = J̃_i⁺ · (ẋ_i_des − J_i · q̇_{i-1})
//     q̇_i = q̇_{i-1} + Δq̇
//     N_i = N_{i-1} − J̃_i⁺ · J̃_i        (null-space projector)
//   return q̇_K
//
// Pseudoinverse is damped least-squares for numerical stability:
//   A⁺ = Aᵀ · (A · Aᵀ + λ · I)⁻¹
//
// Use this rod when you need ABSOLUTE task ordering (e.g. balance
// must never be sacrificed for reach). Use `wbc.nr` (weighted QP)
// when soft tradeoffs are acceptable — the implementation is
// simpler and converges faster, and weighted QPs handle near-
// singular task stacks more gracefully.
//
// **Limitations** (constrained QP per task / box constraints / SVD-
// based null-space land in v0.6 if needed):
// - Numerical-FD-free closed form. The damped pseudoinverse is the
//   simplest stable variant; SVD-based truncation handles rank-
//   deficient stacks more robustly.
// - No box constraints on q̇.
// - Assembled with dense matrices throughout — fine for n_dof ≤ ~30.
//
// Compile: clang -c stdlib/runtime/hwbc_rt.c -o target/hwbc.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int m;
    double *J;       // m × n_dof
    double *x_des;   // m
} _HWBCTask;

typedef struct {
    int n_dof;
    double damping;
    int n_tasks, cap_tasks;
    _HWBCTask *tasks;
    double *qdot;    // n_dof — final solution
    int solved;
} NHWBC;

// === Linear algebra ===

static int _gj_inv(const double *A, int n, double *Ainv) {
    int aw = 2*n;
    double *aug = (double *)malloc((size_t)n * aw * sizeof(double));
    for (int i=0;i<n;i++){
        for (int j=0;j<n;j++) aug[i*aw+j] = A[i*n+j];
        for (int j=0;j<n;j++) aug[i*aw+n+j] = (i==j)?1.0:0.0;
    }
    for (int i=0;i<n;i++){
        int piv=i;
        for (int r=i+1;r<n;r++) if (fabs(aug[r*aw+i])>fabs(aug[piv*aw+i])) piv=r;
        if (fabs(aug[piv*aw+i])<1e-14){ free(aug); return 0; }
        if (piv!=i) for (int j=0;j<aw;j++){ double t=aug[i*aw+j]; aug[i*aw+j]=aug[piv*aw+j]; aug[piv*aw+j]=t; }
        double inv = 1.0/aug[i*aw+i];
        for (int j=0;j<aw;j++) aug[i*aw+j]*=inv;
        for (int r=0;r<n;r++){
            if (r==i) continue;
            double f = aug[r*aw+i];
            for (int j=0;j<aw;j++) aug[r*aw+j] -= f*aug[i*aw+j];
        }
    }
    for (int i=0;i<n;i++) for (int j=0;j<n;j++) Ainv[i*n+j] = aug[i*aw+n+j];
    free(aug);
    return 1;
}

// C = A·B  with shapes (ar × ac)·(ac × bc) = (ar × bc).
static void _mm(const double *A, int ar, int ac, const double *B, int bc, double *C) {
    for (int i = 0; i < ar; i++) {
        for (int j = 0; j < bc; j++) {
            double s = 0;
            for (int k = 0; k < ac; k++) s += A[i*ac+k] * B[k*bc+j];
            C[i*bc+j] = s;
        }
    }
}
// C = Aᵀ·B  shapes (ac × ar)·(ar × bc) = (ac × bc).
static void _mmTN(const double *A, int ar, int ac, const double *B, int bc, double *C) {
    for (int i = 0; i < ac; i++) {
        for (int j = 0; j < bc; j++) {
            double s = 0;
            for (int k = 0; k < ar; k++) s += A[k*ac+i] * B[k*bc+j];
            C[i*bc+j] = s;
        }
    }
}
// y = A·x  with A (m × n).
static void _mv(const double *A, int m, int n, const double *x, double *y) {
    for (int i = 0; i < m; i++) {
        double s = 0;
        for (int j = 0; j < n; j++) s += A[i*n+j] * x[j];
        y[i] = s;
    }
}

// === API ===

long long nuc_hwbc_new(long long n_dof_, long long damping_b) {
    int n = (int)n_dof_;
    if (n <= 0) return 0;
    NHWBC *p = (NHWBC *)calloc(1, sizeof(NHWBC));
    p->n_dof = n;
    double d = _i2f(damping_b);
    p->damping = (d > 0) ? d : 1e-3;
    p->cap_tasks = 8;
    p->tasks = (_HWBCTask *)calloc(p->cap_tasks, sizeof(_HWBCTask));
    p->qdot = (double *)calloc(n, sizeof(double));
    return (long long)(size_t)p;
}

void nuc_hwbc_set_damping(long long h, long long damping_b) {
    NHWBC *p = (NHWBC *)(void *)(size_t)h;
    if (!p) return;
    double d = _i2f(damping_b);
    if (d > 0) p->damping = d;
}

void nuc_hwbc_clear_tasks(long long h) {
    NHWBC *p = (NHWBC *)(void *)(size_t)h;
    if (!p) return;
    for (int t = 0; t < p->n_tasks; t++) {
        if (p->tasks[t].J)     free(p->tasks[t].J);
        if (p->tasks[t].x_des) free(p->tasks[t].x_des);
    }
    p->n_tasks = 0;
    p->solved = 0;
}

// Task added in priority order: first added = highest priority.
long long nuc_hwbc_add_task(long long h, long long J_ptr, long long x_des_ptr, long long n_rows_) {
    NHWBC *p = (NHWBC *)(void *)(size_t)h;
    if (!p) return -1;
    int m = (int)n_rows_;
    if (m <= 0) return -1;
    double *J_in = (double *)(void *)(size_t)J_ptr;
    double *x_in = (double *)(void *)(size_t)x_des_ptr;
    if (!J_in || !x_in) return -1;
    if (p->n_tasks >= p->cap_tasks) {
        p->cap_tasks *= 2;
        p->tasks = (_HWBCTask *)realloc(p->tasks, p->cap_tasks * sizeof(_HWBCTask));
    }
    _HWBCTask *t = &p->tasks[p->n_tasks];
    t->m = m;
    int sz_J = m * p->n_dof;
    t->J = (double *)malloc(sz_J * sizeof(double));
    memcpy(t->J, J_in, sz_J * sizeof(double));
    t->x_des = (double *)malloc(m * sizeof(double));
    memcpy(t->x_des, x_in, m * sizeof(double));
    p->solved = 0;
    return (long long)(p->n_tasks++);
}

long long nuc_hwbc_solve(long long h) {
    NHWBC *p = (NHWBC *)(void *)(size_t)h;
    if (!p) return 0;
    int n = p->n_dof;

    // Initialize: q̇ = 0,  N = I.
    for (int i = 0; i < n; i++) p->qdot[i] = 0;
    double *N = (double *)malloc((size_t)n * n * sizeof(double));
    memset(N, 0, (size_t)n * n * sizeof(double));
    for (int i = 0; i < n; i++) N[i*n + i] = 1.0;

    int ok = 1;
    for (int t = 0; t < p->n_tasks; t++) {
        _HWBCTask *T = &p->tasks[t];
        int m = T->m;

        // J̃ = J · N           (m × n)
        double *Jt = (double *)malloc((size_t)m * n * sizeof(double));
        _mm(T->J, m, n, N, n, Jt);

        // res = ẋ_des − J · q̇_{i-1}     (m)
        double *Jq = (double *)malloc(m * sizeof(double));
        _mv(T->J, m, n, p->qdot, Jq);
        double *res = (double *)malloc(m * sizeof(double));
        for (int i = 0; i < m; i++) res[i] = T->x_des[i] - Jq[i];

        // M = J̃ · J̃ᵀ + λ I    (m × m).
        // Track the Frobenius norm² of J̃ first; if it is dwarfed
        // by the would-be damping (i.e. J̃ has no significant
        // projection into the current null space), skip this task —
        // otherwise the damped pseudoinverse becomes a near-infinite
        // gain that wipes out higher-priority tasks via numerical
        // imprecision in the null-space projector.
        double *M = (double *)malloc((size_t)m * m * sizeof(double));
        double Jt_fro2 = 0;
        for (int i = 0; i < m; i++) {
            for (int j = 0; j < m; j++) {
                double s = 0;
                for (int k = 0; k < n; k++) s += Jt[i*n + k] * Jt[j*n + k];
                M[i*m + j] = s + (i == j ? p->damping : 0.0);
                if (i == j) Jt_fro2 += s;     // sum of diag(J̃·J̃ᵀ) = ‖J̃‖_F²
            }
        }
        // Threshold: if the available signal ‖J̃‖_F² is < (small) ·
        // damping, treat the task as unrepresentable in this null
        // space and skip its update entirely.
        if (Jt_fro2 < 1e-8 * p->damping) {
            free(Jt); free(Jq); free(res); free(M);
            continue;
        }
        double *Minv = (double *)malloc((size_t)m * m * sizeof(double));
        if (!_gj_inv(M, m, Minv)) {
            free(Jt); free(Jq); free(res); free(M); free(Minv);
            ok = 0; break;
        }

        // step = J̃ᵀ · Minv · res    (n)
        double *Mres = (double *)malloc(m * sizeof(double));
        _mv(Minv, m, m, res, Mres);
        // step[j] = sum over i of Jt[i*n+j] * Mres[i]
        for (int j = 0; j < n; j++) {
            double s = 0;
            for (int i = 0; i < m; i++) s += Jt[i*n + j] * Mres[i];
            p->qdot[j] += s;
        }

        // Update null-space projector:
        //   N ← N − J̃⁺ · J̃ = N − J̃ᵀ · Minv · J̃   (n × n)
        // Compute Minv · J̃ first (m × n).
        double *MinvJt = (double *)malloc((size_t)m * n * sizeof(double));
        _mm(Minv, m, m, Jt, n, MinvJt);
        // Subtract J̃ᵀ · MinvJt from N.
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
                double s = 0;
                for (int k = 0; k < m; k++) s += Jt[k*n + i] * MinvJt[k*n + j];
                N[i*n + j] -= s;
            }
        }

        free(Jt); free(Jq); free(res); free(M); free(Minv); free(Mres); free(MinvJt);
    }

    free(N);
    p->solved = ok;
    return ok ? 1 : 0;
}

long long nuc_hwbc_get_qdot(long long h, long long i) {
    NHWBC *p = (NHWBC *)(void *)(size_t)h;
    if (!p || i < 0 || i >= p->n_dof) return _f2i(0.0);
    return _f2i(p->qdot[i]);
}

long long nuc_hwbc_task_residual(long long h, long long task_id_) {
    NHWBC *p = (NHWBC *)(void *)(size_t)h;
    if (!p || !p->solved) return _f2i(0.0);
    int t = (int)task_id_;
    if (t < 0 || t >= p->n_tasks) return _f2i(0.0);
    _HWBCTask *T = &p->tasks[t];
    double s = 0;
    for (int k = 0; k < T->m; k++) {
        double r = -T->x_des[k];
        for (int j = 0; j < p->n_dof; j++) r += T->J[k*p->n_dof + j] * p->qdot[j];
        s += r * r;
    }
    return _f2i(sqrt(s));
}

void nuc_hwbc_free(long long h) {
    NHWBC *p = (NHWBC *)(void *)(size_t)h;
    if (!p) return;
    if (p->tasks) {
        for (int t = 0; t < p->n_tasks; t++) {
            if (p->tasks[t].J)     free(p->tasks[t].J);
            if (p->tasks[t].x_des) free(p->tasks[t].x_des);
        }
        free(p->tasks);
    }
    if (p->qdot) free(p->qdot);
    free(p);
}
