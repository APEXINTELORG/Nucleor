// EXPECT: PARSE-IMPORT-001 import requires a quoted path
// Lane 4 audit close: F-050 (High, unquoted import silent accept).
import stdlib/rods/strings.nr
fn main() -> i32 { return 0; }
