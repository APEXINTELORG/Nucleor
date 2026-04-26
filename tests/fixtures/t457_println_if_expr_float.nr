// t457_println_if_expr_float.nr -- v0.3.195 regression fixture.
//
// Sister fix to v0.3.192 (print(if-expr) dispatch) on the
// println! `{}` heuristic side. Pre-v0.3.195 the format heuristic
// didn't recognize `if cond { ... } else { ... }` shape and fell
// through to int_to_str. For an if-expr returning f64, that
// printed the f64 bit pattern as i64.
//
// Same hazard class as v0.3.131/152/158/166/167/169/172/188 --
// the println! `{}` heuristic chain.
//
// Fix (v0.3.195): detect leading `if ` prefix in the textual
// arg expression. Scan the entire expression for a float-shaped
// substring (decimal literal with digits on both sides, or
// _f64(/_f32( suffix). If found -> f64_to_str; else int_to_str
// (the existing default for unknown types).

fn main() -> i64 {
    let f: f64 = 2.5;
    println!("{}", if f > 0.0 { f } else { 0.0 });   // "2.5"

    let n: i64 = 7;
    println!("{}", if n > 5 { 100 } else { -1 });    // "100" (int default)

    return 42;
}
