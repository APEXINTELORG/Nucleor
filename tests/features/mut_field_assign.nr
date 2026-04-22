// Phase 2c: Direct field assignment on mut variable

struct Point { x: i32, y: i32 }

fn main() -> i32 {
    let mut p: Point = Point { x: 1, y: 2 };
    print_int(p.x);    // 1
    print_int(p.y);    // 2
    p.x = 10;
    p.y = 20;
    print_int(p.x);    // 10
    print_int(p.y);    // 20
    0
}
