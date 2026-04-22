// Phase 2d: Cannot return reference to local variable

struct Data { x: i32 }

fn dangling() -> &Data {
    let d: Data = Data { x: 42 };
    &d       // ERROR: returns a reference to a local variable
}

fn main() -> i32 {
    0
}
