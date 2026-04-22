// Phase 2d: Cannot return reference to local primitive

fn bad_ref() -> &i32 {
    let x: i32 = 99;
    &x              // ERROR: returns reference to local
}

fn main() -> i32 {
    0
}
