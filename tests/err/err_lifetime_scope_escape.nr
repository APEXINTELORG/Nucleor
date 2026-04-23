// EXPECT: OWN-010 cannot bind a reference that escapes an inner block
// Lifetime escapes a nested scope into the enclosing one.
// Phase 2d: Reference cannot escape inner block scope

fn main() -> i32 {
    let r: &i32 = {
        let x: i32 = 42;
        &x              // ERROR: x dropped at end of block
    };
    print_int(*r);
    0
}
