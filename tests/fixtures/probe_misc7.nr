// More probes - looking for any remaining gaps.
fn main() -> i64 {
    // Print of unary deref (kind 92)
    let x: i64 = 42;
    let r: &i64 = &x;
    print(*r);   // 42

    // print of method on cast result
    let f: f64 = 3.7;
    print((f as i64) + 1);   // 4 (after fptosi -- wait this might still be the ABI no-op)

    // print of i64 cast to bool (?)
    let n: i64 = 1;
    print(n as bool);

    // println with method on string-returning fn
    let s: str = str_concat("a", "b");
    println!("{}", str_to_upper(s));

    return 0;
}
