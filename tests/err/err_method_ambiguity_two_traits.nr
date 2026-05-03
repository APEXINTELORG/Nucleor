// EXPECT: ERROR: ambiguous method
//
// v0.6.23 (probe finding 2026-05-02-method-ambiguity-misleading-two-modules-diag):
// pre-fix when two traits define the same method name and both are
// impl'd for the same struct, the LLVM symbol mangling
// `<Type>__<method>` collides at link time. The pre-fix diag said
// "duplicate pub fn name across modules" — misleading because the
// impls are in the same file. v0.6.23 detects the `Type__method`
// symbol shape and emits a clear "ambiguous method dispatch"
// diagnostic instead, mentioning Rust's E0034 and noting UFCS as
// the forward-roadmap fix.

trait T1 { fn name(self: &Self) -> str; }
trait T2 { fn name(self: &Self) -> str; }

struct W;

impl T1 for W { fn name(self: &W) -> str { return "T1::name"; } }
impl T2 for W { fn name(self: &W) -> str { return "T2::name"; } }

fn main() -> i32 {
    let w: W = W {};
    print(w.name());
    return 0;
}
