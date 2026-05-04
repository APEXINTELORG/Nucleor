// v0.8.19 RFC-0062 G-8 P1 — conditional-divergence test B
// Match-arm borrows of the same value, both arms borrow only.
// After the match `s` is still owned and we read it again.
fn main() -> i64 {
    let mut s: Vec<i64> = Vec::new();
    s.push(1); s.push(2); s.push(4);
    let n: i64 = vec_len(&s);
    let label: i64 = if n < 2 {
        10
    } else {
        if n < 5 { 20 } else { 30 }
    };
    return label + vec_len(&s);  // 20 + 3 = 23
}
