// v0.8.136 stdlib/rods/compress.nr first test coverage +
// decompress_lz77 surface gap fix.
//
// Pre-v0.8.136: rod exposed compress_lz77 + compress_size + free
// only. The C runtime has always had `nuc_decompress_lz77` but
// the rod never surfaced it — adopters could compress but not
// decompress through the rod-only API. v0.8.136 adds the missing
// `decompress_lz77` surface.
//
// Locks two invariants:
//   1. Round-trip: decompress(compress(s)) == s for ASCII text
//      with repetition (the LZ77 sweet spot).
//   2. Compression ratio: highly redundant input compresses
//      smaller than its source. (Tiny inputs may not because of
//      LZ77 framing overhead, so we use a long repeated pattern.)
//
// Expected: rc=0.

import "stdlib/rods/compress.nr"

fn check_round_trip() -> i64 {
    let original: str = "the quick brown fox jumps over the lazy dog the quick brown fox";
    let n: i64 = str_len(original);
    let buf: i64 = compress_lz77(original, n);
    if buf == 0 { return 1; };
    let restored: str = decompress_lz77(buf);
    compress_free(buf);
    if str_eq(restored, original) != 1 { return 2; };
    return 0;
}

fn check_compression_ratio() -> i64 {
    // 256-byte highly redundant input: "ABABABAB..."
    let mut s: str = "";
    let mut i: i64 = 0;
    while i < 64 {
        s = str_concat(s, "ABAB");
        i = i + 1;
    };
    let n: i64 = str_len(s);
    if n != 256 { return 4; };
    let buf: i64 = compress_lz77(s, n);
    if buf == 0 { return 8; };
    let csz: i64 = compress_size(buf);
    let restored: str = decompress_lz77(buf);
    compress_free(buf);
    // Should be at least 2× smaller for this input
    if csz >= n / 2 { return 16; };
    if str_eq(restored, s) != 1 { return 32; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_round_trip();
    fails = fails + check_compression_ratio();
    return fails;
}
