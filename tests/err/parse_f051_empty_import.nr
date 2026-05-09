// EXPECT: PARSE-IMPORT-EMPTY empty import path
// Lane 4 audit close: F-051 (High, `import ""` silent accept).
import "";
fn main() -> i32 { return 0; }
