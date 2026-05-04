// v0.7.88 negative fixture — Rust `compile_error!(...)` halt.
// Pre-fix the macro-call shape `compile_error ! (...)` was
// silently dropped (Nucleor's `!`-after-ident handling treated
// it as logical-not on the args, which DCE'd as a discarded
// value), so adopters writing the macro to force a compile-time
// failure got a successful build instead. Now halts at the
// resolver pre-pass with the canonical Rust semantic.
compile_error!("this build is intentionally rejected for tests");

fn main() -> i64 { return 0; }
