// mpc_rt.c — Receding-horizon Model Predictive Control wrapper
// around `ilqr_rt.c`.
//
// Standard MPC pattern:
//
//   At each control tick:
//     1. Observe current state x.
//     2. Plan an optimal control sequence u_0, u_1, ..., u_{T-1}
//        over a finite horizon T using iLQR (warm-started from the
//        previous tick's solution).
//     3. Execute only u_0.
//     4. Shift the planned sequence by 1 — u_1 becomes the new u_0,
//        ..., and append a copy of u_{T-1} (or zeros) at the end —
//        and move to the next tick.
//
// The whole point is the warm start: re-planning from scratch each
// tick is wasteful when consecutive states differ by a single
// timestep. After convergence, the iLQR solution at tick k is
// usually within 1–3 iterations of the solution at tick k+1.
//
// This rod is a thin persistent layer over the existing
// `nuc_ilqr_optimize` runtime — same dynamics/cost callback
// contract, same convergence behavior. `mpc_step` returns the
// immediate `u_0` vector and updates the internal warm-start
// sequence; subsequent calls reuse it.
//
// Limitations (constrained MPC / robust MPC / shrinking horizon
// land in v0.6 if needed):
// - No state or control constraints. For constrained QPs use
//   `lcp.nr` to assemble + solve the per-step QP yourself.
// - Fixed planning horizon T (set at construction). Adaptive horizon
//   variants are reserved for a later extension.
// - Caller assembles dynamics + costs as iLQR-style callbacks.
//
// Compile: clang -c stdlib/runtime/mpc_rt.c -o target/mpc.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

// External iLQR runtime (defined in ilqr_rt.c, same translation
// unit at link time once both runtimes are pulled in).
extern long long nuc_ilqr_optimize(
    long long n_x, long long n_u, long long T,
    long long x0_ptr, long long u_seq_ptr,
    long long max_iters,
    long long dynamics_fp,
    long long stage_cost_fp,
    long long terminal_cost_fp);

extern long long nuc_ilqr_total_cost(
    long long n_x, long long n_u, long long T,
    long long x0_ptr, long long u_seq_ptr,
    long long dynamics_fp, long long stage_cost_fp, long long terminal_cost_fp);

typedef struct {
    int n_x, n_u, T;
    int max_iters_per_step;
    double *u_seq;       // T × n_u (warm-start sequence)
    long long dyn_fp;
    long long sc_fp;
    long long tc_fp;
    int has_callbacks;
    long long last_iters;
    double last_cost;
} NMPC;

long long nuc_mpc_new(long long n_x_, long long n_u_, long long T_,
                      long long max_iters_per_step_)
{
    int nx = (int)n_x_, nu = (int)n_u_, T = (int)T_;
    int mit = (int)max_iters_per_step_;
    if (nx <= 0 || nu <= 0 || T <= 0) return 0;
    if (mit <= 0) mit = 5;
    NMPC *p = (NMPC *)calloc(1, sizeof(NMPC));
    p->n_x = nx; p->n_u = nu; p->T = T;
    p->max_iters_per_step = mit;
    p->u_seq = (double *)calloc((size_t)T * nu, sizeof(double));
    return (long long)(size_t)p;
}

void nuc_mpc_set_callbacks(long long h, long long dyn_fp, long long sc_fp, long long tc_fp) {
    NMPC *p = (NMPC *)(void *)(size_t)h;
    if (!p) return;
    p->dyn_fp = dyn_fp;
    p->sc_fp = sc_fp;
    p->tc_fp = tc_fp;
    p->has_callbacks = 1;
}

void nuc_mpc_warm_start(long long h, long long u_seq_ptr) {
    NMPC *p = (NMPC *)(void *)(size_t)h;
    if (!p) return;
    double *src = (double *)(void *)(size_t)u_seq_ptr;
    if (!src) return;
    memcpy(p->u_seq, src, (size_t)(p->T) * p->n_u * sizeof(double));
}

void nuc_mpc_reset(long long h) {
    NMPC *p = (NMPC *)(void *)(size_t)h;
    if (!p) return;
    memset(p->u_seq, 0, (size_t)(p->T) * p->n_u * sizeof(double));
    p->last_iters = 0;
    p->last_cost = 0;
}

// One MPC tick:
//   1. Run iLQR (warm-started from p->u_seq) for current state x.
//   2. Copy u_0 to the caller's u_out buffer.
//   3. Shift the sequence (drop u_0, repeat last u for the new tail).
// Returns the number of iLQR iterations performed.
long long nuc_mpc_step(long long h, long long x_ptr, long long u_out_ptr) {
    NMPC *p = (NMPC *)(void *)(size_t)h;
    if (!p || !p->has_callbacks) return -1;
    double *u_out = (double *)(void *)(size_t)u_out_ptr;
    if (!u_out) return -1;

    long long iters = nuc_ilqr_optimize(
        p->n_x, p->n_u, p->T,
        x_ptr, (long long)(size_t)p->u_seq,
        p->max_iters_per_step,
        p->dyn_fp, p->sc_fp, p->tc_fp);
    p->last_iters = iters;

    // Copy u_0 to output.
    memcpy(u_out, p->u_seq, p->n_u * sizeof(double));

    // Cache last cost for diagnostics.
    long long c_b = nuc_ilqr_total_cost(p->n_x, p->n_u, p->T,
        x_ptr, (long long)(size_t)p->u_seq,
        p->dyn_fp, p->sc_fp, p->tc_fp);
    p->last_cost = _i2f(c_b);

    // Shift sequence: u_seq[0..T-1] = u_seq[1..T] then duplicate last.
    for (int t = 0; t < p->T - 1; t++) {
        memcpy(p->u_seq + t * p->n_u, p->u_seq + (t + 1) * p->n_u, p->n_u * sizeof(double));
    }
    // Last slot gets a copy of itself (i.e. extend with the last
    // computed control). This is the standard MPC tail policy.

    return iters;
}

long long nuc_mpc_get_control(long long h, long long t, long long dim) {
    NMPC *p = (NMPC *)(void *)(size_t)h;
    if (!p || t < 0 || t >= p->T || dim < 0 || dim >= p->n_u) return _f2i(0.0);
    return _f2i(p->u_seq[t * p->n_u + dim]);
}

long long nuc_mpc_last_iters(long long h) {
    NMPC *p = (NMPC *)(void *)(size_t)h;
    return p ? p->last_iters : 0;
}

long long nuc_mpc_last_cost(long long h) {
    NMPC *p = (NMPC *)(void *)(size_t)h;
    return p ? _f2i(p->last_cost) : _f2i(0.0);
}

void nuc_mpc_free(long long h) {
    NMPC *p = (NMPC *)(void *)(size_t)h;
    if (!p) return;
    if (p->u_seq) free(p->u_seq);
    free(p);
}
