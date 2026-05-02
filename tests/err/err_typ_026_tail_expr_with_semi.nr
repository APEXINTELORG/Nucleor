// EXPECT: TYP-026 fn `nothing` declared to return `i32` but body's last statement
//
// v0.6.1 typ-026 closure: `expr;` at the end of a non-void fn body
// is a tail expression with the semi consumed. Pre-v0.6.1 the parser
// silently ate the `;` and the lowerer treated the kind-25 as a
// value-producing tail anyway, so `fn nothing() -> i32 { 5; }` returned
// 5 to the caller despite the user signaling "discard this value" via
// the trailing `;`. v0.6.1 tracks `had_semi` on kind-25 nodes (parse_stmt
// at line 2443) and TYP-026 (type_check_stmts at the body-tail check)
// fires on `kind-25 + had_semi==1` the same way it already fires on
// kind-20 (let) / kind-21 (assign). The fix mirrors the existing check
// shape: same diag, same always-returning RHS escape hatch (match-with-
// all-arms-return, if-with-both-branches-return).

fn nothing() -> i32 {
    5;
}

fn main() {
    print_int(nothing());
}
