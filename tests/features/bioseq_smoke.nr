// v0.8.117 stdlib/rods/bioseq.nr first test coverage.
//
// Per the zero-coverage rod survey, bioseq.nr (DNA/RNA/protein
// — GC content, alignment, Hamming, k-mer count, ORF finder)
// had no existing tests. Silent regressions in any path would
// invalidate every adopter bioinformatics pipeline.
//
// Locks textbook bioinformatics invariants:
//   1. GC content of empty sequence is 0.
//   2. GC content of all-A is 0; all-G is 1.0; "AGCT" balanced is 0.5.
//   3. Hamming of identical sequences is 0.
//   4. Hamming of single-mismatch is 1; multi-mismatch counts correctly.
//   5. k-mer count: |seq| - k + 1 for k <= |seq|; 0 for k > |seq|.
//
// GC content is returned as f64-bits.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/bioseq.nr"

fn close(a: i64, b: i64) -> i64 {
    let af: f64 = f64_from_bits(a);
    let bf: f64 = f64_from_bits(b);
    let diff: f64 = af - bf;
    let abs_diff: f64 = if diff < 0.0 { 0.0 - diff } else { diff };
    if abs_diff < 1e-6 { return 1; };
    return 0;
}

fn check_gc_empty() -> i64 {
    let gc: i64 = bio_gc("");
    if close(gc, f64_to_bits(0.0)) != 1 { return 1; };
    return 0;
}

fn check_gc_known_values() -> i64 {
    // All A → GC = 0
    if close(bio_gc("AAAA"), f64_to_bits(0.0)) != 1 { return 2; };
    // All G → GC = 1
    if close(bio_gc("GGGG"), f64_to_bits(1.0)) != 1 { return 4; };
    // "AGCT" → GC = 2/4 = 0.5
    if close(bio_gc("AGCT"), f64_to_bits(0.5)) != 1 { return 8; };
    // Lower-case + mixed
    if close(bio_gc("agct"), f64_to_bits(0.5)) != 1 { return 16; };
    return 0;
}

fn check_hamming() -> i64 {
    if bio_hamming("ACGT", "ACGT") != 0 { return 32; };
    if bio_hamming("ACGT", "ACGA") != 1 { return 64; };
    if bio_hamming("AAAA", "TTTT") != 4 { return 128; };
    return 0;
}

fn check_kmer_count() -> i64 {
    // |seq|=10, k=3 → 10 - 3 + 1 = 8
    if bio_kmer_count("ACGTACGTAC", 3) != 8 { return 256; };
    // k=1: every position
    if bio_kmer_count("ACGT", 1) != 4 { return 512; };
    // k > |seq|: 0
    if bio_kmer_count("ACG", 5) != 0 { return 1024; };
    // k == |seq|: 1
    if bio_kmer_count("ACGT", 4) != 1 { return 2048; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_gc_empty();
    fails = fails + check_gc_known_values();
    fails = fails + check_hamming();
    fails = fails + check_kmer_count();
    return fails;
}
