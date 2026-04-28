// repro_v69_eq_typo_guard.nr — v0.4.69 silent-miscompute close.
// `while x = 0` and `if x = 0` are typos for `==`. Pre-fix the
// parser printed parse-error lines and silently continued, building
// broken IR. v0.4.69 panics with a clear `==` hint at parse-time.

fn main() -> i64 {
    let mut x: i64 = 5;
    while x = 0 {                       // panic expected (= not ==)
        println!("inside");
        x = x - 1;
    };
    return 0;
}
