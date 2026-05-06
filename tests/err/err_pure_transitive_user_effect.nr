// EXPECT: error[EFF-001]
// R05-D4 Phase 2b: pure functions must reject same-file user helpers
// whose bodies contain side effects, even when the pure body itself only
// calls the helper and does not directly call print/alloc/ambient APIs.

fn noisy_helper() -> i32 {
    print("side effect through helper");
    1
}

pure fn compute() -> i32 {
    noisy_helper()
}

fn main() -> i32 {
    compute()
}
