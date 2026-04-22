// Phase 3a: wrapping arithmetic — modular overflow
fn main() -> i32 {
    // wrapping block: overflow wraps instead of trapping
    let result: i32 = wrapping {
        let a: i32 = 2147483647;  // i32::MAX
        a + 1                      // wraps to -2147483648
    };
    // result should be i32::MIN = -2147483648
    // return 0 to indicate success — print to verify
    print_int(result);
    0
}
