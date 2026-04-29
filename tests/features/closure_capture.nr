// Phase 5d: Closure with captured variables

fn main() -> i32 {
    let offset: i32 = 10;
    let add_offset = |x: i32| x + offset;
    let result: i32 = add_offset(32);
    print_int(result);
    0
}
