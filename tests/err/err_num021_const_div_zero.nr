// EXPECT: NUM-021 integer constant expression for const `B` overflows i64
// v0.6.53 — gap 3: const div by zero now fires NUM-021 at compile time
const B: i64 = 1 / 0;
fn main() -> i32 { return 0; }
