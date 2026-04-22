// Phase 2c: Cannot mutably borrow immutable variable

struct Data { x: i32 }

fn main() -> i32 {
    let a: Data = Data { x: 1 };   // not mut!
    let r: &mut Data = &mut a;     // ERROR: cannot mutably borrow immutable variable
    r.x = 42;
    0
}
