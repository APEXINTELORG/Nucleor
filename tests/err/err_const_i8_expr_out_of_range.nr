// EXPECT: build fails with NUM-002.
// The expression is compile-time evaluable and its value does not fit i8.

const B: i8 = 120 + 10;

fn main() -> i32 {
    return 0;
}
