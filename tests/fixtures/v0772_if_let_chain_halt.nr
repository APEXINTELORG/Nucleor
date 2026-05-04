// v0.7.72 negative fixture — Rust 2024 if-let chain halt.
// Pre-fix `if let Some(x) = opt && x > 10 { ... }` surfaced as
// wrong-class `error[TYP-005]: undefined function 'x()'` at clang
// link because parse_expr greedily consumed `opt && x > 10` as a
// single scrutinee that referenced `x` BEFORE the match-arm could
// bind it. Now halts at the if-let parser when scanning the
// scrutinee tokens for `&&`.
fn maybe(b: bool) -> Option<i64> {
    if b { return Some(42); };
    return None;
}

fn main() -> i64 {
    let opt: Option<i64> = maybe(true);
    if let Some(x) = opt && x > 10 {
        return x;
    };
    return 0;
}
