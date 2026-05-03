// v0.6.82 (defensive halt): Rust conversion-idiom methods
// (`.into()` / `.to_string()` / `.to_owned()` / `.to_vec()` /
// `.iter_mut()`) pre-fix fell through every receiver-typed
// dispatch and the catch-all synthesized `vec_<idiom>(receiver)`,
// failing late at clang link with the wrong-class
// `error[TYP-005]: receiver type 'Vec<T>' has no method ...` —
// confusing for adopters porting Rust code. Now halts cleanly with
// per-idiom workaround. Negative fixture (compile must reject).
fn main() -> i32 {
    let s: String = "hello".into();    // ← halts: .into() conversion idiom unsupported
    return 0;
}
