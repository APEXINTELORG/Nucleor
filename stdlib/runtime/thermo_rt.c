// thermo_rt.c — Heat Transfer and Thermodynamics for Nucleor
// 2D/3D heat equation, boundary conditions, steady-state Poisson, ideal gas.
// All f64 values passed as i64 (bitcast).
//
// Compile: clang -c stdlib/runtime/thermo_rt.c -o target/thermo_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _hr_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _hr_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } HRVec;

// ================================================================
//  2D Heat Equation: dT/dt = k/(rho*cp) * Laplacian(T)
//  T is flat Vec<f64> [N*N], modified in-place, returns max temperature
// ================================================================

long long nuc_heat_2d(long long T_h, long long k_bits, long long rho_cp_bits,
                       long long dx_bits, long long dt_bits, long long N) {
    HRVec *T = (HRVec *)(void *)T_h;
    double k = _hr_i2f(k_bits), rho_cp = _hr_i2f(rho_cp_bits);
    double dx = _hr_i2f(dx_bits), dt = _hr_i2f(dt_bits);
    int n = (int)N;
    double alpha = k / rho_cp;
    double r = alpha * dt / (dx * dx);

    double *Tnew = (double *)malloc((size_t)n * n * sizeof(double));
    for (int i = 0; i < n * n; i++) Tnew[i] = _hr_i2f(T->data[i]);

    double max_T = -1e30;
    for (int i = 1; i < n - 1; i++) {
        for (int j = 1; j < n - 1; j++) {
            double Tc = _hr_i2f(T->data[i * n + j]);
            double Tn = _hr_i2f(T->data[(i-1) * n + j]);
            double Ts = _hr_i2f(T->data[(i+1) * n + j]);
            double Tw = _hr_i2f(T->data[i * n + j - 1]);
            double Te = _hr_i2f(T->data[i * n + j + 1]);
            Tnew[i * n + j] = Tc + r * (Tn + Ts + Tw + Te - 4 * Tc);
            if (Tnew[i * n + j] > max_T) max_T = Tnew[i * n + j];
        }
    }

    for (int i = 0; i < n * n; i++) T->data[i] = _hr_f2i(Tnew[i]);
    free(Tnew);
    return _hr_f2i(max_T);
}

// ================================================================
//  Steady-state heat: solve -k * Laplacian(T) = source
//  Uses Gauss-Seidel iteration
// ================================================================

long long nuc_heat_steady_state(long long T_h, long long source_h,
                                 long long k_bits, long long dx_bits,
                                 long long N, long long tol_bits) {
    HRVec *T = (HRVec *)(void *)T_h;
    HRVec *src = (HRVec *)(void *)source_h;
    double k = _hr_i2f(k_bits), dx = _hr_i2f(dx_bits), tol = _hr_i2f(tol_bits);
    int n = (int)N;
    double h2_over_k = dx * dx / k;

    for (int iter = 0; iter < 10000; iter++) {
        double max_diff = 0;
        for (int i = 1; i < n - 1; i++) {
            for (int j = 1; j < n - 1; j++) {
                double old = _hr_i2f(T->data[i * n + j]);
                double Tn = _hr_i2f(T->data[(i-1)*n+j]);
                double Ts = _hr_i2f(T->data[(i+1)*n+j]);
                double Tw = _hr_i2f(T->data[i*n+j-1]);
                double Te = _hr_i2f(T->data[i*n+j+1]);
                double s = _hr_i2f(src->data[i * n + j]);
                double Tnew = 0.25 * (Tn + Ts + Tw + Te + h2_over_k * s);
                T->data[i * n + j] = _hr_f2i(Tnew);
                double diff = fabs(Tnew - old);
                if (diff > max_diff) max_diff = diff;
            }
        }
        if (max_diff < tol) break;
    }
    return _hr_f2i(0.0);
}

// ================================================================
//  Ideal Gas Law: PV = nRT
//  Solve for the missing variable. Pass 0 for the unknown.
// ================================================================

long long nuc_thermo_ideal_gas(long long P_bits, long long V_bits,
                                long long n_bits, long long T_bits) {
    double P = _hr_i2f(P_bits), V = _hr_i2f(V_bits);
    double n = _hr_i2f(n_bits), T = _hr_i2f(T_bits);
    double R = 8.314462618; // J/(mol*K)

    if (P == 0 && V > 0 && n > 0 && T > 0) return _hr_f2i(n * R * T / V);
    if (V == 0 && P > 0 && n > 0 && T > 0) return _hr_f2i(n * R * T / P);
    if (n == 0 && P > 0 && V > 0 && T > 0) return _hr_f2i(P * V / (R * T));
    if (T == 0 && P > 0 && V > 0 && n > 0) return _hr_f2i(P * V / (n * R));
    return _hr_f2i(0.0);
}

// ================================================================
//  Carnot Efficiency
// ================================================================

long long nuc_thermo_carnot_eff(long long Th_bits, long long Tc_bits) {
    double Th = _hr_i2f(Th_bits), Tc = _hr_i2f(Tc_bits);
    if (Th <= 0) return _hr_f2i(0.0);
    return _hr_f2i(1.0 - Tc / Th);
}

// ================================================================
//  Stefan-Boltzmann radiation
// ================================================================

long long nuc_thermo_radiation(long long T_bits, long long emissivity_bits, long long area_bits) {
    double T = _hr_i2f(T_bits), eps = _hr_i2f(emissivity_bits), A = _hr_i2f(area_bits);
    double sigma = 5.670374419e-8; // W/(m^2*K^4)
    return _hr_f2i(eps * sigma * A * T * T * T * T);
}
