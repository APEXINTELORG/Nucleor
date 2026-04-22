// hash_b64_uuid.nr — CRC32 + SHA256 + Base64 + UUID
// Foundation for RFC-0019 package checksums + Robotics-RFC §5.4
// observability + general wire-format integrity.

fn main() -> i32 {
    let mut fail: i64 = 0;

    // CRC32 of empty string per IEEE 802.3 = 0
    if crc32("", 0) != 0 { fail = fail + 1; print("FAIL CRC32 empty\n"); };

    // CRC32 of "123456789" = 0xCBF43926 (canonical test vector)
    if crc32("123456789", 9) != 3421780262 { fail = fail + 1; print("FAIL CRC32 123456789\n"); };

    // SHA-256 of empty string (well-known)
    let empty: str = sha256_hex("");
    if str_eq(empty, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") != 1 {
        fail = fail + 1;
        print("FAIL SHA256 empty\n");
    };

    // SHA-256 of "abc" (well-known)
    let abc: str = sha256_hex("abc");
    if str_eq(abc, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") != 1 {
        fail = fail + 1;
        print("FAIL SHA256 abc\n");
    };

    // Base64 round-trip
    let enc: str = base64_encode("Hello, world!");
    if str_eq(enc, "SGVsbG8sIHdvcmxkIQ==") != 1 { fail = fail + 1; print("FAIL b64 encode\n"); };

    let dec: str = base64_decode("SGVsbG8sIHdvcmxkIQ==");
    if str_eq(dec, "Hello, world!") != 1 { fail = fail + 1; print("FAIL b64 decode\n"); };

    // UUID v4 — verify shape: 36 chars, hyphens at 8/13/18/23
    let uu: str = uuid_v4();
    if str_len(uu) != 36 { fail = fail + 1; print("FAIL uuid length\n"); };
    if str_char_at(uu, 8) != 45 { fail = fail + 1; print("FAIL uuid hyphen 1\n"); };
    if str_char_at(uu, 13) != 45 { fail = fail + 1; print("FAIL uuid hyphen 2\n"); };
    if str_char_at(uu, 18) != 45 { fail = fail + 1; print("FAIL uuid hyphen 3\n"); };
    if str_char_at(uu, 23) != 45 { fail = fail + 1; print("FAIL uuid hyphen 4\n"); };
    // Char at 14 is version (must be '4')
    if str_char_at(uu, 14) != 52 { fail = fail + 1; print("FAIL uuid version\n"); };

    // Two UUIDs differ
    let uu2: str = uuid_v4();
    if str_eq(uu, uu2) == 1 { fail = fail + 1; print("FAIL uuid uniqueness\n"); };

    if fail == 0 { print("OK hash_b64_uuid\n"); return 0; };
    return 1;
}
