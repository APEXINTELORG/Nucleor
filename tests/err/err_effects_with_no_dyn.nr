// EXPECT: RT-003 dynamic dispatch inside a function declared with [no_dyn]

trait Sensor {}

fn poll(s: &dyn Sensor) -> i64 with [no_dyn] {
    return 0;
}

fn main() -> i64 {
    return 0;
}
