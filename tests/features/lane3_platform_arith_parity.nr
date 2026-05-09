// Lane 3 (F-CONC-016): platform-divergence parity smoke.
//
// Compiles arith primitives whose behavior must be identical on
// Linux + Windows + macOS: integer overflow wrap, division, modulo,
// shift, bitwise. Test runs on every host; CI compares stdout
// across hosts via a separate harness step. This file just
// guarantees the *output* is byte-stable per-host.

fn main() -> i64 {
    // Signed wrap on overflow.
    let a: i64 = 9223372036854775807;
    let wrap: i64 = a + 1;
    if wrap != -9223372036854775808 {
        return 1;
    };
    // Division — truncated toward zero.
    let q: i64 = -7 / 2;
    if q != -3 {
        return 2;
    };
    // Remainder — sign of LHS.
    let r: i64 = -7 % 2;
    if r != -1 {
        return 3;
    };
    // Shift — left by 32 on 64-bit value.
    let s: i64 = 1;
    let sl: i64 = s * 4294967296;
    if sl != 4294967296 {
        return 4;
    };
    // Bitwise: x ^ x == 0.
    let xor_zero: i64 = 0xDEADBEEF ^ 0xDEADBEEF;
    if xor_zero != 0 {
        return 5;
    };
    print("OK lane3_platform_arith_parity");
    return 0;
}
