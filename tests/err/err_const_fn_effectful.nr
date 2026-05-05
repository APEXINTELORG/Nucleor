// EXPECT: error[NUM-009]
// v0.8.293 R09-D4 Phase 1 — @const_fn body containing print() must fail.
//
// Pre-v0.8.293 this compiled cleanly because @const_fn was
// silently ignored (NUM-G9). Post-v0.8.293 the s1 compiler
// emits error[NUM-009] and the build fails.

@const_fn
fn impure_const() -> i32 {
    print("side effect");
    return 0;
}

fn main() -> i32 {
    return impure_const();
}
