// v0.4.135: str-literal receiver dispatch. Pre-fix, method calls
// on a bare string literal (kind 2 AST node) had empty stype from
// `expr_struct_type` and routed to `vec_<m>` / `vec_<m>_i64`
// runtime helpers — silent miscompute reading the str header as a
// vec header. `"abc".len()` returned 0 instead of 3;
// `"hello".contains("ll")` would have read garbage. Fix detects
// kind-2 receiver in the kind-8 method-dispatch path and stamps
// stype = "str" so the existing v0.4.88 str_* helper dispatch
// catches it. Mirrored to nucleor_tools_suite.nr.

fn main() {
    let n: i64 = "abc".len();
    print_int(n);
    let m: i64 = "hello world".len();
    print_int(m);
    let c: i64 = "hello world".contains("world");
    print_int(c);
    let s: i64 = "hello world".starts_with("hello");
    print_int(s);
    let e: i64 = "hello world".ends_with("world");
    print_int(e);
}
