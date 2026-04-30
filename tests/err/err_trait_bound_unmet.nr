// EXPECT: error[TYP-025] does not implement trait
// v0.4.162: generic trait bounds checked at call sites.
// Pre-fix `add_values(a: i64, b: i64)` for `fn add_values<T:
// Addable>(...)` silently accepted i64 even though no
// `impl Addable for i64` exists in scope. Codegen lowered to
// the user-fn call which then ran arithmetic on whatever the
// runtime-helper resolution found — typically working but
// only because i64 happens to support `+`. Halt at type-check
// when concrete arg type doesn't satisfy the trait bound.
// Original spike used TYP-021 (which v0.4.136 already owns
// for "void RHS in let") — remapped to TYP-025 at integration.

trait Addable {
    fn zero() -> i32;
}

impl Addable for i32 {
    fn zero() -> i32 { 0 }
}

fn add_values<T: Addable>(a: T, b: T) -> T {
    a + b
}

fn main() -> i32 {
    let a: i64 = 10;
    let b: i64 = 20;
    print_int(add_values(a, b));
    0
}
