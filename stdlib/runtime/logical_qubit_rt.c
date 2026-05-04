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
static int _nuc_lq_count = 0;

long long nuc_lq_register(long long code_id, long long distance) {
    if (_nuc_lq_count >= NUC_LQ_MAX) return -1;
    NucLogicalQubit *lq = &_nuc_lqs[_nuc_lq_count];
    lq->code_id = code_id;
    lq->distance = distance;
    lq->in_use = 1;
    _nuc_lq_count++;
    return (long long)(_nuc_lq_count - 1);
}

long long nuc_lq_count(void) { return (long long)_nuc_lq_count; }

long long nuc_lq_code(long long handle) {
    if (handle < 0 || handle >= _nuc_lq_count) return 0;
    return _nuc_lqs[(int)handle].code_id;
}

long long nuc_lq_distance(long long handle) {
    if (handle < 0 || handle >= _nuc_lq_count) return 0;
    return _nuc_lqs[(int)handle].distance;
}

long long nuc_lq_clear(void) {
    for (int i = 0; i < _nuc_lq_count; i++) {
        memset(&_nuc_lqs[i], 0, sizeof(NucLogicalQubit));
    }
    _nuc_lq_count = 0;
    return 0;
}
