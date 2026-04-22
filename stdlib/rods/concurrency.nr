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
fn conc_atomic_get(a: i64) -> i64 { return atomic_load(a); }

// Query system resources
fn conc_cpu_count() -> i64 { return cpu_count(); }

// Safe parallel map: apply fn to each element, collect results
fn conc_map(items: Vec<i32>, fn_ptr: i64) -> Vec<i32> {
    let n: i64 = items.len();
    let mut results: Vec<i32> = Vec::new();
    // For small workloads, run sequentially
    if n <= 4 {
        let mut i: i64 = 0;
        while i < n {
            let fp: i64 = fn_ptr;
            results.push(fp(items.get(i)));
            i = i + 1;
        };
        return results;
    };
    // For larger workloads, use channels
    let ch: i64 = channel_new(n);
    let mut handles: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        // Pack item index and channel for the worker
        handles.push(thread_spawn(fn_ptr, items.get(i)));
        i = i + 1;
    };
    // Join all and collect
    i = 0;
    while i < n {
        thread_join(handles.get(i));
        results.push(0); // placeholder — real impl needs result collection
        i = i + 1;
    };
    return results;
}
