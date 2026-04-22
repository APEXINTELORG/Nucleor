// rods/binary — verify byte buffer + endian + msgpack rod wrapper
import "stdlib/rods/binary.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    let buf: i64 = bin_buf_new();

    bin_write_u32_be(buf, 0xDEADBEEF);
    if bin_read_u32_be(buf, 0) != 0xDEADBEEF { fail = fail + 1; print("FAIL u32 BE"); };

    let buf2: i64 = bin_buf_new();
    bin_write_u64_le(buf2, 0x0102030405060708);
    if bin_read_u64_le(buf2, 0) != 0x0102030405060708 { fail = fail + 1; print("FAIL u64 LE"); };

    let mp: i64 = bin_buf_new();
    mp_write_uint(mp, 200);
    if bin_buf_byte(mp, 0) != 0xCC { fail = fail + 1; print("FAIL mp uint8 marker"); };

    bin_buf_free(buf);
    bin_buf_free(buf2);
    bin_buf_free(mp);

    if fail == 0 { print("OK binary"); return 0; };
    return 1;
}
