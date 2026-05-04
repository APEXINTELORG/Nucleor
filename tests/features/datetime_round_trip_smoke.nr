// v0.8.106 stdlib/rods/datetime.nr — full coverage including
// hour-precise UTC round-trip via the new dt_from_ymd_utc
// companion.
//
// History:
//   v0.8.96 caught the dt_from_ymd / dt_to_ymd asymmetry
//     (mktime local-time input vs gmtime UTC output drifted
//     by tz offset). Locked structural-only assertions.
//   v0.8.106 adds dt_from_ymd_utc (uses _mkgmtime / timegm),
//     enabling exact-hour round-trip. This fixture upgraded to
//     assert that.
//
// Locks:
//   1. dt_from_ymd_utc + dt_to_ymd hour-precise round-trip:
//      every component (year/month/day/hour/min/sec) survives.
//   2. dt_from_ymd (local time) date-only round-trip with noon
//      anchor — preserved for backwards compatibility tests.
//   3. dt_add_days(t, 7) advances by exactly 7 days.
//   4. dt_add_hours(t, 24) == dt_add_days(t, 1).
//   5. dt_diff_days is the inverse of dt_add_days.
//   6. dt_parse_iso returns a non-zero handle for valid ISO.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/datetime.nr"

fn check_utc_round_trip_hour_precise() -> i64 {
    // The whole point of v0.8.106: hour, minute, second all
    // survive a UTC round-trip.
    let t: i64 = dt_from_ymd_utc(2026, 5, 4, 12, 34, 56);
    let parts: Vec<i32> = dt_to_ymd(t);
    if vec_len(parts) != 6 { return 1; };
    if vec_get(parts, 0) != 2026 { return 2; };
    if vec_get(parts, 1) != 5 { return 4; };
    if vec_get(parts, 2) != 4 { return 8; };
    if vec_get(parts, 3) != 12 { return 16; };
    if vec_get(parts, 4) != 34 { return 32; };
    if vec_get(parts, 5) != 56 { return 64; };
    return 0;
}

fn check_local_date_round_trip_noon_anchor() -> i64 {
    // dt_from_ymd retains its original local-time semantics.
    // Noon anchor avoids tz-driven day rollover; hours are not
    // asserted because mktime input vs gmtime output drifts by
    // tz offset (the original v0.8.96 behavior, intentionally
    // preserved for backwards compat).
    let t: i64 = dt_from_ymd(2026, 5, 4, 12, 0, 0);
    let parts: Vec<i32> = dt_to_ymd(t);
    if vec_len(parts) != 6 { return 128; };
    if vec_get(parts, 0) != 2026 { return 256; };
    if vec_get(parts, 1) != 5 { return 512; };
    if vec_get(parts, 2) != 4 { return 1024; };
    return 0;
}

fn check_add_days() -> i64 {
    let t: i64 = dt_from_ymd_utc(2026, 5, 4, 0, 0, 0);
    let t7: i64 = dt_add_days(t, 7);
    let parts: Vec<i32> = dt_to_ymd(t7);
    if vec_get(parts, 0) != 2026 { return 2048; };
    if vec_get(parts, 1) != 5 { return 4096; };
    if vec_get(parts, 2) != 11 { return 8192; };
    return 0;
}

fn check_add_hours_consistency() -> i64 {
    let t: i64 = dt_from_ymd_utc(2026, 5, 4, 0, 0, 0);
    let t24h: i64 = dt_add_hours(t, 24);
    let t1d: i64 = dt_add_days(t, 1);
    if t24h != t1d { return 16384; };
    return 0;
}

fn check_diff_days_inverse() -> i64 {
    let a: i64 = dt_from_ymd_utc(2026, 5, 4, 0, 0, 0);
    let b: i64 = dt_add_days(a, 30);
    let diff: i64 = dt_diff_days(b, a);
    if diff != 30 { return 32768; };
    return 0;
}

fn check_iso_parse_smoke() -> i64 {
    let t: i64 = dt_parse_iso("2026-05-04T12:00:00");
    if t == 0 { return 65536; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_utc_round_trip_hour_precise();
    fails = fails + check_local_date_round_trip_noon_anchor();
    fails = fails + check_add_days();
    fails = fails + check_add_hours_consistency();
    fails = fails + check_diff_days_inverse();
    fails = fails + check_iso_parse_smoke();
    return fails;
}
