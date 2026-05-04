// v0.7.76 negative fixture — Rust 1.79+ `const { ... }` inline-const
// block expression. Pre-fix `let x: i64 = const { 5 + 7 };` surfaced
// as wrong-class `error[NR020]: parse_primary cannot start an
// expression at token kind 73` because parse_primary had no
// `const`-prefix branch at expr start. Now halts cleanly with
// workaround pointer (use a module-scope `const NAME: T = ...;`).
// Sister to v0.7.74 `try { ... }` halt (same expr-position
// block-not-supported family).
fn main() -> i64 {
    let x: i64 = const { 5 + 7 };
    return x;
}
