// EXPECT: PARSE-LET-001 expected identifier as `let` binding name
// Lane 4 audit close: F-054 (High, keyword-as-binding silent accept).
// Pre-fix `let fn: i64 = 5;` silently produced an invalid binding
// with a garbage name and emitted broken IR.
fn main() -> i32 { let fn: i64 = 5; return 0; }
