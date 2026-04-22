// Error test: cannot add meters to seconds
fn main() -> i32 {
    let dist: unit<i32, m> = 10{m};
    let time: unit<i32, s> = 5{s};
    let bad: unit<i32, m> = dist + time;
    0
}
