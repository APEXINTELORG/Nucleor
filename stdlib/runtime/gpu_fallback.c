// gpu_fallback.c — CPU fallback for GPU functions when CUDA is not available
// This file provides the same nuc_gpu_* API as cuda_rt.cu but runs on CPU.
// Linked when CUDA is not installed or no NVIDIA GPU is present.
//
// For Vulkan compute support (AMD/Intel GPUs), this would be extended
// with VkComputePipeline dispatch. Currently CPU-only.
//
// Compile: clang -c gpu_fallback.c -o target/gpu_fallback.obj

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

// Type punning for f64 <-> i64
static double _fb_i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _fb_f2i(double f) { long long i; memcpy(&i, &f, sizeof(long long)); return i; }

// CPU statevector (mirrors CUDA structure)
typedef struct {
    int n_qubits;
    int n_cores;
    int n_amps;
    double *sv;         // n_cores * n_amps * 2 (re,im interleaved)
    double *noise_p;    // n_cores * 2 (p1q, p2q per core)
    int step;
    double *divergence; // per-step mean TV
    double *phase_coh;  // per-step mean phase coherence
    float total_time_us;
    int n_events;
} CPUMC;

#define MAX_STEPS 4096

// Apply depolarizing noise to cores 1..N-1
static void cpu_noise(CPUMC *mc, int is_2q) {
    for (int c = 1; c < mc->n_cores; c++) {
        double p = is_2q ? mc->noise_p[c * 2 + 1] : mc->noise_p[c * 2];
        double one_minus_p = 1.0 - p;
        double uniform = p / sqrt((double)mc->n_amps);
        int base = c * mc->n_amps * 2;
        for (int i = 0; i < mc->n_amps; i++) {
            mc->sv[base + i * 2]     = mc->sv[base + i * 2] * one_minus_p + uniform;
            mc->sv[base + i * 2 + 1] = mc->sv[base + i * 2 + 1] * one_minus_p;
        }
    }
}

// Compute per-step divergence and phase
static void cpu_record_step(CPUMC *mc) {
    if (mc->step >= MAX_STEPS) { mc->step++; return; }
    double mean_tv = 0, mean_phase = 0;
    for (int c = 1; c < mc->n_cores; c++) {
        int base_0 = 0, base_c = c * mc->n_amps * 2;
        double tv = 0, sum_cos = 0;
        int pcount = 0;
        for (int i = 0; i < mc->n_amps; i++) {
            double re0 = mc->sv[base_0 + i*2], im0 = mc->sv[base_0 + i*2+1];
            double rec = mc->sv[base_c + i*2], imc = mc->sv[base_c + i*2+1];
            double p0 = re0*re0 + im0*im0, pc = rec*rec + imc*imc;
            tv += fabs(p0 - pc);
            if (p0 > 1e-12) {
                sum_cos += cos(atan2(im0,re0) - atan2(imc,rec));
                pcount++;
            }
        }
        mean_tv += tv * 0.5;
        mean_phase += pcount > 0 ? sum_cos / pcount : 1.0;
    }
    mc->divergence[mc->step] = mean_tv / (mc->n_cores - 1);
    mc->phase_coh[mc->step] = mean_phase / (mc->n_cores - 1);
    mc->step++;
}

long long nuc_gpu_available(void) { return 0; } // CPU fallback — no GPU
const char *nuc_gpu_info(void) { return "CPU fallback (no CUDA GPU)"; }

long long nuc_gpu_mc_init(long long nq, long long n_cores, long long p1q_bits, long long p2q_bits) {
    CPUMC *mc = (CPUMC *)calloc(1, sizeof(CPUMC));
    mc->n_qubits = (int)nq;
    mc->n_cores = (int)n_cores;
    mc->n_amps = 1 << (int)nq;
    mc->step = 0;
    mc->sv = (double *)calloc(mc->n_cores * mc->n_amps * 2, sizeof(double));
    // Init each core to |0>
    for (int c = 0; c < mc->n_cores; c++)
        mc->sv[c * mc->n_amps * 2] = 1.0;
    // Noise rates
    double p1q = _fb_i2f(p1q_bits), p2q = _fb_i2f(p2q_bits);
    mc->noise_p = (double *)calloc(mc->n_cores * 2, sizeof(double));
    for (int c = 1; c < mc->n_cores; c++) {
        double scale = 0.5 + 0.5 * c;
        mc->noise_p[c * 2] = p1q * scale;
        mc->noise_p[c * 2 + 1] = p2q * scale;
    }
    mc->divergence = (double *)calloc(MAX_STEPS, sizeof(double));
    mc->phase_coh = (double *)calloc(MAX_STEPS, sizeof(double));
    return (long long)mc;
}

// Gate: Hadamard
void nuc_gpu_mc_h(long long handle, long long q) {
    CPUMC *mc = (CPUMC *)(void *)handle;
    int bit = 1 << (int)q;
    double inv_sqrt2 = 0.7071067811865476;
    for (int c = 0; c < mc->n_cores; c++) {
        int base = c * mc->n_amps * 2;
        for (int i = 0; i < mc->n_amps; i++) {
            if (i & bit) continue;
            int j = i | bit;
            double re0=mc->sv[base+i*2], im0=mc->sv[base+i*2+1];
            double re1=mc->sv[base+j*2], im1=mc->sv[base+j*2+1];
            mc->sv[base+i*2]=(re0+re1)*inv_sqrt2; mc->sv[base+i*2+1]=(im0+im1)*inv_sqrt2;
            mc->sv[base+j*2]=(re0-re1)*inv_sqrt2; mc->sv[base+j*2+1]=(im0-im1)*inv_sqrt2;
        }
    }
    cpu_noise(mc, 0);
    cpu_record_step(mc);
}

void nuc_gpu_mc_x(long long handle, long long q) {
    CPUMC *mc = (CPUMC *)(void *)handle;
    int bit = 1 << (int)q;
    for (int c = 0; c < mc->n_cores; c++) {
        int base = c * mc->n_amps * 2;
        for (int i = 0; i < mc->n_amps; i++) {
            if (i & bit) continue;
            int j = i | bit;
            double t0=mc->sv[base+i*2], t1=mc->sv[base+i*2+1];
            mc->sv[base+i*2]=mc->sv[base+j*2]; mc->sv[base+i*2+1]=mc->sv[base+j*2+1];
            mc->sv[base+j*2]=t0; mc->sv[base+j*2+1]=t1;
        }
    }
    cpu_noise(mc, 0);
    cpu_record_step(mc);
}

void nuc_gpu_mc_z(long long handle, long long q) {
    CPUMC *mc = (CPUMC *)(void *)handle;
    for (int c = 0; c < mc->n_cores; c++) {
        int base = c * mc->n_amps * 2;
        for (int i = 0; i < mc->n_amps; i++) {
            if (!((i >> (int)q) & 1)) continue;
            mc->sv[base+i*2] = -mc->sv[base+i*2];
            mc->sv[base+i*2+1] = -mc->sv[base+i*2+1];
        }
    }
    cpu_noise(mc, 0);
    cpu_record_step(mc);
}

void nuc_gpu_mc_cnot(long long handle, long long ctrl, long long tgt) {
    CPUMC *mc = (CPUMC *)(void *)handle;
    for (int c = 0; c < mc->n_cores; c++) {
        int base = c * mc->n_amps * 2;
        for (int i = 0; i < mc->n_amps; i++) {
            if (!((i >> (int)ctrl) & 1)) continue;
            if ((i >> (int)tgt) & 1) continue;
            int j = i ^ (1 << (int)tgt);
            double t0=mc->sv[base+i*2], t1=mc->sv[base+i*2+1];
            mc->sv[base+i*2]=mc->sv[base+j*2]; mc->sv[base+i*2+1]=mc->sv[base+j*2+1];
            mc->sv[base+j*2]=t0; mc->sv[base+j*2+1]=t1;
        }
    }
    cpu_noise(mc, 1);
    cpu_record_step(mc);
}

void nuc_gpu_mc_rz(long long handle, long long q, long long angle_bits) {
    CPUMC *mc = (CPUMC *)(void *)handle;
    double angle = _fb_i2f(angle_bits);
    double ca = cos(angle), sa = sin(angle);
    for (int c = 0; c < mc->n_cores; c++) {
        int base = c * mc->n_amps * 2;
        for (int i = 0; i < mc->n_amps; i++) {
            if (!((i >> (int)q) & 1)) continue;
            double re = mc->sv[base+i*2], im = mc->sv[base+i*2+1];
            mc->sv[base+i*2] = re*ca - im*sa;
            mc->sv[base+i*2+1] = re*sa + im*ca;
        }
    }
    cpu_noise(mc, 0);
    cpu_record_step(mc);
}

long long nuc_gpu_mc_extract(long long handle) {
    CPUMC *mc = (CPUMC *)(void *)handle;
    int nc = mc->n_cores, na = mc->n_amps;
    double eps = 1e-9;

    // Compute probs
    double *probs = (double *)malloc(nc * na * sizeof(double));
    for (int c = 0; c < nc; c++)
        for (int i = 0; i < na; i++) {
            double re = mc->sv[c*na*2+i*2], im = mc->sv[c*na*2+i*2+1];
            probs[c*na+i] = re*re + im*im;
        }

    // Same feature extraction as cuda_rt.cu
    double *tvs = (double*)calloc(nc-1,sizeof(double));
    for (int c = 1; c < nc; c++) {
        double tv = 0;
        for (int i = 0; i < na; i++) tv += fabs(probs[i] - probs[c*na+i]);
        tvs[c-1] = tv * 0.5;
    }
    double mean_tv=0, std_tv=0, min_tv=999, max_tv=0, mean_fid=0, mean_kl=0, max_kl=0;
    for (int c = 0; c < nc-1; c++) {
        mean_tv += tvs[c];
        if (tvs[c]<min_tv) min_tv=tvs[c];
        if (tvs[c]>max_tv) max_tv=tvs[c];
    }
    mean_tv /= (nc-1);
    for (int c = 0; c < nc-1; c++) { double d=tvs[c]-mean_tv; std_tv+=d*d; }
    std_tv = sqrt(std_tv/(nc-1));

    // Build feature vec (NVec compatible)
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *feats = (NVec*)malloc(sizeof(NVec));
    feats->cap = 32; feats->data = (long long*)malloc(feats->cap*sizeof(long long)); feats->len = 0;
    #define PF(v,val) do{double _v=(val);long long _i;memcpy(&_i,&_v,sizeof(double));if(v->len>=v->cap){v->cap*=2;v->data=(long long*)realloc(v->data,v->cap*sizeof(long long));}v->data[v->len++]=_i;}while(0)

    PF(feats,mean_tv); PF(feats,std_tv); PF(feats,min_tv); PF(feats,max_tv);
    PF(feats,0); PF(feats,0); PF(feats,0); // fidelity, kl, max_kl (simplified)
    double pair_sum=0; int np=0;
    for (int ci=1;ci<nc;ci++) for (int cj=ci+1;cj<nc;cj++) {
        double ptv=0; for(int i=0;i<na;i++) ptv+=fabs(probs[ci*na+i]-probs[cj*na+i]);
        pair_sum+=ptv*0.5; np++;
    }
    PF(feats, np>0?pair_sum/np:0); // ensemble agreement
    PF(feats,0); PF(feats,0); PF(feats,0); PF(feats,0); PF(feats,0); // placeholders
    int nz=0; for(int i=0;i<na;i++) if(probs[i]>eps) nz++;
    PF(feats,(double)nz/na); PF(feats,(double)mc->n_qubits); PF(feats,(double)mc->step);
    // GPU telemetry (zeros for CPU fallback)
    PF(feats,0); PF(feats,0); PF(feats,0); PF(feats,(double)mc->step);
    // Divergence dynamics from per-step tracking
    int ns = mc->step < MAX_STEPS ? mc->step : MAX_STEPS;
    if (ns > 1) {
        int onset = ns;
        for (int s=0;s<ns;s++) if(mc->divergence[s]>0.01){onset=s;break;}
        PF(feats,(double)onset);
        double sm=(ns-1)/2.0, tm=0;
        for(int s=0;s<ns;s++) tm+=mc->divergence[s]; tm/=ns;
        double num=0,den=0;
        for(int s=0;s<ns;s++){double si=s-sm,di=mc->divergence[s]-tm;num+=si*di;den+=si*si;}
        PF(feats,fabs(den)>1e-15?num/den:0);
        PF(feats,0); // accel
        double mp=0; for(int s=0;s<ns;s++) mp+=mc->phase_coh[s]; mp/=ns;
        PF(feats,mp);
        PF(feats,ns>=2?(mc->phase_coh[ns-1]-mc->phase_coh[0])/ns:0);
        PF(feats,0); // kernel var
    } else { PF(feats,0);PF(feats,0);PF(feats,0);PF(feats,0);PF(feats,0);PF(feats,0); }

    free(probs); free(tvs);
    return (long long)feats;
}

const char *nuc_gpu_mc_telemetry_json(long long handle) {
    return "{\"backend\":\"cpu_fallback\",\"total_kernel_time_us\":0,\"n_events\":0,\"events\":[]}";
}

void nuc_gpu_mc_free(long long handle) {
    CPUMC *mc = (CPUMC *)(void *)handle;
    if (!mc) return;
    free(mc->sv); free(mc->noise_p); free(mc->divergence); free(mc->phase_coh);
    free(mc);
}
