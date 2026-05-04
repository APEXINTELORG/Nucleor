// EXPECT: tuple destructuring in `let` not yet supported
// Q9 lock-in — v0.8.21. Tuple destructure `let (a, b) = (5, 7);`
// is a Rust-portability paper-cut. The current halt is clean
// (PANIC with workaround pointer); this fixture locks the halt
// behavior so a regression that silently accepts the syntax
// (and potentially miscompiles) gets caught.

fn main() -> i64 {
    let (a, b) = (5, 7);  // ERROR: tuple destructuring in `let`
    return a + b;
}
