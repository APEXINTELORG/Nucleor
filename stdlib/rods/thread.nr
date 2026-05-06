// rods/thread — Thread pool, futures, parallel map, barrier
//
// Thin pool over OS threads. `thread_pool_new(N)` spins up N workers;
// `thread_pool_submit` queues a function-pointer task and returns a
// future handle; `thread_future_get` blocks for the result.
// `thread_pool_map` runs a function over a Vec<i64> in parallel.
//
// See `stdlib/runtime/thread_rt.c`.
#cfile "../runtime/thread_rt.c"

extern fn nuc_threadpool_new(n_threads: i64) -> i64;
extern fn nuc_threadpool_submit(pool_h: i64, fn_ptr: i64, arg: i64) -> i64;
extern fn nuc_future_get(fut_h: i64) -> i64;
extern fn nuc_threadpool_map(pool_h: i64, fn_ptr: i64, vec_h: i64) -> i64;
extern fn nuc_threadpool_free(pool_h: i64);
extern fn nuc_barrier_new(parties: i64) -> i64;
extern fn nuc_barrier_wait(barrier_h: i64) -> i64;
extern fn nuc_barrier_free(barrier_h: i64);

fn thread_pool_new(n: i64) -> i64 { return nuc_threadpool_new(n); }
fn thread_pool_submit(pool: i64, fn_ptr: i64, arg: i64) -> i64 {
    return nuc_threadpool_submit(pool, fn_ptr, arg);
}
fn thread_future_get(f: i64) -> i64 { return nuc_future_get(f); }
fn thread_pool_map(pool: i64, fn_ptr: i64, vec: i64) -> i64 {
    return nuc_threadpool_map(pool, fn_ptr, vec);
}
fn thread_pool_free(pool: i64) { nuc_threadpool_free(pool); }
fn thread_barrier_new(parties: i64) -> i64 { return nuc_barrier_new(parties); }
fn thread_barrier_wait(barrier: i64) -> i64 { return nuc_barrier_wait(barrier); }
fn thread_barrier_free(barrier: i64) { nuc_barrier_free(barrier); }

// === R04-D5 Phase 1 (v0.8.310) — thread rod limitations ===
fn thread_limitations() -> str {
    return "Thread rod limitations (CONC-2/C-10, audit R04-D5 v0.8.310/v0836): (1) thread_pool IS REAL parallel dispatch via OS threads (verified by thread_rt.c). thread_pool_map runs N workers in parallel. (2) thread_barrier_new/thread_barrier_wait/thread_barrier_free provide a reusable runtime barrier for fixed-party rendezvous; wait returns 1 to the releasing thread, 0 to other waiters, and -1 on invalid handles. (3) NO WORK-STEALING: each worker pulls from a single shared queue under a mutex; under heavy contention this is the bottleneck. Phase 2 adds per-worker queues + steal-on-empty. (4) NO PANIC HANDLING: a panic in a submitted fn aborts the worker thread and may leave the future-handle leaked; wrap risky bodies in their own panic-catching shim until Phase 2 wires structured panic propagation. (5) NO POOL RESIZE: thread_pool_new(N) is fixed at construction; cannot grow/shrink dynamically. Use a separate pool per workload tier.";
}

fn thread_pool_is_parallel() -> i64 { return 1; }
