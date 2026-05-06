// EXPECT: error[TYP-008] unit assignment mismatch
// RFC-0005 archive guard: the full `unit<T, dim>` algebra remains queued,
// but assigning a velocity-shaped unit binding into a distance binding must
// not silently compile through erased storage.

fn main() -> i32 {
    let dist: unit<i32, m> = 10{m};
    let time: unit<i32, s> = 5{s};
    let speed: unit<i32, m / s> = dist / time;
    let bad: unit<i32, m> = speed;
    0
}
