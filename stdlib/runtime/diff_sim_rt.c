// diff_sim_rt.c — Differentiable Quantum Simulation Runtime
// General-purpose: N cores, per-core learnable noise logits, von Neumann entropy,
// per-core feature extraction, backward through noise.
// Matches Python twin_core_v2.py + multi_core_twin.py capabilities.
//
// Compile: clang -c diff_sim_rt.c -o target/diff_sim_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _d_i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _d_f2i(double f) { long long i; memcpy(&i, &f, sizeof(long long)); return i; }

// =====================================================
// Configuration
// =====================================================
#define DS_MAX_GATES 200
#define DS_MAX_CORES 16
#define DS_MAX_QUBITS 12
#define DS_MAX_AMPS 4096   // 2^12

// =====================================================
// Noise bounds (matching Python PerGateNoiseModel)
// =====================================================
#define NOISE_1Q_LO 0.0005
#define NOISE_1Q_HI 0.05
#define NOISE_2Q_LO 0.002
#define NOISE_2Q_HI 0.08

// =====================================================
// DiffSim structure
// =====================================================
typedef struct {
    int nq, n_cores, n_amps;

    // Statevectors: [core][amp][re/im]
    double *sv;  // n_cores * n_amps * 2

    // Per-core per-gate learnable noise logits: [(n_cores-1) * n_gates]
    // Core 0 is clean (no noise), cores 1..n_cores-1 have noise
    double *logits;          // (n_cores-1) * DS_MAX_GATES
    double *grad_logits;     // same shape

    int n_gates;
    int gate_is_2q[DS_MAX_GATES];  // 0=1q, 1=2q for each gate

    // Pre-noise statevector cache: [gate][core][amp*2]
    double *cache;
    int cache_allocated;

    // Per-step per-core entropy: [step][core] = mean von Neumann entropy
    double ent[DS_MAX_GATES][DS_MAX_CORES];

    // Probability cache (for feature extraction)
    double cached_probs[DS_MAX_CORES * DS_MAX_AMPS];

    int step;

    // Simple LCG RNG for diversified init
    unsigned int rng_state;
} DiffSim;

static inline double *ds_sv(DiffSim *ds, int core) {
    return ds->sv + core * ds->n_amps * 2;
}

static inline double *ds_cache(DiffSim *ds, int gate, int core) {
    return ds->cache + ((long long)gate * ds->n_cores + core) * ds->n_amps * 2;
}

// Logit index: core c (0-based among noisy cores), gate g
static inline int ds_logit_idx(DiffSim *ds, int c, int g) {
    return c * DS_MAX_GATES + g;  // c is 0-based (core 1 = c=0)
}

// Simple LCG for Gaussian approximation (Box-Muller)
static double ds_randn(DiffSim *ds) {
    // Two uniform randoms via LCG
    ds->rng_state = ds->rng_state * 1103515245 + 12345;
    double u1 = ((double)((ds->rng_state >> 16) & 0x7FFF) + 1.0) / 32768.0;
    ds->rng_state = ds->rng_state * 1103515245 + 12345;
    double u2 = ((double)((ds->rng_state >> 16) & 0x7FFF)) / 32767.0;
    return sqrt(-2.0 * log(u1)) * cos(2.0 * 3.14159265358979323846 * u2);
}

// =====================================================
// Per-qubit von Neumann entropy
// =====================================================
// Compute mean per-qubit entropy for a given core's statevector.
// Uses reduced density matrix: for each qubit q, trace out all others,
// get 2x2 rho, closed-form eigenvalues, compute -sum(lam*log2(lam)).
static double ds_compute_mean_entropy(double *sv, int nq, int na) {
    double total_ent = 0.0;

    for (int q = 0; q < nq; q++) {
        // Build 2x2 reduced density matrix rho for qubit q
        // rho[0][0] = sum of |amp|^2 where qubit q = 0
        // rho[1][1] = sum of |amp|^2 where qubit q = 1
        // rho[0][1] = sum of amp_0 * conj(amp_1) where states differ only in qubit q
        double rho00 = 0, rho11 = 0, rho01_re = 0, rho01_im = 0;
        int bit = 1 << q;

        for (int i = 0; i < na; i++) {
            if (i & bit) continue; // only iterate over qubit q = 0 states
            int j = i | bit;       // corresponding qubit q = 1 state
            double re0 = sv[i*2], im0 = sv[i*2+1];
            double re1 = sv[j*2], im1 = sv[j*2+1];
            rho00 += re0*re0 + im0*im0;
            rho11 += re1*re1 + im1*im1;
            // rho[0][1] = sum(amp_0 * conj(amp_1))
            rho01_re += re0*re1 + im0*im1;
            rho01_im += im0*re1 - re0*im1;  // im(a * conj(b)) = im_a*re_b - re_a*im_b
        }

        // Eigenvalues of 2x2 Hermitian: [[a, c+di], [c-di, b]]
        // lambda = (a+b)/2 +/- sqrt(((a-b)/2)^2 + c^2 + d^2)
        double a = rho00, b = rho11, c = rho01_re, d = rho01_im;
        double mid = (a + b) * 0.5;
        double disc = (a - b) * 0.5;
        double off = sqrt(disc*disc + c*c + d*d);
        double lam0 = mid + off;
        double lam1 = mid - off;

        // Von Neumann entropy: -sum(lam * log2(lam))
        double ent = 0;
        if (lam0 > 1e-10) ent -= lam0 * log2(lam0);
        if (lam1 > 1e-10) ent -= lam1 * log2(lam1);
        total_ent += ent;
    }

    return nq > 0 ? total_ent / nq : 0.0;
}

// =====================================================
// Init
// =====================================================
// mode: 0 = uniform init (all logits same), 1 = diversified (Python MultiCoreNoiseModel style)
long long nuc_diff_sim_init(long long nq, long long n_cores, long long mode_bits, long long seed) {
    int nq_i = (int)nq;
    int nc = (int)n_cores;
    if (nq_i < 1 || nq_i > DS_MAX_QUBITS) return 0;
    if (nc < 2 || nc > DS_MAX_CORES) return 0;  // minimum: 1 clean + 1 noisy

    int na = 1 << nq_i;
    int n_noisy = nc - 1;  // number of noisy cores
    int mode = (int)mode_bits;

    DiffSim *ds = (DiffSim *)calloc(1, sizeof(DiffSim));
    if (!ds) { fprintf(stderr, "diff_sim: alloc failed\n"); return 0; }

    ds->nq = nq_i;
    ds->n_cores = nc;
    ds->n_amps = na;
    ds->n_gates = 0;
    ds->step = 0;
    ds->rng_state = (unsigned int)seed;

    // Allocate statevectors
    ds->sv = (double *)calloc((long long)nc * na * 2, sizeof(double));
    if (!ds->sv) { free(ds); return 0; }
    for (int c = 0; c < nc; c++)
        ds->sv[c * na * 2] = 1.0;  // |0> state

    // Allocate pre-noise cache
    long long cache_size = (long long)DS_MAX_GATES * nc * na * 2;
    ds->cache = (double *)calloc(cache_size, sizeof(double));
    if (!ds->cache) { free(ds->sv); free(ds); return 0; }
    ds->cache_allocated = 1;

    // Allocate per-core logits: (n_cores-1) * DS_MAX_GATES
    int logit_count = n_noisy * DS_MAX_GATES;
    ds->logits = (double *)calloc(logit_count, sizeof(double));
    ds->grad_logits = (double *)calloc(logit_count, sizeof(double));
    if (!ds->logits || !ds->grad_logits) {
        if (ds->logits) free(ds->logits);
        if (ds->grad_logits) free(ds->grad_logits);
        free(ds->cache); free(ds->sv); free(ds); return 0;
    }

    // Initialize logits based on mode
    if (mode == 1) {
        // Diversified: each core gets a different base offset (Python MultiCoreNoiseModel)
        // 1q: base = -5.5 + c*0.3 + gaussian(0, 0.1)
        // 2q: base = -4.0 + c*0.3 + gaussian(0, 0.1)
        // We initialize all as 1q default; gate_is_2q will be set when gates are applied
        for (int c = 0; c < n_noisy; c++) {
            double base_1q = -5.5 + c * 0.3;
            for (int g = 0; g < DS_MAX_GATES; g++) {
                ds->logits[ds_logit_idx(ds, c, g)] = base_1q + ds_randn(ds) * 0.1;
            }
        }
    } else {
        // Uniform: Python PerGateNoiseModel style
        // 1q logit = log(0.003/0.997) ≈ -5.8
        double init_1q = log(0.003 / 0.997);
        for (int c = 0; c < n_noisy; c++) {
            for (int g = 0; g < DS_MAX_GATES; g++) {
                ds->logits[ds_logit_idx(ds, c, g)] = init_1q;
            }
        }
    }

    memset(ds->gate_is_2q, 0, sizeof(ds->gate_is_2q));
    memset(ds->ent, 0, sizeof(ds->ent));

    return (long long)ds;
}

// =====================================================
// Gate implementations
// =====================================================
static void ds_h(double *sv, int na, int q) {
    int bit = 1 << q;
    double r2 = 0.7071067811865476;
    for (int i = 0; i < na; i++) {
        if (i & bit) continue;
        int j = i | bit;
        double re0=sv[i*2],im0=sv[i*2+1],re1=sv[j*2],im1=sv[j*2+1];
        sv[i*2]=(re0+re1)*r2; sv[i*2+1]=(im0+im1)*r2;
        sv[j*2]=(re0-re1)*r2; sv[j*2+1]=(im0-im1)*r2;
    }
}

static void ds_x(double *sv, int na, int q) {
    int bit = 1 << q;
    for (int i = 0; i < na; i++) {
        if (i & bit) continue;
        int j = i | bit;
        double t0=sv[i*2],t1=sv[i*2+1];
        sv[i*2]=sv[j*2]; sv[i*2+1]=sv[j*2+1];
        sv[j*2]=t0; sv[j*2+1]=t1;
    }
}

static void ds_z(double *sv, int na, int q) {
    for (int i = 0; i < na; i++) {
        if (!((i>>q)&1)) continue;
        sv[i*2]=-sv[i*2]; sv[i*2+1]=-sv[i*2+1];
    }
}

static void ds_cnot(double *sv, int na, int ctrl, int tgt) {
    for (int i = 0; i < na; i++) {
        if (!((i>>ctrl)&1)) continue;
        if ((i>>tgt)&1) continue;
        int j = i ^ (1<<tgt);
        double t0=sv[i*2],t1=sv[i*2+1];
        sv[i*2]=sv[j*2]; sv[i*2+1]=sv[j*2+1];
        sv[j*2]=t0; sv[j*2+1]=t1;
    }
}

static void ds_rz(double *sv, int na, int q, double angle) {
    double half = angle * 0.5;
    double ca = cos(half), sa = sin(half);
    for (int i = 0; i < na; i++) {
        if (!((i>>q)&1)) {
            // |0> component: multiply by e^{-i*theta/2}
            double re=sv[i*2], im=sv[i*2+1];
            sv[i*2]  = re*ca + im*sa;
            sv[i*2+1]= -re*sa + im*ca;
        } else {
            // |1> component: multiply by e^{+i*theta/2}
            double re=sv[i*2], im=sv[i*2+1];
            sv[i*2]  = re*ca - im*sa;
            sv[i*2+1]= re*sa + im*ca;
        }
    }
}

static void ds_rx(double *sv, int na, int q, double angle) {
    int bit = 1 << q;
    double half = angle * 0.5;
    double c = cos(half), s = sin(half);
    // RX = [[cos, -i*sin], [-i*sin, cos]]
    for (int i = 0; i < na; i++) {
        if (i & bit) continue;
        int j = i | bit;
        double re0=sv[i*2], im0=sv[i*2+1], re1=sv[j*2], im1=sv[j*2+1];
        // new|0> = cos*|0> - i*sin*|1>
        sv[i*2]   = c*re0 + s*im1;
        sv[i*2+1] = c*im0 - s*re1;
        // new|1> = -i*sin*|0> + cos*|1>
        sv[j*2]   = s*im0 + c*re1;
        sv[j*2+1] = -s*re0 + c*im1;
    }
}

static void ds_cp(double *sv, int na, int ctrl, int tgt, double angle) {
    // CP: apply e^{i*angle} to |11> component
    double ca = cos(angle), sa = sin(angle);
    for (int i = 0; i < na; i++) {
        if (!((i>>ctrl)&1) || !((i>>tgt)&1)) continue;
        double re = sv[i*2], im = sv[i*2+1];
        sv[i*2]   = re*ca - im*sa;
        sv[i*2+1] = re*sa + im*ca;
    }
}

// Depolarizing noise: sv = (1-p)*sv + p*uniform
static void ds_noise(double *sv, int na, double p) {
    double omp = 1.0 - p;
    double u = p / sqrt((double)na);
    for (int i = 0; i < na; i++) {
        sv[i*2]   = sv[i*2]   * omp + u;
        sv[i*2+1] = sv[i*2+1] * omp;
    }
}

// Get bounded noise rate for a core/gate
static double ds_get_noise_rate(DiffSim *ds, int c, int g) {
    // c is 0-based among noisy cores (core 1 = c=0)
    double logit = ds->logits[ds_logit_idx(ds, c, g)];
    double sig = 1.0 / (1.0 + exp(-logit));
    if (ds->gate_is_2q[g]) {
        return NOISE_2Q_LO + sig * (NOISE_2Q_HI - NOISE_2Q_LO);
    } else {
        return NOISE_1Q_LO + sig * (NOISE_1Q_HI - NOISE_1Q_LO);
    }
}

// =====================================================
// Gate application (applies gate, caches state, applies noise, records entropy)
// =====================================================
// gate_type: 0=H, 1=CNOT, 2=X, 3=Z, 4=RZ, 5=RX, 6=CP
void nuc_diff_gate(long long handle, long long gate_type, long long q0, long long q1, long long angle_bits) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return;
    int g = ds->n_gates;
    if (g >= DS_MAX_GATES) return;

    int gt = (int)gate_type;
    int na = ds->n_amps;
    double angle = _d_i2f(angle_bits);

    // Record gate type
    ds->gate_is_2q[g] = (gt == 1 || gt == 6) ? 1 : 0;  // CNOT=1, CP=6

    // Update 2q logits for diversified mode (adjust from 1q init to 2q base)
    // This is done once when the gate is first applied
    if (ds->gate_is_2q[g]) {
        int n_noisy = ds->n_cores - 1;
        for (int c = 0; c < n_noisy; c++) {
            int idx = ds_logit_idx(ds, c, g);
            // If logit is near the 1q init range, shift to 2q range
            // 2q base: -4.0 + c*0.3 vs 1q base: -5.5 + c*0.3, diff = +1.5
            // Only adjust if this is first time seeing this gate
            if (ds->logits[idx] < -4.5) {  // still in 1q range
                ds->logits[idx] += 1.5;  // shift to 2q range
            }
        }
    }

    for (int c = 0; c < ds->n_cores; c++) {
        double *sv = ds_sv(ds, c);

        // Apply gate
        switch (gt) {
            case 0: ds_h(sv, na, (int)q0); break;
            case 1: ds_cnot(sv, na, (int)q0, (int)q1); break;
            case 2: ds_x(sv, na, (int)q0); break;
            case 3: ds_z(sv, na, (int)q0); break;
            case 4: ds_rz(sv, na, (int)q0, angle); break;
            case 5: ds_rx(sv, na, (int)q0, angle); break;
            case 6: ds_cp(sv, na, (int)q0, (int)q1, angle); break;
            default: break;
        }

        // Cache state AFTER gate, BEFORE noise
        memcpy(ds_cache(ds, g, c), sv, na * 2 * sizeof(double));

        // Apply noise to cores 1..N-1
        if (c > 0) {
            double p = ds_get_noise_rate(ds, c - 1, g);
            ds_noise(sv, na, p);
        }

        // Record per-qubit von Neumann entropy for this step
        ds->ent[g][c] = ds_compute_mean_entropy(sv, ds->nq, na);
    }

    ds->n_gates++;
    ds->step++;
}

// =====================================================
// Per-core feature extraction
// Returns flat vector of (n_cores-1) * 12 features.
// For each noisy core c (vs clean core 0):
//   [0] tv_dist
//   [1] kl_div
//   [2] fidelity
//   [3] mean_ent_div (mean across steps of ent_noisy - ent_clean)
//   [4] max_ent_div
//   [5] final_ent_div
//   [6] div_slope (linear regression slope of ent_div over steps)
//   [7] mean_ent_clean (mean per-qubit entropy of clean core at final step)
//   [8] max_ent_clean (max per-qubit entropy of clean core at final step)
//   [9] sparsity (soft non-zero count normalized)
//   [10] n_qubits
//   [11] n_steps
// =====================================================
long long nuc_diff_extract(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return 0;
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */

    int nc = ds->n_cores, na = ds->n_amps;
    int n_noisy = nc - 1;
    int n_steps = ds->n_gates;
    double eps = 1e-9;

    // Compute probabilities for all cores
    for (int c = 0; c < nc; c++)
        for (int i = 0; i < na; i++) {
            double *sv = ds_sv(ds, c);
            ds->cached_probs[c*na+i] = sv[i*2]*sv[i*2] + sv[i*2+1]*sv[i*2+1];
        }

    // Clean core entropy at final step (per qubit) — need max too
    // Recompute per-qubit (not just mean) for max
    double clean_ent_per_q[DS_MAX_QUBITS];
    {
        double *sv0 = ds_sv(ds, 0);
        for (int q = 0; q < ds->nq; q++) {
            double rho00=0, rho11=0, rho01_re=0, rho01_im=0;
            int bit = 1 << q;
            for (int i = 0; i < na; i++) {
                if (i & bit) continue;
                int j = i | bit;
                double re0=sv0[i*2],im0=sv0[i*2+1],re1=sv0[j*2],im1=sv0[j*2+1];
                rho00 += re0*re0+im0*im0;
                rho11 += re1*re1+im1*im1;
                rho01_re += re0*re1+im0*im1;
                rho01_im += im0*re1-re0*im1;
            }
            double mid=(rho00+rho11)*0.5, disc=(rho00-rho11)*0.5;
            double off=sqrt(disc*disc+rho01_re*rho01_re+rho01_im*rho01_im);
            double l0=mid+off, l1=mid-off, ent=0;
            if(l0>1e-10) ent-=l0*log2(l0);
            if(l1>1e-10) ent-=l1*log2(l1);
            clean_ent_per_q[q] = ent;
        }
    }
    double mean_ent_clean = 0, max_ent_clean = 0;
    for (int q = 0; q < ds->nq; q++) {
        mean_ent_clean += clean_ent_per_q[q];
        if (clean_ent_per_q[q] > max_ent_clean) max_ent_clean = clean_ent_per_q[q];
    }
    if (ds->nq > 0) mean_ent_clean /= ds->nq;

    // Build output vector: n_noisy * 12 features
    int total_feats = n_noisy * 12;
    NVec *feats = (NVec *)malloc(sizeof(NVec));
    feats->cap = total_feats + 4;
    feats->len = 0;
    feats->data = (long long *)malloc(feats->cap * sizeof(long long));

    #define PUSH_F(v, val) do { \
        double _fv = (val); long long _fi; memcpy(&_fi, &_fv, sizeof(double)); \
        if ((v)->len >= (v)->cap) { (v)->cap *= 2; (v)->data = (long long*)realloc((v)->data, (v)->cap*sizeof(long long)); } \
        (v)->data[(v)->len++] = _fi; } while(0)

    for (int ci = 0; ci < n_noisy; ci++) {
        int c = ci + 1;  // actual core index

        // TV distance, KL divergence, Fidelity
        double tv = 0, kl = 0, fid = 0;
        for (int i = 0; i < na; i++) {
            double pa = ds->cached_probs[i];          // clean
            double pb = ds->cached_probs[c*na+i];     // noisy
            tv += fabs(pa - pb);
            double pa_s = pa + eps, pb_s = pb + eps;
            kl += pa_s * log(pa_s / pb_s);
            fid += sqrt(pa * pb + eps);
        }
        tv *= 0.5;

        // Entropy divergences across steps
        double mean_ent_div = 0, max_ent_div = -1e30, final_ent_div = 0;
        double sum_t = 0, sum_div = 0, sum_t2 = 0, sum_t_div = 0;
        for (int s = 0; s < n_steps; s++) {
            double ent_div = ds->ent[s][c] - ds->ent[s][0];
            mean_ent_div += ent_div;
            if (ent_div > max_ent_div) max_ent_div = ent_div;
            if (s == n_steps - 1) final_ent_div = ent_div;

            // For slope regression
            double t = (double)s;
            sum_t += t;
            sum_div += ent_div;
            sum_t2 += t * t;
            sum_t_div += t * ent_div;
        }
        if (n_steps > 0) mean_ent_div /= n_steps;
        if (n_steps == 0) max_ent_div = 0;

        // Linear regression slope of ent_div over step index
        double div_slope = 0;
        if (n_steps > 1) {
            double n = (double)n_steps;
            double denom = n * sum_t2 - sum_t * sum_t;
            if (fabs(denom) > 1e-15)
                div_slope = (n * sum_t_div - sum_t * sum_div) / denom;
        }

        // Sparsity: soft non-zero count (matching Python sigmoid threshold)
        double sparsity = 0;
        for (int i = 0; i < na; i++) {
            double p = ds->cached_probs[i];  // clean core probs
            sparsity += 1.0 / (1.0 + exp(-(p - eps) * 1000.0));
        }
        sparsity /= (double)na;

        // Push 12 features for this core
        PUSH_F(feats, tv);                    // [0] tv_dist
        PUSH_F(feats, kl);                    // [1] kl_div
        PUSH_F(feats, fid);                   // [2] fidelity
        PUSH_F(feats, mean_ent_div);          // [3] mean_ent_div
        PUSH_F(feats, max_ent_div);           // [4] max_ent_div
        PUSH_F(feats, final_ent_div);         // [5] final_ent_div
        PUSH_F(feats, div_slope);             // [6] div_slope
        PUSH_F(feats, mean_ent_clean);        // [7] mean_ent_clean
        PUSH_F(feats, max_ent_clean);         // [8] max_ent_clean
        PUSH_F(feats, sparsity);              // [9] sparsity
        PUSH_F(feats, (double)ds->nq);        // [10] n_qubits
        PUSH_F(feats, (double)n_steps);       // [11] n_steps
    }

    #undef PUSH_F
    return (long long)feats;
}

// =====================================================
// Backward: gradient of loss w.r.t. per-core noise logits
// =====================================================
// grad_loss is a scalar (the upstream gradient from the predictor).
// For TC V2 (n_cores=2): gradient flows to logits[0][g] for each gate g.
// For MC (n_cores=16): gradient flows to logits[c][g] for each core c, gate g.
// The gradient through depolarizing noise:
//   sv_noisy = (1-p)*sv_pre + p*uniform
//   d(sv_noisy)/d(p) = -sv_pre + uniform = -sv_pre + 1/sqrt(N)
//   d(p)/d(logit) = sig*(1-sig) * (hi-lo)  (bounded sigmoid derivative)
void nuc_diff_backward(long long handle, long long grad_loss_bits) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return;
    double grad_loss = _d_i2f(grad_loss_bits);
    int na = ds->n_amps, nc = ds->n_cores;
    int n_noisy = nc - 1;
    double inv_sqrt_na = 1.0 / sqrt((double)na);

    for (int g = 0; g < ds->n_gates; g++) {
        double lo, hi;

        for (int ci = 0; ci < n_noisy; ci++) {
            int c = ci + 1;
            int idx = ds_logit_idx(ds, ci, g);

            if (ds->gate_is_2q[g]) { lo = NOISE_2Q_LO; hi = NOISE_2Q_HI; }
            else { lo = NOISE_1Q_LO; hi = NOISE_1Q_HI; }

            double logit = ds->logits[idx];
            double sig = 1.0 / (1.0 + exp(-logit));
            double p = lo + sig * (hi - lo);

            double *pre = ds_cache(ds, g, c);

            // d(TV)/d(p): how TV distance changes with noise rate
            double d_tv_d_p = 0;
            for (int i = 0; i < na; i++) {
                // d(sv_noisy_re)/d(p) = -pre_re + 1/sqrt(N)
                double d_sv_re = -pre[i*2] + inv_sqrt_na;
                // d(sv_noisy_im)/d(p) = -pre_im
                double d_sv_im = -pre[i*2+1];

                // sv_noisy = (1-p)*pre + p*uniform
                double sv_noisy_re = pre[i*2] * (1.0 - p) + p * inv_sqrt_na;
                double sv_noisy_im = pre[i*2+1] * (1.0 - p);

                // d(prob_noisy)/d(p) = 2*(sv_re*d_sv_re + sv_im*d_sv_im)
                double d_prob = 2.0 * (sv_noisy_re * d_sv_re + sv_noisy_im * d_sv_im);

                // d(TV)/d(prob) = sign(p_clean - p_noisy) * 0.5
                double p_clean = ds->cached_probs[i];
                double p_noisy = sv_noisy_re*sv_noisy_re + sv_noisy_im*sv_noisy_im;
                double sign = (p_clean > p_noisy) ? -1.0 : 1.0;
                d_tv_d_p += sign * d_prob;
            }
            d_tv_d_p *= 0.5;

            // d(p)/d(logit) = sig*(1-sig) * (hi-lo)
            double d_p_d_logit = sig * (1.0 - sig) * (hi - lo);

            ds->grad_logits[idx] += grad_loss * d_tv_d_p * d_p_d_logit;
        }
    }
}

// =====================================================
// Logit getters/setters (flat vector: all cores concatenated)
// =====================================================
long long nuc_diff_get_logits(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return 0;
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    int n_noisy = ds->n_cores - 1;
    int total = n_noisy * ds->n_gates;
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->len = total; v->cap = total;
    v->data = (long long *)malloc(v->cap * sizeof(long long));
    for (int ci = 0; ci < n_noisy; ci++)
        for (int g = 0; g < ds->n_gates; g++)
            v->data[ci * ds->n_gates + g] = _d_f2i(ds->logits[ds_logit_idx(ds, ci, g)]);
    return (long long)v;
}

long long nuc_diff_get_grad_logits(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return 0;
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    int n_noisy = ds->n_cores - 1;
    int total = n_noisy * ds->n_gates;
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->len = total; v->cap = total;
    v->data = (long long *)malloc(v->cap * sizeof(long long));
    for (int ci = 0; ci < n_noisy; ci++)
        for (int g = 0; g < ds->n_gates; g++)
            v->data[ci * ds->n_gates + g] = _d_f2i(ds->grad_logits[ds_logit_idx(ds, ci, g)]);
    return (long long)v;
}

void nuc_diff_set_logits(long long handle, long long vec) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return;
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)(void *)vec;
    int n_noisy = ds->n_cores - 1;
    for (int ci = 0; ci < n_noisy; ci++)
        for (int g = 0; g < ds->n_gates && (ci * ds->n_gates + g) < v->len; g++)
            ds->logits[ds_logit_idx(ds, ci, g)] = _d_i2f(v->data[ci * ds->n_gates + g]);
}

void nuc_diff_zero_grad(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return;
    int n_noisy = ds->n_cores - 1;
    memset(ds->grad_logits, 0, n_noisy * DS_MAX_GATES * sizeof(double));
}

void nuc_diff_reset(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return;
    for (int c = 0; c < ds->n_cores; c++) {
        memset(ds_sv(ds, c), 0, ds->n_amps * 2 * sizeof(double));
        ds_sv(ds, c)[0] = 1.0;
    }
    ds->n_gates = 0;
    ds->step = 0;
    memset(ds->ent, 0, sizeof(ds->ent));
}

void nuc_diff_free(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return;
    if (ds->sv) free(ds->sv);
    if (ds->cache) free(ds->cache);
    if (ds->logits) free(ds->logits);
    if (ds->grad_logits) free(ds->grad_logits);
    free(ds);
}

long long nuc_diff_n_gates(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    return ds ? ds->n_gates : 0;
}

// =====================================================
// Per-feature backward — EXACT analytical gradients
// Computes d(feature_f)/d(logit) for each of the 12 features
// using the chain rule through the simulation.
//
// For TV, KL, fidelity: closed-form through probability derivatives
// For entropy: analytical through reduced density matrix eigenvalues
// For features 7-11: zero gradient (clean core / constants)
//
// This matches what PyTorch autograd computes, without autograd.
// =====================================================

// Analytical entropy gradient: d(mean_entropy)/d(p) for a given core at a given gate
// Uses chain rule: entropy → eigenvalues → rho elements → sv amplitudes → noise rate
static double ds_entropy_grad_dp(double *pre_sv, int nq, int na, double p) {
    double inv_sqrt_na = 1.0 / sqrt((double)na);
    double total_d_ent_dp = 0.0;

    for (int q = 0; q < nq; q++) {
        int bit = 1 << q;

        // Compute rho elements AND their derivatives w.r.t. p simultaneously
        double rho00 = 0, rho11 = 0, rho01_re = 0, rho01_im = 0;
        double d_rho00 = 0, d_rho11 = 0, d_rho01_re = 0, d_rho01_im = 0;

        for (int i = 0; i < na; i++) {
            if (i & bit) continue;
            int j = i | bit;

            // Noisy statevector at this noise rate
            double sv_i_re = pre_sv[i*2] * (1.0 - p) + p * inv_sqrt_na;
            double sv_i_im = pre_sv[i*2+1] * (1.0 - p);
            double sv_j_re = pre_sv[j*2] * (1.0 - p) + p * inv_sqrt_na;
            double sv_j_im = pre_sv[j*2+1] * (1.0 - p);

            // d(sv)/d(p)
            double d_i_re = -pre_sv[i*2] + inv_sqrt_na;
            double d_i_im = -pre_sv[i*2+1];
            double d_j_re = -pre_sv[j*2] + inv_sqrt_na;
            double d_j_im = -pre_sv[j*2+1];

            // rho00 += |sv_i|^2, d(rho00)/dp = 2*(sv_i_re*d_i_re + sv_i_im*d_i_im)
            rho00 += sv_i_re*sv_i_re + sv_i_im*sv_i_im;
            d_rho00 += 2.0*(sv_i_re*d_i_re + sv_i_im*d_i_im);

            // rho11 += |sv_j|^2
            rho11 += sv_j_re*sv_j_re + sv_j_im*sv_j_im;
            d_rho11 += 2.0*(sv_j_re*d_j_re + sv_j_im*d_j_im);

            // rho01 += sv_i * conj(sv_j) = (re_i*re_j + im_i*im_j) + i*(im_i*re_j - re_i*im_j)
            rho01_re += sv_i_re*sv_j_re + sv_i_im*sv_j_im;
            rho01_im += sv_i_im*sv_j_re - sv_i_re*sv_j_im;

            // d(rho01_re)/dp
            d_rho01_re += d_i_re*sv_j_re + sv_i_re*d_j_re + d_i_im*sv_j_im + sv_i_im*d_j_im;
            d_rho01_im += d_i_im*sv_j_re + sv_i_im*d_j_re - d_i_re*sv_j_im - sv_i_re*d_j_im;
        }

        // Eigenvalues: lambda = mid +/- off
        // mid = (rho00+rho11)/2, off = sqrt(disc^2 + |rho01|^2)
        double a = rho00, b = rho11, c = rho01_re, d = rho01_im;
        double mid = (a + b) * 0.5;
        double disc = (a - b) * 0.5;
        double off_sq = disc*disc + c*c + d*d;
        double off = sqrt(off_sq + 1e-30);  // protect against zero
        double lam0 = mid + off;
        double lam1 = mid - off;

        // d(mid)/dp = (d_rho00 + d_rho11)/2
        double d_mid = (d_rho00 + d_rho11) * 0.5;
        // d(off)/dp = (disc*d_disc + c*d_c + d*d_d) / off
        double d_disc = (d_rho00 - d_rho11) * 0.5;
        double d_off = (off > 1e-15) ?
            (disc*d_disc + c*d_rho01_re + d*d_rho01_im) / off : 0.0;

        double d_lam0 = d_mid + d_off;
        double d_lam1 = d_mid - d_off;

        // d(S)/d(lambda) = -(1 + log2(lambda)) = -(1 + ln(lambda)/ln(2))
        double d_S = 0;
        double ln2 = 0.6931471805599453;
        if (lam0 > 1e-10) d_S += -(1.0 + log(lam0)/ln2) * d_lam0;
        if (lam1 > 1e-10) d_S += -(1.0 + log(lam1)/ln2) * d_lam1;

        total_d_ent_dp += d_S;
    }

    return nq > 0 ? total_d_ent_dp / nq : 0.0;
}

void nuc_diff_backward_perfeature(long long handle, long long grad_input_vec) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return;
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *grad_input = (NVec *)(void *)grad_input_vec;

    int na = ds->n_amps, nc = ds->n_cores;
    int n_noisy = nc - 1;
    double inv_sqrt_na = 1.0 / sqrt((double)na);
    double eps = 1e-9;
    int n_grad = grad_input->len;

    for (int g = 0; g < ds->n_gates; g++) {
        double lo, hi;
        if (ds->gate_is_2q[g]) { lo = NOISE_2Q_LO; hi = NOISE_2Q_HI; }
        else { lo = NOISE_1Q_LO; hi = NOISE_1Q_HI; }

        for (int ci = 0; ci < n_noisy; ci++) {
            int c = ci + 1;
            int idx = ds_logit_idx(ds, ci, g);
            double logit = ds->logits[idx];
            double sig = 1.0 / (1.0 + exp(-logit));
            double p = lo + sig * (hi - lo);
            double d_p_d_logit = sig * (1.0 - sig) * (hi - lo);

            double *pre = ds_cache(ds, g, c);

            // Precompute noisy probabilities and d(prob)/d(p)
            double prob_noisy[DS_MAX_AMPS], d_prob_dp[DS_MAX_AMPS];
            for (int i = 0; i < na; i++) {
                double sv_re = pre[i*2] * (1.0 - p) + p * inv_sqrt_na;
                double sv_im = pre[i*2+1] * (1.0 - p);
                double d_sv_re = -pre[i*2] + inv_sqrt_na;
                double d_sv_im = -pre[i*2+1];
                prob_noisy[i] = sv_re*sv_re + sv_im*sv_im;
                d_prob_dp[i] = 2.0 * (sv_re * d_sv_re + sv_im * d_sv_im);
            }

            int gi_off = ci * 12;
            if (gi_off + 12 > n_grad) gi_off = 0;

            double total_d_logit = 0;

            // Feature 0: TV distance — analytical
            {
                double g_f = (gi_off < n_grad) ? _d_i2f(grad_input->data[gi_off]) : 0;
                double d_tv = 0;
                for (int i = 0; i < na; i++) {
                    double sign = (ds->cached_probs[i] > prob_noisy[i]) ? -1.0 : 1.0;
                    d_tv += sign * d_prob_dp[i];
                }
                total_d_logit += g_f * d_tv * 0.5 * d_p_d_logit;
            }

            // Feature 1: KL divergence — analytical
            {
                double g_f = (gi_off+1 < n_grad) ? _d_i2f(grad_input->data[gi_off+1]) : 0;
                double d_kl = 0;
                for (int i = 0; i < na; i++)
                    d_kl += -((ds->cached_probs[i]+eps) / (prob_noisy[i]+eps)) * d_prob_dp[i];
                total_d_logit += g_f * d_kl * d_p_d_logit;
            }

            // Feature 2: Fidelity — analytical
            {
                double g_f = (gi_off+2 < n_grad) ? _d_i2f(grad_input->data[gi_off+2]) : 0;
                double d_fid = 0;
                for (int i = 0; i < na; i++) {
                    double pn = prob_noisy[i] + eps;
                    if (pn > eps)
                        d_fid += 0.5 * sqrt(ds->cached_probs[i] / pn) * d_prob_dp[i];
                }
                total_d_logit += g_f * d_fid * d_p_d_logit;
            }

            // Features 3-6: Entropy divergences — EXACT analytical gradient
            {
                double g3 = (gi_off+3 < n_grad) ? _d_i2f(grad_input->data[gi_off+3]) : 0;
                double g4 = (gi_off+4 < n_grad) ? _d_i2f(grad_input->data[gi_off+4]) : 0;
                double g5 = (gi_off+5 < n_grad) ? _d_i2f(grad_input->data[gi_off+5]) : 0;
                double g6 = (gi_off+6 < n_grad) ? _d_i2f(grad_input->data[gi_off+6]) : 0;

                double ent_grad_mag = fabs(g3) + fabs(g4) + fabs(g5) + fabs(g6);
                if (ent_grad_mag > 1e-10) {
                    // Exact analytical entropy gradient
                    double d_ent_dp = ds_entropy_grad_dp(pre, ds->nq, na, p);

                    // mean_ent_div: this gate contributes 1/n_steps to the mean
                    double n_steps = (double)ds->n_gates;
                    total_d_logit += g3 * (d_ent_dp / n_steps) * d_p_d_logit;

                    // max_ent_div: only contributes if this step IS the max
                    // We don't track which step is max, so weight by 1/n_steps as approximation
                    total_d_logit += g4 * (d_ent_dp / n_steps) * d_p_d_logit;

                    // final_ent_div: only the LAST gate contributes
                    if (g == ds->n_gates - 1)
                        total_d_logit += g5 * d_ent_dp * d_p_d_logit;

                    // slope: d(slope)/d(ent_at_step_g) = (g - mean_step) / sum((s-mean)^2)
                    if (n_steps > 1) {
                        double step_mean = (n_steps - 1.0) * 0.5;
                        double sum_sq = 0;
                        for (int s = 0; s < (int)n_steps; s++) {
                            double d = s - step_mean;
                            sum_sq += d * d;
                        }
                        if (sum_sq > 1e-15) {
                            double slope_coeff = ((double)g - step_mean) / sum_sq;
                            total_d_logit += g6 * slope_coeff * d_ent_dp * d_p_d_logit;
                        }
                    }
                }
            }

            // Features 7-11: zero gradient (clean core entropy, sparsity, nq, nsteps)

            ds->grad_logits[idx] += total_d_logit;
        }
    }
}

// =====================================================
// N3: Clean-core caching (toggleable)
// Cache core 0's statevector after simulation. On subsequent resets,
// restore from cache instead of re-simulating. Only recompute noisy cores.
// =====================================================
static double *_clean_cache_sv = NULL;
static double *_clean_cache_ent = NULL;  // [DS_MAX_GATES] entropy per step
static int _clean_cache_nq = 0;
static int _clean_cache_n_gates = 0;
static int _clean_cache_valid = 0;

void nuc_diff_cache_clean(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return;
    int na = ds->n_amps;
    if (_clean_cache_sv) free(_clean_cache_sv);
    if (_clean_cache_ent) free(_clean_cache_ent);
    _clean_cache_sv = (double *)malloc(na * 2 * sizeof(double));
    _clean_cache_ent = (double *)malloc(DS_MAX_GATES * sizeof(double));
    memcpy(_clean_cache_sv, ds_sv(ds, 0), na * 2 * sizeof(double));
    for (int s = 0; s < ds->n_gates; s++)
        _clean_cache_ent[s] = ds->ent[s][0];
    _clean_cache_nq = ds->nq;
    _clean_cache_n_gates = ds->n_gates;
    _clean_cache_valid = 1;
}

// Reset but restore clean core from cache (skips core 0 simulation)
// Returns 1 if cache was used, 0 if not (caller must re-simulate core 0)
long long nuc_diff_reset_cached(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return 0;

    // Reset noisy cores
    for (int c = 1; c < ds->n_cores; c++) {
        memset(ds_sv(ds, c), 0, ds->n_amps * 2 * sizeof(double));
        ds_sv(ds, c)[0] = 1.0;
    }
    ds->n_gates = 0;
    ds->step = 0;
    memset(ds->ent, 0, sizeof(ds->ent));

    if (_clean_cache_valid && _clean_cache_nq == ds->nq) {
        // Restore core 0 from cache
        memcpy(ds_sv(ds, 0), _clean_cache_sv, ds->n_amps * 2 * sizeof(double));
        return 1;  // cache hit
    } else {
        // No cache — reset core 0 too
        memset(ds_sv(ds, 0), 0, ds->n_amps * 2 * sizeof(double));
        ds_sv(ds, 0)[0] = 1.0;
        return 0;  // cache miss
    }
}

// =====================================================
// N4: Gate importance scoring (toggleable)
// Returns a Vec of per-gate importance scores based on
// how much each gate changes the entropy of the clean core.
// Gates with high importance contribute more to the output;
// gates with low importance can be skipped in backward.
// =====================================================
long long nuc_diff_gate_importance(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return 0;
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */

    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->len = ds->n_gates; v->cap = ds->n_gates;
    v->data = (long long *)malloc(v->cap * sizeof(long long));

    for (int g = 0; g < ds->n_gates; g++) {
        // Importance = abs(entropy change at this step for clean core)
        double prev_ent = (g > 0) ? ds->ent[g-1][0] : 0.0;
        double curr_ent = ds->ent[g][0];
        double importance = fabs(curr_ent - prev_ent);
        // Also factor in noise divergence across cores
        double max_div = 0;
        for (int c = 1; c < ds->n_cores; c++) {
            double div = fabs(ds->ent[g][c] - ds->ent[g][0]);
            if (div > max_div) max_div = div;
        }
        importance += max_div;
        v->data[g] = _d_f2i(importance);
    }
    return (long long)v;
}

// Selective backward: only compute gradients for gates above threshold
void nuc_diff_backward_selective(long long handle, long long grad_loss_bits, long long threshold_bits) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return;
    double grad_loss = _d_i2f(grad_loss_bits);
    double threshold = _d_i2f(threshold_bits);
    int na = ds->n_amps, nc = ds->n_cores;
    int n_noisy = nc - 1;
    double inv_sqrt_na = 1.0 / sqrt((double)na);

    for (int g = 0; g < ds->n_gates; g++) {
        // Check importance
        double prev_ent = (g > 0) ? ds->ent[g-1][0] : 0.0;
        double importance = fabs(ds->ent[g][0] - prev_ent);
        for (int c = 1; c < nc; c++) {
            double div = fabs(ds->ent[g][c] - ds->ent[g][0]);
            if (div > importance) importance = div;
        }
        if (importance < threshold) continue;  // skip unimportant gates

        double lo, hi;
        for (int ci = 0; ci < n_noisy; ci++) {
            int c = ci + 1;
            int idx = ds_logit_idx(ds, ci, g);
            if (ds->gate_is_2q[g]) { lo = NOISE_2Q_LO; hi = NOISE_2Q_HI; }
            else { lo = NOISE_1Q_LO; hi = NOISE_1Q_HI; }

            double logit = ds->logits[idx];
            double sig = 1.0 / (1.0 + exp(-logit));
            double p = lo + sig * (hi - lo);
            double *pre = ds_cache(ds, g, c);

            double d_tv_d_p = 0;
            for (int i = 0; i < na; i++) {
                double d_sv_re = -pre[i*2] + inv_sqrt_na;
                double d_sv_im = -pre[i*2+1];
                double sv_noisy_re = pre[i*2] * (1.0 - p) + p * inv_sqrt_na;
                double sv_noisy_im = pre[i*2+1] * (1.0 - p);
                double d_prob = 2.0 * (sv_noisy_re * d_sv_re + sv_noisy_im * d_sv_im);
                double p_clean = ds->cached_probs[i];
                double p_noisy = sv_noisy_re*sv_noisy_re + sv_noisy_im*sv_noisy_im;
                double sign = (p_clean > p_noisy) ? -1.0 : 1.0;
                d_tv_d_p += sign * d_prob;
            }
            d_tv_d_p *= 0.5;
            double d_p_d_logit = sig * (1.0 - sig) * (hi - lo);
            ds->grad_logits[idx] += grad_loss * d_tv_d_p * d_p_d_logit;
        }
    }
}

// =====================================================
// N6: Noise prior export/import
// Export learned logit distribution as a prior for new circuits.
// Returns a Vec with [mean_logit_1q, std_logit_1q, mean_logit_2q, std_logit_2q]
// =====================================================
long long nuc_diff_export_prior(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return 0;
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */

    int n_noisy = ds->n_cores - 1;
    double sum_1q = 0, sum_2q = 0, ssq_1q = 0, ssq_2q = 0;
    int n_1q = 0, n_2q = 0;

    for (int g = 0; g < ds->n_gates; g++) {
        for (int c = 0; c < n_noisy; c++) {
            double logit = ds->logits[ds_logit_idx(ds, c, g)];
            if (ds->gate_is_2q[g]) {
                sum_2q += logit; ssq_2q += logit * logit; n_2q++;
            } else {
                sum_1q += logit; ssq_1q += logit * logit; n_1q++;
            }
        }
    }

    double mean_1q = n_1q > 0 ? sum_1q / n_1q : -5.5;
    double mean_2q = n_2q > 0 ? sum_2q / n_2q : -4.0;
    double std_1q = n_1q > 1 ? sqrt((ssq_1q - sum_1q*sum_1q/n_1q) / (n_1q - 1)) : 0.5;
    double std_2q = n_2q > 1 ? sqrt((ssq_2q - sum_2q*sum_2q/n_2q) / (n_2q - 1)) : 0.5;

    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->len = 4; v->cap = 4;
    v->data = (long long *)malloc(4 * sizeof(long long));
    v->data[0] = _d_f2i(mean_1q);
    v->data[1] = _d_f2i(std_1q);
    v->data[2] = _d_f2i(mean_2q);
    v->data[3] = _d_f2i(std_2q);
    return (long long)v;
}

// Init from a prior: use learned mean/std instead of default init
long long nuc_diff_sim_init_from_prior(long long nq, long long n_cores, long long prior_vec, long long seed) {
    // First init normally with diversified mode
    long long handle = nuc_diff_sim_init(nq, n_cores, 1, seed);
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return 0;

    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *prior = (NVec *)(void *)prior_vec;
    if (!prior || prior->len < 4) return handle;

    double mean_1q = _d_i2f(prior->data[0]);
    double std_1q = _d_i2f(prior->data[1]);
    double mean_2q = _d_i2f(prior->data[2]);
    double std_2q = _d_i2f(prior->data[3]);

    int n_noisy = ds->n_cores - 1;
    for (int c = 0; c < n_noisy; c++) {
        for (int g = 0; g < DS_MAX_GATES; g++) {
            // Use prior distribution + per-core diversification
            double base_1q = mean_1q + c * 0.2 * std_1q + ds_randn(ds) * std_1q * 0.3;
            ds->logits[ds_logit_idx(ds, c, g)] = base_1q;
        }
    }
    return handle;
}

// =====================================================
// N7: Progressive core scaling
// Resize a simulation to use more cores. Copies existing logits
// to the first N-1 cores, initializes new cores by diversifying.
// =====================================================
long long nuc_diff_resize_cores(long long handle, long long new_n_cores) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return 0;
    int new_nc = (int)new_n_cores;
    if (new_nc > DS_MAX_CORES) new_nc = DS_MAX_CORES;
    if (new_nc <= ds->n_cores) return handle;  // can't shrink

    int old_noisy = ds->n_cores - 1;
    int new_noisy = new_nc - 1;
    int na = ds->n_amps;

    // Reallocate statevectors
    double *new_sv = (double *)calloc((long long)new_nc * na * 2, sizeof(double));
    memcpy(new_sv, ds->sv, (long long)ds->n_cores * na * 2 * sizeof(double));
    // Init new cores to |0>
    for (int c = ds->n_cores; c < new_nc; c++)
        new_sv[c * na * 2] = 1.0;
    free(ds->sv);
    ds->sv = new_sv;

    // Reallocate cache
    long long new_cache_size = (long long)DS_MAX_GATES * new_nc * na * 2;
    double *new_cache = (double *)calloc(new_cache_size, sizeof(double));
    // Copy existing cache
    for (int g = 0; g < ds->n_gates; g++)
        for (int c = 0; c < ds->n_cores; c++)
            memcpy(new_cache + ((long long)g * new_nc + c) * na * 2,
                   ds_cache(ds, g, c), na * 2 * sizeof(double));
    free(ds->cache);
    ds->cache = new_cache;

    // Reallocate logits
    double *new_logits = (double *)calloc(new_noisy * DS_MAX_GATES, sizeof(double));
    double *new_grad = (double *)calloc(new_noisy * DS_MAX_GATES, sizeof(double));
    // Copy existing logits
    for (int c = 0; c < old_noisy; c++)
        for (int g = 0; g < DS_MAX_GATES; g++)
            new_logits[c * DS_MAX_GATES + g] = ds->logits[ds_logit_idx(ds, c, g)];
    // Init new cores by diversifying from existing
    for (int c = old_noisy; c < new_noisy; c++) {
        int src = c % old_noisy;  // copy from existing core
        for (int g = 0; g < DS_MAX_GATES; g++) {
            new_logits[c * DS_MAX_GATES + g] =
                ds->logits[ds_logit_idx(ds, src, g)] + ds_randn(ds) * 0.2;
        }
    }
    free(ds->logits);
    free(ds->grad_logits);
    ds->logits = new_logits;
    ds->grad_logits = new_grad;
    ds->n_cores = new_nc;

    return handle;
}

// Return number of noisy cores
long long nuc_diff_n_noisy(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    return ds ? ds->n_cores - 1 : 0;
}

// Return total logit count (for Adam allocation)
long long nuc_diff_logit_count(long long handle) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    return ds ? (ds->n_cores - 1) * ds->n_gates : 0;
}

// =====================================================
// Statevector and probability extraction for VQE
// =====================================================

// Return statevector amplitudes (interleaved re/im) for a core
long long nuc_diff_get_sv(long long handle, long long core) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return 0;
    int c = (int)core;
    if (c < 0 || c >= ds->n_cores) return 0;
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->cap = ds->n_amps * 2 + 4;
    v->len = 0;
    v->data = (long long *)malloc(v->cap * sizeof(long long));
    double *sv = ds_sv(ds, c);
    for (int i = 0; i < ds->n_amps * 2; i++) {
        long long bits;
        memcpy(&bits, &sv[i], sizeof(double));
        v->data[v->len++] = bits;
    }
    return (long long)(void *)v;
}

// Return probability distribution |a|^2 for a core
long long nuc_diff_get_probs(long long handle, long long core) {
    DiffSim *ds = (DiffSim *)(void *)handle;
    if (!ds) return 0;
    int c = (int)core;
    if (c < 0 || c >= ds->n_cores) return 0;
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->cap = ds->n_amps + 4;
    v->len = 0;
    v->data = (long long *)malloc(v->cap * sizeof(long long));
    double *sv = ds_sv(ds, c);
    for (int i = 0; i < ds->n_amps; i++) {
        double prob = sv[i*2]*sv[i*2] + sv[i*2+1]*sv[i*2+1];
        long long bits;
        memcpy(&bits, &prob, sizeof(double));
        v->data[v->len++] = bits;
    }
    return (long long)(void *)v;
}
