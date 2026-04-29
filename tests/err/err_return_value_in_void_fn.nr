// EXPECT: error[TYP-010] `return i32`-typed value in fn `f` whose return type is void
// v0.4.142: `return <expr>;` in a void-returning fn (whether
// declared `fn f() -> ()` or implicit `fn f() { ... }`)
// silently discarded the value at codegen time. The
// `fn f() -> ()` form was already caught by TYP-010, but the
// `fn f() { ... }` form (rtype empty / "void") sailed through:
// the existing check at kind-22 had `str_len(rtype) > 0 &&
// str_eq(rtype, "void") == 0` which skips both empty and "void"
// rtypes. Add a dedicated branch: if rtype is void/unit/empty
// AND val_t is non-void/non-unit, halt with TYP-010 directing
// the user to either drop the value or add `-> T`. Mirrored to
// nucleor_tools_suite.nr.

fn f() {
    return 42;
}

fn main() -> i32 {
    f();
    print_int(0);
    0
}
