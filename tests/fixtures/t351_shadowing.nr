// t351_shadowing.nr — v0.3.76 regression fixture.
//
// Pins shadowing semantics: when a `let x: T = EXPR;` shadows
// an outer binding `x`, the EXPR must resolve `x` to the OUTER
// (shadowed) slot, not the new (uninitialized) slot.
//
// Pre-v0.3.76, the let-stmt lowering bound the new slot to `vname`
// in `sym` BEFORE lowering the RHS, so `let x: i64 = x + 5;`
// after `let x: i64 = 10;` resolved the inner `x` to the new
// uninitialized alloca and produced garbage (hundreds of millions).
// Post-v0.3.76, sym is rebound AFTER the RHS is lowered.
//
// Returns 1 + 2 + 4 + 8 + 16 = 31 if all five shadowing forms
// resolve correctly.

fn main() -> i64 {
    let mut score: i64 = 0;

    // 1) Same-type shadow using old in RHS
    let x: i64 = 10;
    let x: i64 = x + 5;       // expect 15
    if x == 15 { score = score + 1; };

    // 2) Different-type shadow using old via cast
    let y: i64 = 4;
    let y: f64 = (y as f64) + 1.5;  // expect 5.5
    let yi: i32 = y as i32;
    if yi == 5 { score = score + 2; };

    // 3) Multiple sequential shadows
    let n: i64 = 1;
    let n: i64 = n + 1;
    let n: i64 = n + 1;
    let n: i64 = n + 1;
    if n == 4 { score = score + 4; };

    // 4) Shadow inside arithmetic expression
    let a: i64 = 100;
    let a: i64 = a / 4;     // expect 25
    if a == 25 { score = score + 8; };

    // 5) Shadow with no use of old — new value computed from constant
    let z: i64 = 99;
    let z: i64 = 7;          // shadow ignores old
    if z == 7 { score = score + 16; };

    return score;  // expect 31
}
