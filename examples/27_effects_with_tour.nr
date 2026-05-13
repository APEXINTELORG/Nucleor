//! `with [effects]` tour.
//!
//! Single runnable program exercising effects in function types.
//! Compile with `nuc build examples/27_effects_with_tour.nr` and run;
//! prints 3 OK lines and exits 0.
//!
//! Effect annotations can appear in the function type via `with [...]`.
//! That makes allocation and panic contracts visible at call sites.

/// Function declared with effect contract on the type. The body runs
/// in the no_alloc + no_panic world.
fn pure_inc(x: i64) -> i64 with [no_alloc, no_panic] {
    return x + 1;
}

/// Higher-order: a fn that takes a callback whose type also carries
/// an effect contract. The compiler verifies at the call site that
/// any callback passed in here matches the declared effect set.
fn apply_pure(cb: fn(i64) -> i64 with [no_alloc, no_panic], x: i64) -> i64 with [no_alloc, no_panic] {
    return cb(x);
}

/// FFI surface: extern declarations can also carry effect contracts.
/// Adopters pinning a host fn to "no_alloc + no_panic" surface a
/// type-level proof that downstream call paths preserve the contract.
extern fn host_known(x: i64) -> i64 with [no_alloc, no_panic];

fn main() -> i32 {
    let a: i64 = pure_inc(41);
    if a != 42 { return 1; };
    print_int(a);
    print("OK 27_effects_with_tour: pure_inc");

    let b: i64 = apply_pure(pure_inc, a);
    print_int(b);
    print("OK 27_effects_with_tour: apply_pure");

    print("OK 27_effects_with_tour: substrate exercised");
    return 0;
}
