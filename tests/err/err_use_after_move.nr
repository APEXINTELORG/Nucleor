// EXPECT: OWN-001 use of moved variable
// `p` is moved into the Rect struct, then we try to use it again.
struct Point {
    x: i64,
    y: i64
}

struct Rect {
    origin: Point,
    width: i64
}

fn main() -> i64 {
    let p: Point = Point { x: 1, y: 2 };
    let r: Rect = Rect { origin: p, width: 10 };
    let n: i64 = p.x;   // use of moved variable: p was consumed by Rect
    return n + r.width;
}
