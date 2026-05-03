// v0.7.6 (defensive halt): canonical Rust `T::default()` pattern
// (`i64::default()`, `String::default()`, `Default::default()`)
// pre-fix surfaced via the generic v0.3.71 'unsupported associated-
// fn call' diag mentioning Vec/String/etc. — not adopter-actionable
// for the Default trait case. Now halts cleanly with per-type
// literal-default workaround pointers (0 for ints, 0.0 for floats,
// false for bool, "" for str, Vec::new() for Vec, etc.).
// Negative fixture (compile rejects).
fn main() -> i32 {
    let n: i64 = i64::default();    // ← halts: Default trait unsupported
    print_int(n as i32);
    return 0;
}
