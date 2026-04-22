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
    free(fut);
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
    typedef struct { long long *data; int len; int cap; } NVec;
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
