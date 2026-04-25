// T3.15 (v0.3.24) #[ffi_no_alloc] / #[ffi_no_panic] markers
// fixture. Two extern declarations: one annotated safe, one
// not. A #[no_alloc] fn calls both — RT-005 should fire ONLY
// for the unannotated one.
//
// Verify gate asserts:
//   * RT-005 message mentions host_unsafe
//   * RT-005 message does NOT mention host_safe

#[ffi_no_alloc]
extern fn host_safe(x: i64) -> i64;

extern fn host_unsafe(x: i64) -> i64;

#[no_alloc]
fn rt_caller(x: i64) -> i64 {
    let a: i64 = host_safe(x);
    let b: i64 = host_unsafe(x);
    return a + b;
}

fn main() -> i64 {
    return 0;
}
