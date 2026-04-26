// t434_println_bool_binop_dispatch.nr -- v0.3.167 regression
// fixture.
//
// Pre-v0.3.167, the println! `{}` heuristic did not detect
// top-level comparison/equality/logical operators. So
// `println!("{}", a == b)` printed "1" or "0" via int_to_str
// (correct accidentally for ==/!=/<= etc., but should be
// "true"/"false" for bool semantics) and `println!("{}", x && y)`
// also fell back to int_to_str.
//
// More importantly the existing dispatch produced "0"/"1" instead
// of "true"/"false" -- a stylistic miscompute that confuses
// adopter Rust-style debug output.
//
// Fix (v0.3.167): walk arg_expr with paren/bracket depth tracking;
// if any 4-char window matches " == ", " != ", " <= ", " >= ",
// " && ", or " || " at depth 0, dispatch to bool_to_str.
// Conservative (requires whitespace around the op) so generic
// types like `Vec<T>` and shift exprs like `a << 2` don't trip.

fn main() -> i64 {
    let a: i64 = 5;
    let b: i64 = 7;
    println!("eq={}", a == b);    // pre-fix: "0", post-fix: "false"
    println!("ne={}", a != b);    // pre-fix: "1", post-fix: "true"
    println!("le={}", a <= b);    // pre-fix: "1", post-fix: "true"
    println!("ge={}", a >= b);    // pre-fix: "0", post-fix: "false"
    let t: bool = true;
    let f: bool = false;
    println!("and={}", t && f);   // pre-fix: "0", post-fix: "false"
    println!("or={}", t || f);    // pre-fix: "1", post-fix: "true"
    return 42;
}
