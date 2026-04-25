// t373_bitwise_op_diagnostic.nr — v0.3.97 negative regression fixture.
//
// Pre-v0.3.97, writing `let c: i64 = a & b;` silently parsed the RHS
// as just `a` (the parser treated `& b` as a separate borrow
// expression-statement after), producing wrong values with no
// diagnostic. Same for `|` and `^`.
//
// Post-v0.3.97: parse_let detects unconsumed bitwise op tokens after
// the RHS and emits a clear diagnostic. Real bitwise op support
// requires new precedence tiers in the binop chain — tracked.
//
// This fixture is intended to surface the diagnostic.

fn main() -> i64 {
    let a: i64 = 12;
    let b: i64 = 10;
    let c: i64 = a & b;
    return c;
}
