// nucleor_llvm_rt.c — Minimal runtime shim for LLVM-emitted Nucleor programs
// Provides the __nucleor_* symbols that llvm_emitter.nr declares as external.
// This is the bridge between LLVM IR output and the OS.
// Target: x86_64-pc-windows-msvc (also works on Linux with minor changes)

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <errno.h>
#include <limits.h>
#ifdef _WIN32
#include <windows.h>
#include <dbghelp.h>
#endif

/* v0.3.234: shared OOM-aware allocator wrappers. The header is
   also force-included into every other rt TU via clang -include
   from the s1 link command, but we include it explicitly here so
   this file still compiles cleanly when invoked outside the s1
   wrapping (e.g., during runtime smoke tests).                  */
#include "nuc_alloc.h"

// v0.8.82 NUM-G8 Phase 1 — thread-local storage portability macro.
// Defined here at the top so any later TU section can mark a static
// as per-thread without redefining. Hoisted from line ~5861 where
// it was originally introduced for #[max_depth] counters.
#if defined(_MSC_VER)
#define NUCLEOR_TLS __declspec(thread)
#else
#define NUCLEOR_TLS _Thread_local
#endif

// v0.3.215: NUC-FEEDBACK runtime safety -- OOM PANIC. Pre-fix any
// of the 171 malloc/realloc call sites that returned NULL on memory
// exhaustion would silently feed NULL into the next memcpy/store
// and segfault (effectively abort, but with no diagnostic and no
// indication that allocation failed). The strict-by-default safety
// bar requires explicit panic with allocation size in the message.
//
// Implementation: wrap all malloc/realloc through static inline
// xmalloc/xrealloc that panic on NULL, then redefine the standard
// names via macros so all 171 sites pick up the wrapper without
// per-site edits. Opt-out via NUCLEOR_OOM_LENIENT=1 (returns NULL,
// adopters then need their own handling -- the legacy segfault
// path is restored).
/* v0.3.234: OOM-aware malloc/realloc/calloc wrappers were
   collapsed into the shared header `nuc_alloc.h` (force-included
   into every Nucleor runtime TU via clang -include in the s1
   link command). The header preserves the v0.3.232+ panic
   contract and honors NUCLEOR_OOM_LENIENT=1.

   Local thin aliases keep the legacy `_nuc_xmalloc` / `_nuc_xrealloc`
   names available so call sites in this file (which call the
   wrappers explicitly) stay readable. */
#define _oom_lenient _nuc_alloc_oom_lenient
#define _nuc_xmalloc _nuc_alloc_xmalloc
#define _nuc_xrealloc _nuc_alloc_xrealloc
#define _nuc_xcalloc _nuc_alloc_xcalloc

// v0.3.233: cap-doubling overflow guard. Centralizes the
// "doubling cap exceeds safe i64 range" check used by every
// vec/sb/string growth path. Pre-fix every site did
// `cap *= 2` -> if cap was >= LLONG_MAX/2 the multiply wrapped
// negative, the subsequent `cap * sizeof(T)` cast to size_t
// produced a huge value, and realloc failed with a confusing
// OOM panic. Post-fix every grow-by-doubling site routes through
// this helper which fails fast with a precise diagnostic.
//
// elem_size is the per-element byte count; we want both
//   cap * 2                           in long long range, AND
//   (cap * 2) * elem_size             in size_t range.
// The combined safe upper bound is (size_t)LLONG_MAX/elem_size/2.
static long long _grow_cap(long long old_cap, size_t elem_size, const char *what) {
    if (old_cap < 0) {
        fprintf(stderr, "PANIC: %s capacity overflow (cap was negative: %lld)\n", what, old_cap);
        fflush(stderr); exit(1);
    }
    /* compute the largest old_cap that survives doubling and
       byte-size compute without wrapping size_t.                */
    long long max_safe;
    if (elem_size == 0) {
        max_safe = LLONG_MAX / 2;
    } else {
        size_t byte_max = (size_t)LLONG_MAX / 2;  /* room for *2 */
        max_safe = (long long)(byte_max / elem_size);
    }
    if (old_cap > max_safe) {
        fprintf(stderr, "PANIC: %s capacity overflow (cap was %lld, doubling at elem_size=%zu would wrap)\n",
                what, old_cap, elem_size);
        fflush(stderr); exit(1);
    }
    return old_cap * 2;
}

// DIAGNOSTIC: allocation counters (active when NUC_TRACE_ALLOC=1)
static long long g_vec_new_count = 0;
static long long g_vec_realloc_bytes = 0;
static long long g_str_concat_count = 0;
static long long g_str_concat_bytes = 0;
static long long g_str_substring_count = 0;
static long long g_str_substring_bytes = 0;
static long long g_sb_new_count = 0;
static long long g_sb_realloc_bytes = 0;
static long long g_misc_str_count = 0;
static long long g_misc_str_bytes = 0;
static int g_alloc_tracer_init = 0;

// v0.3.212: NUCLEOR_PROFILE=1 -- per-runtime-helper call counters,
// dumped at exit. Catches the "this program is calling vec_get 50M
// times" / "str_char_at is the bottleneck" hot-helper class without
// needing a real profiler. Zero overhead for the common (env unset)
// case beyond the unconditional increment per call (~1ns); the env
// check happens once at exit.
static long long g_p_vec_get = 0;
static long long g_p_vec_set = 0;
static long long g_p_vec_push = 0;
static long long g_p_vec_len = 0;
static long long g_p_vec_pop = 0;
static long long g_p_str_char_at = 0;
static long long g_p_str_eq = 0;
static long long g_p_str_len = 0;
static long long g_p_str_concat = 0;
static long long g_p_str_substring = 0;
static long long g_p_hashmap_get = 0;
static long long g_p_hashmap_insert = 0;
static long long g_p_hashmap_contains = 0;
static long long g_p_panic_add = 0;
static long long g_p_panic_mul = 0;
static long long g_p_panic_sub = 0;

typedef struct {
    void *return_address;
    long long count;
} NucProfileCallerCount;

#define NUC_PROFILE_CALLER_BUCKETS 4096
#define NUC_PROFILE_CALLER_TOP_N 10

typedef struct {
    NucProfileCallerCount *buckets;
    long long overflow_count;
} NucProfileCallerTable;

static NucProfileCallerTable g_pc_vec_get;
static NucProfileCallerTable g_pc_vec_set;
static NucProfileCallerTable g_pc_vec_push;
static NucProfileCallerTable g_pc_vec_len;
static NucProfileCallerTable g_pc_str_eq;
static NucProfileCallerTable g_pc_str_len;
static NucProfileCallerTable g_pc_str_concat;
static NucProfileCallerTable g_pc_str_substring;

static int g_profile_summary_registered = 0;

static void _profile_summary(void);

static inline void _profile_register_summary_once(void) {
    if (!g_profile_summary_registered) {
        g_profile_summary_registered = 1;
        atexit(_profile_summary);
    }
}

static inline void _profile_caller_add(NucProfileCallerTable *table, void *return_address) {
    if (!return_address) return;
    NucProfileCallerCount *buckets = table->buckets;
    if (!buckets) {
        buckets = (NucProfileCallerCount *)calloc(NUC_PROFILE_CALLER_BUCKETS, sizeof(NucProfileCallerCount));
        if (!buckets) {
            table->overflow_count++;
            return;
        }
        table->buckets = buckets;
    }
    uintptr_t key = (uintptr_t)return_address;
    unsigned int idx = (unsigned int)((key >> 4) ^ (key >> 12) ^ (key >> 20)) & (NUC_PROFILE_CALLER_BUCKETS - 1);
    for (int probe = 0; probe < NUC_PROFILE_CALLER_BUCKETS; probe++) {
        NucProfileCallerCount *slot = &buckets[(idx + (unsigned int)probe) & (NUC_PROFILE_CALLER_BUCKETS - 1)];
        if (slot->return_address == return_address) {
            slot->count++;
            return;
        }
        if (!slot->return_address) {
            slot->return_address = return_address;
            slot->count = 1;
            return;
        }
    }
    table->overflow_count++;
}

static const char *_profile_symbol_name(void *addr, char *buf, size_t bufsz) {
    if (!buf || bufsz == 0) return "";
    buf[0] = 0;
#ifdef _WIN32
    typedef BOOL (WINAPI *SymInitializeFn)(HANDLE, PCSTR, BOOL);
    typedef BOOL (WINAPI *SymFromAddrFn)(HANDLE, DWORD64, PDWORD64, PSYMBOL_INFO);
    static int tried = 0;
    static HANDLE process = NULL;
    static SymFromAddrFn pSymFromAddr = NULL;
    if (!tried) {
        tried = 1;
        HMODULE dbghelp = LoadLibraryA("dbghelp.dll");
        if (dbghelp) {
            SymInitializeFn pSymInitialize = (SymInitializeFn)GetProcAddress(dbghelp, "SymInitialize");
            pSymFromAddr = (SymFromAddrFn)GetProcAddress(dbghelp, "SymFromAddr");
            process = GetCurrentProcess();
            if (!pSymInitialize || !pSymFromAddr || !pSymInitialize(process, NULL, TRUE)) {
                pSymFromAddr = NULL;
            }
        }
    }
    if (pSymFromAddr) {
        char sym_storage[sizeof(SYMBOL_INFO) + 256];
        memset(sym_storage, 0, sizeof(sym_storage));
        PSYMBOL_INFO sym = (PSYMBOL_INFO)sym_storage;
        sym->SizeOfStruct = sizeof(SYMBOL_INFO);
        sym->MaxNameLen = 255;
        DWORD64 displacement = 0;
        if (pSymFromAddr(process, (DWORD64)(uintptr_t)addr, &displacement, sym)) {
            snprintf(buf, bufsz, "%s+0x%llx", sym->Name, (unsigned long long)displacement);
            return buf;
        }
    }
#endif
    snprintf(buf, bufsz, "%p", addr);
    return buf;
}

static void _profile_dump_callers_for(const char *helper_name, NucProfileCallerTable *table) {
    NucProfileCallerCount *buckets = table->buckets;
    long long total = table->overflow_count;
    if (buckets) {
        for (int i = 0; i < NUC_PROFILE_CALLER_BUCKETS; i++) total += buckets[i].count;
    }
    if (total <= 0) return;

    fprintf(stderr, "  %s: %lld total\n", helper_name, total);
    if (table->overflow_count > 0) {
        fprintf(stderr, "    overflow %lld unbucketed calls\n", table->overflow_count);
    }
    if (!buckets) return;
    void *printed[NUC_PROFILE_CALLER_TOP_N] = {0};
    for (int rank = 0; rank < NUC_PROFILE_CALLER_TOP_N; rank++) {
        int best = -1;
        long long best_count = 0;
        for (int i = 0; i < NUC_PROFILE_CALLER_BUCKETS; i++) {
            if (!buckets[i].return_address || buckets[i].count <= best_count) continue;
            int seen = 0;
            for (int j = 0; j < rank; j++) {
                if (printed[j] == buckets[i].return_address) { seen = 1; break; }
            }
            if (!seen) {
                best = i;
                best_count = buckets[i].count;
            }
        }
        if (best < 0) break;
        printed[rank] = buckets[best].return_address;
        char sym[320];
        double pct = (100.0 * (double)buckets[best].count) / (double)total;
        fprintf(stderr, "    #%02d %-42s %12lld (%5.1f%%)\n",
                rank + 1, _profile_symbol_name(buckets[best].return_address, sym, sizeof(sym)),
                buckets[best].count, pct);
    }
}

static void _profile_callers_summary(void) {
    if (!getenv("NUCLEOR_PROFILE_CALLERS")) return;
    fprintf(stderr, "\n[NUCLEOR_PROFILE_CALLERS] runtime helper call-site attribution:\n");
    _profile_dump_callers_for("str_eq", &g_pc_str_eq);
    _profile_dump_callers_for("vec_get", &g_pc_vec_get);
    _profile_dump_callers_for("vec_len", &g_pc_vec_len);
    _profile_dump_callers_for("vec_set", &g_pc_vec_set);
    _profile_dump_callers_for("vec_push", &g_pc_vec_push);
    _profile_dump_callers_for("str_len", &g_pc_str_len);
    _profile_dump_callers_for("str_concat", &g_pc_str_concat);
    _profile_dump_callers_for("str_substring", &g_pc_str_substring);
    fflush(stderr);
}

static void _profile_summary(void) {
    if (getenv("NUCLEOR_PROFILE")) {
        long long total =
            g_p_vec_get + g_p_vec_set + g_p_vec_push + g_p_vec_len + g_p_vec_pop +
            g_p_str_char_at + g_p_str_eq + g_p_str_len + g_p_str_concat + g_p_str_substring +
            g_p_hashmap_get + g_p_hashmap_insert + g_p_hashmap_contains +
            g_p_panic_add + g_p_panic_mul + g_p_panic_sub;
        fprintf(stderr, "\n[NUCLEOR_PROFILE] runtime helper call counts (top-N hot helpers):\n");
        fprintf(stderr, "  vec_get          %12lld\n", g_p_vec_get);
        fprintf(stderr, "  vec_set          %12lld\n", g_p_vec_set);
        fprintf(stderr, "  vec_push         %12lld\n", g_p_vec_push);
        fprintf(stderr, "  vec_len          %12lld\n", g_p_vec_len);
        fprintf(stderr, "  vec_pop          %12lld\n", g_p_vec_pop);
        fprintf(stderr, "  str_char_at      %12lld\n", g_p_str_char_at);
        fprintf(stderr, "  str_eq           %12lld\n", g_p_str_eq);
        fprintf(stderr, "  str_len          %12lld\n", g_p_str_len);
        fprintf(stderr, "  str_concat       %12lld\n", g_p_str_concat);
        fprintf(stderr, "  str_substring    %12lld\n", g_p_str_substring);
        fprintf(stderr, "  hashmap_get      %12lld\n", g_p_hashmap_get);
        fprintf(stderr, "  hashmap_insert   %12lld\n", g_p_hashmap_insert);
        fprintf(stderr, "  hashmap_contains %12lld\n", g_p_hashmap_contains);
        fprintf(stderr, "  panic_add        %12lld\n", g_p_panic_add);
        fprintf(stderr, "  panic_mul        %12lld\n", g_p_panic_mul);
        fprintf(stderr, "  panic_sub        %12lld\n", g_p_panic_sub);
        fprintf(stderr, "  TOTAL TRACKED    %12lld\n", total);
        if (total > 0) {
            fprintf(stderr, "  hint: any helper > 1M calls may be a hot-loop bottleneck;\n");
            fprintf(stderr, "        any helper > 100M calls usually points at quadratic\n");
            fprintf(stderr, "        algorithmic complexity (e.g. nested loop over Vec.len).\n");
        }
        fflush(stderr);
    }
    _profile_callers_summary();
}

// v0.3.220: profile counters are conditional on NUCLEOR_PROFILE.
// v0.6.73-probe: caller attribution is conditional on
// NUCLEOR_PROFILE_CALLERS. Both knobs share one cached mode check so the
// env-unset hot path stays at one branch-predicted-not-taken test.
#define NUC_PROFILE_MODE_COUNTS  1
#define NUC_PROFILE_MODE_CALLERS 2

static int g_profile_mode = -1;
static inline int _profile_check_env_once(void) {
    if (g_profile_mode < 0) {
        int mode = 0;
        const char *e = getenv("NUCLEOR_PROFILE");
        if (e && e[0]) mode |= NUC_PROFILE_MODE_COUNTS;
        e = getenv("NUCLEOR_PROFILE_CALLERS");
        if (e && e[0] && e[0] != '0') mode |= NUC_PROFILE_MODE_CALLERS;
        g_profile_mode = mode;
        if (g_profile_mode) _profile_register_summary_once();
    }
    return g_profile_mode;
}
/* Old name kept for source compat with the inc sites; now a no-op
   wrapper around the env check. */
static inline void _profile_init_once(void) { (void)_profile_check_env_once(); }
#define NUC_PROFILE_INC(counter) do { \
    int _nuc_profile_mode = g_profile_mode; \
    if (_nuc_profile_mode < 0) { _nuc_profile_mode = _profile_check_env_once(); } \
    if (_nuc_profile_mode & NUC_PROFILE_MODE_COUNTS) { (counter)++; } \
} while (0)
#define NUC_PROFILE_HOT(counter, helper_id) do { \
    int _nuc_profile_mode = g_profile_mode; \
    if (_nuc_profile_mode < 0) { _nuc_profile_mode = _profile_check_env_once(); } \
    if (_nuc_profile_mode) { \
        if (_nuc_profile_mode & NUC_PROFILE_MODE_COUNTS) { (counter)++; } \
        if (_nuc_profile_mode & NUC_PROFILE_MODE_CALLERS) { \
            _profile_caller_add(&g_pc_##helper_id, __builtin_return_address(0)); \
        } \
    } \
} while (0)

static void _alloc_summary(void) {
    if (getenv("NUC_TRACE_ALLOC")) {
        long long total = g_vec_realloc_bytes + g_str_concat_bytes + g_str_substring_bytes + g_sb_realloc_bytes + g_misc_str_bytes;
        fprintf(stderr, "\n[NUC_TRACE_ALLOC]\n");
        fprintf(stderr, "  vec_new:       %8lld calls   %10lld B (%5lld MB)\n", g_vec_new_count, g_vec_realloc_bytes, g_vec_realloc_bytes >> 20);
        fprintf(stderr, "  str_concat:    %8lld calls   %10lld B (%5lld MB)\n", g_str_concat_count, g_str_concat_bytes, g_str_concat_bytes >> 20);
        fprintf(stderr, "  str_substring: %8lld calls   %10lld B (%5lld MB)\n", g_str_substring_count, g_str_substring_bytes, g_str_substring_bytes >> 20);
        fprintf(stderr, "  sb_new:        %8lld calls   %10lld B (%5lld MB)\n", g_sb_new_count, g_sb_realloc_bytes, g_sb_realloc_bytes >> 20);
        fprintf(stderr, "  misc_str:      %8lld calls   %10lld B (%5lld MB)\n", g_misc_str_count, g_misc_str_bytes, g_misc_str_bytes >> 20);
        fprintf(stderr, "  TOTAL TRACKED:                 %10lld B (%5lld MB)\n", total, total >> 20);
        fflush(stderr);
    }
}

// === Print ===
void __nucleor_print_str(const char *s) {
    if (s) printf("%s\n", s);
    else printf("(null)\n");
    fflush(stdout);
}

long long __nucleor_print_i64(long long x) {
    printf("%lld\n", x);
    return 0;
}

void __nucleor_print_bool(int x) {
    printf("%s\n", x ? "true" : "false");
}

// === RFC-0017 stdlib enrichment: hash + print extras ===

// FNV-1a 64-bit hash (cf. Wikipedia FNV).  Determinstic, non-cryptographic.
long long __nucleor_fnv1a_64_str(const char *s) {
    if (!s) return 0;
    unsigned long long h = 0xcbf29ce484222325ULL;
    while (*s) {
        h ^= (unsigned long long)(unsigned char)*s++;
        h *= 0x100000001b3ULL;
    }
    return (long long)h;
}
long long __nucleor_fnv1a_64_i64(long long v) {
    unsigned long long h = 0xcbf29ce484222325ULL;
    int i;
    for (i = 0; i < 8; i++) {
        h ^= (unsigned long long)((v >> (i * 8)) & 0xFFLL);
        h *= 0x100000001b3ULL;
    }
    return (long long)h;
}

// MurmurHash3 64-bit finalizer — fast bit-mixing without state.
long long __nucleor_murmur3_64(long long v) {
    unsigned long long x = (unsigned long long)v;
    x ^= x >> 33;
    x *= 0xff51afd7ed558ccdULL;
    x ^= x >> 33;
    x *= 0xc4ceb9fe1a85ec53ULL;
    x ^= x >> 33;
    return (long long)x;
}

// Print without trailing newline. `print` (the existing builtin) appends \n
// for ergonomic logging; eprint and these `_raw` variants suppress it for
// progress meters / formatted columns / in-place updates.
void __nucleor_print_raw(const char *s) {
    if (s) fputs(s, stdout);
    fflush(stdout);
}
void __nucleor_eprint_raw(const char *s) {
    if (s) fputs(s, stderr);
    fflush(stderr);
}

// === RFC-0028 phase 1: format string builtins ===
// Scan `template` for the first `{}` placeholder and replace it with the
// rendered argument. Returns a heap-allocated str (caller-owned in the
// Nucleor object model).
//
// `format_i64(t, v)`  — render an i64 as decimal
// `format_str(t, s)`  — splice in another string
// `format_hex(t, v)`  — render an i64 as `0x...` lowercase
// `format2_ii(t, a,b)` — two i64 placeholders (left to right)
// `format2_si(t, s,b)` — first {} = str, second {} = i64
//
// Variadic format strings + `Display`/`Debug` traits ship with full
// RFC-0028 in v0.4.

static const char *__nuc_render_format(const char *tmpl, const char *replacement) {
    if (!tmpl) return "";
    const char *p = tmpl;
    while (*p && !(p[0] == '{' && p[1] == '}')) p++;
    if (!*p) {
        // No placeholder — return template verbatim.
        size_t n = strlen(tmpl) + 1;
        char *out = (char *)malloc(n);
        memcpy(out, tmpl, n);
        return out;
    }
    size_t pre_len = (size_t)(p - tmpl);
    size_t rep_len = replacement ? strlen(replacement) : 0;
    size_t suf_len = strlen(p + 2);
    char *out = (char *)malloc(pre_len + rep_len + suf_len + 1);
    memcpy(out, tmpl, pre_len);
    if (replacement) memcpy(out + pre_len, replacement, rep_len);
    memcpy(out + pre_len + rep_len, p + 2, suf_len + 1);
    return out;
}

const char *__nucleor_format_i64(const char *tmpl, long long v) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%lld", v);
    return __nuc_render_format(tmpl, buf);
}
const char *__nucleor_format_str(const char *tmpl, const char *s) {
    return __nuc_render_format(tmpl, s ? s : "");
}
const char *__nucleor_format_hex(const char *tmpl, long long v) {
    char buf[32];
    snprintf(buf, sizeof(buf), "0x%llx", (unsigned long long)v);
    return __nuc_render_format(tmpl, buf);
}
const char *__nucleor_format2_ii(const char *tmpl, long long a, long long b) {
    const char *first = __nucleor_format_i64(tmpl, a);
    const char *out = __nucleor_format_i64(first, b);
    free((void *)first);
    return out;
}
const char *__nucleor_format2_si(const char *tmpl, const char *s, long long b) {
    const char *first = __nucleor_format_str(tmpl, s);
    const char *out = __nucleor_format_i64(first, b);
    free((void *)first);
    return out;
}
// RFC-0028 phase 2 (v0.2.153) — three more two-arg combinations
// commonly needed but missing from the v0.2.6 baseline:
//   ss = two strs (e.g. format!("from={}, to={}", a, b))
//   is = i64 then str (opposite of si)
//   ff = two f64s (passed as i64-bit-cast cells, like format_f64)
// format_f64 is defined further down; forward-declare here so
// format2_ff can reference it without reordering the file.
const char *__nucleor_format_f64(const char *tmpl, long long b);
const char *__nucleor_format2_ss(const char *tmpl, const char *a, const char *b) {
    const char *first = __nucleor_format_str(tmpl, a);
    const char *out = __nucleor_format_str(first, b);
    free((void *)first);
    return out;
}
const char *__nucleor_format2_is(const char *tmpl, long long a, const char *b) {
    const char *first = __nucleor_format_i64(tmpl, a);
    const char *out = __nucleor_format_str(first, b);
    free((void *)first);
    return out;
}
const char *__nucleor_format2_ff(const char *tmpl, long long a_bits, long long b_bits) {
    const char *first = __nucleor_format_f64(tmpl, a_bits);
    const char *out = __nucleor_format_f64(first, b_bits);
    free((void *)first);
    return out;
}
const char *__nucleor_format2_fi(const char *tmpl, long long a_bits, long long b) {
    const char *first = __nucleor_format_f64(tmpl, a_bits);
    const char *out = __nucleor_format_i64(first, b);
    free((void *)first);
    return out;
}
const char *__nucleor_format2_if(const char *tmpl, long long a, long long b_bits) {
    const char *first = __nucleor_format_i64(tmpl, a);
    const char *out = __nucleor_format_f64(first, b_bits);
    free((void *)first);
    return out;
}
const char *__nucleor_format3_fff(const char *tmpl, long long a_bits, long long b_bits, long long c_bits) {
    const char *s1 = __nucleor_format_f64(tmpl, a_bits);
    const char *s2 = __nucleor_format_f64(s1, b_bits);
    free((void *)s1);
    const char *out = __nucleor_format_f64(s2, c_bits);
    free((void *)s2);
    return out;
}

// f64 args arrive as i64 cells (bit-cast); decode then render with %g.
// Uses a local union since `nf64` is typedef'd later in this file and
// NucF64Bits later still.
const char *__nucleor_format_f64(const char *tmpl, long long b) {
    union { long long i; double d; } u;
    u.i = b;
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", u.d);
    return __nuc_render_format(tmpl, buf);
}

// Bool: i64 (0 = false, anything else = true) -> "true"/"false".
const char *__nucleor_format_bool(const char *tmpl, long long b) {
    return __nuc_render_format(tmpl, b == 0 ? "false" : "true");
}

// Three-i64-placeholder format. Same {} convention; left-to-right.
const char *__nucleor_format3_iii(const char *tmpl, long long a, long long b, long long c) {
    const char *s1 = __nucleor_format_i64(tmpl, a);
    const char *s2 = __nucleor_format_i64(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_i64(s2, c);
    free((void *)s2);
    return out;
}
// RFC-0028 phase 3 (v0.2.155) — three more 3-arg format combos:
//   sii = str then i64 then i64 (e.g. format!("{}={}+{}", op, a, b))
//   iss = i64 then str then str (e.g. format!("{}: {} -> {}", n, src, dst))
//   sss = three strs (e.g. format!("{}/{}/{}", a, b, c))
const char *__nucleor_format3_sii(const char *tmpl, const char *a, long long b, long long c) {
    const char *s1 = __nucleor_format_str(tmpl, a);
    const char *s2 = __nucleor_format_i64(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_i64(s2, c);
    free((void *)s2);
    return out;
}
const char *__nucleor_format3_iss(const char *tmpl, long long a, const char *b, const char *c) {
    const char *s1 = __nucleor_format_i64(tmpl, a);
    const char *s2 = __nucleor_format_str(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_str(s2, c);
    free((void *)s2);
    return out;
}
const char *__nucleor_format3_sss(const char *tmpl, const char *a, const char *b, const char *c) {
    const char *s1 = __nucleor_format_str(tmpl, a);
    const char *s2 = __nucleor_format_str(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_str(s2, c);
    free((void *)s2);
    return out;
}

// v0.3.12 RFC-0028 phase 3 — log-line and tag-prefix combos:
//   ssi = str then str then i64 (e.g. format!("[{}] {}: {}", level, key, n))
//   sis = str then i64 then str (e.g. format!("[{} {}] {}", tag, n, msg))
const char *__nucleor_format3_ssi(const char *tmpl, const char *a, const char *b, long long c) {
    const char *s1 = __nucleor_format_str(tmpl, a);
    const char *s2 = __nucleor_format_str(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_i64(s2, c);
    free((void *)s2);
    return out;
}
const char *__nucleor_format3_sis(const char *tmpl, const char *a, long long b, const char *c) {
    const char *s1 = __nucleor_format_str(tmpl, a);
    const char *s2 = __nucleor_format_i64(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_str(s2, c);
    free((void *)s2);
    return out;
}

// v0.3.13 — round out the i/s trio:
//   iis = i64 then i64 then str (e.g. format!("{}/{}: {}", done, total, label))
//   isi = i64 then str then i64 (e.g. format!("{}: {} ({})", n, kind, count))
const char *__nucleor_format3_iis(const char *tmpl, long long a, long long b, const char *c) {
    const char *s1 = __nucleor_format_i64(tmpl, a);
    const char *s2 = __nucleor_format_i64(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_str(s2, c);
    free((void *)s2);
    return out;
}
const char *__nucleor_format3_isi(const char *tmpl, long long a, const char *b, long long c) {
    const char *s1 = __nucleor_format_i64(tmpl, a);
    const char *s2 = __nucleor_format_str(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_i64(s2, c);
    free((void *)s2);
    return out;
}

// v0.3.14 — float-mixing trio. f64 args carry as i64 bits;
// __nucleor_format_f64 decodes and renders %g.
//   iif = i64 then i64 then f64 (e.g. "iter {} of {} ({} sec)")
//   iff = i64 then f64 then f64 (e.g. "{}: x={} y={}")
//   sff = str then f64 then f64 (e.g. "{} at ({}, {})")
const char *__nucleor_format3_iif(const char *tmpl, long long a, long long b, long long c_bits) {
    const char *s1 = __nucleor_format_i64(tmpl, a);
    const char *s2 = __nucleor_format_i64(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_f64(s2, c_bits);
    free((void *)s2);
    return out;
}
const char *__nucleor_format3_iff(const char *tmpl, long long a, long long b_bits, long long c_bits) {
    const char *s1 = __nucleor_format_i64(tmpl, a);
    const char *s2 = __nucleor_format_f64(s1, b_bits);
    free((void *)s1);
    const char *out = __nucleor_format_f64(s2, c_bits);
    free((void *)s2);
    return out;
}
const char *__nucleor_format3_sff(const char *tmpl, const char *a, long long b_bits, long long c_bits) {
    const char *s1 = __nucleor_format_str(tmpl, a);
    const char *s2 = __nucleor_format_f64(s1, b_bits);
    free((void *)s1);
    const char *out = __nucleor_format_f64(s2, c_bits);
    free((void *)s2);
    return out;
}

// v0.3.15 — common metrics/CSV-ish shape:
//   ssf = str then str then f64 (e.g. "{} {}: {}", category, key, value)
const char *__nucleor_format3_ssf(const char *tmpl, const char *a, const char *b, long long c_bits) {
    const char *s1 = __nucleor_format_str(tmpl, a);
    const char *s2 = __nucleor_format_str(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_f64(s2, c_bits);
    free((void *)s2);
    return out;
}
// v0.3.16 — benchmark/aggregation shape:
//   sif = str then i64 then f64 (e.g. "{} ({} items): {}", tag, n, avg)
const char *__nucleor_format3_sif(const char *tmpl, const char *a, long long b, long long c_bits) {
    const char *s1 = __nucleor_format_str(tmpl, a);
    const char *s2 = __nucleor_format_i64(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_f64(s2, c_bits);
    free((void *)s2);
    return out;
}
// v0.3.17 — profile/step shape:
//   isf = i64 then str then f64 (e.g. "Step {} ({}): {}", n, stage, time_ms)
const char *__nucleor_format3_isf(const char *tmpl, long long a, const char *b, long long c_bits) {
    const char *s1 = __nucleor_format_i64(tmpl, a);
    const char *s2 = __nucleor_format_str(s1, b);
    free((void *)s1);
    const char *out = __nucleor_format_f64(s2, c_bits);
    free((void *)s2);
    return out;
}

// --- v0.2.24: parse / stringify primitives ---
// Parsers tolerate leading whitespace and an optional sign; return 0 on
// completely-malformed input. Stringifiers always allocate fresh strings.
// v0.3.217: NUC-FEEDBACK runtime safety -- str_to_int / str_to_i64
// overflow detection. Pre-fix the digit accumulator silently wrapped
// past i64::MAX (a hostile input like "99999999999999999999" would
// return whatever the wrapped accumulator landed at). Same hazard
// class as the binop strict-arith default. Now: use overflow-checked
// arithmetic during accumulation; panic with the offending input on
// overflow. Opt-out via NUCLEOR_INT_STRICT_ARITH=0 (matches the
// runtime opt-out for arithmetic strict mode -- if you wanted wrap
// semantics in your code, you wanted them in your str-to-int parser
// too).
long long __nucleor_str_to_i64(const char *s) {
    if (!s) return 0;
    const char *orig = s;
    while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') s++;
    int neg = 0;
    if (*s == '-') { neg = 1; s++; }
    else if (*s == '+') { s++; }
    long long v = 0;
    int saw = 0;
    int overflow = 0;
    while (*s >= '0' && *s <= '9') {
        long long digit = (long long)(*s - '0');
        /* overflow check: v*10 + digit must fit in i64. */
        if (v > (LLONG_MAX - digit) / 10) overflow = 1;
        v = v * 10 + digit;
        saw = 1;
        s++;
    }
    if (!saw) return 0;
    if (overflow) {
        /* respect NUCLEOR_INT_STRICT_ARITH opt-out (cached at compile
           time on first arithmetic; here we re-check getenv directly
           since this helper may be called before any binop). */
        const char *e = getenv("NUCLEOR_INT_STRICT_ARITH");
        if (!e || e[0] != '0') {
            fprintf(stderr, "PANIC: str_to_i64 overflow: input '%s' exceeds i64 range (set NUCLEOR_INT_STRICT_ARITH=0 to suppress)\n", orig);
            fflush(stderr); exit(1);
        }
        /* lenient: return the wrapped accumulator */
    }
    return neg ? -v : v;
}

long long __nucleor_str_to_f64(const char *s) {
    union { long long i; double d; } u;
    if (!s) { u.d = 0.0; return u.i; }
    char *end;
    double d = strtod(s, &end);
    if (end == s) { u.d = 0.0; return u.i; }
    u.d = d;
    return u.i;
}

// v0.3.136: str_to_int as user-callable runtime helper. The s1
// compiler defines its own internal `str_to_int` fn (compiler/
// nucleor_s1_compiler.nr:32) for lex-time digit parsing, but
// adopters writing `str_to_int("123")` in their .nr code hit
// `clang: undefined value '@str_to_int'` because no runtime helper
// was registered. Symmetric to `__nucleor_str_to_f64`.
// Returns 0 on parse failure (matches str_to_f64's failure mode).
long long __nucleor_str_to_int(const char *s) {
    if (!s) return 0;
    char *end;
    errno = 0;
    long long v = strtoll(s, &end, 10);
    if (end == s) return 0;
    if (errno == ERANGE) {
        const char *e = getenv("NUCLEOR_INT_STRICT_ARITH");
        if (!e || e[0] != '0') {
            fprintf(stderr, "PANIC: str_to_int overflow: input '%s' exceeds i64 range (set NUCLEOR_INT_STRICT_ARITH=0 to suppress)\n", s);
            fflush(stderr); exit(1);
        }
    }
    return v;
}

// v0.5.12: probe-agent finding 2026-05-01-str-to-int-silent-zero-on-invalid.
// `str_to_int` returns 0 on three failure shapes (NULL, empty,
// "not a number") AND on the legitimate input "0" — adopters can't
// distinguish parse-failed-to-zero from parse-succeeded-to-zero.
// Mirrors v0.4.279's `str_char_at_strict` opt-in pattern: lenient
// default stays (perf path / lex-time), strict variant panics on
// invalid input or trailing garbage. Adopters port from Rust's
// `i64::from_str` by switching to this helper.
//
// Failure shapes that panic (vs the lenient default's silent 0):
//   - NULL input
//   - empty string ""
//   - leading-only whitespace
//   - no digits parsed at all (e.g. "not a number", "abc")
//   - trailing garbage after the integer (e.g. "123abc" — silently
//     parses 123 + drops "abc" in the lenient path)
//   - overflow (i64 range exceeded; same panic as the lenient path
//     under NUCLEOR_INT_STRICT_ARITH default)
long long __nucleor_str_to_int_strict(const char *s) {
    if (!s) {
        fprintf(stderr, "PANIC: str_to_int_strict: NULL input\n");
        fflush(stderr); exit(1);
    }
    if (s[0] == 0) {
        fprintf(stderr, "PANIC: str_to_int_strict: empty input string\n");
        fflush(stderr); exit(1);
    }
    char *end;
    errno = 0;
    long long v = strtoll(s, &end, 10);
    if (end == s) {
        fprintf(stderr, "PANIC: str_to_int_strict: input '%s' has no parseable integer\n", s);
        fflush(stderr); exit(1);
    }
    if (errno == ERANGE) {
        fprintf(stderr, "PANIC: str_to_int_strict: input '%s' exceeds i64 range\n", s);
        fflush(stderr); exit(1);
    }
    // Skip trailing whitespace, then check for trailing garbage.
    while (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r') end++;
    if (*end != 0) {
        fprintf(stderr, "PANIC: str_to_int_strict: input '%s' has trailing non-digit garbage starting at '%s'\n", s, end);
        fflush(stderr); exit(1);
    }
    return v;
}

long long __nucleor_str_to_bool(const char *s) {
    if (!s) return 0;
    while (*s == ' ' || *s == '\t') s++;
    // Accept "true"/"false" (case-insensitive) and "1"/"0".
    if ((s[0] == '1') && (s[1] == 0 || s[1] == ' ' || s[1] == '\t')) return 1;
    if ((s[0] == '0') && (s[1] == 0 || s[1] == ' ' || s[1] == '\t')) return 0;
    char low[6] = {0};
    int i = 0;
    while (i < 5 && s[i]) {
        char c = s[i];
        if (c >= 'A' && c <= 'Z') c = (char)(c + 32);
        low[i] = c;
        i++;
    }
    if (strcmp(low, "true") == 0) return 1;
    if (strcmp(low, "false") == 0) return 0;
    return 0;
}

const char *__nucleor_int_to_str(long long v) {
    g_misc_str_count++;
    char buf[32];
    snprintf(buf, sizeof(buf), "%lld", v);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    g_misc_str_bytes += L + 1;
    memcpy(out, buf, L + 1);
    return out;
}

// v0.4.30 RFC-0028 phase 5: `{:+}` force-sign — prints "+N" for v >= 0,
// "-N" for v < 0 (snprintf already prefixes negatives with "-"). The
// macro dispatcher routes `{:+}` here so the arg expression is
// evaluated exactly once (a `cond ? "+" + s : s` lowering would
// double-evaluate side-effecting fn-call args).
const char *__nucleor_int_to_str_force_sign(long long v) {
    g_misc_str_count++;
    char buf[34];
    if (v >= 0) {
        snprintf(buf, sizeof(buf), "+%lld", v);
    } else {
        snprintf(buf, sizeof(buf), "%lld", v);
    }
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    g_misc_str_bytes += L + 1;
    memcpy(out, buf, L + 1);
    return out;
}

const char *__nucleor_f64_to_str(long long b) {
    union { long long i; double d; } u; u.i = b;
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", u.d);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}

// v0.3.204: f32 display helper. The println!/format dispatch chain
// for f32 routed to `f32_to_str` but no implementation existed --
// linking would fail with `undefined value '@f32_to_str'`. The i64
// holds the f32 bit pattern in the low 32 bits (zero-extended), so
// reinterpret as float and print with %g.
const char *__nucleor_f32_to_str(long long b) {
    union { unsigned int i; float f; } u; u.i = (unsigned int)(b & 0xFFFFFFFFLL);
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", (double)u.f);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}

// v0.4.27 RFC-0028 phase 5: precision-aware float-to-string for
// `{:.N}` format spec semantics. Pre-v0.4.27 the spec text was parsed
// but ignored (type dispatch was correct since v0.4.24 — no silent
// miscompute — but the precision had no effect). Now the format-macro
// lowering can route `{:.N}` for f64/f32 args through these helpers.
//   f64_to_str_prec(bits, prec) -> "%.<prec>f"
//   f32_to_str_prec(bits, prec) -> "%.<prec>f" on float reinterpret
// Precision is clamped to [0, 32]. Buffer sized for worst-case
// (f64 max exponent ~308 digits + sign + dot + 32 frac digits = ~344).
const char *__nucleor_f64_to_str_prec(long long b, long long prec) {
    union { long long i; double d; } u; u.i = b;
    if (prec < 0) prec = 0;
    if (prec > 32) prec = 32;
    char buf[384];
    snprintf(buf, sizeof(buf), "%.*f", (int)prec, u.d);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}

const char *__nucleor_f32_to_str_prec(long long b, long long prec) {
    union { unsigned int i; float f; } u; u.i = (unsigned int)(b & 0xFFFFFFFFLL);
    if (prec < 0) prec = 0;
    if (prec > 32) prec = 32;
    char buf[384];
    snprintf(buf, sizeof(buf), "%.*f", (int)prec, (double)u.f);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}

const char *__nucleor_bool_to_str(long long v) {
    const char *src = v != 0 ? "true" : "false";
    size_t L = strlen(src);
    char *out = (char *)malloc(L + 1);
    memcpy(out, src, L + 1);
    return out;
}

// --- v0.2.25: base-conversion (hex / binary / octal) ---
// Stringifiers always emit unsigned 64-bit values (negative inputs are
// reinterpreted as their two's-complement bit pattern). No "0x" / "0b"
// prefix — callers prepend if they want one.
const char *__nucleor_int_to_hex(long long v) {
    char buf[20];
    snprintf(buf, sizeof(buf), "%llx", (unsigned long long)v);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}
// v0.4.37 RFC-0028 phase 5: `{:X}` upper-case hex digits.
const char *__nucleor_int_to_hex_upper(long long v) {
    char buf[20];
    snprintf(buf, sizeof(buf), "%llX", (unsigned long long)v);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}

// v0.4.38 RFC-0028 phase 5: `{:e}` scientific notation for f64.
// `{:.Ne}` uses precision N. The `arg` is the f64 bit pattern.
const char *__nucleor_f64_to_str_sci(long long bits) {
    union { long long i; double d; } u; u.i = bits;
    char buf[64];
    snprintf(buf, sizeof(buf), "%e", u.d);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}
const char *__nucleor_f64_to_str_sci_upper(long long bits) {
    union { long long i; double d; } u; u.i = bits;
    char buf[64];
    snprintf(buf, sizeof(buf), "%E", u.d);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}
const char *__nucleor_f64_to_str_sci_prec(long long bits, long long prec) {
    union { long long i; double d; } u; u.i = bits;
    if (prec < 0) prec = 0;
    if (prec > 32) prec = 32;
    char buf[80];
    snprintf(buf, sizeof(buf), "%.*e", (int)prec, u.d);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}
const char *__nucleor_f64_to_str_sci_prec_upper(long long bits, long long prec) {
    union { long long i; double d; } u; u.i = bits;
    if (prec < 0) prec = 0;
    if (prec > 32) prec = 32;
    char buf[80];
    snprintf(buf, sizeof(buf), "%.*E", (int)prec, u.d);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}
const char *__nucleor_int_to_bin(long long v) {
    unsigned long long u = (unsigned long long)v;
    if (u == 0) {
        char *z = (char *)malloc(2); z[0] = '0'; z[1] = 0;
        return z;
    }
    char buf[65];
    int i = 64;
    buf[i] = 0;
    while (u) {
        buf[--i] = (char)('0' + (int)(u & 1ULL));
        u >>= 1;
    }
    size_t L = (size_t)(64 - i);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf + i, L + 1);
    return out;
}
const char *__nucleor_int_to_oct(long long v) {
    char buf[24];
    snprintf(buf, sizeof(buf), "%llo", (unsigned long long)v);
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return out;
}
// Parsers tolerate leading whitespace, optional sign, and the standard
// "0x" / "0X" / "0b" / "0B" / "0o" / "0O" prefixes when radix matches.
// Returns 0 on completely-malformed input.
// v0.3.225: same overflow check as v0.3.217's str_to_i64. Pre-fix
// `v = v * radix + digit` silently wrapped past i64::MAX on hostile
// input. Now panic with offending input. NUCLEOR_INT_STRICT_ARITH=0
// opts back into legacy wrap.
long long __nucleor_str_to_i64_radix(const char *s, long long radix) {
    if (!s || radix < 2 || radix > 36) return 0;
    const char *orig = s;
    while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') s++;
    int neg = 0;
    if (*s == '-') { neg = 1; s++; }
    else if (*s == '+') { s++; }
    // Strip optional 0x/0b/0o prefix when radix matches.
    if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X') && radix == 16) s += 2;
    else if (s[0] == '0' && (s[1] == 'b' || s[1] == 'B') && radix == 2) s += 2;
    else if (s[0] == '0' && (s[1] == 'o' || s[1] == 'O') && radix == 8) s += 2;
    long long v = 0;
    int saw = 0;
    int overflow = 0;
    while (*s) {
        long long digit;
        if (*s >= '0' && *s <= '9') digit = (long long)(*s - '0');
        else if (*s >= 'a' && *s <= 'z') digit = (long long)(*s - 'a' + 10);
        else if (*s >= 'A' && *s <= 'Z') digit = (long long)(*s - 'A' + 10);
        else break;
        if (digit >= radix) break;
        if (v > (LLONG_MAX - digit) / radix) overflow = 1;
        v = v * radix + digit;
        saw = 1;
        s++;
    }
    if (!saw) return 0;
    if (overflow) {
        const char *e = getenv("NUCLEOR_INT_STRICT_ARITH");
        if (!e || e[0] != '0') {
            fprintf(stderr, "PANIC: str_to_i64_radix overflow: input '%s' radix %lld exceeds i64 range (set NUCLEOR_INT_STRICT_ARITH=0 to suppress)\n", orig, radix);
            fflush(stderr); exit(1);
        }
    }
    return neg ? -v : v;
}
long long __nucleor_parse_hex(const char *s) {
    return __nucleor_str_to_i64_radix(s, 16);
}
long long __nucleor_parse_bin(const char *s) {
    return __nucleor_str_to_i64_radix(s, 2);
}

// --- v0.2.26: padding / justification / explode ---
// fill_char is an i64 ASCII code. If <= 0 or > 127, defaults to ' '.
static char __nuc_fill_char(long long c) {
    if (c <= 0 || c > 127) return ' ';
    return (char)(c & 0xFF);
}
const char *__nucleor_str_pad_left(const char *s, long long width, long long fill) {
    if (!s) s = "";
    size_t L = strlen(s);
    size_t W = (width < (long long)L) ? L : (size_t)width;
    char pad = __nuc_fill_char(fill);
    char *out = (char *)malloc(W + 1);
    size_t prefix = W - L;
    for (size_t i = 0; i < prefix; i++) out[i] = pad;
    memcpy(out + prefix, s, L);
    out[W] = 0;
    return out;
}
const char *__nucleor_str_pad_right(const char *s, long long width, long long fill) {
    if (!s) s = "";
    size_t L = strlen(s);
    size_t W = (width < (long long)L) ? L : (size_t)width;
    char pad = __nuc_fill_char(fill);
    char *out = (char *)malloc(W + 1);
    memcpy(out, s, L);
    for (size_t i = L; i < W; i++) out[i] = pad;
    out[W] = 0;
    return out;
}
const char *__nucleor_str_center(const char *s, long long width, long long fill) {
    if (!s) s = "";
    size_t L = strlen(s);
    size_t W = (width < (long long)L) ? L : (size_t)width;
    char pad = __nuc_fill_char(fill);
    size_t total_pad = W - L;
    size_t left_pad = total_pad / 2;
    size_t right_pad = total_pad - left_pad;
    char *out = (char *)malloc(W + 1);
    for (size_t i = 0; i < left_pad; i++) out[i] = pad;
    memcpy(out + left_pad, s, L);
    for (size_t i = 0; i < right_pad; i++) out[left_pad + L + i] = pad;
    out[W] = 0;
    return out;
}
// str_join, str_lines, str_chars are defined after NVec (further down).


// === Stdin read helpers (RFC-0015 phase 4 completion) ===
// read_line: returns a newline-terminated input line as a heap-allocated str
//            (caller drops trailing \n); empty string on EOF.
// read_int / read_i64: parse one decimal integer from the next token of
//            stdin; returns 0 on parse failure (callers checking for EOF
//            should pair with read_line + str_len + str_to_int from the
//            stdlib).
const char *__nucleor_read_line(void) {
    size_t cap = 256, len = 0;
    char *buf = (char *)malloc(cap);
    if (!buf) return "";
    int c;
    while ((c = fgetc(stdin)) != EOF && c != '\n') {
        if (len + 1 >= cap) {
            cap = (int)_grow_cap((long long)cap, sizeof(char), "stdin readline buffer");
            char *grown = (char *)realloc(buf, cap);
            if (!grown) { free(buf); return ""; }
            buf = grown;
        }
        buf[len++] = (char)c;
    }
    if (c == EOF && len == 0) { free(buf); return ""; }
    buf[len] = 0;
    return buf;
}

long long __nucleor_read_i64(void) {
    long long v = 0;
    if (scanf("%lld", &v) != 1) return 0;
    return v;
}

long long __nucleor_read_byte(void) {
    int c = fgetc(stdin);
    if (c == EOF) return -1;
    return (long long)(unsigned char)c;
}

// rods_f64_encode: provided by quantum_rt.c (via complex.nr #cfile chain)
// Standalone programs without quantum.nr must declare it as extern fn

// === f64 print ===
void __nucleor_print_f64(long long x) {
    // v0.6.47 (probe finding 2026-05-02-print_f64-formatting-issues):
    // pre-fix `printf("%.6f\n", d)` produced unreadable output at extremes:
    // `f64::MAX` became a ~309-digit integer; subnormals (5e-324 etc.)
    // printed as `0.000000` (silent value loss). Now use %g for values
    // outside [1e-6, 1e15] (auto-scientific) and %.6f for values inside
    // (matches the legacy scaled-decimal output for typical adopter
    // numbers). Match Rust's default Display / Debug formatting for f64.
    double d; memcpy(&d, &x, sizeof(double));
    double abs_d = d < 0 ? -d : d;
    if (abs_d == 0.0) {
        printf("0.000000\n");
    } else if (abs_d < 1e-6 || abs_d >= 1e15) {
        // Extremes — scientific notation with full precision.
        printf("%.17g\n", d);
    } else {
        printf("%.6f\n", d);
    }
    fflush(stdout);
}

// === RFC-0002 phase 1 — bare arena builtins (v0.2.154) ===
// The s1 compiler pre-declares `arena_new` / `arena_alloc` /
// `arena_reset` / `arena_destroy` (see get_rt_name in
// nucleor_s1_compiler.nr) and emits calls to `__nucleor_arena_*`
// symbols. v0.2.150 found those symbols dangling — the only
// implementation lived in `allocator_rt.c` under the rod-prefixed
// `nuc_arena_*` names, so any user code that called the bare
// builtins (without `import "stdlib/rods/allocator.nr"`) link-
// failed. v0.2.154 fixes the trap by shipping minimal arena impls
// here in the always-linked main runtime. The rich pool / stack
// surface stays in `allocator.nr`; this is just the bump-arena
// minimum that the s1 builtin path promises.
//
// Layout: header + raw bytes. Allocations are 8-byte aligned and
// fail (return 0) when the arena is exhausted — no resize.
typedef struct { long long capacity; long long offset; } NArena;

long long __nucleor_arena_new(long long size_bytes) {
    if (size_bytes < 0) return 0;
    NArena *a = (NArena *)malloc(sizeof(NArena) + (size_t)size_bytes);
    if (!a) return 0;
    a->capacity = size_bytes;
    a->offset = 0;
    return (long long)(size_t)a;
}
long long __nucleor_arena_alloc(long long h, long long n_bytes) {
    NArena *a = (NArena *)(void *)(size_t)h;
    if (!a || n_bytes <= 0) return 0;
    long long aligned = (n_bytes + 7) & ~7LL;
    if (a->offset + aligned > a->capacity) return 0;
    long long ptr = (long long)(size_t)((char *)(a + 1) + a->offset);
    a->offset += aligned;
    return ptr;
}
void __nucleor_arena_reset(long long h) {
    NArena *a = (NArena *)(void *)(size_t)h;
    if (!a) return;
    a->offset = 0;
}
void __nucleor_arena_destroy(long long h) {
    NArena *a = (NArena *)(void *)(size_t)h;
    if (a) free(a);
}

// === RFC-0029 phase 1 — identifier interner (v0.2.164) ===
// Returns a stable canonical pointer for any input string. Future
// calls with content-equal inputs return the SAME pointer, so
// downstream comparisons can use pointer-equality (i64 ==) instead
// of byte-equality (str_eq). This is the architectural step toward
// the TypeId interner (Ship 3 in MEMORY_FIX_PUNCHLIST.md): once
// strings are interned, comparing types is one i64 == instead of
// O(n) byte walk + transient allocations.
//
// Implementation: open-addressed hash table with linear probing.
// Table doubles when load > 70%. Each unique string is malloc'd
// once (with its content copied) and lives for process lifetime.
// Memory bounded by ~unique-identifier count × avg-length, which
// for the s1 self-host is ~1500 × 16 = 24 KB — negligible vs the
// 185 MB compile baseline. The win is comparison cost, not memory.

typedef struct {
    char **slots;
    long long *hashes;
    long long count;
    long long capacity;
} NIntern;

static NIntern g_intern = { 0, 0, 0, 0 };
static long long g_intern_hits = 0;
static long long g_intern_misses = 0;

static long long _intern_hash(const char *s) {
    // FNV-1a 64
    long long h = (long long)0xcbf29ce484222325LL;
    while (*s) {
        h ^= (long long)(unsigned char)*s++;
        h *= (long long)0x100000001b3LL;
    }
    return h;
}

static void _intern_init(long long cap) {
    g_intern.capacity = cap;
    g_intern.count = 0;
    g_intern.slots = (char **)calloc((size_t)cap, sizeof(char *));
    g_intern.hashes = (long long *)calloc((size_t)cap, sizeof(long long));
}

static void _intern_grow(void) {
    long long old_cap = g_intern.capacity;
    char **old_slots = g_intern.slots;
    long long *old_hashes = g_intern.hashes;
    /* v0.3.233: cap-doubling overflow guard for the string-intern
       table. Use the larger of (char *) / (long long) since both
       arrays are allocated alongside.                              */
    size_t pair_elem = sizeof(char *) >= sizeof(long long) ? sizeof(char *) : sizeof(long long);
    _intern_init(_grow_cap(old_cap, pair_elem, "intern table grow"));
    for (long long i = 0; i < old_cap; i++) {
        if (old_slots[i] == 0) continue;
        long long h = old_hashes[i];
        long long idx = (h & (long long)0x7FFFFFFFFFFFFFFFLL) % g_intern.capacity;
        while (g_intern.slots[idx] != 0) idx = (idx + 1) % g_intern.capacity;
        g_intern.slots[idx] = old_slots[i];
        g_intern.hashes[idx] = h;
        g_intern.count++;
    }
    free(old_slots);
    free(old_hashes);
}

const char *__nucleor_str_intern(const char *s) {
    if (!s) return 0;
    if (g_intern.capacity == 0) _intern_init(256);
    if (g_intern.count * 10 > g_intern.capacity * 7) _intern_grow();
    long long h = _intern_hash(s);
    long long idx = (h & (long long)0x7FFFFFFFFFFFFFFFLL) % g_intern.capacity;
    while (g_intern.slots[idx] != 0) {
        if (g_intern.hashes[idx] == h && strcmp(g_intern.slots[idx], s) == 0) {
            g_intern_hits++;
            return g_intern.slots[idx];
        }
        idx = (idx + 1) % g_intern.capacity;
    }
    // Miss — copy the string and store it. The interned pointer is
    // stable for process lifetime (we never delete from the table).
    size_t L = strlen(s);
    char *owned = (char *)malloc(L + 1);
    memcpy(owned, s, L + 1);
    g_intern.slots[idx] = owned;
    g_intern.hashes[idx] = h;
    g_intern.count++;
    g_intern_misses++;
    return owned;
}

// Diagnostic: returns a stat-pair packed as (hits << 32) | misses
// (truncated). For test inspection only; not promoted to a public
// CLI yet.
long long __nucleor_str_intern_stats(void) {
    return (g_intern_hits << 24) | (g_intern_misses & 0xFFFFFFLL);
}

// === RFC-0030 phase 1 — string arena (v0.2.165) ===
// Lifetime-bound alternative to global str_concat / str_substring
// for transient string work. Caller creates an arena, allocates
// strings against it via str_arena_concat / str_arena_substring,
// then releases the entire arena in one free at end-of-scope.
//
// vs the global allocators: same content, no per-string free
// burden. Best for "build a bunch of intermediate strings, use
// them, throw them all away" patterns — diagnostic message
// formatting, type-checker temporaries, etc.
//
// Implementation: linked list of bump-allocated chunks. Each
// chunk is 64 KB by default; large allocations get their own
// chunk. str_arena_free walks the list and frees every chunk +
// the arena header.

typedef struct NStrArenaChunk {
    struct NStrArenaChunk *next;
    long long capacity;
    long long offset;
    char *data;
} NStrArenaChunk;

typedef struct {
    NStrArenaChunk *head;
    long long total_bytes;
} NStrArena;

#define NUC_STR_ARENA_CHUNK_DEFAULT 65536LL

static NStrArenaChunk *_str_arena_chunk_new(long long min_capacity) {
    long long cap = NUC_STR_ARENA_CHUNK_DEFAULT;
    if (min_capacity > cap) cap = min_capacity;
    NStrArenaChunk *c = (NStrArenaChunk *)malloc(sizeof(NStrArenaChunk));
    c->next = 0;
    c->capacity = cap;
    c->offset = 0;
    c->data = (char *)malloc((size_t)cap);
    return c;
}

long long __nucleor_str_arena_new(void) {
    NStrArena *a = (NStrArena *)malloc(sizeof(NStrArena));
    a->head = _str_arena_chunk_new(NUC_STR_ARENA_CHUNK_DEFAULT);
    a->total_bytes = 0;
    return (long long)(size_t)a;
}

void __nucleor_str_arena_free(long long handle) {
    NStrArena *a = (NStrArena *)(void *)(size_t)handle;
    if (!a) return;
    NStrArenaChunk *c = a->head;
    while (c) {
        NStrArenaChunk *next = c->next;
        free(c->data);
        free(c);
        c = next;
    }
    free(a);
}

long long __nucleor_str_arena_bytes(long long handle) {
    NStrArena *a = (NStrArena *)(void *)(size_t)handle;
    if (!a) return 0;
    return a->total_bytes;
}

// Internal: allocate `n` bytes from the arena. Returns a pointer
// into one of the chunks. The pointer is valid until the arena
// is freed.
static char *_str_arena_alloc(NStrArena *a, long long n) {
    NStrArenaChunk *c = a->head;
    if (c->offset + n > c->capacity) {
        // Need a new chunk — make it big enough for `n` if `n` is
        // larger than the default chunk size.
        NStrArenaChunk *fresh = _str_arena_chunk_new(n);
        fresh->next = a->head;
        a->head = fresh;
        c = fresh;
    }
    char *p = c->data + c->offset;
    c->offset += n;
    a->total_bytes += n;
    return p;
}

// str_arena_concat — same semantics as str_concat but the result
// lives in the arena instead of the global heap. Caller must
// release the arena (str_arena_free) when done with all strings.
const char *__nucleor_str_arena_concat(long long handle, const char *a, const char *b) {
    NStrArena *ar = (NStrArena *)(void *)(size_t)handle;
    if (!a) a = "";
    if (!b) b = "";
    long long la = (long long)strlen(a), lb = (long long)strlen(b);
    char *r = _str_arena_alloc(ar, la + lb + 1);
    memcpy(r, a, (size_t)la);
    memcpy(r + la, b, (size_t)lb + 1);
    return r;
}

// str_arena_substring — same as str_substring but arena-backed.
const char *__nucleor_str_arena_substring(long long handle, const char *s, long long start, long long end) {
    NStrArena *ar = (NStrArena *)(void *)(size_t)handle;
    if (!s) return "";
    long long n = end - start;
    if (n < 0) n = 0;
    char *r = _str_arena_alloc(ar, n + 1);
    memcpy(r, s + start, (size_t)n);
    r[n] = 0;
    return r;
}

// === Tensor runtime ===
typedef struct { int rows; int cols; double *data; } NTensor;
static double _t_i2f(long long x) { double d; memcpy(&d, &x, sizeof(double)); return d; }
static long long _t_f2i(double f) { long long i; memcpy(&i, &f, sizeof(long long)); return i; }

// v0.3.223: tensor_zeros / tensor_fill overflow PANIC. Pre-fix
// `rows * cols * sizeof(double)` could overflow long-long on hostile
// dimensions, leading to under-allocation + out-of-bounds writes
// when the for-loop iterates rows*cols times.
//
// Also: cast (int)rows / (int)cols truncates ≥2^31 to negative, which
// would silently corrupt indexing. Now: panic if either dim doesn't
// fit in i32, or if total byte count overflows.
static void _check_tensor_dims(long long rows, long long cols, const char *fn) {
    if (rows < 0 || cols < 0) {
        fprintf(stderr, "PANIC: %s: negative dimensions (rows=%lld, cols=%lld)\n", fn, rows, cols);
        fflush(stderr); exit(1);
    }
    if (rows > 2147483647LL || cols > 2147483647LL) {
        fprintf(stderr, "PANIC: %s: dimension exceeds i32 (rows=%lld, cols=%lld)\n", fn, rows, cols);
        fflush(stderr); exit(1);
    }
    /* Overflow check: rows * cols * sizeof(double) must fit in size_t. */
    if (rows > 0 && cols > (long long)((SIZE_MAX / sizeof(double)) / (size_t)rows)) {
        fprintf(stderr, "PANIC: %s: rows %lld * cols %lld * 8 bytes exceeds SIZE_MAX\n", fn, rows, cols);
        fflush(stderr); exit(1);
    }
}
long long __nucleor_tensor_zeros(long long rows, long long cols) {
    _check_tensor_dims(rows, cols, "tensor_zeros");
    NTensor *t = (NTensor *)malloc(sizeof(NTensor));
    t->rows = (int)rows; t->cols = (int)cols;
    t->data = (double *)calloc((size_t)t->rows * (size_t)t->cols, sizeof(double));
    return (long long)t;
}
long long __nucleor_tensor_fill(long long rows, long long cols, long long val_bits) {
    _check_tensor_dims(rows, cols, "tensor_fill");
    NTensor *t = (NTensor *)malloc(sizeof(NTensor));
    t->rows = (int)rows; t->cols = (int)cols;
    t->data = (double *)malloc((size_t)t->rows * (size_t)t->cols * sizeof(double));
    double v = _t_i2f(val_bits);
    long long total = (long long)t->rows * (long long)t->cols;
    for (long long i = 0; i < total; i++) t->data[i] = v;
    return (long long)t;
}
long long __nucleor_tensor_ones(long long rows, long long cols) {
    return __nucleor_tensor_fill(rows, cols, _t_f2i(1.0));
}
long long __nucleor_tensor_rows(long long h) { return ((NTensor*)(void*)h)->rows; }
long long __nucleor_tensor_cols(long long h) { return ((NTensor*)(void*)h)->cols; }
// v0.3.203: NUC-FEEDBACK runtime safety -- Tensor row/col bounds.
// Pre-fix tensor_get/tensor_set had ZERO bounds checking (no NULL
// guard, no row/col check), so passing OOB indices read/wrote
// arbitrary memory -- worse than silent-zero, this was a memory
// safety hazard. Same env var (NUCLEOR_VEC_OOB_LENIENT=1) opts
// back into the unchecked legacy path for adopters running tight
// ML kernels who want zero-overhead access after their own
// validation. (Forward-declared here; definition lives near the
// vec_get strict-mode helpers further down in this file.)
static int _vec_oob_lenient(void);
long long __nucleor_tensor_get(long long h, long long r, long long c) {
    NTensor *t = (NTensor*)(void*)h;
    if (!t) return 0;
    if (r < 0 || c < 0 || r >= t->rows || c >= t->cols) {
        if (_vec_oob_lenient()) return 0;
        fprintf(stderr, "PANIC: tensor_get OOB: index (%lld,%lld), shape (%lld,%lld) (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                r, c, (long long)t->rows, (long long)t->cols);
        fflush(stderr);
        exit(1);
    }
    return _t_f2i(t->data[(int)r * t->cols + (int)c]);
}
void __nucleor_tensor_set(long long h, long long r, long long c, long long v) {
    NTensor *t = (NTensor*)(void*)h;
    if (!t) return;
    if (r < 0 || c < 0 || r >= t->rows || c >= t->cols) {
        if (_vec_oob_lenient()) return;
        fprintf(stderr, "PANIC: tensor_set OOB: index (%lld,%lld), shape (%lld,%lld) (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                r, c, (long long)t->rows, (long long)t->cols);
        fflush(stderr);
        exit(1);
    }
    t->data[(int)r * t->cols + (int)c] = _t_i2f(v);
}
// v0.3.226: tensor reductions PANIC on null/empty input. Pre-fix
// tensor_mean/_variance silently divided by zero (SIGFPE on x86),
// tensor_max/_min read t->data[0] OOB on empty tensors. NULL handle
// segfaulted across all of them.
static void _check_tensor_nonempty(NTensor *t, const char *fn) {
    if (!t) {
        fprintf(stderr, "PANIC: %s: null tensor handle\n", fn);
        fflush(stderr); exit(1);
    }
    if (t->rows <= 0 || t->cols <= 0) {
        fprintf(stderr, "PANIC: %s: empty tensor (rows=%d, cols=%d)\n", fn, t->rows, t->cols);
        fflush(stderr); exit(1);
    }
}
long long __nucleor_tensor_sum(long long h) {
    NTensor *t = (NTensor*)(void*)h;
    if (!t) { fprintf(stderr, "PANIC: tensor_sum: null tensor handle\n"); fflush(stderr); exit(1); }
    /* sum on empty tensor is well-defined as 0; only NULL is fatal. */
    double s = 0;
    long long total = (long long)t->rows * (long long)t->cols;
    for (long long i = 0; i < total; i++) s += t->data[i];
    return _t_f2i(s);
}
long long __nucleor_tensor_mean(long long h) {
    NTensor *t = (NTensor*)(void*)h;
    _check_tensor_nonempty(t, "tensor_mean");
    double s = 0;
    long long n = (long long)t->rows * (long long)t->cols;
    for (long long i = 0; i < n; i++) s += t->data[i];
    return _t_f2i(s / (double)n);
}
long long __nucleor_tensor_max(long long h) {
    NTensor *t = (NTensor*)(void*)h;
    _check_tensor_nonempty(t, "tensor_max");
    double m = t->data[0];
    long long total = (long long)t->rows * (long long)t->cols;
    for (long long i = 1; i < total; i++) if (t->data[i] > m) m = t->data[i];
    return _t_f2i(m);
}
long long __nucleor_tensor_min(long long h) {
    NTensor *t = (NTensor*)(void*)h;
    _check_tensor_nonempty(t, "tensor_min");
    double m = t->data[0];
    long long total = (long long)t->rows * (long long)t->cols;
    for (long long i = 1; i < total; i++) if (t->data[i] < m) m = t->data[i];
    return _t_f2i(m);
}
long long __nucleor_tensor_variance(long long h) {
    NTensor *t = (NTensor*)(void*)h;
    _check_tensor_nonempty(t, "tensor_variance");
    long long n = (long long)t->rows * (long long)t->cols;
    double s = 0;
    for (long long i = 0; i < n; i++) s += t->data[i];
    double m = s / (double)n;
    double v = 0;
    for (long long i = 0; i < n; i++) { double d = t->data[i] - m; v += d * d; }
    return _t_f2i(v / (double)n);
}
long long __nucleor_tensor_stddev(long long h) {
    return _t_f2i(sqrt(_t_i2f(__nucleor_tensor_variance(h))));
}
// v0.3.226: tensor_matmul shape validation. Pre-fix no NULL check, no
// validation that a->cols == b->rows -- silently produced wrong-sized
// results or read OOB on shape mismatch.
long long __nucleor_tensor_matmul(long long ah, long long bh) {
    NTensor *a=(NTensor*)(void*)ah, *b=(NTensor*)(void*)bh;
    if (!a || !b) {
        fprintf(stderr, "PANIC: tensor_matmul: null tensor handle (a=%p, b=%p)\n", (void*)a, (void*)b);
        fflush(stderr); exit(1);
    }
    if (a->cols != b->rows) {
        fprintf(stderr, "PANIC: tensor_matmul: shape mismatch (a=%dx%d, b=%dx%d -- a.cols must equal b.rows)\n",
                a->rows, a->cols, b->rows, b->cols);
        fflush(stderr); exit(1);
    }
    if (a->rows < 0 || a->cols < 0 || b->cols < 0) {
        fprintf(stderr, "PANIC: tensor_matmul: negative dim (a=%dx%d, b=%dx%d)\n", a->rows, a->cols, b->rows, b->cols);
        fflush(stderr); exit(1);
    }
    NTensor *c=(NTensor*)malloc(sizeof(NTensor));
    c->rows=a->rows; c->cols=b->cols;
    c->data=(double*)calloc((size_t)c->rows*(size_t)c->cols,sizeof(double));
    for(int i=0;i<a->rows;i++)for(int j=0;j<b->cols;j++){
        double s=0;for(int k=0;k<a->cols;k++)s+=a->data[i*a->cols+k]*b->data[k*b->cols+j];
        c->data[i*c->cols+j]=s;}
    return (long long)c;
}
long long __nucleor_tensor_transpose(long long h) {
    NTensor *t=(NTensor*)(void*)h;
    NTensor *r=(NTensor*)malloc(sizeof(NTensor));
    r->rows=t->cols; r->cols=t->rows;
    r->data=(double*)malloc(r->rows*r->cols*sizeof(double));
    for(int i=0;i<t->rows;i++)for(int j=0;j<t->cols;j++)r->data[j*r->cols+i]=t->data[i*t->cols+j];
    return (long long)r;
}

// === f64 support (extern fn accessible from Nucleor) ===
// All f64 values are passed as i64 (bitcast) through Nucleor's type system.
// These functions use union-based type punning for safe reinterpretation.
typedef union { long long i; double f; } nf64;

void nuc_print_f64(long long x) {
    nf64 v; v.i = x;
    printf("%.6f\n", v.f);
    fflush(stdout);
}

// Format f64 as string (caller must eventually free, but Nucleor GC handles it)
const char *nuc_fmt_f64(long long x) {
    nf64 v; v.i = x;
    char *buf = (char *)malloc(64);
    snprintf(buf, 64, "%.6f", v.f);
    return buf;
}

long long nuc_f64_from_int(long long x) {
    nf64 v; v.f = (double)x;
    return v.i;
}

long long nuc_f64_to_int(long long x) {
    nf64 v; v.i = x;
    return (long long)v.f;
}

long long nuc_f64_add(long long a, long long b) {
    nf64 va, vb, vr; va.i = a; vb.i = b; vr.f = va.f + vb.f; return vr.i;
}

long long nuc_f64_sub(long long a, long long b) {
    nf64 va, vb, vr; va.i = a; vb.i = b; vr.f = va.f - vb.f; return vr.i;
}

long long nuc_f64_mul(long long a, long long b) {
    nf64 va, vb, vr; va.i = a; vb.i = b; vr.f = va.f * vb.f; return vr.i;
}

long long nuc_f64_div(long long a, long long b) {
    nf64 va, vb, vr; va.i = a; vb.i = b;
    vr.f = (vb.f != 0.0) ? va.f / vb.f : 0.0;
    return vr.i;
}

long long nuc_f64_sqrt(long long x) {
    nf64 v, r; v.i = x; r.f = sqrt(v.f); return r.i;
}

long long nuc_f64_abs(long long x) {
    nf64 v, r; v.i = x; r.f = fabs(v.f); return r.i;
}

long long nuc_f64_gt(long long a, long long b) {
    nf64 va, vb; va.i = a; vb.i = b; return va.f > vb.f ? 1 : 0;
}

long long nuc_f64_lt(long long a, long long b) {
    nf64 va, vb; va.i = a; vb.i = b; return va.f < vb.f ? 1 : 0;
}

long long nuc_f64_max(long long a, long long b) {
    nf64 va, vb, vr; va.i = a; vb.i = b; vr.f = va.f > vb.f ? va.f : vb.f; return vr.i;
}

long long nuc_f64_min(long long a, long long b) {
    nf64 va, vb, vr; va.i = a; vb.i = b; vr.f = va.f < vb.f ? va.f : vb.f; return vr.i;
}

// === String operations ===
long long __nucleor_str_len(const char *s) {
    NUC_PROFILE_HOT(g_p_str_len, str_len);
    if (!s) return 0;
    return (long long)strlen(s);
}

// v0.3.219: str_eq pointer-equality fast path. Many compiler-internal
// str_eq calls compare a string against itself (alias from the same
// source buffer or LLVM @.str dedup); pointer-equal check before
// strcmp skips the per-byte loop on the hot path.
// v0.3.220: source-scan cache for the println! `{}` format heuristic.
// Pre-fix the infer_*_from_source helpers re-walked the entire compiler
// source (936KB) for every println!/format arg, producing 1.26B
// str_char_at calls per self-build. Now: build a name->type map ONCE
// per source pointer, lookup is O(1) average. Per-compile cost drops
// from O(N_args * source_size) to O(source_size + N_args).

#define NUC_INFER_CACHE_BUCKETS 4096
typedef struct { char *key; char *val; int next; } NInferEntry;
static const char *g_var_cache_src = NULL;
static int g_var_cache_used = 0;
static NInferEntry g_var_cache_entries[16384];
static int g_var_cache_buckets[NUC_INFER_CACHE_BUCKETS];

static const char *g_fnret_cache_src = NULL;
static int g_fnret_cache_used = 0;
static NInferEntry g_fnret_cache_entries[8192];
static int g_fnret_cache_buckets[NUC_INFER_CACHE_BUCKETS];

static unsigned int _nuc_str_hash_u(const char *s) {
    unsigned int h = 5381;
    while (*s) { h = h * 33 + (unsigned char)*s; s++; }
    return h;
}

static int _is_id_continue(int c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
        || (c >= '0' && c <= '9') || c == '_';
}

static void _cache_put(NInferEntry *entries, int *buckets, int *used,
                       int max_entries, const char *name, int name_len,
                       const char *type, int type_len) {
    if (*used >= max_entries) return;  /* cache full -- skip */
    int idx = *used;
    entries[idx].key = (char *)malloc(name_len + 1);
    memcpy(entries[idx].key, name, name_len); entries[idx].key[name_len] = 0;
    entries[idx].val = (char *)malloc(type_len + 1);
    memcpy(entries[idx].val, type, type_len); entries[idx].val[type_len] = 0;
    unsigned int h = _nuc_str_hash_u(entries[idx].key) & (NUC_INFER_CACHE_BUCKETS - 1);
    entries[idx].next = buckets[h];
    buckets[h] = idx + 1;  /* +1 so 0 means "empty" */
    *used = idx + 1;
}

static const char *_cache_get(NInferEntry *entries, int *buckets,
                              const char *name) {
    unsigned int h = _nuc_str_hash_u(name) & (NUC_INFER_CACHE_BUCKETS - 1);
    int slot = buckets[h];
    while (slot > 0) {
        if (strcmp(entries[slot - 1].key, name) == 0) return entries[slot - 1].val;
        slot = entries[slot - 1].next;
    }
    return "";
}

static void _cache_reset(NInferEntry *entries, int *buckets, int *used) {
    for (int i = 0; i < *used; i++) {
        free(entries[i].key); free(entries[i].val);
    }
    *used = 0;
    memset(buckets, 0, NUC_INFER_CACHE_BUCKETS * sizeof(int));
}

/* Single-pass build: walk src once, find every `let [mut ]name : type`
   and every `fn name(...) -> type`, populate caches. */
static void _build_caches(const char *src) {
    _cache_reset(g_var_cache_entries, g_var_cache_buckets, &g_var_cache_used);
    _cache_reset(g_fnret_cache_entries, g_fnret_cache_buckets, &g_fnret_cache_used);
    int slen = (int)strlen(src);
    for (int i = 0; i + 4 < slen; i++) {
        char c0 = src[i];
        /* match "let " (108 101 116 32) */
        if (c0 == 'l' && src[i+1] == 'e' && src[i+2] == 't' && src[i+3] == ' ') {
            /* require start-of-line or whitespace before (avoid matching "let" inside identifiers) */
            if (i > 0) {
                char pc = src[i-1];
                if (_is_id_continue(pc)) continue;
            }
            int p = i + 4;
            if (p + 4 < slen && src[p] == 'm' && src[p+1] == 'u' && src[p+2] == 't' && src[p+3] == ' ') p += 4;
            int name_st = p;
            while (p < slen && _is_id_continue(src[p])) p++;
            int name_end = p;
            if (name_end == name_st) continue;
            while (p < slen && src[p] == ' ') p++;
            if (p >= slen || src[p] != ':') continue;
            p++;
            while (p < slen && src[p] == ' ') p++;
            int type_st = p;
            int gd = 0;
            while (p < slen) {
                char tc = src[p];
                if (tc == '<') { gd++; p++; }
                else if (tc == '>' && gd > 0) { gd--; p++; }
                else if (gd == 0 && (tc == ' ' || tc == '=' || tc == ';' || tc == ',' || tc == '\n' || tc == '\r')) break;
                else p++;
            }
            int type_end = p;
            if (type_end > type_st) {
                _cache_put(g_var_cache_entries, g_var_cache_buckets, &g_var_cache_used,
                           16384, src + name_st, name_end - name_st,
                           src + type_st, type_end - type_st);
            }
        }
        /* match "fn " (102 110 32) */
        else if (c0 == 'f' && src[i+1] == 'n' && src[i+2] == ' ') {
            if (i > 0 && _is_id_continue(src[i-1])) continue;
            int p = i + 3;
            int name_st = p;
            while (p < slen && _is_id_continue(src[p])) p++;
            int name_end = p;
            if (name_end == name_st) continue;
            /* skip params (...) — find matching close paren */
            while (p < slen && src[p] != '(') p++;
            if (p >= slen) continue;
            int paren = 1; p++;
            while (p < slen && paren > 0) {
                if (src[p] == '(') paren++;
                else if (src[p] == ')') paren--;
                p++;
            }
            /* skip whitespace, look for "-> TYPE" */
            while (p < slen && src[p] == ' ') p++;
            if (p + 1 >= slen || src[p] != '-' || src[p+1] != '>') continue;
            p += 2;
            while (p < slen && src[p] == ' ') p++;
            int type_st = p;
            int gd = 0;
            while (p < slen) {
                char tc = src[p];
                if (tc == '<') { gd++; p++; }
                else if (tc == '>' && gd > 0) { gd--; p++; }
                else if (gd == 0 && (tc == ' ' || tc == '{' || tc == ';' || tc == '\n' || tc == '\r')) break;
                else p++;
            }
            int type_end = p;
            if (type_end > type_st) {
                _cache_put(g_fnret_cache_entries, g_fnret_cache_buckets, &g_fnret_cache_used,
                           8192, src + name_st, name_end - name_st,
                           src + type_st, type_end - type_st);
            }
        }
    }
}

const char *__nucleor_infer_var_type(const char *src, const char *var_name) {
    if (!src || !var_name) return "";
    if (g_var_cache_src != src) {
        g_var_cache_src = src;
        g_fnret_cache_src = src;
        _build_caches(src);
    }
    return _cache_get(g_var_cache_entries, g_var_cache_buckets, var_name);
}

/* v0.4.20 perf: generic str-keyed source-cache for the new pattern-
   binding / user-variant / enum-payload scanners. Each scanner is
   expensive (full bundled-source walk per call); per-compile cost
   was 1.6 BILLION str_char_at calls because the same var_name
   gets looked up many times across the format-macro pass.
   This cache stores arbitrary (key -> value) entries scoped to a
   single src pointer; cache resets when the src ptr changes.
   Source-side helpers wrap their existing scan with: check cache;
   if hit, return; else scan + store + return. */
#define NUC_GENERIC_CACHE_ENTRIES 32768
static const char *g_generic_cache_src = NULL;
static int g_generic_cache_used = 0;
static NInferEntry g_generic_cache_entries[NUC_GENERIC_CACHE_ENTRIES];
static int g_generic_cache_buckets[NUC_INFER_CACHE_BUCKETS];

const char *__nucleor_str_cache_get(const char *src, const char *key) {
    if (!src || !key) return "";
    if (g_generic_cache_src != src) {
        _cache_reset(g_generic_cache_entries, g_generic_cache_buckets, &g_generic_cache_used);
        g_generic_cache_src = src;
    }
    return _cache_get(g_generic_cache_entries, g_generic_cache_buckets, key);
}

long long __nucleor_str_cache_put(const char *src, const char *key, const char *value) {
    if (!src || !key || !value) return 0;
    if (g_generic_cache_src != src) {
        _cache_reset(g_generic_cache_entries, g_generic_cache_buckets, &g_generic_cache_used);
        g_generic_cache_src = src;
    }
    int klen = (int)strlen(key);
    int vlen = (int)strlen(value);
    _cache_put(g_generic_cache_entries, g_generic_cache_buckets, &g_generic_cache_used,
               NUC_GENERIC_CACHE_ENTRIES, key, klen, value, vlen);
    return 0;
}

/* Sentinel: cache stores values as "" if the lookup yielded a real
   empty answer (we want to remember "miss" too -- otherwise every
   miss re-runs the expensive scan). Use a non-empty sentinel as the
   stored "miss" marker so cache_get's "" return distinguishes
   "not yet looked up" from "looked up, no answer". */
long long __nucleor_str_cache_put_miss(const char *src, const char *key) {
    return __nucleor_str_cache_put(src, key, "\x01");
}

long long __nucleor_str_cache_is_miss_marker(const char *value) {
    return (value && value[0] == '\x01' && value[1] == 0) ? 1 : 0;
}
const char *__nucleor_infer_fn_return_type(const char *src, const char *fn_name) {
    if (!src || !fn_name) return "";
    if (g_fnret_cache_src != src) {
        g_var_cache_src = src;
        g_fnret_cache_src = src;
        _build_caches(src);
    }
    return _cache_get(g_fnret_cache_entries, g_fnret_cache_buckets, fn_name);
}

long long __nucleor_str_eq(const char *a, const char *b) {
    NUC_PROFILE_HOT(g_p_str_eq, str_eq);
    if (a == b) return 1;          /* pointer-equal: same string */
    if (!a || !b) return 0;        /* one null, one not */
    return strcmp(a, b) == 0 ? 1 : 0;
}

// v0.3.210: NUC-FEEDBACK runtime safety -- str_char_at sanity check.
// Per-call strlen would tank lexer perf (the lexer hits 5-50
// char_at per token over freshly-allocated str_substring pointers,
// so a strlen cache thrashes). The remaining cheap defense:
//
//   1. Negative index ALWAYS panics (no false positive possible;
//      a negative i means upstream computed a bad value).
//   2. The byte read at i==strlen(s) is the well-defined NUL
//      terminator (0); many lexers rely on this idiom.
//   3. Reads past the NUL are not strictly bounded -- they walk
//      the malloc'd buffer up to its real boundary, which the
//      allocator typically rounds up by ≥8 bytes. The byte read
//      is "garbage" from the user's perspective but stays inside
//      the process's memory map, so it's not a CVE-class memory
//      safety hazard. A truly bound-checked surface would need
//      length-tagged strings (a new core type) -- tracked.
//
// Net: tightens the obvious bug class (negative index) cheaply,
// documents the residual surface, doesn't tank the lexer.
long long __nucleor_str_char_at(const char *s, long long i) {
    NUC_PROFILE_INC(g_p_str_char_at);
    if (!s) return 0;
    if (i < 0) {
        if (_vec_oob_lenient()) return 0;
        fprintf(stderr, "PANIC: str_char_at OOB: negative index %lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n", i);
        fflush(stderr);
        exit(1);
    }
    return (unsigned char)s[(int)i];
}

// v0.4.279: opt-in strict variant that DOES validate i < strlen(s).
// Probe-agent finding 2026-04-30: default str_char_at silently
// reads past the source's NUL terminator for i >= strlen(s),
// returning whatever heap memory follows — memory-safety hazard.
// Default kept lenient (per v0.3.220 retrospective: strlen on
// every call is a 75x perf killer in lexer hot paths). This
// strict variant pays O(strlen) and panics on OOB, mirroring
// `str_substring_strict` from v0.3.220. Adopters opt in by
// calling `str_char_at_strict` instead of `str_char_at`.
long long __nucleor_str_char_at_strict(const char *s, long long i) {
    if (!s) return 0;
    long long slen = (long long)strlen(s);
    if (i < 0 || i >= slen) {
        fprintf(stderr, "PANIC: str_char_at_strict OOB: index %lld len %lld\n", i, slen);
        fflush(stderr);
        exit(1);
    }
    return (unsigned char)s[(int)i];
}

// v0.3.205: NUC-FEEDBACK runtime safety -- str_substring bounds.
// Pre-fix had no length check on start/end vs strlen(s), so OOB
// values read garbage past the null terminator (memory safety
// hazard, undefined behavior). The substring already does O(n)
// work copying bytes, so an extra strlen is asymptotic-free.
// Negative start, end < start, or end > strlen all trigger PANIC
// by default (NUCLEOR_VEC_OOB_LENIENT=1 opts back into legacy
// undefined behavior for porting purposes).
// v0.3.220 perf revert: v0.3.205's bounds-check called strlen(s) on
// EVERY str_substring -- for a 936KB source with 30K str_substring
// calls during resolve_source, that's 28 BILLION character reads
// just for the bounds check. ~75x compile-time perf killer.
//
// My v0.3.205 note "asymptotic-free since substring already does
// O(n) work copying bytes" was wrong: the COPY is `end - start` bytes
// (substring length), not strlen(s) (source length). On a 30-byte
// substring of 936K source, strlen is 30,000x the copy work.
//
// Fix: remove the strlen check on the hot path. Rely on caller-side
// bounds (the lexer always has p < slen guaranteed by its outer
// loop). Negative start still PANICs (cheap O(1) check). For full
// strict mode use the new `str_substring_strict` helper which still
// does the strlen check.
const char *__nucleor_str_substring(const char *s, long long start, long long end) {
    NUC_PROFILE_HOT(g_p_str_substring, str_substring);
    if (!s) return "";
    if (start < 0 || end < start) {
        if (_vec_oob_lenient()) return "";
        fprintf(stderr, "PANIC: str_substring OOB: start=%lld end=%lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                start, end);
        fflush(stderr);
        exit(1);
    }
    int n = (int)(end - start);
    g_str_substring_count++;
    g_str_substring_bytes += n + 1;
    char *r = (char *)malloc(n + 1);
    memcpy(r, s + (int)start, n);
    r[n] = 0;
    return r;
}

// v0.3.220: opt-in strict variant that DOES validate end <= strlen(s).
// Adopter-facing for code that wants full bounds-checking; pays the
// O(strlen(s)) cost per call.
const char *__nucleor_str_substring_strict(const char *s, long long start, long long end) {
    if (!s) return "";
    long long slen = (long long)strlen(s);
    if (start < 0 || end < start || end > slen) {
        fprintf(stderr, "PANIC: str_substring_strict OOB: start=%lld end=%lld len=%lld\n",
                start, end, slen);
        fflush(stderr); exit(1);
    }
    int n = (int)(end - start);
    char *r = (char *)malloc(n + 1);
    memcpy(r, s + (int)start, n);
    r[n] = 0;
    return r;
}

const char *__nucleor_str_concat(const char *a, const char *b) {
    NUC_PROFILE_HOT(g_p_str_concat, str_concat);
    if (!a) a = "";
    if (!b) b = "";
    int la = (int)strlen(a), lb = (int)strlen(b);
    g_str_concat_count++;
    g_str_concat_bytes += la + lb + 1;
    char *r = (char *)malloc(la + lb + 1);
    memcpy(r, a, la);
    memcpy(r + la, b, lb + 1);
    return r;
}

// === RFC-0017 / RFC-0028 stdlib enrichment: string utilities ===
// All return heap-allocated str (caller-owned in Nucleor).
//
//   str_to_lower(s)              — ASCII lowercase
//   str_to_upper(s)              — ASCII uppercase
//   str_trim(s)                  — strip leading + trailing ASCII whitespace
//   str_starts_with(s, prefix)   — bool 0/1
//   str_ends_with(s, suffix)     — bool 0/1
//   str_contains(s, needle)      — bool 0/1
//   str_index_of(s, needle)      — first match offset or -1
//   str_replace(s, find, repl)   — replace ALL non-overlapping matches
//   str_repeat(s, n)             — concatenate s n times
//   str_split(s, sep) -> NVec*   — Vec<str> of substrings (each is a strdup)

const char *__nucleor_str_to_lower(const char *s) {
    if (!s) return "";
    size_t n = strlen(s);
    char *out = (char *)malloc(n + 1);
    for (size_t i = 0; i < n; i++) {
        char c = s[i];
        out[i] = (c >= 'A' && c <= 'Z') ? (char)(c - 'A' + 'a') : c;
    }
    out[n] = 0;
    return out;
}

const char *__nucleor_str_to_upper(const char *s) {
    if (!s) return "";
    size_t n = strlen(s);
    char *out = (char *)malloc(n + 1);
    for (size_t i = 0; i < n; i++) {
        char c = s[i];
        out[i] = (c >= 'a' && c <= 'z') ? (char)(c - 'a' + 'A') : c;
    }
    out[n] = 0;
    return out;
}

const char *__nucleor_str_trim(const char *s) {
    if (!s) return "";
    size_t n = strlen(s);
    size_t start = 0;
    while (start < n && (s[start] == ' ' || s[start] == '\t' || s[start] == '\n' || s[start] == '\r')) start++;
    size_t end = n;
    while (end > start && (s[end - 1] == ' ' || s[end - 1] == '\t' || s[end - 1] == '\n' || s[end - 1] == '\r')) end--;
    size_t L = end - start;
    char *out = (char *)malloc(L + 1);
    memcpy(out, s + start, L);
    out[L] = 0;
    return out;
}
const char *__nucleor_str_trim_start(const char *s) {
    if (!s) return "";
    size_t n = strlen(s);
    size_t start = 0;
    while (start < n && (s[start] == ' ' || s[start] == '\t' || s[start] == '\n' || s[start] == '\r')) start++;
    size_t L = n - start;
    char *out = (char *)malloc(L + 1);
    memcpy(out, s + start, L);
    out[L] = 0;
    return out;
}
const char *__nucleor_str_trim_end(const char *s) {
    if (!s) return "";
    size_t n = strlen(s);
    size_t end = n;
    while (end > 0 && (s[end - 1] == ' ' || s[end - 1] == '\t' || s[end - 1] == '\n' || s[end - 1] == '\r')) end--;
    char *out = (char *)malloc(end + 1);
    memcpy(out, s, end);
    out[end] = 0;
    return out;
}
long long __nucleor_str_is_empty(const char *s) {
    if (!s) return 1;
    return s[0] == 0 ? 1 : 0;
}
long long __nucleor_str_count(const char *s, const char *needle) {
    if (!s || !needle || !*needle) return 0;
    size_t nl = strlen(needle);
    long long c = 0;
    const char *scan = s;
    const char *p;
    while ((p = strstr(scan, needle)) != NULL) {
        c++;
        scan = p + nl;
    }
    return c;
}
const char *__nucleor_str_reverse(const char *s) {
    if (!s) return "";
    size_t n = strlen(s);
    char *out = (char *)malloc(n + 1);
    for (size_t i = 0; i < n; i++) out[i] = s[n - 1 - i];
    out[n] = 0;
    return out;
}

long long __nucleor_str_starts_with(const char *s, const char *prefix) {
    if (!s || !prefix) return 0;
    size_t pl = strlen(prefix);
    if (strlen(s) < pl) return 0;
    return memcmp(s, prefix, pl) == 0 ? 1 : 0;
}

long long __nucleor_str_ends_with(const char *s, const char *suffix) {
    if (!s || !suffix) return 0;
    size_t sl = strlen(s), xl = strlen(suffix);
    if (sl < xl) return 0;
    return memcmp(s + sl - xl, suffix, xl) == 0 ? 1 : 0;
}

long long __nucleor_str_index_of(const char *s, const char *needle) {
    if (!s || !needle) return -1;
    const char *p = strstr(s, needle);
    if (!p) return -1;
    return (long long)(p - s);
}

long long __nucleor_str_contains(const char *s, const char *needle) {
    return __nucleor_str_index_of(s, needle) >= 0 ? 1 : 0;
}

const char *__nucleor_str_replace(const char *s, const char *find, const char *repl) {
    if (!s) return "";
    if (!find || !*find) {
        size_t n = strlen(s) + 1;
        char *out = (char *)malloc(n);
        memcpy(out, s, n);
        return out;
    }
    if (!repl) repl = "";
    size_t fl = strlen(find), rl = strlen(repl);
    // Two-pass: count occurrences, allocate exact size, fill.
    size_t count = 0;
    const char *scan = s;
    const char *p;
    while ((p = strstr(scan, find)) != NULL) {
        count++;
        scan = p + fl;
    }
    size_t out_len = strlen(s) + (count * (rl > fl ? (rl - fl) : 0)) - (count * (fl > rl ? (fl - rl) : 0));
    char *out = (char *)malloc(out_len + 1);
    char *w = out;
    scan = s;
    while ((p = strstr(scan, find)) != NULL) {
        size_t pre = (size_t)(p - scan);
        memcpy(w, scan, pre);   w += pre;
        memcpy(w, repl, rl);    w += rl;
        scan = p + fl;
    }
    size_t tail = strlen(scan);
    memcpy(w, scan, tail);  w += tail;
    *w = 0;
    return out;
}

// v0.3.223: str_repeat overflow PANIC. Pre-fix `L * n` could overflow
// size_t on hostile input (large L and large n) -- malloc(small) +
// memcpy past buffer = CVE-class memory corruption. Now: detect
// overflow before malloc and panic with the offending sizes.
const char *__nucleor_str_repeat(const char *s, long long n) {
    if (!s || n <= 0) {
        char *empty = (char *)malloc(1); empty[0] = 0; return empty;
    }
    size_t L = strlen(s);
    /* Overflow check: would L * n exceed SIZE_MAX? */
    if (L > 0 && (size_t)n > (SIZE_MAX - 1) / L) {
        fprintf(stderr, "PANIC: str_repeat overflow: %zu bytes * %lld reps would exceed SIZE_MAX\n", L, n);
        fflush(stderr); exit(1);
    }
    size_t total = L * (size_t)n;
    char *out = (char *)malloc(total + 1);
    for (long long i = 0; i < n; i++) memcpy(out + ((size_t)i * L), s, L);
    out[total] = 0;
    return out;
}

// __nucleor_str_split is defined further down in this file (after the
// NVec typedef). It returns NVec* (Vec<str>) of substrings.

// === File I/O ===
// v0.3.218: file_read_string -- two safety fixes.
// (1) Memory safety: pre-fix, if ftell() returned -1 (seek error
//     on a non-seekable stream), the code did `malloc(0)` then
//     `fread(buf, 1, (size_t)-1, f)` which reads SIZE_MAX bytes
//     into a 1-byte buffer -- real CVE-class buffer overflow.
//     Now: detect ftell failure and short-circuit to "".
// (2) Lenient default: the compiler intentionally uses silent-
//     empty-on-missing as a "does this file exist?" probe
//     (path resolution, log existence, etc.). Keep that default
//     intact. Adopters who want strict semantics can call the
//     new __nucleor_file_read_string_or_panic helper.
const char *__nucleor_file_read_string(const char *path) {
    if (!path) return "";
    FILE *f = fopen(path, "rb");
    if (!f) return "";
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return ""; }
    long sz = ftell(f);
    if (sz < 0) { fclose(f); return ""; }   /* CVE-class: prevent SIZE_MAX fread */
    if (fseek(f, 0, SEEK_SET) != 0) { fclose(f); return ""; }
    char *buf = (char *)malloc((size_t)sz + 1);
    size_t n_read = fread(buf, 1, (size_t)sz, f);
    fclose(f);
    buf[n_read] = 0;
    return buf;
}

// v0.3.218: file_read_string_or_panic -- strict variant. Panics on
// missing file, fopen failure, or read error. Adopter-facing
// surface for code that wants OS-level reads to fail loud.
const char *__nucleor_file_read_string_or_panic(const char *path) {
    if (!path) {
        fprintf(stderr, "PANIC: file_read_string_or_panic: null path\n");
        fflush(stderr); exit(1);
    }
    FILE *f = fopen(path, "rb");
    if (!f) {
        fprintf(stderr, "PANIC: file_read_string_or_panic: cannot open '%s' (%s)\n", path, strerror(errno));
        fflush(stderr); exit(1);
    }
    if (fseek(f, 0, SEEK_END) != 0) {
        fprintf(stderr, "PANIC: file_read_string_or_panic: fseek failed on '%s'\n", path);
        fflush(stderr); fclose(f); exit(1);
    }
    long sz = ftell(f);
    if (sz < 0) {
        fprintf(stderr, "PANIC: file_read_string_or_panic: ftell failed on '%s'\n", path);
        fflush(stderr); fclose(f); exit(1);
    }
    if (fseek(f, 0, SEEK_SET) != 0) {
        fprintf(stderr, "PANIC: file_read_string_or_panic: fseek failed on '%s'\n", path);
        fflush(stderr); fclose(f); exit(1);
    }
    char *buf = (char *)malloc((size_t)sz + 1);
    size_t n_read = fread(buf, 1, (size_t)sz, f);
    fclose(f);
    buf[n_read] = 0;
    return buf;
}

// v0.3.218: file_write_string now panics on fopen / fwrite failure.
// Pre-fix it silently swallowed the error -- adopters writing to
// read-only paths got nothing with no diagnostic. The new behavior:
// panic. Opt-out via NUCLEOR_FILE_LENIENT=1 for legacy semantics.
static int g_file_lenient_cached = 0;  /* 0=uncached, 1=panic, 2=lenient */
static int _file_lenient(void) {
    if (g_file_lenient_cached == 0) {
        const char *e = getenv("NUCLEOR_FILE_LENIENT");
        g_file_lenient_cached = (e && e[0] == '1') ? 2 : 1;
    }
    return g_file_lenient_cached == 2;
}
void __nucleor_file_write_string(const char *path, const char *data) {
    if (!path || !data) {
        if (_file_lenient()) return;
        fprintf(stderr, "PANIC: file_write_string: null %s (set NUCLEOR_FILE_LENIENT=1 to suppress)\n",
                !path ? "path" : "data");
        fflush(stderr); exit(1);
    }
    FILE *f = fopen(path, "wb");
    if (!f) {
        if (_file_lenient()) return;
        fprintf(stderr, "PANIC: file_write_string: cannot open '%s' for writing (%s) (set NUCLEOR_FILE_LENIENT=1 to suppress)\n",
                path, strerror(errno));
        fflush(stderr); exit(1);
    }
    size_t len = strlen(data);
    size_t written = fwrite(data, 1, len, f);
    if (fclose(f) != 0 || written != len) {
        if (_file_lenient()) return;
        fprintf(stderr, "PANIC: file_write_string: write failed on '%s' (wrote %zu of %zu bytes) (set NUCLEOR_FILE_LENIENT=1 to suppress)\n",
                path, written, len);
        fflush(stderr); exit(1);
    }
}

// === Process ===
long long __nucleor_system(const char *cmd) {
    if (!cmd) return -1;
    return (long long)system(cmd);
}

// === Vec operations (flat array with length tracking) ===
typedef struct {
    long long *data;
    int len;
    int cap;
    long long inline_data[2];
} NVec;

NVec *__nucleor_vec_new(void) {
    // v0.5.32 memory tighten: initial capacity is 2 elements. The
    // s1 self-host creates millions of Vecs per
    // compile, and many of them are short-lived pairs or empty
    // accumulators. Keeping the default below the common pair shape
    // cuts the baseline allocation footprint while allowing push to
    // grow normally for larger vectors.
    if (!g_alloc_tracer_init) { atexit(_alloc_summary); g_alloc_tracer_init = 1; }
    g_vec_new_count++;
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->data = v->inline_data;
    v->len = 0;
    v->cap = 2;
    g_vec_realloc_bytes += sizeof(NVec);
    return v;
}

// v0.3.116: vec_with_capacity(n) — pre-allocate the data buffer
// to hold n elements without realloc churn. Mirrors Rust's
// `Vec::with_capacity(N)` for known-size accumulators. Returns
// an empty Vec (len = 0) with capacity = max(n, 2) — keeps the
// minimum aligned with Vec::new while still giving the vec_push
// fast path a non-zero buffer.
NVec *__nucleor_vec_with_capacity(long long n) {
    if (!g_alloc_tracer_init) { atexit(_alloc_summary); g_alloc_tracer_init = 1; }
    g_vec_new_count++;
    long long cap = n < 2 ? 2 : n;
    NVec *v = (NVec *)malloc(sizeof(NVec));
    if (cap <= 2) { v->data = v->inline_data; }
    else { v->data = (long long *)malloc((size_t)cap * sizeof(long long)); }
    v->len = 0;
    v->cap = cap;
    g_vec_realloc_bytes += sizeof(NVec);
    if (cap > 2) { g_vec_realloc_bytes += (long long)cap * (long long)sizeof(long long); }
    return v;
}

// v0.8.68 RFC-0062 G-4 Phase 2b — runtime double-free guard
// (sentinel-based, reliable). Production-grade defense in depth
// for the eventual unconditional default-flip.
//
// Approach: when NUC_VEC_FREE_GUARD=1, vec_free DOES NOT free
// the NVec struct itself. It frees the data buffer and stamps
// the struct with a magic sentinel in v->cap. On subsequent
// vec_free of the same handle, the sentinel check fires and we
// PANIC. The struct (~32 bytes) leaks intentionally — that's
// the cost of reliable detection. Adopters get true safety.
//
// Default OFF: zero overhead, identical pre-v0.8.67 semantics.
// Opt-in via NUC_VEC_FREE_GUARD=1 for memory-safety testing.
// Phase 4 v1.0 may flip the default ON when leak budget is
// reviewed.
//
// Why not the v0.8.67 ring buffer: malloc reuses freed memory
// → naive ring-buffer false-positives on legitimate alloc reuse
// (caught at default-on in v0.8.67 testing). Sentinel-in-struct
// is reliable IF the struct itself isn't freed.
//
// Why not magic sentinel + free(): malloc may immediately reuse
// the freed page, overwriting the sentinel. Defeats the check.
//
// The leak-the-struct trade is the cleanest reliable approach.
// v0.x mutator-single-threaded contract per RFC-0062 G-6 Phase 1
// means no thread-safety concerns.
#define NUC_VEC_FREED_SENTINEL_CAP ((int)0xDEADBEEF)

static int _nuc_vec_free_guard_enabled(void) {
    static int g_checked = 0;
    static int g_enabled = 0;  // OFF by default
    if (!g_checked) {
        const char *env = getenv("NUC_VEC_FREE_GUARD");
        if (env && env[0] == '1' && env[1] == '\0') g_enabled = 1;
        g_checked = 1;
    }
    return g_enabled;
}

// Free a Vec and its data. The handle is invalid after this call.
// Always-linked counterpart of mem_rt.c's nuc_vec_free, so user code
// (and the compiler itself) can reclaim a Vec without importing
// stdlib/rods/mem.nr. Safe on null handles.
//
// v0.8.68: under NUC_VEC_FREE_GUARD=1, leaves the NVec struct
// alive with sentinel cap=0xDEADBEEF for reliable double-free
// detection. Default OFF.
void __nucleor_vec_free(long long handle) {
    if (handle == 0) return;
    NVec *v = (NVec *)(void *)(size_t)handle;
    if (!v) return;
    if (_nuc_vec_free_guard_enabled()) {
        // Check sentinel BEFORE accessing other fields — if this
        // is a double-free, the previous vec_free set cap to the
        // sentinel value. Safe to read since we never freed the
        // struct under guard mode.
        if (v->cap == NUC_VEC_FREED_SENTINEL_CAP) {
            fprintf(stderr,
                "PANIC-DOUBLE-FREE[OWN-012]: vec_free called twice on the same handle (0x%llx).\n"
                "  This is a use-after-drop / double-free bug in adopter code.\n"
                "  Per RFC-0062 G-4 Phase 2b runtime guard (sentinel-based).\n"
                "  Common cause: a fn returning a Vec that the caller subsequently\n"
                "  also tried to free, OR the compiler's auto-drop pipeline missed\n"
                "  a manual-free call site.\n"
                "  This guard is reliable (no false positives from malloc reuse).\n"
                "  To disable, unset env NUC_VEC_FREE_GUARD or set it to 0 — but\n"
                "  the underlying double-free remains a memory-safety bug.\n",
                (unsigned long long)handle);
            fflush(stderr);
            exit(134);  // standard double-free abort code
        }
        // Free the data buffer; INTENTIONALLY do NOT free(v).
        // Stamp the sentinel so a subsequent vec_free on the
        // same handle panics. The NVec struct (~32 bytes) leaks
        // — that's the cost of reliable detection.
        if (v->data && v->data != v->inline_data) free(v->data);
        v->data = NULL;
        v->len = 0;
        v->cap = NUC_VEC_FREED_SENTINEL_CAP;
        return;
    }
    // Default path: pre-v0.8.67 semantics. Free everything.
    if (v->data && v->data != v->inline_data) free(v->data);
    free(v);
}

// Free a heap-allocated string previously returned by str_concat,
// str_substring, sb_to_str, format_*, int_to_str, etc. Safe on
// null. Do NOT call on string literals — those live in the rodata
// section and free() would corrupt the heap. Use only on values
// the runtime explicitly malloc'd (return values of the allocating
// builtins listed above).
void __nucleor_str_free(const char *s) {
    if (s) free((void *)s);
}

void __nucleor_vec_push(NVec *v, long long x) {
    NUC_PROFILE_HOT(g_p_vec_push, vec_push);
    if (!v) return;
    if (v->len >= v->cap) {
        long long old_cap = v->cap;
        v->cap = _grow_cap(v->cap, sizeof(long long), "vec_push");
        if (v->data == v->inline_data) {
            long long *grown = (long long *)malloc(v->cap * sizeof(long long));
            memcpy(grown, v->inline_data, (size_t)v->len * sizeof(long long));
            v->data = grown;
        } else {
            v->data = (long long *)realloc(v->data, v->cap * sizeof(long long));
        }
        g_vec_realloc_bytes += (v->cap - old_cap) * sizeof(long long);
    }
    v->data[v->len++] = x;
}

// v0.3.200: NUC-FEEDBACK runtime safety — Vec OOB now PANICs by
// default with index/len in the message, instead of silently
// returning 0 (read) or no-op (write). Silent zero on OOB hides
// real bugs; the launch-bar is "no silent miscomputes". An
// adopter who needs the legacy behavior can set
// `NUCLEOR_VEC_OOB_LENIENT=1` in the environment to opt back in
// (e.g., when porting old programs that reached past end as a
// "is this slot empty?" idiom). Null-vector reads still return 0
// silently (null-safety, not OOB). Cached lookup at first call.
static int g_vec_oob_mode_cached = 0;  /* 0=uncached, 1=panic, 2=lenient */
static int _vec_oob_lenient(void) {
    if (g_vec_oob_mode_cached == 0) {
        const char *e = getenv("NUCLEOR_VEC_OOB_LENIENT");
        g_vec_oob_mode_cached = (e && e[0] == '1') ? 2 : 1;
    }
    return g_vec_oob_mode_cached == 2;
}

static inline long long __nucleor_vec_direct_checked(NVec *v, long long i, const char *what) {
    if (!v) return 0;
    if (i < 0 || i >= v->len) {
        if (_vec_oob_lenient()) return 0;
        fprintf(stderr, "PANIC: %s OOB: index %lld, len %lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                what, i, (long long)v->len);
        fflush(stderr);
        exit(1);
    }
    return v->data[(int)i];
}

long long nuc_node_kind(long long pool_cell, long long nid) {
    NVec *pool = (NVec *)(intptr_t)pool_cell;
    NVec *nd = (NVec *)(intptr_t)__nucleor_vec_direct_checked(pool, nid, "node_kind pool");
    return __nucleor_vec_direct_checked(nd, 0, "node_kind node");
}

long long nuc_node_field(long long pool_cell, long long nid, long long idx) {
    NVec *pool = (NVec *)(intptr_t)pool_cell;
    NVec *nd = (NVec *)(intptr_t)__nucleor_vec_direct_checked(pool, nid, "node_field pool");
    return __nucleor_vec_direct_checked(nd, idx, "node_field node");
}

long long nuc_list_len(long long pool_cell, long long lid) {
    NVec *pool = (NVec *)(intptr_t)pool_cell;
    NVec *nd = (NVec *)(intptr_t)__nucleor_vec_direct_checked(pool, lid, "list_len pool");
    if (!nd) return -1;
    return (long long)nd->len - 1;
}

long long nuc_list_get(long long pool_cell, long long lid, long long idx) {
    NVec *pool = (NVec *)(intptr_t)pool_cell;
    NVec *nd = (NVec *)(intptr_t)__nucleor_vec_direct_checked(pool, lid, "list_get pool");
    return __nucleor_vec_direct_checked(nd, idx + 1, "list_get list");
}

long long __nucleor_vec_get(NVec *v, long long i) {
    NUC_PROFILE_HOT(g_p_vec_get, vec_get);
    if (!v) return 0;
    if (i < 0 || i >= v->len) {
        if (_vec_oob_lenient()) return 0;
        // v0.6.29 (probe finding 2026-05-02-array-shape-gaps-repeat-init-
        // and-slice-param, gap 3): pre-fix wording was "vec_get OOB" which
        // leaked the internal Vec representation in the diag — adopters
        // writing canonical Rust array indexing `arr[99]` (where `arr: [i64; 3]`
        // desugars to a Vec internally) saw a `vec_get OOB` panic that
        // revealed the implementation. Rust-canonical wording works for
        // both real Vec<T> and array indexing without leaking either way.
        fprintf(stderr, "PANIC: index out of bounds: the len is %lld but the index is %lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                (long long)v->len, i);
        fflush(stderr);
        exit(1);
    }
    return v->data[(int)i];
}

long long __nucleor_vec_len(NVec *v) {
    NUC_PROFILE_HOT(g_p_vec_len, vec_len);
    if (!v) return 0;
    return (long long)v->len;
}

void __nucleor_vec_pop(NVec *v) {
    NUC_PROFILE_INC(g_p_vec_pop);
    if (!v || v->len <= 0) return;
    v->len--;
}

void __nucleor_vec_set(NVec *v, long long i, long long x) {
    NUC_PROFILE_HOT(g_p_vec_set, vec_set);
    if (!v) return;
    if (i < 0 || i >= v->len) {
        if (_vec_oob_lenient()) return;
        fprintf(stderr, "PANIC: vec_set OOB: index %lld, len %lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                i, (long long)v->len);
        fflush(stderr);
        exit(1);
    }
    v->data[(int)i] = x;
}

// --- v0.2.22: vec extras ---
// v0.3.201: same hazard class as v0.3.200 — extend strict OOB
// PANIC to vec_first/vec_last on empty and vec_swap on OOB index.
// vec_pop on empty stays a silent no-op (pop-the-top semantics
// reasonably maps to no-op when nothing to pop). vec_is_empty is
// a query, never errors.
long long __nucleor_vec_first(NVec *v) {
    if (!v) return 0;
    if (v->len <= 0) {
        if (_vec_oob_lenient()) return 0;
        fprintf(stderr, "PANIC: vec_first on empty Vec (len 0) (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n");
        fflush(stderr);
        exit(1);
    }
    return v->data[0];
}
long long __nucleor_vec_last(NVec *v) {
    if (!v) return 0;
    if (v->len <= 0) {
        if (_vec_oob_lenient()) return 0;
        fprintf(stderr, "PANIC: vec_last on empty Vec (len 0) (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n");
        fflush(stderr);
        exit(1);
    }
    return v->data[v->len - 1];
}
long long __nucleor_vec_is_empty(NVec *v) {
    if (!v) return 1;
    return v->len == 0 ? 1 : 0;
}
void __nucleor_vec_swap(NVec *v, long long i, long long j) {
    if (!v) return;
    if (i < 0 || j < 0 || i >= v->len || j >= v->len) {
        if (_vec_oob_lenient()) return;
        fprintf(stderr, "PANIC: vec_swap OOB: indices %lld,%lld len %lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                i, j, (long long)v->len);
        fflush(stderr);
        exit(1);
    }
    long long tmp = v->data[(int)i];
    v->data[(int)i] = v->data[(int)j];
    v->data[(int)j] = tmp;
}
void __nucleor_vec_extend(NVec *dst, NVec *src) {
    if (!dst || !src) return;
    int n = src->len;
    for (int i = 0; i < n; i++) {
        long long value = src->data[i];
        __nucleor_vec_push(dst, value);
    }
}
void __nucleor_vec_remove_at(NVec *v, long long i) {
    if (!v) return;
    if (i < 0 || i >= v->len) {
        if (_vec_oob_lenient()) return;
        fprintf(stderr, "PANIC: vec_remove_at OOB: index %lld, len %lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                i, (long long)v->len);
        fflush(stderr);
        exit(1);
    }
    int idx = (int)i;
    for (int k = idx; k < v->len - 1; k++) {
        v->data[k] = v->data[k + 1];
    }
    v->len--;
}
void __nucleor_vec_insert_at(NVec *v, long long i, long long x) {
    if (!v) return;
    // v0.6.44 (probe finding 2026-05-02-vec-insert-at-no-oob-check):
    // pre-fix this silently clamped negative idx to 0 and idx > len
    // to len, so `vec_insert_at(&v, 99, 42)` on a len=1 vec quietly
    // appended at the end and `vec_insert_at(&v, -1, 42)` quietly
    // prepended. Asymmetric with vec_get / vec_swap / vec_remove_at
    // which all PANIC on OOB with the same diag shape and the
    // NUCLEOR_VEC_OOB_LENIENT=1 escape hatch. Bring vec_insert_at
    // into the same pattern. Valid range is 0..=len (insert-at-end
    // is permitted; insert past end is OOB).
    if (i < 0 || i > v->len) {
        if (_vec_oob_lenient()) {
            // Lenient mode: clamp like the legacy behavior so old
            // adopters opting in via env var continue to work.
            if (i < 0) i = 0;
            if (i > v->len) i = v->len;
        } else {
            fprintf(stderr, "PANIC: index out of bounds: the len is %lld but the insert index is %lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n",
                    (long long)v->len, i);
            fflush(stderr);
            exit(1);
        }
    }
    int idx = (int)i;
    if (v->len >= v->cap) {
        v->cap = _grow_cap(v->cap, sizeof(long long), "vec_insert");
        if (v->data == v->inline_data) {
            long long *grown = (long long *)malloc(v->cap * sizeof(long long));
            memcpy(grown, v->inline_data, (size_t)v->len * sizeof(long long));
            v->data = grown;
        } else {
            v->data = (long long *)realloc(v->data, v->cap * sizeof(long long));
        }
    }
    for (int k = v->len; k > idx; k--) {
        v->data[k] = v->data[k - 1];
    }
    v->data[idx] = x;
    v->len++;
}

// === T2.4 (v0.2.350): trait object handle helpers ===
// A Box<dyn Trait> is represented as an i64 handle to a small
// 2-cell allocation: [type_id, data_ptr]. The compiler-generated
// dispatch helpers cast type_id back to a tag, look up the impl
// for that tag, and call the concrete fn with the data pointer.
//
// nuc_dyn_box_make(type_id, data) -> i64    Allocate + return handle.
// nuc_dyn_box_type(box)           -> i64    Read the type tag.
// nuc_dyn_box_data(box)           -> i64    Read the data pointer.
// nuc_dyn_box_free(box)           -> void   Free the wrapper (not the data).
//
// The 2-cell layout is intentionally simple — no vtable indirection,
// no fat-pointer ABI. Compiler-generated dispatch fns do the
// per-trait switch on type_id at the call site. T2.4b will add
// vtable-based dispatch once the runtime is ready for fat pointers.

long long __nucleor_dyn_box_make(long long type_id, long long data) {
    long long *box = (long long *)malloc(2 * sizeof(long long));
    if (!box) return 0;
    box[0] = type_id;
    box[1] = data;
    return (long long)(intptr_t)box;
}

long long __nucleor_dyn_box_type(long long box) {
    if (!box) return 0;
    return ((long long *)(intptr_t)box)[0];
}

long long __nucleor_dyn_box_data(long long box) {
    if (!box) return 0;
    return ((long long *)(intptr_t)box)[1];
}

void __nucleor_dyn_box_free(long long box) {
    if (box) free((void *)(intptr_t)box);
}

// === RFC-0024 phase 1: Vec<i64> functional helpers ===
// All take a Nucleor function pointer (i64 cell holding the function
// address) and apply it across the vec. The function-pointer arg
// matches Nucleor's existing par_map/par_fold convention.
//
//   vec_map_i64(v, fn)        — new Vec where each elem is fn(elem)
//   vec_filter_i64(v, pred)   — new Vec containing elems where pred(elem) != 0
//   vec_fold_i64(v, init, fn) — fold left: acc = fn(acc, elem) starting at init
//   vec_each_i64(v, fn)       — fold-without-accumulator (for side effects)
//   vec_sum_i64(v)            — sum of all elements (i64)
//   vec_min_i64(v)            — minimum element (returns 0 if empty)
//   vec_max_i64(v)            — maximum element (returns 0 if empty)

NVec *__nucleor_vec_map_i64(NVec *v, long long fn_ptr) {
    if (!v || !fn_ptr) return __nucleor_vec_new();
    long long (*fn)(long long) = (long long (*)(long long))(void *)(intptr_t)fn_ptr;
    NVec *out = __nucleor_vec_new();
    for (int i = 0; i < v->len; i++) {
        __nucleor_vec_push(out, fn(v->data[i]));
    }
    return out;
}

NVec *__nucleor_vec_filter_i64(NVec *v, long long fn_ptr) {
    if (!v || !fn_ptr) return __nucleor_vec_new();
    long long (*pred)(long long) = (long long (*)(long long))(void *)(intptr_t)fn_ptr;
    NVec *out = __nucleor_vec_new();
    for (int i = 0; i < v->len; i++) {
        if (pred(v->data[i]) != 0) __nucleor_vec_push(out, v->data[i]);
    }
    return out;
}

long long __nucleor_vec_fold_i64(NVec *v, long long init, long long fn_ptr) {
    if (!v || !fn_ptr) return init;
    long long (*fn)(long long, long long) = (long long (*)(long long, long long))(void *)(intptr_t)fn_ptr;
    long long acc = init;
    for (int i = 0; i < v->len; i++) acc = fn(acc, v->data[i]);
    return acc;
}

long long __nucleor_vec_each_i64(NVec *v, long long fn_ptr) {
    if (!v || !fn_ptr) return 0;
    long long (*fn)(long long) = (long long (*)(long long))(void *)(intptr_t)fn_ptr;
    for (int i = 0; i < v->len; i++) fn(v->data[i]);
    return (long long)v->len;
}

long long __nucleor_vec_sum_i64(NVec *v) {
    if (!v) return 0;
    long long s = 0;
    for (int i = 0; i < v->len; i++) s += v->data[i];
    return s;
}

long long __nucleor_vec_min_i64(NVec *v) {
    if (!v || v->len == 0) return 0;
    long long m = v->data[0];
    for (int i = 1; i < v->len; i++) if (v->data[i] < m) m = v->data[i];
    return m;
}

long long __nucleor_vec_max_i64(NVec *v) {
    if (!v || v->len == 0) return 0;
    long long m = v->data[0];
    for (int i = 1; i < v->len; i++) if (v->data[i] > m) m = v->data[i];
    return m;
}

// === RFC-0024 phase 1 (cont): Vec scalar utilities ===
// vec_contains_i64 / vec_index_of_i64 — linear search
// vec_reverse_i64 — in-place reverse, returns the same vec for chaining
// vec_sort_i64 — in-place ascending sort (qsort)
// vec_clone_i64 — deep copy
// vec_clear_i64 — len = 0 (capacity preserved)
//
// f64 variants take i64-cell bit patterns and operate as doubles.

long long __nucleor_vec_contains_i64(NVec *v, long long needle) {
    if (!v) return 0;
    for (int i = 0; i < v->len; i++) if (v->data[i] == needle) return 1;
    return 0;
}

long long __nucleor_vec_index_of_i64(NVec *v, long long needle) {
    if (!v) return -1;
    for (int i = 0; i < v->len; i++) if (v->data[i] == needle) return (long long)i;
    return -1;
}

NVec *__nucleor_vec_reverse_i64(NVec *v) {
    if (!v || v->len < 2) return v;
    int lo = 0, hi = v->len - 1;
    while (lo < hi) {
        long long t = v->data[lo]; v->data[lo] = v->data[hi]; v->data[hi] = t;
        lo++; hi--;
    }
    return v;
}

static int __nuc_qcmp_i64(const void *a, const void *b) {
    long long x = *(const long long *)a, y = *(const long long *)b;
    if (x < y) return -1;
    if (x > y) return 1;
    return 0;
}
NVec *__nucleor_vec_sort_i64(NVec *v) {
    if (!v || v->len < 2) return v;
    qsort(v->data, (size_t)v->len, sizeof(long long), __nuc_qcmp_i64);
    return v;
}

NVec *__nucleor_vec_clone_i64(NVec *v) {
    NVec *out = __nucleor_vec_new();
    if (!v) return out;
    for (int i = 0; i < v->len; i++) __nucleor_vec_push(out, v->data[i]);
    return out;
}

long long __nucleor_vec_clear_i64(NVec *v) {
    if (!v) return 0;
    v->len = 0;
    return 0;
}

// f64 reductions — values are i64 bit-patterns.
// v0.3.88: __nucleor_vec_iter — identity pass-through. The Rust idiom
// `vec.iter().sum()` requires .iter() to return something the rest of
// the iter chain can be called on. Since Nucleor's iter methods are
// all defined on Vec directly (vec_sum_i64, vec_map_i64, etc.),
// .iter() is a no-op that returns the same Vec. Without this helper,
// every `vec.iter().X()` chain failed at clang link.
long long __nucleor_vec_iter(NVec *v) {
    return (long long)(intptr_t)v;
}
long long __nucleor_vec_iter_i64(NVec *v) {
    return (long long)(intptr_t)v;
}

// v0.3.102: vec_collect_i64 — identity terminator for the
// `.iter().map(f).collect()` chain. The intermediate `.map`
// returns a fresh Vec already; .collect() just hands it back to
// the caller. Without this, Rust-canonical `let w = v.iter()
// .map(f).collect();` failed at clang link with `@vec_collect`
// undefined even though the value flowing into it was already a
// well-formed Vec.
long long __nucleor_vec_collect_i64(NVec *v) {
    return (long long)(intptr_t)v;
}

// v0.3.108: vec_count_i64 — Rust-style `.iter().count()`
// terminator. Returns the number of elements in the underlying
// Vec, mirroring `Iterator::count()`. Without this, the canonical
// pattern `let n = v.iter().count();` failed at clang link with
// `@vec_count` undefined.
long long __nucleor_vec_count_i64(NVec *v) {
    if (!v) return 0;
    return v->len;
}

// v0.3.109: iterator combinators commonly reached for in Rust
// adoption — `.take(n)`, `.skip(n)`. The `any`/`all` helpers
// already existed earlier in this file (v0.2.x); v0.3.109 adds
// the compiler-side surface dispatch for all four through
// `iter_method_for_vec`. take/skip are new helpers — they return
// fresh Vec views so the rest of the chain operates on the
// truncated/skipped slice. Without these, the canonical chain
// `v.iter().take(N).sum()` failed at clang link with
// `@vec_take undefined`.
long long __nucleor_vec_take_i64(NVec *v, long long n) {
    NVec *out = (NVec*)__nucleor_vec_new();
    if (!v || n <= 0) return (long long)(intptr_t)out;
    long long take = n < v->len ? n : v->len;
    for (long long i = 0; i < take; i++) {
        __nucleor_vec_push(out, v->data[i]);
    }
    return (long long)(intptr_t)out;
}
long long __nucleor_vec_skip_i64(NVec *v, long long n) {
    NVec *out = (NVec*)__nucleor_vec_new();
    if (!v) return (long long)(intptr_t)out;
    long long start = n < 0 ? 0 : n;
    for (long long i = start; i < v->len; i++) {
        __nucleor_vec_push(out, v->data[i]);
    }
    return (long long)(intptr_t)out;
}

// v0.4.101 audit doc-#1 §6 partial: vec_chain — concat two iterators.
long long __nucleor_vec_chain_i64(NVec *a, NVec *b) {
    NVec *out = (NVec*)__nucleor_vec_new();
    if (a) for (long long i = 0; i < a->len; i++) __nucleor_vec_push(out, a->data[i]);
    if (b) for (long long i = 0; i < b->len; i++) __nucleor_vec_push(out, b->data[i]);
    return (long long)(intptr_t)out;
}

// v0.4.125 audit doc-#1 §6 (iterator surface extension):
//   position, product, step_by, nth, reduce.
// All operate on the i64 element type. position/nth use the i64 ABI's
// fn-pointer convention (i64 cast to function pointer at call site).
//
// position(pred) -> i64 — index of first elem where pred(x) != 0,
//                        or -1 if none. Pred is fn(i64) -> i64.
long long __nucleor_vec_position_i64(NVec *v, long long fn_ptr) {
    if (!v || fn_ptr == 0) return -1;
    long long (*pred)(long long) = (long long (*)(long long))(intptr_t)fn_ptr;
    for (long long i = 0; i < v->len; i++) {
        if (pred(v->data[i]) != 0) return i;
    }
    return -1;
}

// product() -> i64 — multiplies all elements. Empty vec returns 1
//                    (matches Rust's Iterator::product convention).
long long __nucleor_vec_product_i64(NVec *v) {
    if (!v) return 1;
    long long acc = 1;
    for (long long i = 0; i < v->len; i++) acc *= v->data[i];
    return acc;
}

// step_by(n) -> Vec — returns every n-th element (starting at 0).
//                     n must be > 0; n <= 0 yields empty vec.
long long __nucleor_vec_step_by_i64(NVec *v, long long n) {
    NVec *out = (NVec*)__nucleor_vec_new();
    if (!v || n <= 0) return (long long)(intptr_t)out;
    for (long long i = 0; i < v->len; i += n) __nucleor_vec_push(out, v->data[i]);
    return (long long)(intptr_t)out;
}

// nth(n) -> i64 — returns the n-th element (0-indexed). Panics on OOB
//                 to match the v0.4.106-class clean-halt pattern.
long long __nucleor_vec_nth_i64(NVec *v, long long n) {
    if (!v || n < 0 || n >= v->len) {
        fprintf(stderr, "PANIC: vec_nth OOB: index %lld, len %lld\n",
                n, v ? v->len : 0LL);
        exit(1);
    }
    return v->data[n];
}

// reduce(fn) -> i64 — like fold but uses first element as init.
//                     Empty vec returns 0 (Rust returns Option::None;
//                     the i64-everywhere ABI doesn't yet box the
//                     return, so callers should pre-check is_empty).
long long __nucleor_vec_reduce_i64(NVec *v, long long fn_ptr) {
    if (!v || v->len == 0 || fn_ptr == 0) return 0;
    long long (*fn)(long long, long long) = (long long (*)(long long, long long))(intptr_t)fn_ptr;
    long long acc = v->data[0];
    for (long long i = 1; i < v->len; i++) acc = fn(acc, v->data[i]);
    return acc;
}

long long __nucleor_vec_sum_f64(NVec *v) {
    if (!v) return 0;
    union { long long i; double d; } acc;
    acc.d = 0.0;
    for (int i = 0; i < v->len; i++) {
        union { long long i; double d; } u;
        u.i = v->data[i];
        acc.d += u.d;
    }
    return acc.i;
}

typedef union { long long i; double d; } NucI64F64;

long long __nucleor_vec_min_f64(NVec *v) {
    NucI64F64 m, u;
    if (!v || v->len == 0) { m.d = 0.0; return m.i; }
    m.i = v->data[0];
    for (int i = 1; i < v->len; i++) {
        u.i = v->data[i];
        if (u.d < m.d) m = u;
    }
    return m.i;
}

long long __nucleor_vec_max_f64(NVec *v) {
    NucI64F64 m, u;
    if (!v || v->len == 0) { m.d = 0.0; return m.i; }
    m.i = v->data[0];
    for (int i = 1; i < v->len; i++) {
        u.i = v->data[i];
        if (u.d > m.d) m = u;
    }
    return m.i;
}

// === RFC-0024 phase 1 (cont): Vec<i64> arithmetic helpers ===
// vec_avg_i64    — integer mean (truncated)
// vec_dot_i64    — sum-of-element-product of two equal-length vecs
// vec_count_eq_i64 — number of elements equal to needle
// vec_any_i64    — 1 if any elem matches predicate fn, else 0
// vec_all_i64    — 1 if every elem matches predicate fn, else 0

long long __nucleor_vec_avg_i64(NVec *v) {
    if (!v || v->len == 0) return 0;
    long long s = 0;
    for (int i = 0; i < v->len; i++) s += v->data[i];
    return s / (long long)v->len;
}

long long __nucleor_vec_dot_i64(NVec *a, NVec *b) {
    if (!a || !b) return 0;
    int n = a->len < b->len ? a->len : b->len;
    long long s = 0;
    for (int i = 0; i < n; i++) s += a->data[i] * b->data[i];
    return s;
}

long long __nucleor_vec_count_eq_i64(NVec *v, long long needle) {
    if (!v) return 0;
    long long c = 0;
    for (int i = 0; i < v->len; i++) if (v->data[i] == needle) c++;
    return c;
}

long long __nucleor_vec_any_i64(NVec *v, long long fn_ptr) {
    if (!v || !fn_ptr) return 0;
    long long (*pred)(long long) = (long long (*)(long long))(void *)(intptr_t)fn_ptr;
    for (int i = 0; i < v->len; i++) if (pred(v->data[i]) != 0) return 1;
    return 0;
}

long long __nucleor_vec_all_i64(NVec *v, long long fn_ptr) {
    if (!v || !fn_ptr) return v ? 1 : 0;
    long long (*pred)(long long) = (long long (*)(long long))(void *)(intptr_t)fn_ptr;
    for (int i = 0; i < v->len; i++) if (pred(v->data[i]) == 0) return 0;
    return 1;
}

// === Char predicate + transformation helpers (RFC-0017) ===
// All take an i64 (char code; ASCII is always-correct subset of UTF-8 for
// these predicates). All return i64 (0/1 for predicates; new code for
// transformations).

long long __nucleor_char_is_alpha(long long c) {
    return ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) ? 1 : 0;
}
long long __nucleor_char_is_digit(long long c) {
    return (c >= '0' && c <= '9') ? 1 : 0;
}
long long __nucleor_char_is_alnum(long long c) {
    if (__nucleor_char_is_alpha(c) || __nucleor_char_is_digit(c)) return 1;
    return 0;
}
long long __nucleor_char_is_whitespace(long long c) {
    return (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\v' || c == '\f') ? 1 : 0;
}
long long __nucleor_char_is_upper(long long c) {
    return (c >= 'A' && c <= 'Z') ? 1 : 0;
}
long long __nucleor_char_is_lower(long long c) {
    return (c >= 'a' && c <= 'z') ? 1 : 0;
}
long long __nucleor_char_is_hex_digit(long long c) {
    if (__nucleor_char_is_digit(c)) return 1;
    if (c >= 'a' && c <= 'f') return 1;
    if (c >= 'A' && c <= 'F') return 1;
    return 0;
}
long long __nucleor_char_is_punct(long long c) {
    if (c >= '!' && c <= '/') return 1;
    if (c >= ':' && c <= '@') return 1;
    if (c >= '[' && c <= '`') return 1;
    if (c >= '{' && c <= '~') return 1;
    return 0;
}
long long __nucleor_char_is_ascii(long long c) {
    return (c >= 0 && c <= 127) ? 1 : 0;
}
long long __nucleor_char_to_upper(long long c) {
    if (c >= 'a' && c <= 'z') return c - 'a' + 'A';
    return c;
}
long long __nucleor_char_to_lower(long long c) {
    if (c >= 'A' && c <= 'Z') return c - 'A' + 'a';
    return c;
}
long long __nucleor_char_digit_value(long long c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return 10 + (c - 'a');
    if (c >= 'A' && c <= 'F') return 10 + (c - 'A');
    return -1;
}

// === RFC-0024 phase 1 (cont): Vec<i64> arithmetic helpers ===
NVec *__nucleor_str_split(const char *s, const char *sep) {
    NVec *out = __nucleor_vec_new();
    if (!s) return out;
    if (!sep || !*sep) {
        size_t L = strlen(s);
        char *copy = (char *)malloc(L + 1);
        memcpy(copy, s, L + 1);
        __nucleor_vec_push(out, (long long)(intptr_t)copy);
        return out;
    }
    size_t sl = strlen(sep);
    const char *scan = s;
    const char *p;
    while ((p = strstr(scan, sep)) != NULL) {
        size_t L = (size_t)(p - scan);
        char *piece = (char *)malloc(L + 1);
        memcpy(piece, scan, L);
        piece[L] = 0;
        __nucleor_vec_push(out, (long long)(intptr_t)piece);
        scan = p + sl;
    }
    size_t tailL = strlen(scan);
    char *tail = (char *)malloc(tailL + 1);
    memcpy(tail, scan, tailL + 1);
    __nucleor_vec_push(out, (long long)(intptr_t)tail);
    return out;
}

// --- v0.2.26 (cont): Vec-using str helpers ---
const char *__nucleor_str_join(const char *sep, NVec *parts) {
    if (!parts || parts->len == 0) {
        char *e = (char *)malloc(1); e[0] = 0; return e;
    }
    if (!sep) sep = "";
    size_t sep_len = strlen(sep);
    size_t total = 0;
    for (int i = 0; i < parts->len; i++) {
        const char *p = (const char *)(intptr_t)parts->data[i];
        if (p) total += strlen(p);
        if (i + 1 < parts->len) total += sep_len;
    }
    char *out = (char *)malloc(total + 1);
    size_t off = 0;
    for (int i = 0; i < parts->len; i++) {
        const char *p = (const char *)(intptr_t)parts->data[i];
        if (p) {
            size_t L = strlen(p);
            memcpy(out + off, p, L);
            off += L;
        }
        if (i + 1 < parts->len && sep_len > 0) {
            memcpy(out + off, sep, sep_len);
            off += sep_len;
        }
    }
    out[off] = 0;
    return out;
}
NVec *__nucleor_str_lines(const char *s) {
    NVec *out = __nucleor_vec_new();
    if (!s) return out;
    const char *scan = s;
    while (*scan) {
        const char *p = scan;
        while (*p && *p != '\n') p++;
        size_t L = (size_t)(p - scan);
        if (L > 0 && scan[L - 1] == '\r') L--;
        char *line = (char *)malloc(L + 1);
        memcpy(line, scan, L);
        line[L] = 0;
        __nucleor_vec_push(out, (long long)(intptr_t)line);
        if (!*p) break;
        scan = p + 1;
        if (!*scan) break;
    }
    return out;
}
NVec *__nucleor_str_chars(const char *s) {
    NVec *out = __nucleor_vec_new();
    if (!s) return out;
    while (*s) {
        __nucleor_vec_push(out, (long long)(unsigned char)*s);
        s++;
    }
    return out;
}

// --- v0.2.29 (cont): Vec-using random helpers ---
extern long long nuc_rng_int(long long lo, long long hi);

long long __nucleor_random_choice(NVec *v) {
    if (!v || v->len <= 0) return 0;
    long long idx = nuc_rng_int(0, (long long)(v->len - 1));
    return v->data[(int)idx];
}
void __nucleor_vec_shuffle(NVec *v) {
    if (!v || v->len < 2) return;
    // Fisher-Yates in place, walking backward.
    for (int i = v->len - 1; i > 0; i--) {
        long long j = nuc_rng_int(0, (long long)i);
        long long tmp = v->data[i];
        v->data[i] = v->data[(int)j];
        v->data[(int)j] = tmp;
    }
}
NVec *__nucleor_vec_sample(NVec *v, long long k) {
    NVec *out = __nucleor_vec_new();
    if (!v || k <= 0) return out;
    if (k > (long long)v->len) k = (long long)v->len;
    // Build a shuffled copy of the source indices, take first k.
    int *idx = (int *)malloc(sizeof(int) * v->len);
    for (int i = 0; i < v->len; i++) idx[i] = i;
    for (int i = v->len - 1; i > 0; i--) {
        long long j = nuc_rng_int(0, (long long)i);
        int t = idx[i]; idx[i] = idx[j]; idx[j] = t;
    }
    for (long long i = 0; i < k; i++) {
        __nucleor_vec_push(out, v->data[idx[i]]);
    }
    free(idx);
    return out;
}
void __nucleor_random_fill(NVec *v, long long lo, long long hi) {
    if (!v) return;
    for (int i = 0; i < v->len; i++) {
        v->data[i] = nuc_rng_int(lo, hi);
    }
}

// --- v0.2.30: Vec statistics helpers ---
// vec_mean_f64 / vec_median_f64 / vec_variance_f64 / vec_stddev_f64 /
// vec_percentile_f64 all return f64 bits in an i64 cell. vec_range_i64
// returns max - min as i64.
//
// Empty inputs return 0 / 0.0 (no exception). vec_median + vec_percentile
// allocate a sorted scratch copy so the source vec is not mutated.

long long __nucleor_vec_mean_f64(NVec *v) {
    union { long long i; double d; } u;
    if (!v || v->len <= 0) { u.d = 0.0; return u.i; }
    long long sum = 0;
    for (int i = 0; i < v->len; i++) sum += v->data[i];
    u.d = (double)sum / (double)v->len;
    return u.i;
}
long long __nucleor_vec_median_f64(NVec *v) {
    union { long long i; double d; } u;
    if (!v || v->len <= 0) { u.d = 0.0; return u.i; }
    long long *copy = (long long *)malloc(sizeof(long long) * v->len);
    memcpy(copy, v->data, sizeof(long long) * v->len);
    // Insertion sort — fine for the typical "stat over a small vec" use case.
    for (int i = 1; i < v->len; i++) {
        long long key = copy[i]; int j = i - 1;
        while (j >= 0 && copy[j] > key) { copy[j + 1] = copy[j]; j--; }
        copy[j + 1] = key;
    }
    if (v->len % 2 == 1) {
        u.d = (double)copy[v->len / 2];
    } else {
        long long a = copy[v->len / 2 - 1];
        long long b = copy[v->len / 2];
        u.d = ((double)a + (double)b) / 2.0;
    }
    free(copy);
    return u.i;
}
long long __nucleor_vec_variance_f64(NVec *v) {
    union { long long i; double d; } u;
    if (!v || v->len <= 0) { u.d = 0.0; return u.i; }
    long long sum = 0;
    for (int i = 0; i < v->len; i++) sum += v->data[i];
    double mean = (double)sum / (double)v->len;
    double accum = 0.0;
    for (int i = 0; i < v->len; i++) {
        double dv = (double)v->data[i] - mean;
        accum += dv * dv;
    }
    u.d = accum / (double)v->len;
    return u.i;
}
long long __nucleor_vec_stddev_f64(NVec *v) {
    union { long long i; double d; } u;
    long long var_bits = __nucleor_vec_variance_f64(v);
    union { long long i; double d; } vu; vu.i = var_bits;
    u.d = sqrt(vu.d);
    return u.i;
}
long long __nucleor_vec_range_i64(NVec *v) {
    if (!v || v->len <= 0) return 0;
    long long mn = v->data[0], mx = v->data[0];
    for (int i = 1; i < v->len; i++) {
        if (v->data[i] < mn) mn = v->data[i];
        if (v->data[i] > mx) mx = v->data[i];
    }
    return mx - mn;
}
long long __nucleor_vec_percentile_f64(NVec *v, long long p_bits) {
    union { long long i; double d; } u;
    if (!v || v->len <= 0) { u.d = 0.0; return u.i; }
    union { long long i; double d; } pu; pu.i = p_bits;
    double p = pu.d;
    /* v0.3.227: NaN -> 0.0 (Rust as semantic). Pre-fix NaN passed
       through both bounds (NaN < 0 false, NaN > 1 false), then
       `(int)(NaN * (v->len-1))` was C undefined behavior. */
    if (p != p) p = 0.0;
    if (p < 0.0) p = 0.0;
    if (p > 1.0) p = 1.0;
    long long *copy = (long long *)malloc(sizeof(long long) * v->len);
    memcpy(copy, v->data, sizeof(long long) * v->len);
    for (int i = 1; i < v->len; i++) {
        long long key = copy[i]; int j = i - 1;
        while (j >= 0 && copy[j] > key) { copy[j + 1] = copy[j]; j--; }
        copy[j + 1] = key;
    }
    // Linear interpolation between bracketing samples.
    double idx = p * (double)(v->len - 1);
    int lo = (int)idx;
    int hi = (lo + 1 < v->len) ? lo + 1 : lo;
    double frac = idx - (double)lo;
    u.d = (double)copy[lo] + frac * ((double)copy[hi] - (double)copy[lo]);
    free(copy);
    return u.i;
}

// === StringBuilder (amortized O(1) append, avoids O(n^2) str_concat) ===
typedef struct { char *data; int len; int cap; } NStrBuilder;

long long __nucleor_sb_new(void) {
    // RFC-0030 phase 2 (v0.2.166) — initial capacity dropped from 4 KB
    // to 256 B. The s1 self-host creates ~13K SBs per compile; most
    // never exceed the small range (diag messages, type-name builders,
    // identifier escapers). The 4 KB initial wasted ~50 MB across the
    // compile. Grow-on-append still handles the large IR string-
    // builder sites correctly — it just costs an extra realloc or two
    // (sb_append doubles, so 256→512→1024→2048→4096 = 4 reallocs vs
    // one to reach 4 KB; per-realloc is a memcpy and is amortized).
    g_sb_new_count++;
    NStrBuilder *sb = (NStrBuilder *)malloc(sizeof(NStrBuilder));
    sb->cap = 256;
    sb->data = (char *)malloc(sb->cap);
    sb->data[0] = '\0';
    sb->len = 0;
    g_sb_realloc_bytes += sizeof(NStrBuilder) + sb->cap;
    return (long long)sb;
}

// v0.2.173 — sb_new variant that takes an explicit initial capacity.
// Lets the IR builder pre-size to ~2 MB (the typical s1-compile IR
// length) and skip the 14+ reallocs the default 256 B initial would
// otherwise cost on its way up.
long long __nucleor_sb_new_with_cap(long long initial_cap) {
    g_sb_new_count++;
    NStrBuilder *sb = (NStrBuilder *)malloc(sizeof(NStrBuilder));
    sb->cap = (initial_cap > 0) ? initial_cap : 256;
    sb->data = (char *)malloc(sb->cap);
    sb->data[0] = '\0';
    sb->len = 0;
    g_sb_realloc_bytes += sizeof(NStrBuilder) + sb->cap;
    return (long long)sb;
}

// v0.2.172 — append a single byte without allocating a temp string.
// The compiler's escape_llvm_str path was allocating a 2-byte
// substring per non-special character of every string literal —
// 4 K+ literals × ~20 chars = 80 K+ transient allocations of 2-byte
// strings just to call sb_append with a one-character payload.
void __nucleor_sb_append_char(long long handle, long long c) {
    NStrBuilder *sb = (NStrBuilder *)(void *)handle;
    if (!sb) return;
    if (sb->len + 2 > sb->cap) {
        long long old_cap = sb->cap;
        sb->cap = _grow_cap(sb->cap, sizeof(char), "stringbuf push");
        sb->data = (char *)realloc(sb->data, sb->cap);
        g_sb_realloc_bytes += sb->cap - old_cap;
    }
    sb->data[sb->len++] = (char)(c & 0xFF);
    sb->data[sb->len] = '\0';
}

void __nucleor_sb_append_char_at(long long handle, const char *s, long long i) {
    NStrBuilder *sb = (NStrBuilder *)(void *)handle;
    if (!sb || !s) return;
    if (i < 0) {
        if (_vec_oob_lenient()) return;
        fprintf(stderr, "PANIC: sb_append_char_at OOB: negative index %lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n", i);
        fflush(stderr);
        exit(1);
    }
    if (sb->len + 2 > sb->cap) {
        long long old_cap = sb->cap;
        sb->cap = _grow_cap(sb->cap, sizeof(char), "stringbuf push");
        sb->data = (char *)realloc(sb->data, sb->cap);
        g_sb_realloc_bytes += sb->cap - old_cap;
    }
    sb->data[sb->len++] = (char)((unsigned char)s[(int)i]);
    sb->data[sb->len] = '\0';
}

void __nucleor_sb_append_range(long long handle, const char *s, long long start, long long end) {
    NStrBuilder *sb = (NStrBuilder *)(void *)handle;
    if (!sb || !s) return;
    if (start < 0 || end < start) {
        if (_vec_oob_lenient()) return;
        fprintf(stderr, "PANIC: sb_append_range OOB: start=%lld end=%lld (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n", start, end);
        fflush(stderr);
        exit(1);
    }
    int n = (int)(end - start);
    while (sb->len + n + 1 > sb->cap) {
        long long old_cap = sb->cap;
        sb->cap = _grow_cap(sb->cap, sizeof(char), "stringbuf range append");
        sb->data = (char *)realloc(sb->data, sb->cap);
        g_sb_realloc_bytes += sb->cap - old_cap;
    }
    memcpy(sb->data + sb->len, s + (int)start, n);
    sb->len += n;
    sb->data[sb->len] = '\0';
}

void __nucleor_sb_append(long long handle, const char *s) {
    if (!s) return;
    NStrBuilder *sb = (NStrBuilder *)(void *)handle;
    int slen = (int)strlen(s);
    while (sb->len + slen + 1 > sb->cap) {
        long long old_cap = sb->cap;
        sb->cap = _grow_cap(sb->cap, sizeof(char), "stringbuf append");
        sb->data = (char *)realloc(sb->data, sb->cap);
        g_sb_realloc_bytes += sb->cap - old_cap;
    }
    memcpy(sb->data + sb->len, s, slen + 1);
    sb->len += slen;
}

const char *__nucleor_sb_to_str(long long handle) {
    NStrBuilder *sb = (NStrBuilder *)(void *)handle;
    const char *result = sb->data;
    free(sb);
    return result;
}

void __nucleor_sb_free(long long handle) {
    NStrBuilder *sb = (NStrBuilder *)(void *)handle;
    if (sb) {
        free(sb->data);
        free(sb);
    }
}

// === File append ===
void __nucleor_file_append_string(const char *path, const char *data) {
    if (!path || !data) return;
    FILE *f = fopen(path, "ab");
    if (f) {
        fwrite(data, 1, strlen(data), f);
        fclose(f);
    }
}

// === File byte-equality ===
// v0.8.323 — true byte-level file comparison. Replaces the
// verify-reproducible Python filecmp.cmp shell-out (the last Python
// dependency in the compiler product, TOOLCHAIN-PY-1) and the POSIX
// `cmp -s` system() shell-out. Returns 1 if both files exist and have
// byte-identical contents; 0 otherwise (including missing/unreadable
// files). NULs in content are handled correctly — fread doesn't
// truncate the way file_read_string's strlen-based caller would.
long long __nucleor_file_bytes_equal(const char *a, const char *b) {
    if (!a || !b) return 0;
    FILE *fa = fopen(a, "rb");
    if (!fa) return 0;
    FILE *fb = fopen(b, "rb");
    if (!fb) { fclose(fa); return 0; }
    /* Size compare first — different sizes can't be equal. */
    if (fseek(fa, 0, SEEK_END) != 0 || fseek(fb, 0, SEEK_END) != 0) {
        fclose(fa); fclose(fb); return 0;
    }
    long sa = ftell(fa);
    long sb = ftell(fb);
    if (sa < 0 || sb < 0 || sa != sb) {
        fclose(fa); fclose(fb); return 0;
    }
    if (fseek(fa, 0, SEEK_SET) != 0 || fseek(fb, 0, SEEK_SET) != 0) {
        fclose(fa); fclose(fb); return 0;
    }
    /* Block-by-block compare. 64KB block balances syscall overhead
     * against memory footprint for the 2 MB compiler binaries this
     * helper was originally added for. */
    unsigned char ba[65536], bb[65536];
    long long equal = 1;
    while (sa > 0) {
        size_t want = sa > (long)sizeof(ba) ? sizeof(ba) : (size_t)sa;
        size_t na = fread(ba, 1, want, fa);
        size_t nb = fread(bb, 1, want, fb);
        if (na != want || nb != want) { equal = 0; break; }
        if (memcmp(ba, bb, want) != 0) { equal = 0; break; }
        sa -= (long)want;
    }
    fclose(fa);
    fclose(fb);
    return equal;
}

// === Named Pipe (Windows review surface transport) ===
#ifdef _WIN32
long long __nucleor_pipe_create(const char *name) {
    HANDLE pipe = CreateNamedPipeA(name,
        PIPE_ACCESS_OUTBOUND,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_NOWAIT,
        1, 65536, 0, 0, NULL);
    if (pipe == INVALID_HANDLE_VALUE) return 0;
    return (long long)pipe;
}
void __nucleor_pipe_write(long long handle, const char *data) {
    if (!handle || !data) return;
    DWORD written;
    WriteFile((HANDLE)handle, data, (DWORD)strlen(data), &written, NULL);
}
void __nucleor_pipe_close(long long handle) {
    if (!handle) return;
    FlushFileBuffers((HANDLE)handle);
    DisconnectNamedPipe((HANDLE)handle);
    CloseHandle((HANDLE)handle);
}
#else
long long __nucleor_pipe_create(const char *name) { return 0; }
void __nucleor_pipe_write(long long handle, const char *data) { (void)handle; (void)data; }
void __nucleor_pipe_close(long long handle) { (void)handle; }
#endif

// === Timing ===
#ifdef _WIN32
long long __nucleor_now_ms(void) {
    return (long long)GetTickCount64();
}
#else
#include <time.h>
long long __nucleor_now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}
#endif

// === Structured Concurrency (S14) ===
#ifdef _WIN32
typedef struct { long long (*fn)(long long); long long arg; } NThreadData;
static DWORD WINAPI nucleor_thread_proc(LPVOID param) {
    NThreadData *td = (NThreadData*)param;
    td->fn(td->arg);
    free(td);
    return 0;
}
long long __nucleor_thread_spawn(long long fn_ptr, long long arg) {
    NThreadData *td = (NThreadData*)malloc(sizeof(NThreadData));
    td->fn = (long long(*)(long long))(void*)fn_ptr;
    td->arg = arg;
    HANDLE h = CreateThread(NULL, 0, nucleor_thread_proc, td, CREATE_SUSPENDED, NULL);
    if (!h) { free(td); return 0; }
    // Set to lowest priority — NEVER preempt gaming or normal workloads
    SetThreadPriority(h, THREAD_PRIORITY_IDLE);
    ResumeThread(h);
    return (long long)h;
}
void __nucleor_thread_join(long long handle) {
    if (!handle) return;
    WaitForSingleObject((HANDLE)handle, INFINITE);
    CloseHandle((HANDLE)handle);
}
// === T2.8 (v0.2.353): async runtime — threads-only ===
// async fn / .await desugar to async_spawn / async_await. Each task
// is a real OS thread with a captured i64 result slot. Per the
// locked v0.2 design vote (RFC-0027 phase 1).
// v0.5.25: closes probe-agent findings
//   2026-05-01-async-await-twice-heap-corruption (CRASH-class)
//   2026-05-01-async-await-invalid-handle-segfault (CRASH-class)
// Pre-fix `__nucleor_async_await(h)` blindly dereferenced any non-zero
// i64 as NAsyncTask*. Two adopter mistakes hit memory-safety crashes:
//   1. await(spawn(...)) twice → free()'d memory dereferenced →
//      STATUS_HEAP_CORRUPTION (rc 0xC0000374).
//   2. await(<bogus i64>) → dereferences non-malloc'd memory →
//      STATUS_ACCESS_VIOLATION (rc 0xC0000005).
//
// Fix: maintain a registry of valid NAsyncTask* handles, protected by
// a critical section. spawn registers the handle. await checks the
// handle is in the registry BEFORE dereferencing — if not, panic with
// a clean Nucleor message naming the bogus value. After successful
// await, the handle is unregistered + freed; a second await sees an
// unregistered handle and panics rather than dereferencing freed
// memory.
//
// Registry is a small fixed-capacity array (256 slots) protected by a
// critical section. 256 concurrent tasks is well above the practical
// fan-out for v0.5; if adopters need more, this can grow to a hash
// table. PANIC at registration if full.
typedef struct NAsyncTask {
    HANDLE thread_handle;
    long long (*fn)(long long);
    long long arg;
    long long result;
} NAsyncTask;

#define NUC_ASYNC_REGISTRY_SIZE 256
static NAsyncTask *g_async_registry[NUC_ASYNC_REGISTRY_SIZE] = { 0 };
static CRITICAL_SECTION g_async_registry_cs;
static int g_async_registry_init = 0;

static void __nuc_async_registry_init(void) {
    if (!g_async_registry_init) {
        InitializeCriticalSection(&g_async_registry_cs);
        g_async_registry_init = 1;
    }
}
static int __nuc_async_registry_add(NAsyncTask *t) {
    EnterCriticalSection(&g_async_registry_cs);
    for (int i = 0; i < NUC_ASYNC_REGISTRY_SIZE; i++) {
        if (g_async_registry[i] == 0) {
            g_async_registry[i] = t;
            LeaveCriticalSection(&g_async_registry_cs);
            return 1;
        }
    }
    LeaveCriticalSection(&g_async_registry_cs);
    return 0;
}
// Returns 1 if found and removed (caller now owns t), 0 otherwise.
static int __nuc_async_registry_remove(NAsyncTask *t) {
    EnterCriticalSection(&g_async_registry_cs);
    for (int i = 0; i < NUC_ASYNC_REGISTRY_SIZE; i++) {
        if (g_async_registry[i] == t) {
            g_async_registry[i] = 0;
            LeaveCriticalSection(&g_async_registry_cs);
            return 1;
        }
    }
    LeaveCriticalSection(&g_async_registry_cs);
    return 0;
}
static DWORD WINAPI nucleor_async_proc(LPVOID param) {
    NAsyncTask *t = (NAsyncTask*)param;
    t->result = t->fn(t->arg);
    return 0;
}
long long __nucleor_async_spawn(long long fn_ptr, long long arg) {
    __nuc_async_registry_init();
    NAsyncTask *t = (NAsyncTask*)malloc(sizeof(NAsyncTask));
    if (!t) return 0;
    t->fn = (long long(*)(long long))(void*)fn_ptr;
    t->arg = arg;
    t->result = 0;
    if (!__nuc_async_registry_add(t)) {
        free(t);
        fprintf(stderr, "PANIC: async_spawn: handle registry full (max %d concurrent tasks). Free completed tasks via async_await before spawning more.\n", NUC_ASYNC_REGISTRY_SIZE);
        fflush(stderr); exit(1);
    }
    t->thread_handle = CreateThread(NULL, 0, nucleor_async_proc, t, 0, NULL);
    if (!t->thread_handle) {
        __nuc_async_registry_remove(t);
        free(t);
        return 0;
    }
    return (long long)(intptr_t)t;
}
long long __nucleor_async_await(long long task_handle) {
    if (!task_handle) {
        fprintf(stderr, "PANIC: async_await: handle is 0 (likely an uninitialized i64 or a failed async_spawn). Pass a handle returned from async_spawn().\n");
        fflush(stderr); exit(1);
    }
    __nuc_async_registry_init();
    NAsyncTask *t = (NAsyncTask*)(intptr_t)task_handle;
    if (!__nuc_async_registry_remove(t)) {
        fprintf(stderr, "PANIC: async_await: handle %lld is not a valid spawn handle (already awaited, or not from async_spawn). Each handle may be awaited exactly once.\n", task_handle);
        fflush(stderr); exit(1);
    }
    WaitForSingleObject(t->thread_handle, INFINITE);
    long long r = t->result;
    CloseHandle(t->thread_handle);
    free(t);
    return r;
}
long long __nucleor_mutex_new(void) {
    CRITICAL_SECTION *cs = (CRITICAL_SECTION*)malloc(sizeof(CRITICAL_SECTION));
    InitializeCriticalSection(cs);
    return (long long)cs;
}
void __nucleor_mutex_lock(long long handle) {
    if (!handle) return;
    EnterCriticalSection((CRITICAL_SECTION*)(void*)handle);
}
void __nucleor_mutex_unlock(long long handle) {
    if (!handle) return;
    LeaveCriticalSection((CRITICAL_SECTION*)(void*)handle);
}
// _value-suffixed forwarders — compiler emits these as of V2 (lines 1757-1759
// of nucleor_s1_compiler.nr). The value-passing variants forward to the
// underlying CRITICAL_SECTION-based implementation. Extra i64 args on _new
// reserved for future re-entrant / spinlock variants.
long long __nucleor_mutex_new_value(long long a, long long b) {
    (void)a; (void)b;
    return __nucleor_mutex_new();
}
// rng_seed bridge — compiler emits __nucleor_rng_seed(i64, i64) and the
// rng implementation lives in stdlib/runtime/rng_rt.c (nuc_rng_seed).
// The second argument is reserved (currently unused).
extern void nuc_rng_seed(long long seed);
extern long long nuc_rng_uniform(void);
extern long long nuc_rng_int(long long lo, long long hi);
extern long long nuc_rng_normal(void);
extern long long nuc_rng_bernoulli(long long p_bits);
extern long long nuc_rng_exponential(long long lambda_bits);

long long __nucleor_rng_seed(long long seed, long long reserved) {
    (void)reserved;
    nuc_rng_seed(seed);
    return 0;
}

// Public RNG bridges — pair with the get_rt_name registrations.
// __nucleor_random_uniform / __nucleor_random_normal were previously
// declared but never defined; this commit closes that latent linker gap.
long long __nucleor_random_uniform(long long _reserved) {
    (void)_reserved;
    return nuc_rng_uniform();
}
long long __nucleor_random_normal(long long _reserved) {
    (void)_reserved;
    return nuc_rng_normal();
}
long long __nucleor_rng_int(long long lo, long long hi) {
    return nuc_rng_int(lo, hi);
}
long long __nucleor_rng_uniform(void) { return nuc_rng_uniform(); }
long long __nucleor_rng_normal(void) { return nuc_rng_normal(); }
long long __nucleor_rng_bernoulli(long long p_bits) { return nuc_rng_bernoulli(p_bits); }
long long __nucleor_rng_exponential(long long lambda_bits) { return nuc_rng_exponential(lambda_bits); }

// --- v0.2.29: random helpers (non-Vec) ---
long long __nucleor_random_int(long long lo, long long hi) {
    return nuc_rng_int(lo, hi);
}
long long __nucleor_random_bool(void) {
    return nuc_rng_int(0, 1);
}
long long __nucleor_mutex_lock_value(long long handle) {
    __nucleor_mutex_lock(handle);
    return 0;
}
void __nucleor_mutex_unlock_value(long long handle) {
    __nucleor_mutex_unlock(handle);
}
// Channel: thread-safe bounded queue
typedef struct {
    long long *buf; int cap; int head; int tail; int count;
    CRITICAL_SECTION lock; HANDLE not_empty; HANDLE not_full;
} NChannel;
long long __nucleor_channel_new(long long capacity) {
    NChannel *ch = (NChannel*)malloc(sizeof(NChannel));
    ch->cap = (int)capacity; if (ch->cap < 1) ch->cap = 16;
    ch->buf = (long long*)malloc(ch->cap * sizeof(long long));
    ch->head = 0; ch->tail = 0; ch->count = 0;
    InitializeCriticalSection(&ch->lock);
    ch->not_empty = CreateEvent(NULL, FALSE, FALSE, NULL);
    ch->not_full = CreateEvent(NULL, FALSE, TRUE, NULL);
    return (long long)ch;
}
void __nucleor_channel_send(long long handle, long long val) {
    NChannel *ch = (NChannel*)(void*)handle;
    if (!ch) return;
    while (1) {
        EnterCriticalSection(&ch->lock);
        if (ch->count < ch->cap) {
            ch->buf[ch->tail] = val;
            ch->tail = (ch->tail + 1) % ch->cap;
            ch->count++;
            SetEvent(ch->not_empty);
            LeaveCriticalSection(&ch->lock);
            return;
        }
        LeaveCriticalSection(&ch->lock);
        WaitForSingleObject(ch->not_full, 100);
    }
}
long long __nucleor_channel_recv(long long handle) {
    NChannel *ch = (NChannel*)(void*)handle;
    if (!ch) return 0;
    while (1) {
        EnterCriticalSection(&ch->lock);
        if (ch->count > 0) {
            long long val = ch->buf[ch->head];
            ch->head = (ch->head + 1) % ch->cap;
            ch->count--;
            SetEvent(ch->not_full);
            LeaveCriticalSection(&ch->lock);
            return val;
        }
        LeaveCriticalSection(&ch->lock);
        WaitForSingleObject(ch->not_empty, 100);
    }
}
long long __nucleor_channel_len(long long handle) {
    NChannel *ch = (NChannel*)(void*)handle;
    if (!ch) return 0;
    EnterCriticalSection(&ch->lock);
    long long n = ch->count;
    LeaveCriticalSection(&ch->lock);
    return n;
}
// Atomic counter for safe shared state
long long __nucleor_atomic_new(long long val) {
    long long *p = (long long*)malloc(sizeof(long long));
    *p = val;
    return (long long)p;
}
long long __nucleor_atomic_add(long long handle, long long delta) {
    return InterlockedAdd64((volatile LONG64*)(void*)handle, delta);
}
long long __nucleor_atomic_load(long long handle) {
    return InterlockedCompareExchange64((volatile LONG64*)(void*)handle, 0, 0);
}
// CPU count for work distribution
long long __nucleor_cpu_count(void) {
    SYSTEM_INFO si; GetSystemInfo(&si);
    return (long long)si.dwNumberOfProcessors;
}
#else
// POSIX stubs
#include <pthread.h>
#include <unistd.h>
typedef struct { long long (*fn)(long long); long long arg; } NThreadData;
static void* nucleor_thread_proc(void *param) {
    NThreadData *td = (NThreadData*)param;
    td->fn(td->arg);
    free(td);
    return NULL;
}
long long __nucleor_thread_spawn(long long fn_ptr, long long arg) {
    NThreadData *td = (NThreadData*)malloc(sizeof(NThreadData));
    td->fn = (long long(*)(long long))(void*)fn_ptr;
    td->arg = arg;
    pthread_t *t = (pthread_t*)malloc(sizeof(pthread_t));
    pthread_create(t, NULL, nucleor_thread_proc, td);
    // Set to lowest priority
    struct sched_param sp = {0}; sp.sched_priority = 0;
    pthread_setschedparam(*t, SCHED_IDLE, &sp);
    return (long long)t;
}
void __nucleor_thread_join(long long handle) {
    if (!handle) return;
    pthread_join(*(pthread_t*)(void*)handle, NULL);
    free((void*)handle);
}
// === T2.8 (v0.2.353): async runtime — POSIX side ===
// v0.5.25 mirrors the Win32 path's handle-validation registry (closes
// the same probe findings: async_await-twice heap corruption +
// async_await-invalid-handle segfault).
typedef struct NAsyncTask {
    pthread_t thread;
    long long (*fn)(long long);
    long long arg;
    long long result;
    int started;
} NAsyncTask;

#define NUC_ASYNC_REGISTRY_SIZE 256
static NAsyncTask *g_async_registry[NUC_ASYNC_REGISTRY_SIZE] = { 0 };
static pthread_mutex_t g_async_registry_mu = PTHREAD_MUTEX_INITIALIZER;

static int __nuc_async_registry_add(NAsyncTask *t) {
    pthread_mutex_lock(&g_async_registry_mu);
    for (int i = 0; i < NUC_ASYNC_REGISTRY_SIZE; i++) {
        if (g_async_registry[i] == 0) {
            g_async_registry[i] = t;
            pthread_mutex_unlock(&g_async_registry_mu);
            return 1;
        }
    }
    pthread_mutex_unlock(&g_async_registry_mu);
    return 0;
}
static int __nuc_async_registry_remove(NAsyncTask *t) {
    pthread_mutex_lock(&g_async_registry_mu);
    for (int i = 0; i < NUC_ASYNC_REGISTRY_SIZE; i++) {
        if (g_async_registry[i] == t) {
            g_async_registry[i] = 0;
            pthread_mutex_unlock(&g_async_registry_mu);
            return 1;
        }
    }
    pthread_mutex_unlock(&g_async_registry_mu);
    return 0;
}
static void* nucleor_async_proc(void *param) {
    NAsyncTask *t = (NAsyncTask*)param;
    t->result = t->fn(t->arg);
    return NULL;
}
long long __nucleor_async_spawn(long long fn_ptr, long long arg) {
    NAsyncTask *t = (NAsyncTask*)malloc(sizeof(NAsyncTask));
    if (!t) return 0;
    t->fn = (long long(*)(long long))(void*)fn_ptr;
    t->arg = arg;
    t->result = 0;
    t->started = 0;
    if (!__nuc_async_registry_add(t)) {
        free(t);
        fprintf(stderr, "PANIC: async_spawn: handle registry full (max %d concurrent tasks). Free completed tasks via async_await before spawning more.\n", NUC_ASYNC_REGISTRY_SIZE);
        fflush(stderr); exit(1);
    }
    if (pthread_create(&t->thread, NULL, nucleor_async_proc, t) != 0) {
        __nuc_async_registry_remove(t);
        free(t);
        return 0;
    }
    t->started = 1;
    return (long long)(intptr_t)t;
}
long long __nucleor_async_await(long long task_handle) {
    if (!task_handle) {
        fprintf(stderr, "PANIC: async_await: handle is 0 (likely an uninitialized i64 or a failed async_spawn). Pass a handle returned from async_spawn().\n");
        fflush(stderr); exit(1);
    }
    NAsyncTask *t = (NAsyncTask*)(intptr_t)task_handle;
    if (!__nuc_async_registry_remove(t)) {
        fprintf(stderr, "PANIC: async_await: handle %lld is not a valid spawn handle (already awaited, or not from async_spawn). Each handle may be awaited exactly once.\n", task_handle);
        fflush(stderr); exit(1);
    }
    if (t->started) pthread_join(t->thread, NULL);
    long long r = t->result;
    free(t);
    return r;
}
long long __nucleor_mutex_new(void) {
    pthread_mutex_t *m = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    pthread_mutex_init(m, NULL);
    return (long long)m;
}
void __nucleor_mutex_lock(long long handle) { pthread_mutex_lock((pthread_mutex_t*)(void*)handle); }
void __nucleor_mutex_unlock(long long handle) { pthread_mutex_unlock((pthread_mutex_t*)(void*)handle); }
long long __nucleor_mutex_new_value(long long a, long long b) { (void)a; (void)b; return __nucleor_mutex_new(); }
long long __nucleor_mutex_lock_value(long long handle) { __nucleor_mutex_lock(handle); return 0; }
void __nucleor_mutex_unlock_value(long long handle) { __nucleor_mutex_unlock(handle); }
extern void nuc_rng_seed(long long seed);
long long __nucleor_rng_seed(long long seed, long long reserved) { (void)reserved; nuc_rng_seed(seed); return 0; }
// v0.8.85 RFC C-2 Phase 1 — real POSIX bounded-FIFO channel.
// Pre-fix: four no-op stubs returning 0. channel_new returned
// NULL; channel_send dropped messages; channel_recv returned 0
// immediately (worse than RFC's "blocks forever" claim — at
// least a hang would alert). Adopters using channels for inter-
// thread fan-out / fan-in shipped Linux binaries that silently
// produced zeros where messages should be.
//
// Post-fix: pthread mutex + two condvars matching the Win32
// CRITICAL_SECTION + Event semantics. Bounded FIFO; send blocks
// when full; recv blocks when empty.
typedef struct {
    long long *buf; int cap; int head; int tail; int count;
    pthread_mutex_t lock;
    pthread_cond_t not_empty;
    pthread_cond_t not_full;
} NChannel_posix;
long long __nucleor_channel_new(long long cap) {
    NChannel_posix *ch = (NChannel_posix*)calloc(1, sizeof(NChannel_posix));
    if (!ch) return 0;
    ch->cap = (int)cap;
    if (ch->cap < 1) ch->cap = 16;
    ch->buf = (long long*)malloc(ch->cap * sizeof(long long));
    if (!ch->buf) { free(ch); return 0; }
    pthread_mutex_init(&ch->lock, NULL);
    pthread_cond_init(&ch->not_empty, NULL);
    pthread_cond_init(&ch->not_full, NULL);
    return (long long)ch;
}
void __nucleor_channel_send(long long h, long long v) {
    NChannel_posix *ch = (NChannel_posix*)(void*)h;
    if (!ch) return;
    pthread_mutex_lock(&ch->lock);
    while (ch->count == ch->cap) {
        pthread_cond_wait(&ch->not_full, &ch->lock);
    }
    ch->buf[ch->tail] = v;
    ch->tail = (ch->tail + 1) % ch->cap;
    ch->count++;
    pthread_cond_signal(&ch->not_empty);
    pthread_mutex_unlock(&ch->lock);
}
long long __nucleor_channel_recv(long long h) {
    NChannel_posix *ch = (NChannel_posix*)(void*)h;
    if (!ch) return 0;
    pthread_mutex_lock(&ch->lock);
    while (ch->count == 0) {
        pthread_cond_wait(&ch->not_empty, &ch->lock);
    }
    long long v = ch->buf[ch->head];
    ch->head = (ch->head + 1) % ch->cap;
    ch->count--;
    pthread_cond_signal(&ch->not_full);
    pthread_mutex_unlock(&ch->lock);
    return v;
}
long long __nucleor_channel_len(long long h) {
    NChannel_posix *ch = (NChannel_posix*)(void*)h;
    if (!ch) return 0;
    pthread_mutex_lock(&ch->lock);
    long long n = ch->count;
    pthread_mutex_unlock(&ch->lock);
    return n;
}
long long __nucleor_atomic_new(long long val) {
    long long *p = (long long*)malloc(sizeof(long long));
    *p = val; return (long long)p;
}
long long __nucleor_atomic_add(long long h, long long d) { return __sync_add_and_fetch((long long*)(void*)h, d); }
long long __nucleor_atomic_load(long long h) { return __sync_val_compare_and_swap((long long*)(void*)h, 0, 0); }
long long __nucleor_cpu_count(void) { return (long long)sysconf(_SC_NPROCESSORS_ONLN); }
#endif

// === Cancel Token (RFC C-1, v0.8.80) — cooperative cancellation primitive ===
// Implements the three symbols declared in the compiler's LLVM preamble:
//   declare i64 @__nucleor_cancel_token_new(i64)
//   declare void @__nucleor_cancel_token_cancel(i64)
//   declare i64 @__nucleor_cancel_token_is_cancelled(i64)
// Uses an atomic long long flag — safe for multi-threaded cancellation checks.
typedef struct { volatile long long flag; } NCancelToken;
long long __nucleor_cancel_token_new(long long reserved) {
    (void)reserved;
    NCancelToken *t = (NCancelToken*)calloc(1, sizeof(NCancelToken));
    return (long long)t;
}
void __nucleor_cancel_token_cancel(long long handle) {
    NCancelToken *t = (NCancelToken*)(void*)handle;
    if (!t) return;
#ifdef _WIN32
    InterlockedExchange64((volatile LONG64*)&t->flag, 1LL);
#else
    __sync_lock_test_and_set(&t->flag, 1LL);
#endif
}
long long __nucleor_cancel_token_is_cancelled(long long handle) {
    NCancelToken *t = (NCancelToken*)(void*)handle;
    if (!t) return 0;
#ifdef _WIN32
    return InterlockedCompareExchange64((volatile LONG64*)&t->flag, 0LL, 0LL) ? 1 : 0;
#else
    return __sync_val_compare_and_swap(&t->flag, 0LL, 0LL) ? 1 : 0;
#endif
}

// === Args ===
#ifdef _WIN32
// MSVC CRT globals are populated before main() runs.
extern int __argc;
extern char **__argv;
void __nucleor_init_args(int argc, char **argv) { (void)argc; (void)argv; }
long long __nucleor_args_count(void) { return (long long)__argc; }
const char *__nucleor_args_get(long long i) {
    if (i < 0 || i >= __argc) return "";
    return __argv[(int)i];
}
#else
// POSIX: store args forwarded from the Nucleor-emitted main() wrapper.
static int _nuc_argc = 0;
static char **_nuc_argv = NULL;
void __nucleor_init_args(int argc, char **argv) {
    _nuc_argc = argc;
    _nuc_argv = argv;
}
long long __nucleor_args_count(void) { return (long long)_nuc_argc; }
const char *__nucleor_args_get(long long i) {
    if (i < 0 || i >= _nuc_argc || !_nuc_argv) return "";
    return _nuc_argv[(int)i];
}
#endif

// === getcwd ===
// Returns the current working directory as a string. Used by tools that
// need to report or operate relative to the project root.
#ifdef _WIN32
#include <direct.h>
#define _NUC_GETCWD _getcwd
#else
#define _NUC_GETCWD getcwd
#endif
const char *__nucleor_getcwd(void) {
    static char buf[4096];
    if (_NUC_GETCWD(buf, sizeof(buf)) == NULL) { buf[0] = 0; }
    return buf;
}

// === getenv ===
// Returns the value of an environment variable, or "" if unset.
const char *__nucleor_getenv(const char *name) {
    if (!name) return "";
    const char *v = getenv(name);
    return v ? v : "";
}

// === chr ===
// Returns a 1-byte string for the given code point (0-255). Used by user
// programs that need arbitrary control bytes (e.g., ESC = 27 for ANSI).
const char *__nucleor_chr(long long code) {
    static char buffers[256][2];
    if (code < 0) code = 0;
    if (code > 255) code = 255;
    buffers[(int)code][0] = (char)code;
    buffers[(int)code][1] = 0;
    return buffers[(int)code];
}

// === isatty ===
// Returns 1 if stdout is connected to an interactive terminal, 0 otherwise.
// Used by progress-UI code to gate carriage-return / spinner output.
#ifdef _WIN32
#include <io.h>
long long __nucleor_isatty_stdout(void) {
    return _isatty(_fileno(stdout)) ? 1 : 0;
}
#else
#include <unistd.h>
long long __nucleor_isatty_stdout(void) {
    return isatty(STDOUT_FILENO) ? 1 : 0;
}
#endif

// === Test framework runtime (RFC-0021) ===
// __nucleor_assert(cond) — print FAIL + exit 1 if cond is 0; else return 0.
// __nucleor_assert_eq(a, b) — print FAIL + exit 1 if a != b; else return 0.
// Compiler emits these for the assert!/assert_eq! built-ins.
long long __nucleor_assert(long long cond) {
    if (cond == 0) {
        fprintf(stderr, "ASSERTION FAILED\n");
        fflush(stderr);
        exit(1);
    }
    return 0;
}

// v0.4.245 RFC-0006 Design by Contract — runtime require check.
// Emitted at fn entry by the compiler when a fn carries
// `#[require(EXPR)]`. EXPR is lowered to a boolean (i64; 0 =
// false, non-0 = true). On false, prints CONTRACT-001 and exits.
long long __nucleor_contract_require(long long cond) {
    if (cond == 0) {
        fprintf(stderr, "CONTRACT-001: require precondition violated\n");
        fflush(stderr);
        exit(1);
    }
    return 0;
}

// v0.4.245 RFC-0006 Design by Contract — runtime ensure check.
// Emitted at fn exit by the compiler when a fn carries
// `#[ensure(EXPR)]`. Same shape as require; CONTRACT-002 message.
long long __nucleor_contract_ensure(long long cond) {
    if (cond == 0) {
        fprintf(stderr, "CONTRACT-002: ensure postcondition violated\n");
        fflush(stderr);
        exit(1);
    }
    return 0;
}

// v0.4.248 RFC-0006 Design by Contract — runtime invariant check.
// Emitted at struct method entry by the compiler when the method's
// impl block carries `#[invariant(EXPR)]`. Same shape as require/
// ensure; CONTRACT-003 message.
long long __nucleor_contract_invariant(long long cond) {
    if (cond == 0) {
        fprintf(stderr, "CONTRACT-003: invariant violated\n");
        fflush(stderr);
        exit(1);
    }
    return 0;
}


long long __nucleor_assert_eq(long long a, long long b) {
    if (a != b) {
        fprintf(stderr, "ASSERTION FAILED: %lld != %lld\n", a, b);
        fflush(stderr);
        exit(1);
    }
    return 0;
}

long long __nucleor_assert_ne(long long a, long long b) {
    if (a == b) {
        fprintf(stderr, "ASSERTION FAILED: %lld == %lld (expected !=)\n", a, b);
        fflush(stderr);
        exit(1);
    }
    return 0;
}

long long __nucleor_panic(const char *msg) {
    fprintf(stderr, "PANIC: %s\n", msg ? msg : "<no message>");
    fflush(stderr);
    exit(1);
}

// === RFC-0015 phase 2: `as` cast helpers ===
// Each truncates the value to the target width and (for signed types)
// sign-extends back to i64 storage. Internally everything is i64; these
// helpers preserve the semantic narrowness so user code observes the
// expected wraparound behavior.

long long __nucleor_as_i8(long long v) {
    long long t = v & 0xFFLL;
    if (t & 0x80LL) t |= 0xFFFFFFFFFFFFFF00LL;
    return t;
}

long long __nucleor_as_i16(long long v) {
    long long t = v & 0xFFFFLL;
    if (t & 0x8000LL) t |= 0xFFFFFFFFFFFF0000LL;
    return t;
}

long long __nucleor_as_i32(long long v) {
    long long t = v & 0xFFFFFFFFLL;
    if (t & 0x80000000LL) t |= 0xFFFFFFFF00000000LL;
    return t;
}

long long __nucleor_as_i64(long long v) {
    return v;
}

long long __nucleor_as_u8(long long v)  { return v & 0xFFLL; }
long long __nucleor_as_u16(long long v) { return v & 0xFFFFLL; }
long long __nucleor_as_u32(long long v) { return v & 0xFFFFFFFFLL; }
long long __nucleor_as_u64(long long v) { return v; }

/*
 * v0.4.105: block-form `wrapping { ... }` / `saturating { ... }` helpers.
 *
 * The compiler's kind==52 lowering wraps the block's final expression
 * value through one of these two helpers. Both take the i64 expression
 * result and reduce to an i32-range result returned as i64. The
 * compiler IR has carried the `declare` lines for both since pre-
 * v0.3.150 but the runtime impls were never landed -- the parse path
 * was removed before they were noticed.
 *
 * v0.4.105 restores parse_primary's `saturating { ... }` to call
 * parse_wrapped_block_expr(mode=2) instead of the v0.4.102 NR021 halt;
 * this requires sat_i32 to actually link.
 *
 * `wrap_i32` is mathematically equivalent to `as_i32` (low 32 bits
 * sign-extended); kept as a distinct symbol because the compiler
 * dispatch table maps `wrap_i32` to it. v0.4.102's wrapping {}
 * passthrough path doesn't go through this helper, but a future
 * mode-tagged wrapping {} ship would.
 */
long long __nucleor_sat_i32(long long v) {
    if (v > 2147483647LL) return 2147483647LL;
    if (v < -2147483648LL) return -2147483648LL;
    return v;
}

long long __nucleor_wrap_i32(long long v) {
    long long t = v & 0xFFFFFFFFLL;
    if (t & 0x80000000LL) t |= 0xFFFFFFFF00000000LL;
    return t;
}

// Float casts: f64 storage uses bit-cast i64. f32 storage stores the
// f32 bit-pattern in the low 32 bits with high bits zero.
long long __nucleor_as_f64(long long v) {
    // If v is already an f64-bitcast, no-op. If v is an integer, convert.
    // Heuristic: assume integer-to-float when input is in plausible int
    // range (NaN/Inf bit pattern is large). For exact semantics this would
    // need a type tag the IR doesn't currently carry — phase 3 will add
    // proper IR-level conversion ops.
    return v;
}

long long __nucleor_as_f32(long long v) {
    // T1.1 Phase 5 (2026-04-24): actually narrow f64→f32 so inline
    // arithmetic with f32 operands sees real f32 bit-patterns.
    // Prior no-op was a Phase 3 placeholder; Phase 5 requires correct
    // conversion because lower_expr dispatches f32 binops to
    // __nucleor_f32_<op> which decodes via bits_to_f32.
    union { long long i; double d; } ub;
    ub.i = v;
    float f = (float)ub.d;
    union { unsigned int u; float f; } uf;
    uf.f = f;
    return (long long)(unsigned long long)uf.u;
}

// === T1.1 Phase 3a: sizeof_<T>() builtins — byte-size of primitives ===
// Returns the observable byte size of each primitive type. Pairs with
// a matching surface-level dispatch in get_rt_name so user code can
// write `sizeof_u8()` etc. A future pass will layer a generic
// `sizeof::<T>()` syntax on top.

long long __nucleor_sizeof_i8(void)   { return 1; }
long long __nucleor_sizeof_i16(void)  { return 2; }
long long __nucleor_sizeof_i32(void)  { return 4; }
long long __nucleor_sizeof_i64(void)  { return 8; }
long long __nucleor_sizeof_i128(void) { return 16; }
long long __nucleor_sizeof_u8(void)   { return 1; }
long long __nucleor_sizeof_u16(void)  { return 2; }
long long __nucleor_sizeof_u32(void)  { return 4; }
long long __nucleor_sizeof_u64(void)  { return 8; }
long long __nucleor_sizeof_u128(void) { return 16; }
long long __nucleor_sizeof_usize(void){ return sizeof(void*); }
long long __nucleor_sizeof_isize(void){ return sizeof(void*); }
long long __nucleor_sizeof_f16(void)  { return 2; }
long long __nucleor_sizeof_bf16(void) { return 2; }
long long __nucleor_sizeof_f32(void)  { return 4; }
long long __nucleor_sizeof_f64(void)  { return 8; }
long long __nucleor_sizeof_bool(void) { return 1; }
long long __nucleor_sizeof_char(void) { return 4; }   // Unicode scalar = UTF-32
long long __nucleor_sizeof_ptr(void)  { return sizeof(void*); }

// === RFC-0015 phase 4: overflow-mode arithmetic (i64 width) ===
// wrapping_* — two's-complement wraparound (always defined behavior)
// checked_* — Option<T>; we encode as a packed i64 [is_some:32 | value:32]
//             For full precision: phase 5 ships proper Option<T> values.
//             For now: returns 0 if overflow, the result if not, with the
//             caller using a separate helper to check.
// saturating_* — clamp at i64::MAX or i64::MIN

#include <limits.h>

long long __nucleor_wrapping_add_i64(long long a, long long b) {
    return (long long)((unsigned long long)a + (unsigned long long)b);
}
long long __nucleor_wrapping_sub_i64(long long a, long long b) {
    return (long long)((unsigned long long)a - (unsigned long long)b);
}
long long __nucleor_wrapping_mul_i64(long long a, long long b) {
    return (long long)((unsigned long long)a * (unsigned long long)b);
}

long long __nucleor_saturating_add_i64(long long a, long long b) {
    if (b > 0 && a > LLONG_MAX - b) return LLONG_MAX;
    if (b < 0 && a < LLONG_MIN - b) return LLONG_MIN;
    return a + b;
}
long long __nucleor_saturating_sub_i64(long long a, long long b) {
    if (b < 0 && a > LLONG_MAX + b) return LLONG_MAX;
    if (b > 0 && a < LLONG_MIN + b) return LLONG_MIN;
    return a - b;
}
long long __nucleor_saturating_mul_i64(long long a, long long b) {
    if (a == 0 || b == 0) return 0;
    long long r = a * b;
    if (a != r / b) {
        // overflow occurred
        if ((a < 0) ^ (b < 0)) return LLONG_MIN;
        return LLONG_MAX;
    }
    return r;
}

// checked_* — returns 1 (success) into out via callback pattern.
// Real implementation depends on Option<T> support; for now use 64-bit
// flag values: returns the result, with a separate `last_overflow`
// global checked via __nucleor_checked_overflow_flag().
//
// v0.8.82 NUM-G8 Phase 1: per-thread storage. Pre-fix this was a
// shared static int that races between threads — concurrent
// checked_* calls would overwrite the flag between call and read.
// Now thread-local so each thread sees its own most-recent flag.
static NUCLEOR_TLS int __nucleor_overflow_flag = 0;

long long __nucleor_checked_add_i64(long long a, long long b) {
    __nucleor_overflow_flag = 0;
    if (b > 0 && a > LLONG_MAX - b) { __nucleor_overflow_flag = 1; return 0; }
    if (b < 0 && a < LLONG_MIN - b) { __nucleor_overflow_flag = 1; return 0; }
    return a + b;
}
long long __nucleor_checked_sub_i64(long long a, long long b) {
    __nucleor_overflow_flag = 0;
    if (b < 0 && a > LLONG_MAX + b) { __nucleor_overflow_flag = 1; return 0; }
    if (b > 0 && a < LLONG_MIN + b) { __nucleor_overflow_flag = 1; return 0; }
    return a - b;
}
long long __nucleor_checked_mul_i64(long long a, long long b) {
    __nucleor_overflow_flag = 0;
    if (a == 0 || b == 0) return 0;
    long long r = a * b;
    if (a != r / b) { __nucleor_overflow_flag = 1; return 0; }
    return r;
}
long long __nucleor_checked_overflow_flag(void) {
    return __nucleor_overflow_flag;
}

// v0.3.207: NUC-FEEDBACK runtime safety -- panic-on-overflow
// arithmetic. The existing checked_* surface returns 0 + sets a
// flag the caller has to check; that's awkward enough that
// adopters tend to skip it, so the silent-wrap hazard persists
// in user code even when they "tried to be careful". The
// panic_* surface here is fire-and-forget: result is always
// well-defined (returns a+b/a-b/a*b on success, panics on
// overflow), no flag check needed.
//
// Adopters who want the legacy wrap behavior can use the
// existing wrapping_* helpers; adopters who want clamp can use
// the saturating_* helpers. This is the ergonomic strict-mode
// surface.

long long __nucleor_panic_add_i64(long long a, long long b) {
    NUC_PROFILE_INC(g_p_panic_add);
    if (b > 0 && a > LLONG_MAX - b) {
        fprintf(stderr, "PANIC: i64 add overflow: %lld + %lld\n", a, b);
        fflush(stderr); exit(1);
    }
    if (b < 0 && a < LLONG_MIN - b) {
        fprintf(stderr, "PANIC: i64 add overflow: %lld + %lld\n", a, b);
        fflush(stderr); exit(1);
    }
    return a + b;
}
long long __nucleor_panic_sub_i64(long long a, long long b) {
    NUC_PROFILE_INC(g_p_panic_sub);
    if (b < 0 && a > LLONG_MAX + b) {
        fprintf(stderr, "PANIC: i64 sub overflow: %lld - %lld\n", a, b);
        fflush(stderr); exit(1);
    }
    if (b > 0 && a < LLONG_MIN + b) {
        fprintf(stderr, "PANIC: i64 sub overflow: %lld - %lld\n", a, b);
        fflush(stderr); exit(1);
    }
    return a - b;
}
long long __nucleor_panic_mul_i64(long long a, long long b) {
    NUC_PROFILE_INC(g_p_panic_mul);
    if (a == 0 || b == 0) return 0;
    long long r = a * b;
    if (a != r / b) {
        fprintf(stderr, "PANIC: i64 mul overflow: %lld * %lld\n", a, b);
        fflush(stderr); exit(1);
    }
    return r;
}
long long __nucleor_panic_add_u64(long long a, long long b) {
    unsigned long long ua = (unsigned long long)a;
    unsigned long long ub = (unsigned long long)b;
    unsigned long long r = ua + ub;
    if (r < ua) {
        fprintf(stderr, "PANIC: u64 add overflow: %llu + %llu\n", ua, ub);
        fflush(stderr); exit(1);
    }
    return (long long)r;
}
long long __nucleor_panic_sub_u64(long long a, long long b) {
    unsigned long long ua = (unsigned long long)a;
    unsigned long long ub = (unsigned long long)b;
    if (ub > ua) {
        fprintf(stderr, "PANIC: u64 sub overflow: %llu - %llu\n", ua, ub);
        fflush(stderr); exit(1);
    }
    return (long long)(ua - ub);
}
long long __nucleor_panic_mul_u64(long long a, long long b) {
    unsigned long long ua = (unsigned long long)a;
    unsigned long long ub = (unsigned long long)b;
    if (ua == 0 || ub == 0) return 0;
    unsigned long long r = ua * ub;
    if (r / ua != ub) {
        fprintf(stderr, "PANIC: u64 mul overflow: %llu * %llu\n", ua, ub);
        fflush(stderr); exit(1);
    }
    return (long long)r;
}
long long __nucleor_panic_div_i64(long long a, long long b) {
    if (b == 0) {
        fprintf(stderr, "PANIC: i64 division by zero: %lld / 0\n", a);
        fflush(stderr); exit(1);
    }
    if (a == LLONG_MIN && b == -1) {
        fprintf(stderr, "PANIC: i64 div overflow: i64::MIN / -1\n");
        fflush(stderr); exit(1);
    }
    return a / b;
}
long long __nucleor_panic_rem_i64(long long a, long long b) {
    if (b == 0) {
        fprintf(stderr, "PANIC: i64 mod by zero: %lld %% 0\n", a);
        fflush(stderr); exit(1);
    }
    if (a == LLONG_MIN && b == -1) return 0;
    return a % b;
}
long long __nucleor_panic_neg_i64(long long v) {
    if (v == LLONG_MIN) {
        fprintf(stderr, "PANIC: i64 neg overflow: -(i64::MIN)\n");
        fflush(stderr); exit(1);
    }
    return -v;
}

// v0.5.10: narrow-width div/rem panic helpers. Track E (v0.4.234-235)
// added overflow checks for i8/i16/i32 add/sub/mul, but division was
// missed — narrow signed div fell through to raw `sdiv iN` which on
// Windows surfaces `iN::MIN / -1` as STATUS_INTEGER_OVERFLOW
// (rc=-1073741675), an opaque process exit. Probe-agent finding
// 2026-05-01-i32-min-div-neg-one-windows-exception. These helpers
// take i64 args (sign-extended from iN per Nucleor's call-site ABI),
// truncate to native iN, do the zero + iN_MIN/-1 check, divide,
// return as i64 (caller truncates back to iN).
long long __nucleor_panic_div_i32(long long a64, long long b64) {
    int a = (int)a64;
    int b = (int)b64;
    if (b == 0) {
        fprintf(stderr, "PANIC: i32 division by zero: %d / 0\n", a);
        fflush(stderr); exit(1);
    }
    if (a == INT_MIN && b == -1) {
        fprintf(stderr, "PANIC: i32 div overflow: i32::MIN / -1\n");
        fflush(stderr); exit(1);
    }
    return (long long)(a / b);
}
long long __nucleor_panic_rem_i32(long long a64, long long b64) {
    int a = (int)a64;
    int b = (int)b64;
    if (b == 0) {
        fprintf(stderr, "PANIC: i32 mod by zero: %d %% 0\n", a);
        fflush(stderr); exit(1);
    }
    if (a == INT_MIN && b == -1) return 0;
    return (long long)(a % b);
}
long long __nucleor_panic_div_i16(long long a64, long long b64) {
    short a = (short)a64;
    short b = (short)b64;
    if (b == 0) {
        fprintf(stderr, "PANIC: i16 division by zero: %d / 0\n", (int)a);
        fflush(stderr); exit(1);
    }
    if (a == SHRT_MIN && b == -1) {
        fprintf(stderr, "PANIC: i16 div overflow: i16::MIN / -1\n");
        fflush(stderr); exit(1);
    }
    return (long long)(short)(a / b);
}
long long __nucleor_panic_rem_i16(long long a64, long long b64) {
    short a = (short)a64;
    short b = (short)b64;
    if (b == 0) {
        fprintf(stderr, "PANIC: i16 mod by zero: %d %% 0\n", (int)a);
        fflush(stderr); exit(1);
    }
    if (a == SHRT_MIN && b == -1) return 0;
    return (long long)(short)(a % b);
}
long long __nucleor_panic_div_i8(long long a64, long long b64) {
    signed char a = (signed char)a64;
    signed char b = (signed char)b64;
    if (b == 0) {
        fprintf(stderr, "PANIC: i8 division by zero: %d / 0\n", (int)a);
        fflush(stderr); exit(1);
    }
    if (a == SCHAR_MIN && b == -1) {
        fprintf(stderr, "PANIC: i8 div overflow: i8::MIN / -1\n");
        fflush(stderr); exit(1);
    }
    return (long long)(signed char)(a / b);
}
long long __nucleor_panic_rem_i8(long long a64, long long b64) {
    signed char a = (signed char)a64;
    signed char b = (signed char)b64;
    if (b == 0) {
        fprintf(stderr, "PANIC: i8 mod by zero: %d %% 0\n", (int)a);
        fflush(stderr); exit(1);
    }
    if (a == SCHAR_MIN && b == -1) return 0;
    return (long long)(signed char)(a % b);
}

// v0.3.214: shift-overflow panics. Pre-fix `<<` and `>>` for shift
// amount >= 64 or < 0 produced LLVM poison (observable but not
// silent miscompute). Strict-arith default now panics with
// operands; opt-out via NUCLEOR_INT_STRICT_ARITH=0.
long long __nucleor_panic_shl_i64(long long a, long long b) {
    if (b < 0 || b >= 64) {
        fprintf(stderr, "PANIC: i64 shl out-of-range: %lld << %lld (shift amount must be 0..63)\n", a, b);
        fflush(stderr); exit(1);
    }
    return (long long)((unsigned long long)a << (int)b);
}
long long __nucleor_panic_shr_i64(long long a, long long b) {
    if (b < 0 || b >= 64) {
        fprintf(stderr, "PANIC: i64 shr out-of-range: %lld >> %lld (shift amount must be 0..63)\n", a, b);
        fflush(stderr); exit(1);
    }
    return a >> (int)b;
}

// --- v0.2.28: division / remainder / negation variants ---
// checked_div_i64 / checked_rem_i64: 0 + overflow flag set on
//   (a) divide-by-zero, OR (b) i64::MIN / -1 (would overflow).
// wrapping_div_i64 / wrapping_rem_i64: silent — div-by-zero returns 0,
//   i64::MIN / -1 wraps to i64::MIN (the two's-complement result).
// checked_neg_i64: handles the i64::MIN edge case (no positive equivalent).
// wrapping_neg_i64: returns -v with two's-complement semantics
//   (so wrapping_neg(i64::MIN) == i64::MIN).
// saturating_neg_i64: clamps i64::MIN to i64::MAX.

long long __nucleor_checked_div_i64(long long a, long long b) {
    __nucleor_overflow_flag = 0;
    if (b == 0) { __nucleor_overflow_flag = 1; return 0; }
    if (a == LLONG_MIN && b == -1) { __nucleor_overflow_flag = 1; return 0; }
    return a / b;
}
long long __nucleor_checked_rem_i64(long long a, long long b) {
    __nucleor_overflow_flag = 0;
    if (b == 0) { __nucleor_overflow_flag = 1; return 0; }
    if (a == LLONG_MIN && b == -1) { __nucleor_overflow_flag = 1; return 0; }
    return a % b;
}
long long __nucleor_wrapping_div_i64(long long a, long long b) {
    if (b == 0) return 0;
    if (a == LLONG_MIN && b == -1) return LLONG_MIN;
    return a / b;
}
long long __nucleor_wrapping_rem_i64(long long a, long long b) {
    if (b == 0) return 0;
    if (a == LLONG_MIN && b == -1) return 0;
    return a % b;
}
long long __nucleor_checked_neg_i64(long long v) {
    __nucleor_overflow_flag = 0;
    if (v == LLONG_MIN) { __nucleor_overflow_flag = 1; return 0; }
    return -v;
}
long long __nucleor_wrapping_neg_i64(long long v) {
    return (long long)(0ULL - (unsigned long long)v);
}
long long __nucleor_saturating_neg_i64(long long v) {
    if (v == LLONG_MIN) return LLONG_MAX;
    return -v;
}

// === RFC-0015 phase 4: narrow-width overflow primitives ===
// Generated for i8 / i16 / i32 / u8 / u16 / u32 / u64. The signed
// variants treat the i64 storage as the underlying width's signed
// range; unsigned variants mask to the width.
//
// Each width gets:
//   __nucleor_wrapping_add_<W>     (always-defined modular wrap)
//   __nucleor_wrapping_sub_<W>
//   __nucleor_wrapping_mul_<W>
//   __nucleor_saturating_add_<W>   (clamp at MIN/MAX of <W>)
//   __nucleor_saturating_sub_<W>
//   __nucleor_saturating_mul_<W>
//   __nucleor_checked_add_<W>      (returns 0 + sets overflow flag on of)
//   __nucleor_checked_sub_<W>
//   __nucleor_checked_mul_<W>
//
// `__nucleor_checked_overflow_flag()` is shared with the i64 family.

#define NUC_SIGN_EXT(t, mask, sign_bit) \
    (((t) & (mask)) | (((t) & (sign_bit)) ? ~(mask) : 0))

#define NUC_DEFINE_SIGNED_OVERFLOW(W, MIN_V, MAX_V, MASK, SIGN_BIT)         \
long long __nucleor_wrapping_add_##W(long long a, long long b) {            \
    long long t = (long long)((unsigned long long)a + (unsigned long long)b); \
    return (long long)NUC_SIGN_EXT(t, (long long)MASK, (long long)SIGN_BIT); \
}                                                                            \
long long __nucleor_wrapping_sub_##W(long long a, long long b) {            \
    long long t = (long long)((unsigned long long)a - (unsigned long long)b); \
    return (long long)NUC_SIGN_EXT(t, (long long)MASK, (long long)SIGN_BIT); \
}                                                                            \
long long __nucleor_wrapping_mul_##W(long long a, long long b) {            \
    long long t = (long long)((unsigned long long)a * (unsigned long long)b); \
    return (long long)NUC_SIGN_EXT(t, (long long)MASK, (long long)SIGN_BIT); \
}                                                                            \
long long __nucleor_saturating_add_##W(long long a, long long b) {          \
    long long r = a + b;                                                    \
    if (r > (long long)MAX_V) return (long long)MAX_V;                      \
    if (r < (long long)MIN_V) return (long long)MIN_V;                      \
    return r;                                                               \
}                                                                            \
long long __nucleor_saturating_sub_##W(long long a, long long b) {          \
    long long r = a - b;                                                    \
    if (r > (long long)MAX_V) return (long long)MAX_V;                      \
    if (r < (long long)MIN_V) return (long long)MIN_V;                      \
    return r;                                                               \
}                                                                            \
long long __nucleor_saturating_mul_##W(long long a, long long b) {          \
    /* R09-D5 Phase 1 (v0.8.275) — clamp inputs to the type's range  \
       BEFORE multiplying. Otherwise a caller passing an out-of-range \
       long long could overflow even the i64 product (e.g. INT32_MAX  \
       * 4 fits in i64 but INT64_MAX * 2 does not), invalidating the  \
       post-multiply range checks. For W in {i8, i16, i32}, MAX_V * MAX_V \
       fits in i64 once both operands are pre-clamped. */            \
    if (a > (long long)MAX_V) a = (long long)MAX_V;                         \
    if (a < (long long)MIN_V) a = (long long)MIN_V;                         \
    if (b > (long long)MAX_V) b = (long long)MAX_V;                         \
    if (b < (long long)MIN_V) b = (long long)MIN_V;                         \
    long long r = a * b;                                                    \
    if (r > (long long)MAX_V) return (long long)MAX_V;                      \
    if (r < (long long)MIN_V) return (long long)MIN_V;                      \
    return r;                                                               \
}                                                                            \
long long __nucleor_checked_add_##W(long long a, long long b) {             \
    __nucleor_overflow_flag = 0;                                            \
    long long r = a + b;                                                    \
    if (r > (long long)MAX_V || r < (long long)MIN_V) {                     \
        __nucleor_overflow_flag = 1; return 0;                              \
    }                                                                        \
    return r;                                                               \
}                                                                            \
long long __nucleor_checked_sub_##W(long long a, long long b) {             \
    __nucleor_overflow_flag = 0;                                            \
    long long r = a - b;                                                    \
    if (r > (long long)MAX_V || r < (long long)MIN_V) {                     \
        __nucleor_overflow_flag = 1; return 0;                              \
    }                                                                        \
    return r;                                                               \
}                                                                            \
long long __nucleor_checked_mul_##W(long long a, long long b) {             \
    __nucleor_overflow_flag = 0;                                            \
    long long r = a * b;                                                    \
    if (r > (long long)MAX_V || r < (long long)MIN_V) {                     \
        __nucleor_overflow_flag = 1; return 0;                              \
    }                                                                        \
    return r;                                                               \
}

#define NUC_DEFINE_UNSIGNED_OVERFLOW(W, MAX_V, MASK)                        \
long long __nucleor_wrapping_add_##W(long long a, long long b) {            \
    return (long long)(((unsigned long long)a + (unsigned long long)b) & (unsigned long long)(MASK)); \
}                                                                            \
long long __nucleor_wrapping_sub_##W(long long a, long long b) {            \
    return (long long)(((unsigned long long)a - (unsigned long long)b) & (unsigned long long)(MASK)); \
}                                                                            \
long long __nucleor_wrapping_mul_##W(long long a, long long b) {            \
    return (long long)(((unsigned long long)a * (unsigned long long)b) & (unsigned long long)(MASK)); \
}                                                                            \
long long __nucleor_saturating_add_##W(long long a, long long b) {          \
    unsigned long long ua = (unsigned long long)a & (unsigned long long)(MASK); \
    unsigned long long ub = (unsigned long long)b & (unsigned long long)(MASK); \
    unsigned long long r = ua + ub;                                         \
    if (r > (unsigned long long)(MAX_V)) return (long long)(MAX_V);         \
    return (long long)r;                                                    \
}                                                                            \
long long __nucleor_saturating_sub_##W(long long a, long long b) {          \
    unsigned long long ua = (unsigned long long)a & (unsigned long long)(MASK); \
    unsigned long long ub = (unsigned long long)b & (unsigned long long)(MASK); \
    if (ub > ua) return 0;                                                  \
    return (long long)(ua - ub);                                            \
}                                                                            \
long long __nucleor_saturating_mul_##W(long long a, long long b) {          \
    unsigned long long ua = (unsigned long long)a & (unsigned long long)(MASK); \
    unsigned long long ub = (unsigned long long)b & (unsigned long long)(MASK); \
    if (ua == 0 || ub == 0) return 0;                                       \
    unsigned long long r = ua * ub;                                         \
    if (r / ua != ub || r > (unsigned long long)(MAX_V)) return (long long)(MAX_V); \
    return (long long)r;                                                    \
}                                                                            \
long long __nucleor_checked_add_##W(long long a, long long b) {             \
    __nucleor_overflow_flag = 0;                                            \
    unsigned long long ua = (unsigned long long)a & (unsigned long long)(MASK); \
    unsigned long long ub = (unsigned long long)b & (unsigned long long)(MASK); \
    unsigned long long r = ua + ub;                                         \
    if (r > (unsigned long long)(MAX_V)) { __nucleor_overflow_flag = 1; return 0; } \
    return (long long)r;                                                    \
}                                                                            \
long long __nucleor_checked_sub_##W(long long a, long long b) {             \
    __nucleor_overflow_flag = 0;                                            \
    unsigned long long ua = (unsigned long long)a & (unsigned long long)(MASK); \
    unsigned long long ub = (unsigned long long)b & (unsigned long long)(MASK); \
    if (ub > ua) { __nucleor_overflow_flag = 1; return 0; }                 \
    return (long long)(ua - ub);                                            \
}                                                                            \
long long __nucleor_checked_mul_##W(long long a, long long b) {             \
    __nucleor_overflow_flag = 0;                                            \
    unsigned long long ua = (unsigned long long)a & (unsigned long long)(MASK); \
    unsigned long long ub = (unsigned long long)b & (unsigned long long)(MASK); \
    if (ua == 0 || ub == 0) return 0;                                       \
    unsigned long long r = ua * ub;                                         \
    if (r / ua != ub || r > (unsigned long long)(MAX_V)) { __nucleor_overflow_flag = 1; return 0; } \
    return (long long)r;                                                    \
}

NUC_DEFINE_SIGNED_OVERFLOW(i8,  -128LL, 127LL,           0xFFLL,       0x80LL)
NUC_DEFINE_SIGNED_OVERFLOW(i16, -32768LL, 32767LL,       0xFFFFLL,     0x8000LL)
NUC_DEFINE_SIGNED_OVERFLOW(i32, -2147483648LL, 2147483647LL, 0xFFFFFFFFLL, 0x80000000LL)
NUC_DEFINE_UNSIGNED_OVERFLOW(u8,  255LL,        0xFFLL)
NUC_DEFINE_UNSIGNED_OVERFLOW(u16, 65535LL,      0xFFFFLL)
NUC_DEFINE_UNSIGNED_OVERFLOW(u32, 4294967295LL, 0xFFFFFFFFLL)
// u64 saturating mul checks against UINT64_MAX which can't fit in long long
// signed, so caller must accept u64 wraparound semantics for the cap. Use
// distinct unsigned check.
long long __nucleor_wrapping_add_u64(long long a, long long b) {
    return (long long)((unsigned long long)a + (unsigned long long)b);
}
long long __nucleor_wrapping_sub_u64(long long a, long long b) {
    return (long long)((unsigned long long)a - (unsigned long long)b);
}
long long __nucleor_wrapping_mul_u64(long long a, long long b) {
    return (long long)((unsigned long long)a * (unsigned long long)b);
}
long long __nucleor_saturating_add_u64(long long a, long long b) {
    unsigned long long ua = (unsigned long long)a, ub = (unsigned long long)b;
    unsigned long long r = ua + ub;
    if (r < ua) return (long long)~0ULL;  // wrap-detect
    return (long long)r;
}
long long __nucleor_saturating_sub_u64(long long a, long long b) {
    unsigned long long ua = (unsigned long long)a, ub = (unsigned long long)b;
    if (ub > ua) return 0;
    return (long long)(ua - ub);
}
long long __nucleor_saturating_mul_u64(long long a, long long b) {
    unsigned long long ua = (unsigned long long)a, ub = (unsigned long long)b;
    if (ua == 0 || ub == 0) return 0;
    unsigned long long r = ua * ub;
    if (r / ua != ub) return (long long)~0ULL;
    return (long long)r;
}
long long __nucleor_checked_add_u64(long long a, long long b) {
    __nucleor_overflow_flag = 0;
    unsigned long long ua = (unsigned long long)a, ub = (unsigned long long)b;
    unsigned long long r = ua + ub;
    if (r < ua) { __nucleor_overflow_flag = 1; return 0; }
    return (long long)r;
}
long long __nucleor_checked_sub_u64(long long a, long long b) {
    __nucleor_overflow_flag = 0;
    unsigned long long ua = (unsigned long long)a, ub = (unsigned long long)b;
    if (ub > ua) { __nucleor_overflow_flag = 1; return 0; }
    return (long long)(ua - ub);
}
long long __nucleor_checked_mul_u64(long long a, long long b) {
    __nucleor_overflow_flag = 0;
    unsigned long long ua = (unsigned long long)a, ub = (unsigned long long)b;
    if (ua == 0 || ub == 0) return 0;
    unsigned long long r = ua * ub;
    if (r / ua != ub) { __nucleor_overflow_flag = 1; return 0; }
    return (long long)r;
}


// === RFC-0015 phase 5: per-width print helpers ===
// Print the underlying value at the declared type's display width.
// Today storage is uniformly i64; these helpers ensure correct
// signed/unsigned formatting per RFC-0015 type semantics.
long long __nucleor_print_i8(long long v) {
    long long t = v & 0xFFLL;
    if (t & 0x80LL) t |= 0xFFFFFFFFFFFFFF00LL;
    printf("%lld\n", t);
    return 0;
}
long long __nucleor_print_i16(long long v) {
    long long t = v & 0xFFFFLL;
    if (t & 0x8000LL) t |= 0xFFFFFFFFFFFF0000LL;
    printf("%lld\n", t);
    return 0;
}
long long __nucleor_print_i32(long long v) {
    long long t = v & 0xFFFFFFFFLL;
    if (t & 0x80000000LL) t |= 0xFFFFFFFF00000000LL;
    printf("%lld\n", t);
    return 0;
}
long long __nucleor_print_u8(long long v)  { printf("%llu\n", (unsigned long long)(v & 0xFFLL)); return 0; }
long long __nucleor_print_u16(long long v) { printf("%llu\n", (unsigned long long)(v & 0xFFFFLL)); return 0; }
long long __nucleor_print_u32(long long v) { printf("%llu\n", (unsigned long long)(v & 0xFFFFFFFFLL)); return 0; }
long long __nucleor_print_u64(long long v) { printf("%llu\n", (unsigned long long)v); return 0; }

// Hex/binary print helpers
long long __nucleor_print_hex(long long v) { printf("%llx\n", (unsigned long long)v); return 0; }
long long __nucleor_print_bin(long long v) {
    char buf[65]; buf[64] = 0;
    int i;
    for (i = 0; i < 64; i++) {
        buf[63 - i] = ((v >> i) & 1) ? '1' : '0';
    }
    int start = 0;
    while (start < 63 && buf[start] == '0') start++;
    printf("%s\n", buf + start);
    return 0;
}

// === RFC-0015 phase 5b: typed-storage byte buffers ===
// `Vec<u8>` semantics: 1 byte per element instead of the 8-byte cells
// that NVec uses. This is the *honest* storage for byte buffers (camera
// frames, network packets, MCAP records, etc.). Users opt in via the
// vec_u8_* API. Generic-enum monomorphization in v0.4 RFC-0024 will
// auto-route Vec<u8> to this path.
typedef struct { unsigned char *data; long long len; long long cap; } NVecU8;

long long __nucleor_vec_u8_new(void) {
    NVecU8 *v = (NVecU8 *)malloc(sizeof(NVecU8));
    v->data = (unsigned char *)malloc(64);
    v->len = 0;
    v->cap = 64;
    return (long long)(intptr_t)v;
}
long long __nucleor_vec_u8_with_capacity(long long n) {
    NVecU8 *v = (NVecU8 *)malloc(sizeof(NVecU8));
    if (n < 1) n = 1;
    v->data = (unsigned char *)malloc((size_t)n);
    v->len = 0;
    v->cap = n;
    return (long long)(intptr_t)v;
}
long long __nucleor_vec_u8_push(long long h, long long x) {
    NVecU8 *v = (NVecU8 *)(intptr_t)h;
    if (!v) return 0;
    if (v->len >= v->cap) {
        v->cap = _grow_cap(v->cap, sizeof(unsigned char), "vec_u8 push");
        v->data = (unsigned char *)realloc(v->data, (size_t)v->cap);
    }
    v->data[v->len++] = (unsigned char)(x & 0xFFLL);
    return 0;
}
long long __nucleor_vec_u8_get(long long h, long long i) {
    NVecU8 *v = (NVecU8 *)(intptr_t)h;
    if (!v || i < 0 || i >= v->len) return 0;
    return (long long)v->data[i];
}
long long __nucleor_vec_u8_set(long long h, long long i, long long x) {
    NVecU8 *v = (NVecU8 *)(intptr_t)h;
    if (!v || i < 0 || i >= v->len) return 0;
    v->data[i] = (unsigned char)(x & 0xFFLL);
    return 0;
}
long long __nucleor_vec_u8_len(long long h) {
    NVecU8 *v = (NVecU8 *)(intptr_t)h;
    if (!v) return 0;
    return v->len;
}
long long __nucleor_vec_u8_capacity(long long h) {
    NVecU8 *v = (NVecU8 *)(intptr_t)h;
    if (!v) return 0;
    return v->cap;
}
long long __nucleor_vec_u8_clear(long long h) {
    NVecU8 *v = (NVecU8 *)(intptr_t)h;
    if (!v) return 0;
    v->len = 0;
    return 0;
}
long long __nucleor_vec_u8_free(long long h) {
    NVecU8 *v = (NVecU8 *)(intptr_t)h;
    if (!v) return 0;
    free(v->data);
    free(v);
    return 0;
}
// Bulk copy from C-style buffer — useful for IO.
long long __nucleor_vec_u8_extend_from_ptr(long long h, const unsigned char *src, long long n) {
    NVecU8 *v = (NVecU8 *)(intptr_t)h;
    if (!v || !src || n <= 0) return 0;
    while (v->len + n > v->cap) {
        v->cap = _grow_cap(v->cap, sizeof(unsigned char), "vec_u8 append");
        v->data = (unsigned char *)realloc(v->data, (size_t)v->cap);
    }
    memcpy(v->data + v->len, src, (size_t)n);
    v->len += n;
    return 0;
}

// === Vec<f32> typed storage ===
typedef struct { float *data; long long len; long long cap; } NVecF32;
long long __nucleor_vec_f32_new(void) {
    NVecF32 *v = (NVecF32 *)malloc(sizeof(NVecF32));
    v->data = (float *)malloc(64 * sizeof(float));
    v->len = 0;
    v->cap = 64;
    return (long long)(intptr_t)v;
}
long long __nucleor_vec_f32_with_capacity(long long n) {
    NVecF32 *v = (NVecF32 *)malloc(sizeof(NVecF32));
    if (n < 1) n = 1;
    v->data = (float *)malloc((size_t)n * sizeof(float));
    v->len = 0;
    v->cap = n;
    return (long long)(intptr_t)v;
}
// Push takes f32 bit-pattern in low 32 bits (caller responsible for conv).
long long __nucleor_vec_f32_push_bits(long long h, long long bits) {
    NVecF32 *v = (NVecF32 *)(intptr_t)h;
    if (!v) return 0;
    if (v->len >= v->cap) {
        v->cap = _grow_cap(v->cap, sizeof(float), "vec_f32 push");
        v->data = (float *)realloc(v->data, (size_t)v->cap * sizeof(float));
    }
    union { unsigned int u; float f; } cv;
    cv.u = (unsigned int)(bits & 0xFFFFFFFFLL);
    v->data[v->len++] = cv.f;
    return 0;
}
long long __nucleor_vec_f32_get_bits(long long h, long long i) {
    NVecF32 *v = (NVecF32 *)(intptr_t)h;
    if (!v || i < 0 || i >= v->len) return 0;
    union { unsigned int u; float f; } cv;
    cv.f = v->data[i];
    return (long long)cv.u;
}
long long __nucleor_vec_f32_len(long long h) {
    NVecF32 *v = (NVecF32 *)(intptr_t)h;
    if (!v) return 0;
    return v->len;
}
long long __nucleor_vec_f32_free(long long h) {
    NVecF32 *v = (NVecF32 *)(intptr_t)h;
    if (!v) return 0;
    free(v->data);
    free(v);
    return 0;
}

// === RFC-0015 phase 6: f32 distinct compute path ===
// f32 values are passed as i64 with the bit-pattern in low 32 bits.
// Helpers convert in/out and perform arithmetic at f32 precision.
static inline long long __nuc_f32_to_bits(float f) {
    union { unsigned int u; float f; } cv;
    cv.f = f;
    return (long long)cv.u;
}
static inline float __nuc_bits_to_f32(long long b) {
    union { unsigned int u; float f; } cv;
    cv.u = (unsigned int)(b & 0xFFFFFFFFLL);
    return cv.f;
}

long long __nucleor_f32_from_int(long long n) { return __nuc_f32_to_bits((float)n); }
long long __nucleor_f32_to_int(long long b) { return (long long)__nuc_bits_to_f32(b); }
long long __nucleor_f32_add(long long a, long long b) { return __nuc_f32_to_bits(__nuc_bits_to_f32(a) + __nuc_bits_to_f32(b)); }
long long __nucleor_f32_sub(long long a, long long b) { return __nuc_f32_to_bits(__nuc_bits_to_f32(a) - __nuc_bits_to_f32(b)); }
long long __nucleor_f32_mul(long long a, long long b) { return __nuc_f32_to_bits(__nuc_bits_to_f32(a) * __nuc_bits_to_f32(b)); }
long long __nucleor_f32_div(long long a, long long b) { return __nuc_f32_to_bits(__nuc_bits_to_f32(a) / __nuc_bits_to_f32(b)); }
long long __nucleor_f32_neg(long long a) { return __nuc_f32_to_bits(-__nuc_bits_to_f32(a)); }
long long __nucleor_f32_abs(long long a) { return __nuc_f32_to_bits(fabsf(__nuc_bits_to_f32(a))); }
long long __nucleor_f32_sqrt(long long a) { return __nuc_f32_to_bits(sqrtf(__nuc_bits_to_f32(a))); }
long long __nucleor_f32_exp(long long a) { return __nuc_f32_to_bits(expf(__nuc_bits_to_f32(a))); }
long long __nucleor_f32_log(long long a) { return __nuc_f32_to_bits(logf(__nuc_bits_to_f32(a))); }
long long __nucleor_f32_sin(long long a) { return __nuc_f32_to_bits(sinf(__nuc_bits_to_f32(a))); }
long long __nucleor_f32_cos(long long a) { return __nuc_f32_to_bits(cosf(__nuc_bits_to_f32(a))); }
long long __nucleor_f32_pow(long long a, long long b) { return __nuc_f32_to_bits(powf(__nuc_bits_to_f32(a), __nuc_bits_to_f32(b))); }
long long __nucleor_f32_lt(long long a, long long b) { return __nuc_bits_to_f32(a) < __nuc_bits_to_f32(b) ? 1 : 0; }
long long __nucleor_f32_gt(long long a, long long b) { return __nuc_bits_to_f32(a) > __nuc_bits_to_f32(b) ? 1 : 0; }
long long __nucleor_f32_eq(long long a, long long b) { return __nuc_bits_to_f32(a) == __nuc_bits_to_f32(b) ? 1 : 0; }
long long __nucleor_f32_ne(long long a, long long b) { return __nuc_bits_to_f32(a) != __nuc_bits_to_f32(b) ? 1 : 0; }
long long __nucleor_f32_le(long long a, long long b) { return __nuc_bits_to_f32(a) <= __nuc_bits_to_f32(b) ? 1 : 0; }
long long __nucleor_f32_ge(long long a, long long b) { return __nuc_bits_to_f32(a) >= __nuc_bits_to_f32(b) ? 1 : 0; }
long long __nucleor_f32_to_f64(long long a) {
    union { unsigned long long u; double d; } cd;
    cd.d = (double)__nuc_bits_to_f32(a);
    return (long long)cd.u;
}
// T1.1 Phase 4: full as-cast matrix — float↔int converters.
// Behavior matches Rust `as`: trunc-toward-zero for float→int,
// saturating at i32/i64 max/min if the float is out of range.
long long __nucleor_f32_to_i32(long long a) {
    float f = __nuc_bits_to_f32(a);
    if (f != f) return 0;  /* NaN -> 0 (Rust as semantic) */
    if (f > 2147483647.0f)  return 2147483647LL;
    if (f < -2147483648.0f) return -2147483648LL;
    return (long long)(int)f;
}
long long __nucleor_f32_to_i64(long long a) {
    float f = __nuc_bits_to_f32(a);
    if (f != f) return 0;  /* NaN -> 0 */
    if (f >  9223372036854775000.0f) return 9223372036854775807LL;
    if (f < -9223372036854775000.0f) return -9223372036854775807LL - 1LL;
    return (long long)f;
}
long long __nucleor_f32_to_u32(long long a) {
    float f = __nuc_bits_to_f32(a);
    if (f != f) return 0;  /* NaN -> 0 */
    if (f < 0.0f) return 0;
    if (f > 4294967295.0f) return 4294967295LL;
    return (long long)(unsigned int)f;
}
long long __nucleor_i32_to_f32(long long i) {
    return __nuc_f32_to_bits((float)(int)i);
}
long long __nucleor_i64_to_f32(long long i) {
    return __nuc_f32_to_bits((float)i);
}
long long __nucleor_f64_to_f32(long long a) {
    union { unsigned long long u; double d; } cd;
    cd.u = (unsigned long long)a;
    return __nuc_f32_to_bits((float)cd.d);
}
long long __nucleor_print_f32(long long a) {
    printf("%g\n", (double)__nuc_bits_to_f32(a));
    return 0;
}

// === Debug helpers ===
// dbg!(expr) — eprint "[debug] expr = value", returns the value untouched.
// Compiler maps `dbg(v)` to __nucleor_dbg_i64.
long long __nucleor_dbg_i64(long long v) {
    fprintf(stderr, "[debug] %lld\n", v);
    fflush(stderr);
    return v;
}
long long __nucleor_dbg_f64(long long bits) {
    union { unsigned long long u; double d; } cd;
    cd.u = (unsigned long long)bits;
    fprintf(stderr, "[debug f64] %g\n", cd.d);
    fflush(stderr);
    return bits;
}
long long __nucleor_dbg_str(const char *s) {
    fprintf(stderr, "[debug] \"%s\"\n", s ? s : "(null)");
    fflush(stderr);
    return 0;
}
long long __nucleor_eprint_str(const char *s) {
    if (s) fprintf(stderr, "%s\n", s); else fprintf(stderr, "(null)\n");
    fflush(stderr);
    return 0;
}
long long __nucleor_eprint_int(long long v) {
    fprintf(stderr, "%lld\n", v);
    fflush(stderr);
    return 0;
}

// === RFC-0033 (preview): SIMD vector types ===
// Software-emulated for now. Hardware-native via LLVM intrinsics in
// v0.4+ when the IR supports vector ops natively.
//
// Storage: heap-allocated vector handle, accessed via i64 (intptr).
// f32x4 = packed 4 × f32; f32x8 = 8 × f32 (AVX/AVX2 path); etc.

typedef struct { float lanes[4]; } NF32x4;
typedef struct { float lanes[8]; } NF32x8;
typedef struct { int   lanes[4]; } NI32x4;
typedef struct { int   lanes[8]; } NI32x8;

long long __nucleor_f32x4_new(long long a, long long b, long long c, long long d) {
    NF32x4 *v = (NF32x4 *)malloc(sizeof(NF32x4));
    v->lanes[0] = __nuc_bits_to_f32(a);
    v->lanes[1] = __nuc_bits_to_f32(b);
    v->lanes[2] = __nuc_bits_to_f32(c);
    v->lanes[3] = __nuc_bits_to_f32(d);
    return (long long)(intptr_t)v;
}
long long __nucleor_f32x4_splat(long long bits) {
    NF32x4 *v = (NF32x4 *)malloc(sizeof(NF32x4));
    float f = __nuc_bits_to_f32(bits);
    v->lanes[0] = v->lanes[1] = v->lanes[2] = v->lanes[3] = f;
    return (long long)(intptr_t)v;
}
long long __nucleor_f32x4_get(long long h, long long lane) {
    NF32x4 *v = (NF32x4 *)(intptr_t)h;
    if (!v || lane < 0 || lane >= 4) return 0;
    return __nuc_f32_to_bits(v->lanes[lane]);
}
long long __nucleor_f32x4_add(long long ah, long long bh) {
    NF32x4 *a = (NF32x4 *)(intptr_t)ah;
    NF32x4 *b = (NF32x4 *)(intptr_t)bh;
    NF32x4 *r = (NF32x4 *)malloc(sizeof(NF32x4));
    int i;
    for (i = 0; i < 4; i++) r->lanes[i] = a->lanes[i] + b->lanes[i];
    return (long long)(intptr_t)r;
}
long long __nucleor_f32x4_sub(long long ah, long long bh) {
    NF32x4 *a = (NF32x4 *)(intptr_t)ah;
    NF32x4 *b = (NF32x4 *)(intptr_t)bh;
    NF32x4 *r = (NF32x4 *)malloc(sizeof(NF32x4));
    int i;
    for (i = 0; i < 4; i++) r->lanes[i] = a->lanes[i] - b->lanes[i];
    return (long long)(intptr_t)r;
}
long long __nucleor_f32x4_mul(long long ah, long long bh) {
    NF32x4 *a = (NF32x4 *)(intptr_t)ah;
    NF32x4 *b = (NF32x4 *)(intptr_t)bh;
    NF32x4 *r = (NF32x4 *)malloc(sizeof(NF32x4));
    int i;
    for (i = 0; i < 4; i++) r->lanes[i] = a->lanes[i] * b->lanes[i];
    return (long long)(intptr_t)r;
}
long long __nucleor_f32x4_div(long long ah, long long bh) {
    NF32x4 *a = (NF32x4 *)(intptr_t)ah;
    NF32x4 *b = (NF32x4 *)(intptr_t)bh;
    NF32x4 *r = (NF32x4 *)malloc(sizeof(NF32x4));
    int i;
    for (i = 0; i < 4; i++) r->lanes[i] = a->lanes[i] / b->lanes[i];
    return (long long)(intptr_t)r;
}
long long __nucleor_f32x4_dot(long long ah, long long bh) {
    NF32x4 *a = (NF32x4 *)(intptr_t)ah;
    NF32x4 *b = (NF32x4 *)(intptr_t)bh;
    float s = 0.0f;
    int i;
    for (i = 0; i < 4; i++) s += a->lanes[i] * b->lanes[i];
    return __nuc_f32_to_bits(s);
}
long long __nucleor_f32x4_sum(long long h) {
    NF32x4 *v = (NF32x4 *)(intptr_t)h;
    if (!v) return __nuc_f32_to_bits(0.0f);
    return __nuc_f32_to_bits(v->lanes[0] + v->lanes[1] + v->lanes[2] + v->lanes[3]);
}
long long __nucleor_f32x4_max(long long h) {
    NF32x4 *v = (NF32x4 *)(intptr_t)h;
    if (!v) return __nuc_f32_to_bits(0.0f);
    float m = v->lanes[0];
    int i;
    for (i = 1; i < 4; i++) if (v->lanes[i] > m) m = v->lanes[i];
    return __nuc_f32_to_bits(m);
}
long long __nucleor_f32x4_min(long long h) {
    NF32x4 *v = (NF32x4 *)(intptr_t)h;
    if (!v) return __nuc_f32_to_bits(0.0f);
    float m = v->lanes[0];
    int i;
    for (i = 1; i < 4; i++) if (v->lanes[i] < m) m = v->lanes[i];
    return __nuc_f32_to_bits(m);
}
long long __nucleor_f32x4_free(long long h) {
    NF32x4 *v = (NF32x4 *)(intptr_t)h;
    if (v) free(v);
    return 0;
}

// i32x4 — packed 4 × i32
long long __nucleor_i32x4_new(long long a, long long b, long long c, long long d) {
    NI32x4 *v = (NI32x4 *)malloc(sizeof(NI32x4));
    v->lanes[0] = (int)(a & 0xFFFFFFFFLL);
    v->lanes[1] = (int)(b & 0xFFFFFFFFLL);
    v->lanes[2] = (int)(c & 0xFFFFFFFFLL);
    v->lanes[3] = (int)(d & 0xFFFFFFFFLL);
    return (long long)(intptr_t)v;
}
long long __nucleor_i32x4_splat(long long val) {
    NI32x4 *v = (NI32x4 *)malloc(sizeof(NI32x4));
    int x = (int)(val & 0xFFFFFFFFLL);
    v->lanes[0] = v->lanes[1] = v->lanes[2] = v->lanes[3] = x;
    return (long long)(intptr_t)v;
}
long long __nucleor_i32x4_get(long long h, long long lane) {
    NI32x4 *v = (NI32x4 *)(intptr_t)h;
    if (!v || lane < 0 || lane >= 4) return 0;
    return (long long)v->lanes[lane];
}
long long __nucleor_i32x4_add(long long ah, long long bh) {
    NI32x4 *a = (NI32x4 *)(intptr_t)ah;
    NI32x4 *b = (NI32x4 *)(intptr_t)bh;
    NI32x4 *r = (NI32x4 *)malloc(sizeof(NI32x4));
    int i;
    for (i = 0; i < 4; i++) r->lanes[i] = a->lanes[i] + b->lanes[i];
    return (long long)(intptr_t)r;
}
long long __nucleor_i32x4_sub(long long ah, long long bh) {
    NI32x4 *a = (NI32x4 *)(intptr_t)ah;
    NI32x4 *b = (NI32x4 *)(intptr_t)bh;
    NI32x4 *r = (NI32x4 *)malloc(sizeof(NI32x4));
    int i;
    for (i = 0; i < 4; i++) r->lanes[i] = a->lanes[i] - b->lanes[i];
    return (long long)(intptr_t)r;
}
long long __nucleor_i32x4_mul(long long ah, long long bh) {
    NI32x4 *a = (NI32x4 *)(intptr_t)ah;
    NI32x4 *b = (NI32x4 *)(intptr_t)bh;
    NI32x4 *r = (NI32x4 *)malloc(sizeof(NI32x4));
    int i;
    for (i = 0; i < 4; i++) r->lanes[i] = a->lanes[i] * b->lanes[i];
    return (long long)(intptr_t)r;
}
long long __nucleor_i32x4_sum(long long h) {
    NI32x4 *v = (NI32x4 *)(intptr_t)h;
    if (!v) return 0;
    return (long long)(v->lanes[0] + v->lanes[1] + v->lanes[2] + v->lanes[3]);
}
long long __nucleor_i32x4_free(long long h) {
    NI32x4 *v = (NI32x4 *)(intptr_t)h;
    if (v) free(v);
    return 0;
}

// === RFC-0017 partial: heap-allocated String type ===
// Length-tracked, growable, UTF-8 bytes. Distinct from str (borrowed
// view). Generic-enum monomorphization in v0.4 RFC-0024 will let
// String<A: Allocator> swap allocators.
typedef struct { char *data; long long len; long long cap; } NString;

long long __nucleor_string_new(void) {
    NString *s = (NString *)malloc(sizeof(NString));
    s->data = (char *)malloc(16);
    s->data[0] = 0;
    s->len = 0;
    s->cap = 16;
    return (long long)(intptr_t)s;
}
long long __nucleor_string_with_capacity(long long n) {
    NString *s = (NString *)malloc(sizeof(NString));
    if (n < 1) n = 1;
    s->data = (char *)malloc((size_t)n + 1);
    s->data[0] = 0;
    s->len = 0;
    s->cap = n;
    return (long long)(intptr_t)s;
}
long long __nucleor_string_from_str(const char *src) {
    NString *s = (NString *)malloc(sizeof(NString));
    long long n = src ? (long long)strlen(src) : 0;
    long long cap = n + 1;
    if (cap < 16) cap = 16;
    s->data = (char *)malloc((size_t)cap);
    if (n > 0) memcpy(s->data, src, (size_t)n);
    s->data[n] = 0;
    s->len = n;
    s->cap = cap - 1;
    return (long long)(intptr_t)s;
}
long long __nucleor_string_push_byte(long long h, long long b) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return 0;
    if (s->len + 1 > s->cap) {
        s->cap = _grow_cap(s->cap, sizeof(char), "string push_byte");
        s->data = (char *)realloc(s->data, (size_t)s->cap + 1);
    }
    s->data[s->len++] = (char)(b & 0xFFLL);
    s->data[s->len] = 0;
    return 0;
}
long long __nucleor_string_push_str(long long h, const char *src) {
    NString *s = (NString *)(intptr_t)h;
    if (!s || !src) return 0;
    long long n = (long long)strlen(src);
    while (s->len + n > s->cap) {
        s->cap = _grow_cap(s->cap, sizeof(char), "string append_str");
        s->data = (char *)realloc(s->data, (size_t)s->cap + 1);
    }
    memcpy(s->data + s->len, src, (size_t)n);
    s->len += n;
    s->data[s->len] = 0;
    return 0;
}
long long __nucleor_string_len(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return 0;
    return s->len;
}
long long __nucleor_string_capacity(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return 0;
    return s->cap;
}
long long __nucleor_string_get_byte(long long h, long long i) {
    NString *s = (NString *)(intptr_t)h;
    if (!s || i < 0 || i >= s->len) return 0;
    return (long long)(unsigned char)s->data[i];
}
long long __nucleor_string_clear(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return 0;
    s->len = 0;
    s->data[0] = 0;
    return 0;
}
// Returns a borrowed C string pointer. Caller must not free.
long long __nucleor_string_as_ptr(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return 0;
    return (long long)(intptr_t)s->data;
}
long long __nucleor_string_print(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) { printf("(null)\n"); return 0; }
    printf("%s\n", s->data);
    fflush(stdout);
    return 0;
}
long long __nucleor_string_eq(long long ah, long long bh) {
    NString *a = (NString *)(intptr_t)ah;
    NString *b = (NString *)(intptr_t)bh;
    if (!a || !b) return 0;
    if (a->len != b->len) return 0;
    return memcmp(a->data, b->data, (size_t)a->len) == 0 ? 1 : 0;
}
long long __nucleor_string_eq_str(long long ah, const char *cs) {
    NString *a = (NString *)(intptr_t)ah;
    if (!a || !cs) return 0;
    long long cn = (long long)strlen(cs);
    if (a->len != cn) return 0;
    return memcmp(a->data, cs, (size_t)cn) == 0 ? 1 : 0;
}
long long __nucleor_string_starts_with(long long ah, const char *prefix) {
    NString *a = (NString *)(intptr_t)ah;
    if (!a || !prefix) return 0;
    long long pn = (long long)strlen(prefix);
    if (pn > a->len) return 0;
    return memcmp(a->data, prefix, (size_t)pn) == 0 ? 1 : 0;
}
long long __nucleor_string_ends_with(long long ah, const char *suffix) {
    NString *a = (NString *)(intptr_t)ah;
    if (!a || !suffix) return 0;
    long long sn = (long long)strlen(suffix);
    if (sn > a->len) return 0;
    return memcmp(a->data + a->len - sn, suffix, (size_t)sn) == 0 ? 1 : 0;
}
long long __nucleor_string_contains(long long ah, const char *needle) {
    NString *a = (NString *)(intptr_t)ah;
    if (!a || !needle) return 0;
    return strstr(a->data, needle) != NULL ? 1 : 0;
}
long long __nucleor_string_clone(long long ah) {
    NString *a = (NString *)(intptr_t)ah;
    if (!a) return __nucleor_string_new();
    return __nucleor_string_from_str(a->data);
}
long long __nucleor_string_free(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return 0;
    free(s->data);
    free(s);
    return 0;
}

/* v0.4.124: extend String surface with common Rust String methods.
 * All return new String handles where they produce derived strings,
 * matching Rust's borrow-clean immutable-reference convention.
 * to_uppercase / to_lowercase are ASCII-only (Nucleor's i64 ABI
 * doesn't yet route through Unicode case-fold tables).
 */
long long __nucleor_string_is_empty(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return 1;
    return s->len == 0 ? 1 : 0;
}
long long __nucleor_string_to_uppercase(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return __nucleor_string_new();
    long long out_h = __nucleor_string_with_capacity(s->len);
    NString *out = (NString *)(intptr_t)out_h;
    for (long long i = 0; i < s->len; i++) {
        unsigned char c = (unsigned char)s->data[i];
        if (c >= 'a' && c <= 'z') c = (unsigned char)(c - 32);
        out->data[i] = (char)c;
    }
    out->len = s->len;
    out->data[s->len] = 0;
    return out_h;
}
long long __nucleor_string_to_lowercase(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return __nucleor_string_new();
    long long out_h = __nucleor_string_with_capacity(s->len);
    NString *out = (NString *)(intptr_t)out_h;
    for (long long i = 0; i < s->len; i++) {
        unsigned char c = (unsigned char)s->data[i];
        if (c >= 'A' && c <= 'Z') c = (unsigned char)(c + 32);
        out->data[i] = (char)c;
    }
    out->len = s->len;
    out->data[s->len] = 0;
    return out_h;
}
long long __nucleor_string_trim(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return __nucleor_string_new();
    long long lo = 0, hi = s->len;
    while (lo < hi && (unsigned char)s->data[lo] <= ' ') lo++;
    while (hi > lo && (unsigned char)s->data[hi - 1] <= ' ') hi--;
    long long n = hi - lo;
    long long out_h = __nucleor_string_with_capacity(n);
    NString *out = (NString *)(intptr_t)out_h;
    if (n > 0) memcpy(out->data, s->data + lo, (size_t)n);
    out->len = n;
    out->data[n] = 0;
    return out_h;
}
long long __nucleor_string_trim_start(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return __nucleor_string_new();
    long long lo = 0;
    while (lo < s->len && (unsigned char)s->data[lo] <= ' ') lo++;
    long long n = s->len - lo;
    long long out_h = __nucleor_string_with_capacity(n);
    NString *out = (NString *)(intptr_t)out_h;
    if (n > 0) memcpy(out->data, s->data + lo, (size_t)n);
    out->len = n;
    out->data[n] = 0;
    return out_h;
}
long long __nucleor_string_trim_end(long long h) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return __nucleor_string_new();
    long long hi = s->len;
    while (hi > 0 && (unsigned char)s->data[hi - 1] <= ' ') hi--;
    long long out_h = __nucleor_string_with_capacity(hi);
    NString *out = (NString *)(intptr_t)out_h;
    if (hi > 0) memcpy(out->data, s->data, (size_t)hi);
    out->len = hi;
    out->data[hi] = 0;
    return out_h;
}
long long __nucleor_string_find(long long h, const char *needle) {
    NString *s = (NString *)(intptr_t)h;
    if (!s || !needle) return -1;
    const char *hit = strstr(s->data, needle);
    if (!hit) return -1;
    return (long long)(hit - s->data);
}
long long __nucleor_string_substring(long long h, long long lo, long long hi) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return __nucleor_string_new();
    if (lo < 0) lo = 0;
    if (hi > s->len) hi = s->len;
    if (hi < lo) hi = lo;
    long long n = hi - lo;
    long long out_h = __nucleor_string_with_capacity(n);
    NString *out = (NString *)(intptr_t)out_h;
    if (n > 0) memcpy(out->data, s->data + lo, (size_t)n);
    out->len = n;
    out->data[n] = 0;
    return out_h;
}
long long __nucleor_string_char_at(long long h, long long i) {
    NString *s = (NString *)(intptr_t)h;
    if (!s) return 0;
    if (i < 0 || i >= s->len) return 0;
    return (long long)(unsigned char)s->data[i];
}
long long __nucleor_string_as_str(long long h) {
    /* Reuses existing as_ptr — the i64-everywhere ABI's `str` is a
     * raw `*const char` cell-equivalent. Distinct method name keeps
     * source-side semantics close to Rust's `String::as_str`. */
    return __nucleor_string_as_ptr(h);
}

// === RFC-0017 partial: HashMap<str, i64> ===
// Open-addressed hash table with linear probing. Keys are owned
// C-strings; values are i64 cells. Generic <K, V, A: Allocator>
// arrives with v0.4 monomorphization (RFC-0024).

typedef struct {
    char *key;
    long long val;
    int occupied;
} NHMSlot;

typedef struct {
    NHMSlot *slots;
    long long len;
    long long cap;
} NHashMap;

static unsigned long long __nuc_str_hash(const char *s) {
    // FNV-1a 64
    unsigned long long h = 0xcbf29ce484222325ULL;
    while (*s) {
        h ^= (unsigned char)*s++;
        h *= 0x100000001b3ULL;
    }
    return h;
}

static void __nuc_hashmap_grow(NHashMap *m) {
    long long old_cap = m->cap;
    NHMSlot *old_slots = m->slots;
    /* v0.3.229: cap doubling overflow guard. Past 2^30, refusing to
       grow further is more honest than silently overflowing. */
    if (m->cap >= (1LL << 30)) {
        fprintf(stderr, "PANIC: hashmap grow exceeded max cap 2^30 (cap was %lld)\n", m->cap);
        fflush(stderr); exit(1);
    }
    m->cap *= 2;
    m->slots = (NHMSlot *)calloc((size_t)m->cap, sizeof(NHMSlot));
    m->len = 0;
    long long i;
    for (i = 0; i < old_cap; i++) {
        if (old_slots[i].occupied) {
            // Reinsert
            unsigned long long h = __nuc_str_hash(old_slots[i].key);
            long long idx = (long long)(h & (unsigned long long)(m->cap - 1));
            while (m->slots[idx].occupied) {
                idx = (idx + 1) & (m->cap - 1);
            }
            m->slots[idx].key = old_slots[i].key;
            m->slots[idx].val = old_slots[i].val;
            m->slots[idx].occupied = 1;
            m->len++;
        }
    }
    free(old_slots);
}

long long __nucleor_hashmap_new(void) {
    NHashMap *m = (NHashMap *)malloc(sizeof(NHashMap));
    m->cap = 16;
    m->slots = (NHMSlot *)calloc(16, sizeof(NHMSlot));
    m->len = 0;
    return (long long)(intptr_t)m;
}
// v0.3.229: hashmap_with_capacity(n) safety. Pre-fix:
// - `n * 2` could overflow long long on hostile n -> negative ->
//   loop exits at cap=16 -> silent under-allocation.
// - `cap *= 2` could overflow if user requests huge capacity.
// - n < 0 wasn't validated.
long long __nucleor_hashmap_with_capacity(long long n) {
    if (n < 0) {
        fprintf(stderr, "PANIC: hashmap_with_capacity: negative capacity %lld\n", n);
        fflush(stderr); exit(1);
    }
    /* Cap at 2^30 buckets (=128 GB hashmap header). Beyond that the
       intended workload doesn't fit in any reasonable machine. */
    const long long MAX_CAP = 1LL << 30;
    if (n > MAX_CAP) {
        fprintf(stderr, "PANIC: hashmap_with_capacity: requested %lld exceeds max %lld\n", n, MAX_CAP);
        fflush(stderr); exit(1);
    }
    NHashMap *m = (NHashMap *)malloc(sizeof(NHashMap));
    long long cap = 16;
    /* Compare cap < n*2 in safe form: cap/2 < n */
    while (cap / 2 < n && cap < MAX_CAP) cap *= 2;
    m->cap = cap;
    m->slots = (NHMSlot *)calloc((size_t)cap, sizeof(NHMSlot));
    m->len = 0;
    return (long long)(intptr_t)m;
}
long long __nucleor_hashmap_insert(long long h, const char *key, long long val) {
    NUC_PROFILE_INC(g_p_hashmap_insert);
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m || !key) return 0;
    if ((m->len + 1) * 2 > m->cap) __nuc_hashmap_grow(m);
    unsigned long long hash = __nuc_str_hash(key);
    long long idx = (long long)(hash & (unsigned long long)(m->cap - 1));
    while (m->slots[idx].occupied) {
        if (strcmp(m->slots[idx].key, key) == 0) {
            // Update existing
            m->slots[idx].val = val;
            return 0;
        }
        idx = (idx + 1) & (m->cap - 1);
    }
    size_t klen = strlen(key);
    m->slots[idx].key = (char *)malloc(klen + 1);
    memcpy(m->slots[idx].key, key, klen + 1);
    m->slots[idx].val = val;
    m->slots[idx].occupied = 1;
    m->len++;
    return 0;
}
// v0.3.202: NUC-FEEDBACK runtime safety -- HashMap missing-key
// access now PANICs by default. Silent-zero on missing key was
// indistinguishable from a legitimate stored 0 -- adopters had no
// way to tell "key absent" from "key present with value 0" via
// the get() return. The launch bar (no silent miscomputes)
// requires PANIC. Adopters who genuinely need the legacy behavior
// can opt back in with `NUCLEOR_VEC_OOB_LENIENT=1` (same env var
// covers vec OOB, hashmap missing, btreemap missing -- the
// "lenient" mode is "don't panic on lookup-shaped errors").
// Null-handle / null-key still return 0 silently (defensive).
// Code that uses the contains-then-get pattern or the
// hashmap_get_or(h, k, default) helper never reaches the panic.
long long __nucleor_hashmap_get(long long h, const char *key) {
    NUC_PROFILE_INC(g_p_hashmap_get);
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m || !key) return 0;
    unsigned long long hash = __nuc_str_hash(key);
    long long idx = (long long)(hash & (unsigned long long)(m->cap - 1));
    long long start = idx;
    while (m->slots[idx].occupied) {
        if (strcmp(m->slots[idx].key, key) == 0) {
            return m->slots[idx].val;
        }
        idx = (idx + 1) & (m->cap - 1);
        if (idx == start) break;
    }
    if (_vec_oob_lenient()) return 0;
    fprintf(stderr, "PANIC: hashmap_get missing key '%s' (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n", key);
    fflush(stderr);
    exit(1);
}
long long __nucleor_hashmap_contains(long long h, const char *key) {
    NUC_PROFILE_INC(g_p_hashmap_contains);
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m || !key) return 0;
    unsigned long long hash = __nuc_str_hash(key);
    long long idx = (long long)(hash & (unsigned long long)(m->cap - 1));
    long long start = idx;
    while (m->slots[idx].occupied) {
        if (strcmp(m->slots[idx].key, key) == 0) return 1;
        idx = (idx + 1) & (m->cap - 1);
        if (idx == start) break;
    }
    return 0;
}
// v0.3.189: Rust-canonical name alias. h.contains_key(k) is the
// idiomatic call shape; pre-fix it lowered to hashmap_contains_key
// which did not exist (link error). Mirror to hashmap_contains.
long long __nucleor_hashmap_contains_key(long long h, const char *key) {
    return __nucleor_hashmap_contains(h, key);
}
long long __nucleor_hashmap_remove(long long h, const char *key) {
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m || !key) return 0;
    unsigned long long hash = __nuc_str_hash(key);
    long long idx = (long long)(hash & (unsigned long long)(m->cap - 1));
    long long start = idx;
    while (m->slots[idx].occupied) {
        if (strcmp(m->slots[idx].key, key) == 0) {
            free(m->slots[idx].key);
            m->slots[idx].occupied = 0;
            m->slots[idx].key = NULL;
            m->len--;
            // Re-hash following cluster
            long long next = (idx + 1) & (m->cap - 1);
            while (m->slots[next].occupied) {
                NHMSlot tmp = m->slots[next];
                m->slots[next].occupied = 0;
                m->slots[next].key = NULL;
                m->len--;
                __nucleor_hashmap_insert(h, tmp.key, tmp.val);
                free(tmp.key);
                next = (next + 1) & (m->cap - 1);
            }
            return 1;
        }
        idx = (idx + 1) & (m->cap - 1);
        if (idx == start) break;
    }
    return 0;
}
long long __nucleor_hashmap_len(long long h) {
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m) return 0;
    return m->len;
}
long long __nucleor_hashmap_capacity(long long h) {
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m) return 0;
    return m->cap;
}
long long __nucleor_hashmap_clear(long long h) {
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m) return 0;
    long long i;
    for (i = 0; i < m->cap; i++) {
        if (m->slots[i].occupied) {
            free(m->slots[i].key);
            m->slots[i].occupied = 0;
            m->slots[i].key = NULL;
        }
    }
    m->len = 0;
    return 0;
}
// v0.8.69 RFC-0062 G-4 Phase 2b — sentinel guard for hashmap_free.
// Sister of vec_free. When NUC_VEC_FREE_GUARD=1, panics on
// double-free with diagnostic. Default OFF: same pre-v0.8.69
// semantics. Sentinel: cap = 0xDEADBEEF when freed.
long long __nucleor_hashmap_free(long long h) {
    if (h == 0) return 0;
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m) return 0;
    if (_nuc_vec_free_guard_enabled()) {
        if (m->cap == NUC_VEC_FREED_SENTINEL_CAP) {
            fprintf(stderr,
                "PANIC-DOUBLE-FREE[OWN-012]: hashmap_free called twice on the same handle (0x%llx).\n"
                "  Sister of vec_free guard. Per RFC-0062 G-4 Phase 2b sentinel-based runtime guard.\n",
                (unsigned long long)h);
            fflush(stderr);
            exit(134);
        }
        long long i;
        for (i = 0; i < m->cap; i++) {
            if (m->slots[i].occupied) free(m->slots[i].key);
        }
        free(m->slots);
        m->slots = NULL;
        m->len = 0;
        m->cap = NUC_VEC_FREED_SENTINEL_CAP;
        return 0;
    }
    long long i;
    for (i = 0; i < m->cap; i++) {
        if (m->slots[i].occupied) free(m->slots[i].key);
    }
    free(m->slots);
    free(m);
    return 0;
}

// --- v0.2.27: HashMap accessors ---
long long __nucleor_hashmap_is_empty(long long h) {
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m) return 1;
    return m->len == 0 ? 1 : 0;
}
long long __nucleor_hashmap_get_or(long long h, const char *key, long long fallback) {
    if (!__nucleor_hashmap_contains(h, key)) return fallback;
    return __nucleor_hashmap_get(h, key);
}
long long __nucleor_hashmap_merge(long long dst, long long src) {
    NHashMap *d = (NHashMap *)(intptr_t)dst;
    NHashMap *s = (NHashMap *)(intptr_t)src;
    if (!d || !s) return 0;
    long long i;
    for (i = 0; i < s->cap; i++) {
        if (s->slots[i].occupied) {
            __nucleor_hashmap_insert(dst, s->slots[i].key, s->slots[i].val);
        }
    }
    return s->len;
}
long long __nucleor_hashmap_clone(long long h) {
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m) return __nucleor_hashmap_new();
    long long out = __nucleor_hashmap_with_capacity(m->len);
    long long i;
    for (i = 0; i < m->cap; i++) {
        if (m->slots[i].occupied) {
            __nucleor_hashmap_insert(out, m->slots[i].key, m->slots[i].val);
        }
    }
    return out;
}

// === sym-aux warm cache (v0.4.3 redesign) ===
//
// The s1 self-host compiler stores its symbol/ownership tables as
// flat `Vec<i32>` (interleaved name/reg pairs). Lookup was a
// backward linear scan with a most-recent-entry fast path. For
// large source files this is O(N) per lookup -> O(N^2) total.
//
// Phase A (v0.3.236) shipped four runtime helpers
// (__nucleor_sym_aux_get / _create / _built_at / _set_built_at)
// designed for a per-sym aux model: each Vec<i32> sym got its own
// NHashMap mirroring it.
//
// Phase B (v0.3.237) migrated source to use them and reverted in
// the same release: per-sym aux caused a 1.8x peak-memory regression
// (502MB -> 888MB) at no compile-time gain, because every sym_clone
// (one per branch in type-check / lowering) registered a new handle
// in a side table that never freed entries.
//
// v0.4.3 redesign: SINGLE WARM-CACHE slot. There is exactly one
// NHashMap allocated for the whole runtime. It mirrors the most-
// recently-accessed sym vec ("warm handle"). When sym_get is called
// on a different handle, the hashmap is cleared and rebuilt from
// the new sym. When sym_get is called on the warm handle, lookups
// are O(1).
//
// Workload pattern: lower a function body -> many sym_gets on that
// function's sym -> switch to the next function. Warm-cache rebuild
// happens once per function-body boundary, not once per sym vec
// allocation. Source-side size threshold (skip the warm path for
// small syms) bounds the worst-case clone-thrash overhead.
//
// Memory cost: ONE NHashMap. Size grows with the largest single
// sym ever cached but never accumulates across cloned syms.
//
// Backward-compatible API: the same four helpers from Phase A;
// only the SEMANTICS change. _create returns the (single) warm
// handle; _built_at returns built_at if the queried sym is warm,
// else 0 (force rebuild). The s1 source code that was prototyped
// in Phase B works as-is against the new semantics.
//
// Concurrency: the s1 self-host compiler is single-threaded; the
// warm cache is not protected by a mutex.

static long long g_sym_warm_handle = 0;
static long long g_sym_warm_aux = 0;          /* NHashMap handle, lazily created */
static long long g_sym_warm_built_at = 0;     /* vec_len when aux was last fully synced for warm_handle */

static void _sym_warm_init_if_needed(void) {
    if (g_sym_warm_aux == 0) {
        g_sym_warm_aux = __nucleor_hashmap_new();
    }
}

/* Return the aux NHashMap handle for sym_handle, or -1 if the
   queried sym isn't currently warm. (The runtime owns ONE hashmap;
   it returns -1 when the caller's sym isn't the one mirrored.)  */
long long __nucleor_sym_aux_get(long long sym_handle) {
    if (sym_handle == g_sym_warm_handle && g_sym_warm_aux != 0) {
        return g_sym_warm_aux;
    }
    return -1;
}

/* Get-or-set-warm the aux NHashMap. If `sym_handle` is already
   the warm handle, return the existing aux. Otherwise: clear the
   hashmap, set warm = sym_handle, reset built_at = 0, return the
   (now-empty) aux handle. The caller's catchup loop will then
   repopulate from the new sym's vec.                              */
long long __nucleor_sym_aux_create(long long sym_handle) {
    _sym_warm_init_if_needed();
    if (sym_handle != g_sym_warm_handle) {
        __nucleor_hashmap_clear(g_sym_warm_aux);
        g_sym_warm_handle = sym_handle;
        g_sym_warm_built_at = 0;
    }
    return g_sym_warm_aux;
}

/* Return the vec length at which the warm aux was last fully synced
   for `sym_handle`. If `sym_handle` isn't the warm handle, returns 0
   so the caller's catchup loop runs over the entire vec.           */
long long __nucleor_sym_aux_built_at(long long sym_handle) {
    if (sym_handle == g_sym_warm_handle && g_sym_warm_aux != 0) {
        return g_sym_warm_built_at;
    }
    return 0;
}

/* Record that the warm aux is synced up to vec length n. No-op if
   `sym_handle` isn't the current warm handle (caller raced with a
   context-switch -- the next sym_get will rebuild).                 */
long long __nucleor_sym_aux_set_built_at(long long sym_handle, long long n) {
    if (sym_handle == g_sym_warm_handle) {
        g_sym_warm_built_at = n;
    }
    return 0;
}

// === Compile-source side table (v0.4.10 Phase A) ===
//
// The s1 self-host compiler frequently needs the original source
// text to do source-text inference (infer_var_type_from_source,
// infer_pattern_binding_type_from_source). Some lowering helpers
// deep in the call chain don't currently have `src` in their
// signatures; threading it through (lower_fn -> lower_stmts ->
// lower_expr -> match_bind_payloads_per_idx) would be a 30+
// call-site refactor.
//
// This side table holds ONE source string, set at compile entry
// and cleared at compile exit. Any source-side helper can read it
// via __nucleor_compile_src_get(). Single-threaded by design --
// the s1 self-host compile is single-threaded.
//
// Phase A (this release) ships the helpers + get_rt_name mappings
// dormant; Phase B migrates source to use them.

static const char *g_compile_src = 0;

long long __nucleor_compile_src_set(const char *s) {
    g_compile_src = s;
    return 0;
}

const char *__nucleor_compile_src_get(void) {
    return g_compile_src ? g_compile_src : "";
}

long long __nucleor_compile_src_clear(void) {
    g_compile_src = 0;
    return 0;
}

// === HashMap iteration (RFC-0017 stdlib enrichment) ===
// hashmap_keys(h)   -> Vec<str>  : every occupied slot's key (newly strdup'd)
// hashmap_values(h) -> Vec<i64>  : every occupied slot's value (in same order
//                                  as hashmap_keys for any single hashmap)
//
// Iteration order is the underlying open-addressed slot order — stable for
// a given hashmap state, but unrelated to insertion order.

NVec *__nucleor_hashmap_keys(long long h) {
    NVec *out = __nucleor_vec_new();
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m) return out;
    long long i;
    for (i = 0; i < m->cap; i++) {
        if (m->slots[i].occupied) {
            const char *k = m->slots[i].key;
            size_t L = strlen(k);
            char *copy = (char *)malloc(L + 1);
            memcpy(copy, k, L + 1);
            __nucleor_vec_push(out, (long long)(intptr_t)copy);
        }
    }
    return out;
}

NVec *__nucleor_hashmap_values(long long h) {
    NVec *out = __nucleor_vec_new();
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m) return out;
    long long i;
    for (i = 0; i < m->cap; i++) {
        if (m->slots[i].occupied) __nucleor_vec_push(out, m->slots[i].val);
    }
    return out;
}

// === RFC-0001 §5.1 / Robotics-RFC §5.1: typed time ===
// Distinct monotonic vs wall-clock time.
// Monotonic: never goes backwards; safe for control-loop deadlines.
// Wall-clock: subject to NTP/sleep/system-time-changes; for human display.

long long __nucleor_time_monotonic_ns(void) {
#ifdef _WIN32
    LARGE_INTEGER freq, count;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&count);
    return (long long)((count.QuadPart * 1000000000LL) / freq.QuadPart);
#else
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)(ts.tv_sec * 1000000000LL + ts.tv_nsec);
#endif
}
long long __nucleor_time_monotonic_us(void) { return __nucleor_time_monotonic_ns() / 1000LL; }
long long __nucleor_time_monotonic_ms(void) { return __nucleor_time_monotonic_ns() / 1000000LL; }

// === v0.3.0 (T3.1): runtime #[deadline] checks ===
// Compiler-injected at the entry/exit of #[deadline = N] fns. Reads
// the saved start time, compares against limit, and aborts with a
// friendly diagnostic if elapsed time exceeded the limit.
//
// Returns 0 on pass; aborts (exit 1) on overrun. Returning rather
// than void so source-rewriter can drop the call into expression
// position if needed.
long long __nucleor_deadline_check(long long start_us, long long limit_us) {
    long long now = __nucleor_time_monotonic_us();
    long long elapsed = now - start_us;
    if (elapsed > limit_us) {
        fprintf(stderr, "error[RT-004]: #[deadline] overrun: elapsed %lld us > limit %lld us\n",
                elapsed, limit_us);
        fflush(stderr);
        exit(1);
    }
    return 0;
}

// NUCLEOR_TLS macro is defined at the top of this file (v0.8.82
// hoist for NUM-G8 thread-local overflow flag). See line ~30.

static NUCLEOR_TLS long long __nucleor_max_depth_counts[1024];

long long __nucleor_max_depth_enter(long long id, long long limit) {
    if (id < 0) id = -id;
    id = id % 1024;
    __nucleor_max_depth_counts[id]++;
    if (__nucleor_max_depth_counts[id] > limit) {
        fprintf(stderr,
                "error[DEPTH-003]: #[max_depth] runtime overrun: depth %lld > limit %lld\n",
                __nucleor_max_depth_counts[id], limit);
        fflush(stderr);
        exit(1);
    }
    return __nucleor_max_depth_counts[id];
}

long long __nucleor_max_depth_exit(long long id) {
    if (id < 0) id = -id;
    id = id % 1024;
    if (__nucleor_max_depth_counts[id] > 0) {
        __nucleor_max_depth_counts[id]--;
    }
    return __nucleor_max_depth_counts[id];
}

long long __nucleor_time_wall_ns(void) {
#ifdef _WIN32
    FILETIME ft;
    GetSystemTimePreciseAsFileTime(&ft);
    long long ull = ((long long)ft.dwHighDateTime << 32) | ft.dwLowDateTime;
    // Convert from 100-ns intervals since Jan 1 1601 to ns since Unix epoch
    return (ull - 116444736000000000LL) * 100LL;
#else
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    return (long long)(ts.tv_sec * 1000000000LL + ts.tv_nsec);
#endif
}
long long __nucleor_time_wall_us(void) { return __nucleor_time_wall_ns() / 1000LL; }
long long __nucleor_time_wall_ms(void) { return __nucleor_time_wall_ns() / 1000000LL; }
long long __nucleor_time_wall_seconds(void) { return __nucleor_time_wall_ns() / 1000000000LL; }

// === ISO 8601 formatting (RFC-0017 stdlib enrichment) ===
// time_iso_now() -> "YYYY-MM-DDTHH:MM:SSZ" (UTC); heap-allocated str.
// time_format_iso(unix_seconds) -> same format for an arbitrary timestamp.

#include <time.h>

const char *__nucleor_time_format_iso(long long unix_seconds) {
    time_t t = (time_t)unix_seconds;
    struct tm gmt;
#ifdef _WIN32
    gmtime_s(&gmt, &t);
#else
    gmtime_r(&t, &gmt);
#endif
    char *buf = (char *)malloc(32);
    snprintf(buf, 32, "%04d-%02d-%02dT%02d:%02d:%02dZ",
        gmt.tm_year + 1900, gmt.tm_mon + 1, gmt.tm_mday,
        gmt.tm_hour, gmt.tm_min, gmt.tm_sec);
    return buf;
}

const char *__nucleor_time_iso_now(void) {
    return __nucleor_time_format_iso(__nucleor_time_wall_seconds());
}

// --- v0.2.21: time decomposition + elapsed ---
// All take a unix-seconds timestamp and return a UTC component.
// time_weekday returns 0=Sunday..6=Saturday (POSIX tm_wday convention).
// time_day_of_year returns 1..366.
static void __nuc_unix_to_utc_tm(long long unix_seconds, struct tm *out) {
    time_t t = (time_t)unix_seconds;
#ifdef _WIN32
    gmtime_s(out, &t);
#else
    gmtime_r(&t, out);
#endif
}
long long __nucleor_time_year(long long unix_seconds) {
    struct tm g; __nuc_unix_to_utc_tm(unix_seconds, &g);
    return (long long)(g.tm_year + 1900);
}
long long __nucleor_time_month(long long unix_seconds) {
    struct tm g; __nuc_unix_to_utc_tm(unix_seconds, &g);
    return (long long)(g.tm_mon + 1);
}
long long __nucleor_time_day(long long unix_seconds) {
    struct tm g; __nuc_unix_to_utc_tm(unix_seconds, &g);
    return (long long)g.tm_mday;
}
long long __nucleor_time_hour(long long unix_seconds) {
    struct tm g; __nuc_unix_to_utc_tm(unix_seconds, &g);
    return (long long)g.tm_hour;
}
long long __nucleor_time_minute(long long unix_seconds) {
    struct tm g; __nuc_unix_to_utc_tm(unix_seconds, &g);
    return (long long)g.tm_min;
}
long long __nucleor_time_second(long long unix_seconds) {
    struct tm g; __nuc_unix_to_utc_tm(unix_seconds, &g);
    return (long long)g.tm_sec;
}
long long __nucleor_time_weekday(long long unix_seconds) {
    struct tm g; __nuc_unix_to_utc_tm(unix_seconds, &g);
    return (long long)g.tm_wday;
}
long long __nucleor_time_day_of_year(long long unix_seconds) {
    struct tm g; __nuc_unix_to_utc_tm(unix_seconds, &g);
    return (long long)(g.tm_yday + 1);
}
long long __nucleor_time_elapsed_ms(long long start_ms) {
    return __nucleor_time_wall_ms() - start_ms;
}

long long __nucleor_sleep_ms(long long ms) {
#ifdef _WIN32
    Sleep((DWORD)ms);
#else
    struct timespec req;
    req.tv_sec = ms / 1000;
    req.tv_nsec = (ms % 1000) * 1000000L;
    nanosleep(&req, NULL);
#endif
    return 0;
}
long long __nucleor_sleep_us(long long us) {
#ifdef _WIN32
    Sleep((DWORD)(us / 1000));
#else
    struct timespec req;
    req.tv_sec = us / 1000000;
    req.tv_nsec = (us % 1000000) * 1000L;
    nanosleep(&req, NULL);
#endif
    return 0;
}

// === Environment variables ===
long long __nucleor_env_get(const char *name) {
    if (!name) return 0;
    char *v = getenv(name);
    return (long long)(intptr_t)v;
}
// v0.3.98: env_get_or — returns the env var if set, else the default.
// Common Rust idiom: `std::env::var(name).unwrap_or("default")`.
long long __nucleor_env_get_or(const char *name, const char *default_val) {
    if (!name) return (long long)(intptr_t)default_val;
    char *v = getenv(name);
    if (!v) return (long long)(intptr_t)default_val;
    return (long long)(intptr_t)v;
}
long long __nucleor_env_set(const char *name, const char *value) {
    if (!name || !value) return -1;
#ifdef _WIN32
    return _putenv_s(name, value);
#else
    return setenv(name, value, 1);
#endif
}
long long __nucleor_env_unset(const char *name) {
    if (!name) return -1;
#ifdef _WIN32
    return _putenv_s(name, "");
#else
    return unsetenv(name);
#endif
}
long long __nucleor_env_has(const char *name) {
    if (!name) return 0;
    char *v = getenv(name);
    return v != NULL ? 1 : 0;
}
long long __nucleor_env_keys(void) {
    NVec *out = __nucleor_vec_new();
#ifdef _WIN32
    LPCH block = GetEnvironmentStringsA();
    if (!block) return (long long)(intptr_t)out;
    LPCH p = block;
    while (*p) {
        // Each entry is "KEY=VALUE\0". Some Windows entries start with '='
        // (drive-current-dir tracking like "=C:=C:\\path"); skip those.
        if (*p != '=') {
            const char *eq = strchr(p, '=');
            size_t klen = eq ? (size_t)(eq - p) : strlen(p);
            char *key = (char *)malloc(klen + 1);
            memcpy(key, p, klen);
            key[klen] = 0;
            __nucleor_vec_push(out, (long long)(intptr_t)key);
        }
        p += strlen(p) + 1;
    }
    FreeEnvironmentStringsA(block);
#else
    extern char **environ;
    if (!environ) return (long long)(intptr_t)out;
    for (char **e = environ; *e; e++) {
        const char *eq = strchr(*e, '=');
        size_t klen = eq ? (size_t)(eq - *e) : strlen(*e);
        char *key = (char *)malloc(klen + 1);
        memcpy(key, *e, klen);
        key[klen] = 0;
        __nucleor_vec_push(out, (long long)(intptr_t)key);
    }
#endif
    return (long long)(intptr_t)out;
}

// === Process / OS info ===
long long __nucleor_process_id(void) {
#ifdef _WIN32
    return (long long)GetCurrentProcessId();
#else
    return (long long)getpid();
#endif
}

long long __nucleor_os_family(void) {
    // Return a tag: 1 = windows, 2 = linux, 3 = darwin, 4 = bsd, 0 = unknown
#if defined(_WIN32)
    return 1;
#elif defined(__APPLE__)
    return 3;
#elif defined(__linux__)
    return 2;
#elif defined(__FreeBSD__) || defined(__OpenBSD__) || defined(__NetBSD__)
    return 4;
#else
    return 0;
#endif
}

long long __nucleor_os_pointer_width(void) {
    return (long long)(sizeof(void *) * 8);
}

// === RFC-0017 phase 4: VecDeque<i64> ===
// Ring-buffer-backed deque. O(1) push_front/push_back/pop_front/pop_back.
typedef struct {
    long long *data;
    long long head;   // index of first element
    long long len;
    long long cap;
} NVecDeque;

long long __nucleor_vecdeque_new(void) {
    NVecDeque *d = (NVecDeque *)malloc(sizeof(NVecDeque));
    d->cap = 16;
    d->data = (long long *)malloc((size_t)d->cap * sizeof(long long));
    d->head = 0;
    d->len = 0;
    return (long long)(intptr_t)d;
}
long long __nucleor_vecdeque_with_capacity(long long n) {
    if (n < 0) {
        fprintf(stderr, "PANIC: vecdeque_with_capacity: negative capacity %lld\n", n);
        fflush(stderr); exit(1);
    }
    NVecDeque *d = (NVecDeque *)malloc(sizeof(NVecDeque));
    long long cap = 16;
    /* v0.3.233: bounded doubling -- prior loop could spin until cap
       wrapped negative if n was hostile. _grow_cap panics cleanly
       once doubling would exceed the safe range.                    */
    while (cap < n) cap = _grow_cap(cap, sizeof(long long), "vecdeque_with_capacity");
    d->cap = cap;
    d->data = (long long *)malloc((size_t)cap * sizeof(long long));
    d->head = 0;
    d->len = 0;
    return (long long)(intptr_t)d;
}
static void __nuc_vecdeque_grow(NVecDeque *d) {
    long long new_cap = _grow_cap(d->cap, sizeof(long long), "vecdeque grow");
    long long *new_data = (long long *)malloc((size_t)new_cap * sizeof(long long));
    long long i;
    for (i = 0; i < d->len; i++) {
        new_data[i] = d->data[(d->head + i) % d->cap];
    }
    free(d->data);
    d->data = new_data;
    d->head = 0;
    d->cap = new_cap;
}
long long __nucleor_vecdeque_push_back(long long h, long long v) {
    NVecDeque *d = (NVecDeque *)(intptr_t)h;
    if (!d) return 0;
    if (d->len >= d->cap) __nuc_vecdeque_grow(d);
    long long tail = (d->head + d->len) % d->cap;
    d->data[tail] = v;
    d->len++;
    return 0;
}
long long __nucleor_vecdeque_push_front(long long h, long long v) {
    NVecDeque *d = (NVecDeque *)(intptr_t)h;
    if (!d) return 0;
    if (d->len >= d->cap) __nuc_vecdeque_grow(d);
    d->head = (d->head + d->cap - 1) % d->cap;
    d->data[d->head] = v;
    d->len++;
    return 0;
}
// Returns the popped value; caller checks len > 0 first via vecdeque_len.
// Returns 0 if empty.
long long __nucleor_vecdeque_pop_front(long long h) {
    NVecDeque *d = (NVecDeque *)(intptr_t)h;
    if (!d || d->len == 0) return 0;
    long long v = d->data[d->head];
    d->head = (d->head + 1) % d->cap;
    d->len--;
    return v;
}
long long __nucleor_vecdeque_pop_back(long long h) {
    NVecDeque *d = (NVecDeque *)(intptr_t)h;
    if (!d || d->len == 0) return 0;
    long long tail = (d->head + d->len - 1) % d->cap;
    long long v = d->data[tail];
    d->len--;
    return v;
}
long long __nucleor_vecdeque_get(long long h, long long i) {
    NVecDeque *d = (NVecDeque *)(intptr_t)h;
    if (!d || i < 0 || i >= d->len) return 0;
    return d->data[(d->head + i) % d->cap];
}
long long __nucleor_vecdeque_set(long long h, long long i, long long v) {
    NVecDeque *d = (NVecDeque *)(intptr_t)h;
    if (!d || i < 0 || i >= d->len) return 0;
    d->data[(d->head + i) % d->cap] = v;
    return 0;
}
long long __nucleor_vecdeque_len(long long h) {
    NVecDeque *d = (NVecDeque *)(intptr_t)h;
    if (!d) return 0;
    return d->len;
}
long long __nucleor_vecdeque_capacity(long long h) {
    NVecDeque *d = (NVecDeque *)(intptr_t)h;
    if (!d) return 0;
    return d->cap;
}
long long __nucleor_vecdeque_clear(long long h) {
    NVecDeque *d = (NVecDeque *)(intptr_t)h;
    if (!d) return 0;
    d->head = 0;
    d->len = 0;
    return 0;
}
long long __nucleor_vecdeque_free(long long h) {
    NVecDeque *d = (NVecDeque *)(intptr_t)h;
    if (!d) return 0;
    free(d->data);
    free(d);
    return 0;
}

// === RFC-0017 phase 4: HashSet<str> ===
// Implemented as HashMap<str, 1> (value slot unused). Same hash strategy.
long long __nucleor_hashset_new(void) {
    return __nucleor_hashmap_new();
}
long long __nucleor_hashset_with_capacity(long long n) {
    return __nucleor_hashmap_with_capacity(n);
}
long long __nucleor_hashset_insert(long long h, const char *key) {
    return __nucleor_hashmap_insert(h, key, 1);
}
long long __nucleor_hashset_contains(long long h, const char *key) {
    return __nucleor_hashmap_contains(h, key);
}
long long __nucleor_hashset_remove(long long h, const char *key) {
    return __nucleor_hashmap_remove(h, key);
}
long long __nucleor_hashset_len(long long h) {
    return __nucleor_hashmap_len(h);
}
long long __nucleor_hashset_clear(long long h) {
    return __nucleor_hashmap_clear(h);
}
long long __nucleor_hashset_free(long long h) {
    return __nucleor_hashmap_free(h);
}

// === RFC-0017 phase 3: BTreeMap<str, i64> ===
// Ordered associative map. Keys stored sorted; iteration yields sorted order.
// Implementation: sorted array with binary search — O(log n) get, O(n) insert
// (linear shift). Real B-tree with O(log n) insert arrives in v0.4 RFC-0017
// full impl. Shape-stable API; user code written today transitions cleanly.

typedef struct {
    char **keys;
    long long *vals;
    long long len;
    long long cap;
} NBTreeMap;

static long long __nuc_btreemap_bsearch(NBTreeMap *m, const char *key) {
    // Returns index where key is, or -(insertion_point + 1) if missing.
    long long lo = 0, hi = m->len - 1;
    while (lo <= hi) {
        long long mid = (lo + hi) / 2;
        int cmp = strcmp(m->keys[mid], key);
        if (cmp == 0) return mid;
        if (cmp < 0) lo = mid + 1;
        else hi = mid - 1;
    }
    return -(lo + 1);
}

long long __nucleor_btreemap_new(void) {
    NBTreeMap *m = (NBTreeMap *)malloc(sizeof(NBTreeMap));
    m->cap = 8;
    m->keys = (char **)malloc((size_t)m->cap * sizeof(char *));
    m->vals = (long long *)malloc((size_t)m->cap * sizeof(long long));
    m->len = 0;
    return (long long)(intptr_t)m;
}
long long __nucleor_btreemap_insert(long long h, const char *key, long long val) {
    NBTreeMap *m = (NBTreeMap *)(intptr_t)h;
    if (!m || !key) return 0;
    long long idx = __nuc_btreemap_bsearch(m, key);
    if (idx >= 0) {
        // Update existing
        m->vals[idx] = val;
        return 0;
    }
    long long ins = -idx - 1;
    if (m->len >= m->cap) {
        /* v0.3.233: cap-doubling overflow guard. The pair grow uses
           the larger element (sizeof(char *) on 64-bit == sizeof(long long)),
           so a single _grow_cap call suffices for both arrays.        */
        size_t pair_elem = sizeof(char *) >= sizeof(long long) ? sizeof(char *) : sizeof(long long);
        m->cap = _grow_cap(m->cap, pair_elem, "btreemap insert");
        m->keys = (char **)realloc(m->keys, (size_t)m->cap * sizeof(char *));
        m->vals = (long long *)realloc(m->vals, (size_t)m->cap * sizeof(long long));
    }
    // Shift right
    long long i;
    for (i = m->len; i > ins; i--) {
        m->keys[i] = m->keys[i - 1];
        m->vals[i] = m->vals[i - 1];
    }
    size_t klen = strlen(key);
    m->keys[ins] = (char *)malloc(klen + 1);
    memcpy(m->keys[ins], key, klen + 1);
    m->vals[ins] = val;
    m->len++;
    return 0;
}
long long __nucleor_btreemap_get(long long h, const char *key) {
    NBTreeMap *m = (NBTreeMap *)(intptr_t)h;
    if (!m || !key) return 0;
    long long idx = __nuc_btreemap_bsearch(m, key);
    if (idx < 0) {
        if (_vec_oob_lenient()) return 0;
        fprintf(stderr, "PANIC: btreemap_get missing key '%s' (set NUCLEOR_VEC_OOB_LENIENT=1 to suppress)\n", key);
        fflush(stderr);
        exit(1);
    }
    return m->vals[idx];
}
long long __nucleor_btreemap_contains(long long h, const char *key) {
    NBTreeMap *m = (NBTreeMap *)(intptr_t)h;
    if (!m || !key) return 0;
    return __nuc_btreemap_bsearch(m, key) >= 0 ? 1 : 0;
}
// v0.3.189: Rust-canonical name alias.
long long __nucleor_btreemap_contains_key(long long h, const char *key) {
    return __nucleor_btreemap_contains(h, key);
}
long long __nucleor_btreemap_remove(long long h, const char *key) {
    NBTreeMap *m = (NBTreeMap *)(intptr_t)h;
    if (!m || !key) return 0;
    long long idx = __nuc_btreemap_bsearch(m, key);
    if (idx < 0) return 0;
    free(m->keys[idx]);
    long long i;
    for (i = idx; i < m->len - 1; i++) {
        m->keys[i] = m->keys[i + 1];
        m->vals[i] = m->vals[i + 1];
    }
    m->len--;
    return 1;
}
long long __nucleor_btreemap_len(long long h) {
    NBTreeMap *m = (NBTreeMap *)(intptr_t)h;
    if (!m) return 0;
    return m->len;
}
// Sorted iteration: access by position.
long long __nucleor_btreemap_key_at(long long h, long long pos) {
    NBTreeMap *m = (NBTreeMap *)(intptr_t)h;
    if (!m || pos < 0 || pos >= m->len) return 0;
    return (long long)(intptr_t)m->keys[pos];
}
long long __nucleor_btreemap_val_at(long long h, long long pos) {
    NBTreeMap *m = (NBTreeMap *)(intptr_t)h;
    if (!m || pos < 0 || pos >= m->len) return 0;
    return m->vals[pos];
}
long long __nucleor_btreemap_clear(long long h) {
    NBTreeMap *m = (NBTreeMap *)(intptr_t)h;
    if (!m) return 0;
    long long i;
    for (i = 0; i < m->len; i++) free(m->keys[i]);
    m->len = 0;
    return 0;
}
long long __nucleor_btreemap_free(long long h) {
    NBTreeMap *m = (NBTreeMap *)(intptr_t)h;
    if (!m) return 0;
    long long i;
    for (i = 0; i < m->len; i++) free(m->keys[i]);
    free(m->keys);
    free(m->vals);
    free(m);
    return 0;
}

// === RFC-0017 phase 3: BTreeSet<str> ===
// Ordered set, implemented atop BTreeMap with value = 1.
long long __nucleor_btreeset_new(void) { return __nucleor_btreemap_new(); }
long long __nucleor_btreeset_insert(long long h, const char *key) {
    return __nucleor_btreemap_insert(h, key, 1);
}
long long __nucleor_btreeset_contains(long long h, const char *key) {
    return __nucleor_btreemap_contains(h, key);
}
long long __nucleor_btreeset_remove(long long h, const char *key) {
    return __nucleor_btreemap_remove(h, key);
}
long long __nucleor_btreeset_len(long long h) { return __nucleor_btreemap_len(h); }
long long __nucleor_btreeset_at(long long h, long long pos) {
    return __nucleor_btreemap_key_at(h, pos);
}
long long __nucleor_btreeset_clear(long long h) { return __nucleor_btreemap_clear(h); }
long long __nucleor_btreeset_free(long long h) { return __nucleor_btreemap_free(h); }

// === RFC-0018/0019: File system primitives ===
// Required by module resolver + package manager. POSIX + Win32 portable.
#include <sys/stat.h>
#include <sys/types.h>
#ifdef _WIN32
#include <direct.h>
#include <io.h>
typedef struct _stat64 NucStatBuf;
static inline int nuc_stat_call(const char *p, NucStatBuf *s) { return _stat64(p, s); }
#else
#include <dirent.h>
#include <unistd.h>
typedef struct stat NucStatBuf;
static inline int nuc_stat_call(const char *p, NucStatBuf *s) { return stat(p, s); }
#endif

long long __nucleor_fs_exists(const char *path) {
    if (!path) return 0;
    NucStatBuf st;
    return nuc_stat_call(path, &st) == 0 ? 1 : 0;
}
long long __nucleor_fs_is_file(const char *path) {
    if (!path) return 0;
    NucStatBuf st;
    if (nuc_stat_call(path, &st) != 0) return 0;
#ifdef _WIN32
    return (st.st_mode & _S_IFREG) ? 1 : 0;
#else
    return S_ISREG(st.st_mode) ? 1 : 0;
#endif
}
long long __nucleor_fs_is_dir(const char *path) {
    if (!path) return 0;
    NucStatBuf st;
    if (nuc_stat_call(path, &st) != 0) return 0;
#ifdef _WIN32
    return (st.st_mode & _S_IFDIR) ? 1 : 0;
#else
    return S_ISDIR(st.st_mode) ? 1 : 0;
#endif
}
long long __nucleor_fs_size(const char *path) {
    if (!path) return -1;
    NucStatBuf st;
    if (nuc_stat_call(path, &st) != 0) return -1;
    return (long long)st.st_size;
}
long long __nucleor_fs_mtime(const char *path) {
    if (!path) return 0;
    NucStatBuf st;
    if (nuc_stat_call(path, &st) != 0) return 0;
    return (long long)st.st_mtime;
}
long long __nucleor_fs_create_dir(const char *path) {
    if (!path) return -1;
#ifdef _WIN32
    return _mkdir(path);
#else
    return mkdir(path, 0755);
#endif
}
long long __nucleor_fs_create_dir_all(const char *path) {
    // Create all parent components. Mutates a copy of `path` in place.
    if (!path) return -1;
    char buf[4096];
    size_t len = strlen(path);
    if (len >= sizeof(buf)) return -1;
    memcpy(buf, path, len + 1);
    size_t i;
    for (i = 1; i < len; i++) {
        if (buf[i] == '/' || buf[i] == '\\') {
            char saved = buf[i];
            buf[i] = 0;
            if (!__nucleor_fs_exists(buf)) {
#ifdef _WIN32
                _mkdir(buf);
#else
                mkdir(buf, 0755);
#endif
            }
            buf[i] = saved;
        }
    }
    if (!__nucleor_fs_exists(buf)) {
#ifdef _WIN32
        return _mkdir(buf);
#else
        return mkdir(buf, 0755);
#endif
    }
    return 0;
}
long long __nucleor_fs_remove_file(const char *path) {
    if (!path) return -1;
    return remove(path);
}
long long __nucleor_fs_rename(const char *from, const char *to) {
    if (!from || !to) return -1;
    return rename(from, to);
}

// Directory listing — returns a NVec handle holding str entries.
// Empty Vec on error or non-existent path.
long long __nucleor_fs_list_dir(const char *path) {
    NVec *v = __nucleor_vec_new();
    if (!path) return (long long)(intptr_t)v;
#ifdef _WIN32
    char pattern[4096];
    snprintf(pattern, sizeof(pattern), "%s\\*", path);
    struct _finddata_t fd;
    intptr_t hd = _findfirst(pattern, &fd);
    if (hd == -1) return (long long)(intptr_t)v;
    do {
        if (strcmp(fd.name, ".") == 0 || strcmp(fd.name, "..") == 0) continue;
        size_t nlen = strlen(fd.name);
        char *copy = (char *)malloc(nlen + 1);
        memcpy(copy, fd.name, nlen + 1);
        __nucleor_vec_push(v, (long long)(intptr_t)copy);
    } while (_findnext(hd, &fd) == 0);
    _findclose(hd);
#else
    DIR *d = opendir(path);
    if (!d) return (long long)(intptr_t)v;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        if (strcmp(e->d_name, ".") == 0 || strcmp(e->d_name, "..") == 0) continue;
        size_t nlen = strlen(e->d_name);
        char *copy = (char *)malloc(nlen + 1);
        memcpy(copy, e->d_name, nlen + 1);
        __nucleor_vec_push(v, (long long)(intptr_t)copy);
    }
    closedir(d);
#endif
    return (long long)(intptr_t)v;
}

// Path manipulation
long long __nucleor_fs_join(const char *a, const char *b) {
    if (!a) a = "";
    if (!b) b = "";
    size_t la = strlen(a), lb = strlen(b);
    char *out = (char *)malloc(la + lb + 2);
    memcpy(out, a, la);
    if (la > 0 && a[la - 1] != '/' && a[la - 1] != '\\') {
        out[la++] = '/';
    }
    memcpy(out + la, b, lb + 1);
    return (long long)(intptr_t)out;
}
long long __nucleor_fs_basename(const char *path) {
    if (!path) {
        char *e = (char *)malloc(1); e[0] = 0; return (long long)(intptr_t)e;
    }
    size_t len = strlen(path);
    long i;
    for (i = (long)len - 1; i >= 0; i--) {
        if (path[i] == '/' || path[i] == '\\') {
            size_t blen = len - i - 1;
            char *out = (char *)malloc(blen + 1);
            memcpy(out, path + i + 1, blen + 1);
            return (long long)(intptr_t)out;
        }
    }
    char *out = (char *)malloc(len + 1);
    memcpy(out, path, len + 1);
    return (long long)(intptr_t)out;
}
long long __nucleor_fs_dirname(const char *path) {
    if (!path) {
        char *e = (char *)malloc(2); e[0] = '.'; e[1] = 0; return (long long)(intptr_t)e;
    }
    size_t len = strlen(path);
    long i;
    for (i = (long)len - 1; i >= 0; i--) {
        if (path[i] == '/' || path[i] == '\\') {
            char *out = (char *)malloc(i + 1);
            memcpy(out, path, i);
            out[i] = 0;
            return (long long)(intptr_t)out;
        }
    }
    char *out = (char *)malloc(2); out[0] = '.'; out[1] = 0;
    return (long long)(intptr_t)out;
}
long long __nucleor_fs_extension(const char *path) {
    if (!path) {
        char *e = (char *)malloc(1); e[0] = 0; return (long long)(intptr_t)e;
    }
    size_t len = strlen(path);
    long i;
    for (i = (long)len - 1; i >= 0; i--) {
        if (path[i] == '/' || path[i] == '\\') break;
        if (path[i] == '.' && i > 0 && path[i - 1] != '/' && path[i - 1] != '\\') {
            size_t elen = len - i - 1;
            char *out = (char *)malloc(elen + 1);
            memcpy(out, path + i + 1, elen + 1);
            return (long long)(intptr_t)out;
        }
    }
    char *out = (char *)malloc(1); out[0] = 0;
    return (long long)(intptr_t)out;
}

// --- v0.2.19: fs extras ---
long long __nucleor_fs_temp_dir(void) {
#ifdef _WIN32
    char buf[MAX_PATH + 1];
    DWORD n = GetTempPathA(MAX_PATH, buf);
    if (n == 0) {
        const char *fallback = "C:\\Windows\\Temp";
        size_t L = strlen(fallback);
        char *out = (char *)malloc(L + 1);
        memcpy(out, fallback, L + 1);
        return (long long)(intptr_t)out;
    }
    // Strip trailing backslash for consistency with POSIX-style returns
    if (n > 0 && (buf[n - 1] == '\\' || buf[n - 1] == '/')) buf[n - 1] = 0;
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return (long long)(intptr_t)out;
#else
    const char *t = getenv("TMPDIR");
    if (!t || !*t) t = "/tmp";
    size_t L = strlen(t);
    char *out = (char *)malloc(L + 1);
    memcpy(out, t, L + 1);
    return (long long)(intptr_t)out;
#endif
}

long long __nucleor_fs_current_dir(void) {
#ifdef _WIN32
    char buf[MAX_PATH + 1];
    DWORD n = GetCurrentDirectoryA(MAX_PATH, buf);
    if (n == 0) {
        char *out = (char *)malloc(1); out[0] = 0;
        return (long long)(intptr_t)out;
    }
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return (long long)(intptr_t)out;
#else
    char buf[4096];
    if (!getcwd(buf, sizeof(buf))) {
        char *out = (char *)malloc(1); out[0] = 0;
        return (long long)(intptr_t)out;
    }
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return (long long)(intptr_t)out;
#endif
}

long long __nucleor_fs_remove_dir(const char *path) {
    if (!path) return 0;
#ifdef _WIN32
    return RemoveDirectoryA(path) ? 1 : 0;
#else
    return rmdir(path) == 0 ? 1 : 0;
#endif
}

long long __nucleor_fs_copy_file(const char *from, const char *to) {
    if (!from || !to) return 0;
    FILE *fi = fopen(from, "rb");
    if (!fi) return 0;
    FILE *fo = fopen(to, "wb");
    if (!fo) { fclose(fi); return 0; }
    char buf[8192];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), fi)) > 0) {
        if (fwrite(buf, 1, n, fo) != n) {
            fclose(fi); fclose(fo);
            return 0;
        }
    }
    fclose(fi); fclose(fo);
#ifndef _WIN32
    /* v0.8.323: preserve source mode on POSIX (cp -p style for mode
     * bits only). Without this, the destination file gets the default
     * umask mode (typically 0644), so an executable source becomes
     * non-executable at the destination — which broke the native-link
     * cache restore path: cache miss produced -rwxr-xr-x, cache hit
     * produced -rw-r--r-- and "Permission denied" on exec. On Windows
     * the executable bit is implicit via .exe extension so this is a
     * no-op there. Closes
     * findings/promoted/2026-05-06-cache-restore-drops-exec-bit.md. */
    struct stat _src_st;
    if (stat(from, &_src_st) == 0) {
        (void)chmod(to, _src_st.st_mode & 07777);
    }
#endif
    return 1;
}

// --- v0.2.23: path utilities ---
// Cross-platform string-level path helpers (no I/O — fs_canonicalize is the
// I/O-touching version). All accept "/" or "\\" interchangeably; output uses
// the OS-native separator on Windows ("\\") and "/" elsewhere.
static inline int __nuc_is_sep(char c) { return c == '/' || c == '\\'; }
#ifdef _WIN32
static const char __NUC_SEP = '\\';
#else
static const char __NUC_SEP = '/';
#endif

long long __nucleor_path_separator(void) {
    char *out = (char *)malloc(2);
    out[0] = __NUC_SEP;
    out[1] = 0;
    return (long long)(intptr_t)out;
}

long long __nucleor_path_is_absolute(const char *path) {
    if (!path || !*path) return 0;
    if (__nuc_is_sep(path[0])) return 1;
#ifdef _WIN32
    // "C:\\..." or "C:/..." style drive-rooted paths
    if (((path[0] >= 'A' && path[0] <= 'Z') || (path[0] >= 'a' && path[0] <= 'z'))
        && path[1] == ':' && __nuc_is_sep(path[2])) return 1;
#endif
    return 0;
}

long long __nucleor_path_normalize(const char *path) {
    if (!path) {
        char *e = (char *)malloc(1); e[0] = 0;
        return (long long)(intptr_t)e;
    }
    size_t L = strlen(path);
    // Working buffer: components stack (pointers + lens into a copy).
    char *copy = (char *)malloc(L + 1);
    memcpy(copy, path, L + 1);
    // Detect drive prefix on Windows so we don't strip it.
    size_t drive_len = 0;
#ifdef _WIN32
    if (L >= 2 && ((copy[0] >= 'A' && copy[0] <= 'Z') || (copy[0] >= 'a' && copy[0] <= 'z')) && copy[1] == ':') {
        drive_len = 2;
    }
#endif
    int is_abs = (drive_len < L) && __nuc_is_sep(copy[drive_len]);

    // Tokenize the rest by separators.
    char **parts = (char **)malloc(sizeof(char *) * (L + 1));
    int n = 0;
    char *p = copy + drive_len + (is_abs ? 1 : 0);
    while (*p) {
        while (*p && __nuc_is_sep(*p)) p++;
        if (!*p) break;
        char *start = p;
        while (*p && !__nuc_is_sep(*p)) p++;
        // Null-terminate this segment in-place; advance past the separator
        // *after* terminating, but DO NOT restore — the next iteration will
        // skip the (now-zero) byte via the leading separator-skip loop.
        if (*p) { *p = 0; p++; }
        if (strcmp(start, ".") == 0) {
            // skip
        } else if (strcmp(start, "..") == 0) {
            if (n > 0 && strcmp(parts[n - 1], "..") != 0) {
                n--;
            } else if (!is_abs) {
                parts[n++] = start;
            }
        } else {
            parts[n++] = start;
        }
    }
    // Reassemble.
    size_t out_cap = L + 4;
    char *out = (char *)malloc(out_cap);
    size_t off = 0;
    if (drive_len > 0) {
        memcpy(out + off, copy, drive_len);
        off += drive_len;
    }
    if (is_abs) { out[off++] = __NUC_SEP; }
    for (int i = 0; i < n; i++) {
        if (i > 0) out[off++] = __NUC_SEP;
        size_t pl = strlen(parts[i]);
        memcpy(out + off, parts[i], pl);
        off += pl;
    }
    if (off == 0) { out[off++] = '.'; }
    out[off] = 0;
    free(parts);
    free(copy);
    return (long long)(intptr_t)out;
}

long long __nucleor_path_with_extension(const char *path, const char *ext) {
    if (!path) {
        char *e = (char *)malloc(1); e[0] = 0;
        return (long long)(intptr_t)e;
    }
    if (!ext) ext = "";
    size_t L = strlen(path);
    // Strip leading "." from caller-supplied ext for normalization
    while (*ext == '.') ext++;
    size_t el = strlen(ext);

    // Find position of the last '.' that's after the last separator.
    long dot_pos = -1;
    for (long i = (long)L - 1; i >= 0; i--) {
        if (__nuc_is_sep(path[i])) break;
        if (path[i] == '.' && i > 0 && !__nuc_is_sep(path[i - 1])) {
            dot_pos = i;
            break;
        }
    }
    size_t base_len = (dot_pos >= 0) ? (size_t)dot_pos : L;
    size_t need = base_len + (el > 0 ? 1 + el : 0);
    char *out = (char *)malloc(need + 1);
    memcpy(out, path, base_len);
    if (el > 0) {
        out[base_len] = '.';
        memcpy(out + base_len + 1, ext, el);
    }
    out[need] = 0;
    return (long long)(intptr_t)out;
}

long long __nucleor_path_strip_extension(const char *path) {
    return __nucleor_path_with_extension(path, "");
}

long long __nucleor_path_components(const char *path) {
    NVec *out = __nucleor_vec_new();
    if (!path) return (long long)(intptr_t)out;
    size_t L = strlen(path);
    size_t drive_len = 0;
#ifdef _WIN32
    if (L >= 2 && ((path[0] >= 'A' && path[0] <= 'Z') || (path[0] >= 'a' && path[0] <= 'z')) && path[1] == ':') {
        drive_len = 2;
        char *d = (char *)malloc(3);
        d[0] = path[0]; d[1] = ':'; d[2] = 0;
        __nucleor_vec_push(out, (long long)(intptr_t)d);
    }
#endif
    if (drive_len < L && __nuc_is_sep(path[drive_len])) {
        char *r = (char *)malloc(2);
        r[0] = __NUC_SEP; r[1] = 0;
        __nucleor_vec_push(out, (long long)(intptr_t)r);
    }
    const char *p = path + drive_len;
    while (*p && __nuc_is_sep(*p)) p++;
    while (*p) {
        const char *start = p;
        while (*p && !__nuc_is_sep(*p)) p++;
        size_t pl = (size_t)(p - start);
        char *piece = (char *)malloc(pl + 1);
        memcpy(piece, start, pl);
        piece[pl] = 0;
        __nucleor_vec_push(out, (long long)(intptr_t)piece);
        while (*p && __nuc_is_sep(*p)) p++;
    }
    return (long long)(intptr_t)out;
}

long long __nucleor_fs_canonicalize(const char *path) {
    if (!path) {
        char *out = (char *)malloc(1); out[0] = 0;
        return (long long)(intptr_t)out;
    }
#ifdef _WIN32
    char buf[MAX_PATH + 1];
    DWORD n = GetFullPathNameA(path, MAX_PATH, buf, NULL);
    if (n == 0) {
        size_t L = strlen(path);
        char *out = (char *)malloc(L + 1);
        memcpy(out, path, L + 1);
        return (long long)(intptr_t)out;
    }
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return (long long)(intptr_t)out;
#else
    char buf[4096];
    if (!realpath(path, buf)) {
        size_t L = strlen(path);
        char *out = (char *)malloc(L + 1);
        memcpy(out, path, L + 1);
        return (long long)(intptr_t)out;
    }
    size_t L = strlen(buf);
    char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1);
    return (long long)(intptr_t)out;
#endif
}

// === RFC-0019 phase 1: minimal TOML parser ===
// Stores parsed key→value pairs in an NHashMap. Supports:
//   - [section] headers (keys are emitted as "section.subkey")
//   - key = "string"
//   - key = 42  (integers)
//   - key = true / false  (stored as 1 / 0)
//   - # line comments
//   - [a.b.c] dotted sections
// Out of scope (later phases): arrays, inline tables, multi-line strings,
// floats, dates. Full RFC-0019 toml.nr rod arrives in v0.4.

static void __nuc_toml_strip(char *s) {
    // Trim trailing whitespace including \r
    long n = (long)strlen(s);
    while (n > 0 && (s[n-1] == ' ' || s[n-1] == '\t' || s[n-1] == '\r' || s[n-1] == '\n')) {
        s[--n] = 0;
    }
}
static char *__nuc_toml_skip_ws(char *p) {
    while (*p == ' ' || *p == '\t') p++;
    return p;
}

long long __nucleor_toml_parse_string(const char *src) {
    // Parse TOML source string; return NHashMap handle with "section.key" → packed value.
    // Values that are strings get heap-allocated and the hashmap stores a pointer-as-i64.
    // Values that are integers/bool stored directly.
    NHashMap *m = (NHashMap *)(intptr_t)__nucleor_hashmap_new();
    if (!src) return (long long)(intptr_t)m;

    char section[256] = "";
    const char *p = src;
    char line[4096];

    while (*p) {
        // Read one line
        size_t n = 0;
        while (*p && *p != '\n' && n < sizeof(line) - 1) {
            line[n++] = *p++;
        }
        line[n] = 0;
        if (*p == '\n') p++;

        char *l = line;
        l = __nuc_toml_skip_ws(l);
        __nuc_toml_strip(l);
        if (*l == 0 || *l == '#') continue;

        if (*l == '[') {
            // Section header
            l++;
            char *e = strchr(l, ']');
            if (!e) continue;
            size_t slen = (size_t)(e - l);
            if (slen >= sizeof(section)) slen = sizeof(section) - 1;
            memcpy(section, l, slen);
            section[slen] = 0;
            // Trim section name
            char *s2 = section;
            while (*s2 == ' ' || *s2 == '\t') s2++;
            if (s2 != section) memmove(section, s2, strlen(s2) + 1);
            __nuc_toml_strip(section);
            continue;
        }

        // key = value
        char *eq = strchr(l, '=');
        if (!eq) continue;
        *eq = 0;
        char *key = l;
        char *val = eq + 1;
        __nuc_toml_strip(key);
        val = __nuc_toml_skip_ws(val);
        __nuc_toml_strip(val);

        // Build full key
        char fkey[512];
        if (section[0]) {
            snprintf(fkey, sizeof(fkey), "%s.%s", section, key);
        } else {
            snprintf(fkey, sizeof(fkey), "%s", key);
        }

        // Parse value
        if (*val == '"') {
            // String value — strip quotes
            char *vend = strrchr(val, '"');
            if (vend && vend > val) {
                *vend = 0;
                val++;
                size_t vlen = strlen(val);
                char *copy = (char *)malloc(vlen + 1);
                memcpy(copy, val, vlen + 1);
                __nucleor_hashmap_insert((long long)(intptr_t)m, fkey, (long long)(intptr_t)copy);
            }
        } else if (strcmp(val, "true") == 0) {
            __nucleor_hashmap_insert((long long)(intptr_t)m, fkey, 1);
        } else if (strcmp(val, "false") == 0) {
            __nucleor_hashmap_insert((long long)(intptr_t)m, fkey, 0);
        } else {
            // Integer (best effort)
            char *end;
            long long iv = strtoll(val, &end, 10);
            if (end != val) {
                __nucleor_hashmap_insert((long long)(intptr_t)m, fkey, iv);
            }
        }
    }

    return (long long)(intptr_t)m;
}

long long __nucleor_toml_parse_file(const char *path) {
    // v0.3.224: same ftell-CVE fix as v0.3.218's file_read_string.
    // Pre-fix if ftell returned -1 (seek error), (size_t)sz cast to
    // SIZE_MAX -> fread reads SIZE_MAX bytes into a 1-byte buffer.
    // CVE-class memory corruption.
    if (!path) return __nucleor_hashmap_new();
    FILE *f = fopen(path, "rb");
    if (!f) return __nucleor_hashmap_new();
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return __nucleor_hashmap_new(); }
    long sz = ftell(f);
    if (sz < 0) { fclose(f); return __nucleor_hashmap_new(); }
    if (fseek(f, 0, SEEK_SET) != 0) { fclose(f); return __nucleor_hashmap_new(); }
    char *buf = (char *)malloc((size_t)sz + 1);
    size_t n_read = fread(buf, 1, (size_t)sz, f);
    fclose(f);
    buf[n_read] = 0;
    long long m = __nucleor_toml_parse_string(buf);
    free(buf);
    return m;
}

// Helper to read a string value from the parsed hashmap.
long long __nucleor_toml_get_str(long long h, const char *key) {
    return __nucleor_hashmap_get(h, key);
}
long long __nucleor_toml_get_int(long long h, const char *key) {
    return __nucleor_hashmap_get(h, key);
}
long long __nucleor_toml_has(long long h, const char *key) {
    return __nucleor_hashmap_contains(h, key);
}

// === RFC-0019 phase 1: nuc.toml manifest validator ===
// Validates a parsed manifest map against the v0.2.0 schema.
// Returns a bitfield of issues, or 0 if all required fields present.
//
// Bits:
//   0x01  package.name missing
//   0x02  package.version missing
//   0x04  package.edition missing
//   0x08  package.license missing
//   0x10  package.version not semver-shaped (basic check: contains a dot)
//   0x20  edition not a known value
//
// Useful for CI / pre-commit / `nuc check` integrations.
long long __nucleor_manifest_validate(long long h) {
    if (h == 0) return 0xFF;  // empty map = everything missing
    long long issues = 0;
    if (__nucleor_hashmap_contains(h, "package.name") == 0)    issues |= 0x01;
    if (__nucleor_hashmap_contains(h, "package.version") == 0) issues |= 0x02;
    if (__nucleor_hashmap_contains(h, "package.edition") == 0) issues |= 0x04;
    if (__nucleor_hashmap_contains(h, "package.license") == 0) issues |= 0x08;
    // version semver shape check
    if ((issues & 0x02) == 0) {
        long long vptr = __nucleor_hashmap_get(h, "package.version");
        const char *v = (const char *)(intptr_t)vptr;
        if (v) {
            int dots = 0, c;
            for (c = 0; v[c]; c++) if (v[c] == '.') dots++;
            if (dots < 2) issues |= 0x10;
        }
    }
    // edition known value
    if ((issues & 0x04) == 0) {
        long long eptr = __nucleor_hashmap_get(h, "package.edition");
        const char *e = (const char *)(intptr_t)eptr;
        if (e && strcmp(e, "2026") != 0 && strcmp(e, "2027") != 0 && strcmp(e, "2028") != 0) {
            issues |= 0x20;
        }
    }
    return issues;
}

// Render a human-readable report of validation issues.
// Returns owned C-string; caller frees.
long long __nucleor_manifest_report(long long issues) {
    char buf[2048];
    int n = 0;
    if (issues == 0) {
        const char *ok = "manifest OK";
        size_t l = strlen(ok);
        char *out = (char *)malloc(l + 1);
        memcpy(out, ok, l + 1);
        return (long long)(intptr_t)out;
    }
    if (issues & 0x01) n += snprintf(buf + n, sizeof(buf) - (size_t)n, "missing required: package.name\n");
    if (issues & 0x02) n += snprintf(buf + n, sizeof(buf) - (size_t)n, "missing required: package.version\n");
    if (issues & 0x04) n += snprintf(buf + n, sizeof(buf) - (size_t)n, "missing required: package.edition\n");
    if (issues & 0x08) n += snprintf(buf + n, sizeof(buf) - (size_t)n, "missing required: package.license\n");
    if (issues & 0x10) n += snprintf(buf + n, sizeof(buf) - (size_t)n, "invalid: package.version is not semver-shaped (need MAJOR.MINOR.PATCH)\n");
    if (issues & 0x20) n += snprintf(buf + n, sizeof(buf) - (size_t)n, "invalid: package.edition unknown (expected 2026, 2027, or 2028)\n");
    char *out = (char *)malloc((size_t)n + 1);
    memcpy(out, buf, (size_t)n + 1);
    return (long long)(intptr_t)out;
}

// === Decisions §B5: byte-buffer + endian helpers ===
// Required for binary serialization (MessagePack, CBOR, MCAP, CDR,
// Protobuf wire format, network protocols).
// Builds atop NVecU8 (1-byte-per-element honest storage from v0.1.22).

long long __nucleor_buf_write_u8(long long h, long long v) {
    return __nucleor_vec_u8_push(h, v);
}
long long __nucleor_buf_write_u16_le(long long h, long long v) {
    __nucleor_vec_u8_push(h, v & 0xFFLL);
    __nucleor_vec_u8_push(h, (v >> 8) & 0xFFLL);
    return 0;
}
long long __nucleor_buf_write_u16_be(long long h, long long v) {
    __nucleor_vec_u8_push(h, (v >> 8) & 0xFFLL);
    __nucleor_vec_u8_push(h, v & 0xFFLL);
    return 0;
}
long long __nucleor_buf_write_u32_le(long long h, long long v) {
    __nucleor_vec_u8_push(h, v & 0xFFLL);
    __nucleor_vec_u8_push(h, (v >> 8) & 0xFFLL);
    __nucleor_vec_u8_push(h, (v >> 16) & 0xFFLL);
    __nucleor_vec_u8_push(h, (v >> 24) & 0xFFLL);
    return 0;
}
long long __nucleor_buf_write_u32_be(long long h, long long v) {
    __nucleor_vec_u8_push(h, (v >> 24) & 0xFFLL);
    __nucleor_vec_u8_push(h, (v >> 16) & 0xFFLL);
    __nucleor_vec_u8_push(h, (v >> 8) & 0xFFLL);
    __nucleor_vec_u8_push(h, v & 0xFFLL);
    return 0;
}
long long __nucleor_buf_write_u64_le(long long h, long long v) {
    int i;
    for (i = 0; i < 8; i++) __nucleor_vec_u8_push(h, (v >> (i * 8)) & 0xFFLL);
    return 0;
}
long long __nucleor_buf_write_u64_be(long long h, long long v) {
    int i;
    for (i = 7; i >= 0; i--) __nucleor_vec_u8_push(h, (v >> (i * 8)) & 0xFFLL);
    return 0;
}

// Read helpers — caller passes vec_u8 handle + offset.
long long __nucleor_buf_read_u8(long long h, long long off) {
    return __nucleor_vec_u8_get(h, off);
}
long long __nucleor_buf_read_u16_le(long long h, long long off) {
    long long lo = __nucleor_vec_u8_get(h, off);
    long long hi = __nucleor_vec_u8_get(h, off + 1);
    return (hi << 8) | lo;
}
long long __nucleor_buf_read_u16_be(long long h, long long off) {
    long long hi = __nucleor_vec_u8_get(h, off);
    long long lo = __nucleor_vec_u8_get(h, off + 1);
    return (hi << 8) | lo;
}
long long __nucleor_buf_read_u32_le(long long h, long long off) {
    long long b0 = __nucleor_vec_u8_get(h, off);
    long long b1 = __nucleor_vec_u8_get(h, off + 1);
    long long b2 = __nucleor_vec_u8_get(h, off + 2);
    long long b3 = __nucleor_vec_u8_get(h, off + 3);
    return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
}
long long __nucleor_buf_read_u32_be(long long h, long long off) {
    long long b0 = __nucleor_vec_u8_get(h, off);
    long long b1 = __nucleor_vec_u8_get(h, off + 1);
    long long b2 = __nucleor_vec_u8_get(h, off + 2);
    long long b3 = __nucleor_vec_u8_get(h, off + 3);
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
}
long long __nucleor_buf_read_u64_le(long long h, long long off) {
    long long r = 0;
    int i;
    for (i = 0; i < 8; i++) r |= __nucleor_vec_u8_get(h, off + i) << (i * 8);
    return r;
}
long long __nucleor_buf_read_u64_be(long long h, long long off) {
    long long r = 0;
    int i;
    for (i = 0; i < 8; i++) r = (r << 8) | __nucleor_vec_u8_get(h, off + i);
    return r;
}

// === MessagePack subset ===
// Common wire-format primitives.
long long __nucleor_msgpack_write_nil(long long h) {
    return __nucleor_vec_u8_push(h, 0xC0);
}
long long __nucleor_msgpack_write_bool(long long h, long long b) {
    return __nucleor_vec_u8_push(h, b ? 0xC3 : 0xC2);
}
long long __nucleor_msgpack_write_uint(long long h, long long v) {
    if (v < 0) v = 0;  // delegate signed via write_int
    if (v < 128) {
        return __nucleor_vec_u8_push(h, v);  // positive fixint
    } else if (v < 256) {
        __nucleor_vec_u8_push(h, 0xCC);
        return __nucleor_vec_u8_push(h, v);
    } else if (v < 65536) {
        __nucleor_vec_u8_push(h, 0xCD);
        return __nucleor_buf_write_u16_be(h, v);
    } else if (v < 4294967296LL) {
        __nucleor_vec_u8_push(h, 0xCE);
        return __nucleor_buf_write_u32_be(h, v);
    } else {
        __nucleor_vec_u8_push(h, 0xCF);
        return __nucleor_buf_write_u64_be(h, v);
    }
}

// === Hash + checksum helpers ===
// CRC32 (IEEE 802.3 polynomial), used by MCAP, ZIP, gzip.
long long __nucleor_crc32(const char *data, long long len) {
    if (!data) return 0;
    unsigned int crc = 0xFFFFFFFFU;
    long long i;
    for (i = 0; i < len; i++) {
        unsigned int b = (unsigned char)data[i];
        crc ^= b;
        int j;
        for (j = 0; j < 8; j++) {
            crc = (crc >> 1) ^ (0xEDB88320U & (-(int)(crc & 1U)));
        }
    }
    return (long long)(crc ^ 0xFFFFFFFFU);
}
long long __nucleor_crc32_update(long long crc, const char *data, long long len) {
    if (!data) return crc;
    unsigned int c = (unsigned int)crc ^ 0xFFFFFFFFU;
    long long i;
    for (i = 0; i < len; i++) {
        unsigned int b = (unsigned char)data[i];
        c ^= b;
        int j;
        for (j = 0; j < 8; j++) {
            c = (c >> 1) ^ (0xEDB88320U & (-(int)(c & 1U)));
        }
    }
    return (long long)(c ^ 0xFFFFFFFFU);
}

// SHA-256 — RFC-0019 package checksums + general hashing.
typedef struct {
    unsigned int state[8];
    unsigned long long bit_count;
    unsigned char buf[64];
    unsigned int buf_len;
} NucSha256Ctx;
static const unsigned int __nuc_sha256_k[64] = {
    0x428a2f98U,0x71374491U,0xb5c0fbcfU,0xe9b5dba5U,0x3956c25bU,0x59f111f1U,0x923f82a4U,0xab1c5ed5U,
    0xd807aa98U,0x12835b01U,0x243185beU,0x550c7dc3U,0x72be5d74U,0x80deb1feU,0x9bdc06a7U,0xc19bf174U,
    0xe49b69c1U,0xefbe4786U,0x0fc19dc6U,0x240ca1ccU,0x2de92c6fU,0x4a7484aaU,0x5cb0a9dcU,0x76f988daU,
    0x983e5152U,0xa831c66dU,0xb00327c8U,0xbf597fc7U,0xc6e00bf3U,0xd5a79147U,0x06ca6351U,0x14292967U,
    0x27b70a85U,0x2e1b2138U,0x4d2c6dfcU,0x53380d13U,0x650a7354U,0x766a0abbU,0x81c2c92eU,0x92722c85U,
    0xa2bfe8a1U,0xa81a664bU,0xc24b8b70U,0xc76c51a3U,0xd192e819U,0xd6990624U,0xf40e3585U,0x106aa070U,
    0x19a4c116U,0x1e376c08U,0x2748774cU,0x34b0bcb5U,0x391c0cb3U,0x4ed8aa4aU,0x5b9cca4fU,0x682e6ff3U,
    0x748f82eeU,0x78a5636fU,0x84c87814U,0x8cc70208U,0x90befffaU,0xa4506cebU,0xbef9a3f7U,0xc67178f2U
};
static unsigned int __nuc_rotr32(unsigned int x, unsigned int n) { return (x >> n) | (x << (32 - n)); }
static void __nuc_sha256_block(NucSha256Ctx *c, const unsigned char *block) {
    unsigned int w[64];
    int i;
    for (i = 0; i < 16; i++) {
        w[i] = ((unsigned int)block[i*4] << 24) | ((unsigned int)block[i*4+1] << 16) |
               ((unsigned int)block[i*4+2] << 8) | (unsigned int)block[i*4+3];
    }
    for (i = 16; i < 64; i++) {
        unsigned int s0 = __nuc_rotr32(w[i-15],7) ^ __nuc_rotr32(w[i-15],18) ^ (w[i-15]>>3);
        unsigned int s1 = __nuc_rotr32(w[i-2],17) ^ __nuc_rotr32(w[i-2],19) ^ (w[i-2]>>10);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }
    unsigned int a=c->state[0],b=c->state[1],cc=c->state[2],d=c->state[3];
    unsigned int e=c->state[4],f=c->state[5],g=c->state[6],h=c->state[7];
    for (i = 0; i < 64; i++) {
        unsigned int S1 = __nuc_rotr32(e,6) ^ __nuc_rotr32(e,11) ^ __nuc_rotr32(e,25);
        unsigned int ch = (e & f) ^ ((~e) & g);
        unsigned int t1 = h + S1 + ch + __nuc_sha256_k[i] + w[i];
        unsigned int S0 = __nuc_rotr32(a,2) ^ __nuc_rotr32(a,13) ^ __nuc_rotr32(a,22);
        unsigned int mj = (a & b) ^ (a & cc) ^ (b & cc);
        unsigned int t2 = S0 + mj;
        h=g; g=f; f=e; e=d+t1;
        d=cc; cc=b; b=a; a=t1+t2;
    }
    c->state[0]+=a; c->state[1]+=b; c->state[2]+=cc; c->state[3]+=d;
    c->state[4]+=e; c->state[5]+=f; c->state[6]+=g; c->state[7]+=h;
}
static void __nuc_sha256_init(NucSha256Ctx *c) {
    c->state[0]=0x6a09e667U; c->state[1]=0xbb67ae85U;
    c->state[2]=0x3c6ef372U; c->state[3]=0xa54ff53aU;
    c->state[4]=0x510e527fU; c->state[5]=0x9b05688cU;
    c->state[6]=0x1f83d9abU; c->state[7]=0x5be0cd19U;
    c->bit_count = 0;
    c->buf_len = 0;
}
static void __nuc_sha256_update(NucSha256Ctx *c, const unsigned char *data, size_t len) {
    c->bit_count += (unsigned long long)len * 8;
    while (len > 0) {
        size_t want = 64 - c->buf_len;
        size_t take = len < want ? len : want;
        memcpy(c->buf + c->buf_len, data, take);
        c->buf_len += (unsigned int)take;
        data += take;
        len -= take;
        if (c->buf_len == 64) { __nuc_sha256_block(c, c->buf); c->buf_len = 0; }
    }
}
static void __nuc_sha256_final(NucSha256Ctx *c, unsigned char out[32]) {
    unsigned long long bits = c->bit_count;
    c->buf[c->buf_len++] = 0x80;
    if (c->buf_len > 56) {
        while (c->buf_len < 64) c->buf[c->buf_len++] = 0;
        __nuc_sha256_block(c, c->buf);
        c->buf_len = 0;
    }
    while (c->buf_len < 56) c->buf[c->buf_len++] = 0;
    int i;
    for (i = 7; i >= 0; i--) c->buf[c->buf_len++] = (unsigned char)(bits >> (i * 8));
    __nuc_sha256_block(c, c->buf);
    for (i = 0; i < 8; i++) {
        out[i*4]   = (unsigned char)(c->state[i] >> 24);
        out[i*4+1] = (unsigned char)(c->state[i] >> 16);
        out[i*4+2] = (unsigned char)(c->state[i] >> 8);
        out[i*4+3] = (unsigned char)(c->state[i]);
    }
}
long long __nucleor_sha256_hex(const char *data) {
    NucSha256Ctx c;
    __nuc_sha256_init(&c);
    if (data) __nuc_sha256_update(&c, (const unsigned char *)data, strlen(data));
    unsigned char digest[32];
    __nuc_sha256_final(&c, digest);
    char *out = (char *)malloc(65);
    static const char *hexc = "0123456789abcdef";
    int i;
    for (i = 0; i < 32; i++) {
        out[i*2]   = hexc[digest[i] >> 4];
        out[i*2+1] = hexc[digest[i] & 0xF];
    }
    out[64] = 0;
    return (long long)(intptr_t)out;
}

// === Base64 (RFC 4648) ===
static const char *__nuc_b64_alpha =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

long long __nucleor_base64_encode(const char *data) {
    if (!data) { char *e = (char *)malloc(1); e[0] = 0; return (long long)(intptr_t)e; }
    size_t inlen = strlen(data);
    size_t outlen = ((inlen + 2) / 3) * 4;
    char *out = (char *)malloc(outlen + 1);
    size_t i, j = 0;
    for (i = 0; i + 2 < inlen; i += 3) {
        unsigned int v = ((unsigned int)(unsigned char)data[i] << 16)
                       | ((unsigned int)(unsigned char)data[i+1] << 8)
                       | (unsigned int)(unsigned char)data[i+2];
        out[j++] = __nuc_b64_alpha[(v >> 18) & 0x3F];
        out[j++] = __nuc_b64_alpha[(v >> 12) & 0x3F];
        out[j++] = __nuc_b64_alpha[(v >> 6)  & 0x3F];
        out[j++] = __nuc_b64_alpha[v & 0x3F];
    }
    if (i < inlen) {
        unsigned int v = (unsigned int)(unsigned char)data[i] << 16;
        if (i + 1 < inlen) v |= (unsigned int)(unsigned char)data[i+1] << 8;
        out[j++] = __nuc_b64_alpha[(v >> 18) & 0x3F];
        out[j++] = __nuc_b64_alpha[(v >> 12) & 0x3F];
        out[j++] = (i + 1 < inlen) ? __nuc_b64_alpha[(v >> 6) & 0x3F] : '=';
        out[j++] = '=';
    }
    out[j] = 0;
    return (long long)(intptr_t)out;
}

static int __nuc_b64_decode_char(char c) {
    if (c >= 'A' && c <= 'Z') return c - 'A';
    if (c >= 'a' && c <= 'z') return c - 'a' + 26;
    if (c >= '0' && c <= '9') return c - '0' + 52;
    if (c == '+') return 62;
    if (c == '/') return 63;
    return -1;
}
long long __nucleor_base64_decode(const char *data) {
    if (!data) { char *e = (char *)malloc(1); e[0] = 0; return (long long)(intptr_t)e; }
    size_t inlen = strlen(data);
    size_t outcap = (inlen / 4) * 3 + 4;
    char *out = (char *)malloc(outcap);
    size_t i = 0, j = 0;
    while (i + 3 < inlen) {
        int a = __nuc_b64_decode_char(data[i]);
        int b = __nuc_b64_decode_char(data[i+1]);
        int c = (data[i+2] == '=') ? 0 : __nuc_b64_decode_char(data[i+2]);
        int d = (data[i+3] == '=') ? 0 : __nuc_b64_decode_char(data[i+3]);
        if (a < 0 || b < 0 || c < 0 || d < 0) break;
        unsigned int v = (a << 18) | (b << 12) | (c << 6) | d;
        out[j++] = (char)((v >> 16) & 0xFF);
        if (data[i+2] != '=') out[j++] = (char)((v >> 8) & 0xFF);
        if (data[i+3] != '=') out[j++] = (char)(v & 0xFF);
        i += 4;
    }
    out[j] = 0;
    return (long long)(intptr_t)out;
}

// === UUID v4 (random-based, RFC 4122) ===
long long __nucleor_uuid_v4(void) {
    static int seeded = 0;
    if (!seeded) {
        srand((unsigned int)__nucleor_time_wall_seconds() ^ (unsigned int)(uintptr_t)&seeded);
        seeded = 1;
    }
    unsigned char b[16];
    int i;
    for (i = 0; i < 16; i++) b[i] = (unsigned char)(rand() & 0xFF);
    b[6] = (b[6] & 0x0F) | 0x40;  // version 4
    b[8] = (b[8] & 0x3F) | 0x80;  // variant 10
    char *out = (char *)malloc(37);
    static const char *hexc = "0123456789abcdef";
    int p = 0;
    for (i = 0; i < 16; i++) {
        if (i == 4 || i == 6 || i == 8 || i == 10) out[p++] = '-';
        out[p++] = hexc[b[i] >> 4];
        out[p++] = hexc[b[i] & 0xF];
    }
    out[36] = 0;
    return (long long)(intptr_t)out;
}

// === RFC-0007 partial: AtomicI64 — i64-cell atomic operations ===
// Backed by Win32 Interlocked* (msvc) or C11 stdatomic (POSIX).
// All ops use seq_cst ordering; relaxed/acquire/release variants
// land with full RFC-0007 in v0.5.
//
// Storage: malloc'd long long*. Handle is the pointer.
#ifdef _WIN32
#define NUC_AT_LOAD(p) ((long long)InterlockedCompareExchange64((LONG64 volatile*)(p), 0, 0))
#define NUC_AT_STORE(p, v) ((void)InterlockedExchange64((LONG64 volatile*)(p), (LONG64)(v)))
#define NUC_AT_ADD(p, v) ((long long)InterlockedExchangeAdd64((LONG64 volatile*)(p), (LONG64)(v)))
#define NUC_AT_SUB(p, v) ((long long)InterlockedExchangeAdd64((LONG64 volatile*)(p), -(LONG64)(v)))
#define NUC_AT_CAS(p, e, d) ((long long)InterlockedCompareExchange64((LONG64 volatile*)(p), (LONG64)(d), (LONG64)(e)))
#define NUC_AT_AND(p, v) ((long long)InterlockedAnd64((LONG64 volatile*)(p), (LONG64)(v)))
#define NUC_AT_OR(p, v)  ((long long)InterlockedOr64((LONG64 volatile*)(p), (LONG64)(v)))
#define NUC_AT_XOR(p, v) ((long long)InterlockedXor64((LONG64 volatile*)(p), (LONG64)(v)))
#define NUC_AT_SWAP(p, v) ((long long)InterlockedExchange64((LONG64 volatile*)(p), (LONG64)(v)))
#else
#include <stdatomic.h>
#define NUC_AT_LOAD(p) atomic_load((_Atomic long long *)(p))
#define NUC_AT_STORE(p, v) atomic_store((_Atomic long long *)(p), (v))
#define NUC_AT_ADD(p, v) atomic_fetch_add((_Atomic long long *)(p), (v))
#define NUC_AT_SUB(p, v) atomic_fetch_sub((_Atomic long long *)(p), (v))
#define NUC_AT_CAS(p, e, d) ({ long long __exp=(e); atomic_compare_exchange_strong((_Atomic long long *)(p), &__exp, (d)); __exp; })
#define NUC_AT_AND(p, v) atomic_fetch_and((_Atomic long long *)(p), (v))
#define NUC_AT_OR(p, v)  atomic_fetch_or((_Atomic long long *)(p), (v))
#define NUC_AT_XOR(p, v) atomic_fetch_xor((_Atomic long long *)(p), (v))
#define NUC_AT_SWAP(p, v) atomic_exchange((_Atomic long long *)(p), (v))
#endif

long long __nucleor_atomic_i64_new(long long initial) {
    long long *p = (long long *)malloc(sizeof(long long));
    *p = initial;
    return (long long)(intptr_t)p;
}
long long __nucleor_atomic_i64_free(long long h) {
    long long *p = (long long *)(intptr_t)h;
    if (p) free(p);
    return 0;
}
long long __nucleor_atomic_i64_load(long long h) {
    long long *p = (long long *)(intptr_t)h;
    if (!p) return 0;
    return NUC_AT_LOAD(p);
}
long long __nucleor_atomic_i64_store(long long h, long long v) {
    long long *p = (long long *)(intptr_t)h;
    if (!p) return 0;
    NUC_AT_STORE(p, v);
    return 0;
}
long long __nucleor_atomic_i64_fetch_add(long long h, long long v) {
    long long *p = (long long *)(intptr_t)h;
    if (!p) return 0;
    return NUC_AT_ADD(p, v);
}
long long __nucleor_atomic_i64_fetch_sub(long long h, long long v) {
    long long *p = (long long *)(intptr_t)h;
    if (!p) return 0;
    return NUC_AT_SUB(p, v);
}
long long __nucleor_atomic_i64_fetch_and(long long h, long long v) {
    long long *p = (long long *)(intptr_t)h;
    if (!p) return 0;
    return NUC_AT_AND(p, v);
}
long long __nucleor_atomic_i64_fetch_or(long long h, long long v) {
    long long *p = (long long *)(intptr_t)h;
    if (!p) return 0;
    return NUC_AT_OR(p, v);
}
long long __nucleor_atomic_i64_fetch_xor(long long h, long long v) {
    long long *p = (long long *)(intptr_t)h;
    if (!p) return 0;
    return NUC_AT_XOR(p, v);
}
long long __nucleor_atomic_i64_swap(long long h, long long v) {
    long long *p = (long long *)(intptr_t)h;
    if (!p) return 0;
    return NUC_AT_SWAP(p, v);
}
// CAS — returns the previous value. Caller compares vs `expected` for success.
long long __nucleor_atomic_i64_cas(long long h, long long expected, long long desired) {
    long long *p = (long long *)(intptr_t)h;
    if (!p) return 0;
    return NUC_AT_CAS(p, expected, desired);
}

// === Bit-twiddling primitives ===
long long __nucleor_popcount(long long v) {
    unsigned long long u = (unsigned long long)v;
    long long c = 0;
    while (u) { c += (long long)(u & 1ULL); u >>= 1; }
    return c;
}
long long __nucleor_leading_zeros(long long v) {
    if (v == 0) return 64;
    unsigned long long u = (unsigned long long)v;
    long long c = 0;
    while ((u & 0x8000000000000000ULL) == 0) { c++; u <<= 1; }
    return c;
}
long long __nucleor_trailing_zeros(long long v) {
    if (v == 0) return 64;
    unsigned long long u = (unsigned long long)v;
    long long c = 0;
    while ((u & 1ULL) == 0) { c++; u >>= 1; }
    return c;
}
long long __nucleor_byte_swap(long long v) {
    unsigned long long u = (unsigned long long)v;
    return (long long)(
        ((u & 0xFF00000000000000ULL) >> 56) |
        ((u & 0x00FF000000000000ULL) >> 40) |
        ((u & 0x0000FF0000000000ULL) >> 24) |
        ((u & 0x000000FF00000000ULL) >> 8)  |
        ((u & 0x00000000FF000000ULL) << 8)  |
        ((u & 0x0000000000FF0000ULL) << 24) |
        ((u & 0x000000000000FF00ULL) << 40) |
        ((u & 0x00000000000000FFULL) << 56)
    );
}
long long __nucleor_rotate_left(long long v, long long n) {
    unsigned long long u = (unsigned long long)v;
    n = n & 63;
    return (long long)((u << n) | (u >> (64 - n)));
}
long long __nucleor_rotate_right(long long v, long long n) {
    unsigned long long u = (unsigned long long)v;
    n = n & 63;
    return (long long)((u >> n) | (u << (64 - n)));
}
long long __nucleor_count_ones(long long v) {
    unsigned long long u = (unsigned long long)v;
    long long c = 0;
    while (u) { c += (long long)(u & 1ULL); u >>= 1; }
    return c;
}
long long __nucleor_count_zeros(long long v) {
    unsigned long long u = (unsigned long long)v;
    long long c = 64;
    while (u) { c -= (long long)(u & 1ULL); u >>= 1; }
    return c;
}

// === Comprehensive math primitives (i64 + f64) ===
// f64 values pass as i64 cells with bit-pattern in bits.

typedef union { double d; long long i; } NucF64Bits;
static double __nuc_b2d(long long b) { NucF64Bits u; u.i = b; return u.d; }
static long long __nuc_d2b(double d) { NucF64Bits u; u.d = d; return u.i; }

// ---- Bare-literal float plumbing ----
// Lexer encodes `1.5` as the integer 1500000 (int*1e6 + frac_millionths) and
// emits f64_from_scaled to decode. This bridges raw float literals to the
// f64-bit-pattern convention.
long long __nucleor_f64_from_scaled(long long scaled) {
    return __nuc_d2b((double)scaled / 1000000.0);
}

// v0.4.24 (NUC-FEEDBACK-002): f32 sibling of f64_from_scaled. Decode
// the scaled-int to a double, narrow to float, return the 32-bit IEEE
// bit pattern in the low 32 bits of an i64. Pre-v0.4.24 `1.0f32`
// literals routed through f64_from_scaled, storing the f64 bits of
// 1.0 (=0x3FF0000000000000) in Vec<f32> slots — when later read as
// f32 the upper 32 bits were truncated, leaving 0.
long long __nucleor_f32_from_scaled(long long scaled) {
    float f = (float)((double)scaled / 1000000.0);
    union { float f; unsigned int i; } u;
    u.f = f;
    return (long long)(unsigned long long)u.i;
}

// v0.3.125: NUC-IMPROVE-004 — explicit reinterpret of an i64
// holding an f64 bit pattern back to a typed f64. Identity at the
// runtime ABI level (Nucleor's f64 IS the i64 bit pattern), but
// the existence of a named helper documents intent and lets
// adopters convert `str_to_f64("1.25")` (which returns the i64 bit
// pattern) into the typed f64 needed by f64_add/f64_mul/etc. without
// reaching for a lossy `as f64` numeric cast (which would convert
// the LARGE bit-pattern integer numerically to ~4.6e18, not 1.25).
// f32 sibling has the same shape but only the lower 32 bits are
// meaningful; preserves the convention that f32 lives in the lower
// half of an i64 cell.
long long __nucleor_f64_from_bits(long long bits) {
    return bits;
}
long long __nucleor_f64_to_bits(long long f) {
    return f;
}
long long __nucleor_f32_from_bits(long long bits) {
    return bits;
}
long long __nucleor_f32_to_bits(long long f) {
    return f;
}
long long __nucleor_f64_to_i32(long long b) {
    double d = __nuc_b2d(b);
    if (d != d) return 0;  /* NaN -> 0 (Rust as semantic) */
    if (d >  2147483647.0)  return 2147483647LL;
    if (d < -2147483648.0) return -2147483648LL;
    return (long long)(int)d;
}
long long __nucleor_i32_to_f64(long long i) {
    return __nuc_d2b((double)(int)i);
}
// T1.1 Phase 4: f64 ↔ i64/u32 converters (saturating, Rust `as` semantics).
long long __nucleor_f64_to_i64(long long b) {
    double d = __nuc_b2d(b);
    if (d != d) return 0;  /* NaN -> 0 */
    if (d >  9223372036854775000.0) return 9223372036854775807LL;
    if (d < -9223372036854775000.0) return -9223372036854775807LL - 1LL;
    return (long long)d;
}
long long __nucleor_f64_to_u32(long long b) {
    double d = __nuc_b2d(b);
    if (d != d) return 0;  /* NaN -> 0 */
    if (d < 0.0) return 0;
    if (d > 4294967295.0) return 4294967295LL;
    return (long long)(unsigned int)d;
}
long long __nucleor_i64_to_f64(long long i) {
    return __nuc_d2b((double)i);
}
// v0.3.211: f64/f32 -> u64 saturating, completes the matrix needed
// to redesign `f64 as i64` / `f64 as u64` from no-op-bitcast to
// Rust `as` semantics (numeric truncation, saturating at the bound).
long long __nucleor_f64_to_u64(long long b) {
    double d = __nuc_b2d(b);
    if (d != d) return 0;  /* NaN -> 0 */
    if (d <= 0.0) return 0;
    if (d >= 18446744073709550000.0) return (long long)0xFFFFFFFFFFFFFFFFULL;
    return (long long)(unsigned long long)d;
}
long long __nucleor_f32_to_u64(long long a) {
    float f = __nuc_bits_to_f32(a);
    if (f != f) return 0;  /* NaN -> 0 */
    if (f <= 0.0f) return 0;
    if (f >= 18446744000000000000.0f) return (long long)0xFFFFFFFFFFFFFFFFULL;
    return (long long)(unsigned long long)f;
}
// Legacy unprefixed names referenced by the IR header for cross-compat.
long long __nucleor_fabs(long long b)  { return __nuc_d2b(fabs(__nuc_b2d(b))); }
long long __nucleor_fmod(long long a, long long b) { return __nuc_d2b(fmod(__nuc_b2d(a), __nuc_b2d(b))); }
long long __nucleor_sqrt(long long b)  { return __nuc_d2b(sqrt(__nuc_b2d(b))); }
long long __nucleor_sin(long long b)   { return __nuc_d2b(sin(__nuc_b2d(b))); }
long long __nucleor_cos(long long b)   { return __nuc_d2b(cos(__nuc_b2d(b))); }
long long __nucleor_pow(long long a, long long b) { return __nuc_d2b(pow(__nuc_b2d(a), __nuc_b2d(b))); }
long long __nucleor_floor(long long b) { return __nuc_d2b(floor(__nuc_b2d(b))); }
long long __nucleor_ceil(long long b)  { return __nuc_d2b(ceil(__nuc_b2d(b))); }
long long __nucleor_round(long long b) { return __nuc_d2b(round(__nuc_b2d(b))); }
long long __nucleor_exp(long long b)   { return __nuc_d2b(exp(__nuc_b2d(b))); }
long long __nucleor_log(long long b)   { return __nuc_d2b(log(__nuc_b2d(b))); }
long long __nucleor_sigmoid(long long b) {
    double d = __nuc_b2d(b);
    return __nuc_d2b(1.0 / (1.0 + exp(-d)));
}
long long __nucleor_tanh(long long b)  { return __nuc_d2b(tanh(__nuc_b2d(b))); }
long long __nucleor_relu(long long b)  {
    double d = __nuc_b2d(b);
    return __nuc_d2b(d > 0.0 ? d : 0.0);
}
long long __nucleor_gelu(long long b)  {
    double d = __nuc_b2d(b);
    double inner = 0.7978845608028654 * (d + 0.044715 * d * d * d);
    return __nuc_d2b(0.5 * d * (1.0 + tanh(inner)));
}
// ---- Closure capture table (v0.3.72) ----
// Each closure literal in the source is assigned a unique closure id
// at lower-time. Captured locals are slot-numbered within that closure.
// The codegen emits __nucleor_capture_set(clo_id, cap_id, value) at
// every callsite (right before the closure is invoked) and
// __nucleor_capture_get(clo_id, cap_id) once per capture at closure
// entry. The runtime stores each (clo_id, cap_id) → value in a flat
// 2D table.
//
// Threads-only concurrency model (per locked default): a closure is
// not thread-portable in v0.3.72. Calling the same closure from
// multiple threads with different capture values is undefined; lift
// captures into per-thread state instead. This is documented as a
// known v1 limitation in docs/v0.3-robotics-guide.md and matches the
// "threads-only" pause-default for the punchlist.
//
// Sizing rationale: 8192 closures × 32 captures × 8 bytes = 2 MB
// static. The s1 self-host has < 200 closures total; 8192 is a
// generous upper bound for production code (most rod modules have
// 0-30 closures). 32 captures-per-closure handles every realistic
// case (Rust's median is 1-3 captures; pathological hand-written
// code with > 32 captures is rare and can hit the runtime guard).
#define NUC_MAX_CLOSURES 8192
#define NUC_MAX_CAPTURES 32
static long long g_capture_table[NUC_MAX_CLOSURES][NUC_MAX_CAPTURES];

long long __nucleor_capture_set(long long clo_id, long long cap_id, long long value) {
    if (clo_id < 0 || clo_id >= NUC_MAX_CLOSURES) return 0;
    if (cap_id < 0 || cap_id >= NUC_MAX_CAPTURES) return 0;
    g_capture_table[clo_id][cap_id] = value;
    return value;
}

long long __nucleor_capture_get(long long clo_id, long long cap_id) {
    if (clo_id < 0 || clo_id >= NUC_MAX_CLOSURES) return 0;
    if (cap_id < 0 || cap_id >= NUC_MAX_CAPTURES) return 0;
    return g_capture_table[clo_id][cap_id];
}

long long __nucleor_abs(long long v)   { return v < 0 ? -v : v; }
long long __nucleor_min(long long a, long long b) { return a < b ? a : b; }
long long __nucleor_max(long long a, long long b) { return a > b ? a : b; }
long long __nucleor_clamp(long long v, long long lo, long long hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

// ---- Integer helpers ----
long long __nucleor_i64_abs(long long v) { return v < 0 ? -v : v; }
long long __nucleor_i64_min(long long a, long long b) { return a < b ? a : b; }
long long __nucleor_i64_max(long long a, long long b) { return a > b ? a : b; }
long long __nucleor_i64_clamp(long long v, long long lo, long long hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}
long long __nucleor_i64_sign(long long v) {
    if (v > 0) return 1;
    if (v < 0) return -1;
    return 0;
}
long long __nucleor_i64_pow(long long base, long long exp) {
    if (exp < 0) return 0;
    long long r = 1;
    while (exp > 0) {
        if (exp & 1) r *= base;
        base *= base;
        exp >>= 1;
    }
    return r;
}
long long __nucleor_i64_isqrt(long long n) {
    if (n < 0) return 0;
    if (n < 2) return n;
    long long lo = 0, hi = n;
    while (lo < hi) {
        long long mid = (lo + hi + 1) / 2;
        if (mid <= n / mid) lo = mid;
        else hi = mid - 1;
    }
    return lo;
}
long long __nucleor_i64_gcd(long long a, long long b) {
    if (a < 0) a = -a;
    if (b < 0) b = -b;
    while (b != 0) { long long t = b; b = a % b; a = t; }
    return a;
}
long long __nucleor_i64_lcm(long long a, long long b) {
    if (a == 0 || b == 0) return 0;
    long long g = __nucleor_i64_gcd(a, b);
    return (a / g) * b;
}

// ---- T1.1 Phase 5: native f64 arithmetic for inline + - * / ----
// Decode i64 bits to double, compute, re-encode. Pairs with the
// compiler's binop dispatcher in lower_expr (kind==4) which calls
// these when either operand has type f64.
long long __nucleor_f64_add(long long a, long long b) { return __nuc_d2b(__nuc_b2d(a) + __nuc_b2d(b)); }
long long __nucleor_f64_sub(long long a, long long b) { return __nuc_d2b(__nuc_b2d(a) - __nuc_b2d(b)); }
long long __nucleor_f64_mul(long long a, long long b) { return __nuc_d2b(__nuc_b2d(a) * __nuc_b2d(b)); }
long long __nucleor_f64_div(long long a, long long b) { return __nuc_d2b(__nuc_b2d(a) / __nuc_b2d(b)); }
long long __nucleor_f64_lt(long long a, long long b) { return __nuc_b2d(a) <  __nuc_b2d(b) ? 1 : 0; }
long long __nucleor_f64_gt(long long a, long long b) { return __nuc_b2d(a) >  __nuc_b2d(b) ? 1 : 0; }
long long __nucleor_f64_le(long long a, long long b) { return __nuc_b2d(a) <= __nuc_b2d(b) ? 1 : 0; }
long long __nucleor_f64_ge(long long a, long long b) { return __nuc_b2d(a) >= __nuc_b2d(b) ? 1 : 0; }
long long __nucleor_f64_eq(long long a, long long b) { return __nuc_b2d(a) == __nuc_b2d(b) ? 1 : 0; }
long long __nucleor_f64_ne(long long a, long long b) { return __nuc_b2d(a) != __nuc_b2d(b) ? 1 : 0; }

// ---- f64 transcendental + extended math ----
long long __nucleor_f64_sin(long long b) { return __nuc_d2b(sin(__nuc_b2d(b))); }
long long __nucleor_f64_cos(long long b) { return __nuc_d2b(cos(__nuc_b2d(b))); }
long long __nucleor_f64_tan(long long b) { return __nuc_d2b(tan(__nuc_b2d(b))); }
long long __nucleor_f64_asin(long long b) { return __nuc_d2b(asin(__nuc_b2d(b))); }
long long __nucleor_f64_acos(long long b) { return __nuc_d2b(acos(__nuc_b2d(b))); }
long long __nucleor_f64_atan(long long b) { return __nuc_d2b(atan(__nuc_b2d(b))); }
long long __nucleor_f64_atan2(long long y, long long x) {
    return __nuc_d2b(atan2(__nuc_b2d(y), __nuc_b2d(x)));
}
long long __nucleor_f64_sinh(long long b) { return __nuc_d2b(sinh(__nuc_b2d(b))); }
long long __nucleor_f64_cosh(long long b) { return __nuc_d2b(cosh(__nuc_b2d(b))); }
long long __nucleor_f64_tanh(long long b) { return __nuc_d2b(tanh(__nuc_b2d(b))); }
long long __nucleor_f64_exp(long long b) { return __nuc_d2b(exp(__nuc_b2d(b))); }
long long __nucleor_f64_exp2(long long b) { return __nuc_d2b(exp2(__nuc_b2d(b))); }
long long __nucleor_f64_log(long long b) { return __nuc_d2b(log(__nuc_b2d(b))); }
long long __nucleor_f64_log2(long long b) { return __nuc_d2b(log2(__nuc_b2d(b))); }
long long __nucleor_f64_log10(long long b) { return __nuc_d2b(log10(__nuc_b2d(b))); }
long long __nucleor_f64_pow_v(long long base, long long exp) {
    return __nuc_d2b(pow(__nuc_b2d(base), __nuc_b2d(exp)));
}
long long __nucleor_f64_floor(long long b) { return __nuc_d2b(floor(__nuc_b2d(b))); }
long long __nucleor_f64_ceil(long long b) { return __nuc_d2b(ceil(__nuc_b2d(b))); }
long long __nucleor_f64_round(long long b) { return __nuc_d2b(round(__nuc_b2d(b))); }
long long __nucleor_f64_trunc(long long b) { return __nuc_d2b(trunc(__nuc_b2d(b))); }
long long __nucleor_f64_fmod(long long a, long long b) {
    return __nuc_d2b(fmod(__nuc_b2d(a), __nuc_b2d(b)));
}
long long __nucleor_f64_hypot(long long a, long long b) {
    return __nuc_d2b(hypot(__nuc_b2d(a), __nuc_b2d(b)));
}
long long __nucleor_f64_clamp(long long v, long long lo, long long hi) {
    double dv = __nuc_b2d(v), dlo = __nuc_b2d(lo), dhi = __nuc_b2d(hi);
    if (dv < dlo) return lo;
    if (dv > dhi) return hi;
    return v;
}
long long __nucleor_f64_abs(long long b) {
    return __nuc_d2b(fabs(__nuc_b2d(b)));
}

// v0.3.230: NUC-IMPROVE-007 -- typed special functions for exact
// SciPy stats p-values. Adopter (ML Suite) needs erf/erfc/lgamma/
// gamma plus regularized incomplete beta and Student-t survival
// to ship parity with scipy.stats.ttest_*. C99 math.h provides erf,
// erfc, lgamma, tgamma directly. Incomplete beta + Student-t SF
// use Numerical Recipes continued-fraction algorithms (well-known,
// numerically stable for the typical p-value tail probabilities
// adopters compute).
long long __nucleor_f64_erf(long long b)    { return __nuc_d2b(erf(__nuc_b2d(b))); }
long long __nucleor_f64_erfc(long long b)   { return __nuc_d2b(erfc(__nuc_b2d(b))); }
long long __nucleor_f64_lgamma(long long b) { return __nuc_d2b(lgamma(__nuc_b2d(b))); }
long long __nucleor_f64_tgamma(long long b) { return __nuc_d2b(tgamma(__nuc_b2d(b))); }

/* Regularized incomplete beta I_x(a, b) via Numerical Recipes 6.4
   (Lentz's continued-fraction algorithm). Stable for x in [0,1] and
   moderate a,b (the regime adopter stats code uses).

   Returns NaN bits on invalid input (a<=0, b<=0, x not in [0,1]). */
static double __nuc_betacf(double a, double b, double x) {
    int i, m;
    double aa, c, d, del, h, qab, qam, qap;
    qab = a + b; qap = a + 1.0; qam = a - 1.0;
    c = 1.0;
    d = 1.0 - qab * x / qap;
    if (fabs(d) < 1e-300) d = 1e-300;
    d = 1.0 / d;
    h = d;
    for (i = 1; i <= 200; i++) {
        m = i;
        aa = (double)m * (b - m) * x / ((qam + 2.0 * m) * (a + 2.0 * m));
        d = 1.0 + aa * d;
        if (fabs(d) < 1e-300) d = 1e-300;
        c = 1.0 + aa / c;
        if (fabs(c) < 1e-300) c = 1e-300;
        d = 1.0 / d;
        h *= d * c;
        aa = -(a + m) * (qab + m) * x / ((a + 2.0 * m) * (qap + 2.0 * m));
        d = 1.0 + aa * d;
        if (fabs(d) < 1e-300) d = 1e-300;
        c = 1.0 + aa / c;
        if (fabs(c) < 1e-300) c = 1e-300;
        d = 1.0 / d;
        del = d * c;
        h *= del;
        if (fabs(del - 1.0) < 3e-7) break;
    }
    return h;
}
static double __nuc_betai(double a, double b, double x) {
    if (a <= 0.0 || b <= 0.0) return 0.0/0.0;       /* NaN */
    if (x < 0.0 || x > 1.0)   return 0.0/0.0;
    if (x == 0.0 || x == 1.0) return x;
    double bt = exp(lgamma(a + b) - lgamma(a) - lgamma(b)
                   + a * log(x) + b * log(1.0 - x));
    if (x < (a + 1.0) / (a + b + 2.0)) {
        return bt * __nuc_betacf(a, b, x) / a;
    }
    return 1.0 - bt * __nuc_betacf(b, a, 1.0 - x) / b;
}

/* Regularized incomplete beta I_x(a, b). User-facing helper. */
long long __nucleor_f64_betainc(long long x_b, long long a_b, long long b_b) {
    return __nuc_d2b(__nuc_betai(__nuc_b2d(a_b), __nuc_b2d(b_b), __nuc_b2d(x_b)));
}

/* Student-t two-sided survival function: P(|T| > t) = I_{df/(df+t^2)}(df/2, 1/2).
   Useful for `scipy.stats.ttest_1samp.pvalue` two-sided. */
long long __nucleor_f64_student_t_sf2(long long t_b, long long df_b) {
    double t = __nuc_b2d(t_b);
    double df = __nuc_b2d(df_b);
    if (df <= 0.0) return __nuc_d2b(0.0/0.0);
    double x = df / (df + t * t);
    return __nuc_d2b(__nuc_betai(0.5 * df, 0.5, x));
}

/* Standard normal CDF: 0.5 * erfc(-x / sqrt(2)). */
long long __nucleor_f64_norm_cdf(long long x_b) {
    double x = __nuc_b2d(x_b);
    return __nuc_d2b(0.5 * erfc(-x * 0.7071067811865476));
}

/* Standard normal survival function: 1 - cdf = 0.5 * erfc(x / sqrt(2)). */
long long __nucleor_f64_norm_sf(long long x_b) {
    double x = __nuc_b2d(x_b);
    return __nuc_d2b(0.5 * erfc(x * 0.7071067811865476));
}
long long __nucleor_f64_min(long long a, long long b) {
    double da = __nuc_b2d(a), db = __nuc_b2d(b);
    return __nuc_d2b(da < db ? da : db);
}
long long __nucleor_f64_max(long long a, long long b) {
    double da = __nuc_b2d(a), db = __nuc_b2d(b);
    return __nuc_d2b(da > db ? da : db);
}
long long __nucleor_f64_sign(long long b) {
    double d = __nuc_b2d(b);
    if (d > 0.0) return __nuc_d2b(1.0);
    if (d < 0.0) return __nuc_d2b(-1.0);
    return __nuc_d2b(0.0);
}
long long __nucleor_f64_copy_sign(long long a, long long b) {
    return __nuc_d2b(copysign(__nuc_b2d(a), __nuc_b2d(b)));
}
long long __nucleor_f64_lerp(long long a, long long b, long long t) {
    double da = __nuc_b2d(a), db = __nuc_b2d(b), dt = __nuc_b2d(t);
    return __nuc_d2b(da + (db - da) * dt);
}
long long __nucleor_f64_is_nan(long long b) {
    double d = __nuc_b2d(b);
    return (d != d) ? 1 : 0;
}
long long __nucleor_f64_is_inf(long long b) {
    double d = __nuc_b2d(b);
    if (d == d * 2 && d != 0.0) return 1;
    return 0;
}
long long __nucleor_f64_is_finite(long long b) {
    if (__nucleor_f64_is_nan(b)) return 0;
    if (__nucleor_f64_is_inf(b)) return 0;
    return 1;
}

// Constants
long long __nucleor_f64_pi(void)      { return __nuc_d2b(3.14159265358979323846); }
long long __nucleor_f64_tau(void)     { return __nuc_d2b(6.28318530717958647692); }
long long __nucleor_f64_e(void)       { return __nuc_d2b(2.71828182845904523536); }
long long __nucleor_f64_sqrt2(void)   { return __nuc_d2b(1.41421356237309504880); }
long long __nucleor_f64_ln2(void)     { return __nuc_d2b(0.69314718055994530942); }
long long __nucleor_f64_ln10(void)    { return __nuc_d2b(2.30258509299404568402); }

// Degree/radian conversion
long long __nucleor_f64_deg_to_rad(long long b) {
    return __nuc_d2b(__nuc_b2d(b) * 3.14159265358979323846 / 180.0);
}
long long __nucleor_f64_rad_to_deg(long long b) {
    return __nuc_d2b(__nuc_b2d(b) * 180.0 / 3.14159265358979323846);
}

long long __nucleor_msgpack_write_str(long long h, const char *s) {
    if (!s) {
        __nucleor_vec_u8_push(h, 0xA0);  // empty fixstr
        return 0;
    }
    size_t len = strlen(s);
    if (len < 32) {
        __nucleor_vec_u8_push(h, 0xA0 | (long long)len);
    } else if (len < 256) {
        __nucleor_vec_u8_push(h, 0xD9);
        __nucleor_vec_u8_push(h, (long long)len);
    } else if (len < 65536) {
        __nucleor_vec_u8_push(h, 0xDA);
        __nucleor_buf_write_u16_be(h, (long long)len);
    } else {
        __nucleor_vec_u8_push(h, 0xDB);
        __nucleor_buf_write_u32_be(h, (long long)len);
    }
    size_t i;
    for (i = 0; i < len; i++) __nucleor_vec_u8_push(h, (long long)(unsigned char)s[i]);
    return 0;
}

// === RFC-0015 phase 6: bf16 / f16 / f8 software emulation ===
// All packed in low N bits of i64 storage. Compute happens at f32 precision
// via convert-up / convert-down round-trip.
static inline long long __nuc_bf16_to_f32_bits(long long b) {
    return (b & 0xFFFFLL) << 16;  // bf16 bit pattern is the high 16 bits of f32
}
static inline long long __nuc_f32_to_bf16_bits(long long f) {
    // Round-to-nearest-even
    unsigned int x = (unsigned int)(f & 0xFFFFFFFFLL);
    unsigned int rounding_bias = 0x00007FFF + ((x >> 16) & 1);
    return (long long)((x + rounding_bias) >> 16);
}
long long __nucleor_bf16_from_f32(long long f32_bits) { return __nuc_f32_to_bf16_bits(f32_bits); }
long long __nucleor_bf16_to_f32(long long bf) { return __nuc_bf16_to_f32_bits(bf); }
long long __nucleor_bf16_add(long long a, long long b) {
    return __nuc_f32_to_bf16_bits(__nucleor_f32_add(__nuc_bf16_to_f32_bits(a), __nuc_bf16_to_f32_bits(b)));
}
long long __nucleor_bf16_mul(long long a, long long b) {
    return __nuc_f32_to_bf16_bits(__nucleor_f32_mul(__nuc_bf16_to_f32_bits(a), __nuc_bf16_to_f32_bits(b)));
}

// f16 (IEEE 754 binary16): 1 sign + 5 exp + 10 mantissa
static inline long long __nuc_f16_to_f32_bits(long long h) {
    unsigned int half = (unsigned int)(h & 0xFFFFLL);
    unsigned int sign = (half >> 15) & 0x1;
    unsigned int exp = (half >> 10) & 0x1F;
    unsigned int mant = half & 0x3FF;
    unsigned int f32;
    if (exp == 0) {
        if (mant == 0) {
            f32 = sign << 31;
        } else {
            // subnormal — normalize
            int e = -1;
            while (!(mant & 0x400)) { mant <<= 1; e--; }
            mant &= 0x3FF;
            f32 = (sign << 31) | ((unsigned int)(127 - 15 + e + 1) << 23) | (mant << 13);
        }
    } else if (exp == 31) {
        // inf / NaN
        f32 = (sign << 31) | (0xFFu << 23) | (mant << 13);
    } else {
        f32 = (sign << 31) | ((exp + (127 - 15)) << 23) | (mant << 13);
    }
    return (long long)f32;
}
static inline long long __nuc_f32_to_f16_bits(long long f) {
    unsigned int x = (unsigned int)(f & 0xFFFFFFFFLL);
    unsigned int sign = (x >> 31) & 0x1;
    int exp = (int)((x >> 23) & 0xFF) - 127 + 15;
    unsigned int mant = x & 0x7FFFFF;
    unsigned int half;
    if (exp <= 0) {
        if (exp < -10) {
            half = sign << 15;
        } else {
            mant = (mant | 0x800000) >> (1 - exp);
            half = (sign << 15) | (mant >> 13);
        }
    } else if (exp >= 31) {
        half = (sign << 15) | (0x1F << 10);
    } else {
        half = (sign << 15) | ((unsigned int)exp << 10) | (mant >> 13);
    }
    return (long long)half;
}
long long __nucleor_f16_from_f32(long long f32_bits) { return __nuc_f32_to_f16_bits(f32_bits); }
long long __nucleor_f16_to_f32(long long h) { return __nuc_f16_to_f32_bits(h); }
long long __nucleor_f16_add(long long a, long long b) {
    return __nuc_f32_to_f16_bits(__nucleor_f32_add(__nuc_f16_to_f32_bits(a), __nuc_f16_to_f32_bits(b)));
}
long long __nucleor_f16_mul(long long a, long long b) {
    return __nuc_f32_to_f16_bits(__nucleor_f32_mul(__nuc_f16_to_f32_bits(a), __nuc_f16_to_f32_bits(b)));
}

// f8e4m3 (NVIDIA Hopper format): 1 sign + 4 exp + 3 mantissa
// Range ~±240, min normal ~2^-6
static inline long long __nuc_f8e4m3_to_f32_bits(long long b) {
    unsigned int x = (unsigned int)(b & 0xFFLL);
    unsigned int sign = (x >> 7) & 0x1;
    unsigned int exp = (x >> 3) & 0xF;
    unsigned int mant = x & 0x7;
    unsigned int f32;
    if (exp == 0 && mant == 0) {
        f32 = sign << 31;
    } else if (exp == 0xF && mant == 0x7) {
        // NaN per OFP8 spec
        f32 = (sign << 31) | 0x7FC00000;
    } else if (exp == 0) {
        // subnormal — fall back to f32 representation directly
        // value = ±mant × 2^-9
        union { float f; unsigned int u; } cv;
        cv.f = (float)mant * 0.001953125f;  // 2^-9
        if (sign) cv.f = -cv.f;
        f32 = cv.u;
    } else {
        // normal
        f32 = (sign << 31) | ((exp + (127 - 7)) << 23) | (mant << 20);
    }
    return (long long)f32;
}

// f8e5m2 (NVIDIA Hopper format): 1 sign + 5 exp + 2 mantissa
// Range ~±57344, supports inf and NaN
static inline long long __nuc_f8e5m2_to_f32_bits(long long b) {
    unsigned int x = (unsigned int)(b & 0xFFLL);
    unsigned int sign = (x >> 7) & 0x1;
    unsigned int exp = (x >> 2) & 0x1F;
    unsigned int mant = x & 0x3;
    unsigned int f32;
    if (exp == 0 && mant == 0) {
        f32 = sign << 31;
    } else if (exp == 0x1F) {
        // inf / NaN
        f32 = (sign << 31) | (0xFFu << 23) | (mant << 21);
    } else if (exp == 0) {
        union { float f; unsigned int u; } cv;
        cv.f = (float)mant * 0.0000152587890625f;  // 2^-16
        if (sign) cv.f = -cv.f;
        f32 = cv.u;
    } else {
        f32 = (sign << 31) | ((exp + (127 - 15)) << 23) | (mant << 21);
    }
    return (long long)f32;
}

long long __nucleor_f8e4m3_to_f32(long long v) { return __nuc_f8e4m3_to_f32_bits(v); }
long long __nucleor_f8e5m2_to_f32(long long v) { return __nuc_f8e5m2_to_f32_bits(v); }

// v0.3.206: NUC-FEEDBACK-002 follow-on -- pack helpers for f8e4m3
// and f8e5m2, plus display helpers for f16/bf16/f8e4m3/f8e5m2.
// Pre-fix the narrow-float family had asymmetric runtime support
// (read-only for f8eXmY, no display for any), which kept Vec<f16>/
// Vec<bf16>/Vec<f8eXmY> behind the TYP-009 hard error.
//
// f8e4m3 layout: 1 sign + 4 exp + 3 mantissa, bias 7 (NVIDIA Hopper)
// f8e5m2 layout: 1 sign + 5 exp + 2 mantissa, bias 15 (NVIDIA Hopper)

// v0.3.209: NUC-FEEDBACK-002 follow-on -- f8eXmY pack precision.
// Pre-fix used round-to-zero (truncation, mant >> 20). Now uses
// round-to-nearest-even (the IEEE-754 rounding mode adopters
// expect for ML quantization), and preserves NaN / +inf / -inf
// from the f32 input to the f8 output (per OFP8 spec / NVIDIA
// Hopper convention).
//
// f8e4m3: max exp 0xF + max mant 0x7 = NaN (no inf -- saturates
//         at S1111110 = ±448 for finite-overflow input).
// f8e5m2: max exp 0x1F + zero mant = ±inf, max exp + nonzero
//         mant = NaN.
static inline long long __nuc_f32_to_f8e4m3_bits(long long f) {
    unsigned int x = (unsigned int)(f & 0xFFFFFFFFLL);
    unsigned int sign = (x >> 31) & 0x1;
    unsigned int f32_exp = (x >> 23) & 0xFF;
    unsigned int mant = x & 0x7FFFFF;
    unsigned int e4m3;
    // NaN preservation: f32 NaN (exp=0xFF, mant!=0) -> f8e4m3 NaN.
    if (f32_exp == 0xFF) {
        if (mant != 0) {
            e4m3 = (sign << 7) | (0xF << 3) | 0x7;  // S1111111 = NaN
        } else {
            // f32 inf saturates to +/-MAX (f8e4m3 has no inf).
            e4m3 = (sign << 7) | (0xF << 3) | 0x6;  // ±448
        }
        return (long long)(e4m3 & 0xFF);
    }
    int exp = (int)f32_exp - 127 + 7;  // f8e4m3 bias = 7
    if (exp <= 0) {
        // Subnormal or underflow.
        if (exp < -3) { e4m3 = sign << 7; }
        else {
            // Round-to-nearest-even (RNE) on the shifted mantissa.
            unsigned int full_m = mant | 0x800000;
            int sh = 21 + (1 - exp);
            unsigned int round = (full_m >> (sh - 1)) & 0x1;
            unsigned int sticky = (full_m & ((1u << (sh - 1)) - 1)) ? 1 : 0;
            unsigned int truncated = full_m >> sh;
            unsigned int rounded = truncated + ((round && (sticky || (truncated & 1))) ? 1 : 0);
            e4m3 = (sign << 7) | (rounded & 0x7);
        }
    } else if (exp >= 16) {
        // Finite-overflow -> saturate at +/-MAX = ±448 (no inf in e4m3).
        e4m3 = (sign << 7) | (0xF << 3) | 0x6;
    } else {
        // Normal: RNE on the 20-bit-wider mantissa.
        unsigned int round = (mant >> 19) & 0x1;
        unsigned int sticky = (mant & 0x7FFFF) ? 1 : 0;
        unsigned int truncated = mant >> 20;
        unsigned int rounded = truncated + ((round && (sticky || (truncated & 1))) ? 1 : 0);
        // Mantissa carry-out: rounded = 8 means we incremented past 0x7;
        // treat as carry into exponent.
        if (rounded > 0x7) { exp = exp + 1; rounded = 0; }
        if (exp >= 16) { e4m3 = (sign << 7) | (0xF << 3) | 0x6; }
        else if (exp >= 0xF && rounded >= 0x7) {
            // Would land on the NaN slot S1111111: saturate to MAX instead.
            e4m3 = (sign << 7) | (0xF << 3) | 0x6;
        } else {
            e4m3 = (sign << 7) | ((unsigned int)exp << 3) | rounded;
        }
    }
    return (long long)(e4m3 & 0xFF);
}

static inline long long __nuc_f32_to_f8e5m2_bits(long long f) {
    unsigned int x = (unsigned int)(f & 0xFFFFFFFFLL);
    unsigned int sign = (x >> 31) & 0x1;
    unsigned int f32_exp = (x >> 23) & 0xFF;
    unsigned int mant = x & 0x7FFFFF;
    unsigned int e5m2;
    // NaN / inf preservation.
    if (f32_exp == 0xFF) {
        if (mant != 0) {
            e5m2 = (sign << 7) | (0x1F << 2) | 0x1;  // NaN payload
        } else {
            e5m2 = (sign << 7) | (0x1F << 2);  // ±inf
        }
        return (long long)(e5m2 & 0xFF);
    }
    int exp = (int)f32_exp - 127 + 15;  // f8e5m2 bias = 15
    if (exp <= 0) {
        if (exp < -2) { e5m2 = sign << 7; }
        else {
            unsigned int full_m = mant | 0x800000;
            int sh = 22 + (1 - exp);
            unsigned int round = (full_m >> (sh - 1)) & 0x1;
            unsigned int sticky = (full_m & ((1u << (sh - 1)) - 1)) ? 1 : 0;
            unsigned int truncated = full_m >> sh;
            unsigned int rounded = truncated + ((round && (sticky || (truncated & 1))) ? 1 : 0);
            e5m2 = (sign << 7) | (rounded & 0x3);
        }
    } else if (exp >= 31) {
        // Overflow -> inf
        e5m2 = (sign << 7) | (0x1F << 2);
    } else {
        // Normal: RNE on 21-bit-wider mantissa.
        unsigned int round = (mant >> 20) & 0x1;
        unsigned int sticky = (mant & 0xFFFFF) ? 1 : 0;
        unsigned int truncated = mant >> 21;
        unsigned int rounded = truncated + ((round && (sticky || (truncated & 1))) ? 1 : 0);
        if (rounded > 0x3) { exp = exp + 1; rounded = 0; }
        if (exp >= 31) { e5m2 = (sign << 7) | (0x1F << 2); }
        else { e5m2 = (sign << 7) | ((unsigned int)exp << 2) | rounded; }
    }
    return (long long)(e5m2 & 0xFF);
}

long long __nucleor_f8e4m3_from_f32(long long f32_bits) {
    return __nuc_f32_to_f8e4m3_bits(f32_bits);
}
long long __nucleor_f8e5m2_from_f32(long long f32_bits) {
    return __nuc_f32_to_f8e5m2_bits(f32_bits);
}

// Display helpers: convert to f32, reinterpret as float, print %g.
const char *__nucleor_f16_to_str(long long b) {
    long long f32_bits = __nuc_f16_to_f32_bits(b);
    union { unsigned int i; float f; } u; u.i = (unsigned int)(f32_bits & 0xFFFFFFFFLL);
    char buf[64]; snprintf(buf, sizeof(buf), "%g", (double)u.f);
    size_t L = strlen(buf); char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1); return out;
}
const char *__nucleor_bf16_to_str(long long b) {
    long long f32_bits = __nuc_bf16_to_f32_bits(b);
    union { unsigned int i; float f; } u; u.i = (unsigned int)(f32_bits & 0xFFFFFFFFLL);
    char buf[64]; snprintf(buf, sizeof(buf), "%g", (double)u.f);
    size_t L = strlen(buf); char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1); return out;
}
const char *__nucleor_f8e4m3_to_str(long long b) {
    long long f32_bits = __nuc_f8e4m3_to_f32_bits(b);
    union { unsigned int i; float f; } u; u.i = (unsigned int)(f32_bits & 0xFFFFFFFFLL);
    char buf[64]; snprintf(buf, sizeof(buf), "%g", (double)u.f);
    size_t L = strlen(buf); char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1); return out;
}
const char *__nucleor_f8e5m2_to_str(long long b) {
    long long f32_bits = __nuc_f8e5m2_to_f32_bits(b);
    union { unsigned int i; float f; } u; u.i = (unsigned int)(f32_bits & 0xFFFFFFFFLL);
    char buf[64]; snprintf(buf, sizeof(buf), "%g", (double)u.f);
    size_t L = strlen(buf); char *out = (char *)malloc(L + 1);
    memcpy(out, buf, L + 1); return out;
}

// === Option<T> / Result<T,E> method helpers (v0.4.90) ===
// Layout: Option<T> and Result<T,E> are both lowered to NVec* of i64
// cells with [0] = tag, [1] = payload. Tag conventions per
// nucleor_s1_compiler.nr line 6752 / 6764-6767:
//   Option: Some=0, None=1
//   Result: Ok=1,    Err=0
// These helpers let `opt.unwrap()` / `res.is_ok()` etc. dispatch from
// the compiler's method-name → str_concat("option_"/"result_", mname)
// without needing inline IR for each method.
long long __nucleor_option_unwrap(NVec *opt) {
    // v0.6.33 (probe finding 2026-05-02-result-option-unwrap-diag-and-
    // correctness-gaps, gap 1): pre-fix this read vec_get(opt, 1)
    // unconditionally — for `None` (len-1 Vec) the read was OOB and
    // panicked with `vec_get OOB: index 1, len 1` (v0.6.30 reworded
    // to `index out of bounds: the len is 1 but the index is 1`),
    // both leak the internal Vec representation. Now check the
    // discriminant first and panic with the canonical Rust message.
    if (!opt || opt->len < 2 || __nucleor_vec_get(opt, 0) != 0) {
        fprintf(stderr, "PANIC: called `Option::unwrap()` on a `None` value\n");
        fflush(stderr);
        exit(1);
    }
    return __nucleor_vec_get(opt, 1);
}
long long __nucleor_option_unwrap_or(NVec *opt, long long def) {
    if (__nucleor_vec_get(opt, 0) == 0) return __nucleor_vec_get(opt, 1);
    return def;
}
long long __nucleor_option_is_some(NVec *opt) {
    return __nucleor_vec_get(opt, 0) == 0 ? 1 : 0;
}
long long __nucleor_option_is_none(NVec *opt) {
    return __nucleor_vec_get(opt, 0) != 0 ? 1 : 0;
}
long long __nucleor_result_unwrap(NVec *res) {
    // v0.6.33 (probe finding 2026-05-02-result-option-unwrap-diag-and-
    // correctness-gaps, gap 2 — CRITICAL): pre-fix this read
    // vec_get(res, 1) unconditionally — for `Err(x)` (Result tag 0)
    // the err payload was returned silently as if it were the ok
    // payload. NO discriminant check, NO panic, NO diagnostic.
    // Adopters got garbage data and the program continued —
    // catastrophic correctness bug. Now check the discriminant
    // first and panic with the canonical Rust message.
    //
    // Result tag convention (per __nucleor_result_is_ok / is_err
    // and the compiler's lowering at line 20060+): Ok=1, Err=0.
    if (!res || res->len < 2 || __nucleor_vec_get(res, 0) != 1) {
        fprintf(stderr, "PANIC: called `Result::unwrap()` on an `Err` value\n");
        fflush(stderr);
        exit(1);
    }
    return __nucleor_vec_get(res, 1);
}
long long __nucleor_result_unwrap_or(NVec *res, long long def) {
    if (__nucleor_vec_get(res, 0) == 1) return __nucleor_vec_get(res, 1);
    return def;
}
long long __nucleor_result_is_ok(NVec *res) {
    return __nucleor_vec_get(res, 0) == 1 ? 1 : 0;
}
long long __nucleor_result_is_err(NVec *res) {
    return __nucleor_vec_get(res, 0) != 1 ? 1 : 0;
}
long long __nucleor_result_ok(NVec *res) {
    return __nucleor_vec_get(res, 1);
}
long long __nucleor_result_err(NVec *res) {
    return __nucleor_vec_get(res, 1);
}
// v0.6.34 (probe finding 2026-05-02-result-option-unwrap-diag-and-
// correctness-gaps, gap 3): pre-fix `Result::unwrap_err()` was not
// implemented — calls failed at link with TYP-005. Mirror of
// __nucleor_result_unwrap with inverted discriminant: panics on Ok,
// returns the err payload on Err.
long long __nucleor_result_unwrap_err(NVec *res) {
    if (!res || res->len < 2 || __nucleor_vec_get(res, 0) != 0) {
        fprintf(stderr, "PANIC: called `Result::unwrap_err()` on an `Ok` value\n");
        fflush(stderr);
        exit(1);
    }
    return __nucleor_vec_get(res, 1);
}
long long __nucleor_option_expect(NVec *opt, const char *msg) {
    if (__nucleor_vec_get(opt, 0) != 0) {
        fprintf(stderr, "PANIC: %s\n", msg ? msg : "expect on None");
        exit(1);
    }
    return __nucleor_vec_get(opt, 1);
}
long long __nucleor_result_expect(NVec *res, const char *msg) {
    if (__nucleor_vec_get(res, 0) != 1) {
        fprintf(stderr, "PANIC: %s\n", msg ? msg : "expect on Err");
        exit(1);
    }
    return __nucleor_vec_get(res, 1);
}

// === Option/Result fn-arg helpers (v0.4.92) ===
// Same fn_ptr ABI as vec_map_i64 (i64 → i64 via cast). Tag layout
// per v0.4.90 helpers above.
NVec *__nucleor_option_map(NVec *opt, long long fn_ptr) {
    if (!opt || !fn_ptr) return opt;
    NVec *out = __nucleor_vec_new();
    if (__nucleor_vec_get(opt, 0) == 0) {
        long long (*fn)(long long) = (long long (*)(long long))(void *)(intptr_t)fn_ptr;
        long long mapped = fn(__nucleor_vec_get(opt, 1));
        __nucleor_vec_push(out, 0); // Some tag
        __nucleor_vec_push(out, mapped);
    } else {
        __nucleor_vec_push(out, 1); // None tag
    }
    return out;
}
NVec *__nucleor_option_and_then(NVec *opt, long long fn_ptr) {
    // f returns Option<U>; if Some, call f on payload and return f's result.
    if (!opt || !fn_ptr) return opt;
    if (__nucleor_vec_get(opt, 0) == 0) {
        NVec *(*fn)(long long) = (NVec *(*)(long long))(void *)(intptr_t)fn_ptr;
        return fn(__nucleor_vec_get(opt, 1));
    }
    NVec *out = __nucleor_vec_new();
    __nucleor_vec_push(out, 1);
    return out;
}
long long __nucleor_option_unwrap_or_else(NVec *opt, long long fn_ptr) {
    if (opt && __nucleor_vec_get(opt, 0) == 0) return __nucleor_vec_get(opt, 1);
    if (!fn_ptr) return 0;
    long long (*fn)(void) = (long long (*)(void))(void *)(intptr_t)fn_ptr;
    return fn();
}
NVec *__nucleor_result_map(NVec *res, long long fn_ptr) {
    if (!res || !fn_ptr) return res;
    NVec *out = __nucleor_vec_new();
    if (__nucleor_vec_get(res, 0) == 1) {
        long long (*fn)(long long) = (long long (*)(long long))(void *)(intptr_t)fn_ptr;
        long long mapped = fn(__nucleor_vec_get(res, 1));
        __nucleor_vec_push(out, 1);
        __nucleor_vec_push(out, mapped);
    } else {
        __nucleor_vec_push(out, 0);
        __nucleor_vec_push(out, __nucleor_vec_get(res, 1));
    }
    return out;
}
NVec *__nucleor_result_and_then(NVec *res, long long fn_ptr) {
    if (!res || !fn_ptr) return res;
    if (__nucleor_vec_get(res, 0) == 1) {
        NVec *(*fn)(long long) = (NVec *(*)(long long))(void *)(intptr_t)fn_ptr;
        return fn(__nucleor_vec_get(res, 1));
    }
    // Pass through Err.
    NVec *out = __nucleor_vec_new();
    __nucleor_vec_push(out, 0);
    __nucleor_vec_push(out, __nucleor_vec_get(res, 1));
    return out;
}
long long __nucleor_result_unwrap_or_else(NVec *res, long long fn_ptr) {
    if (res && __nucleor_vec_get(res, 0) == 1) return __nucleor_vec_get(res, 1);
    if (!fn_ptr) return 0;
    long long (*fn)(long long) = (long long (*)(long long))(void *)(intptr_t)fn_ptr;
    return fn(res ? __nucleor_vec_get(res, 1) : 0);
}
// === Recursive Debug formatters for Vec/Option/Result (v0.4.97) ===
// Format element/payload as i64 (Nucleor cell convention). Strings
// returned are heap-allocated; caller responsible for free.
const char *__nucleor_vec_to_debug_str_i64(NVec *v) {
    if (!v) {
        char *s = (char *)malloc(3); s[0]='['; s[1]=']'; s[2]=0; return s;
    }
    // Estimate buffer: 24 chars per element max + 2 brackets + commas.
    long long cap = (v->len * 26) + 16;
    char *out = (char *)malloc(cap);
    long long pos = 0;
    out[pos++] = '[';
    for (int i = 0; i < v->len; i++) {
        if (i > 0) { out[pos++] = ','; out[pos++] = ' '; }
        char buf[32];
        int n = snprintf(buf, sizeof(buf), "%lld", (long long)v->data[i]);
        memcpy(out + pos, buf, n);
        pos += n;
    }
    out[pos++] = ']';
    out[pos] = 0;
    return out;
}
const char *__nucleor_option_to_debug_str_i64(NVec *opt) {
    if (!opt || __nucleor_vec_get(opt, 0) != 0) {
        char *s = (char *)malloc(5); memcpy(s, "None", 5); return s;
    }
    char buf[64];
    int n = snprintf(buf, sizeof(buf), "Some(%lld)", (long long)__nucleor_vec_get(opt, 1));
    char *out = (char *)malloc(n + 1);
    memcpy(out, buf, n + 1);
    return out;
}
// v0.4.98: Vec<str> debug — element is char*. Prints ["a", "b"].
const char *__nucleor_vec_to_debug_str_str(NVec *v) {
    if (!v) {
        char *s = (char *)malloc(3); s[0]='['; s[1]=']'; s[2]=0; return s;
    }
    // Estimate buffer: assume avg 32 chars per element plus quotes/commas.
    long long cap = 16;
    for (int i = 0; i < v->len; i++) {
        const char *p = (const char *)(intptr_t)v->data[i];
        cap += (p ? strlen(p) : 0) + 6;
    }
    char *out = (char *)malloc(cap);
    long long pos = 0;
    out[pos++] = '[';
    for (int i = 0; i < v->len; i++) {
        if (i > 0) { out[pos++] = ','; out[pos++] = ' '; }
        out[pos++] = '"';
        const char *p = (const char *)(intptr_t)v->data[i];
        if (p) {
            size_t n = strlen(p);
            memcpy(out + pos, p, n);
            pos += n;
        }
        out[pos++] = '"';
    }
    out[pos++] = ']';
    out[pos] = 0;
    return out;
}
// v0.4.98: Vec<Option<i64>> debug — element is NVec* (Option layout).
const char *__nucleor_vec_to_debug_str_option_i64(NVec *v) {
    if (!v) {
        char *s = (char *)malloc(3); s[0]='['; s[1]=']'; s[2]=0; return s;
    }
    long long cap = (v->len * 32) + 16;
    char *out = (char *)malloc(cap);
    long long pos = 0;
    out[pos++] = '[';
    for (int i = 0; i < v->len; i++) {
        if (i > 0) { out[pos++] = ','; out[pos++] = ' '; }
        NVec *opt = (NVec *)(intptr_t)v->data[i];
        if (!opt || __nucleor_vec_get(opt, 0) != 0) {
            memcpy(out + pos, "None", 4); pos += 4;
        } else {
            char buf[32];
            int n = snprintf(buf, sizeof(buf), "Some(%lld)", (long long)__nucleor_vec_get(opt, 1));
            memcpy(out + pos, buf, n);
            pos += n;
        }
    }
    out[pos++] = ']';
    out[pos] = 0;
    return out;
}
const char *__nucleor_result_to_debug_str_i64(NVec *res) {
    if (!res) {
        char *s = (char *)malloc(7); memcpy(s, "Err(0)", 7); return s;
    }
    char buf[64];
    if (__nucleor_vec_get(res, 0) == 1) {
        int n = snprintf(buf, sizeof(buf), "Ok(%lld)", (long long)__nucleor_vec_get(res, 1));
        char *out = (char *)malloc(n + 1);
        memcpy(out, buf, n + 1);
        return out;
    }
    int n = snprintf(buf, sizeof(buf), "Err(%lld)", (long long)__nucleor_vec_get(res, 1));
    char *out = (char *)malloc(n + 1);
    memcpy(out, buf, n + 1);
    return out;
}

NVec *__nucleor_result_or_else(NVec *res, long long fn_ptr) {
    // f takes the err payload, returns a Result<T,E2>. If Ok, pass through.
    if (!res || !fn_ptr) return res;
    if (__nucleor_vec_get(res, 0) == 1) {
        // Pass-through Ok: shallow clone.
        NVec *out = __nucleor_vec_new();
        __nucleor_vec_push(out, 1);
        __nucleor_vec_push(out, __nucleor_vec_get(res, 1));
        return out;
    }
    NVec *(*fn)(long long) = (NVec *(*)(long long))(void *)(intptr_t)fn_ptr;
    return fn(__nucleor_vec_get(res, 1));
}

// === RNG ===
// Pull in rng_rt.c so nuc_rng_* symbols are available without a separate
// link step. The compiler emits __nucleor_rng_seed/etc. which forward to
// nuc_rng_*, defined here.
#include "rng_rt.c"
