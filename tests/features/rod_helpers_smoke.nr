// v0.8.200 stdlib/rods/rod_helpers.nr first test coverage.
//
// Cross-rod interop helpers — Vec<str> bridge + fn-pointer
// callers. Pre-v0.8.200: zero coverage.
//
// Locks two invariants on the str-bridge surface (fn-pointer
// surface needs callback fixtures which are out of smoke scope):
//
//   1. **vec_str_push + vec_str_get round-trip** — push 3
//      strings, read each back exactly.
//   2. **hvec_str_set + get** — overwrite an existing entry.
//
// Expected: rc=0.

import "stdlib/rods/rod_helpers.nr"

fn check_vec_str_round_trip() -> i64 {
    let v: i64 = vec_new();
    vec_str_push(v, "alpha");
    vec_str_push(v, "beta");
    vec_str_push(v, "gamma");
    if str_eq(vec_str_get(v, 0), "alpha") != 1 { return 1; };
    if str_eq(vec_str_get(v, 1), "beta") != 1 { return 2; };
    if str_eq(vec_str_get(v, 2), "gamma") != 1 { return 4; };
    return 0;
}

fn check_hvec_str_set() -> i64 {
    let v: i64 = vec_new();
    hvec_str_push(v, "first");
    hvec_str_push(v, "second");
    hvec_str_set(v, 0, "replaced");
    if str_eq(hvec_str_get(v, 0), "replaced") != 1 { return 8; };
    if str_eq(hvec_str_get(v, 1), "second") != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_vec_str_round_trip();
    fails = fails + check_hvec_str_set();
    return fails;
}
