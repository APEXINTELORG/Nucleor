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

// === RNG ===
// Pull in rng_rt.c so nuc_rng_* symbols are available without a separate
// link step. The compiler emits __nucleor_rng_seed/etc. which forward to
// nuc_rng_*, defined here.
#include "rng_rt.c"
