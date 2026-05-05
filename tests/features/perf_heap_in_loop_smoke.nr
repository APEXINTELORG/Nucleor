// EXPECT: warning[PERF-3]
// v0.8.298 R10-D2 Phase 1.5 — `Vec::new` inside `while` body fires PERF-3.
//
// Pre-v0.8.298 per-iteration heap alloc was invisible. Post-v0.8.298
// the loop-depth-tracking scan emits a warning.

fn alloc_in_loop(n: i64) -> i64 {
    let mut total: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let v: Vec<i64> = Vec::new();
        total = total + i;
        i = i + 1;
    };
    return total;
}

fn main() -> i32 {
    let r: i64 = alloc_in_loop(3);
    return 0;
}
