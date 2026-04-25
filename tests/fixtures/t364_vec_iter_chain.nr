// t364_vec_iter_chain.nr — v0.3.88 regression fixture.
//
// Pins the Rust idiom `vec.iter().X()` chain. Pre-v0.3.88, .iter()
// was unwired in iter_method_for_vec, dispatching to the generic
// `vec_iter` fallback which had no runtime helper, failing at
// clang link with `unresolved external symbol __nucleor_vec_iter`.
// Post-v0.3.88: .iter() registered as an iter-method that routes
// to vec_iter_i64, and the runtime adds an identity pass-through
// that returns the same Vec ptr (Nucleor's iter methods all work
// on Vec directly, so .iter() is a no-op in the chain).
//
// Returns 0 on success.

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1); v.push(2); v.push(3); v.push(4);

    // .iter().sum()
    if v.iter().sum() != 10 { return 91; };

    // Direct .sum() (regression)
    if v.sum() != 10 { return 92; };

    // .iter().max()
    if v.iter().max() != 4 { return 93; };

    return 0;
}
