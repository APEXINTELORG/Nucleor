// v0.8.162 stdlib/rods/datetime.nr first test coverage.
//
// Date/time arithmetic — UTC ymd construction, decomposition,
// day/hour add, day-of-week, ISO parse. Pre-v0.8.162: zero
// coverage.
//
// Locks five textbook calendar-arithmetic invariants:
//   1. **UTC ymd round-trip**: from_ymd_utc(2026,5,4,12,30,45) →
//      to_ymd → [2026,5,4,12,30,45] back exactly.
//   2. **diff_days**: 2026-05-04 minus 2026-05-01 == 3.
//   3. **add_days**: 2026-05-01 + 3 days == 2026-05-04.
//   4. **add_hours wraps days**: 2026-05-01 12:00 + 24h ==
//      2026-05-02 12:00.
//   5. **day_of_week** for 2026-05-04 (a Monday in 2026).
//      tm_wday: 0=Sun, 1=Mon, ..., 6=Sat.
//
// Expected: rc=0.

import "stdlib/rods/datetime.nr"

fn check_ymd_round_trip() -> i64 {
    let ts: i64 = dt_from_ymd_utc(2026, 5, 4, 12, 30, 45);
    let parts: i64 = dt_to_ymd(ts);
    if vec_get(parts, 0) != 2026 { return 1; };
    if vec_get(parts, 1) != 5 { return 2; };
    if vec_get(parts, 2) != 4 { return 4; };
    if vec_get(parts, 3) != 12 { return 8; };
    if vec_get(parts, 4) != 30 { return 16; };
    if vec_get(parts, 5) != 45 { return 32; };
    return 0;
}

fn check_diff_days() -> i64 {
    let t1: i64 = dt_from_ymd_utc(2026, 5, 1, 0, 0, 0);
    let t2: i64 = dt_from_ymd_utc(2026, 5, 4, 0, 0, 0);
    if dt_diff_days(t1, t2) != 3 { return 64; };
    return 0;
}

fn check_add_days() -> i64 {
    let t: i64 = dt_from_ymd_utc(2026, 5, 1, 0, 0, 0);
    let plus3: i64 = dt_add_days(t, 3);
    let parts: i64 = dt_to_ymd(plus3);
    if vec_get(parts, 0) != 2026 { return 128; };
    if vec_get(parts, 1) != 5 { return 256; };
    if vec_get(parts, 2) != 4 { return 512; };
    return 0;
}

fn check_add_hours_wraps() -> i64 {
    let t: i64 = dt_from_ymd_utc(2026, 5, 1, 12, 0, 0);
    let plus24h: i64 = dt_add_hours(t, 24);
    let parts: i64 = dt_to_ymd(plus24h);
    if vec_get(parts, 2) != 2 { return 1024; };
    if vec_get(parts, 3) != 12 { return 2048; };
    return 0;
}

fn check_day_of_week() -> i64 {
    // 2026-05-04 is a Monday → 1
    let t: i64 = dt_from_ymd_utc(2026, 5, 4, 12, 0, 0);
    let dow: i64 = dt_day_of_week(t);
    if dow != 1 { return 4096; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_ymd_round_trip();
    fails = fails + check_diff_days();
    fails = fails + check_add_days();
    fails = fails + check_add_hours_wraps();
    fails = fails + check_day_of_week();
    return fails;
}
