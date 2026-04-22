// Phase 3a: default behavior — trap on overflow
// This program should abort/trap at runtime
fn main() -> i32 {
    let a: i32 = 2147483647;  // i32::MAX
    let b: i32 = a + 1;       // DEFAULT: trap on overflow
    print_int(b);
    0
}
