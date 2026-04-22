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
    char *r = (char *)malloc(n + 1);
    memcpy(r, s + (int)start, n);
    r[n] = 0;
    return r;
}

const char *__nucleor_str_concat(const char *a, const char *b) {
    if (!a) a = "";
    if (!b) b = "";
    int la = (int)strlen(a), lb = (int)strlen(b);
    char *r = (char *)malloc(la + lb + 1);
    memcpy(r, a, la);
    memcpy(r + la, b, lb + 1);
    return r;
}

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
    NVec *v = (NVec *)malloc(sizeof(NVec));
    v->data = (long long *)malloc(16 * sizeof(long long));
    v->len = 0;
    v->cap = 16;
    return v;
}

void __nucleor_vec_push(NVec *v, long long x) {
    if (!v) return;
    if (v->len >= v->cap) {
        v->cap *= 2;
        v->data = (long long *)realloc(v->data, v->cap * sizeof(long long));
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

// === StringBuilder (amortized O(1) append, avoids O(n^2) str_concat) ===
typedef struct { char *data; int len; int cap; } NStrBuilder;

long long __nucleor_sb_new(void) {
    NStrBuilder *sb = (NStrBuilder *)malloc(sizeof(NStrBuilder));
    sb->cap = 4096;
    sb->data = (char *)malloc(sb->cap);
    sb->data[0] = '\0';
    sb->len = 0;
    return (long long)sb;
}

void __nucleor_sb_append(long long handle, const char *s) {
    if (!s) return;
    NStrBuilder *sb = (NStrBuilder *)(void *)handle;
    int slen = (int)strlen(s);
    while (sb->len + slen + 1 > sb->cap) {
        sb->cap *= 2;
        sb->data = (char *)realloc(sb->data, sb->cap);
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
long long __nucleor_rng_seed(long long seed, long long reserved) {
    (void)reserved;
    nuc_rng_seed(seed);
    return 0;
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
