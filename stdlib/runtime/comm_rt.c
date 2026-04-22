// comm_rt.c — Collective Communication Primitives for Nucleor
// All-reduce (ring), scatter/gather, broadcast, pipeline send/recv.
// For distributed training and multi-device inference.
//
// Compile: clang -c stdlib/runtime/comm_rt.c -o target/comm_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static double _cm_i2f(long long x) { double d; memcpy(&d, &x, 8); return d; }
static long long _cm_f2i(double f) { long long i; memcpy(&i, &f, 8); return i; }

typedef struct { long long *data; int len; int cap; } CMVec;

// ================================================================
//  Simulated Multi-Process Communication
//  For single-machine simulation of distributed training.
//  Each "rank" has its own buffer. Operations simulate communication.
// ================================================================

#define COMM_MAX_RANKS 64

typedef struct {
    int world_size;
    double **buffers;  // [world_size][buffer_size]
    int buffer_size;
} CommWorld;

long long nuc_comm_init(long long world_size, long long buffer_size) {
    int ws = (int)world_size, bs = (int)buffer_size;
    CommWorld *w = (CommWorld *)calloc(1, sizeof(CommWorld));
    w->world_size = ws;
    w->buffer_size = bs;
    w->buffers = (double **)malloc(ws * sizeof(double *));
    for (int i = 0; i < ws; i++) w->buffers[i] = (double *)calloc(bs, sizeof(double));
    return (long long)w;
}

// Set data for a rank
void nuc_comm_set_data(long long wh, long long rank, long long data_h, long long n) {
    CommWorld *w = (CommWorld *)(void *)wh;
    CMVec *data = (CMVec *)(void *)data_h;
    int r = (int)rank, N = (int)n;
    for (int i = 0; i < N && i < w->buffer_size && i < data->len; i++)
        w->buffers[r][i] = _cm_i2f(data->data[i]);
}

// Get data from a rank
long long nuc_comm_get_data(long long wh, long long rank, long long n) {
    CommWorld *w = (CommWorld *)(void *)wh;
    int r = (int)rank, N = (int)n;
    CMVec *out = (CMVec *)malloc(sizeof(CMVec));
    out->len = N; out->cap = N;
    out->data = (long long *)malloc(N * sizeof(long long));
    for (int i = 0; i < N; i++) out->data[i] = _cm_f2i(w->buffers[r][i]);
    return (long long)out;
}

// ================================================================
//  Ring All-Reduce (sum)
//  Simulates k-1 reduce-scatter + k-1 all-gather steps.
//  After completion: all ranks have the sum of all inputs.
// ================================================================

void nuc_comm_allreduce_ring(long long wh, long long n) {
    CommWorld *w = (CommWorld *)(void *)wh;
    int N = (int)n, ws = w->world_size;
    if (ws <= 1) return;

    int chunk = (N + ws - 1) / ws;
    double *tmp = (double *)malloc(chunk * sizeof(double));

    // Phase 1: Reduce-Scatter
    for (int step = 0; step < ws - 1; step++) {
        for (int r = 0; r < ws; r++) {
            int send_chunk = ((r - step - 1 + ws) % ws);
            int recv_chunk = ((r - step + ws) % ws);
            int src = (r + 1) % ws;
            int send_start = send_chunk * chunk;
            int recv_start = recv_chunk * chunk;

            // rank r receives from src and adds to its chunk
            for (int i = 0; i < chunk && recv_start + i < N; i++) {
                w->buffers[r][recv_start + i] += w->buffers[src][recv_start + i];
            }
        }
    }

    // Phase 2: All-Gather
    for (int step = 0; step < ws - 1; step++) {
        for (int r = 0; r < ws; r++) {
            int send_chunk = ((r - step + ws) % ws);
            int src = (r + 1) % ws;
            int start = send_chunk * chunk;

            // rank r copies chunk from src
            for (int i = 0; i < chunk && start + i < N; i++) {
                w->buffers[r][start + i] = w->buffers[src][start + i];
            }
        }
    }
    free(tmp);
}

// ================================================================
//  Broadcast (rank 0 sends to all)
// ================================================================

void nuc_comm_broadcast(long long wh, long long src_rank, long long n) {
    CommWorld *w = (CommWorld *)(void *)wh;
    int sr = (int)src_rank, N = (int)n;
    for (int r = 0; r < w->world_size; r++) {
        if (r == sr) continue;
        memcpy(w->buffers[r], w->buffers[sr], N * sizeof(double));
    }
}

// ================================================================
//  Reduce-Scatter: each rank gets 1/world_size of the sum
// ================================================================

void nuc_comm_reduce_scatter(long long wh, long long n) {
    CommWorld *w = (CommWorld *)(void *)wh;
    int N = (int)n, ws = w->world_size;
    int chunk = N / ws;

    // Sum all ranks
    double *total = (double *)calloc(N, sizeof(double));
    for (int r = 0; r < ws; r++)
        for (int i = 0; i < N; i++) total[i] += w->buffers[r][i];

    // Each rank gets its chunk
    for (int r = 0; r < ws; r++) {
        memset(w->buffers[r], 0, N * sizeof(double));
        for (int i = 0; i < chunk; i++)
            w->buffers[r][i] = total[r * chunk + i];
    }
    free(total);
}

// ================================================================
//  All-Gather: each rank contributes its chunk, all get full result
// ================================================================

void nuc_comm_all_gather(long long wh, long long chunk_size) {
    CommWorld *w = (CommWorld *)(void *)wh;
    int cs = (int)chunk_size, ws = w->world_size;

    double *gathered = (double *)malloc(ws * cs * sizeof(double));
    for (int r = 0; r < ws; r++)
        memcpy(gathered + r * cs, w->buffers[r], cs * sizeof(double));

    for (int r = 0; r < ws; r++)
        memcpy(w->buffers[r], gathered, ws * cs * sizeof(double));
    free(gathered);
}

// ================================================================
//  Gradient Accumulation Helper
// ================================================================

typedef struct {
    double *accum;
    int size;
    int step;
    int accum_steps;
} GradAccum;

long long nuc_comm_grad_accum_new(long long size, long long accum_steps) {
    GradAccum *ga = (GradAccum *)calloc(1, sizeof(GradAccum));
    ga->size = (int)size;
    ga->accum_steps = (int)accum_steps;
    ga->accum = (double *)calloc(ga->size, sizeof(double));
    return (long long)ga;
}

// Add micro-batch gradient. Returns 1 if accumulation complete, 0 otherwise.
long long nuc_comm_grad_accum_add(long long ga_h, long long grad_h) {
    GradAccum *ga = (GradAccum *)(void *)ga_h;
    CMVec *grad = (CMVec *)(void *)grad_h;
    for (int i = 0; i < ga->size && i < grad->len; i++)
        ga->accum[i] += _cm_i2f(grad->data[i]);
    ga->step++;
    return (ga->step >= ga->accum_steps) ? 1 : 0;
}

// Get accumulated gradient (divided by accum_steps)
long long nuc_comm_grad_accum_get(long long ga_h) {
    GradAccum *ga = (GradAccum *)(void *)ga_h;
    CMVec *out = (CMVec *)malloc(sizeof(CMVec));
    out->len = ga->size; out->cap = ga->size;
    out->data = (long long *)malloc(ga->size * sizeof(long long));
    double scale = 1.0 / ga->accum_steps;
    for (int i = 0; i < ga->size; i++)
        out->data[i] = _cm_f2i(ga->accum[i] * scale);
    return (long long)out;
}

void nuc_comm_grad_accum_reset(long long ga_h) {
    GradAccum *ga = (GradAccum *)(void *)ga_h;
    memset(ga->accum, 0, ga->size * sizeof(double));
    ga->step = 0;
}

void nuc_comm_free(long long wh) {
    CommWorld *w = (CommWorld *)(void *)wh;
    if (!w) return;
    for (int i = 0; i < w->world_size; i++) free(w->buffers[i]);
    free(w->buffers); free(w);
}
