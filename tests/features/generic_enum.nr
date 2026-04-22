// Test generic enum declarations

enum Option<T> {
    Some { value: i32 },
    None,
}

fn main() -> i32 {
    print_int(42);
    0
}
