// EXPECT: TYP-002 boolean values cannot be used in arithmetic
// Booleans aren't addable. The type checker fires TYP-002
// from check_expr's binop branch when either operand is bool.
fn main() -> i32 { true + false }
