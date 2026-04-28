// repro_v68_vec_ord_pointer_guard.nr
//
// v0.4.68 NUC-FEEDBACK silent-miscompute close for Vec ordering
// ops `<`, `<=`, `>`, `>=`. Pre-fix `a < b` for two Vec<T> values
// did integer pointer compare — disconnected from element-wise lex
// order. Adopters writing canonical Rust got quiet wrong results.
//
// v0.4.68 extends the v0.4.61 close (which only caught arith + ==/!=)
// to also catch ops 32/33/34/35.

fn make_vec() -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    v.push(1);
    return v;
}

fn main() -> i64 {
    let a: Vec<i64> = make_vec();
    let b: Vec<i64> = make_vec();
    if a < b {                          // TYP-011 expected
        println!("less");
    } else {
        println!("greater-or-eq");
    };
    return 0;
}
