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

/* Lane 2 audit fix A1 (2026-05-08): NVec definition single-sourced
   in stdlib/runtime/nvec.h, force-included by clang via nuc_alloc.h.
   Local redeclaration removed to prevent layout drift between this
   TU and the canonical layout in nucleor_llvm_rt.c. */

// Free a Vec and its data array. Handle becomes invalid after this call.
void nuc_vec_free(long long handle) {
    NVec *v = (NVec *)(void *)(size_t)handle;
    if (!v) return;
    if (v->data && v->data != v->inline_data) free(v->data);
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
    if (v->data == v->inline_data) return (long long)sizeof(NVec);
    return (long long)(sizeof(NVec) + v->cap * sizeof(long long));
}
