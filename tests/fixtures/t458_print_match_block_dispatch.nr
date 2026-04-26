// t458_print_match_block_dispatch.nr -- v0.3.196 regression
// fixture.
//
// Sister fix to v0.3.192 (print(if-expr)). Match expression
// (kind 38) and block expression (kind 52) were also missing
// from the print() dispatch chain. `print(match x { ... })`
// and `print({ ... block ... })` SIGSEGV'd because the
// dispatch fell through to print_str.
//
// Same hazard class as v0.3.143/163-178/192 print() gaps.
//
// Fix (v0.3.196): kind 38 (match-expr) and kind 52 (block-expr)
// default to print_i64. Most adopter match/block exprs produce
// i64 (the default arm/expression-result type). Adopters with
// non-i64 results can use let-binding to assign first.

fn main() -> i64 {
    let x: i64 = 5;
    print(match x { 0 => 100, _ => 200 });          // pre-fix SIGSEGV (kind 38)
    print({ let a: i64 = 3; a + 2 });               // pre-fix SIGSEGV (kind 52)
    print(match x { 5 => 555, _ => 0 });            // exact match
    return 42;
}
