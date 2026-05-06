/* logical_qubit_rt.c — RFC-0054 Phase A: process-local registry
 * for logical-qubit handles. Phase B promotes to per-code
 * decoder dispatch + physical-qubit resource allocation. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUC_LQ_MAX 256

typedef struct {
    long long code_id;
    long long distance;
    int in_use;
} NucLogicalQubit;

static NucLogicalQubit _nuc_lqs[NUC_LQ_MAX];

long long nuc_lq_register(long long code_id, long long distance) {
    for (int i = 0; i < NUC_LQ_MAX; i++) {
        if (!_nuc_lqs[i].in_use) {
            NucLogicalQubit *lq = &_nuc_lqs[i];
            lq->code_id = code_id;
            lq->distance = distance;
            lq->in_use = 1;
            return (long long)i;
        }
    }
    return -1;
}

long long nuc_lq_count(void) {
    long long count = 0;
    for (int i = 0; i < NUC_LQ_MAX; i++) {
        if (_nuc_lqs[i].in_use) count++;
    }
    return count;
}

long long nuc_lq_code(long long handle) {
    if (handle < 0 || handle >= NUC_LQ_MAX) return 0;
    if (!_nuc_lqs[(int)handle].in_use) return 0;
    return _nuc_lqs[(int)handle].code_id;
}

long long nuc_lq_distance(long long handle) {
    if (handle < 0 || handle >= NUC_LQ_MAX) return 0;
    if (!_nuc_lqs[(int)handle].in_use) return 0;
    return _nuc_lqs[(int)handle].distance;
}

long long nuc_lq_release(long long handle) {
    if (handle < 0 || handle >= NUC_LQ_MAX) return 0;
    if (!_nuc_lqs[(int)handle].in_use) return 0;
    memset(&_nuc_lqs[(int)handle], 0, sizeof(NucLogicalQubit));
    return 1;
}

long long nuc_lq_clear(void) {
    for (int i = 0; i < NUC_LQ_MAX; i++) {
        memset(&_nuc_lqs[i], 0, sizeof(NucLogicalQubit));
    }
    return 0;
}
