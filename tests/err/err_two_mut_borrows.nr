// EXPECT: OWN-004 cannot mutably borrow value that is already borrowed
// Two simultaneous mutable borrows.
// Phase 2c: Cannot have two &mut to same value

struct Data { x: i32 }

fn main() -> i32 {
    let mut a: Data = Data { x: 1 };
    let r1: &mut Data = &mut a;
    let r2: &mut Data = &mut a;   // ERROR: already mutably borrowed
    r1.x = 10;
    r2.x = 20;
    0
}
