// T3.16 (v0.3.26) #[deadline] intersection rule for the
// v0.3.24 #[ffi_no_alloc] / #[ffi_no_panic] markers. Three
// externs: one alloc-only marker, one panic-only marker, one
// with BOTH markers. A #[deadline] caller invokes all three.
//
// Deadline determinism subsumes both no-* contracts, so a
// #[deadline] body considers an extern safe iff it carries
// BOTH markers (the intersection of #[ffi_no_alloc]-marked
// and #[ffi_no_panic]-marked externs).
//
// Verify gate asserts:
//   * RT-005 mentions h_alloc_only (single marker not enough)
//   * RT-005 mentions h_panic_only (single marker not enough)
//   * RT-005 does NOT mention h_both (intersection silences)

#[ffi_no_alloc]
extern fn h_alloc_only(x: i64) -> i64;

#[ffi_no_panic]
extern fn h_panic_only(x: i64) -> i64;

#[ffi_no_alloc]
#[ffi_no_panic]
extern fn h_both(x: i64) -> i64;

#[deadline = 100]
#[allow_fn(RT-007)]
fn dl_caller(x: i64) -> i64 {
    let a: i64 = h_alloc_only(x);
    let b: i64 = h_panic_only(x);
    let c: i64 = h_both(x);
    return a + b + c;
}

fn main() -> i64 {
    return 0;
}
