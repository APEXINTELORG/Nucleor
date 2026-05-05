// EXPECT: warning[PERF-2]
// v0.8.297 R10-D2 Phase 1 — @hot fn body containing print() must
// emit warning[PERF-2].
//
// Pre-v0.8.297 @hot was discovery-only (audit count). Post-v0.8.297
// the body scan flags alloc/I/O in @hot bodies.

@hot
fn hot_with_io() -> i32 {
    print("debug log in hot path");
    return 0;
}

fn main() -> i32 {
    return hot_with_io();
}
