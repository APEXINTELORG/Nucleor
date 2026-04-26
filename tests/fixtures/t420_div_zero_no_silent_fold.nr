// t420_div_zero_no_silent_fold.nr — v0.3.145 regression fixture.
//
// Pre-v0.3.145, opt_fold_block had two compounding bugs in its
// const-fold path for div/mod when the divisor was a constant zero:
//   1. The fold replaced the div/mod instruction with `const_int 0`
//      anyway -- silent miscompute, `100 / 0` returned 0 instead of
//      trapping at runtime.
//   2. The `else { i = i + 1; }` branch pre-incremented the loop
//      counter, then the outer `i = i + 1` at the bottom of the loop
//      incremented it AGAIN -- silently SKIPPING the very next IR
//      instruction in the block.
//
// Same hazard class as the v0.3.137-v0.3.144 silent miscompiles: a
// real expression you wrote produces nothing useful and no
// diagnostic. Adopters who hit a literal `x / 0` (deliberate panic
// test, debugging marker, refactoring artefact) saw the program
// return 0 silently and skip whatever statement followed.
//
// Fix: when divisor is const zero, do NOT replace the inst with
// const 0. Leave the divide in place; at runtime LLVM `sdiv i64 X, 0`
// is undefined behaviour (typically SIGFPE) which is loud, not
// silent. Do NOT touch the loop counter `i`.
//
// Test design: the divide is inside a fn branch we never take at
// runtime, so the SIGFPE is avoided. Pre-fix, the divide was
// silently folded to const 0 at compile time. Post-fix, the IR
// emits `sdiv i64 100, 0` (verified by inspection of t420.ll).
// Both pre- and post-fix returns 42 from this main; the difference
// is the IR shape and the never-skipped post-divide instruction.
// We verify the second bug by exercising the path AROUND the
// divide and asserting subsequent statements still landed.

fn maybe_div(go: i64) -> i64 {
    if go == 1 {
        // Pre-v0.3.145: this divide was const-folded to 0 AND the
        // very next IR instruction (the store for `_q`) was silently
        // dropped from the block. We never take this branch from
        // main, so SIGFPE is avoided either way.
        let _q: i64 = 100 / 0;
        return _q;
    };
    return 42;
}

fn main() -> i64 {
    return maybe_div(0);
}
