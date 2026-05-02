// EXPECT: build fails with NUM-021.
// Module-level const integer expressions must not wrap during compile-time
// evaluation. Use wrapping_* / saturating_* explicitly when wrap/clamp is
// intended.

const B: i64 = 9223372036854775807 + 1;

fn main() -> i32 {
    return 0;
}
