// t370_panic_assert_macros.nr — v0.3.94 regression fixture.
//
// Pins the `panic!` and `assert!` macro forms. Pre-v0.3.94, the
// textual macro preprocessor only recognized `println!`, `format!`,
// and `print!` — `panic!("msg")` was parsed as `panic` (ident) `!`
// (negate) `("msg")` (parens) and the runtime call to
// __nucleor_panic was never emitted, failing at clang link with
// `@panic undefined`. Same for `assert!`.
//
// Post-v0.3.94: textual rewrite drops the `!` from panic!/assert!/
// dbg! so the existing fn call dispatch handles them via the
// regular runtime helpers (already registered as panic / assert).
//
// Returns 0 on success — assert!(2 + 2 == 4) is a no-op when true.

fn main() -> i64 {
    assert!(2 + 2 == 4);
    return 0;
}
