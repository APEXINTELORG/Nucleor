// EXPECT: LEX-001 unexpected byte
// Lane 4 audit close: F-003 (Critical, silent accept).
// Pre-fix `~`, `$`, `` ` ``, `@#$%^&*` etc. silently consumed via the
// lexer's terminal `else { p = p + 1; };` fall-through (F-066 root
// cause). Post-fix: emit LEX-001 with the offending byte.
@#$%^&*~
fn main() -> i32 { return 0; }
