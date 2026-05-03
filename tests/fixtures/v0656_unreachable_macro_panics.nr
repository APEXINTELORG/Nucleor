// v0.6.56 (probe finding 2026-05-01-rust-syntax-translation-fidelity-audit
// unreachable!() row): canonical Rust `unreachable!()` macro expanded to
// panic with the std::macros::unreachable!() canonical message. Pre-fix
// fell through to TYP-005 wrong-class.
fn main() -> i32 {
    let x: i64 = 5;
    if x > 100 { return 0; };
    unreachable!()
}
