// EXPECT: NUM-001 mixed-width integer arithmetic requires an explicit cast.
fn main() -> i32 {
    let a: i32 = 100i32;
    let b: i64 = 200;
    let d: i64 = a + b;
    return d as i32;
}
