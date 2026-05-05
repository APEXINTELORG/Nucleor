// v0.8.130 stdlib/rods/digest.nr first test coverage.
//
// Hash + Base64 + UUID helpers. SHA-256 has known reference
// vectors from FIPS 180-4. Base64 round-trip mirrors v0.8.94's
// base64_round_trip_smoke (which tests the rod-internal version);
// here we test the digest rod's wrapper around the runtime
// builtin.
//
// Locks textbook hash/encoding invariants:
//   1. SHA-256 of empty string = standard FIPS 180-4 vector.
//   2. SHA-256 of "abc" = standard FIPS 180-4 vector.
//   3. Base64 RFC 4648 reference vectors round-trip.
//   4. CRC32 of empty data is 0.
//   5. CRC32 of known string matches IEEE 802.3 polynomial.
//   6. UUID v4 is non-empty and 36 chars (8-4-4-4-12 + 4 hyphens).
//
// Expected: rc=0.

import "stdlib/rods/digest.nr"

fn check_sha256_known_vectors() -> i64 {
    // FIPS 180-4 reference: SHA-256("") =
    //   e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    if str_eq(digest_sha256(""),
              "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") != 1 {
        return 1;
    };
    // FIPS 180-4 reference: SHA-256("abc") =
    //   ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
    if str_eq(digest_sha256("abc"),
              "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") != 1 {
        return 2;
    };
    return 0;
}

fn check_base64_round_trip() -> i64 {
    // RFC 4648 §10 reference: "foobar" → "Zm9vYmFy"
    if str_eq(digest_b64_encode("foobar"), "Zm9vYmFy") != 1 { return 4; };
    if str_eq(digest_b64_decode("Zm9vYmFy"), "foobar") != 1 { return 8; };
    // Empty
    if str_eq(digest_b64_encode(""), "") != 1 { return 16; };
    return 0;
}

fn check_crc32() -> i64 {
    // CRC32(empty) = 0
    if digest_crc32("", 0) != 0 { return 32; };
    // CRC32("123456789") = 0xCBF43926 (well-known IEEE 802.3 test vector)
    let r: i64 = digest_crc32("123456789", 9);
    if r != 0xCBF43926 { return 64; };
    return 0;
}

fn check_uuid_v4() -> i64 {
    let u: str = digest_uuid();
    if str_len(u) != 36 { return 128; };
    // UUID format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (4 hyphens)
    let mut hyphens: i64 = 0;
    let mut i: i64 = 0;
    while i < 36 {
        if str_char_at(u, i) == 45 { hyphens = hyphens + 1; };
        i = i + 1;
    };
    if hyphens != 4 { return 256; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_sha256_known_vectors();
    fails = fails + check_base64_round_trip();
    fails = fails + check_crc32();
    fails = fails + check_uuid_v4();
    return fails;
}
