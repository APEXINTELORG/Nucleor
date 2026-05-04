// v0.7.73 consolidated negative fixture — module-scope silent-strip
// halt family. Two halts share the same dispatch site and same
// silent-drop class:
//   - `extern crate <name>;`        — Rust 2015 / workspace dep decl
//   - `macro_rules! name { ... }`   — declarative-macro decl
//
// Both halts produce a clean parse-time diagnostic with workaround
// pointer. To validate the macro_rules form, swap the body line.
// Sister to v0.7.71 `async fn` and v0.6.53 `unsafe fn` halts (same
// module-item silent-strip family).
extern crate foo;

fn main() -> i64 { return 0; }
