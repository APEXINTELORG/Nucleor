// Phase 5d: Closure with captured variables

fn main() -> i64 {
    let offset: i64 = 10;
    let add_offset = |x: i64| x + offset;
    let result: i64 = add_offset(32);
    print_int(result);
    0
}
