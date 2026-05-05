// EXPECT: error[EFF-001]
// v0.8.307 R05-D1 Phase 1 — `pure fn` body containing print() must fail
// during `nuc build` (not just `nuc check`).
//
// Pre-v0.8.307 this compiled cleanly because s1 build path didn't
// run effect checker. Post-v0.8.307 emits error[EFF-001].

pure fn impure_pure() -> i32 {
    print("side effect in pure fn");
    return 0;
}

fn main() -> i32 {
    return impure_pure();
}
