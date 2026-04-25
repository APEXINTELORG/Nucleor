// t348_module_let_diagnostic.nr — v0.3.73 negative regression fixture.
//
// Verifies that `let` at module scope produces a clear diagnostic
// pointing at the canonical workaround (`const`). Pre-v0.3.73, the
// parser silently dropped the entire `let NAME: T = EXPR;`
// declaration and downstream codegen emitted broken `@NAME`
// references that failed at clang link with no front-end diagnostic.
//
// This fixture is intended to FAIL compilation; the verify-gate
// step asserts that the diagnostic text appears in stderr.

let G_BAD: i64 = 42;

fn main() -> i64 {
    return G_BAD;
}
