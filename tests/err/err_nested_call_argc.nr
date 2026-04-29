// EXPECT: error[TYP-005] wrong number of arguments for 'add'
// v0.4.144: nested fn call inside a runtime helper / built-in
// arg position escaped every type-check diagnostic. The kind-7
// `type_expr` walked args only when callee was in sigs (user-fn
// path) OR in `type_dynamic_helper` (compiler-internal path) —
// runtime helpers like `print_int` / `print` / `panic` fall in
// neither category. Pre-fix `print_int(add(5))` for `fn add(a:
// i64, b: i64) -> i64` silently passed: the inner `add(5)` had
// argc=1 vs expected=2 (would normally fire TYP-005), but
// `type_expr` was never called on it. Mirrors v0.4.117's same-
// hazard fix for the dynamic-helper path. Mirrored to
// nucleor_tools_suite.nr.

fn add(a: i64, b: i64) -> i64 { a + b }

fn main() -> i32 {
    print_int(add(5));
    0
}
