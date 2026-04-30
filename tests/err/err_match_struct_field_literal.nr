// EXPECT: error[MATCH-012] struct pattern field after `:` must be an identifier
// v0.4.163 MATCH-012: pre-fix `match p { Point { x: 0, y: 0 } => ... }`
// silently fed the raw int-literal value into pkv (i64) and bound it
// as a str to the field's rename slot, producing garbage that crashed
// codegen with an ACCESS VIOLATION (0xC0000005). Now: require an
// identifier after `:` in struct patterns and emit MATCH-012 if anything
// else appears.

struct Point {
    x: i32,
    y: i32,
}

fn main() -> i32 {
    let p: Point = Point { x: 3, y: 4 };
    let r: i32 = match p {
        Point { x: 0, y: 0 } => 1,
        Point { x, y } => x + y,
    };
    print_int(r);
    0
}
