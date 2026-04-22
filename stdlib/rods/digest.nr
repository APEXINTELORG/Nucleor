// =====================================================
// rods/digest — Hash + Base64 + UUID helpers
// =====================================================
// Import: import "stdlib/rods/digest.nr"
//
// Wraps the v0.1.42 hash/checksum/encoding/id builtins.
// =====================================================

// ---- CRC32 (IEEE 802.3 polynomial) ----
fn digest_crc32(data: str, len: i64) -> i64 { return crc32(data, len); }
fn digest_crc32_continue(prev: i64, data: str, len: i64) -> i64 {
    return crc32_update(prev, data, len);
}

// ---- SHA-256 ----
fn digest_sha256(data: str) -> str { return sha256_hex(data); }

// ---- Base64 (RFC 4648) ----
fn digest_b64_encode(data: str) -> str { return base64_encode(data); }
fn digest_b64_decode(b64: str) -> str { return base64_decode(b64); }

// ---- UUID (RFC 4122 v4 random) ----
fn digest_uuid() -> str { return uuid_v4(); }
