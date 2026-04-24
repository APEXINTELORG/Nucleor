// nucleor_llvm_rt.c — Minimal runtime shim for LLVM-emitted Nucleor programs
// Provides the __nucleor_* symbols that llvm_emitter.nr declares as external.
// This is the bridge between LLVM IR output and the OS.
// Target: x86_64-pc-windows-msvc (also works on Linux with minor changes)

#define _CRT_SECURE_NO_WARNINGS
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#ifdef _WIN32
#include <windows.h>
#endif

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

// --- v0.2.24: parse / stringify primitives ---
// Parsers tolerate leading whitespace and an optional sign; return 0 on
// completely-malformed input. Stringifiers always allocate fresh strings.
long long __nucleor_str_to_i64(const char *s) {
    if (!s) return 0;
    while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') s++;
    int neg = 0;
    if (*s == '-') { neg = 1; s++; }
    else if (*s == '+') { s++; }
    long long v = 0;
    int saw = 0;
    while (*s >= '0' && *s <= '9') {
        v = v * 10 + (long long)(*s - '0');
        saw = 1;
        s++;
    }
    if (!saw) return 0;
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

const char *__nucleor_f64_to_str(long long b) {
    union { long long i; double d; } u; u.i = b;
    char buf[64];
    snprintf(buf, sizeof(buf), "%g", u.d);
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
long long __nucleor_str_to_i64_radix(const char *s, long long radix) {
    if (!s || radix < 2 || radix > 36) return 0;
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
    while (*s) {
        long long digit;
        if (*s >= '0' && *s <= '9') digit = (long long)(*s - '0');
        else if (*s >= 'a' && *s <= 'z') digit = (long long)(*s - 'a' + 10);
        else if (*s >= 'A' && *s <= 'Z') digit = (long long)(*s - 'A' + 10);
        else break;
        if (digit >= radix) break;
        v = v * radix + digit;
        saw = 1;
        s++;
    }
    if (!saw) return 0;
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
            cap *= 2;
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
    double d; memcpy(&d, &x, sizeof(double));
    printf("%.6f\n", d);
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
    _intern_init(old_cap * 2);
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

long long __nucleor_tensor_zeros(long long rows, long long cols) {
    NTensor *t = (NTensor *)malloc(sizeof(NTensor));
    t->rows = (int)rows; t->cols = (int)cols;
    t->data = (double *)calloc(t->rows * t->cols, sizeof(double));
    return (long long)t;
}
long long __nucleor_tensor_fill(long long rows, long long cols, long long val_bits) {
    NTensor *t = (NTensor *)malloc(sizeof(NTensor));
    t->rows = (int)rows; t->cols = (int)cols;
    t->data = (double *)malloc(t->rows * t->cols * sizeof(double));
    double v = _t_i2f(val_bits);
    for (int i = 0; i < t->rows * t->cols; i++) t->data[i] = v;
    return (long long)t;
}
long long __nucleor_tensor_ones(long long rows, long long cols) {
    return __nucleor_tensor_fill(rows, cols, _t_f2i(1.0));
}
long long __nucleor_tensor_rows(long long h) { return ((NTensor*)(void*)h)->rows; }
long long __nucleor_tensor_cols(long long h) { return ((NTensor*)(void*)h)->cols; }
long long __nucleor_tensor_get(long long h, long long r, long long c) {
    NTensor *t = (NTensor*)(void*)h;
    return _t_f2i(t->data[(int)r * t->cols + (int)c]);
}
void __nucleor_tensor_set(long long h, long long r, long long c, long long v) {
    NTensor *t = (NTensor*)(void*)h;
    t->data[(int)r * t->cols + (int)c] = _t_i2f(v);
}
long long __nucleor_tensor_sum(long long h) {
    NTensor *t = (NTensor*)(void*)h;
    double s = 0; for (int i = 0; i < t->rows*t->cols; i++) s += t->data[i];
    return _t_f2i(s);
}
long long __nucleor_tensor_mean(long long h) {
    NTensor *t = (NTensor*)(void*)h;
    double s = 0; int n = t->rows*t->cols;
    for (int i = 0; i < n; i++) s += t->data[i];
    return _t_f2i(s / n);
}
long long __nucleor_tensor_max(long long h) {
    NTensor *t = (NTensor*)(void*)h;
    double m = t->data[0]; for (int i = 1; i < t->rows*t->cols; i++) if (t->data[i] > m) m = t->data[i];
    return _t_f2i(m);
}
long long __nucleor_tensor_min(long long h) {
    NTensor *t = (NTensor*)(void*)h;
    double m = t->data[0]; for (int i = 1; i < t->rows*t->cols; i++) if (t->data[i] < m) m = t->data[i];
    return _t_f2i(m);
}
long long __nucleor_tensor_variance(long long h) {
    NTensor *t = (NTensor*)(void*)h;
    int n = t->rows*t->cols; double s=0;
    for (int i=0;i<n;i++) s+=t->data[i]; double m=s/n; double v=0;
    for (int i=0;i<n;i++){double d=t->data[i]-m;v+=d*d;}
    return _t_f2i(v/n);
}
long long __nucleor_tensor_stddev(long long h) {
    return _t_f2i(sqrt(_t_i2f(__nucleor_tensor_variance(h))));
}
long long __nucleor_tensor_matmul(long long ah, long long bh) {
    NTensor *a=(NTensor*)(void*)ah, *b=(NTensor*)(void*)bh;
    NTensor *c=(NTensor*)malloc(sizeof(NTensor));
    c->rows=a->rows; c->cols=b->cols;
    c->data=(double*)calloc(c->rows*c->cols,sizeof(double));
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
    if (!s) return 0;
    return (long long)strlen(s);
}

long long __nucleor_str_eq(const char *a, const char *b) {
    if (!a || !b) return a == b ? 1 : 0;
    return strcmp(a, b) == 0 ? 1 : 0;
}

long long __nucleor_str_char_at(const char *s, long long i) {
    if (!s) return 0;
    return (unsigned char)s[(int)i];
}

const char *__nucleor_str_substring(const char *s, long long start, long long end) {
    if (!s) return "";
    int n = (int)(end - start);
    if (n < 0) n = 0;
    g_str_substring_count++;
    g_str_substring_bytes += n + 1;
    char *r = (char *)malloc(n + 1);
    memcpy(r, s + (int)start, n);
    r[n] = 0;
    return r;
}

const char *__nucleor_str_concat(const char *a, const char *b) {
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

const char *__nucleor_str_repeat(const char *s, long long n) {
    if (!s || n <= 0) {
        char *empty = (char *)malloc(1); empty[0] = 0; return empty;
    }
    size_t L = strlen(s);
    size_t total = L * (size_t)n;
    char *out = (char *)malloc(total + 1);
    for (long long i = 0; i < n; i++) memcpy(out + ((size_t)i * L), s, L);
    out[total] = 0;
    return out;
}

// __nucleor_str_split is defined further down in this file (after the
// NVec typedef). It returns NVec* (Vec<str>) of substrings.

// === File I/O ===
const char *__nucleor_file_read_string(const char *path) {
    if (!path) return "";
    FILE *f = fopen(path, "rb");
    if (!f) return "";
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = (char *)malloc(sz + 1);
    fread(buf, 1, sz, f);
    fclose(f);
    buf[sz] = 0;
    return buf;
}

void __nucleor_file_write_string(const char *path, const char *data) {
    if (!path || !data) return;
    FILE *f = fopen(path, "wb");
    if (f) {
        fwrite(data, 1, strlen(data), f);
        fclose(f);
    }
}

// === Process ===
long long __nucleor_system(const char *cmd) {
    if (!cmd) return -1;
    return (long long)system(cmd);
}

// === Vec operations (flat array with length tracking) ===
typedef struct { long long *data; int len; int cap; } NVec;

NVec *__nucleor_vec_new(void) {
    if (!g_alloc_tracer_init) { atexit(_alloc_summary); g_alloc_tracer_init = 1; }
    g_vec_new_count++;
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->data = (long long *)malloc(16 * sizeof(long long));
    v->len = 0;
    v->cap = 16;
    g_vec_realloc_bytes += sizeof(NVec) + 16 * sizeof(long long);
    return v;
}

// Free a Vec and its data. The handle is invalid after this call.
// Always-linked counterpart of mem_rt.c's nuc_vec_free, so user code
// (and the compiler itself) can reclaim a Vec without importing
// stdlib/rods/mem.nr. Safe on null handles.
void __nucleor_vec_free(long long handle) {
    NVec *v = (NVec *)(void *)(size_t)handle;
    if (!v) return;
    if (v->data) free(v->data);
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
    if (!v) return;
    if (v->len >= v->cap) {
        long long old_cap = v->cap;
        v->cap *= 2;
        v->data = (long long *)realloc(v->data, v->cap * sizeof(long long));
        g_vec_realloc_bytes += (v->cap - old_cap) * sizeof(long long);
    }
    v->data[v->len++] = x;
}

long long __nucleor_vec_get(NVec *v, long long i) {
    if (!v || i < 0 || i >= v->len) return 0;
    return v->data[(int)i];
}

long long __nucleor_vec_len(NVec *v) {
    if (!v) return 0;
    return (long long)v->len;
}

void __nucleor_vec_pop(NVec *v) {
    if (!v || v->len <= 0) return;
    v->len--;
}

void __nucleor_vec_set(NVec *v, long long i, long long x) {
    if (!v || i < 0 || i >= v->len) return;
    v->data[(int)i] = x;
}

// --- v0.2.22: vec extras ---
long long __nucleor_vec_first(NVec *v) {
    if (!v || v->len <= 0) return 0;
    return v->data[0];
}
long long __nucleor_vec_last(NVec *v) {
    if (!v || v->len <= 0) return 0;
    return v->data[v->len - 1];
}
long long __nucleor_vec_is_empty(NVec *v) {
    if (!v) return 1;
    return v->len == 0 ? 1 : 0;
}
void __nucleor_vec_swap(NVec *v, long long i, long long j) {
    if (!v) return;
    if (i < 0 || j < 0 || i >= v->len || j >= v->len) return;
    long long tmp = v->data[(int)i];
    v->data[(int)i] = v->data[(int)j];
    v->data[(int)j] = tmp;
}
void __nucleor_vec_extend(NVec *dst, NVec *src) {
    if (!dst || !src) return;
    for (int i = 0; i < src->len; i++) {
        __nucleor_vec_push(dst, src->data[i]);
    }
}
void __nucleor_vec_remove_at(NVec *v, long long i) {
    if (!v || i < 0 || i >= v->len) return;
    int idx = (int)i;
    for (int k = idx; k < v->len - 1; k++) {
        v->data[k] = v->data[k + 1];
    }
    v->len--;
}
void __nucleor_vec_insert_at(NVec *v, long long i, long long x) {
    if (!v) return;
    int idx = (int)i;
    if (idx < 0) idx = 0;
    if (idx > v->len) idx = v->len;
    if (v->len >= v->cap) {
        v->cap *= 2;
        v->data = (long long *)realloc(v->data, v->cap * sizeof(long long));
    }
    for (int k = v->len; k > idx; k--) {
        v->data[k] = v->data[k - 1];
    }
    v->data[idx] = x;
    v->len++;
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

void __nucleor_sb_append(long long handle, const char *s) {
    if (!s) return;
    NStrBuilder *sb = (NStrBuilder *)(void *)handle;
    int slen = (int)strlen(s);
    while (sb->len + slen + 1 > sb->cap) {
        long long old_cap = sb->cap;
        sb->cap *= 2;
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
long long __nucleor_channel_new(long long cap) { return 0; } // TODO: POSIX channel
void __nucleor_channel_send(long long h, long long v) { (void)h; (void)v; }
long long __nucleor_channel_recv(long long h) { (void)h; return 0; }
long long __nucleor_channel_len(long long h) { (void)h; return 0; }
long long __nucleor_atomic_new(long long val) {
    long long *p = (long long*)malloc(sizeof(long long));
    *p = val; return (long long)p;
}
long long __nucleor_atomic_add(long long h, long long d) { return __sync_add_and_fetch((long long*)(void*)h, d); }
long long __nucleor_atomic_load(long long h) { return __sync_val_compare_and_swap((long long*)(void*)h, 0, 0); }
long long __nucleor_cpu_count(void) { return (long long)sysconf(_SC_NPROCESSORS_ONLN); }
#endif

// === Args ===
// Use CRT globals __argc/__argv — populated before main() runs
extern int __argc;
extern char **__argv;

void __nucleor_init_args(int argc, char **argv) {
    (void)argc;
    (void)argv;
}

long long __nucleor_args_count(void) {
    return (long long)__argc;
}

const char *__nucleor_args_get(long long i) {
    if (i < 0 || i >= __argc) return "";
    return __argv[(int)i];
}

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
    // For now: pass through (phase 3 adds proper f64->f32 narrow op).
    return v;
}

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
static int __nucleor_overflow_flag = 0;

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
        v->cap *= 2;
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
        v->cap *= 2;
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
        v->cap *= 2;
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
long long __nucleor_f32_to_f64(long long a) {
    union { unsigned long long u; double d; } cd;
    cd.d = (double)__nuc_bits_to_f32(a);
    return (long long)cd.u;
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
        s->cap *= 2;
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
        s->cap *= 2;
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
long long __nucleor_hashmap_with_capacity(long long n) {
    NHashMap *m = (NHashMap *)malloc(sizeof(NHashMap));
    long long cap = 16;
    while (cap < n * 2) cap *= 2;
    m->cap = cap;
    m->slots = (NHMSlot *)calloc((size_t)cap, sizeof(NHMSlot));
    m->len = 0;
    return (long long)(intptr_t)m;
}
long long __nucleor_hashmap_insert(long long h, const char *key, long long val) {
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
long long __nucleor_hashmap_get(long long h, const char *key) {
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
    return 0;
}
long long __nucleor_hashmap_contains(long long h, const char *key) {
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
long long __nucleor_hashmap_free(long long h) {
    NHashMap *m = (NHashMap *)(intptr_t)h;
    if (!m) return 0;
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
    NVecDeque *d = (NVecDeque *)malloc(sizeof(NVecDeque));
    long long cap = 16;
    while (cap < n) cap *= 2;
    d->cap = cap;
    d->data = (long long *)malloc((size_t)cap * sizeof(long long));
    d->head = 0;
    d->len = 0;
    return (long long)(intptr_t)d;
}
static void __nuc_vecdeque_grow(NVecDeque *d) {
    long long new_cap = d->cap * 2;
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
        m->cap *= 2;
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
    if (idx < 0) return 0;
    return m->vals[idx];
}
long long __nucleor_btreemap_contains(long long h, const char *key) {
    NBTreeMap *m = (NBTreeMap *)(intptr_t)h;
    if (!m || !key) return 0;
    return __nuc_btreemap_bsearch(m, key) >= 0 ? 1 : 0;
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
    if (!path) return __nucleor_hashmap_new();
    FILE *f = fopen(path, "rb");
    if (!f) return __nucleor_hashmap_new();
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = (char *)malloc((size_t)sz + 1);
    fread(buf, 1, (size_t)sz, f);
    buf[sz] = 0;
    fclose(f);
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
long long __nucleor_f64_to_i32(long long b) {
    return (long long)(int)__nuc_b2d(b);
}
long long __nucleor_i32_to_f64(long long i) {
    return __nuc_d2b((double)(int)i);
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

// === RNG ===
// Pull in rng_rt.c so nuc_rng_* symbols are available without a separate
// link step. The compiler emits __nucleor_rng_seed/etc. which forward to
// nuc_rng_*, defined here.
#include "rng_rt.c"
