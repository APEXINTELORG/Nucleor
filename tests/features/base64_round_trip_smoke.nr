// v0.8.94 stdlib/rods/base64.nr first test coverage.
//
// Per the v0.8.94 zero-coverage rod survey, base64.nr had no
// existing tests. Same class as the QM-7 Clifford gap (silent
// correctness bugs in encode/decode would be undetectable).
//
// Locks:
//   1. RFC 4648 §10 reference vectors (known input -> known
//      base64 output): "", "f", "fo", "foo", "foob", "fooba",
//      "foobar".
//   2. round-trip: every encoded string decodes back to the
//      original.
//   3. padding correctness: outputs end with the right number
//      of `=` characters per input length mod 3.
//
// Expected: rc=0 (assertions bump rc on failure).

import "stdlib/rods/base64.nr"

fn enc_eq(input: str, want: str, code: i64) -> i64 {
    let got: str = b64_encode(input);
    if str_eq(got, want) == 1 { return 0; };
    return code;
}

fn round_trip(input: str, code: i64) -> i64 {
    let encoded: str = b64_encode(input);
    let decoded: str = b64_decode(encoded);
    if str_eq(decoded, input) == 1 { return 0; };
    return code;
}

fn main() -> i64 {
    let mut fails: i64 = 0;
    // RFC 4648 §10 reference vectors
    fails = fails + enc_eq("", "", 1);
    fails = fails + enc_eq("f", "Zg==", 2);
    fails = fails + enc_eq("fo", "Zm8=", 4);
    fails = fails + enc_eq("foo", "Zm9v", 8);
    fails = fails + enc_eq("foob", "Zm9vYg==", 16);
    fails = fails + enc_eq("fooba", "Zm9vYmE=", 32);
    fails = fails + enc_eq("foobar", "Zm9vYmFy", 64);

    // Round-trip across all input lengths mod 3
    fails = fails + round_trip("foo", 128);
    fails = fails + round_trip("foob", 256);
    fails = fails + round_trip("fooba", 512);
    fails = fails + round_trip("foobar", 1024);
    fails = fails + round_trip("hello world", 2048);
    fails = fails + round_trip("Nucleor", 4096);

    return fails;
}
