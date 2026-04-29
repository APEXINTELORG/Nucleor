// EXPECT: FMT-002 type does not implement Display
// v0.4.91: bare `{}` on a struct without Display must not fall back to int_to_str.

struct Point {
    x: i64,
    y: i64,
}

fn main() -> i64 {
    let p: Point = Point { x: 1, y: 2 };
    println!("{}", p);
    return 0;
}
