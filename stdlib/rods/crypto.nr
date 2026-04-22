// =====================================================
// rods/crypto — Cryptographic primitives
// =====================================================
// Import: import "stdlib/rods/crypto.nr"
// Provides: cryptographically-secure random bytes. The runtime also
//   exposes sha256 via the core builtin set (no extern needed).
// =====================================================

#cfile "../runtime/crypto_rt.c"
#link "advapi32"

extern fn nuc_random_bytes(buf: i64, len: i64);

// Fill a Vec<i32> handle with `len` cryptographically random bytes.
fn crypto_random_bytes(buf: i64, len: i64) { nuc_random_bytes(buf, len); }
