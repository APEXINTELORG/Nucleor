// v0.8.159 stdlib/rods/base64.nr first test coverage.
//
// b64_encode and b64_decode are also re-exported via digest.nr
// (covered at v0.8.130 by digest_smoke.nr) but the standalone
// base64.nr rod has no dedicated coverage. Pre-v0.8.159: gap.
//
// Locks four RFC 4648 invariants:
//   1. Empty string round-trip: encode("") == ""; decode("") == "".
//   2. RFC 4648 §10 vector: encode("foobar") == "Zm9vYmFy".
//   3. RFC 4648 §10 short vector: encode("f") == "Zg==" (pad).
//   4. Round-trip preserves data on a 12-char ASCII payload.
//
// Expected: rc=0.

import "stdlib/rods/base64.nr"

fn check_empty() -> i64 {
    if str_eq(b64_encode(""), "") != 1 { return 1; };
    if str_eq(b64_decode(""), "") != 1 { return 2; };
    return 0;
}

fn check_rfc4648_foobar() -> i64 {
    let enc: str = b64_encode("foobar");
    if str_eq(enc, "Zm9vYmFy") != 1 { return 4; };
    return 0;
}

fn check_rfc4648_short_padded() -> i64 {
    let enc: str = b64_encode("f");
    if str_eq(enc, "Zg==") != 1 { return 8; };
    return 0;
}

fn check_round_trip() -> i64 {
    let original: str = "the lazy fox";
    let enc: str = b64_encode(original);
    let dec: str = b64_decode(enc);
    if str_eq(dec, original) != 1 { return 16; };
    return 0;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    fails = fails + check_empty();
    fails = fails + check_rfc4648_foobar();
    fails = fails + check_rfc4648_short_padded();
    fails = fails + check_round_trip();
    return fails;
}
