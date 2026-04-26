// t402_user_fn_shadows_runtime.nr — v0.3.126 regression fixture.
//
// Pins user-defined fns shadowing runtime helpers of the same name.
// Pre-v0.3.126, a user-defined `fn pow(base, exp)` was hijacked by
// `__nucleor_pow` (the f64 floating-point runtime helper) — every
// `pow(2, 8)` call dispatched to the float helper instead of the
// user's int loop. Silent miscompute with NO diagnostic. Adopters
// writing math/utility wrappers with common names (pow, abs, min,
// max, log, sin, …) hit this on the first probe — and the failure
// mode (a wildly wrong number) was indistinguishable from any other
// arithmetic bug in their code.
//
// Same hazard class as `Vec::with_capacity` returning 0 (v0.3.116)
// and `panic!` not stripping (v0.3.94) — silent dispatch failure
// under what looks like the right name.
//
// Fix: lower kind-7 fn calls through a new `ir_user_call` (op 31)
// when `__fnret_<fn_name>` is registered in sym (i.e. it's a
// user fn). The new op bypasses the runtime-helper name lookup in
// emit_inst — always emits `call i64 @<fn_name>` directly.
//
// Returns 0 = 256 mod 256, proving `pow(2, 8) = 256` (the user fn)
// instead of whatever the float helper produced.

fn pow(base: i64, exp: i64) -> i64 {
    let mut r: i64 = 1;
    let mut i: i64 = 0;
    while i < exp {
        r = r * base;
        i = i + 1;
    }
    return r;
}

fn main() -> i64 {
    return pow(2, 8);
}
