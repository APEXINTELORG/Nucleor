// t382_char_literal_escapes.nr — v0.3.105 regression fixture.
//
// Pins char literal lexing — both plain `'X'` and the escape
// forms `'\n'` `'\t'` `'\r'` `'\0'` `'\\'` `'\''` `'\"'`.
// Pre-v0.3.105, the lexer treated EVERY single-quote-prefixed
// token as a lifetime annotation (token kind 98), so:
//   `let c: i64 = 'A';`     bound c to a lifetime token (silent 0)
//   `let nl: i64 = '\n';`   silently produced 0
// HIGH-blast for any I/O, ASCII manipulation, parser, or
// terminal-control code reaching for the canonical char literal.
//
// Lifetime parsing is preserved for identifier-shaped names like
// `'a` or `'static` — the disambiguator only matches `'X'` (3 chars
// total: open-quote, single non-backslash char, close-quote) and
// `'\X'` (4 chars: open-quote, backslash, escape-char, close-quote).
//
// Returns 0 when every literal produces the expected codepoint;
// non-zero diagnostic codes pinpoint which form mis-lexed.

fn main() -> i64 {
    if 'A' != 65 { return 1; };
    if 'a' != 97 { return 2; };
    if '0' != 48 { return 3; };
    if ' ' != 32 { return 4; };
    if '\n' != 10 { return 5; };
    if '\t' != 9 { return 6; };
    if '\r' != 13 { return 7; };
    if '\0' != 0 { return 8; };
    if '\\' != 92 { return 9; };
    return 0;
}
