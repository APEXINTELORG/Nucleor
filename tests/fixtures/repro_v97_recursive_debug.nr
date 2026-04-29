// repro_v97_recursive_debug.nr — v0.4.97 audit doc-#1 §10b.
// Pre-fix `println!("{:?}", v)` for v: Vec<i64> emitted the
// pointer integer (silent miscompute). Same for Option/Result.
//
// v0.4.97 adds 3 C runtime helpers + {:?} dispatch routing.
// Element/payload formatted as i64 (Nucleor cell convention).
//
// EXPECT runtime output:
//   [1, 2, 3]
//   Some(42)
//   None
//   Ok(99)
//   Err(7)

fn main() -> i64 {
    let v: Vec<i64> = vec![1, 2, 3];
    println!("{:?}", v);

    let s: Option<i64> = Some(42);
    println!("{:?}", s);

    let n: Option<i64> = None;
    println!("{:?}", n);

    let r: Result<i64, i64> = Ok(99);
    println!("{:?}", r);

    let e: Result<i64, i64> = Err(7);
    println!("{:?}", e);

    return 0;
}
