// v0.8.19 RFC-0062 G-8 P1 — conditional-divergence test A
// Both branches borrow `&v` only (no move); reading `v` after
// the if is fine because no path consumed it.
fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(7); v.push(11);
    let probe: i64 = if vec_len(&v) == 0 {
        100
    } else {
        200
    };
    return probe + vec_len(&v);  // 200 + 2 = 202
}
