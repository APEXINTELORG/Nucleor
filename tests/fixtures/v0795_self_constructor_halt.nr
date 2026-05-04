// v0.7.95 negative fixture — `Self { ... }` struct constructor
// inside impl block halt. Pre-fix surfaced as wrong-class
// `unknown struct Self`. Now halts with a precise diag +
// workaround pointer (write the struct name explicitly).
struct Counter { n: i64 }

impl Counter {
    fn make(x: i64) -> Counter {
        return Self { n: x };
    }
}

fn main() -> i64 {
    let c: Counter = Counter::make(5);
    return c.n;
}
