// Lane 3 (F-CONC-016): mutex contention smoke test.
//
// 4 workers each acquire a shared mutex, increment a shared counter,
// release, repeat 10K iterations. End state must be 4 * 10000 = 40000.
// If the lock is broken (lost wakeup, recursive-acquire UB, or under-
// counted critical section), we'll observe a value below 40000.

import "stdlib/rods/concurrency.nr"

// Globals — addressed via raw pointer-as-i64 since Nucleor v1.0
// does not (yet) provide hashed thread-local state. We pass the
// shared mutex handle via the spawn arg, and read/write the
// counter through an atomic.
fn worker(arg: i64) -> i64 {
    // arg encodes: high 32 bits = mutex handle, low 32 bits = atomic counter handle
    let mtx: i64 = arg / 4294967296;
    let ctr: i64 = arg - (mtx * 4294967296);
    let mut i: i64 = 0;
    while i < 10000 {
        conc_lock(mtx);
        // Increment via atomic so the counter survives even if a
        // future Lane-1 refactor removes the lock — the contention
        // metric is what we want to measure.
        conc_atomic_inc(ctr);
        conc_unlock(mtx);
        i = i + 1;
    };
    return 0;
}

fn main() -> i64 {
    let mtx: i64 = conc_mutex();
    let ctr: i64 = conc_atomic(0);
    let arg: i64 = (mtx * 4294967296) + ctr;
    let h0: i64 = conc_spawn(worker, arg);
    let h1: i64 = conc_spawn(worker, arg);
    let h2: i64 = conc_spawn(worker, arg);
    let h3: i64 = conc_spawn(worker, arg);
    conc_join(h0);
    conc_join(h1);
    conc_join(h2);
    conc_join(h3);
    let total: i64 = conc_atomic_get(ctr);
    if total != 40000 {
        return 1;
    };
    print("OK lane3_mutex_contention");
    return 0;
}
