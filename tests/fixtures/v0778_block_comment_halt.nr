// v0.7.78 negative fixture — Rust block comment `/* ... */` halt.
// Pre-fix the `/` and `*` lexed as separate punct tokens, the
// parser saw `/` at expression start and emitted wrong-class
// `error[NR020]: parse_primary cannot start an expression at
// token kind 23`. Now halts at lex with a precise diag and a
// line-comment workaround pointer.
fn main() -> i64 {
    let x: i64 = 42; /* inline block comment */
    return x;
}
