// EXPECT: SEND-G6-CLOSURE-CAPTURE closure literal
// RFC-0062 G-6 Phase 3 — Sendable per-call-site classification.
// Rust-style explicit-capture closures (`|args| body`) capture
// variables from the enclosing scope; the closure is Sendable
// iff every captured variable is Sendable. The capture set is
// not audited at spawn boundaries today, so any closure literal
// passed to a spawn-family call fires SEND-G6-CLOSURE-CAPTURE.
fn main() -> i32 {
    let n: i64 = 7;
    let task: i64 = async_spawn(|x: i64| -> i64 { return n + x; }, 3);
    return async_await(task) as i32;
}
