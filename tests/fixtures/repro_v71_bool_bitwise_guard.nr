// repro_v71_bool_bitwise_guard.nr — v0.4.71 audit S1 partial.
// Pre-fix `let r: i64 = a & x;` for a:bool, x:i64 silently emitted
// integer i64_and on the bool's i64 representation. Rust errors.
// v0.4.71 extends TYP-002 to bitwise/shift ops 65/82/94/115/116
// when ANY operand is bool.

fn main() -> i64 {
    let a: bool = true;
    let x: i64 = 5;
    let r: i64 = a & x;   // TYP-002 expected
    println!("{}", r);
    return 0;
}
