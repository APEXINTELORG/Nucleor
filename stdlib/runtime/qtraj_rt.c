// qtraj_rt.c — Minimum-snap polynomial trajectory generator for
// quadrotors and other differentially-flat systems.
//
// Mellinger & Kumar 2011. Quadrotor dynamics are differentially
// flat in the four outputs (x, y, z, yaw): given a sufficiently
// smooth trajectory in those outputs, the full 12-state + 4-input
// sequence is recoverable in closed form. Minimum-snap trajectories
// (minimizing the integral of squared 4th derivative) translate to
// low control effort and are the canonical choice for quadrotor
// trajectory generation.
//
// This rod handles ONE flat output. Call it four times (x, y, z,
// yaw) sharing the same waypoint count + segment times to generate
// a full quadrotor trajectory.
//
// Algorithm: degree-7 polynomial per segment, N segments → 8N
// coefficients. Equality constraints:
//   - 4 boundary conditions at t=0 of segment 0 (pos, vel, acc, jerk)
//   - 4 boundary conditions at end of segment N-1
//   - 5 constraints per interior waypoint:
//       * position from left = waypoint
//       * position from right = waypoint
//       * velocity continuity (left = right)
//       * accel continuity
//       * jerk continuity
// → 5(N-1) + 8 = 5N + 3 constraints, 8N - 5N - 3 = 3N - 3 free DOFs
// (= 0 when N=1, problem becomes square).
//
// QP cost: minimize Σ_k ∫_0^{T_k} (p_k^(4)(t))² dt = c^T Q c where
// Q is block-diagonal with explicit per-segment 8×8 blocks.
//
// Solve via KKT system:
//     [ 2Q  A^T ] [ c ]   [ 0 ]
//     [  A   0  ] [ λ ] = [ b ]
//
// → dimension (8N + 5N+3) × (8N + 5N+3); easily handled by dense
// Gauss-Jordan inverse for typical N ≤ 20.
//
// Limitations (corridor constraints / yaw alignment / general
// degree settings land in v0.6 if needed):
// - Fixed degree 7 per segment (snap-minimizing). Higher orders
//   would minimize crackle (5th deriv) etc.
// - No corridor / obstacle constraints (these turn the QP into a
//   QCQP requiring a more sophisticated solver).
// - No automatic time allocation (segment times are user-specified).
// - Single flat output per handle — call four times for quadrotor.
//
// Compile: clang -c stdlib/runtime/qtraj_rt.c -o target/qtraj.obj -O2

#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _f2i(double d) { long long x; memcpy(&x, &d, sizeof(double)); return x; }

#define DEG 7
#define COEFS_PER_SEG (DEG + 1)   // = 8

typedef struct {
    int n_seg;
    double *seg_T;            // per-segment durations (length n_seg)
    double *waypts;           // n_seg + 1 waypoint positions
    double bnd_start[4];      // boundary derivatives at t=0  (pos, vel, acc, jerk)
    double bnd_end[4];        // boundary derivatives at end   (same)
    double *coefs;            // n_seg * 8 polynomial coefficients (after solve)
    int solved;               // 1 if solve succeeded
} NQTRAJ;

static double _factorial(int n) {
    double r = 1; for (int i = 2; i <= n; i++) r *= i;
    return r;
}
static double _power(double x, int n) {
    double r = 1; for (int i = 0; i < n; i++) r *= x;
    return r;
}

// === Linear solve (Gauss-Jordan on augmented matrix) ===
static int _gj_solve(double *A, int n, double *b_inout) {
    // In-place row reduction with partial pivoting; b_inout receives
    // the solution.
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

// === API ===

long long nuc_qtraj_new(long long n_seg_) {
    int n_seg = (int)n_seg_;
    if (n_seg < 1) return 0;
    NQTRAJ *p = (NQTRAJ *)calloc(1, sizeof(NQTRAJ));
    p->n_seg = n_seg;
    p->seg_T = (double *)calloc(n_seg, sizeof(double));
    for (int k = 0; k < n_seg; k++) p->seg_T[k] = 1.0;     // default 1 s per seg
    p->waypts = (double *)calloc(n_seg + 1, sizeof(double));
    p->coefs = (double *)calloc(n_seg * COEFS_PER_SEG, sizeof(double));
    p->solved = 0;
    return (long long)(size_t)p;
}

void nuc_qtraj_set_waypoint(long long h, long long k_, long long x_b) {
    NQTRAJ *p = (NQTRAJ *)(void *)(size_t)h;
    if (!p) return;
    int k = (int)k_;
    if (k < 0 || k > p->n_seg) return;
    p->waypts[k] = _i2f(x_b);
    p->solved = 0;
}

void nuc_qtraj_set_segment_time(long long h, long long k_, long long t_b) {
    NQTRAJ *p = (NQTRAJ *)(void *)(size_t)h;
    if (!p) return;
    int k = (int)k_;
    if (k < 0 || k >= p->n_seg) return;
    double t = _i2f(t_b);
    if (t > 0) p->seg_T[k] = t;
    p->solved = 0;
}

void nuc_qtraj_set_start_boundary(long long h, long long deriv_, long long v_b) {
    NQTRAJ *p = (NQTRAJ *)(void *)(size_t)h;
    if (!p) return;
    int d = (int)deriv_;
    if (d < 0 || d > 3) return;
    p->bnd_start[d] = _i2f(v_b);
    p->solved = 0;
}

void nuc_qtraj_set_end_boundary(long long h, long long deriv_, long long v_b) {
    NQTRAJ *p = (NQTRAJ *)(void *)(size_t)h;
    if (!p) return;
    int d = (int)deriv_;
    if (d < 0 || d > 3) return;
    p->bnd_end[d] = _i2f(v_b);
    p->solved = 0;
}

long long nuc_qtraj_n_segments(long long h) {
    NQTRAJ *p = (NQTRAJ *)(void *)(size_t)h;
    if (!p) return 0;
    return (long long)p->n_seg;
}

long long nuc_qtraj_total_time(long long h) {
    NQTRAJ *p = (NQTRAJ *)(void *)(size_t)h;
    if (!p) return _f2i(0.0);
    double s = 0;
    for (int k = 0; k < p->n_seg; k++) s += p->seg_T[k];
    return _f2i(s);
}

long long nuc_qtraj_solve(long long h) {
    NQTRAJ *p = (NQTRAJ *)(void *)(size_t)h;
    if (!p) return -1;
    int N = p->n_seg;
    int n_unk = N * COEFS_PER_SEG;          // = 8N
    int n_con = 4 + 4 + 5 * (N - 1);        // start (4) + end (4) + interior (5 each)

    // KKT system size:
    //   M = [ 2Q   A^T ]   size (n_unk + n_con) × (n_unk + n_con)
    //       [  A    0  ]
    //   rhs = [ 0 ; b ]   length (n_unk + n_con)
    int dim = n_unk + n_con;
    double *M = (double *)calloc((size_t)dim * dim, sizeof(double));
    double *rhs = (double *)calloc(dim, sizeof(double));

    // === Build 2Q (snap cost) into the top-left block ===
    // Q_k[i][j] = (i! / (i-4)!) * (j! / (j-4)!) * T_k^(i+j-7) / (i+j-7)
    // for i, j in [4, 7]; else 0.
    for (int k = 0; k < N; k++) {
        double T = p->seg_T[k];
        for (int i = 4; i <= 7; i++) {
            for (int j = 4; j <= 7; j++) {
                double num_i = _factorial(i) / _factorial(i - 4);
                double num_j = _factorial(j) / _factorial(j - 4);
                int exp = i + j - 7;
                double v = num_i * num_j * _power(T, exp) / exp;
                int row = k * COEFS_PER_SEG + i;
                int col = k * COEFS_PER_SEG + j;
                M[row * dim + col] = 2.0 * v;
            }
        }
    }

    // === Build A (constraints) into the bottom-left block,
    // and A^T into the top-right block. RHS goes into rhs[n_unk..]. ===
    int row = n_unk;

    // Helper macro to add a row that says
    //   Σ_i coef_i * c[seg=k_seg, i_coef=i] = rhs_val
    // with offset for the right place.
#define SET_ROW_COEF(r, k_seg, i_coef, val)                                  \
    do {                                                                     \
        int col = (k_seg) * COEFS_PER_SEG + (i_coef);                        \
        M[(r) * dim + col]    += (val);                                      \
        M[col * dim + (r)]    += (val);   /* A^T into top-right block */     \
    } while (0)

    // Start boundary: derivatives 0..3 at t=0 of segment 0.
    // p^(d)(0) = c[0][d] * d!.
    for (int d = 0; d < 4; d++) {
        SET_ROW_COEF(row, 0, d, _factorial(d));
        rhs[row] = (d == 0) ? p->waypts[0] : p->bnd_start[d];
        row++;
    }

    // End boundary: derivatives 0..3 at t=T_{N-1} of segment N-1.
    {
        int kseg = N - 1;
        double T = p->seg_T[kseg];
        for (int d = 0; d < 4; d++) {
            for (int i = d; i <= 7; i++) {
                double coef = _factorial(i) / _factorial(i - d) * _power(T, i - d);
                SET_ROW_COEF(row, kseg, i, coef);
            }
            rhs[row] = (d == 0) ? p->waypts[N] : p->bnd_end[d];
            row++;
        }
    }

    // Interior waypoints k=1..N-1:
    //   (a) p_{k-1}(T_{k-1}) = waypts[k]
    //   (b) p_k(0)           = waypts[k]    (just c[k][0] = waypts[k])
    //   (c-e) p_k^(d)(0) - p_{k-1}^(d)(T_{k-1}) = 0  for d = 1, 2, 3
    for (int wp = 1; wp < N; wp++) {
        int kL = wp - 1, kR = wp;
        double T = p->seg_T[kL];

        // (a) p_{kL}(T) = waypts[wp]
        for (int i = 0; i <= 7; i++) {
            SET_ROW_COEF(row, kL, i, _power(T, i));
        }
        rhs[row++] = p->waypts[wp];

        // (b) p_{kR}(0) = waypts[wp]   →  c[kR][0] = waypts[wp]
        SET_ROW_COEF(row, kR, 0, 1.0);
        rhs[row++] = p->waypts[wp];

        // (c-e) continuity of derivatives 1, 2, 3.
        for (int d = 1; d <= 3; d++) {
            // +p_{kR}^(d)(0) = c[kR][d] * d!
            SET_ROW_COEF(row, kR, d, _factorial(d));
            // -p_{kL}^(d)(T) = -Σ_{i=d}^7 c[kL][i] * i!/(i-d)! * T^(i-d)
            for (int i = d; i <= 7; i++) {
                double coef = _factorial(i) / _factorial(i - d) * _power(T, i - d);
                SET_ROW_COEF(row, kL, i, -coef);
            }
            rhs[row] = 0.0;
            row++;
        }
    }
#undef SET_ROW_COEF

    // === Solve KKT system ===
    if (!_gj_solve(M, dim, rhs)) {
        free(M); free(rhs);
        return 0;
    }
    // Solution: rhs[0..n_unk] are the polynomial coefficients.
    memcpy(p->coefs, rhs, n_unk * sizeof(double));
    p->solved = 1;
    free(M); free(rhs);
    return 1;
}

long long nuc_qtraj_evaluate(long long h, long long k_, long long deriv_, long long t_b) {
    NQTRAJ *p = (NQTRAJ *)(void *)(size_t)h;
    if (!p || !p->solved) return _f2i(0.0);
    int k = (int)k_, d = (int)deriv_;
    if (k < 0 || k >= p->n_seg) return _f2i(0.0);
    if (d < 0) d = 0;
    double t = _i2f(t_b);
    double *c = p->coefs + k * COEFS_PER_SEG;
    double s = 0;
    for (int i = d; i <= 7; i++) {
        double coef = _factorial(i) / _factorial(i - d) * _power(t, i - d);
        s += c[i] * coef;
    }
    return _f2i(s);
}

long long nuc_qtraj_evaluate_total(long long h, long long deriv_, long long t_b) {
    NQTRAJ *p = (NQTRAJ *)(void *)(size_t)h;
    if (!p || !p->solved) return _f2i(0.0);
    double t = _i2f(t_b);
    if (t < 0) t = 0;
    int k = 0;
    while (k < p->n_seg - 1 && t > p->seg_T[k]) {
        t -= p->seg_T[k];
        k++;
    }
    if (t > p->seg_T[k]) t = p->seg_T[k];
    return nuc_qtraj_evaluate(h, (long long)k, deriv_, _f2i(t));
}

void nuc_qtraj_free(long long h) {
    NQTRAJ *p = (NQTRAJ *)(void *)(size_t)h;
    if (!p) return;
    if (p->seg_T) free(p->seg_T);
    if (p->waypts) free(p->waypts);
    if (p->coefs) free(p->coefs);
    free(p);
}
