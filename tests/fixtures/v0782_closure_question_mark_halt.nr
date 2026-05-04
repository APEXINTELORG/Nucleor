// v0.7.82 negative fixture — `?` operator inside a closure body.
// Pre-v0.7.82: the `?` emitted an `ir_ret` from the closure on the Err/None
// path. Nucleor closures return i64 by ABI, not Result/Option, so the
// Err/None Vec heap-pointer was returned as an i64 — wrong-class silent
// miscompute. v0.7.82 adds a defensive halt at lower_expr kind-122 when
// `__closure_id` is present in sym.
// Expected: compile-time panic "nucleor: `?` inside closure body not yet supported"
fn try_result(x: i64) -> Result<i64, str> {
    if x > 0 { return Ok(x * 2); }
    return Err("negative");
}
fn main() -> i64 {
    let transform = |x: i64| {
        let y = try_result(x)?;
        return y;
    };
    let r = transform(5);
    return r;
}
