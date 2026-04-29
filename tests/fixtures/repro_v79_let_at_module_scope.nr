// repro_v79_let_at_module_scope.nr — v0.4.79 silent fall-through close.
// Pre-fix `let X: T = V;` at module scope printed a diagnostic and
// silently skipped to the next semicolon — the binding was DROPPED
// from the module surface and any reference produced broken IR.
// v0.4.79 promotes to compile-time panic.
//
// EXPECT: build fails (msg contains "let` at module scope").

let GLOBAL: i64 = 42;

fn main() -> i64 {
    println!("{}", GLOBAL);
    return 0;
}
