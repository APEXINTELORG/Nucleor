// EXPECT: NAM-001 duplicate parameter name
// Lane 3 (F-DIAG-006): NAM-001 had no negative test in the corpus.
// Two params with the same name; the second shadow is rejected at
// parse-time.

fn add(a: i64, a: i64) -> i64 {
    return a + a;
}

fn main() -> i64 {
    return add(1, 2);
}
