// EXPECT: error[EFF-001]
// R05-D4 Phase 2b: undeclared extern calls default to an unsafe/raw
// effect surface and cannot be called from a pure fn.

extern fn abs(x: i32) -> i32;

pure fn bad() -> i32 {
    abs(-7)
}

fn main() -> i32 {
    bad()
}
