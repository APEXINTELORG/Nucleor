// EXPECT: error[TYP-003] unit operands for addition/subtraction must match
// RFC-0005 archive guard: adding distance and time must not silently compile
// through erased i64 storage while full typed-unit algebra is still queued.

fn main() -> i32 {
    let dist: unit<i32, m> = 10{m};
    let time: unit<i32, s> = 5{s};
    let bad: unit<i32, m> = dist + time;
    0
}
