// Phase 2a: Move semantics — basic move on assignment

struct Point { x: i32, y: i32 }

fn main() -> i32 {
    let a: Point = Point { x: 1, y: 2 };
    let b: Point = a;      // a moves to b
    print_int(b.x);        // ok: b owns the value
    print_int(a.x);        // ERROR: use of moved value 'a'
    0
}
