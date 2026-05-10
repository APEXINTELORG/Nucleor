// EXPECT: FFI-G5-NULL-DEREF
// G5-FN-1: known handle-producing externs that return i64 must
// participate in the null-return contract even when the extern
// declaration itself lacks #[may_return_null].
extern fn nuc_handle_new() -> i64;

#[effect(direct_ffi, may_return_null)]
fn make_and_use() -> i64 {
    let p: i64 = nuc_handle_new();
    return p + 1;
}

#[allow_effect(direct_ffi)]
fn main() -> i32 {
    make_and_use();
    0
}
