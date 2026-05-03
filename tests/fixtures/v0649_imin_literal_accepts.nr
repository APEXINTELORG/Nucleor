// v0.6.49 (probe finding 2026-05-02-num-021-coverage-gaps-u64-imin-shift-divzero
// gap 2): canonical Rust literal `-9223372036854775808` (= i64::MIN) is now
// accepted at compile time. Pre-fix the literal triggered NUM-021 false-fire
// because the inner literal `9223372036854775808` overflowed u64::MAX-check
// at the lexer-NUM-021 boundary, then unary-minus on the wrapped i64::MIN
// value flagged overflow at the const evaluator.
const IMIN: i64 = -9223372036854775808;
const IMIN_PLUS_ONE: i64 = -9223372036854775807;

fn main() -> i32 {
    print(str_from_int(IMIN));
    print(str_from_int(IMIN_PLUS_ONE));
    return 0;
}
