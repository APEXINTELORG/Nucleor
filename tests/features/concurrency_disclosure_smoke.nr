// v0.8.310 R04-D5 Phase 1 — concurrency + thread rod disclosures.
//
// Locks 6 invariants:
//   1. concurrency_limitations names "SEQUENTIAL FALLBACK"
//   2. conc_map_is_parallel() = 0 (sequential per v0.8.270)
//   3. thread_limitations names "REAL parallel"
//   4. thread_pool_is_parallel() = 1
//   5. concurrency_limitations names "STRUCTURED-CONCURRENCY"
//   6. thread_limitations names "WORK-STEALING"
//
// Expected: rc=0.

import "stdlib/rods/concurrency.nr"
import "stdlib/rods/thread.nr"

fn check_conc_limits() -> i64 {
    let s: str = concurrency_limitations();
    if str_len(s) == 0 { return 1; };
    if str_index_of(s, "SEQUENTIAL FALLBACK") < 0 { return 2; };
    if str_index_of(s, "STRUCTURED-CONCURRENCY") < 0 { return 4; };
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
    return 0;
}

fn check_thread_parallel_flag() -> i64 {
    if thread_pool_is_parallel() != 1 { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_conc_limits();
    fails = fails + check_conc_parallel_flag();
    fails = fails + check_thread_limits();
    fails = fails + check_thread_parallel_flag();
    return fails;
}
