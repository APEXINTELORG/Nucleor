// v0.8.17 RFC-0062 G-2 Phase 1 smoke fixture — BR-7 lifetime
// warning. Tags 3 fns / 1 struct with `<'a>` annotations. The
// build now emits a one-line warning per RFC-0062 §3.3 G-2 P1:
//   warning[BR-7]: lifetime annotations present in build: N
//   Per RFC-0062 G-2 Phase 1: lifetime annotations parse
//   cleanly but are NOT yet enforced by the borrow checker...
//
// rc = 0 (the warning is informational only; Phase 1 mode does
// not reject — Phase 4 promotes to error per the gap RFC).

struct Wrapper<'a> {
    data: &'a Vec<i64>,
}

fn first<'a>(xs: &'a Vec<i64>) -> i64 {
    return vec_get(xs, 0);
}

fn second<'b>(xs: &'b Vec<i64>) -> i64 {
    return vec_get(xs, 1);
}

fn keep_static() -> &'static str {
    return "hello";
}

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(7); v.push(11);
    return first(&v) + second(&v);  // 18
}
