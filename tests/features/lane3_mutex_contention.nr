// Lane 3 (F-CONC-016): mutex contention smoke test.
//
// 4 workers each acquire a shared mutex, increment a shared counter,
// release, repeat 10K iterations. End state must be 4 * 10000 = 40000.
// If the lock is broken (lost wakeup, recursive-acquire UB, or under-
// counted critical section), we'll observe a value below 40000.

import "stdlib/rods/concurrency.nr"

struct MutexShared {
    mutex: i64,
    counter: Vec<i32>,
    per_worker: i64,
}

fn worker(shared: &MutexShared) -> i64 {
    let mut i: i64 = 0;
    while i < shared.per_worker {
        conc_lock(shared.mutex);
        let current: i32 = shared.counter.get(0);
        shared.counter.set(0, current + 1);
        conc_unlock(shared.mutex);
        i = i + 1;
    };
    return 0;
}

fn main() -> i64 {
    let mtx: i64 = conc_mutex();
    let values: Vec<i32> = Vec::new();
    values.push(0);
    let shared: MutexShared = MutexShared {
        mutex: mtx,
        counter: values,
        per_worker: 10000,
    };
    let h0: i64 = thread_spawn(worker, &shared);
    let h1: i64 = thread_spawn(worker, &shared);
    let h2: i64 = thread_spawn(worker, &shared);
    let h3: i64 = thread_spawn(worker, &shared);
    thread_join(h0);
    thread_join(h1);
    thread_join(h2);
    thread_join(h3);
    let total: i32 = shared.counter.get(0);
    conc_mutex_free(mtx);
    if total != 40000 {
        return 1;
    };
    print("OK lane3_mutex_contention");
    return 0;
}
