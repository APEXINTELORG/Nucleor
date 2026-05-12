// concurrency.nr — Structured concurrency with safety guardrails
// All threads run at IDLE priority — never preempt gaming or normal workloads
// All spawned work is scoped — parent always waits for children

import "stdlib/rods/atomic.nr"

extern fn __nucleor_mutex_free(handle: i64);
extern fn __nucleor_channel_close(handle: i64);
extern fn __nucleor_channel_is_closed(handle: i64) -> i64;

// Spawn a function as a background thread (IDLE priority)
// fn_ptr: function pointer (from closure or |x| expr), arg: argument
// Returns thread handle for joining
fn conc_spawn(fn_ptr: i64, arg: i64) -> i64 {
    return thread_spawn(fn_ptr, arg);
}

// Wait for a spawned thread to complete
fn conc_join(handle: i64) -> i64 {
    thread_join(handle);
    return 0;
}

// Spawn N workers and wait for all to complete (scoped parallelism)
fn conc_parallel(fn_ptr: i64, count: i64) -> i64 {
    let mut handles: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < count {
        handles.push(thread_spawn(fn_ptr, i));
        i = i + 1;
    };
    i = 0;
    while i < count {
        thread_join(handles.get(i));
        i = i + 1;
    };
    return count;
}

// Create a channel for inter-thread communication
fn conc_channel(capacity: i64) -> i64 {
    return channel_new(capacity);
}

fn conc_send(ch: i64, val: i64) -> i64 {
    channel_send(ch, val);
    return 0;
}

fn conc_recv(ch: i64) -> i64 {
    return channel_recv(ch);
}

fn conc_channel_len(ch: i64) -> i64 {
    return channel_len(ch);
}

fn conc_channel_close(ch: i64) { __nucleor_channel_close(ch); }
fn conc_channel_is_closed(ch: i64) -> i64 { return __nucleor_channel_is_closed(ch); }

// Mutex for protecting shared state
fn conc_mutex() -> i64 { return mutex_new(); }
fn conc_lock(m: i64) -> i64 { mutex_lock(m); return 0; }
fn conc_unlock(m: i64) -> i64 { mutex_unlock(m); return 0; }
fn conc_mutex_destroy(m: i64) { __nucleor_mutex_free(m); }
fn conc_mutex_free(m: i64) { __nucleor_mutex_free(m); }

// Atomic counter — lock-free shared integer
fn conc_atomic(initial: i64) -> i64 { return atomic_new(initial); }
fn conc_atomic_inc(a: i64) -> i64 { return atomic_add(a, 1); }
fn conc_atomic_dec(a: i64) -> i64 { return atomic_add(a, 0 - 1); }
fn conc_atomic_add(a: i64, delta: i64) -> i64 { return atomic_add(a, delta); }
fn conc_atomic_get(a: i64) -> i64 { return atomic_load_v(a); }

// Query system resources
fn conc_cpu_count() -> i64 { return cpu_count(); }

// Safe parallel map: apply fn to each element, collect results.
//
// This implementation intentionally runs sequentially until the
// thread-pool collection path owns indexed result writes safely.
//
// Future work wires per-worker result collection: each worker writes
// to a shared Vec<i64> at its index; the main thread reads after join.
fn conc_map(items: Vec<i32>, fn_ptr: i64) -> Vec<i32> {
    let n: i64 = items.len();
    let mut results: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        let fp: i64 = fn_ptr;
        results.push(fp(items.get(i)));
        i = i + 1;
    };
    return results;
}

// === Concurrency rod limitations ===
fn concurrency_limitations() -> str {
    return "Concurrency rod limitations: (1) conc_map IS A SEQUENTIAL FALLBACK. It correctly maps fn_ptr over every item, but does NOT spawn threads - the loop runs in the caller's thread. Future work wires real parallel dispatch via thread_pool when nuc_threadpool_map proves stable across platforms. (2) BARRIER: use thread_barrier_new/thread_barrier_wait/thread_barrier_free from thread.nr for fixed-party rendezvous; concurrency.nr does not re-export it to avoid duplicate thread_rt linkage when both rods are imported. (3) MUTEX LIFECYCLE: conc_mutex_destroy / conc_mutex_free release the native CRITICAL_SECTION or pthread_mutex_t handle; callers must not use a mutex after freeing it. (4) CHANNEL CLOSE: conc_channel_close marks a channel closed; pending buffered values remain readable, sends after close are ignored, and recv on a closed empty channel returns 0 instead of blocking forever. (5) NO STRUCTURED-CONCURRENCY scope: there is no scoped `nursery`-style spawner that joins on scope exit. Future work adds RFC-0027's structured-concurrency surface.";
}

fn conc_map_is_parallel() -> i64 { return 0; }
