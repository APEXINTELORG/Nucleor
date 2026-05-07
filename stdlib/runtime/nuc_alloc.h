/* nuc_alloc.h -- shared OOM-aware allocator wrappers for every
   Nucleor runtime translation unit.

   Pre-v0.3.234, every rt file (~150 of them) called bare
   malloc/realloc/calloc and silently dereferenced the result on
   failure -- a NULL return crashed with a useless SIGSEGV deep
   inside whatever helper triggered the alloc. Only the always-
   linked nucleor_llvm_rt.c had the OOM-panic wrappers, because
   it #defined malloc/realloc inside its own TU.

   v0.3.234: this header centralizes the wrappers and is force-
   included into every TU via clang -include in the s1 link
   command (`compiler/nucleor_s1_compiler.nr`). It honors the
   existing NUCLEOR_OOM_LENIENT=1 contract (return NULL instead of
   panicking) so adopters who handle OOM themselves still get the
   legacy behavior on opt-in. */

#ifndef NUC_ALLOC_H
#define NUC_ALLOC_H

/* Enable GNU extensions on Linux/POSIX so that SCHED_IDLE and other
   glibc extensions are visible. Must come before any system header. */
#ifndef _WIN32
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#endif

/* Suppress MSVC's CRT_INSECURE_DEPRECATE on getenv/etc. nucleor_llvm_rt.c
   already does this for itself; but when this header is force-included
   into other rt TUs that DON'T set the macro, the deprecation warnings
   resurface. Set it before <stdlib.h> is pulled in.                  */
#ifndef _CRT_SECURE_NO_WARNINGS
#define _CRT_SECURE_NO_WARNINGS
#endif

#include <stdio.h>
#include <stdlib.h>
#ifndef _WIN32
#include <execinfo.h>
#endif

/* Per-TU cache of the env lookup. The env value is read once on
   first call inside each TU and reused. The function is static so
   each TU gets its own copy (fine -- the answer is identical). */
static int _nuc_alloc_oom_lenient(void) {
    static int cached = 0;  /* 0=uncached, 1=panic, 2=lenient */
    if (cached == 0) {
        const char *e = getenv("NUCLEOR_OOM_LENIENT");
        cached = (e && e[0] == '1') ? 2 : 1;
    }
    return cached == 2;
}

static void *_nuc_alloc_xmalloc(size_t n) {
    void *p = malloc(n);
    if (!p && n > 0 && !_nuc_alloc_oom_lenient()) {
        fprintf(stderr, "PANIC: out of memory: malloc(%zu) failed (set NUCLEOR_OOM_LENIENT=1 to suppress)\n", n);
        fflush(stderr); exit(1);
    }
    return p;
}

static void *_nuc_alloc_xrealloc(void *p, size_t n) {
    void *r = realloc(p, n);
    if (!r && n > 0 && !_nuc_alloc_oom_lenient()) {
        fprintf(stderr, "PANIC: out of memory: realloc(%zu) failed (set NUCLEOR_OOM_LENIENT=1 to suppress)\n", n);
#ifndef _WIN32
        if (getenv("NUCLEOR_TRACE_OOM")) {
            void *bt[32];
            int bt_n = backtrace(bt, 32);
            char **bt_syms = backtrace_symbols(bt, bt_n);
            fprintf(stderr, "  backtrace (top %d frames):\n", bt_n);
            for (int i = 0; i < bt_n && bt_syms; i++) {
                fprintf(stderr, "    %s\n", bt_syms[i]);
            }
            free(bt_syms);
        }
#endif
        fflush(stderr); exit(1);
    }
    return r;
}

static void *_nuc_alloc_xcalloc(size_t nmemb, size_t size) {
    void *p = calloc(nmemb, size);
    if (!p && nmemb > 0 && size > 0 && !_nuc_alloc_oom_lenient()) {
        fprintf(stderr, "PANIC: out of memory: calloc(%zu, %zu) failed (set NUCLEOR_OOM_LENIENT=1 to suppress)\n", nmemb, size);
        fflush(stderr); exit(1);
    }
    return p;
}

/* Replace the bare-libc symbols. Order matters: the macros must
   come AFTER the wrapper functions reference malloc/realloc/calloc
   so the wrappers see the real libc symbols, not themselves. */
#undef malloc
#undef realloc
#undef calloc
#define malloc(N) _nuc_alloc_xmalloc((size_t)(N))
#define realloc(P, N) _nuc_alloc_xrealloc((void *)(P), (size_t)(N))
#define calloc(NM, SZ) _nuc_alloc_xcalloc((size_t)(NM), (size_t)(SZ))

#endif /* NUC_ALLOC_H */
