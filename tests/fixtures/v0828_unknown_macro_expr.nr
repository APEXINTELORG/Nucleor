// EXPECT: PANIC: nucleor: unknown macro `my_macro!(...)` not supported
//
// v0.8.28 fixture — unknown macro invocation in expression position.
//
// Pre-v0.8.28 any unrecognized `name!(args)` passed through the
// textual macro expansion with `!` preserved; the parser then read
// `name` as an identifier and `!(args)` as unary NOT applied to an i32
// argument → wrong-class error[TYP-002]: unary `!` requires a `bool`
// operand (got i32).
//
// v0.8.28 detects this in the macro expansion pass (third `!(` block)
// and halts with a descriptive diagnostic + workaround pointer.
fn main() -> i64 {
    let _x: i64 = my_macro!(5);
    return 0;
}
