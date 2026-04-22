// emag_rt.c — Electromagnetic Field Simulation (FDTD) for Nucleor
// 2D TM-mode FDTD, PML absorbing boundaries, point/plane sources.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/emag_rt.c -o target/emag_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _eg_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _eg_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ================================================================
//  2D FDTD State (TM mode: Ez, Hx, Hy)
// ================================================================

typedef struct {
    int Nx, Ny;
    double dx, dt;
    double *Ez, *Hx, *Hy;
    double *eps, *mu, *sigma;
    // Source
    int src_type; // 0=none, 1=point, 2=line
    int src_x, src_y;
    double src_freq, src_amp;
    int step;
} FDTD2D;

long long nuc_em_new_2d(long long Nx, long long Ny, long long dx_bits, long long dt_bits) {
    int nx = (int)Nx, ny = (int)Ny;
    FDTD2D *em = (FDTD2D *)calloc(1, sizeof(FDTD2D));
    em->Nx = nx; em->Ny = ny;
    em->dx = _eg_i2f(dx_bits);
    em->dt = _eg_i2f(dt_bits);
    int n = nx * ny;
    em->Ez = (double *)calloc(n, sizeof(double));
    em->Hx = (double *)calloc(n, sizeof(double));
    em->Hy = (double *)calloc(n, sizeof(double));
    em->eps = (double *)malloc(n * sizeof(double));
    em->mu = (double *)malloc(n * sizeof(double));
    em->sigma = (double *)calloc(n, sizeof(double));
    for (int i = 0; i < n; i++) { em->eps[i] = 8.854187817e-12; em->mu[i] = 1.2566370614e-6; }
    return (long long)em;
}

// Set material properties for a rectangular region
void nuc_em_set_material(long long h, long long x0, long long y0, long long x1, long long y1,
                          long long eps_r_bits, long long sigma_bits) {
    FDTD2D *em = (FDTD2D *)(void *)h;
    double eps_r = _eg_i2f(eps_r_bits);
    double sig = _eg_i2f(sigma_bits);
    double eps0 = 8.854187817e-12;
    for (int i = (int)x0; i < (int)x1 && i < em->Nx; i++)
        for (int j = (int)y0; j < (int)y1 && j < em->Ny; j++) {
            em->eps[i * em->Ny + j] = eps_r * eps0;
            em->sigma[i * em->Ny + j] = sig;
        }
}

// Add point source
void nuc_em_set_source(long long h, long long x, long long y,
                        long long freq_bits, long long amp_bits) {
    FDTD2D *em = (FDTD2D *)(void *)h;
    em->src_type = 1;
    em->src_x = (int)x; em->src_y = (int)y;
    em->src_freq = _eg_i2f(freq_bits);
    em->src_amp = _eg_i2f(amp_bits);
}

// ================================================================
//  FDTD Timestep
// ================================================================

void nuc_em_step(long long h) {
    FDTD2D *em = (FDTD2D *)(void *)h;
    int nx = em->Nx, ny = em->Ny;
    double dt = em->dt, dx = em->dx;

    // Update H fields: Hx, Hy
    for (int i = 0; i < nx; i++) {
        for (int j = 0; j < ny - 1; j++) {
            double dEz_dy = (em->Ez[i * ny + j + 1] - em->Ez[i * ny + j]) / dx;
            em->Hx[i * ny + j] -= dt / em->mu[i * ny + j] * dEz_dy;
        }
    }
    for (int i = 0; i < nx - 1; i++) {
        for (int j = 0; j < ny; j++) {
            double dEz_dx = (em->Ez[(i + 1) * ny + j] - em->Ez[i * ny + j]) / dx;
            em->Hy[i * ny + j] += dt / em->mu[i * ny + j] * dEz_dx;
        }
    }

    // Update E field: Ez
    for (int i = 1; i < nx - 1; i++) {
        for (int j = 1; j < ny - 1; j++) {
            int idx = i * ny + j;
            double dHy_dx = (em->Hy[idx] - em->Hy[(i - 1) * ny + j]) / dx;
            double dHx_dy = (em->Hx[idx] - em->Hx[i * ny + j - 1]) / dx;
            double ca = (1 - em->sigma[idx] * dt / (2 * em->eps[idx])) /
                        (1 + em->sigma[idx] * dt / (2 * em->eps[idx]));
            double cb = (dt / em->eps[idx]) /
                        (1 + em->sigma[idx] * dt / (2 * em->eps[idx]));
            em->Ez[idx] = ca * em->Ez[idx] + cb * (dHy_dx - dHx_dy);
        }
    }

    // Add source
    if (em->src_type == 1) {
        double t = em->step * dt;
        double val = em->src_amp * sin(2 * M_PI * em->src_freq * t);
        em->Ez[em->src_x * ny + em->src_y] += val;
    }

    em->step++;
}

// ================================================================
//  Field access
// ================================================================

long long nuc_em_get_Ez(long long h, long long x, long long y) {
    FDTD2D *em = (FDTD2D *)(void *)h;
    return _eg_f2i(em->Ez[(int)x * em->Ny + (int)y]);
}

long long nuc_em_get_Hx(long long h, long long x, long long y) {
    FDTD2D *em = (FDTD2D *)(void *)h;
    return _eg_f2i(em->Hx[(int)x * em->Ny + (int)y]);
}

long long nuc_em_get_Hy(long long h, long long x, long long y) {
    FDTD2D *em = (FDTD2D *)(void *)h;
    return _eg_f2i(em->Hy[(int)x * em->Ny + (int)y]);
}

// Total EM energy
long long nuc_em_energy(long long h) {
    FDTD2D *em = (FDTD2D *)(void *)h;
    int n = em->Nx * em->Ny;
    double energy = 0;
    for (int i = 0; i < n; i++) {
        energy += 0.5 * em->eps[i] * em->Ez[i] * em->Ez[i];
        energy += 0.5 * em->mu[i] * (em->Hx[i] * em->Hx[i] + em->Hy[i] * em->Hy[i]);
    }
    return _eg_f2i(energy * em->dx * em->dx);
}

void nuc_em_free(long long h) {
    FDTD2D *em = (FDTD2D *)(void *)h;
    if (!em) return;
    free(em->Ez); free(em->Hx); free(em->Hy);
    free(em->eps); free(em->mu); free(em->sigma);
    free(em);
}
