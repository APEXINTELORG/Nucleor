// v0.4.91: bare `{}` on a user struct routes through Display.

trait Display {
    fn fmt(self) -> str;
}

struct Point {
    x: i64,
    y: i64,
}

impl Display for Point {
    fn fmt(self) -> str {
        return str_concat("Point(", str_concat(int_to_str(self.x), str_concat(", ", str_concat(int_to_str(self.y), ")"))));
    }
}

fn main() -> i64 {
    let p: Point = Point { x: 3, y: 4 };
    let s: str = format!("{}", p);
    if str_eq(s, "Point(3, 4)") != 1 {
        print(s);
        return 1;
    };
    let p2: Point = Point { x: 3, y: 4 };
    println!("{}", p2);
    return 0;
}
