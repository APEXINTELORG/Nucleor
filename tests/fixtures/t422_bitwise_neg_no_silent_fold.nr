// t422_bitwise_neg_no_silent_fold.nr — v0.3.147 regression fixture.
//
// Pre-v0.3.147, opt_fold_block emulated bitwise & | ^ via a 64-bit
// while-shift loop using `ra - (ra/2)*2 == 1` to extract the LSB.
// For negative odd ra (e.g. -1), C-style integer division (Nucleor's
// semantics) rounds toward zero: `-1/2 == 0` and `-1 - 0*2 == -1`,
// not `1`. The `== 1` check failed, no bit was recorded as set, and
// the entire fold collapsed to ~0 for negative operands.
//
// Concretely, `0xff & -1` const-folded to 0 instead of 255. Same
// hazard class as v0.3.137-v0.3.146 silent miscompiles: a real
// expression you wrote produces a wildly wrong number with no
// diagnostic. Adopters using -1 (all-ones sentinel) for bitmasks --
// canonical pattern for "unset all flags" or "compute width from
// max" -- silently got 0.
//
// The runtime LLVM `and i64` is correct on signed-i64-as-bits;
// the bug was purely in the s1-emulated const fold.
//
// Fix: skip the bitwise const fold when either operand is negative
// (let runtime LLVM compute it). Tracked via a do_bit_fold flag,
// same pattern as the v0.3.145 div/mod-by-zero fold-skip.
//
// Returns 42 if all 4 bitwise checks against -1 pass.

fn main() -> i64 {
    let mask: i64 = 0xff;
    let neg_one: i64 = 0 - 1;

    let r1: i64 = mask & neg_one;
    if r1 != 255 { return 1; };

    let r2: i64 = neg_one & mask;
    if r2 != 255 { return 2; };

    let r3: i64 = neg_one ^ neg_one;
    if r3 != 0 { return 3; };

    let r4: i64 = neg_one | 0;
    if r4 != neg_one { return 4; };

    return 42;
}
