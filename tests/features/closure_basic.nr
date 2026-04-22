// Phase 5d: Basic closure

fn main() -> i32 {
    let add_one = |x: i32| x + 1;
    let result: i32 = add_one(41);
    print_int(result);
    0
}
