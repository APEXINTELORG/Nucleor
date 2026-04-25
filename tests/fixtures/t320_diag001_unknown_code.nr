// T3.20 (v0.3.36) — DIAG-001 unknown-code warning. Each of
// the four allow/deny shapes references a CODE whose prefix is
// NOT in the canonical diagnostic series set. v0.3.36's
// emit_diag001_unknown_codes pass should flag each one.
//
// Verify gate (T3.20) asserts:
//   * DIAG-001 fires exactly four times (one per offending
//     attribute below)
//   * Each warning quotes the offending code substring
//
// The KNOWN-good attribute below (#[allow_fn(RT-007)]) must NOT
// fire DIAG-001 (its prefix RT- is canonical).

// 1. file-wide allow with non-canonical prefix
#[allow(WAT-001)]

// 2. file-wide deny with non-canonical prefix
#[deny(BOGUS-002)]

#[allow_fn(GIBBERISH-003)]
fn first_unknown(x: i64) -> i64 {
    return x + 1;
}

#[deny_fn(NONSENSE-004)]
fn second_unknown(x: i64) -> i64 {
    return x + 2;
}

// Control: known prefix should NOT fire DIAG-001 even though
// RT-007 isn't actually a code that fires from this fn body.
#[allow_fn(RT-007)]
fn known_prefix_ok(x: i64) -> i64 {
    return x + 3;
}

fn main() -> i64 {
    return first_unknown(0) + second_unknown(0) + known_prefix_ok(0);
}
