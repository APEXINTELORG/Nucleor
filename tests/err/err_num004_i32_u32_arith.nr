// EXPECT: NUM-001 mixed-width integer arithmetic requires an explicit cast.
fn main() -> i32 {
    let a: i32 = 100i32;
    let b: u32 = 200u32;
    let d: i32 = a + b;
    return d;
}
