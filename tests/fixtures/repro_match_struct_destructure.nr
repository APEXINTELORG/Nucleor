struct Point { x: i64, y: i64 }

fn main() -> i64 {
    let p: Point = Point { x: 4, y: 9 };
    let r: i64 = match p {
        Point { x, y } => x + y,
    };
    if r != 13 { return 91; };
    return 0;
}
