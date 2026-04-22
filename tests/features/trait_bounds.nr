// Phase 5c: Trait bounds on generic functions

trait Addable {
    fn zero() -> i32;
}

impl Addable for i32 {
    fn zero() -> i32 { 0 }
}

fn add_values<T: Addable>(a: T, b: T) -> T {
    a + b
}

fn main() -> i32 {
    let result: i32 = add_values(10, 20);
    print_int(result);
    0
}
