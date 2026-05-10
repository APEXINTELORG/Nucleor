// EXPECT: error[TYP-044]
// Audit pass 1 Layer 2 F-004: i32 -> i64 binding requires an explicit cast.
fn main() -> i32 {
    let a: i32 = 1;
    let b: i64 = a;
    print_int(b as i32);
    0
}
