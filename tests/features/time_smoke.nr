// v0.8.169 stdlib/rods/time.nr first test coverage.
//
// Legacy wall-clock time API (the typed-time API time_typed.nr
// covered at v0.8.164 is the modern replacement). Pre-v0.8.169:
// zero coverage.
//
// Locks three textbook invariants:
//   1. Plausible epoch — time_now_ms returns ms-since-epoch
//      in [1.7e12, 4.0e12] (post-2023, pre-2096).
//   2. Sleep advances time_now_ms — sleep 5ms → delta ≥ 4.
//   3. time_format_ms produces 19-char string — "YYYY-MM-DD
//      HH:MM:SS" is exactly 19 chars (4+1+2+1+2+1+2+1+2+1+2 = 19).
//
// Expected: rc=0.

import "stdlib/rods/time.nr"

fn check_plausible_epoch() -> i64 {
    let t: i64 = time_now_ms();
    if t < 1700000000000 { return 1; };
    if t > 4000000000000 { return 2; };
    return 0;
}

fn check_sleep_advances() -> i64 {
    let start: i64 = time_now_ms();
    time_sleep_ms(5);
    let after: i64 = time_now_ms();
    if after - start < 4 { return 4; };
    return 0;
}

fn check_format_length() -> i64 {
    let t: i64 = time_now_ms();
    let s: str = time_format_ms(t);
    if str_len(s) != 19 { return 8; };
    // Verify it's "YYYY-MM-DD HH:MM:SS" shape: dashes at 4, 7;
    // space at 10; colons at 13, 16.
    if str_char_at(s, 4) != 45 { return 16; };  // -
    if str_char_at(s, 7) != 45 { return 32; };
    if str_char_at(s, 10) != 32 { return 64; }; // space
    if str_char_at(s, 13) != 58 { return 128; }; // :
    if str_char_at(s, 16) != 58 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_plausible_epoch();
    fails = fails + check_sleep_advances();
    fails = fails + check_format_length();
    return fails;
}
