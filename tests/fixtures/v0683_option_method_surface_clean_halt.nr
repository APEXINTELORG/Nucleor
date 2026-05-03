// v0.6.83 (defensive halt): canonical Rust Option methods not yet
// in Nucleor's runtime surface (`unwrap_or_default`, `take`,
// `replace`, `flatten`, `as_ref`, `as_mut`, `iter`, `ok_or`,
// `ok_or_else`, `cloned`, `copied`) pre-fix fell through to the
// kind-8 catch-all `vec_<method>(receiver)` and surfaced as the
// wrong-class TYP-005 'Vec<T> has no method'. Now halts cleanly
// with per-method workaround. Negative fixture (compile rejects).
fn main() -> i32 {
    let opt: Option<i64> = None;
    let v: i64 = opt.unwrap_or_default();    // ← halts: unwrap_or_default not in surface
    print_int(v as i32);
    return 0;
}
