// EXPECT: nucleor: `unsafe fn` decl not yet supported
// v0.6.53 — `unsafe fn ...` halts cleanly at parse (was silent strip)
unsafe fn dangerous() -> i64 { return 42; }
fn main() -> i32 { return 0; }
