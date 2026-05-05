// v0.8.243 stdlib/rods/thread.nr first test coverage.
//
// Thread pool, futures, parallel map. Pre-v0.8.243: zero
// coverage on the standalone rod. submit / map / future_get
// need fn-pointer task callbacks; deferred to dedicated
// parallel-compute ships.
//
// Locks four lifecycle invariants:
//
//   1. **thread_pool_new returns valid handle** — non-zero
//      for reasonable n_threads.
//   2. **Multiple distinct pools** — two constructions →
//      distinct handles (worker thread groups are not aliased).
//   3. **Single-thread pool valid** — n_threads=1 still works
//      (degenerate case).
//   4. **thread_pool_free does not crash** on a freshly
//      constructed pool.
//
// Expected: rc=0.

import "stdlib/rods/thread.nr"

fn check_new_valid() -> i64 {
    let p: i64 = thread_pool_new(4);
    if p == 0 { return 1; };
    thread_pool_free(p);
    return 0;
}

fn check_distinct_pools() -> i64 {
    let a: i64 = thread_pool_new(2);
    let b: i64 = thread_pool_new(2);
    let same: i64 = if a == b { 1 } else { 0 };
    thread_pool_free(a);
    thread_pool_free(b);
    if same == 1 { return 2; };
    return 0;
}

fn check_single_thread_pool() -> i64 {
    let p: i64 = thread_pool_new(1);
    if p == 0 { return 4; };
    thread_pool_free(p);
    return 0;
}

fn check_free_non_crashing() -> i64 {
    let p: i64 = thread_pool_new(2);
    thread_pool_free(p);
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_new_valid();
    fails = fails + check_distinct_pools();
    fails = fails + check_single_thread_pool();
    fails = fails + check_free_non_crashing();
    return fails;
}
