// EXPECT: nucleor: `const fn` decl not yet supported
// v0.6.55 — `const fn` halts cleanly at parse (was wrong-class NR020 at byte 9)
const fn double(x: i64) -> i64 { return x * 2; }
fn main() -> i32 { return 0; }
