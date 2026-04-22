// Phase 2c: Cannot assign through shared reference

struct Data { x: i32 }

fn main() -> i32 {
    let a: Data = Data { x: 1 };
    let r: &Data = &a;
    r.x = 42;    // ERROR: cannot assign through shared reference
    0
}
