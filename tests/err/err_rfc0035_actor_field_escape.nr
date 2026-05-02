// EXPECT: RACE-003

actor Counter {
    n: i64,
}

fn main() -> i32 {
    let c: Counter = Counter { n: 1 };
    return c.n as i32;
}
