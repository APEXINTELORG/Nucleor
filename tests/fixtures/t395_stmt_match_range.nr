// t395_stmt_match_range.nr — v0.3.118 regression fixture.
//
// Pins range patterns (`0..=9 => …`) in stmt-position match.
// Pre-v0.3.118, two of the four kind-38 (match) lowering paths
// existed: lower_expr (expression-position match) handled `__range`,
// but lower_stmt (statement-position match) did NOT. Range arms
// in stmt-position fell through to the default enum-tag-decode
// path, which treated the i64 scrutinee as a Vec pointer
// (`vec_get(inttoptr i64_value, 0)`) and SEGFAULTED at runtime.
//
// HIGH-blast silent miscompute → segfault for any program using
// range patterns in the statement form (return inside arm body,
// rather than match-as-expression with arm-body values).
//
// Implementation: mirror the v0.3.118 `__range` arm from the
// lower_expr kind-38 handler into the lower_stmt kind-38 handler
// (line 11364). Same load + lo<=mv && mv<=hi compare + br_cond
// pattern; arm body lowered via lower_stmts (not the
// expr-branch helper) since stmt-form bodies are full statement
// lists. Also wire `__range_bad` to a never-match br for the
// MATCH-007 paired-pass diagnostic case.
//
// Returns 2 from `match 50 { 0..=9 => 1, 10..=99 => 2, _ => 3 }`,
// proving multi-arm range patterns dispatch correctly without
// the prior segfault.

fn classify(x: i64) -> i64 {
    match x {
        0..=9 => return 1,
        10..=99 => return 2,
        _ => return 3,
    };
    return 0;
}

fn main() -> i64 {
    return classify(50);
}
