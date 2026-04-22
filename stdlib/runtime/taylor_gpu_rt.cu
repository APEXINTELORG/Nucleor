// taylor_gpu_rt.cu — GPU-accelerated Taylor Model for Boussinesq
//
// Replaces the CPU FFT pipeline with cuFFT + CUDA kernels.
// All working arrays live in GPU VRAM — no per-step allocations.
// The Taylor recurrence loop runs on CPU, dispatching GPU kernels.
//
// Memory strategy (learned from M5 52GB leak):
//   - ALL GPU arrays allocated once in gpu_init()
//   - ZERO allocations in the step function
//   - gpu_cleanup() frees everything + destroys cuFFT plans
//   - nuc_tm_init() calls gpu_cleanup() before re-init
//
// Compile:
//   nvcc -c stdlib/runtime/taylor_gpu_rt.cu -o target/taylor_gpu_rt.obj
//        -O2 --gpu-architecture=sm_89 -Xcompiler "/EHsc"
//
// Link with: taylor_rt.obj (CPU fallback), cufft.lib, cudart.lib

#include <cufft.h>
#include <cuda_runtime.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// ================================================================
// GPU Error Checking
// ================================================================
#define CUDA_CHECK(call) do { \
    cudaError_t err = (call); \
    if (err != cudaSuccess) { \
        fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__, __LINE__, \
                cudaGetErrorString(err)); \
    } \
} while(0)

#define CUFFT_CHECK(call) do { \
    cufftResult err = (call); \
    if (err != CUFFT_SUCCESS) { \
        fprintf(stderr, "cuFFT error at %s:%d: %d\n", __FILE__, __LINE__, err); \
    } \
} while(0)

// ================================================================
// FFI helpers
// ================================================================
static double _b2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _f2b(double f) { long long i; memcpy(&i, &f, 8); return i; }

// ================================================================
// GPU State — ALL persistent, allocated once
// ================================================================
#define GPU_MAXP 12
#define GPU_MAXK (GPU_MAXP + 2)

typedef struct {
    int N, n2, p;
    int M, m2;          // de-aliased size (next pow2 >= 3N/2)
    double dx, nu;
    int initialized;

    // Taylor coefficients on GPU (base + linearized)
    double *d_om[GPU_MAXK], *d_th[GPU_MAXK];   // omega, theta
    double *d_ps[GPU_MAXK];                      // psi (stream function)
    double *d_uf[GPU_MAXK], *d_vf[GPU_MAXK];   // velocity
    double *d_dom[GPU_MAXK], *d_dth[GPU_MAXK];  // linearized omega, theta
    double *d_dps[GPU_MAXK];
    double *d_duf[GPU_MAXK], *d_dvf[GPU_MAXK];

    // Pre-computed derivatives on GPU
    double *d_omx[GPU_MAXK], *d_omy[GPU_MAXK];  // d(omega)/dx, dy
    double *d_thx[GPU_MAXK], *d_thy[GPU_MAXK];
    double *d_domx[GPU_MAXK], *d_domy[GPU_MAXK];
    double *d_dthx[GPU_MAXK], *d_dthy[GPU_MAXK];

    // Midpoint + error on GPU
    double *d_om_mid, *d_th_mid;
    double *d_delta_om, *d_delta_th;

    // Scratch arrays on GPU (reused, never freed mid-run)
    cufftDoubleComplex *d_fft_a, *d_fft_b;       // N×N complex
    cufftDoubleComplex *d_fft_pa, *d_fft_pb;     // M×M complex (de-alias)
    double *d_phys_a, *d_phys_b, *d_phys_c;      // M×M real scratch
    double *d_scratch1, *d_scratch2;              // N×N real scratch
    double *d_comp1, *d_comp2;                    // Horner compensation arrays
    cufftDoubleComplex *d_poisson_buf;            // N×N complex for Poisson

    // cuFFT plans (persistent)
    cufftHandle plan_N;   // N×N complex-to-complex
    cufftHandle plan_M;   // M×M complex-to-complex
    int plans_created;

    // Host-side pre-allocated buffers (for Horner reduction — NO per-step malloc)
    double *h_host_mid;    // n2 doubles
    double *h_host_delta;  // n2 doubles
    double *h_host_mid2;   // second midpoint workspace (n2 doubles)
    double *h_host_delta2; // second delta workspace (n2 doubles)

    // Host-side results (small, for FFI output)
    double h_omega_max_lo, h_omega_max_hi, h_radius;
    int h_peak_i, h_peak_j;        // location of max |omega|
    double h_peak_val;              // value at peak
    double h_growth_rate;           // dω/dt at peak = ω[1] at (peak_i, peak_j)
    double h_enstrophy;             // Ω = ∫ω² dx (midpoint)
    double h_enstrophy_lo;          // Ω_lo = ∫max(0,|ω|-|δω|)² dx (rigorous lower)
    double h_enstrophy_hi;          // Ω_hi = ∫(|ω|+|δω|)² dx (rigorous upper)
    double h_enstrophy_rate;        // dΩ/dt = 2∫ω·θ_x dx (forcing, midpoint)
    double h_enstrophy_rate_lo;     // rigorous lower bound on 2∫ω·θ_x dx
    double h_enstrophy_rate_hi;     // rigorous upper bound on 2∫ω·θ_x dx
    double h_palinstrophy;          // P = ∫|∇ω|² dx
    double h_enstrophy_dissip;      // 2ν·P (viscous dissipation of enstrophy)
    double h_enstrophy_net_rate;    // forcing - dissipation = 2∫ω·θ_x - 2ν∫|∇ω|²
    // Spectral peak interpolation
    double h_interp_x, h_interp_y;  // sub-grid peak location (radians)
    double h_interp_omega;           // ω at interpolated peak
    double h_interp_growth;          // dω/dt at interpolated peak
    double h_nbr_max_growth;         // max dω/dt in neighborhood of peak

    // Fourier-tail diagnostic
    double h_fourier_alpha;         // exponential decay rate
    double h_fourier_C;             // amplitude constant
    double *h_shell_amps;           // shell-averaged Fourier amplitudes (N/2 entries)
    int h_shell_count;              // number of shells

    // Gap 1 scalar-bootstrap diagnostics.
    // These are separate from the tail-fit arrays because the bootstrap needs
    // all resolved square modes, not just radial shells up to N/2.
    int h_gap1_n_shells;
    int *h_gap1_shell_count_arr;    // actual resolved shell occupancy on the N×N grid
    double *h_gap1_om_l1;           // Σ|ω̂_mid| per shell
    double *h_gap1_om_l2sq;         // Σ|ω̂_mid|² per shell
    double *h_gap1_th_l1;           // Σ|θ̂_mid| per shell
    double *h_gap1_th_l2sq;         // Σ|θ̂_mid|² per shell
    cufftDoubleComplex *h_gap1_fft_om;
    cufftDoubleComplex *h_gap1_fft_th;
    double h_gap1_rho_om;           // rigorous per-mode radius: ||δω||₂ / N
    double h_gap1_rho_th;           // rigorous per-mode radius: ||δθ||₂ / N
    double h_gap1_X_upper;          // last computed resolved-shell X_tau upper bound
    double h_gap1_lambda;           // lambda used in the last X_tau evaluation
    double h_gap1_tau;              // tau used in the last X_tau evaluation
    int h_gap1_ready;
    double h_trans_nablau_inf_up;   // Σ |ω̂_k| upper bound for ||∇u||∞
    double h_trans_gradom_inf_up;   // Σ |k| |ω̂_k| upper bound for ||∇ω||∞
    double h_trans_gradth_inf_up;   // Σ |k| |θ̂_k| upper bound for ||∇θ||∞
    cufftDoubleComplex *h_gap1_fft_prod;   // M×M product spectrum scratch
    cufftDoubleComplex *h_gap1_fft_accum;  // M×M accumulated product spectrum
    double h_apost_resid_omega_mid;        // exact midpoint ||Q(u·∇ω)||_(H^s)
    double h_apost_resid_theta_mid;        // exact midpoint ||Q(u·∇θ)||_(H^(s+1))
    double h_apost_resid_combo_mid;        // combined midpoint residual energy
    int h_apost_last_s;
    double h_apost_last_lambda;
    double h_apost_l2_resid_omega_mid;     // exact midpoint ||Q(u·∇ω)||_2
    double h_apost_l2_resid_theta_mid;     // exact midpoint ||Q(u·∇θ)||_2
    double h_apost_l2_resid_combo_mid;     // exact midpoint L2 residual energy
    // Localized mechanism diagnostics
    double h_mech_omega_chi;
    double h_mech_j_chi;
    double h_mech_p_chi;
    double h_mech_o_chi;
    double h_mech_o_diag;
    double h_mech_o_shear;
    double h_mech_o_rot;
    double h_mech_bomega;
    double h_mech_bj;
    double h_mech_center_x;
    double h_mech_center_y;
    double h_mech_vel_x;
    double h_mech_vel_y;
    double h_mech_rin;
    double h_mech_rout;
    // Peak / patch geometry diagnostics
    double h_geom_peak_tx;
    double h_geom_peak_ty;
    double h_geom_peak_angle;
    double h_geom_peak_ux;
    double h_geom_peak_shear;
    double h_geom_peak_lambda;
    double h_geom_peak_strain_angle;
    double h_geom_peak_align;
    double h_geom_patch_tx;
    double h_geom_patch_ty;
    double h_geom_patch_angle;
    double h_geom_patch_ux;
    double h_geom_patch_shear;
    double h_geom_patch_lambda;
    double h_geom_patch_strain_angle;
    double h_geom_patch_align;
    double h_geom_patch_mass;
    // Phase-III far-field diagnostics outside a chosen patch.
    double h_far_omega;
    double h_far_thetay;
    double h_far_opp;
    double h_far_ginf;
    double h_far_defect;
    double h_far_center_x;
    double h_far_center_y;
    double h_far_rin;
    double h_far_rout;
    // Phase-III interval-screen outputs.
    double h_phase3_a_lo;
    double h_phase3_a_hi;
    double h_phase3_dstar_lo;
    double h_phase3_dfar_lo;
    double h_phase3_oloc_hi;
    double h_phase3_ofar_hi;
    double h_phase3_net_lo;
    double h_phase3_q_hi;
    double h_phase3_net1_lo;
    double h_phase3_netg_lo;
    double h_phase3_omega_exact;
    double h_phase3_j_exact;
    double h_phase3_p_exact;
    double h_phase3_o_exact;
    double h_phase3_q_exact;
    double h_phase3_net_exact;
    double h_phase3_net1_exact;
    double h_phase3_jdot_exact;

    // Exact shell lattice counts: count[s] = #{(kx,ky) ∈ Z² : s-0.5 ≤ |(kx,ky)| < s+0.5}
    // Precomputed at init for s = 0..SHELL_EXACT_MAX.
    // For s > SHELL_EXACT_MAX, use proven upper bound 16s+4.
    #define SHELL_EXACT_MAX 8192
    int h_shell_exact[SHELL_EXACT_MAX + 1];

    // Robust Fourier-tail diagnostics
    double *h_shell_max;            // per-shell MAX amplitude (N/2 entries)
    double *h_shell_p90;            // per-shell 90th percentile (N/2 entries)
    double *h_shell_env;            // upper envelope: max(A(s'), s'>=s) (N/2 entries)
    // 3 stats (mean/max/p90) × 5 windows = 15 alpha values + 3 envelope alphas = 18
    #define ROB_NSTAT 3
    #define ROB_NWIN  5
    double h_rob_alpha[ROB_NSTAT][ROB_NWIN];   // [stat][window]
    double h_rob_C[ROB_NSTAT][ROB_NWIN];
    double h_rob_trunc[ROB_NSTAT][ROB_NWIN];
    double h_rob_alpha_env[ROB_NSTAT];          // envelope fit per stat
    double h_rob_C_env[ROB_NSTAT];
    double h_rob_trunc_env[ROB_NSTAT];
    double h_rob_r2[ROB_NSTAT][ROB_NWIN];      // R² per fit
    int    h_rob_violations[ROB_NSTAT][ROB_NWIN]; // shells exceeding fit
    double h_rob_max_violation[ROB_NSTAT][ROB_NWIN]; // worst violation ratio
    double h_rob_min_alpha;         // minimum α across all (α>0) variants
    double h_rob_max_trunc;         // maximum truncation across all (α>0) variants
    // P90 sort buffer: modes per shell, max ~πN modes per shell
    double *h_p90_buf;
    int h_p90_buf_size;

    // Formal majorant: tightest C·exp(-α·s) ABOVE all shell_max values
    // Zero violations by construction — this IS a certificate, not a fit
    double h_majorant_alpha;        // optimal α for tightest majorant
    double h_majorant_C;            // corresponding C
    double h_majorant_trunc;        // truncation bound from majorant
    int    h_majorant_valid;        // 1 if majorant with α>0 exists, 0 otherwise

    double last_h;                  // most recent Taylor step size
    double t;
    int steps;
} GPUState;

static GPUState G = {0};

extern "C" long long nuc_gpu_compute_bkm(void);
static void _eval_grad(const cufftDoubleComplex *fft, int N, double x, double y,
                       double *gx, double *gy);

// ================================================================
// CUDA Kernels
// ================================================================

// Real array → complex (zero imaginary part)
__global__ void k_real_to_complex(const double *re, cufftDoubleComplex *c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) { c[i].x = re[i]; c[i].y = 0; }
}

// Complex → real (take real part)
__global__ void k_complex_to_real(const cufftDoubleComplex *c, double *re, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) re[i] = c[i].x;
}

// Scale complex array by 1/n
__global__ void k_scale_complex(cufftDoubleComplex *c, double scale, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) { c[i].x *= scale; c[i].y *= scale; }
}

// Spectral derivative: multiply by i*kx (for d/dx)
__global__ void k_spectral_dx(const cufftDoubleComplex *in, cufftDoubleComplex *out,
                               int N, int n2) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n2) return;
    int kx = idx / N;
    int kkx = (kx <= N/2) ? kx : kx - N;
    out[idx].x = -(double)kkx * in[idx].y;
    out[idx].y =  (double)kkx * in[idx].x;
}

// Spectral derivative: multiply by i*ky (for d/dy)
__global__ void k_spectral_dy(const cufftDoubleComplex *in, cufftDoubleComplex *out,
                               int N, int n2) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n2) return;
    int ky = idx % N;
    int kky = (ky <= N/2) ? ky : ky - N;
    out[idx].x = -(double)kky * in[idx].y;
    out[idx].y =  (double)kky * in[idx].x;
}

// Spectral Poisson: divide by -|k|² (skip k=0)
__global__ void k_poisson_spectral(cufftDoubleComplex *c, int N, int n2) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n2) return;
    int kx = idx / N, ky = idx % N;
    int kkx = (kx <= N/2) ? kx : kx - N;
    int kky = (ky <= N/2) ? ky : ky - N;
    double k2 = (double)(kkx*kkx + kky*kky);
    if (k2 < 0.5) { c[idx].x = 0; c[idx].y = 0; }
    else { c[idx].x /= -k2; c[idx].y /= -k2; }
}

// Spectral Laplacian: multiply by -(kx²+ky²) in Fourier space
// This is exact for periodic BC: ∇²f̂_k = -(kx²+ky²)·f̂_k
__global__ void k_spectral_laplacian(const cufftDoubleComplex *in, cufftDoubleComplex *out,
                                      int N, int n2) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n2) return;
    int kx = idx / N, ky = idx % N;
    int kkx = (kx <= N/2) ? kx : kx - N;
    int kky = (ky <= N/2) ? ky : ky - N;
    double k2 = (double)(kkx*kkx + kky*kky);
    out[idx].x = -k2 * in[idx].x;
    out[idx].y = -k2 * in[idx].y;
}

// Pointwise multiply: c = a * b (real arrays)
__global__ void k_multiply(const double *a, const double *b, double *c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) c[i] = a[i] * b[i];
}

// Pointwise accumulate: dst += src
__global__ void k_accumulate(double *dst, const double *src, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) dst[i] += src[i];
}

// Zero-pad N×N Fourier → M×M Fourier
__global__ void k_zeropad(const cufftDoubleComplex *src, cufftDoubleComplex *dst,
                          int N, int M, int m2) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= m2) return;
    int dkx = idx / M, dky = idx % M;
    int half = N / 2;
    // Map M-space frequency to N-space frequency
    int skx = -1, sky = -1;
    if (dkx <= half) skx = dkx;
    else if (dkx >= M - half) skx = N - (M - dkx);
    if (dky <= half) sky = dky;
    else if (dky >= M - half) sky = N - (M - dky);
    if (skx >= 0 && skx < N && sky >= 0 && sky < N) {
        dst[idx] = src[skx * N + sky];
    } else {
        dst[idx].x = 0; dst[idx].y = 0;
    }
}

// Truncate M×M Fourier → N×N Fourier
__global__ void k_truncate(const cufftDoubleComplex *src, cufftDoubleComplex *dst,
                           int M, int N, int n2) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n2) return;
    int kx = idx / N, ky = idx % N;
    int half = N / 2;
    int skx = (kx <= half) ? kx : M - (N - kx);
    int sky = (ky <= half) ? ky : M - (N - ky);
    dst[idx] = src[skx * M + sky];
}

// Horner evaluation + error injection for signed step
__global__ void k_horner_signed(
    double **om_coeffs, double **dom_coeffs,
    double *om_mid, double *delta_om,
    double *trunc_om, /* (p+1)-th coefficient */
    int p, double h, double hp1, double round_scale,
    int n2)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= n2) return;

    // Horner for base polynomial
    double val = om_coeffs[p][idx];
    for (int k = p - 1; k >= 0; k--)
        val = om_coeffs[k][idx] + h * val;
    om_mid[idx] = val;

    // Horner for linearized polynomial
    double dval = dom_coeffs[p][idx];
    for (int k = p - 1; k >= 0; k--)
        dval = dom_coeffs[k][idx] + h * dval;

    // Add truncation + rounding
    dval += trunc_om[idx] * hp1;
    double round_err = round_scale * (fabs(val) + 1e-30);
    if (dval >= 0) dval += round_err; else dval -= round_err;
    delta_om[idx] = dval;
}

// ================================================================
// Helper: block/grid dimensions
// ================================================================
static int gpu_blocks(int n, int threads) { return (n + threads - 1) / threads; }
#define THREADS 256

static double _axis_angle_diff(double a, double b) {
    double d = 2.0 * (a - b);
    return 0.5 * atan2(sin(d), cos(d));
}

__global__ void k_horner_step(double *result, const double *coeff, double h, int n);
__global__ void k_horner_step_scaled(double *result, const double *coeff, double h,
                                     double scale, int n);
__global__ void k_add_trunc_round(double *delta, const double *trunc, const double *mid,
                                  double hp1, double round_scale, int n);

__global__ void k_horner_interval_step(double *lo, double *hi, const double *coeff,
                                       double tau_lo, double tau_hi, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    double a = lo[i], b = hi[i];
    double m1 = tau_lo * a;
    double m2 = tau_lo * b;
    double m3 = tau_hi * a;
    double m4 = tau_hi * b;
    double plo = fmin(fmin(m1, m2), fmin(m3, m4));
    double phi = fmax(fmax(m1, m2), fmax(m3, m4));
    lo[i] = coeff[i] + plo;
    hi[i] = coeff[i] + phi;
}

__global__ void k_add_interval_error(double *lo, double *hi, const double *trunc,
                                     double tau_hi_p1, double round_scale, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    double mid_abs = fmax(fabs(lo[i]), fabs(hi[i]));
    double rad = fabs(trunc[i]) * tau_hi_p1 + round_scale * (mid_abs + 1e-30);
    lo[i] -= rad;
    hi[i] += rad;
}

__global__ void k_combine_mid_lin_interval(const double *mid_lo, const double *mid_hi,
                                           const double *lin_lo, const double *lin_hi,
                                           double *out_lo, double *out_hi, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;
    double r = fmax(fabs(lin_lo[i]), fabs(lin_hi[i]));
    out_lo[i] = mid_lo[i] - r;
    out_hi[i] = mid_hi[i] + r;
}

static void _iv_mul(double alo, double ahi, double blo, double bhi,
                    double *lo, double *hi) {
    double p1 = alo * blo;
    double p2 = alo * bhi;
    double p3 = ahi * blo;
    double p4 = ahi * bhi;
    *lo = fmin(fmin(p1, p2), fmin(p3, p4));
    *hi = fmax(fmax(p1, p2), fmax(p3, p4));
}

static void _iv_sq(double lo_in, double hi_in, double *lo, double *hi) {
    double a = lo_in;
    double b = hi_in;
    double alo = fmin(a * a, b * b);
    double ahi = fmax(a * a, b * b);
    if (a <= 0.0 && b >= 0.0) alo = 0.0;
    *lo = alo;
    *hi = ahi;
}

static void _iv_ratio_pos(double nlo, double nhi, double dlo, double dhi,
                          double *rlo, double *rhi) {
    if (dlo <= 0.0 || dhi <= 0.0) {
        *rlo = -1e300;
        *rhi = 1e300;
        return;
    }
    double q1 = nlo / dlo;
    double q2 = nlo / dhi;
    double q3 = nhi / dlo;
    double q4 = nhi / dhi;
    *rlo = fmin(fmin(q1, q2), fmin(q3, q4));
    *rhi = fmax(fmax(q1, q2), fmax(q3, q4));
}

static double _phase3_quad_eval(double p_lo, double om_lo, double a, double j_use) {
    return p_lo + om_lo * a * a - 2.0 * a * j_use;
}

static double _phase3_quadratic_lower(double p_lo, double j_lo, double j_hi,
                                      double om_lo, double a_lo, double a_hi) {
    if (!isfinite(p_lo) || !isfinite(j_lo) || !isfinite(j_hi) || !isfinite(om_lo) ||
        !isfinite(a_lo) || !isfinite(a_hi) || a_hi < a_lo || om_lo < 0.0) {
        return -1e300;
    }

    double best = 1e300;
    int any = 0;

    if (a_lo <= 0.0) {
        double seg_lo = a_lo;
        double seg_hi = fmin(a_hi, 0.0);
        double j_use = j_lo;
        double q_lo = _phase3_quad_eval(p_lo, om_lo, seg_lo, j_use);
        double q_hi = _phase3_quad_eval(p_lo, om_lo, seg_hi, j_use);
        best = fmin(best, fmin(q_lo, q_hi));
        if (om_lo > 0.0) {
            double a_star = j_use / om_lo;
            if (a_star < seg_lo) a_star = seg_lo;
            if (a_star > seg_hi) a_star = seg_hi;
            best = fmin(best, _phase3_quad_eval(p_lo, om_lo, a_star, j_use));
        }
        any = 1;
    }

    if (a_hi >= 0.0) {
        double seg_lo = fmax(a_lo, 0.0);
        double seg_hi = a_hi;
        double j_use = j_hi;
        double q_lo = _phase3_quad_eval(p_lo, om_lo, seg_lo, j_use);
        double q_hi = _phase3_quad_eval(p_lo, om_lo, seg_hi, j_use);
        best = fmin(best, fmin(q_lo, q_hi));
        if (om_lo > 0.0) {
            double a_star = j_use / om_lo;
            if (a_star < seg_lo) a_star = seg_lo;
            if (a_star > seg_hi) a_star = seg_hi;
            best = fmin(best, _phase3_quad_eval(p_lo, om_lo, a_star, j_use));
        }
        any = 1;
    }

    if (!any || !isfinite(best)) return -1e300;
    return best;
}

static void gpu_eval_signed_series(double **base, double **lin, double *trunc,
                                   double tau, double *d_mid_out, double *d_del_out) {
    int p = G.p, n2 = G.n2;
    int B = gpu_blocks(n2, THREADS);
    double hp1 = pow(tau, p + 1);
    double round_scale = (double)(p + 2) * 2.2204460492503131e-16;

    CUDA_CHECK(cudaMemcpy(d_mid_out, base[p], n2 * sizeof(double), cudaMemcpyDeviceToDevice));
    for (int k = p - 1; k >= 0; k--) {
        k_horner_step<<<B,THREADS>>>(d_mid_out, base[k], tau, n2);
    }

    CUDA_CHECK(cudaMemcpy(d_del_out, lin[p], n2 * sizeof(double), cudaMemcpyDeviceToDevice));
    for (int k = p - 1; k >= 0; k--) {
        k_horner_step<<<B,THREADS>>>(d_del_out, lin[k], tau, n2);
    }

    k_add_trunc_round<<<B,THREADS>>>(d_del_out, trunc, d_mid_out, hp1, round_scale, n2);
}

static void gpu_eval_signed_series_interval(double **base, double **lin, double *trunc,
                                            double tau_lo, double tau_hi,
                                            double *d_lo_out, double *d_hi_out) {
    int p = G.p, n2 = G.n2;
    int B = gpu_blocks(n2, THREADS);
    double tau_hi_p1 = pow(tau_hi, p + 1);
    double round_scale = (double)(p + 2) * 2.2204460492503131e-16;

    CUDA_CHECK(cudaMemcpy(d_lo_out, base[p], n2 * sizeof(double), cudaMemcpyDeviceToDevice));
    CUDA_CHECK(cudaMemcpy(d_hi_out, base[p], n2 * sizeof(double), cudaMemcpyDeviceToDevice));
    for (int k = p - 1; k >= 0; k--) {
        k_horner_interval_step<<<B,THREADS>>>(d_lo_out, d_hi_out, base[k], tau_lo, tau_hi, n2);
    }

    CUDA_CHECK(cudaMemcpy(G.d_scratch1, lin[p], n2 * sizeof(double), cudaMemcpyDeviceToDevice));
    CUDA_CHECK(cudaMemcpy(G.d_scratch2, lin[p], n2 * sizeof(double), cudaMemcpyDeviceToDevice));
    for (int k = p - 1; k >= 0; k--) {
        k_horner_interval_step<<<B,THREADS>>>(G.d_scratch1, G.d_scratch2, lin[k], tau_lo, tau_hi, n2);
    }
    k_add_interval_error<<<B,THREADS>>>(G.d_scratch1, G.d_scratch2, trunc, tau_hi_p1, round_scale, n2);
    k_combine_mid_lin_interval<<<B,THREADS>>>(
        d_lo_out, d_hi_out, G.d_scratch1, G.d_scratch2, d_lo_out, d_hi_out, n2);
}

static void gpu_eval_derivative_series_exact(double **base, double tau, double *d_out) {
    int p = G.p, n2 = G.n2;
    int B = gpu_blocks(n2, THREADS);
    CUDA_CHECK(cudaMemset(d_out, 0, n2 * sizeof(double)));
    k_horner_step_scaled<<<B,THREADS>>>(d_out, base[p + 1], 0.0, (double)(p + 1), n2);
    for (int k = p - 1; k >= 0; k--) {
        k_horner_step_scaled<<<B,THREADS>>>(d_out, base[k + 1], tau, (double)(k + 1), n2);
    }
}

// Signed-error derivative: d/dtau of the Taylor series with error tracking.
// Midpoint: Σ_{k=0}^p (k+1)*base[k+1]*τ^k  (same as _exact)
// Delta:    Σ_{k=0}^{p-1} (k+1)*lin[k+1]*τ^k + (p+1)*trunc*τ^p + rounding
static void gpu_eval_derivative_series_signed(double **base, double **lin, double *trunc,
                                               double tau, double *d_mid_out, double *d_del_out) {
    int p = G.p, n2 = G.n2;
    int B = gpu_blocks(n2, THREADS);
    double hp = pow(tau, p);
    double round_scale = (double)(p + 2) * 2.2204460492503131e-16;

    // Midpoint: same Horner as gpu_eval_derivative_series_exact
    CUDA_CHECK(cudaMemset(d_mid_out, 0, n2 * sizeof(double)));
    k_horner_step_scaled<<<B,THREADS>>>(d_mid_out, base[p + 1], 0.0, (double)(p + 1), n2);
    for (int k = p - 1; k >= 0; k--) {
        k_horner_step_scaled<<<B,THREADS>>>(d_mid_out, base[k + 1], tau, (double)(k + 1), n2);
    }

    // Delta: derivative of the error series
    // Σ_{k=0}^{p-1} (k+1)*lin[k+1]*τ^k, evaluated by Horner from k=p-1 down to 0
    CUDA_CHECK(cudaMemset(d_del_out, 0, n2 * sizeof(double)));
    if (p >= 1) {
        k_horner_step_scaled<<<B,THREADS>>>(d_del_out, lin[p], 0.0, (double)p, n2);
        for (int k = p - 2; k >= 0; k--) {
            k_horner_step_scaled<<<B,THREADS>>>(d_del_out, lin[k + 1], tau, (double)(k + 1), n2);
        }
    }

    // Add derivative truncation: (p+1)*trunc*τ^p and rounding
    k_add_trunc_round<<<B,THREADS>>>(d_del_out, trunc, d_mid_out, (double)(p + 1) * hp, round_scale, n2);
}

// ================================================================
// GPU Memory Management — allocate once, free once
// ================================================================

static void gpu_cleanup() {
    if (!G.initialized) return;
    for (int k = 0; k < GPU_MAXK; k++) {
        cudaFree(G.d_om[k]); cudaFree(G.d_th[k]); cudaFree(G.d_ps[k]);
        cudaFree(G.d_uf[k]); cudaFree(G.d_vf[k]);
        cudaFree(G.d_dom[k]); cudaFree(G.d_dth[k]); cudaFree(G.d_dps[k]);
        cudaFree(G.d_duf[k]); cudaFree(G.d_dvf[k]);
        cudaFree(G.d_omx[k]); cudaFree(G.d_omy[k]);
        cudaFree(G.d_thx[k]); cudaFree(G.d_thy[k]);
        cudaFree(G.d_domx[k]); cudaFree(G.d_domy[k]);
        cudaFree(G.d_dthx[k]); cudaFree(G.d_dthy[k]);
    }
    cudaFree(G.d_om_mid); cudaFree(G.d_th_mid);
    cudaFree(G.d_delta_om); cudaFree(G.d_delta_th);
    cudaFree(G.d_fft_a); cudaFree(G.d_fft_b);
    cudaFree(G.d_fft_pa); cudaFree(G.d_fft_pb);
    cudaFree(G.d_phys_a); cudaFree(G.d_phys_b); cudaFree(G.d_phys_c);
    cudaFree(G.d_scratch1); cudaFree(G.d_scratch2);
    cudaFree(G.d_comp1); cudaFree(G.d_comp2);
    cudaFree(G.d_poisson_buf);
    if (G.plans_created) {
        cufftDestroy(G.plan_N);
        cufftDestroy(G.plan_M);
    }
    free(G.h_host_mid);
    free(G.h_host_delta);
    free(G.h_host_mid2);
    free(G.h_host_delta2);
    free(G.h_shell_amps);
    free(G.h_shell_max);
    free(G.h_shell_p90);
    free(G.h_shell_env);
    free(G.h_p90_buf);
    free(G.h_gap1_shell_count_arr);
    free(G.h_gap1_om_l1);
    free(G.h_gap1_om_l2sq);
    free(G.h_gap1_th_l1);
    free(G.h_gap1_th_l2sq);
    free(G.h_gap1_fft_om);
    free(G.h_gap1_fft_th);
    free(G.h_gap1_fft_prod);
    free(G.h_gap1_fft_accum);
    memset(&G, 0, sizeof(G));
}

extern "C" long long nuc_gpu_init(long long N_val, long long order_val) {
    int N = (int)N_val, p = (int)order_val;
    if (N < 4 || N > 2048 || p < 1 || p > GPU_MAXP) return 0;
    // Check power of 2
    if (N & (N - 1)) return 0;

    gpu_cleanup();

    G.N = N; G.n2 = N * N; G.p = p;
    G.dx = 2.0 * M_PI / (double)N;
    G.nu = 0; G.last_h = 0; G.t = 0; G.steps = 0;

    // De-alias size: next power of 2 >= 3N/2
    int target = (3 * N + 1) / 2;
    G.M = 1; while (G.M < target) G.M <<= 1;
    G.m2 = G.M * G.M;

    int n2 = G.n2, m2 = G.m2;
    size_t n2d = n2 * sizeof(double);
    size_t n2c = n2 * sizeof(cufftDoubleComplex);
    size_t m2d = m2 * sizeof(double);
    size_t m2c = m2 * sizeof(cufftDoubleComplex);

    // Allocate ALL GPU arrays
    for (int k = 0; k < GPU_MAXK; k++) {
        CUDA_CHECK(cudaMalloc(&G.d_om[k], n2d));  CUDA_CHECK(cudaMemset(G.d_om[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_th[k], n2d));  CUDA_CHECK(cudaMemset(G.d_th[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_ps[k], n2d));  CUDA_CHECK(cudaMemset(G.d_ps[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_uf[k], n2d));  CUDA_CHECK(cudaMemset(G.d_uf[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_vf[k], n2d));  CUDA_CHECK(cudaMemset(G.d_vf[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_dom[k], n2d)); CUDA_CHECK(cudaMemset(G.d_dom[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_dth[k], n2d)); CUDA_CHECK(cudaMemset(G.d_dth[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_dps[k], n2d)); CUDA_CHECK(cudaMemset(G.d_dps[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_duf[k], n2d)); CUDA_CHECK(cudaMemset(G.d_duf[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_dvf[k], n2d)); CUDA_CHECK(cudaMemset(G.d_dvf[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_omx[k], n2d)); CUDA_CHECK(cudaMemset(G.d_omx[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_omy[k], n2d)); CUDA_CHECK(cudaMemset(G.d_omy[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_thx[k], n2d)); CUDA_CHECK(cudaMemset(G.d_thx[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_thy[k], n2d)); CUDA_CHECK(cudaMemset(G.d_thy[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_domx[k], n2d)); CUDA_CHECK(cudaMemset(G.d_domx[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_domy[k], n2d)); CUDA_CHECK(cudaMemset(G.d_domy[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_dthx[k], n2d)); CUDA_CHECK(cudaMemset(G.d_dthx[k], 0, n2d));
        CUDA_CHECK(cudaMalloc(&G.d_dthy[k], n2d)); CUDA_CHECK(cudaMemset(G.d_dthy[k], 0, n2d));
    }

    CUDA_CHECK(cudaMalloc(&G.d_om_mid, n2d));   CUDA_CHECK(cudaMemset(G.d_om_mid, 0, n2d));
    CUDA_CHECK(cudaMalloc(&G.d_th_mid, n2d));   CUDA_CHECK(cudaMemset(G.d_th_mid, 0, n2d));
    CUDA_CHECK(cudaMalloc(&G.d_delta_om, n2d)); CUDA_CHECK(cudaMemset(G.d_delta_om, 0, n2d));
    CUDA_CHECK(cudaMalloc(&G.d_delta_th, n2d)); CUDA_CHECK(cudaMemset(G.d_delta_th, 0, n2d));

    CUDA_CHECK(cudaMalloc(&G.d_fft_a, n2c));
    CUDA_CHECK(cudaMalloc(&G.d_fft_b, n2c));
    CUDA_CHECK(cudaMalloc(&G.d_fft_pa, m2c));
    CUDA_CHECK(cudaMalloc(&G.d_fft_pb, m2c));
    CUDA_CHECK(cudaMalloc(&G.d_phys_a, m2d));
    CUDA_CHECK(cudaMalloc(&G.d_phys_b, m2d));
    CUDA_CHECK(cudaMalloc(&G.d_phys_c, m2d));
    CUDA_CHECK(cudaMalloc(&G.d_scratch1, n2d));
    CUDA_CHECK(cudaMalloc(&G.d_scratch2, n2d));
    CUDA_CHECK(cudaMalloc(&G.d_comp1, n2d));
    CUDA_CHECK(cudaMalloc(&G.d_comp2, n2d));
    CUDA_CHECK(cudaMalloc(&G.d_poisson_buf, n2c));

    // cuFFT plans
    CUFFT_CHECK(cufftPlan2d(&G.plan_N, N, N, CUFFT_Z2Z));
    CUFFT_CHECK(cufftPlan2d(&G.plan_M, G.M, G.M, CUFFT_Z2Z));
    G.plans_created = 1;

    // Pre-allocate host buffers (NEVER malloc in step function)
    G.h_host_mid = (double *)malloc(n2 * sizeof(double));
    G.h_host_delta = (double *)malloc(n2 * sizeof(double));
    G.h_host_mid2 = (double *)malloc(n2 * sizeof(double));
    G.h_host_delta2 = (double *)malloc(n2 * sizeof(double));
    G.h_shell_amps = (double *)calloc(N / 2 + 1, sizeof(double));
    G.h_shell_max  = (double *)calloc(N / 2 + 1, sizeof(double));
    G.h_shell_p90  = (double *)calloc(N / 2 + 1, sizeof(double));
    G.h_shell_env  = (double *)calloc(N / 2 + 1, sizeof(double));
    G.h_shell_count = N / 2;
    // P90 buffer: max modes in any shell ~ π*N for the outermost shell
    G.h_p90_buf_size = (int)(4.0 * N);
    G.h_p90_buf = (double *)malloc(G.h_p90_buf_size * sizeof(double));

    G.h_gap1_n_shells = (int)(sqrt(2.0) * (double)(N / 2) + 1.5);
    G.h_gap1_shell_count_arr = (int *)calloc(G.h_gap1_n_shells + 1, sizeof(int));
    G.h_gap1_om_l1 = (double *)calloc(G.h_gap1_n_shells + 1, sizeof(double));
    G.h_gap1_om_l2sq = (double *)calloc(G.h_gap1_n_shells + 1, sizeof(double));
    G.h_gap1_th_l1 = (double *)calloc(G.h_gap1_n_shells + 1, sizeof(double));
    G.h_gap1_th_l2sq = (double *)calloc(G.h_gap1_n_shells + 1, sizeof(double));
    G.h_gap1_fft_om = (cufftDoubleComplex *)malloc(n2 * sizeof(cufftDoubleComplex));
    G.h_gap1_fft_th = (cufftDoubleComplex *)malloc(n2 * sizeof(cufftDoubleComplex));
    G.h_gap1_fft_prod = (cufftDoubleComplex *)malloc(m2 * sizeof(cufftDoubleComplex));
    G.h_gap1_fft_accum = (cufftDoubleComplex *)malloc(m2 * sizeof(cufftDoubleComplex));
    G.h_gap1_rho_om = 0.0;
    G.h_gap1_rho_th = 0.0;
    G.h_gap1_X_upper = 0.0;
    G.h_gap1_lambda = 0.0;
    G.h_gap1_tau = 0.0;
    G.h_gap1_ready = 0;
    G.h_trans_nablau_inf_up = 0.0;
    G.h_trans_gradom_inf_up = 0.0;
    G.h_trans_gradth_inf_up = 0.0;
    G.h_apost_resid_omega_mid = 0.0;
    G.h_apost_resid_theta_mid = 0.0;
    G.h_apost_resid_combo_mid = 0.0;
    G.h_apost_last_s = 0;
    G.h_apost_last_lambda = 0.0;
    G.h_apost_l2_resid_omega_mid = 0.0;
    G.h_apost_l2_resid_theta_mid = 0.0;
    G.h_apost_l2_resid_combo_mid = 0.0;

    // Precompute exact shell lattice counts for s = 0..SHELL_EXACT_MAX
    // count[s] = #{(kx,ky) ∈ Z² : (s-0.5)² ≤ kx²+ky² < (s+0.5)²}
    // This is exact (computable), used for rigorous truncation bounds.
    memset(G.h_shell_exact, 0, sizeof(G.h_shell_exact));
    {
        int smax = SHELL_EXACT_MAX;
        for (int kx = -smax; kx <= smax; kx++) {
            // For each kx, ky range is limited by kx²+ky² < (smax+0.5)²
            int ky_max = (int)sqrt((double)(smax + 0.5) * (smax + 0.5) - (double)kx * kx);
            if (ky_max > smax) ky_max = smax;
            for (int ky = -ky_max; ky <= ky_max; ky++) {
                double r = sqrt((double)(kx * kx + ky * ky));
                int s = (int)(r + 0.5);  // round to nearest shell
                if (s >= 0 && s <= smax) {
                    G.h_shell_exact[s]++;
                }
            }
        }
        fprintf(stderr, "Shell counts precomputed: s=0..%d (s[0]=%d, s[1]=%d, s[5]=%d, s[100]=%d)\n",
                smax, G.h_shell_exact[0], G.h_shell_exact[1],
                G.h_shell_exact[5], G.h_shell_exact[100]);
    }

    G.initialized = 1;

    // Report memory usage
    size_t total_gpu = GPU_MAXK * 18 * n2d  // coefficient arrays
                     + 4 * n2d              // mid + delta
                     + 2 * n2c + 2 * m2c    // FFT buffers
                     + 3 * m2d + 2 * n2d    // scratch
                     + n2c;                 // poisson buf
    fprintf(stderr, "GPU init: N=%d, M=%d, p=%d, VRAM=%.1f MB\n",
            N, G.M, p, (double)total_gpu / (1024*1024));
    return 1;
}

// ================================================================
// GPU Operations: Spectral derivative of a real grid
//   Input: d_f (N×N real on GPU)
//   Output: d_df (N×N real on GPU)
//   Uses d_fft_a as scratch
// ================================================================
static void gpu_spectral_dx(double *d_f, double *d_df) {
    int n2 = G.n2, N = G.N;
    k_real_to_complex<<<gpu_blocks(n2,THREADS), THREADS>>>(d_f, G.d_fft_a, n2);
    CUFFT_CHECK(cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD));
    k_spectral_dx<<<gpu_blocks(n2,THREADS), THREADS>>>(G.d_fft_a, G.d_fft_b, N, n2);
    CUFFT_CHECK(cufftExecZ2Z(G.plan_N, G.d_fft_b, G.d_fft_b, CUFFT_INVERSE));
    k_complex_to_real<<<gpu_blocks(n2,THREADS), THREADS>>>(G.d_fft_b, d_df, n2);
    double inv = 1.0 / (double)n2;
    k_scale_complex<<<gpu_blocks(n2,THREADS), THREADS>>>((cufftDoubleComplex*)d_df, inv, n2/2);
    // Actually: IFFT result needs scaling by 1/N² — cuFFT INVERSE is unscaled
    // Simpler: scale the real output directly
    // ... let me handle this properly in a scale kernel for doubles
}

// Actually, let me write this more carefully with proper scaling:

// Scale real array by constant
__global__ void k_scale_real(double *a, double scale, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) a[i] *= scale;
}

// Set real array to zero
__global__ void k_zero(double *a, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) a[i] = 0;
}

// Spectral derivative d/dx: FFT → multiply by ik_x → IFFT → scale 1/N²
static void gpu_ddx(double *d_f, double *d_df) {
    int n2 = G.n2, N = G.N;
    int B = gpu_blocks(n2, THREADS);
    k_real_to_complex<<<B,THREADS>>>(d_f, G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_spectral_dx<<<B,THREADS>>>(G.d_fft_a, G.d_fft_b, N, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_b, G.d_fft_b, CUFFT_INVERSE);
    k_complex_to_real<<<B,THREADS>>>(G.d_fft_b, d_df, n2);
    k_scale_real<<<B,THREADS>>>(d_df, 1.0/(double)n2, n2);
}

static void gpu_ddy(double *d_f, double *d_df) {
    int n2 = G.n2, N = G.N;
    int B = gpu_blocks(n2, THREADS);
    k_real_to_complex<<<B,THREADS>>>(d_f, G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_spectral_dy<<<B,THREADS>>>(G.d_fft_a, G.d_fft_b, N, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_b, G.d_fft_b, CUFFT_INVERSE);
    k_complex_to_real<<<B,THREADS>>>(G.d_fft_b, d_df, n2);
    k_scale_real<<<B,THREADS>>>(d_df, 1.0/(double)n2, n2);
}

// GPU Spectral Laplacian: ∇²f via FFT (exact for periodic BC)
static void gpu_laplacian(double *d_f, double *d_lap) {
    int n2 = G.n2, N = G.N;
    int B = gpu_blocks(n2, THREADS);
    k_real_to_complex<<<B,THREADS>>>(d_f, G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_spectral_laplacian<<<B,THREADS>>>(G.d_fft_a, G.d_fft_b, N, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_b, G.d_fft_b, CUFFT_INVERSE);
    k_complex_to_real<<<B,THREADS>>>(G.d_fft_b, d_lap, n2);
    k_scale_real<<<B,THREADS>>>(d_lap, 1.0/(double)n2, n2);
}

// ================================================================
// GPU Spectral Poisson: ψ̂ = -ω̂/|k|²
// ================================================================
static void gpu_poisson(double *d_omega, double *d_psi) {
    int n2 = G.n2, N = G.N;
    int B = gpu_blocks(n2, THREADS);
    k_real_to_complex<<<B,THREADS>>>(d_omega, G.d_poisson_buf, n2);
    cufftExecZ2Z(G.plan_N, G.d_poisson_buf, G.d_poisson_buf, CUFFT_FORWARD);
    k_scale_complex<<<B,THREADS>>>(G.d_poisson_buf, 1.0/(double)n2, n2);
    k_poisson_spectral<<<B,THREADS>>>(G.d_poisson_buf, N, n2);
    cufftExecZ2Z(G.plan_N, G.d_poisson_buf, G.d_poisson_buf, CUFFT_INVERSE);
    k_complex_to_real<<<B,THREADS>>>(G.d_poisson_buf, d_psi, n2);
}

// ================================================================
// GPU Velocity: u = dψ/dy, v = -dψ/dx
// ================================================================
static void gpu_velocity(double *d_psi, double *d_u, double *d_v) {
    gpu_ddy(d_psi, d_u);
    gpu_ddx(d_psi, d_v);
    k_scale_real<<<gpu_blocks(G.n2,THREADS),THREADS>>>(d_v, -1.0, G.n2);
}

// ================================================================
// GPU De-aliased Product: c = a * b (alias-free via 3/2 padding)
// ================================================================
static void gpu_dealiased_mul(double *d_a, double *d_b, double *d_c) {
    int n2 = G.n2, N = G.N, M = G.M, m2 = G.m2;
    int Bn = gpu_blocks(n2, THREADS);
    int Bm = gpu_blocks(m2, THREADS);

    // a: FFT → scale → zeropad → IFFT
    k_real_to_complex<<<Bn,THREADS>>>(d_a, G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_scale_complex<<<Bn,THREADS>>>(G.d_fft_a, 1.0/(double)n2, n2);
    k_zeropad<<<Bm,THREADS>>>(G.d_fft_a, G.d_fft_pa, N, M, m2);
    cufftExecZ2Z(G.plan_M, G.d_fft_pa, G.d_fft_pa, CUFFT_INVERSE);
    k_complex_to_real<<<Bm,THREADS>>>(G.d_fft_pa, G.d_phys_a, m2);

    // b: same path
    k_real_to_complex<<<Bn,THREADS>>>(d_b, G.d_fft_b, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_b, G.d_fft_b, CUFFT_FORWARD);
    k_scale_complex<<<Bn,THREADS>>>(G.d_fft_b, 1.0/(double)n2, n2);
    k_zeropad<<<Bm,THREADS>>>(G.d_fft_b, G.d_fft_pb, N, M, m2);
    cufftExecZ2Z(G.plan_M, G.d_fft_pb, G.d_fft_pb, CUFFT_INVERSE);
    k_complex_to_real<<<Bm,THREADS>>>(G.d_fft_pb, G.d_phys_b, m2);

    // Pointwise multiply at M resolution
    k_multiply<<<Bm,THREADS>>>(G.d_phys_a, G.d_phys_b, G.d_phys_c, m2);

    // FFT product → scale → truncate → IFFT → result
    k_real_to_complex<<<Bm,THREADS>>>(G.d_phys_c, G.d_fft_pa, m2);
    cufftExecZ2Z(G.plan_M, G.d_fft_pa, G.d_fft_pa, CUFFT_FORWARD);
    k_scale_complex<<<Bm,THREADS>>>(G.d_fft_pa, 1.0/(double)m2, m2);
    k_truncate<<<Bn,THREADS>>>(G.d_fft_pa, G.d_fft_a, M, N, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_INVERSE);
    k_complex_to_real<<<Bn,THREADS>>>(G.d_fft_a, d_c, n2);
}

// Same product path, but keep the exact padded M×M product spectrum in d_fft_pa.
// For powers-of-two production runs (e.g. N=256,512,1024), G.M = 2N, so this
// contains the full quadratic spectrum of the N-grid Galerkin fields.
static void gpu_dealiased_mul_fullfft(double *d_a, double *d_b) {
    int n2 = G.n2, N = G.N, M = G.M, m2 = G.m2;
    int Bn = gpu_blocks(n2, THREADS);
    int Bm = gpu_blocks(m2, THREADS);

    k_real_to_complex<<<Bn,THREADS>>>(d_a, G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_scale_complex<<<Bn,THREADS>>>(G.d_fft_a, 1.0/(double)n2, n2);
    k_zeropad<<<Bm,THREADS>>>(G.d_fft_a, G.d_fft_pa, N, M, m2);
    cufftExecZ2Z(G.plan_M, G.d_fft_pa, G.d_fft_pa, CUFFT_INVERSE);
    k_complex_to_real<<<Bm,THREADS>>>(G.d_fft_pa, G.d_phys_a, m2);

    k_real_to_complex<<<Bn,THREADS>>>(d_b, G.d_fft_b, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_b, G.d_fft_b, CUFFT_FORWARD);
    k_scale_complex<<<Bn,THREADS>>>(G.d_fft_b, 1.0/(double)n2, n2);
    k_zeropad<<<Bm,THREADS>>>(G.d_fft_b, G.d_fft_pb, N, M, m2);
    cufftExecZ2Z(G.plan_M, G.d_fft_pb, G.d_fft_pb, CUFFT_INVERSE);
    k_complex_to_real<<<Bm,THREADS>>>(G.d_fft_pb, G.d_phys_b, m2);

    k_multiply<<<Bm,THREADS>>>(G.d_phys_a, G.d_phys_b, G.d_phys_c, m2);

    k_real_to_complex<<<Bm,THREADS>>>(G.d_phys_c, G.d_fft_pa, m2);
    cufftExecZ2Z(G.plan_M, G.d_fft_pa, G.d_fft_pa, CUFFT_FORWARD);
    k_scale_complex<<<Bm,THREADS>>>(G.d_fft_pa, 1.0/(double)m2, m2);
}

static int _m_mode_kept_by_N_grid(int idx, int M, int N) {
    int half = N / 2;
    int k = (idx <= M/2) ? idx : idx - M;
    return (k >= -half + 1 && k <= half);
}

static double _accum_omitted_hs_norm_sq(const cufftDoubleComplex *spec, int M, int N, int s) {
    double sum = 0.0;
    for (int kx = 0; kx < M; kx++) {
        int keep_x = _m_mode_kept_by_N_grid(kx, M, N);
        int kkx = (kx <= M/2) ? kx : kx - M;
        for (int ky = 0; ky < M; ky++) {
            int keep_y = _m_mode_kept_by_N_grid(ky, M, N);
            if (keep_x && keep_y) continue;
            int kky = (ky <= M/2) ? ky : ky - M;
            int idx = kx * M + ky;
            double mag2 = spec[idx].x * spec[idx].x + spec[idx].y * spec[idx].y;
            if (mag2 <= 0.0) continue;
            double k2 = 1.0 + (double)(kkx * kkx + kky * kky);
            sum += pow(k2, (double)s) * mag2;
        }
    }
    return sum;
}

// ================================================================
// GPU Taylor Recurrence (base, de-aliased spectral)
// Fills d_om[k+1], d_th[k+1] from d_om[0..k], d_th[0..k]
// ================================================================
static void gpu_taylor_recurrence(int max_k) {
    int n2 = G.n2, N = G.N;
    int B = gpu_blocks(n2, THREADS);

    for (int k = 0; k <= max_k; k++) {
        // Poisson solve: psi_k from omega_k
        gpu_poisson(G.d_om[k], G.d_ps[k]);
        // Velocity from psi_k
        gpu_velocity(G.d_ps[k], G.d_uf[k], G.d_vf[k]);
        // Derivatives of omega_k and theta_k
        gpu_ddx(G.d_om[k], G.d_omx[k]);
        gpu_ddy(G.d_om[k], G.d_omy[k]);
        gpu_ddx(G.d_th[k], G.d_thx[k]);
        gpu_ddy(G.d_th[k], G.d_thy[k]);

        if (k < max_k) {
            double scl = 1.0 / (double)(k + 1);

            // Accumulate Cauchy product into scratch1 (adv_om) and scratch2 (adv_th)
            k_zero<<<B,THREADS>>>(G.d_scratch1, n2);
            k_zero<<<B,THREADS>>>(G.d_scratch2, n2);

            for (int m = 0; m <= k; m++) {
                int km = k - m;
                // u[m] * dom/dx[km] → phys_c, accumulate into scratch1
                gpu_dealiased_mul(G.d_uf[m], G.d_omx[km], G.d_phys_c);
                cudaMemcpy(G.d_scratch1, G.d_scratch1, 0, cudaMemcpyDeviceToDevice); // sync
                k_accumulate<<<B,THREADS>>>(G.d_scratch1, G.d_phys_c, n2);
                // v[m] * dom/dy[km]
                gpu_dealiased_mul(G.d_vf[m], G.d_omy[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch1, G.d_phys_c, n2);
                // u[m] * dth/dx[km]
                gpu_dealiased_mul(G.d_uf[m], G.d_thx[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch2, G.d_phys_c, n2);
                // v[m] * dth/dy[km]
                gpu_dealiased_mul(G.d_vf[m], G.d_thy[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch2, G.d_phys_c, n2);
            }

            // om[k+1] = scl * (thx[k] - adv_om)
            // th[k+1] = scl * (-adv_th)
            // Use a combined kernel:
            // For now, download, compute on CPU, upload (TODO: kernel)
            // Actually let's do a simple kernel:
            // ... this needs a custom kernel. Let me add one.
        }
    }
}

// Horner step: result = coeff + h * result (in-place, simple)
__global__ void k_horner_step(double *result, const double *coeff, double h, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) result[i] = coeff[i] + h * result[i];
}

// Horner step for derivative series: result = scale * coeff + h * result
__global__ void k_horner_step_scaled(double *result, const double *coeff, double h,
                                     double scale, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) result[i] = scale * coeff[i] + h * result[i];
}

// Add truncation + rounding to delta.
// With compensated Horner, rounding bound is O(ε²) instead of O(p·ε).
__global__ void k_add_trunc_round(double *delta, const double *trunc, const double *mid,
                                   double hp1, double round_scale, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        delta[i] += trunc[i] * hp1;
        double re = round_scale * (fabs(mid[i]) + 1e-30);
        if (delta[i] >= 0) delta[i] += re; else delta[i] -= re;
    }
}

// Kernel: om_next = scale * (thx - adv_om), th_next = scale * (-adv_th)
__global__ void k_taylor_combine(double *om_next, double *th_next,
                                  const double *thx, const double *adv_om,
                                  const double *adv_th, double scale, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        om_next[i] = scale * (thx[i] - adv_om[i]);
        th_next[i] = scale * (-adv_th[i]);
    }
}

// Viscous variant: om[k+1] = scale * (thx[k] - adv_om + nu * lap_om[k])
__global__ void k_taylor_combine_visc(double *om_next, double *th_next,
                                       const double *thx, const double *adv_om,
                                       const double *adv_th, const double *lap_om,
                                       double scale, double nu, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        om_next[i] = scale * (thx[i] - adv_om[i] + nu * lap_om[i]);
        th_next[i] = scale * (-adv_th[i]);
    }
}

// ================================================================
// FFI: Set initial conditions (host → GPU)
// ================================================================
extern "C" void nuc_gpu_set_omega(long long i, long long j, long long val_bits) {
    double v = _b2f(val_bits);
    int idx = ((int)i % G.N) * G.N + ((int)j % G.N);
    CUDA_CHECK(cudaMemcpy(G.d_om_mid + idx, &v, sizeof(double), cudaMemcpyHostToDevice));
}

extern "C" void nuc_gpu_set_theta(long long i, long long j, long long val_bits) {
    double v = _b2f(val_bits);
    int idx = ((int)i % G.N) * G.N + ((int)j % G.N);
    CUDA_CHECK(cudaMemcpy(G.d_th_mid + idx, &v, sizeof(double), cudaMemcpyHostToDevice));
}

extern "C" void nuc_gpu_set_nu(long long nu_bits) { G.nu = _b2f(nu_bits); }

// ================================================================
// FFI: Signed error step (GPU-accelerated)
//
// Same algorithm as CPU nuc_tm_step_signed, but all grid ops on GPU.
// ================================================================
extern "C" long long nuc_gpu_step_signed(long long h_bits, long long poi_val) {
    double h = _b2f(h_bits);
    int p = G.p, n2 = G.n2, N = G.N;
    int B = gpu_blocks(n2, THREADS);

    // Phase 1: Copy midpoint to order-0 coefficients
    CUDA_CHECK(cudaMemcpy(G.d_om[0], G.d_om_mid, n2*sizeof(double), cudaMemcpyDeviceToDevice));
    CUDA_CHECK(cudaMemcpy(G.d_th[0], G.d_th_mid, n2*sizeof(double), cudaMemcpyDeviceToDevice));

    // Phase 2: Base Taylor recurrence (orders 0..p+1)
    for (int k = 0; k <= p + 1; k++) {
        gpu_poisson(G.d_om[k], G.d_ps[k]);
        gpu_velocity(G.d_ps[k], G.d_uf[k], G.d_vf[k]);
        gpu_ddx(G.d_om[k], G.d_omx[k]);
        gpu_ddy(G.d_om[k], G.d_omy[k]);
        gpu_ddx(G.d_th[k], G.d_thx[k]);
        gpu_ddy(G.d_th[k], G.d_thy[k]);

        if (k <= p) {
            double scl = 1.0 / (double)(k + 1);
            k_zero<<<B,THREADS>>>(G.d_scratch1, n2);  // adv_om
            k_zero<<<B,THREADS>>>(G.d_scratch2, n2);  // adv_th

            for (int m = 0; m <= k; m++) {
                int km = k - m;
                gpu_dealiased_mul(G.d_uf[m], G.d_omx[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch1, G.d_phys_c, n2);
                gpu_dealiased_mul(G.d_vf[m], G.d_omy[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch1, G.d_phys_c, n2);
                gpu_dealiased_mul(G.d_uf[m], G.d_thx[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch2, G.d_phys_c, n2);
                gpu_dealiased_mul(G.d_vf[m], G.d_thy[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch2, G.d_phys_c, n2);
            }

            // Apply viscous Laplacian if nu > 0
            if (G.nu > 0) {
                gpu_laplacian(G.d_om[k], G.d_comp1);  // comp1 = ∇²ω[k]
                k_taylor_combine_visc<<<B,THREADS>>>(G.d_om[k+1], G.d_th[k+1],
                    G.d_thx[k], G.d_scratch1, G.d_scratch2, G.d_comp1,
                    scl, G.nu, n2);
            } else {
                k_taylor_combine<<<B,THREADS>>>(G.d_om[k+1], G.d_th[k+1],
                    G.d_thx[k], G.d_scratch1, G.d_scratch2, scl, n2);
            }
        }
    }

    // Phase 3: Linearized Taylor recurrence for delta (orders 0..p)
    CUDA_CHECK(cudaMemcpy(G.d_dom[0], G.d_delta_om, n2*sizeof(double), cudaMemcpyDeviceToDevice));
    CUDA_CHECK(cudaMemcpy(G.d_dth[0], G.d_delta_th, n2*sizeof(double), cudaMemcpyDeviceToDevice));

    for (int k = 0; k <= p; k++) {
        gpu_poisson(G.d_dom[k], G.d_dps[k]);
        gpu_velocity(G.d_dps[k], G.d_duf[k], G.d_dvf[k]);
        gpu_ddx(G.d_dom[k], G.d_domx[k]);
        gpu_ddy(G.d_dom[k], G.d_domy[k]);
        gpu_ddx(G.d_dth[k], G.d_dthx[k]);
        gpu_ddy(G.d_dth[k], G.d_dthy[k]);

        if (k < p) {
            double scl = 1.0 / (double)(k + 1);
            k_zero<<<B,THREADS>>>(G.d_scratch1, n2);
            k_zero<<<B,THREADS>>>(G.d_scratch2, n2);

            for (int m = 0; m <= k; m++) {
                int km = k - m;
                // δu·∇ω + u·∇δω (8 de-aliased products)
                gpu_dealiased_mul(G.d_duf[m], G.d_omx[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch1, G.d_phys_c, n2);
                gpu_dealiased_mul(G.d_dvf[m], G.d_omy[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch1, G.d_phys_c, n2);
                gpu_dealiased_mul(G.d_uf[m], G.d_domx[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch1, G.d_phys_c, n2);
                gpu_dealiased_mul(G.d_vf[m], G.d_domy[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch1, G.d_phys_c, n2);
                // δu·∇θ + u·∇δθ
                gpu_dealiased_mul(G.d_duf[m], G.d_thx[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch2, G.d_phys_c, n2);
                gpu_dealiased_mul(G.d_dvf[m], G.d_thy[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch2, G.d_phys_c, n2);
                gpu_dealiased_mul(G.d_uf[m], G.d_dthx[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch2, G.d_phys_c, n2);
                gpu_dealiased_mul(G.d_vf[m], G.d_dthy[km], G.d_phys_c);
                k_accumulate<<<B,THREADS>>>(G.d_scratch2, G.d_phys_c, n2);
            }

            // Apply viscous Laplacian to linearized error if nu > 0
            if (G.nu > 0) {
                gpu_laplacian(G.d_dom[k], G.d_comp1);  // comp1 = ∇²δω[k]
                k_taylor_combine_visc<<<B,THREADS>>>(G.d_dom[k+1], G.d_dth[k+1],
                    G.d_dthx[k], G.d_scratch1, G.d_scratch2, G.d_comp1,
                    scl, G.nu, n2);
            } else {
                k_taylor_combine<<<B,THREADS>>>(G.d_dom[k+1], G.d_dth[k+1],
                    G.d_dthx[k], G.d_scratch1, G.d_scratch2, scl, n2);
            }
        }
    }

    // Phase 4: Horner evaluation — ENTIRELY on GPU
    // No malloc, no memcpy per step. Only a 3-double reduction at the end.
    {
        double hp1 = pow(h, p + 1);
        double round_scale = (double)(p + 2) * 2.2204460492503131e-16;

        /* Base Horner (simple) */
        cudaMemcpy(G.d_om_mid, G.d_om[p], n2*sizeof(double), cudaMemcpyDeviceToDevice);
        cudaMemcpy(G.d_th_mid, G.d_th[p], n2*sizeof(double), cudaMemcpyDeviceToDevice);
        for (int k = p - 1; k >= 0; k--) {
            k_horner_step<<<B,THREADS>>>(G.d_om_mid, G.d_om[k], h, n2);
            k_horner_step<<<B,THREADS>>>(G.d_th_mid, G.d_th[k], h, n2);
        }

        /* Linearized Horner (simple) */
        cudaMemcpy(G.d_delta_om, G.d_dom[p], n2*sizeof(double), cudaMemcpyDeviceToDevice);
        cudaMemcpy(G.d_delta_th, G.d_dth[p], n2*sizeof(double), cudaMemcpyDeviceToDevice);
        for (int k = p - 1; k >= 0; k--) {
            k_horner_step<<<B,THREADS>>>(G.d_delta_om, G.d_dom[k], h, n2);
            k_horner_step<<<B,THREADS>>>(G.d_delta_th, G.d_dth[k], h, n2);
        }

        /* Add truncation + rounding */
        k_add_trunc_round<<<B,THREADS>>>(G.d_delta_om, G.d_om[p+1], G.d_om_mid,
                                          hp1, round_scale, n2);
        k_add_trunc_round<<<B,THREADS>>>(G.d_delta_th, G.d_th[p+1], G.d_th_mid,
                                          hp1, round_scale, n2);

        // Compute bounds on GPU, reduce to 3 scalars
        // Download only om_mid and delta_om for reduction (2 arrays, not 4*(p+2))
        double *h_mid = G.h_host_mid;   // pre-allocated in init
        double *h_del = G.h_host_delta;
        cudaMemcpy(h_mid, G.d_om_mid, n2*sizeof(double), cudaMemcpyDeviceToHost);
        cudaMemcpy(h_del, G.d_delta_om, n2*sizeof(double), cudaMemcpyDeviceToHost);

        double max_delta = 0, max_lo = 0, max_hi = 0;
        double peak_val = 0; int peak_idx = 0;
        for (int i = 0; i < n2; i++) {
            double d = fabs(h_del[i]);
            if (d > max_delta) max_delta = d;
            double lo = fabs(h_mid[i]) - d;
            double hi = fabs(h_mid[i]) + d;
            if (lo < 0) lo = 0;
            if (lo > max_lo) max_lo = lo;
            if (hi > max_hi) max_hi = hi;
            // Track peak location
            if (fabs(h_mid[i]) > peak_val) {
                peak_val = fabs(h_mid[i]);
                peak_idx = i;
            }
        }
        G.h_peak_i = peak_idx / G.N;
        G.h_peak_j = peak_idx % G.N;
        G.h_peak_val = peak_val;
        // Extract dω/dt at peak: ω[1] is the first Taylor coefficient
        // d_om[1] contains dω/dt from the most recent recurrence (lag = h = 0.001)
        {
            double omega1_at_peak;
            cudaMemcpy(&omega1_at_peak, G.d_om[1] + peak_idx,
                        sizeof(double), cudaMemcpyDeviceToHost);
            G.h_growth_rate = omega1_at_peak;
        }
        // Also check theta delta
        cudaMemcpy(h_del, G.d_delta_th, n2*sizeof(double), cudaMemcpyDeviceToHost);
        for (int i = 0; i < n2; i++) {
            double d = fabs(h_del[i]);
            if (d > max_delta) max_delta = d;
        }

        G.h_radius = max_delta;
        G.h_omega_max_lo = max_lo;
        G.h_omega_max_hi = max_hi;
    }

    G.last_h = h;
    G.t += h;
    G.steps++;
    return 1;
}

// ================================================================
// FFI: Get results
// ================================================================
// ================================================================
// Fourier-tail diagnostic: compute spectral decay rate α
//
// 1. cuFFT of midpoint omega → ω̂(kx,ky)
// 2. Shell-average: A(|k|) = mean |ω̂| for modes with |k| in [s, s+1)
// 3. Fit log A(s) = log C - α·s → extract α
// 4. If α > 0 through blowup, spectral truncation ≤ C·exp(-αN/2)
// ================================================================
extern "C" long long nuc_gpu_fourier_tail(void) {
    int N = G.N, n2 = G.n2;
    int B = gpu_blocks(n2, THREADS);
    int n_shells = N / 2;

    // FFT omega on GPU
    k_real_to_complex<<<B,THREADS>>>(G.d_om_mid, G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_scale_complex<<<B,THREADS>>>(G.d_fft_a, 1.0 / (double)n2, n2);

    // Download Fourier coefficients to host — need n2 * sizeof(cufftDoubleComplex)
    // Can't reuse h_host_mid (too small). Allocate once, keep as static.
    static cufftDoubleComplex *h_fft = NULL;
    if (!h_fft) h_fft = (cufftDoubleComplex *)malloc(n2 * sizeof(cufftDoubleComplex));
    cudaMemcpy(h_fft, G.d_fft_a, n2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);

    // Shell-average amplitudes
    double *shell_sum = G.h_shell_amps;
    static int *shell_count_arr = NULL;
    if (!shell_count_arr) shell_count_arr = (int *)calloc(n_shells + 1, sizeof(int));
    memset(shell_sum, 0, (n_shells + 1) * sizeof(double));
    if (shell_count_arr) memset(shell_count_arr, 0, (n_shells + 1) * sizeof(int));

    for (int kx = 0; kx < N; kx++) {
        int kkx = (kx <= N/2) ? kx : kx - N;
        for (int ky = 0; ky < N; ky++) {
            int kky = (ky <= N/2) ? ky : ky - N;
            int shell = (int)(sqrt((double)(kkx*kkx + kky*kky)) + 0.5);
            if (shell > 0 && shell <= n_shells) {
                int idx = kx * N + ky;
                double mag = sqrt(h_fft[idx].x * h_fft[idx].x + h_fft[idx].y * h_fft[idx].y);
                shell_sum[shell] += mag;
                shell_count_arr[shell]++;
            }
        }
    }

    // Average each shell
    for (int s = 1; s <= n_shells; s++) {
        if (shell_count_arr[s] > 0)
            shell_sum[s] /= (double)shell_count_arr[s];
    }

    // Fit log(A) = log(C) - α·s using least squares
    // Find the range where amplitudes are above noise floor (> max_amp * 1e-12)
    double max_amp = 0;
    for (int s = 1; s <= n_shells; s++)
        if (shell_sum[s] > max_amp) max_amp = shell_sum[s];
    double noise_floor = max_amp * 1e-12;

    // Fit from shell 2 (skip DC-adjacent) to where signal drops below noise
    int fit_lo = 2, fit_hi = n_shells;
    for (int s = fit_lo; s <= n_shells; s++) {
        if (shell_sum[s] < noise_floor) { fit_hi = s - 1; break; }
    }
    if (fit_hi < fit_lo + 3) fit_hi = fit_lo + 3; // need at least 4 points
    double sum_s = 0, sum_logA = 0, sum_s2 = 0, sum_slogA = 0;
    int n_fit = 0;
    for (int s = fit_lo; s <= fit_hi; s++) {
        if (shell_sum[s] > 1e-300) {
            double ls = (double)s;
            double la = log(shell_sum[s]);
            sum_s += ls;
            sum_logA += la;
            sum_s2 += ls * ls;
            sum_slogA += ls * la;
            n_fit++;
        }
    }

    if (n_fit > 2) {
        double denom = n_fit * sum_s2 - sum_s * sum_s;
        if (fabs(denom) > 1e-30) {
            double slope = (n_fit * sum_slogA - sum_s * sum_logA) / denom;
            double intercept = (sum_logA - slope * sum_s) / n_fit;
            G.h_fourier_alpha = -slope;  // α = -slope (positive means decay)
            G.h_fourier_C = exp(intercept);
        }
    }

    return _f2b(G.h_fourier_alpha);
}

// Forward declaration (defined later with robust helpers)
static double _trunc_bound(double alpha, double C_val, int N);

// FFI: Get diagnostics
extern "C" long long nuc_gpu_get_peak_i(void) { return (long long)G.h_peak_i; }
extern "C" long long nuc_gpu_get_peak_j(void) { return (long long)G.h_peak_j; }
extern "C" long long nuc_gpu_get_peak_val(void) { return _f2b(G.h_peak_val); }
extern "C" long long nuc_gpu_get_growth_rate(void) { return _f2b(G.h_growth_rate); }
extern "C" long long nuc_gpu_get_fourier_alpha(void) { return _f2b(G.h_fourier_alpha); }
extern "C" long long nuc_gpu_get_fourier_C(void) { return _f2b(G.h_fourier_C); }
extern "C" long long nuc_gpu_get_spectral_trunc(void) {
    return _f2b(_trunc_bound(G.h_fourier_alpha, G.h_fourier_C, G.N));
}

// ================================================================
// ROBUST Fourier-tail diagnostic — adversarial robustness tests
//
// Computes α under 3 shell statistics × 5 fit windows × 2 envelope
// methods = 30+ variants. Reports minimum α and maximum truncation.
// ================================================================

// Helper: least-squares fit of log(data[s]) = intercept + slope*s
// Returns slope, intercept, r2. Only fits shells where data[s] > 1e-300.
static void _ls_fit(const double *data, int lo, int hi,
                    double *out_slope, double *out_intercept, double *out_r2) {
    double ss = 0, sl = 0, ss2 = 0, ssl = 0, sl2 = 0;
    int n = 0;
    for (int s = lo; s <= hi; s++) {
        if (data[s] > 1e-300) {
            double x = (double)s, y = log(data[s]);
            ss += x; sl += y; ss2 += x*x; ssl += x*y; sl2 += y*y;
            n++;
        }
    }
    if (n < 3) { *out_slope = 0; *out_intercept = 0; *out_r2 = 0; return; }
    double dn = (double)n;
    double denom = dn * ss2 - ss * ss;
    if (fabs(denom) < 1e-30) { *out_slope = 0; *out_intercept = 0; *out_r2 = 0; return; }
    *out_slope = (dn * ssl - ss * sl) / denom;
    *out_intercept = (sl - (*out_slope) * ss) / dn;
    // R²
    double mean_y = sl / dn;
    double ss_tot = sl2 - dn * mean_y * mean_y;
    double ss_res = 0;
    for (int s = lo; s <= hi; s++) {
        if (data[s] > 1e-300) {
            double y = log(data[s]);
            double pred = (*out_intercept) + (*out_slope) * (double)s;
            ss_res += (y - pred) * (y - pred);
        }
    }
    *out_r2 = (ss_tot > 1e-30) ? 1.0 - ss_res / ss_tot : 0.0;
}

// Helper: compute truncation bound from alpha and C
// 2D truncation bound with PROVEN shell multiplicity upper bound:
// ||ω||∞ truncation ≤ Σ_{s>N/2} count(s) × C·exp(-α·s)
//
// count(s) = # integer lattice points (kx,ky) with s-0.5 ≤ |(kx,ky)| < s+0.5
//
// PROVEN upper bound via elementary covering argument:
//   Each lattice point in the annulus has a unit square centered on it.
//   The unit square corners lie at distance ≤ √2/2 from the center.
//   All unit squares fit within the expanded annulus:
//     { (x,y) : s - 0.5 - √2/2 ≤ |(x,y)| < s + 0.5 + √2/2 }
//   The expanded annulus has area:
//     π(s+0.5+√2/2)² - π(max(0, s-0.5-√2/2))²
//   For s ≥ 2: = π · 2s · (1+√2) = 2π(1+√2)s ≈ 15.17s
//   Adding π for the constant term and ceiling for integrality:
//     count(s) ≤ ceil(2π(1+√2)·s + π)  for all s ≥ 0
//
// We use the conservative linear bound: count(s) ≤ A·s + B
//   where A = 16 > 2π(1+√2) ≈ 15.17  and  B = 4 > π ≈ 3.14
//   so A·s + B ≥ ceil(2π(1+√2)·s + π) for all s ≥ 0.
//   (Verification: 16s+4 - [15.17s+3.14] = 0.83s+0.86 > 0 for all s ≥ 0.)
//
// Closed form for Σ_{s=S}^∞ (A·s + B)·r^s  where r = exp(-α):
//   = A·Σ s·r^s + B·Σ r^s
//   = A·r^S·(S/(1-r) + r/(1-r)²) + B·r^S/(1-r)
// Proven upper bound for shells beyond SHELL_EXACT_MAX (covering argument):
#define SHELL_BOUND_A 16.0   // proven: > 2π(1+√2) ≈ 15.17
#define SHELL_BOUND_B 4.0    // proven: > π ≈ 3.14
static double _trunc_bound(double alpha, double C_val, int N) {
    if (alpha <= 0) return 1e30;
    int S = N / 2 + 1;  // first unresolved shell
    double r = exp(-alpha);
    if (r >= 1.0 - 1e-15) return 1e30;  // α≈0 → no decay

    // Part 1: EXACT shell counts for s = S .. min(SHELL_EXACT_MAX, reasonable cutoff)
    // Sum Σ exact_count[s] · exp(-α·s) using precomputed counts.
    double exact_sum = 0;
    int exact_end = SHELL_EXACT_MAX;
    // Stop early when exp(-α·s) underflows (saves time for large α)
    for (int s = S; s <= exact_end; s++) {
        double term = (double)G.h_shell_exact[s] * exp(-alpha * (double)s);
        if (term < 1e-300) { exact_end = s; break; }  // rest is zero
        exact_sum += term;
    }

    // Part 2: Proven bound for s > exact_end (if any remain above underflow)
    double tail_sum = 0;
    if (exact_end < SHELL_EXACT_MAX) {
        // Exact sum covered everything — tail is zero
        tail_sum = 0;
    } else {
        // Need proven bound for s > SHELL_EXACT_MAX
        int T = SHELL_EXACT_MAX + 1;
        double eaT = exp(-alpha * (double)T);
        if (eaT > 1e-300) {
            double omr = 1.0 - r;
            double sum_sr = eaT * ((double)T / omr + r / (omr * omr));
            double sum_r = eaT / omr;
            tail_sum = SHELL_BOUND_A * sum_sr + SHELL_BOUND_B * sum_r;
        }
    }

    return C_val * (exact_sum + tail_sum);
}

// Helper: count violations and max violation ratio
static void _count_violations(const double *data, double alpha, double C_val,
                              int lo, int hi, int *out_count, double *out_max_ratio) {
    *out_count = 0; *out_max_ratio = 0;
    for (int s = lo; s <= hi; s++) {
        if (data[s] > 1e-300) {
            double bound = C_val * exp(-alpha * (double)s);
            if (data[s] > bound && bound > 1e-300) {
                (*out_count)++;
                double ratio = data[s] / bound;
                if (ratio > *out_max_ratio) *out_max_ratio = ratio;
            }
        }
    }
}

// Comparison function for qsort
static int _dbl_cmp(const void *a, const void *b) {
    double da = *(const double *)a, db = *(const double *)b;
    return (da > db) - (da < db);
}

extern "C" long long nuc_gpu_fourier_tail_robust(void) {
    int N = G.N, n2 = G.n2;
    int B = gpu_blocks(n2, THREADS);
    int n_shells = N / 2;

    // FFT omega on GPU (same as nuc_gpu_fourier_tail)
    k_real_to_complex<<<B,THREADS>>>(G.d_om_mid, G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_scale_complex<<<B,THREADS>>>(G.d_fft_a, 1.0 / (double)n2, n2);

    static cufftDoubleComplex *h_fft = NULL;
    if (!h_fft) h_fft = (cufftDoubleComplex *)malloc(n2 * sizeof(cufftDoubleComplex));
    cudaMemcpy(h_fft, G.d_fft_a, n2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);

    // --- Pass 1: compute shell_mean, shell_max, shell_p90 ---
    double *sh_sum = G.h_shell_amps;
    double *sh_max = G.h_shell_max;
    double *sh_p90 = G.h_shell_p90;
    static int *sh_count = NULL;
    if (!sh_count) sh_count = (int *)calloc(n_shells + 1, sizeof(int));

    memset(sh_sum, 0, (n_shells + 1) * sizeof(double));
    memset(sh_max, 0, (n_shells + 1) * sizeof(double));
    memset(sh_p90, 0, (n_shells + 1) * sizeof(double));
    memset(sh_count, 0, (n_shells + 1) * sizeof(int));

    // First pass: sum and max
    for (int kx = 0; kx < N; kx++) {
        int kkx = (kx <= N/2) ? kx : kx - N;
        for (int ky = 0; ky < N; ky++) {
            int kky = (ky <= N/2) ? ky : ky - N;
            int shell = (int)(sqrt((double)(kkx*kkx + kky*kky)) + 0.5);
            if (shell > 0 && shell <= n_shells) {
                int idx = kx * N + ky;
                double mag = sqrt(h_fft[idx].x * h_fft[idx].x + h_fft[idx].y * h_fft[idx].y);
                sh_sum[shell] += mag;
                if (mag > sh_max[shell]) sh_max[shell] = mag;
                sh_count[shell]++;
            }
        }
    }

    // Compute mean
    for (int s = 1; s <= n_shells; s++) {
        if (sh_count[s] > 0) sh_sum[s] /= (double)sh_count[s];
    }

    // Second pass: P90 (per-shell sort)
    for (int s = 1; s <= n_shells; s++) {
        if (sh_count[s] == 0) { sh_p90[s] = 0; continue; }
        // Collect modes for this shell
        int cnt = 0;
        for (int kx = 0; kx < N && cnt < G.h_p90_buf_size; kx++) {
            int kkx = (kx <= N/2) ? kx : kx - N;
            for (int ky = 0; ky < N && cnt < G.h_p90_buf_size; ky++) {
                int kky = (ky <= N/2) ? ky : ky - N;
                int sh = (int)(sqrt((double)(kkx*kkx + kky*kky)) + 0.5);
                if (sh == s) {
                    int idx = kx * N + ky;
                    G.h_p90_buf[cnt++] = sqrt(h_fft[idx].x * h_fft[idx].x +
                                               h_fft[idx].y * h_fft[idx].y);
                }
            }
        }
        if (cnt > 0) {
            qsort(G.h_p90_buf, cnt, sizeof(double), _dbl_cmp);
            int p90_idx = (int)(0.9 * (cnt - 1));
            sh_p90[s] = G.h_p90_buf[p90_idx];
        }
    }

    // --- Compute upper envelopes for each stat ---
    // envelope[s] = max(data[s'], s' >= s)
    double *stats[ROB_NSTAT] = { sh_sum, sh_max, sh_p90 };  // mean, max, p90
    double *sh_env = G.h_shell_env;  // reused for each stat during fitting

    // Determine noise-floor-based fit bounds
    // max_amp across all stats
    double max_amp_arr[ROB_NSTAT];
    for (int st = 0; st < ROB_NSTAT; st++) {
        max_amp_arr[st] = 0;
        for (int s = 1; s <= n_shells; s++)
            if (stats[st][s] > max_amp_arr[st]) max_amp_arr[st] = stats[st][s];
    }

    // Window definitions: [lo, hi] where hi depends on noise floor
    // W0: (2, noise_12)  W1: (2, N/4)  W2: (N/4, noise_12)  W3: (2, noise_8)  W4: (10, noise_12)
    int win_lo[ROB_NWIN] = { 2, 2, N/4, 2, 10 };

    // --- Fit all stat × window combinations ---
    G.h_rob_min_alpha = 1e30;
    G.h_rob_max_trunc = 0;

    for (int st = 0; st < ROB_NSTAT; st++) {
        double nf12 = max_amp_arr[st] * 1e-12;
        double nf8  = max_amp_arr[st] * 1e-8;

        // Find noise floor cutoffs for this stat
        int hi_nf12 = n_shells, hi_nf8 = n_shells;
        for (int s = 2; s <= n_shells; s++) {
            if (stats[st][s] < nf12) { hi_nf12 = s - 1; break; }
        }
        for (int s = 2; s <= n_shells; s++) {
            if (stats[st][s] < nf8) { hi_nf8 = s - 1; break; }
        }

        int win_hi[ROB_NWIN] = { hi_nf12, N/4, hi_nf12, hi_nf8, hi_nf12 };

        for (int w = 0; w < ROB_NWIN; w++) {
            int lo = win_lo[w], hi = win_hi[w];
            if (hi < lo + 3) hi = lo + 3;  // minimum 4 points
            if (hi > n_shells) hi = n_shells;

            double slope, intercept, r2;
            _ls_fit(stats[st], lo, hi, &slope, &intercept, &r2);
            double alpha = -slope;
            double C_val = exp(intercept);

            G.h_rob_alpha[st][w] = alpha;
            G.h_rob_C[st][w] = C_val;
            G.h_rob_r2[st][w] = r2;
            G.h_rob_trunc[st][w] = _trunc_bound(alpha, C_val, N);

            _count_violations(stats[st], alpha, C_val, lo, hi,
                              &G.h_rob_violations[st][w], &G.h_rob_max_violation[st][w]);

            // Track global min alpha (only if positive)
            if (alpha > 0 && alpha < G.h_rob_min_alpha) G.h_rob_min_alpha = alpha;
            if (alpha > 0) {
                double tr = G.h_rob_trunc[st][w];
                if (tr > G.h_rob_max_trunc) G.h_rob_max_trunc = tr;
            }
        }

        // --- Upper envelope fit for this stat ---
        for (int s = n_shells; s >= 1; s--) {
            sh_env[s] = stats[st][s];
            if (s < n_shells && sh_env[s+1] > sh_env[s]) sh_env[s] = sh_env[s+1];
        }
        // Fit envelope with baseline window (W0: 2 to noise_12)
        int env_hi = hi_nf12;
        if (env_hi < 5) env_hi = 5;
        double slope_e, intercept_e, r2_e;
        _ls_fit(sh_env, 2, env_hi, &slope_e, &intercept_e, &r2_e);
        G.h_rob_alpha_env[st] = -slope_e;
        G.h_rob_C_env[st] = exp(intercept_e);
        G.h_rob_trunc_env[st] = _trunc_bound(-slope_e, exp(intercept_e), N);

        if (-slope_e > 0 && -slope_e < G.h_rob_min_alpha) G.h_rob_min_alpha = -slope_e;
        if (-slope_e > 0) {
            double tr = G.h_rob_trunc_env[st];
            if (tr > G.h_rob_max_trunc) G.h_rob_max_trunc = tr;
        }
    }

    // Also update the original fields with baseline (mean, W0)
    G.h_fourier_alpha = G.h_rob_alpha[0][0];
    G.h_fourier_C = G.h_rob_C[0][0];

    // ================================================================
    // FORMAL MAJORANT: certified tail bound with zero violations
    //
    // For each candidate α, the tightest C satisfying C·exp(-α·s) ≥ shell_max[s]
    // for ALL resolved shells is C = max_s(shell_max[s]·exp(α·s)).
    // The truncation bound is then C·exp(-α·N/2)/(1-exp(-α)).
    //
    // We sweep α in small steps to find the α that minimizes truncation
    // while maintaining the majorant. Uses shell_max (stat=1) as the
    // most conservative per-mode statistic.
    // ================================================================
    {
        // Find range of meaningful shells for majorant (skip shells with 0 amplitude)
        int maj_lo = 1, maj_hi = n_shells;
        double max_sm = 0;
        for (int s = 1; s <= n_shells; s++) {
            if (sh_max[s] > max_sm) max_sm = sh_max[s];
        }
        if (max_sm < 1e-300) {
            // No signal — majorant trivially valid
            G.h_majorant_alpha = 1.0;
            G.h_majorant_C = 0.0;
            G.h_majorant_trunc = 0.0;
            G.h_majorant_valid = 1;
        } else {
            double noise = max_sm * 1e-14;
            for (int s = n_shells; s >= 1; s--) {
                if (sh_max[s] > noise) { maj_hi = s; break; }
            }

            // Sweep α from 0.0001 to 1.0 in 10000 steps
            double best_alpha = 0, best_C = 1e30, best_trunc = 1e30;
            int found = 0;

            for (int ai = 1; ai <= 10000; ai++) {
                double alpha = (double)ai * 0.0001;  // 0.0001 to 1.0
                // Find C = max over all shells of shell_max[s] * exp(alpha*s)
                double C_val = 0;
                for (int s = maj_lo; s <= maj_hi; s++) {
                    if (sh_max[s] > 1e-300) {
                        double c_s = sh_max[s] * exp(alpha * (double)s);
                        if (c_s > C_val) C_val = c_s;
                    }
                }
                // Truncation with 2D shell multiplicity
                double trunc = _trunc_bound(alpha, C_val, N);

                if (trunc < best_trunc) {
                    best_trunc = trunc;
                    best_alpha = alpha;
                    best_C = C_val;
                    found = 1;
                }
            }

            G.h_majorant_alpha = best_alpha;
            G.h_majorant_C = best_C;
            G.h_majorant_trunc = best_trunc;
            G.h_majorant_valid = found && (best_alpha > 0) && (best_trunc < 1e20);
        }
    }

    return _f2b(G.h_rob_min_alpha);
}

// ================================================================
// GAP 1 bootstrap preparation
//
// Build rigorous upper data for the resolved analytic energy:
//   X_tau = Σ |k|² e^{2τ|k|} (|ω̂_k|² + λ |k|² |θ̂_k|²)
//
// The midpoint coefficients are computed exactly by FFT of the midpoint fields.
// For the error enclosure we use the rigorous per-mode bound
//   |δf̂_k| <= ||δf||₂ / N
// which follows from Parseval for the normalized N×N DFT used here.
// ================================================================
extern "C" long long nuc_gpu_prepare_analytic_bootstrap(void) {
    int N = G.N, n2 = G.n2;
    int B = gpu_blocks(n2, THREADS);
    int n_shells = G.h_gap1_n_shells;

    // FFT ω midpoint
    k_real_to_complex<<<B,THREADS>>>(G.d_om_mid, G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_scale_complex<<<B,THREADS>>>(G.d_fft_a, 1.0 / (double)n2, n2);
    cudaMemcpy(G.h_gap1_fft_om, G.d_fft_a, n2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);

    // FFT θ midpoint
    k_real_to_complex<<<B,THREADS>>>(G.d_th_mid, G.d_fft_b, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_b, G.d_fft_b, CUFFT_FORWARD);
    k_scale_complex<<<B,THREADS>>>(G.d_fft_b, 1.0 / (double)n2, n2);
    cudaMemcpy(G.h_gap1_fft_th, G.d_fft_b, n2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);

    // Download the current signed-error fields and form rigorous per-mode radii
    // via Parseval: max_k |δf̂_k| <= ||δf||₂ / N.
    cudaMemcpy(G.h_host_delta, G.d_delta_om, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(G.h_host_delta2, G.d_delta_th, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    double om_del2 = 0.0, th_del2 = 0.0;
    for (int i = 0; i < n2; i++) {
        double dom = fabs(G.h_host_delta[i]);
        double dth = fabs(G.h_host_delta2[i]);
        om_del2 += dom * dom;
        th_del2 += dth * dth;
    }
    G.h_gap1_rho_om = sqrt(om_del2) / (double)N;
    G.h_gap1_rho_th = sqrt(th_del2) / (double)N;

    memset(G.h_gap1_shell_count_arr, 0, (n_shells + 1) * sizeof(int));
    memset(G.h_gap1_om_l1, 0, (n_shells + 1) * sizeof(double));
    memset(G.h_gap1_om_l2sq, 0, (n_shells + 1) * sizeof(double));
    memset(G.h_gap1_th_l1, 0, (n_shells + 1) * sizeof(double));
    memset(G.h_gap1_th_l2sq, 0, (n_shells + 1) * sizeof(double));
    G.h_trans_nablau_inf_up = 0.0;
    G.h_trans_gradom_inf_up = 0.0;
    G.h_trans_gradth_inf_up = 0.0;

    for (int kx = 0; kx < N; kx++) {
        int kkx = (kx <= N/2) ? kx : kx - N;
        for (int ky = 0; ky < N; ky++) {
            int kky = (ky <= N/2) ? ky : ky - N;
            int shell = (int)(sqrt((double)(kkx * kkx + kky * kky)) + 0.5);
            if (shell <= 0 || shell > n_shells) continue;
            int idx = kx * N + ky;
            double om_mag = hypot(G.h_gap1_fft_om[idx].x, G.h_gap1_fft_om[idx].y);
            double th_mag = hypot(G.h_gap1_fft_th[idx].x, G.h_gap1_fft_th[idx].y);
            G.h_gap1_shell_count_arr[shell]++;
            G.h_gap1_om_l1[shell] += om_mag;
            G.h_gap1_om_l2sq[shell] += om_mag * om_mag;
            G.h_gap1_th_l1[shell] += th_mag;
            G.h_gap1_th_l2sq[shell] += th_mag * th_mag;

            double r = sqrt((double)(kkx * kkx + kky * kky));
            double om_up = om_mag + G.h_gap1_rho_om;
            double th_up = th_mag + G.h_gap1_rho_th;
            G.h_trans_nablau_inf_up += om_up;
            G.h_trans_gradom_inf_up += r * om_up;
            G.h_trans_gradth_inf_up += r * th_up;
        }
    }

    G.h_gap1_ready = 1;
    return _f2b(G.h_gap1_rho_om);
}

extern "C" long long nuc_gpu_analytic_energy_upper(long long lambda_bits, long long tau_bits) {
    if (!G.h_gap1_ready) return _f2b(1e300);

    double lambda = _b2f(lambda_bits);
    double tau = _b2f(tau_bits);
    if (!(lambda > 0.0) || tau < 0.0) return _f2b(1e300);

    double rho_om = G.h_gap1_rho_om;
    double rho_th = G.h_gap1_rho_th;
    double rho_om2 = rho_om * rho_om;
    double rho_th2 = rho_th * rho_th;

    double X_upper = 0.0;
    for (int s = 1; s <= G.h_gap1_n_shells; s++) {
        int cnt = G.h_gap1_shell_count_arr[s];
        if (cnt <= 0) continue;

        double r_hi = (double)s + 0.5;
        double arg = 2.0 * tau * r_hi;
        if (arg > 700.0) {
            G.h_gap1_lambda = lambda;
            G.h_gap1_tau = tau;
            G.h_gap1_X_upper = 1e300;
            return _f2b(G.h_gap1_X_upper);
        }

        double expw = exp(arg);
        double r2 = r_hi * r_hi;
        double om_shell = G.h_gap1_om_l2sq[s]
                        + 2.0 * rho_om * G.h_gap1_om_l1[s]
                        + (double)cnt * rho_om2;
        double th_shell = G.h_gap1_th_l2sq[s]
                        + 2.0 * rho_th * G.h_gap1_th_l1[s]
                        + (double)cnt * rho_th2;

        X_upper += r2 * expw * om_shell + lambda * r2 * r2 * expw * th_shell;
        if (!isfinite(X_upper) || X_upper > 1e300) {
            G.h_gap1_lambda = lambda;
            G.h_gap1_tau = tau;
            G.h_gap1_X_upper = 1e300;
            return _f2b(G.h_gap1_X_upper);
        }
    }

    G.h_gap1_lambda = lambda;
    G.h_gap1_tau = tau;
    G.h_gap1_X_upper = X_upper;
    return _f2b(X_upper);
}

extern "C" long long nuc_gpu_sobolev_energy_upper(long long m_bits, long long lambda_bits) {
    if (!G.h_gap1_ready) return _f2b(1e300);

    int m = (int)m_bits;
    double lambda = _b2f(lambda_bits);
    if (m < 0 || !isfinite(lambda) || lambda <= 0.0) return _f2b(1e300);

    double rho_om = G.h_gap1_rho_om;
    double rho_th = G.h_gap1_rho_th;
    double rho_om2 = rho_om * rho_om;
    double rho_th2 = rho_th * rho_th;
    double S_upper = 0.0;

    for (int s = 1; s <= G.h_gap1_n_shells; s++) {
        int cnt = G.h_gap1_shell_count_arr[s];
        if (cnt <= 0) continue;

        double r_hi = (double)s + 0.5;
        double w2 = 1.0 + r_hi * r_hi;
        double w_om = pow(w2, (double)m);
        double w_th = pow(w2, (double)(m + 1));

        double om_shell = G.h_gap1_om_l2sq[s]
                        + 2.0 * rho_om * G.h_gap1_om_l1[s]
                        + (double)cnt * rho_om2;
        double th_shell = G.h_gap1_th_l2sq[s]
                        + 2.0 * rho_th * G.h_gap1_th_l1[s]
                        + (double)cnt * rho_th2;

        S_upper += w_om * om_shell + lambda * w_th * th_shell;
        if (!isfinite(S_upper) || S_upper > 1e300) return _f2b(1e300);
    }

    return _f2b(S_upper);
}

extern "C" long long nuc_gpu_aposteriori_residual_mid(long long s_bits, long long lambda_bits) {
    if (!G.h_gap1_ready) return _f2b(1e300);

    int s = (int)s_bits;
    double lambda = _b2f(lambda_bits);
    if (s < 0 || !isfinite(lambda) || lambda <= 0.0) return _f2b(1e300);
    if (G.M < 2 * G.N) return _f2b(1e300);

    int n2 = G.n2;
    int m2 = G.m2;

    // Midpoint reference flow and derivatives
    gpu_poisson(G.d_om_mid, G.d_ps[0]);
    gpu_velocity(G.d_ps[0], G.d_uf[0], G.d_vf[0]);
    gpu_ddx(G.d_om_mid, G.d_omx[0]);
    gpu_ddy(G.d_om_mid, G.d_omy[0]);
    gpu_ddx(G.d_th_mid, G.d_thx[0]);
    gpu_ddy(G.d_th_mid, G.d_thy[0]);

    memset(G.h_gap1_fft_accum, 0, m2 * sizeof(cufftDoubleComplex));

    // omega residual = Q_K(u*ω_x + v*ω_y)
    gpu_dealiased_mul_fullfft(G.d_uf[0], G.d_omx[0]);
    cudaMemcpy(G.h_gap1_fft_prod, G.d_fft_pa, m2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);
    for (int i = 0; i < m2; i++) G.h_gap1_fft_accum[i] = G.h_gap1_fft_prod[i];

    gpu_dealiased_mul_fullfft(G.d_vf[0], G.d_omy[0]);
    cudaMemcpy(G.h_gap1_fft_prod, G.d_fft_pa, m2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);
    for (int i = 0; i < m2; i++) {
        G.h_gap1_fft_accum[i].x += G.h_gap1_fft_prod[i].x;
        G.h_gap1_fft_accum[i].y += G.h_gap1_fft_prod[i].y;
    }
    double om_sq = _accum_omitted_hs_norm_sq(G.h_gap1_fft_accum, G.M, G.N, s);

    // theta residual = Q_K(u*θ_x + v*θ_y)
    memset(G.h_gap1_fft_accum, 0, m2 * sizeof(cufftDoubleComplex));

    gpu_dealiased_mul_fullfft(G.d_uf[0], G.d_thx[0]);
    cudaMemcpy(G.h_gap1_fft_prod, G.d_fft_pa, m2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);
    for (int i = 0; i < m2; i++) G.h_gap1_fft_accum[i] = G.h_gap1_fft_prod[i];

    gpu_dealiased_mul_fullfft(G.d_vf[0], G.d_thy[0]);
    cudaMemcpy(G.h_gap1_fft_prod, G.d_fft_pa, m2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);
    for (int i = 0; i < m2; i++) {
        G.h_gap1_fft_accum[i].x += G.h_gap1_fft_prod[i].x;
        G.h_gap1_fft_accum[i].y += G.h_gap1_fft_prod[i].y;
    }
    double th_sq = _accum_omitted_hs_norm_sq(G.h_gap1_fft_accum, G.M, G.N, s + 1);

    G.h_apost_resid_omega_mid = sqrt(om_sq);
    G.h_apost_resid_theta_mid = sqrt(th_sq);
    G.h_apost_resid_combo_mid = om_sq + lambda * th_sq;
    G.h_apost_last_s = s;
    G.h_apost_last_lambda = lambda;

    return _f2b(G.h_apost_resid_combo_mid);
}

extern "C" long long nuc_gpu_aposteriori_residual_l2_mid(long long lambda_bits) {
    if (!G.h_gap1_ready) return _f2b(1e300);

    double lambda = _b2f(lambda_bits);
    if (!isfinite(lambda) || lambda <= 0.0) return _f2b(1e300);
    if (G.M < 2 * G.N) return _f2b(1e300);

    int m2 = G.m2;

    gpu_poisson(G.d_om_mid, G.d_ps[0]);
    gpu_velocity(G.d_ps[0], G.d_uf[0], G.d_vf[0]);
    gpu_ddx(G.d_om_mid, G.d_omx[0]);
    gpu_ddy(G.d_om_mid, G.d_omy[0]);
    gpu_ddx(G.d_th_mid, G.d_thx[0]);
    gpu_ddy(G.d_th_mid, G.d_thy[0]);

    memset(G.h_gap1_fft_accum, 0, m2 * sizeof(cufftDoubleComplex));

    gpu_dealiased_mul_fullfft(G.d_uf[0], G.d_omx[0]);
    cudaMemcpy(G.h_gap1_fft_prod, G.d_fft_pa, m2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);
    for (int i = 0; i < m2; i++) G.h_gap1_fft_accum[i] = G.h_gap1_fft_prod[i];

    gpu_dealiased_mul_fullfft(G.d_vf[0], G.d_omy[0]);
    cudaMemcpy(G.h_gap1_fft_prod, G.d_fft_pa, m2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);
    for (int i = 0; i < m2; i++) {
        G.h_gap1_fft_accum[i].x += G.h_gap1_fft_prod[i].x;
        G.h_gap1_fft_accum[i].y += G.h_gap1_fft_prod[i].y;
    }
    double om_sq = _accum_omitted_hs_norm_sq(G.h_gap1_fft_accum, G.M, G.N, 0);

    memset(G.h_gap1_fft_accum, 0, m2 * sizeof(cufftDoubleComplex));

    gpu_dealiased_mul_fullfft(G.d_uf[0], G.d_thx[0]);
    cudaMemcpy(G.h_gap1_fft_prod, G.d_fft_pa, m2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);
    for (int i = 0; i < m2; i++) G.h_gap1_fft_accum[i] = G.h_gap1_fft_prod[i];

    gpu_dealiased_mul_fullfft(G.d_vf[0], G.d_thy[0]);
    cudaMemcpy(G.h_gap1_fft_prod, G.d_fft_pa, m2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);
    for (int i = 0; i < m2; i++) {
        G.h_gap1_fft_accum[i].x += G.h_gap1_fft_prod[i].x;
        G.h_gap1_fft_accum[i].y += G.h_gap1_fft_prod[i].y;
    }
    double th_sq = _accum_omitted_hs_norm_sq(G.h_gap1_fft_accum, G.M, G.N, 0);

    G.h_apost_l2_resid_omega_mid = sqrt(om_sq);
    G.h_apost_l2_resid_theta_mid = sqrt(th_sq);
    G.h_apost_l2_resid_combo_mid = om_sq + lambda * th_sq;
    G.h_apost_last_lambda = lambda;

    return _f2b(G.h_apost_l2_resid_combo_mid);
}

extern "C" long long nuc_gpu_symmetric_s0_energy_upper(long long lambda_bits, long long tau_bits) {
    if (!G.h_gap1_ready) return _f2b(1e300);

    double lambda = _b2f(lambda_bits);
    double tau = _b2f(tau_bits);
    if (!(lambda > 0.0) || tau < 0.0) return _f2b(1e300);

    int N = G.N;
    double rho_om = G.h_gap1_rho_om;
    double rho_th = G.h_gap1_rho_th;
    double E_upper = 0.0;

    for (int kx = 0; kx < N; kx++) {
        int kkx = (kx <= N / 2) ? kx : kx - N;
        for (int ky = 0; ky < N; ky++) {
            int kky = (ky <= N / 2) ? ky : ky - N;
            if (kkx == 0 && kky == 0) continue;

            double r = sqrt((double)(kkx * kkx + kky * kky));
            double arg = 2.0 * tau * r;
            if (arg > 700.0) return _f2b(1e300);
            double w = exp(arg);

            int idx = kx * N + ky;
            double om_mag = hypot(G.h_gap1_fft_om[idx].x, G.h_gap1_fft_om[idx].y) + rho_om;
            double th_mag = hypot(G.h_gap1_fft_th[idx].x, G.h_gap1_fft_th[idx].y) + rho_th;

            E_upper += w * (om_mag * om_mag + lambda * th_mag * th_mag);
            if (!isfinite(E_upper) || E_upper > 1e300) return _f2b(1e300);
        }
    }

    return _f2b(E_upper);
}

extern "C" long long nuc_gpu_symmetric_s0_d_lower(long long lambda_bits, long long tau_bits) {
    if (!G.h_gap1_ready) return _f2b(0.0);

    double lambda = _b2f(lambda_bits);
    double tau = _b2f(tau_bits);
    if (!(lambda > 0.0) || tau < 0.0) return _f2b(0.0);

    int N = G.N;
    double rho_om = G.h_gap1_rho_om;
    double rho_th = G.h_gap1_rho_th;
    double D_lower = 0.0;

    for (int kx = 0; kx < N; kx++) {
        int kkx = (kx <= N / 2) ? kx : kx - N;
        for (int ky = 0; ky < N; ky++) {
            int kky = (ky <= N / 2) ? ky : ky - N;
            if (kkx == 0 && kky == 0) continue;

            double r = sqrt((double)(kkx * kkx + kky * kky));
            double arg = 2.0 * tau * r;
            if (arg > 700.0) return _f2b(0.0);
            double w = r * exp(arg);

            int idx = kx * N + ky;
            double om_mag = hypot(G.h_gap1_fft_om[idx].x, G.h_gap1_fft_om[idx].y);
            double th_mag = hypot(G.h_gap1_fft_th[idx].x, G.h_gap1_fft_th[idx].y);
            double om_lo = om_mag - rho_om;
            double th_lo = th_mag - rho_th;
            if (om_lo < 0.0) om_lo = 0.0;
            if (th_lo < 0.0) th_lo = 0.0;

            D_lower += w * (om_lo * om_lo + lambda * th_lo * th_lo);
            if (!isfinite(D_lower) || D_lower > 1e300) return _f2b(0.0);
        }
    }

    return _f2b(D_lower);
}

extern "C" long long nuc_gpu_symmetric_s0_forcing_upper(long long tau_bits) {
    if (!G.h_gap1_ready) return _f2b(1e300);

    double tau = _b2f(tau_bits);
    if (tau < 0.0) return _f2b(1e300);

    int N = G.N;
    double rho_om = G.h_gap1_rho_om;
    double rho_th = G.h_gap1_rho_th;
    double mid_real = 0.0;
    double err = 0.0;

    for (int kx = 0; kx < N; kx++) {
        int kkx = (kx <= N / 2) ? kx : kx - N;
        if (kkx == 0) continue;
        for (int ky = 0; ky < N; ky++) {
            int kky = (ky <= N / 2) ? ky : ky - N;
            if (kkx == 0 && kky == 0) continue;

            double r = sqrt((double)(kkx * kkx + kky * kky));
            double arg = 2.0 * tau * r;
            if (arg > 700.0) return _f2b(1e300);
            double w = exp(arg);

            int idx = kx * N + ky;
            double wr = G.h_gap1_fft_om[idx].x;
            double wi = G.h_gap1_fft_om[idx].y;
            double tr = G.h_gap1_fft_th[idx].x;
            double ti = G.h_gap1_fft_th[idx].y;
            double om_mag = hypot(wr, wi);
            double th_mag = hypot(tr, ti);

            mid_real += w * (double)kkx * (wi * tr - wr * ti);
            err += w * (double)abs(kkx)
                 * (om_mag * rho_th + th_mag * rho_om + rho_om * rho_th);
            if (!isfinite(mid_real) || !isfinite(err) || fabs(mid_real) > 1e300 || err > 1e300) {
                return _f2b(1e300);
            }
        }
    }

    double F_upper = 2.0 * fabs(mid_real) + 2.0 * err;
    if (!isfinite(F_upper) || F_upper > 1e300) return _f2b(1e300);
    return _f2b(F_upper);
}

static void _chi_annulus(double dx, double dy, double rin, double rout,
                         double *chi, double *gx, double *gy) {
    double r = sqrt(dx * dx + dy * dy);
    if (r <= rin) {
        *chi = 1.0; *gx = 0.0; *gy = 0.0;
        return;
    }
    if (r >= rout || rout <= rin) {
        *chi = 0.0; *gx = 0.0; *gy = 0.0;
        return;
    }
    double t = (r - rin) / (rout - rin);
    *chi = 0.5 * (1.0 + cos(M_PI * t));
    double dchi_dr = -0.5 * M_PI * sin(M_PI * t) / (rout - rin);
    if (r > 1e-14) {
        *gx = dchi_dr * dx / r;
        *gy = dchi_dr * dy / r;
    } else {
        *gx = 0.0; *gy = 0.0;
    }
}

extern "C" long long nuc_gpu_local_mechanism_probe(long long rin_bits, long long rout_bits) {
    int n2 = G.n2, N = G.N;
    double dx = G.dx;
    double rin = _b2f(rin_bits);
    double rout = _b2f(rout_bits);
    if (!(rin >= 0.0) || !(rout > rin)) return _f2b(-1e300);

    // Midpoint reference fields
    gpu_poisson(G.d_om_mid, G.d_ps[0]);
    gpu_velocity(G.d_ps[0], G.d_uf[0], G.d_vf[0]);
    gpu_ddx(G.d_th_mid, G.d_thx[0]);

    double *h_om = G.h_host_mid;
    double *h_u = G.h_host_delta;
    double *h_v = G.h_host_mid2;
    double *h_thx = G.h_host_delta2;

    cudaMemcpy(h_om, G.d_om_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_u, G.d_uf[0], n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_v, G.d_vf[0], n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_thx, G.d_thx[0], n2 * sizeof(double), cudaMemcpyDeviceToHost);

    static double *h_aux1 = NULL;
    static double *h_aux2 = NULL;
    if (!h_aux1) h_aux1 = (double *)malloc(n2 * sizeof(double));
    if (!h_aux2) h_aux2 = (double *)malloc(n2 * sizeof(double));
    if (!h_aux1 || !h_aux2) return _f2b(-1e300);

    int pi = G.h_peak_i, pj = G.h_peak_j;
    if (pi < 0 || pi >= N) pi = 0;
    if (pj < 0 || pj >= N) pj = 0;
    int pidx = pi * N + pj;
    double x0 = (double)pi * dx;
    double y0 = (double)pj * dx;
    double Vx = h_u[pidx];
    double Vy = h_v[pidx];

    double cell_area = dx * dx;
    double Omega_chi = 0.0, J_chi = 0.0, P_chi = 0.0;
    double B_Omega = 0.0, B_J = 0.0;

    for (int i = 0; i < N; i++) {
        double xi = (double)i * dx;
        double ddx0 = xi - x0;
        if (ddx0 > M_PI) ddx0 -= 2.0 * M_PI;
        if (ddx0 < -M_PI) ddx0 += 2.0 * M_PI;
        for (int j = 0; j < N; j++) {
            double yj = (double)j * dx;
            double ddy0 = yj - y0;
            if (ddy0 > M_PI) ddy0 -= 2.0 * M_PI;
            if (ddy0 < -M_PI) ddy0 += 2.0 * M_PI;
            double chi, gx, gy;
            _chi_annulus(ddx0, ddy0, rin, rout, &chi, &gx, &gy);
            if (chi <= 0.0 && fabs(gx) < 1e-30 && fabs(gy) < 1e-30) continue;

            int idx = i * N + j;
            double om = h_om[idx];
            double tx = h_thx[idx];
            double drift = (h_u[idx] - Vx) * gx + (h_v[idx] - Vy) * gy;

            Omega_chi += chi * om * om;
            J_chi += chi * om * tx;
            P_chi += chi * tx * tx;
            B_Omega += drift * om * om;
            B_J += drift * om * tx;
        }
    }

    // Need theta_y, u_x, u_y, v_x for the opposition-term split
    gpu_ddy(G.d_th_mid, G.d_scratch1);
    cudaMemcpy(h_aux1, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost); // theta_y
    gpu_ddx(G.d_uf[0], G.d_scratch1);
    cudaMemcpy(h_u, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);    // u_x
    gpu_ddx(G.d_vf[0], G.d_scratch2);
    cudaMemcpy(h_aux2, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost); // v_x
    gpu_ddy(G.d_uf[0], G.d_scratch2);
    cudaMemcpy(h_v, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);    // u_y

    double O_chi = 0.0;
    double O_diag = 0.0;
    double O_shear = 0.0;
    double O_rot = 0.0;
    for (int i = 0; i < N; i++) {
        double xi = (double)i * dx;
        double ddx0 = xi - x0;
        if (ddx0 > M_PI) ddx0 -= 2.0 * M_PI;
        if (ddx0 < -M_PI) ddx0 += 2.0 * M_PI;
        for (int j = 0; j < N; j++) {
            double yj = (double)j * dx;
            double ddy0 = yj - y0;
            if (ddy0 > M_PI) ddy0 -= 2.0 * M_PI;
            if (ddy0 < -M_PI) ddy0 += 2.0 * M_PI;
            double chi, gx, gy;
            _chi_annulus(ddx0, ddy0, rin, rout, &chi, &gx, &gy);
            (void)gx; (void)gy;
            if (chi <= 0.0) continue;

            int idx = i * N + j;
            double om = h_om[idx];
            double tx = h_thx[idx];
            double ty = h_aux1[idx];
            double ux = h_u[idx];
            double uy = h_v[idx];
            double vx = h_aux2[idx];
            double shear = 0.5 * (uy + vx);
            double opp_diag = ux * tx;
            double opp_shear = shear * ty;
            // Runtime convention: Delta psi = omega, u = psi_y, v = -psi_x,
            // so curl(u) = v_x - u_y = -omega and the antisymmetric column
            // contributes -(omega/2) * theta_y.
            double opp_rot = -0.5 * om * ty;
            O_diag += chi * om * opp_diag;
            O_shear += chi * om * opp_shear;
            O_rot += chi * om * opp_rot;
            O_chi += chi * om * (opp_diag + opp_shear + opp_rot);
        }
    }

    G.h_mech_omega_chi = Omega_chi * cell_area;
    G.h_mech_j_chi = J_chi * cell_area;
    G.h_mech_p_chi = P_chi * cell_area;
    G.h_mech_o_chi = O_chi * cell_area;
    G.h_mech_o_diag = O_diag * cell_area;
    G.h_mech_o_shear = O_shear * cell_area;
    G.h_mech_o_rot = O_rot * cell_area;
    G.h_mech_bomega = B_Omega * cell_area;
    G.h_mech_bj = B_J * cell_area;
    G.h_mech_center_x = x0;
    G.h_mech_center_y = y0;
    G.h_mech_vel_x = Vx;
    G.h_mech_vel_y = Vy;
    G.h_mech_rin = rin;
    G.h_mech_rout = rout;
    return _f2b(G.h_mech_j_chi);
}

extern "C" long long nuc_gpu_local_geometry_probe(long long rin_bits, long long rout_bits) {
    int n2 = G.n2, N = G.N;
    double dx = G.dx;
    double rin = _b2f(rin_bits);
    double rout = _b2f(rout_bits);
    if (!(rin >= 0.0) || !(rout > rin)) return _f2b(-1e300);

    // Ensure the interpolated peak location is current.
    nuc_gpu_compute_bkm();
    double x0 = G.h_interp_x;
    double y0 = G.h_interp_y;

    gpu_poisson(G.d_om_mid, G.d_ps[0]);
    gpu_velocity(G.d_ps[0], G.d_uf[0], G.d_vf[0]);

    double *h_om = G.h_host_mid;
    double *h_thx = G.h_host_delta;
    double *h_thy = G.h_host_mid2;
    double *h_ux = G.h_host_delta2;

    cudaMemcpy(h_om, G.d_om_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    gpu_ddx(G.d_th_mid, G.d_scratch1);
    cudaMemcpy(h_thx, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    gpu_ddy(G.d_th_mid, G.d_scratch2);
    cudaMemcpy(h_thy, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    gpu_ddx(G.d_uf[0], G.d_scratch1);
    cudaMemcpy(h_ux, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    static double *h_uy = NULL;
    static double *h_vx = NULL;
    static cufftDoubleComplex *h_fft_th = NULL;
    static cufftDoubleComplex *h_fft_u = NULL;
    static cufftDoubleComplex *h_fft_v = NULL;
    if (!h_uy) h_uy = (double *)malloc(n2 * sizeof(double));
    if (!h_vx) h_vx = (double *)malloc(n2 * sizeof(double));
    if (!h_fft_th) h_fft_th = (cufftDoubleComplex *)malloc(n2 * sizeof(cufftDoubleComplex));
    if (!h_fft_u) h_fft_u = (cufftDoubleComplex *)malloc(n2 * sizeof(cufftDoubleComplex));
    if (!h_fft_v) h_fft_v = (cufftDoubleComplex *)malloc(n2 * sizeof(cufftDoubleComplex));
    if (!h_uy || !h_vx || !h_fft_th || !h_fft_u || !h_fft_v) return _f2b(-1e300);

    gpu_ddy(G.d_uf[0], G.d_scratch2);
    cudaMemcpy(h_uy, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    gpu_ddx(G.d_vf[0], G.d_scratch1);
    cudaMemcpy(h_vx, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    int B = gpu_blocks(n2, THREADS);
    k_real_to_complex<<<B,THREADS>>>(G.d_th_mid, G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_scale_complex<<<B,THREADS>>>(G.d_fft_a, 1.0/(double)n2, n2);
    cudaMemcpy(h_fft_th, G.d_fft_a, n2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);

    k_real_to_complex<<<B,THREADS>>>(G.d_uf[0], G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_scale_complex<<<B,THREADS>>>(G.d_fft_a, 1.0/(double)n2, n2);
    cudaMemcpy(h_fft_u, G.d_fft_a, n2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);

    k_real_to_complex<<<B,THREADS>>>(G.d_vf[0], G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_scale_complex<<<B,THREADS>>>(G.d_fft_a, 1.0/(double)n2, n2);
    cudaMemcpy(h_fft_v, G.d_fft_a, n2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);

    double tx_peak, ty_peak, ux_peak, uy_peak, vx_peak, vy_peak;
    _eval_grad(h_fft_th, N, x0, y0, &tx_peak, &ty_peak);
    _eval_grad(h_fft_u, N, x0, y0, &ux_peak, &uy_peak);
    _eval_grad(h_fft_v, N, x0, y0, &vx_peak, &vy_peak);
    double shear_peak = 0.5 * (uy_peak + vx_peak);
    double lambda_peak = sqrt(ux_peak * ux_peak + shear_peak * shear_peak);
    double strain_angle_peak = 0.5 * atan2(shear_peak, ux_peak);
    double peak_angle = atan2(ty_peak, tx_peak);

    double mass = 0.0;
    double tx_sum = 0.0, ty_sum = 0.0;
    double ux_sum = 0.0, shear_sum = 0.0, lam_sum = 0.0;
    double c2_sum = 0.0, s2_sum = 0.0;
    for (int i = 0; i < N; i++) {
        double xi = (double)i * dx;
        double ddx0 = xi - x0;
        if (ddx0 > M_PI) ddx0 -= 2.0 * M_PI;
        if (ddx0 < -M_PI) ddx0 += 2.0 * M_PI;
        for (int j = 0; j < N; j++) {
            double yj = (double)j * dx;
            double ddy0 = yj - y0;
            if (ddy0 > M_PI) ddy0 -= 2.0 * M_PI;
            if (ddy0 < -M_PI) ddy0 += 2.0 * M_PI;
            double chi, gx, gy;
            _chi_annulus(ddx0, ddy0, rin, rout, &chi, &gx, &gy);
            (void)gx; (void)gy;
            if (chi <= 0.0) continue;

            int idx = i * N + j;
            double om = h_om[idx];
            double w = chi * om * om;
            double shear = 0.5 * (h_uy[idx] + h_vx[idx]);
            double lam = sqrt(h_ux[idx] * h_ux[idx] + shear * shear);
            mass += w;
            tx_sum += w * h_thx[idx];
            ty_sum += w * h_thy[idx];
            ux_sum += w * h_ux[idx];
            shear_sum += w * shear;
            lam_sum += w * lam;
            if (lam > 1e-30) {
                c2_sum += w * (h_ux[idx] / lam);
                s2_sum += w * (shear / lam);
            }
        }
    }

    G.h_geom_peak_tx = tx_peak;
    G.h_geom_peak_ty = ty_peak;
    G.h_geom_peak_angle = peak_angle;
    G.h_geom_peak_ux = ux_peak;
    G.h_geom_peak_shear = shear_peak;
    G.h_geom_peak_lambda = lambda_peak;
    G.h_geom_peak_strain_angle = strain_angle_peak;
    G.h_geom_peak_align = _axis_angle_diff(peak_angle, strain_angle_peak);
    G.h_geom_patch_mass = mass * dx * dx;

    if (mass > 0.0) {
        double inv = 1.0 / mass;
        double tx_avg = tx_sum * inv;
        double ty_avg = ty_sum * inv;
        double ux_avg = ux_sum * inv;
        double shear_avg = shear_sum * inv;
        double strain_patch = 0.5 * atan2(s2_sum, c2_sum);
        G.h_geom_patch_tx = tx_avg;
        G.h_geom_patch_ty = ty_avg;
        G.h_geom_patch_angle = atan2(ty_avg, tx_avg);
        G.h_geom_patch_ux = ux_avg;
        G.h_geom_patch_shear = shear_avg;
        G.h_geom_patch_lambda = lam_sum * inv;
        G.h_geom_patch_strain_angle = strain_patch;
        G.h_geom_patch_align = _axis_angle_diff(G.h_geom_patch_angle, strain_patch);
    } else {
        G.h_geom_patch_tx = 0.0;
        G.h_geom_patch_ty = 0.0;
        G.h_geom_patch_angle = 0.0;
        G.h_geom_patch_ux = 0.0;
        G.h_geom_patch_shear = 0.0;
        G.h_geom_patch_lambda = 0.0;
        G.h_geom_patch_strain_angle = 0.0;
        G.h_geom_patch_align = 0.0;
    }

    return _f2b(G.h_geom_peak_angle);
}

extern "C" long long nuc_gpu_phase3_farfield_probe(long long rin_bits, long long rout_bits,
                                                    long long a_bits) {
    int n2 = G.n2, N = G.N;
    double dx = G.dx;
    double rin = _b2f(rin_bits);
    double rout = _b2f(rout_bits);
    double a = _b2f(a_bits);
    if (!(rin >= 0.0) || !(rout > rin)) return _f2b(-1e300);

    gpu_poisson(G.d_om_mid, G.d_ps[0]);
    gpu_velocity(G.d_ps[0], G.d_uf[0], G.d_vf[0]);
    gpu_ddx(G.d_th_mid, G.d_thx[0]);

    double *h_om = G.h_host_mid;
    double *h_u = G.h_host_delta;
    double *h_v = G.h_host_mid2;
    double *h_thx = G.h_host_delta2;

    cudaMemcpy(h_om, G.d_om_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_u, G.d_uf[0], n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_v, G.d_vf[0], n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_thx, G.d_thx[0], n2 * sizeof(double), cudaMemcpyDeviceToHost);

    static double *h_thy = NULL;
    static double *h_ux = NULL;
    static double *h_uy = NULL;
    static double *h_vx = NULL;
    if (!h_thy) h_thy = (double *)malloc(n2 * sizeof(double));
    if (!h_ux) h_ux = (double *)malloc(n2 * sizeof(double));
    if (!h_uy) h_uy = (double *)malloc(n2 * sizeof(double));
    if (!h_vx) h_vx = (double *)malloc(n2 * sizeof(double));
    if (!h_thy || !h_ux || !h_uy || !h_vx) return _f2b(-1e300);

    gpu_ddy(G.d_th_mid, G.d_scratch1);
    cudaMemcpy(h_thy, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    gpu_ddx(G.d_uf[0], G.d_scratch1);
    cudaMemcpy(h_ux, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    gpu_ddy(G.d_uf[0], G.d_scratch2);
    cudaMemcpy(h_uy, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    gpu_ddx(G.d_vf[0], G.d_scratch1);
    cudaMemcpy(h_vx, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    int pi = G.h_peak_i, pj = G.h_peak_j;
    if (pi < 0 || pi >= N) pi = 0;
    if (pj < 0 || pj >= N) pj = 0;
    double x0 = (double)pi * dx;
    double y0 = (double)pj * dx;

    double cell_area = dx * dx;
    double Omega_far = 0.0;
    double T_far = 0.0;
    double O_far = 0.0;
    double G_far = 0.0;
    double D_far = 0.0;

    for (int i = 0; i < N; i++) {
        double xi = (double)i * dx;
        double ddx0 = xi - x0;
        if (ddx0 > M_PI) ddx0 -= 2.0 * M_PI;
        if (ddx0 < -M_PI) ddx0 += 2.0 * M_PI;
        for (int j = 0; j < N; j++) {
            double yj = (double)j * dx;
            double ddy0 = yj - y0;
            if (ddy0 > M_PI) ddy0 -= 2.0 * M_PI;
            if (ddy0 < -M_PI) ddy0 += 2.0 * M_PI;
            double chi, gx, gy;
            _chi_annulus(ddx0, ddy0, rin, rout, &chi, &gx, &gy);
            (void)gx; (void)gy;
            double alpha = 1.0 - chi;
            if (alpha <= 0.0) continue;

            int idx = i * N + j;
            double om = h_om[idx];
            double tx = h_thx[idx];
            double ty = h_thy[idx];
            double ux = h_ux[idx];
            double uy = h_uy[idx];
            double vx = h_vx[idx];
            double g_here = sqrt(2.0 * ux * ux + uy * uy + vx * vx);
            if (g_here > G_far) G_far = g_here;

            Omega_far += alpha * om * om;
            T_far += alpha * ty * ty;
            O_far += alpha * om * (ux * tx + vx * ty);
            double defect = tx - a * om;
            D_far += alpha * defect * defect;
        }
    }

    G.h_far_omega = Omega_far * cell_area;
    G.h_far_thetay = T_far * cell_area;
    G.h_far_opp = O_far * cell_area;
    G.h_far_ginf = G_far;
    G.h_far_defect = D_far * cell_area;
    G.h_far_center_x = x0;
    G.h_far_center_y = y0;
    G.h_far_rin = rin;
    G.h_far_rout = rout;
    return _f2b(G.h_far_defect);
}

extern "C" long long nuc_gpu_phase3_interval_probe(long long rin_bits, long long rout_bits) {
    int n2 = G.n2, N = G.N;
    double dx = G.dx;
    double rin = _b2f(rin_bits);
    double rout = _b2f(rout_bits);
    if (!(rin >= 0.0) || !(rout > rin)) return _f2b(-1e300);

    // Midpoint fields.
    gpu_poisson(G.d_om_mid, G.d_ps[0]);
    gpu_velocity(G.d_ps[0], G.d_uf[0], G.d_vf[0]);
    gpu_ddx(G.d_th_mid, G.d_scratch1);   // theta_x mid
    gpu_ddy(G.d_th_mid, G.d_scratch2);   // theta_y mid
    gpu_ddx(G.d_uf[0], G.d_comp1);       // u_x mid
    gpu_ddx(G.d_vf[0], G.d_comp2);       // v_x mid

    // Radii from the same linear operators on the delta fields.
    gpu_ddx(G.d_delta_th, G.d_dthx[0]);  // theta_x radius (signed)
    gpu_ddy(G.d_delta_th, G.d_dthy[0]);  // theta_y radius (signed)
    gpu_poisson(G.d_delta_om, G.d_dps[0]);
    gpu_velocity(G.d_dps[0], G.d_duf[0], G.d_dvf[0]);
    gpu_ddx(G.d_duf[0], G.d_domx[0]);    // u_x radius (signed)
    gpu_ddx(G.d_dvf[0], G.d_domy[0]);    // v_x radius (signed)

    static double *h_om_mid = NULL;
    static double *h_om_rad = NULL;
    static double *h_tx_mid = NULL;
    static double *h_tx_rad = NULL;
    static double *h_ty_mid = NULL;
    static double *h_ty_rad = NULL;
    static double *h_ux_mid = NULL;
    static double *h_ux_rad = NULL;
    static double *h_vx_mid = NULL;
    static double *h_vx_rad = NULL;
    static double *h_omdot_mid = NULL;
    static double *h_txtdot_mid = NULL;
    if (!h_om_mid) h_om_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_om_rad) h_om_rad = (double *)malloc(n2 * sizeof(double));
    if (!h_tx_mid) h_tx_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_tx_rad) h_tx_rad = (double *)malloc(n2 * sizeof(double));
    if (!h_ty_mid) h_ty_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_ty_rad) h_ty_rad = (double *)malloc(n2 * sizeof(double));
    if (!h_ux_mid) h_ux_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_ux_rad) h_ux_rad = (double *)malloc(n2 * sizeof(double));
    if (!h_vx_mid) h_vx_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_vx_rad) h_vx_rad = (double *)malloc(n2 * sizeof(double));
    if (!h_omdot_mid) h_omdot_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_txtdot_mid) h_txtdot_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_om_mid || !h_om_rad || !h_tx_mid || !h_tx_rad || !h_ty_mid || !h_ty_rad ||
        !h_ux_mid || !h_ux_rad || !h_vx_mid || !h_vx_rad ||
        !h_omdot_mid || !h_txtdot_mid) return _f2b(-1e300);

    cudaMemcpy(h_om_mid, G.d_om_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_om_rad, G.d_delta_om, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_tx_mid, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_ty_mid, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_tx_rad, G.d_dthx[0], n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_ty_rad, G.d_dthy[0], n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_ux_mid, G.d_comp1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_vx_mid, G.d_comp2, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_ux_rad, G.d_domx[0], n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_vx_rad, G.d_domy[0], n2 * sizeof(double), cudaMemcpyDeviceToHost);

    int pi = G.h_peak_i, pj = G.h_peak_j;
    if (pi < 0 || pi >= N) pi = 0;
    if (pj < 0 || pj >= N) pj = 0;
    double x0 = (double)pi * dx;
    double y0 = (double)pj * dx;

    double om_chi_lo = 0.0, om_chi_hi = 0.0;
    double j_chi_lo = 0.0, j_chi_hi = 0.0;
    double p_chi_lo = 0.0, p_chi_hi = 0.0;
    double o_chi_hi = 0.0;
    double om_far_lo = 0.0, om_far_hi = 0.0;
    double j_far_lo = 0.0, j_far_hi = 0.0;
    double p_far_lo = 0.0, p_far_hi = 0.0;
    double o_far_hi = 0.0;
    double om_chi_ex = 0.0, j_chi_ex = 0.0, p_chi_ex = 0.0, o_chi_ex = 0.0;
    double om_far_ex = 0.0, j_far_ex = 0.0, p_far_ex = 0.0, o_far_ex = 0.0;

    for (int i = 0; i < N; i++) {
        double xi = (double)i * dx;
        double ddx0 = xi - x0;
        if (ddx0 > M_PI) ddx0 -= 2.0 * M_PI;
        if (ddx0 < -M_PI) ddx0 += 2.0 * M_PI;
        for (int j = 0; j < N; j++) {
            double yj = (double)j * dx;
            double ddy0 = yj - y0;
            if (ddy0 > M_PI) ddy0 -= 2.0 * M_PI;
            if (ddy0 < -M_PI) ddy0 += 2.0 * M_PI;
            double chi, gx, gy;
            _chi_annulus(ddx0, ddy0, rin, rout, &chi, &gx, &gy);
            (void)gx; (void)gy;
            double alpha = 1.0 - chi;

            int idx = i * N + j;
            double om_lo = h_om_mid[idx] - fabs(h_om_rad[idx]);
            double om_hi = h_om_mid[idx] + fabs(h_om_rad[idx]);
            double tx_lo = h_tx_mid[idx] - fabs(h_tx_rad[idx]);
            double tx_hi = h_tx_mid[idx] + fabs(h_tx_rad[idx]);
            double ty_lo = h_ty_mid[idx] - fabs(h_ty_rad[idx]);
            double ty_hi = h_ty_mid[idx] + fabs(h_ty_rad[idx]);
            double ux_lo = h_ux_mid[idx] - fabs(h_ux_rad[idx]);
            double ux_hi = h_ux_mid[idx] + fabs(h_ux_rad[idx]);
            double vx_lo = h_vx_mid[idx] - fabs(h_vx_rad[idx]);
            double vx_hi = h_vx_mid[idx] + fabs(h_vx_rad[idx]);

            double sq_lo, sq_hi;
            double prod_lo, prod_hi;

            if (chi > 0.0) {
                double om_ex = h_om_mid[idx];
                double tx_ex = h_tx_mid[idx];
                double ty_ex = h_ty_mid[idx];
                double ux_ex = h_ux_mid[idx];
                double vx_ex = h_vx_mid[idx];
                om_chi_ex += chi * om_ex * om_ex;
                j_chi_ex += chi * om_ex * tx_ex;
                p_chi_ex += chi * tx_ex * tx_ex;
                o_chi_ex += chi * om_ex * (ux_ex * tx_ex + vx_ex * ty_ex);

                _iv_sq(om_lo, om_hi, &sq_lo, &sq_hi);
                om_chi_lo += chi * sq_lo;
                om_chi_hi += chi * sq_hi;

                _iv_mul(om_lo, om_hi, tx_lo, tx_hi, &prod_lo, &prod_hi);
                j_chi_lo += chi * prod_lo;
                j_chi_hi += chi * prod_hi;

                _iv_sq(tx_lo, tx_hi, &sq_lo, &sq_hi);
                p_chi_lo += chi * sq_lo;
                p_chi_hi += chi * sq_hi;

                double t1_lo, t1_hi, t2_lo, t2_hi, inner_lo, inner_hi;
                _iv_mul(ux_lo, ux_hi, tx_lo, tx_hi, &t1_lo, &t1_hi);
                _iv_mul(vx_lo, vx_hi, ty_lo, ty_hi, &t2_lo, &t2_hi);
                inner_lo = t1_lo + t2_lo;
                inner_hi = t1_hi + t2_hi;
                _iv_mul(om_lo, om_hi, inner_lo, inner_hi, &prod_lo, &prod_hi);
                o_chi_hi += chi * prod_hi;
            }

            if (alpha > 0.0) {
                double om_ex = h_om_mid[idx];
                double tx_ex = h_tx_mid[idx];
                double ty_ex = h_ty_mid[idx];
                double ux_ex = h_ux_mid[idx];
                double vx_ex = h_vx_mid[idx];
                om_far_ex += alpha * om_ex * om_ex;
                j_far_ex += alpha * om_ex * tx_ex;
                p_far_ex += alpha * tx_ex * tx_ex;
                o_far_ex += alpha * om_ex * (ux_ex * tx_ex + vx_ex * ty_ex);

                _iv_sq(om_lo, om_hi, &sq_lo, &sq_hi);
                om_far_lo += alpha * sq_lo;
                om_far_hi += alpha * sq_hi;

                _iv_mul(om_lo, om_hi, tx_lo, tx_hi, &prod_lo, &prod_hi);
                j_far_lo += alpha * prod_lo;
                j_far_hi += alpha * prod_hi;

                _iv_sq(tx_lo, tx_hi, &sq_lo, &sq_hi);
                p_far_lo += alpha * sq_lo;
                p_far_hi += alpha * sq_hi;

                double t1_lo, t1_hi, t2_lo, t2_hi, inner_lo, inner_hi;
                _iv_mul(ux_lo, ux_hi, tx_lo, tx_hi, &t1_lo, &t1_hi);
                _iv_mul(vx_lo, vx_hi, ty_lo, ty_hi, &t2_lo, &t2_hi);
                inner_lo = t1_lo + t2_lo;
                inner_hi = t1_hi + t2_hi;
                _iv_mul(om_lo, om_hi, inner_lo, inner_hi, &prod_lo, &prod_hi);
                o_far_hi += alpha * prod_hi;
            }
        }
    }

    double cell_area = dx * dx;
    om_chi_lo *= cell_area; om_chi_hi *= cell_area;
    j_chi_lo *= cell_area; j_chi_hi *= cell_area;
    p_chi_lo *= cell_area; p_chi_hi *= cell_area;
    o_chi_hi *= cell_area;
    om_far_lo *= cell_area; om_far_hi *= cell_area;
    j_far_lo *= cell_area; j_far_hi *= cell_area;
    p_far_lo *= cell_area; p_far_hi *= cell_area;
    o_far_hi *= cell_area;
    om_chi_ex *= cell_area; j_chi_ex *= cell_area; p_chi_ex *= cell_area; o_chi_ex *= cell_area;
    om_far_ex *= cell_area; j_far_ex *= cell_area; p_far_ex *= cell_area; o_far_ex *= cell_area;

    double omega_glob_lo = om_chi_lo + om_far_lo;
    double omega_glob_hi = om_chi_hi + om_far_hi;
    double j_glob_lo = j_chi_lo + j_far_lo;
    double j_glob_hi = j_chi_hi + j_far_hi;
    double a_lo, a_hi;
    _iv_ratio_pos(j_glob_lo, j_glob_hi, omega_glob_lo, omega_glob_hi, &a_lo, &a_hi);
    if (!isfinite(a_lo) || !isfinite(a_hi)) return _f2b(-1e300);

    double jchi_abs_hi = fmax(fabs(j_chi_lo), fabs(j_chi_hi));
    double dstar_lo = -1e300;
    if (om_chi_lo > 0.0) {
        dstar_lo = p_chi_lo - (jchi_abs_hi * jchi_abs_hi) / om_chi_lo;
    }

    double dfar_lo = _phase3_quadratic_lower(p_far_lo, j_far_lo, j_far_hi, om_far_lo, a_lo, a_hi);

    double j_glob_abs_hi = fmax(fabs(j_glob_lo), fabs(j_glob_hi));
    double q_hi = 0.0;
    if (omega_glob_lo > 0.0) q_hi = (j_glob_abs_hi * j_glob_abs_hi) / omega_glob_lo;
    double net_lo = dstar_lo + dfar_lo - o_chi_hi - o_far_hi;
    double net1_lo = net_lo - q_hi;
    double omega_glob_ex = om_chi_ex + om_far_ex;
    double j_glob_ex = j_chi_ex + j_far_ex;
    double p_glob_ex = p_chi_ex + p_far_ex;
    double o_glob_ex = o_chi_ex + o_far_ex;
    double q_ex = 0.0;
    if (omega_glob_ex > 0.0) q_ex = (j_glob_ex * j_glob_ex) / omega_glob_ex;
    double net_ex = (p_glob_ex - q_ex) - o_glob_ex;
    double net1_ex = net_ex - q_ex;
    G.h_phase3_a_lo = a_lo;
    G.h_phase3_a_hi = a_hi;
    G.h_phase3_dstar_lo = dstar_lo;
    G.h_phase3_dfar_lo = dfar_lo;
    G.h_phase3_oloc_hi = o_chi_hi;
    G.h_phase3_ofar_hi = o_far_hi;
    G.h_phase3_net_lo = net_lo;
    G.h_phase3_q_hi = q_hi;
    G.h_phase3_net1_lo = net1_lo;
    G.h_phase3_omega_exact = omega_glob_ex;
    G.h_phase3_j_exact = j_glob_ex;
    G.h_phase3_p_exact = p_glob_ex;
    G.h_phase3_o_exact = o_glob_ex;
    G.h_phase3_q_exact = q_ex;
    G.h_phase3_net_exact = net_ex;
    G.h_phase3_net1_exact = net1_ex;
    return _f2b(net_lo);
}

extern "C" long long nuc_gpu_phase3_interval_probe_at(long long rin_bits, long long rout_bits,
                                                       long long tau_bits) {
    int n2 = G.n2, N = G.N;
    double dx = G.dx;
    double rin = _b2f(rin_bits);
    double rout = _b2f(rout_bits);
    double tau = _b2f(tau_bits);
    if (!(rin >= 0.0) || !(rout > rin)) return _f2b(-1e300);
    if (tau < 0.0 || tau > G.last_h + 1e-15) return _f2b(-1e300);

    // Evaluate omega, theta, u, v at substep tau using the current step polynomial.
    gpu_eval_signed_series(G.d_om, G.d_dom, G.d_om[G.p + 1], tau, G.d_scratch1, G.d_scratch2);
    gpu_eval_signed_series(G.d_th, G.d_dth, G.d_th[G.p + 1], tau, G.d_comp1, G.d_comp2);

    // theta_x, theta_y from evaluated theta slabs
    gpu_ddx(G.d_comp1, G.d_om_mid);
    gpu_ddx(G.d_comp2, G.d_delta_om);
    gpu_ddy(G.d_comp1, G.d_th_mid);
    gpu_ddy(G.d_comp2, G.d_delta_th);

    static double *h_om_mid = NULL;
    static double *h_om_rad = NULL;
    static double *h_tx_mid = NULL;
    static double *h_tx_rad = NULL;
    static double *h_ty_mid = NULL;
    static double *h_ty_rad = NULL;
    static double *h_ux_mid = NULL;
    static double *h_ux_rad = NULL;
    static double *h_vx_mid = NULL;
    static double *h_vx_rad = NULL;
    static double *h_omdot_mid = NULL;
    static double *h_txtdot_mid = NULL;
    if (!h_om_mid) h_om_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_om_rad) h_om_rad = (double *)malloc(n2 * sizeof(double));
    if (!h_tx_mid) h_tx_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_tx_rad) h_tx_rad = (double *)malloc(n2 * sizeof(double));
    if (!h_ty_mid) h_ty_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_ty_rad) h_ty_rad = (double *)malloc(n2 * sizeof(double));
    if (!h_ux_mid) h_ux_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_ux_rad) h_ux_rad = (double *)malloc(n2 * sizeof(double));
    if (!h_vx_mid) h_vx_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_vx_rad) h_vx_rad = (double *)malloc(n2 * sizeof(double));
    if (!h_omdot_mid) h_omdot_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_txtdot_mid) h_txtdot_mid = (double *)malloc(n2 * sizeof(double));
    if (!h_om_mid || !h_om_rad || !h_tx_mid || !h_tx_rad || !h_ty_mid || !h_ty_rad ||
        !h_ux_mid || !h_ux_rad || !h_vx_mid || !h_vx_rad ||
        !h_omdot_mid || !h_txtdot_mid) return _f2b(-1e300);

    cudaMemcpy(h_om_mid, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_om_rad, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_tx_mid, G.d_om_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_tx_rad, G.d_delta_om, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_ty_mid, G.d_th_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_ty_rad, G.d_delta_th, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // u_x and v_x at tau
    gpu_eval_signed_series(G.d_uf, G.d_duf, G.d_uf[G.p + 1], tau, G.d_comp1, G.d_comp2);
    gpu_ddx(G.d_comp1, G.d_om_mid);
    gpu_ddx(G.d_comp2, G.d_delta_om);
    cudaMemcpy(h_ux_mid, G.d_om_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_ux_rad, G.d_delta_om, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    gpu_eval_signed_series(G.d_vf, G.d_dvf, G.d_vf[G.p + 1], tau, G.d_comp1, G.d_comp2);
    gpu_ddx(G.d_comp1, G.d_om_mid);
    gpu_ddx(G.d_comp2, G.d_delta_om);
    cudaMemcpy(h_vx_mid, G.d_om_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_vx_rad, G.d_delta_om, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // Exact polynomial time derivatives: omega_t and theta_xt at tau.
    gpu_eval_derivative_series_exact(G.d_om, tau, G.d_om_mid);
    cudaMemcpy(h_omdot_mid, G.d_om_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    gpu_eval_derivative_series_exact(G.d_thx, tau, G.d_th_mid);
    cudaMemcpy(h_txtdot_mid, G.d_th_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    int pi = G.h_peak_i, pj = G.h_peak_j;
    if (pi < 0 || pi >= N) pi = 0;
    if (pj < 0 || pj >= N) pj = 0;
    double x0 = (double)pi * dx;
    double y0 = (double)pj * dx;

    double om_chi_lo = 0.0, om_chi_hi = 0.0;
    double j_chi_lo = 0.0, j_chi_hi = 0.0;
    double p_chi_lo = 0.0, p_chi_hi = 0.0;
    double o_chi_hi = 0.0;
    double om_far_lo = 0.0, om_far_hi = 0.0;
    double j_far_lo = 0.0, j_far_hi = 0.0;
    double p_far_lo = 0.0, p_far_hi = 0.0;
    double o_far_hi = 0.0;
    double om_chi_ex = 0.0, j_chi_ex = 0.0, p_chi_ex = 0.0, o_chi_ex = 0.0;
    double om_far_ex = 0.0, j_far_ex = 0.0, p_far_ex = 0.0, o_far_ex = 0.0;
    double jdot_chi_ex = 0.0, jdot_far_ex = 0.0;

    for (int i = 0; i < N; i++) {
        double xi = (double)i * dx;
        double ddx0 = xi - x0;
        if (ddx0 > M_PI) ddx0 -= 2.0 * M_PI;
        if (ddx0 < -M_PI) ddx0 += 2.0 * M_PI;
        for (int j = 0; j < N; j++) {
            double yj = (double)j * dx;
            double ddy0 = yj - y0;
            if (ddy0 > M_PI) ddy0 -= 2.0 * M_PI;
            if (ddy0 < -M_PI) ddy0 += 2.0 * M_PI;
            double chi, gx, gy;
            _chi_annulus(ddx0, ddy0, rin, rout, &chi, &gx, &gy);
            (void)gx; (void)gy;
            double alpha = 1.0 - chi;

            int idx = i * N + j;
            double om_lo = h_om_mid[idx] - fabs(h_om_rad[idx]);
            double om_hi = h_om_mid[idx] + fabs(h_om_rad[idx]);
            double tx_lo = h_tx_mid[idx] - fabs(h_tx_rad[idx]);
            double tx_hi = h_tx_mid[idx] + fabs(h_tx_rad[idx]);
            double ty_lo = h_ty_mid[idx] - fabs(h_ty_rad[idx]);
            double ty_hi = h_ty_mid[idx] + fabs(h_ty_rad[idx]);
            double ux_lo = h_ux_mid[idx] - fabs(h_ux_rad[idx]);
            double ux_hi = h_ux_mid[idx] + fabs(h_ux_rad[idx]);
            double vx_lo = h_vx_mid[idx] - fabs(h_vx_rad[idx]);
            double vx_hi = h_vx_mid[idx] + fabs(h_vx_rad[idx]);

            double sq_lo, sq_hi;
            double prod_lo, prod_hi;

            if (chi > 0.0) {
                double om_ex = h_om_mid[idx];
                double tx_ex = h_tx_mid[idx];
                double ty_ex = h_ty_mid[idx];
                double ux_ex = h_ux_mid[idx];
                double vx_ex = h_vx_mid[idx];
                double omdot_ex = h_omdot_mid[idx];
                double txtdot_ex = h_txtdot_mid[idx];
                om_chi_ex += chi * om_ex * om_ex;
                j_chi_ex += chi * om_ex * tx_ex;
                p_chi_ex += chi * tx_ex * tx_ex;
                o_chi_ex += chi * om_ex * (ux_ex * tx_ex + vx_ex * ty_ex);
                jdot_chi_ex += chi * (omdot_ex * tx_ex + om_ex * txtdot_ex);

                _iv_sq(om_lo, om_hi, &sq_lo, &sq_hi);
                om_chi_lo += chi * sq_lo;
                om_chi_hi += chi * sq_hi;

                _iv_mul(om_lo, om_hi, tx_lo, tx_hi, &prod_lo, &prod_hi);
                j_chi_lo += chi * prod_lo;
                j_chi_hi += chi * prod_hi;

                _iv_sq(tx_lo, tx_hi, &sq_lo, &sq_hi);
                p_chi_lo += chi * sq_lo;
                p_chi_hi += chi * sq_hi;

                double t1_lo, t1_hi, t2_lo, t2_hi, inner_lo, inner_hi;
                _iv_mul(ux_lo, ux_hi, tx_lo, tx_hi, &t1_lo, &t1_hi);
                _iv_mul(vx_lo, vx_hi, ty_lo, ty_hi, &t2_lo, &t2_hi);
                inner_lo = t1_lo + t2_lo;
                inner_hi = t1_hi + t2_hi;
                _iv_mul(om_lo, om_hi, inner_lo, inner_hi, &prod_lo, &prod_hi);
                o_chi_hi += chi * prod_hi;
            }

            if (alpha > 0.0) {
                double om_ex = h_om_mid[idx];
                double tx_ex = h_tx_mid[idx];
                double ty_ex = h_ty_mid[idx];
                double ux_ex = h_ux_mid[idx];
                double vx_ex = h_vx_mid[idx];
                double omdot_ex = h_omdot_mid[idx];
                double txtdot_ex = h_txtdot_mid[idx];
                om_far_ex += alpha * om_ex * om_ex;
                j_far_ex += alpha * om_ex * tx_ex;
                p_far_ex += alpha * tx_ex * tx_ex;
                o_far_ex += alpha * om_ex * (ux_ex * tx_ex + vx_ex * ty_ex);
                jdot_far_ex += alpha * (omdot_ex * tx_ex + om_ex * txtdot_ex);

                _iv_sq(om_lo, om_hi, &sq_lo, &sq_hi);
                om_far_lo += alpha * sq_lo;
                om_far_hi += alpha * sq_hi;

                _iv_mul(om_lo, om_hi, tx_lo, tx_hi, &prod_lo, &prod_hi);
                j_far_lo += alpha * prod_lo;
                j_far_hi += alpha * prod_hi;

                _iv_sq(tx_lo, tx_hi, &sq_lo, &sq_hi);
                p_far_lo += alpha * sq_lo;
                p_far_hi += alpha * sq_hi;

                double t1_lo, t1_hi, t2_lo, t2_hi, inner_lo, inner_hi;
                _iv_mul(ux_lo, ux_hi, tx_lo, tx_hi, &t1_lo, &t1_hi);
                _iv_mul(vx_lo, vx_hi, ty_lo, ty_hi, &t2_lo, &t2_hi);
                inner_lo = t1_lo + t2_lo;
                inner_hi = t1_hi + t2_hi;
                _iv_mul(om_lo, om_hi, inner_lo, inner_hi, &prod_lo, &prod_hi);
                o_far_hi += alpha * prod_hi;
            }
        }
    }

    double cell_area = dx * dx;
    om_chi_lo *= cell_area; om_chi_hi *= cell_area;
    j_chi_lo *= cell_area; j_chi_hi *= cell_area;
    p_chi_lo *= cell_area; p_chi_hi *= cell_area;
    o_chi_hi *= cell_area;
    om_far_lo *= cell_area; om_far_hi *= cell_area;
    j_far_lo *= cell_area; j_far_hi *= cell_area;
    p_far_lo *= cell_area; p_far_hi *= cell_area;
    o_far_hi *= cell_area;
    om_chi_ex *= cell_area; j_chi_ex *= cell_area; p_chi_ex *= cell_area; o_chi_ex *= cell_area;
    om_far_ex *= cell_area; j_far_ex *= cell_area; p_far_ex *= cell_area; o_far_ex *= cell_area;
    jdot_chi_ex *= cell_area; jdot_far_ex *= cell_area;

    double omega_glob_lo = om_chi_lo + om_far_lo;
    double omega_glob_hi = om_chi_hi + om_far_hi;
    double j_glob_lo = j_chi_lo + j_far_lo;
    double j_glob_hi = j_chi_hi + j_far_hi;
    double a_lo, a_hi;
    _iv_ratio_pos(j_glob_lo, j_glob_hi, omega_glob_lo, omega_glob_hi, &a_lo, &a_hi);
    if (!isfinite(a_lo) || !isfinite(a_hi)) return _f2b(-1e300);
    G.h_phase3_a_lo = a_lo;
    G.h_phase3_a_hi = a_hi;

    double jchi_abs_hi = fmax(fabs(j_chi_lo), fabs(j_chi_hi));
    double dstar_lo = -1e300;
    if (om_chi_lo > 0.0) {
        dstar_lo = p_chi_lo - (jchi_abs_hi * jchi_abs_hi) / om_chi_lo;
    }

    double dfar_lo = _phase3_quadratic_lower(p_far_lo, j_far_lo, j_far_hi, om_far_lo, a_lo, a_hi);

    double j_glob_abs_hi = fmax(fabs(j_glob_lo), fabs(j_glob_hi));
    double q_hi = 0.0;
    if (omega_glob_lo > 0.0) q_hi = (j_glob_abs_hi * j_glob_abs_hi) / omega_glob_lo;
    double net_lo = dstar_lo + dfar_lo - o_chi_hi - o_far_hi;
    double net1_lo = net_lo - q_hi;
    double omega_glob_ex = om_chi_ex + om_far_ex;
    double j_glob_ex = j_chi_ex + j_far_ex;
    double p_glob_ex = p_chi_ex + p_far_ex;
    double o_glob_ex = o_chi_ex + o_far_ex;
    double jdot_glob_ex = jdot_chi_ex + jdot_far_ex;
    double q_ex = 0.0;
    if (omega_glob_ex > 0.0) q_ex = (j_glob_ex * j_glob_ex) / omega_glob_ex;
    double net_ex = (p_glob_ex - q_ex) - o_glob_ex;
    double net1_ex = net_ex - q_ex;

    // Restore endpoint state before returning.
    gpu_eval_signed_series(G.d_om, G.d_dom, G.d_om[G.p + 1], G.last_h, G.d_om_mid, G.d_delta_om);
    gpu_eval_signed_series(G.d_th, G.d_dth, G.d_th[G.p + 1], G.last_h, G.d_th_mid, G.d_delta_th);
    G.h_phase3_q_hi = q_hi;
    G.h_phase3_net1_lo = net1_lo;
    G.h_phase3_omega_exact = omega_glob_ex;
    G.h_phase3_j_exact = j_glob_ex;
    G.h_phase3_p_exact = p_glob_ex;
    G.h_phase3_o_exact = o_glob_ex;
    G.h_phase3_jdot_exact = jdot_glob_ex;
    G.h_phase3_q_exact = q_ex;
    G.h_phase3_net_exact = net_ex;
    G.h_phase3_net1_exact = net1_ex;

    return _f2b(net_lo);
}

// ================================================================
// De-aliased O integral: O = integral(omega * (u_x*theta_x + v_x*theta_y))
// Uses gpu_dealiased_mul to compute P_N(u_x*theta_x) and P_N(v_x*theta_y),
// then sums omega * inner on the N grid (exact quadratic inner product).
// This avoids the cubic aliasing that corrupts the raw N-grid triple product.
// Also computes de-aliased P = integral(theta_x^2) for validation.
// ================================================================
extern "C" long long nuc_gpu_compute_dealiased_po(long long tau_bits) {
    double tau = _b2f(tau_bits);
    int n2 = G.n2, N = G.N;
    double dx = G.dx;
    double cell_area = dx * dx;
    if (tau < 0.0 || tau > G.last_h + 1e-15) return _f2b(-1e300);

    static double *h_om = NULL, *h_t1 = NULL, *h_t2 = NULL;
    if (!h_om) h_om = (double *)malloc(n2 * sizeof(double));
    if (!h_t1) h_t1 = (double *)malloc(n2 * sizeof(double));
    if (!h_t2) h_t2 = (double *)malloc(n2 * sizeof(double));
    if (!h_om || !h_t1 || !h_t2) return _f2b(-1e300);

    // Evaluate omega at tau → d_scratch1 (midpoint)
    gpu_eval_signed_series(G.d_om, G.d_dom, G.d_om[G.p + 1], tau, G.d_scratch1, G.d_scratch2);
    cudaMemcpy(h_om, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // Evaluate theta at tau → d_comp1 (midpoint)
    gpu_eval_signed_series(G.d_th, G.d_dth, G.d_th[G.p + 1], tau, G.d_comp1, G.d_comp2);
    // theta_x → d_comp2, theta_y → d_delta_om (temp)
    gpu_ddx(G.d_comp1, G.d_comp2);
    gpu_ddy(G.d_comp1, G.d_delta_om);

    // --- De-aliased P = integral(theta_x^2) ---
    // P_N(theta_x^2) → d_delta_th
    gpu_dealiased_mul(G.d_comp2, G.d_comp2, G.d_delta_th);
    cudaMemcpy(h_t1, G.d_delta_th, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    double p_dealiased = 0.0;
    for (int i = 0; i < n2; i++) p_dealiased += h_t1[i];
    p_dealiased *= cell_area;

    // --- De-aliased O = integral(omega * (u_x*theta_x + v_x*theta_y)) ---
    // Term 1: P_N(u_x * theta_x)
    gpu_eval_signed_series(G.d_uf, G.d_duf, G.d_uf[G.p + 1], tau, G.d_comp1, G.d_scratch2);
    gpu_ddx(G.d_comp1, G.d_th_mid);  // u_x → d_th_mid
    gpu_dealiased_mul(G.d_th_mid, G.d_comp2, G.d_delta_th);  // P_N(u_x * theta_x) → d_delta_th
    cudaMemcpy(h_t1, G.d_delta_th, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // Term 2: P_N(v_x * theta_y)
    gpu_eval_signed_series(G.d_vf, G.d_dvf, G.d_vf[G.p + 1], tau, G.d_comp1, G.d_scratch2);
    gpu_ddx(G.d_comp1, G.d_th_mid);  // v_x → d_th_mid
    gpu_dealiased_mul(G.d_th_mid, G.d_delta_om, G.d_comp2);  // P_N(v_x * theta_y) → d_comp2
    cudaMemcpy(h_t2, G.d_comp2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // Sum: O = integral(omega * (term1 + term2))
    double o_dealiased = 0.0;
    for (int i = 0; i < n2; i++) {
        o_dealiased += h_om[i] * (h_t1[i] + h_t2[i]);
    }
    o_dealiased *= cell_area;

    // Store results
    G.h_phase3_p_exact = p_dealiased;    // overwrite with de-aliased P (should match)
    G.h_phase3_o_exact = o_dealiased;    // overwrite with de-aliased O (corrected!)

    // Restore endpoint state
    gpu_eval_signed_series(G.d_om, G.d_dom, G.d_om[G.p + 1], G.last_h, G.d_om_mid, G.d_delta_om);
    gpu_eval_signed_series(G.d_th, G.d_dth, G.d_th[G.p + 1], G.last_h, G.d_th_mid, G.d_delta_th);

    return _f2b(o_dealiased);
}

// ================================================================
// Interval Jdot: rigorous bounds on J'(tau) = int(omega_t * theta_x + omega * theta_xt)
// Uses gpu_eval_derivative_series_signed for omega_t and theta_xt error bounds.
// Returns Jdot_lo as bits. Stores Jdot_lo, Jdot_hi, Jdot_mid in G state.
// ================================================================
extern "C" long long nuc_gpu_compute_jdot_interval(long long tau_bits) {
    double tau = _b2f(tau_bits);
    int n2 = G.n2;
    double dx = G.dx;
    double cell_area = dx * dx;
    if (tau < 0.0 || tau > G.last_h + 1e-15) return _f2b(-1e300);

    static double *h_om_mid = NULL, *h_om_rad = NULL;
    static double *h_tx_mid = NULL, *h_tx_rad = NULL;
    static double *h_omt_mid = NULL, *h_omt_rad = NULL;
    static double *h_txt_mid = NULL, *h_txt_rad = NULL;
    if (!h_om_mid) {
        h_om_mid = (double *)malloc(n2 * sizeof(double));
        h_om_rad = (double *)malloc(n2 * sizeof(double));
        h_tx_mid = (double *)malloc(n2 * sizeof(double));
        h_tx_rad = (double *)malloc(n2 * sizeof(double));
        h_omt_mid = (double *)malloc(n2 * sizeof(double));
        h_omt_rad = (double *)malloc(n2 * sizeof(double));
        h_txt_mid = (double *)malloc(n2 * sizeof(double));
        h_txt_rad = (double *)malloc(n2 * sizeof(double));
    }
    if (!h_om_mid || !h_om_rad || !h_tx_mid || !h_tx_rad ||
        !h_omt_mid || !h_omt_rad || !h_txt_mid || !h_txt_rad) return _f2b(-1e300);

    // 1. Evaluate omega at tau with error bounds
    gpu_eval_signed_series(G.d_om, G.d_dom, G.d_om[G.p + 1], tau, G.d_scratch1, G.d_scratch2);
    cudaMemcpy(h_om_mid, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_om_rad, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // 2. Evaluate theta at tau, then theta_x with error via ddx
    gpu_eval_signed_series(G.d_th, G.d_dth, G.d_th[G.p + 1], tau, G.d_comp1, G.d_comp2);
    gpu_ddx(G.d_comp1, G.d_scratch1);  // theta_x midpoint
    gpu_ddx(G.d_comp2, G.d_scratch2);  // theta_x delta (ddx of delta = delta of ddx)
    cudaMemcpy(h_tx_mid, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_tx_rad, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // 3. Evaluate omega_t at tau with error bounds (NEW signed derivative)
    gpu_eval_derivative_series_signed(G.d_om, G.d_dom, G.d_om[G.p + 1], tau,
                                      G.d_comp1, G.d_comp2);
    cudaMemcpy(h_omt_mid, G.d_comp1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_omt_rad, G.d_comp2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // 4. Evaluate (theta_x)_t at tau with error bounds
    gpu_eval_derivative_series_signed(G.d_thx, G.d_dthx, G.d_thx[G.p + 1], tau,
                                      G.d_scratch1, G.d_scratch2);
    cudaMemcpy(h_txt_mid, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_txt_rad, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // 5. CPU interval arithmetic: Jdot = sum(omega_t * theta_x + omega * theta_xt)
    double jdot_mid = 0.0, jdot_lo = 0.0, jdot_hi = 0.0;
    for (int i = 0; i < n2; i++) {
        double om_m = h_om_mid[i], om_r = fabs(h_om_rad[i]);
        double tx_m = h_tx_mid[i], tx_r = fabs(h_tx_rad[i]);
        double omt_m = h_omt_mid[i], omt_r = fabs(h_omt_rad[i]);
        double txt_m = h_txt_mid[i], txt_r = fabs(h_txt_rad[i]);

        // Term 1: omega_t * theta_x
        double omt_lo = omt_m - omt_r, omt_hi = omt_m + omt_r;
        double tx_lo = tx_m - tx_r, tx_hi = tx_m + tx_r;
        double p1 = omt_lo * tx_lo, p2 = omt_lo * tx_hi;
        double p3 = omt_hi * tx_lo, p4 = omt_hi * tx_hi;
        double t1_lo = fmin(fmin(p1, p2), fmin(p3, p4));
        double t1_hi = fmax(fmax(p1, p2), fmax(p3, p4));

        // Term 2: omega * theta_xt
        double om_lo = om_m - om_r, om_hi = om_m + om_r;
        double txt_lo = txt_m - txt_r, txt_hi = txt_m + txt_r;
        p1 = om_lo * txt_lo; p2 = om_lo * txt_hi;
        p3 = om_hi * txt_lo; p4 = om_hi * txt_hi;
        double t2_lo = fmin(fmin(p1, p2), fmin(p3, p4));
        double t2_hi = fmax(fmax(p1, p2), fmax(p3, p4));

        jdot_mid += omt_m * tx_m + om_m * txt_m;
        jdot_lo += t1_lo + t2_lo;
        jdot_hi += t1_hi + t2_hi;
    }
    jdot_mid *= cell_area;
    jdot_lo *= cell_area;
    jdot_hi *= cell_area;

    G.h_phase3_jdot_exact = jdot_mid;
    G.h_phase3_p_exact = jdot_lo;   // reuse slot for Jdot_lo
    G.h_phase3_o_exact = jdot_hi;   // reuse slot for Jdot_hi

    // Restore endpoint state
    gpu_eval_signed_series(G.d_om, G.d_dom, G.d_om[G.p + 1], G.last_h, G.d_om_mid, G.d_delta_om);
    gpu_eval_signed_series(G.d_th, G.d_dth, G.d_th[G.p + 1], G.last_h, G.d_th_mid, G.d_delta_th);

    return _f2b(jdot_lo);
}

extern "C" long long nuc_gpu_phase3_interval_probe_window(long long rin_bits, long long rout_bits,
                                                          long long tau0_bits, long long tau1_bits) {
    int n2 = G.n2, N = G.N, p = G.p;
    double dx = G.dx;
    double rin = _b2f(rin_bits);
    double rout = _b2f(rout_bits);
    double tau0 = _b2f(tau0_bits);
    double tau1 = _b2f(tau1_bits);
    if (!(rin >= 0.0) || !(rout > rin)) return _f2b(-1e300);
    if (tau0 < 0.0 || tau1 < tau0 || tau1 > G.last_h + 1e-15) return _f2b(-1e300);

    static double *h_om_lo = NULL, *h_om_hi = NULL;
    static double *h_tx_lo = NULL, *h_tx_hi = NULL;
    static double *h_ty_lo = NULL, *h_ty_hi = NULL;
    static double *h_ux_lo = NULL, *h_ux_hi = NULL;
    static double *h_vx_lo = NULL, *h_vx_hi = NULL;
    if (!h_om_lo) h_om_lo = (double *)malloc(n2 * sizeof(double));
    if (!h_om_hi) h_om_hi = (double *)malloc(n2 * sizeof(double));
    if (!h_tx_lo) h_tx_lo = (double *)malloc(n2 * sizeof(double));
    if (!h_tx_hi) h_tx_hi = (double *)malloc(n2 * sizeof(double));
    if (!h_ty_lo) h_ty_lo = (double *)malloc(n2 * sizeof(double));
    if (!h_ty_hi) h_ty_hi = (double *)malloc(n2 * sizeof(double));
    if (!h_ux_lo) h_ux_lo = (double *)malloc(n2 * sizeof(double));
    if (!h_ux_hi) h_ux_hi = (double *)malloc(n2 * sizeof(double));
    if (!h_vx_lo) h_vx_lo = (double *)malloc(n2 * sizeof(double));
    if (!h_vx_hi) h_vx_hi = (double *)malloc(n2 * sizeof(double));
    if (!h_om_lo || !h_om_hi || !h_tx_lo || !h_tx_hi || !h_ty_lo || !h_ty_hi ||
        !h_ux_lo || !h_ux_hi || !h_vx_lo || !h_vx_hi) return _f2b(-1e300);

    // omega interval over tau window
    gpu_eval_signed_series_interval(G.d_om, G.d_dom, G.d_om[p + 1], tau0, tau1, G.d_comp1, G.d_comp2);
    cudaMemcpy(h_om_lo, G.d_comp1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_om_hi, G.d_comp2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // theta_x interval over tau window
    gpu_ddx(G.d_th[p + 1], G.d_scratch1);
    gpu_eval_signed_series_interval(G.d_thx, G.d_dthx, G.d_scratch1, tau0, tau1, G.d_comp1, G.d_comp2);
    cudaMemcpy(h_tx_lo, G.d_comp1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_tx_hi, G.d_comp2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // theta_y interval over tau window
    gpu_ddy(G.d_th[p + 1], G.d_scratch1);
    gpu_eval_signed_series_interval(G.d_thy, G.d_dthy, G.d_scratch1, tau0, tau1, G.d_comp1, G.d_comp2);
    cudaMemcpy(h_ty_lo, G.d_comp1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_ty_hi, G.d_comp2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // u_x interval over tau window
    for (int k = 0; k <= p; k++) {
        gpu_ddx(G.d_uf[k], G.d_omx[k]);
        gpu_ddx(G.d_duf[k], G.d_domx[k]);
    }
    gpu_ddx(G.d_uf[p + 1], G.d_scratch1);
    gpu_eval_signed_series_interval(G.d_omx, G.d_domx, G.d_scratch1, tau0, tau1, G.d_comp1, G.d_comp2);
    cudaMemcpy(h_ux_lo, G.d_comp1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_ux_hi, G.d_comp2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    // v_x interval over tau window
    for (int k = 0; k <= p; k++) {
        gpu_ddx(G.d_vf[k], G.d_omy[k]);
        gpu_ddx(G.d_dvf[k], G.d_domy[k]);
    }
    gpu_ddx(G.d_vf[p + 1], G.d_scratch1);
    gpu_eval_signed_series_interval(G.d_omy, G.d_domy, G.d_scratch1, tau0, tau1, G.d_comp1, G.d_comp2);
    cudaMemcpy(h_vx_lo, G.d_comp1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_vx_hi, G.d_comp2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    int pi = G.h_peak_i, pj = G.h_peak_j;
    if (pi < 0 || pi >= N) pi = 0;
    if (pj < 0 || pj >= N) pj = 0;
    double x0 = (double)pi * dx;
    double y0 = (double)pj * dx;

    double om_chi_lo = 0.0, om_chi_hi = 0.0;
    double j_chi_lo = 0.0, j_chi_hi = 0.0;
    double p_chi_lo = 0.0, p_chi_hi = 0.0;
    double o_chi_hi = 0.0;
    double om_far_lo = 0.0, om_far_hi = 0.0;
    double j_far_lo = 0.0, j_far_hi = 0.0;
    double p_far_lo = 0.0, p_far_hi = 0.0;
    double o_far_hi = 0.0;

    for (int i = 0; i < N; i++) {
        double xi = (double)i * dx;
        double ddx0 = xi - x0;
        if (ddx0 > M_PI) ddx0 -= 2.0 * M_PI;
        if (ddx0 < -M_PI) ddx0 += 2.0 * M_PI;
        for (int j = 0; j < N; j++) {
            double yj = (double)j * dx;
            double ddy0 = yj - y0;
            if (ddy0 > M_PI) ddy0 -= 2.0 * M_PI;
            if (ddy0 < -M_PI) ddy0 += 2.0 * M_PI;
            double chi, gx, gy;
            _chi_annulus(ddx0, ddy0, rin, rout, &chi, &gx, &gy);
            (void)gx; (void)gy;
            double alpha = 1.0 - chi;

            int idx = i * N + j;
            double om_lo = h_om_lo[idx];
            double om_hi = h_om_hi[idx];
            double tx_lo = h_tx_lo[idx];
            double tx_hi = h_tx_hi[idx];
            double ty_lo = h_ty_lo[idx];
            double ty_hi = h_ty_hi[idx];
            double ux_lo = h_ux_lo[idx];
            double ux_hi = h_ux_hi[idx];
            double vx_lo = h_vx_lo[idx];
            double vx_hi = h_vx_hi[idx];

            double sq_lo, sq_hi;
            double prod_lo, prod_hi;

            if (chi > 0.0) {
                _iv_sq(om_lo, om_hi, &sq_lo, &sq_hi);
                om_chi_lo += chi * sq_lo;
                om_chi_hi += chi * sq_hi;

                _iv_mul(om_lo, om_hi, tx_lo, tx_hi, &prod_lo, &prod_hi);
                j_chi_lo += chi * prod_lo;
                j_chi_hi += chi * prod_hi;

                _iv_sq(tx_lo, tx_hi, &sq_lo, &sq_hi);
                p_chi_lo += chi * sq_lo;
                p_chi_hi += chi * sq_hi;

                double t1_lo, t1_hi, t2_lo, t2_hi, inner_lo, inner_hi;
                _iv_mul(ux_lo, ux_hi, tx_lo, tx_hi, &t1_lo, &t1_hi);
                _iv_mul(vx_lo, vx_hi, ty_lo, ty_hi, &t2_lo, &t2_hi);
                inner_lo = t1_lo + t2_lo;
                inner_hi = t1_hi + t2_hi;
                _iv_mul(om_lo, om_hi, inner_lo, inner_hi, &prod_lo, &prod_hi);
                o_chi_hi += chi * prod_hi;
            }

            if (alpha > 0.0) {
                _iv_sq(om_lo, om_hi, &sq_lo, &sq_hi);
                om_far_lo += alpha * sq_lo;
                om_far_hi += alpha * sq_hi;

                _iv_mul(om_lo, om_hi, tx_lo, tx_hi, &prod_lo, &prod_hi);
                j_far_lo += alpha * prod_lo;
                j_far_hi += alpha * prod_hi;

                _iv_sq(tx_lo, tx_hi, &sq_lo, &sq_hi);
                p_far_lo += alpha * sq_lo;
                p_far_hi += alpha * sq_hi;

                double t1_lo, t1_hi, t2_lo, t2_hi, inner_lo, inner_hi;
                _iv_mul(ux_lo, ux_hi, tx_lo, tx_hi, &t1_lo, &t1_hi);
                _iv_mul(vx_lo, vx_hi, ty_lo, ty_hi, &t2_lo, &t2_hi);
                inner_lo = t1_lo + t2_lo;
                inner_hi = t1_hi + t2_hi;
                _iv_mul(om_lo, om_hi, inner_lo, inner_hi, &prod_lo, &prod_hi);
                o_far_hi += alpha * prod_hi;
            }
        }
    }

    double cell_area = dx * dx;
    om_chi_lo *= cell_area; om_chi_hi *= cell_area;
    j_chi_lo *= cell_area;  j_chi_hi *= cell_area;
    p_chi_lo *= cell_area;  p_chi_hi *= cell_area;
    o_chi_hi *= cell_area;
    om_far_lo *= cell_area; om_far_hi *= cell_area;
    j_far_lo *= cell_area;  j_far_hi *= cell_area;
    p_far_lo *= cell_area;  p_far_hi *= cell_area;
    o_far_hi *= cell_area;

    double omega_glob_lo = om_chi_lo + om_far_lo;
    double omega_glob_hi = om_chi_hi + om_far_hi;
    double j_glob_lo = j_chi_lo + j_far_lo;
    double j_glob_hi = j_chi_hi + j_far_hi;
    double a_lo, a_hi;
    _iv_ratio_pos(j_glob_lo, j_glob_hi, omega_glob_lo, omega_glob_hi, &a_lo, &a_hi);
    if (!isfinite(a_lo) || !isfinite(a_hi)) return _f2b(-1e300);
    G.h_phase3_a_lo = a_lo;
    G.h_phase3_a_hi = a_hi;

    double dstar_lo = 0.0;
    if (om_chi_lo > 0.0) {
        double q_hi = (fabs(j_chi_hi) > fabs(j_chi_lo) ? fabs(j_chi_hi) : fabs(j_chi_lo));
        q_hi = (q_hi * q_hi) / om_chi_lo;
        dstar_lo = p_chi_lo - q_hi;
        if (!isfinite(dstar_lo)) dstar_lo = -1e300;
    } else {
        dstar_lo = -1e300;
    }

    double dfar_lo = _phase3_quadratic_lower(p_far_lo, j_far_lo, j_far_hi, om_far_lo, a_lo, a_hi);

    double j_glob_abs_hi = fmax(fabs(j_glob_lo), fabs(j_glob_hi));
    double q_hi = 0.0;
    if (omega_glob_lo > 0.0) q_hi = (j_glob_abs_hi * j_glob_abs_hi) / omega_glob_lo;
    double net_lo = dstar_lo + dfar_lo - o_chi_hi - o_far_hi;
    double net1_lo = net_lo - q_hi;
    G.h_phase3_dstar_lo = dstar_lo;
    G.h_phase3_dfar_lo = dfar_lo;
    G.h_phase3_oloc_hi = o_chi_hi;
    G.h_phase3_ofar_hi = o_far_hi;
    G.h_phase3_net_lo = net_lo;
    G.h_phase3_q_hi = q_hi;
    G.h_phase3_net1_lo = net1_lo;
    G.h_phase3_netg_lo = net1_lo;
    return _f2b(net_lo);
}

extern "C" long long nuc_gpu_phase3_interval_probe_window_qcoeff(long long rin_bits, long long rout_bits,
                                                                 long long tau0_bits, long long tau1_bits,
                                                                 long long qcoeff_bits) {
    long long base = nuc_gpu_phase3_interval_probe_window(rin_bits, rout_bits, tau0_bits, tau1_bits);
    (void)base;
    double qcoeff = _b2f(qcoeff_bits);
    if (!isfinite(qcoeff)) {
        G.h_phase3_netg_lo = -1e300;
        return _f2b(-1e300);
    }
    double netg_lo = G.h_phase3_net_lo - qcoeff * G.h_phase3_q_hi;
    if (!isfinite(netg_lo)) netg_lo = -1e300;
    G.h_phase3_netg_lo = netg_lo;
    return _f2b(netg_lo);
}

// ================================================================
// ================================================================
// Spectral peak interpolation + BKM growth rate
//
// 1. Evaluate ω(x,y) at arbitrary (x,y) using Fourier series
// 2. Gradient ascent from grid peak to find sub-grid maximum
// 3. Evaluate dω/dt at the interpolated peak using ω₁ Fourier coeffs
// 4. Track max(dω/dt) in a neighborhood for robustness
// ================================================================

// Evaluate Fourier series at point (x,y): f(x,y) = Σ f̂_k · e^{i·k·(x,y)}
// h_fft must contain the N×N Fourier coefficients (already downloaded)
static double _eval_fourier(const cufftDoubleComplex *fft, int N, double x, double y) {
    double val = 0;
    for (int kxi = 0; kxi < N; kxi++) {
        int kx = (kxi <= N/2) ? kxi : kxi - N;
        double cx = cos((double)kx * x), sx = sin((double)kx * x);
        for (int kyi = 0; kyi < N; kyi++) {
            int ky = (kyi <= N/2) ? kyi : kyi - N;
            double cy = cos((double)ky * y), sy = sin((double)ky * y);
            // e^{i(kx·x + ky·y)} = (cx + i·sx)(cy + i·sy)
            //                     = (cx·cy - sx·sy) + i(cx·sy + sx·cy)
            double re = cx*cy - sx*sy;
            double im = cx*sy + sx*cy;
            int idx = kxi * N + kyi;
            val += fft[idx].x * re - fft[idx].y * im;
        }
    }
    return val;
}

// Evaluate gradient: ∂f/∂x, ∂f/∂y at (x,y)
static void _eval_grad(const cufftDoubleComplex *fft, int N, double x, double y,
                        double *dfdx, double *dfdy) {
    *dfdx = 0; *dfdy = 0;
    for (int kxi = 0; kxi < N; kxi++) {
        int kx = (kxi <= N/2) ? kxi : kxi - N;
        double cx = cos((double)kx * x), sx = sin((double)kx * x);
        for (int kyi = 0; kyi < N; kyi++) {
            int ky = (kyi <= N/2) ? kyi : kyi - N;
            double cy = cos((double)ky * y), sy = sin((double)ky * y);
            double re = cx*cy - sx*sy;
            double im = cx*sy + sx*cy;
            int idx = kxi * N + kyi;
            double a = fft[idx].x, b = fft[idx].y;
            // f contribution: a·re - b·im
            // df/dx: multiply by i·kx → -kx·(a·im + b·re) ... wait
            // d/dx e^{ikx·x} = i·kx·e^{ikx·x}
            // So df/dx contribution = (a + ib)·(i·kx)·e^{i·k·(x,y)}
            //   = (a+ib)·(i·kx)·(re+i·im) = kx·(-a·im - b·re + i(a·re - b·im))
            // Real part of df/dx: kx·(-a·im - b·re)
            *dfdx += (double)kx * (-a*im - b*re);
            *dfdy += (double)ky * (-a*im - b*re);
        }
    }
}

extern "C" long long nuc_gpu_compute_bkm(void) {
    int N = G.N, n2 = G.n2;
    int B = gpu_blocks(n2, THREADS);

    // --- Step 1: FFT ω (midpoint) and ω₁ (Taylor k=1 coeff) ---
    // ω FFT is already in d_fft_a from the last fourier_tail_robust call
    // We need to FFT ω₁ separately
    static cufftDoubleComplex *h_fft_om = NULL;
    static cufftDoubleComplex *h_fft_om1 = NULL;
    if (!h_fft_om) h_fft_om = (cufftDoubleComplex *)malloc(n2 * sizeof(cufftDoubleComplex));
    if (!h_fft_om1) h_fft_om1 = (cufftDoubleComplex *)malloc(n2 * sizeof(cufftDoubleComplex));

    // FFT midpoint ω
    k_real_to_complex<<<B,THREADS>>>(G.d_om_mid, G.d_fft_a, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_a, G.d_fft_a, CUFFT_FORWARD);
    k_scale_complex<<<B,THREADS>>>(G.d_fft_a, 1.0/(double)n2, n2);
    cudaMemcpy(h_fft_om, G.d_fft_a, n2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);

    // FFT ω₁ = d_om[1]
    k_real_to_complex<<<B,THREADS>>>(G.d_om[1], G.d_fft_b, n2);
    cufftExecZ2Z(G.plan_N, G.d_fft_b, G.d_fft_b, CUFFT_FORWARD);
    k_scale_complex<<<B,THREADS>>>(G.d_fft_b, 1.0/(double)n2, n2);
    cudaMemcpy(h_fft_om1, G.d_fft_b, n2 * sizeof(cufftDoubleComplex), cudaMemcpyDeviceToHost);

    // --- Step 2: Gradient ascent from grid peak to sub-grid maximum ---
    double dx = G.dx;
    double x = (double)G.h_peak_i * dx;
    double y = (double)G.h_peak_j * dx;

    // 5 Newton-like steps with small step size
    for (int iter = 0; iter < 10; iter++) {
        double gx, gy;
        _eval_grad(h_fft_om, N, x, y, &gx, &gy);
        double gnorm = sqrt(gx*gx + gy*gy);
        if (gnorm < 1e-12) break;  // converged
        // Step size: half a grid cell, capped
        double step = dx * 0.3;
        if (step * gnorm > dx * 0.5) step = dx * 0.5 / gnorm;
        x += step * gx / gnorm;
        y += step * gy / gnorm;
        // Wrap to [0, 2π]
        while (x < 0) x += 2.0 * M_PI;
        while (x >= 2.0 * M_PI) x -= 2.0 * M_PI;
        while (y < 0) y += 2.0 * M_PI;
        while (y >= 2.0 * M_PI) y -= 2.0 * M_PI;
    }

    G.h_interp_x = x;
    G.h_interp_y = y;
    G.h_interp_omega = _eval_fourier(h_fft_om, N, x, y);
    G.h_interp_growth = _eval_fourier(h_fft_om1, N, x, y);

    // --- Step 3: Neighborhood max of dω/dt ---
    // Check ω₁ in a 11×11 grid around the peak
    int pi = G.h_peak_i, pj = G.h_peak_j;
    double max_growth = -1e30;
    double *h_om1 = G.h_host_delta;  // reuse host buffer (n2 doubles)
    cudaMemcpy(h_om1, G.d_om[1], n2 * sizeof(double), cudaMemcpyDeviceToHost);
    for (int di = -5; di <= 5; di++) {
        int ii = (pi + di + N) % N;
        for (int dj = -5; dj <= 5; dj++) {
            int jj = (pj + dj + N) % N;
            double v = h_om1[ii * N + jj];
            if (v > max_growth) max_growth = v;
        }
    }
    G.h_nbr_max_growth = max_growth;

    return _f2b(G.h_interp_growth);
}

// ================================================================
// Enstrophy-based BKM argument
//
// Ω(t) = ∫ω² dx = (2π)²/N² · Σ_ij ω(i,j)²   (grid quadrature)
// dΩ/dt = 2∫ω·θ_x dx = 2·(2π)²/N² · Σ_ij ω(i,j)·θ_x(i,j)
//
// If dΩ/dt ≥ c·Ω^γ with γ>1, then Ω→∞ in finite time.
// By Agmon's inequality: ||ω||_∞ → ∞ when Ω→∞.
//
// Smooth global quantities — no peak tracking, no sign oscillation.
// ================================================================

extern "C" long long nuc_gpu_compute_enstrophy(void) {
    int n2 = G.n2, N = G.N, p = G.p;
    double dx = G.dx;
    double cell_area = dx * dx;  // (2π/N)²

    double *h_om_mid = G.h_host_mid;
    double *h_om_del = G.h_host_delta;
    double *h_thx_mid = G.h_host_mid2;
    double *h_thx_del = G.h_host_delta2;

    // ================================================================
    // PHASE 1: Rigorous enstrophy bounds using delta vectors
    // Download om_mid and delta_om
    // ================================================================
    cudaMemcpy(h_om_mid, G.d_om_mid, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(h_om_del, G.d_delta_om, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    double enstrophy = 0, enstrophy_lo = 0, enstrophy_hi = 0;
    for (int i = 0; i < n2; i++) {
        double m = h_om_mid[i];
        double d = fabs(h_om_del[i]);
        enstrophy += m * m;
        double lo = fabs(m) - d;
        if (lo < 0.0) lo = 0.0;
        enstrophy_lo += lo * lo;
        double hi = fabs(m) + d;
        enstrophy_hi += hi * hi;
    }
    enstrophy *= cell_area;
    enstrophy_lo *= cell_area;
    enstrophy_hi *= cell_area;

    // ================================================================
    // PHASE 2: Rigorous forcing bounds for dΩ/dt = 2∫ω·θ_x dx
    // θ_x is certified from the derivative Taylor coefficients directly.
    // ================================================================
    double enstrophy_rate = 0, enstrophy_rate_lo = 0, enstrophy_rate_hi = 0;
    if (G.last_h > 0.0) {
        int B = gpu_blocks(n2, THREADS);
        double h = G.last_h;
        double hp1 = pow(h, p + 1);
        double round_scale = (double)(p + 2) * 2.2204460492503131e-16;

        cudaMemcpy(G.d_scratch1, G.d_thx[p], n2 * sizeof(double), cudaMemcpyDeviceToDevice);
        cudaMemcpy(G.d_scratch2, G.d_dthx[p], n2 * sizeof(double), cudaMemcpyDeviceToDevice);
        for (int k = p - 1; k >= 0; k--) {
            k_horner_step<<<B,THREADS>>>(G.d_scratch1, G.d_thx[k], h, n2);
            k_horner_step<<<B,THREADS>>>(G.d_scratch2, G.d_dthx[k], h, n2);
        }

        // Truncation for θ_x comes from ∂x θ[p+1].
        gpu_ddx(G.d_th[p + 1], G.d_comp1);
        k_add_trunc_round<<<B,THREADS>>>(G.d_scratch2, G.d_comp1, G.d_scratch1,
                                         hp1, round_scale, n2);

        cudaMemcpy(h_thx_mid, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
        cudaMemcpy(h_thx_del, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

        for (int i = 0; i < n2; i++) {
            double om_mid = h_om_mid[i];
            double om_rad = fabs(h_om_del[i]);
            double tx_mid = h_thx_mid[i];
            double tx_rad = fabs(h_thx_del[i]);

            enstrophy_rate += om_mid * tx_mid;

            double om_lo = om_mid - om_rad;
            double om_hi = om_mid + om_rad;
            double tx_lo = tx_mid - tx_rad;
            double tx_hi = tx_mid + tx_rad;

            double p1 = om_lo * tx_lo;
            double p2 = om_lo * tx_hi;
            double p3 = om_hi * tx_lo;
            double p4 = om_hi * tx_hi;
            double plo = fmin(fmin(p1, p2), fmin(p3, p4));
            double phi = fmax(fmax(p1, p2), fmax(p3, p4));

            enstrophy_rate_lo += plo;
            enstrophy_rate_hi += phi;
        }
    } else {
        gpu_ddx(G.d_th_mid, G.d_scratch1);
        cudaMemcpy(h_thx_mid, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
        for (int i = 0; i < n2; i++) {
            enstrophy_rate += h_om_mid[i] * h_thx_mid[i];
        }
        enstrophy_rate_lo = enstrophy_rate;
        enstrophy_rate_hi = enstrophy_rate;
    }
    enstrophy_rate *= 2.0 * cell_area;
    enstrophy_rate_lo *= 2.0 * cell_area;
    enstrophy_rate_hi *= 2.0 * cell_area;

    // ================================================================
    // PHASE 3: Palinstrophy P = ∫|∇ω|² (for viscous balance)
    // Reuses the omega host workspaces.
    // ================================================================
    gpu_ddx(G.d_om_mid, G.d_scratch1);
    cudaMemcpy(h_om_mid, G.d_scratch1, n2 * sizeof(double), cudaMemcpyDeviceToHost);
    gpu_ddy(G.d_om_mid, G.d_scratch2);
    cudaMemcpy(h_om_del, G.d_scratch2, n2 * sizeof(double), cudaMemcpyDeviceToHost);

    double palinstrophy = 0;
    for (int i = 0; i < n2; i++) {
        palinstrophy += h_om_mid[i] * h_om_mid[i] + h_om_del[i] * h_om_del[i];
    }
    palinstrophy *= cell_area;

    // ================================================================
    // Store all results
    // ================================================================
    G.h_enstrophy = enstrophy;
    G.h_enstrophy_lo = enstrophy_lo;
    G.h_enstrophy_hi = enstrophy_hi;
    G.h_enstrophy_rate = enstrophy_rate;
    G.h_enstrophy_rate_lo = enstrophy_rate_lo;
    G.h_enstrophy_rate_hi = enstrophy_rate_hi;
    G.h_palinstrophy = palinstrophy;
    G.h_enstrophy_dissip = 2.0 * G.nu * palinstrophy;
    G.h_enstrophy_net_rate = enstrophy_rate - G.h_enstrophy_dissip;

    return _f2b(enstrophy);
}

extern "C" long long nuc_gpu_get_enstrophy(void) { return _f2b(G.h_enstrophy); }
extern "C" long long nuc_gpu_get_enstrophy_lo(void) { return _f2b(G.h_enstrophy_lo); }
extern "C" long long nuc_gpu_get_enstrophy_hi(void) { return _f2b(G.h_enstrophy_hi); }
extern "C" long long nuc_gpu_get_enstrophy_rate(void) { return _f2b(G.h_enstrophy_rate); }
extern "C" long long nuc_gpu_get_enstrophy_rate_lo(void) { return _f2b(G.h_enstrophy_rate_lo); }
extern "C" long long nuc_gpu_get_enstrophy_rate_hi(void) { return _f2b(G.h_enstrophy_rate_hi); }
extern "C" long long nuc_gpu_get_palinstrophy(void) { return _f2b(G.h_palinstrophy); }
extern "C" long long nuc_gpu_get_enstrophy_dissip(void) { return _f2b(G.h_enstrophy_dissip); }
extern "C" long long nuc_gpu_get_enstrophy_net_rate(void) { return _f2b(G.h_enstrophy_net_rate); }

// BKM FFI getters
extern "C" long long nuc_gpu_get_interp_x(void) { return _f2b(G.h_interp_x); }
extern "C" long long nuc_gpu_get_interp_y(void) { return _f2b(G.h_interp_y); }
extern "C" long long nuc_gpu_get_interp_omega(void) { return _f2b(G.h_interp_omega); }
extern "C" long long nuc_gpu_get_interp_growth(void) { return _f2b(G.h_interp_growth); }
extern "C" long long nuc_gpu_get_nbr_max_growth(void) { return _f2b(G.h_nbr_max_growth); }

// Robust FFI getters
// ================================================================
// stat: 0=mean, 1=max, 2=p90.  win: 0-4 per plan.
extern "C" long long nuc_gpu_get_rob_alpha(long long stat, long long win) {
    int s = (int)stat, w = (int)win;
    if (s < 0 || s >= ROB_NSTAT || w < 0 || w >= ROB_NWIN) return _f2b(0.0);
    return _f2b(G.h_rob_alpha[s][w]);
}
extern "C" long long nuc_gpu_get_rob_trunc(long long stat, long long win) {
    int s = (int)stat, w = (int)win;
    if (s < 0 || s >= ROB_NSTAT || w < 0 || w >= ROB_NWIN) return _f2b(1e30);
    return _f2b(G.h_rob_trunc[s][w]);
}
extern "C" long long nuc_gpu_get_rob_r2(long long stat, long long win) {
    int s = (int)stat, w = (int)win;
    if (s < 0 || s >= ROB_NSTAT || w < 0 || w >= ROB_NWIN) return _f2b(0.0);
    return _f2b(G.h_rob_r2[s][w]);
}
extern "C" long long nuc_gpu_get_rob_violations(long long stat, long long win) {
    int s = (int)stat, w = (int)win;
    if (s < 0 || s >= ROB_NSTAT || w < 0 || w >= ROB_NWIN) return 0;
    return (long long)G.h_rob_violations[s][w];
}
extern "C" long long nuc_gpu_get_rob_max_violation(long long stat, long long win) {
    int s = (int)stat, w = (int)win;
    if (s < 0 || s >= ROB_NSTAT || w < 0 || w >= ROB_NWIN) return _f2b(0.0);
    return _f2b(G.h_rob_max_violation[s][w]);
}
extern "C" long long nuc_gpu_get_rob_alpha_env(long long stat) {
    int s = (int)stat;
    if (s < 0 || s >= ROB_NSTAT) return _f2b(0.0);
    return _f2b(G.h_rob_alpha_env[s]);
}
extern "C" long long nuc_gpu_get_rob_trunc_env(long long stat) {
    int s = (int)stat;
    if (s < 0 || s >= ROB_NSTAT) return _f2b(1e30);
    return _f2b(G.h_rob_trunc_env[s]);
}
extern "C" long long nuc_gpu_get_rob_min_alpha(void) { return _f2b(G.h_rob_min_alpha); }
extern "C" long long nuc_gpu_get_rob_max_trunc(void) { return _f2b(G.h_rob_max_trunc); }
// Formal majorant getters
extern "C" long long nuc_gpu_get_majorant_alpha(void) { return _f2b(G.h_majorant_alpha); }
extern "C" long long nuc_gpu_get_majorant_C(void) { return _f2b(G.h_majorant_C); }
extern "C" long long nuc_gpu_get_majorant_trunc(void) { return _f2b(G.h_majorant_trunc); }
extern "C" long long nuc_gpu_get_majorant_valid(void) { return (long long)G.h_majorant_valid; }
extern "C" long long nuc_gpu_get_shell_mean(long long s) {
    int si = (int)s;
    if (si < 0 || si > G.h_shell_count) return _f2b(0.0);
    return _f2b(G.h_shell_amps[si]);
}
extern "C" long long nuc_gpu_get_shell_max_val(long long s) {
    int si = (int)s;
    if (si < 0 || si > G.h_shell_count) return _f2b(0.0);
    return _f2b(G.h_shell_max[si]);
}
extern "C" long long nuc_gpu_get_shell_p90(long long s) {
    int si = (int)s;
    if (si < 0 || si > G.h_shell_count) return _f2b(0.0);
    return _f2b(G.h_shell_p90[si]);
}
extern "C" long long nuc_gpu_get_analytic_rho_omega(void) { return _f2b(G.h_gap1_rho_om); }
extern "C" long long nuc_gpu_get_analytic_rho_theta(void) { return _f2b(G.h_gap1_rho_th); }
extern "C" long long nuc_gpu_get_analytic_x_upper(void) { return _f2b(G.h_gap1_X_upper); }
extern "C" long long nuc_gpu_get_analytic_tau(void) { return _f2b(G.h_gap1_tau); }
extern "C" long long nuc_gpu_get_analytic_lambda(void) { return _f2b(G.h_gap1_lambda); }
extern "C" long long nuc_gpu_get_transport_nablau_inf_up(void) { return _f2b(G.h_trans_nablau_inf_up); }
extern "C" long long nuc_gpu_get_transport_gradom_inf_up(void) { return _f2b(G.h_trans_gradom_inf_up); }
extern "C" long long nuc_gpu_get_transport_gradth_inf_up(void) { return _f2b(G.h_trans_gradth_inf_up); }
static double _gap1_transport_prefix_om_l1(int smax, int weighted_by_r) {
    if (!G.h_gap1_ready) return 0.0;
    if (smax < 0) return 0.0;
    if (smax > G.h_gap1_n_shells) smax = G.h_gap1_n_shells;
    double rho = G.h_gap1_rho_om;
    double acc = 0.0;
    for (int s = 1; s <= smax; s++) {
        int cnt = G.h_gap1_shell_count_arr[s];
        if (cnt <= 0) continue;
        double shell = G.h_gap1_om_l1[s] + (double)cnt * rho;
        if (weighted_by_r) shell *= ((double)s + 0.5);
        acc += shell;
    }
    return acc;
}

static double _gap1_transport_prefix_th_l1(int smax) {
    if (!G.h_gap1_ready) return 0.0;
    if (smax < 0) return 0.0;
    if (smax > G.h_gap1_n_shells) smax = G.h_gap1_n_shells;
    double rho = G.h_gap1_rho_th;
    double acc = 0.0;
    for (int s = 1; s <= smax; s++) {
        int cnt = G.h_gap1_shell_count_arr[s];
        if (cnt <= 0) continue;
        double shell = G.h_gap1_th_l1[s] + (double)cnt * rho;
        acc += ((double)s + 0.5) * shell;
    }
    return acc;
}

extern "C" long long nuc_gpu_get_transport_nablau_inf_up_to(long long smax_bits) {
    return _f2b(_gap1_transport_prefix_om_l1((int)smax_bits, 0));
}

extern "C" long long nuc_gpu_get_transport_gradom_inf_up_to(long long smax_bits) {
    return _f2b(_gap1_transport_prefix_om_l1((int)smax_bits, 1));
}

extern "C" long long nuc_gpu_get_transport_gradth_inf_up_to(long long smax_bits) {
    return _f2b(_gap1_transport_prefix_th_l1((int)smax_bits));
}
extern "C" long long nuc_gpu_get_aposteriori_resid_omega_mid(void) { return _f2b(G.h_apost_resid_omega_mid); }
extern "C" long long nuc_gpu_get_aposteriori_resid_theta_mid(void) { return _f2b(G.h_apost_resid_theta_mid); }
extern "C" long long nuc_gpu_get_aposteriori_resid_combo_mid(void) { return _f2b(G.h_apost_resid_combo_mid); }
extern "C" long long nuc_gpu_get_aposteriori_last_s(void) { return (long long)G.h_apost_last_s; }
extern "C" long long nuc_gpu_get_aposteriori_last_lambda(void) { return _f2b(G.h_apost_last_lambda); }
extern "C" long long nuc_gpu_get_aposteriori_l2_resid_omega_mid(void) { return _f2b(G.h_apost_l2_resid_omega_mid); }
extern "C" long long nuc_gpu_get_aposteriori_l2_resid_theta_mid(void) { return _f2b(G.h_apost_l2_resid_theta_mid); }
extern "C" long long nuc_gpu_get_aposteriori_l2_resid_combo_mid(void) { return _f2b(G.h_apost_l2_resid_combo_mid); }
extern "C" long long nuc_gpu_get_mech_omega_chi(void) { return _f2b(G.h_mech_omega_chi); }
extern "C" long long nuc_gpu_get_mech_j_chi(void) { return _f2b(G.h_mech_j_chi); }
extern "C" long long nuc_gpu_get_mech_p_chi(void) { return _f2b(G.h_mech_p_chi); }
extern "C" long long nuc_gpu_get_mech_o_chi(void) { return _f2b(G.h_mech_o_chi); }
extern "C" long long nuc_gpu_get_mech_o_diag(void) { return _f2b(G.h_mech_o_diag); }
extern "C" long long nuc_gpu_get_mech_o_shear(void) { return _f2b(G.h_mech_o_shear); }
extern "C" long long nuc_gpu_get_mech_o_rot(void) { return _f2b(G.h_mech_o_rot); }
extern "C" long long nuc_gpu_get_mech_bomega(void) { return _f2b(G.h_mech_bomega); }
extern "C" long long nuc_gpu_get_mech_bj(void) { return _f2b(G.h_mech_bj); }
extern "C" long long nuc_gpu_get_mech_center_x(void) { return _f2b(G.h_mech_center_x); }
extern "C" long long nuc_gpu_get_mech_center_y(void) { return _f2b(G.h_mech_center_y); }
extern "C" long long nuc_gpu_get_mech_vel_x(void) { return _f2b(G.h_mech_vel_x); }
extern "C" long long nuc_gpu_get_mech_vel_y(void) { return _f2b(G.h_mech_vel_y); }
extern "C" long long nuc_gpu_get_mech_rin(void) { return _f2b(G.h_mech_rin); }
extern "C" long long nuc_gpu_get_mech_rout(void) { return _f2b(G.h_mech_rout); }
extern "C" long long nuc_gpu_get_geom_peak_tx(void) { return _f2b(G.h_geom_peak_tx); }
extern "C" long long nuc_gpu_get_geom_peak_ty(void) { return _f2b(G.h_geom_peak_ty); }
extern "C" long long nuc_gpu_get_geom_peak_angle(void) { return _f2b(G.h_geom_peak_angle); }
extern "C" long long nuc_gpu_get_geom_peak_ux(void) { return _f2b(G.h_geom_peak_ux); }
extern "C" long long nuc_gpu_get_geom_peak_shear(void) { return _f2b(G.h_geom_peak_shear); }
extern "C" long long nuc_gpu_get_geom_peak_lambda(void) { return _f2b(G.h_geom_peak_lambda); }
extern "C" long long nuc_gpu_get_geom_peak_strain_angle(void) { return _f2b(G.h_geom_peak_strain_angle); }
extern "C" long long nuc_gpu_get_geom_peak_align(void) { return _f2b(G.h_geom_peak_align); }
extern "C" long long nuc_gpu_get_geom_patch_tx(void) { return _f2b(G.h_geom_patch_tx); }
extern "C" long long nuc_gpu_get_geom_patch_ty(void) { return _f2b(G.h_geom_patch_ty); }
extern "C" long long nuc_gpu_get_geom_patch_angle(void) { return _f2b(G.h_geom_patch_angle); }
extern "C" long long nuc_gpu_get_geom_patch_ux(void) { return _f2b(G.h_geom_patch_ux); }
extern "C" long long nuc_gpu_get_geom_patch_shear(void) { return _f2b(G.h_geom_patch_shear); }
extern "C" long long nuc_gpu_get_geom_patch_lambda(void) { return _f2b(G.h_geom_patch_lambda); }
extern "C" long long nuc_gpu_get_geom_patch_strain_angle(void) { return _f2b(G.h_geom_patch_strain_angle); }
extern "C" long long nuc_gpu_get_geom_patch_align(void) { return _f2b(G.h_geom_patch_align); }
extern "C" long long nuc_gpu_get_geom_patch_mass(void) { return _f2b(G.h_geom_patch_mass); }
extern "C" long long nuc_gpu_get_far_omega(void) { return _f2b(G.h_far_omega); }
extern "C" long long nuc_gpu_get_far_thetay(void) { return _f2b(G.h_far_thetay); }
extern "C" long long nuc_gpu_get_far_opp(void) { return _f2b(G.h_far_opp); }
extern "C" long long nuc_gpu_get_far_ginf(void) { return _f2b(G.h_far_ginf); }
extern "C" long long nuc_gpu_get_far_defect(void) { return _f2b(G.h_far_defect); }
extern "C" long long nuc_gpu_get_far_center_x(void) { return _f2b(G.h_far_center_x); }
extern "C" long long nuc_gpu_get_far_center_y(void) { return _f2b(G.h_far_center_y); }
extern "C" long long nuc_gpu_get_far_rin(void) { return _f2b(G.h_far_rin); }
extern "C" long long nuc_gpu_get_far_rout(void) { return _f2b(G.h_far_rout); }
extern "C" long long nuc_gpu_get_phase3_a_lo(void) { return _f2b(G.h_phase3_a_lo); }
extern "C" long long nuc_gpu_get_phase3_a_hi(void) { return _f2b(G.h_phase3_a_hi); }
extern "C" long long nuc_gpu_get_phase3_dstar_lo(void) { return _f2b(G.h_phase3_dstar_lo); }
extern "C" long long nuc_gpu_get_phase3_dfar_lo(void) { return _f2b(G.h_phase3_dfar_lo); }
extern "C" long long nuc_gpu_get_phase3_oloc_hi(void) { return _f2b(G.h_phase3_oloc_hi); }
extern "C" long long nuc_gpu_get_phase3_ofar_hi(void) { return _f2b(G.h_phase3_ofar_hi); }
extern "C" long long nuc_gpu_get_phase3_net_lo(void) { return _f2b(G.h_phase3_net_lo); }
extern "C" long long nuc_gpu_get_phase3_q_hi(void) { return _f2b(G.h_phase3_q_hi); }
extern "C" long long nuc_gpu_get_phase3_net1_lo(void) { return _f2b(G.h_phase3_net1_lo); }
extern "C" long long nuc_gpu_get_phase3_netg_lo(void) { return _f2b(G.h_phase3_netg_lo); }
extern "C" long long nuc_gpu_get_phase3_omega_exact(void) { return _f2b(G.h_phase3_omega_exact); }
extern "C" long long nuc_gpu_get_phase3_j_exact(void) { return _f2b(G.h_phase3_j_exact); }
extern "C" long long nuc_gpu_get_phase3_p_exact(void) { return _f2b(G.h_phase3_p_exact); }
extern "C" long long nuc_gpu_get_phase3_o_exact(void) { return _f2b(G.h_phase3_o_exact); }
extern "C" long long nuc_gpu_get_phase3_jdot_exact(void) { return _f2b(G.h_phase3_jdot_exact); }
extern "C" long long nuc_gpu_get_phase3_q_exact(void) { return _f2b(G.h_phase3_q_exact); }
extern "C" long long nuc_gpu_get_phase3_net_exact(void) { return _f2b(G.h_phase3_net_exact); }
extern "C" long long nuc_gpu_get_phase3_net1_exact(void) { return _f2b(G.h_phase3_net1_exact); }
extern "C" long long nuc_gpu_get_analytic_shell_count(long long s) {
    int si = (int)s;
    if (si < 0 || si > G.h_gap1_n_shells) return 0;
    return (long long)G.h_gap1_shell_count_arr[si];
}
extern "C" long long nuc_gpu_get_analytic_n_shells(void) { return (long long)G.h_gap1_n_shells; }
extern "C" long long nuc_gpu_get_exact_shell_count(long long s) {
    int si = (int)s;
    if (si < 0) return 0;
    if (si <= SHELL_EXACT_MAX) return (long long)G.h_shell_exact[si];
    return (long long)(16 * si + 4);
}

extern "C" long long nuc_gpu_get_omega_max_hi(void) { return _f2b(G.h_omega_max_hi); }
extern "C" long long nuc_gpu_get_omega_max_lo(void) { return _f2b(G.h_omega_max_lo); }
extern "C" long long nuc_gpu_get_radius(void) { return _f2b(G.h_radius); }
extern "C" long long nuc_gpu_get_time(void) { return _f2b(G.t); }
extern "C" long long nuc_gpu_get_steps(void) { return (long long)G.steps; }
extern "C" void nuc_gpu_cleanup(void) { gpu_cleanup(); }
