// EXPECT: MATCH-015 negative literal pattern
// Lane 3 (F-DIAG-006): MATCH-015 only had a positive fixture under
// tests/fixtures/, not a negative test in tests/err/. Now it does.
// Negative literal patterns in match arms aren't supported in v1.0.

fn classify(x: i64) -> i64 {
    let m: i64 = match x {
        -1 => 100,
        0 => 200,
        _ => 300,
    };
    return m;
}

fn main() -> i64 {
    return classify(-1);
}
