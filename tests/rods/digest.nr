// rods/digest — verify hash + b64 + uuid rod wrapper
import "stdlib/rods/digest.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Canonical SHA-256
    let abc: str = digest_sha256("abc");
    if str_eq(abc, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") != 1 {
        fail = fail + 1;
        print("FAIL sha256 abc");
    };

    // Base64 round-trip
    let enc: str = digest_b64_encode("Nucleor");
    let dec: str = digest_b64_decode(enc);
    if str_eq(dec, "Nucleor") != 1 { fail = fail + 1; print("FAIL b64 round-trip"); };

    // UUID shape
    let u: str = digest_uuid();
    if str_len(u) != 36 { fail = fail + 1; print("FAIL uuid length"); };

    // CRC32 canonical
    if digest_crc32("123456789", 9) != 3421780262 { fail = fail + 1; print("FAIL crc32"); };

    if fail == 0 { print("OK digest"); return 0; };
    return 1;
}
