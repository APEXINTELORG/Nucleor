// =====================================================
// rods/compress — Lossless compression
// =====================================================
// Import: import "stdlib/rods/compress.nr"
// Provides: LZ77 compression and a free for the result handle.
// =====================================================

#cfile "../runtime/compress_rt.c"

extern fn nuc_compress_lz77(data: str, len: i64) -> i64;
extern fn nuc_decompress_lz77(buf: i64) -> str;
extern fn nuc_compress_size(buf: i64) -> i64;
extern fn nuc_compress_free(buf: i64);

fn compress_lz77(data: str, len: i64) -> i64 { return nuc_compress_lz77(data, len); }
// v0.8.136: surface for the existing nuc_decompress_lz77 C symbol.
// The C runtime always shipped this; the rod simply never exposed it,
// so adopters could compress but not decompress through the rod-only
// API (had to drop to extern fn). Round-trip is the canonical lock for
// any compression library — see tests/features/compress_smoke.nr.
fn decompress_lz77(buf: i64) -> str { return nuc_decompress_lz77(buf); }
fn compress_size(buf: i64) -> i64 { return nuc_compress_size(buf); }
fn compress_free(buf: i64) { nuc_compress_free(buf); }
