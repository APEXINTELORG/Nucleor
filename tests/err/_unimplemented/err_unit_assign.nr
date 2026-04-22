// Error test: cannot assign velocity to distance
fn main() -> i32 {
    let dist: unit<i32, m> = 10{m};
    let time: unit<i32, s> = 5{s};
    let speed: unit<i32, m / s> = dist / time;
    let bad: unit<i32, m> = speed;
    0
}
