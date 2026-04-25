// T3.20 (v0.3.36, extended v0.3.38) — DIAG-001 unknown-code
// warning. Each of the four allow/deny shapes references a
// CODE that is NOT in the canonical diagnostic code set.
// v0.3.36's emit_diag001_unknown_codes pass (with v0.3.38's
// enumerated check) should flag each one.
//
// Coverage:
//   * 4 unknown-prefix codes (WAT-001, BOGUS-002,
//     GIBBERISH-003, NONSENSE-004) — caught since v0.3.36
//   * 1 within-series typo (RT-099 — has the canonical RT-
//     prefix but isn't in the v0.3.38 enumerated code set) —
//     caught since v0.3.38
//
// Verify gate (T3.20) asserts:
//   * DIAG-001 fires exactly five times (one per offending
//     attribute below)
//   * Each warning quotes the offending code substring
//
// The KNOWN-good attribute below (#[allow_fn(RT-007)]) must
// NOT fire DIAG-001 — RT-007 is a real shipped code.

// 1. file-wide allow with non-canonical prefix (caught v0.3.36)
#[allow(WAT-001)]

// 2. file-wide deny with non-canonical prefix (caught v0.3.36)
#[deny(BOGUS-002)]

#[allow_fn(GIBBERISH-003)]
fn first_unknown(x: i64) -> i64 {
    return x + 1;
}

#[deny_fn(NONSENSE-004)]
fn second_unknown(x: i64) -> i64 {
    return x + 2;
}

// Within-series typo (caught v0.3.38). RT- prefix is canonical
// but RT-099 isn't in the enumerated set. Catches the class
// the v0.3.36 prefix-only check intentionally let through.
#[allow_fn(RT-099)]
fn within_series_typo(x: i64) -> i64 {
    return x + 4;
}

// Control: known code should NOT fire DIAG-001.
#[allow_fn(RT-007)]
fn known_code_ok(x: i64) -> i64 {
    return x + 3;
}

fn main() -> i64 {
    return first_unknown(0) + second_unknown(0)
         + within_series_typo(0) + known_code_ok(0);
}
