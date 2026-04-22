// Phase 2b: Shared references (&T) are Copy — can be freely duplicated

struct Point { x: i32, y: i32 }

fn read_point(p: &Point) -> i32 { p.x }

fn main() -> i32 {
    let a: Point = Point { x: 5, y: 10 };
    let r: &Point = &a;

    // Pass ref to function — ref is Copy, not moved
    let v1: i32 = read_point(r);
    let v2: i32 = read_point(r);   // r still valid
    print_int(v1);
    print_int(v2);

    // Assign ref to another binding — original ref still valid
    let r2: &Point = r;
    print_int(r.x);    // r still works
    print_int(r2.y);   // r2 works too

    0
}
