// EXPECT: error[TYP-005] wrong number of arguments to closure 'f'
// v0.4.146: closure call-site argc check. Pre-fix `let f = |x:
// i64, y: i64| x + y; f(5);` silently lowered an indirect call
// with arg_regs of length 1 for a 2-param closure body — the
// closure read undefined registers for the missing param,
// returning garbage. Closures aren't in `sigs` (their binding
// lives in tenv with no plist), so the kind-7 type-check's
// existing argc check never fired. Fix: at let-stmt type-check
// time, when init kind is 42 (closure), register
// `__closure_argc_<vname>` in tenv with the param count. At the
// kind-7 call site, look it up and compare. Mirrored to
// nucleor_tools_suite.nr.

fn main() -> i32 {
    let f = |x: i64, y: i64| x + y;
    print_int(f(5));
    0
}
