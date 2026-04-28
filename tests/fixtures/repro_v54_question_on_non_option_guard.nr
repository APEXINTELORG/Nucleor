// repro_v54_question_on_non_option_guard.nr
//
// v0.4.54 NUC-FEEDBACK silent-segfault guard for the `?` operator
// on non-Option/Result receivers.
//
// Pre-v0.4.54 `let x: i64 = some_fn()?;` where some_fn returns
// bare i64 (not Result<T,E> or Option<T>) silently SIGSEGVed at
// runtime. The `?` lower called `vec_get(val_r, 0)` on the i64
// value, dereferencing it as a pointer and crashing.
//
// v0.4.54 emits TYP-011 at type-check time when the inner kind-7
// fn-call returns a type whose base name is not Result/Option/Vec
// (Vec is allowed as the legacy untyped Result<i64, i64> stub).

fn some_fn() -> i64 {
    return 42;
}

fn main() -> i64 {
    let x: i64 = some_fn()?;   // TYP-011 expected
    println!("{}", x);
    return 0;
}
