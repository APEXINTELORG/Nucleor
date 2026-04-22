// binary_io.nr — byte buffer + endian helpers + MessagePack subset
// Decisions §B5: required for binary serialization (CDR, Protobuf,
// MCAP, MessagePack, CBOR, network protocols).

fn main() -> i32 {
    let mut fail: i64 = 0;

    let buf: i64 = vec_u8_new();

    // u8
    buf_write_u8(buf, 0x42);
    if buf_read_u8(buf, 0) != 0x42 { fail = fail + 1; print("FAIL u8 round-trip\n"); };

    // u16 LE / BE
    buf_write_u16_le(buf, 0xCAFE);  // bytes: 0xFE 0xCA
    if vec_u8_get(buf, 1) != 0xFE { fail = fail + 1; print("FAIL u16 LE byte 0\n"); };
    if vec_u8_get(buf, 2) != 0xCA { fail = fail + 1; print("FAIL u16 LE byte 1\n"); };
    if buf_read_u16_le(buf, 1) != 0xCAFE { fail = fail + 1; print("FAIL u16 LE round-trip\n"); };

    let buf2: i64 = vec_u8_new();
    buf_write_u16_be(buf2, 0xCAFE);
    if vec_u8_get(buf2, 0) != 0xCA { fail = fail + 1; print("FAIL u16 BE byte 0\n"); };
    if vec_u8_get(buf2, 1) != 0xFE { fail = fail + 1; print("FAIL u16 BE byte 1\n"); };
    if buf_read_u16_be(buf2, 0) != 0xCAFE { fail = fail + 1; print("FAIL u16 BE round-trip\n"); };

    // u32 LE / BE round-trip
    let buf3: i64 = vec_u8_new();
    buf_write_u32_le(buf3, 0xDEADBEEF);
    if buf_read_u32_le(buf3, 0) != 0xDEADBEEF { fail = fail + 1; print("FAIL u32 LE\n"); };

    let buf4: i64 = vec_u8_new();
    buf_write_u32_be(buf4, 0xDEADBEEF);
    if buf_read_u32_be(buf4, 0) != 0xDEADBEEF { fail = fail + 1; print("FAIL u32 BE\n"); };

    // u64 round-trip
    let buf5: i64 = vec_u8_new();
    buf_write_u64_be(buf5, 0x0102030405060708);
    if buf_read_u64_be(buf5, 0) != 0x0102030405060708 { fail = fail + 1; print("FAIL u64 BE\n"); };

    // MessagePack: positive fixint
    let mp1: i64 = vec_u8_new();
    msgpack_write_uint(mp1, 5);
    if vec_u8_get(mp1, 0) != 5 { fail = fail + 1; print("FAIL msgpack fixint\n"); };

    // MessagePack: uint8 marker (>=128 < 256)
    let mp2: i64 = vec_u8_new();
    msgpack_write_uint(mp2, 200);
    if vec_u8_get(mp2, 0) != 0xCC { fail = fail + 1; print("FAIL msgpack uint8 marker\n"); };
    if vec_u8_get(mp2, 1) != 200 { fail = fail + 1; print("FAIL msgpack uint8 value\n"); };

    // MessagePack: nil + bool
    let mp3: i64 = vec_u8_new();
    msgpack_write_nil(mp3);
    msgpack_write_bool(mp3, 1);
    msgpack_write_bool(mp3, 0);
    if vec_u8_get(mp3, 0) != 0xC0 { fail = fail + 1; print("FAIL msgpack nil\n"); };
    if vec_u8_get(mp3, 1) != 0xC3 { fail = fail + 1; print("FAIL msgpack true\n"); };
    if vec_u8_get(mp3, 2) != 0xC2 { fail = fail + 1; print("FAIL msgpack false\n"); };

    // MessagePack: short str (fixstr)
    let mp4: i64 = vec_u8_new();
    msgpack_write_str(mp4, "hi");
    if vec_u8_get(mp4, 0) != 0xA2 { fail = fail + 1; print("FAIL msgpack fixstr marker\n"); };
    if vec_u8_get(mp4, 1) != 104 { fail = fail + 1; print("FAIL msgpack fixstr 'h'\n"); };
    if vec_u8_get(mp4, 2) != 105 { fail = fail + 1; print("FAIL msgpack fixstr 'i'\n"); };

    if fail == 0 { print("OK binary_io\n"); return 0; };
    return 1;
}
