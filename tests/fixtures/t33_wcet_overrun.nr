// T3.3 (v0.3.2 take-2) static WCET fixture — used by the verify
// gate to assert the v1 estimator emits warning[RT-004] when the
// estimated body cost exceeds the declared deadline.
//
// Fixture: `#[deadline = 1]` (1 µs) on a fn whose body contains a
// while loop with multiple `;` statements. v2 estimator counts
// stmts × (1, 100, 1000, 10000 multiplier for 0/1/2/3+ whiles).
// Body has 1 while + 6 `;` → 6 × 100 = 600 units = 60 µs > 1 µs.

#[deadline = 1]
#[no_alloc]
fn obvious_overrun(x: i64) -> i64 {
    let mut acc: i64 = 0;
    let mut i: i64 = 0;
    while i < 100 {
        acc = acc + i;
        i = i + 1;
    };
    return acc + x;
}

fn main() -> i64 {
    return obvious_overrun(0);
}
