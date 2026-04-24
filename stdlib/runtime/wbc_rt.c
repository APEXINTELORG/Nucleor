// wbc_rt.c — Whole-body / multi-task controller (weighted QP).
//
// At each control tick, the robot has n joints with current
// configuration q ∈ ℝⁿ. The controller's job is to pick a
// joint-velocity command q̇ ∈ ℝⁿ (or torque, with appropriate
// substitution) that simultaneously realizes a stack of tasks —
// each task wanting some end-effector / body / CoM output to move
// at a desired rate.
//
// Each task is defined by:
//   - an output Jacobian J_i  ∈ ℝ^(m_i × n)
//   - a desired output rate ẋ_i ∈ ℝ^(m_i)
//   - a relative weight w_i > 0
//
// Weighted-QP formulation:
//
//   minimize  Σ_i w_i · ‖J_i · q̇ − ẋ_i‖²  +  α · ‖q̇‖²
//
// Closed form:
//
//   A = Σ_i w_i · J_iᵀ · J_i  +  α · I
//   b = Σ_i w_i · J_iᵀ · ẋ_i
//   q̇ = A⁻¹ · b
//
// `α` is a small Tikhonov regularizer that handles redundancy and
// rank deficiency without extra machinery (rotation around redundant
// joints is naturally pulled toward zero by the regularizer).
//
// Use cases: humanoid balance + reach (CoM task + hand position +
// posture regularizer), mobile-manipulator coordination (base
// motion + arm pose), redundant-arm IK with multiple objectives.
//
// **Limitations** (strict-priority hierarchy / box constraints /
// torque-level control land in v0.6 if needed):
// - Weighted QP gives soft priorities only — high weight ≠ strict
//   precedence. For absolute task ordering, use the Siciliano-
//   Slotine null-space projection method (planned for v0.6).
// - No joint velocity / acceleration / torque box constraints.
//   Adding them turns the problem into a constrained QP requiring
//   an active-set or interior-point solver (use `lcp.nr` for the
//   constrained-QP-as-LCP reduction in the meantime).
// - Velocity-level command only; torque-level control needs the
//   manipulator inertia matrix in the Jacobians.
//
// Compile: clang -c stdlib/runtime/wbc_rt.c -o target/wbc.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int m;            // task output dimension
    double weight;
    double *J;        // m × n_dof, row-major (caller-allocated; we copy)
    double *x_des;    // m
} _WBCTask;

typedef struct {
    int n_dof;
    double alpha;     // regularizer
    int n_tasks, cap_tasks;
    _WBCTask *tasks;
    double *qdot;     // n_dof
    int solved;
} NWBC;

// === Linear solve via in-place Gauss-Jordan with partial pivoting. ===
static int _gj_solve(double *A, int n, double *b_inout) {
    for (int i = 0; i < n; i++) {
        int piv = i;
        for (int r = i + 1; r < n; r++)
            if (fabs(A[r*n + i]) > fabs(A[piv*n + i])) piv = r;
        if (fabs(A[piv*n + i]) < 1e-14) return 0;
        if (piv != i) {
            for (int j = 0; j < n; j++) { double t = A[i*n + j]; A[i*n + j] = A[piv*n + j]; A[piv*n + j] = t; }
            double tb = b_inout[i]; b_inout[i] = b_inout[piv]; b_inout[piv] = tb;
        }
        double inv = 1.0 / A[i*n + i];
        for (int j = 0; j < n; j++) A[i*n + j] *= inv;
        b_inout[i] *= inv;
        for (int r = 0; r < n; r++) {
            if (r == i) continue;
            double f = A[r*n + i];
            if (fabs(f) < 1e-30) continue;
            for (int j = 0; j < n; j++) A[r*n + j] -= f * A[i*n + j];
            b_inout[r] -= f * b_inout[i];
        }
    }
    return 1;
}

long long nuc_wbc_new(long long n_dof_, long long alpha_b) {
    int n = (int)n_dof_;
    if (n <= 0) return 0;
    NWBC *p = (NWBC *)calloc(1, sizeof(NWBC));
    p->n_dof = n;
    double a = _i2f(alpha_b);
    p->alpha = (a > 0) ? a : 1e-4;
    p->cap_tasks = 8;
    p->tasks = (_WBCTask *)calloc(p->cap_tasks, sizeof(_WBCTask));
    p->qdot = (double *)calloc(n, sizeof(double));
    return (long long)(size_t)p;
}

void nuc_wbc_set_regularization(long long h, long long alpha_b) {
    NWBC *p = (NWBC *)(void *)(size_t)h;
    if (!p) return;
    double a = _i2f(alpha_b);
    if (a > 0) p->alpha = a;
}

void nuc_wbc_clear_tasks(long long h) {
    NWBC *p = (NWBC *)(void *)(size_t)h;
    if (!p) return;
    for (int t = 0; t < p->n_tasks; t++) {
        if (p->tasks[t].J)     free(p->tasks[t].J);
        if (p->tasks[t].x_des) free(p->tasks[t].x_des);
    }
    p->n_tasks = 0;
    p->solved = 0;
}

long long nuc_wbc_add_task(long long h, long long J_ptr, long long x_des_ptr,
                            long long n_rows_, long long weight_b)
{
    NWBC *p = (NWBC *)(void *)(size_t)h;
    if (!p) return -1;
    int m = (int)n_rows_;
    if (m <= 0) return -1;
    double *J_in = (double *)(void *)(size_t)J_ptr;
    double *x_in = (double *)(void *)(size_t)x_des_ptr;
    if (!J_in || !x_in) return -1;
    if (p->n_tasks >= p->cap_tasks) {
        p->cap_tasks *= 2;
        p->tasks = (_WBCTask *)realloc(p->tasks, p->cap_tasks * sizeof(_WBCTask));
    }
    _WBCTask *t = &p->tasks[p->n_tasks];
    t->m = m;
    double w = _i2f(weight_b);
    t->weight = (w > 0) ? w : 1.0;
    int sz_J = m * p->n_dof;
    t->J = (double *)malloc(sz_J * sizeof(double));
    memcpy(t->J, J_in, sz_J * sizeof(double));
    t->x_des = (double *)malloc(m * sizeof(double));
    memcpy(t->x_des, x_in, m * sizeof(double));
    p->solved = 0;
    return (long long)(p->n_tasks++);
}

long long nuc_wbc_solve(long long h) {
    NWBC *p = (NWBC *)(void *)(size_t)h;
    if (!p) return 0;
    int n = p->n_dof;
    double *A = (double *)calloc(n * n, sizeof(double));
    double *b = (double *)calloc(n, sizeof(double));

    // A = α I
    for (int i = 0; i < n; i++) A[i*n + i] = p->alpha;

    // Accumulate A += w · Jᵀ J,  b += w · Jᵀ x
    for (int t = 0; t < p->n_tasks; t++) {
        _WBCTask *T = &p->tasks[t];
        double w = T->weight;
        double *J = T->J;
        // A += w · Jᵀ J  (n × n)
        for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
                double s = 0;
                for (int k = 0; k < T->m; k++) s += J[k*n + i] * J[k*n + j];
                A[i*n + j] += w * s;
            }
            // b += w · Jᵀ x_des
            double s = 0;
            for (int k = 0; k < T->m; k++) s += J[k*n + i] * T->x_des[k];
            b[i] += w * s;
        }
    }

    // Solve A · q̇ = b in place.
    int ok = _gj_solve(A, n, b);
    if (ok) {
        memcpy(p->qdot, b, n * sizeof(double));
        p->solved = 1;
    }
    free(A); free(b);
    return ok ? 1 : 0;
}

long long nuc_wbc_get_qdot(long long h, long long i) {
    NWBC *p = (NWBC *)(void *)(size_t)h;
    if (!p || i < 0 || i >= (long long)p->n_dof) return _f2i(0.0);
    return _f2i(p->qdot[i]);
}

// Per-task residual norm: ‖J_i · q̇ − x_des_i‖₂.
long long nuc_wbc_task_residual(long long h, long long task_id_) {
    NWBC *p = (NWBC *)(void *)(size_t)h;
    if (!p || !p->solved) return _f2i(0.0);
    int t = (int)task_id_;
    if (t < 0 || t >= p->n_tasks) return _f2i(0.0);
    _WBCTask *T = &p->tasks[t];
    double sum = 0;
    for (int k = 0; k < T->m; k++) {
        double r = -T->x_des[k];
        for (int j = 0; j < p->n_dof; j++) r += T->J[k*p->n_dof + j] * p->qdot[j];
        sum += r * r;
    }
    return _f2i(sqrt(sum));
}

void nuc_wbc_free(long long h) {
    NWBC *p = (NWBC *)(void *)(size_t)h;
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
