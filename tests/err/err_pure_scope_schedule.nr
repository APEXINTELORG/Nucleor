// EXPECT: error[EFF-001]
// R05-D4 Phase 2b: structured scheduling is an effectful operation and
// cannot be used inside a pure fn.

pure fn bad() -> i32 {
    scope {
    }
    0
}

fn main() -> i32 {
    bad()
}
