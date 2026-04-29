// EXPECT: error[TYP-024] `if`-expression branches have incompatible types
// v0.4.145: if-expression branches with incompatible types
// silently picked the then-branch type and bit-cast the else
// value into that slot. `let x = if cond { 1 } else { "two" };`
// returned i32; when cond was false, x got the str pointer's
// i64 value bit-cast as i32 → garbage at use sites. Rust rejects
// with E0308 ("if and else have incompatible types"). Detect at
// kind-23 type_expr when both branches have known types AND
// types_compatible_context says they're not compatible AND
// neither is void/unit (early-return branches like
// `if cond { return x; } else { val }` legitimately have
// void/unit on one side and continue to compile).
// s1-only fix.

fn main() -> i32 {
    let x = if true { 1 } else { "two" };
    print_int(0);
    0
}
