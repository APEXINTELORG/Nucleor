// EXPECT: error[EFF-001]
// R05-D4 Phase 2b: same-file requires-row propagation catches a
// wrapper that calls an effectful function without declaring the effect.
fn effectful() -> i32 requires [io.read] { 42 }
fn wrapper() -> i32 { effectful() }

pure fn should_fail() -> i32 {
    wrapper()
}

fn main() -> i32 { should_fail() }
