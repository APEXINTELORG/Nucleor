// stdlib `str_char_at_strict` opt-in bounds-checked variant.
//
// v0.4.279 — closes probe finding 2026-04-30
// (str-char-at-oob-silent-read). Default `str_char_at` keeps
// its v0.3.220 cheap-default semantics (negative-only check;
// strlen-per-call would be a 75x perf killer in lexer paths).
// Adopters who want full bounds-check safety opt in by calling
// `str_char_at_strict` instead.
//
// EXPECT: build success, runtime exit 0, output "OK str_char_at_strict_basic".

fn main() -> i32 {
    let s: str = "hello";

    // In-bounds reads return the same as default str_char_at.
    if str_char_at_strict(s, 0) != str_char_at(s, 0) { print("FAIL c0"); return 1; };
    if str_char_at_strict(s, 1) != str_char_at(s, 1) { print("FAIL c1"); return 1; };
    if str_char_at_strict(s, 4) != str_char_at(s, 4) { print("FAIL c4"); return 1; };

    // Specific byte values for "hello".
    if str_char_at_strict(s, 0) != 104 { print("FAIL h"); return 1; };  // 'h'
    if str_char_at_strict(s, 1) != 101 { print("FAIL e"); return 1; };  // 'e'
    if str_char_at_strict(s, 4) != 111 { print("FAIL o"); return 1; };  // 'o'

    print("OK str_char_at_strict_basic");
    0
}
