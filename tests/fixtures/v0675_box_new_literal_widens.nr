// v0.6.75 RFC V1.2 step 1: Box<T> generic-T inference for literal init.
// Pre-fix `let b: Box<i64> = Box::new(5);` failed TYP-008 because the
// literal `5` defaults to i32. Post-fix: types_compatible accepts a
// Box<wider-int> ← Box<i32> shape via literal-default widening.
fn main() -> i32 {
    let b: Box<i64> = Box::new(5);
    let c: Box<isize> = Box::new(7);
    let d: Box<i64> = Box::new(42);
    print_int(*b as i32);
    print_int(*c as i32);
    print_int(*d as i32);
    return 0;
}
