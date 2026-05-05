// EXPECT: error[EFF-002]
// v0.8.320 R05-D2 Phase 1 — `pure fn` cannot also declare a
// `requires [...]` effect row. Pre-v0.8.320 this syntax compiled and
// the requires clause was skipped as metadata.

pure fn bad() -> i32 requires [io.read] {
    42
}

fn main() -> i32 {
    bad()
}
