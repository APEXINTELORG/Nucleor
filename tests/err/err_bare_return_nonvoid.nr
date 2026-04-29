// EXPECT: error[TYP-010] bare `return;` in fn declared to return
// v0.4.112: bare `return;` in a fn with non-void declared return
// type silently emitted `ret i64 undef` pre-fix; LLVM optimised
// that to the alloca's zero-init slot, so callers got 0 / garbage
// with no signal. Sister to v0.4.108's tail-expr ret check —
// that one fired on tail expressions; this one fires on the
// previously-skipped val<0 branch in the kind==22 type-check.

fn main() -> i32 {
    return;
}
