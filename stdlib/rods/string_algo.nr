// rods/string_algo — Advanced string algorithms (KMP, Levenshtein, Trie)
#cfile "../runtime/string_algo_rt.c"

extern fn nuc_str_kmp_search(text: str, pattern: str) -> i64;
extern fn nuc_str_levenshtein(a: str, b: str) -> i64;
extern fn nuc_str_trie_new() -> i64;
extern fn nuc_str_trie_insert(t: i64, word: str);
extern fn nuc_str_trie_contains(t: i64, word: str) -> i64;
extern fn nuc_str_trie_starts_with(t: i64, prefix: str) -> i64;
extern fn nuc_str_trie_count_prefix(t: i64, prefix: str) -> i64;
extern fn nuc_str_trie_free(t: i64);

fn str_kmp(text: str, pat: str) -> i64 { return nuc_str_kmp_search(text, pat); }
fn str_levenshtein(a: str, b: str) -> i64 { return nuc_str_levenshtein(a, b); }
fn trie_new() -> i64 { return nuc_str_trie_new(); }
fn trie_insert(t: i64, w: str) { nuc_str_trie_insert(t, w); }
fn trie_contains(t: i64, w: str) -> i64 { return nuc_str_trie_contains(t, w); }
fn trie_starts_with(t: i64, p: str) -> i64 { return nuc_str_trie_starts_with(t, p); }
fn trie_count_prefix(t: i64, p: str) -> i64 { return nuc_str_trie_count_prefix(t, p); }
fn trie_free(t: i64) { nuc_str_trie_free(t); }
