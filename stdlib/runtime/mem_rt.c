// mem_rt.c — Memory management extensions for Nucleor runtime
// Adds vec_free and vec_clear to enable long-running experiments
// without unbounded memory growth.
//
// These are opt-in: existing code works unchanged. Call vec_free
// on Vecs you're done with, vec_clear to reuse without realloc.
//
// Compile: clang -c stdlib/runtime/mem_rt.c -o target/mem_rt.obj -O2

#include <stdlib.h>
#include <string.h>

// NVec must match nucleor_llvm_rt.c exactly
typedef struct { long long *data; int len; int cap; } NVec;

// Free a Vec and its data array. Handle becomes invalid after this call.
void nuc_vec_free(long long handle) {
    NVec *v = (NVec *)(void *)(size_t)handle;
    if (!v) return;
    if (v->data) free(v->data);
    free(v);
}

// Reset Vec length to 0 without freeing. Keeps allocation for reuse.
// Next vec_push starts filling from index 0 again.
void nuc_vec_clear(long long handle) {
    NVec *v = (NVec *)(void *)(size_t)handle;
    if (!v) return;
    v->len = 0;
}

// Get current memory footprint of a Vec in bytes (data + struct).
long long nuc_vec_mem_bytes(long long handle) {
    NVec *v = (NVec *)(void *)(size_t)handle;
    if (!v) return 0;
    return (long long)(sizeof(NVec) + v->cap * sizeof(long long));
}
