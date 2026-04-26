// t419_tokenizer_accessors.nr — v0.3.144 NUC-IMPROVE-006 fixture.
//
// Pre-v0.3.144, stdlib/rods/tokenizer.nr exposed tok_encode and
// tok_char_level returning an opaque i64 handle to the encoded id
// sequence — but no .nr surface to read length, index in, decode, or
// free. nuc_tok_decode existed in the runtime but was never exposed.
//
// Round-trip: char-tokenize "Nu" (2 chars) → assert len == 2 →
// assert ids match the byte values of N (78) and u (117) → free.
// Returns 42 on success; non-zero codes pinpoint which check failed.

import "stdlib/rods/tokenizer.nr"

fn main() -> i64 {
    let ids: i64 = tok_char_level("Nu");
    if ids == 0 { return 1; };

    let n: i64 = tok_vec_len(ids);
    if n != 2 { return 2; };

    let id0: i64 = tok_vec_at(ids, 0);
    if id0 != 78 { return 3; };

    let id1: i64 = tok_vec_at(ids, 1);
    if id1 != 117 { return 4; };

    // out-of-bounds returns 0
    let oob: i64 = tok_vec_at(ids, 99);
    if oob != 0 { return 5; };

    tok_vec_free(ids);
    return 42;
}
