// =====================================================
// rods/time — Time utilities
// =====================================================
// Import: import "stdlib/rods/time.nr"
// Provides: time_now_ms, time_sleep_ms, time_format_ms
// =====================================================

#cfile "time_rt.c"

extern fn rods_time_now_ms() -> i64;
extern fn rods_time_sleep_ms(ms: i64);
extern fn rods_time_format_ms(ms: i64) -> str;

// Returns current time as milliseconds since Unix epoch
fn time_now_ms() -> i64 {
    return rods_time_now_ms();
}

// Sleep for the given number of milliseconds
fn time_sleep_ms(ms: i64) {
    rods_time_sleep_ms(ms);
}

// Format milliseconds since epoch as "YYYY-MM-DD HH:MM:SS"
fn time_format_ms(ms: i64) -> str {
    return rods_time_format_ms(ms);
}
