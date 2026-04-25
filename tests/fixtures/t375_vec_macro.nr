// t375_vec_macro.nr — v0.3.99 regression fixture.
//
// Pins the `vec![...]` macro. Pre-v0.3.99, the lexer split
// `vec![a, b, c]` as `vec` (ident) + `!` (logical-NOT) +
// `[a, b, c]` (array-literal). The `vec` ident bound to a
// non-existent global symbol (clang link error: `@vec undefined`)
// and the array-literal payload became dead code, leaving Rust
// adopters who reach for the canonical `vec![]` initializer with
// a hard compile failure.
//
// Returns 60 = 10+20+30 from a vec![] init plus three pushes,
// proving the empty-form macro lowers to Vec::new() and the
// resulting vec is push-able.

fn main() -> i64 {
    let v: Vec<i64> = vec![10, 20, 30];
    return v[0] + v[1] + v[2];
}
