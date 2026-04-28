// v0.4.33c silent-fall-through closure: associated constants in impl
// bodies. Pre-fix: ERROR printed, const decl silently dropped.
// Post-fix: panic.
// EXPECT: panic
struct Counter { v: i64 }

impl Counter {
    const STEP: i64 = 1;
    fn inc(&self) -> i64 { return self.v + 1; }
}

fn main() -> i64 { return 0; }
