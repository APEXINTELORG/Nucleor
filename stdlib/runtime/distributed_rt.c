/* distributed_rt.c — RFC-0055 Phase A: process-local
 * distributed-collectives state. Single-rank pass-through;
 * Phase B promotes to NCCL / RCCL / MPI / RDMA dispatch. */

#include <stdio.h>
#include <stdlib.h>

static long long _nuc_dist_rank = 0;
static long long _nuc_dist_world = 1;
static long long _nuc_dist_calls = 0;

long long nuc_dist_init(long long rank, long long world_size) {
    if (rank < 0) rank = 0;
    if (world_size < 1) world_size = 1;
    _nuc_dist_rank = rank;
    _nuc_dist_world = world_size;
    return 0;
}

long long nuc_dist_rank(void) { return _nuc_dist_rank; }
long long nuc_dist_world_size(void) { return _nuc_dist_world; }

long long nuc_dist_barrier(void) {
    _nuc_dist_calls++;
    return 0;
}

long long nuc_dist_call_count(void) { return _nuc_dist_calls; }

long long nuc_dist_reset(void) {
    _nuc_dist_rank = 0;
    _nuc_dist_world = 1;
    _nuc_dist_calls = 0;
    return 0;
}
