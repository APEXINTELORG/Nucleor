// rods/quantum runtime — S12b trace emission + entanglement tracking
// Provides JSONL event output and union-find entanglement tracker
// v1.2: depth, gate angle, transpiler overhead, noise estimate

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#ifdef _WIN32
#include <windows.h>
static long long trace_time_us(void) {
    static LARGE_INTEGER freq = {0};
    LARGE_INTEGER now;
    if (freq.QuadPart == 0) QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&now);
    return (long long)(now.QuadPart * 1000000 / freq.QuadPart);
}
#else
#include <time.h>
static long long trace_time_us(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000000 + (long long)ts.tv_nsec / 1000;
}
#endif

// === Trace state ===
static FILE *trace_file = NULL;
static int trace_enabled = 0;
static long long trace_step = 0;
static long long trace_start_us = 0;
static long long trace_event_count = 0;

// === Entanglement tracker (union-find) ===
#define MAX_QUBITS 32
static long long raw_total_gates = 0;
static long long raw_2q_gates = 0;
static long long raw_nc_gates = 0;
static long long raw_gate_density[MAX_QUBITS] = {0};
static int uf_parent[MAX_QUBITS];
static int uf_rank[MAX_QUBITS];
static int uf_n_qubits = 0;

// === Depth tracking ===
static long long qubit_depth[MAX_QUBITS] = {0};     // per-qubit gate depth
static long long qubit_depth_2q[MAX_QUBITS] = {0};  // per-qubit 2q-gate depth
static long long circuit_depth = 0;                   // max across all qubits
static long long circuit_depth_2q = 0;                // max 2q depth

// === Transpiler overhead (set by caller before running transpiled circuit) ===
static long long original_gates = 0;
static long long original_depth = 0;
static long long transpiled_swap_count = 0;

// === Noise estimate accumulators ===
static double sum_angle_magnitude = 0.0;  // total |theta| across rotation gates
static long long rotation_gate_count = 0;

static int uf_find(int x) {
    while (uf_parent[x] != x) {
        uf_parent[x] = uf_parent[uf_parent[x]]; // path compression
        x = uf_parent[x];
    }
    return x;
}

static void uf_union(int a, int b) {
    int ra = uf_find(a), rb = uf_find(b);
    if (ra == rb) return;
    if (uf_rank[ra] < uf_rank[rb]) { int t = ra; ra = rb; rb = t; }
    uf_parent[rb] = ra;
    if (uf_rank[ra] == uf_rank[rb]) uf_rank[ra]++;
}

static void uf_init(int n) {
    uf_n_qubits = n;
    for (int i = 0; i < n; i++) {
        uf_parent[i] = i;
        uf_rank[i] = 0;
    }
}

// Count distinct entanglement components
static int uf_num_components(void) {
    int count = 0;
    for (int i = 0; i < uf_n_qubits; i++) {
        if (uf_find(i) == i) count++;
    }
    return count;
}

// Get max component size
static int uf_max_component(void) {
    int sizes[MAX_QUBITS] = {0};
    for (int i = 0; i < uf_n_qubits; i++) sizes[uf_find(i)]++;
    int mx = 0;
    for (int i = 0; i < uf_n_qubits; i++) if (sizes[i] > mx) mx = sizes[i];
    return mx;
}

// Build component list as JSON array string: [[0,1],[2],[3,4]]
static const char *uf_components_json(void) {
    static char buf[1024];
    int roots[MAX_QUBITS];
    int members[MAX_QUBITS][MAX_QUBITS];
    int member_count[MAX_QUBITS] = {0};
    int nroots = 0;

    // Collect unique roots
    for (int i = 0; i < uf_n_qubits; i++) {
        int r = uf_find(i);
        int found = 0;
        for (int j = 0; j < nroots; j++) {
            if (roots[j] == r) { members[j][member_count[j]++] = i; found = 1; break; }
        }
        if (!found) {
            roots[nroots] = r;
            members[nroots][0] = i;
            member_count[nroots] = 1;
            nroots++;
        }
    }

    int pos = 0;
    buf[pos++] = '[';
    for (int i = 0; i < nroots; i++) {
        if (i > 0) buf[pos++] = ',';
        buf[pos++] = '[';
        for (int j = 0; j < member_count[i]; j++) {
            if (j > 0) buf[pos++] = ',';
            pos += snprintf(buf + pos, sizeof(buf) - pos, "%d", members[i][j]);
        }
        buf[pos++] = ']';
    }
    buf[pos++] = ']';
    buf[pos] = 0;
    return buf;
}

// === Helper: is this a 2-qubit gate? ===
static int is_2q_gate(const char *name) {
    return strcmp(name, "CNOT") == 0 || strcmp(name, "CZ") == 0 ||
           strcmp(name, "SWAP") == 0 || strcmp(name, "CP") == 0 ||
           strcmp(name, "CRK") == 0;
}

// === Helper: is this a non-Clifford gate? ===
static int is_nc_gate(const char *name) {
    return strcmp(name, "RX") == 0 || strcmp(name, "RZ") == 0 ||
           strcmp(name, "RY") == 0 || strcmp(name, "T") == 0 ||
           strcmp(name, "CP") == 0 || strcmp(name, "CRK") == 0;
}

// === Helper: is this a rotation gate that has an angle? ===
static int is_rotation_gate(const char *name) {
    return strcmp(name, "RX") == 0 || strcmp(name, "RZ") == 0 ||
           strcmp(name, "RY") == 0 || strcmp(name, "CP") == 0 ||
           strcmp(name, "CRK") == 0;
}

// === Trace API ===

void rods_trace_init(const char *filename, long long n_qubits) {
    if (trace_file) fclose(trace_file);
    trace_file = fopen(filename, "w");
    trace_enabled = (trace_file != NULL);
    trace_step = 0;
    trace_event_count = 0;
    trace_start_us = trace_time_us();
    raw_total_gates = 0;
    raw_2q_gates = 0;
    raw_nc_gates = 0;
    circuit_depth = 0;
    circuit_depth_2q = 0;
    sum_angle_magnitude = 0.0;
    rotation_gate_count = 0;
    for (int i = 0; i < MAX_QUBITS; i++) {
        raw_gate_density[i] = 0;
        qubit_depth[i] = 0;
        qubit_depth_2q[i] = 0;
    }
    uf_init((int)n_qubits);

    if (trace_enabled) {
        long long elapsed = trace_time_us() - trace_start_us;
        fprintf(trace_file,
            "{\"schema_version\":\"1.2\",\"event\":\"surface_open\","
            "\"n_qubits\":%lld,\"elapsed_us\":%lld}\n",
            n_qubits, elapsed);
        fflush(trace_file);
    }
}

// Set pre-transpilation baseline (call before running transpiled circuit)
void rods_trace_set_original(long long gates, long long depth, long long swaps) {
    original_gates = gates;
    original_depth = depth;
    transpiled_swap_count = swaps;
}

void rods_trace_close(void) {
    if (trace_enabled && trace_file) {
        long long elapsed = trace_time_us() - trace_start_us;
        long long n1q = raw_total_gates - raw_2q_gates;
        int final_components = uf_num_components();
        int max_comp = uf_max_component();

        // Noise susceptibility estimate:
        // gate_survival = product(1 - err_i) approximated as (1-p1)^n1q * (1-p2)^n2q
        // Using typical error rates: p1q=0.003, p2q=0.015
        double gate_survival = pow(1.0 - 0.003, (double)n1q) * pow(1.0 - 0.015, (double)raw_2q_gates);
        // Depolarizing noise estimate: r = 1 - gate_survival
        double noise_est = 1.0 - gate_survival;
        if (noise_est > 1.0) noise_est = 1.0;

        // Transpiler overhead ratios (0 if original not set)
        double route_oh_gates = 0.0;
        double route_oh_depth = 0.0;
        if (original_gates > 0) route_oh_gates = (double)raw_total_gates / (double)original_gates;
        if (original_depth > 0) route_oh_depth = (double)circuit_depth / (double)original_depth;

        // Mean angle magnitude (for rotation-heavy circuits)
        double mean_angle = rotation_gate_count > 0 ? sum_angle_magnitude / (double)rotation_gate_count : 0.0;

        fprintf(trace_file,
            "{\"schema_version\":\"1.2\",\"event\":\"circuit_profile\","
            "\"raw_total_gates\":%lld,\"raw_1q_gates\":%lld,\"raw_2q_gates\":%lld,\"raw_nc_gates\":%lld,"
            "\"raw_gate_density\":[",
            raw_total_gates, n1q, raw_2q_gates, raw_nc_gates);
        for(int i=0; i<uf_n_qubits; i++) {
            fprintf(trace_file, "%lld%s", raw_gate_density[i], i == uf_n_qubits-1 ? "" : ",");
        }
        fprintf(trace_file, "],"
            "\"depth\":%lld,\"depth_2q\":%lld,"
            "\"qubit_depth\":[",
            circuit_depth, circuit_depth_2q);
        for(int i=0; i<uf_n_qubits; i++) {
            fprintf(trace_file, "%lld%s", qubit_depth[i], i == uf_n_qubits-1 ? "" : ",");
        }
        fprintf(trace_file, "],"
            "\"final_components\":%d,\"max_component_size\":%d,"
            "\"rotation_count\":%lld,\"mean_angle\":%.6f,"
            "\"original_gates\":%lld,\"original_depth\":%lld,\"transpiled_swaps\":%lld,"
            "\"route_oh_gates\":%.6f,\"route_oh_depth\":%.6f,"
            "\"gate_survival\":%.6f,\"noise_estimate\":%.6f,"
            "\"elapsed_us\":%lld}\n",
            final_components, max_comp,
            rotation_gate_count, mean_angle,
            original_gates, original_depth, transpiled_swap_count,
            route_oh_gates, route_oh_depth,
            gate_survival, noise_est,
            elapsed);

        fprintf(trace_file,
            "{\"schema_version\":\"1.2\",\"event\":\"surface_close\","
            "\"total_steps\":%lld,\"total_events\":%lld,\"elapsed_us\":%lld}\n",
            trace_step, trace_event_count, elapsed);
        fclose(trace_file);
        trace_file = NULL;
        trace_enabled = 0;
    }
}

long long rods_trace_enabled(void) {
    return trace_enabled ? 1 : 0;
}

long long rods_trace_step(void) {
    return trace_step;
}

long long rods_trace_next_step(void) {
    return ++trace_step;
}

// Emit gate_apply event (backward-compatible, angle=0)
void rods_trace_gate(const char *gate_name, const char *qubits_json,
                     long long pre_sparsity, long long post_sparsity) {
    if (!trace_enabled) return;
    long long elapsed = trace_time_us() - trace_start_us;

    raw_total_gates++;
    if (is_nc_gate(gate_name)) raw_nc_gates++;
    if (is_2q_gate(gate_name)) raw_2q_gates++;

    int q1 = -1, q2 = -1;
    if (sscanf(qubits_json, "[%d,%d]", &q1, &q2) == 2) {
        if (q1 >= 0 && q1 < MAX_QUBITS) raw_gate_density[q1]++;
        if (q2 >= 0 && q2 < MAX_QUBITS) raw_gate_density[q2]++;
        // Depth: 2-qubit gate occupies both qubit wires at max(d[q1],d[q2])+1
        long long d = qubit_depth[q1] > qubit_depth[q2] ? qubit_depth[q1] : qubit_depth[q2];
        d++;
        if (q1 >= 0 && q1 < MAX_QUBITS) qubit_depth[q1] = d;
        if (q2 >= 0 && q2 < MAX_QUBITS) qubit_depth[q2] = d;
        if (d > circuit_depth) circuit_depth = d;
        if (is_2q_gate(gate_name)) {
            long long d2 = qubit_depth_2q[q1] > qubit_depth_2q[q2] ? qubit_depth_2q[q1] : qubit_depth_2q[q2];
            d2++;
            if (q1 >= 0 && q1 < MAX_QUBITS) qubit_depth_2q[q1] = d2;
            if (q2 >= 0 && q2 < MAX_QUBITS) qubit_depth_2q[q2] = d2;
            if (d2 > circuit_depth_2q) circuit_depth_2q = d2;
        }
    } else if (sscanf(qubits_json, "[%d]", &q1) == 1) {
        if (q1 >= 0 && q1 < MAX_QUBITS) {
            raw_gate_density[q1]++;
            qubit_depth[q1]++;
            if (qubit_depth[q1] > circuit_depth) circuit_depth = qubit_depth[q1];
        }
    }
    fprintf(trace_file,
        "{\"schema_version\":\"1.2\",\"event\":\"gate_apply\","
        "\"gate\":\"%s\",\"qubits\":%s,\"step\":%lld,"
        "\"elapsed_us\":%lld}\n",
        gate_name, qubits_json, trace_step, elapsed);
    trace_event_count++;
    fflush(trace_file);
}

// Emit gate_apply event with angle (for parameterized gates)
// angle_bits is f64 reinterpreted as i64 (Nucleor calling convention)
void rods_trace_gate_angle(const char *gate_name, const char *qubits_json,
                           long long angle_bits) {
    if (!trace_enabled) return;
    long long elapsed = trace_time_us() - trace_start_us;
    double angle;
    memcpy(&angle, &angle_bits, sizeof(double));

    raw_total_gates++;
    if (is_nc_gate(gate_name)) raw_nc_gates++;
    if (is_2q_gate(gate_name)) raw_2q_gates++;
    if (is_rotation_gate(gate_name)) {
        rotation_gate_count++;
        sum_angle_magnitude += fabs(angle);
    }

    int q1 = -1, q2 = -1;
    if (sscanf(qubits_json, "[%d,%d]", &q1, &q2) == 2) {
        if (q1 >= 0 && q1 < MAX_QUBITS) raw_gate_density[q1]++;
        if (q2 >= 0 && q2 < MAX_QUBITS) raw_gate_density[q2]++;
        long long d = qubit_depth[q1] > qubit_depth[q2] ? qubit_depth[q1] : qubit_depth[q2];
        d++;
        if (q1 >= 0 && q1 < MAX_QUBITS) qubit_depth[q1] = d;
        if (q2 >= 0 && q2 < MAX_QUBITS) qubit_depth[q2] = d;
        if (d > circuit_depth) circuit_depth = d;
        if (is_2q_gate(gate_name)) {
            long long d2 = qubit_depth_2q[q1] > qubit_depth_2q[q2] ? qubit_depth_2q[q1] : qubit_depth_2q[q2];
            d2++;
            if (q1 >= 0 && q1 < MAX_QUBITS) qubit_depth_2q[q1] = d2;
            if (q2 >= 0 && q2 < MAX_QUBITS) qubit_depth_2q[q2] = d2;
            if (d2 > circuit_depth_2q) circuit_depth_2q = d2;
        }
    } else if (sscanf(qubits_json, "[%d]", &q1) == 1) {
        if (q1 >= 0 && q1 < MAX_QUBITS) {
            raw_gate_density[q1]++;
            qubit_depth[q1]++;
            if (qubit_depth[q1] > circuit_depth) circuit_depth = qubit_depth[q1];
        }
    }
    fprintf(trace_file,
        "{\"schema_version\":\"1.2\",\"event\":\"gate_apply\","
        "\"gate\":\"%s\",\"qubits\":%s,\"angle\":%.6f,\"step\":%lld,"
        "\"elapsed_us\":%lld}\n",
        gate_name, qubits_json, angle, trace_step, elapsed);
    trace_event_count++;
    fflush(trace_file);
}

// Emit entanglement_update event (called after 2-qubit gates)
void rods_trace_entangle(const char *gate_name, long long q1, long long q2) {
    if (!trace_enabled) return;
    int pre_components = uf_num_components();
    uf_union((int)q1, (int)q2);
    int post_components = uf_num_components();
    int max_comp = uf_max_component();
    long long elapsed = trace_time_us() - trace_start_us;

    fprintf(trace_file,
        "{\"schema_version\":\"1.2\",\"event\":\"entanglement_update\","
        "\"gate\":\"%s\",\"qubits\":[%lld,%lld],\"step\":%lld,"
        "\"pre_components\":%d,\"post_components\":%d,"
        "\"max_component_size\":%d,"
        "\"components\":%s,\"elapsed_us\":%lld}\n",
        gate_name, q1, q2, trace_step,
        pre_components, post_components, max_comp,
        uf_components_json(), elapsed);
    trace_event_count++;
    fflush(trace_file);
}

// Emit amplitude_sparsity event
void rods_trace_sparsity(long long nonzero, long long total) {
    if (!trace_enabled) return;
    long long elapsed = trace_time_us() - trace_start_us;
    double sparsity = 1.0 - (double)nonzero / (double)total;
    fprintf(trace_file,
        "{\"schema_version\":\"1.2\",\"event\":\"amplitude_sparsity\","
        "\"step\":%lld,\"nonzero\":%lld,\"total\":%lld,"
        "\"sparsity\":%.6f,\"elapsed_us\":%lld}\n",
        trace_step, nonzero, total, sparsity, elapsed);
    trace_event_count++;
    fflush(trace_file);
}

// Emit measurement_event
void rods_trace_measure(long long qubit, long long outcome, double probability,
                        long long collapse_count) {
    if (!trace_enabled) return;
    long long elapsed = trace_time_us() - trace_start_us;
    fprintf(trace_file,
        "{\"schema_version\":\"1.2\",\"event\":\"measurement_event\","
        "\"qubit\":%lld,\"outcome\":%lld,\"probability\":%.6f,"
        "\"collapse_affected\":%lld,\"step\":%lld,\"elapsed_us\":%lld}\n",
        qubit, outcome, probability, collapse_count, trace_step, elapsed);
    trace_event_count++;
    fflush(trace_file);
}

// Emit algorithm_phase event
void rods_trace_phase(const char *phase_name, const char *detail) {
    if (!trace_enabled) return;
    long long elapsed = trace_time_us() - trace_start_us;
    fprintf(trace_file,
        "{\"schema_version\":\"1.2\",\"event\":\"algorithm_phase\","
        "\"phase\":\"%s\",\"detail\":\"%s\",\"step\":%lld,"
        "\"elapsed_us\":%lld}\n",
        phase_name, detail, trace_step, elapsed);
    trace_event_count++;
    fflush(trace_file);
}

// Emit checker_coverage (per-iteration summary)
void rods_trace_iteration(long long iteration, long long total_gates,
                          double target_prob, int n_components) {
    if (!trace_enabled) return;
    long long elapsed = trace_time_us() - trace_start_us;
    fprintf(trace_file,
        "{\"schema_version\":\"1.2\",\"event\":\"checker_coverage\","
        "\"iteration\":%lld,\"total_gates\":%lld,"
        "\"target_probability\":%.6f,\"entanglement_components\":%d,"
        "\"step\":%lld,\"elapsed_us\":%lld}\n",
        iteration, total_gates, target_prob, n_components,
        trace_step, elapsed);
    trace_event_count++;
    fflush(trace_file);
}

// Emit gate_influence event — causal link between a gate and measurement
void rods_trace_gate_influence(long long gate_step, long long measurement_step,
                               const char *influence_type, long long chain_length) {
    if (!trace_enabled) return;
    long long elapsed = trace_time_us() - trace_start_us;
    fprintf(trace_file,
        "{\"schema_version\":\"1.2\",\"event\":\"gate_influence\","
        "\"gate_step\":%lld,\"measurement_step\":%lld,"
        "\"influence_type\":\"%s\",\"chain_length\":%lld,"
        "\"step\":%lld,\"elapsed_us\":%lld}\n",
        gate_step, measurement_step, influence_type, chain_length,
        trace_step, elapsed);
    trace_event_count++;
    fflush(trace_file);
}

// Simple int to string (for building JSON qubit arrays)
const char *rods_i64_to_str(long long x) {
    char *buf = (char *)malloc(32);
    snprintf(buf, 32, "%lld", x);
    return buf;
}

// Count nonzero amplitudes above threshold
// sv is a Vec<i64> of complex handles; threshold is f64-as-i64
static double i2f_local(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }

long long rods_count_nonzero(long long sv_ptr, long long threshold_bits) {
    // sv_ptr is a NVec*
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *v = (NVec *)sv_ptr;
    double threshold = i2f_local(threshold_bits);
    // Audit fix HIGH-LAYER9B-004 (2026-05-08): the API surface is
    // documented as "amplitude threshold" — count amps with |amp| >
    // threshold. Prior code compared `|amp|^2 > threshold`, which
    // mixed units and silently filtered at threshold^2 (e.g., a 0.1
    // arg actually filtered |amp| > 0.316). We now compare against
    // probability `mag_sq > threshold * threshold`, restoring the
    // documented `|amp| > threshold` semantics.
    double thr_sq = threshold * threshold;
    int count = 0;
    for (int i = 0; i < v->len; i++) {
        long long *cx = (long long *)v->data[i]; // complex = pair of i64
        double re = i2f_local(cx[0]);
        double im = i2f_local(cx[1]);
        double mag_sq = re * re + im * im;
        if (mag_sq > thr_sq) count++;
    }
    return count;
}

// =====================================================
// Closed-form Ridge Regression (Phase 1 tensor runtime)
// =====================================================
static double ii2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long ff2i(double f) { long long i; memcpy(&i, &f, sizeof(long long)); return i; }

// =====================================================
// Mersenne Twister 19937 — matches numpy exactly
// =====================================================
#define MT_N 624
#define MT_M 397
#define MT_MATRIX_A 0x9908b0dfUL
#define MT_UPPER_MASK 0x80000000UL
#define MT_LOWER_MASK 0x7fffffffUL

typedef struct {
    unsigned long mt[MT_N];
    int mti;
} MT19937;

static void mt_init(MT19937 *state, unsigned long seed) {
    state->mt[0] = seed & 0xffffffffUL;
    for (state->mti = 1; state->mti < MT_N; state->mti++) {
        state->mt[state->mti] =
            (1812433253UL * (state->mt[state->mti-1] ^ (state->mt[state->mti-1] >> 30)) + state->mti);
        state->mt[state->mti] &= 0xffffffffUL;
    }
}

static unsigned long mt_next(MT19937 *state) {
    unsigned long y;
    static unsigned long mag01[2] = {0x0UL, MT_MATRIX_A};
    if (state->mti >= MT_N) {
        int kk;
        for (kk = 0; kk < MT_N - MT_M; kk++) {
            y = (state->mt[kk] & MT_UPPER_MASK) | (state->mt[kk+1] & MT_LOWER_MASK);
            state->mt[kk] = state->mt[kk+MT_M] ^ (y >> 1) ^ mag01[y & 0x1UL];
        }
        for (; kk < MT_N - 1; kk++) {
            y = (state->mt[kk] & MT_UPPER_MASK) | (state->mt[kk+1] & MT_LOWER_MASK);
            state->mt[kk] = state->mt[kk+(MT_M-MT_N)] ^ (y >> 1) ^ mag01[y & 0x1UL];
        }
        y = (state->mt[MT_N-1] & MT_UPPER_MASK) | (state->mt[0] & MT_LOWER_MASK);
        state->mt[MT_N-1] = state->mt[MT_M-1] ^ (y >> 1) ^ mag01[y & 0x1UL];
        state->mti = 0;
    }
    y = state->mt[state->mti++];
    y ^= (y >> 11);
    y ^= (y << 7) & 0x9d2c5680UL;
    y ^= (y << 15) & 0xefc60000UL;
    y ^= (y >> 18);
    return y;
}

// Bounded random: [0, bound) matching numpy's bounded_uint32_t
static int mt_below(MT19937 *state, int bound) {
    unsigned long r;
    if (bound <= 1) return 0;
    // Rejection sampling for unbiased distribution
    unsigned long limit = (0xFFFFFFFFUL / (unsigned long)bound) * (unsigned long)bound;
    do { r = mt_next(state); } while (r >= limit);
    return (int)(r % (unsigned long)bound);
}

// Fisher-Yates shuffle matching numpy's permutation
static void mt_shuffle(int *arr, int n, unsigned long seed) {
    MT19937 state;
    mt_init(&state, seed);
    for (int i = n - 1; i > 0; i--) {
        int j = mt_below(&state, i + 1);
        int tmp = arr[i]; arr[i] = arr[j]; arr[j] = tmp;
    }
}

// Shuffled k-fold CV with MT19937 — matches Python sklearn KFold exactly
// 3 seeds x 5 folds, averaged MAE
// Ridge LOO: leave-one-out cross-validation, returns MAE
// X_vec: flat n*p features, y_vec: n targets
long long nuc_ridge_loo(long long X_vec, long long y_vec, long long n_samples, long long n_feats, long long lambda_bits) {
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *xv = (NVec *)(void *)X_vec;
    NVec *yv = (NVec *)(void *)y_vec;
    double lam = ii2f(lambda_bits);
    int n = (int)n_samples, p = (int)n_feats;

    double total_err = 0;
    for (int hold = 0; hold < n; hold++) {
        // Build train set excluding hold
        int nt = n - 1;
        double *X_tr = (double *)malloc(nt * p * sizeof(double));
        double *y_tr = (double *)malloc(nt * sizeof(double));
        int ti = 0;
        for (int i = 0; i < n; i++) {
            if (i == hold) continue;
            for (int j = 0; j < p; j++)
                X_tr[ti * p + j] = ii2f(xv->data[i * p + j]);
            y_tr[ti] = ii2f(yv->data[i]);
            ti++;
        }

        // Solve (X^T X + lam*I) w = X^T y via Gaussian elimination
        double *A = (double *)calloc((p+1) * p, sizeof(double));
        for (int i = 0; i < nt; i++)
            for (int j = 0; j < p; j++)
                for (int k = 0; k < p; k++)
                    A[j * (p+1) + k] += X_tr[i*p+j] * X_tr[i*p+k];
        for (int j = 0; j < p; j++) A[j*(p+1)+j] += lam;
        for (int i = 0; i < nt; i++)
            for (int j = 0; j < p; j++)
                A[j*(p+1)+p] += X_tr[i*p+j] * y_tr[i];

        // Gauss elimination with partial pivoting
        for (int col = 0; col < p; col++) {
            int pivot = col;
            for (int row = col+1; row < p; row++)
                if (fabs(A[row*(p+1)+col]) > fabs(A[pivot*(p+1)+col])) pivot = row;
            if (pivot != col)
                for (int j = 0; j <= p; j++) {
                    double tmp = A[col*(p+1)+j]; A[col*(p+1)+j] = A[pivot*(p+1)+j]; A[pivot*(p+1)+j] = tmp;
                }
            double diag = A[col*(p+1)+col];
            if (fabs(diag) < 1e-15) continue;
            for (int row = col+1; row < p; row++) {
                double factor = A[row*(p+1)+col] / diag;
                for (int j = col; j <= p; j++)
                    A[row*(p+1)+j] -= factor * A[col*(p+1)+j];
            }
        }
        double *w = (double *)calloc(p, sizeof(double));
        for (int i = p-1; i >= 0; i--) {
            double s = A[i*(p+1)+p];
            for (int j = i+1; j < p; j++) s -= A[i*(p+1)+j] * w[j];
            double diag = A[i*(p+1)+i];
            w[i] = (fabs(diag) > 1e-15) ? s / diag : 0;
        }

        // Predict held-out sample
        double pred = 0;
        for (int j = 0; j < p; j++)
            pred += w[j] * ii2f(xv->data[hold * p + j]);
        double true_val = ii2f(yv->data[hold]);
        total_err += fabs(pred - true_val);

        free(X_tr); free(y_tr); free(A); free(w);
    }

    return ff2i(total_err / n);
}

long long nuc_ridge_cv(long long X_vec, long long y_vec,
                        long long n_samples, long long n_feats,
                        long long k_folds, long long lambda_bits) {
    typedef struct { long long *data; int len; int cap; } NVec;
    NVec *xv = (NVec *)(void *)X_vec;
    NVec *yv = (NVec *)(void *)y_vec;
    double lam = ii2f(lambda_bits);
    int n = (int)n_samples, p = (int)n_feats, k = (int)k_folds;
    int n_seeds = 3;
    unsigned long seeds[3] = {7, 49, 91}; // seed*42+7 for seed=0,1,2

    double grand_total_err = 0;
    int grand_total_test = 0;

    for (int seed_i = 0; seed_i < n_seeds; seed_i++) {
        // Create shuffled index array using MT19937
        int *idx = (int *)malloc(n * sizeof(int));
        for (int i = 0; i < n; i++) idx[i] = i;
        mt_shuffle(idx, n, seeds[seed_i]);

        int fold_size = n / k;
        for (int fold = 0; fold < k; fold++) {
            int ts = fold * fold_size;
            int te = (fold == k - 1) ? n : ts + fold_size;
            int nt = te - ts, nr = n - nt;

            double *Xr = (double *)malloc(nr * p * sizeof(double));
            double *yr = (double *)malloc(nr * sizeof(double));
            double *Xt = (double *)malloc(nt * p * sizeof(double));
            double *yt = (double *)malloc(nt * sizeof(double));

            // Split using shuffled indices
            int ri = 0, ti = 0;
            for (int i = 0; i < n; i++) {
                int orig = idx[i];
                if (i >= ts && i < te) {
                    for (int j = 0; j < p; j++)
                        Xt[ti * p + j] = ii2f(xv->data[orig * p + j]);
                    yt[ti] = ii2f(yv->data[orig]);
                    ti++;
                } else {
                    for (int j = 0; j < p; j++)
                        Xr[ri * p + j] = ii2f(xv->data[orig * p + j]);
                    yr[ri] = ii2f(yv->data[orig]);
                    ri++;
                }
            }

            // NO standardization — match sklearn Ridge default behavior
            // sklearn Ridge solves on raw features

            // A = X^T X + lambda*I
            double *A = (double *)calloc(p * p, sizeof(double));
            for (int i = 0; i < p; i++) {
                for (int j = 0; j < p; j++) {
                    double s = 0;
                    for (int kk = 0; kk < nr; kk++)
                        s += Xr[kk * p + i] * Xr[kk * p + j];
                    A[i * p + j] = s;
                }
                A[i * p + i] += lam;
            }

            // b = X^T y
            double *b = (double *)calloc(p, sizeof(double));
            for (int i = 0; i < p; i++)
                for (int kk = 0; kk < nr; kk++)
                    b[i] += Xr[kk * p + i] * yr[kk];

            // Gaussian elimination with partial pivoting
            for (int kk = 0; kk < p; kk++) {
                int mr = kk;
                double mv = fabs(A[kk * p + kk]);
                for (int i = kk + 1; i < p; i++)
                    if (fabs(A[i * p + kk]) > mv) {
                        mv = fabs(A[i * p + kk]);
                        mr = i;
                    }
                if (mr != kk) {
                    for (int j = 0; j < p; j++) {
                        double t = A[kk*p+j]; A[kk*p+j] = A[mr*p+j]; A[mr*p+j] = t;
                    }
                    double t = b[kk]; b[kk] = b[mr]; b[mr] = t;
                }
                double piv = A[kk * p + kk];
                if (fabs(piv) < 1e-15) continue;
                for (int i = kk + 1; i < p; i++) {
                    double fac = A[i * p + kk] / piv;
                    for (int j = kk; j < p; j++)
                        A[i * p + j] -= fac * A[kk * p + j];
                    b[i] -= fac * b[kk];
                }
            }

            // Back substitution
            double *w = (double *)calloc(p, sizeof(double));
            for (int i = p - 1; i >= 0; i--) {
                double s = b[i];
                for (int j = i + 1; j < p; j++)
                    s -= A[i * p + j] * w[j];
                w[i] = (fabs(A[i * p + i]) > 1e-15) ? s / A[i * p + i] : 0.0;
            }

            // Predict test set
            for (int i = 0; i < nt; i++) {
                double pred = 0;
                for (int j = 0; j < p; j++)
                    pred += w[j] * Xt[i * p + j];
                if (pred < 0) pred = 0;
                if (pred > 1) pred = 1;
                grand_total_err += fabs(pred - yt[i]);
            }
            grand_total_test += nt;

            free(Xr); free(yr); free(Xt); free(yt);
            free(A); free(b); free(w);
        }
        free(idx);
    }

    return ff2i(grand_total_err / grand_total_test);
}
