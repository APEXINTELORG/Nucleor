// v0.6.76 RFC V1.9: assert!/assert_eq!/assert_ne! format-args expansion.
// Pre-fix `assert!(cond, "fmt {}", arg)` stripped `!` and emitted a
// 3-arg `assert(cond, "fmt {}", arg)` call to a 1-arg helper —
// format args dropped, "{}" stayed literal, false-pass on truthy cond.
// Post-fix: textual rewrite to `if !(cond) { panic!("fmt-built"); };`
// — format args expand, panic on failure produces formatted message.
fn main() -> i32 {
    let n: i64 = 7;
    // Truthy assert — stays silent, falls through.
    assert!(n > 0, "expected positive, got {}", n);
    // Truthy assert_eq.
    let a: i64 = 5;
    let b: i64 = 5;
    assert_eq!(a, b, "expected {} == {}", a, b);
    // Truthy assert_ne.
    let c: i64 = 9;
    let d: i64 = 11;
    assert_ne!(c, d, "expected {} != {}", c, d);
    print_int(n as i32);
    return 0;
}
