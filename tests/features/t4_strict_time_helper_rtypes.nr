// T-4 strict inference positive lock for direct scalar time/clock helper returns.
// These runtime helpers are callable without rod imports, so strict mode must
// know their i64 return types instead of using the empty sentinel.

fn main() -> i64 {
    let start_ms: i64 = time_wall_ms();
    let wall_ns: i64 = time_wall_ns();
    let wall_us: i64 = time_wall_us();
    let wall_s: i64 = time_wall_seconds();
    let now: i64 = now_ms();
    let mono_ns: i64 = time_monotonic_ns();
    let mono_us: i64 = time_monotonic_us();
    let mono_ms: i64 = time_monotonic_ms();
    let slept_ms: i64 = sleep_ms(1);
    let slept_us: i64 = sleep_us(1);
    let elapsed: i64 = time_elapsed_ms(start_ms);

    let ts: i64 = 1776591045;
    let year: i64 = time_year(ts);
    let month: i64 = time_month(ts);
    let day: i64 = time_day(ts);
    let hour: i64 = time_hour(ts);
    let minute: i64 = time_minute(ts);
    let second: i64 = time_second(ts);
    let weekday: i64 = time_weekday(ts);
    let day_of_year: i64 = time_day_of_year(ts);

    if start_ms < 1700000000000 { return 1; };
    if wall_ns < 1700000000000000000 { return 2; };
    if wall_us < 1700000000000000 { return 3; };
    if wall_s < 1700000000 { return 4; };
    if now <= 0 { return 5; };
    if mono_ns <= 0 || mono_us <= 0 || mono_ms <= 0 { return 6; };
    if slept_ms != 0 || slept_us != 0 { return 7; };
    if elapsed < 0 || elapsed > 5000 { return 8; };

    if year != 2026 { return 9; };
    if month != 4 { return 10; };
    if day != 19 { return 11; };
    if hour != 9 { return 12; };
    if minute != 30 { return 13; };
    if second != 45 { return 14; };
    if weekday != 0 { return 15; };
    if day_of_year != 109 { return 16; };
    return 0;
}
