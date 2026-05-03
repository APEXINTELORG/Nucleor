// EXPECT: NUM-021 integer constant expression for let-binding `x` overflows i64
// v0.6.50 — gap 4: let-binding const expr overflow now fires NUM-021 at compile
fn main() -> i32 {
    let x: i64 = 9223372036854775807 + 1;
    return x as i32;
}
