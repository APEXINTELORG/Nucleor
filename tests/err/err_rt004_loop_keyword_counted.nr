// EXPECT: warning[RT-004]
// Verifies v0.8.292: `loop { ... }` participates in the RT-004
// loop-multiplier ladder. Pre-v0.8.292 the estimator counted only
// `while`, so a body of nothing but `loop {}` tallied
// while_count=0 → multiplier=1 → severe under-estimate.
//
// This body has 1 loop + ~22 statements. Pre-fix: ~22 units = 2.2us
// → no RT-004 (deadline 1us is met "trivially"). Post-fix:
// while_count=1 → multiplier=100 → 22*100 = 2200 units = 220us,
// which exceeds the declared 1us deadline → RT-004 fires.
//
// Audit ref: BUILD_PLAN_R03_realtime_determinism.md §1 R03-D3.

#[deadline = 1us]
fn looping() -> i32 {
    let mut x: i32 = 0;
    loop {
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        x = x + 1;
        if x > 100 { break; };
    };
    return x;
}

fn main() -> i32 {
    return 0;
}
