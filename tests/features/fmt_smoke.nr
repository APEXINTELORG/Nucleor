// v0.8.110 stdlib/rods/fmt.nr first test coverage.
//
// Per the zero-coverage rod survey, fmt.nr (string formatting —
// int/bool/hex/oct/bin, padding, fmt_format template) had no
// existing tests. Silent regressions in any of the converters
// would corrupt every adopter log line / CLI output / debug
// print.
//
// Locks textbook formatting invariants:
//   1. fmt_int round-trips through fmt_to_int.
//   2. fmt_int handles 0, positive, negative, and large values.
//   3. fmt_hex / fmt_oct / fmt_bin produce known-good strings
//      for canonical inputs.
//   4. fmt_bool maps 0 → "false" and any non-zero → "true".
//   5. fmt_pad_left / fmt_pad_right pad to width with the
//      requested character.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/fmt.nr"

fn check_fmt_int_basic() -> i64 {
    if str_eq(fmt_int(0), "0") != 1 { return 1; };
    if str_eq(fmt_int(42), "42") != 1 { return 2; };
    if str_eq(fmt_int(0 - 7), "-7") != 1 { return 4; };
    if str_eq(fmt_int(1000000), "1000000") != 1 { return 8; };
    return 0;
}

fn check_fmt_int_round_trip() -> i64 {
    if fmt_to_int(fmt_int(42)) != 42 { return 16; };
    if fmt_to_int(fmt_int(0 - 13)) != 0 - 13 { return 32; };
    if fmt_to_int(fmt_int(0)) != 0 { return 64; };
    if fmt_to_int(fmt_int(123456)) != 123456 { return 128; };
    return 0;
}

fn check_fmt_bool() -> i64 {
    if str_eq(fmt_bool(0), "false") != 1 { return 256; };
    if str_eq(fmt_bool(1), "true") != 1 { return 512; };
    if str_eq(fmt_bool(42), "true") != 1 { return 1024; };
    return 0;
}

fn check_fmt_hex() -> i64 {
    if str_eq(fmt_hex(0), "0x0") != 1 { return 2048; };
    if str_eq(fmt_hex(255), "0xff") != 1 { return 4096; };
    if str_eq(fmt_hex(16), "0x10") != 1 { return 8192; };
    return 0;
}

fn check_fmt_bin() -> i64 {
    if str_eq(fmt_bin(0), "0b0") != 1 { return 16384; };
    if str_eq(fmt_bin(5), "0b101") != 1 { return 32768; };
    if str_eq(fmt_bin(8), "0b1000") != 1 { return 65536; };
    return 0;
}

fn check_fmt_oct() -> i64 {
    if str_eq(fmt_oct(0), "0o0") != 1 { return 131072; };
    if str_eq(fmt_oct(8), "0o10") != 1 { return 262144; };
    if str_eq(fmt_oct(64), "0o100") != 1 { return 524288; };
    return 0;
}

fn check_fmt_pad_left() -> i64 {
    if str_eq(fmt_pad_left("42", 5, "0"), "00042") != 1 { return 1048576; };
    // shorter than width: padded
    // already at width: unchanged
    if str_eq(fmt_pad_left("hello", 5, " "), "hello") != 1 { return 2097152; };
    return 0;
}

fn check_fmt_pad_right() -> i64 {
    if str_eq(fmt_pad_right("42", 5, "0"), "42000") != 1 { return 4194304; };
    if str_eq(fmt_pad_right("abc", 3, "x"), "abc") != 1 { return 8388608; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_fmt_int_basic();
    fails = fails + check_fmt_int_round_trip();
    fails = fails + check_fmt_bool();
    fails = fails + check_fmt_hex();
    fails = fails + check_fmt_bin();
    fails = fails + check_fmt_oct();
    fails = fails + check_fmt_pad_left();
    fails = fails + check_fmt_pad_right();
    return fails;
}
