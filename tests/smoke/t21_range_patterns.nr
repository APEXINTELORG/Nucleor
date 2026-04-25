// T2.1 (v0.2.347) smoke: range patterns in match.
// Both inclusive `LO..=HI` and exclusive `LO..HI` are recognized
// at parse time. Half-open `LO..HI` normalizes to `LO..=(HI-1)`.
// LO > HI emits a __range_bad arm + MATCH-007 warning.
//
// Lower side has been wired since the original RFC-0023 phase —
// T2.1 just connects the parser to the existing infrastructure.
//
// Negative-bound ranges (`-5..=-1`) require unary-minus token
// support which lands in T2.1b — the lexer treats `-` as a
// binary operator today. Workaround: shift the range or use a
// guard.

fn classify_inclusive(n: i64) -> i64 {
    return match n {
        0 => 0,
        1..=9 => 1,
        10..=99 => 2,
        _ => 3,
    };
}

fn classify_exclusive(n: i64) -> i64 {
    return match n {
        0..10 => 1,         // 0..=9
        10..100 => 2,       // 10..=99
        100..1000 => 3,     // 100..=999
        _ => 4,
    };
}

#[test]
fn test_range_inclusive_boundaries() {
    assert_eq(classify_inclusive(0), 0);
    assert_eq(classify_inclusive(1), 1);
    assert_eq(classify_inclusive(9), 1);
    assert_eq(classify_inclusive(10), 2);
    assert_eq(classify_inclusive(99), 2);
    assert_eq(classify_inclusive(100), 3);
}

#[test]
fn test_range_exclusive_normalizes() {
    // 0..10 means 0..=9 — bound 10 should NOT match
    assert_eq(classify_exclusive(0), 1);
    assert_eq(classify_exclusive(9), 1);
    assert_eq(classify_exclusive(10), 2);
    assert_eq(classify_exclusive(99), 2);
    assert_eq(classify_exclusive(100), 3);
    assert_eq(classify_exclusive(999), 3);
    assert_eq(classify_exclusive(1000), 4);
}

#[test]
fn test_range_falls_through_to_wildcard() {
    // Values that don't match any range hit the wildcard arm
    assert_eq(classify_inclusive(0 - 1), 3);
    assert_eq(classify_inclusive(0 - 100), 3);
    assert_eq(classify_inclusive(1000), 3);
    assert_eq(classify_exclusive(0 - 1), 4);
}
