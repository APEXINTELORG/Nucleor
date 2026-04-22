// fluid_rt.c — Lattice Boltzmann Fluid Simulation for Nucleor
// D2Q9 model, BGK collision, obstacles, inlet/outlet.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/fluid_rt.c -o target/fluid_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _fl_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _fl_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

// D2Q9 velocities and weights
static const int cx[9] = { 0, 1, 0,-1, 0, 1,-1,-1, 1};
static const int cy[9] = { 0, 0, 1, 0,-1, 1, 1,-1,-1};
static const double w[9] = {4.0/9, 1.0/9, 1.0/9, 1.0/9, 1.0/9,
                              1.0/36, 1.0/36, 1.0/36, 1.0/36};
static const int opp[9] = {0, 3, 4, 1, 2, 7, 8, 5, 6};

typedef struct {
    int Nx, Ny;
    double *f;       // distribution functions [Nx*Ny*9]
    double *f_new;   // post-streaming
    int *obstacle;   // 1 = solid
    double omega;    // relaxation parameter = 1/tau
    int step;
} LBM2D;

#define LBM_IDX(lbm, x, y, q) ((((y) * (lbm)->Nx + (x)) * 9) + (q))

// Equilibrium distribution
static double feq(int q, double rho, double ux, double uy) {
    double cu = cx[q] * ux + cy[q] * uy;
    double u2 = ux * ux + uy * uy;
    return w[q] * rho * (1 + 3 * cu + 4.5 * cu * cu - 1.5 * u2);
}

long long nuc_lbm_new_2d(long long Nx, long long Ny, long long viscosity_bits) {
    int nx = (int)Nx, ny = (int)Ny;
    double nu = _fl_i2f(viscosity_bits);
    double tau = 3 * nu + 0.5;

    LBM2D *lbm = (LBM2D *)calloc(1, sizeof(LBM2D));
    lbm->Nx = nx; lbm->Ny = ny;
    lbm->omega = 1.0 / tau;
    lbm->f = (double *)malloc(nx * ny * 9 * sizeof(double));
    lbm->f_new = (double *)malloc(nx * ny * 9 * sizeof(double));
    lbm->obstacle = (int *)calloc(nx * ny, sizeof(int));

    // Initialize to rho=1, u=0 equilibrium
    for (int y = 0; y < ny; y++)
        for (int x = 0; x < nx; x++)
            for (int q = 0; q < 9; q++)
                lbm->f[LBM_IDX(lbm, x, y, q)] = feq(q, 1.0, 0.0, 0.0);

    return (long long)lbm;
}

void nuc_lbm_set_obstacle(long long h, long long x, long long y) {
    LBM2D *lbm = (LBM2D *)(void *)h;
    lbm->obstacle[(int)y * lbm->Nx + (int)x] = 1;
}

// Set inlet velocity at left wall (x=0)
void nuc_lbm_set_inlet(long long h, long long velocity_bits) {
    LBM2D *lbm = (LBM2D *)(void *)h;
    double u_in = _fl_i2f(velocity_bits);
    for (int y = 1; y < lbm->Ny - 1; y++) {
        double rho = 1.0;
        for (int q = 0; q < 9; q++)
            lbm->f[LBM_IDX(lbm, 0, y, q)] = feq(q, rho, u_in, 0.0);
    }
}

// ================================================================
//  LBM Timestep: collide + stream
// ================================================================

void nuc_lbm_step(long long h) {
    LBM2D *lbm = (LBM2D *)(void *)h;
    int nx = lbm->Nx, ny = lbm->Ny;

    // Collision (BGK)
    for (int y = 0; y < ny; y++) {
        for (int x = 0; x < nx; x++) {
            if (lbm->obstacle[y * nx + x]) continue;

            double rho = 0, ux = 0, uy = 0;
            for (int q = 0; q < 9; q++) {
                double fq = lbm->f[LBM_IDX(lbm, x, y, q)];
                rho += fq;
                ux += cx[q] * fq;
                uy += cy[q] * fq;
            }
            if (rho > 1e-10) { ux /= rho; uy /= rho; }

            for (int q = 0; q < 9; q++) {
                double eq = feq(q, rho, ux, uy);
                lbm->f[LBM_IDX(lbm, x, y, q)] += lbm->omega * (eq - lbm->f[LBM_IDX(lbm, x, y, q)]);
            }
        }
    }

    // Streaming
    memset(lbm->f_new, 0, nx * ny * 9 * sizeof(double));
    for (int y = 0; y < ny; y++) {
        for (int x = 0; x < nx; x++) {
            for (int q = 0; q < 9; q++) {
                int xn = x + cx[q], yn = y + cy[q];
                // Periodic or bounce-back
                if (xn < 0 || xn >= nx || yn < 0 || yn >= ny) continue;
                if (lbm->obstacle[yn * nx + xn]) {
                    // Bounce-back
                    lbm->f_new[LBM_IDX(lbm, x, y, opp[q])] = lbm->f[LBM_IDX(lbm, x, y, q)];
                } else {
                    lbm->f_new[LBM_IDX(lbm, xn, yn, q)] = lbm->f[LBM_IDX(lbm, x, y, q)];
                }
            }
        }
    }

    double *tmp = lbm->f; lbm->f = lbm->f_new; lbm->f_new = tmp;
    lbm->step++;
}

// ================================================================
//  Field access
// ================================================================

long long nuc_lbm_get_density(long long h, long long x, long long y) {
    LBM2D *lbm = (LBM2D *)(void *)h;
    double rho = 0;
    for (int q = 0; q < 9; q++) rho += lbm->f[LBM_IDX(lbm, (int)x, (int)y, q)];
    return _fl_f2i(rho);
}

long long nuc_lbm_get_vx(long long h, long long x, long long y) {
    LBM2D *lbm = (LBM2D *)(void *)h;
    double rho = 0, ux = 0;
    for (int q = 0; q < 9; q++) {
        double fq = lbm->f[LBM_IDX(lbm, (int)x, (int)y, q)];
        rho += fq; ux += cx[q] * fq;
    }
    return _fl_f2i(rho > 1e-10 ? ux / rho : 0.0);
}

long long nuc_lbm_get_vy(long long h, long long x, long long y) {
    LBM2D *lbm = (LBM2D *)(void *)h;
    double rho = 0, uy = 0;
    for (int q = 0; q < 9; q++) {
        double fq = lbm->f[LBM_IDX(lbm, (int)x, (int)y, q)];
        rho += fq; uy += cy[q] * fq;
    }
    return _fl_f2i(rho > 1e-10 ? uy / rho : 0.0);
}

// Vorticity: dvy/dx - dvx/dy (central difference)
long long nuc_lbm_get_vorticity(long long h, long long x, long long y) {
    int xi = (int)x, yi = (int)y;
    LBM2D *lbm = (LBM2D *)(void *)h;
    if (xi <= 0 || xi >= lbm->Nx - 1 || yi <= 0 || yi >= lbm->Ny - 1) return _fl_f2i(0);
    double vy_r = _fl_i2f(nuc_lbm_get_vy(h, xi + 1, yi));
    double vy_l = _fl_i2f(nuc_lbm_get_vy(h, xi - 1, yi));
    double vx_u = _fl_i2f(nuc_lbm_get_vx(h, xi, yi + 1));
    double vx_d = _fl_i2f(nuc_lbm_get_vx(h, xi, yi - 1));
    return _fl_f2i(0.5 * (vy_r - vy_l) - 0.5 * (vx_u - vx_d));
}

void nuc_lbm_free(long long h) {
    LBM2D *lbm = (LBM2D *)(void *)h;
    if (!lbm) return;
    free(lbm->f); free(lbm->f_new); free(lbm->obstacle); free(lbm);
}
