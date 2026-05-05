// v0.8.129 stdlib/rods/env.nr first test coverage.
//
// Environment variable utilities. Tests rely on the host having
// PATH set (universally true on POSIX + Windows) and a known
// fictitious var being unset.
//
// Locks:
//   1. env_get on common var (PATH) returns non-empty string.
//   2. env_has(PATH) returns 1.
//   3. env_get on never-set var returns "".
//   4. env_has on never-set var returns 0.
//
// Expected: rc=0.

import "stdlib/rods/env.nr"

fn check_path_set() -> i64 {
    let p: str = env_get("PATH");
    // PATH is always set on POSIX and Windows hosts — non-empty.
    if str_len(p) <= 0 { return 1; };
    if env_has("PATH") != 1 { return 2; };
    return 0;
}

fn check_missing_var() -> i64 {
    // Pick a clearly-fictitious var name to ensure it's not set.
    let unset: str = env_get("NUCLEOR_TEST_VAR_DOES_NOT_EXIST_123XYZ");
    if str_len(unset) != 0 { return 4; };
    if env_has("NUCLEOR_TEST_VAR_DOES_NOT_EXIST_123XYZ") != 0 { return 8; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_path_set();
    fails = fails + check_missing_var();
    return fails;
}
