// multigrid_rt.c — Multigrid PDE Solver for Nucleor
// V-cycle multigrid for Poisson/elliptic equations (2D and 3D).
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/multigrid_rt.c -o target/multigrid_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _mg_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _mg_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
//  2D Multigrid (Poisson: -Laplacian(u) = f)
// ================================================================

// Gauss-Seidel red-black smoother
static void gs_smooth_2d(double *u, double *f, int N, double h2, int iters) {
    for (int it = 0; it < iters; it++) {
        for (int color = 0; color < 2; color++) {
            for (int i = 1; i < N - 1; i++) {
                for (int j = 1; j < N - 1; j++) {
                    if ((i + j) % 2 != color) continue;
                    u[i * N + j] = 0.25 * (u[(i-1)*N+j] + u[(i+1)*N+j] +
                                             u[i*N+j-1] + u[i*N+j+1] + h2 * f[i*N+j]);
                }
            }
        }
    }
}

// Compute residual: r = f + Laplacian(u)
static void residual_2d(double *r, double *u, double *f, int N, double h2inv) {
    for (int i = 1; i < N - 1; i++) {
        for (int j = 1; j < N - 1; j++) {
            double lap = (u[(i-1)*N+j] + u[(i+1)*N+j] + u[i*N+j-1] + u[i*N+j+1] - 4*u[i*N+j]) * h2inv;
            r[i * N + j] = f[i * N + j] + lap;
        }
    }
}

// Restrict fine grid to coarse (full weighting)
static void restrict_2d(double *coarse, double *fine, int Nc, int Nf) {
    memset(coarse, 0, Nc * Nc * sizeof(double));
    for (int i = 1; i < Nc - 1; i++) {
        for (int j = 1; j < Nc - 1; j++) {
            int fi = 2 * i, fj = 2 * j;
            coarse[i * Nc + j] = (
                4 * fine[fi * Nf + fj] +
                2 * (fine[(fi-1)*Nf+fj] + fine[(fi+1)*Nf+fj] + fine[fi*Nf+fj-1] + fine[fi*Nf+fj+1]) +
                (fine[(fi-1)*Nf+fj-1] + fine[(fi-1)*Nf+fj+1] + fine[(fi+1)*Nf+fj-1] + fine[(fi+1)*Nf+fj+1])
            ) / 16.0;
        }
    }
}

// Prolong coarse to fine (bilinear interpolation)
static void prolong_2d(double *fine, double *coarse, int Nf, int Nc) {
    for (int i = 0; i < Nc; i++) {
        for (int j = 0; j < Nc; j++) {
            fine[2*i * Nf + 2*j] += coarse[i * Nc + j];
            if (2*i+1 < Nf && i+1 < Nc)
                fine[(2*i+1) * Nf + 2*j] += 0.5 * (coarse[i*Nc+j] + coarse[(i+1)*Nc+j]);
            if (2*j+1 < Nf && j+1 < Nc)
                fine[2*i * Nf + 2*j+1] += 0.5 * (coarse[i*Nc+j] + coarse[i*Nc+j+1]);
            if (2*i+1 < Nf && 2*j+1 < Nf && i+1 < Nc && j+1 < Nc)
                fine[(2*i+1) * Nf + 2*j+1] += 0.25 * (coarse[i*Nc+j] + coarse[(i+1)*Nc+j] +
                                                         coarse[i*Nc+j+1] + coarse[(i+1)*Nc+j+1]);
        }
    }
}

// V-cycle
static void vcycle_2d(double *u, double *f, int N, double h) {
    if (N <= 3) {
        // Direct solve at coarsest level
        gs_smooth_2d(u, f, N, h * h, 50);
        return;
    }

    double h2 = h * h;
    double h2inv = 1.0 / h2;

    // Pre-smooth
    gs_smooth_2d(u, f, N, h2, 3);

    // Compute residual
    double *r = (double *)calloc(N * N, sizeof(double));
    residual_2d(r, u, f, N, h2inv);

    // Restrict to coarse
    int Nc = (N - 1) / 2 + 1;
    double *fc = (double *)calloc(Nc * Nc, sizeof(double));
    double *uc = (double *)calloc(Nc * Nc, sizeof(double));
    restrict_2d(fc, r, Nc, N);

    // Recurse
    vcycle_2d(uc, fc, Nc, 2 * h);

    // Prolong and correct
    prolong_2d(u, uc, N, Nc);

    // Post-smooth
    gs_smooth_2d(u, f, N, h2, 3);

    free(r); free(fc); free(uc);
}

// Public: solve -Laplacian(u) = rhs on [0,1]^2 with Dirichlet BC = 0
// rhs_h and sol_h are Vec<f64> of length N*N
long long nuc_mg_solve_2d(long long rhs_h, long long sol_h, long long N, long long tol_bits) {
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *rhs_v = (NVec *)(void *)rhs_h;
    NVec *sol_v = (NVec *)(void *)sol_h;
    int n = (int)N;
    double tol = _mg_i2f(tol_bits);
    double h = 1.0 / (n - 1);

    double *u = (double *)calloc(n * n, sizeof(double));
    double *f = (double *)malloc(n * n * sizeof(double));
    for (int i = 0; i < n * n; i++) {
        f[i] = _mg_i2f(rhs_v->data[i]);
        if (i < sol_v->len) u[i] = _mg_i2f(sol_v->data[i]);
    }

    for (int cycle = 0; cycle < 100; cycle++) {
        vcycle_2d(u, f, n, h);

        // Check residual norm
        double rnorm = 0;
        double h2inv = 1.0 / (h * h);
        for (int i = 1; i < n - 1; i++) {
            for (int j = 1; j < n - 1; j++) {
                double lap = (u[(i-1)*n+j] + u[(i+1)*n+j] + u[i*n+j-1] + u[i*n+j+1] - 4*u[i*n+j]) * h2inv;
                double r = f[i * n + j] + lap;
                rnorm += r * r;
            }
        }
        if (sqrt(rnorm) < tol) break;
    }

    // Write back
    for (int i = 0; i < n * n && i < sol_v->len; i++)
        sol_v->data[i] = _mg_f2i(u[i]);

    free(u); free(f);
    return _mg_f2i(0.0); // success
}

// Residual norm (for external convergence check)
long long nuc_mg_residual(long long sol_h, long long rhs_h, long long N) {
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *sol = (NVec *)(void *)sol_h, *rhs = (NVec *)(void *)rhs_h;
    int n = (int)N;
    double h = 1.0 / (n - 1);
    double h2inv = 1.0 / (h * h);
    double rnorm = 0;
    for (int i = 1; i < n - 1; i++) {
        for (int j = 1; j < n - 1; j++) {
            double u_c = _mg_i2f(sol->data[i * n + j]);
            double u_n = _mg_i2f(sol->data[(i-1)*n+j]);
            double u_s = _mg_i2f(sol->data[(i+1)*n+j]);
            double u_w = _mg_i2f(sol->data[i*n+j-1]);
            double u_e = _mg_i2f(sol->data[i*n+j+1]);
            double lap = (u_n + u_s + u_w + u_e - 4 * u_c) * h2inv;
            double r = _mg_i2f(rhs->data[i * n + j]) + lap;
            rnorm += r * r;
        }
    }
    return _mg_f2i(sqrt(rnorm));
}
