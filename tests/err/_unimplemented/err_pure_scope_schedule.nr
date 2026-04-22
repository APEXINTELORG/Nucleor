// Error test: pure function cannot use structured scheduling
pure fn bad() -> i32 {
    scope {
    }
    0
}

fn main() -> i32 {
    bad()
}
