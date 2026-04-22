// Phase 5b: Generic function with monomorphization

fn identity<T>(x: T) -> T {
    x
}

fn main() -> i32 {
    let a: i32 = identity(42);
    print_int(a);
    0
}
