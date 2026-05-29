// admit_rt.c — Per-DOF admittance controller.
//
// Maps measured force to a position command via a virtual mass-
// spring-damper:
//
//   M · ẍ + D · ẋ + K · x = F_meas − F_des
//
// Discrete update each tick:
//   ẍ  ← (F_meas − F_des − D · ẋ − K · x) / M
//   x  ← x + dt · ẋ + ½ · dt² · ẍ
//   ẋ  ← ẋ + dt · ẍ
//
// Output: the (x, ẋ) state of the virtual admittance model.
// Higher-level code typically adds `x` as a perturbation to a
// nominal position trajectory ("compliant tracking") so the robot
// yields under contact force.
//
// Compare to impedance control (the dual): impedance maps
// position deviation to commanded force; admittance maps measured
// force to commanded position. Use admittance for position-
// controlled robots that need force compliance; use impedance for
// torque-controlled robots in stiffness-shaping mode.
//
// Limitations (full SE(3) impedance / coupling between DOFs /
// adaptive admittance land in v0.6 if needed):
// - Per-DOF independent (no off-diagonal M, D, K).
// - Linear time-invariant — no auto-gain-scheduling.
//
// Compile: clang -c stdlib/runtime/admit_rt.c -o target/admit.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

typedef struct {
    int n_dof;
    double *M, *D, *K;
    double *F_des;
    double *x;       // current position perturbation
    double *xdot;    // velocity
} NADMIT;

long long nuc_admit_new(long long n_dof_) {
    int n = (int)n_dof_;
    if (n <= 0) return 0;
    NADMIT *p = (NADMIT *)calloc(1, sizeof(NADMIT));
    p->n_dof = n;
    p->M     = (double *)malloc(n * sizeof(double));
    p->D     = (double *)malloc(n * sizeof(double));
    p->K     = (double *)malloc(n * sizeof(double));
    p->F_des = (double *)calloc(n, sizeof(double));
    p->x     = (double *)calloc(n, sizeof(double));
    p->xdot  = (double *)calloc(n, sizeof(double));
    for (int i = 0; i < n; i++) { p->M[i] = 1.0; p->D[i] = 1.0; p->K[i] = 1.0; }
    return (long long)(size_t)p;
}

void nuc_admit_set_gains(long long h, long long dim_,
                          long long M_b, long long D_b, long long K_b)
{
    NADMIT *p = (NADMIT *)(void *)(size_t)h;
    if (!p) return;
    int d = (int)dim_;
    if (d < 0 || d >= p->n_dof) return;
    double M = _i2f(M_b), D = _i2f(D_b), K = _i2f(K_b);
    if (M > 0) p->M[d] = M;
    if (D >= 0) p->D[d] = D;
    if (K >= 0) p->K[d] = K;
}

void nuc_admit_set_force_target(long long h, long long dim_, long long f_b) {
    NADMIT *p = (NADMIT *)(void *)(size_t)h;
    if (!p) return;
    int d = (int)dim_;
    if (d < 0 || d >= p->n_dof) return;
    p->F_des[d] = _i2f(f_b);
}

void nuc_admit_reset(long long h) {
    NADMIT *p = (NADMIT *)(void *)(size_t)h;
    if (!p) return;
    for (int i = 0; i < p->n_dof; i++) { p->x[i] = 0; p->xdot[i] = 0; }
}

// One tick. force_meas_ptr is double[n_dof]; dt_b is timestep.
// Updates internal (x, xdot) state per DOF.
void nuc_admit_step(long long h, long long force_meas_ptr, long long dt_b) {
    NADMIT *p = (NADMIT *)(void *)(size_t)h;
    if (!p) return;
    double *F = (double *)(void *)(size_t)force_meas_ptr;
    double dt = _i2f(dt_b);
    if (!F || dt <= 0) return;
    for (int i = 0; i < p->n_dof; i++) {
        double xddot = (F[i] - p->F_des[i] - p->D[i] * p->xdot[i] - p->K[i] * p->x[i]) / p->M[i];
        p->x[i] += dt * p->xdot[i] + 0.5 * dt * dt * xddot;
        p->xdot[i] += dt * xddot;
    }
}

long long nuc_admit_get_position(long long h, long long dim_) {
    NADMIT *p = (NADMIT *)(void *)(size_t)h;
    if (!p || dim_ < 0 || dim_ >= p->n_dof) return _f2i(0.0);
    return _f2i(p->x[(int)dim_]);
}
long long nuc_admit_get_velocity(long long h, long long dim_) {
    NADMIT *p = (NADMIT *)(void *)(size_t)h;
    if (!p || dim_ < 0 || dim_ >= p->n_dof) return _f2i(0.0);
    return _f2i(p->xdot[(int)dim_]);
}

void nuc_admit_free(long long h) {
    NADMIT *p = (NADMIT *)(void *)(size_t)h;
    if (!p) return;
    if (p->M) free(p->M);
    if (p->D) free(p->D);
    if (p->K) free(p->K);
    if (p->F_des) free(p->F_des);
    if (p->x) free(p->x);
    if (p->xdot) free(p->xdot);
    free(p);
}
