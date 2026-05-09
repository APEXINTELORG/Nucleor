// EXPECT: PARSE-MATCH-COMMA missing `,` between match arms
// Lane 4 audit close: F-036 (High, missing-comma silent accept).
fn main() -> i32 {
    let x: i64 = 1;
    match x { _ => { 1 } 1 => { 2 } };
    return 0;
}
