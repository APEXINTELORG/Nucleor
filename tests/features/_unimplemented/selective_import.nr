// Phase 11: Selective imports from modules
use "math_lib.nr" { square };

fn main() -> i32 {
    let x: i32 = square(5);
    print_int(x);  // 25
    0
}
