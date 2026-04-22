// Error test: undeclared externs default to unsafe.raw_ptr

extern fn abs(x: i32) -> i32;

pure fn bad() -> i32 {
    abs(-7)
}

fn main() -> i32 {
    bad()
}
