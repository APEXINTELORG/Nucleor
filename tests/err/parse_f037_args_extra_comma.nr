// EXPECT: PARSE-ARGS-COMMA extra `,` in fn-call argument list
// Lane 4 audit close: F-037 (High, extra commas in fn args silent drop).
fn h(a: i64, b: i64) -> i64 { return a + b; }
fn main() -> i32 { let x: i64 = h(1,, 2); return 0; }
