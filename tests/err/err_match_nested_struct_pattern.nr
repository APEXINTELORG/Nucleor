// EXPECT: nucleor: nested struct pattern not yet supported
// v0.6.69 — nested struct pattern halts cleanly at parse (was wrong-class NR020)
struct Point { x: i64, y: i64 }
struct Line { a: Point, b: Point }
fn describe(l: Line) -> i64 {
    match l {
        Line { a: Point { x, y: _ }, b: _ } => x,
    }
}
fn main() -> i32 {
    let l: Line = Line { a: Point { x: 7, y: 8 }, b: Point { x: 9, y: 10 } };
    print_int(describe(l) as i32);
    return 0;
}
