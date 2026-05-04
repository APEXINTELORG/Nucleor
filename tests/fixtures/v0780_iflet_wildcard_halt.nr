// v0.7.80 negative fixture — Rust wildcard pattern in if-let halt.
// Pre-fix `if let _ = x { ... }` surfaced as wrong-class
// `error[NR020]: parse_primary cannot start an expression at
// token kind 11` (`let`) because the if-let pattern dispatcher
// had no `_` branch — it tried Some/None/Ok/Err and Type::Variant,
// neither matched, and the parser fell through. Now halts cleanly
// with a workaround pointer (`let _ = expr;` for the discard +
// `if true { ... }` for the conditional, or just inline the body).
// Sister to v0.7.50 or-pattern halt.
fn main() -> i64 {
    let x: i64 = 5;
    if let _ = x { return 1; };
    return 0;
}
