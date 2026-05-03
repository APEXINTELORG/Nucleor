// EXPECT: NUM-021 integer constant expression for const `B` overflows declared unsigned type `u64`
// v0.6.64 — gap 1: u64 const overflow now caught at compile time
const B: u64 = 18446744073709551615 + 1;
fn main() -> i32 { return 0; }
