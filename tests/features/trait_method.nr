// Phase 5c: Trait with method dispatch

trait Shape {
    fn area(self) -> i32;
}

struct Rectangle {
    width: i32,
    height: i32,
}

impl Shape for Rectangle {
    fn area(self) -> i32 {
        self.width * self.height
    }
}

struct Square {
    side: i32,
}

impl Shape for Square {
    fn area(self) -> i32 {
        self.side * self.side
    }
}

fn main() -> i32 {
    let r: Rectangle = Rectangle { width: 5, height: 3 };
    let s: Square = Square { side: 4 };
    print_int(r.area());
    print_int(s.area());
    0
}
