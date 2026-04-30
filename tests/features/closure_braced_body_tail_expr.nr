// Regression-guard fixture for v0.4.204 closure-braced-body fix.
//
// Pre-fix: `|y| { y + 7 }` returned 0 (silent miscompute) while
// `|y| y + 7` returned 17. The bare-expr form was correctly wrapped
// as kind-22 (return-with-value) by parse_primary at line 1344, but
// the braced form passed body_list through parse_stmts unchanged —
// every expr-stmt is kind-25 (discard) regardless of whether a `;`
// followed. The closure handler at line 16168 then called
// lower_stmts which discarded the kind-25 last stmt, fell through
// to "no terminator → ret 0", and adopters saw the wrong value
// with no diagnostic.
//
// Fix mirrors lower_fn's tail-expression detection (line 17252):
// if the final body item is kind 25/23/38, lower all preceding stmts
// via lower_stmt, then lower the last item's payload via lower_expr
// and emit `ret rv`. Six shapes locked in below — any future ship
// that re-breaks any of them halts the verify gate immediately.

fn main() -> i32 {
    // 1. expression body (always worked; lock in)
    let f_expr = |y: i32| y + 7;
    if f_expr(10) != 17 { print("FAIL expr body"); return 1; };

    // 2. braced single tail expr (was the bug)
    let f_tail = |y: i32| { y + 7 };
    if f_tail(10) != 17 { print("FAIL braced single tail"); return 1; };

    // 3. multi-stmt body with tail expr
    let f_multi = |y: i32| {
        let z: i32 = 3;
        let w: i32 = 4;
        y + z + w
    };
    if f_multi(10) != 17 { print("FAIL multi-stmt tail"); return 1; };

    // 4. side-effect-only body (closure returns 0; runs print)
    let f_side = |y: i32| { print_int(y); };
    f_side(42);

    // 5. if-as-tail-expression
    let f_if = |y: i32| { if y > 0 { 1 } else { 0 - 1 } };
    if f_if(5) != 1 { print("FAIL if tail (positive)"); return 1; };
    if f_if(0 - 5) != -1 { print("FAIL if tail (negative)"); return 1; };

    // 6. mixed: stmt-with-semi then tail-without-semi
    let f_mix = |y: i32| {
        let a: i32 = y * 2;
        let b: i32 = a + 1;
        b
    };
    if f_mix(10) != 21 { print("FAIL mixed stmt+tail"); return 1; };

    print("OK closure_braced_body_tail_expr");
    0
}
