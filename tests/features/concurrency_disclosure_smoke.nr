// v0.8.310/v0.8.311 R04-D5 Phase 1 — concurrency + thread + atomic
// rod disclosures.
//
// Locks 13 invariants (extended in v0.8.311/v0836):
//   1. concurrency_limitations names "SEQUENTIAL FALLBACK"
//   2. conc_map_is_parallel() = 0 (sequential per v0.8.270)
//   3. thread_limitations names "REAL parallel"
//   4. thread_pool_is_parallel() = 1
//   5. concurrency_limitations names "STRUCTURED-CONCURRENCY"
//   6. thread_limitations names "WORK-STEALING"
//   7. atomic_limitations names "WIDTHS"
//   8. atomic_limitations names "WAIT/NOTIFY"
//   9. thread_limitations names "thread_barrier"
//   10. concurrency_limitations points callers to "thread_barrier"
//   11. concurrency_limitations names "MUTEX LIFECYCLE"
//   12. concurrency_limitations names "CHANNEL CLOSE"
//   13. atomic_limitations names "C-17"
//
// Expected: rc=0.

import "stdlib/rods/concurrency.nr"
import "stdlib/rods/thread.nr"
import "stdlib/rods/atomic.nr"

fn check_conc_limits() -> i64 {
    let s: str = concurrency_limitations();
    if str_len(s) == 0 { return 1; };
    if str_index_of(s, "SEQUENTIAL FALLBACK") < 0 { return 2; };
    if str_index_of(s, "STRUCTURED-CONCURRENCY") < 0 { return 4; };
    if str_index_of(s, "thread_barrier") < 0 { return 4096; };
    if str_index_of(s, "MUTEX LIFECYCLE") < 0 { return 8192; };
    if str_index_of(s, "CHANNEL CLOSE") < 0 { return 16384; };
    return 0;
}

fn check_conc_parallel_flag() -> i64 {
    if conc_map_is_parallel() != 0 { return 8; };
    return 0;
}

fn check_thread_limits() -> i64 {
    let s: str = thread_limitations();
    if str_len(s) == 0 { return 16; };
    if str_index_of(s, "REAL parallel") < 0 { return 32; };
    if str_index_of(s, "WORK-STEALING") < 0 { return 64; };
    if str_index_of(s, "thread_barrier") < 0 { return 2048; };
    return 0;
}

fn check_thread_parallel_flag() -> i64 {
    if thread_pool_is_parallel() != 1 { return 128; };
    return 0;
}

fn check_atomic_limits() -> i64 {
    let s: str = atomic_limitations();
    if str_len(s) == 0 { return 256; };
    if str_index_of(s, "WIDTHS") < 0 { return 512; };
    if str_index_of(s, "WAIT/NOTIFY") < 0 { return 1024; };
    if str_index_of(s, "C-17") < 0 { return 32768; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_conc_limits();
    fails = fails + check_conc_parallel_flag();
    fails = fails + check_thread_limits();
    fails = fails + check_thread_parallel_flag();
    fails = fails + check_atomic_limits();
    return fails;
}
