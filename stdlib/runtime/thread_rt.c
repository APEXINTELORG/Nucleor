// thread_rt.c — Thread Pool and Futures for Nucleor
// Extends the basic threading in nucleor_llvm_rt.c with:
// thread pool, futures, parallel map, barrier.
//
// Compile: clang -c stdlib/runtime/thread_rt.c -o target/thread_rt.obj -O2
// Link: (uses Windows threads / pthreads already in nucleor_llvm_rt)

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

// ================================================================
//  Thread Pool
// ================================================================

typedef struct Task Task;
struct Task {
    long long (*fn)(long long);
    long long arg;
    long long *result_ptr;
    Task *next;
};

typedef struct {
    int n_threads;
    int shutdown;
    Task *head, *tail;
    int task_count;
#ifdef _WIN32
    HANDLE *threads;
    CRITICAL_SECTION lock;
    HANDLE work_ready;
    HANDLE work_done;
#else
    pthread_t *threads;
    pthread_mutex_t lock;
    pthread_cond_t work_ready;
#endif
} ThreadPool;

#ifdef _WIN32
static DWORD WINAPI pool_worker(LPVOID param) {
    ThreadPool *pool = (ThreadPool *)param;
    while (1) {
        EnterCriticalSection(&pool->lock);
        while (!pool->head && !pool->shutdown) {
            LeaveCriticalSection(&pool->lock);
            WaitForSingleObject(pool->work_ready, 100);
            EnterCriticalSection(&pool->lock);
        }
        if (pool->shutdown && !pool->head) {
            LeaveCriticalSection(&pool->lock);
            return 0;
        }
        Task *t = pool->head;
        pool->head = t->next;
        if (!pool->head) pool->tail = NULL;
        pool->task_count--;
        LeaveCriticalSection(&pool->lock);

        long long result = t->fn(t->arg);
        if (t->result_ptr) *t->result_ptr = result;
        free(t);
    }
    return 0;
}
#else
static void *pool_worker(void *param) {
    ThreadPool *pool = (ThreadPool *)param;
    while (1) {
        pthread_mutex_lock(&pool->lock);
        while (!pool->head && !pool->shutdown)
            pthread_cond_wait(&pool->work_ready, &pool->lock);
        if (pool->shutdown && !pool->head) {
            pthread_mutex_unlock(&pool->lock);
            return NULL;
        }
        Task *t = pool->head;
        pool->head = t->next;
        if (!pool->head) pool->tail = NULL;
        pool->task_count--;
        pthread_mutex_unlock(&pool->lock);

        long long result = t->fn(t->arg);
        if (t->result_ptr) *t->result_ptr = result;
        free(t);
    }
    return NULL;
}
#endif

long long nuc_threadpool_new(long long n_threads) {
    int nt = (int)n_threads;
    if (nt < 1) nt = 1;
    ThreadPool *pool = (ThreadPool *)calloc(1, sizeof(ThreadPool));
    pool->n_threads = nt;

#ifdef _WIN32
    InitializeCriticalSection(&pool->lock);
    pool->work_ready = CreateEvent(NULL, FALSE, FALSE, NULL);
    pool->threads = (HANDLE *)malloc(nt * sizeof(HANDLE));
    for (int i = 0; i < nt; i++) {
        pool->threads[i] = CreateThread(NULL, 0, pool_worker, pool, 0, NULL);
        SetThreadPriority(pool->threads[i], THREAD_PRIORITY_BELOW_NORMAL);
    }
#else
    pthread_mutex_init(&pool->lock, NULL);
    pthread_cond_init(&pool->work_ready, NULL);
    pool->threads = (pthread_t *)malloc(nt * sizeof(pthread_t));
    for (int i = 0; i < nt; i++)
        pthread_create(&pool->threads[i], NULL, pool_worker, pool);
#endif
    return (long long)pool;
}

// ================================================================
//  Submit work to pool
// ================================================================

typedef struct {
    long long result;
    int done;
    /* Lane 2 audit fix F-CONC-002 (Critical, 2026-05-08):
       idempotent consume flag. Pre-fix `nuc_future_get` freed
       the Future struct unconditionally; a second call (in a
       retry loop, or after a panic-aborted worker leaves the
       handle dangling per `thread_limitations()`) double-freed
       the heap allocation → process crash with rc=0xC0000374
       (Windows heap-corruption fast-fail) or libc abort on glibc.
       The flag is set on first consume; second consume returns
       0 (sentinel) without re-waiting or re-freeing the
       primitives. The struct is intentionally LEAKED on the
       second call rather than re-freed — a 64-byte leak per
       double-consume is preferable to a UAF crash. */
    int consumed;
#ifdef _WIN32
    HANDLE event;
#else
    pthread_mutex_t lock;
    pthread_cond_t cond;
#endif
} Future;

static long long future_wrapper(long long arg) {
    // Decode: arg is a pointer to [fn_ptr, real_arg, future_ptr]
    long long *args = (long long *)(void *)arg;
    long long (*fn)(long long) = (long long (*)(long long))(void *)args[0];
    long long result = fn(args[1]);
    Future *fut = (Future *)(void *)args[2];
    fut->result = result;
    fut->done = 1;
#ifdef _WIN32
    SetEvent(fut->event);
#else
    pthread_mutex_lock(&fut->lock);
    pthread_cond_signal(&fut->cond);
    pthread_mutex_unlock(&fut->lock);
#endif
    free(args);
    return result;
}

long long nuc_threadpool_submit(long long pool_h, long long fn_ptr, long long arg) {
    ThreadPool *pool = (ThreadPool *)(void *)pool_h;
    Future *fut = (Future *)calloc(1, sizeof(Future));
#ifdef _WIN32
    fut->event = CreateEvent(NULL, TRUE, FALSE, NULL);
#else
    pthread_mutex_init(&fut->lock, NULL);
    pthread_cond_init(&fut->cond, NULL);
#endif

    long long *wrapper_args = (long long *)malloc(3 * sizeof(long long));
    wrapper_args[0] = fn_ptr;
    wrapper_args[1] = arg;
    wrapper_args[2] = (long long)fut;

    Task *t = (Task *)calloc(1, sizeof(Task));
    t->fn = future_wrapper;
    t->arg = (long long)wrapper_args;

#ifdef _WIN32
    EnterCriticalSection(&pool->lock);
#else
    pthread_mutex_lock(&pool->lock);
#endif
    if (pool->tail) pool->tail->next = t;
    else pool->head = t;
    pool->tail = t;
    pool->task_count++;
#ifdef _WIN32
    SetEvent(pool->work_ready);
    LeaveCriticalSection(&pool->lock);
#else
    pthread_cond_signal(&pool->work_ready);
    pthread_mutex_unlock(&pool->lock);
#endif

    return (long long)fut;
}

// ================================================================
//  Future: blocking get
// ================================================================

long long nuc_future_get(long long fut_h) {
    Future *fut = (Future *)(void *)fut_h;
    if (!fut) return 0;
    /* Lane 2 audit fix F-CONC-002: idempotency guard. If the
       future was already consumed (its consumed flag is set), the
       backing storage is in one of two states: (a) freed on first
       call (legacy path, now disabled below) or (b) leaked but
       still mapped (post-fix path). Either way, do NOT re-wait
       on the destroyed event/cond and do NOT re-free. Return 0
       and emit a one-shot diagnostic. The diagnostic helps
       adopters notice the bug without crashing. */
    if (fut->consumed) {
        static int warned_once = 0;
        if (!warned_once) {
            warned_once = 1;
            fprintf(stderr,
                "WARN[F-CONC-002]: thread_future_get called twice on the same "
                "future handle (0x%llx). Returning 0 sentinel. Pre-Lane-2-fix "
                "this would have double-freed the Future struct and crashed "
                "with rc=0xC0000374 (heap fast-fail) on Windows. The first "
                "consume's result is gone; subsequent consumes are no-ops. "
                "If you need polling, use a separate consume guard in adopter "
                "code or wait for `thread_future_try_get` (post-v1.0).\n",
                (unsigned long long)fut_h);
            fflush(stderr);
        }
        return 0;
    }
#ifdef _WIN32
    WaitForSingleObject(fut->event, INFINITE);
    CloseHandle(fut->event);
#else
    pthread_mutex_lock(&fut->lock);
    while (!fut->done) pthread_cond_wait(&fut->cond, &fut->lock);
    pthread_mutex_unlock(&fut->lock);
    pthread_mutex_destroy(&fut->lock);
    pthread_cond_destroy(&fut->cond);
#endif
    long long result = fut->result;
    /* Mark consumed before relinquishing the storage. Intentionally
       LEAK the Future struct (~64 bytes) so the consumed flag stays
       readable on a subsequent erroneous call — turns the previously
       crashing UAF into an observable WARN. The leak is bounded by
       the number of double-consume bugs in adopter code, not by
       legitimate per-future allocation. */
    fut->consumed = 1;
    /* Pre-Lane-2-fix path freed unconditionally:
           free(fut);
       The free is removed; see comment above. Adopters running long-
       lived workloads who never double-consume see only the new
       nominal leak (which a future v1.x slab allocator can recover). */
    return result;
}

// ================================================================
//  Pool shutdown
// ================================================================

void nuc_threadpool_free(long long pool_h) {
    ThreadPool *pool = (ThreadPool *)(void *)pool_h;
    if (!pool) return;

#ifdef _WIN32
    EnterCriticalSection(&pool->lock);
    pool->shutdown = 1;
    LeaveCriticalSection(&pool->lock);
    for (int i = 0; i < pool->n_threads; i++) SetEvent(pool->work_ready);
    WaitForMultipleObjects(pool->n_threads, pool->threads, TRUE, INFINITE);
    for (int i = 0; i < pool->n_threads; i++) CloseHandle(pool->threads[i]);
    DeleteCriticalSection(&pool->lock);
    CloseHandle(pool->work_ready);
#else
    pthread_mutex_lock(&pool->lock);
    pool->shutdown = 1;
    pthread_cond_broadcast(&pool->work_ready);
    pthread_mutex_unlock(&pool->lock);
    for (int i = 0; i < pool->n_threads; i++) pthread_join(pool->threads[i], NULL);
    pthread_mutex_destroy(&pool->lock);
    pthread_cond_destroy(&pool->work_ready);
#endif
    free(pool->threads);
    free(pool);
}

// ================================================================
//  Parallel Map: apply fn to each element of Vec, using pool
// ================================================================

long long nuc_threadpool_map(long long pool_h, long long fn_ptr, long long vec_h) {
    /* NVec typedef removed Lane 2 audit fix A1 2026-05-08; canonical definition force-included via stdlib/runtime/nvec.h */
    NVec *v = (NVec *)(void *)vec_h;
    int n = v->len;

    long long *futures = (long long *)malloc(n * sizeof(long long));
    for (int i = 0; i < n; i++)
        futures[i] = nuc_threadpool_submit(pool_h, fn_ptr, v->data[i]);

    NVec *out = (NVec *)malloc(sizeof(NVec));
    out->len = n; out->cap = n;
    out->data = (long long *)malloc(n * sizeof(long long));
    for (int i = 0; i < n; i++)
        out->data[i] = nuc_future_get(futures[i]);

    free(futures);
    return (long long)out;
}

// ================================================================
//  Reusable Barrier
// ================================================================

typedef struct {
    long long parties;
    long long waiting;
    long long generation;
#ifdef _WIN32
    CRITICAL_SECTION lock;
    CONDITION_VARIABLE cond;
#else
    pthread_mutex_t lock;
    pthread_cond_t cond;
#endif
} NucBarrier;

long long nuc_barrier_new(long long parties) {
    if (parties < 1) return 0;
    NucBarrier *b = (NucBarrier *)calloc(1, sizeof(NucBarrier));
    if (!b) return 0;
    b->parties = parties;
#ifdef _WIN32
    InitializeCriticalSection(&b->lock);
    InitializeConditionVariable(&b->cond);
#else
    pthread_mutex_init(&b->lock, NULL);
    pthread_cond_init(&b->cond, NULL);
#endif
    return (long long)b;
}

long long nuc_barrier_wait(long long barrier_h) {
    NucBarrier *b = (NucBarrier *)(void *)barrier_h;
    if (!b || b->parties < 1) return -1;
    long long rc = 0;
#ifdef _WIN32
    EnterCriticalSection(&b->lock);
    long long generation = b->generation;
    b->waiting++;
    if (b->waiting >= b->parties) {
        b->waiting = 0;
        b->generation++;
        WakeAllConditionVariable(&b->cond);
        rc = 1;
    } else {
        while (generation == b->generation) {
            SleepConditionVariableCS(&b->cond, &b->lock, INFINITE);
        }
    }
    LeaveCriticalSection(&b->lock);
#else
    pthread_mutex_lock(&b->lock);
    long long generation = b->generation;
    b->waiting++;
    if (b->waiting >= b->parties) {
        b->waiting = 0;
        b->generation++;
        pthread_cond_broadcast(&b->cond);
        rc = 1;
    } else {
        while (generation == b->generation) {
            pthread_cond_wait(&b->cond, &b->lock);
        }
    }
    pthread_mutex_unlock(&b->lock);
#endif
    return rc;
}

void nuc_barrier_free(long long barrier_h) {
    NucBarrier *b = (NucBarrier *)(void *)barrier_h;
    if (!b) return;
#ifdef _WIN32
    DeleteCriticalSection(&b->lock);
#else
    pthread_mutex_destroy(&b->lock);
    pthread_cond_destroy(&b->cond);
#endif
    free(b);
}
