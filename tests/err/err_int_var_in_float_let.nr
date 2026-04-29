// EXPECT: error[NUM-020] integer-typed expression cannot initialize float binding
// v0.4.113: closes a SILENT MISCOMPUTE — `let f: f64 = i;` for an
// i64 variable type-checked clean (types_compatible accepted any
// i*/f* combo), and codegen lowered without a sitofp instruction
// — the i64 bit pattern was stored directly in the f64 slot. For
// `i: i64 = 5` the f64 binding then printed `0.000000` (5 as a
// denormal f64) instead of `5.0`.
//
// Sister to NUM-018 (float literal into int binding, v0.4.76).
// The literal-int-into-f64 case (`let f: f64 = 5;`) still works
// — the parser's narrow-numeric coercion handles it via the
// type-aware literal-emit path, so only non-literal int
// expressions trip NUM-020.

fn main() -> i32 {
    let i: i64 = 5;
    let f: f64 = i;
    print_f64(f);
    0
}
