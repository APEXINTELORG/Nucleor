// 02_fib.nr — Fibonacci, recursive and iterative.
// Build: nuc build examples/02_fib.nr -o fib
// Run:   ./fib.exe

fn fib_rec(n: i64) -> i64 {
    if n <= 1 { return n; };
    return fib_rec(n - 1) + fib_rec(n - 2);
}

fn fib_iter(n: i64) -> i64 {
    if n <= 1 { return n; };
    let mut a: i64 = 0;
    let mut b: i64 = 1;
    let mut i: i64 = 2;
    while i <= n {
        let next: i64 = a + b;
        a = b;
        b = next;
        i = i + 1;
    };
    return b;
}

fn str_from_int(n: i64) -> str {
    if n == 0 { return "0"; };
    let mut s: str = "";
    let mut v: i64 = n;
    if v < 0 { v = 0 - v; };
    while v > 0 {
        let d: i64 = v - (v / 10) * 10;
        s = str_concat(str_substring("0123456789", d, d + 1), s);
        v = v / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    return s;
}

fn main() -> i64 {
    let r: i64 = fib_rec(10);
    let i: i64 = fib_iter(20);
    print(str_concat("fib_rec(10) = ", str_from_int(r)));
    print(str_concat("fib_iter(20) = ", str_from_int(i)));
    return 0;
}
