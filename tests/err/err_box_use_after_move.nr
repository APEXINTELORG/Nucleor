// EXPECT: OWN-001 use of moved variable
// RFC-0062 OWN-VAL-1: Box<T> is non-Copy. A Box binding transfer
// moves the source handle, so dereferencing the source afterwards
// must fail in the ownership checker.

fn main() -> i32 {
    let b: Box<i32> = Box::new(42);
    let b2: Box<i32> = b;
    let val: i32 = *b;
    print_int(val);
    print_int(*b2);
    0
}
