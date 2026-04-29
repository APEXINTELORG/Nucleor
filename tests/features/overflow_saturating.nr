// Phase 3a: saturating arithmetic — clamps to min/max
fn main() -> i32 {
    // saturating add: clamps at MAX instead of wrapping
    let result: i32 = saturating {
        let a: i32 = 2147483647;  // i32::MAX
        a + 1                      // saturates to 2147483647
    };
    print_int(result);

    // saturating sub: underflow clamps at MIN
    let result2: i32 = saturating {
        let b: i32 = 0;
        b - 2147483647 - 2         // -2147483649 saturates to -2147483648
    };
    print_int(result2);
    0
}
