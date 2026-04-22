// time_decompose — RFC-0017 stdlib enrichment.
//
//   time_year(unix_seconds)        -> i64
//   time_month(unix_seconds)       -> i64   1..12
//   time_day(unix_seconds)         -> i64   1..31
//   time_hour(unix_seconds)        -> i64   0..23
//   time_minute(unix_seconds)      -> i64   0..59
//   time_second(unix_seconds)      -> i64   0..60
//   time_weekday(unix_seconds)     -> i64   0=Sun..6=Sat
//   time_day_of_year(unix_seconds) -> i64   1..366
//   time_elapsed_ms(start_ms)      -> i64

fn main() -> i64 {
    let mut fail: i64 = 0;

    // 2026-04-19 09:30:45 UTC = 1776591045 unix seconds (Sunday)
    let ts: i64 = 1776591045;

    if time_year(ts) != 2026   { fail = fail + 1; print("FAIL time_year"); };
    if time_month(ts) != 4     { fail = fail + 1; print("FAIL time_month"); };
    if time_day(ts) != 19      { fail = fail + 1; print("FAIL time_day"); };
    if time_hour(ts) != 9      { fail = fail + 1; print("FAIL time_hour"); };
    if time_minute(ts) != 30   { fail = fail + 1; print("FAIL time_minute"); };
    if time_second(ts) != 45   { fail = fail + 1; print("FAIL time_second"); };
    // Sunday => tm_wday == 0
    if time_weekday(ts) != 0   { fail = fail + 1; print("FAIL time_weekday"); };
    // Day of year: Jan(31)+Feb(28)+Mar(31)+19 = 109
    if time_day_of_year(ts) != 109 { fail = fail + 1; print("FAIL time_day_of_year"); };

    // Epoch (1970-01-01 00:00:00 UTC)
    if time_year(0) != 1970     { fail = fail + 1; print("FAIL epoch year"); };
    if time_month(0) != 1       { fail = fail + 1; print("FAIL epoch month"); };
    if time_day(0) != 1         { fail = fail + 1; print("FAIL epoch day"); };
    if time_weekday(0) != 4     { fail = fail + 1; print("FAIL epoch weekday"); };

    // time_elapsed_ms: should be small after immediate measure
    let start: i64 = time_wall_ms();
    let elapsed: i64 = time_elapsed_ms(start);
    if elapsed < 0 || elapsed > 5000 {
        fail = fail + 1; print("FAIL time_elapsed_ms range");
    };

    if fail == 0 { print("OK time_decompose"); return 0; };
    return 1;
}
