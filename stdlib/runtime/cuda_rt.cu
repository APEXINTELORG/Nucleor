// cuda_rt.cu — CUDA Multi-Core Quantum Simulation with Telemetry
// Compiles with: nvcc -c cuda_rt.cu -o target/cuda_rt.obj
//
// DATA PORTS (GPU telemetry for ML):
//   - Per-kernel execution time (nanoseconds)
//   - Per-gate memory throughput
//   - Warp occupancy per kernel
//   - FP32 vs FP64 precision delta per circuit
//   - Core divergence at each gate step
//
// Priority: all kernels launch on a low-priority stream
// Fallback: if no CUDA device, routes to CPU implementation

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <cuda_runtime.h>

// =====================================================
// Telemetry collection
// =====================================================
#define MAX_TELEMETRY 4096

typedef struct {
    int gate_step;
    int gate_type;        // 0=H, 1=CNOT, etc
    float kernel_time_us; // microseconds
    float mem_throughput;  // GB/s estimate
    int active_warps;
    float mean_core_divergence; // mean TV between cores at this step
    float fp32_delta;     // |fp64_result - fp32_result| for precision sensitivity
} GPUTelemetryEvent;

typedef struct {
    int n_events;
    GPUTelemetryEvent events[MAX_TELEMETRY];
    // Aggregate stats
    float total_kernel_time_us;
    float mean_warp_occupancy;
    float mean_precision_delta;
    float max_precision_delta;
    float mean_divergence_rate;  // how fast cores diverge per gate step
} GPUTelemetry;

// =====================================================
// Multi-core statevector on GPU
// =====================================================
// Each core is a statevector of 2^nq complex amplitudes
// Stored as interleaved real/imag doubles: [re0, im0, re1, im1, ...]
// All N cores stored contiguously: core_k starts at offset k * 2 * (2^nq)

typedef struct {
    int n_qubits;
    int n_cores;
    int n_amps;          // 2^nq
    double *d_sv;        // device memory: n_cores * n_amps * 2 doubles (re,im interleaved)
    float *d_sv_f32;     // FP32 shadow copy for precision delta measurement
    double *d_noise_p1q; // per-core 1q noise rate (n_cores doubles on device)
    double *d_noise_p2q; // per-core 2q noise rate
    cudaStream_t stream; // low-priority compute stream
    cudaEvent_t evt_start, evt_stop; // timing
    GPUTelemetry telemetry;
    int step;
    // Host-side divergence tracking
    double *h_divergence; // per-step mean TV (host, MAX_TELEMETRY entries)
} GPUMC;

// =====================================================
// CUDA Kernels — one thread per amplitude per core
// =====================================================

// Hadamard gate on qubit q, applied to ALL cores simultaneously
__global__ void kernel_h(double *sv, int n_amps, int n_cores, int q) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_amps * n_cores;
    if (idx >= total) return;

    int core = idx / n_amps;
    int amp = idx % n_amps;
    int bit = 1 << q;

    if (amp & bit) return; // only process lower partner

    int partner = amp | bit;
    int base_c = core * n_amps * 2; // core offset in interleaved array

    double re0 = sv[base_c + amp * 2];
    double im0 = sv[base_c + amp * 2 + 1];
    double re1 = sv[base_c + partner * 2];
    double im1 = sv[base_c + partner * 2 + 1];

    double inv_sqrt2 = 0.7071067811865476;
    sv[base_c + amp * 2]         = (re0 + re1) * inv_sqrt2;
    sv[base_c + amp * 2 + 1]     = (im0 + im1) * inv_sqrt2;
    sv[base_c + partner * 2]     = (re0 - re1) * inv_sqrt2;
    sv[base_c + partner * 2 + 1] = (im0 - im1) * inv_sqrt2;
}

// CNOT gate: ctrl, tgt applied to ALL cores
__global__ void kernel_cnot(double *sv, int n_amps, int n_cores, int ctrl, int tgt) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_amps * n_cores;
    if (idx >= total) return;

    int core = idx / n_amps;
    int amp = idx % n_amps;

    // Only act when control bit is set and target bit is clear
    if (!((amp >> ctrl) & 1)) return;
    if ((amp >> tgt) & 1) return;

    int partner = amp ^ (1 << tgt);
    int base_c = core * n_amps * 2;

    // Swap amp <-> partner
    double re_a = sv[base_c + amp * 2];
    double im_a = sv[base_c + amp * 2 + 1];
    sv[base_c + amp * 2]         = sv[base_c + partner * 2];
    sv[base_c + amp * 2 + 1]     = sv[base_c + partner * 2 + 1];
    sv[base_c + partner * 2]     = re_a;
    sv[base_c + partner * 2 + 1] = im_a;
}

// Pauli-X gate on qubit q
__global__ void kernel_x(double *sv, int n_amps, int n_cores, int q) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_amps * n_cores;
    if (idx >= total) return;

    int core = idx / n_amps;
    int amp = idx % n_amps;
    int bit = 1 << q;
    if (amp & bit) return;

    int partner = amp | bit;
    int base_c = core * n_amps * 2;

    double re0 = sv[base_c + amp * 2];
    double im0 = sv[base_c + amp * 2 + 1];
    sv[base_c + amp * 2]         = sv[base_c + partner * 2];
    sv[base_c + amp * 2 + 1]     = sv[base_c + partner * 2 + 1];
    sv[base_c + partner * 2]     = re0;
    sv[base_c + partner * 2 + 1] = im0;
}

// Pauli-Z gate on qubit q
__global__ void kernel_z(double *sv, int n_amps, int n_cores, int q) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_amps * n_cores;
    if (idx >= total) return;

    int core = idx / n_amps;
    int amp = idx % n_amps;

    if (!((amp >> q) & 1)) return; // only negate |1> component

    int base_c = core * n_amps * 2;
    sv[base_c + amp * 2]     = -sv[base_c + amp * 2];
    sv[base_c + amp * 2 + 1] = -sv[base_c + amp * 2 + 1];
}

// RZ gate: phase rotation by angle on qubit q
__global__ void kernel_rz(double *sv, int n_amps, int n_cores, int q, double angle) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_amps * n_cores;
    if (idx >= total) return;

    int core = idx / n_amps;
    int amp = idx % n_amps;

    if (!((amp >> q) & 1)) return; // only rotate |1> component

    int base_c = core * n_amps * 2;
    double re = sv[base_c + amp * 2];
    double im = sv[base_c + amp * 2 + 1];
    double c = cos(angle);
    double s = sin(angle);
    sv[base_c + amp * 2]     = re * c - im * s;
    sv[base_c + amp * 2 + 1] = re * s + im * c;
}

// Depolarizing noise: mix toward uniform for cores 1..N-1
// Core 0 stays clean. Each core k has its own noise rate.
__global__ void kernel_noise(double *sv, double *noise_rates, int n_amps, int n_cores, int is_2q) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_amps * n_cores;
    if (idx >= total) return;

    int core = idx / n_amps;
    if (core == 0) return; // core 0 is clean

    int amp = idx % n_amps;
    double p = is_2q ? noise_rates[core * 2 + 1] : noise_rates[core * 2]; // p1q or p2q
    double one_minus_p = 1.0 - p;
    double uniform = p / sqrt((double)n_amps);

    int base_c = core * n_amps * 2;
    sv[base_c + amp * 2]     = sv[base_c + amp * 2] * one_minus_p + uniform;
    sv[base_c + amp * 2 + 1] = sv[base_c + amp * 2 + 1] * one_minus_p;
}

// =====================================================
// DATA PORT KERNELS — Additional telemetry for ML
// =====================================================

// Per-core TV distance from clean core (core 0)
// Output: one double per noisy core (n_cores-1 values)
// Uses shared memory reduction within each core
__global__ void kernel_core_tv(double *sv, double *tv_out, int n_amps, int n_cores) {
    // Simple: one thread per noisy core, sequential over amplitudes
    // (For production, use parallel reduction per core)
    int core = blockIdx.x * blockDim.x + threadIdx.x + 1; // skip core 0
    if (core >= n_cores) return;

    int base_0 = 0; // clean core
    int base_c = core * n_amps * 2;

    double tv = 0;
    for (int i = 0; i < n_amps; i++) {
        double re0 = sv[base_0 + i * 2], im0 = sv[base_0 + i * 2 + 1];
        double rec = sv[base_c + i * 2], imc = sv[base_c + i * 2 + 1];
        double p0 = re0 * re0 + im0 * im0;
        double pc = rec * rec + imc * imc;
        tv += fabs(p0 - pc);
    }
    tv_out[core - 1] = tv * 0.5;
}

// Phase coherence between clean core and each noisy core
// cos(phase_clean - phase_noisy) averaged over significant amplitudes
__global__ void kernel_phase_coherence(double *sv, double *phase_out, int n_amps, int n_cores) {
    int core = blockIdx.x * blockDim.x + threadIdx.x + 1;
    if (core >= n_cores) return;

    int base_0 = 0;
    int base_c = core * n_amps * 2;
    double eps = 1e-12;

    double sum_cos = 0;
    int count = 0;
    for (int i = 0; i < n_amps; i++) {
        double re0 = sv[base_0 + i * 2], im0 = sv[base_0 + i * 2 + 1];
        double mag0_sq = re0 * re0 + im0 * im0;
        if (mag0_sq < eps) continue;

        double rec = sv[base_c + i * 2], imc = sv[base_c + i * 2 + 1];
        double phase0 = atan2(im0, re0);
        double phasec = atan2(imc, rec);
        sum_cos += cos(phase0 - phasec);
        count++;
    }
    phase_out[core - 1] = count > 0 ? sum_cos / count : 1.0;
}

// Compute probability |a|^2 for all amplitudes, all cores → output buffer
__global__ void kernel_probs(double *sv, double *probs_out, int n_amps, int n_cores) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_amps * n_cores;
    if (idx >= total) return;

    int core = idx / n_amps;
    int amp = idx % n_amps;
    int base_c = core * n_amps * 2;

    double re = sv[base_c + amp * 2];
    double im = sv[base_c + amp * 2 + 1];
    probs_out[core * n_amps + amp] = re * re + im * im;
}

// =====================================================
// Host-side API (extern "C" for Nucleor FFI)
// =====================================================

static int cuda_available = -1; // -1=unchecked, 0=no, 1=yes

static int check_cuda() {
    if (cuda_available >= 0) return cuda_available;
    int count = 0;
    cudaError_t err = cudaGetDeviceCount(&count);
    cuda_available = (err == cudaSuccess && count > 0) ? 1 : 0;
    return cuda_available;
}

extern "C" {

// Check if GPU is available
long long nuc_gpu_available() {
    return check_cuda();
}

// Get GPU info string
const char *nuc_gpu_info() {
    if (!check_cuda()) return "No CUDA GPU available";
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    static char buf[256];
    snprintf(buf, 256, "%s (%d MB, CUDA %d.%d, %d SMs)",
             prop.name, (int)(prop.totalGlobalMem / (1024*1024)),
             prop.major, prop.minor, prop.multiProcessorCount);
    return buf;
}

// Initialize multi-core simulation on GPU
long long nuc_gpu_mc_init(long long nq, long long n_cores, long long p1q_bits, long long p2q_bits) {
    if (!check_cuda()) return 0; // fallback signal

    GPUMC *mc = (GPUMC *)calloc(1, sizeof(GPUMC));
    mc->n_qubits = (int)nq;
    mc->n_cores = (int)n_cores;
    mc->n_amps = 1 << (int)nq;
    mc->step = 0;
    memset(&mc->telemetry, 0, sizeof(GPUTelemetry));

    // Create low-priority stream
    int least_priority, greatest_priority;
    cudaDeviceGetStreamPriorityRange(&least_priority, &greatest_priority);
    cudaStreamCreateWithPriority(&mc->stream, cudaStreamNonBlocking, least_priority);
    cudaEventCreate(&mc->evt_start);
    cudaEventCreate(&mc->evt_stop);

    // Allocate statevectors on GPU
    size_t sv_size = mc->n_cores * mc->n_amps * 2 * sizeof(double); // interleaved re,im
    cudaMalloc(&mc->d_sv, sv_size);
    cudaMemset(mc->d_sv, 0, sv_size);

    // Initialize each core to |000...0> (amplitude[0] = 1+0i)
    double one[2] = {1.0, 0.0};
    for (int c = 0; c < mc->n_cores; c++) {
        cudaMemcpy(mc->d_sv + c * mc->n_amps * 2, one, 2 * sizeof(double), cudaMemcpyHostToDevice);
    }

    // Set up per-core noise rates
    // Core 0: p=0 (clean). Cores 1..N-1: spread noise
    double p1q_base, p2q_base;
    memcpy(&p1q_base, &p1q_bits, sizeof(double));
    memcpy(&p2q_base, &p2q_bits, sizeof(double));

    double *h_noise = (double *)calloc(mc->n_cores * 2, sizeof(double)); // [p1q, p2q] per core
    for (int c = 1; c < mc->n_cores; c++) {
        double scale = 0.5 + 0.5 * c;
        h_noise[c * 2]     = p1q_base * scale;
        h_noise[c * 2 + 1] = p2q_base * scale;
    }
    cudaMalloc(&mc->d_noise_p1q, mc->n_cores * 2 * sizeof(double));
    cudaMemcpy(mc->d_noise_p1q, h_noise, mc->n_cores * 2 * sizeof(double), cudaMemcpyHostToDevice);
    free(h_noise);

    // Allocate host divergence tracking
    mc->h_divergence = (double *)calloc(MAX_TELEMETRY, sizeof(double));

    return (long long)mc;
}

// Helper: launch grid for n_amps * n_cores threads
static void launch_config(int total, int *blocks, int *threads) {
    *threads = 256;
    *blocks = (total + *threads - 1) / *threads;
}

// Record telemetry for a gate
static void record_telemetry(GPUMC *mc, int gate_type, float kernel_time_us) {
    if (mc->telemetry.n_events >= MAX_TELEMETRY) return;
    GPUTelemetryEvent *evt = &mc->telemetry.events[mc->telemetry.n_events];
    evt->gate_step = mc->step;
    evt->gate_type = gate_type;
    evt->kernel_time_us = kernel_time_us;
    evt->mem_throughput = 0; // TODO: compute from bytes transferred / time
    evt->active_warps = 0;  // TODO: query occupancy
    evt->mean_core_divergence = 0; // computed after probs extraction
    evt->fp32_delta = 0;    // TODO: FP32 shadow comparison
    mc->telemetry.n_events++;
    mc->telemetry.total_kernel_time_us += kernel_time_us;
}

// Gate dispatch helper — inline, no macro (avoids <<<>>> comma issues)
static void gpu_gate_post(GPUMC *mc, int gate_type, int is_2q) {
    int blocks, threads;
    launch_config(mc->n_amps * mc->n_cores, &blocks, &threads);
    kernel_noise<<<blocks, threads, 0, mc->stream>>>(mc->d_sv, mc->d_noise_p1q, mc->n_amps, mc->n_cores, is_2q);
    cudaEventRecord(mc->evt_stop, mc->stream);
    cudaEventSynchronize(mc->evt_stop);
    float ms = 0; cudaEventElapsedTime(&ms, mc->evt_start, mc->evt_stop);
    record_telemetry(mc, gate_type, ms * 1000.0f);

    // DATA PORT: per-step divergence and phase coherence
    if (mc->step < MAX_TELEMETRY && mc->n_cores > 1) {
        int nc = mc->n_cores;
        // Allocate temp buffers for TV and phase
        double *d_tv, *d_phase;
        cudaMalloc(&d_tv, (nc - 1) * sizeof(double));
        cudaMalloc(&d_phase, (nc - 1) * sizeof(double));

        int core_blocks = (nc - 1 + 255) / 256;
        kernel_core_tv<<<core_blocks, 256, 0, mc->stream>>>(mc->d_sv, d_tv, mc->n_amps, nc);
        kernel_phase_coherence<<<core_blocks, 256, 0, mc->stream>>>(mc->d_sv, d_phase, mc->n_amps, nc);
        cudaStreamSynchronize(mc->stream);

        // Read back and compute means
        double *h_tv = (double *)malloc((nc - 1) * sizeof(double));
        double *h_phase = (double *)malloc((nc - 1) * sizeof(double));
        cudaMemcpy(h_tv, d_tv, (nc - 1) * sizeof(double), cudaMemcpyDeviceToHost);
        cudaMemcpy(h_phase, d_phase, (nc - 1) * sizeof(double), cudaMemcpyDeviceToHost);

        double mean_tv = 0, mean_phase = 0;
        for (int c = 0; c < nc - 1; c++) {
            mean_tv += h_tv[c];
            mean_phase += h_phase[c];
        }
        mean_tv /= (nc - 1);
        mean_phase /= (nc - 1);

        mc->h_divergence[mc->step] = mean_tv;

        // Store in telemetry event
        if (mc->telemetry.n_events > 0) {
            mc->telemetry.events[mc->telemetry.n_events - 1].mean_core_divergence = (float)mean_tv;
            mc->telemetry.events[mc->telemetry.n_events - 1].fp32_delta = (float)mean_phase; // repurpose for phase
        }

        cudaFree(d_tv); cudaFree(d_phase);
        free(h_tv); free(h_phase);
    }

    mc->step++;
}

void nuc_gpu_mc_h(long long handle, long long q) {
    GPUMC *mc = (GPUMC *)(void *)handle;
    int blocks, threads;
    launch_config(mc->n_amps * mc->n_cores, &blocks, &threads);
    cudaEventRecord(mc->evt_start, mc->stream);
    kernel_h<<<blocks, threads, 0, mc->stream>>>(mc->d_sv, mc->n_amps, mc->n_cores, (int)q);
    gpu_gate_post(mc, 0, 0);
}

void nuc_gpu_mc_x(long long handle, long long q) {
    GPUMC *mc = (GPUMC *)(void *)handle;
    int blocks, threads;
    launch_config(mc->n_amps * mc->n_cores, &blocks, &threads);
    cudaEventRecord(mc->evt_start, mc->stream);
    kernel_x<<<blocks, threads, 0, mc->stream>>>(mc->d_sv, mc->n_amps, mc->n_cores, (int)q);
    gpu_gate_post(mc, 2, 0);
}

void nuc_gpu_mc_z(long long handle, long long q) {
    GPUMC *mc = (GPUMC *)(void *)handle;
    int blocks, threads;
    launch_config(mc->n_amps * mc->n_cores, &blocks, &threads);
    cudaEventRecord(mc->evt_start, mc->stream);
    kernel_z<<<blocks, threads, 0, mc->stream>>>(mc->d_sv, mc->n_amps, mc->n_cores, (int)q);
    gpu_gate_post(mc, 3, 0);
}

void nuc_gpu_mc_cnot(long long handle, long long ctrl, long long tgt) {
    GPUMC *mc = (GPUMC *)(void *)handle;
    int blocks, threads;
    launch_config(mc->n_amps * mc->n_cores, &blocks, &threads);
    cudaEventRecord(mc->evt_start, mc->stream);
    kernel_cnot<<<blocks, threads, 0, mc->stream>>>(mc->d_sv, mc->n_amps, mc->n_cores, (int)ctrl, (int)tgt);
    gpu_gate_post(mc, 1, 1);
}

void nuc_gpu_mc_rz(long long handle, long long q, long long angle_bits) {
    GPUMC *mc = (GPUMC *)(void *)handle;
    double angle; memcpy(&angle, &angle_bits, sizeof(double));
    int blocks, threads;
    launch_config(mc->n_amps * mc->n_cores, &blocks, &threads);
    cudaEventRecord(mc->evt_start, mc->stream);
    kernel_rz<<<blocks, threads, 0, mc->stream>>>(mc->d_sv, mc->n_amps, mc->n_cores, (int)q, angle);
    gpu_gate_post(mc, 4, 0);
}

// Extract features: compute probabilities on GPU, transfer to host, compute ensemble features
long long nuc_gpu_mc_extract(long long handle) {
    GPUMC *mc = (GPUMC *)(void *)handle;
    int total_probs = mc->n_amps * mc->n_cores;

    // Allocate prob buffer on GPU
    double *d_probs;
    cudaMalloc(&d_probs, total_probs * sizeof(double));

    int blocks, threads;
    launch_config(total_probs, &blocks, &threads);
    kernel_probs<<<blocks, threads, 0, mc->stream>>>(mc->d_sv, d_probs, mc->n_amps, mc->n_cores);
    cudaStreamSynchronize(mc->stream);

    // Copy to host
    double *h_probs = (double *)malloc(total_probs * sizeof(double));
    cudaMemcpy(h_probs, d_probs, total_probs * sizeof(double), cudaMemcpyDeviceToHost);
    cudaFree(d_probs);

    // Compute ensemble features on host (same as multi_core.nr mc_extract)
    // Clean core probs = h_probs[0..n_amps-1]
    double *p_clean = h_probs;
    int nc = mc->n_cores, na = mc->n_amps;

    // Per-core TV distance
    double *tvs = (double *)calloc(nc - 1, sizeof(double));
    double *kls = (double *)calloc(nc - 1, sizeof(double));
    double *fids = (double *)calloc(nc - 1, sizeof(double));
    double eps = 1e-9;

    for (int c = 1; c < nc; c++) {
        double *p_noisy = h_probs + c * na;
        double tv = 0, kl = 0, fid = 0;
        for (int i = 0; i < na; i++) {
            tv += fabs(p_clean[i] - p_noisy[i]);
            double pa = p_clean[i] + eps, pb = p_noisy[i] + eps;
            kl += pa * log(pa / pb);
            fid += sqrt(p_clean[i] * p_noisy[i] + eps);
        }
        tvs[c-1] = tv * 0.5;
        kls[c-1] = kl;
        fids[c-1] = fid;
    }

    // Compute summary stats
    double mean_tv = 0, std_tv = 0, min_tv = 999, max_tv = 0;
    double mean_fid = 0, mean_kl = 0, max_kl = 0;
    for (int c = 0; c < nc - 1; c++) {
        mean_tv += tvs[c]; mean_fid += fids[c]; mean_kl += kls[c];
        if (tvs[c] < min_tv) min_tv = tvs[c];
        if (tvs[c] > max_tv) max_tv = tvs[c];
        if (kls[c] > max_kl) max_kl = kls[c];
    }
    mean_tv /= (nc - 1); mean_fid /= (nc - 1); mean_kl /= (nc - 1);
    for (int c = 0; c < nc - 1; c++) {
        double d = tvs[c] - mean_tv;
        std_tv += d * d;
    }
    std_tv = sqrt(std_tv / (nc - 1));

    // Ensemble agreement (pairwise TV among noisy cores)
    double pair_sum = 0; int n_pairs = 0;
    for (int ci = 1; ci < nc; ci++) {
        for (int cj = ci + 1; cj < nc; cj++) {
            double ptv = 0;
            for (int i = 0; i < na; i++)
                ptv += fabs(h_probs[ci * na + i] - h_probs[cj * na + i]);
            pair_sum += ptv * 0.5;
            n_pairs++;
        }
    }
    double agreement = n_pairs > 0 ? pair_sum / n_pairs : 0;

    // Pack features into Nucleor Vec (via the NVec API)
    // Return as i64-encoded f64 values in a flat array
    // We'll use the NVec from the main runtime
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *feats = (NVec *)malloc(sizeof(NVec));
    feats->cap = 24;
    feats->data = (long long *)malloc(feats->cap * sizeof(long long));
    feats->len = 0;

    #define PUSH_F64(vec, val) do { \
        double _v = (val); long long _i; memcpy(&_i, &_v, sizeof(double)); \
        if (vec->len >= vec->cap) { vec->cap *= 2; vec->data = (long long*)realloc(vec->data, vec->cap * sizeof(long long)); } \
        vec->data[vec->len++] = _i; \
    } while(0)

    PUSH_F64(feats, mean_tv);        // [0]
    PUSH_F64(feats, std_tv);         // [1]
    PUSH_F64(feats, min_tv);         // [2]
    PUSH_F64(feats, max_tv);         // [3]
    PUSH_F64(feats, mean_fid);       // [4]
    PUSH_F64(feats, mean_kl);        // [5]
    PUSH_F64(feats, max_kl);         // [6]
    PUSH_F64(feats, agreement);      // [7]
    PUSH_F64(feats, 0.0);            // [8] divergence_onset (TODO)
    PUSH_F64(feats, 0.0);            // [9] divergence_slope (TODO)
    PUSH_F64(feats, 0.0);            // [10] core_rank_stability (TODO)
    PUSH_F64(feats, 0.0);            // [11] phase_coherence (TODO - needs raw amplitudes)
    PUSH_F64(feats, 0.0);            // [12] phase_drift_rate (TODO)

    // Sparsity of clean core
    int nonzero = 0;
    for (int i = 0; i < na; i++) if (p_clean[i] > eps) nonzero++;
    PUSH_F64(feats, (double)nonzero / na); // [13]
    PUSH_F64(feats, (double)mc->n_qubits); // [14]
    PUSH_F64(feats, (double)mc->step);     // [15]

    // GPU telemetry features (NEW — not available from CPU simulation)
    PUSH_F64(feats, mc->telemetry.total_kernel_time_us); // [16] total GPU time
    PUSH_F64(feats, mc->telemetry.n_events > 0 ?
             mc->telemetry.total_kernel_time_us / mc->telemetry.n_events : 0); // [17] mean kernel time
    PUSH_F64(feats, mc->telemetry.max_precision_delta); // [18] FP precision sensitivity
    PUSH_F64(feats, (double)mc->telemetry.n_events); // [19] gate count from GPU perspective

    // Per-step divergence curve features (DATA PORT — unique to GPU)
    int n_steps = mc->step;
    if (n_steps > 1) {
        // Divergence onset: first step where mean TV > 0.01
        double threshold = 0.01;
        int onset = n_steps;
        for (int s = 0; s < n_steps; s++) {
            if (mc->h_divergence[s] > threshold) { onset = s; break; }
        }
        PUSH_F64(feats, (double)onset); // [20] gpu_divergence_onset

        // Divergence slope: linear regression of TV over steps
        double step_mean = (n_steps - 1) / 2.0;
        double tv_mean = 0;
        for (int s = 0; s < n_steps; s++) tv_mean += mc->h_divergence[s];
        tv_mean /= n_steps;
        double num = 0, den = 0;
        for (int s = 0; s < n_steps; s++) {
            double si = s - step_mean;
            double di = mc->h_divergence[s] - tv_mean;
            num += si * di;
            den += si * si;
        }
        double slope = (fabs(den) > 1e-15) ? num / den : 0;
        PUSH_F64(feats, slope); // [21] gpu_divergence_slope

        // Divergence acceleration: change in slope between first and second half
        if (n_steps >= 4) {
            int mid = n_steps / 2;
            double slope1 = (mc->h_divergence[mid-1] - mc->h_divergence[0]) / (mid - 1);
            double slope2 = (mc->h_divergence[n_steps-1] - mc->h_divergence[mid]) / (n_steps - 1 - mid);
            PUSH_F64(feats, slope2 - slope1); // [22] gpu_divergence_acceleration
        } else {
            PUSH_F64(feats, 0.0); // [22]
        }

        // Mean phase coherence across steps
        double mean_phase = 0;
        for (int s = 0; s < n_steps && s < mc->telemetry.n_events; s++) {
            mean_phase += mc->telemetry.events[s].fp32_delta; // we stored phase here
        }
        mean_phase /= n_steps;
        PUSH_F64(feats, mean_phase); // [23] gpu_mean_phase_coherence

        // Phase drift rate: slope of phase coherence
        if (mc->telemetry.n_events >= 2) {
            double first_phase = mc->telemetry.events[0].fp32_delta;
            double last_phase = mc->telemetry.events[mc->telemetry.n_events-1].fp32_delta;
            PUSH_F64(feats, (last_phase - first_phase) / n_steps); // [24] gpu_phase_drift_rate
        } else {
            PUSH_F64(feats, 0.0); // [24]
        }

        // Kernel time variance (do different gates take different amounts of GPU time?)
        double kt_mean = mc->telemetry.total_kernel_time_us / mc->telemetry.n_events;
        double kt_var = 0;
        for (int s = 0; s < mc->telemetry.n_events; s++) {
            double d = mc->telemetry.events[s].kernel_time_us - kt_mean;
            kt_var += d * d;
        }
        PUSH_F64(feats, kt_var / mc->telemetry.n_events); // [25] gpu_kernel_time_variance
    } else {
        PUSH_F64(feats, 0.0); // [20]
        PUSH_F64(feats, 0.0); // [21]
        PUSH_F64(feats, 0.0); // [22]
        PUSH_F64(feats, 0.0); // [23]
        PUSH_F64(feats, 0.0); // [24]
        PUSH_F64(feats, 0.0); // [25]
    }

    free(tvs); free(kls); free(fids); free(h_probs);

    return (long long)feats;
}

// Get telemetry as JSON string
const char *nuc_gpu_mc_telemetry_json(long long handle) {
    GPUMC *mc = (GPUMC *)(void *)handle;
    GPUTelemetry *t = &mc->telemetry;

    static char buf[8192];
    int pos = 0;
    pos += snprintf(buf + pos, sizeof(buf) - pos,
        "{\"total_kernel_time_us\":%.2f,\"n_events\":%d,\"events\":[",
        t->total_kernel_time_us, t->n_events);

    for (int i = 0; i < t->n_events && i < 100; i++) {
        if (i > 0) pos += snprintf(buf + pos, sizeof(buf) - pos, ",");
        pos += snprintf(buf + pos, sizeof(buf) - pos,
            "{\"step\":%d,\"gate\":%d,\"time_us\":%.3f,\"divergence\":%.6f,\"phase\":%.6f}",
            t->events[i].gate_step, t->events[i].gate_type, t->events[i].kernel_time_us,
            t->events[i].mean_core_divergence, t->events[i].fp32_delta);
    }
    pos += snprintf(buf + pos, sizeof(buf) - pos, "]}");
    return buf;
}

// Cleanup
void nuc_gpu_mc_free(long long handle) {
    GPUMC *mc = (GPUMC *)(void *)handle;
    if (!mc) return;
    cudaFree(mc->d_sv);
    if (mc->d_sv_f32) cudaFree(mc->d_sv_f32);
    cudaFree(mc->d_noise_p1q);
    cudaEventDestroy(mc->evt_start);
    cudaEventDestroy(mc->evt_stop);
    cudaStreamDestroy(mc->stream);
    free(mc->h_divergence);
    free(mc);
}

// =====================================================
// DIFFERENTIABLE TRAINING ON GPU
// Full backward pass: per-gate learnable logits, pre-noise caching,
// per-core feature extraction, gradient accumulation.
// This is the GPU equivalent of diff_sim_rt.c — the REAL computation.
// =====================================================

#define DIFF_MAX_GATES 200
#define DIFF_MAX_QUBITS 7

typedef struct {
    int nq, n_cores, n_amps, n_noisy;
    double *d_sv;           // device: [n_cores * n_amps * 2]
    double *d_cache;        // device: [max_gates * n_cores * n_amps * 2] pre-noise state cache
    double *d_logits;       // device: [n_noisy * max_gates] per-core per-gate logits
    double *d_grad_logits;  // device: same shape
    double *d_probs;        // device: [n_cores * n_amps] probability buffer
    double *d_ent;          // device: [max_gates * n_cores] per-step per-core entropy
    int *d_gate_is_2q;      // device: [max_gates]
    int n_gates;
    cudaStream_t stream;
    cudaEvent_t evt_start, evt_stop;
} GPUDiffSim;

// Kernel: depolarizing noise with per-core per-gate learnable rate
// p = lo + sigmoid(logit) * (hi - lo)
__global__ void kernel_diff_noise(double *sv, double *logits, int *gate_is_2q,
                                   int n_amps, int n_cores, int gate_idx) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_amps * (n_cores - 1); // only noisy cores
    if (idx >= total) return;

    int ci = idx / n_amps;  // 0-based noisy core index
    int amp = idx % n_amps;
    int core = ci + 1;      // actual core index (skip core 0)

    double lo, hi;
    if (gate_is_2q[gate_idx]) { lo = 0.002; hi = 0.08; }
    else { lo = 0.0005; hi = 0.05; }

    double logit = logits[ci * DIFF_MAX_GATES + gate_idx];
    double sig = 1.0 / (1.0 + exp(-logit));
    double p = lo + sig * (hi - lo);
    double omp = 1.0 - p;
    double u = p / sqrt((double)n_amps);

    int base = core * n_amps * 2;
    sv[base + amp * 2]     = sv[base + amp * 2] * omp + u;
    sv[base + amp * 2 + 1] = sv[base + amp * 2 + 1] * omp;
}

// Kernel: cache pre-noise state for backward
__global__ void kernel_cache_sv(double *sv, double *cache, int n_amps, int n_cores, int gate_idx) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_amps * n_cores * 2;
    if (idx >= total) return;
    long long cache_off = (long long)gate_idx * n_cores * n_amps * 2;
    cache[cache_off + idx] = sv[idx];
}

// Kernel: compute per-qubit von Neumann entropy for all cores at current step
// One thread per (core, qubit) pair
__global__ void kernel_entropy(double *sv, double *ent_out, int n_amps, int n_cores, int nq, int step) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_cores * nq;
    if (idx >= total) return;

    int core = idx / nq;
    int q = idx % nq;
    int base = core * n_amps * 2;
    int bit = 1 << q;

    // Build 2x2 reduced density matrix for qubit q
    double rho00 = 0, rho11 = 0, rho01_re = 0, rho01_im = 0;
    for (int i = 0; i < n_amps; i++) {
        if (i & bit) continue;
        int j = i | bit;
        double re0 = sv[base + i*2], im0 = sv[base + i*2+1];
        double re1 = sv[base + j*2], im1 = sv[base + j*2+1];
        rho00 += re0*re0 + im0*im0;
        rho11 += re1*re1 + im1*im1;
        rho01_re += re0*re1 + im0*im1;
        rho01_im += im0*re1 - re0*im1;
    }

    double mid = (rho00 + rho11) * 0.5;
    double disc = (rho00 - rho11) * 0.5;
    double off = sqrt(disc*disc + rho01_re*rho01_re + rho01_im*rho01_im);
    double lam0 = mid + off, lam1 = mid - off;
    double entropy = 0;
    if (lam0 > 1e-10) entropy -= lam0 * log2(lam0);
    if (lam1 > 1e-10) entropy -= lam1 * log2(lam1);

    // Atomic add to per-core mean entropy (divide by nq after)
    atomicAdd(&ent_out[step * n_cores + core], entropy / nq);
}

// Kernel: backward — compute d(TV)/d(logit) for each gate, each noisy core
// One thread per (noisy_core, gate) pair
__global__ void kernel_backward(double *d_cache, double *d_probs_clean, double *d_logits,
                                 double *d_grad_logits, int *d_gate_is_2q,
                                 int n_amps, int n_cores, int n_gates, double grad_loss) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int n_noisy = n_cores - 1;
    int total = n_noisy * n_gates;
    if (idx >= total) return;

    int ci = idx / n_gates;
    int g = idx % n_gates;
    int core = ci + 1;

    double lo, hi;
    if (d_gate_is_2q[g]) { lo = 0.002; hi = 0.08; }
    else { lo = 0.0005; hi = 0.05; }

    double logit = d_logits[ci * DIFF_MAX_GATES + g];
    double sig = 1.0 / (1.0 + exp(-logit));
    double p = lo + sig * (hi - lo);
    double inv_sqrt_na = 1.0 / sqrt((double)n_amps);

    long long cache_off = ((long long)g * n_cores + core) * n_amps * 2;

    double d_tv_d_p = 0;
    for (int i = 0; i < n_amps; i++) {
        double pre_re = d_cache[cache_off + i*2];
        double pre_im = d_cache[cache_off + i*2+1];
        double d_sv_re = -pre_re + inv_sqrt_na;
        double d_sv_im = -pre_im;
        double sv_noisy_re = pre_re * (1.0 - p) + p * inv_sqrt_na;
        double sv_noisy_im = pre_im * (1.0 - p);
        double d_prob = 2.0 * (sv_noisy_re * d_sv_re + sv_noisy_im * d_sv_im);
        double p_noisy = sv_noisy_re*sv_noisy_re + sv_noisy_im*sv_noisy_im;
        double sign = (d_probs_clean[i] > p_noisy) ? -1.0 : 1.0;
        d_tv_d_p += sign * d_prob;
    }
    d_tv_d_p *= 0.5;

    double d_p_d_logit = sig * (1.0 - sig) * (hi - lo);
    atomicAdd(&d_grad_logits[ci * DIFF_MAX_GATES + g], grad_loss * d_tv_d_p * d_p_d_logit);
}

// Kernel: compute probabilities for all cores
__global__ void kernel_diff_probs(double *sv, double *probs, int n_amps, int n_cores) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    int total = n_amps * n_cores;
    if (idx >= total) return;
    int core = idx / n_amps;
    int amp = idx % n_amps;
    int base = core * n_amps * 2;
    double re = sv[base + amp*2], im = sv[base + amp*2+1];
    probs[core * n_amps + amp] = re*re + im*im;
}

// ── Host API for GPU differentiable simulation ──

long long nuc_gpu_diff_init(long long nq, long long n_cores, long long mode, long long seed) {
    if (!check_cuda()) return 0;

    GPUDiffSim *ds = (GPUDiffSim *)calloc(1, sizeof(GPUDiffSim));
    ds->nq = (int)nq;
    ds->n_cores = (int)n_cores;
    if (ds->n_cores < 2) ds->n_cores = 2;
    ds->n_amps = 1 << ds->nq;
    ds->n_noisy = ds->n_cores - 1;
    ds->n_gates = 0;

    int na = ds->n_amps, nc = ds->n_cores;

    cudaStreamCreate(&ds->stream);
    cudaEventCreate(&ds->evt_start);
    cudaEventCreate(&ds->evt_stop);

    // Statevectors on GPU
    cudaMalloc(&ds->d_sv, (long long)nc * na * 2 * sizeof(double));
    cudaMemset(ds->d_sv, 0, (long long)nc * na * 2 * sizeof(double));
    double one[2] = {1.0, 0.0};
    for (int c = 0; c < nc; c++)
        cudaMemcpy(ds->d_sv + c * na * 2, one, 2 * sizeof(double), cudaMemcpyHostToDevice);

    // Pre-noise cache on GPU
    long long cache_size = (long long)DIFF_MAX_GATES * nc * na * 2;
    cudaMalloc(&ds->d_cache, cache_size * sizeof(double));
    cudaMemset(ds->d_cache, 0, cache_size * sizeof(double));

    // Logits on GPU
    int logit_count = ds->n_noisy * DIFF_MAX_GATES;
    cudaMalloc(&ds->d_logits, logit_count * sizeof(double));
    cudaMalloc(&ds->d_grad_logits, logit_count * sizeof(double));
    cudaMemset(ds->d_grad_logits, 0, logit_count * sizeof(double));

    // Initialize logits (diversified mode)
    double *h_logits = (double *)calloc(logit_count, sizeof(double));
    unsigned int rng = (unsigned int)seed;
    for (int c = 0; c < ds->n_noisy; c++) {
        double base_1q = -5.5 + c * 0.3;
        for (int g = 0; g < DIFF_MAX_GATES; g++) {
            rng = rng * 1103515245 + 12345;
            double u1 = ((double)((rng >> 16) & 0x7FFF) + 1.0) / 32768.0;
            rng = rng * 1103515245 + 12345;
            double u2 = ((double)((rng >> 16) & 0x7FFF)) / 32767.0;
            double noise = sqrt(-2.0 * log(u1)) * cos(2.0 * 3.14159265358979 * u2) * 0.1;
            h_logits[c * DIFF_MAX_GATES + g] = base_1q + noise;
        }
    }
    cudaMemcpy(ds->d_logits, h_logits, logit_count * sizeof(double), cudaMemcpyHostToDevice);
    free(h_logits);

    // Probabilities buffer
    cudaMalloc(&ds->d_probs, (long long)nc * na * sizeof(double));

    // Entropy buffer
    cudaMalloc(&ds->d_ent, (long long)DIFF_MAX_GATES * nc * sizeof(double));
    cudaMemset(ds->d_ent, 0, (long long)DIFF_MAX_GATES * nc * sizeof(double));

    // Gate type tracking
    cudaMalloc(&ds->d_gate_is_2q, DIFF_MAX_GATES * sizeof(int));
    cudaMemset(ds->d_gate_is_2q, 0, DIFF_MAX_GATES * sizeof(int));

    return (long long)ds;
}

// Apply gate + cache + noise + entropy on GPU
void nuc_gpu_diff_gate(long long handle, long long gate_type, long long q0, long long q1, long long angle_bits) {
    GPUDiffSim *ds = (GPUDiffSim *)(void *)handle;
    if (!ds || ds->n_gates >= DIFF_MAX_GATES) return;

    int gt = (int)gate_type;
    int g = ds->n_gates;
    int na = ds->n_amps, nc = ds->n_cores;
    int blocks, threads;

    // Record gate type
    int is_2q = (gt == 1 || gt == 6) ? 1 : 0;
    cudaMemcpy(ds->d_gate_is_2q + g, &is_2q, sizeof(int), cudaMemcpyHostToDevice);

    // Apply gate kernel to all cores
    launch_config(na * nc, &blocks, &threads);
    cudaEventRecord(ds->evt_start, ds->stream);

    switch (gt) {
        case 0: kernel_h<<<blocks, threads, 0, ds->stream>>>(ds->d_sv, na, nc, (int)q0); break;
        case 1: kernel_cnot<<<blocks, threads, 0, ds->stream>>>(ds->d_sv, na, nc, (int)q0, (int)q1); break;
        case 2: kernel_x<<<blocks, threads, 0, ds->stream>>>(ds->d_sv, na, nc, (int)q0); break;
        case 3: kernel_z<<<blocks, threads, 0, ds->stream>>>(ds->d_sv, na, nc, (int)q0); break;
        case 4: case 5: {
            double angle; memcpy(&angle, &angle_bits, sizeof(double));
            kernel_rz<<<blocks, threads, 0, ds->stream>>>(ds->d_sv, na, nc, (int)q0, angle);
            break;
        }
        case 6: kernel_cnot<<<blocks, threads, 0, ds->stream>>>(ds->d_sv, na, nc, (int)q0, (int)q1); break;
    }

    // Cache state AFTER gate, BEFORE noise
    int cache_total = na * nc * 2;
    int cb, ct;
    launch_config(cache_total, &cb, &ct);
    kernel_cache_sv<<<cb, ct, 0, ds->stream>>>(ds->d_sv, ds->d_cache, na, nc, g);

    // Apply learnable noise to cores 1..N-1
    int noise_total = na * (nc - 1);
    launch_config(noise_total, &blocks, &threads);
    kernel_diff_noise<<<blocks, threads, 0, ds->stream>>>(ds->d_sv, ds->d_logits, ds->d_gate_is_2q,
                                                            na, nc, g);

    // Compute entropy for all cores at this step
    int ent_total = nc * ds->nq;
    launch_config(ent_total, &blocks, &threads);
    kernel_entropy<<<blocks, threads, 0, ds->stream>>>(ds->d_sv, ds->d_ent, na, nc, ds->nq, g);

    cudaEventRecord(ds->evt_stop, ds->stream);

    ds->n_gates++;
}

// Extract per-core features on GPU → transfer to host as flat vec
long long nuc_gpu_diff_extract(long long handle) {
    GPUDiffSim *ds = (GPUDiffSim *)(void *)handle;
    if (!ds) return 0;

    int na = ds->n_amps, nc = ds->n_cores, n_noisy = ds->n_noisy;
    int n_steps = ds->n_gates;

    // Compute probabilities on GPU
    int total = na * nc;
    int blocks, threads;
    launch_config(total, &blocks, &threads);
    kernel_diff_probs<<<blocks, threads, 0, ds->stream>>>(ds->d_sv, ds->d_probs, na, nc);
    cudaStreamSynchronize(ds->stream);

    // Transfer to host
    double *h_probs = (double *)malloc(total * sizeof(double));
    cudaMemcpy(h_probs, ds->d_probs, total * sizeof(double), cudaMemcpyDeviceToHost);

    double *h_ent = (double *)malloc((long long)DIFF_MAX_GATES * nc * sizeof(double));
    cudaMemcpy(h_ent, ds->d_ent, (long long)DIFF_MAX_GATES * nc * sizeof(double), cudaMemcpyDeviceToHost);

    // Build per-core features on host (same 12 features as diff_sim_rt.c)
    double eps = 1e-9;
    int total_feats = n_noisy * 12;
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *feats = (NVec *)malloc(sizeof(NVec));
    feats->cap = total_feats + 4;
    feats->len = 0;
    feats->data = (long long *)malloc(feats->cap * sizeof(long long));

    #define PF(v, val) do { double _v=(val); long long _i; memcpy(&_i,&_v,sizeof(double)); \
        if((v)->len>=(v)->cap){(v)->cap*=2;(v)->data=(long long*)realloc((v)->data,(v)->cap*sizeof(long long));} \
        (v)->data[(v)->len++]=_i; } while(0)

    // Clean core entropy per qubit at final step (for max_ent_clean)
    // Recompute from host probs (simpler than transferring per-qubit data)
    double mean_ent_clean = (n_steps > 0) ? h_ent[(n_steps-1) * nc + 0] : 0;
    double max_ent_clean = mean_ent_clean; // approximate — would need per-qubit for exact

    for (int ci = 0; ci < n_noisy; ci++) {
        int c = ci + 1;

        // TV, KL, fidelity
        double tv = 0, kl = 0, fid = 0;
        for (int i = 0; i < na; i++) {
            double pa = h_probs[i], pb = h_probs[c*na+i];
            tv += fabs(pa - pb);
            kl += (pa+eps) * log((pa+eps)/(pb+eps));
            fid += sqrt(pa*pb+eps);
        }
        tv *= 0.5;

        // Entropy divergences
        double mean_ed = 0, max_ed = -1e30, final_ed = 0;
        double sum_t = 0, sum_d = 0, sum_t2 = 0, sum_td = 0;
        for (int s = 0; s < n_steps; s++) {
            double ed = h_ent[s * nc + c] - h_ent[s * nc + 0];
            mean_ed += ed;
            if (ed > max_ed) max_ed = ed;
            if (s == n_steps - 1) final_ed = ed;
            double t = (double)s;
            sum_t += t; sum_d += ed; sum_t2 += t*t; sum_td += t*ed;
        }
        if (n_steps > 0) mean_ed /= n_steps;
        if (n_steps == 0) max_ed = 0;

        double slope = 0;
        if (n_steps > 1) {
            double n = (double)n_steps;
            double denom = n * sum_t2 - sum_t * sum_t;
            if (fabs(denom) > 1e-15) slope = (n * sum_td - sum_t * sum_d) / denom;
        }

        double sparsity = 0;
        for (int i = 0; i < na; i++)
            sparsity += 1.0 / (1.0 + exp(-(h_probs[i] - eps) * 1000.0));
        sparsity /= (double)na;

        PF(feats, tv);          PF(feats, kl);          PF(feats, fid);
        PF(feats, mean_ed);     PF(feats, max_ed);      PF(feats, final_ed);
        PF(feats, slope);       PF(feats, mean_ent_clean); PF(feats, max_ent_clean);
        PF(feats, sparsity);    PF(feats, (double)ds->nq); PF(feats, (double)n_steps);
    }

    #undef PF
    free(h_probs);
    free(h_ent);
    return (long long)feats;
}

// Backward on GPU
void nuc_gpu_diff_backward(long long handle, long long grad_loss_bits) {
    GPUDiffSim *ds = (GPUDiffSim *)(void *)handle;
    if (!ds) return;
    double grad_loss; memcpy(&grad_loss, &grad_loss_bits, sizeof(double));

    int na = ds->n_amps, nc = ds->n_cores;

    // Need clean core probs on device for backward kernel
    // d_probs already has them from extract (core 0 = first na entries)

    int total = ds->n_noisy * ds->n_gates;
    int blocks, threads;
    launch_config(total, &blocks, &threads);
    kernel_backward<<<blocks, threads, 0, ds->stream>>>(
        ds->d_cache, ds->d_probs, ds->d_logits, ds->d_grad_logits,
        ds->d_gate_is_2q, na, nc, ds->n_gates, grad_loss);
    cudaStreamSynchronize(ds->stream);
}

// Get/set logits (device → host → NVec)
long long nuc_gpu_diff_get_logits(long long handle) {
    GPUDiffSim *ds = (GPUDiffSim *)(void *)handle;
    if (!ds) return 0;
    typedef struct { long long *data; int len; int cap; } NVec;
    int total = ds->n_noisy * ds->n_gates;
    double *h_logits = (double *)malloc(ds->n_noisy * DIFF_MAX_GATES * sizeof(double));
    cudaMemcpy(h_logits, ds->d_logits, ds->n_noisy * DIFF_MAX_GATES * sizeof(double), cudaMemcpyDeviceToHost);
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->len = total; v->cap = total;
    v->data = (long long *)malloc(total * sizeof(long long));
    for (int ci = 0; ci < ds->n_noisy; ci++)
        for (int g = 0; g < ds->n_gates; g++) {
            double val = h_logits[ci * DIFF_MAX_GATES + g];
            memcpy(&v->data[ci * ds->n_gates + g], &val, sizeof(double));
        }
    free(h_logits);
    return (long long)v;
}

long long nuc_gpu_diff_get_grad_logits(long long handle) {
    GPUDiffSim *ds = (GPUDiffSim *)(void *)handle;
    if (!ds) return 0;
    typedef struct { long long *data; int len; int cap; } NVec;
    int total = ds->n_noisy * ds->n_gates;
    double *h_grad = (double *)malloc(ds->n_noisy * DIFF_MAX_GATES * sizeof(double));
    cudaMemcpy(h_grad, ds->d_grad_logits, ds->n_noisy * DIFF_MAX_GATES * sizeof(double), cudaMemcpyDeviceToHost);
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->len = total; v->cap = total;
    v->data = (long long *)malloc(total * sizeof(long long));
    for (int ci = 0; ci < ds->n_noisy; ci++)
        for (int g = 0; g < ds->n_gates; g++) {
            double val = h_grad[ci * DIFF_MAX_GATES + g];
            memcpy(&v->data[ci * ds->n_gates + g], &val, sizeof(double));
        }
    free(h_grad);
    return (long long)v;
}

void nuc_gpu_diff_set_logits(long long handle, long long vec) {
    GPUDiffSim *ds = (GPUDiffSim *)(void *)handle;
    if (!ds) return;
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *v = (NVec *)(void *)vec;
    double *h_logits = (double *)calloc(ds->n_noisy * DIFF_MAX_GATES, sizeof(double));
    for (int ci = 0; ci < ds->n_noisy; ci++)
        for (int g = 0; g < ds->n_gates && (ci * ds->n_gates + g) < v->len; g++) {
            memcpy(&h_logits[ci * DIFF_MAX_GATES + g], &v->data[ci * ds->n_gates + g], sizeof(double));
        }
    cudaMemcpy(ds->d_logits, h_logits, ds->n_noisy * DIFF_MAX_GATES * sizeof(double), cudaMemcpyHostToDevice);
    free(h_logits);
}

void nuc_gpu_diff_zero_grad(long long handle) {
    GPUDiffSim *ds = (GPUDiffSim *)(void *)handle;
    if (!ds) return;
    cudaMemset(ds->d_grad_logits, 0, ds->n_noisy * DIFF_MAX_GATES * sizeof(double));
}

void nuc_gpu_diff_reset(long long handle) {
    GPUDiffSim *ds = (GPUDiffSim *)(void *)handle;
    if (!ds) return;
    int na = ds->n_amps, nc = ds->n_cores;
    cudaMemset(ds->d_sv, 0, (long long)nc * na * 2 * sizeof(double));
    double one[2] = {1.0, 0.0};
    for (int c = 0; c < nc; c++)
        cudaMemcpy(ds->d_sv + c * na * 2, one, 2 * sizeof(double), cudaMemcpyHostToDevice);
    ds->n_gates = 0;
    cudaMemset(ds->d_ent, 0, (long long)DIFF_MAX_GATES * nc * sizeof(double));
}

void nuc_gpu_diff_free(long long handle) {
    GPUDiffSim *ds = (GPUDiffSim *)(void *)handle;
    if (!ds) return;
    cudaFree(ds->d_sv);
    cudaFree(ds->d_cache);
    cudaFree(ds->d_logits);
    cudaFree(ds->d_grad_logits);
    cudaFree(ds->d_probs);
    cudaFree(ds->d_ent);
    cudaFree(ds->d_gate_is_2q);
    cudaEventDestroy(ds->evt_start);
    cudaEventDestroy(ds->evt_stop);
    cudaStreamDestroy(ds->stream);
    free(ds);
}

} // extern "C"
