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
