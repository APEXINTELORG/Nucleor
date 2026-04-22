// Test where clause syntax on functions

fn process<T>(x: T) -> T where T: Display + Clone {
    x
}

fn main() -> i32 {
    let val: i32 = 42;
    print_int(val);
    0
}
