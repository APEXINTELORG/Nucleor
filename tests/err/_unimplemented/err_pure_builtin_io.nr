// Error test: pure function cannot call builtin io.write effects

pure fn bad() -> i32 {
    print_int(1);
    0
}

fn main() -> i32 {
    bad()
}
