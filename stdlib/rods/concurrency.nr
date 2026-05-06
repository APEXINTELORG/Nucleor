// concurrency.nr — Structured concurrency with safety guardrails
// All threads run at IDLE priority — never preempt gaming or normal workloads
// All spawned work is scoped — parent always waits for children

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

// Mutex for protecting shared state
fn conc_mutex() -> i64 { return mutex_new(); }
fn conc_lock(m: i64) -> i64 { mutex_lock(m); return 0; }
fn conc_unlock(m: i64) -> i64 { mutex_unlock(m); return 0; }

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
// R04-D1 Phase 1 (v0.8.284, audit 2026-05-05): pre-v0.8.284 the
// n > 4 path spawned workers via thread_spawn + thread_join but
// pushed placeholder ZEROES instead of collecting real return
// values (line 94 was `results.push(0); // placeholder`). That's a
// silent-corruption class — adopters relying on conc_map for n > 4
// got an all-zero results vec while their fn_ptr's real outputs
// were silently dropped.
//
// Phase 1 fix: run sequentially for ALL n. Correct results,
// slower. Phase 2 wires per-worker result collection (each worker
// writes to a shared Vec<i64> at its index; main reads after join)
// per the audit's R04-D1 ship plan.
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

// === R04-D5 Phase 1 (v0.8.310) — concurrency rod limitations ===
//
// Per audit `BUILD_PLAN_R04_concurrency.md` §1 R04-D5 (MEDIUM):
// document which primitives are sequential fallbacks vs real
// parallel/concurrent dispatch.
fn concurrency_limitations() -> str {
    return "Concurrency rod limitations (CONC-1, audit R04-D5 v0.8.310): (1) conc_map IS A SEQUENTIAL FALLBACK as of v0.8.270 (R04-D2 closure of silent-zero placeholder bug). It correctly maps fn_ptr over every item, but does NOT spawn threads — the loop runs in the caller's thread. Phase 2 wires real parallel dispatch via thread_pool when nuc_threadpool_map proves stable across platforms. (2) NO BARRIER PRIMITIVE: a sync_barrier(n)-style primitive is not in this rod yet; combine N async_spawn + N async_await calls or wait on the thread_pool for fan-in. (3) NO STRUCTURED-CONCURRENCY scope: there is no scoped `nursery`-style spawner that joins on scope exit. Phase 2 adds RFC-0027 phase 2's structured-concurrency surface. (4) NO CHANNEL-CLOSE diagnostic: when a channel is dropped while a writer is mid-send, the failure mode is silent (no panic, no Result::Err). Phase 2 ships channel_close_status per audit ship plan.";
}

fn conc_map_is_parallel() -> i64 { return 0; }
