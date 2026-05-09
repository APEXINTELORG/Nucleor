// Lane 3 (F-CONC-016): platform-divergence parity smoke.
//
// Compiles arith primitives whose behavior must be identical on
// Linux + Windows + macOS: integer overflow wrap, division, modulo,
// shift, bitwise. Test runs on every host; CI compares stdout
// across hosts via a separate harness step. This file just
// guarantees the *output* is byte-stable per-host.

// v1.0.1 integrator: opaque() forces values to be opaque to const-fold,
// so the wrapping/strict-overflow tests below exercise the runtime path
// rather than tripping the compile-time const-evaluator. Pre-fix the
// `let wrap: i64 = a + 1` was const-folded to a NUM-021 reject (audit
// strict mode treats compile-time signed wrap as a defect, but this
// fixture is *exercising* runtime wrap parity, not requesting strict).
fn opaque(x: i64) -> i64 {
    return x;
}

fn main() -> i64 {
    // Signed wrap on overflow.
    let a: i64 = opaque(9223372036854775807);
    let wrap: i64 = a + 1;
    if wrap != -9223372036854775808 {
        return 1;
    };
    // Division — truncated toward zero.
    let neg_seven: i64 = opaque(-7);
    let two: i64 = opaque(2);
    let q: i64 = neg_seven / two;
    if q != -3 {
        return 2;
    };
    // Remainder — sign of LHS.
    let r: i64 = neg_seven % two;
    if r != -1 {
        return 3;
    };
    // Shift — left by 32 on 64-bit value.
    let s: i64 = opaque(1);
    let factor: i64 = opaque(4294967296);
    let sl: i64 = s * factor;
    if sl != 4294967296 {
        return 4;
    };
    // Bitwise: x ^ x == 0.
    let dead: i64 = opaque(0xDEADBEEF);
    let xor_zero: i64 = dead ^ dead;
    if xor_zero != 0 {
        return 5;
    };
    print("OK lane3_platform_arith_parity");
    return 0;
}
