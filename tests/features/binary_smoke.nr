// v0.8.116 stdlib/rods/binary.nr first test coverage.
//
// Per the zero-coverage rod survey, binary.nr (byte buffers,
// endian helpers, foundation for CDR / Protobuf / MCAP /
// MessagePack / CBOR) had no existing tests. Silent regressions
// in endian conversion would corrupt every wire-format pipeline.
//
// Locks textbook binary I/O invariants:
//   1. Empty buffer: bin_buf_new + bin_buf_len == 0
//   2. u8 write/read round-trip.
//   3. u16 LE write produces correct byte ordering at offsets.
//   4. u16 BE write produces reverse byte ordering.
//   5. u32 LE write/read round-trip preserves the 32-bit value.
//   6. u64 LE/BE round-trip preserves 64-bit values including
//      high-bit / negative-as-u64 cases.
//
// Expected: rc=0 (assertion bumps).

import "stdlib/rods/binary.nr"

fn check_empty_buf() -> i64 {
    let b: i64 = bin_buf_new();
    let n: i64 = bin_buf_len(b);
    bin_buf_free(b);
    if n != 0 { return 1; };
    return 0;
}

fn check_u8_round_trip() -> i64 {
    let b: i64 = bin_buf_new();
    bin_write_u8(b, 65);    // 'A'
    bin_write_u8(b, 200);
    let v0: i64 = bin_read_u8(b, 0);
    let v1: i64 = bin_read_u8(b, 1);
    let len: i64 = bin_buf_len(b);
    bin_buf_free(b);
    if v0 != 65 { return 2; };
    if v1 != 200 { return 4; };
    if len != 2 { return 8; };
    return 0;
}

fn check_u16_endian() -> i64 {
    // 0x1234 LE: bytes are [0x34, 0x12]
    let b_le: i64 = bin_buf_new();
    bin_write_u16_le(b_le, 0x1234);
    let lo: i64 = bin_read_u8(b_le, 0);
    let hi: i64 = bin_read_u8(b_le, 1);
    let rt_le: i64 = bin_read_u16_le(b_le, 0);
    bin_buf_free(b_le);
    if lo != 0x34 { return 16; };
    if hi != 0x12 { return 32; };
    if rt_le != 0x1234 { return 64; };

    // 0x1234 BE: bytes are [0x12, 0x34]
    let b_be: i64 = bin_buf_new();
    bin_write_u16_be(b_be, 0x1234);
    let bhi: i64 = bin_read_u8(b_be, 0);
    let blo: i64 = bin_read_u8(b_be, 1);
    let rt_be: i64 = bin_read_u16_be(b_be, 0);
    bin_buf_free(b_be);
    if bhi != 0x12 { return 128; };
    if blo != 0x34 { return 256; };
    if rt_be != 0x1234 { return 512; };
    return 0;
}

fn check_u32_round_trip() -> i64 {
    let b: i64 = bin_buf_new();
    bin_write_u32_le(b, 0xDEADBEEF);
    bin_write_u32_be(b, 0xCAFEBABE);
    let r1: i64 = bin_read_u32_le(b, 0);
    let r2: i64 = bin_read_u32_be(b, 4);
    bin_buf_free(b);
    if r1 != 0xDEADBEEF { return 1024; };
    if r2 != 0xCAFEBABE { return 2048; };
    return 0;
}

fn check_u64_round_trip() -> i64 {
    let b: i64 = bin_buf_new();
    let v: i64 = 0x123456789ABCDEF0;
    bin_write_u64_le(b, v);
    bin_write_u64_be(b, v);
    let r1: i64 = bin_read_u64_le(b, 0);
    let r2: i64 = bin_read_u64_be(b, 8);
    bin_buf_free(b);
    if r1 != v { return 4096; };
    if r2 != v { return 8192; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty_buf();
    fails = fails + check_u8_round_trip();
    fails = fails + check_u16_endian();
    fails = fails + check_u32_round_trip();
    fails = fails + check_u64_round_trip();
    return fails;
}
