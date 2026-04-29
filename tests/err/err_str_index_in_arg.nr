// EXPECT: error[TYP-011] str does not support direct indexing
// v0.4.117: TYP-011 promoted from type-check side to codegen side.
// Pre-fix the type_check guard at line 11567 only fired when `s[i]`
// was the let-stmt RHS — fn-call args (`print_int(s[0])`) and
// `as` casts (`s[0] as i64`) skipped past it because the
// type_dynamic_helper early-return at line 11297 short-circuited
// the call's arg-walk. Codegen-side check fires unconditionally
// for every kind 10 receiver-is-str, halting before the broken
// `vec_get` lowering runs.

fn main() -> i32 {
    let s: str = "hello";
    print_int(s[0]);
    0
}
