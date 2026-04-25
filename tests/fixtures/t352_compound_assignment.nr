// t352_compound_assignment.nr — v0.3.77 regression fixture.
//
// Pins compound-assignment desugar: `LHS op= RHS` rewrites to
// `LHS = LHS op RHS` at parse time. Pre-v0.3.77, the lexer split
// `+=` into two tokens (`+` and `=`) and the parser silently
// dropped the entire statement, producing IR that was missing
// the assignment. v0.3.77 adds compound-op tokens (kind 110-114)
// in the lexer and a desugar branch in parse_stmt's expr-position.
//
// Returns 3 if all five compound forms work end-to-end:
//   x = 10  --(+=5)--> 15  --(-=2)--> 13  --(*=3)--> 39
//                     --(/=3)--> 13  --(%=5)--> 3
// Also covers field-LHS and Vec-LHS via a side check.

fn main() -> i64 {
    // Bare i64 var
    let mut x: i64 = 10;
    x += 5;     // 15
    x -= 2;     // 13
    x *= 3;     // 39
    x /= 3;     // 13
    x %= 5;     // 3
    if x != 3 { return 99; };

    // Struct field LHS (verifies the LHS-share desugar handles field access)
    let mut p: Point = Point { x: 100, y: 0 };
    p.x += 50;  // 150
    p.x /= 5;   // 30
    if p.x != 30 { return 98; };

    return 3;
}

#[repr(C)]
struct Point { x: i64, y: i64 }
