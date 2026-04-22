// rods/bioseq — Bioinformatics sequence ops (DNA/RNA/protein)
#cfile "../runtime/bioseq_rt.c"

extern fn nuc_bio_gc_content(seq: str) -> i64;
extern fn nuc_bio_align_global(seq1: str, seq2: str, match: i64, mismatch: i64, gap: i64) -> i64;
extern fn nuc_bio_align_score(h: i64) -> i64;
extern fn nuc_bio_hamming(seq1: str, seq2: str) -> i64;
extern fn nuc_bio_kmer_count(seq: str, k: i64) -> i64;
extern fn nuc_bio_find_orfs(seq: str, min_len: i64) -> i64;

fn bio_gc(seq: str) -> i64 { return nuc_bio_gc_content(seq); }
fn bio_align(s1: str, s2: str, m: i64, mm: i64, gap: i64) -> i64 { return nuc_bio_align_global(s1, s2, m, mm, gap); }
fn bio_align_score(h: i64) -> i64 { return nuc_bio_align_score(h); }
fn bio_hamming(s1: str, s2: str) -> i64 { return nuc_bio_hamming(s1, s2); }
fn bio_kmer_count(seq: str, k: i64) -> i64 { return nuc_bio_kmer_count(seq, k); }
fn bio_find_orfs(seq: str, min_len: i64) -> i64 { return nuc_bio_find_orfs(seq, min_len); }
