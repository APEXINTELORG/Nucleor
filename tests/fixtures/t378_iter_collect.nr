// t378_iter_collect.nr — v0.3.102 regression fixture.
//
// Pins `.collect()` as the iterator-chain terminator. Pre-v0.3.102,
// the canonical Rust pattern `let w: Vec<T> = v.iter().map(f).collect();`
// failed at clang link with `use of undefined value '@vec_collect'`
// even though the `.map(f)` step already returned a fresh Vec —
// `.collect()` had no runtime helper and wasn't in the iter-method
// dispatch table. Adopters reaching for the standard iterator
// pipeline hit this on their first program.
//
// Returns 12 = 2 + 4 + 6 (each input element doubled), proving
// the chain `vec![1,2,3].iter().map(dbl).collect()` lowers cleanly
// and the terminating Vec is index-able.

fn dbl(x: i64) -> i64 { return x * 2; }

fn main() -> i64 {
    let v: Vec<i64> = vec![1, 2, 3];
    let w: Vec<i64> = v.iter().map(dbl).collect();
    return w[0] + w[1] + w[2];
}
