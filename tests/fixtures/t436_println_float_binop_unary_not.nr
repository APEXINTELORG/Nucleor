// t436_println_float_binop_unary_not.nr -- v0.3.169 regression
// fixture.
//
// Pre-v0.3.169, the println! `{}` heuristic missed two more
// silent-miscompute shapes:
//   1. Typed float binop without textual decimal:
//      `println!("{}", a + b)` for a, b: f64 printed the result's
//      i64 bit pattern instead of the float value.
//   2. Unary not:
//      `println!("{}", !flag)` printed "0"/"1" via int_to_str
//      instead of "false"/"true" per Rust Display semantics.
//
// Same hazard class as the v0.3.166/167 println! extensions.
//
// Fix (v0.3.169):
//   - Unary not: when arg_expr starts with `!` (and next char is
//     not `=`), dispatch to bool_to_str.
//   - Float binop: detect top-level arithmetic op (` + `, ` - `,
//     ` * `, ` / `, ` % `) at depth 0, split into operands, check
//     each for float shape (decimal literal, _f64(/_f32( suffix,
//     or bare ident with f-typed via infer_var_type_from_source).
//     If any operand is float, dispatch to f64_to_str.

fn main() -> i64 {
    let a: f64 = 1.5;
    let b: f64 = 2.5;
    println!("sum={}", a + b);     // f64 binop -- pre-fix: bit pattern
    let flag: bool = true;
    println!("not={}", !flag);     // unary not -- pre-fix: "0"
    return 42;
}
