// =====================================================
// rods/binary — Byte buffers, endian helpers, MessagePack subset
// =====================================================
// Import: import "stdlib/rods/binary.nr"
//
// Wraps the v0.1.41 binary-IO builtins with descriptive names.
// Foundation for CDR (ROS 2 DDS), Protobuf wire format, MCAP
// (Foxglove logging), MessagePack, CBOR, and arbitrary network
// protocols.
//
// Backed by Vec<u8> typed-storage (1 byte per element honest
// storage from v0.1.22).
// =====================================================

// ---- Byte buffer construction (delegate to vec_u8) ----
fn bin_buf_new() -> i64 { return vec_u8_new(); }
fn bin_buf_with_capacity(n: i64) -> i64 { return vec_u8_with_capacity(n); }
fn bin_buf_len(h: i64) -> i64 { return vec_u8_len(h); }
fn bin_buf_byte(h: i64, i: i64) -> i64 { return vec_u8_get(h, i); }
fn bin_buf_free(h: i64) -> i64 { return vec_u8_free(h); }

// ---- Endian writes ----
fn bin_write_u8(h: i64, v: i64) -> i64 { return buf_write_u8(h, v); }
fn bin_write_u16_le(h: i64, v: i64) -> i64 { return buf_write_u16_le(h, v); }
fn bin_write_u16_be(h: i64, v: i64) -> i64 { return buf_write_u16_be(h, v); }
fn bin_write_u32_le(h: i64, v: i64) -> i64 { return buf_write_u32_le(h, v); }
fn bin_write_u32_be(h: i64, v: i64) -> i64 { return buf_write_u32_be(h, v); }
fn bin_write_u64_le(h: i64, v: i64) -> i64 { return buf_write_u64_le(h, v); }
fn bin_write_u64_be(h: i64, v: i64) -> i64 { return buf_write_u64_be(h, v); }

// ---- Endian reads ----
fn bin_read_u8(h: i64, off: i64) -> i64 { return buf_read_u8(h, off); }
fn bin_read_u16_le(h: i64, off: i64) -> i64 { return buf_read_u16_le(h, off); }
fn bin_read_u16_be(h: i64, off: i64) -> i64 { return buf_read_u16_be(h, off); }
fn bin_read_u32_le(h: i64, off: i64) -> i64 { return buf_read_u32_le(h, off); }
fn bin_read_u32_be(h: i64, off: i64) -> i64 { return buf_read_u32_be(h, off); }
fn bin_read_u64_le(h: i64, off: i64) -> i64 { return buf_read_u64_le(h, off); }
fn bin_read_u64_be(h: i64, off: i64) -> i64 { return buf_read_u64_be(h, off); }

// ---- MessagePack subset ----
fn mp_write_nil(h: i64) -> i64 { return msgpack_write_nil(h); }
fn mp_write_bool(h: i64, b: i64) -> i64 { return msgpack_write_bool(h, b); }
fn mp_write_uint(h: i64, v: i64) -> i64 { return msgpack_write_uint(h, v); }
fn mp_write_str(h: i64, s: str) -> i64 { return msgpack_write_str(h, s); }
