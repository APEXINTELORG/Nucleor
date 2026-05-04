// =====================================================
// rods/bm25 — BM25 search index
// =====================================================
// Import: import "stdlib/rods/bm25.nr"
// =====================================================

#cfile "../runtime/bm25_rt.c"

extern fn nuc_bm25_new() -> i64;
extern fn nuc_bm25_add_doc(idx: i64, doc_id: i64, text: str);
extern fn nuc_bm25_search(idx: i64, query: str, top_k: i64) -> i64;
extern fn nuc_bm25_n_docs(idx: i64) -> i64;
extern fn nuc_bm25_doc_count(idx: i64) -> i64;
extern fn nuc_bm25_n_terms(idx: i64) -> i64;
extern fn nuc_bm25_free(idx: i64);

fn bm25_new() -> i64 { return nuc_bm25_new(); }
fn bm25_add(idx: i64, doc_id: i64, text: str) { nuc_bm25_add_doc(idx, doc_id, text); }
fn bm25_search(idx: i64, query: str, top_k: i64) -> i64 { return nuc_bm25_search(idx, query, top_k); }
// bm25_n_docs returns max_doc_id + 1 (used internally as the
// scoring-loop bound). For sparse / non-sequential ids this is
// usually NOT the actual number of documents added.
fn bm25_n_docs(idx: i64) -> i64 { return nuc_bm25_n_docs(idx); }
// v0.8.108: distinct-doc count. Returns the number of unique
// add_doc calls (each unique doc_id counted once). Use this
// when you want "how many documents have I added" rather than
// the max-id-bounded n_docs. For sequential 0..N-1 doc_ids
// the two values are equal.
fn bm25_doc_count(idx: i64) -> i64 { return nuc_bm25_doc_count(idx); }
fn bm25_n_terms(idx: i64) -> i64 { return nuc_bm25_n_terms(idx); }
fn bm25_free(idx: i64) { nuc_bm25_free(idx); }
