// Phase 5a: Box<T> is non-Copy — use after move should fail

fn main() -> i32 {
    let b: Box<i32> = Box::new(42);
    let b2: Box<i32> = b;   // b moves to b2
    let val: i32 = *b;       // ERROR: use of moved value 'b'
    print_int(val);
    0
}
