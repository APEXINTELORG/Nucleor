// =====================================================
// rods/compress — Lossless compression
// =====================================================
// Import: import "stdlib/rods/compress.nr"
// Provides: LZ77 compression and a free for the result handle.
// =====================================================

#cfile "../runtime/compress_rt.c"

extern fn nuc_compress_lz77(data: str, len: i64) -> i64;
extern fn nuc_compress_size(buf: i64) -> i64;
extern fn nuc_compress_free(buf: i64);

fn compress_lz77(data: str, len: i64) -> i64 { return nuc_compress_lz77(data, len); }
fn compress_size(buf: i64) -> i64 { return nuc_compress_size(buf); }
fn compress_free(buf: i64) { nuc_compress_free(buf); }
