// EXPECT: PERF-2 hot-path performance hint
// Lane 3 (F-DIAG-006): PERF-2 had no negative test.
// Pattern that should fire the hot-loop allocation hint.

fn main() -> i64 {
    let mut total: i64 = 0;
    let mut i: i64 = 0;
    while i < 1000 {
        let v: Vec<i64> = Vec::new();
        v.push(i);
        total = total + v.len();
        i = i + 1;
    };
    return total;
}
