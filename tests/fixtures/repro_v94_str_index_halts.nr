// repro_v94_str_index_halts.nr — v0.4.94 TYP-011 close.
// Pre-fix `s[0]` for `s: str` silently dispatched to vec_get(s, 0)
// which read the str pointer as if it were an NVec header — at
// best returned garbage, at worst SIGSEGVed. Adopters writing
// canonical Rust string indexing got an OOB panic with "len 0"
// or random garbage.
//
// v0.4.94 halts at type-check with TYP-011 + workaround hint
// pointing at str_char_at / str_substring.
//
// EXPECT: build fails (msg contains "str` does not support direct
// indexing").

fn main() -> i64 {
    let s: str = "hello";
    let c: i64 = s[0];
    println!("{}", c);
    return 0;
}
