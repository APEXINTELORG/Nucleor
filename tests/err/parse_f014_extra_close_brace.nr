// EXPECT: PARSE-TOP-001 unexpected `}` at module scope
// Lane 4 audit close: F-014 (High, `}}}}` at module scope silent accept).
fn main() -> i32 {
    return 0;
}}
