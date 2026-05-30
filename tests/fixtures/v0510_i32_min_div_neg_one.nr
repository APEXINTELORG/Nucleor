// Runtime-panic regression for v0.5.10. Build succeeds, exe runs,
// and panics non-zero rc with a Nucleor-side PANIC message naming
// the overflow class. probe finding
// 2026-05-01-i32-min-div-neg-one-windows-exception: pre-v0.5.10 this
// surfaced as Windows STATUS_INTEGER_OVERFLOW (rc=-1073741675), an
// opaque process exit. v0.5.10 routes narrow-width signed div/rem
// through new `__nucleor_panic_div_iN` helpers that catch the
// iN::MIN/-1 + zero corners with a clean PANIC message.
//
// Runtime expectations (verified by `v0510_i32_min_div_overflow`
// step in tools/verify.sh):
//   - rc != 0 (specifically rc=1, not Windows STATUS_INTEGER_OVERFLOW)
//   - stderr contains "PANIC: i32 div overflow: i32::MIN / -1"

fn main() -> i32 {
    let a: i32 = 0 - 2147483648;
    let b: i32 = 0 - 1;
    print_int(a / b);
    0
}
