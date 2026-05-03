// EXPECT: nucleor: struct destructure-in-let not yet supported
// v0.6.61 — struct destructure-in-let halts cleanly at parse (was wrong-class TYP-008)
struct Point { x: i64, y: i64 }
fn main() -> i32 {
    let p: Point = Point { x: 5, y: 10 };
    let Point { x, y } = p;
    return x as i32;
}
