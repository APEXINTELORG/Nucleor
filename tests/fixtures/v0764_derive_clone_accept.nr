// v0.7.64 positive fixture: derive(Clone) on named struct and tuple struct.
// Pre-v0.7.64: `.clone()` on a user struct fell through to `vec_clone(...)`
// synthesis → wrong-class TYP-005 at clang link. Now works cleanly.

#[derive(Clone, PartialEq)]
struct Point { x: i64, y: i64 }

#[derive(Clone)]
struct Wrapper(i64);

fn main() -> i64 {
    let p1: Point = Point { x: 3, y: 4 };
    let p2: Point = p1.clone();
    let w1: Wrapper = Wrapper(10);
    let w2: Wrapper = w1.clone();
    // p2 is a fresh copy — fields equal to p1's
    if p2.x != 3 { return 1; };
    if p2.y != 4 { return 2; };
    // w2.__0 equals w1.__0
    if w2.__0 != 10 { return 3; };
    return 0;
}
