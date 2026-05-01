// `str_char_at_strict(s, i)` panics for `i >= strlen(s)`.
//
// v0.4.279 — closes probe-agent finding 2026-04-30
// (str-char-at-oob-silent-read). The strict variant does the
// strlen check + panics on OOB, mirroring `str_substring_strict`
// from v0.3.220.
//
// EXPECT: build success, runtime exits 1 with PANIC mentioning
// `str_char_at_strict OOB`.

fn main() -> i32 {
    let s: str = "hi";
    let c: i64 = str_char_at_strict(s, 100);
    print_int(c as i32);
    0
}
