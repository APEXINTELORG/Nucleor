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

fn thread_pool_new(n: i64) -> i64 { return nuc_threadpool_new(n); }
fn thread_pool_submit(pool: i64, fn_ptr: i64, arg: i64) -> i64 {
    return nuc_threadpool_submit(pool, fn_ptr, arg);
}
fn thread_future_get(f: i64) -> i64 { return nuc_future_get(f); }
fn thread_pool_map(pool: i64, fn_ptr: i64, vec: i64) -> i64 {
    return nuc_threadpool_map(pool, fn_ptr, vec);
}
fn thread_pool_free(pool: i64) { nuc_threadpool_free(pool); }
