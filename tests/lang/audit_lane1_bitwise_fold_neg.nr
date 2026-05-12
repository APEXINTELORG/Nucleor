// Regression gate / C-004: negative i64 operands must use the same
// bitwise semantics in the optimizer fold path and in emitted LLVM.
//
// The validation script builds this fixture with --emit=llvm and checks
// that main contains no residual `and/or/xor i64` instructions. That
// proves these constant expressions folded instead of merely running the
// correct LLVM runtime path.

fn main() -> i64 {
    let r1: i64 = 0xffffffffffffffff & 255;
    if r1 != 255 { return 1; };

    let r2: i64 = 255 & 0xffffffffffffffff;
    if r2 != 255 { return 2; };

    let r3: i64 = 0xffffffffffffffff ^ 0xffffffffffffffff;
    if r3 != 0 { return 3; };

    let r4: i64 = 0xffffffffffffffff | 0;
    if r4 != 0xffffffffffffffff { return 4; };

    let r5: i64 = 0xfffffffffffffffd | 5;
    if r5 != 0xfffffffffffffffd { return 5; };

    let r6: i64 = 0xfffffffffffffffd ^ 5;
    if r6 != 0xfffffffffffffff8 { return 6; };

    let r7: i64 = 0xfffffffffffffff8 & 7;
    if r7 != 0 { return 7; };

    print("OK audit_lane1_bitwise_fold_neg\n");
    return 0;
}
