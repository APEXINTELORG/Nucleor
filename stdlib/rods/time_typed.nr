// =====================================================
// rods/time_typed — Typed time API (Robotics-RFC §5.1)
// =====================================================
// Import: import "stdlib/rods/time_typed.nr"
//
// Distinct monotonic vs wall-clock APIs. Required for control-loop
// deadlines and replay debugging — see Robotics-RFC §5.1.
//
// Existing rods/time.nr provides the legacy wall-clock-ms-only
// surface. This rod adds:
//   - time_mono_*    — monotonic clock, never goes backwards
//   - time_wall_*    — wall clock (subject to NTP/sleep/system changes)
//   - time_sleep_*   — both ms and us granularity
//
// Use monotonic for: deadlines, intervals, control loops, profiling.
// Use wall for: log timestamps, file modification times, user display.
// =====================================================

// ---- Monotonic clock (never decreasing; safe for deadlines) ----
fn time_mono_ns() -> i64 { return time_monotonic_ns(); }
fn time_mono_us() -> i64 { return time_monotonic_us(); }
fn time_mono_ms() -> i64 { return time_monotonic_ms(); }

// ---- Wall clock (subject to NTP/system-time changes) ----
fn time_wall_seconds_since_epoch() -> i64 { return time_wall_seconds(); }
fn time_wall_ms_since_epoch() -> i64 { return time_wall_ms(); }
fn time_wall_us_since_epoch() -> i64 { return time_wall_us(); }
fn time_wall_ns_since_epoch() -> i64 { return time_wall_ns(); }

// ---- Sleep ----
fn time_sleep_milliseconds(ms: i64) -> i64 { return sleep_ms(ms); }
fn time_sleep_microseconds(us: i64) -> i64 { return sleep_us(us); }

// ---- Convenience helpers ----
// Elapsed monotonic ns between two snapshots.
fn time_elapsed_ns(start: i64) -> i64 {
    return time_monotonic_ns() - start;
}
fn time_elapsed_us(start: i64) -> i64 {
    return time_monotonic_us() - start;
}
fn time_elapsed_ms(start: i64) -> i64 {
    return time_monotonic_ms() - start;
}
