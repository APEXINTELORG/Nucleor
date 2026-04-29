// EXPECT: error[TYP-010] tail-expression type does not match
// v0.4.108: tail-expression return-type check. Pre-fix
// `fn add(a, b) -> str { a + b }` (i32 tail-expr returned as str)
// type-checked clean and produced a runtime SIGSEGV at the caller
// when the i64 sum was reinterpreted as a str pointer. TYP-010
// only checked explicit `return val;` (kind 22), not tail-expr
// (kind 25). Now the closing brace of every fn body with a
// declared non-void return runs the tail-expr through type_expr
// and compares to the declared return type.

fn add(a: i32, b: i32) -> str {
    a + b
}

fn main() -> i32 {
    let x: str = add(1, 2);
    print(x);
    0
}
