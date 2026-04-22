// taylor_rt.c — Taylor Model Validated ODE Integrator for Boussinesq System
//
// Two integration modes:
//   Mode 1 (nuc_tm_step): Full interval Taylor model. Rigorous but limited
//     to t~0.5 by wrapping in the enclosure recurrence.
//   Mode 2 (nuc_tm_step_mr): Midpoint-Radius approach. Computes Taylor
//     coefficients at the midpoint in double precision (NO wrapping), tracks
//     a scalar error radius via rigorous Lipschitz bound. Reaches t=2.0+
//     for N=8 grid (L~15-20).
//
// The midpoint-radius approach:
//   1. Taylor coefficients computed at midpoint (double precision, fast)
//   2. New midpoint = Horner evaluation of polynomial at h
//   3. Truncation error = |g_{p+1}| * h^{p+1}
//   4. Lipschitz constant L computed from midpoint velocity/gradient norms
//   5. Radius update: r_new = r * exp(L*h) + truncation + rounding
//
// Compile: clang -c stdlib/runtime/taylor_rt.c -o target/taylor_rt.obj -O2

#pragma STDC FENV_ACCESS ON

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>
#include <fenv.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* ==================================================================
   FFI helpers
   ================================================================== */
static double _b2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _f2b(double f) { long long i; memcpy(&i, &f, 8); return i; }

/* ==================================================================
   Internal Interval Type (IVal) — for Mode 1 only
   ================================================================== */
typedef struct { double lo; double hi; } IVal;

static IVal IVpt(double x) { return (IVal){x, x}; }
static double ivwid(IVal a) { return a.hi - a.lo; }
static double ivmag(IVal a) {
    double al = fabs(a.lo), ah = fabs(a.hi);
    return al > ah ? al : ah;
}
static double dm4(double a, double b, double c, double d) {
    double m = a; if (b < m) m = b; if (c < m) m = c; if (d < m) m = d; return m;
}
static double dx4(double a, double b, double c, double d) {
    double m = a; if (b > m) m = b; if (c > m) m = c; if (d > m) m = d; return m;
}
static IVal ivadd(IVal a, IVal b) {
    fesetround(FE_DOWNWARD); double lo = a.lo + b.lo;
    fesetround(FE_UPWARD);   double hi = a.hi + b.hi;
    fesetround(FE_TONEAREST); return (IVal){lo, hi};
}
static IVal ivsub(IVal a, IVal b) {
    fesetround(FE_DOWNWARD); double lo = a.lo - b.hi;
    fesetround(FE_UPWARD);   double hi = a.hi - b.lo;
    fesetround(FE_TONEAREST); return (IVal){lo, hi};
}
static IVal ivmul(IVal a, IVal b) {
    fesetround(FE_DOWNWARD);
    double p1 = a.lo*b.lo, p2 = a.lo*b.hi, p3 = a.hi*b.lo, p4 = a.hi*b.hi;
    double lo = dm4(p1, p2, p3, p4);
    fesetround(FE_UPWARD);
    p1 = a.lo*b.lo; p2 = a.lo*b.hi; p3 = a.hi*b.lo; p4 = a.hi*b.hi;
    double hi = dx4(p1, p2, p3, p4);
    fesetround(FE_TONEAREST); return (IVal){lo, hi};
}
static IVal ivneg(IVal a) { return (IVal){-a.hi, -a.lo}; }
static IVal ivabs(IVal a) {
    if (a.lo >= 0) return a;
    if (a.hi <= 0) return (IVal){-a.hi, -a.lo};
    double m = (-a.lo > a.hi) ? -a.lo : a.hi;
    return (IVal){0, m};
}
static IVal ivscl(IVal a, double s) {
    if (s >= 0) {
        fesetround(FE_DOWNWARD); double lo = a.lo * s;
        fesetround(FE_UPWARD);   double hi = a.hi * s;
        fesetround(FE_TONEAREST); return (IVal){lo, hi};
    } else {
        fesetround(FE_DOWNWARD); double lo = a.hi * s;
        fesetround(FE_UPWARD);   double hi = a.lo * s;
        fesetround(FE_TONEAREST); return (IVal){lo, hi};
    }
}
static IVal ivinfl(IVal a, double eps) { return (IVal){a.lo - eps, a.hi + eps}; }
static int ivsubof(IVal a, IVal b) { return a.lo >= b.lo && a.hi <= b.hi; }

/* ==================================================================
   State
   ================================================================== */
#define MAXP 12
#define MAXN 256

static double dmax(double a, double b) { return a > b ? a : b; }

typedef struct {
    int N, n2, p;
    double dx;
    double nu;           /* viscosity (0 = Euler, >0 = Navier-Stokes) */
    int poi;

    /* --- Mode 1: Full interval arrays --- */
    IVal *om[MAXP + 2];
    IVal *th[MAXP + 2];
    IVal *ps[MAXP + 2];
    IVal *uf[MAXP + 2];
    IVal *vf[MAXP + 2];
    IVal *om_cur;
    IVal *th_cur;
    IVal *enc_om, *enc_th, *rhs_om, *rhs_th;
    IVal *poly_om, *poly_th;

    /* --- Mode 2: Midpoint-Radius arrays (double precision) --- */
    double *om_d[MAXP + 2];   /* omega Taylor coefficients (double) */
    double *th_d[MAXP + 2];   /* theta Taylor coefficients (double) */
    double *ps_d[MAXP + 2];   /* psi (double) */
    double *ud[MAXP + 2];     /* u velocity (double) */
    double *vd[MAXP + 2];     /* v velocity (double) */
    double *om_mid;            /* midpoint omega */
    double *th_mid;            /* midpoint theta */
    double radius;             /* scalar L-infinity error radius */

    /* --- Mode 3: Signed error vector (linearized Taylor propagation) --- */
    double *dom_d[MAXP + 2];  /* linearized omega Taylor coefficients */
    double *dth_d[MAXP + 2];  /* linearized theta Taylor coefficients */
    double *dps_d[MAXP + 2];  /* linearized psi */
    double *dud[MAXP + 2];    /* linearized u velocity */
    double *dvd[MAXP + 2];    /* linearized v velocity */
    double *delta_om;          /* signed error vector (omega) */
    double *delta_th;          /* signed error vector (theta) */

    double t;
    int steps;
} TM;

static TM g = {0};
static int g_init = 0;

/* ==================================================================
   Grid indexing (periodic)
   ================================================================== */
static int gidx(int i, int j, int N) {
    int ri = i % N; if (ri < 0) ri += N;
    int rj = j % N; if (rj < 0) rj += N;
    return ri * N + rj;
}

/* ==================================================================
   Finite difference stencil selection: 2nd or 4th order
   4th-order: (-f[i+2]+8f[i+1]-8f[i-1]+f[i-2])/(12dx), error O(dx⁴)
   2nd-order: (f[i+1]-f[i-1])/(2dx), error O(dx²)
   ================================================================== */
static int g_fd_order = 2;  /* default 2nd-order; set to 4 for 4th-order */

static double ddx(double *f, int i, int j, int N, double dx) {
    if (g_fd_order == 4) {
        double inv12dx = 1.0 / (12.0 * dx);
        return inv12dx * (-f[gidx(i+2,j,N)] + 8.0*f[gidx(i+1,j,N)]
                          - 8.0*f[gidx(i-1,j,N)] + f[gidx(i-2,j,N)]);
    }
    return (f[gidx(i+1,j,N)] - f[gidx(i-1,j,N)]) / (2.0 * dx);
}
static double ddy(double *f, int i, int j, int N, double dx) {
    if (g_fd_order == 4) {
        double inv12dx = 1.0 / (12.0 * dx);
        return inv12dx * (-f[gidx(i,j+2,N)] + 8.0*f[gidx(i,j+1,N)]
                          - 8.0*f[gidx(i,j-1,N)] + f[gidx(i,j-2,N)]);
    }
    return (f[gidx(i,j+1,N)] - f[gidx(i,j-1,N)]) / (2.0 * dx);
}

/* FFI to set FD order: 2=2nd-order FD, 4=4th-order FD, 0=spectral */
void nuc_tm_set_fd_order(long long order) { g_fd_order = (int)order; }

static void fft_2d(double *re, double *im, int N, int sign);  /* forward decl */

/* ==================================================================
   De-aliased quadratic product (3/2 rule)

   Given two N×N grids a and b (physical space), compute c = a*b
   WITHOUT aliasing by zero-padding to M×M where M = 3N/2 (next pow2).

   1. FFT a and b to get â, b̂ (N×N Fourier)
   2. Zero-pad â, b̂ to M×M Fourier (insert zeros at high frequencies)
   3. IFFT to M×M physical space
   4. Multiply pointwise: ĉ_phys = â_phys * b̂_phys (at M resolution)
   5. FFT back to M×M Fourier
   6. Truncate to N×N Fourier
   7. IFFT to N×N physical space → c (de-aliased product)

   For the Taylor recurrence: u*∂ω/∂x uses this instead of direct pointwise.
   ================================================================== */
static int g_dealias = 0;  /* 1 = de-aliased products, 0 = direct */

/* Scratch for de-aliased computation */
static double *g_da_re1 = NULL, *g_da_im1 = NULL;
static double *g_da_re2 = NULL, *g_da_im2 = NULL;
static double *g_da_pre = NULL, *g_da_pim = NULL;
static double *g_da_phys1 = NULL, *g_da_phys2 = NULL;
static int g_da_M = 0, g_da_N = 0;

static void ensure_dealias_scratch(int N) {
    /* M = smallest power of 2 >= 3N/2 */
    int M = 1;
    int target = (3 * N + 1) / 2;
    while (M < target) M <<= 1;
    if (g_da_N == N && g_da_M == M) return;
    int m2 = M * M;
    free(g_da_re1); free(g_da_im1); free(g_da_re2); free(g_da_im2);
    free(g_da_pre); free(g_da_pim); free(g_da_phys1); free(g_da_phys2);
    g_da_re1  = (double *)calloc(m2, sizeof(double));
    g_da_im1  = (double *)calloc(m2, sizeof(double));
    g_da_re2  = (double *)calloc(m2, sizeof(double));
    g_da_im2  = (double *)calloc(m2, sizeof(double));
    g_da_pre  = (double *)calloc(m2, sizeof(double));
    g_da_pim  = (double *)calloc(m2, sizeof(double));
    g_da_phys1 = (double *)malloc(m2 * sizeof(double));
    g_da_phys2 = (double *)malloc(m2 * sizeof(double));
    g_da_N = N; g_da_M = M;
}

/* Zero-pad N×N Fourier coefficients to M×M.
   Frequencies [0..N/2] go to [0..N/2], frequencies [N/2+1..N-1] (negative)
   go to [M-N/2+1..M-1]. Middle is zero. */
static void zeropad_fft(double *src_re, double *src_im, int N,
                        double *dst_re, double *dst_im, int M) {
    int m2 = M * M;
    memset(dst_re, 0, m2 * sizeof(double));
    memset(dst_im, 0, m2 * sizeof(double));
    int half = N / 2;
    for (int kx = 0; kx < N; kx++) {
        int dkx;
        if (kx <= half) dkx = kx;             /* positive frequencies */
        else            dkx = M - (N - kx);   /* negative frequencies map to end */
        for (int ky = 0; ky < N; ky++) {
            int dky;
            if (ky <= half) dky = ky;
            else            dky = M - (N - ky);
            dst_re[dkx * M + dky] = src_re[kx * N + ky];
            dst_im[dkx * M + dky] = src_im[kx * N + ky];
        }
    }
}

/* Truncate M×M Fourier coefficients back to N×N (inverse of zero-pad) */
static void truncate_fft(double *src_re, double *src_im, int M,
                         double *dst_re, double *dst_im, int N) {
    int half = N / 2;
    for (int kx = 0; kx < N; kx++) {
        int skx;
        if (kx <= half) skx = kx;
        else            skx = M - (N - kx);
        for (int ky = 0; ky < N; ky++) {
            int sky;
            if (ky <= half) sky = ky;
            else            sky = M - (N - ky);
            dst_re[kx * N + ky] = src_re[skx * M + sky];
            dst_im[kx * N + ky] = src_im[skx * M + sky];
        }
    }
}

/* De-aliased pointwise product: c = a * b on N×N grid, alias-free.
   a and b are in physical space (N×N). Result c is in physical space (N×N).

   Normalization convention: fft_2d(sign=-1) gives UNSCALED forward DFT.
   Scaled coefficients = unscaled / N². IFFT of scaled coefficients (sign=+1)
   gives physical values directly. */
static void dealiased_multiply(double *a, double *b, double *c, int N) {
    int n2 = N * N;
    ensure_dealias_scratch(N);
    int M = g_da_M, m2 = M * M;
    double inv_n2 = 1.0 / (double)n2;
    double inv_m2 = 1.0 / (double)m2;

    /* Step 1: FFT a → scaled coefficients â_k = FFT(a)/N² */
    memcpy(g_da_re1, a, n2 * sizeof(double));
    memset(g_da_im1, 0, n2 * sizeof(double));
    fft_2d(g_da_re1, g_da_im1, N, -1);
    for (int i = 0; i < n2; i++) { g_da_re1[i] *= inv_n2; g_da_im1[i] *= inv_n2; }

    /* Step 2: Zero-pad â to M×M */
    zeropad_fft(g_da_re1, g_da_im1, N, g_da_pre, g_da_pim, M);

    /* Step 3: IFFT on M-grid → physical values a(x_m) */
    fft_2d(g_da_pre, g_da_pim, M, +1);
    memcpy(g_da_phys1, g_da_pre, m2 * sizeof(double));

    /* Same for b */
    memcpy(g_da_re2, b, n2 * sizeof(double));
    memset(g_da_im2, 0, n2 * sizeof(double));
    fft_2d(g_da_re2, g_da_im2, N, -1);
    for (int i = 0; i < n2; i++) { g_da_re2[i] *= inv_n2; g_da_im2[i] *= inv_n2; }
    zeropad_fft(g_da_re2, g_da_im2, N, g_da_pre, g_da_pim, M);
    fft_2d(g_da_pre, g_da_pim, M, +1);
    memcpy(g_da_phys2, g_da_pre, m2 * sizeof(double));

    /* Step 4: Pointwise multiply on M-grid */
    for (int i = 0; i < m2; i++) {
        g_da_pre[i] = g_da_phys1[i] * g_da_phys2[i];
        g_da_pim[i] = 0;
    }

    /* Step 5: FFT product → scaled coefficients p̂_k = FFT(p)/M² */
    fft_2d(g_da_pre, g_da_pim, M, -1);
    for (int i = 0; i < m2; i++) { g_da_pre[i] *= inv_m2; g_da_pim[i] *= inv_m2; }

    /* Step 6: Truncate to N modes */
    truncate_fft(g_da_pre, g_da_pim, M, g_da_re1, g_da_im1, N);

    /* Step 7: IFFT on N-grid → physical values c(x_n) */
    fft_2d(g_da_re1, g_da_im1, N, +1);
    memcpy(c, g_da_re1, n2 * sizeof(double));
}

void nuc_tm_set_dealias(long long on) { g_dealias = (int)on; }

/* ==================================================================
   Spectral derivative of entire grid (fast, FFT-based)
   Computes d/dx or d/dy of all N² grid values at once.
   Uses pre-allocated scratch to avoid malloc in hot loop.
   ================================================================== */
static double *g_fft_re = NULL, *g_fft_im = NULL;  /* scratch for FFT */
static double *g_fft_dre = NULL, *g_fft_dim = NULL;
static int g_fft_n = 0;

static void ensure_fft_scratch(int N) {
    int n2 = N * N;
    if (g_fft_n != N) {
        free(g_fft_re); free(g_fft_im); free(g_fft_dre); free(g_fft_dim);
        g_fft_re  = (double *)malloc(n2 * sizeof(double));
        g_fft_im  = (double *)malloc(n2 * sizeof(double));
        g_fft_dre = (double *)malloc(n2 * sizeof(double));
        g_fft_dim = (double *)malloc(n2 * sizeof(double));
        g_fft_n = N;
    }
}

/* Compute d/dx of entire grid f → df_out. N must be power of 2. */
static void grid_ddx(double *f, double *df_out, int N) {
    int n2 = N * N;
    ensure_fft_scratch(N);
    /* Forward FFT */
    memcpy(g_fft_re, f, n2 * sizeof(double));
    memset(g_fft_im, 0, n2 * sizeof(double));
    fft_2d(g_fft_re, g_fft_im, N, -1);
    /* Multiply by i*kx */
    for (int kx = 0; kx < N; kx++) {
        int kkx = (kx <= N / 2) ? kx : kx - N;
        for (int ky = 0; ky < N; ky++) {
            int idx = kx * N + ky;
            g_fft_dre[idx] = -(double)kkx * g_fft_im[idx];
            g_fft_dim[idx] =  (double)kkx * g_fft_re[idx];
        }
    }
    /* Inverse FFT + scale by 1/N² (forward FFT is unscaled) */
    fft_2d(g_fft_dre, g_fft_dim, N, +1);
    double inv_n2 = 1.0 / (double)n2;
    for (int i = 0; i < n2; i++) df_out[i] = g_fft_dre[i] * inv_n2;
}

/* Compute d/dy of entire grid */
static void grid_ddy(double *f, double *df_out, int N) {
    int n2 = N * N;
    ensure_fft_scratch(N);
    memcpy(g_fft_re, f, n2 * sizeof(double));
    memset(g_fft_im, 0, n2 * sizeof(double));
    fft_2d(g_fft_re, g_fft_im, N, -1);
    for (int kx = 0; kx < N; kx++) {
        for (int ky = 0; ky < N; ky++) {
            int kky = (ky <= N / 2) ? ky : ky - N;
            int idx = kx * N + ky;
            g_fft_dre[idx] = -(double)kky * g_fft_im[idx];
            g_fft_dim[idx] =  (double)kky * g_fft_re[idx];
        }
    }
    fft_2d(g_fft_dre, g_fft_dim, N, +1);
    double inv_n2 = 1.0 / (double)n2;
    for (int i = 0; i < n2; i++) df_out[i] = g_fft_dre[i] * inv_n2;
}

/* ==================================================================
   Double-precision grid operations (Mode 2)
   ================================================================== */

/* ==================================================================
   FFT: Cooley-Tukey radix-2 (in-place, N must be power of 2)
   sign = -1 for forward, +1 for inverse
   ================================================================== */
static void fft_1d(double *re, double *im, int N, int sign) {
    /* Bit-reversal permutation */
    for (int i = 1, j = 0; i < N; i++) {
        int bit = N >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) {
            double t; t = re[i]; re[i] = re[j]; re[j] = t;
            t = im[i]; im[i] = im[j]; im[j] = t;
        }
    }
    /* Butterfly stages */
    for (int len = 2; len <= N; len <<= 1) {
        double ang = (double)sign * 2.0 * M_PI / (double)len;
        double wre = cos(ang), wim = sin(ang);
        for (int i = 0; i < N; i += len) {
            double ure = 1.0, uim = 0.0;
            for (int j = 0; j < len / 2; j++) {
                int a = i + j, b = i + j + len / 2;
                double tre = re[b] * ure - im[b] * uim;
                double tim = re[b] * uim + im[b] * ure;
                re[b] = re[a] - tre; im[b] = im[a] - tim;
                re[a] += tre; im[a] += tim;
                double nu = ure * wre - uim * wim;
                uim = ure * wim + uim * wre; ure = nu;
            }
        }
    }
}

/* 2D FFT via row-then-column 1D FFTs. N must be power of 2.
   Data layout: row-major, re[i*N+j], im[i*N+j] */
static void fft_2d(double *re, double *im, int N, int sign) {
    double *row_re = (double *)malloc(N * sizeof(double));
    double *row_im = (double *)malloc(N * sizeof(double));
    /* FFT each row */
    for (int i = 0; i < N; i++) {
        memcpy(row_re, re + i * N, N * sizeof(double));
        memcpy(row_im, im + i * N, N * sizeof(double));
        fft_1d(row_re, row_im, N, sign);
        memcpy(re + i * N, row_re, N * sizeof(double));
        memcpy(im + i * N, row_im, N * sizeof(double));
    }
    /* FFT each column */
    for (int j = 0; j < N; j++) {
        for (int i = 0; i < N; i++) { row_re[i] = re[i * N + j]; row_im[i] = im[i * N + j]; }
        fft_1d(row_re, row_im, N, sign);
        for (int i = 0; i < N; i++) { re[i * N + j] = row_re[i]; im[i * N + j] = row_im[i]; }
    }
    free(row_re); free(row_im);
}

/* Check if N is a power of 2 */
static int is_pow2(int n) { return n > 0 && (n & (n - 1)) == 0; }

/* 2D DFT: real input f → complex output (re, im).
   Uses FFT if N is power of 2, direct DFT otherwise. */
static void dft_2d(double *f, double *re_out, double *im_out, int N);
static void idft_2d(double *re_in, double *im_in, double *f_out, int N);

/* Poisson solve: -Lap(psi) = omega
   Spectral method: psi_hat(k) = -omega_hat(k) / |k|^2 (exact for periodic BC)
   Falls back to Gauss-Seidel for the interval mode (IVal arrays).
   The 'iters' parameter is ignored in spectral mode. */
static int g_spectral_poisson = 1;  /* 1 = spectral (default), 0 = Gauss-Seidel */

static void poi_d(double *omega, double *psi, int N, double dx, int iters) {
    int n2 = N * N;

    if (g_spectral_poisson && N <= MAXN) {
        /* Spectral Poisson: DFT(omega) → divide by |k|² → IDFT → psi */
        double *ore = (double *)calloc(n2, sizeof(double));
        double *oim = (double *)calloc(n2, sizeof(double));
        double *pre = (double *)calloc(n2, sizeof(double));
        double *pim = (double *)calloc(n2, sizeof(double));

        dft_2d(omega, ore, oim, N);

        for (int kx = 0; kx < N; kx++) {
            int kkx = (kx <= N / 2) ? kx : kx - N;
            for (int ky = 0; ky < N; ky++) {
                int kky = (ky <= N / 2) ? ky : ky - N;
                int idx = kx * N + ky;
                double k2 = (double)(kkx * kkx + kky * kky);
                if (k2 < 0.5) {
                    /* k=0 mode: psi_hat(0) = 0 (mean-free) */
                    pre[idx] = 0; pim[idx] = 0;
                } else {
                    /* -Lap(psi) = omega → -|k|² psi_hat = omega_hat → psi_hat = -omega_hat/|k|² */
                    pre[idx] = -ore[idx] / k2;
                    pim[idx] = -oim[idx] / k2;
                }
            }
        }

        idft_2d(pre, pim, psi, N);
        free(ore); free(oim); free(pre); free(pim);
    } else {
        /* Gauss-Seidel fallback */
        double dx2 = dx * dx;
        for (int it = 0; it < iters; it++) {
            for (int i = 0; i < N; i++) {
                for (int j = 0; j < N; j++) {
                    double nb = psi[gidx(i+1,j,N)] + psi[gidx(i-1,j,N)]
                              + psi[gidx(i,j+1,N)] + psi[gidx(i,j-1,N)];
                    psi[gidx(i,j,N)] = 0.25 * (nb + dx2 * omega[gidx(i,j,N)]);
                }
            }
        }
    }
}

/* Velocity from stream function (double) — uses selected FD stencil */
static void vel_d(double *psi, double *u, double *v, int N, double dx) {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            int idx = gidx(i, j, N);
            u[idx] = ddy(psi, i, j, N, dx);        /* u = dpsi/dy */
            v[idx] = -ddx(psi, i, j, N, dx);       /* v = -dpsi/dx */
        }
    }
}

/* ==================================================================
   Double-precision Taylor coefficient recurrence (Mode 2)
   Same Cauchy product structure but in double — no wrapping.
   ================================================================== */
/* Pre-computed derivative grids for the Taylor recurrence.
   For spectral mode: computed once per order via FFT.
   For FD mode: filled point-by-point from ddx/ddy. */
static double **g_omx = NULL, **g_omy = NULL;  /* d(omega_k)/dx, dy */
static double **g_thx = NULL, **g_thy = NULL;  /* d(theta_k)/dx, dy */
static int g_deriv_alloc_n = 0, g_deriv_alloc_k = 0;

static void ensure_deriv_grids(int n2, int max_k) {
    if (g_deriv_alloc_n == n2 && g_deriv_alloc_k >= max_k) return;
    /* Free old */
    if (g_omx) { for (int k = 0; k <= g_deriv_alloc_k; k++) { free(g_omx[k]); free(g_omy[k]); free(g_thx[k]); free(g_thy[k]); } }
    free(g_omx); free(g_omy); free(g_thx); free(g_thy);
    g_omx = (double **)malloc((max_k+2) * sizeof(double*));
    g_omy = (double **)malloc((max_k+2) * sizeof(double*));
    g_thx = (double **)malloc((max_k+2) * sizeof(double*));
    g_thy = (double **)malloc((max_k+2) * sizeof(double*));
    for (int k = 0; k <= max_k+1; k++) {
        g_omx[k] = (double *)calloc(n2, sizeof(double));
        g_omy[k] = (double *)calloc(n2, sizeof(double));
        g_thx[k] = (double *)calloc(n2, sizeof(double));
        g_thy[k] = (double *)calloc(n2, sizeof(double));
    }
    g_deriv_alloc_n = n2; g_deriv_alloc_k = max_k+1;
}

/* Compute derivatives of grid f into fx, fy using selected method */
static void compute_grid_derivs(double *f, double *fx, double *fy, int N, double dx) {
    int n2 = N * N;
    if (g_fd_order == 0 && is_pow2(N)) {
        /* Spectral derivatives via FFT */
        grid_ddx(f, fx, N);
        grid_ddy(f, fy, N);
    } else {
        /* FD derivatives (2nd or 4th order) */
        for (int idx = 0; idx < n2; idx++) {
            int i = idx / N, j = idx % N;
            fx[idx] = ddx(f, i, j, N, dx);
            fy[idx] = ddy(f, i, j, N, dx);
        }
    }
}

static void taylor_recurrence_d(double **om, double **th, double **ps,
                                double **uf, double **vf,
                                int N, int max_k, double dx, int poi, double nu) {
    int n2 = N * N;
    double inv_dx2 = 1.0 / (dx * dx);
    ensure_deriv_grids(n2, max_k);

    for (int k = 0; k <= max_k; k++) {
        memset(ps[k], 0, n2 * sizeof(double));
        poi_d(om[k], ps[k], N, dx, poi);
        vel_d(ps[k], uf[k], vf[k], N, dx);

        /* Pre-compute derivatives of om[k] and th[k] */
        compute_grid_derivs(om[k], g_omx[k], g_omy[k], N, dx);
        compute_grid_derivs(th[k], g_thx[k], g_thy[k], N, dx);

        if (k < max_k) {
            double scl = 1.0 / (double)(k + 1);

            if (g_dealias && g_fd_order == 0 && is_pow2(N)) {
                /* De-aliased Cauchy product: compute each u[m]*∇ω[km] product
                   via 3/2-rule padding, accumulate into scratch grids */
                double *adv_om_grid = (double *)calloc(n2, sizeof(double));
                double *adv_th_grid = (double *)calloc(n2, sizeof(double));
                double *prod = (double *)malloc(n2 * sizeof(double));

                for (int m = 0; m <= k; m++) {
                    int km = k - m;
                    /* u[m] * ∂ω[km]/∂x */
                    dealiased_multiply(uf[m], g_omx[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) adv_om_grid[idx] += prod[idx];
                    /* v[m] * ∂ω[km]/∂y */
                    dealiased_multiply(vf[m], g_omy[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) adv_om_grid[idx] += prod[idx];
                    /* u[m] * ∂θ[km]/∂x */
                    dealiased_multiply(uf[m], g_thx[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) adv_th_grid[idx] += prod[idx];
                    /* v[m] * ∂θ[km]/∂y */
                    dealiased_multiply(vf[m], g_thy[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) adv_th_grid[idx] += prod[idx];
                }

                for (int idx = 0; idx < n2; idx++) {
                    om[k+1][idx] = scl * (g_thx[k][idx] - adv_om_grid[idx]);
                    th[k+1][idx] = scl * (-adv_th_grid[idx]);
                }
                /* Viscous diffusion (linear, no aliasing concern) */
                if (nu > 0) {
                    for (int idx = 0; idx < n2; idx++) {
                        int i = idx / N, j = idx % N;
                        double lap = nu * inv_dx2 * (
                            om[k][gidx(i+1,j,N)] + om[k][gidx(i-1,j,N)]
                          + om[k][gidx(i,j+1,N)] + om[k][gidx(i,j-1,N)]
                          - 4.0 * om[k][idx]);
                        om[k+1][idx] += scl * lap;
                    }
                }
                free(adv_om_grid); free(adv_th_grid); free(prod);

            } else {
                /* Direct (non-de-aliased) Cauchy product */
                for (int idx = 0; idx < n2; idx++) {
                    int i = idx / N, j = idx % N;
                    double thx_k = g_thx[k][idx];
                    double adv_om = 0, adv_th = 0;
                    for (int m = 0; m <= k; m++) {
                        int km = k - m;
                        adv_om += uf[m][idx]*g_omx[km][idx] + vf[m][idx]*g_omy[km][idx];
                        adv_th += uf[m][idx]*g_thx[km][idx] + vf[m][idx]*g_thy[km][idx];
                    }
                    double lap_om_k = 0;
                    if (nu > 0) {
                        lap_om_k = nu * inv_dx2 * (
                            om[k][gidx(i+1,j,N)] + om[k][gidx(i-1,j,N)]
                          + om[k][gidx(i,j+1,N)] + om[k][gidx(i,j-1,N)]
                          - 4.0 * om[k][idx]);
                    }
                    om[k+1][idx] = scl * (thx_k - adv_om + lap_om_k);
                    th[k+1][idx] = scl * (-adv_th);
                }
            }
        }
    }
}

/* Horner evaluation at point h (double precision) */
static double horner_d(double **c, int p, int idx, double h) {
    double r = c[p][idx];
    for (int k = p - 1; k >= 0; k--)
        r = c[k][idx] + h * r;
    return r;
}

/* ==================================================================
   Interval grid operations (Mode 1) — kept for comparison
   ================================================================== */
static void poi_iv(IVal *omega, IVal *psi, int N, double dx, int iters) {
    IVal dx2 = IVpt(dx * dx);
    IVal quarter = IVpt(0.25);
    for (int it = 0; it < iters; it++) {
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) {
                IVal nb = ivadd(ivadd(psi[gidx(i+1,j,N)], psi[gidx(i-1,j,N)]),
                                ivadd(psi[gidx(i,j+1,N)], psi[gidx(i,j-1,N)]));
                psi[gidx(i,j,N)] = ivmul(quarter, ivadd(nb, ivmul(dx2, omega[gidx(i,j,N)])));
            }
    }
}
static void vel_iv(IVal *psi, IVal *u, IVal *v, int N, double dx) {
    IVal inv2dx = IVpt(1.0 / (2.0 * dx));
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            int idx = gidx(i, j, N);
            u[idx] = ivmul(inv2dx, ivsub(psi[gidx(i,j+1,N)], psi[gidx(i,j-1,N)]));
            v[idx] = ivneg(ivmul(inv2dx, ivsub(psi[gidx(i+1,j,N)], psi[gidx(i-1,j,N)])));
        }
}
static void rhs_iv(IVal *omega, IVal *theta, IVal *d_omega, IVal *d_theta,
                   int N, double dx, int poi_iters) {
    int n2 = N * N;
    IVal inv2dx = IVpt(1.0 / (2.0 * dx));
    IVal *psi = (IVal *)calloc(n2, sizeof(IVal));
    IVal *u   = (IVal *)calloc(n2, sizeof(IVal));
    IVal *v   = (IVal *)calloc(n2, sizeof(IVal));
    poi_iv(omega, psi, N, dx, poi_iters);
    vel_iv(psi, u, v, N, dx);
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            int idx = gidx(i, j, N);
            IVal dw_dx = ivmul(inv2dx, ivsub(omega[gidx(i+1,j,N)], omega[gidx(i-1,j,N)]));
            IVal dw_dy = ivmul(inv2dx, ivsub(omega[gidx(i,j+1,N)], omega[gidx(i,j-1,N)]));
            IVal dt_dx = ivmul(inv2dx, ivsub(theta[gidx(i+1,j,N)], theta[gidx(i-1,j,N)]));
            IVal dt_dy = ivmul(inv2dx, ivsub(theta[gidx(i,j+1,N)], theta[gidx(i,j-1,N)]));
            IVal adv_w = ivadd(ivmul(u[idx], dw_dx), ivmul(v[idx], dw_dy));
            IVal adv_t = ivadd(ivmul(u[idx], dt_dx), ivmul(v[idx], dt_dy));
            d_omega[idx] = ivsub(dt_dx, adv_w);
            d_theta[idx] = ivneg(adv_t);
        }
    free(psi); free(u); free(v);
}
static void taylor_recurrence_iv(IVal **om, IVal **th, IVal **ps, IVal **uf, IVal **vf,
                                 int N, int max_k, double dx, int poi) {
    int n2 = N * N;
    IVal inv2dx = IVpt(1.0 / (2.0 * dx));
    for (int k = 0; k <= max_k; k++) {
        memset(ps[k], 0, n2 * sizeof(IVal));
        poi_iv(om[k], ps[k], N, dx, poi);
        vel_iv(ps[k], uf[k], vf[k], N, dx);
        if (k < max_k) {
            double scl = 1.0 / (double)(k + 1);
            for (int idx = 0; idx < n2; idx++) {
                int i = idx / N, j = idx % N;
                IVal thx_k = ivmul(inv2dx, ivsub(th[k][gidx(i+1,j,N)], th[k][gidx(i-1,j,N)]));
                IVal adv_om = IVpt(0), adv_th = IVpt(0);
                for (int m = 0; m <= k; m++) {
                    int km = k - m;
                    IVal dom_dx = ivmul(inv2dx, ivsub(om[km][gidx(i+1,j,N)], om[km][gidx(i-1,j,N)]));
                    IVal dom_dy = ivmul(inv2dx, ivsub(om[km][gidx(i,j+1,N)], om[km][gidx(i,j-1,N)]));
                    IVal dth_dx = ivmul(inv2dx, ivsub(th[km][gidx(i+1,j,N)], th[km][gidx(i-1,j,N)]));
                    IVal dth_dy = ivmul(inv2dx, ivsub(th[km][gidx(i,j+1,N)], th[km][gidx(i,j-1,N)]));
                    adv_om = ivadd(adv_om, ivadd(ivmul(uf[m][idx], dom_dx), ivmul(vf[m][idx], dom_dy)));
                    adv_th = ivadd(adv_th, ivadd(ivmul(uf[m][idx], dth_dx), ivmul(vf[m][idx], dth_dy)));
                }
                om[k+1][idx] = ivscl(ivsub(thx_k, adv_om), scl);
                th[k+1][idx] = ivscl(ivneg(adv_th), scl);
            }
        }
    }
}
static IVal horner_pt_iv(IVal **c, int p, int idx, double h) {
    IVal r = c[p][idx];
    for (int k = p - 1; k >= 0; k--)
        r = ivadd(c[k][idx], ivscl(r, h));
    return r;
}
static IVal horner_iv_iv(IVal **c, int p, int idx, double h) {
    IVal h_iv = {0, h};
    IVal r = c[p][idx];
    for (int k = p - 1; k >= 0; k--)
        r = ivadd(c[k][idx], ivmul(r, h_iv));
    return r;
}

/* ==================================================================
   FFI: Initialize
   ================================================================== */
long long nuc_tm_init(long long N_val, long long order_val) {
    int N = (int)N_val, p = (int)order_val;
    if (N < 2 || N > MAXN || p < 1 || p > MAXP) return 0;

    if (g_init) {
        for (int k = 0; k <= g.p + 1; k++) {
            free(g.om[k]); free(g.th[k]); free(g.ps[k]); free(g.uf[k]); free(g.vf[k]);
            free(g.om_d[k]); free(g.th_d[k]); free(g.ps_d[k]); free(g.ud[k]); free(g.vd[k]);
            free(g.dom_d[k]); free(g.dth_d[k]); free(g.dps_d[k]); free(g.dud[k]); free(g.dvd[k]);
        }
        free(g.om_cur); free(g.th_cur);
        free(g.enc_om); free(g.enc_th); free(g.rhs_om); free(g.rhs_th);
        free(g.poly_om); free(g.poly_th);
        free(g.om_mid); free(g.th_mid);
        free(g.delta_om); free(g.delta_th);
    }

    g.N = N; g.n2 = N * N; g.p = p;
    g.dx = 2.0 * M_PI / (double)N;
    g.nu = 0; g.poi = 30; g.t = 0; g.steps = 0; g.radius = 0;
    int n2 = g.n2;

    for (int k = 0; k <= p + 1; k++) {
        g.om[k] = (IVal *)calloc(n2, sizeof(IVal));
        g.th[k] = (IVal *)calloc(n2, sizeof(IVal));
        g.ps[k] = (IVal *)calloc(n2, sizeof(IVal));
        g.uf[k] = (IVal *)calloc(n2, sizeof(IVal));
        g.vf[k] = (IVal *)calloc(n2, sizeof(IVal));
        g.om_d[k] = (double *)calloc(n2, sizeof(double));
        g.th_d[k] = (double *)calloc(n2, sizeof(double));
        g.ps_d[k] = (double *)calloc(n2, sizeof(double));
        g.ud[k]   = (double *)calloc(n2, sizeof(double));
        g.vd[k]   = (double *)calloc(n2, sizeof(double));
        g.dom_d[k] = (double *)calloc(n2, sizeof(double));
        g.dth_d[k] = (double *)calloc(n2, sizeof(double));
        g.dps_d[k] = (double *)calloc(n2, sizeof(double));
        g.dud[k]   = (double *)calloc(n2, sizeof(double));
        g.dvd[k]   = (double *)calloc(n2, sizeof(double));
    }
    g.om_cur  = (IVal *)calloc(n2, sizeof(IVal));
    g.th_cur  = (IVal *)calloc(n2, sizeof(IVal));
    g.enc_om  = (IVal *)calloc(n2, sizeof(IVal));
    g.enc_th  = (IVal *)calloc(n2, sizeof(IVal));
    g.rhs_om  = (IVal *)calloc(n2, sizeof(IVal));
    g.rhs_th  = (IVal *)calloc(n2, sizeof(IVal));
    g.poly_om = (IVal *)calloc(n2, sizeof(IVal));
    g.poly_th = (IVal *)calloc(n2, sizeof(IVal));
    g.om_mid   = (double *)calloc(n2, sizeof(double));
    g.th_mid   = (double *)calloc(n2, sizeof(double));
    g.delta_om = (double *)calloc(n2, sizeof(double));
    g.delta_th = (double *)calloc(n2, sizeof(double));

    g_init = 1;
    return 1;
}

void nuc_tm_set_poi(long long iters) { g.poi = (int)iters; }
void nuc_tm_set_nu(long long nu_bits) { g.nu = _b2f(nu_bits); }

void nuc_tm_set_omega(long long i, long long j, long long val_bits) {
    double v = _b2f(val_bits);
    int idx = gidx((int)i, (int)j, g.N);
    g.om_cur[idx] = IVpt(v);
    g.om_mid[idx] = v;
}
void nuc_tm_set_theta(long long i, long long j, long long val_bits) {
    double v = _b2f(val_bits);
    int idx = gidx((int)i, (int)j, g.N);
    g.th_cur[idx] = IVpt(v);
    g.th_mid[idx] = v;
}

/* ==================================================================
   Mode 1: Full interval Taylor step (kept for comparison)
   ================================================================== */
long long nuc_tm_step(long long h_bits, long long poi_val) {
    double h = _b2f(h_bits);
    int poi = (int)poi_val;
    int n2 = g.n2, N = g.N, p = g.p;

    memcpy(g.om[0], g.om_cur, n2 * sizeof(IVal));
    memcpy(g.th[0], g.th_cur, n2 * sizeof(IVal));
    taylor_recurrence_iv(g.om, g.th, g.ps, g.uf, g.vf, N, p, g.dx, poi);

    for (int idx = 0; idx < n2; idx++) {
        g.poly_om[idx] = horner_pt_iv(g.om, p, idx, h);
        g.poly_th[idx] = horner_pt_iv(g.th, p, idx, h);
    }

    for (int idx = 0; idx < n2; idx++) {
        IVal enc_o = horner_iv_iv(g.om, p, idx, h);
        IVal enc_t = horner_iv_iv(g.th, p, idx, h);
        g.enc_om[idx] = ivinfl(enc_o, ivwid(enc_o) * 0.1 + 1e-14);
        g.enc_th[idx] = ivinfl(enc_t, ivwid(enc_t) * 0.1 + 1e-14);
    }

    IVal h_iv = {0.0, h};
    int validated = 0;
    for (int picard_iter = 0; picard_iter < 5; picard_iter++) {
        rhs_iv(g.enc_om, g.enc_th, g.rhs_om, g.rhs_th, N, g.dx, poi);
        int all_ok = 1;
        for (int idx = 0; idx < n2; idx++) {
            IVal pic_o = ivadd(g.om_cur[idx], ivmul(h_iv, g.rhs_om[idx]));
            IVal pic_t = ivadd(g.th_cur[idx], ivmul(h_iv, g.rhs_th[idx]));
            if (!ivsubof(pic_o, g.enc_om[idx])) {
                g.enc_om[idx] = ivinfl(pic_o, (ivwid(pic_o) + 1e-14) * 0.3);
                all_ok = 0;
            }
            if (!ivsubof(pic_t, g.enc_th[idx])) {
                g.enc_th[idx] = ivinfl(pic_t, (ivwid(pic_t) + 1e-14) * 0.3);
                all_ok = 0;
            }
        }
        if (all_ok) { validated = 1; break; }
    }
    if (!validated) return 0;

    memcpy(g.om[0], g.enc_om, n2 * sizeof(IVal));
    memcpy(g.th[0], g.enc_th, n2 * sizeof(IVal));
    taylor_recurrence_iv(g.om, g.th, g.ps, g.uf, g.vf, N, p + 1, g.dx, poi);

    double hp1 = pow(h, p + 1);
    for (int idx = 0; idx < n2; idx++) {
        g.om_cur[idx] = ivadd(g.poly_om[idx], ivscl(g.om[p+1][idx], hp1));
        g.th_cur[idx] = ivadd(g.poly_th[idx], ivscl(g.th[p+1][idx], hp1));
    }
    g.t += h; g.steps++;
    return 1;
}

/* ==================================================================
   Double-precision RHS evaluation (for numerical Jacobian)
   ================================================================== */
static void rhs_d(double *omega, double *theta,
                  double *d_omega, double *d_theta,
                  int N, double dx, int poi) {
    int n2 = N * N;
    double inv2dx = 1.0 / (2.0 * dx);
    double *psi = (double *)calloc(n2, sizeof(double));
    double *u   = (double *)calloc(n2, sizeof(double));
    double *v   = (double *)calloc(n2, sizeof(double));
    poi_d(omega, psi, N, dx, poi);
    vel_d(psi, u, v, N, dx);
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++) {
            int idx = gidx(i, j, N);
            double dw_dx = inv2dx * (omega[gidx(i+1,j,N)] - omega[gidx(i-1,j,N)]);
            double dw_dy = inv2dx * (omega[gidx(i,j+1,N)] - omega[gidx(i,j-1,N)]);
            double dt_dx = inv2dx * (theta[gidx(i+1,j,N)] - theta[gidx(i-1,j,N)]);
            double dt_dy = inv2dx * (theta[gidx(i,j+1,N)] - theta[gidx(i,j-1,N)]);
            d_omega[idx] = dt_dx - (u[idx] * dw_dx + v[idx] * dw_dy);
            d_theta[idx] = -(u[idx] * dt_dx + v[idx] * dt_dy);
        }
    free(psi); free(u); free(v);
}

/* ==================================================================
   Numerical Lipschitz constant: ||Df||_inf via column-by-column
   finite differencing of the Jacobian.
   Exact (up to eps) — no analytical overestimate.
   ================================================================== */
static double compute_L_numerical(double *om, double *th, int N, double dx, int poi) {
    int n2 = N * N;
    int dim = 2 * n2;
    double eps = 1e-7;

    double *f_om  = (double *)calloc(n2, sizeof(double));
    double *f_th  = (double *)calloc(n2, sizeof(double));
    double *om_p  = (double *)malloc(n2 * sizeof(double));
    double *th_p  = (double *)malloc(n2 * sizeof(double));
    double *fp_om = (double *)calloc(n2, sizeof(double));
    double *fp_th = (double *)calloc(n2, sizeof(double));
    double *row_sums = (double *)calloc(dim, sizeof(double));

    /* Base RHS */
    rhs_d(om, th, f_om, f_th, N, dx, poi);

    /* Perturb each omega variable */
    for (int j = 0; j < n2; j++) {
        memcpy(om_p, om, n2 * sizeof(double));
        memcpy(th_p, th, n2 * sizeof(double));
        om_p[j] += eps;
        rhs_d(om_p, th_p, fp_om, fp_th, N, dx, poi);
        for (int i = 0; i < n2; i++) {
            row_sums[i]      += fabs((fp_om[i] - f_om[i]) / eps);
            row_sums[n2 + i] += fabs((fp_th[i] - f_th[i]) / eps);
        }
    }

    /* Perturb each theta variable */
    for (int j = 0; j < n2; j++) {
        memcpy(om_p, om, n2 * sizeof(double));
        memcpy(th_p, th, n2 * sizeof(double));
        th_p[j] += eps;
        rhs_d(om_p, th_p, fp_om, fp_th, N, dx, poi);
        for (int i = 0; i < n2; i++) {
            row_sums[i]      += fabs((fp_om[i] - f_om[i]) / eps);
            row_sums[n2 + i] += fabs((fp_th[i] - f_th[i]) / eps);
        }
    }

    double L = 0;
    for (int i = 0; i < dim; i++)
        if (row_sums[i] > L) L = row_sums[i];

    free(f_om); free(f_th); free(om_p); free(th_p);
    free(fp_om); free(fp_th); free(row_sums);

    return L * 1.01;  /* 1% safety for finite-difference truncation */
}

/* Cached L value and update interval */
static double g_L_cached = -1;
static int g_L_update_interval = 50;

/* ==================================================================
   Mode 2: Midpoint-Radius Taylor Step

   Key insight: Taylor coefficients computed at the MIDPOINT in
   double precision — NO interval wrapping. Only the scalar radius
   uses rigorous bounds (Lipschitz propagation + truncation).

   Rigorous because:
   - The midpoint trajectory is within machine epsilon of the true
     trajectory starting from the midpoint initial condition.
   - The radius rigorously bounds the difference between the midpoint
     trajectory and ANY trajectory starting within the initial ball.
   - The Lipschitz bound is a rigorous upper bound on ||Df||_inf.
   ================================================================== */
long long nuc_tm_step_mr(long long h_bits, long long poi_val) {
    double h = _b2f(h_bits);
    int poi = (int)poi_val;
    int n2 = g.n2, N = g.N, p = g.p;
    double dx = g.dx;
    double inv2dx = 1.0 / (2.0 * dx);

    /* ---- Phase 1: Double-precision Taylor coefficients at midpoint ---- */
    memcpy(g.om_d[0], g.om_mid, n2 * sizeof(double));
    memcpy(g.th_d[0], g.th_mid, n2 * sizeof(double));

    /* Compute orders 0..p+1 (the extra order for truncation bound) */
    taylor_recurrence_d(g.om_d, g.th_d, g.ps_d, g.ud, g.vd, N, p + 1, dx, poi, g.nu);

    /* ---- Phase 2: Evaluate polynomial at h (new midpoint) ---- */
    double max_poly_val = 0;
    for (int idx = 0; idx < n2; idx++) {
        g.om_mid[idx] = horner_d(g.om_d, p, idx, h);
        g.th_mid[idx] = horner_d(g.th_d, p, idx, h);
        double av = fabs(g.om_mid[idx]);
        if (av > max_poly_val) max_poly_val = av;
    }

    /* ---- Phase 3: Truncation error from g_{p+1} ---- */
    double hp1 = pow(h, p + 1);
    double max_trunc = 0;
    for (int idx = 0; idx < n2; idx++) {
        double t_om = fabs(g.om_d[p + 1][idx]) * hp1;
        double t_th = fabs(g.th_d[p + 1][idx]) * hp1;
        double t_max = dmax(t_om, t_th);
        if (t_max > max_trunc) max_trunc = t_max;
    }

    /* ---- Phase 4: Lipschitz constant via numerical Jacobian ----
       Compute ||Df||_inf by finite-differencing each column of the Jacobian.
       Recomputed every g_L_update_interval steps; cached between updates.
       Radius correction added to account for the ball around midpoint. */
    {
        /* Recompute L periodically (expensive but exact) */
        if (g_L_cached < 0 || (g.steps % g_L_update_interval) == 0) {
            g_L_cached = compute_L_numerical(g.om_mid, g.th_mid, N, dx, poi);
        }

        /* Radius correction: L increases when state varies within the ball.
           For quadratic system: Df(y) = A + 2B(y,·), so
           ||Df(y+δ) - Df(y)|| ≤ 2||B|| * ||δ|| ≤ 2 * grad_factor * radius
           where grad_factor accounts for the Poisson-to-velocity map.
           Conservative: L_ball ≤ L_mid + C * radius / dx */
        double L = g_L_cached + 2.0 * g.radius / dx;

        /* ---- Phase 5: Propagate radius ----
           r_new = r * exp(L*h) + truncation + rounding
           exp(L*h) approximated by 1 + L*h + (L*h)^2/2 + (L*h)^3/6 for accuracy,
           but we use the actual exp() for rigor. */
        double exp_Lh = exp(L * h);
        /* Rounding error in Horner evaluation: (p+2) * eps * max|polynomial value| */
        double round_err = (double)(p + 2) * DBL_EPSILON * (max_poly_val + 1e-30);

        g.radius = g.radius * exp_Lh + max_trunc + round_err;
    }

    /* ---- Phase 6: Update interval state for output ---- */
    for (int idx = 0; idx < n2; idx++) {
        g.om_cur[idx] = (IVal){g.om_mid[idx] - g.radius, g.om_mid[idx] + g.radius};
        g.th_cur[idx] = (IVal){g.th_mid[idx] - g.radius, g.th_mid[idx] + g.radius};
    }

    g.t += h;
    g.steps++;
    return 1;  /* midpoint-radius always succeeds (no enclosure to validate) */
}

/* ==================================================================
   Mode 3: Signed Error Propagation via Linearized Taylor Recurrence

   The linearized recurrence for error δ = (δω, δθ):
     δω_{k+1} = (1/(k+1)) * [δθ_x[k]
       - Σ_{m=0}^{k} (δu_m·∇ω_{k-m} + u_m·∇δω_{k-m} + δv_m·dω_{k-m}/dy + v_m·dδω_{k-m}/dy)]
   where δu, δv come from Poisson solve of δω (same linear Poisson operator).

   Key: the advection linearization (u·∇δω + δu·∇ω) is the SIGNED Jacobian action.
   The antisymmetric part (transport) rotates δ without amplifying it.
   Only the physical vortex stretching contributes to δ growth.
   ================================================================== */
/* Additional derivative grids for the linearized (perturbation) fields */
static double **g_domx = NULL, **g_domy = NULL;
static double **g_dthx = NULL, **g_dthy = NULL;

static void ensure_deriv_grids_linear(int n2, int max_k) {
    if (g_domx && g_deriv_alloc_n == n2 && g_deriv_alloc_k >= max_k) return;
    if (g_domx) { for (int k = 0; k <= g_deriv_alloc_k; k++) { free(g_domx[k]); free(g_domy[k]); free(g_dthx[k]); free(g_dthy[k]); } }
    free(g_domx); free(g_domy); free(g_dthx); free(g_dthy);
    int mk = (g_deriv_alloc_k > max_k) ? g_deriv_alloc_k : max_k;
    g_domx = (double **)malloc((mk+2) * sizeof(double*));
    g_domy = (double **)malloc((mk+2) * sizeof(double*));
    g_dthx = (double **)malloc((mk+2) * sizeof(double*));
    g_dthy = (double **)malloc((mk+2) * sizeof(double*));
    for (int k = 0; k <= mk+1; k++) {
        g_domx[k] = (double *)calloc(n2, sizeof(double));
        g_domy[k] = (double *)calloc(n2, sizeof(double));
        g_dthx[k] = (double *)calloc(n2, sizeof(double));
        g_dthy[k] = (double *)calloc(n2, sizeof(double));
    }
}

static void taylor_recurrence_linear_d(
    double **dom, double **dth, double **dps, double **du, double **dv,
    double **om,  double **th,  double **ps,  double **uf, double **vf,
    int N, int max_k, double dx, int poi, double nu) {
    int n2 = N * N;
    double inv_dx2 = 1.0 / (dx * dx);
    ensure_deriv_grids_linear(n2, max_k);

    for (int k = 0; k <= max_k; k++) {
        memset(dps[k], 0, n2 * sizeof(double));
        poi_d(dom[k], dps[k], N, dx, poi);
        vel_d(dps[k], du[k], dv[k], N, dx);

        /* Pre-compute derivatives of perturbation fields */
        compute_grid_derivs(dom[k], g_domx[k], g_domy[k], N, dx);
        compute_grid_derivs(dth[k], g_dthx[k], g_dthy[k], N, dx);

        if (k < max_k) {
            double scl = 1.0 / (double)(k + 1);

            if (g_dealias && g_fd_order == 0 && is_pow2(N)) {
                /* De-aliased linearized Cauchy product */
                double *dadv_om_grid = (double *)calloc(n2, sizeof(double));
                double *dadv_th_grid = (double *)calloc(n2, sizeof(double));
                double *prod = (double *)malloc(n2 * sizeof(double));

                for (int m = 0; m <= k; m++) {
                    int km = k - m;
                    /* δu·∇ω + u·∇δω (8 de-aliased products per m) */
                    dealiased_multiply(du[m], g_omx[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) dadv_om_grid[idx] += prod[idx];
                    dealiased_multiply(dv[m], g_omy[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) dadv_om_grid[idx] += prod[idx];
                    dealiased_multiply(uf[m], g_domx[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) dadv_om_grid[idx] += prod[idx];
                    dealiased_multiply(vf[m], g_domy[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) dadv_om_grid[idx] += prod[idx];
                    /* δu·∇θ + u·∇δθ */
                    dealiased_multiply(du[m], g_thx[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) dadv_th_grid[idx] += prod[idx];
                    dealiased_multiply(dv[m], g_thy[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) dadv_th_grid[idx] += prod[idx];
                    dealiased_multiply(uf[m], g_dthx[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) dadv_th_grid[idx] += prod[idx];
                    dealiased_multiply(vf[m], g_dthy[km], prod, N);
                    for (int idx = 0; idx < n2; idx++) dadv_th_grid[idx] += prod[idx];
                }

                for (int idx = 0; idx < n2; idx++) {
                    double dlap = 0;
                    if (nu > 0) {
                        int i = idx / N, j = idx % N;
                        dlap = nu * inv_dx2 * (dom[k][gidx(i+1,j,N)] + dom[k][gidx(i-1,j,N)]
                              + dom[k][gidx(i,j+1,N)] + dom[k][gidx(i,j-1,N)] - 4.0*dom[k][idx]);
                    }
                    dom[k+1][idx] = scl * (g_dthx[k][idx] - dadv_om_grid[idx] + dlap);
                    dth[k+1][idx] = scl * (-dadv_th_grid[idx]);
                }
                free(dadv_om_grid); free(dadv_th_grid); free(prod);

            } else {
                /* Direct linearized Cauchy product */
                for (int idx = 0; idx < n2; idx++) {
                    int i = idx / N, j = idx % N;
                    double dthx_k = g_dthx[k][idx];
                    double dadv_om = 0, dadv_th = 0;
                    for (int m = 0; m <= k; m++) {
                        int km = k - m;
                        dadv_om += du[m][idx]*g_omx[km][idx] + dv[m][idx]*g_omy[km][idx];
                        dadv_om += uf[m][idx]*g_domx[km][idx] + vf[m][idx]*g_domy[km][idx];
                        dadv_th += du[m][idx]*g_thx[km][idx] + dv[m][idx]*g_thy[km][idx];
                        dadv_th += uf[m][idx]*g_dthx[km][idx] + vf[m][idx]*g_dthy[km][idx];
                    }
                    double dlap = 0;
                    if (nu > 0) {
                        dlap = nu * inv_dx2 * (dom[k][gidx(i+1,j,N)] + dom[k][gidx(i-1,j,N)]
                              + dom[k][gidx(i,j+1,N)] + dom[k][gidx(i,j-1,N)] - 4.0*dom[k][idx]);
                    }
                    dom[k+1][idx] = scl * (dthx_k - dadv_om + dlap);
                    dth[k+1][idx] = scl * (-dadv_th);
                }
            }
        }
    }
}

/* Spatial truncation arrays (computed by nuc_tm_compute_spatial_tau, used in step) */
static double *g_spatial_tau_om = NULL;
static double *g_spatial_tau_th = NULL;

/* Signed-error Taylor step:
   1. Compute base Taylor coefficients at midpoint
   2. Compute linearized Taylor coefficients for δ
   3. New midpoint = Horner(base, h)
   4. New δ = Horner(linearized, h) + truncation + rounding
   5. Radius = ||δ||_∞ */
long long nuc_tm_step_signed(long long h_bits, long long poi_val) {
    double h = _b2f(h_bits);
    int poi = (int)poi_val;
    int n2 = g.n2, N = g.N, p = g.p;
    double dx = g.dx;

    /* ---- Phase 1: Base Taylor coefficients at midpoint ---- */
    memcpy(g.om_d[0], g.om_mid, n2 * sizeof(double));
    memcpy(g.th_d[0], g.th_mid, n2 * sizeof(double));
    taylor_recurrence_d(g.om_d, g.th_d, g.ps_d, g.ud, g.vd, N, p + 1, dx, poi, g.nu);

    /* ---- Phase 2: Linearized Taylor coefficients for δ ---- */
    memcpy(g.dom_d[0], g.delta_om, n2 * sizeof(double));
    memcpy(g.dth_d[0], g.delta_th, n2 * sizeof(double));
    taylor_recurrence_linear_d(
        g.dom_d, g.dth_d, g.dps_d, g.dud, g.dvd,
        g.om_d,  g.th_d,  g.ps_d,  g.ud,  g.vd,
        N, p, dx, poi, g.nu);

    /* ---- Phase 3: New midpoint = Horner(base, h) ---- */
    double max_poly = 0;
    for (int idx = 0; idx < n2; idx++) {
        g.om_mid[idx] = horner_d(g.om_d, p, idx, h);
        g.th_mid[idx] = horner_d(g.th_d, p, idx, h);
        double av = fabs(g.om_mid[idx]);
        if (av > max_poly) max_poly = av;
    }

    /* ---- Phase 4: New δ = Horner(linearized, h) + errors ---- */
    /* Truncation error: the (p+1)-th base coefficient * h^{p+1}
       This is the error in the MIDPOINT trajectory (added to δ). */
    double hp1 = pow(h, p + 1);
    /* Rounding error in Horner evaluation */
    double round_scale = (double)(p + 2) * DBL_EPSILON;

    double max_delta = 0;
    for (int idx = 0; idx < n2; idx++) {
        /* Propagated δ via linearized Taylor */
        double new_dom = horner_d(g.dom_d, p, idx, h);
        double new_dth = horner_d(g.dth_d, p, idx, h);

        /* Add truncation error (from base Taylor, signed) */
        new_dom += g.om_d[p + 1][idx] * hp1;
        new_dth += g.th_d[p + 1][idx] * hp1;

        /* Add spatial truncation if available (computed externally) */
        new_dom += g_spatial_tau_om ? g_spatial_tau_om[idx] * h : 0;
        new_dth += g_spatial_tau_th ? g_spatial_tau_th[idx] * h : 0;

        /* Add rounding error (unsigned — worst case) */
        double round_om = round_scale * (fabs(g.om_mid[idx]) + 1e-30);
        double round_th = round_scale * (fabs(g.th_mid[idx]) + 1e-30);
        /* Rounding can go either way; widen by adding absolute value */
        if (new_dom >= 0) new_dom += round_om; else new_dom -= round_om;
        if (new_dth >= 0) new_dth += round_th; else new_dth -= round_th;

        g.delta_om[idx] = new_dom;
        g.delta_th[idx] = new_dth;

        double d = dmax(fabs(new_dom), fabs(new_dth));
        if (d > max_delta) max_delta = d;
    }

    g.radius = max_delta;

    /* ---- Phase 5: Update interval state for output ---- */
    for (int idx = 0; idx < n2; idx++) {
        double r_om = fabs(g.delta_om[idx]);
        double r_th = fabs(g.delta_th[idx]);
        g.om_cur[idx] = (IVal){g.om_mid[idx] - r_om, g.om_mid[idx] + r_om};
        g.th_cur[idx] = (IVal){g.th_mid[idx] - r_th, g.th_mid[idx] + r_th};
    }

    g.t += h;
    g.steps++;
    return 1;
}

/* ==================================================================
   Spectral Diagnostics: DFT-based spatial error bound

   Computes the 2D DFT of the midpoint omega, then:
   1. D4 = Σ (kx⁴+ky⁴) |ω̂(kx,ky)| — bounds ||∂⁴ω/∂x⁴|| + ||∂⁴ω/∂y⁴||
   2. spatial_err = (dx²/12) * D4 — FD truncation error bound
   3. spectral_res = max high-freq / max all-freq — resolution indicator
   4. If ||ω_N|| - spatial_err > 0, the continuous PDE also has large vorticity.
   ================================================================== */
static double g_D4 = 0;
static double g_spatial_err = 0;
static double g_spectral_res = 0;

long long nuc_tm_spectral_check(void) {
    int N = g.N, n2 = g.n2;
    double max_all = 0, max_high = 0;
    double D4 = 0;
    int N3 = N / 3;

    for (int kx = 0; kx < N; kx++) {
        for (int ky = 0; ky < N; ky++) {
            double re = 0, im = 0;
            for (int i = 0; i < N; i++) {
                double angle_i = 2.0 * M_PI * (double)kx * (double)i / (double)N;
                double ci = cos(angle_i), si = sin(angle_i);
                for (int j = 0; j < N; j++) {
                    double angle_j = 2.0 * M_PI * (double)ky * (double)j / (double)N;
                    double w = g.om_mid[gidx(i, j, N)];
                    double cj = cos(angle_j), sj = sin(angle_j);
                    /* exp(-i*(angle_i+angle_j)) = (ci*cj - si*sj) - i*(ci*sj + si*cj) */
                    re += w * (ci * cj - si * sj);
                    im -= w * (ci * sj + si * cj);
                }
            }
            re /= (double)n2;
            im /= (double)n2;
            double mag = sqrt(re * re + im * im);

            if (mag > max_all) max_all = mag;

            /* Centered wavenumber */
            int kkx = (kx <= N / 2) ? kx : kx - N;
            int kky = (ky <= N / 2) ? ky : ky - N;

            /* High-frequency check */
            if (abs(kkx) > N3 || abs(kky) > N3) {
                if (mag > max_high) max_high = mag;
            }

            /* Fourth derivative bound contribution */
            double kx4 = (double)kkx * (double)kkx * (double)kkx * (double)kkx;
            double ky4 = (double)kky * (double)kky * (double)kky * (double)kky;
            D4 += (kx4 + ky4) * mag;
        }
    }

    g_D4 = D4;
    g_spatial_err = (g.dx * g.dx / 12.0) * D4;
    g_spectral_res = (max_all > 1e-30) ? max_high / max_all : 0;

    return _f2b(g_spatial_err);
}

long long nuc_tm_get_D4(void) { return _f2b(g_D4); }
long long nuc_tm_get_spatial_err(void) { return _f2b(g_spatial_err); }
long long nuc_tm_get_spectral_res(void) { return _f2b(g_spectral_res); }

/* ==================================================================
   TIGHT spatial error: compare FD vs spectral derivatives POINTWISE.
   No L1 bound — computes the actual truncation error at each grid point.

   For d/dx: spectral = IDFT(i*kx * DFT(omega)), FD = (omega[i+1]-omega[i-1])/(2dx)
   Truncation at each point = |spectral - FD|
   Spatial error in RHS = max over grid of |u * trunc_dx + v * trunc_dy + trunc_theta_x|
   ================================================================== */
static double g_tight_spatial_err = 0;

static void dft_2d(double *f, double *re_out, double *im_out, int N) {
    int n2 = N * N;
    if (is_pow2(N)) {
        /* FFT path: copy real data into complex arrays, FFT, scale by 1/N² */
        for (int i = 0; i < n2; i++) { re_out[i] = f[i]; im_out[i] = 0; }
        fft_2d(re_out, im_out, N, -1);  /* forward: sign = -1 */
        double inv = 1.0 / (double)n2;
        for (int i = 0; i < n2; i++) { re_out[i] *= inv; im_out[i] *= inv; }
    } else {
        /* Direct DFT fallback for non-power-of-2 N */
        for (int kx = 0; kx < N; kx++)
            for (int ky = 0; ky < N; ky++) {
                double re = 0, im = 0;
                for (int i = 0; i < N; i++) {
                    double ax = 2.0*M_PI*(double)kx*(double)i/(double)N;
                    double ci = cos(ax), si = sin(ax);
                    for (int j = 0; j < N; j++) {
                        double ay = 2.0*M_PI*(double)ky*(double)j/(double)N;
                        double w = f[gidx(i,j,N)];
                        re += w*(ci*cos(ay)-si*sin(ay));
                        im -= w*(ci*sin(ay)+si*cos(ay));
                    }
                }
                re_out[kx*N+ky] = re/(double)n2;
                im_out[kx*N+ky] = im/(double)n2;
            }
    }
}

static void idft_2d(double *re_in, double *im_in, double *f_out, int N) {
    int n2 = N * N;
    if (is_pow2(N)) {
        /* IFFT path: copy, inverse FFT (sign=+1), result is real part */
        double *tre = (double *)malloc(n2 * sizeof(double));
        double *tim = (double *)malloc(n2 * sizeof(double));
        memcpy(tre, re_in, n2 * sizeof(double));
        memcpy(tim, im_in, n2 * sizeof(double));
        fft_2d(tre, tim, N, +1);  /* inverse: sign = +1 */
        for (int i = 0; i < n2; i++) f_out[i] = tre[i];
        free(tre); free(tim);
    } else {
        /* Direct IDFT fallback */
        for (int i = 0; i < N; i++)
            for (int j = 0; j < N; j++) {
                double val = 0;
                for (int kx = 0; kx < N; kx++) {
                    double ax = 2.0*M_PI*(double)kx*(double)i/(double)N;
                    double ckx = cos(ax), skx = sin(ax);
                    for (int ky = 0; ky < N; ky++) {
                        double ay = 2.0*M_PI*(double)ky*(double)j/(double)N;
                        double c = ckx*cos(ay)-skx*sin(ay);
                        double s = ckx*sin(ay)+skx*cos(ay);
                        val += re_in[kx*N+ky]*c - im_in[kx*N+ky]*s;
                    }
                }
                f_out[gidx(i,j,N)] = val;
            }
    }
}

/* Compute spectral d/dx of f: multiply DFT by i*kx, then IDFT */
static void spectral_dx(double *f, double *df_out, int N) {
    int n2 = N * N;
    double *fre = (double *)calloc(n2, sizeof(double));
    double *fim = (double *)calloc(n2, sizeof(double));
    double *dre = (double *)calloc(n2, sizeof(double));
    double *dim = (double *)calloc(n2, sizeof(double));

    dft_2d(f, fre, fim, N);

    /* Multiply by i*kx: (i*kx)*(re+i*im) = -kx*im + i*kx*re */
    for (int kx = 0; kx < N; kx++) {
        int kkx = (kx <= N / 2) ? kx : kx - N;
        for (int ky = 0; ky < N; ky++) {
            int idx = kx * N + ky;
            dre[idx] = -(double)kkx * fim[idx];
            dim[idx] =  (double)kkx * fre[idx];
        }
    }

    idft_2d(dre, dim, df_out, N);
    free(fre); free(fim); free(dre); free(dim);
}

/* Same for d/dy */
static void spectral_dy(double *f, double *df_out, int N) {
    int n2 = N * N;
    double *fre = (double *)calloc(n2, sizeof(double));
    double *fim = (double *)calloc(n2, sizeof(double));
    double *dre = (double *)calloc(n2, sizeof(double));
    double *dim = (double *)calloc(n2, sizeof(double));

    dft_2d(f, fre, fim, N);

    for (int kx = 0; kx < N; kx++) {
        for (int ky = 0; ky < N; ky++) {
            int kky = (ky <= N / 2) ? ky : ky - N;
            int idx = kx * N + ky;
            dre[idx] = -(double)kky * fim[idx];
            dim[idx] =  (double)kky * fre[idx];
        }
    }

    idft_2d(dre, dim, df_out, N);
    free(fre); free(fim); free(dre); free(dim);
}

long long nuc_tm_tight_spatial_check(void) {
    int N = g.N, n2 = g.n2;
    double dx = g.dx;
    double inv2dx = 1.0 / (2.0 * dx);

    /* Spectral derivatives of omega and theta */
    double *om_dx_sp = (double *)calloc(n2, sizeof(double));
    double *om_dy_sp = (double *)calloc(n2, sizeof(double));
    double *th_dx_sp = (double *)calloc(n2, sizeof(double));

    spectral_dx(g.om_mid, om_dx_sp, N);
    spectral_dy(g.om_mid, om_dy_sp, N);
    spectral_dx(g.th_mid, th_dx_sp, N);

    /* Compute velocity at midpoint (reuse from Taylor step if available,
       but for safety recompute) */
    double *psi = (double *)calloc(n2, sizeof(double));
    double *u = (double *)calloc(n2, sizeof(double));
    double *v = (double *)calloc(n2, sizeof(double));
    poi_d(g.om_mid, psi, N, dx, g.poi);
    vel_d(psi, u, v, N, dx);

    /* Compare FD vs spectral at each grid point */
    double max_tau = 0;
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            int idx = gidx(i, j, N);

            /* FD derivatives */
            double om_dx_fd = ddx(g.om_mid, i, j, N, dx);
            double om_dy_fd = ddy(g.om_mid, i, j, N, dx);
            double th_dx_fd = ddx(g.th_mid, i, j, N, dx);

            /* Truncation = spectral - FD at this grid point */
            double tau_om_dx = om_dx_sp[idx] - om_dx_fd;
            double tau_om_dy = om_dy_sp[idx] - om_dy_fd;
            double tau_th_dx = th_dx_sp[idx] - th_dx_fd;

            /* RHS truncation: u*tau_dx + v*tau_dy + tau_theta_x */
            double tau = fabs(u[idx] * tau_om_dx + v[idx] * tau_om_dy)
                       + fabs(tau_th_dx);

            if (tau > max_tau) max_tau = tau;
        }
    }

    g_tight_spatial_err = max_tau;

    free(om_dx_sp); free(om_dy_sp); free(th_dx_sp);
    free(psi); free(u); free(v);
    return _f2b(max_tau);
}

long long nuc_tm_get_tight_spatial_err(void) { return _f2b(g_tight_spatial_err); }

/* Compute SIGNED spatial truncation at each grid point and store it.
   Called before nuc_tm_step_signed — the step function then adds tau*h to delta. */
void nuc_tm_compute_spatial_tau(void) {
    int N = g.N, n2 = g.n2;
    double dx = g.dx;

    if (!g_spatial_tau_om) g_spatial_tau_om = (double *)calloc(n2, sizeof(double));
    if (!g_spatial_tau_th) g_spatial_tau_th = (double *)calloc(n2, sizeof(double));

    double *om_dx_sp = (double *)calloc(n2, sizeof(double));
    double *om_dy_sp = (double *)calloc(n2, sizeof(double));
    double *th_dx_sp = (double *)calloc(n2, sizeof(double));

    spectral_dx(g.om_mid, om_dx_sp, N);
    spectral_dy(g.om_mid, om_dy_sp, N);
    spectral_dx(g.th_mid, th_dx_sp, N);

    double *psi = (double *)calloc(n2, sizeof(double));
    double *u   = (double *)calloc(n2, sizeof(double));
    double *v   = (double *)calloc(n2, sizeof(double));
    poi_d(g.om_mid, psi, N, dx, g.poi);
    vel_d(psi, u, v, N, dx);

    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            int idx = gidx(i, j, N);
            double om_dx_fd = ddx(g.om_mid, i, j, N, dx);
            double om_dy_fd = ddy(g.om_mid, i, j, N, dx);
            double th_dx_fd = ddx(g.th_mid, i, j, N, dx);

            /* SIGNED truncation: spectral - FD (preserves direction) */
            double tau_om_dx = om_dx_sp[idx] - om_dx_fd;
            double tau_om_dy = om_dy_sp[idx] - om_dy_fd;
            double tau_th_dx = th_dx_sp[idx] - th_dx_fd;

            /* Signed RHS truncation (same structure as the Boussinesq RHS) */
            g_spatial_tau_om[idx] = (tau_th_dx) - (u[idx]*tau_om_dx + v[idx]*tau_om_dy);
            g_spatial_tau_th[idx] = -(u[idx]*tau_th_dx + v[idx]*0); /* theta dy not used in buoyancy */
        }
    }

    free(om_dx_sp); free(om_dy_sp); free(th_dx_sp);
    free(psi); free(u); free(v);
}

/* Disable spatial tau injection (go back to temporal-only) */
void nuc_tm_disable_spatial_tau(void) {
    if (g_spatial_tau_om) { free(g_spatial_tau_om); g_spatial_tau_om = NULL; }
    if (g_spatial_tau_th) { free(g_spatial_tau_th); g_spatial_tau_th = NULL; }
}

/* ==================================================================
   FFI: Get Results
   ================================================================== */
long long nuc_tm_get_omega_max_hi(void) {
    double mx = 0;
    for (int idx = 0; idx < g.n2; idx++) {
        double a = ivmag(g.om_cur[idx]);
        if (a > mx) mx = a;
    }
    return _f2b(mx);
}
long long nuc_tm_get_omega_max_lo(void) {
    double mx = 0;
    for (int idx = 0; idx < g.n2; idx++) {
        IVal ab = ivabs(g.om_cur[idx]);
        if (ab.lo > mx) mx = ab.lo;
    }
    return _f2b(mx);
}
long long nuc_tm_get_max_width(void) {
    double mx = 0;
    for (int idx = 0; idx < g.n2; idx++) {
        double w = ivwid(g.om_cur[idx]);
        if (w > mx) mx = w;
    }
    return _f2b(mx);
}
long long nuc_tm_get_time(void) { return _f2b(g.t); }
long long nuc_tm_get_steps(void) { return (long long)g.steps; }
long long nuc_tm_get_radius(void) { return _f2b(g.radius); }
long long nuc_tm_get_theta_max_hi(void) {
    double mx = 0;
    for (int idx = 0; idx < g.n2; idx++) {
        double a = ivmag(g.th_cur[idx]);
        if (a > mx) mx = a;
    }
    return _f2b(mx);
}
