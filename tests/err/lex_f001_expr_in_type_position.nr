// EXPECT: PARSE-TYPE-001 expression in type position
// Lane 4 audit close: F-001 (Critical, SIGSEGV).
// Pre-fix `let x: 1 + 1 = 5;` segfaulted (rc=139) with no diag.
// Post-fix: clean PARSE-TYPE-001 reject.
fn main() -> i32 { let x: 1 + 1 = 5; return 0; }
