// v0.4.41 RFC-0028 phase 5 follow-on: `{:?}` Debug formatter.
// Rust convention: Debug for primitives = same as Display; Debug
// for strings wraps in quotes ("..."). The high-value case for
// adopters is debug-printing strings to disambiguate "hello" from
// hello (display).
fn main() -> i64 {
    let s: str = "hello";
    let n: i64 = 42;
    let b: bool = true;
    let pi: f64 = 3.14;

    println!("{:?}", s);    // expect "hello" (with quotes)
    println!("{:?}", n);    // expect 42
    println!("{:?}", b);    // expect true
    println!("{:?}", pi);   // expect 3.14

    // Plain {} for contrast (no quotes on str)
    println!("{}", s);      // expect hello (no quotes)

    return 0;
}
