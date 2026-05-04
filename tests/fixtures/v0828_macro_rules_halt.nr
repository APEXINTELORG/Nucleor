// EXPECT: PANIC: nucleor: `macro_rules!` decl not yet supported
//
// v0.8.28 fixture — macro_rules! module-level halt (token fix).
//
// Pre-v0.8.28 the halt added in v0.7.73 checked token kind 97 (`?`)
// instead of token kind 38 (`!`), so `macro_rules! name { ... }` was
// silently dropped at module scope — wrong-class silent miscompile.
// v0.8.28 corrects the token constant so the halt fires properly.
//
// Companion: the expression-position halt for unknown `name!(args)` is
// tested in v0828_unknown_macro_expr.nr.
macro_rules! double {
    ($x:expr) => { $x * 2 }
}
fn main() -> i64 {
    return 0;
}
