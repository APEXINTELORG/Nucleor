// EXPECT: error[EFF-001]
// R05-D4 Phase 2b: channel creation is a scheduling/synchronization effect
// and cannot be used inside a pure fn.

pure fn bad() -> i32 {
    let _ch: i64 = channel(2);
    0
}

fn main() -> i32 {
    bad()
}
