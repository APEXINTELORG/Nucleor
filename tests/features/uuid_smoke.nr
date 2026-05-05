// v0.8.163 stdlib/rods/uuid.nr first test coverage.
//
// UUID v4 generation + nil-UUID helpers. Pre-v0.8.163: zero
// coverage on the standalone uuid rod (uuid_v4 is also re-
// exported via digest.nr at v0.8.130, but uuid.nr's uuid_nil
// + uuid_is_nil have no dedicated coverage).
//
// Locks four format invariants (RFC 4122 §4.4 Random UUID):
//   1. **Length 36** — `xxxxxxxx-xxxx-Mxxx-Vxxx-xxxxxxxxxxxx`
//      = 8 + 4 + 4 + 4 + 12 + 4 dashes = 36 chars.
//   2. **Dashes at indices 8, 13, 18, 23** — always.
//   3. **Version byte == '4'** at index 14 (RFC 4122 v4).
//   4. **uuid_nil + uuid_is_nil** round-trip.
//
// Expected: rc=0.

import "stdlib/rods/uuid.nr"

fn check_v4_length() -> i64 {
    let u: str = uuid_v4();
    if str_len(u) != 36 { return 1; };
    return 0;
}

fn check_v4_dash_positions() -> i64 {
    let u: str = uuid_v4();
    // dash = 0x2D = 45
    if str_char_at(u, 8) != 45 { return 2; };
    if str_char_at(u, 13) != 45 { return 4; };
    if str_char_at(u, 18) != 45 { return 8; };
    if str_char_at(u, 23) != 45 { return 16; };
    return 0;
}

fn check_v4_version_4() -> i64 {
    let u: str = uuid_v4();
    // '4' = 0x34 = 52
    if str_char_at(u, 14) != 52 { return 32; };
    return 0;
}

fn check_nil_round_trip() -> i64 {
    let n: str = uuid_nil();
    if str_eq(n, "00000000-0000-0000-0000-000000000000") != 1 { return 64; };
    if uuid_is_nil(n) != 1 { return 128; };
    if uuid_is_nil(uuid_v4()) != 0 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_v4_length();
    fails = fails + check_v4_dash_positions();
    fails = fails + check_v4_version_4();
    fails = fails + check_nil_round_trip();
    return fails;
}
