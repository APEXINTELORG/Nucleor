// v0.8.164 stdlib/rods/time_typed.nr first test coverage.
//
// Robotics-RFC §5.1 typed time API: distinct monotonic vs
// wall-clock surfaces + sleep granularity (ms / us). Pre-
// v0.8.164: zero coverage.
//
// Locks four textbook clock invariants:
//   1. Monotonic non-decreasing — back-to-back reads of
//      `time_mono_ns` return non-decreasing values (the
//      defining property of a monotonic clock).
//   2. Sleep advances monotonic clock — sleeping 5ms
//      advances mono_ms by ≥4 (allow 1ms of slop for short
//      sleep granularity).
//   3. Wall clock returns plausible epoch — wall_seconds
//      should be > 1700000000 (post-2023) and < 4000000000
//      (pre-2096).
//   4. time_elapsed_ms self-consistency — start = mono_ms,
//      elapsed = mono_ms - start ≥ 0.
//
// Expected: rc=0.

import "stdlib/rods/time_typed.nr"

fn check_mono_non_decreasing() -> i64 {
    let t1: i64 = time_mono_ns();
    let t2: i64 = time_mono_ns();
    if t2 < t1 { return 1; };
    return 0;
}

fn check_sleep_advances_mono() -> i64 {
    let start: i64 = time_mono_ms();
    time_sleep_milliseconds(5);
    let after: i64 = time_mono_ms();
    if after - start < 4 { return 2; };
    return 0;
}

fn check_wall_plausible() -> i64 {
    let s: i64 = time_wall_seconds_since_epoch();
    if s < 1700000000 { return 4; };
    if s > 4000000000 { return 8; };
    return 0;
}

fn check_elapsed_self_consistent() -> i64 {
    let start: i64 = time_mono_ms();
    let e: i64 = time_elapsed_ms(start);
    if e < 0 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_mono_non_decreasing();
    fails = fails + check_sleep_advances_mono();
    fails = fails + check_wall_plausible();
    fails = fails + check_elapsed_self_consistent();
    return fails;
}
