// v0.8.107 stdlib/rods/bm25.nr first test coverage.
//
// Per the zero-coverage rod survey, bm25.nr (BM25 search index)
// had no existing tests. Silent regressions in tokenization or
// scoring would surface as wrong-rank results — extremely hard
// to detect by adopters without a reference set.
//
// Locks BM25 invariants:
//   1. Empty index: n_docs == 0, search returns no results.
//   2. After adding docs with sequential doc_ids 0..N-1,
//      n_docs == N. NOTE: bm25_n_docs returns "max doc_id +
//      1", treating it as an array bound; adopters who pass
//      sparse / non-sequential doc_ids get the highest+1.
//      Documented here for fixture stability.
//   3. Searching for an exact term in one doc returns that
//      doc as a top result.
//   4. Searching for a term in NO docs returns 0 results.
//   5. The most-relevant doc (term appears, others lack term)
//      ranks above docs that don't contain the term.
//
// Search results layout: Vec<i64> of interleaved
// [doc_id, score_bits, doc_id, score_bits, ...] per the
// BM25Index runtime.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/bm25.nr"

fn check_empty() -> i64 {
    let idx: i64 = bm25_new();
    if bm25_n_docs(idx) != 0 { bm25_free(idx); return 1; };
    let r: i64 = bm25_search(idx, "anything", 5);
    // r is a Vec<i64>; len should be 0.
    if vec_len(r) != 0 { bm25_free(idx); return 2; };
    bm25_free(idx);
    return 0;
}

fn check_add_count() -> i64 {
    let idx: i64 = bm25_new();
    bm25_add(idx, 0, "alpha bravo charlie");
    bm25_add(idx, 1, "delta echo foxtrot");
    bm25_add(idx, 2, "golf hotel india");
    let n: i64 = bm25_n_docs(idx);
    bm25_free(idx);
    if n != 3 { return 4; };
    return 0;
}

fn check_search_exact_term() -> i64 {
    let idx: i64 = bm25_new();
    bm25_add(idx, 0, "alpha bravo charlie");
    bm25_add(idx, 1, "delta echo foxtrot");
    bm25_add(idx, 2, "golf hotel india");
    let r: i64 = bm25_search(idx, "delta", 5);
    // r format: [doc_id, score, doc_id, score, ...]
    // Doc 1 contains "delta"; expect at least one result with doc_id=1.
    let mut found: i64 = 0;
    let mut i: i64 = 0;
    while i < vec_len(r) {
        if vec_get(r, i) == 1 { found = 1; };
        i = i + 2;
    };
    bm25_free(idx);
    if found != 1 { return 8; };
    return 0;
}

fn check_search_no_match() -> i64 {
    let idx: i64 = bm25_new();
    bm25_add(idx, 0, "alpha bravo charlie");
    bm25_add(idx, 1, "delta echo foxtrot");
    let r: i64 = bm25_search(idx, "zzz_nonexistent", 5);
    let n: i64 = vec_len(r);
    bm25_free(idx);
    if n != 0 { return 16; };
    return 0;
}

fn check_search_top_returns_relevant_doc() -> i64 {
    let idx: i64 = bm25_new();
    // Three docs. Only one contains "rare".
    bm25_add(idx, 0, "common common common");
    bm25_add(idx, 1, "common rare common");
    bm25_add(idx, 2, "common common common");
    let r: i64 = bm25_search(idx, "rare", 3);
    bm25_free(idx);
    // Top result must be doc 1 (the one with the term).
    if vec_len(r) < 2 { return 32; };
    if vec_get(r, 0) != 1 { return 64; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_add_count();
    fails = fails + check_search_exact_term();
    fails = fails + check_search_no_match();
    fails = fails + check_search_top_returns_relevant_doc();
    return fails;
}
