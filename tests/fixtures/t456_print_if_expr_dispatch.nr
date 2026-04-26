// t456_print_if_expr_dispatch.nr -- v0.3.192 regression fixture.
//
// `print(if cond { x } else { y })` SIGSEGV'd because the
// print() dispatch chain (v0.3.143/163-178) had branches for
// kinds 1, 3, 4, 5, 6, 7, 8, 9, 10, 12, 23 wait no -- 23 was
// missing. The dispatch fell through to print_str which
// dereferenced the i64 if-result as a string pointer.
//
// Same hazard class as the prior print() dispatch gaps.
//
// Fix (v0.3.192): kind 23 (if-expr) defaults to print_i64.
// Most adopter if-exprs produce i64 (the default arm-result
// type for arithmetic / int branches). Adopters with non-i64
// if-exprs can use let-binding to assign first (which gets
// proper type inference via __type_<name>).

fn main() -> i64 {
    let n: i64 = 7;
    print(if n > 5 { 100 } else { -1 });   // pre-fix SIGSEGV
    print(if n > 5 { 100 } else { 200 });
    print(if n < 0 { 1 } else { 0 });
    return 42;
}
