// t425_user_fn_named_wrapping_saturating.nr — v0.3.150 regression fixture.
//
// Pre-v0.3.150, classify_kw mapped `wrapping` (78) and `saturating`
// (79) to hard kw tokens for planned RFC overflow-block forms
// (`wrapping { x + y }` etc.). Both block forms had ZERO usage in the
// codebase. parse_primary's tt == 78/79 branches called
// parse_wrapped_block_expr which, when given `(x)` instead of `{x}`,
// parsed the inner expression as the wrap target and emitted a call
// to __nucleor_wrap_i32 -- a runtime helper that doesn't exist.
//
// Adopters writing `fn wrapping(x) { ... }` and calling
// `wrapping(41)` got a clang LINK error pointing at IR they didn't
// write ("undefined reference to __nucleor_wrap_i32"). Same hazard
// class as v0.3.149 unsafe: noisy, non-fatal-LOOKING failure mode
// that points at the wrong place. Adopter scratches their head.
//
// Both names are common in user code (`fn saturating(x: i64, max:
// i64) -> i64 { ... }`, `fn wrapping(x: i64) -> i64 { ... }` for
// fixed-width arithmetic helpers).
//
// Fix (v0.3.150): removed both names from classify_kw and removed
// the dead parse_primary tt == 78/79 branches (zero block-form
// usage anywhere, same pattern as v0.3.140 restricts).
//
// Returns 42 = wrapping(41) = 41 + 1.

fn wrapping(x: i64) -> i64 { return x + 1; }
fn saturating(x: i64) -> i64 { return x + 2; }

fn main() -> i64 {
    let r1: i64 = wrapping(41);
    if r1 != 42 { return 1; };
    let r2: i64 = saturating(40);
    if r2 != 42 { return 2; };
    return 42;
}
