// v0.7.87 negative fixture — Rust prelude `drop(value)` halt.
// Pre-fix `drop(v)` surfaced as wrong-class
// `warning[TYP-005]: undefined function 'drop'` at type-check
// then hard-failed at clang link with the same TYP-005. Now
// halts cleanly at parse_primary with a workaround pointer.
// Sister to v0.6.82 idiom-method halt family.
fn main() -> i64 {
    let v: Vec<i64> = Vec::new();
    drop(v);
    return 0;
}
