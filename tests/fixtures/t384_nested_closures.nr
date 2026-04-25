// t384_nested_closures.nr — v0.3.107 regression fixture.
//
// Pins the nested-closure id allocation. Pre-v0.3.107, both the
// outer and inner closures queried `vec_len(closures)` for their
// id while the closures Vec was still empty — both got id 0,
// hard-failing at clang link with `invalid redefinition of
// function '__closure_0'`. The push-after-lower order in
// lower_expr at kind 42 reserved the slot only AFTER the body
// (which contained the inner closure) had been lowered. Adopters
// reaching for the canonical Rust returns-a-closure pattern
// (`let make = |n| { return |x| x + n; };`) hit the link error
// on first use — a hard adoption blocker for any functional /
// curried API design.
//
// Fix: push the outer closure into `closures` BEFORE lowering its
// body. The push reserves the slot for the already-allocated
// `clo_idx`, so nested closures get the next id (1, 2, …). Safe
// because clo_fir is a Vec reference and lower_stmts mutates it
// in place — the closures list holds the same pointer either way.
//
// Returns 12 = 5 + 7, proving the captured `n` from the outer
// closure correctly reaches the inner closure's body and both
// closures emit distinct LLVM functions.

fn main() -> i64 {
    let make = |n: i64| -> fn(i64) -> i64 {
        return |x: i64| -> i64 { return x + n; };
    };
    let add5 = make(5);
    return add5(7);
}
