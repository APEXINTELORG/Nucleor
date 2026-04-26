// t441_handle_helper_int_literal_diag.nr -- v0.3.174 regression
// fixture (positive: build succeeds with WARNING).
//
// Pre-v0.3.174, the literal-only WARNING covered vec_*,
// hashmap_*/etc, and tok_* helpers. Several remaining
// adopter-facing helper families still silently SIGSEGV'd on
// int-literal-as-handle:
//   - str_arena_* / arena_*
//   - nuc_graph_*, nuc_bm25_*, nuc_hnsw_*, nuc_emb_*,
//     nuc_sym_*, nuc_stat_* (NS_Sage / search subsystems)
//
// Fix (v0.3.174): extend the prefix-match WARNING to cover
// these families. Excludes constructors (str_arena_new,
// arena_new, nuc_graph_new, etc.). Variables remain unflagged.
//
// This fixture pins the well-typed case (real arena usage)
// to guard against regressions in legitimate use.

fn main() -> i64 {
    let a: Arena = arena_new(4096);
    let p1 = arena_alloc(a, 64);
    if p1 == 0 { return 1; };
    arena_destroy(a);
    return 42;
}
