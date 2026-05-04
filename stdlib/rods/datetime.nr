// =====================================================
// rods/datetime — Date/time operations
// =====================================================
// Import: import "stdlib/rods/datetime.nr"
// Provides: now, year/month/day construction + decomposition,
//   day arithmetic, ISO parse, day-of-week.
// =====================================================

#cfile "../runtime/datetime_rt.c"

extern fn nuc_dt_now() -> i64;
extern fn nuc_dt_from_ymd(y: i64, m: i64, d: i64, hh: i64, mm: i64, ss: i64) -> i64;
extern fn nuc_dt_from_ymd_utc(y: i64, m: i64, d: i64, hh: i64, mm: i64, ss: i64) -> i64;
extern fn nuc_dt_to_ymd(ts_ms: i64) -> i64;
extern fn nuc_dt_diff_days(a: i64, b: i64) -> i64;
extern fn nuc_dt_diff_seconds(a: i64, b: i64) -> i64;
extern fn nuc_dt_add_days(ts_ms: i64, n: i64) -> i64;
extern fn nuc_dt_add_hours(ts_ms: i64, n: i64) -> i64;
extern fn nuc_dt_day_of_week(ts_ms: i64) -> i64;
extern fn nuc_dt_parse_iso(s: str) -> i64;
extern fn nuc_dt_elapsed_us(start_ms: i64) -> i64;

fn dt_now() -> i64 { return nuc_dt_now(); }
fn dt_from_ymd(y: i64, m: i64, d: i64, hh: i64, mm: i64, ss: i64) -> i64 { return nuc_dt_from_ymd(y, m, d, hh, mm, ss); }
// v0.8.106: companion that interprets components as UTC (round-
// trips with dt_to_ymd which uses gmtime). Use this for
// machine-to-machine / log timestamps. dt_from_ymd remains for
// local-time interpretation.
fn dt_from_ymd_utc(y: i64, m: i64, d: i64, hh: i64, mm: i64, ss: i64) -> i64 { return nuc_dt_from_ymd_utc(y, m, d, hh, mm, ss); }
fn dt_to_ymd(ts_ms: i64) -> i64 { return nuc_dt_to_ymd(ts_ms); }
fn dt_diff_days(a: i64, b: i64) -> i64 { return nuc_dt_diff_days(a, b); }
fn dt_diff_seconds(a: i64, b: i64) -> i64 { return nuc_dt_diff_seconds(a, b); }
fn dt_add_days(ts_ms: i64, n: i64) -> i64 { return nuc_dt_add_days(ts_ms, n); }
fn dt_add_hours(ts_ms: i64, n: i64) -> i64 { return nuc_dt_add_hours(ts_ms, n); }
fn dt_day_of_week(ts_ms: i64) -> i64 { return nuc_dt_day_of_week(ts_ms); }
fn dt_parse_iso(s: str) -> i64 { return nuc_dt_parse_iso(s); }
fn dt_elapsed_us(start_ms: i64) -> i64 { return nuc_dt_elapsed_us(start_ms); }
