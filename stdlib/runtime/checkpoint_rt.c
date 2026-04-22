// checkpoint_rt.c — Activation Checkpointing for Nucleor
// Save/restore activations at layer boundaries for memory-bounded training.
// Recompute forward pass segments during backward.
//
// Compile: clang -c stdlib/runtime/checkpoint_rt.c -o target/checkpoint_rt.obj -O2

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ================================================================
//  Checkpoint Store
// ================================================================

#define CKPT_MAX_LAYERS 256

typedef struct {
    double *data;
    int size;     // number of doubles
    int layer_id;
    int valid;
} Checkpoint;

typedef struct {
    Checkpoint checkpoints[CKPT_MAX_LAYERS];
    int n_checkpoints;
    int interval;      // checkpoint every N layers
    long long memory_used;
    long long memory_saved; // estimate of memory saved by not storing intermediate activations
} CheckpointStore;

long long nuc_ckpt_new(long long interval) {
    CheckpointStore *cs = (CheckpointStore *)calloc(1, sizeof(CheckpointStore));
    cs->interval = (int)interval;
    if (cs->interval < 1) cs->interval = 1;
    return (long long)cs;
}

// ================================================================
//  Save activation at a layer
// ================================================================

void nuc_ckpt_save(long long cs_h, long long layer_id, long long data_h, long long size) {
    typedef struct { long long *data; int len; int cap; } NVec;
    CheckpointStore *cs = (CheckpointStore *)(void *)cs_h;
    NVec *data = (NVec *)(void *)data_h;
    int lid = (int)layer_id, n = (int)size;

    // Only checkpoint at intervals
    if (lid % cs->interval != 0) {
        cs->memory_saved += n * sizeof(double);
        return;
    }

    if (cs->n_checkpoints >= CKPT_MAX_LAYERS) return;

    Checkpoint *ckpt = &cs->checkpoints[cs->n_checkpoints++];
    ckpt->layer_id = lid;
    ckpt->size = n;
    ckpt->data = (double *)malloc(n * sizeof(double));
    ckpt->valid = 1;
    for (int i = 0; i < n && i < data->len; i++) {
        double d; long long v = data->data[i]; memcpy(&d, &v, 8);
        ckpt->data[i] = d;
    }
    cs->memory_used += n * sizeof(double);
}

// ================================================================
//  Restore activation for a layer
//  Returns the stored data as Vec<f64>, or 0 if not checkpointed
// ================================================================

long long nuc_ckpt_restore(long long cs_h, long long layer_id) {
    typedef struct { long long *data; int len; int cap; } NVec;
    CheckpointStore *cs = (CheckpointStore *)(void *)cs_h;
    int lid = (int)layer_id;

    for (int i = 0; i < cs->n_checkpoints; i++) {
        if (cs->checkpoints[i].layer_id == lid && cs->checkpoints[i].valid) {
            Checkpoint *ckpt = &cs->checkpoints[i];
            NVec *out = (NVec *)malloc(sizeof(NVec));
            out->len = ckpt->size; out->cap = ckpt->size;
            out->data = (long long *)malloc(ckpt->size * sizeof(long long));
            for (int j = 0; j < ckpt->size; j++) {
                long long v; memcpy(&v, &ckpt->data[j], 8);
                out->data[j] = v;
            }
            return (long long)out;
        }
    }
    return 0; // not found — needs recomputation
}

// ================================================================
//  Find nearest checkpoint before a given layer
// ================================================================

long long nuc_ckpt_nearest_before(long long cs_h, long long layer_id) {
    CheckpointStore *cs = (CheckpointStore *)(void *)cs_h;
    int lid = (int)layer_id;
    int best = -1;
    for (int i = 0; i < cs->n_checkpoints; i++) {
        if (cs->checkpoints[i].valid && cs->checkpoints[i].layer_id <= lid) {
            if (best < 0 || cs->checkpoints[i].layer_id > cs->checkpoints[best].layer_id)
                best = i;
        }
    }
    return best >= 0 ? (long long)cs->checkpoints[best].layer_id : -1;
}

// ================================================================
//  Determine which layers need recomputation for backward at layer_id
//  Returns [start_layer, end_layer] — need to recompute forward from start to end
// ================================================================

long long nuc_ckpt_recompute_range(long long cs_h, long long layer_id) {
    typedef struct { long long *data; int len; int cap; } NVec;
    long long nearest = nuc_ckpt_nearest_before(cs_h, layer_id);
    int start = (nearest >= 0) ? (int)nearest : 0;
    int end = (int)layer_id;

    NVec *range = (NVec *)malloc(sizeof(NVec));
    range->len = 2; range->cap = 2;
    range->data = (long long *)malloc(2 * sizeof(long long));
    range->data[0] = start;
    range->data[1] = end;
    return (long long)range;
}

// ================================================================
//  Clear all checkpoints (between training steps)
// ================================================================

void nuc_ckpt_clear(long long cs_h) {
    CheckpointStore *cs = (CheckpointStore *)(void *)cs_h;
    for (int i = 0; i < cs->n_checkpoints; i++) {
        free(cs->checkpoints[i].data);
        cs->checkpoints[i].data = NULL;
        cs->checkpoints[i].valid = 0;
    }
    cs->n_checkpoints = 0;
    cs->memory_used = 0;
    cs->memory_saved = 0;
}

// ================================================================
//  Memory stats
// ================================================================

long long nuc_ckpt_memory_used(long long cs_h) {
    return ((CheckpointStore *)(void *)cs_h)->memory_used;
}

long long nuc_ckpt_memory_saved(long long cs_h) {
    return ((CheckpointStore *)(void *)cs_h)->memory_saved;
}

long long nuc_ckpt_n_stored(long long cs_h) {
    return ((CheckpointStore *)(void *)cs_h)->n_checkpoints;
}

void nuc_ckpt_free(long long cs_h) {
    CheckpointStore *cs = (CheckpointStore *)(void *)cs_h;
    if (!cs) return;
    nuc_ckpt_clear(cs_h);
    free(cs);
}
