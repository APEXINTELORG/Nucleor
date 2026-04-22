// Phase 2b: Shared borrows — create &T, read through it

struct Point { x: i32, y: i32 }

fn main() -> i32 {
    let a: Point = Point { x: 10, y: 20 };
    let r: &Point = &a;     // borrow a
    print_int(r.x);         // read field through reference
    print_int(r.y);
    print_int(a.x);         // a is still usable (not moved)
    print_int(a.y);
    0
}
