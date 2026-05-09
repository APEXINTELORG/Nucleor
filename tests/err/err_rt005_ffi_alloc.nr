// EXPECT: RT-005 FFI allocation crossing requires-row
// Lane 3 (F-DIAG-006): RT-005 had no negative test.

extern fn malloc(n: i64) -> i64;

fn allocate_and_return(n: i64) -> i64 {
    let p: i64 = malloc(n);
    return p;
}

fn main() -> i64 {
    return allocate_and_return(64);
}
