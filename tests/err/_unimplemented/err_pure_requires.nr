// Error test: pure fn cannot have requires clause
pure fn bad() -> i32 requires [io.read] {
    42
}

fn main() -> i32 {
    bad()
}
