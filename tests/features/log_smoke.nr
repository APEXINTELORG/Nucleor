// v0.8.207 stdlib/rods/log.nr first test coverage.
//
// Structured logging with severity levels (DEBUG/INFO/WARN/
// ERROR/FATAL). Pre-v0.8.207: zero coverage on the standalone
// rod.
//
// Locks four invariants on the level/store API. The emit-side
// effect (printing to stdout) is intentionally NOT tested — the
// fixture verifies the gating logic so emit failures surface as
// "level under threshold returns without printing" via the
// store API instead of via stdout capture.
//
//   1. Stable level constants — DEBUG=0, INFO=1, WARN=2,
//      ERROR=3, FATAL=4 (wire stability).
//   2. Default store level == INFO — log_level_store()
//      ships at 1 so DEBUG is filtered by default.
//   3. set/get round-trip — set_level(WARN), get_level == WARN.
//   4. Last-write-wins — set_level called twice; only the
//      second value is observed.
//
// Expected: rc=0.

import "stdlib/rods/log.nr"

fn check_level_constants() -> i64 {
    if LOG_DEBUG() != 0 { return 1; };
    if LOG_INFO() != 1 { return 2; };
    if LOG_WARN() != 2 { return 4; };
    if LOG_ERROR() != 3 { return 8; };
    if LOG_FATAL() != 4 { return 16; };
    return 0;
}

fn check_default_level() -> i64 {
    let s: Vec<i32> = log_level_store();
    if log_get_level(s) != 1 { return 32; };
    return 0;
}

fn check_set_get_round_trip() -> i64 {
    let s: Vec<i32> = log_level_store();
    log_set_level(s, LOG_WARN());
    if log_get_level(s) != LOG_WARN() { return 64; };
    return 0;
}

fn check_last_write_wins() -> i64 {
    let s: Vec<i32> = log_level_store();
    log_set_level(s, LOG_DEBUG());
    log_set_level(s, LOG_FATAL());
    if log_get_level(s) != LOG_FATAL() { return 128; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_level_constants();
    fails = fails + check_default_level();
    fails = fails + check_set_get_round_trip();
    fails = fails + check_last_write_wins();
    return fails;
}
