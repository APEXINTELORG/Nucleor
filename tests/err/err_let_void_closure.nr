// EXPECT: error[TYP-021] `void`-typed expression cannot initialize binding
// v0.4.156: closure call returning void silently bound the let
// target to 0. Pre-fix `let r = f(42)` for `let f = |n: i64| {
// print_int(n); };` walked through every kind-7 check (the
// v0.4.146 closure argc check matched 1==1, the rest fell to
// `return builtin_rtype("f")` which returns ""), so init_t
// was empty and v0.4.136 TYP-021 didn't fire because its guard
// is `init_t == "void"` not "". Sister fix to v0.4.139 (Vec
// void mutators) and v0.4.146 (closure argc): register the
// closure body's last-stmt type as `__closure_rtype_<vname>`
// in tenv at let-stmt time, return it from kind-7 type_expr
// at call sites. That cascades through v0.4.136 TYP-021,
// v0.4.132 TYP-020, NUM-022, etc. without per-callsite
// duplication. Mirrored to nucleor_tools_suite.nr.

fn main() -> i32 {
    let f = |n: i64| { print_int(n); };
    let r = f(42);
    print_int(r);
    0
}
