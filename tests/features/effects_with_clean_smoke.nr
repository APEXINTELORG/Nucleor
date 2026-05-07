// R05 v0842 RFC-0033 with-row subtyping ship — positive smoke.
// Pre-v0842 the with-row enforcement (`rt_header_has_effect`) used
// a whole-header word search for the literal effect token. Any
// occurrence of `Alloc` outside the actual `with [...]` row
// (parameter name, type name in a where-clause, etc.) was
// indistinguishable from a real `with [Alloc]` declaration, so a
// `with [no_alloc]` caller was wrongly flagged with EFF-003 when
// it called a fn whose header merely *mentioned* `Alloc` as a
// parameter identifier. v0842 reroutes the check through
// `extract_with_row` + `restricts_row_covers_effect`, so the
// match is scoped to the row contents only.
//
// `helper(Alloc: i64)` is declared with `with [no_alloc]` and
// genuinely allocates nothing; `main` (also `with [no_alloc]`)
// calls it. Pre-v0842 this trapped on a false-positive EFF-003;
// post-v0842 the build succeeds and the program exits 0.

fn helper(Alloc: i64) -> i64 with [no_alloc] {
    return Alloc + 1;
}

fn main() -> i64 with [no_alloc] {
    return helper(0) - 1;
}
