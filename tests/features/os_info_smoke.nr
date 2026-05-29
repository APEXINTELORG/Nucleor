// v0.8.219 stdlib/rods/os_info.nr first test coverage.
//
// OS family detection + pointer-width queries + cross-platform
// env mutation. Pre-v0.8.219: zero coverage on the standalone
// rod.
//
// Locks four invariants. The fixture is built / run on Windows
// (CWD is C:\windows\system32) so the active OS is Windows.
// On a different host, swap the os_is_windows asserts for the
// matching family.
//
//   1. Exactly one OS family is true — Windows / Linux /
//      macOS / BSD are mutually exclusive; sum to 1.
//   2. Family name matches the boolean — os_is_windows()
//      ↔ os_family_name() == "windows".
//   3. 64-bit pointer width — os_is_64bit() == 1 and
//      os_pointer_bits() == 64 (we don't ship 32-bit Nucleor).
//   4. env round-trip — env_set + getenv read; env_unset
//      removes (getenv returns "" or empty).
//
// Expected: rc=0.

import "stdlib/rods/os_info.nr"
import "stdlib/rods/os.nr"

fn check_exactly_one_family() -> i64 {
    let s: i64 = os_is_windows() + os_is_linux() + os_is_macos() + os_is_bsd();
    if s != 1 { return 1; };
    return 0;
}

fn check_family_name_matches() -> i64 {
    if os_is_windows() == 1 {
        if str_eq(os_family_name(), "windows") != 1 { return 2; };
    };
    if os_is_linux() == 1 {
        if str_eq(os_family_name(), "linux") != 1 { return 4; };
    };
    if os_is_macos() == 1 {
        if str_eq(os_family_name(), "macos") != 1 { return 8; };
    };
    if os_is_bsd() == 1 {
        if str_eq(os_family_name(), "bsd") != 1 { return 16; };
    };
    return 0;
}

fn check_64bit_pointer_width() -> i64 {
    if os_is_64bit() != 1 { return 32; };
    if os_pointer_bits() != 64 { return 64; };
    return 0;
}

fn check_env_round_trip() -> i64 {
    os_env_set("NUCLEOR_OS_INFO_SMOKE_TEST", "hello");
    if str_eq(getenv("NUCLEOR_OS_INFO_SMOKE_TEST"), "hello") != 1 { return 128; };
    os_env_unset("NUCLEOR_OS_INFO_SMOKE_TEST");
    if str_eq(getenv("NUCLEOR_OS_INFO_SMOKE_TEST"), "hello") == 1 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_exactly_one_family();
    fails = fails + check_family_name_matches();
    fails = fails + check_64bit_pointer_width();
    fails = fails + check_env_round_trip();
    return fails;
}
