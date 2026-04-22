// Phase 5c: Basic trait declaration and implementation

trait Describable {
    fn describe(self) -> i32;
}

struct Point {
    x: i32,
    y: i32,
}

impl Describable for Point {
    fn describe(self) -> i32 {
        self.x + self.y
    }
}

fn main() -> i32 {
    let p: Point = Point { x: 10, y: 20 };
    let d: i32 = p.describe();
    print_int(d);
    0
}
