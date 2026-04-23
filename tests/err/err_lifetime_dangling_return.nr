// EXPECT: OWN-009 cannot return reference to local value
// Lifetime escapes the function via return value.
// Phase 2d: Cannot return reference to local variable

fn dangling() -> &i32 {
    let x: i32 = 42;
    &x      // ERROR: x is dropped at end of function
}

fn main() -> i32 {
    let r: &i32 = dangling();
    print_int(*r);
    0
}
