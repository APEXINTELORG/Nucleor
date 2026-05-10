// EXPECT: error[TYP-044]
// Audit pass 1 Layer 2 F-003: i64 -> i32 binding requires an explicit cast.
fn main() -> i32 {
    let a: i64 = 1234567890123;
    let b: i32 = a;
    print_int(b);
    0
}
