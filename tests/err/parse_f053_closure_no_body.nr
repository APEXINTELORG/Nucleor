// EXPECT: PARSE-CLOSURE-NO-BODY closure literal has no body
// Lane 4 audit close: F-053 (High, closure no body silent accept).
// Pre-fix `||;` silently produced `int_lit(0)` as the closure body.
fn main() -> i32 { let f: i64 = ||; return 0; }
