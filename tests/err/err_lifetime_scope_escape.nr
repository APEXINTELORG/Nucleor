// Phase 2d: Reference cannot escape inner block scope

fn main() -> i32 {
    let r: &i32 = {
        let x: i32 = 42;
        &x              // ERROR: x dropped at end of block
    };
    print_int(*r);
    0
}
