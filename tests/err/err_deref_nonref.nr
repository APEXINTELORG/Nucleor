// EXPECT: TYP-004 cannot dereference a non-reference value
// The * operator only applies to reference types.
// Phase 2b: Cannot dereference a non-reference type

fn main() -> i32 {
    let x: i32 = 42;
    let y: i32 = *x;   // ERROR: cannot dereference non-reference type i32
    print_int(y);
    0
}
