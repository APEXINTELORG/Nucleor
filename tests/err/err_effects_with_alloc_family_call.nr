// EXPECT: error[EFF-003]
// R05 v0842 RFC-0033 with-row subtyping ship — sub-effect family
// negative. A `with [no_alloc]` caller calls a callee declared
// with the dotted sub-effect `with [Alloc.heap]`. The shared
// row-overlap helper `restricts_row_covers_effect` (now wired
// into `rt_header_has_effect` via `extract_with_row`) treats the
// callee's `Alloc.heap` token as covered by the family root
// `Alloc`, so the existing `enforce_no_alloc` flow continues to
// fire EFF-003 — exactly the same observable diagnostic the
// pre-v0842 whole-header word search produced for this shape,
// now landed on a row-token-aware path. Sister to
// `err_effects_with_alloc_call.nr` (the original `with [Alloc]`
// flat-row negative).

fn alloc_heap() -> i64 with [Alloc.heap] {
    return 1;
}

fn main() -> i64 with [no_alloc] {
    return alloc_heap();
}
