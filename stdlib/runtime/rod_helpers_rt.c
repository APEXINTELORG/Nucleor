// rod_helpers_rt.c — Helper functions for rod interop
// Provides vec_push_s, vec_get_s (string <-> i64 vec bridge)
// and call_fn2, call_fn3 (function pointer callers)

#include <stdlib.h>

// Forward-declare NVec layout (matches nucleor_llvm_rt.c / nucleor_rt)
/* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */

void __nucleor_vec_push(NVec *v, long long x);
long long __nucleor_vec_get(NVec *v, long long i);
void __nucleor_vec_set(NVec *v, long long i, long long x);

// vec_push_s: push a string pointer into an i64 vec
void vec_push_s(long long v, const char *s) {
    __nucleor_vec_push((NVec *)v, (long long)s);
}

// vec_get_s: get a string pointer from an i64 vec
const char *vec_get_s(long long v, long long i) {
    return (const char *)__nucleor_vec_get((NVec *)v, i);
}

// hvec_push_s / hvec_get_s / hvec_set_s: explicit NS_Sage compat aliases
void hvec_push_s(long long v, const char *s) {
    __nucleor_vec_push((NVec *)v, (long long)s);
}

const char *hvec_get_s(long long v, long long i) {
    return (const char *)__nucleor_vec_get((NVec *)v, i);
}

void hvec_set_s(long long v, long long i, const char *s) {
    __nucleor_vec_set((NVec *)v, i, (long long)s);
}

// call_fn2: call a 2-arg function pointer
typedef long long (*fn2_t)(long long, long long);
long long call_fn2(long long fp, long long a, long long b) {
    return ((fn2_t)fp)(a, b);
}

// call_fn3: call a 3-arg function pointer
typedef long long (*fn3_t)(long long, long long, long long);
long long call_fn3(long long fp, long long a, long long b, long long c) {
    return ((fn3_t)fp)(a, b, c);
}
