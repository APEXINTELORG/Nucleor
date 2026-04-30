// Regression-guard fixture for v0.4.205 — for-loop snapshots
// vec_len at loop entry; pushes inside the body extend the Vec
// but are NOT iterated. Pre-fix the for-loop re-read vec_len(v)
// every iteration; pushing inside the body grew len, the exit
// check never tripped, memory grew unboundedly. Run-Capped at
// 256 MB killed the process in ~5s — without it, an adopter would
// see the OS pause / OOM-kill an unrelated process.
//
// Snapshot semantics: the loop iterates EXACTLY the original-length
// elements. Matches Rust's `for x in v.iter().take(initial_len)`
// shape. If the body pushes K items, post-loop len = original_len + K
// but only original_len iterations ran.
//
// Closes findings/inbox/2026-04-30-push-during-for-iter-unbounded.md.

fn main() -> i32 {
    // Case 1: push during iter — must terminate, len = 6 (3 + 3).
    let mut v: Vec<i32> = Vec::new();
    v.push(1);
    v.push(2);
    v.push(3);
    let mut iter_count: i32 = 0;
    for x in v {
        v.push(x + 100);
        iter_count = iter_count + 1;
    };
    if iter_count != 3 { print("FAIL push-during-iter ran wrong number of times"); return 1; };
    if v.len() as i32 != 6 { print("FAIL push-during-iter final len wrong"); return 1; };

    // Case 2: empty Vec — zero iterations.
    let mut empty: Vec<i32> = Vec::new();
    let mut empty_count: i32 = 0;
    for _x in empty {
        empty_count = empty_count + 1;
    };
    if empty_count != 0 { print("FAIL empty-vec iterations"); return 1; };

    // Case 3: no mutation in body — exact element count.
    let mut readonly: Vec<i32> = Vec::new();
    readonly.push(10); readonly.push(20); readonly.push(30); readonly.push(40);
    let mut sum: i32 = 0;
    for x in readonly {
        sum = sum + x;
    };
    if sum != 100 { print("FAIL readonly sum"); return 1; };

    // Case 4: multiple pushes per body — still bounded by snapshot.
    let mut multi: Vec<i32> = Vec::new();
    multi.push(1); multi.push(2);
    let mut multi_iters: i32 = 0;
    for x in multi {
        multi.push(x * 10);
        multi.push(x * 20);
        multi_iters = multi_iters + 1;
    };
    if multi_iters != 2 { print("FAIL multi-push iterations"); return 1; };
    if multi.len() as i32 != 6 { print("FAIL multi-push final len"); return 1; };

    print("OK for_loop_push_during_iter_bounded");
    0
}
