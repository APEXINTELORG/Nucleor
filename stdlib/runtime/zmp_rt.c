// zmp_rt.c — Zero Moment Point (ZMP) tracking via cart-table
// inverse dynamics + finite-horizon LQR (Kajita 2003 / 2014).
//
// Bipedal locomotion convention: model the robot as a single-mass
// inverted pendulum (the "cart-table"). The ZMP — the point where
// the ground reaction force passes — must stay inside the support
// polygon for static stability. The relationship between the
// horizontal CoM trajectory `c(t)` and the ZMP `p(t)` is
//
//   p = c − (h / g) · c̈
//
// where `h` is the constant CoM height and `g` is gravity. Given a
// desired ZMP reference `p_ref(t)` (typically inside the support
// polygon at each timestep), this rod inverts the cart-table
// dynamics to compute the CoM trajectory `c(t)` whose induced
// ZMP best tracks `p_ref(t)`.
//
// Algorithm (per axis — call this rod twice for x and y):
//
//   State        x = (c, ċ, c̈) ∈ ℝ³
//   Discrete dyn x_{k+1} = A · x_k + B · u_k   (u = c⃛, jerk)
//                where  A = [[1, dt, dt²/2], [0, 1, dt], [0, 0, 1]]
//                       B = [dt³/6, dt²/2, dt]
//   Output       p_k = C · x_k    where  C = [1, 0, -h/g]
//
//   Cost         J = Σ_k (p_k − p_ref_k)² + R · u_k²
//
// Solved by a standard finite-horizon LQR backward Riccati pass
// with affine offset term for the tracking reference, then a
// forward pass to compute u and roll the state.
//
// **Limitations** (3-D / online preview / variable-height land in
// v0.6 if needed):
// - 1-D per call (call twice for x and y in the standard 2-DOF
//   biped formulation; the two axes are independent under the
//   linear cart-table model).
// - Constant CoM height `h`. Variable-height (LIPM with vertical
//   motion) requires a different model.
// - Offline (whole-trajectory) — no online preview controller. For
//   online MPC, feed each window of `p_ref` through this rod
//   repeatedly with rolling horizons.
//
// Compile: clang -c stdlib/runtime/zmp_rt.c -o target/zmp.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

#define G 9.81

typedef struct {
    int N;            // number of timesteps
    double h;         // CoM height
    double dt;
    double c_h_g;     // h / g — the C[2] coefficient
    double *p_ref;    // N — ZMP reference
    double *x;        // 3*(N+1) — state trajectory (c, ċ, c̈)
    double *u;        // N — jerk
    double *p_actual; // N — induced ZMP
    int solved;
} NZMP;

long long nuc_zmp_new(long long h_b, long long dt_b, long long n_steps) {
    int N = (int)n_steps;
    double h = _i2f(h_b);
    double dt = _i2f(dt_b);
    if (N <= 0 || h <= 0 || dt <= 0) return 0;
    NZMP *p = (NZMP *)calloc(1, sizeof(NZMP));
    p->N = N;
    p->h = h; p->dt = dt;
    p->c_h_g = h / G;
    p->p_ref    = (double *)calloc(N, sizeof(double));
    p->x        = (double *)calloc(3 * (N + 1), sizeof(double));
    p->u        = (double *)calloc(N, sizeof(double));
    p->p_actual = (double *)calloc(N, sizeof(double));
    return (long long)(size_t)p;
}

void nuc_zmp_set_zmp_ref(long long h, long long k_, long long v_b) {
    NZMP *p = (NZMP *)(void *)(size_t)h;
    if (!p) return;
    int k = (int)k_;
    if (k < 0 || k >= p->N) return;
    p->p_ref[k] = _i2f(v_b);
    p->solved = 0;
}

void nuc_zmp_set_initial_state(long long h, long long c_b, long long cdot_b, long long cddot_b) {
    NZMP *p = (NZMP *)(void *)(size_t)h;
    if (!p) return;
    p->x[0] = _i2f(c_b);
    p->x[1] = _i2f(cdot_b);
    p->x[2] = _i2f(cddot_b);
    p->solved = 0;
}

// Solve via finite-horizon LQR backward Riccati + forward pass.
// `R_b` is the jerk-cost weight (small, e.g. 1e-6).
long long nuc_zmp_solve(long long h, long long R_b) {
    NZMP *p = (NZMP *)(void *)(size_t)h;
    if (!p) return 0;
    double R = _i2f(R_b);
    if (R <= 0) R = 1e-6;

    int N = p->N;
    double dt = p->dt;
    // A (3×3) and B (3) — cart-table integrator.
    double A[9] = {
        1, dt, 0.5*dt*dt,
        0, 1, dt,
        0, 0, 1
    };
    double B[3] = { dt*dt*dt/6.0, 0.5*dt*dt, dt };
    double C[3] = { 1.0, 0.0, -p->c_h_g };

    // Backward pass storage:
    //   P (3×3), s (3), per timestep.
    // Standard tracking LQR:
    //   J = Σ_k (Cx_k - p_ref)² + R u_k²
    //   value-to-go V_k(x) = ½ xᵀ P_k x + s_kᵀ x + const
    //   Recursion:
    //     P_{k+1} given. P_k = CᵀC + Aᵀ P_{k+1} A − Aᵀ P_{k+1} B (R + Bᵀ P_{k+1} B)⁻¹ Bᵀ P_{k+1} A
    //     s_k = (-Cᵀ p_ref_k) + Aᵀ s_{k+1} − Aᵀ P_{k+1} B (R + Bᵀ P_{k+1} B)⁻¹ Bᵀ s_{k+1}
    //     K_k = (R + Bᵀ P_{k+1} B)⁻¹ Bᵀ P_{k+1} A   (1×3)
    //     k_k = (R + Bᵀ P_{k+1} B)⁻¹ Bᵀ s_{k+1}     (scalar)
    //     u_k = -K_k x_k - k_k

    double *P_seq = (double *)malloc(9 * (N + 1) * sizeof(double));
    double *s_seq = (double *)malloc(3 * (N + 1) * sizeof(double));
    double *K_seq = (double *)malloc(3 * N * sizeof(double));
    double *kk_seq = (double *)malloc(N * sizeof(double));

    // Terminal cost: assume Q_N = CᵀC, q_N = -Cᵀ p_ref_{N-1}.
    // (No separate terminal — we treat last stage symmetrically.)
    for (int i = 0; i < 9*(N+1); i++) P_seq[i] = 0;
    for (int i = 0; i < 3*(N+1); i++) s_seq[i] = 0;
    // P_N = 0, s_N = 0 (no terminal cost) — tracking is in the
    // running cost.

    for (int k = N - 1; k >= 0; k--) {
        double *P_next = P_seq + (k + 1) * 9;
        double *s_next = s_seq + (k + 1) * 3;
        double *P_cur  = P_seq + k * 9;
        double *s_cur  = s_seq + k * 3;
        double *K_cur  = K_seq + k * 3;
        double *kk_cur = &kk_seq[k];

        // PA = P_next · A   (3×3)
        double PA[9];
        for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) {
            double s = 0;
            for (int kk = 0; kk < 3; kk++) s += P_next[i*3+kk] * A[kk*3+j];
            PA[i*3+j] = s;
        }
        // PB = P_next · B   (3)
        double PB[3];
        for (int i = 0; i < 3; i++) {
            double s = 0;
            for (int kk = 0; kk < 3; kk++) s += P_next[i*3+kk] * B[kk];
            PB[i] = s;
        }
        // BTPB = Bᵀ · PB    (scalar)
        double BTPB = 0;
        for (int i = 0; i < 3; i++) BTPB += B[i] * PB[i];
        // R + BTPB
        double M = R + BTPB;
        double Minv = 1.0 / M;
        // BTPA = Bᵀ · PA    (3)
        double BTPA[3];
        for (int j = 0; j < 3; j++) {
            double s = 0;
            for (int i = 0; i < 3; i++) s += B[i] * PA[i*3+j];
            BTPA[j] = s;
        }
        // K = Minv · BTPA
        for (int j = 0; j < 3; j++) K_cur[j] = Minv * BTPA[j];

        // BTs = Bᵀ · s_next  (scalar)
        double BTs = B[0]*s_next[0] + B[1]*s_next[1] + B[2]*s_next[2];
        *kk_cur = Minv * BTs;

        // P_cur = CᵀC + Aᵀ PA − Aᵀ PB · Minv · BᵀPA
        // Compute ATPA (3×3), then subtract.
        double ATPA[9];
        for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) {
            double s = 0;
            for (int kk = 0; kk < 3; kk++) s += A[kk*3+i] * PA[kk*3+j];
            ATPA[i*3+j] = s;
        }
        // ATPB (3) = Aᵀ · PB
        double ATPB[3];
        for (int i = 0; i < 3; i++) {
            double s = 0;
            for (int kk = 0; kk < 3; kk++) s += A[kk*3+i] * PB[kk];
            ATPB[i] = s;
        }
        for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) {
            P_cur[i*3+j] = C[i] * C[j] + ATPA[i*3+j]
                         - ATPB[i] * Minv * BTPA[j];
        }
        // s_cur = -C·p_ref + Aᵀ s_next - ATPB · Minv · BTs
        for (int i = 0; i < 3; i++) {
            double a_t_s = 0;
            for (int kk = 0; kk < 3; kk++) a_t_s += A[kk*3+i] * s_next[kk];
            s_cur[i] = -C[i] * p->p_ref[k] + a_t_s - ATPB[i] * Minv * BTs;
        }
    }

    // Forward pass: roll out using K and k.
    // Initial state already stored at p->x[0..2].
    for (int k = 0; k < N; k++) {
        double *K_cur  = K_seq + k * 3;
        double *xk = p->x + k * 3;
        double u = -(K_cur[0]*xk[0] + K_cur[1]*xk[1] + K_cur[2]*xk[2]) - kk_seq[k];
        p->u[k] = u;
        // x_{k+1} = A xk + B u
        double *xn = p->x + (k+1) * 3;
        for (int i = 0; i < 3; i++) {
            double s = 0;
            for (int j = 0; j < 3; j++) s += A[i*3+j] * xk[j];
            xn[i] = s + B[i] * u;
        }
        // p_actual = C · xk (use the state at k for "ZMP at step k")
        p->p_actual[k] = C[0]*xk[0] + C[1]*xk[1] + C[2]*xk[2];
    }

    free(P_seq); free(s_seq); free(K_seq); free(kk_seq);
    p->solved = 1;
    return 1;
}

long long nuc_zmp_com(long long h, long long k_) {
    NZMP *p = (NZMP *)(void *)(size_t)h;
    if (!p || k_ < 0 || k_ > p->N) return _f2i(0.0);
    return _f2i(p->x[(int)k_ * 3 + 0]);
}
long long nuc_zmp_com_velocity(long long h, long long k_) {
    NZMP *p = (NZMP *)(void *)(size_t)h;
    if (!p || k_ < 0 || k_ > p->N) return _f2i(0.0);
    return _f2i(p->x[(int)k_ * 3 + 1]);
}
long long nuc_zmp_com_accel(long long h, long long k_) {
    NZMP *p = (NZMP *)(void *)(size_t)h;
    if (!p || k_ < 0 || k_ > p->N) return _f2i(0.0);
    return _f2i(p->x[(int)k_ * 3 + 2]);
}
long long nuc_zmp_zmp_actual(long long h, long long k_) {
    NZMP *p = (NZMP *)(void *)(size_t)h;
    if (!p || k_ < 0 || k_ >= p->N) return _f2i(0.0);
    return _f2i(p->p_actual[(int)k_]);
}
long long nuc_zmp_jerk(long long h, long long k_) {
    NZMP *p = (NZMP *)(void *)(size_t)h;
    if (!p || k_ < 0 || k_ >= p->N) return _f2i(0.0);
    return _f2i(p->u[(int)k_]);
}

void nuc_zmp_free(long long h) {
    NZMP *p = (NZMP *)(void *)(size_t)h;
    if (!p) return;
    if (p->p_ref) free(p->p_ref);
    if (p->x) free(p->x);
    if (p->u) free(p->u);
    if (p->p_actual) free(p->p_actual);
    free(p);
}
