// =====================================================
// Nucleor Stage 1 Compiler
// =====================================================
// A complete Nucleor compiler written in Nucleor.
// Reads a .nr source file, compiles it through:
//   source -> lex -> parse -> lower -> emit LLVM IR -> clang -> native exe
// Usage: nucleor_s1 <source.nr> <output_name>
// =====================================================

// T1.1 Phase 3c (v0.2.310): widened internal arithmetic to i64 so
// large register IDs and IR constant values (up to i64 max) are
// formatted correctly. The parameter remains `i32` for source
// compatibility; arithmetic moves to i64 to avoid Phase 1's
// narrow-as-i32 hook truncating values that exceed i32 range.
fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i64 = n;
    if val < 0 { val = 0 - val; };
    let mut s: str = "";
    while val > 0 {
        let d: i64 = val - (val / 10) * 10;
        let mut ch: str = "0";
        if d == 1 { ch = "1"; } else if d == 2 { ch = "2"; } else if d == 3 { ch = "3"; }
        else if d == 4 { ch = "4"; } else if d == 5 { ch = "5"; } else if d == 6 { ch = "6"; }
        else if d == 7 { ch = "7"; } else if d == 8 { ch = "8"; } else if d == 9 { ch = "9"; };
        s = str_concat(ch, s);
        val = val / 10;
    };
    if n < 0 { s = str_concat("-", s); };
    return s;
}
fn str_to_int(s: str) -> i64 {
    let slen: i64 = str_len(s);
    let mut result: i64 = 0;
    let mut i: i64 = 0;
    let mut neg: i64 = 0;
    if slen > 0 && str_char_at(s, 0) == 45 { neg = 1; i = 1; };
    while i < slen { result = result * 10 + (str_char_at(s, i) - 48); i = i + 1; };
    if neg == 1 { return 0 - result; };
    return result;
}
fn str_is_digits(s: str) -> i64 {
    let slen: i64 = str_len(s);
    if slen == 0 { return 0; };
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c < 48 || c > 57 { return 0; };
        i = i + 1;
    };
    return 1;
}

// =====================================================
// LEXER (from T29, unchanged)
// =====================================================
fn tok_new(tt: i64, v: i64, p: i64) -> Vec<i32> {
    let mut t: Vec<i32> = Vec::new(); t.push(tt); t.push(v); t.push(p); return t;
}
fn tok_type(t: Vec<i32>) -> i64 { return vec_get(t, 0); }
fn tok_val(t: Vec<i32>) -> i64 { return vec_get(t, 1); }
fn is_ws(c: i64) -> i64 { if c == 32 || c == 9 || c == 10 || c == 13 { return 1; }; return 0; }
fn is_digit(c: i64) -> i64 { if c >= 48 && c <= 57 { return 1; }; return 0; }
fn is_alpha(c: i64) -> i64 {
    if c >= 65 && c <= 90 { return 1; }; if c >= 97 && c <= 122 { return 1; };
    if c == 95 { return 1; }; return 0;
}
fn is_alnum(c: i64) -> i64 { if is_alpha(c) == 1 || is_digit(c) == 1 { return 1; }; return 0; }
fn classify_kw(w: str) -> i64 {
    if str_eq(w, "fn") { return 10; }; if str_eq(w, "let") { return 11; };
    if str_eq(w, "mut") { return 12; }; if str_eq(w, "if") { return 13; };
    if str_eq(w, "else") { return 14; }; if str_eq(w, "while") { return 15; };
    if str_eq(w, "return") { return 16; }; if str_eq(w, "struct") { return 17; };
    if str_eq(w, "break") { return 18; }; if str_eq(w, "continue") { return 19; };
    if str_eq(w, "extern") { return 20; };
    if str_eq(w, "for") { return 56; }; if str_eq(w, "in") { return 57; };
    if str_eq(w, "enum") { return 62; }; if str_eq(w, "match") { return 63; };
    if str_eq(w, "trait") { return 66; }; if str_eq(w, "impl") { return 67; };
    if str_eq(w, "pure") { return 68; };
    if str_eq(w, "pub") { return 72; };
    if str_eq(w, "const") { return 73; };
    if str_eq(w, "type") { return 74; };
    if str_eq(w, "requires") { return 75; };
    if str_eq(w, "restricts") { return 76; };
    if str_eq(w, "unsafe") { return 77; };
    if str_eq(w, "wrapping") { return 78; };
    if str_eq(w, "saturating") { return 79; };
    if str_eq(w, "scope") { return 80; };
    if str_eq(w, "spawn") { return 81; };
    if str_eq(w, "loop") { return 84; };
    if str_eq(w, "as") { return 86; };
    return 1;
}
fn lex(src: str) -> Vec<i32> {
    let mut tokens: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if is_ws(c) == 1 { p = p + 1; }
        else if c == 64 {
            // Skip attributes like @authored(...), @policy(...), @hot, @const_fn.
            p = p + 1;
            while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
            if p < slen && str_char_at(src, p) == 40 {
                let mut depth: i64 = 1;
                p = p + 1;
                while p < slen && depth > 0 {
                    let ch: i64 = str_char_at(src, p);
                    if ch == 34 {
                        p = p + 1;
                        while p < slen && str_char_at(src, p) != 34 {
                            if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                            else { p = p + 1; };
                        };
                        if p < slen { p = p + 1; };
                    } else {
                        if ch == 40 { depth = depth + 1; }
                        else if ch == 41 { depth = depth - 1; };
                        p = p + 1;
                    };
                };
            };
        }
        else if c == 35 && p + 1 < slen && str_char_at(src, p + 1) == 91 {
            // Rust-style outer attribute: #[name], #[name(args)], #[name = val].
            // Lex-time skip with quoted-string + bracket-depth awareness.
            // Forward-compatible with RFC-0001/0021 attribute family; semantics
            // ship in later RFC implementation phases.
            p = p + 2;
            let mut depth: i64 = 1;
            while p < slen && depth > 0 {
                let ch: i64 = str_char_at(src, p);
                if ch == 34 {
                    p = p + 1;
                    while p < slen && str_char_at(src, p) != 34 {
                        if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                        else { p = p + 1; };
                    };
                    if p < slen { p = p + 1; };
                } else {
                    if ch == 91 { depth = depth + 1; }
                    else if ch == 93 { depth = depth - 1; };
                    p = p + 1;
                };
            };
        }
        else if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        }
        else if c == 92 && p + 1 < slen && str_char_at(src, p + 1) == 32 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        }
        else if is_alpha(c) == 1 {
            let st: i64 = p;
            while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
            let w: str = str_substring(src, st, p);
            tokens.push(tok_new(classify_kw(w), w, st));
        }
        else if is_digit(c) == 1 {
            // RFC-0015 phase 1+5: integer/float lexer with hex/oct/bin literals,
            // underscores, and type suffixes.
            //   0x... = hex   (e.g., 0xAB, 0xFFFF_FFFF)
            //   0o... = octal (e.g., 0o777)
            //   0b... = binary (e.g., 0b1010_0001)
            //   Otherwise decimal.
            // Recognised suffixes: i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128
            // usize (lexed; full type-check arrives in later phases).
            let st: i64 = p;
            let mut int_value: i64 = 0;
            let mut handled_radix: i64 = 0;
            // Detect 0x / 0o / 0b prefix
            if c == 48 && p + 1 < slen {
                let nx: i64 = str_char_at(src, p + 1);
                if nx == 120 || nx == 88 {
                    // hex
                    p = p + 2;
                    while p < slen {
                        let hc: i64 = str_char_at(src, p);
                        if hc == 95 { p = p + 1; }
                        else if hc >= 48 && hc <= 57 { int_value = int_value * 16 + (hc - 48); p = p + 1; }
                        else if hc >= 97 && hc <= 102 { int_value = int_value * 16 + (hc - 87); p = p + 1; }
                        else if hc >= 65 && hc <= 70 { int_value = int_value * 16 + (hc - 55); p = p + 1; }
                        else { break; };
                    };
                    handled_radix = 1;
                } else if nx == 111 || nx == 79 {
                    // octal
                    p = p + 2;
                    while p < slen {
                        let oc: i64 = str_char_at(src, p);
                        if oc == 95 { p = p + 1; }
                        else if oc >= 48 && oc <= 55 { int_value = int_value * 8 + (oc - 48); p = p + 1; }
                        else { break; };
                    };
                    handled_radix = 1;
                } else if nx == 98 || nx == 66 {
                    // binary
                    p = p + 2;
                    while p < slen {
                        let bc: i64 = str_char_at(src, p);
                        if bc == 95 { p = p + 1; }
                        else if bc == 48 { int_value = int_value * 2; p = p + 1; }
                        else if bc == 49 { int_value = int_value * 2 + 1; p = p + 1; }
                        else { break; };
                    };
                    handled_radix = 1;
                };
            };
            let mut digit_sb: i64 = sb_new();
            if handled_radix == 0 {
                while p < slen && (is_digit(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) {
                    if str_char_at(src, p) != 95 {
                        sb_append(digit_sb, str_substring(src, p, p + 1));
                    };
                    p = p + 1;
                };
            };
            // Check for f64 literal: digits DOT digits
            if p < slen && str_char_at(src, p) == 46 && p + 1 < slen && is_digit(str_char_at(src, p + 1)) == 1 {
                // f64 literal — parse integer.fraction, encode as bitcast i64
                let int_part: i64 = str_to_int(sb_to_str(digit_sb));
                p = p + 1; // skip dot
                let frac_st: i64 = p;
                let mut frac_sb: i64 = sb_new();
                while p < slen && (is_digit(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) {
                    if str_char_at(src, p) != 95 {
                        sb_append(frac_sb, str_substring(src, p, p + 1));
                    };
                    p = p + 1;
                };
                let raw_frac_str: str = sb_to_str(frac_sb);
                // v0.3.130: NUC-FEEDBACK-005 — truncate fractional digits to
                // the encoder's 6-digit (millionth) precision BEFORE
                // computing frac_div. The truncate path handles literals
                // where the first 6 frac digits carry meaningful value.
                //
                // v0.3.133: NUC-FEEDBACK-006 — for SUB-MICRO literals
                // (`0.00000001` = 1e-8 used as AdamW eps, etc.), the
                // first 6 frac digits are all '0' and truncation still
                // produces zero. Falling back to the runtime
                // `__nucleor_str_to_f64` parser via the str_to_f64
                // helper gives full IEEE-754 precision. The bit
                // pattern is stored as token kind 124 (raw-bits f64
                // literal); parse_primary emits AST kind 72 which
                // lower_expr emits as a direct const_int (no
                // f64_from_scaled divide needed since the value IS
                // already the f64 bit pattern).
                let raw_frac_len: i64 = str_len(raw_frac_str);
                let mut use_raw_bits: i64 = 0;
                if raw_frac_len > 6 {
                    let mut all_zero: i64 = 1;
                    let mut zi: i64 = 0;
                    while zi < 6 {
                        if str_char_at(raw_frac_str, zi) != 48 { all_zero = 0; zi = 6; };
                        zi = zi + 1;
                    };
                    if all_zero == 1 { use_raw_bits = 1; };
                };
                if use_raw_bits == 1 {
                    let lit_text: str = str_concat(str_from_int(int_part), str_concat(".", raw_frac_str));
                    let bits: i64 = str_to_f64(lit_text);
                    tokens.push(tok_new(124, bits, st));
                } else {
                    let frac_str: str = if raw_frac_len > 6 { str_substring(raw_frac_str, 0, 6) } else { raw_frac_str };
                    let frac_val: i64 = str_to_int(frac_str);
                    let frac_len: i64 = str_len(frac_str);
                    // Compute frac_divisor = 10^frac_len
                    let mut frac_div: i64 = 1;
                    let mut fi: i64 = 0;
                    while fi < frac_len { frac_div = frac_div * 10; fi = fi + 1; };
                    // Encode: store int_part and frac as token type 70 (f64 literal)
                    // Value = int_part * 1000000 + frac_val * (1000000 / frac_div)
                    let encoded: i64 = int_part * 1000000 + frac_val * (1000000 / frac_div);
                    tokens.push(tok_new(70, encoded, st));
                };
                // Consume optional float suffix: f32 or f64
                if p < slen && str_char_at(src, p) == 102 {
                    let suf_st: i64 = p;
                    while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
                    let suf: str = str_substring(src, suf_st, p);
                    if str_eq(suf, "f32") == 0 && str_eq(suf, "f64") == 0 {
                        // Not actually a suffix; rewind.
                        p = suf_st;
                    };
                };
                if p < slen && str_char_at(src, p) == 123 {
                    tokens.push(tok_new(83, 0, p));
                    p = p + 1;
                }
            } else {
                let int_lit_value: i64 = if handled_radix == 1 { int_value } else { str_to_int(sb_to_str(digit_sb)) };
                tokens.push(tok_new(2, int_lit_value, st));
                // Consume optional integer suffix: i8 i16 i32 i64 u8 u16 u32 u64 usize isize
                if p < slen && (str_char_at(src, p) == 105 || str_char_at(src, p) == 117) {
                    let suf_st: i64 = p;
                    while p < slen && is_alnum(str_char_at(src, p)) == 1 { p = p + 1; };
                    let suf: str = str_substring(src, suf_st, p);
                    let mut is_known: i64 = 0;
                    if str_eq(suf, "i8") == 1 { is_known = 1; };
                    if str_eq(suf, "i16") == 1 { is_known = 1; };
                    if str_eq(suf, "i32") == 1 { is_known = 1; };
                    if str_eq(suf, "i64") == 1 { is_known = 1; };
                    if str_eq(suf, "i128") == 1 { is_known = 1; };
                    if str_eq(suf, "isize") == 1 { is_known = 1; };
                    if str_eq(suf, "u8") == 1 { is_known = 1; };
                    if str_eq(suf, "u16") == 1 { is_known = 1; };
                    if str_eq(suf, "u32") == 1 { is_known = 1; };
                    if str_eq(suf, "u64") == 1 { is_known = 1; };
                    if str_eq(suf, "u128") == 1 { is_known = 1; };
                    if str_eq(suf, "usize") == 1 { is_known = 1; };
                    if is_known == 0 {
                        // Not actually a suffix; rewind so it lexes as identifier.
                        p = suf_st;
                    };
                };
                if p < slen && str_char_at(src, p) == 123 {
                    tokens.push(tok_new(83, 0, p));
                    p = p + 1;
                }
            };
        }
        else if c == 34 {
            let st: i64 = p; p = p + 1;
            let mut sb: i64 = sb_new();
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    let nc: i64 = str_char_at(src, p + 1);
                    if nc == 110 { sb_append(sb, "\n"); } else if nc == 116 { sb_append(sb, "\t"); }
                    else if nc == 34 { sb_append(sb, "\""); } else if nc == 92 { sb_append(sb, "\\"); }
                    else { sb_append(sb, str_substring(src, p + 1, p + 2)); };
                    p = p + 2;
                } else { sb_append(sb, str_substring(src, p, p + 1)); p = p + 1; };
            };
            if p < slen { p = p + 1; };
            tokens.push(tok_new(3, sb_to_str(sb), st));
        }
        else if c == 45 && p + 1 < slen && str_char_at(src, p + 1) == 62 { tokens.push(tok_new(41, 0, p)); p = p + 2; }
        else if c == 61 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(30, 0, p)); p = p + 2; }
        else if c == 61 && p + 1 < slen && str_char_at(src, p + 1) == 62 { tokens.push(tok_new(64, 0, p)); p = p + 2; }
        else if c == 33 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(31, 0, p)); p = p + 2; }
        else if c == 60 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(34, 0, p)); p = p + 2; }
        else if c == 62 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(35, 0, p)); p = p + 2; }
        else if c == 38 && p + 1 < slen && str_char_at(src, p + 1) == 38 { tokens.push(tok_new(36, 0, p)); p = p + 2; }
        // v0.3.105: bitwise compound assigns. `&=` → token 117,
        // `|=` → 118, `^=` → 119. Lexed BEFORE the bare `&`/`|`/`^`
        // single-token rules below so `&=` doesn't split as `&` `=`.
        // `<<=` and `>>=` follow the same pattern (120/121).
        else if c == 38 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(117, 0, p)); p = p + 2; }
        else if c == 38 { tokens.push(tok_new(82, 0, p)); p = p + 1; }
        else if c == 124 && p + 1 < slen && str_char_at(src, p + 1) == 124 { tokens.push(tok_new(37, 0, p)); p = p + 2; }
        else if c == 124 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(118, 0, p)); p = p + 2; }
        else if c == 124 { tokens.push(tok_new(65, 0, p)); p = p + 1; }
        // v0.3.103: bitwise XOR `^` as token 94 — paired with the
        // `parse_bitwise` tier (tier between parse_eq and parse_and_expr)
        // and tok_to_ir mapping (94 → iop 15 = LLVM xor i64).
        else if c == 94 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(119, 0, p)); p = p + 2; }
        else if c == 94 { tokens.push(tok_new(94, 0, p)); p = p + 1; }
        // v0.3.104: shift-left `<<` as token 115. Shift-right `>>`
        // is intentionally NOT lexed as a single token — generic
        // syntax `Vec<Vec<i64>>` ends in `>>` and the seven angle-
        // group skips would all need updating to handle the merged
        // form. Instead, parse_shift detects two adjacent `>` tokens
        // and consumes both as shift-right at parse time. `<<` has
        // no such conflict so a single token is safe here.
        else if c == 60 && p + 2 < slen && str_char_at(src, p + 1) == 60 && str_char_at(src, p + 2) == 61 { tokens.push(tok_new(120, 0, p)); p = p + 3; }
        else if c == 60 && p + 1 < slen && str_char_at(src, p + 1) == 60 { tokens.push(tok_new(115, 0, p)); p = p + 2; }
        // v0.3.105: `>>=` lexed as a single token 121 — has no
        // conflict with generics because `>>=` (3 chars) doesn't
        // appear in any valid generic-position form.
        else if c == 62 && p + 2 < slen && str_char_at(src, p + 1) == 62 && str_char_at(src, p + 2) == 61 { tokens.push(tok_new(121, 0, p)); p = p + 3; }
        else if c == 58 && p + 1 < slen && str_char_at(src, p + 1) == 58 { tokens.push(tok_new(46, 0, p)); p = p + 2; }
        // v0.3.77: compound-assignment tokens (`+=`, `-=`, `*=`, `/=`, `%=`).
        // Lex as single tokens kind 110-114 so the parser can desugar
        // `LHS op= RHS` to `LHS = LHS op RHS` cleanly. Without this,
        // `x += 5;` lexed as separate `+` and `=` tokens which the parser
        // dropped silently. Token kinds 110/111/112/113/114 are reserved
        // for the five compound-op forms in op-token order.
        else if c == 43 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(110, 0, p)); p = p + 2; }
        else if c == 43 { tokens.push(tok_new(20, 0, p)); p = p + 1; }
        else if c == 45 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(111, 0, p)); p = p + 2; }
        else if c == 45 { tokens.push(tok_new(21, 0, p)); p = p + 1; }
        else if c == 42 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(112, 0, p)); p = p + 2; }
        else if c == 42 { tokens.push(tok_new(22, 0, p)); p = p + 1; }
        else if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(113, 0, p)); p = p + 2; }
        else if c == 47 { tokens.push(tok_new(23, 0, p)); p = p + 1; }
        else if c == 37 && p + 1 < slen && str_char_at(src, p + 1) == 61 { tokens.push(tok_new(114, 0, p)); p = p + 2; }
        else if c == 37 { tokens.push(tok_new(24, 0, p)); p = p + 1; }
        else if c == 61 { tokens.push(tok_new(40, 0, p)); p = p + 1; }
        else if c == 60 { tokens.push(tok_new(32, 0, p)); p = p + 1; }
        else if c == 62 { tokens.push(tok_new(33, 0, p)); p = p + 1; }
        else if c == 33 { tokens.push(tok_new(38, 0, p)); p = p + 1; }
        else if c == 58 { tokens.push(tok_new(42, 0, p)); p = p + 1; }
        else if c == 59 { tokens.push(tok_new(43, 0, p)); p = p + 1; }
        else if c == 44 { tokens.push(tok_new(44, 0, p)); p = p + 1; }
        else if c == 46 && p + 1 < slen && str_char_at(src, p + 1) == 46 && p + 2 < slen && str_char_at(src, p + 2) == 61 {
            // ..= inclusive range
            tokens.push(tok_new(96, 0, p));
            p = p + 3;
        }
        else if c == 46 && p + 1 < slen && str_char_at(src, p + 1) == 46 { tokens.push(tok_new(58, 0, p)); p = p + 2; }
        else if c == 46 { tokens.push(tok_new(45, 0, p)); p = p + 1; }
        else if c == 40 { tokens.push(tok_new(50, 0, p)); p = p + 1; }
        else if c == 41 { tokens.push(tok_new(51, 0, p)); p = p + 1; }
        else if c == 123 { tokens.push(tok_new(52, 0, p)); p = p + 1; }
        else if c == 125 { tokens.push(tok_new(53, 0, p)); p = p + 1; }
        else if c == 91 { tokens.push(tok_new(54, 0, p)); p = p + 1; }
        else if c == 93 { tokens.push(tok_new(55, 0, p)); p = p + 1; }
        else if c == 63 { tokens.push(tok_new(97, 0, p)); p = p + 1; }
        else if c == 39 {
            // v0.3.105: char literals `'X'` and escape forms
            // `'\n'`/`'\t'`/`'\r'`/`'\0'`/`'\\'`/`'\''`. Emit as int
            // literal (token kind 2 with the codepoint as the value)
            // — matches Rust semantics where `'A' as i64 == 65` and
            // matches the convention documented at the prior
            // lifetime-only branch ("chars use u8/u32 via int literals").
            // Pre-v0.3.105, `'\n'` was lexed as a malformed lifetime
            // marker and silently produced 0 at runtime, a HIGH-blast
            // miscompute for any code using char escapes (parsers,
            // I/O, ASCII manipulation). Lifetime parsing is preserved
            // as the fallback when the pattern doesn't match
            // `'<one-char>'`.
            let st: i64 = p;
            // Try to recognize a char literal first.
            let mut handled: i64 = 0;
            if p + 2 < slen {
                let n1: i64 = str_char_at(src, p + 1);
                let n2: i64 = str_char_at(src, p + 2);
                // Plain `'X'` form — single non-backslash char.
                if n1 != 92 && n2 == 39 {
                    tokens.push(tok_new(2, n1, st));
                    p = p + 3;
                    handled = 1;
                };
            };
            if handled == 0 && p + 3 < slen && str_char_at(src, p + 1) == 92 && str_char_at(src, p + 3) == 39 {
                let esc: i64 = str_char_at(src, p + 2);
                let mut val: i64 = esc;
                if esc == 110 { val = 10; };       // \n
                if esc == 116 { val = 9; };        // \t
                if esc == 114 { val = 13; };       // \r
                if esc == 48  { val = 0; };        // \0
                if esc == 92  { val = 92; };       // \\
                if esc == 39  { val = 39; };       // \'
                if esc == 34  { val = 34; };       // \"
                tokens.push(tok_new(2, val, st));
                p = p + 4;
                handled = 1;
            };
            if handled == 0 {
                // T2.5 (v0.2.351) fallback: apostrophe → lifetime token.
                p = p + 1;
                let id_st: i64 = p;
                while p < slen && (is_alnum(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) { p = p + 1; };
                let lt_name: str = str_substring(src, id_st, p);
                tokens.push(tok_new(98, lt_name, st));
            };
        }
        else { p = p + 1; };
    };
    tokens.push(tok_new(0, 0, slen));
    return tokens;
}
fn tok_at(tokens: Vec<i32>, idx: i64) -> Vec<i32> {
    if idx >= vec_len(tokens) { return tok_new(0, 0, 0); }; return vec_get(tokens, idx);
}
fn tok_type_at(tokens: Vec<i32>, idx: i64) -> i64 { return tok_type(tok_at(tokens, idx)); }
fn tok_val_at(tokens: Vec<i32>, idx: i64) -> i64 { return tok_val(tok_at(tokens, idx)); }

// =====================================================
// PARSER (from T29, unchanged)
// =====================================================
fn node_add(pool: Vec<i32>, nd: Vec<i32>) -> i64 { let nid: i64 = vec_len(pool); pool.push(nd); return nid; }
fn node_kind(pool: Vec<i32>, nid: i64) -> i64 { let nd: Vec<i32> = vec_get(pool, nid); return vec_get(nd, 0); }
fn node_field(pool: Vec<i32>, nid: i64, idx: i64) -> i64 { let nd: Vec<i32> = vec_get(pool, nid); return vec_get(nd, idx); }
fn mk2(pool: Vec<i32>, k: i64, a: i64) -> i64 { let mut n: Vec<i32> = Vec::new(); n.push(k); n.push(a); return node_add(pool, n); }
fn mk3(pool: Vec<i32>, k: i64, a: i64, b: i64) -> i64 { let mut n: Vec<i32> = Vec::new(); n.push(k); n.push(a); n.push(b); return node_add(pool, n); }
fn mk4(pool: Vec<i32>, k: i64, a: i64, b: i64, c: i64) -> i64 { let mut n: Vec<i32> = Vec::new(); n.push(k); n.push(a); n.push(b); n.push(c); return node_add(pool, n); }
fn mk5(pool: Vec<i32>, k: i64, a: i64, b: i64, c: i64, d: i64) -> i64 { let mut n: Vec<i32> = Vec::new(); n.push(k); n.push(a); n.push(b); n.push(c); n.push(d); return node_add(pool, n); }
fn mk6(pool: Vec<i32>, k: i64, a: i64, b: i64, c: i64, d: i64, e: i64) -> i64 { let mut n: Vec<i32> = Vec::new(); n.push(k); n.push(a); n.push(b); n.push(c); n.push(d); n.push(e); return node_add(pool, n); }
fn mk_list(pool: Vec<i32>, items: Vec<i32>) -> i64 {
    let mut n: Vec<i32> = Vec::new(); n.push(40);
    let mut i: i64 = 0; while i < vec_len(items) { n.push(vec_get(items, i)); i = i + 1; };
    return node_add(pool, n);
}
fn list_len(pool: Vec<i32>, lid: i64) -> i64 { let nd: Vec<i32> = vec_get(pool, lid); return vec_len(nd) - 1; }
fn list_get(pool: Vec<i32>, lid: i64, idx: i64) -> i64 { let nd: Vec<i32> = vec_get(pool, lid); return vec_get(nd, idx + 1); }

fn pr(p: i64, v: i64) -> Vec<i32> { let mut r: Vec<i32> = Vec::new(); r.push(p); r.push(v); return r; }
fn pr_pos(r: Vec<i32>) -> i64 { return vec_get(r, 0); }
fn pr_val(r: Vec<i32>) -> i64 { return vec_get(r, 1); }

fn pk(tokens: Vec<i32>, pos: i64) -> i64 { return tok_type_at(tokens, pos); }
fn pkv(tokens: Vec<i32>, pos: i64) -> i64 { return tok_val_at(tokens, pos); }
fn expect_tok(tokens: Vec<i32>, pos: i64, tt: i64) -> i64 {
    if pk(tokens, pos) != tt {
        // Get byte position from token for line number
        let tok: Vec<i32> = tok_at(tokens, pos);
        let byte_pos: i64 = vec_get(tok, 2);
        print(str_concat("Parse error at token position ", str_concat(str_from_int(byte_pos), str_concat(": expected token ", str_concat(str_from_int(tt), str_concat(" got ", str_from_int(pk(tokens, pos))))))));
    };
    return pos + 1;
}

fn parse_args(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut args: Vec<i32> = Vec::new();
    let mut cp: i64 = pos;
    if pk(tokens, cp) != 51 {
        let mut r: Vec<i32> = parse_expr(tokens, cp, pool);
        args.push(pr_val(r)); cp = pr_pos(r);
        while pk(tokens, cp) == 44 {
            if pk(tokens, cp + 1) == 51 { cp = cp + 1; }
            else {
                r = parse_expr(tokens, cp + 1, pool); args.push(pr_val(r)); cp = pr_pos(r);
            };
        };
    };
    return pr(cp + 1, mk_list(pool, args));
}

fn skip_bracket_list(tokens: Vec<i32>, pos: i64) -> i64 {
    let mut cp: i64 = expect_tok(tokens, pos, 54);
    let mut depth: i64 = 1;
    while depth > 0 && pk(tokens, cp) != 0 {
        if pk(tokens, cp) == 54 { depth = depth + 1; }
        else if pk(tokens, cp) == 55 { depth = depth - 1; };
        cp = cp + 1;
    };
    return cp;
}

fn skip_angle_group(tokens: Vec<i32>, pos: i64) -> i64 {
    if pk(tokens, pos) != 32 { return pos; };
    let mut cp: i64 = pos + 1;
    let mut depth: i64 = 1;
    while depth > 0 && pk(tokens, cp) != 0 {
        let tt: i64 = pk(tokens, cp);
        if depth == 1 {
            if tt == 2 || tt == 3 || tt == 40 || tt == 41 || tt == 43 || tt == 52 || tt == 53 || tt == 54 || tt == 55 || tt == 64 { return pos; };
            if tt == 30 || tt == 31 || tt == 34 || tt == 35 || tt == 36 || tt == 37 || tt == 38 || tt == 39 { return pos; };
        };
        if tt == 32 { depth = depth + 1; }
        else if tt == 33 { depth = depth - 1; };
        cp = cp + 1;
    };
    if depth != 0 { return pos; };
    if pk(tokens, cp) == 50 || pk(tokens, cp) == 52 || pk(tokens, cp) == 46 { return cp; };
    return pos;
}

fn skip_where_clause(tokens: Vec<i32>, pos: i64) -> i64 {
    let mut cp: i64 = pos;
    if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "where") == 1 {
        cp = cp + 1;
        while pk(tokens, cp) != 52 && pk(tokens, cp) != 43 && pk(tokens, cp) != 0 {
            cp = cp + 1;
        };
    };
    return cp;
}

fn parse_match_binding_block(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    let mut cp: i64 = pos;
    let mut binding: str = "";
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if str_len(binding) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 53 { break; };
            binding = str_concat(binding, "|");
        };
        let mut name: str = pkv(tokens, cp);
        cp = cp + 1;
        if pk(tokens, cp) == 42 {
            cp = cp + 1;
            name = pkv(tokens, cp);
            cp = cp + 1;
        };
        binding = str_concat(binding, name);
    };
    cp = expect_tok(tokens, cp, 53);
    return pr(cp, binding);
}

fn mk_passthrough_block_expr(pool: Vec<i32>, body: i64) -> i64 {
    return mk4(pool, 23, mk2(pool, 1, 1), body, 0 - 1);
}

fn parse_passthrough_block_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut cp: i64 = expect_tok(tokens, pos, 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    return pr(cp, mk_passthrough_block_expr(pool, pr_val(br)));
}

fn parse_wrapped_block_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>, mode: i64) -> Vec<i32> {
    let mut cp: i64 = expect_tok(tokens, pos, 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    return pr(cp, mk3(pool, 52, mode, pr_val(br)));
}

fn parse_primary(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let tt: i64 = pk(tokens, pos);
    if tt == 2 {
        let mut cp: i64 = pos + 1;
        if pk(tokens, cp) == 83 {
            let mut depth: i64 = 1;
            cp = cp + 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 52 { depth = depth + 1; }
                else if pk(tokens, cp) == 53 { depth = depth - 1; };
                cp = cp + 1;
            };
        };
        return pr(cp, mk2(pool, 1, pkv(tokens, pos)));
    };
    // f64 literal (token 70) — encoded as int_part*1000000 + frac_millionths
    if tt == 70 {
        let mut cp: i64 = pos + 1;
        if pk(tokens, cp) == 83 {
            let mut depth: i64 = 1;
            cp = cp + 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 52 { depth = depth + 1; }
                else if pk(tokens, cp) == 53 { depth = depth - 1; };
                cp = cp + 1;
            };
        };
        return pr(cp, mk2(pool, 71, pkv(tokens, pos)));
    };
    // v0.3.133: f64 raw-bits literal (token 124) — value IS the i64
    // bit pattern of the parsed float (via str_to_f64 at lex time).
    // Emits AST kind 72 which lower_expr handles by emitting the
    // bit pattern directly as a const_int (no scaled-int divide).
    if tt == 124 {
        let mut cp: i64 = pos + 1;
        if pk(tokens, cp) == 83 {
            let mut depth: i64 = 1;
            cp = cp + 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 52 { depth = depth + 1; }
                else if pk(tokens, cp) == 53 { depth = depth - 1; };
                cp = cp + 1;
            };
        };
        return pr(cp, mk2(pool, 72, pkv(tokens, pos)));
    };
    if tt == 3 { return pr(pos + 1, mk2(pool, 2, pkv(tokens, pos))); };
    if tt == 52 { return parse_passthrough_block_expr(tokens, pos, pool); };
    if tt == 50 {
        let mut r: Vec<i32> = parse_expr(tokens, pos + 1, pool);
        let mut cp: i64 = pr_pos(r);
        if pk(tokens, cp) != 44 {
            return pr(expect_tok(tokens, cp, 51), pr_val(r));
        };
        let mut items: Vec<i32> = Vec::new();
        items.push(pr_val(r));
        while pk(tokens, cp) == 44 {
            r = parse_expr(tokens, cp + 1, pool);
            items.push(pr_val(r));
            cp = pr_pos(r);
        };
        cp = expect_tok(tokens, cp, 51);
        return pr(cp, mk2(pool, 48, mk_list(pool, items)));
    };
    if tt == 54 {
        let mut cp: i64 = pos + 1;
        let mut items: Vec<i32> = Vec::new();
        while pk(tokens, cp) != 55 && pk(tokens, cp) != 0 {
            if vec_len(items) > 0 { cp = expect_tok(tokens, cp, 44); };
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
            items.push(pr_val(er));
            cp = pr_pos(er);
        };
        cp = expect_tok(tokens, cp, 55);
        return pr(cp, mk2(pool, 47, mk_list(pool, items)));
    };
    // if-expression
    if tt == 13 { let mut r: Vec<i32> = parse_if(tokens, pos + 1, pool); return r; };
    if tt == 63 { let mut r: Vec<i32> = parse_match_stmt(tokens, pos + 1, pool); return r; };
    if tt == 76 {
        let cp: i64 = skip_bracket_list(tokens, pos + 1);
        return parse_passthrough_block_expr(tokens, cp, pool);
    };
    if tt == 77 { return parse_passthrough_block_expr(tokens, pos + 1, pool); };
    if tt == 78 { return parse_wrapped_block_expr(tokens, pos + 1, pool, 1); };
    if tt == 79 { return parse_wrapped_block_expr(tokens, pos + 1, pool, 2); };
    if tt == 1 {
        let name: i64 = pkv(tokens, pos);
        if str_eq(name, "Some") == 1 || str_eq(name, "None") == 1 || str_eq(name, "Ok") == 1 || str_eq(name, "Err") == 1 {
            let mut tname: str = "Option";
            if str_eq(name, "Ok") == 1 || str_eq(name, "Err") == 1 { tname = "Result"; };
            if pk(tokens, pos + 1) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, pos + 2, pool);
                return pr(pr_pos(ar), mk4(pool, 12, tname, name, pr_val(ar)));
            };
            let mut empty: Vec<i32> = Vec::new();
            return pr(pos + 1, mk4(pool, 12, tname, name, mk_list(pool, empty)));
        };
        let p2: i64 = pos + 1;
        let cp2: i64 = skip_angle_group(tokens, p2);
        if pk(tokens, cp2) == 52 {
            // v0.3.114: also recognize pure-shorthand struct init —
            // `IDENT,` (multi-field shorthand) and `IDENT}` (single-
            // field shorthand). Pre-v0.3.114, only `IDENT:` (named
            // field) and `}` (empty) triggered struct-init parse.
            // Pure shorthand like `P { x, y }` (no `:`) fell through
            // to the bare identifier path; the `{ x, y }` was treated
            // as a separate block which left `@P` as an unresolved
            // global ref. Hard adoption blocker for any constructor
            // body using the canonical shorthand form
            // (`fn make(x, y) -> P { P { x, y } }`).
            //
            // For shorthand-only patterns (`,` / `}` after IDENT, no
            // `:` to confirm field-init shape), require the TYPE
            // identifier (`name`) to start with an uppercase letter.
            // Without this guard, `if foo { bar }` and
            // `while x { y }` patterns misfire — the lowercase `foo`
            // looks like a struct name to the disambiguator and the
            // single-ident body `bar` becomes a phantom shorthand
            // field. Rust convention reserves CamelCase for types,
            // so the case check is a clean boundary.
            let name_first: i64 = if str_len(name) > 0 { str_char_at(name, 0) } else { 0 };
            let is_upper: i64 = if name_first >= 65 && name_first <= 90 { 1 } else { 0 };
            if pk(tokens, cp2 + 1) == 53
               || (pk(tokens, cp2 + 1) == 1 && pk(tokens, cp2 + 2) == 42)
               || (is_upper == 1 && pk(tokens, cp2 + 1) == 1 && pk(tokens, cp2 + 2) == 44)
               || (is_upper == 1 && pk(tokens, cp2 + 1) == 1 && pk(tokens, cp2 + 2) == 53) {
                return parse_struct_init(tokens, pos, pool);
            };
        };
        // v0.3.115: turbofish syntax `name::<TypeArgs>(args)`. Pre-
        // v0.3.115, the `::<` after `name` was treated as `::ident` —
        // qname captured the `<` token's value (garbage), the
        // following `(` failed to match the kind-12 dispatch shape,
        // and the call lowered as an associated-fn-call with a bogus
        // qname → diagnostic + zero placeholder. Adopters reaching
        // for the canonical `Vec::<i64>::new()` / `id::<T>(x)` pattern
        // saw silent miscomputes alongside an informational error.
        // Strip `::<TypeArgs>` and re-dispatch via the regular fn-call
        // path; the type args are advisory at lower-time anyway.
        if pk(tokens, cp2) == 46 && pk(tokens, cp2 + 1) == 32 {
            let after_args: i64 = skip_angle_group(tokens, cp2 + 1);
            if pk(tokens, after_args) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, after_args + 1, pool);
                return pr(pr_pos(ar), mk3(pool, 7, name, pr_val(ar)));
            };
        };
        if pk(tokens, cp2) == 46 {
            let qname: i64 = pkv(tokens, cp2 + 1);
            if pk(tokens, cp2 + 2) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, cp2 + 3, pool);
                return pr(pr_pos(ar), mk4(pool, 12, name, qname, pr_val(ar)));
            } else if pk(tokens, cp2 + 2) == 52 && (pk(tokens, cp2 + 3) == 53 || (pk(tokens, cp2 + 3) == 1 && pk(tokens, cp2 + 4) == 42)) {
                // v0.3.87: struct-like enum variant constructor
                // `EnumName::Variant { field: val, ... }`. Parse the
                // named fields and produce a kind-12 with values in
                // SOURCE order (field names are discarded).
                //
                // v0.3.88: disambiguation guard. Only fire if what's
                // inside the `{` looks like a field-init list (empty
                // `}` or IDENT followed by `:`). Without this, the
                // branch incorrectly captured the match body in
                // `match Stream::Done { Stream::More(v) => ... }`
                // because the SCRUTINEE position has `IDENT::IDENT {`
                // followed by patterns, not field initializers.
                let mut cp3: i64 = cp2 + 3;
                let mut sargs: Vec<i32> = Vec::new();
                while pk(tokens, cp3) != 53 && pk(tokens, cp3) != 0 {
                    if vec_len(sargs) > 0 { cp3 = expect_tok(tokens, cp3, 44); };
                    if pk(tokens, cp3) == 53 { break; };
                    cp3 = cp3 + 1;
                    cp3 = expect_tok(tokens, cp3, 42);
                    let mut vr: Vec<i32> = parse_expr(tokens, cp3, pool);
                    sargs.push(pr_val(vr));
                    cp3 = pr_pos(vr);
                };
                cp3 = cp3 + 1; // }
                return pr(cp3, mk4(pool, 12, name, qname, mk_list(pool, sargs)));
            } else {
                let mut empty: Vec<i32> = Vec::new();
                return pr(cp2 + 2, mk4(pool, 12, name, qname, mk_list(pool, empty)));
            };
        };
        if pk(tokens, cp2) == 50 { let mut ar: Vec<i32> = parse_args(tokens, cp2 + 1, pool); return pr(pr_pos(ar), mk3(pool, 7, name, pr_val(ar))); };
        return pr(cp2, mk2(pool, 3, name));
    };
    // Closure: |params| expr  or  |params| { stmts }  or  || expr  or  || { stmts }
    if tt == 65 || tt == 37 {
        let mut cparams: Vec<i32> = Vec::new();
        let mut cp: i64 = pos + 1;
        // tt==37 means ||, i.e. zero-param closure — skip param parsing
        if tt == 65 {
            while pk(tokens, cp) != 65 && pk(tokens, cp) != 0 {
                if vec_len(cparams) > 0 { cp = expect_tok(tokens, cp, 44); };
                let pn: i64 = pkv(tokens, cp);
                cp = cp + 1;
                if pk(tokens, cp) == 42 { cp = cp + 1; let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr); };
                cparams.push(pn);
            };
            cp = cp + 1;
        };
        // v0.3.101: optional `-> RetType` after the closing `|`. Pre-
        // v0.3.101, `|x: i64| -> i64 { … }` left the parser pointing
        // at `->`, which neither matched the `{ … }` block branch nor
        // parsed cleanly as an expression — the body parser then
        // produced an `@i64` global ref (clang link error
        // `use of undefined value '@i64'`). The return type is
        // advisory at lower-time anyway (closures emit i64 returns
        // by convention), so we just skip the annotation.
        if pk(tokens, cp) == 41 {
            let mut tr: Vec<i32> = parse_type(tokens, cp + 1);
            cp = pr_pos(tr);
        };
        if pk(tokens, cp) == 52 {
            cp = expect_tok(tokens, cp, 52);
            let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
            cp = expect_tok(tokens, pr_pos(br), 53);
            return pr(cp, mk3(pool, 42, mk_list(pool, cparams), pr_val(br)));
        } else {
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
            cp = pr_pos(er);
            let mut rbody: Vec<i32> = Vec::new();
            rbody.push(mk2(pool, 22, pr_val(er)));
            return pr(cp, mk3(pool, 42, mk_list(pool, cparams), mk_list(pool, rbody)));
        };
    };
    return pr(pos + 1, mk2(pool, 1, 0));
}

fn parse_postfix(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_primary(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 45 || pk(tokens, cp) == 54 || pk(tokens, cp) == 97 {
        if pk(tokens, cp) == 97 {
            // RFC-0016 phase 1: `?` postfix — desugars at lower-time into
            // err-check + early return on Err / None. Inner expression is
            // expected to be Result<T, E> or Option<T> (compiler trusts the
            // layout: cell 0 = tag, cell 1 = payload; tag 0 = Err/None).
            cp = cp + 1;
            node = mk2(pool, 122, node);
        } else {
        if pk(tokens, cp) == 45 {
            let mut fname: str = "";
            if pk(tokens, cp + 1) == 2 { fname = str_from_int(pkv(tokens, cp + 1)); }
            else { fname = pkv(tokens, cp + 1); };
            let p2: i64 = cp + 2;
            let mut tname: str = "";
            let mut ctor_like: i64 = 0;
            if node_kind(pool, node) == 3 {
                tname = node_field(pool, node, 1);
                if str_len(tname) > 0 && str_len(fname) > 0 && str_char_at(tname, 0) >= 65 && str_char_at(tname, 0) <= 90 && str_char_at(fname, 0) >= 65 && str_char_at(fname, 0) <= 90 {
                    ctor_like = 1;
                };
            };
            if ctor_like == 1 && pk(tokens, p2) == 52 {
                let mut qp: i64 = p2 + 1;
                let mut qargs: Vec<i32> = Vec::new();
                while pk(tokens, qp) != 53 && pk(tokens, qp) != 0 {
                    if vec_len(qargs) > 0 {
                        qp = expect_tok(tokens, qp, 44);
                        if pk(tokens, qp) == 53 { break; };
                    };
                    let _field_name: str = pkv(tokens, qp);
                    qp = expect_tok(tokens, qp + 1, 42);
                    let mut er: Vec<i32> = parse_expr(tokens, qp, pool);
                    qargs.push(pr_val(er));
                    qp = pr_pos(er);
                };
                qp = expect_tok(tokens, qp, 53);
                cp = qp;
                node = mk4(pool, 12, tname, fname, mk_list(pool, qargs));
            } else if pk(tokens, p2) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, p2 + 1, pool);
                cp = pr_pos(ar); node = mk4(pool, 8, node, fname, pr_val(ar));
            } else if ctor_like == 1 {
                let mut empty: Vec<i32> = Vec::new();
                cp = p2;
                node = mk4(pool, 12, tname, fname, mk_list(pool, empty));
            } else { cp = p2; node = mk3(pool, 9, node, fname); };
        } else {
            let mut ir: Vec<i32> = parse_expr(tokens, cp + 1, pool);
            cp = expect_tok(tokens, pr_pos(ir), 55); node = mk3(pool, 10, node, pr_val(ir));
        };
        };
    };
    return pr(cp, node);
}

fn parse_unary(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    if pk(tokens, pos) == 21 { let mut r: Vec<i32> = parse_unary(tokens, pos + 1, pool); return pr(pr_pos(r), mk2(pool, 5, pr_val(r))); };
    if pk(tokens, pos) == 38 { let mut r: Vec<i32> = parse_unary(tokens, pos + 1, pool); return pr(pr_pos(r), mk2(pool, 6, pr_val(r))); };
    if pk(tokens, pos) == 22 {
        let mut r: Vec<i32> = parse_unary(tokens, pos + 1, pool);
        return pr(pr_pos(r), mk2(pool, 92, pr_val(r)));
    };
    if pk(tokens, pos) == 82 {
        let mut cp: i64 = pos + 1;
        let mut is_mut: i64 = 0;
        if pk(tokens, cp) == 12 { is_mut = 1; cp = cp + 1; };
        let mut r: Vec<i32> = parse_unary(tokens, cp, pool);
        if is_mut == 1 { return pr(pr_pos(r), mk2(pool, 91, pr_val(r))); };
        return pr(pr_pos(r), mk2(pool, 90, pr_val(r)));
    };
    let mut base: Vec<i32> = parse_postfix(tokens, pos, pool);
    let mut cp: i64 = pr_pos(base);
    let mut node: i64 = pr_val(base);
    // RFC-0015 phase 2: postfix `as TYPE` cast
    while pk(tokens, cp) == 86 {
        cp = cp + 1;
        let mut tr: Vec<i32> = parse_type(tokens, cp);
        cp = pr_pos(tr);
        // AST node kind 99 = "as cast"; field 1 = expr, field 2 = type name
        node = mk3(pool, 99, node, pr_val(tr));
    };
    return pr(cp, node);
}

fn parse_mul(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_unary(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 22 || pk(tokens, cp) == 23 || pk(tokens, cp) == 24 {
        let op: i64 = pk(tokens, cp); r = parse_unary(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, op, node, pr_val(r));
    };
    return pr(cp, node);
}
fn parse_add(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_mul(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 20 || pk(tokens, cp) == 21 {
        let op: i64 = pk(tokens, cp); r = parse_mul(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, op, node, pr_val(r));
    };
    return pr(cp, node);
}
// v0.3.104: shift tier — `<<` (token 115) and `>>` (parsed as two
// adjacent `>` tokens, so generic `Vec<Vec<T>>` keeps working).
// Between parse_add and parse_bitwise, matching Rust precedence:
// `* / %` > `+ -` > `<< >>` > `& ^ |` > `< > <= >=` > `== !=` > etc.
// tok_to_ir maps 115 → iop 16 (LLVM `shl i64`); the parser
// synthesizes a virtual `>>` token (kind 116) only at lower-time
// via mk4 → iop 17 (LLVM `ashr i64`) without touching the lexer.
fn parse_shift(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_add(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    let mut done: i64 = 0;
    while done == 0 {
        let tt: i64 = pk(tokens, cp);
        if tt == 115 {
            r = parse_add(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, 115, node, pr_val(r));
        } else if tt == 33 && pk(tokens, cp + 1) == 33 {
            r = parse_add(tokens, cp + 2, pool); cp = pr_pos(r); node = mk4(pool, 4, 116, node, pr_val(r));
        } else {
            done = 1;
        };
    };
    return pr(cp, node);
}

// v0.3.103: bitwise tier — `&` `^` `|` between `<<>>` and `< >` so
// that `a & b == c` parses as `(a & b) == c` (Rust precedence).
// All three ops share one tier here for simplicity. tok_to_ir maps
// `&` (tok 82) → iop 13 (LLVM `and i64`), `|` (tok 65) → iop 14
// (LLVM `or i64`), and `^` (tok 94) → iop 15 (LLVM `xor i64`).
// Disambiguates from logical `&&`/`||` because the lexer emits
// distinct tokens 36/37 for those — never tt == 82/65 here.
fn parse_bitwise(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_shift(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    let mut tt: i64 = pk(tokens, cp);
    while tt == 82 || tt == 65 || tt == 94 {
        r = parse_shift(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, tt, node, pr_val(r)); tt = pk(tokens, cp);
    };
    return pr(cp, node);
}
fn parse_cmp(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_bitwise(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    let mut tt: i64 = pk(tokens, cp);
    while tt == 32 || tt == 33 || tt == 34 || tt == 35 {
        r = parse_bitwise(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, tt, node, pr_val(r)); tt = pk(tokens, cp);
    };
    return pr(cp, node);
}
fn parse_eq(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_cmp(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 30 || pk(tokens, cp) == 31 {
        let op: i64 = pk(tokens, cp); r = parse_cmp(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, op, node, pr_val(r));
    };
    return pr(cp, node);
}

fn parse_and_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_eq(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 36 { r = parse_eq(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, 36, node, pr_val(r)); };
    return pr(cp, node);
}
fn parse_or_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_and_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 37 { r = parse_and_expr(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, 37, node, pr_val(r)); };
    return pr(cp, node);
}

fn parse_pipe_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_or_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r);
    let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 65 && pk(tokens, cp + 1) == 33 {
        let rp: i64 = cp + 2;
        if pk(tokens, rp) != 1 { return pr(rp, node); };
        let fname: str = pkv(tokens, rp);
        let rp2: i64 = rp + 1;
        let rp3: i64 = skip_angle_group(tokens, rp2);
        let mut piped_args: Vec<i32> = Vec::new();
        piped_args.push(node);
        if pk(tokens, rp3) == 50 {
            let mut ar: Vec<i32> = parse_args(tokens, rp3 + 1, pool);
            let alist: i64 = pr_val(ar);
            let ac: i64 = list_len(pool, alist);
            let mut ai: i64 = 0;
            while ai < ac {
                piped_args.push(list_get(pool, alist, ai));
                ai = ai + 1;
            };
            cp = pr_pos(ar);
        } else {
            cp = rp3;
        };
        node = mk3(pool, 7, fname, mk_list(pool, piped_args));
    };
    return pr(cp, node);
}

fn parse_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> { return parse_pipe_expr(tokens, pos, pool); }

fn parse_type(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    if pk(tokens, pos) == 82 {
        let mut cp: i64 = pos + 1;
        let mut prefix: str = "&";
        // T2.5 (v0.2.351): skip optional lifetime annotation `'a` after `&`.
        // Treated as advisory — does not appear in the parsed type string.
        if pk(tokens, cp) == 98 { cp = cp + 1; };
        if pk(tokens, cp) == 12 { prefix = "&mut "; cp = cp + 1; };
        let mut tr: Vec<i32> = parse_type(tokens, cp);
        return pr(pr_pos(tr), str_concat(prefix, pr_val(tr)));
    };
    if pk(tokens, pos) == 54 {
        let mut tr: Vec<i32> = parse_type(tokens, pos + 1);
        let mut cp: i64 = expect_tok(tokens, pr_pos(tr), 43);
        let len_s: str = if pk(tokens, cp) == 2 { str_from_int(pkv(tokens, cp)) } else { pkv(tokens, cp) };
        cp = expect_tok(tokens, cp + 1, 55);
        return pr(cp, str_concat("[", str_concat(pr_val(tr), str_concat("; ", str_concat(len_s, "]")))));
    };
    if pk(tokens, pos) == 50 {
        let mut cp: i64 = pos + 1;
        let mut inner: str = "";
        while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
            if str_len(inner) > 0 { cp = expect_tok(tokens, cp, 44); inner = str_concat(inner, ", "); };
            let mut tr: Vec<i32> = parse_type(tokens, cp);
            cp = pr_pos(tr);
            inner = str_concat(inner, pr_val(tr));
        };
        return pr(cp + 1, str_concat("(", str_concat(inner, ")")));
    };
    // v0.3.92: trait object syntax `dyn Trait` (and `Box<dyn Trait>`).
    // Skip the `dyn` keyword (lexed as identifier) and parse the
    // following Trait name as the type. Trait objects are
    // represented as i64-shaped fn-pointer-like values in Nucleor's
    // ABI (the existing dyn_box runtime helpers handle dispatch),
    // so we just need the parser to accept the syntax. Pre-v0.3.92,
    // `Box<dyn Greet>` cascaded into parse errors.
    if pk(tokens, pos) == 1 && str_eq(pkv(tokens, pos), "dyn") == 1 {
        let mut tr: Vec<i32> = parse_type(tokens, pos + 1);
        return pr(pr_pos(tr), pr_val(tr));
    };
    // v0.3.83: fn-pointer type syntax `fn(T1, T2) -> R`. Nucleor stores
    // function pointers as i64, so we consume the syntactic shape and
    // return "i64" — the existing fn-pointer/closure dispatch already
    // handles i64-typed callable values. Pre-v0.3.83, `fn(i64) -> i64`
    // in a parameter type position cascaded into 26+ parse errors.
    if pk(tokens, pos) == 10 {
        let mut cp: i64 = pos + 1;
        // Expect `(`
        if pk(tokens, cp) == 50 {
            cp = cp + 1;
            // Skip args: each arg is `parse_type` (no name needed).
            // Walk paren-balanced to allow nested fn types.
            let mut depth: i64 = 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 50 { depth = depth + 1; };
                if pk(tokens, cp) == 51 { depth = depth - 1; };
                cp = cp + 1;
            };
            // Optional `-> R` return type
            if pk(tokens, cp) == 41 {
                cp = cp + 1;
                let mut tr: Vec<i32> = parse_type(tokens, cp);
                cp = pr_pos(tr);
            };
        };
        return pr(cp, "i64");
    };
    let name: i64 = pkv(tokens, pos); let p2: i64 = pos + 1;
    if str_eq(name, "fixed") == 1 && pk(tokens, p2) == 32 {
        let mut cp: i64 = p2 + 1;
        let mut depth: i64 = 1;
        while depth > 0 && pk(tokens, cp) != 0 {
            if pk(tokens, cp) == 32 { depth = depth + 1; }
            else if pk(tokens, cp) == 33 { depth = depth - 1; };
            cp = cp + 1;
        };
        return pr(cp, "i64");
    };
    if str_eq(name, "unit") == 1 && pk(tokens, p2) == 32 {
        let mut cp: i64 = p2 + 1;
        let mut inner: Vec<i32> = parse_type(tokens, cp);
        let base_t: str = pr_val(inner);
        cp = pr_pos(inner);
        let mut depth: i64 = 1;
        while depth > 0 && pk(tokens, cp) != 0 {
            if pk(tokens, cp) == 32 { depth = depth + 1; }
            else if pk(tokens, cp) == 33 { depth = depth - 1; };
            cp = cp + 1;
        };
        return pr(cp, base_t);
    };
    if pk(tokens, p2) == 32 {
        // Generic type: Name<T1, T2, ...>
        // T2.5 (v0.2.351): accept lifetime args alongside type args.
        // Lifetime args are skipped from the resulting type string —
        // `Vec<'a, T>` parses as `Vec<T>` since codegen doesn't see
        // lifetime info. Real lifetime threading lands in T2.5b.
        let mut cp: i64 = p2 + 1;
        let mut type_parts: Vec<i32> = Vec::new();
        let mut first_arg: i64 = 1;
        while pk(tokens, cp) != 33 && pk(tokens, cp) != 0 {
            if first_arg == 0 {
                cp = expect_tok(tokens, cp, 44);
                if pk(tokens, cp) == 33 { break; };
            };
            first_arg = 0;
            if pk(tokens, cp) == 98 {
                // Skip lifetime arg.
                cp = cp + 1;
            } else {
                let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
                type_parts.push(pr_val(tr));
            };
        };
        let n: i64 = vec_len(type_parts);
        if n == 0 { return pr(cp + 1, name); };
        let mut inner: str = vec_get(type_parts, 0);
        let mut tpi: i64 = 1;
        while tpi < n {
            inner = str_concat(inner, str_concat(", ", vec_get(type_parts, tpi)));
            tpi = tpi + 1;
        };
        return pr(cp + 1, str_concat(name, str_concat("<", str_concat(inner, ">"))));
    };
    return pr(p2, name);
}

fn parse_generic_params(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    // pos points at '<', returns (pos_after_>, list of param name strings).
    // T2.5 (v0.2.351): accepts lifetime parameters (`'a`, `'static`, etc.)
    // alongside type parameters. Lifetime params get prepended with `'`
    // in the returned list so downstream consumers can distinguish them
    // (today no consumer does, but the marker is preserved for T2.5b).
    let mut cp: i64 = pos + 1;
    let mut params: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 33 && pk(tokens, cp) != 0 {
        if vec_len(params) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 33 { break; };
        };
        if pk(tokens, cp) == 98 {
            // Lifetime param — store as `'<name>` for traceability.
            params.push(str_concat("'", pkv(tokens, cp)));
        } else {
            params.push(pkv(tokens, cp));
        };
        cp = cp + 1;
    };
    cp = cp + 1; // skip >
    return pr(cp, params);
}

fn parse_let(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut is_mut: i64 = 0; let mut cp: i64 = pos;
    if pk(tokens, cp) == 12 { is_mut = 1; cp = cp + 1; };
    // v0.3.81 safety net: tuple-destructuring `let (a, b) = (5, 7);`
    // is not yet supported. Pre-v0.3.81, the parser read `(` as a
    // var name and downstream code segfaulted with ACCESS_VIOLATION
    // on a garbage string offset. Detect the open-paren and emit a
    // clear diagnostic, then skip past the destructure-stmt to
    // recover so the rest of the program still parses.
    if pk(tokens, cp) == 50 {
        print("ERROR: tuple destructuring in `let` is not yet supported (e.g. `let (a, b) = (5, 7);`). Workaround: bind to a struct or to two separate `let` statements: `let a: i64 = 5; let b: i64 = 7;`. Tracked for a future ship — tuple-pattern lowering needed.");
        // Skip ahead to next semicolon (43) for recovery.
        let mut sk: i64 = cp;
        while pk(tokens, sk) != 0 && pk(tokens, sk) != 43 { sk = sk + 1; };
        if pk(tokens, sk) == 43 { sk = sk + 1; };
        // Emit a placeholder let-stmt with a synthetic name so the
        // rest of the AST/codegen doesn't trip on the missing node.
        return pr(sk, mk5(pool, 20, "__tuple_destructure_unsupported__", 0, "", 0 - 1));
    };
    let name: i64 = pkv(tokens, cp); cp = cp + 1;
    let mut tstr: str = "";
    if pk(tokens, cp) == 42 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); tstr = pr_val(tr); };
    // v0.3.119: NUC-FEEDBACK-002 silent-miscompute defense.
    // `let v: Vec<f32> = …; v.push(1.0f32);` compiles cleanly today
    // but `let s: f32 = v[0]; f32_add(s, …)` produces 0 — the f32
    // bit pattern stored in the underlying i64 cell loses its type
    // tag through the vec_get → let-init chain, so the f32_add helper
    // operates on raw i64 storage. HIGH-blast for any ML/scientific
    // code reaching for narrow-float typed vectors. Real fix needs
    // expr_struct_type to propagate Vec element type through indexing
    // and let-init type propagation; until that lands, surface a hard
    // diagnostic for the broken types so adopters don't ship silently-
    // wrong tensor kernels.
    //
    // `Vec<f64>` is intentionally NOT in the rejected set — it works
    // correctly today because i64 storage cells naturally hold f64 bit
    // patterns via direct memory load (both are 64-bit). Many existing
    // fixtures (t330-t349) depend on `Vec<f64>` and would break.
    // The narrow-float family (`f32`, `f16`, `bf16`, `f8e4m3`, `f8e5m2`)
    // are all <64-bit and need the conversion-helper round-trip.
    if str_eq(tstr, "Vec<f32>") == 1
       || str_eq(tstr, "Vec<f16>") == 1
       || str_eq(tstr, "Vec<bf16>") == 1
       || str_eq(tstr, "Vec<f8e4m3>") == 1
       || str_eq(tstr, "Vec<f8e5m2>") == 1 {
        print(str_concat("ERROR: narrow-float vector `", str_concat(tstr, "` is not yet supported as user-facing storage. The push/get round-trip silently drops the float type tag and downstream f*_* helpers operate on raw i64 storage (returning 0). Workaround: store explicit float bit patterns in `Vec<i64>` and call the runtime helpers manually, or use `Vec<f64>` (which works today because both i64 cells and f64 are 64-bit), or `Tensor::*` for ML kernels (typed at the runtime level). Tracked as NUC-FEEDBACK-002 in docs/ML_SUITE_FEEDBACK_QUEUE.md.")));
    };
    let mut init_id: i64 = 0 - 1;
    if pk(tokens, cp) == 40 { let mut er: Vec<i32> = parse_expr(tokens, cp + 1, pool); cp = pr_pos(er); init_id = pr_val(er); };
    // v0.3.103: bitwise ops (`&`, `|`, `^`) are now supported via
    // parse_bitwise (between parse_eq and parse_and_expr). The
    // v0.3.97 diag-only stub is no longer needed — parse_expr
    // consumes the full bitwise expression, so there's nothing
    // left for next_after_rhs to detect.
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk5(pool, 20, name, is_mut, tstr, init_id));
}

fn parse_const_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = expect_tok(tokens, pos + 1, 42);
    let mut tr: Vec<i32> = parse_type(tokens, cp);
    cp = expect_tok(tokens, pr_pos(tr), 40);
    let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
    cp = pr_pos(er);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk4(pool, 50, name, pr_val(tr), pr_val(er)));
}

fn parse_type_alias_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = expect_tok(tokens, pos + 1, 40);
    let mut tr: Vec<i32> = parse_type(tokens, cp);
    cp = pr_pos(tr);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk3(pool, 51, name, pr_val(tr)));
}

fn parse_if(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // RFC-0016 sugar: `if let PATTERN = EXPR { THEN } else { ELSE }`
    // desugars to `match EXPR { PATTERN => { THEN }, _ => { ELSE } }`.
    // Supported patterns: Some(x), None, Ok(v), Err(e), EnumName::Variant[(b)].
    if pk(tokens, pos) == 11 {
        let mut ip: i64 = pos + 1;
        let mut ename: str = "";
        let mut vname: str = "";
        let mut binding: str = "";
        let pat_tt: i64 = pk(tokens, ip);
        if pat_tt == 1 && (str_eq(pkv(tokens, ip), "Some") == 1 || str_eq(pkv(tokens, ip), "None") == 1 || str_eq(pkv(tokens, ip), "Ok") == 1 || str_eq(pkv(tokens, ip), "Err") == 1) {
            vname = pkv(tokens, ip);
            if str_eq(vname, "Ok") == 1 || str_eq(vname, "Err") == 1 { ename = "Result"; }
            else { ename = "Option"; };
            ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 { binding = pkv(tokens, ip); ip = ip + 1; };
                ip = expect_tok(tokens, ip, 51);
            };
        } else if pat_tt == 1 && pk(tokens, ip + 1) == 46 {
            ename = pkv(tokens, ip);
            ip = expect_tok(tokens, ip + 1, 46);
            vname = pkv(tokens, ip); ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 { binding = pkv(tokens, ip); ip = ip + 1; };
                ip = expect_tok(tokens, ip, 51);
            };
        };
        if str_len(ename) > 0 {
            // We have a pattern; parse `= EXPR { BODY } [else { BODY }]`
            ip = expect_tok(tokens, ip, 40); // `=`
            let mut sr: Vec<i32> = parse_expr(tokens, ip, pool);
            let mut sp: i64 = expect_tok(tokens, pr_pos(sr), 52); // `{`
            let mut br: Vec<i32> = parse_stmts(tokens, sp, pool);
            sp = expect_tok(tokens, pr_pos(br), 53); // `}`
            let mut else_body: i64 = 0;
            if pk(tokens, sp) == 14 {
                sp = sp + 1;
                sp = expect_tok(tokens, sp, 52);
                let mut er: Vec<i32> = parse_stmts(tokens, sp, pool);
                sp = expect_tok(tokens, pr_pos(er), 53);
                else_body = pr_val(er);
            } else {
                let mut empty_stmts: Vec<i32> = Vec::new();
                else_body = mk_list(pool, empty_stmts);
            };
            // Build match arms: [PATTERN => then_body, _ => else_body]
            let mut arms: Vec<i32> = Vec::new();
            arms.push(mk6(pool, 39, ename, vname, binding, pr_val(br), 0));
            arms.push(mk6(pool, 39, "__wild", "", "", else_body, 0));
            return pr(sp, mk3(pool, 38, pr_val(sr), mk_list(pool, arms)));
        };
        // `let` not followed by a recognized pattern — fall through to plain if.
    };
    let mut cr: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = expect_tok(tokens, pr_pos(cr), 52);
    let mut tr: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(tr), 53);
    let mut else_id: i64 = 0 - 1;
    if pk(tokens, cp) == 14 {
        cp = cp + 1;
        if pk(tokens, cp) == 13 { cp = cp + 1;
            let mut elif: Vec<i32> = parse_if(tokens, cp, pool);
            let mut els: Vec<i32> = Vec::new(); els.push(pr_val(elif));
            else_id = mk_list(pool, els); cp = pr_pos(elif);
        } else {
            cp = expect_tok(tokens, cp, 52);
            let mut er: Vec<i32> = parse_stmts(tokens, cp, pool);
            cp = expect_tok(tokens, pr_pos(er), 53); else_id = pr_val(er);
        };
    };
    return pr(cp, mk4(pool, 23, pr_val(cr), pr_val(tr), else_id));
}

fn parse_while_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // RFC-0016 sugar: `while let PATTERN = EXPR { BODY }` desugars to
    // `loop { match EXPR { PATTERN => { BODY }, _ => break } }`.
    // For v0.1.16: implement as a while-true with an embedded match
    // that breaks on wildcard arm.
    if pk(tokens, pos) == 11 {
        let mut ip: i64 = pos + 1;
        let mut ename: str = "";
        let mut vname: str = "";
        let mut binding: str = "";
        let pat_tt: i64 = pk(tokens, ip);
        if pat_tt == 1 && (str_eq(pkv(tokens, ip), "Some") == 1 || str_eq(pkv(tokens, ip), "None") == 1 || str_eq(pkv(tokens, ip), "Ok") == 1 || str_eq(pkv(tokens, ip), "Err") == 1) {
            vname = pkv(tokens, ip);
            if str_eq(vname, "Ok") == 1 || str_eq(vname, "Err") == 1 { ename = "Result"; }
            else { ename = "Option"; };
            ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 { binding = pkv(tokens, ip); ip = ip + 1; };
                ip = expect_tok(tokens, ip, 51);
            };
        } else if pat_tt == 1 && pk(tokens, ip + 1) == 46 {
            ename = pkv(tokens, ip);
            ip = expect_tok(tokens, ip + 1, 46);
            vname = pkv(tokens, ip); ip = ip + 1;
            if pk(tokens, ip) == 50 {
                ip = ip + 1;
                if pk(tokens, ip) != 51 { binding = pkv(tokens, ip); ip = ip + 1; };
                ip = expect_tok(tokens, ip, 51);
            };
        };
        if str_len(ename) > 0 {
            ip = expect_tok(tokens, ip, 40); // `=`
            let mut sr: Vec<i32> = parse_expr(tokens, ip, pool);
            let mut sp: i64 = expect_tok(tokens, pr_pos(sr), 52); // `{`
            let mut br: Vec<i32> = parse_stmts(tokens, sp, pool);
            sp = expect_tok(tokens, pr_pos(br), 53); // `}`
            // Build break statement (node kind 26)
            let break_stmt: i64 = mk2(pool, 26, 0);
            let mut break_stmts: Vec<i32> = Vec::new();
            break_stmts.push(break_stmt);
            // Match arms: [PATTERN => body, _ => break]
            let mut arms: Vec<i32> = Vec::new();
            arms.push(mk6(pool, 39, ename, vname, binding, pr_val(br), 0));
            arms.push(mk6(pool, 39, "__wild", "", "", mk_list(pool, break_stmts), 0));
            let match_node: i64 = mk3(pool, 38, pr_val(sr), mk_list(pool, arms));
            // Wrap match in a stmt list to be the loop body
            let mut loop_body: Vec<i32> = Vec::new();
            loop_body.push(mk2(pool, 25, match_node));
            // True condition: literal 1
            let true_node: i64 = mk2(pool, 1, 1);
            return pr(sp, mk3(pool, 24, true_node, mk_list(pool, loop_body)));
        };
    };
    let mut cr: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = expect_tok(tokens, pr_pos(cr), 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    return pr(cp, mk3(pool, 24, pr_val(cr), pr_val(br)));
}

fn parse_for_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos is after 'for', pointing at variable name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = expect_tok(tokens, pos + 1, 57); // expect 'in'
    let mut sr: Vec<i32> = parse_expr(tokens, cp, pool);
    cp = pr_pos(sr);
    if pk(tokens, cp) == 58 {
        let mut er: Vec<i32> = parse_expr(tokens, cp + 1, pool); // end expr
        cp = expect_tok(tokens, pr_pos(er), 52); // expect '{'
        let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
        cp = expect_tok(tokens, pr_pos(br), 53); // expect '}'
        return pr(cp, mk5(pool, 28, name, pr_val(sr), pr_val(er), pr_val(br)));
    };
    if pk(tokens, cp) == 96 {
        // ..= inclusive: synthesize end+1 expression so existing exclusive
        // for-loop codegen handles it. Wrap end in (end + 1).
        let mut er: Vec<i32> = parse_expr(tokens, cp + 1, pool);
        let one_node: i64 = mk2(pool, 1, 1);
        let plus_node: i64 = mk4(pool, 4, 20, pr_val(er), one_node);
        cp = expect_tok(tokens, pr_pos(er), 52);
        let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
        cp = expect_tok(tokens, pr_pos(br), 53);
        return pr(cp, mk5(pool, 28, name, pr_val(sr), plus_node, pr_val(br)));
    };
    cp = expect_tok(tokens, cp, 52); // expect '{'
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53); // expect '}'
    return pr(cp, mk4(pool, 49, name, pr_val(sr), pr_val(br)));
}

fn parse_return_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    if pk(tokens, pos) == 43 { return pr(pos + 1, mk2(pool, 22, 0 - 1)); };
    let mut er: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(er);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk2(pool, 22, pr_val(er)));
}

fn parse_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let tt: i64 = pk(tokens, pos);
    if tt == 11 { return parse_let(tokens, pos + 1, pool); };
    if tt == 52 { let mut r: Vec<i32> = parse_passthrough_block_expr(tokens, pos, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 13 { let mut r: Vec<i32> = parse_if(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 15 { let mut r: Vec<i32> = parse_while_stmt(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 84 {
        // `loop { BODY }` desugars to `while true { BODY }`.
        let mut cp: i64 = expect_tok(tokens, pos + 1, 52);
        let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
        cp = expect_tok(tokens, pr_pos(br), 53);
        if pk(tokens, cp) == 43 { cp = cp + 1; };
        let true_node: i64 = mk2(pool, 1, 1);
        return pr(cp, mk3(pool, 24, true_node, pr_val(br)));
    };
    if tt == 56 { let mut r: Vec<i32> = parse_for_stmt(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 63 { let mut r: Vec<i32> = parse_match_stmt(tokens, pos + 1, pool); let mut cp: i64 = pr_pos(r); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, pr_val(r)); };
    if tt == 76 {
        let cp2: i64 = skip_bracket_list(tokens, pos + 1);
        let mut r: Vec<i32> = parse_passthrough_block_expr(tokens, cp2, pool);
        let mut cp: i64 = pr_pos(r);
        if pk(tokens, cp) == 43 { cp = cp + 1; };
        return pr(cp, pr_val(r));
    };
    if tt == 80 || tt == 81 {
        let mut r: Vec<i32> = parse_passthrough_block_expr(tokens, pos + 1, pool);
        let mut cp: i64 = pr_pos(r);
        if pk(tokens, cp) == 43 { cp = cp + 1; };
        return pr(cp, pr_val(r));
    };
    if tt == 16 { return parse_return_stmt(tokens, pos + 1, pool); };
    if tt == 18 { let mut cp: i64 = pos + 1; if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, mk2(pool, 26, 0)); };
    if tt == 19 { let mut cp: i64 = pos + 1; if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, mk2(pool, 27, 0)); };
    let mut er: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(er);
    if pk(tokens, cp) == 40 { let mut vr: Vec<i32> = parse_expr(tokens, cp + 1, pool); cp = pr_pos(vr); if pk(tokens, cp) == 43 { cp = cp + 1; }; return pr(cp, mk3(pool, 21, pr_val(er), pr_val(vr))); };
    // v0.3.77: compound assignment desugar. `x += y` → `x = x + y`,
    // and likewise for `-=` (111→21), `*=` (112→22), `/=` (113→23),
    // `%=` (114→24). LHS AST node is shared between the assign LHS and
    // the desugared binop LHS; this is safe because pool nodes are
    // immutable after creation and the lowering walks each AST exactly
    // once. For LHS forms with side effects (e.g. method calls in
    // future expansions), a real Get-Modify-Set lowering would be
    // required; today only var-ref / field-access / index LHS forms
    // are syntactically allowed, all of which are pure.
    let assign_tok: i64 = pk(tokens, cp);
    if assign_tok == 110 || assign_tok == 111 || assign_tok == 112 || assign_tok == 113 || assign_tok == 114
       || assign_tok == 117 || assign_tok == 118 || assign_tok == 119 || assign_tok == 120 || assign_tok == 121 {
        let mut vr: Vec<i32> = parse_expr(tokens, cp + 1, pool);
        cp = pr_pos(vr);
        if pk(tokens, cp) == 43 { cp = cp + 1; };
        let mut bin_op: i64 = 20;
        if assign_tok == 110 { bin_op = 20; };
        if assign_tok == 111 { bin_op = 21; };
        if assign_tok == 112 { bin_op = 22; };
        if assign_tok == 113 { bin_op = 23; };
        if assign_tok == 114 { bin_op = 24; };
        // v0.3.105: bitwise / shift compound assigns. Map to the
        // raw binop tokens so the existing tok_to_ir + parse_*
        // tier do the right thing at lowering — `&=` → `&` (82),
        // `|=` → `|` (65), `^=` → `^` (94), `<<=` → `<<` (115),
        // `>>=` → `>>` synthesized at lower-time as token 116.
        if assign_tok == 117 { bin_op = 82; };
        if assign_tok == 118 { bin_op = 65; };
        if assign_tok == 119 { bin_op = 94; };
        if assign_tok == 120 { bin_op = 115; };
        if assign_tok == 121 { bin_op = 116; };
        let rhs_node: i64 = mk4(pool, 4, bin_op, pr_val(er), pr_val(vr));
        return pr(cp, mk3(pool, 21, pr_val(er), rhs_node));
    };
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk2(pool, 25, pr_val(er)));
}

fn parse_stmts(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut items: Vec<i32> = Vec::new(); let mut cp: i64 = pos;
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        let mut r: Vec<i32> = parse_stmt(tokens, cp, pool); items.push(pr_val(r)); cp = pr_pos(r);
    };
    return pr(cp, mk_list(pool, items));
}

fn parse_fn_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    // Optional generic params: fn name<T, U>(...)
    let mut gparams: i64 = mk_list(pool, Vec::new());
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr);
        gparams = mk_list(pool, pr_val(gr));
    };
    cp = expect_tok(tokens, cp, 50); // (
    let mut params: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
        if vec_len(params) > 0 { cp = expect_tok(tokens, cp, 44); };
        let pn: i64 = pkv(tokens, cp); cp = expect_tok(tokens, cp + 1, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
        let ptype: str = pr_val(tr);
        // v0.3.93: detect &mut T parameter and emit a clear diagnostic.
        // Pre-v0.3.93, &mut T params silently passed by value (not by
        // reference), so any caller mutation via `*x = ...` was a no-op
        // — `add_one(&mut n)` returned without modifying caller's n.
        // Real implementation requires get/store-via-pointer codegen
        // (ptrtoint of alloca slot at call site, inttoptr+load/store
        // at deref). Until then, emit a clear error pointing at the
        // workaround.
        if str_len(ptype) >= 5 && str_eq(str_substring(ptype, 0, 5), "&mut ") == 1 {
            print(str_concat("ERROR: &mut reference parameter `", str_concat(pn, str_concat(": ", str_concat(ptype, "` in fn signature is not yet supported. Mutations via `*x = ...` would silently NOT propagate back to the caller. Workaround: return the new value (`fn foo(x: i64) -> i64 { return x + 1; }`) or use a `Vec<i64>` for shared state. Tracked for a future ship — get/store-via-pointer codegen needed.")))));
        };
        params.push(mk3(pool, 41, pn, ptype));
    };
    cp = cp + 1;
    let mut rtype: str = "void";
    if pk(tokens, cp) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); rtype = pr_val(tr); };
    if pk(tokens, cp) == 75 { cp = skip_bracket_list(tokens, cp + 1); };
    cp = skip_where_clause(tokens, cp);
    cp = expect_tok(tokens, cp, 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    return pr(cp, mk6(pool, 30, name, mk_list(pool, params), rtype, pr_val(br), gparams));
}

fn parse_extern_fn(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'extern fn', at the name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = expect_tok(tokens, pos + 1, 50);
    let mut params: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
        if vec_len(params) > 0 { cp = expect_tok(tokens, cp, 44); };
        let pn: i64 = pkv(tokens, cp); cp = expect_tok(tokens, cp + 1, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
        params.push(mk3(pool, 41, pn, pr_val(tr)));
    };
    cp = cp + 1;
    let mut rtype: str = "void";
    if pk(tokens, cp) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); rtype = pr_val(tr); };
    if pk(tokens, cp) == 75 { cp = skip_bracket_list(tokens, cp + 1); };
    cp = skip_where_clause(tokens, cp);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk4(pool, 32, name, mk_list(pool, params), rtype));
}

fn parse_struct_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'struct', at the name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    // Optional generic params: struct Name<T, U> { ... }
    let mut gparams: i64 = mk_list(pool, Vec::new());
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr);
        gparams = mk_list(pool, pr_val(gr));
    };
    cp = expect_tok(tokens, cp, 52); // {
    let mut fields: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if vec_len(fields) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 53 { break; };
        };
        let fn2: i64 = pkv(tokens, cp); cp = expect_tok(tokens, cp + 1, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
        fields.push(mk3(pool, 41, fn2, pr_val(tr)));
    };
    cp = cp + 1;
    return pr(cp, mk4(pool, 33, name, mk_list(pool, fields), gparams));
}

fn parse_struct_init(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points at name, next is {
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    cp = skip_angle_group(tokens, cp);
    cp = expect_tok(tokens, cp, 52);
    let mut inits: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if vec_len(inits) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 53 { break; };
        };
        let fn2: i64 = pkv(tokens, cp);
        // v0.3.90: shorthand struct init `Point { x, y }`. If the
        // next token after the field name is `,` (44) or `}` (53),
        // synthesize a var-ref expression with the same name as the
        // field (Rust shorthand `Point { x }` → `Point { x: x }`).
        // Without this, the parser called expect_tok(42) (`:`) and
        // failed when the user wrote shorthand.
        if pk(tokens, cp + 1) == 44 || pk(tokens, cp + 1) == 53 {
            let var_node: i64 = mk2(pool, 3, fn2);
            cp = cp + 1;
            inits.push(mk3(pool, 35, fn2, var_node));
        } else {
            cp = expect_tok(tokens, cp + 1, 42);
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool); cp = pr_pos(er);
            inits.push(mk3(pool, 35, fn2, pr_val(er)));
        };
    };
    cp = cp + 1;
    return pr(cp, mk3(pool, 34, name, mk_list(pool, inits)));
}

fn parse_enum_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'enum', at the name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    // Optional generic params: enum Name<T> { ... }
    let mut gparams: i64 = mk_list(pool, Vec::new());
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr);
        gparams = mk_list(pool, pr_val(gr));
    };
    cp = expect_tok(tokens, cp, 52); // {
    let mut variants: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if vec_len(variants) > 0 && pk(tokens, cp) == 44 { cp = cp + 1; };
        if pk(tokens, cp) == 53 || pk(tokens, cp) == 0 { break; };
        let vname: i64 = pkv(tokens, cp); cp = cp + 1;
        let mut ptypes: Vec<i32> = Vec::new();
        if pk(tokens, cp) == 50 {
            cp = cp + 1;
            while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
                if vec_len(ptypes) > 0 {
                    cp = expect_tok(tokens, cp, 44);
                    if pk(tokens, cp) == 51 { break; };
                };
                let mut tr: Vec<i32> = parse_type(tokens, cp); ptypes.push(pr_val(tr)); cp = pr_pos(tr);
            };
            cp = cp + 1;
        } else if pk(tokens, cp) == 52 {
            cp = cp + 1;
            while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
                if vec_len(ptypes) > 0 {
                    cp = expect_tok(tokens, cp, 44);
                    if pk(tokens, cp) == 53 { break; };
                };
                let _fname: str = pkv(tokens, cp);
                cp = expect_tok(tokens, cp + 1, 42);
                let mut tr: Vec<i32> = parse_type(tokens, cp);
                ptypes.push(pr_val(tr));
                cp = pr_pos(tr);
            };
            cp = expect_tok(tokens, cp, 53);
        };
        variants.push(mk3(pool, 37, vname, mk_list(pool, ptypes)));
    };
    cp = cp + 1;
    return pr(cp, mk4(pool, 36, name, mk_list(pool, variants), gparams));
}

fn parse_trait_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos points after 'trait', at the name
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = pos + 1;
    let mut gparams: i64 = mk_list(pool, Vec::new());
    if pk(tokens, cp) == 32 {
        let mut gr: Vec<i32> = parse_generic_params(tokens, cp);
        cp = pr_pos(gr); gparams = mk_list(pool, pr_val(gr));
    };
    // v0.3.110: supertrait syntax `trait Dog: Animal { ... }` and
    // `trait Foo: Bar + Baz { ... }`. Pre-v0.3.110, the parser
    // expected `{` right after the trait name, so the canonical
    // Rust form `trait Dog: Animal { ... }` cascaded into 13+
    // parse errors. Supertrait names are accepted but not yet
    // wired into method dispatch — adopters get the syntactic
    // freedom to express the relationship; trait inheritance
    // semantics (calling super-trait default methods through the
    // sub-trait) already work because the impl block separately
    // implements both traits and method dispatch resolves through
    // the impl_table. Skip ident, optional `+ ident` repeats, and
    // the optional `where` clause until `{`.
    if pk(tokens, cp) == 42 {
        cp = cp + 1;
        cp = cp + 1; // first super-trait name
        // Optional generic args on supertrait `Foo<T>` — skip the angle group.
        if pk(tokens, cp) == 32 { cp = skip_angle_group(tokens, cp); };
        while pk(tokens, cp) == 20 {
            cp = cp + 1;
            cp = cp + 1; // additional super-trait name
            if pk(tokens, cp) == 32 { cp = skip_angle_group(tokens, cp); };
        };
    };
    cp = skip_where_clause(tokens, cp);
    cp = expect_tok(tokens, cp, 52); // {
    let mut methods: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        // v0.3.85: associated constants in trait bodies aren't yet
        // supported. Pre-v0.3.85 the `const NAME: T;` line cascaded
        // into 18+ parse errors as expect_tok(fn) failed and the
        // recovery walked through the rest of the trait body
        // mis-aligned. Detect `const` (token 73) and skip to the
        // next stmt boundary with a clear diagnostic.
        if pk(tokens, cp) == 73 {
            print("ERROR: associated constants in traits are not yet supported (e.g. `trait T { const MAX: i64; }`). Workaround: declare the constant at module scope (`const MAX: i64 = 100;`) or as an inherent fn that returns the value. Tracked for a future ship.");
            while pk(tokens, cp) != 0 && pk(tokens, cp) != 43 && pk(tokens, cp) != 53 { cp = cp + 1; };
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            continue;
        };
        cp = expect_tok(tokens, cp, 10); // fn
        let mname: i64 = pkv(tokens, cp); cp = cp + 1;
        // v0.3.89: skip optional generic params on trait method
        // (`fn count<T>(self)` etc.). Pre-v0.3.89 this cascaded into
        // 22+ parse errors. The generic params are accepted but
        // discarded — Nucleor's trait dispatch is monomorphic-by-
        // mangled-name, and the generic types resolve at impl time.
        if pk(tokens, cp) == 32 {
            let mut depth: i64 = 1;
            cp = cp + 1;
            while depth > 0 && pk(tokens, cp) != 0 {
                if pk(tokens, cp) == 32 { depth = depth + 1; };
                if pk(tokens, cp) == 33 { depth = depth - 1; };
                cp = cp + 1;
            };
        };
        cp = expect_tok(tokens, cp, 50); // (
        let mut params: Vec<i32> = Vec::new();
        while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
            if vec_len(params) > 0 { cp = expect_tok(tokens, cp, 44); };
            // v0.3.106: `&self` / `&mut self` in trait method
            // declarations. Pre-v0.3.106 the trait parser only
            // recognized bare `self`, so the canonical Rust form
            // `fn say(&self)` cascaded into 13+ parse errors. Mirror
            // the parse_impl_block branch (line 1685) but use a
            // generic `&Self` / `&mut Self` type since no concrete
            // receiver type is known here.
            if pk(tokens, cp) == 82 {
                cp = cp + 1;
                let mut ptype: str = "&Self";
                if pk(tokens, cp) == 12 { ptype = "&mut Self"; cp = cp + 1; };
                let pn2: i64 = pkv(tokens, cp); cp = cp + 1;
                params.push(mk3(pool, 41, pn2, ptype));
            } else {
                let pn: i64 = pkv(tokens, cp); cp = cp + 1;
                if pk(tokens, cp) == 42 {
                    cp = cp + 1;
                    let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
                    params.push(mk3(pool, 41, pn, pr_val(tr)));
                } else {
                    params.push(mk3(pool, 41, pn, "Self"));
                };
            };
        };
        cp = cp + 1; // )
        let mut rtype: str = "void";
        if pk(tokens, cp) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); rtype = pr_val(tr); };
        if pk(tokens, cp) == 75 { cp = skip_bracket_list(tokens, cp + 1); };
        cp = skip_where_clause(tokens, cp);
        if pk(tokens, cp) == 52 {
            // Default method with body
            cp = cp + 1;
            let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
            cp = expect_tok(tokens, pr_pos(br), 53);
            methods.push(mk5(pool, 44, mname, mk_list(pool, params), rtype, pr_val(br)));
        } else {
            // Required method (no body)
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            methods.push(mk5(pool, 44, mname, mk_list(pool, params), rtype, 0 - 1));
        };
    };
    cp = cp + 1; // }
    return pr(cp, mk4(pool, 43, name, mk_list(pool, methods), gparams));
}

fn parse_impl_block(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // Supports both `impl Trait for Type { ... }` and `impl Type { ... }`
    let first_name: i64 = pkv(tokens, pos);
    let mut trait_name: str = "";
    let mut type_name: str = first_name;
    let mut cp: i64 = pos + 1;
    if pk(tokens, cp) == 56 {
        trait_name = first_name;
        type_name = pkv(tokens, cp + 1);
        cp = cp + 2;
    };
    cp = expect_tok(tokens, cp, 52); // {
    let mut methods: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        // v0.3.85: associated constants in impl bodies aren't yet
        // supported. Same diagnostic+recovery as trait body.
        if pk(tokens, cp) == 73 {
            print("ERROR: associated constants in impl blocks are not yet supported. Workaround: declare the constant at module scope or as an inherent fn that returns the value. Tracked for a future ship.");
            while pk(tokens, cp) != 0 && pk(tokens, cp) != 43 && pk(tokens, cp) != 53 { cp = cp + 1; };
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            continue;
        };
        cp = expect_tok(tokens, cp, 10); // fn
        let mname: i64 = pkv(tokens, cp);
        // Parse as fn_decl but handle self without type annotation
        let mut cp2: i64 = cp + 1;
        let mut mgparams: i64 = mk_list(pool, Vec::new());
        if pk(tokens, cp2) == 32 {
            let mut gr: Vec<i32> = parse_generic_params(tokens, cp2);
            cp2 = pr_pos(gr); mgparams = mk_list(pool, pr_val(gr));
        };
        cp2 = expect_tok(tokens, cp2, 50); // (
        let mut params: Vec<i32> = Vec::new();
        while pk(tokens, cp2) != 51 && pk(tokens, cp2) != 0 {
            if vec_len(params) > 0 { cp2 = expect_tok(tokens, cp2, 44); };
            if pk(tokens, cp2) == 82 {
                cp2 = cp2 + 1;
                let mut ptype: str = str_concat("&", type_name);
                if pk(tokens, cp2) == 12 { ptype = str_concat("&mut ", type_name); cp2 = cp2 + 1; };
                let pn2: i64 = pkv(tokens, cp2); cp2 = cp2 + 1;
                params.push(mk3(pool, 41, pn2, ptype));
            } else {
                let pn: i64 = pkv(tokens, cp2); cp2 = cp2 + 1;
                if str_eq(pn, "self") && pk(tokens, cp2) != 42 {
                // self without type annotation — inject type_name
                    params.push(mk3(pool, 41, pn, type_name));
                } else {
                    cp2 = expect_tok(tokens, cp2, 42); // :
                    let mut tr: Vec<i32> = parse_type(tokens, cp2); cp2 = pr_pos(tr);
                    params.push(mk3(pool, 41, pn, pr_val(tr)));
                };
            };
        };
        cp2 = cp2 + 1; // )
        let mut rtype: str = "void";
        if pk(tokens, cp2) == 41 { let mut tr: Vec<i32> = parse_type(tokens, cp2 + 1); cp2 = pr_pos(tr); rtype = pr_val(tr); };
        // v0.3.111: substitute `Self` (and `&Self` / `&mut Self`) in
        // the return type with the impl's actual `type_name`. Pre-
        // v0.3.111, `impl Point { fn new() -> Self { ... } }` left
        // rtype = "Self" verbatim, so the populate_fn_returns_in_sym
        // pass registered `__fnret_Point__new = "Self"`. Downstream,
        // expr_struct_type couldn't resolve "Self" to a known struct,
        // and the call result fell back to a zero placeholder. The
        // canonical Rust `fn new() -> Self` constructor pattern
        // silently miscomputed (returned 0 instead of the constructed
        // value). Param-side substitution already happens for
        // `&self` / `&mut self` at the param-loop above; this mirrors
        // it for the return slot.
        if str_eq(rtype, "Self") == 1 { rtype = type_name; };
        if str_eq(rtype, "&Self") == 1 { rtype = str_concat("&", type_name); };
        if str_eq(rtype, "&mut Self") == 1 { rtype = str_concat("&mut ", type_name); };
        if pk(tokens, cp2) == 75 { cp2 = skip_bracket_list(tokens, cp2 + 1); };
        cp2 = skip_where_clause(tokens, cp2);
        cp2 = expect_tok(tokens, cp2, 52); // {
        let mut br: Vec<i32> = parse_stmts(tokens, cp2, pool);
        cp2 = expect_tok(tokens, pr_pos(br), 53); // }
        methods.push(mk6(pool, 30, mname, mk_list(pool, params), rtype, pr_val(br), mgparams));
        cp = cp2;
    };
    cp = cp + 1; // }
    return pr(cp, mk4(pool, 45, trait_name, type_name, mk_list(pool, methods)));
}

fn parse_match_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    // pos is after 'match', at the expression
    let mut er: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = expect_tok(tokens, pr_pos(er), 52); // {
    let mut arms: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if vec_len(arms) > 0 && pk(tokens, cp) == 44 { cp = cp + 1; };
        if pk(tokens, cp) == 53 || pk(tokens, cp) == 0 { break; };
        let att: i64 = pk(tokens, cp);
        let mut ename: str = "";
        let mut vname: str = "";
        let mut binding: str = "";
        if att == 2 {
            // Integer literal pattern (token value is already i64).
            // T2.1 (v0.2.347): range patterns now wire through to the
            // long-existing lower-side __range / __range_bad handlers.
            // Encoding fits cleanly in the existing arm tuple:
            //   vname    = LO (i64 cell, raw int from token)
            //   binding  = str_from_int(HI) (string-encoded HI; lower
            //              side recovers via str_to_int)
            //   ename    = "__range" if LO <= HI, else "__range_bad"
            //   Half-open `LO..HI` normalizes to `LO..=(HI-1)`.
            // (Earlier worry about arm tuple fragility turned out to
            // be unfounded — the existing shape handles it fine.)
            let lo_val: i64 = pkv(tokens, cp);
            cp = cp + 1;
            let next_tok: i64 = pk(tokens, cp);
            if next_tok == 96 || next_tok == 58 {
                let inclusive: i64 = if next_tok == 96 { 1 } else { 0 };
                cp = cp + 1;
                if pk(tokens, cp) == 2 {
                    let hi_raw: i64 = pkv(tokens, cp);
                    cp = cp + 1;
                    let hi_norm: i64 = if inclusive == 1 { hi_raw } else { hi_raw - 1 };
                    if lo_val <= hi_norm {
                        ename = "__range";
                    } else {
                        ename = "__range_bad";
                    };
                    vname = lo_val;
                    binding = str_from_int(hi_norm);
                } else {
                    // Malformed range — fall back to plain int.
                    ename = "__int";
                    vname = lo_val;
                };
            } else {
                ename = "__int";
                vname = lo_val;
            };
        } else if att == 3 {
            // String literal pattern
            ename = "__str";
            vname = pkv(tokens, cp);
            cp = cp + 1;
        } else if att == 1 && str_eq(pkv(tokens, cp), "_") {
            // Wildcard pattern
            ename = "__wild";
            cp = cp + 1;
        } else if att == 1 && pk(tokens, cp + 1) == 46 {
            // Enum pattern: EnumName::Variant or EnumName::Variant(b1, b2, ...)
            // v0.3.86: multi-capture support — bindings separated by `|`
            // in the binding string (match_bind_payloads at line 9177
            // already handles this format).
            ename = pkv(tokens, cp);
            cp = expect_tok(tokens, cp + 1, 46); // ::
            vname = pkv(tokens, cp); cp = cp + 1;
            if pk(tokens, cp) == 50 {
                cp = cp + 1;
                let mut first: i64 = 1;
                while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
                    if first == 0 { cp = expect_tok(tokens, cp, 44); };
                    let bn: str = pkv(tokens, cp); cp = cp + 1;
                    if first == 1 { binding = bn; } else { binding = str_concat(binding, str_concat("|", bn)); };
                    first = 0;
                };
                cp = expect_tok(tokens, cp, 51); // )
            } else if pk(tokens, cp) == 52 {
                let mut br: Vec<i32> = parse_match_binding_block(tokens, cp + 1);
                binding = pr_val(br);
                cp = pr_pos(br);
            };
        } else if att == 1 && pk(tokens, cp + 1) == 45 {
            // Enum pattern: EnumName.Variant { binding }
            ename = pkv(tokens, cp);
            cp = cp + 2;
            vname = pkv(tokens, cp); cp = cp + 1;
            if pk(tokens, cp) == 50 {
                cp = cp + 1;
                binding = pkv(tokens, cp); cp = cp + 1;
                cp = expect_tok(tokens, cp, 51);
            } else if pk(tokens, cp) == 52 {
                let mut br: Vec<i32> = parse_match_binding_block(tokens, cp + 1);
                binding = pr_val(br);
                cp = pr_pos(br);
            };
        } else if att == 50 {
            // v0.3.106: tuple destructure pattern (`(x, y) => …`).
            // Pre-v0.3.106 the `(` fell into the catch-all else
            // branch which set ename="__wild" + binding="(", then
            // expect_tok(=>) on the inner `x` cascaded into 13+
            // parse errors AND silently returned 0 from the match
            // (HIGH-blast silent miscompute for any pattern-matching
            // code reaching for tuple destructure). Real tuple-arm
            // codegen needs payload-binding for tuple cells; until
            // that lands, surface a diagnostic and fast-skip to `=>`
            // so the rest of the body parses cleanly. Workaround:
            // wildcard `_` and access tuple fields via `.0` / `.1`.
            print("ERROR: tuple destructure patterns in match (e.g. `(x, y) => …`) are not yet supported. Workaround: use `_ =>` and access tuple fields explicitly via `.0` / `.1` (`match p { _ => return p.0 + p.1, };`). Tracked for a future ship.");
            while pk(tokens, cp) != 64 && pk(tokens, cp) != 0 && pk(tokens, cp) != 53 { cp = cp + 1; };
            ename = "__wild";
        } else if att == 1 && (str_eq(pkv(tokens, cp), "Some") == 1 || str_eq(pkv(tokens, cp), "None") == 1 || str_eq(pkv(tokens, cp), "Ok") == 1 || str_eq(pkv(tokens, cp), "Err") == 1) {
            vname = pkv(tokens, cp);
            if str_eq(vname, "Ok") == 1 || str_eq(vname, "Err") == 1 { ename = "Result"; }
            else { ename = "Option"; };
            cp = cp + 1;
            if pk(tokens, cp) == 50 {
                cp = cp + 1;
                if pk(tokens, cp) != 51 { binding = pkv(tokens, cp); cp = cp + 1; };
                cp = expect_tok(tokens, cp, 51);
            } else if pk(tokens, cp) == 52 {
                let mut br: Vec<i32> = parse_match_binding_block(tokens, cp + 1);
                binding = pr_val(br);
                cp = pr_pos(br);
            };
        } else {
            // Identifier as value pattern (variable binding like wildcard)
            ename = "__wild";
            binding = pkv(tokens, cp);
            cp = cp + 1;
        };
        // Optional guard: if condition
        let mut guard_nid: i64 = 0;
        if pk(tokens, cp) == 13 {
            cp = cp + 1;
            let mut gr: Vec<i32> = parse_expr(tokens, cp, pool);
            cp = pr_pos(gr);
            guard_nid = pr_val(gr);
        };
        cp = expect_tok(tokens, cp, 64); // =>
        let mut body_list: i64 = 0;
        if pk(tokens, cp) == 52 {
            cp = cp + 1;
            let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
            cp = expect_tok(tokens, pr_pos(br), 53); // }
            body_list = pr_val(br);
        } else if pk(tokens, cp) == 16 {
            // v0.3.79: arm body `return EXPR` — Rust-style. Parse as a
            // return stmt (kind 22) so the lowering treats it as a
            // divergent stmt rather than an expression. Pre-v0.3.79 this
            // hit parse_expr(return ...) which failed silently and left
            // cp parked on `return`, producing the cascading "expected
            // token 64 got 44/16" parse errors as the next arm's
            // pattern-parse re-entered partway through the previous
            // arm's body.
            cp = cp + 1;
            let mut rstmts: Vec<i32> = Vec::new();
            if pk(tokens, cp) == 43 {
                rstmts.push(mk2(pool, 22, 0 - 1));
                cp = cp + 1;
            } else {
                let mut rer: Vec<i32> = parse_expr(tokens, cp, pool);
                cp = pr_pos(rer);
                rstmts.push(mk2(pool, 22, pr_val(rer)));
            };
            body_list = mk_list(pool, rstmts);
        } else if pk(tokens, cp) == 18 {
            // v0.3.79: arm body `break;` (or bare `break`).
            cp = cp + 1;
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            let mut bstmts: Vec<i32> = Vec::new();
            bstmts.push(mk2(pool, 26, 0));
            body_list = mk_list(pool, bstmts);
        } else if pk(tokens, cp) == 19 {
            // v0.3.79: arm body `continue;` (or bare `continue`).
            cp = cp + 1;
            if pk(tokens, cp) == 43 { cp = cp + 1; };
            let mut cstmts: Vec<i32> = Vec::new();
            cstmts.push(mk2(pool, 27, 0));
            body_list = mk_list(pool, cstmts);
        } else {
            // v0.3.84: detect assignment LHS = RHS in arm body. Pre-v0.3.84,
            // parse_expr stopped at `=` and the result wrapped as kind 25
            // (expression-stmt) — the `= RHS` was silently dropped, so
            // `total = v` arm bodies became no-op expression-stmts of just
            // `total`. Now: parse the LHS expression, then if next token is
            // `=` (40), parse the RHS and produce a kind 21 (assign) stmt.
            // Mirrors parse_stmt's expr-stmt-or-assign discrimination.
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
            cp = pr_pos(er);
            let mut stmts: Vec<i32> = Vec::new();
            if pk(tokens, cp) == 40 {
                let mut vr: Vec<i32> = parse_expr(tokens, cp + 1, pool);
                cp = pr_pos(vr);
                stmts.push(mk3(pool, 21, pr_val(er), pr_val(vr)));
            } else {
                stmts.push(mk2(pool, 25, pr_val(er)));
            };
            body_list = mk_list(pool, stmts);
        };
        arms.push(mk6(pool, 39, ename, vname, binding, body_list, guard_nid));
    };
    cp = cp + 1;
    return pr(cp, mk3(pool, 38, pr_val(er), mk_list(pool, arms)));
}

fn has_main_decl(pool: Vec<i32>, items: Vec<i32>) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(items) {
        let nid: i64 = vec_get(items, i);
        if node_kind(pool, nid) == 30 && str_eq(node_field(pool, nid, 1), "main") { return 1; };
        i = i + 1;
    };
    return 0;
}

fn remove_main_decl(pool: Vec<i32>, items: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(items) {
        let nid: i64 = vec_get(items, i);
        let mut keep: i64 = 1;
        if node_kind(pool, nid) == 30 && str_eq(node_field(pool, nid, 1), "main") { keep = 0; };
        if node_kind(pool, nid) == 46 && str_eq(node_field(pool, nid, 1), "main") { keep = 0; };
        if keep == 1 { out.push(nid); };
        i = i + 1;
    };
    return out;
}

fn parse_program(tokens: Vec<i32>, pool: Vec<i32>) -> Vec<i32> {
    let mut items: Vec<i32> = Vec::new(); let mut cp: i64 = 0;
    // T1.5b (v0.2.341): track `pub` keyword on top-level items.
    // Previously the `pub` token was silently swallowed. Now: when
    // we see `pub`, we set `pending_pub = 1` and re-enter the loop
    // without consuming any item. The next item we successfully
    // parse gets a marker node (kind 76 = pub_marker) emitted into
    // `items` immediately before the item itself, mirroring the
    // pattern already established for `pure fn` (kind 46). The
    // marker carries the item's name so downstream tools (the
    // visibility surface in `nuc summary`, the `nuc abi --exports`
    // walker, and T1.5c's resolver-layer enforcement) can identify
    // pub items without re-walking the source text.
    let mut pending_pub: i64 = 0;
    while pk(tokens, cp) != 0 {
        if pk(tokens, cp) == 72 {
            pending_pub = 1;
            cp = cp + 1;
        }
        else if pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 10 {
            // extern fn — never carries `pub` (extern is its own visibility).
            let mut r: Vec<i32> = parse_extern_fn(tokens, cp + 2, pool); items.push(pr_val(r)); cp = pr_pos(r);
            pending_pub = 0;
        }
        else if pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 3 && pk(tokens, cp + 2) == 10 {
            // v0.3.112: `extern "C" fn name(...)` (or any ABI string).
            // Pre-v0.3.112, the parser only recognized bare `extern fn`,
            // so the canonical Rust form `extern "C" fn abs(x: i64) -> i64;`
            // cascaded into 4+ parse errors. The ABI string is accepted
            // and discarded — Nucleor's only ABI today is the C calling
            // convention used by all extern declarations, so the explicit
            // marker is informational. Skip ABI literal then call into
            // parse_extern_fn at the `fn` token.
            let mut r: Vec<i32> = parse_extern_fn(tokens, cp + 3, pool); items.push(pr_val(r)); cp = pr_pos(r);
            pending_pub = 0;
        }
        else if pk(tokens, cp) == 73 {
            let mut r: Vec<i32> = parse_const_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 74 {
            let mut r: Vec<i32> = parse_type_alias_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 17 {
            let mut r: Vec<i32> = parse_struct_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 62 {
            let mut r: Vec<i32> = parse_enum_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 66 {
            let mut r: Vec<i32> = parse_trait_decl(tokens, cp + 1, pool);
            let nid: i64 = pr_val(r);
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, nid, 1))); pending_pub = 0; };
            items.push(nid); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 67 {
            // impl blocks don't carry pub (the items inside do).
            let mut r: Vec<i32> = parse_impl_block(tokens, cp + 1, pool); items.push(pr_val(r)); cp = pr_pos(r);
            pending_pub = 0;
        }
        else if pk(tokens, cp) == 68 && pk(tokens, cp + 1) == 10 {
            // pure fn — parse as fn_decl, mark name with __pure_ prefix internally
            let mut r: Vec<i32> = parse_fn_decl(tokens, cp + 2, pool);
            let fn_nid: i64 = pr_val(r);
            if str_eq(node_field(pool, fn_nid, 1), "main") == 1 && has_main_decl(pool, items) == 1 { items = remove_main_decl(pool, items); };
            // Tag function as pure by storing a marker node (kind 46).
            items.push(mk2(pool, 46, node_field(pool, fn_nid, 1)));
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, fn_nid, 1))); pending_pub = 0; };
            items.push(fn_nid);
            cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 10 {
            let mut r: Vec<i32> = parse_fn_decl(tokens, cp + 1, pool);
            let fn_nid: i64 = pr_val(r);
            if str_eq(node_field(pool, fn_nid, 1), "main") == 1 && has_main_decl(pool, items) == 1 { items = remove_main_decl(pool, items); };
            if pending_pub == 1 { items.push(mk2(pool, 76, node_field(pool, fn_nid, 1))); pending_pub = 0; };
            items.push(fn_nid);
            cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 11 {
            // v0.3.73: `let` is a statement-level binding — it cannot
            // appear at module scope. Pre-v0.3.73, the parser silently
            // skipped the entire `let NAME: T = EXPR;` token-by-token
            // and downstream codegen emitted `@NAME` references that
            // failed at clang link with "use of undefined value '@NAME'"
            // when main referenced the binding. Surface a clear
            // diagnostic with the canonical workaround (`const`) and
            // skip the let-stmt cleanly so the rest of the program
            // still parses for any other diagnostics the user needs.
            print("ERROR: `let` is not allowed at module scope. Use `const NAME: T = VALUE;` for module-scope constants. (`let` is statement-only — the parser previously dropped this declaration silently and emitted broken IR.)");
            // Skip ahead to the next semicolon (token kind 43) to recover.
            let mut sk: i64 = cp + 1;
            while pk(tokens, sk) != 0 && pk(tokens, sk) != 43 { sk = sk + 1; };
            if pk(tokens, sk) == 43 { sk = sk + 1; };
            cp = sk;
            pending_pub = 0;
        }
        else if pk(tokens, cp) == 13 || pk(tokens, cp) == 15 || pk(tokens, cp) == 16 || pk(tokens, cp) == 18 || pk(tokens, cp) == 19 || pk(tokens, cp) == 56 || pk(tokens, cp) == 63 || pk(tokens, cp) == 84 {
            // v0.3.75: catch other statement-level keywords at module
            // scope. `if` (13), `while` (15), `return` (16), `break` (18),
            // `continue` (19), `for` (56), `match` (63), `loop` (84) all
            // belong inside fn bodies — at module scope they have no
            // meaning and the pre-v0.3.75 silent fall-through dropped
            // them token-by-token. Surface a clear diagnostic so the
            // user sees their malformed top-level construct named
            // explicitly. Recovery: skip to the next semicolon (43)
            // OR the next opening brace (40) — whichever comes first
            // — so block-form constructs (`if/while/loop { ... }`)
            // get cleaned up in one go rather than dribbling broken
            // body tokens through the rest of the program.
            print("ERROR: statement-level keyword at module scope. Only `fn`, `extern fn`, `pure fn`, `const`, `type`, `struct`, `enum`, `trait`, `impl`, and `pub` (with the above) are allowed as top-level items. Move statement-level constructs into a fn body.");
            let mut sk: i64 = cp + 1;
            while pk(tokens, sk) != 0 && pk(tokens, sk) != 43 && pk(tokens, sk) != 40 { sk = sk + 1; };
            if pk(tokens, sk) == 43 { sk = sk + 1; };
            // For a `{`-terminated form (e.g. `if c { ... }`), skip to
            // the matching close brace (41) so the block body doesn't
            // keep producing diagnostics. Tracks brace depth.
            if pk(tokens, sk) == 40 {
                let mut depth: i64 = 1;
                sk = sk + 1;
                while pk(tokens, sk) != 0 && depth > 0 {
                    if pk(tokens, sk) == 40 { depth = depth + 1; };
                    if pk(tokens, sk) == 41 { depth = depth - 1; };
                    sk = sk + 1;
                };
            };
            cp = sk;
            pending_pub = 0;
        }
        else { cp = cp + 1; pending_pub = 0; };
    };
    return pr(cp, mk_list(pool, items));
}

// =====================================================
// IR DATA STRUCTURES (from T29, extended)
// =====================================================
fn ir_inst(op: i64, d: i64, tid: i64, o1: i64, o2: i64, ex: i64) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::new(); ii.push(op); ii.push(d); ii.push(tid); ii.push(o1); ii.push(o2); ii.push(ex); return ii;
}
fn ir_op(ii: Vec<i32>) -> i64 { return vec_get(ii, 0); }
fn ir_dest(ii: Vec<i32>) -> i64 { return vec_get(ii, 1); }
fn ir_op1(ii: Vec<i32>) -> i64 { return vec_get(ii, 3); }
fn ir_op2(ii: Vec<i32>) -> i64 { return vec_get(ii, 4); }
fn ir_extra(ii: Vec<i32>) -> i64 { return vec_get(ii, 5); }

fn ir_const_int(d: i64, v: i64) -> Vec<i32> { return ir_inst(0, d, 0, v, 0, 0); }
fn ir_binop(iop: i64, d: i64, a: i64, b: i64) -> Vec<i32> { return ir_inst(iop, d, 0, a, b, 0); }
fn ir_cmpop(iop: i64, d: i64, a: i64, b: i64) -> Vec<i32> { return ir_inst(iop, d, 0, a, b, 0); }
fn ir_alloca(d: i64) -> Vec<i32> { return ir_inst(16, d, 0, 0, 0, 0); }
fn ir_load(d: i64, ptr: i64) -> Vec<i32> { return ir_inst(17, d, 0, ptr, 0, 0); }
fn ir_store(v: i64, ptr: i64) -> Vec<i32> { return ir_inst(18, 0, 0, v, ptr, 0); }
fn ir_ret(v: i64) -> Vec<i32> { return ir_inst(20, 0, 0, v, 0, 0); }
fn ir_br(lbl: i64) -> Vec<i32> { return ir_inst(21, 0, 0, lbl, 0, 0); }
fn ir_br_cond(cond: i64, t: i64, f: i64) -> Vec<i32> { return ir_inst(22, 0, 0, cond, t, f); }
fn ir_param_ref(d: i64, pidx: i64) -> Vec<i32> { return ir_inst(26, d, 0, pidx, 0, 0); }
fn ir_const_str(d: i64, str_idx: i64) -> Vec<i32> { return ir_inst(27, d, 0, str_idx, 0, 0); }
fn ir_call_ex(d: i64, fn_name: str, args: Vec<i32>) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::new();
    ii.push(19); ii.push(d); ii.push(0); ii.push(fn_name); ii.push(vec_len(args)); ii.push(args);
    return ii;
}

// v0.3.126: ir_user_call — bypass the runtime-helper name lookup
// in emit_inst so a user-defined fn that happens to share a name
// with a runtime helper (e.g. user `pow(base, exp)`) dispatches
// to `@pow` (the user-emitted definition) instead of being
// hijacked by `@__nucleor_pow` (the f64 floating-point helper).
// Pre-v0.3.126 the runtime helper always won — silent miscompute
// with NO diagnostic for the very-common pattern of writing a
// math helper named the same as a builtin.
fn ir_user_call(d: i64, fn_name: str, args: Vec<i32>) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::new();
    ii.push(31); ii.push(d); ii.push(0); ii.push(fn_name); ii.push(vec_len(args)); ii.push(args);
    return ii;
}

fn ir_fn_ptr(d: i64, fn_name: str) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::new();
    ii.push(29); ii.push(d); ii.push(0); ii.push(fn_name); ii.push(0); ii.push(0);
    return ii;
}
fn ir_indirect_call(d: i64, closure_reg: i64, args: Vec<i32>) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::new();
    ii.push(30); ii.push(d); ii.push(0); ii.push(closure_reg); ii.push(vec_len(args)); ii.push(args);
    return ii;
}

fn ir_block_new(lbl: i64) -> Vec<i32> {
    let mut b: Vec<i32> = Vec::new(); b.push(lbl);
    let mut insts: Vec<i32> = Vec::new(); b.push(insts); return b;
}
fn ir_block_label(b: Vec<i32>) -> i64 { return vec_get(b, 0); }
fn ir_block_add(b: Vec<i32>, inst: Vec<i32>) -> i64 { let mut insts: Vec<i32> = vec_get(b, 1); insts.push(inst); return 0; }
fn ir_block_inst_count(b: Vec<i32>) -> i64 { let insts: Vec<i32> = vec_get(b, 1); return vec_len(insts); }
fn ir_block_get_inst(b: Vec<i32>, idx: i64) -> Vec<i32> { let insts: Vec<i32> = vec_get(b, 1); return vec_get(insts, idx); }

fn ir_fn_new(name: str, pc: i64) -> Vec<i32> {
    let mut f: Vec<i32> = Vec::new(); f.push(name); f.push(pc);
    let mut entry_allocas: Vec<i32> = Vec::new(); f.push(entry_allocas);
    let mut blocks: Vec<i32> = Vec::new(); f.push(blocks); return f;
}
fn ir_fn_name(f: Vec<i32>) -> str { return vec_get(f, 0); }
fn ir_fn_param_count(f: Vec<i32>) -> i64 { return vec_get(f, 1); }
fn ir_fn_add_block(f: Vec<i32>, blk: Vec<i32>) -> i64 { let mut b: Vec<i32> = vec_get(f, 3); b.push(blk); return 0; }
fn ir_fn_block_count(f: Vec<i32>) -> i64 { let b: Vec<i32> = vec_get(f, 3); return vec_len(b); }
fn ir_fn_get_block(f: Vec<i32>, idx: i64) -> Vec<i32> { let b: Vec<i32> = vec_get(f, 3); return vec_get(b, idx); }
fn ir_fn_add_entry_alloca(f: Vec<i32>, reg: i64) -> i64 {
    let mut ea: Vec<i32> = vec_get(f, 2);
    ea.push(ir_alloca(reg));
    return 0;
}

fn block_has_term(blk: Vec<i32>) -> i64 {
    let ic: i64 = ir_block_inst_count(blk);
    if ic == 0 { return 0; };
    let op: i64 = ir_op(ir_block_get_inst(blk, ic - 1));
    if op == 20 || op == 21 || op == 22 { return 1; }; return 0;
}

// =====================================================
// OPTIMIZER PASSES (S6)
// =====================================================

// --- Constant map: tracks register -> constant value ---
fn cmap_new() -> Vec<i32> { let mut m: Vec<i32> = Vec::new(); return m; }
fn cmap_set(m: Vec<i32>, reg: i64, val: i64) -> i64 {
    let mc: i64 = vec_len(m);
    let mut i: i64 = 0;
    while i < mc {
        if vec_get(m, i) == reg { vec_set(m, i + 1, val); return 0; };
        i = i + 2;
    };
    m.push(reg); m.push(val); return 0;
}
fn cmap_get(m: Vec<i32>, reg: i64) -> i64 {
    let mc: i64 = vec_len(m);
    let mut i: i64 = 0;
    while i < mc {
        if vec_get(m, i) == reg { return vec_get(m, i + 1); };
        i = i + 2;
    };
    return 0 - 9999999;
}
fn cmap_has(m: Vec<i32>, reg: i64) -> i64 {
    let mc: i64 = vec_len(m);
    let mut i: i64 = 0;
    while i < mc {
        if vec_get(m, i) == reg { return 1; };
        i = i + 2;
    };
    return 0;
}

// --- Pass 1: Constant Folding ---
// Scans instructions in a block. When both operands of an arithmetic/comparison
// op are known constants, replaces the instruction with a const_int.
fn opt_fold_block(blk: Vec<i32>) -> i64 {
    let mut cm: Vec<i32> = cmap_new();
    let ic: i64 = ir_block_inst_count(blk);
    let insts: Vec<i32> = vec_get(blk, 1);
    let mut folded: i64 = 0;
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        // Track const_int values
        if op == 0 {
            cmap_set(cm, d, ir_op1(inst));
        }
        // Fold arithmetic: add(2), sub(3), mul(4), div(5), mod(6)
        else if op >= 2 && op <= 6 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                let mut result: i64 = 0;
                if op == 2 { result = va + vb; }
                else if op == 3 { result = va - vb; }
                else if op == 4 { result = va * vb; }
                else if op == 5 { if vb != 0 { result = va / vb; } else { i = i + 1; }; }
                else if op == 6 { if vb != 0 { result = va - (va / vb) * vb; } else { i = i + 1; }; };
                // Replace instruction with const_int
                vec_set(inst, 0, 0);
                vec_set(inst, 3, result);
                vec_set(inst, 4, 0);
                vec_set(inst, 5, 0);
                cmap_set(cm, d, result);
                folded = folded + 1;
            };
        }
        // Fold comparisons: eq(7), ne(8), slt(9), sgt(10), sle(11), sge(12)
        else if op >= 7 && op <= 12 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                let mut result: i64 = 0;
                if op == 7 { if va == vb { result = 1; }; }
                else if op == 8 { if va != vb { result = 1; }; }
                else if op == 9 { if va < vb { result = 1; }; }
                else if op == 10 { if va > vb { result = 1; }; }
                else if op == 11 { if va <= vb { result = 1; }; }
                else if op == 12 { if va >= vb { result = 1; }; };
                vec_set(inst, 0, 0);
                vec_set(inst, 3, result);
                vec_set(inst, 4, 0);
                vec_set(inst, 5, 0);
                cmap_set(cm, d, result);
                folded = folded + 1;
            };
        }
        // v0.3.103: Fold bitwise: and(13), or(14), xor(15). Pre-v0.3.103
        // ops 13/14 were folded with LOGICAL semantics (`va != 0 && vb != 0`
        // → 1 or 0), which matched the historical interpretation of
        // these iops as `&&`/`||`. But the runtime LLVM emit for these
        // iops is `and i64`/`or i64` — pure bitwise — so the const-fold
        // was diverging from what the un-folded code would compute. With
        // bitwise `&` `|` `^` now wired through these iops too, fold
        // bitwise so both paths produce identical answers for constant
        // inputs (e.g. 255 & 15 → 15, not 1 from "both truthy").
        else if op == 13 || op == 14 || op == 15 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                let mut result: i64 = 0;
                // Use sym_get's hash-style int-pair AND emulation: Nucleor
                // doesn't expose a `&` operator at this self-host level
                // either (chicken-and-egg), so do it via while-shift.
                if op == 13 {
                    let mut acc: i64 = 0;
                    let mut bit: i64 = 1;
                    let mut ra: i64 = va;
                    let mut rb: i64 = vb;
                    let mut k: i64 = 0;
                    while k < 64 {
                        if ra - (ra / 2) * 2 == 1 && rb - (rb / 2) * 2 == 1 { acc = acc + bit; };
                        ra = ra / 2; rb = rb / 2; bit = bit + bit;
                        k = k + 1;
                    };
                    result = acc;
                } else if op == 14 {
                    let mut acc: i64 = 0;
                    let mut bit: i64 = 1;
                    let mut ra: i64 = va;
                    let mut rb: i64 = vb;
                    let mut k: i64 = 0;
                    while k < 64 {
                        if ra - (ra / 2) * 2 == 1 || rb - (rb / 2) * 2 == 1 { acc = acc + bit; };
                        ra = ra / 2; rb = rb / 2; bit = bit + bit;
                        k = k + 1;
                    };
                    result = acc;
                } else {
                    let mut acc: i64 = 0;
                    let mut bit: i64 = 1;
                    let mut ra: i64 = va;
                    let mut rb: i64 = vb;
                    let mut k: i64 = 0;
                    while k < 64 {
                        let bita: i64 = ra - (ra / 2) * 2;
                        let bitb: i64 = rb - (rb / 2) * 2;
                        if bita != bitb { acc = acc + bit; };
                        ra = ra / 2; rb = rb / 2; bit = bit + bit;
                        k = k + 1;
                    };
                    result = acc;
                };
                vec_set(inst, 0, 0);
                vec_set(inst, 3, result);
                vec_set(inst, 4, 0);
                vec_set(inst, 5, 0);
                cmap_set(cm, d, result);
                folded = folded + 1;
            };
        };
        i = i + 1;
    };
    return folded;
}

// --- Pass 2: Dead Code Elimination ---
// Removes instructions whose dest register is never used by any later instruction.
// Side-effecting ops (store, call, ret, br, br_cond, alloca) are never removed.
fn opt_dce_block(blk: Vec<i32>) -> i64 {
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    if ic == 0 { return 0; };
    let last_op: i64 = ir_op(vec_get(insts, ic - 1));
    // This pass is block-local only. Once a block branches, its pure values may
    // still be consumed in successor blocks, so intra-block liveness is unsafe.
    if last_op == 21 || last_op == 22 { return 0; };
    // Build used-register set: scan all instructions for operand references
    let mut used: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        // Collect register operands that are used
        if op >= 2 && op <= 15 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        else if op == 23 || op == 24 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        else if op == 17 { used.push(ir_op1(inst)); }
        else if op == 18 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        else if op == 20 { used.push(ir_op1(inst)); }
        else if op == 22 { used.push(ir_op1(inst)); }
        else if op == 28 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); used.push(ir_extra(inst)); }
        else if op == 30 { used.push(ir_op1(inst)); let cargs: Vec<i32> = vec_get(inst, 5); let mut ci: i64 = 0; while ci < vec_len(cargs) { used.push(vec_get(cargs, ci)); ci = ci + 1; }; }
        else if op == 19 || op == 31 {
            // Call: args are in the args Vec (index 5)
            let args: Vec<i32> = vec_get(inst, 5);
            let ac: i64 = vec_len(args);
            let mut ai: i64 = 0;
            while ai < ac { used.push(vec_get(args, ai)); ai = ai + 1; };
        };
        i = i + 1;
    };
    // Now remove dead instructions (rebuild insts list)
    let mut new_insts: Vec<i32> = Vec::new();
    let mut removed: i64 = 0;
    i = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        let mut keep: i64 = 1;
        // Only consider removing pure value-producing ops
        if op == 0 || (op >= 2 && op <= 15) || op == 17 || op == 23 || op == 24 || op == 26 || op == 27 || op == 28 || op == 29 {
            if d > 0 {
                // Check if d is in used set
                let mut found: i64 = 0;
                let uc: i64 = vec_len(used);
                let mut ui: i64 = 0;
                while ui < uc {
                    if vec_get(used, ui) == d { found = 1; ui = uc; };
                    ui = ui + 1;
                };
                if found == 0 { keep = 0; };
            };
        };
        if keep == 1 { new_insts.push(inst); }
        else { removed = removed + 1; };
        i = i + 1;
    };
    // Replace instruction list
    if removed > 0 { vec_set(blk, 1, new_insts); };
    return removed;
}

// --- Pass 3: Store-Load Constant Propagation ---
// Propagates known constants through store/load chains within a block.
// If a constant is stored to a slot and later loaded, replaces the load with const_int.
fn opt_prop_block(blk: Vec<i32>) -> i64 {
    let mut cm: Vec<i32> = cmap_new();
    let mut sv: Vec<i32> = cmap_new();
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        if op == 0 { cmap_set(cm, d, ir_op1(inst)); }
        else if op == 18 {
            let val: i64 = ir_op1(inst);
            let ptr: i64 = ir_op2(inst);
            if cmap_has(cm, val) == 1 { cmap_set(sv, ptr, cmap_get(cm, val)); }
            else { cmap_set(sv, ptr, 0 - 9999999); };
        }
        else if op == 17 {
            let ptr: i64 = ir_op1(inst);
            if cmap_has(sv, ptr) == 1 {
                let cv: i64 = cmap_get(sv, ptr);
                if cv != 0 - 9999999 {
                    vec_set(inst, 0, 0);
                    vec_set(inst, 3, cv);
                    vec_set(inst, 4, 0);
                    vec_set(inst, 5, 0);
                    cmap_set(cm, d, cv);
                    count = count + 1;
                };
            };
        }
        else if op == 19 || op == 30 || op == 31 { sv = cmap_new(); };
        i = i + 1;
    };
    return count;
}

// --- Pass 4: Dead Store Elimination ---
// Removes stores that are overwritten before being read within the same block.
fn opt_dead_store_block(blk: Vec<i32>) -> i64 {
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    if ic == 0 { return 0; };
    let mut last_store: Vec<i32> = cmap_new();
    let mut dead: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        if op == 18 {
            let ptr: i64 = ir_op2(inst);
            if cmap_has(last_store, ptr) == 1 {
                let prev_idx: i64 = cmap_get(last_store, ptr);
                if prev_idx >= 0 { dead.push(prev_idx); };
            };
            cmap_set(last_store, ptr, i);
        }
        else if op == 17 {
            let ptr: i64 = ir_op1(inst);
            cmap_set(last_store, ptr, 0 - 1);
        }
        else if op == 19 || op == 20 || op == 21 || op == 22 || op == 30 || op == 31 {
            last_store = cmap_new();
        };
        i = i + 1;
    };
    if vec_len(dead) == 0 { return 0; };
    let mut new_insts: Vec<i32> = Vec::new();
    let mut removed: i64 = 0;
    i = 0;
    while i < ic {
        let mut is_dead: i64 = 0;
        let dc: i64 = vec_len(dead);
        let mut di: i64 = 0;
        while di < dc {
            if vec_get(dead, di) == i { is_dead = 1; di = dc; };
            di = di + 1;
        };
        if is_dead == 0 { new_insts.push(vec_get(insts, i)); }
        else { removed = removed + 1; };
        i = i + 1;
    };
    if removed > 0 { vec_set(blk, 1, new_insts); };
    return removed;
}

// --- Pass 5: Common Subexpression Elimination ---
// Deduplicates identical pure computations within a block.
// When a duplicate is found, rewrites all uses of its dest to the original dest.
fn opt_cse_block(blk: Vec<i32>) -> i64 {
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    if ic < 2 { return 0; };
    let mut seen_op: Vec<i32> = Vec::new();
    let mut seen_o1: Vec<i32> = Vec::new();
    let mut seen_o2: Vec<i32> = Vec::new();
    let mut seen_dst: Vec<i32> = Vec::new();
    let mut rewrites: i64 = 0;
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        let o1: i64 = ir_op1(inst);
        let o2: i64 = ir_op2(inst);
        if op == 0 || (op >= 2 && op <= 14) || op == 27 {
            let sc: i64 = vec_len(seen_op);
            let mut found: i64 = 0 - 1;
            let mut si: i64 = 0;
            while si < sc {
                if vec_get(seen_op, si) == op && vec_get(seen_o1, si) == o1 && vec_get(seen_o2, si) == o2 {
                    found = vec_get(seen_dst, si); si = sc;
                };
                si = si + 1;
            };
            if found >= 0 {
                // Rewrite all forward uses of d to found (opcode-aware)
                let mut j: i64 = i + 1;
                while j < ic {
                    let jinst: Vec<i32> = vec_get(insts, j);
                    let jop: i64 = ir_op(jinst);
                    if jop == 19 {
                        let args: Vec<i32> = vec_get(jinst, 5);
                        let ac: i64 = vec_len(args);
                        let mut ai: i64 = 0;
                        while ai < ac {
                            if vec_get(args, ai) == d { vec_set(args, ai, found); };
                            ai = ai + 1;
                        };
                    }
                    else if jop >= 2 && jop <= 14 {
                        // arithmetic/cmp/logic: op1 and op2 are registers
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        if ir_op2(jinst) == d { vec_set(jinst, 4, found); };
                    }
                    else if jop == 17 { if ir_op1(jinst) == d { vec_set(jinst, 3, found); }; }
                    else if jop == 18 {
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        if ir_op2(jinst) == d { vec_set(jinst, 4, found); };
                    }
                    else if jop == 20 { if ir_op1(jinst) == d { vec_set(jinst, 3, found); }; }
                    else if jop == 22 { if ir_op1(jinst) == d { vec_set(jinst, 3, found); }; }
                    else if jop == 28 {
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        if ir_op2(jinst) == d { vec_set(jinst, 4, found); };
                        if ir_extra(jinst) == d { vec_set(jinst, 5, found); };
                    }
                    else if jop == 30 {
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        let jargs: Vec<i32> = vec_get(jinst, 5);
                        let jac: i64 = vec_len(jargs);
                        let mut jai: i64 = 0;
                        while jai < jac {
                            if vec_get(jargs, jai) == d { vec_set(jargs, jai, found); };
                            jai = jai + 1;
                        };
                    };
                    // ops 0, 16, 21, 26, 27, 29: no register operands to rewrite
                    j = j + 1;
                };
                rewrites = rewrites + 1;
            } else {
                seen_op.push(op); seen_o1.push(o1); seen_o2.push(o2); seen_dst.push(d);
            };
        };
        i = i + 1;
    };
    return rewrites;
}

// --- Optimizer driver: runs all passes on an entire function ---
fn opt_fn(f: Vec<i32>) -> i64 {
    let mut total: i64 = 0;
    let mut bi: i64 = 0;
    // Iteration 1: fold → prop → fold → CSE → dead store → DCE
    let mut bc: i64 = ir_fn_block_count(f);
    bi = 0;
    while bi < bc {
        let blk: Vec<i32> = ir_fn_get_block(f, bi);
        total = total + opt_fold_block(blk);
        total = total + opt_prop_block(blk);
        total = total + opt_fold_block(blk);
        total = total + opt_cse_block(blk);
        total = total + opt_dead_store_block(blk);
        total = total + opt_dce_block(blk);
        bi = bi + 1;
    };
    // Block merging disabled — predecessor counting doesn't account for
    // new predecessors created when a merged block's terminator branches elsewhere.
    // Iteration 2: re-run per-block passes on merged blocks
    bc = ir_fn_block_count(f);
    bi = 0;
    while bi < bc {
        let blk: Vec<i32> = ir_fn_get_block(f, bi);
        total = total + opt_fold_block(blk);
        total = total + opt_prop_block(blk);
        total = total + opt_fold_block(blk);
        total = total + opt_dead_store_block(blk);
        total = total + opt_dce_block(blk);
        bi = bi + 1;
    };
    return total;
}

// =====================================================
// BUILTIN MAPPING (NEW in T30)
// =====================================================
fn get_rt_name(name: str) -> str {
    if str_eq(name, "print") { return "__nucleor_print_str"; };
    if str_eq(name, "putchar") { return "__nucleor_putchar"; };
    if str_eq(name, "str_len") { return "__nucleor_str_len"; };
    if str_eq(name, "str_eq") { return "__nucleor_str_eq"; };
    if str_eq(name, "str_char_at") { return "__nucleor_str_char_at"; };
    if str_eq(name, "str_substring") { return "__nucleor_str_substring"; };
    if str_eq(name, "str_concat") { return "__nucleor_str_concat"; };
    if str_eq(name, "str_intern") { return "__nucleor_str_intern"; };
    if str_eq(name, "str_free") { return "__nucleor_str_free"; };
    if str_eq(name, "str_arena_new") { return "__nucleor_str_arena_new"; };
    if str_eq(name, "str_arena_free") { return "__nucleor_str_arena_free"; };
    if str_eq(name, "str_arena_bytes") { return "__nucleor_str_arena_bytes"; };
    if str_eq(name, "str_arena_concat") { return "__nucleor_str_arena_concat"; };
    if str_eq(name, "str_arena_substring") { return "__nucleor_str_arena_substring"; };
    if str_eq(name, "file_read_string") { return "__nucleor_file_read_string"; };
    if str_eq(name, "file_write_string") { return "__nucleor_file_write_string"; };
    if str_eq(name, "system") { return "__nucleor_system"; };
    if str_eq(name, "sb_new") { return "__nucleor_sb_new"; };
    if str_eq(name, "sb_append") { return "__nucleor_sb_append"; };
    if str_eq(name, "sb_append_char") { return "__nucleor_sb_append_char"; };
    if str_eq(name, "sb_new_with_cap") { return "__nucleor_sb_new_with_cap"; };
    if str_eq(name, "sb_to_str") { return "__nucleor_sb_to_str"; };
    if str_eq(name, "vec_new") { return "__nucleor_vec_new"; };
    if str_eq(name, "vec_with_capacity") { return "__nucleor_vec_with_capacity"; };
    if str_eq(name, "vec_push") { return "__nucleor_vec_push"; };
    if str_eq(name, "vec_get") { return "__nucleor_vec_get"; };
    if str_eq(name, "vec_len") { return "__nucleor_vec_len"; };
    if str_eq(name, "vec_pop") { return "__nucleor_vec_pop"; };
    if str_eq(name, "vec_free") { return "__nucleor_vec_free"; };
    if str_eq(name, "vec_set") { return "__nucleor_vec_set"; };
    if str_eq(name, "vec_first") { return "__nucleor_vec_first"; };
    if str_eq(name, "vec_last") { return "__nucleor_vec_last"; };
    if str_eq(name, "vec_is_empty") { return "__nucleor_vec_is_empty"; };
    if str_eq(name, "vec_swap") { return "__nucleor_vec_swap"; };
    if str_eq(name, "vec_extend") { return "__nucleor_vec_extend"; };
    if str_eq(name, "vec_remove_at") { return "__nucleor_vec_remove_at"; };
    if str_eq(name, "vec_insert_at") { return "__nucleor_vec_insert_at"; };
    if str_eq(name, "args_count") { return "__nucleor_args_count"; };
    if str_eq(name, "args_get") { return "__nucleor_args_get"; };
    if str_eq(name, "print_int") { return "__nucleor_print_i64"; };
    if str_eq(name, "print_bool") { return "__nucleor_print_bool"; };
    // Stdin read helpers (RFC-0015 phase 4 completion)
    if str_eq(name, "read_line") { return "__nucleor_read_line"; };
    if str_eq(name, "read_i64") { return "__nucleor_read_i64"; };
    if str_eq(name, "read_byte") { return "__nucleor_read_byte"; };
    // RFC-0028 phase 1 — format string builtins (one {} placeholder per call,
    // multi-placeholder via format2_*; full variadic + Display/Debug in v0.4)
    if str_eq(name, "format_i64") { return "__nucleor_format_i64"; };
    if str_eq(name, "str_to_i64") { return "__nucleor_str_to_i64"; };
    if str_eq(name, "str_to_f64") { return "__nucleor_str_to_f64"; };
    if str_eq(name, "str_to_int") { return "__nucleor_str_to_int"; };
    if str_eq(name, "str_to_bool") { return "__nucleor_str_to_bool"; };
    if str_eq(name, "int_to_str") { return "__nucleor_int_to_str"; };
    // v0.3.103: Rust-style alias. The canonical Rust idiom for
    // i64→string is `i.to_string()` or `String::from(i)`; the closest
    // ergonomic helper Nucleor exposes is `int_to_str(n)`. Pre-v0.3.103,
    // users (and the s1 compiler's own source!) wrote `str_from_int(n)`
    // and hit `clang: undefined value '@str_from_int'` because only
    // `int_to_str` was registered. Both names now route to the same
    // runtime helper.
    if str_eq(name, "str_from_int") { return "__nucleor_int_to_str"; };
    if str_eq(name, "f64_to_str") { return "__nucleor_f64_to_str"; };
    if str_eq(name, "bool_to_str") { return "__nucleor_bool_to_str"; };
    if str_eq(name, "int_to_hex") { return "__nucleor_int_to_hex"; };
    if str_eq(name, "int_to_bin") { return "__nucleor_int_to_bin"; };
    if str_eq(name, "int_to_oct") { return "__nucleor_int_to_oct"; };
    if str_eq(name, "str_to_i64_radix") { return "__nucleor_str_to_i64_radix"; };
    if str_eq(name, "parse_hex") { return "__nucleor_parse_hex"; };
    if str_eq(name, "parse_bin") { return "__nucleor_parse_bin"; };
    if str_eq(name, "str_pad_left") { return "__nucleor_str_pad_left"; };
    if str_eq(name, "str_pad_right") { return "__nucleor_str_pad_right"; };
    if str_eq(name, "str_center") { return "__nucleor_str_center"; };
    if str_eq(name, "str_join") { return "__nucleor_str_join"; };
    if str_eq(name, "str_lines") { return "__nucleor_str_lines"; };
    if str_eq(name, "str_chars") { return "__nucleor_str_chars"; };
    if str_eq(name, "format_str") { return "__nucleor_format_str"; };
    if str_eq(name, "format_hex") { return "__nucleor_format_hex"; };
    if str_eq(name, "format2_ii") { return "__nucleor_format2_ii"; };
    if str_eq(name, "format2_si") { return "__nucleor_format2_si"; };
    if str_eq(name, "format2_ss") { return "__nucleor_format2_ss"; };
    if str_eq(name, "format2_is") { return "__nucleor_format2_is"; };
    if str_eq(name, "format2_ff") { return "__nucleor_format2_ff"; };
    if str_eq(name, "format2_fi") { return "__nucleor_format2_fi"; };
    if str_eq(name, "format2_if") { return "__nucleor_format2_if"; };
    if str_eq(name, "format3_fff") { return "__nucleor_format3_fff"; };
    if str_eq(name, "format_f64") { return "__nucleor_format_f64"; };
    // RFC-0024 phase 1: Vec<i64> functional helpers (function-pointer args)
    // T2.4 (v0.2.350): trait object 2-cell handle helpers.
    if str_eq(name, "dyn_box_make") { return "__nucleor_dyn_box_make"; };
    if str_eq(name, "dyn_box_type") { return "__nucleor_dyn_box_type"; };
    if str_eq(name, "dyn_box_data") { return "__nucleor_dyn_box_data"; };
    if str_eq(name, "dyn_box_free") { return "__nucleor_dyn_box_free"; };
    if str_eq(name, "vec_iter_i64") { return "__nucleor_vec_iter_i64"; };
    if str_eq(name, "vec_collect_i64") { return "__nucleor_vec_collect_i64"; };
    if str_eq(name, "vec_count_i64") { return "__nucleor_vec_count_i64"; };
    if str_eq(name, "vec_take_i64") { return "__nucleor_vec_take_i64"; };
    if str_eq(name, "vec_skip_i64") { return "__nucleor_vec_skip_i64"; };
    if str_eq(name, "vec_map_i64") { return "__nucleor_vec_map_i64"; };
    if str_eq(name, "vec_filter_i64") { return "__nucleor_vec_filter_i64"; };
    if str_eq(name, "vec_fold_i64") { return "__nucleor_vec_fold_i64"; };
    if str_eq(name, "vec_each_i64") { return "__nucleor_vec_each_i64"; };
    if str_eq(name, "vec_sum_i64") { return "__nucleor_vec_sum_i64"; };
    if str_eq(name, "vec_min_i64") { return "__nucleor_vec_min_i64"; };
    if str_eq(name, "vec_max_i64") { return "__nucleor_vec_max_i64"; };
    if str_eq(name, "vec_contains_i64") { return "__nucleor_vec_contains_i64"; };
    if str_eq(name, "vec_index_of_i64") { return "__nucleor_vec_index_of_i64"; };
    if str_eq(name, "vec_reverse_i64") { return "__nucleor_vec_reverse_i64"; };
    if str_eq(name, "vec_sort_i64") { return "__nucleor_vec_sort_i64"; };
    if str_eq(name, "vec_clone_i64") { return "__nucleor_vec_clone_i64"; };
    if str_eq(name, "vec_clear_i64") { return "__nucleor_vec_clear_i64"; };
    if str_eq(name, "vec_sum_f64") { return "__nucleor_vec_sum_f64"; };
    if str_eq(name, "vec_min_f64") { return "__nucleor_vec_min_f64"; };
    if str_eq(name, "vec_max_f64") { return "__nucleor_vec_max_f64"; };
    // String utilities (RFC-0017 / RFC-0028 stdlib enrichment)
    if str_eq(name, "str_to_lower") { return "__nucleor_str_to_lower"; };
    if str_eq(name, "str_to_upper") { return "__nucleor_str_to_upper"; };
    if str_eq(name, "str_trim") { return "__nucleor_str_trim"; };
    if str_eq(name, "str_starts_with") { return "__nucleor_str_starts_with"; };
    if str_eq(name, "str_ends_with") { return "__nucleor_str_ends_with"; };
    if str_eq(name, "str_index_of") { return "__nucleor_str_index_of"; };
    if str_eq(name, "str_contains") { return "__nucleor_str_contains"; };
    if str_eq(name, "str_replace") { return "__nucleor_str_replace"; };
    if str_eq(name, "str_repeat") { return "__nucleor_str_repeat"; };
    if str_eq(name, "str_split") { return "__nucleor_str_split"; };
    if str_eq(name, "str_trim_start") { return "__nucleor_str_trim_start"; };
    if str_eq(name, "str_trim_end") { return "__nucleor_str_trim_end"; };
    if str_eq(name, "str_is_empty") { return "__nucleor_str_is_empty"; };
    if str_eq(name, "str_count") { return "__nucleor_str_count"; };
    if str_eq(name, "str_reverse") { return "__nucleor_str_reverse"; };
    if str_eq(name, "format_bool") { return "__nucleor_format_bool"; };
    if str_eq(name, "format3_iii") { return "__nucleor_format3_iii"; };
    if str_eq(name, "format3_sii") { return "__nucleor_format3_sii"; };
    if str_eq(name, "format3_iss") { return "__nucleor_format3_iss"; };
    if str_eq(name, "format3_sss") { return "__nucleor_format3_sss"; };
    if str_eq(name, "format3_ssi") { return "__nucleor_format3_ssi"; };
    if str_eq(name, "format3_sis") { return "__nucleor_format3_sis"; };
    if str_eq(name, "format3_iis") { return "__nucleor_format3_iis"; };
    if str_eq(name, "format3_isi") { return "__nucleor_format3_isi"; };
    if str_eq(name, "format3_iif") { return "__nucleor_format3_iif"; };
    if str_eq(name, "format3_iff") { return "__nucleor_format3_iff"; };
    if str_eq(name, "format3_sff") { return "__nucleor_format3_sff"; };
    if str_eq(name, "format3_ssf") { return "__nucleor_format3_ssf"; };
    if str_eq(name, "format3_sif") { return "__nucleor_format3_sif"; };
    if str_eq(name, "format3_isf") { return "__nucleor_format3_isf"; };
    if str_eq(name, "vec_avg_i64") { return "__nucleor_vec_avg_i64"; };
    if str_eq(name, "vec_dot_i64") { return "__nucleor_vec_dot_i64"; };
    if str_eq(name, "vec_count_eq_i64") { return "__nucleor_vec_count_eq_i64"; };
    if str_eq(name, "vec_any_i64") { return "__nucleor_vec_any_i64"; };
    if str_eq(name, "vec_all_i64") { return "__nucleor_vec_all_i64"; };
    // Char predicates / transformations (RFC-0017 stdlib enrichment)
    if str_eq(name, "char_is_alpha") { return "__nucleor_char_is_alpha"; };
    if str_eq(name, "char_is_digit") { return "__nucleor_char_is_digit"; };
    if str_eq(name, "char_is_alnum") { return "__nucleor_char_is_alnum"; };
    if str_eq(name, "char_is_whitespace") { return "__nucleor_char_is_whitespace"; };
    if str_eq(name, "char_is_upper") { return "__nucleor_char_is_upper"; };
    if str_eq(name, "char_is_lower") { return "__nucleor_char_is_lower"; };
    if str_eq(name, "char_is_hex_digit") { return "__nucleor_char_is_hex_digit"; };
    if str_eq(name, "char_is_punct") { return "__nucleor_char_is_punct"; };
    if str_eq(name, "char_is_ascii") { return "__nucleor_char_is_ascii"; };
    if str_eq(name, "char_to_upper") { return "__nucleor_char_to_upper"; };
    if str_eq(name, "char_to_lower") { return "__nucleor_char_to_lower"; };
    if str_eq(name, "char_digit_value") { return "__nucleor_char_digit_value"; };
    // Note: hashmap_keys/values + time_iso_now/format_iso are exposed below
    // (later in this map) — listed there next to the rest of the v0.2.16
    // helpers.
    // RNG primitives (rng_seed/random_uniform/random_normal already mapped above)
    if str_eq(name, "rng_int") { return "__nucleor_rng_int"; };
    if str_eq(name, "rng_uniform") { return "__nucleor_rng_uniform"; };
    if str_eq(name, "rng_normal") { return "__nucleor_rng_normal"; };
    if str_eq(name, "rng_bernoulli") { return "__nucleor_rng_bernoulli"; };
    if str_eq(name, "rng_exponential") { return "__nucleor_rng_exponential"; };
    // HashMap iteration (RFC-0017 enrichment)
    if str_eq(name, "hashmap_keys") { return "__nucleor_hashmap_keys"; };
    if str_eq(name, "hashmap_values") { return "__nucleor_hashmap_values"; };
    // ISO 8601 time formatting (RFC-0017 enrichment)
    if str_eq(name, "time_iso_now") { return "__nucleor_time_iso_now"; };
    if str_eq(name, "time_format_iso") { return "__nucleor_time_format_iso"; };
    // Hash helpers (RFC-0017 stdlib enrichment)
    if str_eq(name, "fnv1a_64_str") { return "__nucleor_fnv1a_64_str"; };
    if str_eq(name, "fnv1a_64_i64") { return "__nucleor_fnv1a_64_i64"; };
    if str_eq(name, "murmur3_64") { return "__nucleor_murmur3_64"; };
    // Print without trailing newline (RFC-0017 ergonomics)
    if str_eq(name, "print_raw") { return "__nucleor_print_raw"; };
    if str_eq(name, "eprint_raw") { return "__nucleor_eprint_raw"; };
    if str_eq(name, "file_append_string") { return "__nucleor_file_append_string"; };
    if str_eq(name, "sb_free") { return "__nucleor_sb_free"; };
    if str_eq(name, "now_ms") { return "__nucleor_now_ms"; };
    if str_eq(name, "isatty_stdout") { return "__nucleor_isatty_stdout"; };
    if str_eq(name, "chr") { return "__nucleor_chr"; };
    if str_eq(name, "getcwd") { return "__nucleor_getcwd"; };
    if str_eq(name, "getenv") { return "__nucleor_getenv"; };
    if str_eq(name, "pipe_create") { return "__nucleor_pipe_create"; };
    if str_eq(name, "pipe_write") { return "__nucleor_pipe_write"; };
    if str_eq(name, "pipe_close") { return "__nucleor_pipe_close"; };
    if str_eq(name, "sha256") { return "__nucleor_sha256"; };
    if str_eq(name, "thread_spawn") { return "__nucleor_thread_spawn"; };
    if str_eq(name, "thread_join") { return "__nucleor_thread_join"; };
    // T2.8 (v0.2.353): async runtime — threads-only per RFC-0027.
    if str_eq(name, "async_spawn") { return "__nucleor_async_spawn"; };
    if str_eq(name, "async_await") { return "__nucleor_async_await"; };
    if str_eq(name, "mutex_new") { return "__nucleor_mutex_new_value"; };
    if str_eq(name, "mutex_lock") { return "__nucleor_mutex_lock_value"; };
    if str_eq(name, "mutex_unlock") { return "__nucleor_mutex_unlock_value"; };
    if str_eq(name, "channel_new") { return "__nucleor_channel_new"; };
    if str_eq(name, "channel_send") { return "__nucleor_channel_send"; };
    if str_eq(name, "channel_recv") { return "__nucleor_channel_recv"; };
    if str_eq(name, "channel_len") { return "__nucleor_channel_len"; };
    if str_eq(name, "channel") { return "__nucleor_channel_new"; };
    if str_eq(name, "chan_send") { return "__nucleor_channel_send"; };
    if str_eq(name, "chan_recv") { return "__nucleor_channel_recv"; };
    if str_eq(name, "chan_len") { return "__nucleor_channel_len"; };
    if str_eq(name, "atomic_new") { return "__nucleor_atomic_new"; };
    if str_eq(name, "atomic_add") { return "__nucleor_atomic_add"; };
    if str_eq(name, "atomic_load") { return "__nucleor_atomic_load"; };
    if str_eq(name, "cpu_count") { return "__nucleor_cpu_count"; };
    if str_eq(name, "print_f64") { return "__nucleor_print_f64"; };
    if str_eq(name, "f64_from_scaled") { return "__nucleor_f64_from_scaled"; };
    if str_eq(name, "f64_from_bits") { return "__nucleor_f64_from_bits"; };
    if str_eq(name, "f64_to_bits") { return "__nucleor_f64_to_bits"; };
    if str_eq(name, "f32_from_bits") { return "__nucleor_f32_from_bits"; };
    if str_eq(name, "f32_to_bits") { return "__nucleor_f32_to_bits"; };
    if str_eq(name, "f64_to_i32") { return "__nucleor_f64_to_i32"; };
    if str_eq(name, "i32_to_f64") { return "__nucleor_i32_to_f64"; };
    if str_eq(name, "fabs") { return "__nucleor_fabs"; };
    if str_eq(name, "fmod") { return "__nucleor_fmod"; };
    if str_eq(name, "sqrt") { return "__nucleor_sqrt"; };
    if str_eq(name, "sin") { return "__nucleor_sin"; };
    if str_eq(name, "cos") { return "__nucleor_cos"; };
    if str_eq(name, "pow") { return "__nucleor_pow"; };
    if str_eq(name, "floor") { return "__nucleor_floor"; };
    if str_eq(name, "ceil") { return "__nucleor_ceil"; };
    if str_eq(name, "round") { return "__nucleor_round"; };
    if str_eq(name, "exp") { return "__nucleor_exp"; };
    if str_eq(name, "log") { return "__nucleor_log"; };
    if str_eq(name, "sigmoid") { return "__nucleor_sigmoid"; };
    if str_eq(name, "tanh") { return "__nucleor_tanh"; };
    if str_eq(name, "tanh_act") { return "__nucleor_tanh"; };
    if str_eq(name, "relu") { return "__nucleor_relu"; };
    if str_eq(name, "gelu") { return "__nucleor_gelu"; };
    if str_eq(name, "abs") { return "__nucleor_abs"; };
    if str_eq(name, "min") { return "__nucleor_min"; };
    if str_eq(name, "max") { return "__nucleor_max"; };
    if str_eq(name, "clamp") { return "__nucleor_clamp"; };
    if str_eq(name, "assert") { return "__nucleor_assert"; };
    if str_eq(name, "profile_start") { return "__nucleor_profile_start"; };
    if str_eq(name, "profile_end") { return "__nucleor_profile_end"; };
    if str_eq(name, "ambient_random") { return "__nucleor_ambient_random"; };
    if str_eq(name, "rng_seed") { return "__nucleor_rng_seed"; };
    if str_eq(name, "random_uniform") { return "__nucleor_random_uniform"; };
    if str_eq(name, "random_normal") { return "__nucleor_random_normal"; };
    if str_eq(name, "random_int") { return "__nucleor_random_int"; };
    if str_eq(name, "random_bool") { return "__nucleor_random_bool"; };
    if str_eq(name, "random_choice") { return "__nucleor_random_choice"; };
    if str_eq(name, "vec_shuffle") { return "__nucleor_vec_shuffle"; };
    if str_eq(name, "vec_sample") { return "__nucleor_vec_sample"; };
    if str_eq(name, "random_fill") { return "__nucleor_random_fill"; };
    if str_eq(name, "vec_mean_f64") { return "__nucleor_vec_mean_f64"; };
    if str_eq(name, "vec_median_f64") { return "__nucleor_vec_median_f64"; };
    if str_eq(name, "vec_variance_f64") { return "__nucleor_vec_variance_f64"; };
    if str_eq(name, "vec_stddev_f64") { return "__nucleor_vec_stddev_f64"; };
    if str_eq(name, "vec_range_i64") { return "__nucleor_vec_range_i64"; };
    if str_eq(name, "vec_percentile_f64") { return "__nucleor_vec_percentile_f64"; };
    if str_eq(name, "arena_reset") { return "__nucleor_arena_reset"; };
    if str_eq(name, "device_alloc") { return "__nucleor_device_alloc"; };
    if str_eq(name, "device_transfer") { return "__nucleor_device_transfer"; };
    if str_eq(name, "device_free") { return "__nucleor_device_free"; };
    if str_eq(name, "tensor_view") { return "__nucleor_tensor_view"; };
    if str_eq(name, "py_eval") { return "__nucleor_py_eval"; };
    if str_eq(name, "kvcache_new") { return "__nucleor_kvcache_new"; };
    if str_eq(name, "kvcache_append") { return "__nucleor_kvcache_append"; };
    if str_eq(name, "kvcache_read_prefix") { return "__nucleor_kvcache_read_prefix"; };
    if str_eq(name, "kvcache_evict") { return "__nucleor_kvcache_evict"; };
    if str_eq(name, "kvcache_compact") { return "__nucleor_kvcache_compact"; };
    if str_eq(name, "kvcache_free") { return "__nucleor_kvcache_free"; };
    if str_eq(name, "kvprefix_free") { return "__nucleor_kvprefix_free"; };
    if str_eq(name, "simd_add") { return "__nucleor_simd_add"; };
    if str_eq(name, "simd_mul") { return "__nucleor_simd_mul"; };
    if str_eq(name, "simd_fma") { return "__nucleor_simd_fma"; };
    if str_eq(name, "vector_new") { return "__nucleor_vector_new"; };
    if str_eq(name, "vector_add") { return "__nucleor_vector_add"; };
    if str_eq(name, "vector_mul") { return "__nucleor_vector_mul"; };
    if str_eq(name, "vector_fma") { return "__nucleor_vector_fma"; };
    if str_eq(name, "vector_broadcast") { return "__nucleor_vector_broadcast"; };
    if str_eq(name, "vector_reduce_sum") { return "__nucleor_vector_reduce_sum"; };
    if str_eq(name, "vec_iter") { return "__nucleor_vec_iter"; };
    if str_eq(name, "vec_sum") { return "__nucleor_vec_sum"; };
    if str_eq(name, "vec_take") { return "__nucleor_vec_take"; };
    if str_eq(name, "vec_skip") { return "__nucleor_vec_skip"; };
    if str_eq(name, "vec_chain") { return "__nucleor_vec_chain"; };
    if str_eq(name, "vec_map") { return "__nucleor_vec_map"; };
    if str_eq(name, "vec_filter") { return "__nucleor_vec_filter"; };
    if str_eq(name, "vec_any") { return "__nucleor_vec_any"; };
    if str_eq(name, "vec_all") { return "__nucleor_vec_all"; };
    if str_eq(name, "vec_count") { return "__nucleor_vec_count"; };
    if str_eq(name, "vec_fold") { return "__nucleor_vec_fold"; };
    if str_eq(name, "rods_f64_encode") { return "__nucleor_rods_f64_encode"; };
    if str_eq(name, "rods_f64_add") { return "__nucleor_rods_f64_add"; };
    if str_eq(name, "rods_f64_sub") { return "__nucleor_rods_f64_sub"; };
    if str_eq(name, "rods_f64_div") { return "__nucleor_rods_f64_div"; };
    if str_eq(name, "wrap_i32") { return "__nucleor_wrap_i32"; };
    if str_eq(name, "sat_i32") { return "__nucleor_sat_i32"; };
    if str_eq(name, "ambient_scheduler") { return "__nucleor_ambient_scheduler"; };
    if str_eq(name, "rwlock_new") { return "__nucleor_rwlock_new"; };
    if str_eq(name, "rwlock_read") { return "__nucleor_rwlock_read"; };
    if str_eq(name, "rwlock_write") { return "__nucleor_rwlock_write"; };
    if str_eq(name, "rwlock_unlock") { return "__nucleor_rwlock_unlock"; };
    if str_eq(name, "cancel_token_new") { return "__nucleor_cancel_token_new"; };
    if str_eq(name, "cancel_token_cancel") { return "__nucleor_cancel_token_cancel"; };
    if str_eq(name, "cancel_token_is_cancelled") { return "__nucleor_cancel_token_is_cancelled"; };
    if str_eq(name, "arena_new") { return "__nucleor_arena_new"; };
    if str_eq(name, "arena_alloc") { return "__nucleor_arena_alloc"; };
    if str_eq(name, "arena_destroy") { return "__nucleor_arena_destroy"; };
    if str_eq(name, "assert_eq") { return "__nucleor_assert_eq"; };
    if str_eq(name, "assert_ne") { return "__nucleor_assert_ne"; };
    if str_eq(name, "panic") { return "__nucleor_panic"; };
    // RFC-0015 phase 2: `as` cast helpers
    if str_eq(name, "as_i8") { return "__nucleor_as_i8"; };
    if str_eq(name, "as_i16") { return "__nucleor_as_i16"; };
    if str_eq(name, "as_i32") { return "__nucleor_as_i32"; };
    if str_eq(name, "as_i64") { return "__nucleor_as_i64"; };
    if str_eq(name, "as_u8") { return "__nucleor_as_u8"; };
    if str_eq(name, "as_u16") { return "__nucleor_as_u16"; };
    if str_eq(name, "as_u32") { return "__nucleor_as_u32"; };
    if str_eq(name, "as_u64") { return "__nucleor_as_u64"; };
    if str_eq(name, "as_f32") { return "__nucleor_as_f32"; };
    if str_eq(name, "as_f64") { return "__nucleor_as_f64"; };
    // T1.1 Phase 3a: sizeof_<T>() primitive byte-size queries.
    if str_eq(name, "sizeof_i8") { return "__nucleor_sizeof_i8"; };
    if str_eq(name, "sizeof_i16") { return "__nucleor_sizeof_i16"; };
    if str_eq(name, "sizeof_i32") { return "__nucleor_sizeof_i32"; };
    if str_eq(name, "sizeof_i64") { return "__nucleor_sizeof_i64"; };
    if str_eq(name, "sizeof_i128") { return "__nucleor_sizeof_i128"; };
    if str_eq(name, "sizeof_u8") { return "__nucleor_sizeof_u8"; };
    if str_eq(name, "sizeof_u16") { return "__nucleor_sizeof_u16"; };
    if str_eq(name, "sizeof_u32") { return "__nucleor_sizeof_u32"; };
    if str_eq(name, "sizeof_u64") { return "__nucleor_sizeof_u64"; };
    if str_eq(name, "sizeof_u128") { return "__nucleor_sizeof_u128"; };
    if str_eq(name, "sizeof_usize") { return "__nucleor_sizeof_usize"; };
    if str_eq(name, "sizeof_isize") { return "__nucleor_sizeof_isize"; };
    if str_eq(name, "sizeof_f16") { return "__nucleor_sizeof_f16"; };
    if str_eq(name, "sizeof_bf16") { return "__nucleor_sizeof_bf16"; };
    if str_eq(name, "sizeof_f32") { return "__nucleor_sizeof_f32"; };
    if str_eq(name, "sizeof_f64") { return "__nucleor_sizeof_f64"; };
    if str_eq(name, "sizeof_bool") { return "__nucleor_sizeof_bool"; };
    if str_eq(name, "sizeof_char") { return "__nucleor_sizeof_char"; };
    if str_eq(name, "sizeof_ptr") { return "__nucleor_sizeof_ptr"; };
    // RFC-0015 phase 4: overflow-mode arithmetic
    if str_eq(name, "wrapping_add") { return "__nucleor_wrapping_add_i64"; };
    if str_eq(name, "wrapping_sub") { return "__nucleor_wrapping_sub_i64"; };
    if str_eq(name, "wrapping_mul") { return "__nucleor_wrapping_mul_i64"; };
    if str_eq(name, "saturating_add") { return "__nucleor_saturating_add_i64"; };
    if str_eq(name, "saturating_sub") { return "__nucleor_saturating_sub_i64"; };
    if str_eq(name, "saturating_mul") { return "__nucleor_saturating_mul_i64"; };
    if str_eq(name, "checked_add") { return "__nucleor_checked_add_i64"; };
    if str_eq(name, "checked_sub") { return "__nucleor_checked_sub_i64"; };
    if str_eq(name, "checked_mul") { return "__nucleor_checked_mul_i64"; };
    if str_eq(name, "checked_overflow_flag") { return "__nucleor_checked_overflow_flag"; };
    if str_eq(name, "checked_div") { return "__nucleor_checked_div_i64"; };
    if str_eq(name, "checked_rem") { return "__nucleor_checked_rem_i64"; };
    if str_eq(name, "checked_neg") { return "__nucleor_checked_neg_i64"; };
    if str_eq(name, "wrapping_div") { return "__nucleor_wrapping_div_i64"; };
    if str_eq(name, "wrapping_rem") { return "__nucleor_wrapping_rem_i64"; };
    if str_eq(name, "wrapping_neg") { return "__nucleor_wrapping_neg_i64"; };
    if str_eq(name, "saturating_neg") { return "__nucleor_saturating_neg_i64"; };
    // RFC-0015 phase 4 — per-narrow-width overflow primitives
    if str_eq(name, "wrapping_add_i8") { return "__nucleor_wrapping_add_i8"; };
    if str_eq(name, "wrapping_sub_i8") { return "__nucleor_wrapping_sub_i8"; };
    if str_eq(name, "wrapping_mul_i8") { return "__nucleor_wrapping_mul_i8"; };
    if str_eq(name, "saturating_add_i8") { return "__nucleor_saturating_add_i8"; };
    if str_eq(name, "saturating_sub_i8") { return "__nucleor_saturating_sub_i8"; };
    if str_eq(name, "saturating_mul_i8") { return "__nucleor_saturating_mul_i8"; };
    if str_eq(name, "checked_add_i8") { return "__nucleor_checked_add_i8"; };
    if str_eq(name, "checked_sub_i8") { return "__nucleor_checked_sub_i8"; };
    if str_eq(name, "checked_mul_i8") { return "__nucleor_checked_mul_i8"; };
    if str_eq(name, "wrapping_add_i16") { return "__nucleor_wrapping_add_i16"; };
    if str_eq(name, "wrapping_sub_i16") { return "__nucleor_wrapping_sub_i16"; };
    if str_eq(name, "wrapping_mul_i16") { return "__nucleor_wrapping_mul_i16"; };
    if str_eq(name, "saturating_add_i16") { return "__nucleor_saturating_add_i16"; };
    if str_eq(name, "saturating_sub_i16") { return "__nucleor_saturating_sub_i16"; };
    if str_eq(name, "saturating_mul_i16") { return "__nucleor_saturating_mul_i16"; };
    if str_eq(name, "checked_add_i16") { return "__nucleor_checked_add_i16"; };
    if str_eq(name, "checked_sub_i16") { return "__nucleor_checked_sub_i16"; };
    if str_eq(name, "checked_mul_i16") { return "__nucleor_checked_mul_i16"; };
    if str_eq(name, "wrapping_add_i32") { return "__nucleor_wrapping_add_i32"; };
    if str_eq(name, "wrapping_sub_i32") { return "__nucleor_wrapping_sub_i32"; };
    if str_eq(name, "wrapping_mul_i32") { return "__nucleor_wrapping_mul_i32"; };
    if str_eq(name, "saturating_add_i32") { return "__nucleor_saturating_add_i32"; };
    if str_eq(name, "saturating_sub_i32") { return "__nucleor_saturating_sub_i32"; };
    if str_eq(name, "saturating_mul_i32") { return "__nucleor_saturating_mul_i32"; };
    if str_eq(name, "checked_add_i32") { return "__nucleor_checked_add_i32"; };
    if str_eq(name, "checked_sub_i32") { return "__nucleor_checked_sub_i32"; };
    if str_eq(name, "checked_mul_i32") { return "__nucleor_checked_mul_i32"; };
    if str_eq(name, "wrapping_add_u8") { return "__nucleor_wrapping_add_u8"; };
    if str_eq(name, "wrapping_sub_u8") { return "__nucleor_wrapping_sub_u8"; };
    if str_eq(name, "wrapping_mul_u8") { return "__nucleor_wrapping_mul_u8"; };
    if str_eq(name, "saturating_add_u8") { return "__nucleor_saturating_add_u8"; };
    if str_eq(name, "saturating_sub_u8") { return "__nucleor_saturating_sub_u8"; };
    if str_eq(name, "saturating_mul_u8") { return "__nucleor_saturating_mul_u8"; };
    if str_eq(name, "checked_add_u8") { return "__nucleor_checked_add_u8"; };
    if str_eq(name, "checked_sub_u8") { return "__nucleor_checked_sub_u8"; };
    if str_eq(name, "checked_mul_u8") { return "__nucleor_checked_mul_u8"; };
    if str_eq(name, "wrapping_add_u16") { return "__nucleor_wrapping_add_u16"; };
    if str_eq(name, "wrapping_sub_u16") { return "__nucleor_wrapping_sub_u16"; };
    if str_eq(name, "wrapping_mul_u16") { return "__nucleor_wrapping_mul_u16"; };
    if str_eq(name, "saturating_add_u16") { return "__nucleor_saturating_add_u16"; };
    if str_eq(name, "saturating_sub_u16") { return "__nucleor_saturating_sub_u16"; };
    if str_eq(name, "saturating_mul_u16") { return "__nucleor_saturating_mul_u16"; };
    if str_eq(name, "checked_add_u16") { return "__nucleor_checked_add_u16"; };
    if str_eq(name, "checked_sub_u16") { return "__nucleor_checked_sub_u16"; };
    if str_eq(name, "checked_mul_u16") { return "__nucleor_checked_mul_u16"; };
    if str_eq(name, "wrapping_add_u32") { return "__nucleor_wrapping_add_u32"; };
    if str_eq(name, "wrapping_sub_u32") { return "__nucleor_wrapping_sub_u32"; };
    if str_eq(name, "wrapping_mul_u32") { return "__nucleor_wrapping_mul_u32"; };
    if str_eq(name, "saturating_add_u32") { return "__nucleor_saturating_add_u32"; };
    if str_eq(name, "saturating_sub_u32") { return "__nucleor_saturating_sub_u32"; };
    if str_eq(name, "saturating_mul_u32") { return "__nucleor_saturating_mul_u32"; };
    if str_eq(name, "checked_add_u32") { return "__nucleor_checked_add_u32"; };
    if str_eq(name, "checked_sub_u32") { return "__nucleor_checked_sub_u32"; };
    if str_eq(name, "checked_mul_u32") { return "__nucleor_checked_mul_u32"; };
    if str_eq(name, "wrapping_add_u64") { return "__nucleor_wrapping_add_u64"; };
    if str_eq(name, "wrapping_sub_u64") { return "__nucleor_wrapping_sub_u64"; };
    if str_eq(name, "wrapping_mul_u64") { return "__nucleor_wrapping_mul_u64"; };
    if str_eq(name, "saturating_add_u64") { return "__nucleor_saturating_add_u64"; };
    if str_eq(name, "saturating_sub_u64") { return "__nucleor_saturating_sub_u64"; };
    if str_eq(name, "saturating_mul_u64") { return "__nucleor_saturating_mul_u64"; };
    if str_eq(name, "checked_add_u64") { return "__nucleor_checked_add_u64"; };
    if str_eq(name, "checked_sub_u64") { return "__nucleor_checked_sub_u64"; };
    if str_eq(name, "checked_mul_u64") { return "__nucleor_checked_mul_u64"; };
    // RFC-0015 phase 5: per-width print helpers
    if str_eq(name, "print_i8") { return "__nucleor_print_i8"; };
    if str_eq(name, "print_i16") { return "__nucleor_print_i16"; };
    if str_eq(name, "print_i32") { return "__nucleor_print_i32"; };
    if str_eq(name, "print_u8") { return "__nucleor_print_u8"; };
    if str_eq(name, "print_u16") { return "__nucleor_print_u16"; };
    if str_eq(name, "print_u32") { return "__nucleor_print_u32"; };
    if str_eq(name, "print_u64") { return "__nucleor_print_u64"; };
    if str_eq(name, "print_hex") { return "__nucleor_print_hex"; };
    if str_eq(name, "print_bin") { return "__nucleor_print_bin"; };
    // RFC-0015 phase 5b: typed Vec storage
    if str_eq(name, "vec_u8_new") { return "__nucleor_vec_u8_new"; };
    if str_eq(name, "vec_u8_with_capacity") { return "__nucleor_vec_u8_with_capacity"; };
    if str_eq(name, "vec_u8_push") { return "__nucleor_vec_u8_push"; };
    if str_eq(name, "vec_u8_get") { return "__nucleor_vec_u8_get"; };
    if str_eq(name, "vec_u8_set") { return "__nucleor_vec_u8_set"; };
    if str_eq(name, "vec_u8_len") { return "__nucleor_vec_u8_len"; };
    if str_eq(name, "vec_u8_capacity") { return "__nucleor_vec_u8_capacity"; };
    if str_eq(name, "vec_u8_clear") { return "__nucleor_vec_u8_clear"; };
    if str_eq(name, "vec_u8_free") { return "__nucleor_vec_u8_free"; };
    if str_eq(name, "vec_f32_new") { return "__nucleor_vec_f32_new"; };
    if str_eq(name, "vec_f32_with_capacity") { return "__nucleor_vec_f32_with_capacity"; };
    if str_eq(name, "vec_f32_push_bits") { return "__nucleor_vec_f32_push_bits"; };
    if str_eq(name, "vec_f32_get_bits") { return "__nucleor_vec_f32_get_bits"; };
    if str_eq(name, "vec_f32_len") { return "__nucleor_vec_f32_len"; };
    if str_eq(name, "vec_f32_free") { return "__nucleor_vec_f32_free"; };
    // RFC-0015 phase 6: f32 distinct compute path
    if str_eq(name, "f32_from_int") { return "__nucleor_f32_from_int"; };
    if str_eq(name, "f32_to_int") { return "__nucleor_f32_to_int"; };
    if str_eq(name, "f32_add") { return "__nucleor_f32_add"; };
    if str_eq(name, "f32_sub") { return "__nucleor_f32_sub"; };
    if str_eq(name, "f32_mul") { return "__nucleor_f32_mul"; };
    if str_eq(name, "f32_div") { return "__nucleor_f32_div"; };
    // T1.1 Phase 5: f32 comparisons.
    if str_eq(name, "f32_lt") { return "__nucleor_f32_lt"; };
    if str_eq(name, "f32_gt") { return "__nucleor_f32_gt"; };
    if str_eq(name, "f32_le") { return "__nucleor_f32_le"; };
    if str_eq(name, "f32_ge") { return "__nucleor_f32_ge"; };
    if str_eq(name, "f32_eq") { return "__nucleor_f32_eq"; };
    if str_eq(name, "f32_ne") { return "__nucleor_f32_ne"; };
    // T1.1 Phase 5: native f64 arithmetic + comparisons.
    if str_eq(name, "f64_add") { return "__nucleor_f64_add"; };
    if str_eq(name, "f64_sub") { return "__nucleor_f64_sub"; };
    if str_eq(name, "f64_mul") { return "__nucleor_f64_mul"; };
    if str_eq(name, "f64_div") { return "__nucleor_f64_div"; };
    if str_eq(name, "f64_lt") { return "__nucleor_f64_lt"; };
    if str_eq(name, "f64_gt") { return "__nucleor_f64_gt"; };
    if str_eq(name, "f64_le") { return "__nucleor_f64_le"; };
    if str_eq(name, "f64_ge") { return "__nucleor_f64_ge"; };
    if str_eq(name, "f64_eq") { return "__nucleor_f64_eq"; };
    if str_eq(name, "f64_ne") { return "__nucleor_f64_ne"; };
    // T1.1 Phase 4: float↔int converters (Rust `as` saturating).
    if str_eq(name, "f32_to_i32") { return "__nucleor_f32_to_i32"; };
    if str_eq(name, "f32_to_i64") { return "__nucleor_f32_to_i64"; };
    if str_eq(name, "f32_to_u32") { return "__nucleor_f32_to_u32"; };
    if str_eq(name, "i32_to_f32") { return "__nucleor_i32_to_f32"; };
    if str_eq(name, "i64_to_f32") { return "__nucleor_i64_to_f32"; };
    if str_eq(name, "f64_to_i64") { return "__nucleor_f64_to_i64"; };
    if str_eq(name, "f64_to_u32") { return "__nucleor_f64_to_u32"; };
    if str_eq(name, "i64_to_f64") { return "__nucleor_i64_to_f64"; };
    if str_eq(name, "f64_to_i32") { return "__nucleor_f64_to_i32"; };
    if str_eq(name, "i32_to_f64") { return "__nucleor_i32_to_f64"; };
    if str_eq(name, "f32_to_f64") { return "__nucleor_f32_to_f64"; };
    if str_eq(name, "f64_to_f32") { return "__nucleor_f64_to_f32"; };
    if str_eq(name, "f32_neg") { return "__nucleor_f32_neg"; };
    if str_eq(name, "f32_abs") { return "__nucleor_f32_abs"; };
    if str_eq(name, "f32_sqrt") { return "__nucleor_f32_sqrt"; };
    if str_eq(name, "f32_exp") { return "__nucleor_f32_exp"; };
    if str_eq(name, "f32_log") { return "__nucleor_f32_log"; };
    if str_eq(name, "f32_sin") { return "__nucleor_f32_sin"; };
    if str_eq(name, "f32_cos") { return "__nucleor_f32_cos"; };
    if str_eq(name, "f32_pow") { return "__nucleor_f32_pow"; };
    if str_eq(name, "f32_lt") { return "__nucleor_f32_lt"; };
    if str_eq(name, "f32_gt") { return "__nucleor_f32_gt"; };
    if str_eq(name, "f32_eq") { return "__nucleor_f32_eq"; };
    if str_eq(name, "f32_to_f64") { return "__nucleor_f32_to_f64"; };
    if str_eq(name, "f64_to_f32") { return "__nucleor_f64_to_f32"; };
    if str_eq(name, "print_f32") { return "__nucleor_print_f32"; };
    // bf16 / f16 / f8 emulation
    if str_eq(name, "bf16_from_f32") { return "__nucleor_bf16_from_f32"; };
    if str_eq(name, "bf16_to_f32") { return "__nucleor_bf16_to_f32"; };
    if str_eq(name, "bf16_add") { return "__nucleor_bf16_add"; };
    if str_eq(name, "bf16_mul") { return "__nucleor_bf16_mul"; };
    if str_eq(name, "f16_from_f32") { return "__nucleor_f16_from_f32"; };
    if str_eq(name, "f16_to_f32") { return "__nucleor_f16_to_f32"; };
    if str_eq(name, "f16_add") { return "__nucleor_f16_add"; };
    if str_eq(name, "f16_mul") { return "__nucleor_f16_mul"; };
    if str_eq(name, "f8e4m3_to_f32") { return "__nucleor_f8e4m3_to_f32"; };
    if str_eq(name, "f8e5m2_to_f32") { return "__nucleor_f8e5m2_to_f32"; };
    // Debug + stderr helpers
    if str_eq(name, "dbg") { return "__nucleor_dbg_i64"; };
    if str_eq(name, "dbg_f64") { return "__nucleor_dbg_f64"; };
    if str_eq(name, "dbg_str") { return "__nucleor_dbg_str"; };
    if str_eq(name, "eprint") { return "__nucleor_eprint_str"; };
    if str_eq(name, "eprint_int") { return "__nucleor_eprint_int"; };
    // RFC-0033 (preview): SIMD vector types
    if str_eq(name, "f32x4_new") { return "__nucleor_f32x4_new"; };
    if str_eq(name, "f32x4_splat") { return "__nucleor_f32x4_splat"; };
    if str_eq(name, "f32x4_get") { return "__nucleor_f32x4_get"; };
    if str_eq(name, "f32x4_add") { return "__nucleor_f32x4_add"; };
    if str_eq(name, "f32x4_sub") { return "__nucleor_f32x4_sub"; };
    if str_eq(name, "f32x4_mul") { return "__nucleor_f32x4_mul"; };
    if str_eq(name, "f32x4_div") { return "__nucleor_f32x4_div"; };
    if str_eq(name, "f32x4_dot") { return "__nucleor_f32x4_dot"; };
    if str_eq(name, "f32x4_sum") { return "__nucleor_f32x4_sum"; };
    if str_eq(name, "f32x4_max") { return "__nucleor_f32x4_max"; };
    if str_eq(name, "f32x4_min") { return "__nucleor_f32x4_min"; };
    if str_eq(name, "f32x4_free") { return "__nucleor_f32x4_free"; };
    if str_eq(name, "i32x4_new") { return "__nucleor_i32x4_new"; };
    if str_eq(name, "i32x4_splat") { return "__nucleor_i32x4_splat"; };
    if str_eq(name, "i32x4_get") { return "__nucleor_i32x4_get"; };
    if str_eq(name, "i32x4_add") { return "__nucleor_i32x4_add"; };
    if str_eq(name, "i32x4_sub") { return "__nucleor_i32x4_sub"; };
    if str_eq(name, "i32x4_mul") { return "__nucleor_i32x4_mul"; };
    if str_eq(name, "i32x4_sum") { return "__nucleor_i32x4_sum"; };
    if str_eq(name, "i32x4_free") { return "__nucleor_i32x4_free"; };
    // RFC-0017 partial: heap-allocated String type
    if str_eq(name, "string_new") { return "__nucleor_string_new"; };
    if str_eq(name, "string_with_capacity") { return "__nucleor_string_with_capacity"; };
    if str_eq(name, "string_from_str") { return "__nucleor_string_from_str"; };
    if str_eq(name, "string_push_byte") { return "__nucleor_string_push_byte"; };
    if str_eq(name, "string_push_str") { return "__nucleor_string_push_str"; };
    if str_eq(name, "string_len") { return "__nucleor_string_len"; };
    if str_eq(name, "string_capacity") { return "__nucleor_string_capacity"; };
    if str_eq(name, "string_get_byte") { return "__nucleor_string_get_byte"; };
    if str_eq(name, "string_clear") { return "__nucleor_string_clear"; };
    if str_eq(name, "string_as_ptr") { return "__nucleor_string_as_ptr"; };
    if str_eq(name, "string_print") { return "__nucleor_string_print"; };
    if str_eq(name, "string_eq") { return "__nucleor_string_eq"; };
    if str_eq(name, "string_eq_str") { return "__nucleor_string_eq_str"; };
    if str_eq(name, "string_starts_with") { return "__nucleor_string_starts_with"; };
    if str_eq(name, "string_ends_with") { return "__nucleor_string_ends_with"; };
    if str_eq(name, "string_contains") { return "__nucleor_string_contains"; };
    if str_eq(name, "string_clone") { return "__nucleor_string_clone"; };
    if str_eq(name, "string_free") { return "__nucleor_string_free"; };
    // RFC-0017 partial: HashMap<str, i64>
    if str_eq(name, "hashmap_new") { return "__nucleor_hashmap_new"; };
    if str_eq(name, "hashmap_with_capacity") { return "__nucleor_hashmap_with_capacity"; };
    if str_eq(name, "hashmap_insert") { return "__nucleor_hashmap_insert"; };
    if str_eq(name, "hashmap_get") { return "__nucleor_hashmap_get"; };
    if str_eq(name, "hashmap_contains") { return "__nucleor_hashmap_contains"; };
    if str_eq(name, "hashmap_remove") { return "__nucleor_hashmap_remove"; };
    if str_eq(name, "hashmap_len") { return "__nucleor_hashmap_len"; };
    if str_eq(name, "hashmap_capacity") { return "__nucleor_hashmap_capacity"; };
    if str_eq(name, "hashmap_clear") { return "__nucleor_hashmap_clear"; };
    if str_eq(name, "hashmap_free") { return "__nucleor_hashmap_free"; };
    if str_eq(name, "hashmap_is_empty") { return "__nucleor_hashmap_is_empty"; };
    if str_eq(name, "hashmap_get_or") { return "__nucleor_hashmap_get_or"; };
    if str_eq(name, "hashmap_merge") { return "__nucleor_hashmap_merge"; };
    if str_eq(name, "hashmap_clone") { return "__nucleor_hashmap_clone"; };
    // Typed time
    if str_eq(name, "time_monotonic_ns") { return "__nucleor_time_monotonic_ns"; };
    if str_eq(name, "time_monotonic_us") { return "__nucleor_time_monotonic_us"; };
    if str_eq(name, "time_monotonic_ms") { return "__nucleor_time_monotonic_ms"; };
    // v0.3.0 (T3.1): runtime #[deadline] check helper.
    if str_eq(name, "deadline_check") { return "__nucleor_deadline_check"; };
    if str_eq(name, "time_wall_ns") { return "__nucleor_time_wall_ns"; };
    if str_eq(name, "time_wall_us") { return "__nucleor_time_wall_us"; };
    if str_eq(name, "time_wall_ms") { return "__nucleor_time_wall_ms"; };
    if str_eq(name, "time_wall_seconds") { return "__nucleor_time_wall_seconds"; };
    if str_eq(name, "time_year") { return "__nucleor_time_year"; };
    if str_eq(name, "time_month") { return "__nucleor_time_month"; };
    if str_eq(name, "time_day") { return "__nucleor_time_day"; };
    if str_eq(name, "time_hour") { return "__nucleor_time_hour"; };
    if str_eq(name, "time_minute") { return "__nucleor_time_minute"; };
    if str_eq(name, "time_second") { return "__nucleor_time_second"; };
    if str_eq(name, "time_weekday") { return "__nucleor_time_weekday"; };
    if str_eq(name, "time_day_of_year") { return "__nucleor_time_day_of_year"; };
    if str_eq(name, "time_elapsed_ms") { return "__nucleor_time_elapsed_ms"; };
    if str_eq(name, "sleep_ms") { return "__nucleor_sleep_ms"; };
    if str_eq(name, "sleep_us") { return "__nucleor_sleep_us"; };
    // Env
    if str_eq(name, "env_get") { return "__nucleor_env_get"; };
    if str_eq(name, "env_get_or") { return "__nucleor_env_get_or"; };
    if str_eq(name, "env_set") { return "__nucleor_env_set"; };
    if str_eq(name, "env_unset") { return "__nucleor_env_unset"; };
    if str_eq(name, "env_has") { return "__nucleor_env_has"; };
    if str_eq(name, "env_keys") { return "__nucleor_env_keys"; };
    // OS info
    if str_eq(name, "process_id") { return "__nucleor_process_id"; };
    if str_eq(name, "os_family") { return "__nucleor_os_family"; };
    if str_eq(name, "os_pointer_width") { return "__nucleor_os_pointer_width"; };
    // RFC-0017 phase 4: VecDeque + HashSet
    if str_eq(name, "vecdeque_new") { return "__nucleor_vecdeque_new"; };
    if str_eq(name, "vecdeque_with_capacity") { return "__nucleor_vecdeque_with_capacity"; };
    if str_eq(name, "vecdeque_push_back") { return "__nucleor_vecdeque_push_back"; };
    if str_eq(name, "vecdeque_push_front") { return "__nucleor_vecdeque_push_front"; };
    if str_eq(name, "vecdeque_pop_front") { return "__nucleor_vecdeque_pop_front"; };
    if str_eq(name, "vecdeque_pop_back") { return "__nucleor_vecdeque_pop_back"; };
    if str_eq(name, "vecdeque_get") { return "__nucleor_vecdeque_get"; };
    if str_eq(name, "vecdeque_set") { return "__nucleor_vecdeque_set"; };
    if str_eq(name, "vecdeque_len") { return "__nucleor_vecdeque_len"; };
    if str_eq(name, "vecdeque_capacity") { return "__nucleor_vecdeque_capacity"; };
    if str_eq(name, "vecdeque_clear") { return "__nucleor_vecdeque_clear"; };
    if str_eq(name, "vecdeque_free") { return "__nucleor_vecdeque_free"; };
    if str_eq(name, "hashset_new") { return "__nucleor_hashset_new"; };
    if str_eq(name, "hashset_with_capacity") { return "__nucleor_hashset_with_capacity"; };
    if str_eq(name, "hashset_insert") { return "__nucleor_hashset_insert"; };
    if str_eq(name, "hashset_contains") { return "__nucleor_hashset_contains"; };
    if str_eq(name, "hashset_remove") { return "__nucleor_hashset_remove"; };
    if str_eq(name, "hashset_len") { return "__nucleor_hashset_len"; };
    if str_eq(name, "hashset_clear") { return "__nucleor_hashset_clear"; };
    if str_eq(name, "hashset_free") { return "__nucleor_hashset_free"; };
    // RFC-0017 phase 3: BTreeMap / BTreeSet (ordered collections)
    if str_eq(name, "btreemap_new") { return "__nucleor_btreemap_new"; };
    if str_eq(name, "btreemap_insert") { return "__nucleor_btreemap_insert"; };
    if str_eq(name, "btreemap_get") { return "__nucleor_btreemap_get"; };
    if str_eq(name, "btreemap_contains") { return "__nucleor_btreemap_contains"; };
    if str_eq(name, "btreemap_remove") { return "__nucleor_btreemap_remove"; };
    if str_eq(name, "btreemap_len") { return "__nucleor_btreemap_len"; };
    if str_eq(name, "btreemap_key_at") { return "__nucleor_btreemap_key_at"; };
    if str_eq(name, "btreemap_val_at") { return "__nucleor_btreemap_val_at"; };
    if str_eq(name, "btreemap_clear") { return "__nucleor_btreemap_clear"; };
    if str_eq(name, "btreemap_free") { return "__nucleor_btreemap_free"; };
    if str_eq(name, "btreeset_new") { return "__nucleor_btreeset_new"; };
    if str_eq(name, "btreeset_insert") { return "__nucleor_btreeset_insert"; };
    if str_eq(name, "btreeset_contains") { return "__nucleor_btreeset_contains"; };
    if str_eq(name, "btreeset_remove") { return "__nucleor_btreeset_remove"; };
    if str_eq(name, "btreeset_len") { return "__nucleor_btreeset_len"; };
    if str_eq(name, "btreeset_at") { return "__nucleor_btreeset_at"; };
    if str_eq(name, "btreeset_clear") { return "__nucleor_btreeset_clear"; };
    if str_eq(name, "btreeset_free") { return "__nucleor_btreeset_free"; };
    // RFC-0018/0019: File system primitives
    if str_eq(name, "fs_exists") { return "__nucleor_fs_exists"; };
    if str_eq(name, "fs_is_file") { return "__nucleor_fs_is_file"; };
    if str_eq(name, "fs_is_dir") { return "__nucleor_fs_is_dir"; };
    if str_eq(name, "fs_size") { return "__nucleor_fs_size"; };
    if str_eq(name, "fs_mtime") { return "__nucleor_fs_mtime"; };
    if str_eq(name, "fs_create_dir") { return "__nucleor_fs_create_dir"; };
    if str_eq(name, "fs_create_dir_all") { return "__nucleor_fs_create_dir_all"; };
    if str_eq(name, "fs_remove_file") { return "__nucleor_fs_remove_file"; };
    if str_eq(name, "fs_rename") { return "__nucleor_fs_rename"; };
    if str_eq(name, "fs_list_dir") { return "__nucleor_fs_list_dir"; };
    if str_eq(name, "fs_join") { return "__nucleor_fs_join"; };
    if str_eq(name, "fs_basename") { return "__nucleor_fs_basename"; };
    if str_eq(name, "fs_dirname") { return "__nucleor_fs_dirname"; };
    if str_eq(name, "fs_extension") { return "__nucleor_fs_extension"; };
    if str_eq(name, "fs_temp_dir") { return "__nucleor_fs_temp_dir"; };
    if str_eq(name, "fs_current_dir") { return "__nucleor_fs_current_dir"; };
    if str_eq(name, "fs_remove_dir") { return "__nucleor_fs_remove_dir"; };
    if str_eq(name, "fs_copy_file") { return "__nucleor_fs_copy_file"; };
    if str_eq(name, "fs_canonicalize") { return "__nucleor_fs_canonicalize"; };
    if str_eq(name, "path_separator") { return "__nucleor_path_separator"; };
    if str_eq(name, "path_is_absolute") { return "__nucleor_path_is_absolute"; };
    if str_eq(name, "path_normalize") { return "__nucleor_path_normalize"; };
    if str_eq(name, "path_with_extension") { return "__nucleor_path_with_extension"; };
    if str_eq(name, "path_strip_extension") { return "__nucleor_path_strip_extension"; };
    if str_eq(name, "path_components") { return "__nucleor_path_components"; };
    // RFC-0019 phase 1: TOML parser
    if str_eq(name, "toml_parse_string") { return "__nucleor_toml_parse_string"; };
    if str_eq(name, "toml_parse_file") { return "__nucleor_toml_parse_file"; };
    if str_eq(name, "toml_get_str") { return "__nucleor_toml_get_str"; };
    if str_eq(name, "toml_get_int") { return "__nucleor_toml_get_int"; };
    if str_eq(name, "toml_has") { return "__nucleor_toml_has"; };
    // RFC-0019 phase 1: manifest validation
    if str_eq(name, "manifest_validate") { return "__nucleor_manifest_validate"; };
    if str_eq(name, "manifest_report") { return "__nucleor_manifest_report"; };
    // Decisions §B5: byte-buffer + endian helpers + MessagePack subset
    if str_eq(name, "buf_write_u8") { return "__nucleor_buf_write_u8"; };
    if str_eq(name, "buf_write_u16_le") { return "__nucleor_buf_write_u16_le"; };
    if str_eq(name, "buf_write_u16_be") { return "__nucleor_buf_write_u16_be"; };
    if str_eq(name, "buf_write_u32_le") { return "__nucleor_buf_write_u32_le"; };
    if str_eq(name, "buf_write_u32_be") { return "__nucleor_buf_write_u32_be"; };
    if str_eq(name, "buf_write_u64_le") { return "__nucleor_buf_write_u64_le"; };
    if str_eq(name, "buf_write_u64_be") { return "__nucleor_buf_write_u64_be"; };
    if str_eq(name, "buf_read_u8") { return "__nucleor_buf_read_u8"; };
    if str_eq(name, "buf_read_u16_le") { return "__nucleor_buf_read_u16_le"; };
    if str_eq(name, "buf_read_u16_be") { return "__nucleor_buf_read_u16_be"; };
    if str_eq(name, "buf_read_u32_le") { return "__nucleor_buf_read_u32_le"; };
    if str_eq(name, "buf_read_u32_be") { return "__nucleor_buf_read_u32_be"; };
    if str_eq(name, "buf_read_u64_le") { return "__nucleor_buf_read_u64_le"; };
    if str_eq(name, "buf_read_u64_be") { return "__nucleor_buf_read_u64_be"; };
    if str_eq(name, "msgpack_write_nil") { return "__nucleor_msgpack_write_nil"; };
    if str_eq(name, "msgpack_write_bool") { return "__nucleor_msgpack_write_bool"; };
    if str_eq(name, "msgpack_write_uint") { return "__nucleor_msgpack_write_uint"; };
    if str_eq(name, "msgpack_write_str") { return "__nucleor_msgpack_write_str"; };
    // Hash + checksum
    if str_eq(name, "crc32") { return "__nucleor_crc32"; };
    if str_eq(name, "crc32_update") { return "__nucleor_crc32_update"; };
    if str_eq(name, "sha256_hex") { return "__nucleor_sha256_hex"; };
    // Base64
    if str_eq(name, "base64_encode") { return "__nucleor_base64_encode"; };
    if str_eq(name, "base64_decode") { return "__nucleor_base64_decode"; };
    // UUID
    if str_eq(name, "uuid_v4") { return "__nucleor_uuid_v4"; };
    // RFC-0007 partial: AtomicI64
    if str_eq(name, "atomic_i64_new") { return "__nucleor_atomic_i64_new"; };
    if str_eq(name, "atomic_i64_free") { return "__nucleor_atomic_i64_free"; };
    if str_eq(name, "atomic_i64_load") { return "__nucleor_atomic_i64_load"; };
    if str_eq(name, "atomic_i64_store") { return "__nucleor_atomic_i64_store"; };
    if str_eq(name, "atomic_i64_fetch_add") { return "__nucleor_atomic_i64_fetch_add"; };
    if str_eq(name, "atomic_i64_fetch_sub") { return "__nucleor_atomic_i64_fetch_sub"; };
    if str_eq(name, "atomic_i64_fetch_and") { return "__nucleor_atomic_i64_fetch_and"; };
    if str_eq(name, "atomic_i64_fetch_or") { return "__nucleor_atomic_i64_fetch_or"; };
    if str_eq(name, "atomic_i64_fetch_xor") { return "__nucleor_atomic_i64_fetch_xor"; };
    if str_eq(name, "atomic_i64_swap") { return "__nucleor_atomic_i64_swap"; };
    if str_eq(name, "atomic_i64_cas") { return "__nucleor_atomic_i64_cas"; };
    // Bit-twiddling
    if str_eq(name, "popcount") { return "__nucleor_popcount"; };
    if str_eq(name, "leading_zeros") { return "__nucleor_leading_zeros"; };
    if str_eq(name, "trailing_zeros") { return "__nucleor_trailing_zeros"; };
    if str_eq(name, "byte_swap") { return "__nucleor_byte_swap"; };
    if str_eq(name, "rotate_left") { return "__nucleor_rotate_left"; };
    if str_eq(name, "rotate_right") { return "__nucleor_rotate_right"; };
    if str_eq(name, "count_ones") { return "__nucleor_count_ones"; };
    if str_eq(name, "count_zeros") { return "__nucleor_count_zeros"; };
    // Math primitives — i64 helpers
    if str_eq(name, "i64_abs") { return "__nucleor_i64_abs"; };
    if str_eq(name, "i64_min") { return "__nucleor_i64_min"; };
    if str_eq(name, "i64_max") { return "__nucleor_i64_max"; };
    if str_eq(name, "i64_clamp") { return "__nucleor_i64_clamp"; };
    if str_eq(name, "i64_sign") { return "__nucleor_i64_sign"; };
    if str_eq(name, "i64_pow") { return "__nucleor_i64_pow"; };
    if str_eq(name, "i64_isqrt") { return "__nucleor_i64_isqrt"; };
    if str_eq(name, "i64_gcd") { return "__nucleor_i64_gcd"; };
    if str_eq(name, "i64_lcm") { return "__nucleor_i64_lcm"; };
    // Math primitives — f64 transcendentals
    if str_eq(name, "f64_sin") { return "__nucleor_f64_sin"; };
    if str_eq(name, "f64_cos") { return "__nucleor_f64_cos"; };
    if str_eq(name, "f64_tan") { return "__nucleor_f64_tan"; };
    if str_eq(name, "f64_asin") { return "__nucleor_f64_asin"; };
    if str_eq(name, "f64_acos") { return "__nucleor_f64_acos"; };
    if str_eq(name, "f64_atan") { return "__nucleor_f64_atan"; };
    if str_eq(name, "f64_atan2") { return "__nucleor_f64_atan2"; };
    if str_eq(name, "f64_sinh") { return "__nucleor_f64_sinh"; };
    if str_eq(name, "f64_cosh") { return "__nucleor_f64_cosh"; };
    if str_eq(name, "f64_tanh") { return "__nucleor_f64_tanh"; };
    if str_eq(name, "f64_exp") { return "__nucleor_f64_exp"; };
    if str_eq(name, "f64_exp2") { return "__nucleor_f64_exp2"; };
    if str_eq(name, "f64_log") { return "__nucleor_f64_log"; };
    if str_eq(name, "f64_log2") { return "__nucleor_f64_log2"; };
    if str_eq(name, "f64_log10") { return "__nucleor_f64_log10"; };
    if str_eq(name, "f64_pow_v") { return "__nucleor_f64_pow_v"; };
    if str_eq(name, "f64_floor") { return "__nucleor_f64_floor"; };
    if str_eq(name, "f64_ceil") { return "__nucleor_f64_ceil"; };
    if str_eq(name, "f64_round") { return "__nucleor_f64_round"; };
    if str_eq(name, "f64_trunc") { return "__nucleor_f64_trunc"; };
    if str_eq(name, "f64_fmod") { return "__nucleor_f64_fmod"; };
    if str_eq(name, "f64_hypot") { return "__nucleor_f64_hypot"; };
    if str_eq(name, "f64_clamp") { return "__nucleor_f64_clamp"; };
    if str_eq(name, "f64_abs") { return "__nucleor_f64_abs"; };
    if str_eq(name, "f64_min") { return "__nucleor_f64_min"; };
    if str_eq(name, "f64_max") { return "__nucleor_f64_max"; };
    if str_eq(name, "f64_sign") { return "__nucleor_f64_sign"; };
    if str_eq(name, "f64_copy_sign") { return "__nucleor_f64_copy_sign"; };
    if str_eq(name, "f64_lerp") { return "__nucleor_f64_lerp"; };
    if str_eq(name, "f64_is_nan") { return "__nucleor_f64_is_nan"; };
    if str_eq(name, "f64_is_inf") { return "__nucleor_f64_is_inf"; };
    if str_eq(name, "f64_is_finite") { return "__nucleor_f64_is_finite"; };
    if str_eq(name, "f64_pi") { return "__nucleor_f64_pi"; };
    if str_eq(name, "f64_tau") { return "__nucleor_f64_tau"; };
    if str_eq(name, "f64_e") { return "__nucleor_f64_e"; };
    if str_eq(name, "f64_sqrt2") { return "__nucleor_f64_sqrt2"; };
    if str_eq(name, "f64_ln2") { return "__nucleor_f64_ln2"; };
    if str_eq(name, "f64_ln10") { return "__nucleor_f64_ln10"; };
    if str_eq(name, "f64_deg_to_rad") { return "__nucleor_f64_deg_to_rad"; };
    if str_eq(name, "f64_rad_to_deg") { return "__nucleor_f64_rad_to_deg"; };
    // V2: parallelism runtime
    if str_eq(name, "par_map") { return "__nucleor_par_map"; };
    if str_eq(name, "par_fold") { return "__nucleor_par_fold"; };
    if str_eq(name, "par_reduce") { return "__nucleor_par_reduce"; };
    // V2: region/arena
    if str_eq(name, "region_new") { return "__nucleor_region_new"; };
    if str_eq(name, "region_alloc") { return "__nucleor_region_alloc"; };
    if str_eq(name, "region_free") { return "__nucleor_region_free"; };
    if str_eq(name, "region_reset") { return "__nucleor_region_reset"; };
    // HashMap
    if str_eq(name, "__nucleor_hashmap_new") { return "__nucleor_hashmap_new"; };
    if str_eq(name, "__nucleor_hashmap_insert") { return "__nucleor_hashmap_insert"; };
    if str_eq(name, "__nucleor_hashmap_get") { return "__nucleor_hashmap_get"; };
    if str_eq(name, "__nucleor_hashmap_contains") { return "__nucleor_hashmap_contains"; };
    return "";
}
fn is_void_ret(name: str) -> i64 {
    if str_eq(name, "print") { return 1; };
    if str_eq(name, "str_free") { return 1; };
    if str_eq(name, "str_arena_free") { return 1; };
    if str_eq(name, "print_raw") { return 1; };
    if str_eq(name, "eprint_raw") { return 1; };
    if str_eq(name, "file_write_string") { return 1; };
    if str_eq(name, "sb_append") { return 1; };
    if str_eq(name, "sb_append_char") { return 1; };
    if str_eq(name, "sb_new_with_cap") { return 0; };
    if str_eq(name, "vec_push") { return 1; };
    if str_eq(name, "vec_pop") { return 1; };
    if str_eq(name, "vec_free") { return 1; };
    if str_eq(name, "vec_set") { return 1; };
    if str_eq(name, "vec_swap") { return 1; };
    if str_eq(name, "vec_extend") { return 1; };
    if str_eq(name, "vec_remove_at") { return 1; };
    if str_eq(name, "vec_insert_at") { return 1; };
    if str_eq(name, "vec_shuffle") { return 1; };
    if str_eq(name, "random_fill") { return 1; };
    if str_eq(name, "print_bool") { return 1; };
    if str_eq(name, "print_f64") { return 1; };
    if str_eq(name, "__nucleor_tensor_set") { return 1; };
    if str_eq(name, "file_append_string") { return 1; };
    if str_eq(name, "sb_free") { return 1; };
    if str_eq(name, "pipe_write") { return 1; };
    if str_eq(name, "pipe_close") { return 1; };
    if str_eq(name, "thread_join") { return 1; };
    if str_eq(name, "mutex_unlock") { return 1; };
    if str_eq(name, "channel_send") { return 1; };
    if str_eq(name, "chan_send") { return 1; };
    if str_eq(name, "cancel_token_cancel") { return 1; };
    if str_eq(name, "rwlock_unlock") { return 1; };
    if str_eq(name, "vec_shuffle") { return 1; };
    if str_eq(name, "random_fill") { return 1; };
    return 0;
}
fn is_ptr_ret(name: str) -> i64 {
    if str_eq(name, "str_concat") { return 1; };
    if str_eq(name, "str_intern") { return 1; };
    if str_eq(name, "str_arena_concat") { return 1; };
    if str_eq(name, "str_arena_substring") { return 1; };
    if str_eq(name, "str_substring") { return 1; };
    if str_eq(name, "file_read_string") { return 1; };
    if str_eq(name, "sb_to_str") { return 1; };
    if str_eq(name, "vec_new") { return 1; };
    if str_eq(name, "vec_with_capacity") { return 1; };
    if str_eq(name, "args_get") { return 1; };
    if str_eq(name, "read_line") { return 1; };
    if str_eq(name, "format_i64") { return 1; };
    if str_eq(name, "int_to_str") { return 1; };
    if str_eq(name, "str_from_int") { return 1; };
    if str_eq(name, "f64_to_str") { return 1; };
    if str_eq(name, "bool_to_str") { return 1; };
    if str_eq(name, "int_to_hex") { return 1; };
    if str_eq(name, "int_to_bin") { return 1; };
    if str_eq(name, "int_to_oct") { return 1; };
    if str_eq(name, "str_pad_left") { return 1; };
    if str_eq(name, "str_pad_right") { return 1; };
    if str_eq(name, "str_center") { return 1; };
    if str_eq(name, "str_join") { return 1; };
    if str_eq(name, "str_lines") { return 1; };
    if str_eq(name, "str_chars") { return 1; };
    if str_eq(name, "format_str") { return 1; };
    if str_eq(name, "format_hex") { return 1; };
    if str_eq(name, "format2_ii") { return 1; };
    if str_eq(name, "format2_si") { return 1; };
    if str_eq(name, "format2_ss") { return 1; };
    if str_eq(name, "format2_is") { return 1; };
    if str_eq(name, "format2_ff") { return 1; };
    if str_eq(name, "format2_fi") { return 1; };
    if str_eq(name, "format2_if") { return 1; };
    if str_eq(name, "format3_fff") { return 1; };
    if str_eq(name, "format_f64") { return 1; };
    if str_eq(name, "format_bool") { return 1; };
    if str_eq(name, "format3_iii") { return 1; };
    if str_eq(name, "format3_sii") { return 1; };
    if str_eq(name, "format3_iss") { return 1; };
    if str_eq(name, "format3_sss") { return 1; };
    if str_eq(name, "format3_ssi") { return 1; };
    if str_eq(name, "format3_sis") { return 1; };
    if str_eq(name, "format3_iis") { return 1; };
    if str_eq(name, "format3_isi") { return 1; };
    if str_eq(name, "format3_iif") { return 1; };
    if str_eq(name, "format3_iff") { return 1; };
    if str_eq(name, "format3_sff") { return 1; };
    if str_eq(name, "format3_ssf") { return 1; };
    if str_eq(name, "format3_sif") { return 1; };
    if str_eq(name, "format3_isf") { return 1; };
    if str_eq(name, "dyn_box_make") { return 1; };
    if str_eq(name, "dyn_box_type") { return 1; };
    if str_eq(name, "dyn_box_data") { return 1; };
    if str_eq(name, "dyn_box_free") { return 1; };
    if str_eq(name, "vec_iter_i64") { return 1; };
    if str_eq(name, "vec_collect_i64") { return 1; };
    if str_eq(name, "vec_count_i64") { return 0; };
    if str_eq(name, "vec_take_i64") { return 1; };
    if str_eq(name, "vec_skip_i64") { return 1; };
    if str_eq(name, "vec_map_i64") { return 1; };
    if str_eq(name, "vec_filter_i64") { return 1; };
    if str_eq(name, "vec_reverse_i64") { return 1; };
    if str_eq(name, "vec_sort_i64") { return 1; };
    if str_eq(name, "vec_clone_i64") { return 1; };
    if str_eq(name, "str_to_lower") { return 1; };
    if str_eq(name, "str_to_upper") { return 1; };
    if str_eq(name, "str_trim") { return 1; };
    if str_eq(name, "str_trim_start") { return 1; };
    if str_eq(name, "str_trim_end") { return 1; };
    if str_eq(name, "str_replace") { return 1; };
    if str_eq(name, "str_repeat") { return 1; };
    if str_eq(name, "str_split") { return 1; };
    if str_eq(name, "str_reverse") { return 1; };
    if str_eq(name, "env_keys") { return 1; };
    if str_eq(name, "sha256") { return 1; };
    if str_eq(name, "py_eval") { return 1; };
    if str_eq(name, "chr") { return 1; };
    if str_eq(name, "getcwd") { return 1; };
    if str_eq(name, "getenv") { return 1; };
    if str_eq(name, "fs_join") { return 1; };
    if str_eq(name, "fs_basename") { return 1; };
    if str_eq(name, "fs_dirname") { return 1; };
    if str_eq(name, "fs_extension") { return 1; };
    if str_eq(name, "fs_temp_dir") { return 1; };
    if str_eq(name, "fs_current_dir") { return 1; };
    if str_eq(name, "fs_canonicalize") { return 1; };
    if str_eq(name, "path_separator") { return 1; };
    if str_eq(name, "path_normalize") { return 1; };
    if str_eq(name, "path_with_extension") { return 1; };
    if str_eq(name, "path_strip_extension") { return 1; };
    if str_eq(name, "path_components") { return 1; };
    if str_eq(name, "manifest_report") { return 1; };
    if str_eq(name, "sha256_hex") { return 1; };
    if str_eq(name, "base64_encode") { return 1; };
    if str_eq(name, "base64_decode") { return 1; };
    if str_eq(name, "uuid_v4") { return 1; };
    if str_eq(name, "hashmap_keys") { return 1; };
    if str_eq(name, "hashmap_values") { return 1; };
    if str_eq(name, "time_iso_now") { return 1; };
    if str_eq(name, "time_format_iso") { return 1; };
    return 0;
}
fn is_ptr_arg(name: str, idx: i64) -> i64 {
    if str_eq(name, "print") { return 1; };
    if str_eq(name, "print_raw") { return 1; };
    if str_eq(name, "eprint_raw") { return 1; };
    if str_eq(name, "panic") { return 1; };
    if str_eq(name, "dbg_str") { return 1; };
    if str_eq(name, "eprint") { return 1; };
    if str_eq(name, "fnv1a_64_str") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "string_from_str") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "string_push_str") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_eq_str") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_starts_with") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_ends_with") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_insert") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_get") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_get_or") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_remove") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "env_get") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "env_get_or") { return 1; };
    if str_eq(name, "env_set") { return 1; };
    if str_eq(name, "env_unset") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "hashset_insert") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashset_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashset_remove") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreemap_insert") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreemap_get") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreemap_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreemap_remove") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreeset_insert") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreeset_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "btreeset_remove") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "fs_exists") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_is_file") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_is_dir") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_size") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_mtime") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_create_dir") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_create_dir_all") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_remove_file") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_rename") { return 1; };
    if str_eq(name, "fs_list_dir") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_join") { return 1; };
    if str_eq(name, "fs_basename") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_dirname") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_extension") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_remove_dir") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "fs_copy_file") { return 1; };
    if str_eq(name, "fs_canonicalize") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "path_is_absolute") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "path_normalize") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "path_with_extension") { return 1; };
    if str_eq(name, "path_strip_extension") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "path_components") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "toml_parse_string") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "toml_parse_file") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "toml_get_str") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "toml_get_int") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "toml_has") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "msgpack_write_str") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "crc32") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "crc32_update") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "sha256_hex") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "base64_encode") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "base64_decode") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_len") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_eq") { return 1; };
    if str_eq(name, "str_char_at") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_substring") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_concat") { return 1; };
    if str_eq(name, "str_intern") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_free") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_arena_concat") { if idx == 1 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "str_arena_substring") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "file_read_string") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "file_write_string") { return 1; };
    if str_eq(name, "system") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "sb_append") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "sb_append_char") { return 0; };
    if str_eq(name, "sb_new_with_cap") { return 0; };
    if str_eq(name, "vec_push") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_get") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_len") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_pop") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_free") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_set") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_first") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_last") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_is_empty") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_swap") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_extend") { return 1; };
    if str_eq(name, "vec_remove_at") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_insert_at") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "random_choice") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_shuffle") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_sample") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "random_fill") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_mean_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_median_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_variance_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_stddev_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_range_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_percentile_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "file_append_string") { return 1; };
    if str_eq(name, "pipe_create") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "pipe_write") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "sha256") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "profile_start") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "profile_end") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "py_eval") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "getenv") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "env_get") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "env_get_or") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "env_unset") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_int") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_bool") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_i64_radix") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "parse_hex") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "parse_bin") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_pad_left") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_pad_right") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_center") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_join") { return 1; };
    if str_eq(name, "str_lines") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_chars") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format_str") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format_hex") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format2_ii") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format2_si") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format2_ss") { if idx == 0 || idx == 1 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "format2_is") { if idx == 0 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "format2_ff") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format2_fi") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format2_if") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_fff") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_iter_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_collect_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_count_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_take_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_skip_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_map_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_filter_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_fold_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_each_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_sum_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_min_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_max_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_contains_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_index_of_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_reverse_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_sort_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_clone_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_clear_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_sum_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_min_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_max_f64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_lower") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_to_upper") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_trim") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_trim_start") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_trim_end") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_is_empty") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_count") { return 1; };
    if str_eq(name, "str_reverse") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_starts_with") { return 1; };
    if str_eq(name, "str_ends_with") { return 1; };
    if str_eq(name, "str_index_of") { return 1; };
    if str_eq(name, "str_contains") { return 1; };
    if str_eq(name, "str_replace") { return 1; };
    if str_eq(name, "str_repeat") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_split") { return 1; };
    if str_eq(name, "env_has") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format_bool") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_iii") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_sii") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format3_iss") { if idx == 0 || idx == 2 || idx == 3 { return 1; }; return 0; };
    if str_eq(name, "format3_sss") { if idx == 0 || idx == 1 || idx == 2 || idx == 3 { return 1; }; return 0; };
    if str_eq(name, "format3_ssi") { if idx == 0 || idx == 1 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "format3_sis") { if idx == 0 || idx == 1 || idx == 3 { return 1; }; return 0; };
    if str_eq(name, "format3_iis") { if idx == 0 || idx == 3 { return 1; }; return 0; };
    if str_eq(name, "format3_isi") { if idx == 0 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "format3_iif") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_iff") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_sff") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format3_ssf") { if idx == 0 || idx == 1 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "format3_sif") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format3_isf") { if idx == 0 || idx == 2 { return 1; }; return 0; };
    if str_eq(name, "vec_avg_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_dot_i64") { return 1; };
    if str_eq(name, "vec_count_eq_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_any_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_all_i64") { if idx == 0 { return 1; }; return 0; };
    return 0;
}

fn emit_builtin_call(sb: i64, name: str, rn: str, d: i64, argc: i64, args: Vec<i32>) -> i64 {
    let ds: str = str_from_int(d);
    // Step 1: inttoptr for ptr args
    let mut ai: i64 = 0;
    while ai < argc {
        if is_ptr_arg(name, ai) == 1 {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, str_from_int(ai));
            sb_append(sb, " = inttoptr i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to ptr\n");
        };
        ai = ai + 1;
    };
    // Step 2: emit call with correct return type
    let vr: i64 = is_void_ret(name);
    let pret: i64 = is_ptr_ret(name);
    if vr == 1 {
        sb_append(sb, "  call void @"); sb_append(sb, rn); sb_append(sb, "(");
    } else if pret == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".rv = call ptr @"); sb_append(sb, rn); sb_append(sb, "(");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = call i64 @"); sb_append(sb, rn); sb_append(sb, "(");
    };
    // Step 3: emit args with correct types
    ai = 0;
    while ai < argc {
        if ai > 0 { sb_append(sb, ", "); };
        if is_ptr_arg(name, ai) == 1 {
            sb_append(sb, "ptr %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, str_from_int(ai));
        } else {
            sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai)));
        };
        ai = ai + 1;
    };
    sb_append(sb, ")\n");
    // Step 4: handle return conversion
    if vr == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
    } else if pret == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = ptrtoint ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    };
    return 0;
}

// =====================================================
// LLVM STRING ESCAPING (NEW in T30)
// =====================================================
fn hex_digit(v: i64) -> str {
    if v == 0 { return "0"; }; if v == 1 { return "1"; }; if v == 2 { return "2"; };
    if v == 3 { return "3"; }; if v == 4 { return "4"; }; if v == 5 { return "5"; };
    if v == 6 { return "6"; }; if v == 7 { return "7"; }; if v == 8 { return "8"; };
    if v == 9 { return "9"; }; if v == 10 { return "A"; }; if v == 11 { return "B"; };
    if v == 12 { return "C"; }; if v == 13 { return "D"; }; if v == 14 { return "E"; };
    if v == 15 { return "F"; }; return "0";
}
fn hex_byte(v: i64) -> str {
    let hi: i64 = v / 16;
    let lo: i64 = v - hi * 16;
    return str_concat(hex_digit(hi), hex_digit(lo));
}
fn escape_llvm_str(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut esb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 92 { sb_append(esb, "\\5C"); }
        else if c == 34 { sb_append(esb, "\\22"); }
        else if c == 10 { sb_append(esb, "\\0A"); }
        else if c == 13 { sb_append(esb, "\\0D"); }
        else if c == 9 { sb_append(esb, "\\09"); }
        else if c == 0 { sb_append(esb, "\\00"); }
        else if c >= 32 && c <= 126 { sb_append_char(esb, c); }
        else { sb_append(esb, "\\"); sb_append(esb, hex_byte(c)); };
        i = i + 1;
    };
    return sb_to_str(esb);
}

// =====================================================
// EMISSION (from T29, extended for builtins + strings)
// =====================================================
fn emit_cmp(sb: i64, cn: str, d: i64, a: i64, b: i64) -> i64 {
    sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, ".cmp = icmp "); sb_append(sb, cn);
    sb_append(sb, " i64 %r."); sb_append(sb, str_from_int(a));
    sb_append(sb, ", %r."); sb_append(sb, str_from_int(b));
    sb_append(sb, "\n  %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, " = zext i1 %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, ".cmp to i64\n"); return 0;
}
fn emit_arith(sb: i64, on: str, d: i64, a: i64, b: i64) -> i64 {
    sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, " = "); sb_append(sb, on);
    sb_append(sb, " i64 %r."); sb_append(sb, str_from_int(a));
    sb_append(sb, ", %r."); sb_append(sb, str_from_int(b));
    sb_append(sb, "\n"); return 0;
}
fn find_extern_idx(pool: Vec<i32>, externs: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(externs) {
        if str_eq(node_field(pool, vec_get(externs, i), 1), name) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

fn emit_extern_call(sb: i64, pool: Vec<i32>, externs: Vec<i32>, ext_idx: i64, d: i64, argc: i64, args: Vec<i32>) -> i64 {
    let nid: i64 = vec_get(externs, ext_idx);
    let name: str = node_field(pool, nid, 1);
    let plist: i64 = node_field(pool, nid, 2);
    let rtype: str = node_field(pool, nid, 3);
    let ds: str = str_from_int(d);
    let lr: str = nr_type_to_llvm(rtype);
    // Step 1: convert args from i64 to target types
    let mut ai: i64 = 0;
    while ai < argc {
        let pnid: i64 = list_get(pool, plist, ai);
        let ptype: str = node_field(pool, pnid, 2);
        let as2: str = str_from_int(ai);
        if is_ptr_type(ptype) == 1 {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, as2);
            sb_append(sb, " = inttoptr i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to ptr\n");
        } else if str_eq(ptype, "i32") {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, as2);
            sb_append(sb, " = trunc i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to i32\n");
        } else if str_eq(ptype, "f64") {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, as2);
            sb_append(sb, " = sitofp i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to double\n");
        };
        ai = ai + 1;
    };
    // Step 2: emit call
    if str_eq(lr, "void") {
        sb_append(sb, "  call void @"); sb_append(sb, name); sb_append(sb, "(");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".rv = call "); sb_append(sb, lr);
        sb_append(sb, " @"); sb_append(sb, name); sb_append(sb, "(");
    };
    // Step 3: emit args with correct types
    ai = 0;
    while ai < argc {
        if ai > 0 { sb_append(sb, ", "); };
        let pnid: i64 = list_get(pool, plist, ai);
        let ptype: str = node_field(pool, pnid, 2);
        let lt: str = nr_type_to_llvm(ptype);
        if is_ptr_type(ptype) == 1 || str_eq(ptype, "i32") || str_eq(ptype, "f64") {
            sb_append(sb, lt); sb_append(sb, " %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, str_from_int(ai));
        } else {
            sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai)));
        };
        ai = ai + 1;
    };
    sb_append(sb, ")\n");
    // Step 4: convert return from target type to i64
    if str_eq(lr, "void") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
    } else if str_eq(lr, "ptr") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = ptrtoint ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    } else if str_eq(lr, "i32") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = sext i32 %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    } else if str_eq(lr, "double") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = fptosi double %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 %r.");
        sb_append(sb, ds); sb_append(sb, ".rv, 0\n");
    };
    return 0;
}

fn emit_inst(inst: Vec<i32>, sb: i64, pool: Vec<i32>, externs: Vec<i32>) -> i64 {
    let op: i64 = ir_op(inst); let d: i64 = ir_dest(inst);
    if op == 0 { sb_append(sb, "  %r."); sb_append(sb, str_from_int(d)); sb_append(sb, " = add i64 "); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, ", 0\n"); }
    else if op == 2 { emit_arith(sb, "add", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 3 { emit_arith(sb, "sub", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 4 { emit_arith(sb, "mul", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 5 { emit_arith(sb, "sdiv", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 6 { emit_arith(sb, "srem", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 7 { emit_cmp(sb, "eq", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 8 { emit_cmp(sb, "ne", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 9 { emit_cmp(sb, "slt", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 10 { emit_cmp(sb, "sgt", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 11 { emit_cmp(sb, "sle", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 12 { emit_cmp(sb, "sge", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 13 { emit_arith(sb, "and", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 14 { emit_arith(sb, "or", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 15 { emit_arith(sb, "xor", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 23 { emit_arith(sb, "shl", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 24 { emit_arith(sb, "ashr", d, ir_op1(inst), ir_op2(inst)); }
    else if op == 16 { sb_append(sb, "  %r."); sb_append(sb, str_from_int(d)); sb_append(sb, " = alloca i64\n"); }
    else if op == 17 { sb_append(sb, "  %r."); sb_append(sb, str_from_int(d)); sb_append(sb, " = load i64, ptr %r."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, "\n"); }
    else if op == 18 { sb_append(sb, "  store i64 %r."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, ", ptr %r."); sb_append(sb, str_from_int(ir_op2(inst))); sb_append(sb, "\n"); }
    else if op == 19 {
        let fn_name: str = ir_op1(inst); let argc: i64 = ir_op2(inst); let args: Vec<i32> = ir_extra(inst);
        let ext_idx: i64 = find_extern_idx(pool, externs, fn_name);
        if ext_idx >= 0 {
            emit_extern_call(sb, pool, externs, ext_idx, d, argc, args);
        } else {
            let rn: str = get_rt_name(fn_name);
            if str_eq(rn, "") {
                // Regular (non-builtin, non-extern) call — all i64
                sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
                sb_append(sb, " = call i64 @"); sb_append(sb, fn_name); sb_append(sb, "(");
                let mut ai: i64 = 0;
                while ai < argc { if ai > 0 { sb_append(sb, ", "); }; sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); ai = ai + 1; };
                sb_append(sb, ")\n");
            } else {
                // Builtin call with ABI conversion
                emit_builtin_call(sb, fn_name, rn, d, argc, args);
            };
        };
    }
    else if op == 31 {
        // v0.3.126: user-fn call — bypasses get_rt_name lookup so
        // user-defined fns shadow runtime helpers of the same name.
        // Always emits `call i64 @<fn_name>(...)` directly.
        let fn_name: str = ir_op1(inst); let argc: i64 = ir_op2(inst); let args: Vec<i32> = ir_extra(inst);
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = call i64 @"); sb_append(sb, fn_name); sb_append(sb, "(");
        let mut ai: i64 = 0;
        while ai < argc { if ai > 0 { sb_append(sb, ", "); }; sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); ai = ai + 1; };
        sb_append(sb, ")\n");
    }
    else if op == 20 { sb_append(sb, "  ret i64 %r."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, "\n"); }
    else if op == 21 { sb_append(sb, "  br label %L"); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, "\n"); }
    else if op == 22 {
        sb_append(sb, "  %br."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, ".cond = icmp ne i64 %r."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, ", 0\n");
        sb_append(sb, "  br i1 %br."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, ".cond, label %L"); sb_append(sb, str_from_int(ir_op2(inst)));
        sb_append(sb, ", label %L"); sb_append(sb, str_from_int(ir_extra(inst))); sb_append(sb, "\n");
    }
    else if op == 26 { sb_append(sb, "  %r."); sb_append(sb, str_from_int(d)); sb_append(sb, " = add i64 %p."); sb_append(sb, str_from_int(ir_op1(inst))); sb_append(sb, ", 0\n"); }
    else if op == 27 {
        // const_str: ptrtoint ptr @.str.IDX to i64
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = ptrtoint ptr @.str."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, " to i64\n");
    }
    else if op == 28 {
        // select: result = select i1 (cond != 0), i64 then_val, i64 else_val
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, ".sel = icmp ne i64 %r."); sb_append(sb, str_from_int(ir_op1(inst)));
        sb_append(sb, ", 0\n  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = select i1 %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, ".sel, i64 %r."); sb_append(sb, str_from_int(ir_op2(inst)));
        sb_append(sb, ", i64 %r."); sb_append(sb, str_from_int(ir_extra(inst)));
        sb_append(sb, "\n");
    }
    else if op == 29 {
        // fn_ptr: ptrtoint ptr @fn_name to i64
        sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
        sb_append(sb, " = ptrtoint ptr @"); sb_append(sb, ir_op1(inst));
        sb_append(sb, " to i64\n");
    }
    else if op == 30 {
        // indirect_call: inttoptr fn ptr, call through it
        let clo_reg: i64 = ir_op1(inst);
        let argc: i64 = ir_op2(inst);
        let args: Vec<i32> = ir_extra(inst);
        let ds: str = str_from_int(d);
        // Step 1: inttoptr to function pointer
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".fp = inttoptr i64 %r.");
        sb_append(sb, str_from_int(clo_reg)); sb_append(sb, " to ptr\n");
        // Step 2: call fn_ptr(arg1, arg2, ...)
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = call i64 %r.");
        sb_append(sb, ds); sb_append(sb, ".fp(");
        let mut ai: i64 = 0;
        while ai < argc {
            if ai > 0 { sb_append(sb, ", "); };
            sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai)));
            ai = ai + 1;
        };
        sb_append(sb, ")\n");
    };
    return 0;
}

fn emit_fn(f: Vec<i32>, pool: Vec<i32>, externs: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let fname: str = ir_fn_name(f);
    let is_main: i64 = str_eq(fname, "main");
    if is_main == 1 {
        // main gets argc/argv and calls init_args before user body
        sb_append(sb, "define i64 @main(i32 %__argc, ptr %__argv) {\n");
        sb_append(sb, "bb.entry:\n");
        sb_append(sb, "  call void @__nucleor_init_args(i32 %__argc, ptr %__argv)\n");
    } else {
        sb_append(sb, "define i64 @"); sb_append(sb, fname); sb_append(sb, "(");
        let pc: i64 = ir_fn_param_count(f); let mut pi: i64 = 0;
        while pi < pc { if pi > 0 { sb_append(sb, ", "); }; sb_append(sb, "i64 %p."); sb_append(sb, str_from_int(pi)); pi = pi + 1; };
        sb_append(sb, ") {\n");
    };
    // Emit entry-block allocas first (hoisted from loop/branch bodies)
    let ea: Vec<i32> = vec_get(f, 2);
    let eac: i64 = vec_len(ea);
    let bc: i64 = ir_fn_block_count(f); let mut bi: i64 = 0;
    while bi < bc {
        let blk: Vec<i32> = ir_fn_get_block(f, bi);
        if bi == 0 {
            if is_main == 0 { sb_append(sb, "bb.entry:\n"); };
            // For main, bb.entry was already emitted above with init_args
            // Emit hoisted entry allocas before any other instructions
            let mut eai: i64 = 0;
            while eai < eac { emit_inst(vec_get(ea, eai), sb, pool, externs); eai = eai + 1; };
        }
        else { sb_append(sb, "L"); sb_append(sb, str_from_int(ir_block_label(blk))); sb_append(sb, ":\n"); };
        let ic: i64 = ir_block_inst_count(blk); let mut jj: i64 = 0;
        while jj < ic { emit_inst(ir_block_get_inst(blk, jj), sb, pool, externs); jj = jj + 1; };
        bi = bi + 1;
    };
    sb_append(sb, "}\n"); return sb_to_str(sb);
}

fn emit_externs() -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "declare void @__nucleor_print_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_putchar(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_str_len(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_eq(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_char_at(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_substring(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_concat(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_intern(ptr)\n");
    sb_append(sb, "declare void @__nucleor_str_free(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_arena_new()\n");
    sb_append(sb, "declare void @__nucleor_str_arena_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_str_arena_bytes(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_arena_concat(i64, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_arena_substring(i64, ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_file_read_string(ptr)\n");
    sb_append(sb, "declare void @__nucleor_file_write_string(ptr, ptr)\n");
    sb_append(sb, "declare void @__nucleor_init_args(i32, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_system(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_new()\n");
    sb_append(sb, "declare ptr @__nucleor_vec_with_capacity(i64)\n");
    sb_append(sb, "declare void @__nucleor_vec_push(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_get(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_len(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_pop(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_free(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_set(ptr, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_first(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_last(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_is_empty(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_swap(ptr, i64, i64)\n");
    sb_append(sb, "declare void @__nucleor_vec_extend(ptr, ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_remove_at(ptr, i64)\n");
    sb_append(sb, "declare void @__nucleor_vec_insert_at(ptr, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sb_new()\n");
    sb_append(sb, "declare void @__nucleor_sb_append(i64, ptr)\n");
    sb_append(sb, "declare void @__nucleor_sb_append_char(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sb_new_with_cap(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_sb_to_str(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_args_count()\n");
    sb_append(sb, "declare ptr @__nucleor_args_get(i64)\n");
    sb_append(sb, "declare void @__nucleor_print_bool(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_read_line()\n");
    sb_append(sb, "declare i64 @__nucleor_read_i64()\n");
    sb_append(sb, "declare i64 @__nucleor_read_byte()\n");
    sb_append(sb, "declare ptr @__nucleor_format_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_int(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_bool(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_int_to_str(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_f64_to_str(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_bool_to_str(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_int_to_hex(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_int_to_bin(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_int_to_oct(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_str_to_i64_radix(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_parse_hex(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_parse_bin(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_pad_left(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_pad_right(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_center(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_join(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_lines(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_chars(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format_str(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format_hex(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_ii(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_si(ptr, ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_ss(ptr, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_is(ptr, i64, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_ff(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_fi(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_if(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_fff(ptr, i64, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format_f64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dyn_box_make(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dyn_box_type(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dyn_box_data(i64)\n");
    sb_append(sb, "declare void @__nucleor_dyn_box_free(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_iter_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_collect_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_count_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_take_i64(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_skip_i64(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_map_i64(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_filter_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_fold_i64(ptr, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_each_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_sum_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_min_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_max_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_contains_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_index_of_i64(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_reverse_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_sort_i64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_clone_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_clear_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_sum_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_min_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_max_f64(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_to_lower(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_to_upper(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_trim(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_trim_start(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_trim_end(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_is_empty(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_count(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_reverse(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_starts_with(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_ends_with(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_index_of(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_contains(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_replace(ptr, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_repeat(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_split(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format_bool(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iii(ptr, i64, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_sii(ptr, ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iss(ptr, i64, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_sss(ptr, ptr, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_ssi(ptr, ptr, ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_sis(ptr, ptr, i64, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iis(ptr, i64, i64, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_isi(ptr, i64, ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iif(ptr, i64, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iff(ptr, i64, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_sff(ptr, ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_ssf(ptr, ptr, ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_sif(ptr, ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_isf(ptr, i64, ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_avg_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_dot_i64(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_count_eq_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_any_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_all_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_alpha(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_digit(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_alnum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_whitespace(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_upper(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_lower(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_hex_digit(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_punct(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_is_ascii(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_to_upper(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_to_lower(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_char_digit_value(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rng_int(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rng_uniform()\n");
    sb_append(sb, "declare i64 @__nucleor_rng_normal()\n");
    sb_append(sb, "declare i64 @__nucleor_rng_bernoulli(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rng_exponential(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_hashmap_keys(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_hashmap_values(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_time_iso_now()\n");
    sb_append(sb, "declare ptr @__nucleor_time_format_iso(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_fnv1a_64_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fnv1a_64_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_murmur3_64(i64)\n");
    sb_append(sb, "declare void @__nucleor_print_raw(ptr)\n");
    sb_append(sb, "declare void @__nucleor_eprint_raw(ptr)\n");
    sb_append(sb, "declare void @__nucleor_file_append_string(ptr, ptr)\n");
    sb_append(sb, "declare void @__nucleor_sb_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_now_ms()\n");
    sb_append(sb, "declare i64 @__nucleor_isatty_stdout()\n");
    sb_append(sb, "declare ptr @__nucleor_chr(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_getcwd()\n");
    sb_append(sb, "declare ptr @__nucleor_getenv(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_pipe_create(ptr)\n");
    sb_append(sb, "declare void @__nucleor_pipe_write(i64, ptr)\n");
    sb_append(sb, "declare void @__nucleor_pipe_close(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_sha256(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_thread_spawn(i64, i64)\n");
    sb_append(sb, "declare void @__nucleor_thread_join(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_async_spawn(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_async_await(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_mutex_new()\n");
    sb_append(sb, "declare void @__nucleor_mutex_lock(i64)\n");
    sb_append(sb, "declare void @__nucleor_mutex_unlock(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_channel_new(i64)\n");
    sb_append(sb, "declare void @__nucleor_channel_send(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_channel_recv(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_channel_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_load(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_cpu_count()\n");
    // HashMap runtime
    sb_append(sb, "declare i64 @__nucleor_hashmap_new()\n");
    sb_append(sb, "declare void @__nucleor_hashmap_insert(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_contains(i64, i64)\n");
    // V2: parallelism runtime
    sb_append(sb, "declare i64 @__nucleor_par_map(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_par_fold(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_par_reduce(i64, i64)\n");
    // V2: region/arena
    sb_append(sb, "declare i64 @__nucleor_region_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_region_alloc(i64, i64)\n");
    sb_append(sb, "declare void @__nucleor_region_free(i64)\n");
    sb_append(sb, "declare void @__nucleor_region_reset(i64)\n");
    // f64 (always available via nucleor_llvm_rt.c)
    sb_append(sb, "declare void @__nucleor_print_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_from_scaled(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_from_bits(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_bits(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_from_bits(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_bits(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32_to_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_fabs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_fmod(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sqrt(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_cos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_pow(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_floor(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_ceil(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_round(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_exp(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_log(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sigmoid(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tanh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_relu(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_gelu(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_abs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_min(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_max(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_clamp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_assert(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_profile_start(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_profile_end(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_ambient_random()\n");
    sb_append(sb, "declare i64 @__nucleor_rng_seed(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_random_uniform(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_random_normal(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_random_int(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_random_bool()\n");
    sb_append(sb, "declare i64 @__nucleor_random_choice(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_shuffle(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_sample(ptr, i64)\n");
    sb_append(sb, "declare void @__nucleor_random_fill(ptr, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_mean_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_median_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_variance_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_stddev_f64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_range_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_percentile_f64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_arena_reset(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_device_alloc(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_device_transfer(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_device_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_view(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_py_eval(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_new(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_append(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_read_prefix(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_evict(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_compact(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvcache_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_kvprefix_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_simd_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_simd_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_simd_fma(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_fma(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_broadcast(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vector_reduce_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_iter(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_take(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_skip(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_chain(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_map(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_filter(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_any(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_all(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_count(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_fold(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rods_f64_encode(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rods_f64_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rods_f64_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rods_f64_div(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_capture_set(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_capture_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrap_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sat_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_ambient_scheduler()\n");
    sb_append(sb, "declare i64 @__nucleor_mutex_new_value(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_mutex_lock_value(i64)\n");
    sb_append(sb, "declare void @__nucleor_mutex_unlock_value(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rwlock_new(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rwlock_read(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rwlock_write(i64)\n");
    sb_append(sb, "declare void @__nucleor_rwlock_unlock(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_cancel_token_new(i64)\n");
    sb_append(sb, "declare void @__nucleor_cancel_token_cancel(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_cancel_token_is_cancelled(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_arena_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_arena_alloc(i64, i64)\n");
    sb_append(sb, "declare void @__nucleor_arena_destroy(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_assert_eq(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_assert_ne(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_panic(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_f64(i64)\n");
    // T1.1 Phase 3a: sizeof_<T>() primitive byte-size builtins.
    sb_append(sb, "declare i64 @__nucleor_sizeof_i8()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_i16()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_i32()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_i64()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_i128()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_u8()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_u16()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_u32()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_u64()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_u128()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_usize()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_isize()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_f16()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_bf16()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_f32()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_f64()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_bool()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_char()\n");
    sb_append(sb, "declare i64 @__nucleor_sizeof_ptr()\n");
    // T1.1 Phase 5: native f64 arithmetic for inline + - * /
    sb_append(sb, "declare i64 @__nucleor_f64_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_div(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_lt(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_gt(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ge(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_eq(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ne(i64, i64)\n");
    // T1.1 Phase 4: full as-cast matrix — float↔int converters.
    sb_append(sb, "declare i64 @__nucleor_f32_to_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_u32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_u32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_to_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_overflow_flag()\n");
    sb_append(sb, "declare i64 @__nucleor_checked_div_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_rem_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_neg_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_div_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_rem_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_neg_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_neg_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_hex(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_bin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_new()\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_push(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_set(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_new()\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_push_bits(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_get_bits(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_from_int(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_int(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_div(i64, i64)\n");
    // T1.1 Phase 5: f32 le/ne (lt/gt/eq already declared below).
    sb_append(sb, "declare i64 @__nucleor_f32_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_ge(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_ne(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_neg(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_abs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_sqrt(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_exp(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_log(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_sin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_cos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_pow(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_lt(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_gt(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_eq(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_from_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_from_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f8e4m3_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f8e5m2_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dbg_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dbg_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dbg_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_eprint_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_eprint_int(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_new(i64, i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_splat(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_div(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_dot(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_max(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_min(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_new(i64, i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_splat(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_new()\n");
    sb_append(sb, "declare i64 @__nucleor_string_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_from_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_push_byte(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_push_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_get_byte(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_as_ptr(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_print(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_eq(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_eq_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_starts_with(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_ends_with(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_clone(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_free(i64)\n");
    // HashMap extras — new/insert/get/contains already declared in the
    // header block above; extras live here.
    sb_append(sb, "declare i64 @__nucleor_hashmap_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_is_empty(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_get_or(i64, ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_merge(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_clone(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_ns()\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_us()\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_ms()\n");
    sb_append(sb, "declare i64 @__nucleor_deadline_check(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_ns()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_us()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_ms()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_seconds()\n");
    sb_append(sb, "declare i64 @__nucleor_time_year(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_month(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_day(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_hour(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_minute(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_second(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_weekday(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_day_of_year(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_elapsed_ms(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sleep_ms(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sleep_us(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_env_get(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_get_or(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_set(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_unset(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_has(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_env_keys()\n");
    sb_append(sb, "declare i64 @__nucleor_process_id()\n");
    sb_append(sb, "declare i64 @__nucleor_os_family()\n");
    sb_append(sb, "declare i64 @__nucleor_os_pointer_width()\n");
    // RFC-0017 phase 4: VecDeque + HashSet
    sb_append(sb, "declare i64 @__nucleor_vecdeque_new()\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_push_back(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_push_front(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_pop_front(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_pop_back(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_set(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_new()\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_insert(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_new()\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_insert(i64, ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_get(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_key_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_val_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_new()\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_insert(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_exists(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_is_file(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_is_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_size(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_mtime(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_create_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_create_dir_all(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_remove_file(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_rename(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_list_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_join(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_basename(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_dirname(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_extension(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_temp_dir()\n");
    sb_append(sb, "declare i64 @__nucleor_fs_current_dir()\n");
    sb_append(sb, "declare i64 @__nucleor_fs_remove_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_copy_file(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_canonicalize(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_path_separator()\n");
    sb_append(sb, "declare i64 @__nucleor_path_is_absolute(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_path_normalize(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_path_with_extension(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_path_strip_extension(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_path_components(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_parse_string(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_parse_file(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_get_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_get_int(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_has(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_manifest_validate(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_manifest_report(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u16_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u16_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u32_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u32_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u64_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u64_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u16_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u16_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u32_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u32_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u64_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u64_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_nil(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_bool(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_uint(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_crc32(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_crc32_update(i64, ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sha256_hex(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_base64_encode(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_base64_decode(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_uuid_v4()\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_load(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_store(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_and(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_or(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_xor(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_swap(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_cas(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_popcount(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_leading_zeros(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_trailing_zeros(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_byte_swap(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rotate_left(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rotate_right(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_count_ones(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_count_zeros(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_abs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_min(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_max(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_clamp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_sign(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_pow(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_isqrt(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_gcd(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_lcm(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_cos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_tan(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_asin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_acos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_atan(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_atan2(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sinh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_cosh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_tanh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_exp(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_exp2(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_log(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_log2(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_log10(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_pow_v(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_floor(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ceil(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_round(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_trunc(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_fmod(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_hypot(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_clamp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_abs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_min(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_max(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sign(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_copy_sign(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_lerp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_is_nan(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_is_inf(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_is_finite(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_pi()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_tau()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_e()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sqrt2()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ln2()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ln10()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_deg_to_rad(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_rad_to_deg(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_zeros(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_fill(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_ones(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_rows(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_cols(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_get(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_set(i64, i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_mean(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_max(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_min(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_variance(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_stddev(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_matmul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_transpose(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_l1(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_l2(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_normalize_l2(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_zscore(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_clip(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_greedy(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sample_topk_temp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sample_nucleus_temp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_median(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_percentile(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_mad(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_entropy(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_top2_gap(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_minmax(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_center(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sample_eps(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sample_rank(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_tensor_sample_gumbel(i64, i64)\n");
    sb_append(sb, "\n");
    return sb_to_str(sb);
}

fn emit_str_constants(strtab: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(strtab) {
        let s: str = vec_get(strtab, i);
        sb_append(sb, "@.str."); sb_append(sb, str_from_int(i));
        sb_append(sb, " = private unnamed_addr constant [");
        sb_append(sb, str_from_int(str_len(s) + 1));
        sb_append(sb, " x i8] c\"");
        sb_append(sb, escape_llvm_str(s));
        sb_append(sb, "\\00\"\n");
        i = i + 1;
    };
    if vec_len(strtab) > 0 { sb_append(sb, "\n"); };
    return sb_to_str(sb);
}

fn nr_type_to_llvm(t: str) -> str {
    if str_eq(t, "str") { return "ptr"; };
    if str_eq(t, "ptr") { return "ptr"; };
    if str_eq(t, "void") { return "void"; };
    // Integer widths (RFC-0015 phase 2)
    if str_eq(t, "i8") { return "i8"; };
    if str_eq(t, "i16") { return "i16"; };
    if str_eq(t, "i32") { return "i32"; };
    if str_eq(t, "i64") { return "i64"; };
    if str_eq(t, "i128") { return "i128"; };
    if str_eq(t, "u8") { return "i8"; };
    if str_eq(t, "u16") { return "i16"; };
    if str_eq(t, "u32") { return "i32"; };
    if str_eq(t, "u64") { return "i64"; };
    if str_eq(t, "u128") { return "i128"; };
    // Pointer-width: 64-bit on x86_64/aarch64; treat as i64 for now,
    // RFC-0022 cross-compile will adjust per target triple.
    if str_eq(t, "isize") { return "i64"; };
    if str_eq(t, "usize") { return "i64"; };
    // Floats
    if str_eq(t, "f16") { return "half"; };
    if str_eq(t, "bf16") { return "bfloat"; };
    if str_eq(t, "f32") { return "float"; };
    if str_eq(t, "f64") { return "double"; };
    // FP8 — software-emulated; lower as i8 storage with conversion fns.
    if str_eq(t, "f8e4m3") { return "i8"; };
    if str_eq(t, "f8e5m2") { return "i8"; };
    // Char — Unicode scalar value, 32-bit
    if str_eq(t, "char") { return "i32"; };
    if str_eq(t, "bool") { return "i1"; };
    return "i64";
}

// RFC-0015: numeric type predicates
fn is_int_type(t: str) -> i64 {
    if str_eq(t, "i8") == 1 { return 1; };
    if str_eq(t, "i16") == 1 { return 1; };
    if str_eq(t, "i32") == 1 { return 1; };
    if str_eq(t, "i64") == 1 { return 1; };
    if str_eq(t, "i128") == 1 { return 1; };
    if str_eq(t, "isize") == 1 { return 1; };
    if str_eq(t, "u8") == 1 { return 1; };
    if str_eq(t, "u16") == 1 { return 1; };
    if str_eq(t, "u32") == 1 { return 1; };
    if str_eq(t, "u64") == 1 { return 1; };
    if str_eq(t, "u128") == 1 { return 1; };
    if str_eq(t, "usize") == 1 { return 1; };
    return 0;
}

fn is_unsigned_type(t: str) -> i64 {
    if str_eq(t, "u8") == 1 { return 1; };
    if str_eq(t, "u16") == 1 { return 1; };
    if str_eq(t, "u32") == 1 { return 1; };
    if str_eq(t, "u64") == 1 { return 1; };
    if str_eq(t, "u128") == 1 { return 1; };
    if str_eq(t, "usize") == 1 { return 1; };
    return 0;
}

fn is_float_type(t: str) -> i64 {
    if str_eq(t, "f16") == 1 { return 1; };
    if str_eq(t, "bf16") == 1 { return 1; };
    if str_eq(t, "f32") == 1 { return 1; };
    if str_eq(t, "f64") == 1 { return 1; };
    if str_eq(t, "f8e4m3") == 1 { return 1; };
    if str_eq(t, "f8e5m2") == 1 { return 1; };
    return 0;
}

fn is_numeric_type(t: str) -> i64 {
    if is_int_type(t) == 1 { return 1; };
    if is_float_type(t) == 1 { return 1; };
    return 0;
}

// Bit-width of a numeric type. Returns 0 for non-numerics.
fn type_bit_width(t: str) -> i64 {
    if str_eq(t, "i8") == 1 || str_eq(t, "u8") == 1 { return 8; };
    if str_eq(t, "i16") == 1 || str_eq(t, "u16") == 1 { return 16; };
    if str_eq(t, "i32") == 1 || str_eq(t, "u32") == 1 { return 32; };
    if str_eq(t, "i64") == 1 || str_eq(t, "u64") == 1 { return 64; };
    if str_eq(t, "i128") == 1 || str_eq(t, "u128") == 1 { return 128; };
    if str_eq(t, "isize") == 1 || str_eq(t, "usize") == 1 { return 64; };
    if str_eq(t, "f8e4m3") == 1 || str_eq(t, "f8e5m2") == 1 { return 8; };
    if str_eq(t, "f16") == 1 || str_eq(t, "bf16") == 1 { return 16; };
    if str_eq(t, "f32") == 1 { return 32; };
    if str_eq(t, "f64") == 1 { return 64; };
    if str_eq(t, "char") == 1 { return 32; };
    if str_eq(t, "bool") == 1 { return 1; };
    return 0;
}
fn is_ptr_type(t: str) -> i64 {
    if str_eq(t, "str") { return 1; };
    if str_eq(t, "ptr") { return 1; };
    return 0;
}

fn emit_user_externs(pool: Vec<i32>, externs: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(externs) {
        let nid: i64 = vec_get(externs, i);
        let name: str = node_field(pool, nid, 1);
        let plist: i64 = node_field(pool, nid, 2);
        let rtype: str = node_field(pool, nid, 3);
        let pc: i64 = list_len(pool, plist);
        sb_append(sb, "declare ");
        sb_append(sb, nr_type_to_llvm(rtype));
        sb_append(sb, " @"); sb_append(sb, name); sb_append(sb, "(");
        let mut pi: i64 = 0;
        while pi < pc {
            if pi > 0 { sb_append(sb, ", "); };
            let pnid: i64 = list_get(pool, plist, pi);
            let ptype: str = node_field(pool, pnid, 2);
            sb_append(sb, nr_type_to_llvm(ptype));
            pi = pi + 1;
        };
        sb_append(sb, ")\n");
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn emit_module_ext(fns: Vec<i32>, strtab: Vec<i32>, pool: Vec<i32>, externs: Vec<i32>) -> str {
    // Pre-size the IR builder to ~2 MB. The s1 self-host produces
    // 2.7 MB of IR; without pre-sizing the SB grows from 256 B
    // through 14 reallocs (256→512→…→4M), each copying the
    // previous buffer. With 2 MB initial we hit at most 1 realloc
    // for the final stretch, saving ~10 MB of cumulative
    // allocator churn per self-host compile.
    let mut sb: i64 = sb_new_with_cap(2097152);
    sb_append(sb, emit_externs());
    sb_append(sb, emit_user_externs(pool, externs));
    sb_append(sb, emit_str_constants(strtab));
    let mut fi: i64 = 0;
    while fi < vec_len(fns) { sb_append(sb, emit_fn(vec_get(fns, fi), pool, externs)); sb_append(sb, "\n"); fi = fi + 1; };
    return sb_to_str(sb);
}

// =====================================================
// LOWERING (from T29, extended for STR_LIT, METHOD, QUAL_CALL)
// =====================================================
fn ctr_new() -> Vec<i32> { let mut c: Vec<i32> = Vec::new(); c.push(0); return c; }
fn ctr_next(c: Vec<i32>) -> i64 { let v: i64 = vec_get(c, vec_len(c) - 1); c.push(v + 1); return v; }
fn sym_new() -> Vec<i32> { return Vec::new(); }
fn sym_set(s: Vec<i32>, name: str, reg: i64) -> i64 { s.push(name); s.push(reg); return 0; }
fn sym_get(s: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = vec_len(s) - 2;
    while i >= 0 { if str_eq(vec_get(s, i), name) { return vec_get(s, i + 1); }; i = i - 2; };
    return 0 - 1;
}
fn sym_clone(s: Vec<i32>) -> Vec<i32> {
    let mut c: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    let cnt: i64 = vec_len(s);
    while i < cnt { c.push(vec_get(s, i)); i = i + 1; };
    return c;
}
fn smap_hash(key: str, cap: i64) -> i64 {
    let mut hash: i64 = 5381;
    let slen: i64 = str_len(key);
    let mut i: i64 = 0;
    while i < slen {
        hash = hash * 33 + str_char_at(key, i);
        if cap > 0 {
            hash = hash - (hash / cap) * cap;
            if hash < 0 { hash = 0 - hash; };
        };
        i = i + 1;
    };
    return hash;
}
fn smap_new_cap(cap: i64) -> Vec<i32> {
    let mut keys: Vec<i32> = Vec::new();
    let mut vals: Vec<i32> = Vec::new();
    let mut occ: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < cap {
        keys.push("");
        vals.push(0 - 1);
        occ.push(0);
        i = i + 1;
    };
    let mut m: Vec<i32> = Vec::new();
    m.push(keys);
    m.push(vals);
    m.push(occ);
    m.push(0);
    m.push(cap);
    return m;
}
fn smap_new() -> Vec<i32> {
    return smap_new_cap(64);
}
fn smap_slots(m: Vec<i32>) -> i64 {
    return vec_get(m, 4);
}
fn smap_slot_used(m: Vec<i32>, slot: i64) -> i64 {
    return vec_get(vec_get(m, 2), slot);
}
fn smap_slot_key(m: Vec<i32>, slot: i64) -> str {
    return vec_get(vec_get(m, 0), slot);
}
fn smap_slot_val(m: Vec<i32>, slot: i64) -> i64 {
    return vec_get(vec_get(m, 1), slot);
}
fn smap_find_slot(m: Vec<i32>, key: str) -> i64 {
    let cap: i64 = smap_slots(m);
    let mut slot: i64 = smap_hash(key, cap);
    let mut probes: i64 = 0;
    while probes < cap {
        if smap_slot_used(m, slot) == 0 { return 0 - slot - 1; };
        if str_eq(smap_slot_key(m, slot), key) == 1 { return slot; };
        slot = slot + 1;
        if slot >= cap { slot = 0; };
        probes = probes + 1;
    };
    return 0 - 1;
}
fn smap_grow(m: Vec<i32>) -> i64 {
    let old_cap: i64 = smap_slots(m);
    let grown: Vec<i32> = smap_new_cap(old_cap * 2);
    let mut i: i64 = 0;
    while i < old_cap {
        if smap_slot_used(m, i) == 1 {
            smap_set(grown, smap_slot_key(m, i), smap_slot_val(m, i));
        };
        i = i + 1;
    };
    vec_set(m, 0, vec_get(grown, 0));
    vec_set(m, 1, vec_get(grown, 1));
    vec_set(m, 2, vec_get(grown, 2));
    vec_set(m, 3, vec_get(grown, 3));
    vec_set(m, 4, vec_get(grown, 4));
    return 0;
}
fn smap_set(m: Vec<i32>, key: str, value: i64) -> i64 {
    let count: i64 = vec_get(m, 3);
    let cap: i64 = smap_slots(m);
    if count * 2 >= cap { smap_grow(m); };
    let slot: i64 = smap_find_slot(m, key);
    if slot >= 0 {
        vec_set(vec_get(m, 1), slot, value);
        return 0;
    };
    let ins: i64 = 0 - slot - 1;
    vec_set(vec_get(m, 0), ins, str_concat("", key));
    vec_set(vec_get(m, 1), ins, value);
    vec_set(vec_get(m, 2), ins, 1);
    vec_set(m, 3, vec_get(m, 3) + 1);
    return 0;
}
fn smap_get(m: Vec<i32>, key: str) -> i64 {
    let slot: i64 = smap_find_slot(m, key);
    if slot >= 0 { return smap_slot_val(m, slot); };
    return 0 - 1;
}
fn lx_new(reg: i64, blk: Vec<i32>) -> Vec<i32> {
    let mut p: Vec<i32> = Vec::new();
    p.push(reg);
    p.push(blk);
    return p;
}
fn lx_reg(p: Vec<i32>) -> i64 { return vec_get(p, 0); }
fn lx_blk(p: Vec<i32>) -> Vec<i32> { return vec_get(p, 1); }
fn tok_to_ir(tok: i64) -> i64 {
    if tok == 20 { return 2; }; if tok == 21 { return 3; }; if tok == 22 { return 4; };
    if tok == 23 { return 5; }; if tok == 24 { return 6; }; if tok == 30 { return 7; };
    if tok == 31 { return 8; }; if tok == 32 { return 9; }; if tok == 33 { return 10; };
    if tok == 34 { return 11; }; if tok == 35 { return 12; };
    if tok == 36 { return 13; }; if tok == 37 { return 14; };
    // v0.3.103: bitwise ops. Map `&` (token 82) to LLVM `and i64`
    // (iop 13 — same as `&&` since both lower to bitwise AND of i64
    // operands), `|` (token 65) to `or i64` (iop 14), and `^`
    // (token 94) to a new `xor i64` (iop 15). The parse_bitwise
    // tier between parse_eq and parse_and_expr (logical &&) ensures
    // these operators actually reach the binop chain instead of
    // dying after the LHS with a diag.
    if tok == 82 { return 13; }; if tok == 65 { return 14; }; if tok == 94 { return 15; };
    // v0.3.104: shift ops. Token 115 = `<<` (lexer), 116 = synthetic
    // `>>` produced by parse_shift when it sees two adjacent `>`.
    // iops 16-17 are alloca/load — can't reuse. Use 23/24 (free).
    if tok == 115 { return 23; }; if tok == 116 { return 24; };
    return 0 - 1;
}
fn is_cmp_or_logic(iop: i64) -> i64 { if iop >= 7 && iop <= 14 { return 1; }; return 0; }

// Struct registry helpers
fn trait_impl_register(impls: Vec<i32>, type_name: str, method_name: str, mangled: str) -> i64 {
    impls.push(type_name); impls.push(method_name); impls.push(mangled); return 0;
}
fn trait_impl_find(impls: Vec<i32>, type_name: str, method_name: str) -> str {
    let mut i: i64 = 0;
    while i < vec_len(impls) {
        if str_eq(vec_get(impls, i), type_name) == 1 && str_eq(vec_get(impls, i + 1), method_name) == 1 {
            return vec_get(impls, i + 2);
        };
        i = i + 3;
    };
    return "";
}

fn iter_method_for_vec(mname: str) -> i64 {
    // T2.2 (v0.2.348): method names that map to the typed
    // `vec_<name>_i64` runtime helpers in
    // stdlib/runtime/nucleor_llvm_rt.c. Used by lower_expr's
    // method-dispatch path so `v.map(f)` lowers to
    // `vec_map_i64(v, f)` instead of the unwired `vec_map`.
    // Anything not in this set falls through to the existing
    // `vec_<method>` convention — preserves backward compat with
    // current `.push`, `.pop`, `.len`, `.get`, `.set`, etc.
    // v0.3.88: `.iter()` is an identity pass-through that lets users
    // write the Rust idiom `vec.iter().sum()`. Routes to vec_iter_i64
    // which returns the same Vec ptr. Without this, .iter() was
    // unwired and the chain failed at clang link.
    if str_eq(mname, "iter") == 1 { return 1; };
    if str_eq(mname, "map") == 1 { return 1; };
    if str_eq(mname, "filter") == 1 { return 1; };
    if str_eq(mname, "fold") == 1 { return 1; };
    if str_eq(mname, "each") == 1 { return 1; };
    if str_eq(mname, "sum") == 1 { return 1; };
    if str_eq(mname, "min") == 1 { return 1; };
    if str_eq(mname, "max") == 1 { return 1; };
    if str_eq(mname, "contains") == 1 { return 1; };
    if str_eq(mname, "index_of") == 1 { return 1; };
    if str_eq(mname, "reverse") == 1 { return 1; };
    if str_eq(mname, "sort") == 1 { return 1; };
    if str_eq(mname, "clone") == 1 { return 1; };
    if str_eq(mname, "clear") == 1 { return 1; };
    // v0.3.102: `.collect()` is the canonical Rust terminator for an
    // iterator chain (`v.iter().map(f).collect()`). It's an identity
    // pass-through here since the prior `.map` already returns a Vec.
    if str_eq(mname, "collect") == 1 { return 1; };
    // v0.3.108: `.count()` returns iterator length (mirrors Rust
    // Iterator::count). For Vec it's `v.len()` — runtime helper
    // is `__nucleor_vec_count_i64`, alias for vec_len in the C side.
    if str_eq(mname, "count") == 1 { return 1; };
    // v0.3.109: take/skip return fresh Vec views; any/all are
    // boolean predicate terminators. Each routes via iter_method_for_vec
    // → vec_<name>_i64 runtime helper.
    if str_eq(mname, "take") == 1 { return 1; };
    if str_eq(mname, "skip") == 1 { return 1; };
    if str_eq(mname, "any") == 1 { return 1; };
    if str_eq(mname, "all") == 1 { return 1; };
    return 0;
}

fn tensor_builtin_method_name(mname: str) -> str {
    if str_eq(mname, "rows") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "cols") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "len") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "get") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "set") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "matmul") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "transpose") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sum") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "mean") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "max") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "min") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "variance") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "stddev") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "l1") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "l2") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "normalize_l2") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "zscore") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "clip") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "softmax_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "argmax_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "argmin_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "greedy") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "exp") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sqrt") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "abs") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "log") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sigmoid") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "tanh") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "relu") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "dot") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "reshape") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "flatten") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "add") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sub") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "mul") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "div") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "square") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "pow") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sin") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "cos") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "concat_rows") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "concat_cols") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "trace") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "outer") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "layernorm") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sum_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "mean_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "logsumexp_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sample_topk_temp") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sample_nucleus_temp") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sample_eps") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sample_rank") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sample_gumbel") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "median") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "percentile") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "mad") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "entropy") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "top2_gap") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "tile") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "repeat_rows") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "take_rows") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "drop_rows") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "minmax") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "center") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "reverse_cols") == 1 { return str_concat("__nucleor_tensor_", mname); };
    return "";
}

fn type_base_name(t: str) -> str {
    // Hot path: this fn runs on every type comparison during type-
    // check. The prior implementation allocated 4-7 substrings per
    // call (one per prefix probe). Replaced with non-allocating
    // str_starts_with checks; the only remaining allocation is the
    // final substring(0, i) when the input contains a generic angle
    // bracket (e.g. "Vec<i32>" → "Vec"). Most calls return the input
    // unchanged or hit the early "fixed<" / scalar paths.
    let mut base: str = t;
    let tlen: i64 = str_len(base);
    if str_starts_with(base, "&mut ") == 1 { base = str_substring(base, 5, tlen); }
    else if tlen >= 1 && str_char_at(base, 0) == 38 { base = str_substring(base, 1, tlen); };
    let slen: i64 = str_len(base);
    if str_starts_with(base, "Box<") == 1 {
        let inner: str = str_substring(base, 4, slen - 1);
        let r: str = type_base_name(inner);
        return r;
    };
    if str_starts_with(base, "fixed<") == 1 { return "i64"; };
    let mut i: i64 = 0;
    while i < slen {
        if str_char_at(base, i) == 60 { return str_substring(base, 0, i); };
        i = i + 1;
    };
    return base;
}
// RFC-0015 phase 1: numeric-type lattice — width + signedness + class.
// type_width:    bit width of a numeric type (0 if non-numeric)
// type_signedness: 1 = signed int, 2 = unsigned int, 3 = float, 0 = other
// type_is_int / type_is_float / type_is_numeric: predicates
//
// `usize`/`isize` are treated as 64-bit on the only target Nucleor ships
// today (x86_64 Windows). The type lattice will revisit this when the
// LP64/ILP32 split arrives with cross-target sysroots.
fn type_width(t: str) -> i64 {
    let b: str = type_base_name(t);
    if str_eq(b, "i8") == 1 || str_eq(b, "u8") == 1 { return 8; };
    if str_eq(b, "i16") == 1 || str_eq(b, "u16") == 1 { return 16; };
    if str_eq(b, "i32") == 1 || str_eq(b, "u32") == 1 { return 32; };
    if str_eq(b, "i64") == 1 || str_eq(b, "u64") == 1 { return 64; };
    if str_eq(b, "isize") == 1 || str_eq(b, "usize") == 1 { return 64; };
    if str_eq(b, "f8e4m3") == 1 || str_eq(b, "f8e5m2") == 1 { return 8; };
    if str_eq(b, "bf16") == 1 || str_eq(b, "f16") == 1 { return 16; };
    if str_eq(b, "f32") == 1 { return 32; };
    if str_eq(b, "f64") == 1 { return 64; };
    if str_eq(b, "char") == 1 { return 32; };
    if str_eq(b, "bool") == 1 { return 1; };
    return 0;
}
fn type_signedness(t: str) -> i64 {
    let b: str = type_base_name(t);
    if str_eq(b, "i8") == 1 || str_eq(b, "i16") == 1 || str_eq(b, "i32") == 1 || str_eq(b, "i64") == 1 || str_eq(b, "isize") == 1 { return 1; };
    if str_eq(b, "u8") == 1 || str_eq(b, "u16") == 1 || str_eq(b, "u32") == 1 || str_eq(b, "u64") == 1 || str_eq(b, "usize") == 1 || str_eq(b, "char") == 1 { return 2; };
    if str_eq(b, "f8e4m3") == 1 || str_eq(b, "f8e5m2") == 1 || str_eq(b, "bf16") == 1 || str_eq(b, "f16") == 1 || str_eq(b, "f32") == 1 || str_eq(b, "f64") == 1 { return 3; };
    return 0;
}
fn type_is_int(t: str) -> i64 {
    let s: i64 = type_signedness(t);
    if s == 1 || s == 2 { return 1; };
    return 0;
}
fn type_is_float(t: str) -> i64 {
    if type_signedness(t) == 3 { return 1; };
    return 0;
}
fn type_is_numeric(t: str) -> i64 {
    if type_signedness(t) > 0 { return 1; };
    return 0;
}

// T1.1 Phase 3b: byte size of a primitive type. Returns 0 for
// non-primitives (caller must handle struct/array/ref types).
fn type_byte_size(t: str) -> i64 {
    let b: str = type_base_name(t);
    if str_eq(b, "i8") == 1 || str_eq(b, "u8") == 1 || str_eq(b, "bool") == 1 { return 1; };
    if str_eq(b, "i16") == 1 || str_eq(b, "u16") == 1 { return 2; };
    if str_eq(b, "f16") == 1 || str_eq(b, "bf16") == 1 { return 2; };
    if str_eq(b, "i32") == 1 || str_eq(b, "u32") == 1 { return 4; };
    if str_eq(b, "f32") == 1 || str_eq(b, "char") == 1 { return 4; };
    if str_eq(b, "i64") == 1 || str_eq(b, "u64") == 1 { return 8; };
    if str_eq(b, "f64") == 1 { return 8; };
    if str_eq(b, "isize") == 1 || str_eq(b, "usize") == 1 { return 8; };
    if str_eq(b, "i128") == 1 || str_eq(b, "u128") == 1 { return 16; };
    if str_eq(b, "f8e4m3") == 1 || str_eq(b, "f8e5m2") == 1 { return 1; };
    if str_eq(b, "ptr") == 1 { return 8; };
    return 0;
}

// T1.1 Phase 3b: natural alignment of a primitive type (= byte size
// for primitives). For non-primitives returns 0.
fn type_align(t: str) -> i64 {
    return type_byte_size(t);
}

// T1.1 Phase 3b: align `offset` up to `align`. Returns the next
// multiple of `align` >= offset. Assumes align > 0.
fn align_up(offset: i64, align: i64) -> i64 {
    if align <= 1 { return offset; };
    let rem: i64 = offset - (offset / align) * align;
    if rem == 0 { return offset; };
    return offset + (align - rem);
}

// T1.1 Phase 3b: compute byte size of a struct given its repr.
// `repr` is "C" (natural alignment), "packed" (no alignment),
// or "" / "Nucleor" (default — currently 8 bytes per field
// because Nucleor stores everything as i64 slots in a Vec<i32>).
//
// Returns 0 if the struct has any non-primitive field type the
// computation can't yet handle (nested struct, generic, array).
// Caller can fall back to default size in that case.
fn struct_byte_size(pool: Vec<i32>, struct_nid: i64, repr: str) -> i64 {
    let flist: i64 = node_field(pool, struct_nid, 2);
    let cnt: i64 = list_len(pool, flist);
    if cnt == 0 { return 0; };
    let mut max_align: i64 = 1;
    let mut offset: i64 = 0;
    let is_packed: i64 = if str_eq(repr, "packed") == 1 { 1 } else { 0 };
    let is_c: i64 = if str_eq(repr, "C") == 1 { 1 } else { 0 };
    let is_natural: i64 = if (is_packed + is_c) == 0 { 1 } else { 0 };
    let mut i: i64 = 0;
    while i < cnt {
        let fnode: i64 = list_get(pool, flist, i);
        let ftype: str = node_field(pool, fnode, 2);
        let fsize: i64 = type_byte_size(ftype);
        if fsize == 0 {
            // Unknown / non-primitive field type; fall back to
            // 8 bytes per field (Nucleor's i64-slot representation).
            return cnt * 8;
        };
        if is_packed == 0 {
            let falign: i64 = type_align(ftype);
            if falign > max_align { max_align = falign; };
            offset = align_up(offset, falign);
        };
        offset = offset + fsize;
        i = i + 1;
    };
    if is_natural == 1 {
        // Default Nucleor repr — backing storage is Vec<i32> with
        // one i64 slot per field. Report that observable size.
        return cnt * 8;
    };
    if is_c == 1 {
        // Pad up to the max field alignment so arrays of this struct
        // align correctly. Standard C ABI rule.
        offset = align_up(offset, max_align);
    };
    return offset;
}

// T1.1 Phase 3b: read the `repr` attribute from a struct AST node.
// Looks at the prefix attribute list (if any) for `#[repr(C)]` /
// `#[repr(packed)]`. Returns "C", "packed", or "" if absent.
//
// Currently uses a source-text scan via the surrounding source —
// will be moved to proper attribute-list AST walking once the
// generic attribute storage lands.
fn struct_repr(source: str, struct_name: str) -> str {
    if str_len(source) == 0 || str_len(struct_name) == 0 { return ""; };
    let needle: str = str_concat("struct ", struct_name);
    let pos: i64 = source_find(source, needle);
    if pos < 0 { return ""; };
    // Look back up to 200 chars for an attribute.
    let look_start: i64 = if pos > 200 { pos - 200 } else { 0 };
    let prefix: str = str_substring(source, look_start, pos);
    if source_find(prefix, "#[repr(packed)]") >= 0 { return "packed"; };
    if source_find(prefix, "#[repr(C)]") >= 0 { return "C"; };
    return "";
}

// Helper: find substring in source (returns byte offset or -1).
fn source_find(haystack: str, needle: str) -> i64 {
    let hlen: i64 = str_len(haystack);
    let nlen: i64 = str_len(needle);
    if nlen == 0 { return 0; };
    if hlen < nlen { return 0 - 1; };
    let mut i: i64 = 0;
    while i <= hlen - nlen {
        if str_eq_at(haystack, i, needle) == 1 { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

fn type_is_mut_ref(t: str) -> i64 {
    if str_starts_with(t, "&mut ") == 1 { return 1; };
    return 0;
}
fn type_is_shared_ref(t: str) -> i64 {
    let tlen: i64 = str_len(t);
    if tlen >= 1 && str_char_at(t, 0) == 38 && type_is_mut_ref(t) == 0 { return 1; };
    return 0;
}
fn type_is_ref(t: str) -> i64 {
    if type_is_mut_ref(t) == 1 { return 1; };
    if str_len(t) >= 1 && str_char_at(t, 0) == 38 { return 1; };
    return 0;
}
fn struct_find(pool: Vec<i32>, structs: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(structs) {
        if str_eq(node_field(pool, vec_get(structs, i), 1), name) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}
fn struct_find_type(pool: Vec<i32>, structs: Vec<i32>, name: str) -> i64 {
    return struct_find(pool, structs, type_base_name(name));
}
fn struct_field_idx(pool: Vec<i32>, struct_nid: i64, fname: str) -> i64 {
    let flist: i64 = node_field(pool, struct_nid, 2);
    let cnt: i64 = list_len(pool, flist);
    let mut i: i64 = 0;
    while i < cnt {
        let fn_nid: i64 = list_get(pool, flist, i);
        if str_eq(node_field(pool, fn_nid, 1), fname) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

fn struct_field_type(pool: Vec<i32>, struct_nid: i64, fname: str) -> str {
    let flist: i64 = node_field(pool, struct_nid, 2);
    let cnt: i64 = list_len(pool, flist);
    let mut i: i64 = 0;
    while i < cnt {
        let fn_nid: i64 = list_get(pool, flist, i);
        if str_eq(node_field(pool, fn_nid, 1), fname) { return node_field(pool, fn_nid, 2); };
        i = i + 1;
    };
    return "";
}

fn expr_struct_type(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let stype: i64 = sym_get(sym, str_concat("__type_", node_field(pool, nid, 1)));
        if stype < 0 { return ""; };
        return stype;
    };
    if kind == 34 { return type_base_name(node_field(pool, nid, 1)); };
    if kind == 90 || kind == 91 { return expr_struct_type(pool, node_field(pool, nid, 1), sym, structs); };
    if kind == 92 { return type_base_name(expr_struct_type(pool, node_field(pool, nid, 1), sym, structs)); };
    if kind == 9 {
        let outer_type: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(outer_type) == 0 { return ""; };
        let si: i64 = struct_find_type(pool, structs, outer_type);
        if si >= 0 { return type_base_name(struct_field_type(pool, vec_get(structs, si), node_field(pool, nid, 2))); };
    };
    // v0.3.58 fix: function call result. For `make_v().x`, the
    // operand of the field access is `make_v()` (kind 7); without
    // this branch expr_struct_type returned "" and lower_expr's
    // kind==9 then errored "cannot resolve field access type".
    // Reuses the v0.3.54 __fnret_<NAME> sym entry populated by
    // populate_fn_returns_in_sym at lower_fn entry.
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        let rt: i64 = sym_get(sym, str_concat("__fnret_", fn_name));
        if rt < 0 { return ""; };
        return type_base_name(rt);
    };
    // v0.3.69 fix: trait method call returning a struct. For
    // `v.rotated().x` (where `rotated` returns V3), the operand
    // of the field access is `v.rotated()` (kind 8). Same shape
    // as v0.3.60 binop_float_type kind 8 — resolve receiver type,
    // construct mangled name, look up __fnret_<MANGLED>.
    if kind == 8 {
        let recv_nid: i64 = node_field(pool, nid, 1);
        let mname: str = node_field(pool, nid, 2);
        let rtype: str = expr_struct_type(pool, recv_nid, sym, structs);
        if str_len(rtype) == 0 { return ""; };
        let mangled: str = str_concat(rtype, str_concat("__", mname));
        let rt: i64 = sym_get(sym, str_concat("__fnret_", mangled));
        if rt < 0 { return ""; };
        return type_base_name(rt);
    };
    // v0.3.123 fix: associated-fn call returning a struct. For
    // `Counter::new().add(10)` the receiver of `.add(10)` is
    // `Counter::new()` (kind 12). The kind-8 method dispatch
    // needs the receiver's struct type to construct the mangled
    // method name; without this branch expr_struct_type returned
    // "" for kind 12 receivers and the chain fell through to
    // `vec_<method>` (clang link `@vec_add undefined`). Lookup
    // mirrors kind 7 — sym entry `__fnret_<TypeName>__<methodname>`.
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let mname12: str = node_field(pool, nid, 2);
        let mangled12: str = str_concat(tname, str_concat("__", mname12));
        let rt12: i64 = sym_get(sym, str_concat("__fnret_", mangled12));
        if rt12 < 0 { return ""; };
        return type_base_name(rt12);
    };
    // v0.3.59 fix: Vec indexing result. For `v[0].x` where v
    // is Vec<V3>, the operand of the field access is `v[0]`
    // (kind 10); same compile-error class as v0.3.58. Reuses
    // the v0.3.55 __fulltype_<vname> sym entry that preserves
    // the generic; extracts T from "Vec<T>" via str_substring.
    //
    // v0.3.63 extension: also handles fixed-size arrays
    // `[T; N]` (mirrors v0.3.62's binop_float_type extension).
    // Production code uses fixed arrays of structs for known-
    // size pose batches / state vectors.
    if kind == 10 {
        // v0.3.68: refactored to use indexed_element_full_type
        // which composes all four operand kinds (3, 9, 7, 10).
        // Returns the BASE name for the struct lookup (callers of
        // expr_struct_type expect the unparameterized struct name).
        let elem_full: str = indexed_element_full_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(elem_full) == 0 { return ""; };
        return type_base_name(elem_full);
    };
    return "";
}

// Enum helpers: pre-populate sym with variant tags and arg counts
fn enum_populate_sym(pool: Vec<i32>, enums: Vec<i32>, sym: Vec<i32>) -> i64 {
    let mut ei: i64 = 0;
    while ei < vec_len(enums) {
        let e_nid: i64 = vec_get(enums, ei);
        let ename: str = node_field(pool, e_nid, 1);
        let vlist: i64 = node_field(pool, e_nid, 2);
        let vcnt: i64 = list_len(pool, vlist);
        let mut vi: i64 = 0;
        while vi < vcnt {
            let v_nid: i64 = list_get(pool, vlist, vi);
            let vname: str = node_field(pool, v_nid, 1);
            let ptypes: i64 = node_field(pool, v_nid, 2);
            let pcount: i64 = list_len(pool, ptypes);
            sym_set(sym, str_concat("__etag_", str_concat(ename, str_concat("_", vname))), vi);
            sym_set(sym, str_concat("__eargs_", str_concat(ename, str_concat("_", vname))), pcount);
            vi = vi + 1;
        };
        ei = ei + 1;
    };
    sym_set(sym, "__etag_Option_Some", 0);
    sym_set(sym, "__eargs_Option_Some", 1);
    sym_set(sym, "__etag_Option_None", 1);
    sym_set(sym, "__eargs_Option_None", 0);
    // v0.3.91 (revised): Result variant tags must match the stdlib
    // `result.nr` convention (Ok=1, Err=0) so the `?` operator works
    // for BOTH compiler-builtin Ok(x)/Err(x) AND
    // stdlib result_ok(x)/result_err(x) calls. Pre-revision had
    // Ok=0/Err=1, which conflicted with the stdlib (used by the
    // existing tests/lang/try_op.nr) — flipping etag tag values is
    // the correct fix; reverting the `?` lowering too. Both Result
    // construction shapes now produce Vec<i32> [tag, payload] with
    // tag=1 on Ok, tag=0 on Err.
    sym_set(sym, "__etag_Result_Ok", 1);
    sym_set(sym, "__eargs_Result_Ok", 1);
    sym_set(sym, "__etag_Result_Err", 0);
    sym_set(sym, "__eargs_Result_Err", 1);
    return 0;
}

// =====================================================
// S12a — STRUCTURED DIAGNOSTIC SURFACE
// =====================================================
fn diag_new() -> Vec<i32> { return Vec::new(); }
fn diag_add(diags: Vec<i32>, severity: str, checker: str, code: str, message: str, fn_name: str, line: i64) -> i64 {
    return diag_add_ex(diags, severity, checker, code, message, fn_name, line, 0, "");
}
fn diag_add_ex(diags: Vec<i32>, severity: str, checker: str, code: str, message: str, fn_name: str, line: i64, col: i64, related_id: str) -> i64 {
    let mut d: Vec<i32> = Vec::new();
    d.push(severity); d.push(checker); d.push(code); d.push(message); d.push(fn_name); d.push(line);
    d.push(col); d.push(related_id);
    // Auto-generate suggestions based on error code
    let mut sug_msg: str = "";
    let mut sug_app: str = "Unspecified";
    if str_eq(code, "OWN-001") { sug_msg = "Consider cloning the value before passing it, or restructure to avoid the second use"; sug_app = "MaybeIncorrect"; };
    if str_eq(code, "TNT-001") { sug_msg = "Sanitize the tainted data before passing to the sensitive function: sanitize(value)"; sug_app = "HasPlaceholders"; };
    if str_eq(code, "EFF-001") { sug_msg = "Remove the 'pure' annotation, or remove the side-effecting call"; sug_app = "MaybeIncorrect"; };
    d.push(sug_msg); // index 8
    d.push(sug_app); // index 9
    // Child note (for ownership: "moved here")
    d.push(""); // index 10: child_message
    d.push(0);  // index 11: child_line
    diags.push(d);
    return vec_len(diags);
}
fn diag_count(diags: Vec<i32>) -> i64 { return vec_len(diags); }
fn diag_count_errors(diags: Vec<i32>) -> i64 {
    let n: i64 = vec_len(diags);
    let mut errors: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let d: Vec<i32> = vec_get(diags, i);
        let sev: str = vec_get(d, 0);
        if str_eq(sev, "error") == 1 { errors = errors + 1; };
        i = i + 1;
    };
    return errors;
}
fn diag_get(diags: Vec<i32>, i: i64) -> Vec<i32> { return vec_get(diags, i); }

// RFC-0028 §Suppression — minimal `#[allow(CODE)]` post-filter.
//
// Scans the source for the literal pattern `#[allow(CODE)]` and
// returns a Vec<str> of the CODEs the user has marked as silenced.
// Whitespace inside the parens is tolerated but the CODE must be a
// bare identifier (e.g. `NUM-003`, `MATCH-001`) — quoted-string
// payloads are not supported in the v0.2 subset.
//
// `#[allow]` is file-wide for now; per-fn / per-block scoping ships
// with the v0.4 attribute-with-argument parsing pass that powers
// RFC-0004 `#[assume]` and RFC-0014 `#[max_depth]`.
fn collect_allowed_codes(source: str) -> Vec<i32> {
    let mut allowed: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[allow(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            // Skip leading whitespace inside the parens.
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) {
                q = q + 1;
            };
            let start: i64 = q;
            // Read the bare identifier up to ')' or whitespace.
            while q < slen {
                let ch: i64 = str_char_at(source, q);
                if ch == 41 || ch == 32 || ch == 9 { break; };
                q = q + 1;
            };
            if q > start {
                let code: str = str_substring(source, start, q);
                allowed.push(code);
            };
            p = q + 1;
        } else {
            p = p + 1;
        };
    };
    return allowed;
}

// v0.3.20 (T3.12): per-fn #[allow_fn(CODE)] attribute. Sibling
// of collect_allowed_codes that ALSO records which fn the
// attribute attaches to. Returns alternating [fn_name, code, ...]
// so the diag filter can suppress only when (diag.fn_name,
// diag.code) matches an entry. Lets users narrow file-wide
// #[allow] noise to a specific fn — handy when one fn has a
// legitimate reason to fire RT-007 but the rest of the file
// shouldn't be silenced too.
fn collect_allow_fn_pairs(source: str) -> Vec<i32> {
    let mut pairs: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[allow_fn(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) { q = q + 1; };
            let code_start: i64 = q;
            while q < slen {
                let ch: i64 = str_char_at(source, q);
                if ch == 41 || ch == 32 || ch == 9 { break; };
                q = q + 1;
            };
            if q == code_start { p = p + 1; continue; };
            let code: str = str_substring(source, code_start, q);
            // Skip past `]` to land at the line break / following content.
            while q < slen && str_char_at(source, q) != 93 { q = q + 1; };
            if q < slen { q = q + 1; };
            // Walk past blank/doc/other-attribute lines for the next `fn NAME(`.
            let mut found: i64 = 0;
            while q + 3 <= slen && found == 0 {
                while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9 || str_char_at(source, q) == 10 || str_char_at(source, q) == 13) {
                    q = q + 1;
                };
                if q + 3 > slen { found = 0 - 1; }
                else if str_char_at(source, q) == 47 && q + 1 < slen && str_char_at(source, q + 1) == 47 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_char_at(source, q) == 35 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_char_at(source, q) == 102 && str_char_at(source, q + 1) == 110 && str_char_at(source, q + 2) == 32 {
                    q = q + 3;
                    let nm_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
                    if q > nm_start {
                        let fname: str = str_substring(source, nm_start, q);
                        pairs.push(fname);
                        pairs.push(code);
                        found = 1;
                    } else {
                        found = 0 - 1;
                    };
                } else if q + 4 <= slen && str_char_at(source, q) == 112 && str_char_at(source, q + 1) == 117 && str_char_at(source, q + 2) == 98 && str_char_at(source, q + 3) == 32 {
                    // pub <space> — could be `pub fn`. Skip past `pub `.
                    q = q + 4;
                } else {
                    found = 0 - 1;
                };
            };
            p = q;
        } else {
            p = p + 1;
        };
    };
    return pairs;
}

// Drop every diagnostic whose code is in `allowed` (file-wide)
// or whose (fn_name, code) is in the per-fn pair list. Errors
// are always preserved — `#[allow]` / `#[allow_fn]` only
// suppress warnings (Rust model). Modifies the input vec by
// rebuilding a filtered copy.
fn filter_allow_suppressed(diags: Vec<i32>, source: str) -> Vec<i32> {
    let allowed: Vec<i32> = collect_allowed_codes(source);
    let allow_fn_pairs: Vec<i32> = collect_allow_fn_pairs(source);
    if vec_len(allowed) == 0 && vec_len(allow_fn_pairs) == 0 { return diags; };
    let mut filtered: Vec<i32> = Vec::new();
    let n: i64 = vec_len(diags);
    let mut i: i64 = 0;
    while i < n {
        let d: Vec<i32> = vec_get(diags, i);
        let sev: str = vec_get(d, 0);
        let code: str = vec_get(d, 2);
        let fn_name: str = vec_get(d, 4);
        let mut suppressed: i64 = 0;
        if str_eq(sev, "error") == 0 {
            let mut j: i64 = 0;
            let m: i64 = vec_len(allowed);
            while j < m && suppressed == 0 {
                if str_eq(vec_get(allowed, j), code) == 1 { suppressed = 1; };
                j = j + 1;
            };
            if suppressed == 0 {
                let pn: i64 = vec_len(allow_fn_pairs);
                let mut pi: i64 = 0;
                while pi + 1 < pn && suppressed == 0 {
                    if str_eq(vec_get(allow_fn_pairs, pi), fn_name) == 1
                       && str_eq(vec_get(allow_fn_pairs, pi + 1), code) == 1 {
                        suppressed = 1;
                    };
                    pi = pi + 2;
                };
            };
        };
        if suppressed == 0 { filtered.push(d); };
        i = i + 1;
    };
    return filtered;
}

// RFC-0028 §Suppression — sibling of collect_allowed_codes.
// Scans the source for the literal pattern `#[deny(CODE)]`; same
// scope rules (file-wide for v0.2; per-fn deferred to v0.4).
fn collect_denied_codes(source: str) -> Vec<i32> {
    let mut denied: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[deny(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) {
                q = q + 1;
            };
            let start: i64 = q;
            while q < slen {
                let ch: i64 = str_char_at(source, q);
                if ch == 41 || ch == 32 || ch == 9 { break; };
                q = q + 1;
            };
            if q > start {
                let code: str = str_substring(source, start, q);
                denied.push(code);
            };
            p = q + 1;
        } else {
            p = p + 1;
        };
    };
    return denied;
}

// Promote every warning-severity diagnostic whose code is in
// `denied` to error severity. Errors stay errors; allow-then-deny
// of the same code is order-dependent (allow strips the diag, so
// deny would not see it) — the recommended user pattern is to use
// at most one of `#[allow(CODE)]` or `#[deny(CODE)]` per code per
// file. Mutates each promoted diag's severity slot in place via
// vec_set (the diag inner vec is the actual storage, not a copy).
// v0.3.21 (T3.13): per-fn #[deny_fn(CODE)] attribute. Sibling
// of #[allow_fn] (v0.3.20) and the file-wide #[deny] (v0.2.152).
// Promotes one warning-tier diagnostic to error for the next fn
// declaration only — useful when a critical fn has stricter
// requirements than the rest of the file. Returns alternating
// [fn_name, code, ...].
fn collect_deny_fn_pairs(source: str) -> Vec<i32> {
    let mut pairs: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[deny_fn(";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) { q = q + 1; };
            let code_start: i64 = q;
            while q < slen {
                let ch: i64 = str_char_at(source, q);
                if ch == 41 || ch == 32 || ch == 9 { break; };
                q = q + 1;
            };
            if q == code_start { p = p + 1; continue; };
            let code: str = str_substring(source, code_start, q);
            while q < slen && str_char_at(source, q) != 93 { q = q + 1; };
            if q < slen { q = q + 1; };
            let mut found: i64 = 0;
            while q + 3 <= slen && found == 0 {
                while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9 || str_char_at(source, q) == 10 || str_char_at(source, q) == 13) {
                    q = q + 1;
                };
                if q + 3 > slen { found = 0 - 1; }
                else if str_char_at(source, q) == 47 && q + 1 < slen && str_char_at(source, q + 1) == 47 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_char_at(source, q) == 35 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_char_at(source, q) == 102 && str_char_at(source, q + 1) == 110 && str_char_at(source, q + 2) == 32 {
                    q = q + 3;
                    let nm_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
                    if q > nm_start {
                        let fname: str = str_substring(source, nm_start, q);
                        pairs.push(fname);
                        pairs.push(code);
                        found = 1;
                    } else {
                        found = 0 - 1;
                    };
                } else if q + 4 <= slen && str_char_at(source, q) == 112 && str_char_at(source, q + 1) == 117 && str_char_at(source, q + 2) == 98 && str_char_at(source, q + 3) == 32 {
                    q = q + 4;
                } else {
                    found = 0 - 1;
                };
            };
            p = q;
        } else {
            p = p + 1;
        };
    };
    return pairs;
}

// v0.3.36 (T3.20): validation pass for #[allow(_fn)] / #[deny(_fn)]
// CODE arguments. The four collectors above accept any well-formed
// substring; a typo like #[allow_fn(RT-099)] would silently absorb
// (the user's intended diagnostic still fires, but the suppression
// they wrote points at nothing).
//
// v0.3.38 (T3.22): tightened from prefix-only to enumerated. The
// canonical code set below mirrors cli_explain_full_smoke (verify.sh
// + verify.ps1). When minting a new code, add to BOTH this list and
// the cli_explain_full_smoke `codes` array. A future ship may unify
// via a generated header or a runtime registry exposed through
// `nuc explain`.
fn is_known_diag_code(code: str) -> i64 {
    // NR series — RFC-0020 baseline pipeline diagnostics
    if str_eq(code, "NR001") == 1 { return 1; };
    if str_eq(code, "NR005") == 1 { return 1; };
    if str_eq(code, "NR010") == 1 { return 1; };
    if str_eq(code, "NR020") == 1 { return 1; };
    if str_eq(code, "NR030") == 1 { return 1; };
    if str_eq(code, "NR031") == 1 { return 1; };
    if str_eq(code, "NR032") == 1 { return 1; };
    if str_eq(code, "NR033") == 1 { return 1; };
    if str_eq(code, "NR034") == 1 { return 1; };
    if str_eq(code, "NR040") == 1 { return 1; };
    if str_eq(code, "NR050") == 1 { return 1; };
    if str_eq(code, "NR051") == 1 { return 1; };
    if str_eq(code, "NR070") == 1 { return 1; };
    if str_eq(code, "NR090") == 1 { return 1; };
    // RFC-0001 RT
    if str_eq(code, "RT-001") == 1 { return 1; };
    if str_eq(code, "RT-002") == 1 { return 1; };
    if str_eq(code, "RT-003") == 1 { return 1; };
    if str_eq(code, "RT-004") == 1 { return 1; };
    if str_eq(code, "RT-005") == 1 { return 1; };
    if str_eq(code, "RT-006") == 1 { return 1; };
    if str_eq(code, "RT-007") == 1 { return 1; };
    if str_eq(code, "RT-008") == 1 { return 1; };
    // RFC-0002 allocators
    if str_eq(code, "ALLOC-001") == 1 { return 1; };
    if str_eq(code, "ALLOC-002") == 1 { return 1; };
    if str_eq(code, "ALLOC-003") == 1 { return 1; };
    // RFC-0003 typed frames
    if str_eq(code, "FRAME-001") == 1 { return 1; };
    if str_eq(code, "FRAME-002") == 1 { return 1; };
    if str_eq(code, "FRAME-003") == 1 { return 1; };
    // OWN — borrow checker
    if str_eq(code, "OWN-001") == 1 { return 1; };
    if str_eq(code, "OWN-002") == 1 { return 1; };
    if str_eq(code, "OWN-003") == 1 { return 1; };
    if str_eq(code, "OWN-004") == 1 { return 1; };
    if str_eq(code, "OWN-005") == 1 { return 1; };
    if str_eq(code, "OWN-006") == 1 { return 1; };
    if str_eq(code, "OWN-007") == 1 { return 1; };
    if str_eq(code, "OWN-008") == 1 { return 1; };
    if str_eq(code, "OWN-009") == 1 { return 1; };
    if str_eq(code, "OWN-010") == 1 { return 1; };
    if str_eq(code, "OWN-011") == 1 { return 1; };
    if str_eq(code, "OWN-012") == 1 { return 1; };
    if str_eq(code, "OWN-013") == 1 { return 1; };
    // GOV — governance
    if str_eq(code, "GOV-001") == 1 { return 1; };
    if str_eq(code, "GOV-002") == 1 { return 1; };
    // TNT — taint
    if str_eq(code, "TNT-001") == 1 { return 1; };
    // TYP — type checker
    if str_eq(code, "TYP-001") == 1 { return 1; };
    if str_eq(code, "TYP-002") == 1 { return 1; };
    if str_eq(code, "TYP-003") == 1 { return 1; };
    if str_eq(code, "TYP-004") == 1 { return 1; };
    if str_eq(code, "TYP-005") == 1 { return 1; };
    if str_eq(code, "TYP-006") == 1 { return 1; };
    if str_eq(code, "TYP-007") == 1 { return 1; };
    if str_eq(code, "TYP-008") == 1 { return 1; };
    if str_eq(code, "TYP-009") == 1 { return 1; };
    if str_eq(code, "TYP-010") == 1 { return 1; };
    // RFC-0004 assume!
    if str_eq(code, "ASSUME-001") == 1 { return 1; };
    if str_eq(code, "ASSUME-002") == 1 { return 1; };
    if str_eq(code, "ASSUME-003") == 1 { return 1; };
    if str_eq(code, "ASSUME-004") == 1 { return 1; };
    if str_eq(code, "ASSUME-005") == 1 { return 1; };
    // RFC-0005 units
    if str_eq(code, "UNIT-001") == 1 { return 1; };
    if str_eq(code, "UNIT-002") == 1 { return 1; };
    if str_eq(code, "UNIT-003") == 1 { return 1; };
    if str_eq(code, "UNIT-004") == 1 { return 1; };
    if str_eq(code, "UNIT-005") == 1 { return 1; };
    // RFC-0006 contracts
    if str_eq(code, "CONTRACT-001") == 1 { return 1; };
    if str_eq(code, "CONTRACT-002") == 1 { return 1; };
    if str_eq(code, "CONTRACT-003") == 1 { return 1; };
    if str_eq(code, "CONTRACT-004") == 1 { return 1; };
    if str_eq(code, "CONTRACT-005") == 1 { return 1; };
    if str_eq(code, "CONTRACT-006") == 1 { return 1; };
    if str_eq(code, "CONTRACT-007") == 1 { return 1; };
    // RFC-0007 atomic
    if str_eq(code, "ATOMIC-001") == 1 { return 1; };
    if str_eq(code, "ATOMIC-002") == 1 { return 1; };
    if str_eq(code, "ATOMIC-003") == 1 { return 1; };
    if str_eq(code, "ATOMIC-004") == 1 { return 1; };
    // RFC-0008 ISR
    if str_eq(code, "ISR-001") == 1 { return 1; };
    if str_eq(code, "ISR-002") == 1 { return 1; };
    if str_eq(code, "ISR-003") == 1 { return 1; };
    if str_eq(code, "ISR-004") == 1 { return 1; };
    if str_eq(code, "ISR-005") == 1 { return 1; };
    if str_eq(code, "ISR-006") == 1 { return 1; };
    // RFC-0009 WCET
    if str_eq(code, "WCET-001") == 1 { return 1; };
    if str_eq(code, "WCET-002") == 1 { return 1; };
    if str_eq(code, "WCET-003") == 1 { return 1; };
    if str_eq(code, "WCET-004") == 1 { return 1; };
    if str_eq(code, "WCET-005") == 1 { return 1; };
    if str_eq(code, "WCET-006") == 1 { return 1; };
    // RFC-0010 DLPack
    if str_eq(code, "DLPACK-001") == 1 { return 1; };
    if str_eq(code, "DLPACK-002") == 1 { return 1; };
    if str_eq(code, "DLPACK-003") == 1 { return 1; };
    if str_eq(code, "DLPACK-004") == 1 { return 1; };
    if str_eq(code, "DLPACK-005") == 1 { return 1; };
    // RFC-0011 nuc-cxx
    if str_eq(code, "CXX-001") == 1 { return 1; };
    if str_eq(code, "CXX-002") == 1 { return 1; };
    if str_eq(code, "CXX-003") == 1 { return 1; };
    if str_eq(code, "CXX-004") == 1 { return 1; };
    if str_eq(code, "CXX-005") == 1 { return 1; };
    // RFC-0012 nuc-bindgen
    if str_eq(code, "BINDGEN-001") == 1 { return 1; };
    if str_eq(code, "BINDGEN-002") == 1 { return 1; };
    if str_eq(code, "BINDGEN-003") == 1 { return 1; };
    if str_eq(code, "BINDGEN-004") == 1 { return 1; };
    if str_eq(code, "BINDGEN-005") == 1 { return 1; };
    // RFC-0013 URDF
    if str_eq(code, "URDF-001") == 1 { return 1; };
    if str_eq(code, "URDF-002") == 1 { return 1; };
    if str_eq(code, "URDF-003") == 1 { return 1; };
    if str_eq(code, "URDF-004") == 1 { return 1; };
    if str_eq(code, "URDF-005") == 1 { return 1; };
    if str_eq(code, "URDF-006") == 1 { return 1; };
    // RFC-0014 max_depth
    if str_eq(code, "DEPTH-001") == 1 { return 1; };
    if str_eq(code, "DEPTH-002") == 1 { return 1; };
    if str_eq(code, "DEPTH-003") == 1 { return 1; };
    if str_eq(code, "DEPTH-004") == 1 { return 1; };
    if str_eq(code, "DEPTH-005") == 1 { return 1; };
    // RFC-0015 numeric types — base set + v0.2.319 expansion (NUM-006..020)
    if str_eq(code, "NUM-001") == 1 { return 1; };
    if str_eq(code, "NUM-002") == 1 { return 1; };
    if str_eq(code, "NUM-003") == 1 { return 1; };
    if str_eq(code, "NUM-004") == 1 { return 1; };
    if str_eq(code, "NUM-005") == 1 { return 1; };
    if str_eq(code, "NUM-006") == 1 { return 1; };
    if str_eq(code, "NUM-007") == 1 { return 1; };
    if str_eq(code, "NUM-008") == 1 { return 1; };
    if str_eq(code, "NUM-009") == 1 { return 1; };
    if str_eq(code, "NUM-010") == 1 { return 1; };
    if str_eq(code, "NUM-011") == 1 { return 1; };
    if str_eq(code, "NUM-012") == 1 { return 1; };
    if str_eq(code, "NUM-013") == 1 { return 1; };
    if str_eq(code, "NUM-014") == 1 { return 1; };
    if str_eq(code, "NUM-015") == 1 { return 1; };
    if str_eq(code, "NUM-016") == 1 { return 1; };
    if str_eq(code, "NUM-017") == 1 { return 1; };
    if str_eq(code, "NUM-018") == 1 { return 1; };
    if str_eq(code, "NUM-019") == 1 { return 1; };
    if str_eq(code, "NUM-020") == 1 { return 1; };
    // RFC-0016 Result/Option/match
    if str_eq(code, "MATCH-001") == 1 { return 1; };
    if str_eq(code, "MATCH-002") == 1 { return 1; };
    if str_eq(code, "MATCH-003") == 1 { return 1; };
    if str_eq(code, "MATCH-004") == 1 { return 1; };
    if str_eq(code, "MATCH-005") == 1 { return 1; };
    if str_eq(code, "MATCH-006") == 1 { return 1; };
    if str_eq(code, "MATCH-007") == 1 { return 1; };
    if str_eq(code, "MATCH-008") == 1 { return 1; };
    if str_eq(code, "MATCH-009") == 1 { return 1; };
    if str_eq(code, "MATCH-010") == 1 { return 1; };
    // RFC-0017 collections
    if str_eq(code, "COLL-001") == 1 { return 1; };
    if str_eq(code, "COLL-002") == 1 { return 1; };
    if str_eq(code, "COLL-003") == 1 { return 1; };
    if str_eq(code, "COLL-004") == 1 { return 1; };
    if str_eq(code, "COLL-005") == 1 { return 1; };
    // RFC-0018 modules
    if str_eq(code, "MOD-001") == 1 { return 1; };
    if str_eq(code, "MOD-002") == 1 { return 1; };
    if str_eq(code, "MOD-003") == 1 { return 1; };
    if str_eq(code, "MOD-004") == 1 { return 1; };
    if str_eq(code, "MOD-005") == 1 { return 1; };
    if str_eq(code, "MOD-006") == 1 { return 1; };
    // RFC-0019 packages
    if str_eq(code, "PKG-001") == 1 { return 1; };
    if str_eq(code, "PKG-002") == 1 { return 1; };
    if str_eq(code, "PKG-003") == 1 { return 1; };
    if str_eq(code, "PKG-004") == 1 { return 1; };
    if str_eq(code, "PKG-005") == 1 { return 1; };
    if str_eq(code, "PKG-006") == 1 { return 1; };
    // RFC-0020 DIAG
    if str_eq(code, "DIAG-001") == 1 { return 1; };
    // RFC-0021 test framework
    if str_eq(code, "TST-001") == 1 { return 1; };
    if str_eq(code, "TST-002") == 1 { return 1; };
    if str_eq(code, "TST-003") == 1 { return 1; };
    // RFC-0022 cross-platform
    if str_eq(code, "TGT-001") == 1 { return 1; };
    if str_eq(code, "TGT-002") == 1 { return 1; };
    if str_eq(code, "TGT-003") == 1 { return 1; };
    if str_eq(code, "TGT-004") == 1 { return 1; };
    // RFC-0031 algebraic laws
    if str_eq(code, "LAW-001") == 1 { return 1; };
    if str_eq(code, "LAW-002") == 1 { return 1; };
    if str_eq(code, "LAW-003") == 1 { return 1; };
    if str_eq(code, "LAW-004") == 1 { return 1; };
    // RFC-0032 effects
    if str_eq(code, "EFF-001") == 1 { return 1; };
    if str_eq(code, "EFF-002") == 1 { return 1; };
    if str_eq(code, "EFF-003") == 1 { return 1; };
    if str_eq(code, "EFF-004") == 1 { return 1; };
    if str_eq(code, "EFF-005") == 1 { return 1; };
    return 0;
}

// Walk all four allow/deny collectors; emit warning[DIAG-001] for
// any CODE whose prefix doesn't match the canonical set. Hint
// names docs/spec/Nucleor_Error_Codes.md as the catalog. The
// emitted diags themselves can be suppressed via #[allow(DIAG-001)]
// on a noisy refactor.
fn emit_diag001_unknown_codes(diags: Vec<i32>, source: str) -> Vec<i32> {
    let allowed: Vec<i32> = collect_allowed_codes(source);
    let allow_fn_pairs: Vec<i32> = collect_allow_fn_pairs(source);
    let denied: Vec<i32> = collect_denied_codes(source);
    let deny_fn_pairs: Vec<i32> = collect_deny_fn_pairs(source);
    let mut i: i64 = 0;
    let an: i64 = vec_len(allowed);
    while i < an {
        let code: str = vec_get(allowed, i);
        if is_known_diag_code(code) == 0 {
            let msg: str = str_concat("unknown diagnostic code '", str_concat(code, "' in #[allow(...)] -- not in canonical diagnostic code set; suppression has no effect (check spelling against docs/spec/Nucleor_Error_Codes.md)"));
            diag_add_ex(diags, "warning", "diag", "DIAG-001", msg, "", 0, 0, "");
        };
        i = i + 1;
    };
    i = 0;
    let dn: i64 = vec_len(denied);
    while i < dn {
        let code: str = vec_get(denied, i);
        if is_known_diag_code(code) == 0 {
            let msg: str = str_concat("unknown diagnostic code '", str_concat(code, "' in #[deny(...)] -- not in canonical diagnostic code set; promotion has no effect (check spelling against docs/spec/Nucleor_Error_Codes.md)"));
            diag_add_ex(diags, "warning", "diag", "DIAG-001", msg, "", 0, 0, "");
        };
        i = i + 1;
    };
    let pn: i64 = vec_len(allow_fn_pairs);
    let mut pi: i64 = 0;
    while pi + 1 < pn {
        let fname: str = vec_get(allow_fn_pairs, pi);
        let code: str = vec_get(allow_fn_pairs, pi + 1);
        if is_known_diag_code(code) == 0 {
            let msg: str = str_concat("unknown diagnostic code '", str_concat(code, str_concat("' in #[allow_fn(...)] on fn '", str_concat(fname, "' -- not in canonical diagnostic code set; suppression has no effect (check spelling against docs/spec/Nucleor_Error_Codes.md)"))));
            diag_add_ex(diags, "warning", "diag", "DIAG-001", msg, fname, 0, 0, "");
        };
        pi = pi + 2;
    };
    let qn: i64 = vec_len(deny_fn_pairs);
    let mut qi: i64 = 0;
    while qi + 1 < qn {
        let fname: str = vec_get(deny_fn_pairs, qi);
        let code: str = vec_get(deny_fn_pairs, qi + 1);
        if is_known_diag_code(code) == 0 {
            let msg: str = str_concat("unknown diagnostic code '", str_concat(code, str_concat("' in #[deny_fn(...)] on fn '", str_concat(fname, "' -- not in canonical diagnostic code set; promotion has no effect (check spelling against docs/spec/Nucleor_Error_Codes.md)"))));
            diag_add_ex(diags, "warning", "diag", "DIAG-001", msg, fname, 0, 0, "");
        };
        qi = qi + 2;
    };
    return diags;
}

fn promote_denied_to_errors(diags: Vec<i32>, source: str) -> Vec<i32> {
    let denied: Vec<i32> = collect_denied_codes(source);
    let deny_fn_pairs: Vec<i32> = collect_deny_fn_pairs(source);
    if vec_len(denied) == 0 && vec_len(deny_fn_pairs) == 0 { return diags; };
    let n: i64 = vec_len(diags);
    let mut i: i64 = 0;
    while i < n {
        let d: Vec<i32> = vec_get(diags, i);
        let sev: str = vec_get(d, 0);
        let code: str = vec_get(d, 2);
        let fn_name: str = vec_get(d, 4);
        if str_eq(sev, "warning") == 1 {
            let mut promoted: i64 = 0;
            let mut j: i64 = 0;
            let m: i64 = vec_len(denied);
            while j < m && promoted == 0 {
                if str_eq(vec_get(denied, j), code) == 1 {
                    vec_set(d, 0, "error");
                    promoted = 1;
                };
                j = j + 1;
            };
            if promoted == 0 {
                let pn: i64 = vec_len(deny_fn_pairs);
                let mut pi: i64 = 0;
                while pi + 1 < pn && promoted == 0 {
                    if str_eq(vec_get(deny_fn_pairs, pi), fn_name) == 1
                       && str_eq(vec_get(deny_fn_pairs, pi + 1), code) == 1 {
                        vec_set(d, 0, "error");
                        promoted = 1;
                    };
                    pi = pi + 2;
                };
            };
        };
        i = i + 1;
    };
    return diags;
}

// RFC-0001 phase 1 — `#[no_alloc]` v1 (file-wide source-level
// static check). Scans for `#[no_alloc]` attribute lines and
// associates each with the next `fn NAME(` declaration. For every
// such fn, scans its body text for forbidden allocator-builtin
// call patterns (literal `<name>(` substrings) and fires `RT-001`
// per violation.
//
// Limitations of the source-level check (acceptable for v1):
//   - False positive if the literal pattern (e.g. `vec_push(`)
//     appears inside a string or comment in the body. Rare in
//     practice; rewrites are easy.
//   - Does not chase transitive calls. `#[no_alloc]` fn that calls
//     `helper()` which itself calls `vec_push` will not fire.
//     v0.4 lifts this once trait-resolution + call-graph analysis
//     ships.
//   - Per-file scope only; no module boundary tracking.
//
// AST-based v2 ships with the rest of RFC-0001 (`#[no_panic]`,
// `#[no_dyn]`, `#[deadline]`).

// T3.7 (v0.3.6): mask string literals + `//` line comments out of a
// fn body before the RT-001/002/003 substring checks scan it. The
// v1 checks were naive str_contains, so a literal `"Vec::new"` in
// a string or `// vec_push(x)` in a comment would false-positive.
// We replace masked ranges with spaces (preserving length so any
// downstream position math stays valid) — `(` characters get
// blanked too, which means the `<name>(` anchor pattern can no
// longer match anywhere inside a quoted/commented region.
fn strip_strings_and_line_comments(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut sb: i64 = sb_new();
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(s, p);
        if c == 47 && p + 1 < slen && str_char_at(s, p + 1) == 47 {
            // Line comment: emit spaces until newline.
            while p < slen && str_char_at(s, p) != 10 {
                sb_append(sb, " ");
                p = p + 1;
            };
            if p < slen { sb_append(sb, "\n"); p = p + 1; };
        } else if c == 34 {
            // Double-quoted string: emit space for the opening quote,
            // then walk past escape sequences until the closing quote.
            sb_append(sb, " ");
            p = p + 1;
            while p < slen && str_char_at(s, p) != 34 {
                if str_char_at(s, p) == 92 && p + 1 < slen {
                    sb_append(sb, "  ");
                    p = p + 2;
                } else {
                    sb_append(sb, " ");
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, " "); p = p + 1; };
        } else if c == 39 {
            // Single-quoted char: same shape as double-quote but with `'`.
            sb_append(sb, " ");
            p = p + 1;
            while p < slen && str_char_at(s, p) != 39 {
                if str_char_at(s, p) == 92 && p + 1 < slen {
                    sb_append(sb, "  ");
                    p = p + 2;
                } else {
                    sb_append(sb, " ");
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, " "); p = p + 1; };
        } else {
            sb_append(sb, str_substring(s, p, p + 1));
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}

fn collect_no_alloc_fns(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[no_alloc]";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        // Skip the rest of any line that starts with `//` so the
        // pattern in a comment (including this comment when the
        // s1 compiles itself) doesn't get treated as a real
        // attribute. Doc comments above the next fn would
        // otherwise collide with their own subject.
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        // Skip string literals — `let pat: str = "#[no_alloc]"`
        // would otherwise be matched as a real attribute. Walk
        // through escape sequences (`\"` is not the closing
        // quote). The s1 itself contains the literal `#[no_alloc]`
        // in a string for use by this scanner; without this guard
        // the s1 false-positives on its own helper fn.
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            // Skip whitespace until we hit the next 'fn '.
            while q + 3 <= slen {
                let c0: i64 = str_char_at(source, q);
                let c1: i64 = str_char_at(source, q + 1);
                let c2: i64 = str_char_at(source, q + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    // 'fn ' — read the name identifier.
                    q = q + 3;
                    let name_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) {
                        q = q + 1;
                    };
                    if q > name_start {
                        let name: str = str_substring(source, name_start, q);
                        fns.push(name);
                    };
                    p = q;
                    break;
                };
                q = q + 1;
            };
            if q + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return fns;
}

// For a given fn_name marked #[no_alloc], scan its body text for
// literal `<alloc_call>(` patterns and emit RT-001 diags into
// `diags` for each match.
fn check_no_alloc_violations(diags: Vec<i32>, source: str, fn_name: str) {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            // Walk to the body's opening '{'.
            let mut q: i64 = p + nlen;
            while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
            if q < slen {
                let body_start: i64 = q + 1;
                let mut depth: i64 = 1;
                q = q + 1;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                let body_raw: str = str_substring(source, body_start, q - 1);
                // T3.7 (v0.3.6): strip `"..."` strings and `// ...`
                // line comments before scanning so a `"Vec::new"` or
                // `// uses vec_push` text doesn't false-positive.
                let body: str = strip_strings_and_line_comments(body_raw);
                // Walk every alloc-builtin name and check str_contains
                // for `<name>(` in the body. Each match becomes one
                // diag; we don't dedup, so two `vec_push(...)` calls
                // produce two RT-001 entries.
                let alloc_names: Vec<i32> = no_alloc_check_list();
                let mut ai: i64 = 0;
                while ai < vec_len(alloc_names) {
                    let n: str = vec_get(alloc_names, ai);
                    // For dot-prefixed method-call sugar (e.g. `.push`)
                    // the `(` separator is already implied; for the
                    // bare names append `(` to anchor the match.
                    let pat: str = str_concat(n, "(");
                    if str_contains(body, pat) == 1 {
                        let msg: str = str_concat("`", str_concat(n, str_concat("` allocates but `", str_concat(fn_name, "` is marked #[no_alloc]"))));
                        diag_add_ex(diags, "error", "rt", "RT-001", msg, fn_name, 0, 0, "");
                    };
                    ai = ai + 1;
                };
            };
            return;
        };
        p = p + 1;
    };
}

// The list of allocator-call patterns to scan for in a #[no_alloc]
// body. Each entry is matched as a literal substring with `(`
// appended (so `vec_push` matches `vec_push(` but not `vec_pushy`),
// EXCEPT entries already containing `(` or `::` are matched verbatim
// so they can encode method-call / constructor forms.
//
// Includes both the underlying builtin names (rare in user code) and
// the user-facing forms (`Vec::new(`, `.push(`, etc.) that the s1
// lowers to those builtins. The dot-prefixed forms catch the method-
// call sugar; this is the only way the source-level v1 check can see
// `vec.push(x)` without an AST.
fn no_alloc_check_list() -> Vec<i32> {
    let mut v: Vec<i32> = Vec::new();
    // Vec — constructor + method calls
    v.push("Vec::new");
    v.push(".push");
    v.push(".pop");
    v.push(".extend");
    v.push(".insert_at");
    v.push(".remove_at");
    // Vec — builtin names (in case user reaches past the sugar)
    v.push("vec_new"); v.push("vec_push"); v.push("vec_pop");
    v.push("vec_extend"); v.push("vec_insert_at"); v.push("vec_remove_at");
    // String builder
    v.push("sb_new"); v.push("sb_append");
    // String allocators
    v.push("str_concat"); v.push("str_substring"); v.push("str_repeat");
    v.push("str_pad_left"); v.push("str_pad_right");
    v.push("str_center"); v.push("str_join");
    // Format-string helpers (every one mallocs)
    v.push("format_i64"); v.push("format_str"); v.push("format_f64");
    v.push("format_hex"); v.push("format_bool");
    v.push("format2_ii"); v.push("format2_si"); v.push("format2_ss");
    v.push("format2_is"); v.push("format2_ff");
    v.push("format3_iii"); v.push("format3_sii"); v.push("format3_iss"); v.push("format3_sss");
    v.push("format3_ssi"); v.push("format3_sis");
    v.push("format3_iis"); v.push("format3_isi");
    v.push("format3_iif"); v.push("format3_iff"); v.push("format3_sff");
    v.push("format3_ssf"); v.push("format3_sif"); v.push("format3_isf");
    // Number-to-string
    v.push("int_to_str"); v.push("f64_to_str"); v.push("bool_to_str");
    // Bare arena builtins (RFC-0002 phase 1) — also alloc
    v.push("arena_new"); v.push("arena_alloc");
    return v;
}

fn enforce_no_alloc(diags: Vec<i32>, source: str) -> Vec<i32> {
    let no_alloc_fns: Vec<i32> = collect_no_alloc_fns(source);
    let mut i: i64 = 0;
    while i < vec_len(no_alloc_fns) {
        let fn_name: str = vec_get(no_alloc_fns, i);
        check_no_alloc_violations(diags, source, fn_name);
        i = i + 1;
    };
    return diags;
}

// === T3.2 (v0.3.1): #[no_panic] enforcement (RT-002) ===
// Mirror of the #[no_alloc] source-level scanner. Walks for the
// `#[no_panic]` attribute, associates each with the next fn,
// then scans the fn body for panic-prone call patterns and emits
// RT-002 per violation.
//
// What "can panic" includes:
//   - `panic("...")`         — explicit panic builtin
//   - `assert_eq` / `assert_ne` — abort on failure
//   - `unwrap` / `.unwrap()`  — Option/Result unwrap (panics on None/Err)
//   - `expect` / `.expect()`  — same with custom message
//   - `dbg!`                  — convention: panics on assertion fail
//
// Same v1 limitations as #[no_alloc]:
//   - Source-level only (no AST, no transitive call-graph chase)
//   - String/comment-aware skip
//   - Per-file scope

fn collect_no_panic_fns(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[no_panic]";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q + 3 <= slen {
                let c0: i64 = str_char_at(source, q);
                let c1: i64 = str_char_at(source, q + 1);
                let c2: i64 = str_char_at(source, q + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    q = q + 3;
                    let name_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) {
                        q = q + 1;
                    };
                    if q > name_start {
                        let name: str = str_substring(source, name_start, q);
                        fns.push(name);
                    };
                    p = q;
                    break;
                };
                q = q + 1;
            };
            if q + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return fns;
}

fn no_panic_check_list() -> Vec<i32> {
    // Call patterns to flag inside #[no_panic] fns. Each entry is
    // a literal substring search; the body MUST contain `<entry>(`
    // (or `.unwrap`/`.expect` for method-call form). Same approach
    // as no_alloc_check_list — easy to extend as new panic-prone
    // primitives ship.
    let mut v: Vec<i32> = Vec::new();
    v.push("panic");
    v.push("assert_eq");
    v.push("assert_ne");
    v.push("unwrap");
    v.push("expect");
    v.push(".unwrap");
    v.push(".expect");
    return v;
}

fn check_no_panic_violations(diags: Vec<i32>, source: str, fn_name: str) {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + nlen;
            while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
            if q < slen {
                let body_start: i64 = q + 1;
                let mut depth: i64 = 1;
                q = q + 1;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                let body_raw: str = str_substring(source, body_start, q - 1);
                let body: str = strip_strings_and_line_comments(body_raw);
                let panic_names: Vec<i32> = no_panic_check_list();
                let mut ai: i64 = 0;
                while ai < vec_len(panic_names) {
                    let n: str = vec_get(panic_names, ai);
                    let pat: str = str_concat(n, "(");
                    if str_contains(body, pat) == 1 {
                        let msg: str = str_concat("`", str_concat(n, str_concat("` can panic but `", str_concat(fn_name, "` is marked #[no_panic]"))));
                        diag_add_ex(diags, "error", "rt", "RT-002", msg, fn_name, 0, 0, "");
                    };
                    ai = ai + 1;
                };
            };
            return;
        };
        p = p + 1;
    };
}

fn enforce_no_panic(diags: Vec<i32>, source: str) -> Vec<i32> {
    let no_panic_fns: Vec<i32> = collect_no_panic_fns(source);
    let mut i: i64 = 0;
    while i < vec_len(no_panic_fns) {
        let fn_name: str = vec_get(no_panic_fns, i);
        check_no_panic_violations(diags, source, fn_name);
        i = i + 1;
    };
    return diags;
}

// === T3.6 (v0.3.5): #[no_dyn] enforcement (RT-003) ===
// Forbids dynamic dispatch in the marked fn — `Box<dyn Trait>`,
// `&dyn Trait`, `&mut dyn Trait`, and bare `dyn Trait` types.
// Matches the v1 source-level pattern of #[no_alloc] / #[no_panic]:
// scan the resolved source for `#[no_dyn]\nfn NAME(...)` pairs,
// then walk each fn body for the literal substring `dyn ` (a
// trailing space rules out identifiers like `dyn_var`). The same
// comment-and-string skip the other RT scanners use guards against
// false positives on the `let pat: str = "#[no_dyn]"` literal in
// this very compiler.

fn collect_no_dyn_fns(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[no_dyn]";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            while q + 3 <= slen {
                let c0: i64 = str_char_at(source, q);
                let c1: i64 = str_char_at(source, q + 1);
                let c2: i64 = str_char_at(source, q + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    q = q + 3;
                    let name_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) {
                        q = q + 1;
                    };
                    if q > name_start {
                        let name: str = str_substring(source, name_start, q);
                        fns.push(name);
                    };
                    p = q;
                    break;
                };
                q = q + 1;
            };
            if q + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return fns;
}

fn check_no_dyn_violations(diags: Vec<i32>, source: str, fn_name: str) {
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            // Scan the SIGNATURE (between fn_name and `{`) AND the
            // body (between matching braces). dyn Trait can appear in
            // either parameters or local bindings.
            let mut sig_q: i64 = p + nlen;
            let sig_start: i64 = sig_q;
            while sig_q < slen && str_char_at(source, sig_q) != 123 { sig_q = sig_q + 1; };
            let sig_text: str = str_substring(source, sig_start, sig_q);
            if sig_q < slen {
                let body_start: i64 = sig_q + 1;
                let mut depth: i64 = 1;
                let mut q: i64 = body_start;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                let body_raw: str = str_substring(source, body_start, q - 1);
                let body: str = strip_strings_and_line_comments(body_raw);
                // The signature itself contains the user-facing type
                // names (`&dyn Trait` etc.) — we want to KEEP those
                // matches, so only the body gets the strip pass. (A
                // `dyn` inside a signature-level string literal is a
                // pathological edge case; not worth slowing v1 for.)
                let combined: str = str_concat(sig_text, str_concat(" ", body));
                if str_contains(combined, "dyn ") == 1 {
                    let msg: str = str_concat("dynamic dispatch (`dyn`) used but `", str_concat(fn_name, "` is marked #[no_dyn]"));
                    diag_add_ex(diags, "error", "rt", "RT-003", msg, fn_name, 0, 0, "");
                };
            };
            return;
        };
        p = p + 1;
    };
}

fn enforce_no_dyn(diags: Vec<i32>, source: str) -> Vec<i32> {
    let no_dyn_fns: Vec<i32> = collect_no_dyn_fns(source);
    let mut i: i64 = 0;
    while i < vec_len(no_dyn_fns) {
        let fn_name: str = vec_get(no_dyn_fns, i);
        check_no_dyn_violations(diags, source, fn_name);
        i = i + 1;
    };
    return diags;
}

// === T3.9 (v0.3.8): RT-005 — FFI call in RT-marked fn ===
// `extern fn` declarations are unknown to the compiler and may
// allocate, panic, take indeterminate time, or do IO. Calling
// one from inside a #[no_alloc] / #[no_panic] / #[deadline] fn
// breaks every RT contract. Until ffi annotations like
// #[ffi_no_alloc] ship (deferred to v0.4), every extern fn call
// from an RT body fires `warning[RT-005]`. Suppressible via
// `#[allow(RT-005)]`.

fn collect_extern_fn_names(source: str) -> Vec<i32> {
    let mut names: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "extern fn ";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + plen;
            let nm_start: i64 = q;
            while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
            if q > nm_start {
                let nm: str = str_substring(source, nm_start, q);
                let mut already: i64 = 0;
                let mut j: i64 = 0;
                while j < vec_len(names) && already == 0 {
                    if str_eq(vec_get(names, j), nm) == 1 { already = 1; };
                    j = j + 1;
                };
                if already == 0 { names.push(nm); };
            };
            p = q;
        } else {
            p = p + 1;
        };
    };
    return names;
}

fn check_no_ffi_violations(diags: Vec<i32>, source: str, fn_name: str, externs: Vec<i32>, attr_label: str) {
    if vec_len(externs) == 0 { return; };
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + nlen;
            while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
            if q < slen {
                let body_start: i64 = q + 1;
                let mut depth: i64 = 1;
                q = q + 1;
                while q < slen && depth > 0 {
                    let c: i64 = str_char_at(source, q);
                    if c == 123 { depth = depth + 1; };
                    if c == 125 { depth = depth - 1; };
                    q = q + 1;
                };
                let body_raw: str = str_substring(source, body_start, q - 1);
                let body: str = strip_strings_and_line_comments(body_raw);
                let mut ei: i64 = 0;
                let en: i64 = vec_len(externs);
                while ei < en {
                    let ext_name: str = vec_get(externs, ei);
                    let pat: str = str_concat(ext_name, "(");
                    if str_contains(body, pat) == 1 {
                        let msg: str = str_concat("FFI call '", str_concat(ext_name, str_concat("' from ", str_concat(attr_label, str_concat(" fn '", str_concat(fn_name, "' -- extern fns may allocate, panic, or block (mark the extern with #[ffi_no_alloc] / #[ffi_no_panic] for per-symbol opt-out, or #[allow(RT-005)] for file-wide)"))))));
                        diag_add_ex(diags, "warning", "rt", "RT-005", msg, fn_name, 0, 0, "");
                    };
                    ei = ei + 1;
                };
            };
            return;
        };
        p = p + 1;
    };
}

// v0.3.24 (T3.15): per-symbol FFI safety markers. An `extern fn`
// declaration prefixed with `#[ffi_no_alloc]` tells the RT-005
// check that this particular FFI symbol is known not to allocate;
// `#[ffi_no_panic]` does the same for panic-prone behaviour.
// The two markers can stack on the same extern declaration. RT
// fns calling an annotated-safe extern stay clean; RT fns calling
// an UNannotated extern still fire RT-005 (the conservative
// default — we don't know what the C side does).
fn collect_externs_with_marker(source: str, marker_pat: str) -> Vec<i32> {
    let mut names: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let plen: i64 = str_len(marker_pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(marker_pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            // Walk forward past blanks/`///`/other-attribute lines for `extern fn NAME(`.
            let mut q: i64 = p + plen;
            while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
            if q < slen { q = q + 1; };
            let mut found: i64 = 0;
            while q + 10 <= slen && found == 0 {
                while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9 || str_char_at(source, q) == 10 || str_char_at(source, q) == 13) {
                    q = q + 1;
                };
                if q + 10 > slen { found = 0 - 1; }
                else if str_char_at(source, q) == 47 && q + 1 < slen && str_char_at(source, q + 1) == 47 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_char_at(source, q) == 35 {
                    while q < slen && str_char_at(source, q) != 10 { q = q + 1; };
                } else if str_eq_at(source, q, "extern fn ") == 1 {
                    q = q + 10;
                    let nm_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
                    if q > nm_start {
                        let nm: str = str_substring(source, nm_start, q);
                        names.push(nm);
                        found = 1;
                    } else {
                        found = 0 - 1;
                    };
                } else {
                    found = 0 - 1;
                };
            };
            p = q;
        } else {
            p = p + 1;
        };
    };
    return names;
}

// Set difference: returns elements of `all` that are NOT in
// `removed`. Used to filter FFI symbols safe for a given RT
// contract out of the "RT-005 fires" list.
fn filter_externs_keep_unsafe(all: Vec<i32>, safe: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let an: i64 = vec_len(all);
    let sn: i64 = vec_len(safe);
    let mut i: i64 = 0;
    while i < an {
        let nm: str = vec_get(all, i);
        let mut is_safe: i64 = 0;
        let mut j: i64 = 0;
        while j < sn && is_safe == 0 {
            if str_eq(vec_get(safe, j), nm) == 1 { is_safe = 1; };
            j = j + 1;
        };
        if is_safe == 0 { out.push(nm); };
        i = i + 1;
    };
    return out;
}

fn enforce_rt005_ffi(diags: Vec<i32>, source: str) -> Vec<i32> {
    let externs: Vec<i32> = collect_extern_fn_names(source);
    if vec_len(externs) == 0 { return diags; };
    // v0.3.24: per-RT-attr safe extern lists. #[no_alloc] body
    // calls are clean iff the extern carries #[ffi_no_alloc];
    // #[no_panic] body iff #[ffi_no_panic]; #[deadline] needs
    // BOTH (deadline determinism subsumes both no-* contracts).
    let ffi_no_alloc_safe: Vec<i32> = collect_externs_with_marker(source, "#[ffi_no_alloc]");
    let ffi_no_panic_safe: Vec<i32> = collect_externs_with_marker(source, "#[ffi_no_panic]");
    let no_alloc_unsafe_externs: Vec<i32> = filter_externs_keep_unsafe(externs, ffi_no_alloc_safe);
    let no_panic_unsafe_externs: Vec<i32> = filter_externs_keep_unsafe(externs, ffi_no_panic_safe);
    // Deadline-safe = intersection; build it as: drop from `externs`
    // any name that is in BOTH safe lists.
    let mut dl_safe: Vec<i32> = Vec::new();
    let an2: i64 = vec_len(ffi_no_alloc_safe);
    let pn2: i64 = vec_len(ffi_no_panic_safe);
    let mut ii: i64 = 0;
    while ii < an2 {
        let nm2: str = vec_get(ffi_no_alloc_safe, ii);
        let mut in_panic: i64 = 0;
        let mut jj: i64 = 0;
        while jj < pn2 && in_panic == 0 {
            if str_eq(vec_get(ffi_no_panic_safe, jj), nm2) == 1 { in_panic = 1; };
            jj = jj + 1;
        };
        if in_panic == 1 { dl_safe.push(nm2); };
        ii = ii + 1;
    };
    let dl_unsafe_externs: Vec<i32> = filter_externs_keep_unsafe(externs, dl_safe);
    let no_alloc_fns: Vec<i32> = collect_no_alloc_fns(source);
    let mut i: i64 = 0;
    while i < vec_len(no_alloc_fns) {
        check_no_ffi_violations(diags, source, vec_get(no_alloc_fns, i), no_alloc_unsafe_externs, "#[no_alloc]");
        i = i + 1;
    };
    let no_panic_fns: Vec<i32> = collect_no_panic_fns(source);
    i = 0;
    while i < vec_len(no_panic_fns) {
        check_no_ffi_violations(diags, source, vec_get(no_panic_fns, i), no_panic_unsafe_externs, "#[no_panic]");
        i = i + 1;
    };
    // Deadline fns live as the wcet inner pair after T3.1 expansion.
    let dl_entries: Vec<i32> = wcet_collect_deadline_fns(source);
    let n: i64 = vec_len(dl_entries);
    let mut k: i64 = 0;
    while k + 1 < n {
        check_no_ffi_violations(diags, source, vec_get(dl_entries, k), dl_unsafe_externs, "#[deadline]");
        k = k + 2;
    };
    return diags;
}

// === T3.10 (v0.3.9): RT-008 — direct recursion in #[deadline] fn ===
// Recursion blows the deadline budget unless the call depth is
// bounded. We detect *direct* self-recursion: the inner fn's
// body contains a literal call to the original (wrapper) name.
// `#[max_depth = N]` opts out — bounded recursion is fine if
// the user has declared a static bound that fits in the budget.
//
// Indirect recursion (A→B→A) requires a call graph and is left
// for the v2 AST-based check.

fn dl_get_wrapper_name(source: str, inner_name: str) -> str {
    // The T3.1 expander emits the inner fn first, then a blank,
    // then the wrapper fn whose body calls deadline_check. Walk
    // forward from the inner's brace-balanced body close, skip
    // whitespace, and read the next `fn NAME(` identifier.
    let needle: str = str_concat("fn ", str_concat(inner_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut found_at: i64 = 0 - 1;
    while p + nlen <= slen && found_at < 0 {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen && m == 1 {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; };
            k = k + 1;
        };
        if m == 1 { found_at = p; }
        else { p = p + 1; };
    };
    if found_at < 0 { return ""; };
    let mut q: i64 = found_at + nlen;
    while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
    if q >= slen { return ""; };
    q = q + 1;
    let mut depth: i64 = 1;
    while q < slen && depth > 0 {
        let c: i64 = str_char_at(source, q);
        if c == 123 { depth = depth + 1; };
        if c == 125 { depth = depth - 1; };
        q = q + 1;
    };
    while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9 || str_char_at(source, q) == 10 || str_char_at(source, q) == 13) {
        q = q + 1;
    };
    if q + 3 > slen { return ""; };
    if str_char_at(source, q) != 102 || str_char_at(source, q + 1) != 110 || str_char_at(source, q + 2) != 32 {
        return "";
    };
    q = q + 3;
    let nm_start: i64 = q;
    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
    if q == nm_start { return ""; };
    return str_substring(source, nm_start, q);
}

fn collect_max_depth_fns(source: str) -> Vec<i32> {
    // Returns the list of fn names tagged with `#[max_depth ...]`
    // (either `#[max_depth = N]` or `#[max_depth(N)]`). Matches the
    // existing collect_no_alloc_fns pattern: skip `//` comments and
    // string literals so the literal in this very compiler doesn't
    // self-match.
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let pat: str = "#[max_depth";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    while p + plen <= slen {
        if p + 1 < slen && str_char_at(source, p) == 47 && str_char_at(source, p + 1) == 47 {
            while p < slen && str_char_at(source, p) != 10 { p = p + 1; };
            p = p + 1;
            continue;
        };
        if str_char_at(source, p) == 34 {
            p = p + 1;
            while p < slen && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            p = p + 1;
            continue;
        };
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < plen {
            if str_char_at(source, p + k) != str_char_at(pat, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            // Skip past `]` so we land at the next line.
            let mut q: i64 = p + plen;
            while q < slen && str_char_at(source, q) != 93 { q = q + 1; };
            if q < slen { q = q + 1; };
            // Walk to next `fn NAME(`.
            while q + 3 <= slen {
                let c0: i64 = str_char_at(source, q);
                let c1: i64 = str_char_at(source, q + 1);
                let c2: i64 = str_char_at(source, q + 2);
                if c0 == 102 && c1 == 110 && c2 == 32 {
                    q = q + 3;
                    let nm_start: i64 = q;
                    while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
                    if q > nm_start {
                        let nm: str = str_substring(source, nm_start, q);
                        fns.push(nm);
                    };
                    p = q;
                    break;
                };
                q = q + 1;
            };
            if q + 3 > slen { p = slen; };
        } else {
            p = p + 1;
        };
    };
    return fns;
}

fn enforce_rt008_recursion(diags: Vec<i32>, source: str) -> Vec<i32> {
    let dl_entries: Vec<i32> = wcet_collect_deadline_fns(source);
    let n: i64 = vec_len(dl_entries);
    if n == 0 { return diags; };
    let max_depth_fns: Vec<i32> = collect_max_depth_fns(source);
    let mut k: i64 = 0;
    while k + 1 < n {
        let inner_name: str = vec_get(dl_entries, k);
        let wrapper_name: str = dl_get_wrapper_name(source, inner_name);
        if str_len(wrapper_name) > 0 {
            // Is the inner (the one carrying the user's #[max_depth]
            // attribute after T3.1 preserves it) opted out?
            let mut bounded: i64 = 0;
            let mut j: i64 = 0;
            let mn: i64 = vec_len(max_depth_fns);
            while j < mn && bounded == 0 {
                if str_eq(vec_get(max_depth_fns, j), inner_name) == 1 { bounded = 1; };
                j = j + 1;
            };
            if bounded == 0 {
                // Scan the inner body (stripped) for `<wrapper>(`.
                let needle: str = str_concat("fn ", str_concat(inner_name, "("));
                let nlen: i64 = str_len(needle);
                let slen: i64 = str_len(source);
                let mut p: i64 = 0;
                while p + nlen <= slen {
                    let mut m: i64 = 1;
                    let mut q: i64 = 0;
                    while q < nlen && m == 1 {
                        if str_char_at(source, p + q) != str_char_at(needle, q) { m = 0; };
                        q = q + 1;
                    };
                    if m == 1 { break; };
                    p = p + 1;
                };
                if p + nlen <= slen {
                    let mut bp: i64 = p + nlen;
                    while bp < slen && str_char_at(source, bp) != 123 { bp = bp + 1; };
                    if bp < slen {
                        let body_start: i64 = bp + 1;
                        let mut depth: i64 = 1;
                        bp = bp + 1;
                        while bp < slen && depth > 0 {
                            let c: i64 = str_char_at(source, bp);
                            if c == 123 { depth = depth + 1; };
                            if c == 125 { depth = depth - 1; };
                            bp = bp + 1;
                        };
                        let body_raw: str = str_substring(source, body_start, bp - 1);
                        let body: str = strip_strings_and_line_comments(body_raw);
                        let call_pat: str = str_concat(wrapper_name, "(");
                        if str_contains(body, call_pat) == 1 {
                            let msg: str = str_concat("'", str_concat(wrapper_name, "' has #[deadline] and recursively calls itself; add #[max_depth = N] to opt out (recursion can blow the deadline budget)"));
                            diag_add_ex(diags, "warning", "rt", "RT-008", msg, wrapper_name, 0, 0, "");
                        };
                    };
                };
            };
        };
        k = k + 2;
    };
    return diags;
}

// === T3.8 (v0.3.7): RT-006 — RT attribute on async fn ===
// expand_async_strip_keyword (in the resolver-level expanders)
// drops the `async` keyword for good. To still detect "an RT
// attribute was attached to an `async fn`", that pass leaves
// behind a marker comment line at column 0 for every offender.
// The marker prefix is intentionally short and weird so the
// exact byte sequence (with leading newline) does not appear
// elsewhere in the s1 compiler source — without that, the
// scanner would self-match on its own needle.
//
// Per the RFC: async is non-deterministic by design (thread
// scheduling, IO wakeups, etc.) and cannot satisfy any RT
// guarantee. The two have to be mutually exclusive.

fn enforce_rt006_async(diags: Vec<i32>, source: str) -> Vec<i32> {
    // Match \n + "//__NUC6T:" — leading newline ensures we only
    // hit markers that the expander emitted at column 0, not
    // string-literal contents (preceded by ") or mid-line prose.
    let needle: str = "\n//__NUC6T:";
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + nlen <= slen {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; break; };
            k = k + 1;
        };
        if m == 1 {
            let nm_start: i64 = p + nlen;
            let mut q: i64 = nm_start;
            while q < slen && str_char_at(source, q) != 10 && str_char_at(source, q) != 13 { q = q + 1; };
            let fn_name: str = str_substring(source, nm_start, q);
            let msg: str = str_concat("RT attribute (e.g. #[no_alloc] / #[no_panic] / #[no_dyn] / #[deadline]) on async fn '", str_concat(fn_name, "' -- async is non-deterministic by design and cannot satisfy real-time guarantees"));
            diag_add_ex(diags, "error", "rt", "RT-006", msg, fn_name, 0, 0, "");
            p = q;
        } else {
            p = p + 1;
        };
    };
    return diags;
}

// === T3.3 (v0.3.2): static WCET (v1 estimator, RT-004) ===
// Parses every `#[deadline = N]` fn, estimates its worst-case
// execution time via a simple statement counter, and emits a
// compile-time RT-004 warning when the estimate exceeds the
// declared deadline.
//
// v1 estimator heuristics (conservative, prone to false positives
// — explicitly documented so users can `#[allow(RT-004)]` when
// the estimator is wrong):
//   - Each `;` (statement terminator) = 1 unit = 0.1 µs
//   - Each `while` keyword multiplies the inner unit count by a
//     coarse multiplier (1, 100, 1000, 10000 for 0/1/2/3+ whiles)
//   - Hard cap at 1e6 units to prevent runaway
// Conversion: estimated_us = ceil(units / 10).
//
// Ship shape: warning-level diagnostic (not error) because the
// estimator is deliberately crude. v0.3.2b's AST-based v2 will
// tighten the estimate + promote to error for unambiguous cases.

fn wcet_collect_deadline_fns(source: str) -> Vec<i32> {
    // Returns alternating [inner_name1, limit1_us, ...].
    // Scans for `deadline_check(__nuc_dl_start, N)` which the
    // T3.1 expander emits in every wrapper, then walks back up to
    // 1024 bytes for the matching `__nuc_dl_inner_<...>` ident.
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let needle: str = "deadline_check(__nuc_dl_start,";
    let nlen: i64 = str_len(needle);
    let inner_pat: str = "__nuc_dl_inner_";
    let ipl: i64 = str_len(inner_pat);
    let mut p: i64 = 0;
    let max_outer_iters: i64 = 1000000;  // safety bound
    let mut outer_iters: i64 = 0;
    while p + nlen <= slen && outer_iters < max_outer_iters {
        outer_iters = outer_iters + 1;
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen && m == 1 {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; };
            k = k + 1;
        };
        if m == 1 {
            let mut q: i64 = p + nlen;
            while q < slen && (str_char_at(source, q) == 32 || str_char_at(source, q) == 9) { q = q + 1; };
            let num_start: i64 = q;
            while q < slen && is_digit(str_char_at(source, q)) == 1 { q = q + 1; };
            if q > num_start {
                let limit_us: i64 = str_to_int(str_substring(source, num_start, q));
                let scan_floor: i64 = if p > 1024 { p - 1024 } else { 0 };
                let mut bp: i64 = p;
                let mut found: i64 = 0;
                while bp > scan_floor && found == 0 {
                    if bp + ipl <= slen {
                        let mut im: i64 = 1;
                        let mut ik: i64 = 0;
                        while ik < ipl && im == 1 {
                            if str_char_at(source, bp + ik) != str_char_at(inner_pat, ik) { im = 0; };
                            ik = ik + 1;
                        };
                        if im == 1 {
                            let mut np: i64 = bp + ipl;
                            while np < slen && (is_alnum(str_char_at(source, np)) == 1 || str_char_at(source, np) == 95) {
                                np = np + 1;
                            };
                            let inner_name: str = str_substring(source, bp, np);
                            out.push(inner_name);
                            out.push(limit_us);
                            found = 1;
                        };
                    };
                    if found == 0 { bp = bp - 1; };
                };
            };
            p = q + 1;
        } else {
            p = p + 1;
        };
    };
    return out;
}

fn wcet_estimate_fn_units(source: str, fn_name: str) -> i64 {
    // Counts `;` (statements) inside the named fn body, separately
    // counts `while` keywords, applies a coarse multiplier ladder
    // (1, 100, 1000, 10000 for 0/1/2/3+ loops). Hard-capped at 1e6
    // units. No string/comment skipping — false positives on `;`
    // inside string literals are an acceptable v1 tradeoff.
    let needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut found_at: i64 = 0 - 1;
    while p + nlen <= slen && found_at < 0 {
        let mut m: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen && m == 1 {
            if str_char_at(source, p + k) != str_char_at(needle, k) { m = 0; };
            k = k + 1;
        };
        if m == 1 { found_at = p; }
        else { p = p + 1; };
    };
    if found_at < 0 { return 0; };
    let mut q: i64 = found_at + nlen;
    while q < slen && str_char_at(source, q) != 123 { q = q + 1; };
    if q >= slen { return 0; };
    q = q + 1;
    let mut depth: i64 = 1;
    let mut stmt_count: i64 = 0;
    let mut while_count: i64 = 0;
    let stmt_cap: i64 = 1000000;
    while q < slen && depth > 0 && stmt_count < stmt_cap {
        let c: i64 = str_char_at(source, q);
        if c == 123 { depth = depth + 1; };
        if c == 125 { depth = depth - 1; };
        if c == 59 { stmt_count = stmt_count + 1; };
        if c == 119 && q + 5 <= slen {
            if str_char_at(source, q + 1) == 104 && str_char_at(source, q + 2) == 105
                && str_char_at(source, q + 3) == 108 && str_char_at(source, q + 4) == 101 {
                let prev: i64 = if q > 0 { str_char_at(source, q - 1) } else { 32 };
                let next: i64 = if q + 5 < slen { str_char_at(source, q + 5) } else { 32 };
                let prev_ok: i64 = if is_alnum(prev) == 0 && prev != 95 { 1 } else { 0 };
                let next_ok: i64 = if is_alnum(next) == 0 && next != 95 { 1 } else { 0 };
                if prev_ok == 1 && next_ok == 1 { while_count = while_count + 1; };
            };
        };
        q = q + 1;
    };
    let mut multiplier: i64 = 1;
    if while_count == 1 { multiplier = 100; };
    if while_count == 2 { multiplier = 1000; };
    if while_count >= 3 { multiplier = 10000; };
    let units: i64 = stmt_count * multiplier;
    if units > stmt_cap { return stmt_cap; };
    return units;
}

fn enforce_static_wcet(diags: Vec<i32>, source: str) -> Vec<i32> {
    // For each #[deadline = N] fn (post-resolver shape — inner +
    // outer wrapper pair from T3.1), estimate WCET on the inner
    // body and warn if the estimate exceeds the budget.
    let entries: Vec<i32> = wcet_collect_deadline_fns(source);
    let n: i64 = vec_len(entries);
    let mut i: i64 = 0;
    while i + 1 < n {
        let inner_name: str = vec_get(entries, i);
        let limit_us: i64 = vec_get(entries, i + 1);
        let units: i64 = wcet_estimate_fn_units(source, inner_name);
        let estimated_us: i64 = (units + 9) / 10;
        if estimated_us > limit_us {
            let msg: str = str_concat("static WCET estimate ", str_concat(str_from_int(estimated_us), str_concat(" us (", str_concat(str_from_int(units), str_concat(" units x 0.1 us) exceeds #[deadline = ", str_concat(str_from_int(limit_us), str_concat(" us] (v1 estimator -- use #[allow(RT-004)] file-wide or #[allow_fn(RT-004)] per-fn if the estimate is wrong; default loop multiplier 100x)", "")))))));
            diag_add_ex(diags, "warning", "rt", "RT-004", msg, inner_name, 0, 0, "");
        };
        i = i + 2;
    };
    return diags;
}

// === T3.5 (v0.3.3): RT-007 cross-check — #[deadline] without #[no_alloc] / #[no_panic] ===
// Allocations and panics are non-deterministic and can blow past
// any fixed deadline budget. The runtime deadline check (RT-004)
// catches overruns AFTER the fact. RT-007 nudges authors to also
// declare intent: at least one of #[no_alloc] or #[no_panic]
// should accompany #[deadline] so the compiler can statically
// rule out the most common deadline-busters.

fn enforce_deadline_safety(diags: Vec<i32>, source: str) -> Vec<i32> {
    let dl_entries: Vec<i32> = wcet_collect_deadline_fns(source);
    let no_alloc_fns: Vec<i32> = collect_no_alloc_fns(source);
    let no_panic_fns: Vec<i32> = collect_no_panic_fns(source);
    let n: i64 = vec_len(dl_entries);
    let mut i: i64 = 0;
    while i + 1 < n {
        let inner_name: str = vec_get(dl_entries, i);
        let mut has_no_alloc: i64 = 0;
        let mut j: i64 = 0;
        let na_n: i64 = vec_len(no_alloc_fns);
        while j < na_n && has_no_alloc == 0 {
            if str_eq(vec_get(no_alloc_fns, j), inner_name) == 1 { has_no_alloc = 1; };
            j = j + 1;
        };
        let mut has_no_panic: i64 = 0;
        j = 0;
        let np_n: i64 = vec_len(no_panic_fns);
        while j < np_n && has_no_panic == 0 {
            if str_eq(vec_get(no_panic_fns, j), inner_name) == 1 { has_no_panic = 1; };
            j = j + 1;
        };
        if has_no_alloc == 0 && has_no_panic == 0 {
            let msg: str = str_concat("'", str_concat(inner_name, "' has #[deadline] but neither #[no_alloc] nor #[no_panic]; allocations or panics can break WCET determinism (use #[allow(RT-007)] file-wide, or #[allow_fn(RT-007)] per-fn)"));
            diag_add_ex(diags, "warning", "rt", "RT-007", msg, inner_name, 0, 0, "");
        };
        i = i + 2;
    };
    return diags;
}

fn byte_to_line(source: str, byte_off: i64) -> i64 {
    let slen: i64 = str_len(source);
    let mut line: i64 = 1;
    let mut i: i64 = 0;
    let limit: i64 = byte_off;
    if limit > slen { return 0; };
    while i < limit {
        if str_char_at(source, i) == 10 { line = line + 1; };
        i = i + 1;
    };
    return line;
}

// RFC-0020 phase 1: LineMap — precomputed line-start byte offsets.
// linemap_build returns Vec<i32> where item[k] = byte offset of line (k+1)'s
// first character (line 1 starts at offset 0). Lookup is O(log n) via
// binary search; pair with linemap_col for column number.
fn linemap_build(source: str) -> Vec<i32> {
    let mut starts: Vec<i32> = Vec::new();
    starts.push(0);  // line 1 starts at offset 0
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i < slen {
        if str_char_at(source, i) == 10 { starts.push(i + 1); };
        i = i + 1;
    };
    return starts;
}

fn linemap_line(starts: Vec<i32>, byte_off: i64) -> i64 {
    let n: i64 = vec_len(starts);
    if n == 0 { return 1; };
    let mut lo: i64 = 0;
    let mut hi: i64 = n - 1;
    // Find the largest index `k` such that starts[k] <= byte_off.
    // Returned line number is k + 1 (1-indexed).
    while lo < hi {
        let mid: i64 = (lo + hi + 1) / 2;
        if vec_get(starts, mid) <= byte_off { lo = mid; }
        else { hi = mid - 1; };
    };
    return lo + 1;
}

fn linemap_col(starts: Vec<i32>, byte_off: i64) -> i64 {
    let line: i64 = linemap_line(starts, byte_off);
    let line_start: i64 = vec_get(starts, line - 1);
    return byte_off - line_start + 1;
}

fn linemap_line_count(starts: Vec<i32>) -> i64 { return vec_len(starts); }

fn find_linecol_in_source(source: str, fn_name: str, var_name: str) -> Vec<i32> {
    let slen: i64 = str_len(source);
    let fnlen: i64 = str_len(fn_name);
    let vlen: i64 = str_len(var_name);
    let mut out: Vec<i32> = Vec::new();
    if fnlen == 0 || vlen == 0 { out.push(0); out.push(0); return out; };
    let target: str = str_concat("fn ", fn_name);
    let tlen: i64 = str_len(target);
    let mut i: i64 = 0;
    let mut fn_start: i64 = 0 - 1;
    while i < slen - tlen {
        if str_eq_at(source, i, target) == 1 { fn_start = i; i = slen; };
        i = i + 1;
    };
    if fn_start < 0 { out.push(0); out.push(0); return out; };
    let mut line: i64 = byte_to_line(source, fn_start);
    let mut col: i64 = 1;
    i = fn_start;
    while i < slen - vlen {
        if str_eq_at(source, i, var_name) == 1 {
            out.push(line);
            out.push(col);
            return out;
        };
        if str_char_at(source, i) == 10 { line = line + 1; col = 1; }
        else { col = col + 1; };
        i = i + 1;
    };
    out.push(byte_to_line(source, fn_start));
    out.push(1);
    return out;
}
fn find_in_source(source: str, fn_name: str, var_name: str) -> i64 {
    return vec_get(find_linecol_in_source(source, fn_name, var_name), 0);
}

fn find_column_in_source(source: str, fn_name: str, var_name: str) -> i64 {
    return vec_get(find_linecol_in_source(source, fn_name, var_name), 1);
}

// RFC-0020 phase 1: Rust-style diagnostic rendering.
// Detects TTY via NO_COLOR env; ANSI when colored, plain otherwise.
fn diag_use_color() -> i64 {
    if str_len(getenv("NO_COLOR")) > 0 { return 0; };
    if str_len(getenv("NUCLEOR_NO_COLOR")) > 0 { return 0; };
    if isatty_stdout() == 0 { return 0; };
    return 1;
}

fn ansi_red(s: str) -> str {
    if diag_use_color() == 0 { return s; };
    let esc: str = chr(27);
    return str_concat(esc, str_concat("[31m", str_concat(s, str_concat(esc, "[0m"))));
}

fn ansi_yellow(s: str) -> str {
    if diag_use_color() == 0 { return s; };
    let esc: str = chr(27);
    return str_concat(esc, str_concat("[33m", str_concat(s, str_concat(esc, "[0m"))));
}

fn ansi_dim(s: str) -> str {
    if diag_use_color() == 0 { return s; };
    let esc: str = chr(27);
    return str_concat(esc, str_concat("[2m", str_concat(s, str_concat(esc, "[0m"))));
}

fn ansi_bold(s: str) -> str {
    if diag_use_color() == 0 { return s; };
    let esc: str = chr(27);
    return str_concat(esc, str_concat("[1m", str_concat(s, str_concat(esc, "[0m"))));
}

// RFC-0020 phase 2: JSON renderer for IDE / CI consumption.
// Honors NUCLEOR_DIAG_JSON env var (when set, all diags emit as one JSON
// array of objects). Stable schema for tool integration:
//   { "code": "OWN-008", "severity": "error", "message": "...",
//     "fn": "main", "line": 14, "col": 5,
//     "child": "moved here", "child_line": 13,
//     "suggestion": "consider `let mut x` here" }
fn diag_use_json() -> i64 {
    if str_len(getenv("NUCLEOR_DIAG_JSON")) > 0 { return 1; };
    return 0;
}

fn diag_json_escape(s: str) -> str {
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(s);
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 34 { sb_append(sb, "\\\""); }
        else if c == 92 { sb_append(sb, "\\\\"); }
        else if c == 10 { sb_append(sb, "\\n"); }
        else if c == 13 { sb_append(sb, "\\r"); }
        else if c == 9 { sb_append(sb, "\\t"); }
        else { sb_append(sb, str_substring(s, i, i + 1)); };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn diag_emit_json(diags: Vec<i32>) -> i64 {
    let cnt: i64 = vec_len(diags);
    print("[");
    let mut i: i64 = 0;
    while i < cnt {
        let d: Vec<i32> = vec_get(diags, i);
        let severity: str = vec_get(d, 0);
        let code: str = vec_get(d, 2);
        let message: str = vec_get(d, 3);
        let fn_name: str = vec_get(d, 4);
        let line: i64 = vec_get(d, 5);
        let col: i64 = vec_get(d, 6);
        let suggestion: str = vec_get(d, 8);
        let child_msg: str = vec_get(d, 10);
        let child_line: i64 = vec_get(d, 11);
        let mut sb: i64 = sb_new();
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "{\"code\":\"");
        sb_append(sb, diag_json_escape(code));
        sb_append(sb, "\",\"severity\":\"");
        sb_append(sb, severity);
        sb_append(sb, "\",\"message\":\"");
        sb_append(sb, diag_json_escape(message));
        sb_append(sb, "\"");
        if str_len(fn_name) > 0 {
            sb_append(sb, ",\"fn\":\"");
            sb_append(sb, diag_json_escape(fn_name));
            sb_append(sb, "\"");
        };
        if line > 0 {
            sb_append(sb, ",\"line\":");
            sb_append(sb, str_from_int(line));
        };
        if col > 0 {
            sb_append(sb, ",\"col\":");
            sb_append(sb, str_from_int(col));
        };
        if str_len(child_msg) > 0 {
            sb_append(sb, ",\"child\":\"");
            sb_append(sb, diag_json_escape(child_msg));
            sb_append(sb, "\"");
        };
        if child_line > 0 {
            sb_append(sb, ",\"child_line\":");
            sb_append(sb, str_from_int(child_line));
        };
        if str_len(suggestion) > 0 {
            sb_append(sb, ",\"suggestion\":\"");
            sb_append(sb, diag_json_escape(suggestion));
            sb_append(sb, "\"");
        };
        sb_append(sb, "}");
        print(sb_to_str(sb));
        i = i + 1;
    };
    print("]");
    return cnt;
}

// T1.8 (v0.2.335): extract a single 1-based line from a source
// string. Returns "" if line is out of range. Memory-safe: walks
// the source by index without allocating a substring per
// candidate.
fn diag_extract_line(source: str, line_no: i64) -> str {
    if line_no <= 0 || str_len(source) == 0 { return ""; };
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut cur_line: i64 = 1;
    let mut line_start: i64 = 0;
    while p < slen && cur_line < line_no {
        if str_char_at(source, p) == 10 { cur_line = cur_line + 1; line_start = p + 1; };
        p = p + 1;
    };
    if cur_line != line_no { return ""; };
    let mut line_end: i64 = line_start;
    while line_end < slen && str_char_at(source, line_end) != 10 { line_end = line_end + 1; };
    return str_substring(source, line_start, line_end);
}

// T1.8: build a caret line "    ^^^^^^" pointing at column `col`
// (1-based). Length defaults to 1 (single caret) for now; future
// work can pass a token span.
fn diag_caret_line(col: i64) -> str {
    if col <= 0 { return ""; };
    let mut sb: i64 = sb_new();
    let mut i: i64 = 1;
    while i < col { sb_append(sb, " "); i = i + 1; };
    sb_append(sb, "^");
    return sb_to_str(sb);
}

fn diag_emit_text(diags: Vec<i32>) -> i64 {
    return diag_emit_text_with_source(diags, "");
}

// T1.8: source-aware text emit. Renders Rust-style frame:
//   error[CODE]: message
//     --> fn:line:col
//     |
//   42 |     let x: u8 = 256;
//      |                 ^
//     = help: ...
fn diag_emit_text_with_source(diags: Vec<i32>, source: str) -> i64 {
    let cnt: i64 = vec_len(diags);
    let mut i: i64 = 0;
    while i < cnt {
        let d: Vec<i32> = vec_get(diags, i);
        let severity: str = vec_get(d, 0);
        let code: str = vec_get(d, 2);
        let message: str = vec_get(d, 3);
        let fn_name: str = vec_get(d, 4);
        let line: i64 = vec_get(d, 5);
        let col: i64 = vec_get(d, 6);
        let suggestion: str = vec_get(d, 8);
        let child_msg: str = vec_get(d, 10);
        let child_line: i64 = vec_get(d, 11);

        // First line: severity[CODE]: message
        let mut head: i64 = sb_new();
        let label: str = if str_eq(severity, "error") == 1 { ansi_red("error") } else { ansi_yellow("warning") };
        sb_append(head, label);
        sb_append(head, ansi_bold(str_concat("[", str_concat(code, "]"))));
        sb_append(head, ": ");
        sb_append(head, message);
        print(sb_to_str(head));

        // Second line: --> file:line:col  (file currently unknown; emit fn:line:col)
        if line > 0 {
            let mut loc: i64 = sb_new();
            sb_append(loc, "  ");
            sb_append(loc, ansi_dim("-->"));
            sb_append(loc, " ");
            if str_len(fn_name) > 0 {
                sb_append(loc, ansi_dim("fn "));
                sb_append(loc, fn_name);
                sb_append(loc, ansi_dim("@"));
            };
            sb_append(loc, ansi_dim(str_concat("line ", str_from_int(line))));
            if col > 0 {
                sb_append(loc, ansi_dim(str_concat(":", str_from_int(col))));
            };
            print(sb_to_str(loc));
        };

        // T1.8: source snippet + caret frame, when source is available.
        // Format (Rust-style):
        //     |
        //  42 | let x: u8 = 256;
        //     |             ^
        if str_len(source) > 0 && line > 0 {
            let snippet: str = diag_extract_line(source, line);
            if str_len(snippet) > 0 {
                let line_str: str = str_from_int(line);
                let gutter_w: i64 = str_len(line_str);
                // Pad line number gutter + vertical bar on blank row.
                let mut blank: i64 = sb_new();
                let mut pi: i64 = 0;
                while pi < gutter_w { sb_append(blank, " "); pi = pi + 1; };
                sb_append(blank, " ");
                sb_append(blank, ansi_dim("|"));
                print(sb_to_str(blank));
                // Source line row.
                let mut src_row: i64 = sb_new();
                sb_append(src_row, ansi_dim(line_str));
                sb_append(src_row, " ");
                sb_append(src_row, ansi_dim("|"));
                sb_append(src_row, " ");
                sb_append(src_row, snippet);
                print(sb_to_str(src_row));
                // Caret row.
                if col > 0 {
                    let mut caret_row: i64 = sb_new();
                    pi = 0;
                    while pi < gutter_w { sb_append(caret_row, " "); pi = pi + 1; };
                    sb_append(caret_row, " ");
                    sb_append(caret_row, ansi_dim("|"));
                    sb_append(caret_row, " ");
                    sb_append(caret_row, ansi_red(diag_caret_line(col)));
                    print(sb_to_str(caret_row));
                };
            };
        };

        // Child note line ("moved here", "borrowed here", etc.)
        if str_len(child_msg) > 0 && child_line > 0 {
            let mut child: i64 = sb_new();
            sb_append(child, "  ");
            sb_append(child, ansi_dim("note: "));
            sb_append(child, child_msg);
            sb_append(child, ansi_dim(str_concat(" (line ", str_concat(str_from_int(child_line), ")"))));
            print(sb_to_str(child));
        };

        // Suggestion / help line
        if str_len(suggestion) > 0 {
            let mut help: i64 = sb_new();
            sb_append(help, "  ");
            sb_append(help, ansi_dim("help: "));
            sb_append(help, suggestion);
            print(sb_to_str(help));
        };

        // Blank separator between diagnostics
        if i + 1 < cnt { print(""); };
        i = i + 1;
    };
    return cnt;
}

// =====================================================
// OWNERSHIP CHECKER (S11.5)
// =====================================================
fn own_new() -> Vec<i32> { return Vec::new(); }
fn own_put_i(o: Vec<i32>, key: str, val: i64) -> i64 {
    let mut slot: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < vec_len(o) {
        if str_eq(vec_get(o, i), key) == 1 { slot = i + 1; };
        i = i + 2;
    };
    if slot >= 0 { vec_set(o, slot, val); return 0; };
    o.push(key);
    o.push(val);
    return 0;
}
fn own_put_s(o: Vec<i32>, key: str, val: str) -> i64 {
    let mut slot: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < vec_len(o) {
        if str_eq(vec_get(o, i), key) == 1 { slot = i + 1; };
        i = i + 2;
    };
    if slot >= 0 { vec_set(o, slot, val); return 0; };
    o.push(key);
    o.push(val);
    return 0;
}
fn own_set(o: Vec<i32>, name: str, state: i64) -> i64 { return own_put_i(o, str_concat("__os_", name), state); }
fn own_get(o: Vec<i32>, name: str) -> i64 {
    let v: i64 = sym_get(o, str_concat("__os_", name));
    if v < 0 { return 1; }; // unknown variables default to alive
    return v;
}
fn own_set_type(o: Vec<i32>, name: str, tstr: str) -> i64 { return own_put_s(o, str_concat("__ot_", name), tstr); }
fn own_get_type(o: Vec<i32>, name: str) -> str {
    let v: i64 = sym_get(o, str_concat("__ot_", name));
    if v < 0 { return ""; };
    return v;
}
fn own_set_i(o: Vec<i32>, key: str, val: i64) -> i64 { return own_put_i(o, str_concat("__oi_", key), val); }
fn own_get_i(o: Vec<i32>, key: str) -> i64 {
    let v: i64 = sym_get(o, str_concat("__oi_", key));
    if v < 0 { return 0; };
    return v;
}
fn own_set_s(o: Vec<i32>, key: str, val: str) -> i64 { return own_put_s(o, str_concat("__os2_", key), val); }
fn own_get_s(o: Vec<i32>, key: str) -> str {
    let v: i64 = sym_get(o, str_concat("__os2_", key));
    if v < 0 { return ""; };
    return v;
}
fn own_set_mutable(o: Vec<i32>, name: str, is_mut: i64) -> i64 { return own_set_i(o, str_concat("mutable_", name), is_mut); }
fn own_get_mutable(o: Vec<i32>, name: str) -> i64 { return own_get_i(o, str_concat("mutable_", name)); }
fn own_track_key(o: Vec<i32>, list_key: str, name: str) -> i64 {
    let keys: Vec<i32> = own_get_type(o, list_key);
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        if str_eq(vec_get(keys, i), name) == 1 { return 0; };
        i = i + 1;
    };
    keys.push(name);
    return 0;
}
fn own_set_scope(o: Vec<i32>, name: str, depth: i64) -> i64 {
    own_track_key(o, "__scope_keys", name);
    return own_set_i(o, str_concat("scope_", name), depth);
}
fn own_get_scope(o: Vec<i32>, name: str) -> i64 { return own_get_i(o, str_concat("scope_", name)); }
fn own_set_param(o: Vec<i32>, name: str, is_param: i64) -> i64 { return own_set_i(o, str_concat("param_", name), is_param); }
fn own_get_param(o: Vec<i32>, name: str) -> i64 { return own_get_i(o, str_concat("param_", name)); }
fn own_set_ref_target(o: Vec<i32>, name: str, target: str) -> i64 { return own_set_s(o, str_concat("ref_target_", name), target); }
fn own_get_ref_target(o: Vec<i32>, name: str) -> str { return own_get_s(o, str_concat("ref_target_", name)); }
fn own_set_ref_kind(o: Vec<i32>, name: str, kind: i64) -> i64 { return own_set_i(o, str_concat("ref_kind_", name), kind); }
fn own_get_ref_kind(o: Vec<i32>, name: str) -> i64 { return own_get_i(o, str_concat("ref_kind_", name)); }
fn own_shared_borrows(o: Vec<i32>, key: str) -> i64 { return own_get_i(o, str_concat("shared_", key)); }
fn own_mut_borrowed(o: Vec<i32>, key: str) -> i64 { return own_get_i(o, str_concat("mut_", key)); }
fn own_inc_shared(o: Vec<i32>, key: str) -> i64 {
    own_track_key(o, "__shared_keys", key);
    return own_set_i(o, str_concat("shared_", key), own_shared_borrows(o, key) + 1);
}
fn own_dec_shared(o: Vec<i32>, key: str) -> i64 {
    let cur: i64 = own_shared_borrows(o, key);
    if cur > 0 { own_set_i(o, str_concat("shared_", key), cur - 1); };
    return 0;
}
fn own_set_mut_borrow(o: Vec<i32>, key: str, on: i64) -> i64 {
    own_track_key(o, "__mut_keys", key);
    return own_set_i(o, str_concat("mut_", key), on);
}
fn str_starts_with(s: str, prefix: str) -> i64 {
    // Non-allocating prefix check — walks the bytes directly instead
    // of building a substring and calling str_eq. Critical for the
    // type-check hot path (type_base_name, types_compatible) which
    // calls this millions of times per self-host compile; the prior
    // substring-and-equate version was responsible for ~9.5 GB of
    // transient string allocations during a single self-host build.
    let slen: i64 = str_len(s);
    let plen: i64 = str_len(prefix);
    if slen < plen { return 0; };
    let mut i: i64 = 0;
    while i < plen {
        if str_char_at(s, i) != str_char_at(prefix, i) { return 0; };
        i = i + 1;
    };
    return 1;
}

// Non-allocating "is target string at source[pos..pos+len(target)]"
// check. Replaces the `str_eq(str_substring(source, pos, pos+tlen),
// target)` anti-pattern that was the dominant memory leak in the
// self-host compile (find_linecol_in_source, line_contains_text,
// source_box_binding_type, substring-search loops — each scanned
// the full source allocating a substring per byte position; for a
// 485 KB source that was ~485,000 transient allocations per
// invocation × thousands of invocations = ~9.5 GB of leaked
// transient strings during type-check).
fn str_eq_at(source: str, pos: i64, target: str) -> i64 {
    // CRITICAL: do NOT call str_len(source) here — it's O(n) (walks
    // to the null terminator). The dominant caller (find_linecol_in_
    // source) already guarantees pos + str_len(target) <= str_len(
    // source) via its outer loop bound, so we don't need to recheck.
    // A naive bounds check made the s1 self-host compile take >5 min
    // (was ~25 s) because the per-call str_len walked the entire
    // 485 KB source for every byte position scanned.
    let tlen: i64 = str_len(target);
    let mut k: i64 = 0;
    while k < tlen {
        if str_char_at(source, pos + k) != str_char_at(target, k) { return 0; };
        k = k + 1;
    };
    return 1;
}
fn path_overlaps(a: str, b: str) -> i64 {
    if str_len(a) == 0 || str_len(b) == 0 { return 0; };
    if str_eq(a, b) == 1 { return 1; };
    let ap: str = str_concat(a, ".");
    let bp: str = str_concat(b, ".");
    if str_starts_with(b, ap) == 1 { return 1; };
    if str_starts_with(a, bp) == 1 { return 1; };
    return 0;
}
fn expr_borrow_key(pool: Vec<i32>, nid: i64, own: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if type_is_ref(own_get_type(own, name)) == 1 {
            let target: str = own_get_ref_target(own, name);
            if str_len(target) > 0 { return target; };
        };
        return name;
    };
    if kind == 9 {
        let base: str = expr_borrow_key(pool, node_field(pool, nid, 1), own);
        if str_len(base) == 0 { return ""; };
        return str_concat(base, str_concat(".", node_field(pool, nid, 2)));
    };
    if kind == 92 { return expr_borrow_key(pool, node_field(pool, nid, 1), own); };
    return "";
}
fn expr_root_name(pool: Vec<i32>, nid: i64, own: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if type_is_ref(own_get_type(own, name)) == 1 {
            let target: str = own_get_ref_target(own, name);
            if str_len(target) > 0 {
                let mut i: i64 = 0;
                while i < str_len(target) {
                    if str_char_at(target, i) == 46 { return str_substring(target, 0, i); };
                    i = i + 1;
                };
                return target;
            };
        };
        return name;
    };
    if kind == 9 || kind == 90 || kind == 91 || kind == 92 { return expr_root_name(pool, node_field(pool, nid, 1), own); };
    return "";
}
fn own_has_shared_overlap(o: Vec<i32>, key: str) -> i64 {
    let keys: Vec<i32> = own_get_type(o, "__shared_keys");
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        let target: str = vec_get(keys, i);
        if own_shared_borrows(o, target) > 0 && path_overlaps(target, key) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}
fn own_has_mut_overlap(o: Vec<i32>, key: str) -> i64 {
    let keys: Vec<i32> = own_get_type(o, "__mut_keys");
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        let target: str = vec_get(keys, i);
        if own_mut_borrowed(o, target) == 1 && path_overlaps(target, key) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}
fn own_release_ref(o: Vec<i32>, name: str) -> i64 {
    let target: str = own_get_ref_target(o, name);
    if str_len(target) == 0 { return 0; };
    if own_get_ref_kind(o, name) == 1 { own_set_mut_borrow(o, target, 0); }
    else { own_dec_shared(o, target); };
    own_set_ref_target(o, name, "");
    own_set_ref_kind(o, name, 0);
    return 0;
}
fn own_release_scope(o: Vec<i32>, depth: i64) -> i64 {
    let keys: Vec<i32> = own_get_type(o, "__scope_keys");
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        let name: str = vec_get(keys, i);
        if own_get_scope(o, name) == depth { own_release_ref(o, name); };
        i = i + 1;
    };
    return 0;
}

fn own_snapshot(o: Vec<i32>) -> Vec<i32> {
    let mut snap: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(o) { snap.push(vec_get(o, i)); i = i + 1; };
    return snap;
}
fn own_restore(o: Vec<i32>, snap: Vec<i32>) -> i64 {
    // Reset o to snap state: truncate and repopulate. The snapshot
    // is consumed (frees its backing Vec) so callers do not need a
    // separate vec_free — the snap handle is invalid after this
    // call. Without this free, every if/match arm in type-check
    // leaks a full env-sized Vec; for a self-host compile that
    // accumulated to 19 GB peak (see project notes 2026-04-23).
    while vec_len(o) > 0 { o.pop(); };
    let mut i: i64 = 0;
    while i < vec_len(snap) {
        o.push(vec_get(snap, i)); o.push(vec_get(snap, i + 1));
        i = i + 2;
    };
    // Keep snap alive — caller in check_expr (kind == 23 if-else) may
    // still hold pointers into snap's storage via downstream check
    // function references. The check pass needs a deeper audit before
    // we can free here. The type pass (type_check_stmts) is safe to
    // free because its env consumers don't outlive the snapshot.
    return 0;
}
fn own_merge_moved(o: Vec<i32>, a: Vec<i32>, b: Vec<i32>) -> i64 {
    // If a variable is moved in either branch, mark it moved.
    // Both `a` and `b` are consumed (freed) — they are then/else
    // env snapshots that no caller references after merge.
    let mut i: i64 = 0;
    while i < vec_len(a) {
        let key: str = vec_get(a, i);
        let va: i64 = vec_get(a, i + 1);
        if va == 2 { own_put_i(o, key, 2); }
        else {
            let vb: i64 = sym_get(b, key);
            if vb == 2 { own_put_i(o, key, 2); };
        };
        i = i + 2;
    };
    // Keep a/b alive — own_merge_moved is called from check_expr (line
    // 5786 area) where the caller may still reference them. The
    // type-pass own_snapshot/free pattern is safe; the check pass needs
    // a deeper audit before we can free here.
    return 0;
}

fn enum_find(pool: Vec<i32>, enums: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(enums) {
        if str_eq(node_field(pool, vec_get(enums, i), 1), name) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

fn is_copy_type(tstr: str, pool: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    if str_len(tstr) == 0 { return 1; };
    if type_is_mut_ref(tstr) == 1 { return 0; };
    if type_is_shared_ref(tstr) == 1 { return 1; };
    let base: str = type_base_name(tstr);
    if str_eq(base, "i64") { return 1; }; if str_eq(base, "i32") { return 1; };
    if str_eq(base, "str") { return 1; }; if str_eq(base, "bool") { return 1; };
    if str_eq(base, "f64") { return 1; }; if str_eq(base, "ptr") { return 1; };
    if str_eq(base, "void") { return 1; };
    if str_eq(base, "Vec") { return 1; }; if str_eq(base, "HashMap") { return 1; };
    if str_eq(base, "StringBuilder") { return 1; };
    if str_eq(base, "Box") { return 0; };
    if str_eq(base, "Option") { return 0; };
    if str_eq(base, "Result") { return 0; };
    if str_eq(base, "Arena") { return 1; };
    if str_eq(base, "DeviceBuffer") { return 0; };
    if str_eq(base, "RandomCap") { return 1; };
    if str_eq(base, "Tensor") { return 0; };
    // User-defined struct or enum is Move
    if struct_find(pool, structs, base) >= 0 { return 0; };
    if enum_find(pool, enums, base) >= 0 { return 0; };
    return 1; // unknown types default to Copy
}

fn check_expr(pool: Vec<i32>, nid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, fn_name: str) -> i64 {
    if nid < 0 { return 0; };
    if nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    let source_text: str = own_get_type(own, "__source");
    let diag_vec: Vec<i32> = own_get_type(own, "__diags");
    if kind == 1 || kind == 2 || kind == 71 || kind == 72 { return 0; }; // literals
    if kind == 3 {
        // IDENT — check for use-after-move
        let vname: str = node_field(pool, nid, 1);
        let state: i64 = own_get(own, vname);
        if state == 2 {
            let ln: i64 = find_in_source(source_text, fn_name, vname);
            let col: i64 = find_column_in_source(source_text, fn_name, vname);
            let d_idx: i64 = diag_add_ex(diag_vec, "warning", "ownership", "OWN-001", str_concat("use of moved variable '", str_concat(vname, "'")), fn_name, ln, col, "");
            // Add child note: where was it moved?
            let moved_by: str = own_get_type(own, str_concat("__moved_by_", vname));
            if str_len(moved_by) > 0 {
                let d: Vec<i32> = diag_get(diag_vec, d_idx - 1);
                let move_line: i64 = find_in_source(source_text, fn_name, moved_by);
                vec_set(d, 10, str_concat("'", str_concat(vname, str_concat("' was moved here by call to '", str_concat(moved_by, "'")))));
                vec_set(d, 11, move_line);
            };
            return 1;
        };
        return 0;
    };
    if kind == 4 {
        warns = warns + check_expr(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        warns = warns + check_expr(pool, node_field(pool, nid, 3), own, structs, enums, fn_name);
        return warns;
    };
    if kind == 5 || kind == 6 || kind == 90 || kind == 91 || kind == 92 { return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name); };
    if kind == 7 {
        // CALL — check args, move Move-type idents
        let callee_name: str = node_field(pool, nid, 1);
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            warns = warns + check_expr(pool, arg_nid, own, structs, enums, fn_name);
            if node_kind(pool, arg_nid) == 90 || node_kind(pool, arg_nid) == 91 {
                warns = warns + own_register_borrow_expr(pool, arg_nid, own, fn_name, "", 0, 0);
                let key: str = expr_borrow_key(pool, node_field(pool, arg_nid, 1), own);
                if node_kind(pool, arg_nid) == 90 { own_dec_shared(own, key); }
                else { own_set_mut_borrow(own, key, 0); };
            };
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                let atype: str = own_get_type(own, aname);
                if type_is_mut_ref(atype) == 1 {
                    ai = ai + 1;
                    continue;
                };
                if str_eq(callee_name, "arena_destroy") == 1 {
                    let arena_key: str = str_concat("@arena:", aname);
                    if own_has_shared_overlap(own, arena_key) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-012", str_concat("cannot destroy arena '", str_concat(aname, "': live arena references still exist")), aname);
                    };
                };
                if is_copy_type(atype, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, aname) == 1 || own_has_mut_overlap(own, aname) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(aname, "': value is borrowed")), aname);
                    } else {
                        own_set(own, aname, 2); own_set_type(own, str_concat("__moved_by_", aname), callee_name);
                    };
                };
            };
            ai = ai + 1;
        };
        return warns;
    };
    if kind == 8 {
        // METHOD — check receiver (don't move it) and args
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        let method_name: str = node_field(pool, nid, 2);
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            warns = warns + check_expr(pool, arg_nid, own, structs, enums, fn_name);
            if node_kind(pool, arg_nid) == 90 || node_kind(pool, arg_nid) == 91 {
                warns = warns + own_register_borrow_expr(pool, arg_nid, own, fn_name, "", 0, 0);
                let key: str = expr_borrow_key(pool, node_field(pool, arg_nid, 1), own);
                if node_kind(pool, arg_nid) == 90 { own_dec_shared(own, key); }
                else { own_set_mut_borrow(own, key, 0); };
            };
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                let atype: str = own_get_type(own, aname);
                if type_is_mut_ref(atype) == 1 {
                    ai = ai + 1;
                    continue;
                };
                if is_copy_type(atype, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, aname) == 1 || own_has_mut_overlap(own, aname) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(aname, "': value is borrowed")), aname);
                    } else {
                        own_set(own, aname, 2); own_set_type(own, str_concat("__moved_by_", aname), method_name);
                    };
                };
            };
            ai = ai + 1;
        };
        return warns;
    };
    if kind == 9 { return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name); };
    if kind == 10 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        warns = warns + check_expr(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        return warns;
    };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            warns = warns + check_expr(pool, list_get(pool, items, ii), own, structs, enums, fn_name);
            ii = ii + 1;
        };
        return warns;
    };
    if kind == 12 {
        let qual_name: str = str_concat(node_field(pool, nid, 1), str_concat("::", node_field(pool, nid, 2)));
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            warns = warns + check_expr(pool, arg_nid, own, structs, enums, fn_name);
            if node_kind(pool, arg_nid) == 90 || node_kind(pool, arg_nid) == 91 {
                warns = warns + own_register_borrow_expr(pool, arg_nid, own, fn_name, "", 0, 0);
                let key: str = expr_borrow_key(pool, node_field(pool, arg_nid, 1), own);
                if node_kind(pool, arg_nid) == 90 { own_dec_shared(own, key); }
                else { own_set_mut_borrow(own, key, 0); };
            };
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                let atype: str = own_get_type(own, aname);
                if type_is_mut_ref(atype) == 1 {
                    ai = ai + 1;
                    continue;
                };
                if is_copy_type(atype, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, aname) == 1 || own_has_mut_overlap(own, aname) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(aname, "': value is borrowed")), aname);
                    } else {
                        own_set(own, aname, 2); own_set_type(own, str_concat("__moved_by_", aname), qual_name);
                    };
                };
            };
            ai = ai + 1;
        };
        return warns;
    };
    if kind == 34 {
        // STRUCT_INIT — check field init exprs
        let inits: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, inits);
        let mut ii: i64 = 0;
        while ii < ic {
            let init_nid: i64 = list_get(pool, inits, ii);
            let val_nid: i64 = node_field(pool, init_nid, 2);
            warns = warns + check_expr(pool, val_nid, own, structs, enums, fn_name);
            if node_kind(pool, val_nid) == 3 {
                let vn: str = node_field(pool, val_nid, 1);
                let vt: str = own_get_type(own, vn);
                if is_copy_type(vt, pool, structs, enums) == 0 { own_set(own, vn, 2); };
            };
            ii = ii + 1;
        };
        return warns;
    };
    if kind == 52 {
        let cur_scope: i64 = own_get_i(own, "cur_scope");
        own_set_i(own, "cur_scope", cur_scope + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        own_release_scope(own, cur_scope + 1);
        own_set_i(own, "cur_scope", cur_scope);
        return warns;
    };
    if kind == 42 { return 0; }; // closure — skip for now
    return warns;
}

fn check_stmt(pool: Vec<i32>, nid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, fn_name: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    let scope_depth: i64 = own_get_i(own, "cur_scope");
    let source_text: str = own_get_type(own, "__source");
    if kind == 20 {
        let vname: str = node_field(pool, nid, 1);
        let is_mut: i64 = node_field(pool, nid, 2);
        let mut tstr: str = node_field(pool, nid, 3);
        let init: i64 = node_field(pool, nid, 4);
        own_set_mutable(own, vname, is_mut);
        own_set_scope(own, vname, scope_depth);
        own_set_param(own, vname, 0);
        if init >= 0 {
            if str_len(tstr) == 0 && node_kind(pool, init) == 34 { tstr = node_field(pool, init, 1); };
            if str_len(tstr) == 0 && node_kind(pool, init) == 3 { tstr = own_get_type(own, node_field(pool, init, 1)); };
            warns = warns + check_expr(pool, init, own, structs, enums, fn_name);
            if type_is_ref(tstr) == 1 {
                if node_kind(pool, init) == 90 || node_kind(pool, init) == 91 {
                    warns = warns + own_register_borrow_expr(pool, init, own, fn_name, vname, scope_depth, 1);
                } else if node_kind(pool, init) == 7 && str_eq(node_field(pool, init, 1), "arena_alloc") == 1 {
                    let a_args: i64 = node_field(pool, init, 2);
                    if list_len(pool, a_args) > 0 && node_kind(pool, list_get(pool, a_args, 0)) == 3 {
                        let arena_name: str = node_field(pool, list_get(pool, a_args, 0), 1);
                        let arena_key: str = str_concat("@arena:", arena_name);
                        own_inc_shared(own, arena_key);
                        own_set_ref_target(own, vname, arena_key);
                        own_set_ref_kind(own, vname, 0);
                        own_set_scope(own, vname, scope_depth);
                    };
                } else if node_kind(pool, init) == 3 {
                    let src: str = node_field(pool, init, 1);
                    let st: str = own_get_type(own, src);
                    if type_is_ref(st) == 1 {
                        own_copy_ref_binding(own, src, vname, scope_depth);
                        if type_is_mut_ref(st) == 1 {
                            own_set_ref_target(own, src, "");
                            own_set_ref_kind(own, src, 0);
                            own_set(own, src, 2);
                        };
                    };
                };
                let escape_root: str = expr_escape_root(pool, init, own);
                if str_len(escape_root) > 0 && own_get_scope(own, escape_root) > scope_depth {
                    warns = warns + own_diag(own, fn_name, "OWN-010", str_concat("cannot let reference to inner-scope value '", str_concat(escape_root, "' escape its scope")), escape_root);
                };
            } else if node_kind(pool, init) == 3 {
                let src: str = node_field(pool, init, 1);
                let mut st: str = own_get_type(own, src);
                let hinted_box: str = own_box_hint(own, fn_name, vname);
                if str_len(hinted_box) > 0 && str_eq(type_base_name(st), "Box") == 0 { st = hinted_box; };
                if str_len(st) == 0 { st = tstr; };
                if is_copy_type(st, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, src) == 1 || own_has_mut_overlap(own, src) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(src, "': value is borrowed")), src);
                    } else {
                        own_set(own, src, 2);
                    };
                };
            };
            own_set(own, vname, 1);
        } else {
            own_set(own, vname, 0);
        };
        own_set_type(own, vname, tstr);
        return warns;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let rhs: i64 = node_field(pool, nid, 2);
        warns = warns + check_expr(pool, rhs, own, structs, enums, fn_name);
        // v0.3.81 safety net: assignment LHS shapes that aren't yet
        // supported. Pre-v0.3.81 these segfaulted the compiler with
        // ACCESS_VIOLATION because downstream code in lower_stmt
        // assumed the LHS was a var-ref (kind 3) or field-access
        // (kind 9) and treated other node-ids as string offsets.
        // Kind 10 = indexing (`v[i] = X`); other kinds = tuple/literal/
        // computed expressions that have no addressable storage.
        let lhs_kind_check: i64 = node_kind(pool, lhs);
        // v0.3.124: kind-10 indexed assignment now lowered to vec_set
        // in lower_stmt; the prior diag-only stub here is no longer
        // needed.
        if lhs_kind_check != 3 && lhs_kind_check != 9 && lhs_kind_check != 10 {
            print("ERROR: assignment to this LHS form is not supported (only var-ref `x = ...`, field-access `obj.f = ...`, and indexed `v[i] = ...` are recognized; tuple destructuring assignment / computed-expression LHS is not). The pre-v0.3.81 compiler would segfault on this shape.");
            return warns + 1;
        };
        if node_kind(pool, lhs) == 3 {
            let lname: str = node_field(pool, lhs, 1);
            if own_get_mutable(own, lname) == 0 && own_get_param(own, lname) == 0 {
                warns = warns + own_diag(own, fn_name, "OWN-008", str_concat("cannot assign to immutable binding '", str_concat(lname, "'")), lname);
            };
            own_release_ref(own, lname);
            if node_kind(pool, rhs) == 90 || node_kind(pool, rhs) == 91 {
                warns = warns + own_register_borrow_expr(pool, rhs, own, fn_name, lname, scope_depth, 1);
                let escape_root: str = expr_escape_root(pool, rhs, own);
                if str_len(escape_root) > 0 && own_get_scope(own, escape_root) > scope_depth {
                    warns = warns + own_diag(own, fn_name, "OWN-010", str_concat("cannot let reference to inner-scope value '", str_concat(escape_root, "' escape its scope")), escape_root);
                };
            } else if node_kind(pool, rhs) == 3 {
                let src: str = node_field(pool, rhs, 1);
                let mut st: str = own_get_type(own, src);
                let hinted_box: str = own_box_hint(own, fn_name, lname);
                if str_len(hinted_box) > 0 && str_eq(type_base_name(st), "Box") == 0 { st = hinted_box; };
                if str_len(st) == 0 { st = own_get_type(own, lname); };
                if type_is_ref(st) == 1 {
                    own_copy_ref_binding(own, src, lname, scope_depth);
                    if type_is_mut_ref(st) == 1 {
                        own_set_ref_target(own, src, "");
                        own_set_ref_kind(own, src, 0);
                        own_set(own, src, 2);
                    };
                } else if is_copy_type(st, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, src) == 1 || own_has_mut_overlap(own, src) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(src, "': value is borrowed")), src);
                    } else {
                        own_set(own, src, 2);
                    };
                };
            };
            own_set(own, lname, 1);
            return warns;
        };
        if node_kind(pool, lhs) == 9 {
            let recv: i64 = node_field(pool, lhs, 1);
            // v0.3.80 safety net: nested field assignment
            // (`outer.inner.field = X`) was crashing the compiler with
            // a segfault during the ownership/type check pass. Detect
            // the nested kind-9-on-kind-9 LHS and emit a clear
            // diagnostic instead of crashing. The actual feature
            // (deep field-path mutation) requires a get-modify-set
            // lowering tracked for a future ship.
            if node_kind(pool, recv) == 9 {
                print("ERROR: nested struct field assignment is not yet supported (e.g. `outer.inner.field = X`). Workaround: copy the inner struct to a local, mutate the local, then assign it back: `let mut tmp = outer.inner; tmp.field = X; outer.inner = tmp;`. Tracked for a future ship — get-modify-set lowering needed.");
                return warns + 1;
            };
            if node_kind(pool, recv) == 3 && type_is_shared_ref(own_get_type(own, node_field(pool, recv, 1))) == 1 {
                let rname: str = node_field(pool, recv, 1);
                warns = warns + own_diag(own, fn_name, "OWN-006", str_concat("cannot assign through shared reference '", str_concat(rname, "'")), rname);
                return warns;
            };
            let mut recv_is_mut_ref: i64 = 0;
            if node_kind(pool, recv) == 3 && type_is_mut_ref(own_get_type(own, node_field(pool, recv, 1))) == 1 { recv_is_mut_ref = 1; };
            if recv_is_mut_ref == 0 {
                let key: str = expr_borrow_key(pool, lhs, own);
                if own_has_shared_overlap(own, key) == 1 || own_has_mut_overlap(own, key) == 1 {
                    let root: str = expr_root_name(pool, lhs, own);
                    warns = warns + own_diag(own, fn_name, "OWN-007", str_concat("cannot assign to borrowed location '", str_concat(key, "'")), root);
                };
            };
        };
        return warns;
    };
    if kind == 22 {
        let val: i64 = node_field(pool, nid, 1);
        if val >= 0 {
            warns = warns + check_expr(pool, val, own, structs, enums, fn_name);
            let escape_root: str = expr_escape_root(pool, val, own);
            if str_len(escape_root) > 0 && own_get_param(own, escape_root) == 0 {
                warns = warns + own_diag(own, fn_name, "OWN-009", str_concat("cannot return reference to local value '", str_concat(escape_root, "'")), escape_root);
            };
        };
        return warns;
    };
    if kind == 23 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        let snap: Vec<i32> = own_snapshot(own);
        own_set_i(own, "cur_scope", scope_depth + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_i(own, "cur_scope", scope_depth);
        let then_state: Vec<i32> = own_snapshot(own);
        own_restore(own, snap);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 {
            own_set_i(own, "cur_scope", scope_depth + 1);
            warns = warns + check_stmts(pool, enode, own, structs, enums, fn_name);
            own_release_scope(own, scope_depth + 1);
            own_set_i(own, "cur_scope", scope_depth);
        };
        let else_state: Vec<i32> = own_snapshot(own);
        own_merge_moved(own, then_state, else_state);
        return warns;
    };
    if kind == 24 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        own_set_i(own, "cur_scope", scope_depth + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_i(own, "cur_scope", scope_depth);
        return warns;
    };
    if kind == 25 {
        return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
    };
    if kind == 28 {
        let loop_var: str = node_field(pool, nid, 1);
        own_set(own, loop_var, 1);
        own_set_type(own, loop_var, "i64");
        own_set_mutable(own, loop_var, 1);
        own_set_scope(own, loop_var, scope_depth + 1);
        own_set_param(own, loop_var, 0);
        own_set_i(own, "cur_scope", scope_depth + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 4), own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_i(own, "cur_scope", scope_depth);
        return warns;
    };
    if kind == 49 {
        let loop_var: str = node_field(pool, nid, 1);
        own_set(own, loop_var, 1);
        own_set_type(own, loop_var, "Vec");
        own_set_mutable(own, loop_var, 1);
        own_set_scope(own, loop_var, scope_depth + 1);
        own_set_param(own, loop_var, 0);
        warns = warns + check_expr(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        own_set_i(own, "cur_scope", scope_depth + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 3), own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_i(own, "cur_scope", scope_depth);
        return warns;
    };
    if kind == 38 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        let arms: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, arms);
        let snap: Vec<i32> = own_snapshot(own);
        let mut has_wildcard: i64 = 0;
        let mut wildcard_idx: i64 = 0 - 1;
        let mut ai: i64 = 0;
        while ai < ac {
            let arm_nid: i64 = list_get(pool, arms, ai);
            own_restore(own, snap);
            let ename: str = node_field(pool, arm_nid, 1);
            if str_eq(ename, "__wild") {
                has_wildcard = 1;
                if wildcard_idx < 0 { wildcard_idx = ai; };
            };
            // RFC-0023 §3.1 + MATCH-007: range pattern with bounds in
            // wrong order (LO > HI) — would never match.
            if str_eq(ename, "__range_bad") {
                let src: str = source_text;
                let ln: i64 = find_in_source(src, fn_name, "match");
                diag_add(own_get_type(own, "__diags"), "warning", "type", "MATCH-007", str_concat("range pattern bounds in wrong order at arm ", str_concat(str_from_int(ai + 1), " — pattern can never match")), fn_name, ln);
                warns = warns + 1;
            };
            let binding: str = node_field(pool, arm_nid, 3);
            // For __range / __range_bad the `binding` field holds the
            // string-encoded high bound (e.g. "9"), not a variable name.
            // Skip the binding-as-variable scope setup for those arms.
            let is_range: i64 = if str_eq(ename, "__range") == 1 || str_eq(ename, "__range_bad") == 1 { 1 } else { 0 };
            if is_range == 0 && str_len(binding) > 0 {
                own_set(own, binding, 1);
                own_set_type(own, binding, "i64");
                own_set_mutable(own, binding, 0);
                own_set_scope(own, binding, scope_depth + 1);
                own_set_param(own, binding, 0);
            };
            own_set_i(own, "cur_scope", scope_depth + 1);
            warns = warns + check_stmts(pool, node_field(pool, arm_nid, 4), own, structs, enums, fn_name);
            own_release_scope(own, scope_depth + 1);
            own_set_i(own, "cur_scope", scope_depth);
            ai = ai + 1;
        };
        // RFC-0016 phase 5 — MATCH-002: any arm following a wildcard is
        // unreachable (the wildcard already captures every value).
        if wildcard_idx >= 0 && wildcard_idx < ac - 1 {
            let src: str = source_text;
            let ln: i64 = find_in_source(src, fn_name, "match");
            diag_add(own_get_type(own, "__diags"), "warning", "type", "MATCH-002", str_concat("unreachable match arm after wildcard at arm ", str_concat(str_from_int(wildcard_idx + 1), str_concat(" of ", str_from_int(ac)))), fn_name, ln);
            warns = warns + 1;
        };
        if has_wildcard == 0 && ac > 0 {
            let first_arm: i64 = list_get(pool, arms, 0);
            let first_ename: str = node_field(pool, first_arm, 1);
            if str_eq(first_ename, "__int") == 0 && str_eq(first_ename, "__str") == 0 && str_eq(first_ename, "__wild") == 0 {
                let ei: i64 = enum_find(pool, enums, first_ename);
                if ei >= 0 {
                    let e_nid: i64 = vec_get(enums, ei);
                    let vlist: i64 = node_field(pool, e_nid, 2);
                    let vcnt: i64 = list_len(pool, vlist);
                    if ac < vcnt {
                        let src: str = source_text;
                        let ln: i64 = find_in_source(src, fn_name, "match");
                        // RFC-0016 phase 5 — MATCH-001 (canonical) alongside
                        // legacy TYP-001 for backwards compatibility.
                        let msg: str = str_concat("non-exhaustive match: ", str_concat(str_from_int(ac), str_concat(" arms for enum with ", str_concat(str_from_int(vcnt), " variants"))));
                        diag_add(own_get_type(own, "__diags"), "warning", "type", "TYP-001", msg, fn_name, ln);
                        diag_add(own_get_type(own, "__diags"), "warning", "type", "MATCH-001", msg, fn_name, ln);
                        warns = warns + 2;
                    };
                };
            };
        };
        return warns;
    };
    return warns;
}

fn check_stmts(pool: Vec<i32>, lid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, fn_name: str) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0; let mut warns: i64 = 0;
    while i < cnt { warns = warns + check_stmt(pool, list_get(pool, lid, i), own, structs, enums, fn_name); i = i + 1; };
    return warns;
}

fn check_fn(pool: Vec<i32>, fn_nid: i64, structs: Vec<i32>, enums: Vec<i32>, diags: Vec<i32>, source: str) -> i64 {
    let fn_name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let body: i64 = node_field(pool, fn_nid, 4);
    if body < 0 || body >= vec_len(pool) { return 0; };
    let pc: i64 = list_len(pool, plist);
    let mut own: Vec<i32> = own_new();
    own_set_type(own, "__diags", diags);
    own_set_type(own, "__source", source);
    own_set_type(own, "__shared_keys", Vec::new());
    own_set_type(own, "__mut_keys", Vec::new());
    own_set_type(own, "__scope_keys", Vec::new());
    own_set_i(own, "cur_scope", 0);
    let mut pi: i64 = 0;
    while pi < pc {
        let pnid: i64 = list_get(pool, plist, pi);
        let pname: str = node_field(pool, pnid, 1);
        let ptype: str = node_field(pool, pnid, 2);
        own_set(own, pname, 1);
        own_set_type(own, pname, ptype);
        own_set_mutable(own, pname, 0);
        own_set_scope(own, pname, 0);
        own_set_param(own, pname, 1);
        if type_is_ref(ptype) == 1 {
            own_set_ref_target(own, pname, pname);
            if type_is_mut_ref(ptype) == 1 { own_set_ref_kind(own, pname, 1); }
            else { own_set_ref_kind(own, pname, 0); };
        };
        pi = pi + 1;
    };
    let w: i64 = check_stmts(pool, body, own, structs, enums, fn_name);
    let rtype: str = node_field(pool, fn_nid, 3);
    if type_is_ref(rtype) == 1 {
        let body_cnt: i64 = list_len(pool, body);
        if body_cnt > 0 {
            let last_stmt: i64 = list_get(pool, body, body_cnt - 1);
            let last_kind: i64 = node_kind(pool, last_stmt);
            if last_kind == 25 || last_kind == 23 || last_kind == 52 {
                let mut escape_root: str = "";
                if last_kind == 25 { escape_root = expr_escape_root(pool, node_field(pool, last_stmt, 1), own); }
                else { escape_root = expr_escape_root(pool, last_stmt, own); };
                if str_len(escape_root) > 0 && own_get_param(own, escape_root) == 0 {
                    own_diag(own, fn_name, "OWN-009", str_concat("cannot return reference to local value '", str_concat(escape_root, "'")), escape_root);
                };
            };
        };
    };
    return w;
}

// =====================================================
// EFFECT CHECKER (S11.6)
// =====================================================
fn is_tainted_type(tstr: str) -> i64 {
    // Hot path: was allocating a 7-byte substring per call.
    if str_starts_with(tstr, "tainted") == 1 { return 1; };
    return 0;
}
fn taint_inner_type(t: str) -> str {
    let slen: i64 = str_len(t);
    if str_starts_with(t, "tainted<") == 1 { return str_substring(t, 8, slen - 1); };
    return t;
}
fn types_compatible(expected: str, actual: str) -> i64 {
    if str_len(expected) == 0 || str_len(actual) == 0 { return 1; };
    if str_eq(expected, "_") == 1 { return 1; };
    if str_eq(actual, "_") == 1 { return 1; };
    if str_eq(expected, actual) == 1 { return 1; };
    let ebase: str = type_base_name(expected);
    let abase: str = type_base_name(actual);
    if str_eq(ebase, "Vec") == 1 && (str_eq(actual, "i64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "ptr") == 1) { return 1; };
    if str_eq(abase, "Vec") == 1 && (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1 || str_eq(expected, "ptr") == 1) { return 1; };
    // T1.2 (v0.2.336): Option/Result constructors lower to a Vec<i32>
    // tag-payload runtime representation. Allow them to flow into
    // Vec / Vec<i32> / Vec<i64> return types.
    if (str_eq(actual, "Option") == 1 || str_eq(actual, "Result") == 1) &&
       (str_eq(ebase, "Vec") == 1 || str_eq(ebase, "Option") == 1 || str_eq(ebase, "Result") == 1) { return 1; };
    if (str_eq(expected, "Option") == 1 || str_eq(expected, "Result") == 1) &&
       (str_eq(abase, "Vec") == 1 || str_eq(abase, "Option") == 1 || str_eq(abase, "Result") == 1) { return 1; };
    // Option ↔ Result interop (rare but useful for ? in ad-hoc contexts).
    if (str_eq(expected, "Option") == 1 && str_eq(actual, "Result") == 1) { return 1; };
    if (str_eq(expected, "Result") == 1 && str_eq(actual, "Option") == 1) { return 1; };
    if (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1) && str_eq(actual, "bool") == 1 { return 1; };
    if str_eq(expected, "bool") == 1 && (str_eq(actual, "i64") == 1 || str_eq(actual, "i32") == 1) { return 1; };
    if str_eq(expected, "Int") == 1 && (str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1) { return 1; };
    if str_eq(expected, "Float") == 1 && (str_eq(actual, "f64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1) { return 1; };
    if str_len(ebase) >= 2 && (str_char_at(ebase, 0) == 105 || str_char_at(ebase, 0) == 117) {
        let mut digits_only: i64 = 1;
        let mut di: i64 = 1;
        while di < str_len(ebase) {
            let dc: i64 = str_char_at(ebase, di);
            if dc < 48 || dc > 57 { digits_only = 0; };
            di = di + 1;
        };
        if digits_only == 1 && (str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1 || str_eq(actual, "f64") == 1) { return 1; };
    };
    // T1.1 Phase 6: narrow integer → i64/i32 widening for argument
    // passing. Storage is i64 anyway, so a u8 / u16 / i8 / i16 / u32
    // can be passed as an i64 / i32 argument without loss.
    if (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1) {
        if str_eq(actual, "i8") == 1 || str_eq(actual, "i16") == 1 ||
           str_eq(actual, "u8") == 1 || str_eq(actual, "u16") == 1 ||
           str_eq(actual, "u32") == 1 { return 1; };
    };
    // T1.1 Phase 2: f32 / f16 / bf16 accept f64 literals (the parser
    // emits all float literals as f64; lowering inserts the conversion).
    if (str_eq(expected, "f32") == 1 || str_eq(expected, "f16") == 1 || str_eq(expected, "bf16") == 1)
       && (str_eq(actual, "f64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1) { return 1; };
    if str_len(expected) == 1 {
        let c: i64 = str_char_at(expected, 0);
        if c >= 65 && c <= 90 { return 1; };
    };
    if str_len(actual) == 1 {
        let c: i64 = str_char_at(actual, 0);
        if c >= 65 && c <= 90 { return 1; };
    };
    if str_eq(strip_spaces(expected), strip_spaces(actual)) == 1 { return 1; };
    if (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1 || str_eq(expected, "f64") == 1) &&
       (str_eq(actual, "i64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "f64") == 1) { return 1; };
    if is_tainted_type(expected) == 1 && is_tainted_type(actual) == 0 {
        if str_eq(strip_spaces(taint_inner_type(expected)), strip_spaces(actual)) == 1 { return 1; };
    };
    if is_tainted_type(expected) == 0 && is_tainted_type(actual) == 1 { return 0; };
    if type_is_unit(expected) == 1 || type_is_unit(actual) == 1 { return 0; };
    if str_eq(ebase, abase) == 1 { return 1; };
    return 0;
}
fn target_root_name(target: str) -> str {
    let mut i: i64 = 0;
    while i < str_len(target) {
        if str_char_at(target, i) == 46 { return str_substring(target, 0, i); };
        i = i + 1;
    };
    return target;
}
fn expr_escape_root(pool: Vec<i32>, nid: i64, own: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 90 || kind == 91 {
        let root: str = expr_root_name(pool, node_field(pool, nid, 1), own);
        if own_get_param(own, root) == 0 { return root; };
        return "";
    };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if type_is_ref(own_get_type(own, name)) == 1 {
            let target: str = own_get_ref_target(own, name);
            if str_len(target) > 0 {
                let root: str = target_root_name(target);
                if own_get_param(own, root) == 0 { return root; };
                return "";
            };
            if own_get_param(own, name) == 0 { return name; };
        };
        return "";
    };
    if kind == 52 {
        let body: i64 = node_field(pool, nid, 2);
        if body < 0 || body >= vec_len(pool) { return ""; };
        let cnt: i64 = list_len(pool, body);
        if cnt == 0 { return ""; };
        let last_stmt: i64 = list_get(pool, body, cnt - 1);
        let sk: i64 = node_kind(pool, last_stmt);
        if sk == 22 || sk == 25 { return expr_escape_root(pool, node_field(pool, last_stmt, 1), own); };
        if sk == 23 { return expr_escape_root(pool, last_stmt, own); };
        return "";
    };
    if kind == 23 {
        let mut root: str = expr_escape_root(pool, node_field(pool, nid, 2), own);
        if str_len(root) > 0 { return root; };
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 { return expr_escape_root(pool, enode, own); };
        return "";
    };
    return "";
}

fn builtin_rtype(name: str) -> str {
    if str_eq(name, "ambient_scheduler") == 1 { return "SchedulerCap"; };
    if str_eq(name, "ambient_random") == 1 { return "RandomCap"; };
    if str_eq(name, "random_uniform") == 1 { return "f64"; };
    if str_eq(name, "random_normal") == 1 { return "f64"; };
    if str_eq(name, "arena_new") == 1 { return "Arena"; };
    if str_eq(name, "arena_alloc") == 1 { return "&i64"; };
    if str_eq(name, "device_alloc") == 1 { return "DeviceBuffer"; };
    if str_eq(name, "device_transfer") == 1 { return "DeviceBuffer"; };
    if str_eq(name, "tensor_view") == 1 { return "i64"; };
    if str_eq(name, "channel") == 1 { return "i64"; };
    if str_eq(name, "rwlock_new") == 1 || str_eq(name, "rwlock_read") == 1 || str_eq(name, "rwlock_write") == 1 || str_eq(name, "rwlock_unlock") == 1 { return "i64"; };
    if str_eq(name, "cancel_token_new") == 1 || str_eq(name, "cancel_token_cancel") == 1 { return "i64"; };
    if str_eq(name, "print") == 1 || str_eq(name, "print_int") == 1 || str_eq(name, "print_f64") == 1 || str_eq(name, "print_bool") == 1 || str_eq(name, "putchar") == 1 { return "void"; };
    if str_eq(name, "rng_seed") == 1 || str_eq(name, "device_free") == 1 || str_eq(name, "arena_destroy") == 1 || str_eq(name, "arena_reset") == 1 { return "void"; };
    return "";
}

fn source_line(source: str, line: i64) -> str {
    let slen: i64 = str_len(source);
    let mut cur: i64 = 1;
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i < slen {
        if cur == line {
            let mut end: i64 = i;
            while end < slen && str_char_at(source, end) != 10 { end = end + 1; };
            return str_substring(source, start, end);
        };
        if str_char_at(source, i) == 10 { cur = cur + 1; start = i + 1; };
        i = i + 1;
    };
    if cur == line { return str_substring(source, start, slen); };
    return "";
}
fn line_has_unit_literal(source: str, fn_name: str, symbol: str) -> i64 {
    let line: i64 = find_in_source(source, fn_name, symbol);
    let txt: str = source_line(source, line);
    let mut i: i64 = 0;
    while i < str_len(txt) {
        if str_char_at(txt, i) == 123 { return 1; };
        i = i + 1;
    };
    return 0;
}
fn line_contains_text(source: str, fn_name: str, symbol: str, text: str) -> i64 {
    let line: i64 = find_in_source(source, fn_name, symbol);
    let txt: str = source_line(source, line);
    let tlen: i64 = str_len(text);
    let llen: i64 = str_len(txt);
    if llen < tlen { return 0; };
    let mut i: i64 = 0;
    while i <= llen - tlen {
        if str_eq_at(txt, i, text) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}
fn source_box_binding_type(source: str, fn_name: str, name: str) -> str {
    let target: str = str_concat("let ", str_concat(name, ": Box<"));
    let tlen: i64 = str_len(target);
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i <= slen - tlen {
        if str_eq_at(source, i, target) == 1 {
            let mut end: i64 = i + tlen;
            while end < slen && str_char_at(source, end) != 62 { end = end + 1; };
            if end < slen { return str_concat("Box<", str_concat(str_substring(source, i + tlen, end), ">")); };
        };
        i = i + 1;
    };
    return "";
}
fn own_diag_ex(own: Vec<i32>, fn_name: str, code: str, message: str, symbol: str, checker: str) -> i64 {
    let src: str = own_get_type(own, "__source");
    let diags: Vec<i32> = own_get_type(own, "__diags");
    let loc: Vec<i32> = find_linecol_in_source(src, fn_name, symbol);
    diag_add_ex(diags, "error", checker, code, message, fn_name, vec_get(loc, 0), vec_get(loc, 1), "");
    return 1;
}
fn own_diag(own: Vec<i32>, fn_name: str, code: str, message: str, symbol: str) -> i64 {
    return own_diag_ex(own, fn_name, code, message, symbol, "ownership");
}
fn own_box_hint(own: Vec<i32>, fn_name: str, name: str) -> str {
    let cache_key: str = str_concat("__box_hint_", name);
    let cached: str = own_get_s(own, cache_key);
    if str_eq(cached, "_none_") == 1 { return ""; };
    if str_len(cached) > 0 { return cached; };
    let source_text: str = own_get_type(own, "__source");
    let guessed: str = source_box_binding_type(source_text, fn_name, name);
    if str_len(guessed) > 0 {
        own_set_s(own, cache_key, guessed);
        return guessed;
    };
    if line_contains_text(source_text, fn_name, name, "Box<") == 1 {
        own_set_s(own, cache_key, "Box");
        return "Box";
    };
    own_set_s(own, cache_key, "_none_");
    return "";
}
fn own_copy_ref_binding(own: Vec<i32>, src: str, dst: str, scope_depth: i64) -> i64 {
    let target: str = own_get_ref_target(own, src);
    if str_len(target) == 0 { return 0; };
    let kind: i64 = own_get_ref_kind(own, src);
    if kind == 0 { own_inc_shared(own, target); };
    own_set_ref_target(own, dst, target);
    own_set_ref_kind(own, dst, kind);
    own_set_scope(own, dst, scope_depth);
    return 0;
}
fn own_register_borrow_expr(pool: Vec<i32>, nid: i64, own: Vec<i32>, fn_name: str, ref_name: str, scope_depth: i64, persist: i64) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind != 90 && kind != 91 { return 0; };
    let target_expr: i64 = node_field(pool, nid, 1);
    let key: str = expr_borrow_key(pool, target_expr, own);
    let root: str = expr_root_name(pool, target_expr, own);
    if str_len(key) == 0 || str_len(root) == 0 { return 0; };
    if own_get(own, root) == 2 {
        return own_diag(own, fn_name, "OWN-002", str_concat("cannot borrow moved value '", str_concat(root, "'")), root);
    };
    if kind == 90 {
        if own_has_mut_overlap(own, key) == 1 {
            return own_diag(own, fn_name, "OWN-005", str_concat("cannot shared-borrow '", str_concat(root, "': value is mutably borrowed")), root);
        };
        own_inc_shared(own, key);
        if persist == 1 && str_len(ref_name) > 0 {
            own_set_ref_target(own, ref_name, key);
            own_set_ref_kind(own, ref_name, 0);
            own_set_scope(own, ref_name, scope_depth);
        };
        return 0;
    };
    if own_get_mutable(own, root) == 0 && own_get_param(own, root) == 0 && type_is_mut_ref(own_get_type(own, root)) == 0 {
        return own_diag(own, fn_name, "OWN-011", str_concat("cannot mutably borrow immutable value '", str_concat(root, "'")), root);
    };
    if own_has_mut_overlap(own, key) == 1 || own_has_shared_overlap(own, key) == 1 {
        return own_diag(own, fn_name, "OWN-004", str_concat("cannot mutably borrow '", str_concat(root, "': value is already borrowed")), root);
    };
    own_set_mut_borrow(own, key, 1);
    if persist == 1 && str_len(ref_name) > 0 {
        own_set_ref_target(own, ref_name, key);
        own_set_ref_kind(own, ref_name, 1);
        own_set_scope(own, ref_name, scope_depth);
    };
    return 0;
}

fn tprof_new(enabled: i64) -> Vec<i32> {
    let mut prof: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    prof.push(enabled);
    while i < 12 {
        prof.push(0);
        i = i + 1;
    };
    return prof;
}
fn tprof_enabled(prof: Vec<i32>) -> i64 {
    if vec_len(prof) == 0 { return 0; };
    return vec_get(prof, 0);
}
fn tprof_start(prof: Vec<i32>) -> i64 {
    if tprof_enabled(prof) == 1 { return now_ms(); };
    return 0;
}
fn tprof_mark(prof: Vec<i32>, count_idx: i64, time_idx: i64, start_ms: i64) -> i64 {
    if tprof_enabled(prof) == 1 {
        vec_set(prof, count_idx, vec_get(prof, count_idx) + 1);
        vec_set(prof, time_idx, vec_get(prof, time_idx) + (now_ms() - start_ms));
    };
    return 0;
}
fn tprof_dump(prof: Vec<i32>) -> i64 {
    if tprof_enabled(prof) == 0 { return 0; };
    print(str_concat("  type profile stmt: ", str_concat(str_from_int(vec_get(prof, 1)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 2)), " ms")))));
    print(str_concat("  type profile env_lookup: ", str_concat(str_from_int(vec_get(prof, 3)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 4)), " ms")))));
    print(str_concat("  type profile sig_lookup: ", str_concat(str_from_int(vec_get(prof, 5)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 6)), " ms")))));
    print(str_concat("  type profile compat: ", str_concat(str_from_int(vec_get(prof, 7)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 8)), " ms")))));
    print(str_concat("  type profile call_expr: ", str_concat(str_from_int(vec_get(prof, 9)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 10)), " ms")))));
    print(str_concat("  type profile box_hint: ", str_concat(str_from_int(vec_get(prof, 11)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 12)), " ms")))));
    return 0;
}
fn type_diag(diags: Vec<i32>, source: str, fn_name: str, symbol: str, code: str, message: str) -> i64 {
    let loc: Vec<i32> = find_linecol_in_source(source, fn_name, symbol);
    return diag_add_ex(diags, "error", "type", code, message, fn_name, vec_get(loc, 0), vec_get(loc, 1), "");
}
fn sig_new() -> Vec<i32> { return smap_new(); }
fn sig_entry_new(plist: i64, rtype: str, is_extern: i64) -> Vec<i32> {
    let mut entry: Vec<i32> = Vec::new();
    entry.push(plist);
    entry.push(rtype);
    entry.push(is_extern);
    return entry;
}
fn sig_add(sigs: Vec<i32>, name: str, plist: i64, rtype: str, is_extern: i64) -> i64 {
    return smap_set(sigs, name, sig_entry_new(plist, rtype, is_extern));
}
fn sig_find(sigs: Vec<i32>, name: str) -> i64 {
    return smap_get(sigs, name);
}
fn sig_plist(sigs: Vec<i32>, name: str) -> i64 {
    let entry: i64 = sig_find(sigs, name);
    if entry < 0 { return 0 - 1; };
    return vec_get(entry, 0);
}
fn sig_rtype(sigs: Vec<i32>, name: str) -> str {
    let entry: i64 = sig_find(sigs, name);
    if entry < 0 { return ""; };
    return vec_get(entry, 1);
}
fn sig_is_extern(sigs: Vec<i32>, name: str) -> i64 {
    let entry: i64 = sig_find(sigs, name);
    if entry < 0 { return 0; };
    return vec_get(entry, 2);
}
fn tenv_new() -> Vec<i32> { return Vec::new(); }
fn tenv_set(env: Vec<i32>, name: str, tstr: str) -> i64 { env.push(name); env.push(tstr); return 0; }
fn tenv_get(env: Vec<i32>, name: str) -> str {
    let v: i64 = sym_get(env, name);
    if v < 0 { return ""; };
    return v;
}
fn strip_spaces(s: str) -> str {
    // Fast path: most type strings (the dominant caller) have no
    // whitespace. Scan once to detect; if clean, return the input
    // unchanged — no allocation. Only allocate the SB when we
    // actually have characters to strip. The previous version
    // always allocated a SB and a 1-byte substring per non-space
    // character; for a 12-byte type name that was 12 separate
    // allocations even when no whitespace was present.
    let slen: i64 = str_len(s);
    let mut i: i64 = 0;
    let mut has_ws: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 32 || c == 9 || c == 10 || c == 13 { has_ws = 1; break; };
        i = i + 1;
    };
    if has_ws == 0 { return s; };
    let mut sb: i64 = sb_new();
    let mut j: i64 = 0;
    while j < slen {
        let c2: i64 = str_char_at(s, j);
        if c2 != 32 && c2 != 9 && c2 != 10 && c2 != 13 { sb_append(sb, str_substring(s, j, j + 1)); };
        j = j + 1;
    };
    return sb_to_str(sb);
}
fn type_is_unit(t: str) -> i64 {
    if str_starts_with(t, "unit<") == 1 { return 1; };
    return 0;
}
fn unit_dim(t: str) -> str {
    if type_is_unit(t) == 0 { return ""; };
    let slen: i64 = str_len(t);
    let mut i: i64 = 5;
    while i < slen && str_char_at(t, i) != 44 { i = i + 1; };
    if i >= slen { return ""; };
    return strip_spaces(str_substring(t, i + 1, slen - 1));
}
fn type_dynamic_helper(name: str) -> i64 {
    if str_eq(name, "tok_type") == 1 { return 1; };
    if str_eq(name, "tok_val") == 1 { return 1; };
    if str_eq(name, "node_field") == 1 { return 1; };
    if str_eq(name, "list_get") == 1 { return 1; };
    if str_eq(name, "vec_get") == 1 { return 1; };
    if str_eq(name, "sym_get") == 1 { return 1; };
    if str_eq(name, "sym_set") == 1 { return 1; };
    if str_eq(name, "smap_get") == 1 { return 1; };
    if str_eq(name, "smap_set") == 1 { return 1; };
    if str_eq(name, "tenv_get") == 1 { return 1; };
    if str_eq(name, "tenv_set") == 1 { return 1; };
    if str_eq(name, "pr") == 1 { return 1; };
    if str_eq(name, "pkv") == 1 { return 1; };
    if str_eq(name, "pr_pos") == 1 { return 1; };
    if str_eq(name, "pr_val") == 1 { return 1; };
    if str_eq(name, "mk2") == 1 { return 1; };
    if str_eq(name, "mk3") == 1 { return 1; };
    if str_eq(name, "mk4") == 1 { return 1; };
    if str_eq(name, "mk5") == 1 { return 1; };
    if str_eq(name, "mk6") == 1 { return 1; };
    if str_eq(name, "mk_list") == 1 { return 1; };
    if str_eq(name, "diag_get") == 1 { return 1; };
    if str_eq(name, "own_get_type") == 1 { return 1; };
    if str_eq(name, "own_set_type") == 1 { return 1; };
    if str_eq(name, "own_get_s") == 1 { return 1; };
    if str_eq(name, "sig_plist") == 1 { return 1; };
    if str_eq(name, "sig_add") == 1 { return 1; };
    if str_eq(name, "sig_rtype") == 1 { return 1; };
    if str_eq(name, "sig_is_extern") == 1 { return 1; };
    if str_eq(name, "ir_op") == 1 { return 1; };
    if str_eq(name, "ir_dest") == 1 { return 1; };
    if str_eq(name, "ir_op1") == 1 { return 1; };
    if str_eq(name, "ir_op2") == 1 { return 1; };
    if str_eq(name, "ir_extra") == 1 { return 1; };
    if str_eq(name, "ir_block_label") == 1 { return 1; };
    if str_eq(name, "ir_block_get_inst") == 1 { return 1; };
    if str_eq(name, "ir_fn_name") == 1 { return 1; };
    if str_eq(name, "ir_fn_param_count") == 1 { return 1; };
    if str_eq(name, "ir_fn_get_block") == 1 { return 1; };
    if str_eq(name, "lx_reg") == 1 { return 1; };
    if str_eq(name, "lx_blk") == 1 { return 1; };
    if str_eq(name, "ir_const_int") == 1 { return 1; };
    if str_starts_with(name, "json_") == 1 { return 1; };
    if str_starts_with(name, "map_") == 1 { return 1; };
    if str_starts_with(name, "vec_") == 1 { return 1; };
    if str_starts_with(name, "nuc_json_") == 1 { return 1; };
    if str_starts_with(name, "nuc_graph_") == 1 { return 1; };
    if str_starts_with(name, "nuc_bm25_") == 1 { return 1; };
    if str_starts_with(name, "nuc_hnsw_") == 1 { return 1; };
    if str_starts_with(name, "nuc_emb_") == 1 { return 1; };
    if str_starts_with(name, "nuc_sym_") == 1 { return 1; };
    if str_starts_with(name, "nuc_stat_") == 1 { return 1; };
    return 0;
}
fn type_stmt_value(pool: Vec<i32>, nid: i64) -> i64 {
    let kind: i64 = node_kind(pool, nid);
    if kind == 25 || kind == 22 { return node_field(pool, nid, 1); };
    return 0 - 1;
}
fn type_last_stmt(pool: Vec<i32>, lid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, tprof: Vec<i32>) -> str {
    if lid < 0 || lid >= vec_len(pool) { return ""; };
    let cnt: i64 = list_len(pool, lid);
    if cnt == 0 { return ""; };
    let last_stmt: i64 = list_get(pool, lid, cnt - 1);
    let val: i64 = type_stmt_value(pool, last_stmt);
    if val >= 0 { return type_expr(pool, val, env, sigs, structs, fn_name, diags, source, tprof); };
    if node_kind(pool, last_stmt) == 23 || node_kind(pool, last_stmt) == 52 { return type_expr(pool, last_stmt, env, sigs, structs, fn_name, diags, source, tprof); };
    return "";
}
fn type_expr(pool: Vec<i32>, nid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, tprof: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 { return "i32"; };
    if kind == 71 { return "f64"; };
    if kind == 72 { return "f64"; };
    if kind == 2 { return "str"; };
    if kind == 122 {
        // RFC-0016 phase 1: ? operator. Until generic enums land we treat
        // the unwrapped payload as i64 — matches the existing untyped
        // Result<i64,i64> stub layout in stdlib/rods/result.nr.
        return "i64";
    };
    if kind == 99 {
        // RFC-0015 phase 2: `as` cast. Fire NUM-003 (warning) when the
        // cast loses precision (target_width < source_width within the
        // same class). Returns "" (the legacy unknown-type marker) so
        // existing v0.1.x code that assigns a cast result to a wider
        // binding (e.g. `let x: i64 = small as u8;`) still type-checks
        // — strict cast typing flips on with the stdlib audit.
        let target_type: str = node_field(pool, nid, 2);
        let source_t: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let sw: i64 = type_width(source_t);
        let tw: i64 = type_width(target_type);
        let ss: i64 = type_signedness(source_t);
        let ts: i64 = type_signedness(target_type);
        if sw > 0 && tw > 0 && ss == ts && tw < sw {
            let nloc: Vec<i32> = find_linecol_in_source(source, fn_name, fn_name);
            diag_add_ex(diags, "warning", "type", "NUM-003", str_concat("`as` cast loses precision: ", str_concat(source_t, str_concat(" (", str_concat(str_from_int(sw), str_concat("-bit) -> ", str_concat(target_type, str_concat(" (", str_concat(str_from_int(tw), "-bit)")))))))), fn_name, vec_get(nloc, 0), vec_get(nloc, 1), "");
        };
        return "";
    };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if str_eq(name, "true") == 1 || str_eq(name, "false") == 1 { return "bool"; };
        let env_start: i64 = tprof_start(tprof);
        let out: str = tenv_get(env, name);
        tprof_mark(tprof, 3, 4, env_start);
        return out;
    };
    if kind == 4 {
        let op: i64 = node_field(pool, nid, 1);
        let lt: str = type_expr(pool, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof);
        let rt: str = type_expr(pool, node_field(pool, nid, 3), env, sigs, structs, fn_name, diags, source, tprof);
        if (op == 20 || op == 21 || op == 22 || op == 23 || op == 24) && (str_eq(lt, "bool") == 1 || str_eq(rt, "bool") == 1) {
            type_diag(diags, source, fn_name, fn_name, "TYP-002", "boolean values cannot be used in arithmetic");
        };
        if (op == 20 || op == 21) && type_is_unit(lt) == 1 && type_is_unit(rt) == 1 && str_eq(unit_dim(lt), unit_dim(rt)) == 0 {
            type_diag(diags, source, fn_name, fn_name, "TYP-003", "unit operands for addition/subtraction must match");
        };
        // RFC-0015 phase 6 (NUM-001 firing) is gated behind the stdlib
        // audit (phase 5) — the existing v0.1.x codebase relies on
        // implicit i32→i64 widening pervasively. The classifier
        // helpers (type_width, type_signedness, type_is_int, type_is_float,
        // type_is_numeric) are in place; the typecker will start firing
        // NUM-001 at warning level once `nuc fix --numeric` (RFC-0015
        // phase 5) has migrated the stdlib.
        if is_tainted_type(lt) == 1 { return lt; };
        if is_tainted_type(rt) == 1 { return rt; };
        if (op == 20 || op == 21) && type_is_unit(lt) == 1 && str_eq(unit_dim(lt), unit_dim(rt)) == 1 { return lt; };
        if op == 30 || op == 31 || op == 32 || op == 33 || op == 34 || op == 35 || op == 36 || op == 37 { return "bool"; };
        return lt;
    };
    if kind == 5 || kind == 6 { return type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof); };
    if kind == 90 {
        let inner: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        if str_len(inner) == 0 { return ""; };
        return str_concat("&", inner);
    };
    if kind == 91 {
        let inner: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        if str_len(inner) == 0 { return ""; };
        return str_concat("&mut ", inner);
    };
    if kind == 92 {
        let mut inner: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        if node_kind(pool, node_field(pool, nid, 1)) == 3 {
            let box_start: i64 = tprof_start(tprof);
            let guessed_box: str = source_box_binding_type(source, fn_name, node_field(pool, node_field(pool, nid, 1), 1));
            tprof_mark(tprof, 11, 12, box_start);
            if str_len(guessed_box) > 0 { inner = guessed_box; };
        };
        if type_is_ref(inner) == 0 && str_eq(type_base_name(inner), "Box") == 0 {
            if str_eq(inner, "i32") == 1 || str_eq(inner, "i64") == 1 || str_eq(inner, "bool") == 1 || str_eq(inner, "f64") == 1 || str_eq(inner, "str") == 1 || str_eq(inner, "ptr") == 1 {
                type_diag(diags, source, fn_name, fn_name, "TYP-004", "cannot dereference a non-reference value");
            };
            return "";
        };
        if str_eq(type_base_name(inner), "Box") == 1 {
            let slen: i64 = str_len(inner);
            if slen >= 5 && str_starts_with(inner, "Box<") == 1 { return str_substring(inner, 4, slen - 1); };
        };
        return type_base_name(inner);
    };
    if kind == 7 {
        let call_start: i64 = tprof_start(tprof);
        let callee: str = node_field(pool, nid, 1);
        let args: i64 = node_field(pool, nid, 2);
        let argc: i64 = list_len(pool, args);
        if str_eq(callee, "sanitize") == 1 && argc > 0 {
            let arg_t: str = type_expr(pool, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
            tprof_mark(tprof, 9, 10, call_start);
            if is_tainted_type(arg_t) == 1 { return taint_inner_type(arg_t); };
            return arg_t;
        };
        if type_dynamic_helper(callee) == 1 { tprof_mark(tprof, 9, 10, call_start); return ""; };
        let sig_start: i64 = tprof_start(tprof);
        let sentry: i64 = sig_find(sigs, callee);
        tprof_mark(tprof, 5, 6, sig_start);
        if sentry >= 0 {
            let plist: i64 = vec_get(sentry, 0);
            let expected_argc: i64 = list_len(pool, plist);
            if argc != expected_argc { type_diag(diags, source, fn_name, callee, "TYP-005", str_concat("wrong number of arguments for '", str_concat(callee, "'"))); };
            let mut ai: i64 = 0;
            while ai < argc && ai < expected_argc {
                let actual_t: str = type_expr(pool, list_get(pool, args, ai), env, sigs, structs, fn_name, diags, source, tprof);
                let expected_t: str = node_field(pool, list_get(pool, plist, ai), 2);
                let compat_start: i64 = tprof_start(tprof);
                let compat_ok: i64 = types_compatible(expected_t, actual_t);
                tprof_mark(tprof, 7, 8, compat_start);
                if compat_ok == 0 {
                    type_diag(diags, source, fn_name, callee, "TYP-006", str_concat("argument type mismatch in call to '", str_concat(callee, "'")));
                };
                ai = ai + 1;
            };
            tprof_mark(tprof, 9, 10, call_start);
            return vec_get(sentry, 1);
        };
        tprof_mark(tprof, 9, 10, call_start);
        return builtin_rtype(callee);
    };
    if kind == 8 {
        let recv_t: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let mname: str = node_field(pool, nid, 2);
        if str_eq(mname, "sum") == 1 || str_eq(mname, "mean") == 1 || str_eq(mname, "max") == 1 || str_eq(mname, "min") == 1 {
            if str_eq(type_base_name(recv_t), "Tensor") == 1 { return "f64"; };
            return "i32";
        };
        if str_eq(mname, "any") == 1 || str_eq(mname, "all") == 1 { return "bool"; };
        if str_eq(mname, "len") == 1 { return "i64"; };
        if str_eq(mname, "matmul") == 1 { return recv_t; };
        if str_eq(mname, "set") == 1 { return "void"; };
        if str_eq(mname, "iter") == 1 { return recv_t; };
        return "";
    };
    if kind == 9 {
        let recv_t: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let si: i64 = struct_find_type(pool, structs, recv_t);
        if si >= 0 { return struct_field_type(pool, vec_get(structs, si), node_field(pool, nid, 2)); };
        return "";
    };
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let args: i64 = node_field(pool, nid, 3);
        if str_eq(tname, "Box") == 1 {
            if list_len(pool, args) > 0 {
                let inner: str = type_expr(pool, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
                if str_len(inner) > 0 { return str_concat("Box<", str_concat(inner, ">")); };
            };
            return "Box<i64>";
        };
        if str_eq(tname, "Tensor") == 1 { return "Tensor<f64>"; };
        if str_eq(tname, "Option") == 1 { return "Option"; };
        if str_eq(tname, "Result") == 1 { return "Result"; };
        return "";
    };
    if kind == 34 { return node_field(pool, nid, 1); };
    if kind == 52 { return type_last_stmt(pool, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof); };
    if kind == 23 {
        let tt: str = type_last_stmt(pool, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 {
            let et: str = type_last_stmt(pool, enode, env, sigs, structs, fn_name, diags, source, tprof);
            if str_eq(strip_spaces(tt), strip_spaces(et)) == 1 { return tt; };
        };
        return tt;
    };
    return "";
}
fn type_check_stmt(pool: Vec<i32>, nid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, rtype: str, tprof: Vec<i32>) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    if kind == 20 {
        let vname: str = node_field(pool, nid, 1);
        let tstr: str = node_field(pool, nid, 3);
        let init: i64 = node_field(pool, nid, 4);
        let mut init_t: str = "";
        if init >= 0 {
            init_t = type_expr(pool, init, env, sigs, structs, fn_name, diags, source, tprof);
            if str_len(tstr) > 0 {
                if type_is_unit(tstr) == 1 && (node_kind(pool, init) == 1 || node_kind(pool, init) == 71) && line_has_unit_literal(source, fn_name, vname) == 0 {
                    type_diag(diags, source, fn_name, vname, "TYP-007", "bare numeric literal cannot initialize a unit value");
                } else {
                    let compat_start: i64 = tprof_start(tprof);
                    let compat_ok: i64 = types_compatible(tstr, init_t);
                    tprof_mark(tprof, 7, 8, compat_start);
                    if compat_ok == 0 {
                    type_diag(diags, source, fn_name, vname, "TYP-008", str_concat("type mismatch for binding '", str_concat(vname, "'")));
                    };
                };
            };
            // RFC-0015 phase 6: NUM-002 — integer literal out of range for
            // declared type. Only fires for bare integer literal init
            // (kind == 1) with an explicit narrow numeric type. The check
            // uses two's-complement signed range / 0..2^width unsigned
            // range. Fires as warning, not error, until the strict-mode
            // flip in v0.4.
            if str_len(tstr) > 0 && node_kind(pool, init) == 1 && type_is_int(tstr) == 1 {
                let lit_v: i64 = node_field(pool, init, 1);
                let w: i64 = type_width(tstr);
                let s: i64 = type_signedness(tstr);
                let mut out_of_range: i64 = 0;
                if s == 1 && w < 64 {
                    let max_v: i64 = i64_pow(2, w - 1) - 1;
                    let min_v: i64 = 0 - i64_pow(2, w - 1);
                    if lit_v > max_v || lit_v < min_v { out_of_range = 1; };
                };
                if s == 2 && w < 64 {
                    let umax_v: i64 = i64_pow(2, w) - 1;
                    if lit_v < 0 || lit_v > umax_v { out_of_range = 1; };
                };
                if s == 2 && w == 64 && lit_v < 0 {
                    out_of_range = 1;
                };
                if out_of_range == 1 {
                    let nloc: Vec<i32> = find_linecol_in_source(source, fn_name, vname);
                    diag_add_ex(diags, "warning", "type", "NUM-002", str_concat("numeric literal ", str_concat(str_from_int(lit_v), str_concat(" out of range for declared type ", tstr))), fn_name, vec_get(nloc, 0), vec_get(nloc, 1), "");
                };
            };
            // RFC-0015 phase 6: NUM-005 — usize/isize mixed with an
            // explicit-width numeric type. Even when widths happen to
            // match on the current target, this is a portability hazard
            // (LP64 vs ILP32). Warning only.
            if str_len(tstr) > 0 && type_is_numeric(tstr) == 1 && type_is_numeric(init_t) == 1 {
                let lhs_is_size: i64 = if str_eq(type_base_name(tstr), "usize") == 1 || str_eq(type_base_name(tstr), "isize") == 1 { 1 } else { 0 };
                let rhs_is_size: i64 = if str_eq(type_base_name(init_t), "usize") == 1 || str_eq(type_base_name(init_t), "isize") == 1 { 1 } else { 0 };
                if lhs_is_size != rhs_is_size {
                    let nloc2: Vec<i32> = find_linecol_in_source(source, fn_name, vname);
                    diag_add_ex(diags, "warning", "type", "NUM-005", str_concat("usize/isize mixed with explicit-width type: ", str_concat(tstr, str_concat(" vs ", init_t))), fn_name, vec_get(nloc2, 0), vec_get(nloc2, 1), "");
                };
            };
        };
        if str_len(tstr) > 0 {
            if str_len(init_t) == 0 { tenv_set(env, vname, ""); }
            else { tenv_set(env, vname, tstr); };
        }
        else { tenv_set(env, vname, init_t); };
        return warns;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let rhs: i64 = node_field(pool, nid, 2);
        let rhs_t: str = type_expr(pool, rhs, env, sigs, structs, fn_name, diags, source, tprof);
        if node_kind(pool, lhs) == 3 {
            let env_start: i64 = tprof_start(tprof);
            let lhs_t: str = tenv_get(env, node_field(pool, lhs, 1));
            tprof_mark(tprof, 3, 4, env_start);
            let compat_start: i64 = tprof_start(tprof);
            let compat_ok: i64 = types_compatible(lhs_t, rhs_t);
            tprof_mark(tprof, 7, 8, compat_start);
            if compat_ok == 0 { type_diag(diags, source, fn_name, node_field(pool, lhs, 1), "TYP-009", "assignment type mismatch"); };
        };
        return warns;
    };
    if kind == 22 {
        let val: i64 = node_field(pool, nid, 1);
        if val >= 0 {
            let val_t: str = type_expr(pool, val, env, sigs, structs, fn_name, diags, source, tprof);
            let compat_start: i64 = tprof_start(tprof);
            let compat_ok: i64 = types_compatible(rtype, val_t);
            tprof_mark(tprof, 7, 8, compat_start);
            if str_len(rtype) > 0 && str_eq(rtype, "void") == 0 && compat_ok == 0 {
                type_diag(diags, source, fn_name, fn_name, "TYP-010", "return type mismatch");
            };
        };
        return warns;
    };
    if kind == 23 {
        type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let then_env: Vec<i32> = own_snapshot(env);
        warns = warns + type_check_stmts(pool, node_field(pool, nid, 2), then_env, sigs, structs, fn_name, diags, source, rtype, tprof);
        vec_free(then_env);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 {
            let else_env: Vec<i32> = own_snapshot(env);
            warns = warns + type_check_stmts(pool, enode, else_env, sigs, structs, fn_name, diags, source, rtype, tprof);
            vec_free(else_env);
        };
        return warns;
    };
    if kind == 24 { type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof); return type_check_stmts(pool, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, rtype, tprof); };
    if kind == 25 { type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof); return warns; };
    if kind == 28 { return type_check_stmts(pool, node_field(pool, nid, 4), env, sigs, structs, fn_name, diags, source, rtype, tprof); };
    if kind == 49 { type_expr(pool, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof); return type_check_stmts(pool, node_field(pool, nid, 3), env, sigs, structs, fn_name, diags, source, rtype, tprof); };
    if kind == 38 {
        type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let arms: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, arms);
        let mut ai: i64 = 0;
        while ai < ac {
            let arm_env: Vec<i32> = own_snapshot(env);
            warns = warns + type_check_stmts(pool, node_field(pool, list_get(pool, arms, ai), 4), arm_env, sigs, structs, fn_name, diags, source, rtype, tprof);
            vec_free(arm_env);
            ai = ai + 1;
        };
        return warns;
    };
    return warns;
}
fn type_check_stmts(pool: Vec<i32>, lid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, rtype: str, tprof: Vec<i32>) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    let mut warns: i64 = 0;
    while i < cnt {
        let stmt_start: i64 = tprof_start(tprof);
        warns = warns + type_check_stmt(pool, list_get(pool, lid, i), env, sigs, structs, fn_name, diags, source, rtype, tprof);
        tprof_mark(tprof, 1, 2, stmt_start);
        i = i + 1;
    };
    return warns;
}
fn type_check_program(pool: Vec<i32>, prog: i64, structs: Vec<i32>, diags: Vec<i32>, source: str, tprof: Vec<i32>) -> i64 {
    let mut sigs: Vec<i32> = sig_new();
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 { sig_add(sigs, node_field(pool, nid, 1), node_field(pool, nid, 2), node_field(pool, nid, 3), 0); };
        if node_kind(pool, nid) == 32 { sig_add(sigs, node_field(pool, nid, 1), node_field(pool, nid, 2), node_field(pool, nid, 3), 1); };
        i = i + 1;
    };
    let mut warns: i64 = 0;
    i = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let fn_name: str = node_field(pool, nid, 1);
            let plist: i64 = node_field(pool, nid, 2);
            let body: i64 = node_field(pool, nid, 4);
            let rtype: str = node_field(pool, nid, 3);
            let mut env: Vec<i32> = tenv_new();
            let pc: i64 = list_len(pool, plist);
            let mut pi: i64 = 0;
            while pi < pc {
                let pnid: i64 = list_get(pool, plist, pi);
                tenv_set(env, node_field(pool, pnid, 1), node_field(pool, pnid, 2));
                pi = pi + 1;
            };
            warns = warns + type_check_stmts(pool, body, env, sigs, structs, fn_name, diags, source, rtype, tprof);
        };
        i = i + 1;
    };
    return warns;
}

fn text_contains(hay: str, needle: str) -> i64 {
    let hlen: i64 = str_len(hay);
    let nlen: i64 = str_len(needle);
    if nlen == 0 { return 1; };
    if hlen < nlen { return 0; };
    let mut i: i64 = 0;
    while i <= hlen - nlen {
        if str_eq_at(hay, i, needle) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}
fn source_has_scope_escape_ref_binding(source: str) -> i64 {
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(source, lp) == 32 || str_char_at(source, lp) == 9) { lp = lp + 1; };
        let line: str = str_substring(source, lp, eol);
        if str_starts_with(line, "let ") == 1 && text_contains(line, ": &") == 1 && text_contains(line, "= {") == 1 { return 1; };
        p = eol + 1;
    };
    return 0;
}
fn preflight_source_check(source: str) -> i64 {
    if source_has_scope_escape_ref_binding(source) == 1 {
        let mut diags: Vec<i32> = diag_new();
        type_diag(diags, source, "main", "let", "OWN-010", "cannot bind a reference that escapes an inner block");
        diags = filter_allow_suppressed(diags, source);
        diags = promote_denied_to_errors(diags, source);
        if diag_count(diags) == 0 { return 0; };
        if diag_use_json() == 1 { diag_emit_json(diags); } else { diag_emit_text_with_source(diags, source); };
        return 1;
    };
    return 0;
}
// Sanitize is a no-op at runtime (identity function)
// It is handled by the taint checker at compile time

fn match_bind_payloads(binding: str, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, mslot: i64, fir: Vec<i32>) -> Vec<i32> {
    let mut cur: Vec<i32> = blk;
    let blen: i64 = str_len(binding);
    if blen == 0 { return cur; };
    let mut start: i64 = 0;
    let mut payload_idx: i64 = 1;
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(binding, end) != 124 { end = end + 1; };
        let name: str = str_substring(binding, start, end);
        if str_len(name) > 0 {
            let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
            sym_set(sym, name, bar);
            let mv2: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv2, mslot));
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, payload_idx));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(mv2); get_args.push(idx_r);
            let pv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pv_r, "vec_get", get_args));
            ir_block_add(cur, ir_store(pv_r, bar));
            payload_idx = payload_idx + 1;
        };
        start = end + 1;
    };
    return cur;
}

fn capture_has_name(caps: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(caps) {
        if str_eq(vec_get(caps, i), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn capture_param_has(pool: Vec<i32>, params: i64, name: str) -> i64 {
    let pc: i64 = list_len(pool, params);
    let mut i: i64 = 0;
    while i < pc {
        if str_eq(list_get(pool, params, i), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn closure_collect_capture_expr(pool: Vec<i32>, nid: i64, sym: Vec<i32>, params: i64, caps: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if sym_get(sym, name) >= 0 && capture_param_has(pool, params, name) == 0 && capture_has_name(caps, name) == 0 {
            caps.push(name);
        };
        return 0;
    };
    if kind == 4 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        closure_collect_capture_expr(pool, node_field(pool, nid, 3), sym, params, caps);
        return 0;
    };
    if kind == 5 || kind == 6 || kind == 90 || kind == 91 || kind == 92 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        return 0;
    };
    if kind == 7 || kind == 12 {
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            closure_collect_capture_expr(pool, list_get(pool, args, ai), sym, params, caps);
            ai = ai + 1;
        };
        return 0;
    };
    if kind == 8 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            closure_collect_capture_expr(pool, list_get(pool, args, ai), sym, params, caps);
            ai = ai + 1;
        };
        return 0;
    };
    if kind == 9 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        return 0;
    };
    if kind == 10 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        return 0;
    };
    if kind == 23 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        let tb: i64 = node_field(pool, nid, 2);
        let tc: i64 = list_len(pool, tb);
        let mut ti: i64 = 0;
        while ti < tc {
            closure_collect_capture_stmt(pool, list_get(pool, tb, ti), sym, params, caps);
            ti = ti + 1;
        };
        let eb: i64 = node_field(pool, nid, 3);
        if eb >= 0 {
            let ec: i64 = list_len(pool, eb);
            let mut ei: i64 = 0;
            while ei < ec {
                closure_collect_capture_stmt(pool, list_get(pool, eb, ei), sym, params, caps);
                ei = ei + 1;
            };
        };
        return 0;
    };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            closure_collect_capture_expr(pool, list_get(pool, items, ii), sym, params, caps);
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 34 {
        let init_list: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, init_list);
        let mut ii: i64 = 0;
        while ii < ic {
            closure_collect_capture_expr(pool, node_field(pool, list_get(pool, init_list, ii), 2), sym, params, caps);
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 52 {
        let body: i64 = node_field(pool, nid, 2);
        let bc: i64 = list_len(pool, body);
        let mut bi: i64 = 0;
        while bi < bc {
            closure_collect_capture_stmt(pool, list_get(pool, body, bi), sym, params, caps);
            bi = bi + 1;
        };
        return 0;
    };
    // v0.3.113: nested closure literal (kind 42). Pre-v0.3.113, the
    // outer closure's capture-collect ignored inner closure literals
    // entirely (no kind-42 case). Outer never captured names that
    // ONLY the inner closure referenced — so when inner's lowering
    // queried outer's clo_sym for those names, they weren't there,
    // inner emitted `@<name>` global refs, and clang link failed
    // (`use of undefined value '@n'`). Walk the inner's body and
    // bubble up any var-refs that resolve in OUTER's sym AND are
    // NOT inner's params (those are inner-local and shouldn't
    // propagate to outer's capture set).
    if kind == 42 {
        let inner_params: i64 = node_field(pool, nid, 1);
        let inner_body: i64 = node_field(pool, nid, 2);
        let ibc: i64 = list_len(pool, inner_body);
        let mut ibi: i64 = 0;
        while ibi < ibc {
            // Use inner's params as the "shadow" param list so a name
            // that's an inner-param is treated as bound (skipped).
            // Otherwise the existing capture-collect rules apply.
            closure_collect_capture_stmt(pool, list_get(pool, inner_body, ibi), sym, inner_params, caps);
            ibi = ibi + 1;
        };
        return 0;
    };
    return 0;
}

fn closure_collect_capture_stmt(pool: Vec<i32>, nid: i64, sym: Vec<i32>, params: i64, caps: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 20 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 4), sym, params, caps);
        return 0;
    };
    if kind == 21 {
        // v0.3.96: detect mutable capture writeback. If the LHS of an
        // assignment in a closure body is a captured variable
        // (kind 3 var ref whose name resolves in the OUTER sym AND
        // isn't a closure param), emit a clear diagnostic. Pre-v0.3.96
        // this silently no-op'd — the assignment wrote to the closure's
        // local copy of the captured value (loaded once at entry via
        // __nucleor_capture_get) and never propagated back to the
        // caller's scope. Programs using FnMut-style mutation in
        // closures silently mis-computed.
        let lhs: i64 = node_field(pool, nid, 1);
        if node_kind(pool, lhs) == 3 {
            let lname: str = node_field(pool, lhs, 1);
            if sym_get(sym, lname) >= 0 && capture_param_has(pool, params, lname) == 0 {
                print(str_concat("ERROR: closure cannot mutate captured variable `", str_concat(lname, "` via assignment. The mutation would write to the closure's local copy and silently NOT propagate back to the caller's scope (FnMut semantics not yet supported). Workaround: have the closure RETURN the new value (`let new = inc(5); total = new;`) or use a `Vec<i64>` for shared mutable state. Tracked for a future ship.")));
            };
        };
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        closure_collect_capture_expr(pool, node_field(pool, nid, 2), sym, params, caps);
        return 0;
    };
    if kind == 22 || kind == 25 {
        closure_collect_capture_expr(pool, node_field(pool, nid, 1), sym, params, caps);
        return 0;
    };
    if kind == 23 {
        closure_collect_capture_expr(pool, nid, sym, params, caps);
        return 0;
    };
    // v0.3.72: bare-expression body fall-through. When a closure
    // literal's body is `|x| EXPR` (no braces), the parser stores
    // EXPR as the single body element — but EXPR has an expression
    // kind (binop/call/index/etc.), not a stmt kind. Pre-v0.3.72,
    // closure_collect_capture_stmt silently returned without walking,
    // missing every capture in inline closures (typically those
    // passed to .map / .filter / .fold). The let-bound case
    // (`let f = |x| x + outer;`) accidentally worked because the
    // outer let-stmt's RHS handler took a different path. Without
    // this, every `v.map(|x| x * factor)` lowered to a closure body
    // that referenced `@factor` as a missing global symbol —
    // unresolved external at link time.
    closure_collect_capture_expr(pool, nid, sym, params, caps);
    return 0;
}

fn lower_if_expr_branch(pool: Vec<i32>, lid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    let mut b: Vec<i32> = cur;
    while i < cnt {
        let stmt: i64 = list_get(pool, lid, i);
        let sk: i64 = node_kind(pool, stmt);
        if i == cnt - 1 {
            if sk == 25 {
                return lower_expr(pool, node_field(pool, stmt, 1), b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
            if sk == 23 {
                return lower_expr(pool, stmt, b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
        };
        b = lower_stmt(pool, stmt, b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        if block_has_term(b) == 1 { return lx_new(0 - 1, b); };
        i = i + 1;
    };
    let zr: i64 = ctr_next(regs);
    ir_block_add(b, ir_const_int(zr, 0));
    return lx_new(zr, b);
}

// v0.3.128: helper for enum-equality dispatch in lower_expr kind-4.
// Returns the etag (>= 0) if the node is a kind-12 associated-fn-call
// matching a registered enum variant constructor (sym key
// `__etag_<tname>_<mname>` populated at enum-collection time).
// Returns -1 otherwise.
fn enum_etag_for_node(pool: Vec<i32>, nid: i64, sym: Vec<i32>) -> i64 {
    if node_kind(pool, nid) != 12 { return 0 - 1; };
    let tname: str = node_field(pool, nid, 1);
    let mname: str = node_field(pool, nid, 2);
    let key: str = str_concat("__etag_", str_concat(tname, str_concat("_", mname)));
    return sym_get(sym, key);
}

fn lower_expr(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let kind: i64 = node_kind(pool, nid);
    // RFC-0015 phase 2: `as` cast. Lower inner, then call __nucleor_as_<T>
    // to actually perform width truncation / sign extension at runtime.
    if kind == 99 {
        let inner_nid: i64 = node_field(pool, nid, 1);
        let inner_lx: Vec<i32> = lower_expr(pool, inner_nid, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let inner_blk: Vec<i32> = lx_blk(inner_lx);
        let inner_r: i64 = lx_reg(inner_lx);
        let target_type: str = node_field(pool, nid, 2);
        // T1.1 Phase 4: full as-cast matrix. If we can detect that
        // source is a float (variable with f32/f64 type, or kind==71
        // f64 literal), dispatch to the float↔int / float↔float
        // converter helper. Otherwise fall through to the existing
        // int-only `as_<T>` mask path.
        let src_ftype: str = binop_float_type(pool, inner_nid, sym, structs);
        let mut conv_helper: str = "";
        // Float → narrow int / float → float dispatch. i64 target
        // is INTENTIONALLY left to the bitcast-preserving as_i64
        // helper because Nucleor's i64-everywhere ABI relies on
        // `f64 as i64` being a no-op bit-preservation for FFI to C
        // runtime functions. To truncate float→i64 explicitly use
        // `(x as i32) as i64` or call `f64_to_i64()` directly.
        if str_eq(src_ftype, "f32") == 1 {
            if str_eq(target_type, "i32") == 1 { conv_helper = "f32_to_i32"; };
            if str_eq(target_type, "u32") == 1 { conv_helper = "f32_to_u32"; };
            if str_eq(target_type, "f64") == 1 { conv_helper = "f32_to_f64"; };
        };
        if str_eq(src_ftype, "f64") == 1 {
            if str_eq(target_type, "i32") == 1 { conv_helper = "f64_to_i32"; };
            if str_eq(target_type, "u32") == 1 { conv_helper = "f64_to_u32"; };
            if str_eq(target_type, "f32") == 1 { conv_helper = "f64_to_f32"; };
        };
        // int → float: detect if source has int type and target is float.
        if str_len(src_ftype) == 0 {
            if str_eq(target_type, "f32") == 1 { conv_helper = "i64_to_f32"; };
            if str_eq(target_type, "f64") == 1 { conv_helper = "i64_to_f64"; };
        };
        if str_len(conv_helper) > 0 {
            let mut cargs: Vec<i32> = Vec::new();
            cargs.push(inner_r);
            let r: i64 = ctr_next(regs);
            ir_block_add(inner_blk, ir_call_ex(r, conv_helper, cargs));
            return lx_new(r, inner_blk);
        };
        // Fall through to existing as_<T> mask helpers (int↔int).
        let mut helper: str = "";
        if str_eq(target_type, "i8") == 1 { helper = "as_i8"; };
        if str_eq(target_type, "i16") == 1 { helper = "as_i16"; };
        if str_eq(target_type, "i32") == 1 { helper = "as_i32"; };
        if str_eq(target_type, "i64") == 1 { helper = "as_i64"; };
        if str_eq(target_type, "isize") == 1 { helper = "as_i64"; };
        if str_eq(target_type, "u8") == 1 { helper = "as_u8"; };
        if str_eq(target_type, "u16") == 1 { helper = "as_u16"; };
        if str_eq(target_type, "u32") == 1 { helper = "as_u32"; };
        if str_eq(target_type, "u64") == 1 { helper = "as_u64"; };
        if str_eq(target_type, "usize") == 1 { helper = "as_u64"; };
        if str_eq(target_type, "f32") == 1 { helper = "as_f32"; };
        if str_eq(target_type, "f64") == 1 { helper = "as_f64"; };
        if str_eq(target_type, "char") == 1 { helper = "as_u32"; };
        if str_len(helper) == 0 {
            return inner_lx;
        };
        let mut conv_args: Vec<i32> = Vec::new();
        conv_args.push(inner_r);
        let r: i64 = ctr_next(regs);
        ir_block_add(inner_blk, ir_call_ex(r, helper, conv_args));
        return lx_new(r, inner_blk);
    };
    if kind == 1 {
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(r, node_field(pool, nid, 1)));
        return lx_new(r, blk);
    };
    if kind == 71 {
        let scaled_r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(scaled_r, node_field(pool, nid, 1)));
        let mut conv_args: Vec<i32> = Vec::new();
        conv_args.push(scaled_r);
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_call_ex(r, "f64_from_scaled", conv_args));
        return lx_new(r, blk);
    };
    // v0.3.133: f64 raw-bits literal (AST kind 72). Value IS the i64
    // bit pattern of the parsed float (via str_to_f64 at lex time).
    // Lower as a direct const_int — Nucleor's f64 IS the i64 bit
    // pattern at the runtime ABI level, so no conversion needed.
    if kind == 72 {
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(r, node_field(pool, nid, 1)));
        return lx_new(r, blk);
    };
    if kind == 122 {
        // RFC-0016 phase 1: `?` postfix operator. Inner expression returns a
        // Result-like Vec<i32> with [0]=tag (Ok=1, Err=0) and [1]=payload —
        // matching the stdlib `result.nr` convention (and v0.3.91-revised
        // __etag_Result_Ok=1 / __etag_Result_Err=0 at line 5298-5301).
        //
        // Lowering: compute `cmp = (tag == 0)` (true on Err); if true,
        // branch to err_lbl (early-return the Result); else branch to
        // ok_lbl (extract payload at index 1).
        let inner_lx: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mut cur: Vec<i32> = lx_blk(inner_lx);
        let val_r: i64 = lx_reg(inner_lx);
        let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
        let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(val_r); tag_args.push(zero_r);
        let tag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
        let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, zero_r));
        let err_lbl: i64 = ctr_next(lbls); let ok_lbl: i64 = ctr_next(lbls);
        // cmp_r == 1 (tag==0, Err) → err_lbl (return); cmp_r == 0 (tag!=0, Ok) → ok_lbl (extract).
        ir_block_add(cur, ir_br_cond(cmp_r, err_lbl, ok_lbl));
        let mut err_blk: Vec<i32> = ir_block_new(err_lbl); ir_fn_add_block(fir, err_blk);
        ir_block_add(err_blk, ir_ret(val_r));
        let mut ok_blk: Vec<i32> = ir_block_new(ok_lbl); ir_fn_add_block(fir, ok_blk);
        let one_r: i64 = ctr_next(regs); ir_block_add(ok_blk, ir_const_int(one_r, 1));
        let mut pay_args: Vec<i32> = Vec::new(); pay_args.push(val_r); pay_args.push(one_r);
        let pay_r: i64 = ctr_next(regs); ir_block_add(ok_blk, ir_call_ex(pay_r, "vec_get", pay_args));
        return lx_new(pay_r, ok_blk);
    };
    if kind == 2 {
        let idx: i64 = vec_len(strtab);
        strtab.push(node_field(pool, nid, 1));
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_str(r, idx));
        return lx_new(r, blk);
    };
    if kind == 3 {
        let iname: str = node_field(pool, nid, 1);
        if str_eq(iname, "true") {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(r, 1));
            return lx_new(r, blk);
        };
        if str_eq(iname, "false") {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(r, 0));
            return lx_new(r, blk);
        };
        let ar: i64 = sym_get(sym, iname);
        if ar < 0 {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_fn_ptr(r, iname));
            return lx_new(r, blk);
        };
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_load(r, ar));
        return lx_new(r, blk);
    };
    if kind == 4 {
        // v0.3.128: enum-equality dispatch. Pre-v0.3.128, `t == Tag::A`
        // (where t is an enum value) compared the underlying Vec
        // pointers — each Tag::A constructor allocates a fresh Vec, so
        // pointer equality was always false. Silent miscompute for
        // every enum-discriminator comparison adopters wrote.
        // Detect: if BOTH operands resolve to known enum etags (the
        // sym entry `__etag_<tname>_<mname>` populated at enum
        // collection), OR if exactly one is a kind-12 enum-variant
        // constructor and the other is presumed to be an enum value
        // of the same type (var-ref / fn-call result), emit a tag
        // compare instead of pointer compare. Tag is at vec_get(_, 0).
        let bop: i64 = node_field(pool, nid, 1);
        if bop == 30 || bop == 31 {
            let lhs_n: i64 = node_field(pool, nid, 2);
            let rhs_n: i64 = node_field(pool, nid, 3);
            let lhs_etag: i64 = enum_etag_for_node(pool, lhs_n, sym);
            let rhs_etag: i64 = enum_etag_for_node(pool, rhs_n, sym);
            // At least one side is a kind-12 enum constructor with a known etag.
            // The other side is treated as an enum value (its Vec[0] is its tag).
            if lhs_etag >= 0 || rhs_etag >= 0 {
                let mut elp: Vec<i32> = lower_expr(pool, lhs_n, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let elr: i64 = lx_reg(elp);
                let mut ecur: Vec<i32> = lx_blk(elp);
                let mut erp: Vec<i32> = lower_expr(pool, rhs_n, ecur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let err: i64 = lx_reg(erp);
                ecur = lx_blk(erp);
                let zero_r: i64 = ctr_next(regs); ir_block_add(ecur, ir_const_int(zero_r, 0));
                let mut lt_args: Vec<i32> = Vec::new(); lt_args.push(elr); lt_args.push(zero_r);
                let lt_tag: i64 = ctr_next(regs); ir_block_add(ecur, ir_call_ex(lt_tag, "vec_get", lt_args));
                let mut rt_args: Vec<i32> = Vec::new(); rt_args.push(err); rt_args.push(zero_r);
                let rt_tag: i64 = ctr_next(regs); ir_block_add(ecur, ir_call_ex(rt_tag, "vec_get", rt_args));
                let er: i64 = ctr_next(regs);
                let eiop: i64 = if bop == 30 { 7 } else { 8 };
                ir_block_add(ecur, ir_cmpop(eiop, er, lt_tag, rt_tag));
                return lx_new(er, ecur);
            };
        };
        let mut lp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let lr: i64 = lx_reg(lp);
        let mut cur: Vec<i32> = lx_blk(lp);
        let mut rp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let rr: i64 = lx_reg(rp);
        cur = lx_blk(rp);
        let iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        let r: i64 = ctr_next(regs);
        // T1.1 Phase 5: dispatch float binop to runtime helper instead
        // of integer binop. Detection: either operand is a variable
        // declared as f32/f64, or a kind==71 float literal. The f32
        // type wins precedence (matches narrowing cast rule). Only
        // applies to + - * / and the comparison ops.
        let lt: str = binop_float_type(pool, node_field(pool, nid, 2), sym, structs);
        let rt: str = binop_float_type(pool, node_field(pool, nid, 3), sym, structs);
        let mut ftype: str = "";
        if str_eq(lt, "f32") == 1 { ftype = "f32"; }
        else if str_eq(rt, "f32") == 1 { ftype = "f32"; }
        else if str_eq(lt, "f64") == 1 { ftype = "f64"; }
        else if str_eq(rt, "f64") == 1 { ftype = "f64"; };
        let helper: str = float_binop_helper(iop, ftype);
        if str_len(helper) > 0 {
            let mut conv_args: Vec<i32> = Vec::new();
            conv_args.push(lr);
            conv_args.push(rr);
            ir_block_add(cur, ir_call_ex(r, helper, conv_args));
        } else if is_cmp_or_logic(iop) == 1 { ir_block_add(cur, ir_cmpop(iop, r, lr, rr)); }
        else { ir_block_add(cur, ir_binop(iop, r, lr, rr)); };
        return lx_new(r, cur);
    };
    if kind == 5 {
        // v0.3.57 fix: dispatch to float-or-int subtract based on
        // operand type. Pre-v0.3.57 always used integer 0 + integer
        // sub, which mis-computed for f64 operands (subtracts the
        // f64 bit pattern as an i64 → garbage). Now: if operand
        // resolves to f32/f64 via binop_float_type, emit
        // f<T>_from_scaled(0) + f<T>_sub(zr, opr); otherwise the
        // legacy int path.
        let inner_nid: i64 = node_field(pool, nid, 1);
        let neg_ftype: str = binop_float_type(pool, inner_nid, sym, structs);
        let mut op_p: Vec<i32> = lower_expr(pool, inner_nid, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let opr: i64 = lx_reg(op_p);
        let cur: Vec<i32> = lx_blk(op_p);
        let r: i64 = ctr_next(regs);
        if str_len(neg_ftype) > 0 {
            // Float zero literal: scaled-int 0 → f<T>_from_scaled.
            let scaled_zr: i64 = ctr_next(regs);
            ir_block_add(cur, ir_const_int(scaled_zr, 0));
            let zr: i64 = ctr_next(regs);
            let mut from_args: Vec<i32> = Vec::new();
            from_args.push(scaled_zr);
            let from_helper: str = if str_eq(neg_ftype, "f32") == 1 { "f32_from_scaled" } else { "f64_from_scaled" };
            ir_block_add(cur, ir_call_ex(zr, from_helper, from_args));
            // Float sub: f<T>_sub(zr, opr).
            let sub_helper: str = float_binop_helper(3, neg_ftype);
            let mut sub_args: Vec<i32> = Vec::new();
            sub_args.push(zr);
            sub_args.push(opr);
            ir_block_add(cur, ir_call_ex(r, sub_helper, sub_args));
        } else {
            let zr: i64 = ctr_next(regs);
            ir_block_add(cur, ir_const_int(zr, 0));
            ir_block_add(cur, ir_binop(3, r, zr, opr));
        };
        return lx_new(r, cur);
    };
    if kind == 6 {
        let mut op_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let opr: i64 = lx_reg(op_p);
        let cur: Vec<i32> = lx_blk(op_p);
        let zr: i64 = ctr_next(regs);
        ir_block_add(cur, ir_const_int(zr, 0));
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_cmpop(7, r, opr, zr));
        return lx_new(r, cur);
    };
    if kind == 90 || kind == 91 || kind == 92 {
        return lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
    };
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        // T1.1 Phase 3b: sizeof_struct(StructName) — compile-time
        // constant. Looks up the struct and returns its byte size
        // computed per its repr attribute (default Nucleor / C / packed).
        if str_eq(fn_name, "sizeof_struct") {
            let sa: i64 = node_field(pool, nid, 2);
            if list_len(pool, sa) == 1 {
                let arg_nid: i64 = list_get(pool, sa, 0);
                if node_kind(pool, arg_nid) == 3 {
                    let sname: str = node_field(pool, arg_nid, 1);
                    let si: i64 = struct_find_type(pool, structs, sname);
                    if si >= 0 {
                        let snode: i64 = vec_get(structs, si);
                        // Default Nucleor repr: backing storage is
                        // Vec<i32> with one i64 slot per field.
                        // repr(C) / repr(packed) variants land when
                        // attribute-preservation plumbing is wired.
                        let sz: i64 = struct_byte_size(pool, snode, "");
                        let r: i64 = ctr_next(regs);
                        ir_block_add(blk, ir_const_int(r, sz));
                        return lx_new(r, blk);
                    };
                };
            };
        };
        if str_eq(fn_name, "sanitize") {
            let args_list: i64 = node_field(pool, nid, 2);
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
        };
        if str_eq(fn_name, "grad") {
            let g_args: i64 = node_field(pool, nid, 2);
            if list_len(pool, g_args) >= 2 {
                let fn_arg: i64 = list_get(pool, g_args, 0);
                let mut xp: Vec<i32> = lower_expr(pool, list_get(pool, g_args, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let x_r: i64 = lx_reg(xp);
                let cur: Vec<i32> = lx_blk(xp);
                let h_ip: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(h_ip, 0));
                let h_fm: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(h_fm, 1));
                let mut h_args: Vec<i32> = Vec::new(); h_args.push(h_ip); h_args.push(h_fm);
                let h_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(h_r, "rods_f64_encode", h_args));
                let mut add_args: Vec<i32> = Vec::new(); add_args.push(x_r); add_args.push(h_r);
                let xph: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(xph, "rods_f64_add", add_args));
                let mut sub_args: Vec<i32> = Vec::new(); sub_args.push(x_r); sub_args.push(h_r);
                let xmh: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(xmh, "rods_f64_sub", sub_args));
                let target_fn: str = node_field(pool, fn_arg, 1);
                let mut fp_args: Vec<i32> = Vec::new(); fp_args.push(xph);
                let f_plus: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(f_plus, target_fn, fp_args));
                let mut fm_args: Vec<i32> = Vec::new(); fm_args.push(xmh);
                let f_minus: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(f_minus, target_fn, fm_args));
                let mut diff_args: Vec<i32> = Vec::new(); diff_args.push(f_plus); diff_args.push(f_minus);
                let diff: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(diff, "rods_f64_sub", diff_args));
                let mut twoh_args: Vec<i32> = Vec::new(); twoh_args.push(h_r); twoh_args.push(h_r);
                let two_h: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(two_h, "rods_f64_add", twoh_args));
                let mut div_args: Vec<i32> = Vec::new(); div_args.push(diff); div_args.push(two_h);
                let result: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(result, "rods_f64_div", div_args));
                return lx_new(result, cur);
            };
        };
        let args_list: i64 = node_field(pool, nid, 2);
        let argc: i64 = list_len(pool, args_list);
        let mut arg_regs: Vec<i32> = Vec::new();
        let mut ai: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while ai < argc {
            let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            arg_regs.push(lx_reg(ap));
            cur = lx_blk(ap);
            ai = ai + 1;
        };
        let fn_slot: i64 = sym_get(sym, fn_name);
        if fn_slot >= 0 {
            let fp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_load(fp_r, fn_slot));
            let r: i64 = ctr_next(regs);
            ir_block_add(cur, ir_indirect_call(r, fp_r, arg_regs));
            return lx_new(r, cur);
        };
        let r: i64 = ctr_next(regs);
        // v0.3.126: when fn_name is a registered user fn (its return
        // type is in sym as `__fnret_<name>`), emit a USER call op
        // (31) that bypasses the runtime-helper name lookup. Without
        // this, user fns that share a name with a runtime helper
        // (e.g. user `pow(base, exp)` vs `__nucleor_pow(f64, f64)`)
        // dispatched to the runtime helper — silent miscompute since
        // the int args were treated as f64 bit patterns by the
        // float helper. Adopters writing math/utility wrappers with
        // common names hit this on the very first probe.
        let user_ret: i64 = sym_get(sym, str_concat("__fnret_", fn_name));
        if user_ret >= 0 {
            ir_block_add(cur, ir_user_call(r, fn_name, arg_regs));
        } else {
            ir_block_add(cur, ir_call_ex(r, fn_name, arg_regs));
        };
        return lx_new(r, cur);
    };
    if kind == 8 {
        let mut obj_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(obj_p);
        let mut cur: Vec<i32> = lx_blk(obj_p);
        let mname: str = node_field(pool, nid, 2);
        let args_list: i64 = node_field(pool, nid, 3);
        let argc: i64 = list_len(pool, args_list);
        let mut all_args: Vec<i32> = Vec::new();
        all_args.push(obj_r);
        let mut ai: i64 = 0;
        while ai < argc {
            let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            all_args.push(lx_reg(ap));
            cur = lx_blk(ap);
            ai = ai + 1;
        };
        let stype: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        let mut fn_name: str = "";
        if str_len(stype) > 0 { fn_name = trait_impl_find(trait_impls, stype, mname); };
        if str_len(fn_name) == 0 {
            if str_eq(type_base_name(stype), "Tensor") == 1 {
                fn_name = tensor_builtin_method_name(mname);
            };
            if str_len(fn_name) == 0 {
                // T2.2 (v0.2.348): iterator method dispatch on Vec.
                // `v.map(f)` / `v.filter(p)` / `v.fold(init, f)` etc.
                // route to the typed `vec_*_i64` runtime helpers
                // already wired up in stdlib/runtime/nucleor_llvm_rt.c.
                // Anything else falls through to the existing
                // `vec_<method>` convention.
                if iter_method_for_vec(mname) == 1 {
                    fn_name = str_concat("vec_", str_concat(mname, "_i64"));
                } else {
                    // v0.3.100: receiver-type-aware dispatch for the
                    // collection family (HashMap/HashSet/BTreeMap/
                    // BTreeSet/VecDeque). Pre-v0.3.100 the fallback
                    // was always `vec_<method>`, so a Rust-style
                    // `m.insert(k, v)` on a `HashMap<K,V>` lowered
                    // to `vec_insert(m, k, v)` — undefined symbol at
                    // clang link. The lowercase runtime helpers
                    // (`hashmap_insert`, `hashset_insert`, etc.) all
                    // exist; this is the missing surface-level
                    // dispatch from the `let m: HashMap<...>`
                    // type annotation through `expr_struct_type` to
                    // the right prefix. Falls through to `vec_*` for
                    // unknown receiver types so the existing Vec
                    // method convention still works.
                    let stype_base: str = type_base_name(stype);
                    if str_eq(stype_base, "HashMap") == 1 {
                        fn_name = str_concat("hashmap_", mname);
                    } else if str_eq(stype_base, "HashSet") == 1 {
                        fn_name = str_concat("hashset_", mname);
                    } else if str_eq(stype_base, "BTreeMap") == 1 {
                        fn_name = str_concat("btreemap_", mname);
                    } else if str_eq(stype_base, "BTreeSet") == 1 {
                        fn_name = str_concat("btreeset_", mname);
                    } else if str_eq(stype_base, "VecDeque") == 1 {
                        fn_name = str_concat("vecdeque_", mname);
                    } else {
                        // v0.3.123: user-defined inherent-impl method
                        // dispatch via mangled name. Pre-v0.3.123 the
                        // fallback was always `vec_<method>`, so a
                        // chained inherent fn call like
                        // `Counter::new().add(10).add(5)` lowered the
                        // SECOND `.add(...)` to `vec_add(...)` —
                        // undefined symbol at clang link. The kind-12
                        // path (Counter::new) was fixed in v0.3.111
                        // via the same `__fnret_<mangled>` lookup;
                        // mirror that here for instance-method chains.
                        // Falls through to `vec_<method>` for receiver
                        // types that aren't registered impl methods,
                        // preserving the existing Vec convention.
                        let user_mangled: str = str_concat(stype_base, str_concat("__", mname));
                        let user_ret: i64 = sym_get(sym, str_concat("__fnret_", user_mangled));
                        if user_ret >= 0 {
                            fn_name = user_mangled;
                        } else {
                            fn_name = str_concat("vec_", mname);
                        };
                    };
                };
            };
        };
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(r, fn_name, all_args));
        return lx_new(r, cur);
    };
    if kind == 10 {
        let mut obj_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(obj_p);
        let mut cur: Vec<i32> = lx_blk(obj_p);
        let mut idx_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let idx_r: i64 = lx_reg(idx_p);
        cur = lx_blk(idx_p);
        let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
        let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
        return lx_new(r, cur);
    };
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let mname: str = node_field(pool, nid, 2);
        let args_list: i64 = node_field(pool, nid, 3);
        if str_eq(tname, "Vec") && str_eq(mname, "new") {
            let r: i64 = ctr_next(regs);
            let mut empty_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(r, "vec_new", empty_args));
            return lx_new(r, blk);
        };
        // v0.3.116: `Vec::with_capacity(n)`. Pre-v0.3.116 fell through
        // to the diagnostic+zero path because no kind-12 handler
        // matched. Adopters reaching for the canonical Rust pre-
        // allocation pattern (`Vec::with_capacity(N)` for known-size
        // accumulators) saw their .exe return 0 from the ctor and
        // every push silently fail. The runtime helper
        // `__nucleor_vec_with_capacity` already exists; this is purely
        // the missing surface dispatch. Lower the single arg, then
        // emit a call to the runtime helper.
        if str_eq(tname, "Vec") && str_eq(mname, "with_capacity") {
            let mut wc_cur: Vec<i32> = blk;
            let mut wc_args: Vec<i32> = Vec::new();
            if list_len(pool, args_list) >= 1 {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, 0), wc_cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                wc_args.push(lx_reg(ap));
                wc_cur = lx_blk(ap);
            };
            let r: i64 = ctr_next(regs);
            ir_block_add(wc_cur, ir_call_ex(r, "vec_with_capacity", wc_args));
            return lx_new(r, wc_cur);
        };
        if str_eq(tname, "String") && str_eq(mname, "new") {
            let idx: i64 = vec_len(strtab);
            strtab.push("");
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_str(r, idx));
            return lx_new(r, blk);
        };
        if str_eq(tname, "Box") && str_eq(mname, "new") {
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
            let zr: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(zr, 0));
            return lx_new(zr, blk);
        };
        // v0.3.71: Rust-style associated-fn aliases for the lowercase
        // collection helpers. Maps `HashMap::new()` → `hashmap_new()`,
        // `HashSet::new()` → `hashset_new()`, `BTreeMap::new()` →
        // `btreemap_new()`, `BTreeSet::new()` → `btreeset_new()`,
        // `VecDeque::new()` → `vecdeque_new()`. Without this, users
        // coming from Rust who write `let m: HashMap<K,V> = HashMap::new();`
        // hit "unhandled expr kind 12" with no diagnostic and broken
        // `%r.-1` IR. The runtime helpers themselves (__nucleor_hashmap_new
        // etc.) all exist; this is purely surface-level wiring.
        if str_eq(mname, "new") {
            let mut helper_n: str = "";
            if str_eq(tname, "HashMap") { helper_n = "hashmap_new"; };
            if str_eq(tname, "HashSet") { helper_n = "hashset_new"; };
            if str_eq(tname, "BTreeMap") { helper_n = "btreemap_new"; };
            if str_eq(tname, "BTreeSet") { helper_n = "btreeset_new"; };
            if str_eq(tname, "VecDeque") { helper_n = "vecdeque_new"; };
            if str_len(helper_n) > 0 {
                let r: i64 = ctr_next(regs);
                let mut empty_args: Vec<i32> = Vec::new();
                ir_block_add(blk, ir_call_ex(r, helper_n, empty_args));
                return lx_new(r, blk);
            };
        };
        // v0.3.117: `with_capacity(N)` for the collection family.
        // Pre-v0.3.117 only `Vec::with_capacity` (added in v0.3.116)
        // was wired; HashMap/HashSet/BTreeMap/BTreeSet/VecDeque/String
        // all silently dispatched to the diagnostic+zero path,
        // returning an empty handle that no subsequent insert/push
        // could populate. Runtime helpers `__nucleor_<type>_with_capacity`
        // already exist for each (with v0.3.116 just adding the Vec one).
        if str_eq(mname, "with_capacity") {
            let mut wch: str = "";
            if str_eq(tname, "HashMap") { wch = "hashmap_with_capacity"; };
            if str_eq(tname, "HashSet") { wch = "hashset_with_capacity"; };
            if str_eq(tname, "VecDeque") { wch = "vecdeque_with_capacity"; };
            if str_eq(tname, "String") { wch = "string_with_capacity"; };
            if str_len(wch) > 0 {
                let mut wcc: Vec<i32> = blk;
                let mut wca: Vec<i32> = Vec::new();
                if list_len(pool, args_list) >= 1 {
                    let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, 0), wcc, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    wca.push(lx_reg(ap));
                    wcc = lx_blk(ap);
                };
                let r: i64 = ctr_next(regs);
                ir_block_add(wcc, ir_call_ex(r, wch, wca));
                return lx_new(r, wcc);
            };
        };
        if str_eq(tname, "Tensor") {
            let mut t_args: Vec<i32> = Vec::new();
            let ac: i64 = list_len(pool, args_list);
            let mut ai: i64 = 0;
            let mut cur: Vec<i32> = blk;
            while ai < ac {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                t_args.push(lx_reg(ap));
                cur = lx_blk(ap);
                ai = ai + 1;
            };
            let r: i64 = ctr_next(regs);
            if str_eq(mname, "zeros") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_zeros", t_args)); }
            else if str_eq(mname, "fill") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_fill", t_args)); }
            else if str_eq(mname, "ones") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_ones", t_args)); };
            return lx_new(r, cur);
        };
        let etag_key: str = str_concat("__etag_", str_concat(tname, str_concat("_", mname)));
        let etag: i64 = sym_get(sym, etag_key);
        if etag >= 0 {
            let vr: i64 = ctr_next(regs);
            let mut new_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
            let tr: i64 = ctr_next(regs); ir_block_add(blk, ir_const_int(tr, etag));
            let mut push_args1: Vec<i32> = Vec::new(); push_args1.push(vr); push_args1.push(tr);
            let dr1: i64 = ctr_next(regs); ir_block_add(blk, ir_call_ex(dr1, "vec_push", push_args1));
            let argc: i64 = list_len(pool, args_list);
            let mut ai: i64 = 0;
            let mut cur: Vec<i32> = blk;
            while ai < argc {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let av: i64 = lx_reg(ap);
                cur = lx_blk(ap);
                let mut pa: Vec<i32> = Vec::new(); pa.push(vr); pa.push(av);
                let dp: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dp, "vec_push", pa));
                ai = ai + 1;
            };
            return lx_new(vr, cur);
        };
        // v0.3.111: dispatch user-defined associated fns. The impl
        // block synthesizes each method as `<TypeName>__<methodname>`
        // (mangled name registered in fn_decls / impl_fns at
        // collect_impls time). Pre-v0.3.111, `Point::new(7, 3)`
        // matched none of the built-in Type::method handlers above,
        // skipped the etag enum-variant check (Point isn't an enum),
        // hit the diagnostic, and emitted const_int 0 — silent
        // miscompute returning 0 from any user constructor.
        // Adopters reaching for the canonical `let p = Point::new(...)`
        // pattern saw a printed error but their .exe still ran with
        // wrong values. Lookup `__fnret_<mangled>` to confirm the
        // method exists; if so, lower as a normal i64 fn call with
        // the args (the function takes the args directly, not a
        // self prefix, since this is an associated fn — not an
        // instance method).
        let mangled: str = str_concat(tname, str_concat("__", mname));
        let mret: i64 = sym_get(sym, str_concat("__fnret_", mangled));
        if mret >= 0 {
            let mut maa: Vec<i32> = Vec::new();
            let mac: i64 = list_len(pool, args_list);
            let mut mai: i64 = 0;
            let mut mcur: Vec<i32> = blk;
            while mai < mac {
                let mut mp: Vec<i32> = lower_expr(pool, list_get(pool, args_list, mai), mcur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                maa.push(lx_reg(mp));
                mcur = lx_blk(mp);
                mai = mai + 1;
            };
            let mr: i64 = ctr_next(regs);
            ir_block_add(mcur, ir_call_ex(mr, mangled, maa));
            return lx_new(mr, mcur);
        };
        // v0.3.71: surface a clear diagnostic instead of falling through
        // to the generic "unhandled expr kind 12" + broken `%r.-1` IR.
        // Production-readiness: any unsupported `Type::method(...)` shape
        // now reports the exact type and method that needs wiring.
        print(str_concat("ERROR: unsupported associated-fn call ", str_concat(tname, str_concat("::", str_concat(mname, "(...). Supported: Vec/String/Box/HashMap/HSet/BTMap/BTSet/VecDeque ::new, Tensor::{zeros,fill,ones}, enum variants. For Rust-style HashMap/etc operations, use the lowercase API (hashmap_new, hashmap_insert, ...) until method dispatch lands.")))));
        let zr: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(zr, 0));
        return lx_new(zr, blk);
    };
    if kind == 52 {
        let mode: i64 = node_field(pool, nid, 1);
        let body: i64 = node_field(pool, nid, 2);
        let mut bp: Vec<i32> = lower_if_expr_branch(pool, body, blk, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
        let mut br: i64 = lx_reg(bp);
        let mut cur: Vec<i32> = lx_blk(bp);
        if br < 0 {
            br = ctr_next(regs);
            ir_block_add(cur, ir_const_int(br, 0));
        };
        let mut wrap_args: Vec<i32> = Vec::new();
        wrap_args.push(br);
        let r: i64 = ctr_next(regs);
        if mode == 2 { ir_block_add(cur, ir_call_ex(r, "sat_i32", wrap_args)); }
        else { ir_block_add(cur, ir_call_ex(r, "wrap_i32", wrap_args)); };
        return lx_new(r, cur);
    };
    if kind == 23 {
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        let cur: Vec<i32> = lx_blk(cp);
        let tmp: i64 = ctr_next(regs);
        ir_fn_add_entry_alloca(fir, tmp);
        let tl: i64 = ctr_next(lbls);
        let el: i64 = ctr_next(lbls);
        let ml: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br_cond(cr, tl, el));

        let mut tb: Vec<i32> = ir_block_new(tl);
        ir_fn_add_block(fir, tb);
        let mut tp: Vec<i32> = lower_if_expr_branch(pool, node_field(pool, nid, 2), tb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
        tb = lx_blk(tp);
        let tv: i64 = lx_reg(tp);
        if block_has_term(tb) == 0 {
            let mut store_tv: i64 = tv;
            if store_tv < 0 {
                let tz: i64 = ctr_next(regs);
                ir_block_add(tb, ir_const_int(tz, 0));
                store_tv = tz;
            };
            ir_block_add(tb, ir_store(store_tv, tmp));
            ir_block_add(tb, ir_br(ml));
        };

        let enode: i64 = node_field(pool, nid, 3);
        let mut eb: Vec<i32> = ir_block_new(el);
        ir_fn_add_block(fir, eb);
        if enode >= 0 {
            let mut ep: Vec<i32> = lower_if_expr_branch(pool, enode, eb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
            eb = lx_blk(ep);
            let fv: i64 = lx_reg(ep);
            if block_has_term(eb) == 0 {
                let mut store_fv: i64 = fv;
                if store_fv < 0 {
                    let ez: i64 = ctr_next(regs);
                    ir_block_add(eb, ir_const_int(ez, 0));
                    store_fv = ez;
                };
                ir_block_add(eb, ir_store(store_fv, tmp));
                ir_block_add(eb, ir_br(ml));
            };
        } else {
            let ez: i64 = ctr_next(regs);
            ir_block_add(eb, ir_const_int(ez, 0));
            ir_block_add(eb, ir_store(ez, tmp));
            ir_block_add(eb, ir_br(ml));
        };

        let mut mb: Vec<i32> = ir_block_new(ml);
        ir_fn_add_block(fir, mb);
        let r: i64 = ctr_next(regs);
        ir_block_add(mb, ir_load(r, tmp));
        return lx_new(r, mb);
    };
    if kind == 38 {
        let mut mp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mexpr_r: i64 = lx_reg(mp);
        let mut cur: Vec<i32> = lx_blk(mp);
        let mslot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, mslot);
        ir_block_add(cur, ir_store(mexpr_r, mslot));
        let tmp: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, tmp);
        let arms_list: i64 = node_field(pool, nid, 2);
        let arm_cnt: i64 = list_len(pool, arms_list);
        let ml: i64 = ctr_next(lbls);
        let mut tag_r: i64 = 0 - 1;
        let mut ci: i64 = 0;
        while ci < arm_cnt {
            let arm_nid: i64 = list_get(pool, arms_list, ci);
            let ename: str = node_field(pool, arm_nid, 1);
            let vname: str = node_field(pool, arm_nid, 2);
            let binding: str = node_field(pool, arm_nid, 3);
            let body_list: i64 = node_field(pool, arm_nid, 4);
            let guard_nid: i64 = node_field(pool, arm_nid, 5);
            let al: i64 = ctr_next(lbls);
            let nl: i64 = ctr_next(lbls);
            if str_eq(ename, "__wild") {
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
                    sym_set(arm_sym, binding, bar);
                    let mv: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv, mslot));
                    ir_block_add(ab, ir_store(mv, bar));
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    gb = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(gb) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(gb, ir_const_int(rv, 0)); };
                        ir_block_add(gb, ir_store(rv, tmp));
                        ir_block_add(gb, ir_br(ml));
                    };
                } else {
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    ab = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(ab) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                        ir_block_add(ab, ir_store(rv, tmp));
                        ir_block_add(ab, ir_br(ml));
                    };
                };
            } else if str_eq(ename, "__int") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let iv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(iv_r, vname));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, mv, iv_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
                    sym_set(arm_sym, binding, bar);
                    let mv2: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv2, mslot));
                    ir_block_add(ab, ir_store(mv2, bar));
                };
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else if str_eq(ename, "__range") {
                // RFC-0023 §3.1: range pattern. vname = LO (i64 cell),
                // binding = str_from_int(HI) (inclusive — half-open ranges
                // were normalized at parse). Match if LO <= scrut && scrut
                // <= HI.
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let lo_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(lo_r, vname));
                let hi_n: i64 = str_to_int(binding);
                let hi_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(hi_r, hi_n));
                let lo_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, lo_ok, lo_r, mv));
                let hi_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, hi_ok, mv, hi_r));
                let both_r: i64 = ctr_next(regs); ir_block_add(cur, ir_binop(13, both_r, lo_ok, hi_ok));
                ir_block_add(cur, ir_br_cond(both_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let arm_sym: Vec<i32> = sym_clone(sym);
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else if str_eq(ename, "__range_bad") {
                // MATCH-007 fired by the typecker (paired pass). Lower as
                // never-match so program compiles; warning surfaces in the
                // diagnostic stream.
                ir_block_add(cur, ir_br(nl));
            } else if str_eq(ename, "__str") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let sidx: i64 = vec_len(strtab); strtab.push(vname);
                let sv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_str(sv_r, sidx));
                let mut eq_args: Vec<i32> = Vec::new(); eq_args.push(mv); eq_args.push(sv_r);
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(cmp_r, "str_eq", eq_args));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
                    sym_set(arm_sym, binding, bar);
                    let mv2: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv2, mslot));
                    ir_block_add(ab, ir_store(mv2, bar));
                };
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else {
                if tag_r < 0 {
                    let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                    let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
                    let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(mv); tag_args.push(zero_r);
                    tag_r = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
                };
                let etag_key: str = str_concat("__etag_", str_concat(ename, str_concat("_", vname)));
                let vtag: i64 = sym_get(sym, etag_key);
                let vtag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(vtag_r, vtag));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, vtag_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_payloads(binding, ab, regs, arm_sym, mslot, fir);
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            };
            let mut nb: Vec<i32> = ir_block_new(nl); ir_fn_add_block(fir, nb);
            cur = nb;
            ci = ci + 1;
        };
        ir_block_add(cur, ir_br(ml));
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb);
        let r: i64 = ctr_next(regs);
        ir_block_add(mb, ir_load(r, tmp));
        return lx_new(r, mb);
    };
    if kind == 47 || kind == 48 {
        let items_list: i64 = node_field(pool, nid, 1);
        let vr: i64 = ctr_next(regs);
        let mut new_args: Vec<i32> = Vec::new();
        ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
        let ic: i64 = list_len(pool, items_list);
        let mut ii: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while ii < ic {
            let mut ep: Vec<i32> = lower_expr(pool, list_get(pool, items_list, ii), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let ev: i64 = lx_reg(ep);
            cur = lx_blk(ep);
            let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(ev);
            let dr: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dr, "vec_push", push_args));
            ii = ii + 1;
        };
        return lx_new(vr, cur);
    };
    if kind == 34 {
        let sname: str = node_field(pool, nid, 1);
        let init_list: i64 = node_field(pool, nid, 2);
        let si: i64 = struct_find_type(pool, structs, sname);
        if si < 0 {
            print(str_concat("ERROR: unknown struct ", sname));
            return lx_new(0 - 1, blk);
        };
        let s_nid: i64 = vec_get(structs, si);
        let flist: i64 = node_field(pool, s_nid, 2);
        let fc: i64 = list_len(pool, flist);
        let vr: i64 = ctr_next(regs);
        let mut new_args: Vec<i32> = Vec::new();
        ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
        let mut fi: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while fi < fc {
            let decl_fname: str = node_field(pool, list_get(pool, flist, fi), 1);
            let ic: i64 = list_len(pool, init_list);
            let mut ii: i64 = 0;
            let mut found: i64 = 0;
            while ii < ic {
                let init_nid: i64 = list_get(pool, init_list, ii);
                if str_eq(node_field(pool, init_nid, 1), decl_fname) {
                    let mut vp: Vec<i32> = lower_expr(pool, node_field(pool, init_nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let val_r: i64 = lx_reg(vp);
                    cur = lx_blk(vp);
                    let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(val_r);
                    let pr2: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pr2, "vec_push", push_args));
                    found = 1; ii = ic;
                };
                ii = ii + 1;
            };
            if found == 0 {
                let zr: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zr, 0));
                let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(zr);
                let pr2: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pr2, "vec_push", push_args));
            };
            fi = fi + 1;
        };
        return lx_new(vr, cur);
    };
    if kind == 9 {
        let mut op: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(op);
        let cur: Vec<i32> = lx_blk(op);
        let fname: str = node_field(pool, nid, 2);
        if str_is_digits(fname) == 1 {
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, str_to_int(fname)));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
            let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
            return lx_new(r, cur);
        };
        let stype: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        let si: i64 = struct_find_type(pool, structs, stype);
        if si >= 0 {
            let fi2: i64 = struct_field_idx(pool, vec_get(structs, si), fname);
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, fi2));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
            let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
            return lx_new(r, cur);
        };
        print(str_concat("ERROR: cannot resolve field access type for .", fname));
        return lx_new(0 - 1, cur);
    };
    if kind == 42 {
        let param_list: i64 = node_field(pool, nid, 1);
        let body_list: i64 = node_field(pool, nid, 2);
        let clo_idx: i64 = vec_len(closures);
        let clo_name: str = str_concat("__closure_", str_from_int(clo_idx));
        let pc: i64 = list_len(pool, param_list);
        let mut clo_regs: Vec<i32> = ctr_new();
        let mut clo_lbls: Vec<i32> = ctr_new();
        let mut clo_sym: Vec<i32> = sym_new();
        let mut clo_fir: Vec<i32> = ir_fn_new(clo_name, pc);
        let mut clo_b0: Vec<i32> = ir_block_new(0);
        ir_fn_add_block(clo_fir, clo_b0);
        let mut captures: Vec<i32> = Vec::new();
        let bc: i64 = list_len(pool, body_list);
        let mut bi: i64 = 0;
        while bi < bc {
            closure_collect_capture_stmt(pool, list_get(pool, body_list, bi), sym, param_list, captures);
            bi = bi + 1;
        };
        let mut cpi: i64 = 0;
        while cpi < pc {
            let cpname: str = list_get(pool, param_list, cpi);
            let car: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_alloca(car));
            let cpr: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_param_ref(cpr, cpi));
            ir_block_add(clo_b0, ir_store(cpr, car));
            sym_set(clo_sym, cpname, car);
            cpi = cpi + 1;
        };
        let mut capi: i64 = 0;
        while capi < vec_len(captures) {
            let capname: str = vec_get(captures, capi);
            let car: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_alloca(car));
            let clo_id_r: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_const_int(clo_id_r, clo_idx));
            let cap_id_r: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_const_int(cap_id_r, capi));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(clo_id_r); get_args.push(cap_id_r);
            let cval: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_call_ex(cval, "__nucleor_capture_get", get_args));
            ir_block_add(clo_b0, ir_store(cval, car));
            sym_set(clo_sym, capname, car);
            // v0.3.129: propagate the captured variable's TYPE entry
            // from the parent sym so expr_struct_type can resolve
            // field accesses inside the closure body. Pre-v0.3.129
            // the closure's clo_sym had the captured slot but no
            // `__type_<capname>` entry — `cfg.factor` (where cfg was
            // captured) failed to resolve to a struct field, lowered
            // to register -1, and clang link errored with
            // `use of undefined value '%r.-1'`. Without this entry
            // adopters couldn't access fields of any captured struct
            // inside a closure (very common pattern: closure
            // capturing a config / context struct).
            let parent_type: i64 = sym_get(sym, str_concat("__type_", capname));
            if parent_type >= 0 {
                sym_set(clo_sym, str_concat("__type_", capname), parent_type);
            };
            let parent_full: i64 = sym_get(sym, str_concat("__fulltype_", capname));
            if parent_full >= 0 {
                sym_set(clo_sym, str_concat("__fulltype_", capname), parent_full);
            };
            capi = capi + 1;
        };
        // v0.3.107: push the closure into `closures` BEFORE lowering
        // its body. Pre-v0.3.107 the push happened AFTER body lowering,
        // so nested closures (a closure inside another closure's body)
        // queried `vec_len(closures)` at line 10541 and saw the same
        // count as the outer closure — both got `__closure_0`, which
        // hard-failed at clang link with `invalid redefinition of
        // function '__closure_0'`. Pushing first reserves the slot
        // for clo_idx (already allocated above) so nested closures
        // get the next id (1, 2, …). Safe because clo_fir is a Vec
        // reference and lower_stmts mutates it in place — the
        // closures list holds the same pointer either way.
        closures.push(clo_fir);
        let mut clo_fb: Vec<i32> = lower_stmts(pool, body_list, clo_b0, clo_regs, clo_lbls, clo_sym, clo_fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        if block_has_term(clo_fb) == 0 {
            let czr: i64 = ctr_next(clo_regs);
            ir_block_add(clo_fb, ir_const_int(czr, 0));
            ir_block_add(clo_fb, ir_ret(czr));
        };
        let mut capi2: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while capi2 < vec_len(captures) {
            let capname2: str = vec_get(captures, capi2);
            let capslot: i64 = sym_get(sym, capname2);
            if capslot >= 0 {
                let capv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(capv, capslot));
                let clo_id_r2: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(clo_id_r2, clo_idx));
                let cap_id_r2: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(cap_id_r2, capi2));
                let mut set_args: Vec<i32> = Vec::new(); set_args.push(clo_id_r2); set_args.push(cap_id_r2); set_args.push(capv);
                let dr: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dr, "__nucleor_capture_set", set_args));
            };
            capi2 = capi2 + 1;
        };
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_fn_ptr(r, clo_name));
        return lx_new(r, cur);
    };
    print(str_concat("ERROR: unhandled expr kind ", str_from_int(kind)));
    return lx_new(0 - 1, blk);
}
// T1.1 Phase 5: detect whether an AST expression node has a known
// float type (f32 or f64), looking through variable reads (kind==3)
// and float literals (kind==71). Returns "f32"/"f64"/"" .
// v0.3.54 helper: populate sym with `__fnret_NAME = rtype` entries
// for every fn declared in pool. Walks the entire pool once,
// skipping non-fn nodes. Called from lower_fn at the start of each
// fn body so binop_float_type's kind==7 (call) branch can look up
// the called fn's return type via the existing sym mechanism — no
// signature plumbing required.
//
// Pool walk caveat: pool nodes form a flat arena. Fn decls are
// kind 30 (regular) and kind 32 (extern). The walk uses node_kind
// at every offset and bails early once we run off the end (handled
// by node_kind returning -1 / 0 for invalid offsets in the arena).
fn populate_fn_returns_in_sym(pool: Vec<i32>, fn_decls: Vec<i32>, sym: Vec<i32>) -> i64 {
    let n: i64 = vec_len(fn_decls);
    let mut i: i64 = 0;
    while i < n {
        let fnid: i64 = vec_get(fn_decls, i);
        let name: str = node_field(pool, fnid, 1);
        let raw_rtype: str = node_field(pool, fnid, 3);
        let rtype: str = type_base_name(raw_rtype);
        if str_len(name) > 0 && str_len(rtype) > 0 {
            sym_set(sym, str_concat("__fnret_", name), rtype);
        };
        // v0.3.67: also store the FULL declared return type
        // (preserving generics like Vec<f64>) so kind==10 dispatch
        // can extract the element type when an indexer's operand is
        // a kind 7 (fn call). Mirrors __fulltype_ for variables.
        if str_len(name) > 0 && str_len(raw_rtype) > 0 {
            sym_set(sym, str_concat("__fnfulltype_", name), raw_rtype);
        };
        i = i + 1;
    };
    return 0;
}

// v0.3.68 helper: strip ONE container layer from a type
// annotation, returning the inner element type WITH generics
// preserved. Used by the kind==10 dispatchers to resolve nested
// indexing chains (`grid[i][j]` where grid: Vec<Vec<f64>>).
//   "Vec<f64>"          → "f64"
//   "Vec<Vec<f64>>"     → "Vec<f64>"
//   "[f64; 3]"          → "f64"
//   "[Vec<f64>; 4]"     → "Vec<f64>"
// Returns "" for non-container shapes.
fn strip_container_one_level(t: str) -> str {
    let tlen: i64 = str_len(t);
    if str_starts_with(t, "Vec<") == 1 && tlen > 5 && str_char_at(t, tlen - 1) == 62 {
        return str_substring(t, 4, tlen - 1);
    };
    if tlen > 1 && str_char_at(t, 0) == 91 {
        let mut sep: i64 = 0 - 1;
        let mut k: i64 = 1;
        while k < tlen {
            let ch: i64 = str_char_at(t, k);
            if ch == 59 || ch == 44 { sep = k; k = tlen; }
            else { k = k + 1; };
        };
        if sep > 1 {
            return strip_spaces(str_substring(t, 1, sep));
        };
    };
    return "";
}

// v0.3.68 helper: recursively walk an indexable expression and
// return the FULL type of its element (with generics preserved).
// Composes the v0.3.55/65/66/67 operand-kind handlers — kind 3
// (var ref), kind 9 (struct field), kind 7 (fn-call), and now
// kind 10 (nested indexing) — and strips one container layer.
//
// Returns "" if the operand kind isn't recognized or the type
// isn't a container shape.
fn indexed_element_full_type(pool: Vec<i32>, vexpr: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let vk: i64 = node_kind(pool, vexpr);
    let mut vtype: str = "";
    if vk == 3 {
        let vname: str = node_field(pool, vexpr, 1);
        let vt: i64 = sym_get(sym, str_concat("__fulltype_", vname));
        if vt >= 0 { vtype = vt; };
    };
    if vk == 9 {
        let parent_type: str = expr_struct_type(pool, node_field(pool, vexpr, 1), sym, structs);
        if str_len(parent_type) > 0 {
            let si: i64 = struct_find_type(pool, structs, parent_type);
            if si >= 0 {
                vtype = struct_field_type(pool, vec_get(structs, si), node_field(pool, vexpr, 2));
            };
        };
    };
    if vk == 7 {
        let fn_name: str = node_field(pool, vexpr, 1);
        let ft: i64 = sym_get(sym, str_concat("__fnfulltype_", fn_name));
        if ft >= 0 { vtype = ft; };
    };
    // v0.3.74: trait-method-call (kind 8) indexed operand. Mirrors
    // the kind==7 lookup but with the trait-impl mangled name
    // (`<TYPE>__<METHOD>`) — so `s.samples()[i]` where samples
    // returns Vec<f64> resolves correctly to f64 element type.
    // Pre-v0.3.74, this fell through to "" and the outer binop
    // dispatched to integer add on packed-double bit patterns.
    if vk == 8 {
        let recv_nid: i64 = node_field(pool, vexpr, 1);
        let mname: str = node_field(pool, vexpr, 2);
        let rtype: str = expr_struct_type(pool, recv_nid, sym, structs);
        if str_len(rtype) > 0 {
            let mangled: str = str_concat(rtype, str_concat("__", mname));
            let ft: i64 = sym_get(sym, str_concat("__fnfulltype_", mangled));
            if ft >= 0 { vtype = ft; };
        };
    };
    if vk == 10 {
        // Nested indexing — recurse to get inner expr's element type,
        // which is itself a container. The outer indexing strips
        // one MORE level below.
        vtype = indexed_element_full_type(pool, node_field(pool, vexpr, 1), sym, structs);
    };
    if str_len(vtype) == 0 { return ""; };
    return strip_container_one_level(vtype);
}

fn binop_float_type(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let vname: str = node_field(pool, nid, 1);
        let tstr: i64 = sym_get(sym, str_concat("__type_", vname));
        if tstr < 0 { return ""; };
        if str_eq(tstr, "f32") == 1 { return "f32"; };
        if str_eq(tstr, "f64") == 1 { return "f64"; };
        return "";
    };
    if kind == 71 { return "f64"; };
    if kind == 72 { return "f64"; };
    // v0.3.53 fix: struct field access. Pre-v0.3.53 this fell
    // through to "" → integer binop, mis-computing inline
    // f64 ops on struct-field operands (`a.x * b.x` etc).
    // Look up the struct via expr_struct_type → struct_field_type.
    if kind == 9 {
        let outer_type: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(outer_type) == 0 { return ""; };
        let si: i64 = struct_find_type(pool, structs, outer_type);
        if si >= 0 {
            let ftype: str = type_base_name(struct_field_type(pool, vec_get(structs, si), node_field(pool, nid, 2)));
            if str_eq(ftype, "f32") == 1 { return "f32"; };
            if str_eq(ftype, "f64") == 1 { return "f64"; };
        };
        return "";
    };
    // v0.3.53 fix: nested binop. For `(a.x*b.x) + (a.y*b.y)`,
    // the outer + has binop operands. Recurse into each operand's
    // own binop type — f32 wins precedence, then f64 (matches the
    // outer dispatch rule). Without this, the + fell through to
    // integer add even though both halves were correctly compiled
    // as f64 muls.
    if kind == 4 {
        let lt: str = binop_float_type(pool, node_field(pool, nid, 2), sym, structs);
        let rt: str = binop_float_type(pool, node_field(pool, nid, 3), sym, structs);
        if str_eq(lt, "f32") == 1 { return "f32"; };
        if str_eq(rt, "f32") == 1 { return "f32"; };
        if str_eq(lt, "f64") == 1 { return "f64"; };
        if str_eq(rt, "f64") == 1 { return "f64"; };
        return "";
    };
    // v0.3.53 fix: parenthesized expression / cast / borrow
    // wrappers preserve the inner type. Mirror the precedence
    // chain that expr_struct_type already handles.
    if kind == 90 || kind == 91 || kind == 92 {
        return binop_float_type(pool, node_field(pool, nid, 1), sym, structs);
    };
    // v0.3.54 fix: function call. Look up the called fn's return
    // type via the `__fnret_<NAME>` sym entry (populated by
    // populate_fn_returns_in_sym at lower_fn entry). Without this,
    // `make_one() + make_four()` (both returning f64) silently
    // fell through to integer add and miscomputed.
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        let rt: i64 = sym_get(sym, str_concat("__fnret_", fn_name));
        if rt < 0 { return ""; };
        if str_eq(rt, "f32") == 1 { return "f32"; };
        if str_eq(rt, "f64") == 1 { return "f64"; };
        return "";
    };
    // v0.3.61 fix: as-cast (`x as f64` is AST kind 99). The
    // target type is stored directly on the cast node (field 2).
    // Pre-v0.3.61: `(make_int() as f64) + (make_int() as f64)`
    // miscomputed because both operands were casts and neither
    // triggered the existing literal/var f-typed paths. Fix:
    // strip type_base_name in case the target carries generic
    // decorations, then return f32/f64 if matched.
    if kind == 99 {
        let target_type: str = type_base_name(node_field(pool, nid, 2));
        if str_eq(target_type, "f32") == 1 { return "f32"; };
        if str_eq(target_type, "f64") == 1 { return "f64"; };
        return "";
    };
    // v0.3.60 fix: trait method call (`obj.method(args)` is
    // AST kind 8). Real production case: trait method results
    // used inline in binops (`r1.area() + r2.area()`) miscompiled
    // because kind 8 wasn't in the enumeration. Resolve receiver
    // type via expr_struct_type, construct the trait_impl mangled
    // name (`<TYPE>__<METHOD>`), look up __fnret_<MANGLED>. The
    // mangling matches what compile_one's pass-1.5 (collect_impls
    // at line 11144) generates for trait methods.
    if kind == 8 {
        let recv_nid: i64 = node_field(pool, nid, 1);
        let mname: str = node_field(pool, nid, 2);
        let rtype: str = expr_struct_type(pool, recv_nid, sym, structs);
        if str_len(rtype) == 0 { return ""; };
        let mangled: str = str_concat(rtype, str_concat("__", mname));
        let rt: i64 = sym_get(sym, str_concat("__fnret_", mangled));
        if rt < 0 { return ""; };
        if str_eq(rt, "f32") == 1 { return "f32"; };
        if str_eq(rt, "f64") == 1 { return "f64"; };
        return "";
    };
    // v0.3.55 fix: Vec indexing (`v[i]` is AST kind 10).
    // Extract the element type from the variable's full declared
    // type (Vec<f64>) via the __fulltype_ sym entry. The existing
    // __type_ sym entry only stores the base name ("Vec") because
    // type_base_name strips generics; v0.3.55 added a parallel
    // __fulltype_ entry that preserves the generic so the kind==10
    // dispatcher can extract the element type.
    //
    // v0.3.62 extension: also handles fixed-size arrays
    // `[T; N]` (parsed identically to indexing). Production code
    // uses fixed arrays for state vectors / sensor batches with
    // known length.
    if kind == 10 {
        // v0.3.68: refactored to use indexed_element_full_type
        // which composes all four operand kinds (3, 9, 7, 10) and
        // strips one container layer per level. The element type
        // returned has generics preserved; type_base_name strips
        // the outer wrapper for the f-typed primitive check.
        let elem_full: str = indexed_element_full_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(elem_full) == 0 { return ""; };
        let elem_base: str = type_base_name(elem_full);
        if str_eq(elem_base, "f32") == 1 { return "f32"; };
        if str_eq(elem_base, "f64") == 1 { return "f64"; };
        return "";
    };
    return "";
}

// T1.1 Phase 5: map a binop token (via tok_to_ir) and a float type
// to the corresponding runtime helper name. Returns "" if the op
// isn't a float-supported binop or the type isn't float.
//
// Supported ops (iop values from tok_to_ir):
//   2  + → f<T>_add        7  == → f<T>_eq
//   3  - → f<T>_sub        8  != → f<T>_ne
//   4  * → f<T>_mul        9  <  → f<T>_lt
//   5  / → f<T>_div       10  >  → f<T>_gt
//                         11  <= → f<T>_le
//                         12  >= → f<T>_ge
fn float_binop_helper(iop: i64, ftype: str) -> str {
    if str_len(ftype) == 0 { return ""; };
    let mut suffix: str = "";
    if iop == 2 { suffix = "add"; };
    if iop == 3 { suffix = "sub"; };
    if iop == 4 { suffix = "mul"; };
    if iop == 5 { suffix = "div"; };
    if iop == 7 { suffix = "eq"; };
    if iop == 8 { suffix = "ne"; };
    if iop == 9 { suffix = "lt"; };
    if iop == 10 { suffix = "gt"; };
    if iop == 11 { suffix = "le"; };
    if iop == 12 { suffix = "ge"; };
    if str_len(suffix) == 0 { return ""; };
    if str_eq(ftype, "f32") == 1 { return str_concat("f32_", suffix); };
    if str_eq(ftype, "f64") == 1 { return str_concat("f64_", suffix); };
    return "";
}

// T1.1 Phase 1+2+3c+5: if `tstr` is a narrow numeric type, insert a
// runtime `__nucleor_as_<T>` cast so the stored value is width-
// correct (e.g. u8 wraps mod 256, i32 truncates from i64, f32
// narrows from f64). Returns the new register holding the narrowed
// value, or `vr` unchanged otherwise.
//
// `src_kind` is the AST kind of the init expression. For f32
// narrowing we ONLY narrow when the source is a f64 literal
// (kind == 71). If the source is already a float expression
// (e.g. result of f32 binop, another f32 variable), a second
// narrowing would corrupt the already-narrow bit-pattern. This
// guard is specific to float types; integer narrowing is always
// safe to apply.
//
// Phase 3c stdlib audit complete: i32/u32 narrowing is safe.
fn narrow_via_as(blk: Vec<i32>, regs: Vec<i32>, vr: i64, tstr: str, src_kind: i64) -> i64 {
    // Defensive: a negative source register means upstream lowering failed.
    // Return it unchanged so the bad register propagates to a visible
    // diagnostic rather than getting silently wrapped in an as-cast.
    if vr < 0 { return vr; };
    if str_len(tstr) == 0 { return vr; };
    let mut helper: str = "";
    if str_eq(tstr, "i8") == 1 { helper = "as_i8"; };
    if str_eq(tstr, "i16") == 1 { helper = "as_i16"; };
    if str_eq(tstr, "i32") == 1 { helper = "as_i32"; };
    if str_eq(tstr, "u8") == 1 { helper = "as_u8"; };
    if str_eq(tstr, "u16") == 1 { helper = "as_u16"; };
    if str_eq(tstr, "u32") == 1 { helper = "as_u32"; };
    // f32 narrowing per source kind: literals get the right converter,
    // already-narrow values are left alone (avoid double-conversion).
    if str_eq(tstr, "f32") == 1 && src_kind == 71 { helper = "as_f32"; };       // f64 literal
    if str_eq(tstr, "f32") == 1 && src_kind == 1 { helper = "i64_to_f32"; };    // int literal
    // f64 from int literal: needs i64→f64 conversion (literals are
    // stored as raw i64 bit pattern, not as scaled-f64).
    if str_eq(tstr, "f64") == 1 && src_kind == 1 { helper = "i64_to_f64"; };
    if str_len(helper) == 0 { return vr; };
    let mut conv_args: Vec<i32> = Vec::new();
    conv_args.push(vr);
    let r: i64 = ctr_next(regs);
    ir_block_add(blk, ir_call_ex(r, helper, conv_args));
    return r;
}

fn lower_stmt(pool: Vec<i32>, nid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let kind: i64 = node_kind(pool, nid);
    if kind == 20 {
        // v0.3.76: shadowing fix. Pre-v0.3.76, this lowering bound the
        // new slot (sym_set) BEFORE lowering the RHS, so a shadowing
        // statement like `let x: i64 = x + 5;` resolved the inner `x`
        // to the new (uninitialized) slot and produced garbage.
        // Fix: allocate the new slot upfront, but bind sym entries
        // AFTER lowering the RHS expression so the RHS sees the OLD
        // shadowed binding (Rust shadowing semantics — the new binding
        // takes effect on the next statement, not within its own RHS).
        let ar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, ar);
        let vname: str = node_field(pool, nid, 1);
        let init: i64 = node_field(pool, nid, 4);
        let mut tstr: str = node_field(pool, nid, 3);
        if str_len(tstr) == 0 && init >= 0 {
            let ik: i64 = node_kind(pool, init);
            if ik == 34 { tstr = node_field(pool, init, 1); }
            else if ik == 12 { tstr = node_field(pool, init, 1); };
        };
        let sbase: str = type_base_name(tstr);
        if init >= 0 {
            // Lower RHS BEFORE rebinding sym so any reference to `vname`
            // inside the RHS resolves to the OUTER (shadowed) slot.
            let src_kind: i64 = node_kind(pool, init);
            let mut vp: Vec<i32> = lower_expr(pool, init, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            cur = lx_blk(vp);
            let vr: i64 = lx_reg(vp);
            let nvr: i64 = narrow_via_as(cur, regs, vr, sbase, src_kind);
            ir_block_add(cur, ir_store(nvr, ar));
        };
        // Bind sym entries AFTER the RHS is lowered.
        sym_set(sym, vname, ar);
        if str_len(sbase) > 0 { sym_set(sym, str_concat("__type_", vname), sbase); };
        // v0.3.55: also store the FULL declared type (with generics
        // like Vec<f64>) so binop_float_type can extract Vec<T>'s
        // element type for kind==10 (indexing) dispatch. type_base_name
        // strips the <T> for the existing __type_ entry.
        if str_len(tstr) > 0 { sym_set(sym, str_concat("__fulltype_", vname), tstr); };
        return cur;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let lhs_kind: i64 = node_kind(pool, lhs);
        // v0.3.81 safety net: assignment LHS shapes that lower_stmt
        // can't lower must short-circuit so we don't fall through to
        // the var-ref code path (which interprets node-id as string
        // offset and segfaults). Diagnostic was already emitted by
        // check_stmt; lower_stmt just needs to skip codegen.
        // v0.3.124: real `v[i] = X` indexed-LHS lowering. Pre-v0.3.124
        // the kind-10 LHS shape silently dropped the assignment AND
        // its diag was informational (build still produced a .exe with
        // wrong values — the read-back of v[i] returned the original
        // value instead of the assigned X). Adopters writing
        // `v[i] = …` (a basic Rust pattern) saw silent miscomputes.
        // Fix: lower the receiver expr, the index expr, and the value
        // expr; emit `vec_set(v, i, X)`. The runtime helper exists.
        if lhs_kind == 10 {
            let mut recv_p: Vec<i32> = lower_expr(pool, node_field(pool, lhs, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let recv_r: i64 = lx_reg(recv_p);
            cur = lx_blk(recv_p);
            let mut idx_p: Vec<i32> = lower_expr(pool, node_field(pool, lhs, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let idx_r: i64 = lx_reg(idx_p);
            cur = lx_blk(idx_p);
            let mut val_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let val_r: i64 = lx_reg(val_p);
            cur = lx_blk(val_p);
            let mut set_args: Vec<i32> = Vec::new();
            set_args.push(recv_r);
            set_args.push(idx_r);
            set_args.push(val_r);
            let sr: i64 = ctr_next(regs);
            ir_block_add(cur, ir_call_ex(sr, "vec_set", set_args));
            return cur;
        };
        if lhs_kind != 3 && lhs_kind != 9 {
            return cur;
        };
        // v0.3.80 safety net: nested field assignment (e.g.
        // `o.inner.val = X`) was crashing the compiler with a
        // segfault during the kind 21 / kind 9 lowering interaction.
        // The actual feature (deep field-path mutation) requires a
        // get-modify-set lowering that is multi-cycle to implement
        // correctly — copying the inner struct, mutating the copy,
        // and writing it back. Until that ships, emit a clear
        // diagnostic with the workaround so users don't hit the
        // segfault.
        if lhs_kind == 9 {
            let parent_kind: i64 = node_kind(pool, node_field(pool, lhs, 1));
            if parent_kind == 9 {
                print("ERROR: nested struct field assignment is not yet supported (e.g. `outer.inner.field = X`). Workaround: copy the inner struct to a local, mutate the local, then assign it back: `let mut tmp = outer.inner; tmp.field = X; outer.inner = tmp;`. Tracked for a future ship — get-modify-set lowering needed.");
                return cur;
            };
        };
        if lhs_kind == 9 {
            let mut op: Vec<i32> = lower_expr(pool, node_field(pool, lhs, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let obj_r: i64 = lx_reg(op);
            cur = lx_blk(op);
            let fname: str = node_field(pool, lhs, 2);
            let mut vp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let vr: i64 = lx_reg(vp);
            cur = lx_blk(vp);
            let stype: str = expr_struct_type(pool, node_field(pool, lhs, 1), sym, structs);
            let si: i64 = struct_find_type(pool, structs, stype);
            if si >= 0 {
                let fi2: i64 = struct_field_idx(pool, vec_get(structs, si), fname);
                let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, fi2));
                let mut set_args: Vec<i32> = Vec::new(); set_args.push(obj_r); set_args.push(idx_r); set_args.push(vr);
                let dr: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dr, "vec_set", set_args));
            };
            return cur;
        };
        let ar: i64 = sym_get(sym, node_field(pool, lhs, 1));
        let mut vp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let vr: i64 = lx_reg(vp);
        cur = lx_blk(vp);
        ir_block_add(cur, ir_store(vr, ar));
        return cur;
    };
    if kind == 22 {
        let vn: i64 = node_field(pool, nid, 1);
        if vn >= 0 {
            let mut vp: Vec<i32> = lower_expr(pool, vn, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let vr: i64 = lx_reg(vp);
            cur = lx_blk(vp);
            ir_block_add(cur, ir_ret(vr));
        } else {
            let zr: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zr, 0)); ir_block_add(cur, ir_ret(zr));
        };
        return cur;
    };
    if kind == 23 {
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        cur = lx_blk(cp);
        let tl: i64 = ctr_next(lbls); let el: i64 = ctr_next(lbls); let ml: i64 = ctr_next(lbls);
        let enode: i64 = node_field(pool, nid, 3);
        if enode < 0 { ir_block_add(cur, ir_br_cond(cr, tl, ml)); }
        else { ir_block_add(cur, ir_br_cond(cr, tl, el)); };
        let mut tb: Vec<i32> = ir_block_new(tl); ir_fn_add_block(fir, tb);
        tb = lower_stmts(pool, node_field(pool, nid, 2), tb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
        if block_has_term(tb) == 0 { ir_block_add(tb, ir_br(ml)); };
        if enode >= 0 {
            let mut eb: Vec<i32> = ir_block_new(el); ir_fn_add_block(fir, eb);
            eb = lower_stmts(pool, enode, eb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
            if block_has_term(eb) == 0 { ir_block_add(eb, ir_br(ml)); };
        };
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb); return mb;
    };
    if kind == 24 {
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), hb, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        hb = lx_blk(cp);
        ir_block_add(hb, ir_br_cond(cr, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        bb = lower_stmts(pool, node_field(pool, nid, 2), bb, regs, lbls, sym_clone(sym), fir, strtab, hl, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 { ir_block_add(bb, ir_br(hl)); };
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 28 {
        let name: str = node_field(pool, nid, 1);
        let ar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, ar);
        let mut loop_sym: Vec<i32> = sym_clone(sym);
        sym_set(loop_sym, name, ar);
        let mut sp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let sv: i64 = lx_reg(sp);
        cur = lx_blk(sp);
        ir_block_add(cur, ir_store(sv, ar));
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls);
        let il: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        let lv: i64 = ctr_next(regs); ir_block_add(hb, ir_load(lv, ar));
        let mut ep: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), hb, regs, lbls, loop_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let ev: i64 = lx_reg(ep);
        hb = lx_blk(ep);
        let cv: i64 = ctr_next(regs); ir_block_add(hb, ir_cmpop(9, cv, lv, ev));
        ir_block_add(hb, ir_br_cond(cv, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        bb = lower_stmts(pool, node_field(pool, nid, 4), bb, regs, lbls, sym_clone(loop_sym), fir, strtab, il, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 { ir_block_add(bb, ir_br(il)); };
        let mut ib: Vec<i32> = ir_block_new(il); ir_fn_add_block(fir, ib);
        let lv2: i64 = ctr_next(regs); ir_block_add(ib, ir_load(lv2, ar));
        let one: i64 = ctr_next(regs); ir_block_add(ib, ir_const_int(one, 1));
        let nv: i64 = ctr_next(regs); ir_block_add(ib, ir_binop(2, nv, lv2, one));
        ir_block_add(ib, ir_store(nv, ar));
        ir_block_add(ib, ir_br(hl));
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 49 {
        let name: str = node_field(pool, nid, 1);
        let item_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, item_slot);
        let iter_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, iter_slot);
        let idx_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, idx_slot);
        let mut loop_sym: Vec<i32> = sym_clone(sym);
        sym_set(loop_sym, name, item_slot);
        let mut sp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let sv: i64 = lx_reg(sp);
        cur = lx_blk(sp);
        ir_block_add(cur, ir_store(sv, iter_slot));
        let zero: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero, 0));
        ir_block_add(cur, ir_store(zero, idx_slot));
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls);
        let il: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        let idx_v: i64 = ctr_next(regs); ir_block_add(hb, ir_load(idx_v, idx_slot));
        let iter_v: i64 = ctr_next(regs); ir_block_add(hb, ir_load(iter_v, iter_slot));
        let mut len_args: Vec<i32> = Vec::new(); len_args.push(iter_v);
        let len_v: i64 = ctr_next(regs); ir_block_add(hb, ir_call_ex(len_v, "vec_len", len_args));
        let cv: i64 = ctr_next(regs); ir_block_add(hb, ir_cmpop(9, cv, idx_v, len_v));
        ir_block_add(hb, ir_br_cond(cv, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        let iter_v2: i64 = ctr_next(regs); ir_block_add(bb, ir_load(iter_v2, iter_slot));
        let idx_v2: i64 = ctr_next(regs); ir_block_add(bb, ir_load(idx_v2, idx_slot));
        let mut get_args: Vec<i32> = Vec::new(); get_args.push(iter_v2); get_args.push(idx_v2);
        let item_v: i64 = ctr_next(regs); ir_block_add(bb, ir_call_ex(item_v, "vec_get", get_args));
        ir_block_add(bb, ir_store(item_v, item_slot));
        bb = lower_stmts(pool, node_field(pool, nid, 3), bb, regs, lbls, sym_clone(loop_sym), fir, strtab, il, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 { ir_block_add(bb, ir_br(il)); };
        let mut ib: Vec<i32> = ir_block_new(il); ir_fn_add_block(fir, ib);
        let idx_v3: i64 = ctr_next(regs); ir_block_add(ib, ir_load(idx_v3, idx_slot));
        let one: i64 = ctr_next(regs); ir_block_add(ib, ir_const_int(one, 1));
        let next_v: i64 = ctr_next(regs); ir_block_add(ib, ir_binop(2, next_v, idx_v3, one));
        ir_block_add(ib, ir_store(next_v, idx_slot));
        ir_block_add(ib, ir_br(hl));
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 25 {
        let mut ep: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        return lx_blk(ep);
    };
    if kind == 38 {
        let mut mp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mexpr_r: i64 = lx_reg(mp);
        cur = lx_blk(mp);
        let mslot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, mslot);
        ir_block_add(cur, ir_store(mexpr_r, mslot));
        let arms_list: i64 = node_field(pool, nid, 2);
        let arm_cnt: i64 = list_len(pool, arms_list);
        let ml: i64 = ctr_next(lbls);
        let mut tag_r: i64 = 0 - 1;
        let mut ci: i64 = 0;
        while ci < arm_cnt {
            let arm_nid: i64 = list_get(pool, arms_list, ci);
            let ename: str = node_field(pool, arm_nid, 1);
            let vname: str = node_field(pool, arm_nid, 2);
            let binding: str = node_field(pool, arm_nid, 3);
            let body_list: i64 = node_field(pool, arm_nid, 4);
            let guard_nid: i64 = node_field(pool, arm_nid, 5);
            let al: i64 = ctr_next(lbls);
            let nl: i64 = ctr_next(lbls);
            if str_eq(ename, "__wild") {
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
                    sym_set(arm_sym, binding, bar);
                    let mv: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv, mslot));
                    ir_block_add(ab, ir_store(mv, bar));
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__int") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let iv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(iv_r, vname));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, mv, iv_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
                    sym_set(arm_sym, binding, bar);
                    let mv2: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv2, mslot));
                    ir_block_add(ab, ir_store(mv2, bar));
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__str") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let sidx: i64 = vec_len(strtab); strtab.push(vname);
                let sv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_str(sv_r, sidx));
                let mut eq_args: Vec<i32> = Vec::new(); eq_args.push(mv); eq_args.push(sv_r);
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(cmp_r, "str_eq", eq_args));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, bar);
                    sym_set(arm_sym, binding, bar);
                    let mv2: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv2, mslot));
                    ir_block_add(ab, ir_store(mv2, bar));
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__range") {
                // v0.3.118: range pattern in stmt-position match.
                // Mirrors the lower_expr __range arm at line 10592.
                // Pre-v0.3.118 this branch fell through to the
                // enum-tag-decode path, which treated the i64
                // scrutinee as a Vec pointer and segfaulted at runtime
                // (`vec_get(inttoptr i64_value, 0)`). HIGH-blast
                // silent miscompute → segfault for any program using
                // range patterns in statement-form match (the
                // expression-position match was already correct).
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let lo_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(lo_r, vname));
                let hi_n: i64 = str_to_int(binding);
                let hi_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(hi_r, hi_n));
                let lo_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, lo_ok, lo_r, mv));
                let hi_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, hi_ok, mv, hi_r));
                let both_r: i64 = ctr_next(regs); ir_block_add(cur, ir_binop(13, both_r, lo_ok, hi_ok));
                ir_block_add(cur, ir_br_cond(both_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let arm_sym: Vec<i32> = sym_clone(sym);
                ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
            } else if str_eq(ename, "__range_bad") {
                ir_block_add(cur, ir_br(nl));
            } else {
                if tag_r < 0 {
                    let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                    let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
                    let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(mv); tag_args.push(zero_r);
                    tag_r = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
                };
                let etag_key: str = str_concat("__etag_", str_concat(ename, str_concat("_", vname)));
                let vtag: i64 = sym_get(sym, etag_key);
                let vtag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(vtag_r, vtag));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, vtag_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_payloads(binding, ab, regs, arm_sym, mslot, fir);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            };
            let mut nb: Vec<i32> = ir_block_new(nl); ir_fn_add_block(fir, nb);
            cur = nb;
            ci = ci + 1;
        };
        ir_block_add(cur, ir_br(ml));
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb);
        return mb;
    };
    if kind == 26 {
        if lx >= 0 { ir_block_add(cur, ir_br(lx)); };
        return cur;
    };
    if kind == 27 {
        if lh >= 0 { ir_block_add(cur, ir_br(lh)); };
        return cur;
    };
    print(str_concat("ERROR: unknown stmt kind ", str_from_int(kind)));
    return cur;
}
fn lower_stmts(pool: Vec<i32>, lid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let cnt: i64 = list_len(pool, lid); let mut i: i64 = 0; let mut b: Vec<i32> = cur;
    while i < cnt { b = lower_stmt(pool, list_get(pool, lid, i), b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls); i = i + 1; };
    return b;
}

fn lower_fn(pool: Vec<i32>, fn_nid: i64, strtab: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, globals: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>, fn_decls: Vec<i32>) -> Vec<i32> {
    let name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let blist: i64 = node_field(pool, fn_nid, 4);
    let pc: i64 = list_len(pool, plist);
    let mut regs: Vec<i32> = ctr_new();
    let mut lbls: Vec<i32> = ctr_new();
    let mut sym: Vec<i32> = sym_new();
    enum_populate_sym(pool, enums, sym);
    // v0.3.54: seed sym with `__fnret_NAME = rtype` entries so
    // binop_float_type's kind==7 (call) branch can resolve the
    // called fn's return type without signature plumbing through
    // 44 lower_expr call sites.
    populate_fn_returns_in_sym(pool, fn_decls, sym);
    let mut fir: Vec<i32> = ir_fn_new(name, pc);
    let mut ebb0: Vec<i32> = ir_block_new(0);
    ir_fn_add_block(fir, ebb0);
    let mut pi: i64 = 0;
    while pi < pc {
        let pnid: i64 = list_get(pool, plist, pi);
        let pname: str = node_field(pool, pnid, 1);
        let ar: i64 = ctr_next(regs); ir_block_add(ebb0, ir_alloca(ar));
        let pr2: i64 = ctr_next(regs); ir_block_add(ebb0, ir_param_ref(pr2, pi));
        ir_block_add(ebb0, ir_store(pr2, ar));
        sym_set(sym, pname, ar);
        // Track struct type for parameters (strip generic params)
        let ptype: str = node_field(pool, pnid, 2);
        let sbase: str = type_base_name(ptype);
        if str_len(sbase) > 0 { sym_set(sym, str_concat("__type_", pname), sbase); };
        // v0.3.55: also store full declared type for generic-aware
        // dispatch (mirror the same change at the let binding site).
        if str_len(ptype) > 0 { sym_set(sym, str_concat("__fulltype_", pname), ptype); };
        pi = pi + 1;
    };
    let mut gi: i64 = 0;
    while gi < vec_len(globals) {
        let gnid: i64 = vec_get(globals, gi);
        let gname: str = node_field(pool, gnid, 1);
        let gar: i64 = ctr_next(regs); ir_block_add(ebb0, ir_alloca(gar));
        sym_set(sym, gname, gar);
        let ginit: i64 = node_field(pool, gnid, 3);
        let mut gp: Vec<i32> = lower_expr(pool, ginit, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        let gv: i64 = lx_reg(gp);
        ebb0 = lx_blk(gp);
        ir_block_add(ebb0, ir_store(gv, gar));
        let mut gtype: str = node_field(pool, gnid, 2);
        if str_len(gtype) == 0 && node_kind(pool, ginit) == 34 { gtype = node_field(pool, ginit, 1); }
        else if str_len(gtype) == 0 && node_kind(pool, ginit) == 12 { gtype = node_field(pool, ginit, 1); };
        let gbase: str = type_base_name(gtype);
        if str_len(gbase) > 0 { sym_set(sym, str_concat("__type_", gname), gbase); };
        // v0.3.55: full declared type (mirror let / param sites).
        if str_len(gtype) > 0 { sym_set(sym, str_concat("__fulltype_", gname), gtype); };
        gi = gi + 1;
    };
    let bcnt: i64 = list_len(pool, blist);
    let mut fb: Vec<i32> = ebb0;
    let mut last_kind: i64 = 0 - 1;
    if bcnt > 0 { last_kind = node_kind(pool, list_get(pool, blist, bcnt - 1)); };
    if bcnt > 0 && (last_kind == 25 || last_kind == 23 || last_kind == 38) {
        let mut bi: i64 = 0;
        while bi + 1 < bcnt {
            fb = lower_stmt(pool, list_get(pool, blist, bi), fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            bi = bi + 1;
        };
        let last_stmt: i64 = list_get(pool, blist, bcnt - 1);
        let mut expr_nid: i64 = last_stmt;
        if last_kind == 25 { expr_nid = node_field(pool, last_stmt, 1); };
        let mut ep: Vec<i32> = lower_expr(pool, expr_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        fb = lx_blk(ep);
        let mut rv: i64 = lx_reg(ep);
        if block_has_term(fb) == 0 {
            if rv < 0 {
                rv = ctr_next(regs);
                ir_block_add(fb, ir_const_int(rv, 0));
            };
            ir_block_add(fb, ir_ret(rv));
        };
        return fir;
    };
    fb = lower_stmts(pool, blist, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
    if block_has_term(fb) == 0 {
        let zr: i64 = ctr_next(regs); ir_block_add(fb, ir_const_int(zr, 0)); ir_block_add(fb, ir_ret(zr));
    };
    return fir;
}

// =====================================================
// V2 §1.4: PARALLEL FRONTEND
// =====================================================
// When compiling multi-file projects, files at the same dependency
// level can be lexed and parsed in parallel. The constraint is the
// dependency DAG: a file cannot type-check until the signatures of
// its imports are resolved.
//
// Within a single file, the pipeline is sequential (lex → parse →
// check → lower → emit) because each stage depends on the previous.
// Parallelism applies across independent files within a level.
//
// For single-file compilation (most common case), the parallel frontend
// has no effect. The incremental compilation cache (§1.3) provides the
// speed benefit for iterative development.
//
// Multi-file parallel compilation is enabled automatically when
// the import resolver detects multiple independent imports at the
// same depth level. Each is resolved via thread_spawn + thread_join.
// =====================================================

// =====================================================
// V2 §1.3: INCREMENTAL COMPILATION
// =====================================================
// Cache compiled function IR keyed by source hash.
// On rebuild: re-lex/parse the changed file, extract signatures,
// compare against cache. If no signature changed, only re-codegen
// changed function bodies. If a signature changed, invalidate
// all transitive dependents.
//
// Cache format: .nuc_cache/<source_hash>.sig  (signature file)
//               .nuc_cache/<fn_hash>.ll       (per-function LLVM IR)
//
// ALL safety checks (ownership, taint, effect) run on every
// recompiled function. The cache only avoids re-checking
// byte-identical unchanged code.
// =====================================================

fn build_mode_name(strict_mode: i64) -> str {
    if strict_mode == 1 { return "strict"; };
    return "fast";
}

fn print_phase_time(enabled: i64, label: str, elapsed_ms: i64) {
    if enabled == 1 {
        print(str_concat("  time ", str_concat(label, str_concat(": ", str_concat(str_from_int(elapsed_ms), " ms")))));
    };
}

fn build_cache_key(source: str, strict_mode: i64) -> str {
    let mut sb: i64 = sb_new();
    // v0.3.135: NUC-FEEDBACK-007 — include compiler_version_label
    // in the cache key so a binary upgrade invalidates the cache.
    // Pre-v0.3.135 the key was {scheme | exe_path | mode | source}.
    // The agent flipped a literal back-and-forth across versions
    // (`0.00000001` → `0.000001` → `0.00000001`); after the
    // v0.3.133 lexer fix, the SAME source text from before the fix
    // keyed identically and hit the OLD IR (which still produced
    // the NaN cascade). Adding the version label means each tagged
    // release has its own cache namespace; stale IR from older
    // tags is never reused.
    sb_append(sb, "native-cache-v5|");
    sb_append(sb, compiler_version_label());
    sb_append(sb, "|");
    if args_count() > 0 { sb_append(sb, args_get(0)); };
    sb_append(sb, "|");
    sb_append(sb, build_mode_name(strict_mode));
    sb_append(sb, "|");
    sb_append(sb, source);
    return content_hash(sb_to_str(sb));
}

fn collect_native_directives(imported: Vec<i32>) -> Vec<i32> {
    let mut all_links: i64 = sb_new();
    let mut all_cfiles: i64 = sb_new();
    let mut all_libpaths: i64 = sb_new();
    let mut di: i64 = 0;
    while di < vec_len(imported) {
        let imp_path: str = vec_get(imported, di);
        let imp_raw: str = file_read_string(imp_path);
        let imp_dir: str = extract_dir(imp_path);
        let imp_d: Vec<i32> = extract_directives(imp_raw, imp_dir);
        sb_append(all_links, vec_get(imp_d, 0));
        sb_append(all_cfiles, vec_get(imp_d, 1));
        sb_append(all_libpaths, vec_get(imp_d, 2));
        di = di + 1;
    };
    let mut out: Vec<i32> = Vec::new();
    out.push(sb_to_str(all_links));
    out.push(sb_to_str(all_cfiles));
    out.push(sb_to_str(all_libpaths));
    return out;
}

fn resolve_toolchain_path(raw_path: str) -> str {
    let from_cwd: str = sanitize(raw_path);
    if str_len(file_read_string(from_cwd)) > 0 { return from_cwd; };
    if args_count() > 0 {
        let exe_dir: str = extract_dir(args_get(0));
        let from_exe_dir: str = sanitize(str_concat(exe_dir, raw_path));
        if str_len(file_read_string(from_exe_dir)) > 0 { return from_exe_dir; };
        let repo_dir: str = parent_dir(exe_dir);
        let from_repo_dir: str = sanitize(str_concat(repo_dir, raw_path));
        if str_len(file_read_string(from_repo_dir)) > 0 { return from_repo_dir; };
    };
    return from_cwd;
}

fn llvm_clang_path() -> str {
    // v0.3.119: NUC-FEEDBACK-003 toolchain detection. The launcher
    // scripts SHOULD set up PATH before invoking the compiler, but
    // when users invoke `nucleor.exe` directly (or run from a fresh
    // shell that hasn't sourced the launcher), the bare `clang` PATH
    // lookup fails with the unhelpful Windows error
    // `'clang' is not recognized as an internal or external command`.
    // Probe the canonical install paths in order and return an
    // absolute path when found. Falls back to bare `clang` (PATH
    // lookup) if none match — preserves prior behavior for users
    // with a custom install elsewhere.
    //
    // Resolution order:
    //   1. NUCLEOR_CLANG env override (highest priority — explicit user wish)
    //   2. Windows: C:\Program Files\LLVM\bin\clang.exe (default LLVM installer)
    //   3. Windows: C:\msys64\mingw64\bin\clang.exe (MSYS2)
    //   4. macOS: /opt/homebrew/opt/llvm/bin/clang (homebrew)
    //   5. macOS: /usr/local/opt/llvm/bin/clang (older homebrew)
    //   6. Linux: /usr/bin/clang, /usr/local/bin/clang
    //   7. Bare `clang` (PATH fallback)
    let envc: str = env_get_or("NUCLEOR_CLANG", "");
    if str_len(envc) > 0 { return envc; };
    if host_is_windows() == 1 {
        // Windows: probe canonical LLVM install paths. file_read_string
        // returns the binary contents (PE files start with `MZ` so
        // strlen > 0); empty string ⇒ file doesn't exist.
        let p1: str = "C:\\Program Files\\LLVM\\bin\\clang.exe";
        if str_len(file_read_string(p1)) > 0 { return p1; };
        let p2: str = "C:\\msys64\\mingw64\\bin\\clang.exe";
        if str_len(file_read_string(p2)) > 0 { return p2; };
    };
    return "clang";
}

fn host_is_windows() -> i64 {
    // Detects host OS via the path separator returned by the runtime.
    // Used by link_native_module to choose Windows-only flags (/STACK: linker
    // syntax, .exe suffix, 2>NUL stderr redirect) vs POSIX equivalents.
    let sep: str = path_separator();
    if str_len(sep) >= 1 && str_char_at(sep, 0) == 92 { return 1; };
    return 0;
}

fn host_exe_suffix() -> str {
    if host_is_windows() == 1 { return ".exe"; };
    return "";
}

fn host_target_path_sep() -> str {
    if host_is_windows() == 1 { return "\\"; };
    return "/";
}

fn host_null_redirect() -> str {
    if host_is_windows() == 1 { return " 2>NUL"; };
    return " 2>/dev/null";
}

fn host_stack_link_flag() -> str {
    // Windows: clang-cl-style flag passed through to MSVC link.exe / lld-link.
    // POSIX: GNU ld accepts -z stacksize=N (in bytes). Both expand the main
    // thread stack to 16 MiB so deep recursion in the compiler works.
    if host_is_windows() == 1 { return " -Wl,/STACK:16777216"; };
    return " -Wl,-z,stacksize=16777216";
}

fn link_native_module(ll: str, out_name: str, imported: Vec<i32>, cache_ll_path: str, link_native: i64, time_passes: i64) -> i64 {
    let ll_path: str = sanitize(str_concat("target/", str_concat(out_name, ".ll")));
    let exe_path: str = sanitize(str_concat(str_concat("target", host_target_path_sep()), str_concat(out_name, host_exe_suffix())));
    let null_redir: str = host_null_redirect();
    system(str_concat("mkdir target", null_redir));
    file_write_string(ll_path, ll);
    if str_len(cache_ll_path) > 0 {
        system(str_concat("mkdir .nuc_cache", null_redir));
        let clean_cache_path: str = sanitize(cache_ll_path);
        file_write_string(clean_cache_path, ll);
    };
    print(str_concat("  emitted: ", str_concat(ll_path, str_concat(" (", str_concat(str_from_int(str_len(ll)), " bytes)")))));
    if link_native == 0 {
        print(str_concat("  native link: skipped (use ", str_concat(exe_path, " only after a linked build)")));
        return 0;
    };
    let native_d: Vec<i32> = collect_native_directives(imported);
    let link_flags: str = vec_get(native_d, 0);
    let cfiles: str = vec_get(native_d, 1);
    let libpath_flags: str = vec_get(native_d, 2);
    let rt_arg: str = resolve_toolchain_path("stdlib/runtime/nucleor_llvm_rt.c");
    let clang_start: i64 = now_ms();
    let stack_flag: str = host_stack_link_flag();
    // T1.5d (v0.2.343): capture clang stderr to a log file so the
    // post-link MOD-003 diagnostic step can scan it for undefined-
    // symbol references that match privatized fn names. Without
    // capture, clang's output goes straight to the terminal and we
    // can't tell whether any of its errors are MOD-003-worthy.
    system(str_concat("mkdir .nuc_cache", null_redir));
    let log_path: str = sanitize(".nuc_cache/clang_link.log");
    // v0.3.119: NUC-FEEDBACK-003 — quote the clang path so spaces
    // (e.g. `C:\Program Files\LLVM\bin\clang.exe`) survive the shell
    // command split. Without quoting, cmd.exe sees `C:\Program` as
    // the executable and the rest as args, failing with
    // `'C:\Program' is not recognized`.
    let clang_quoted: str = str_concat("\"", str_concat(llvm_clang_path(), "\""));
    let cmd: str = str_concat(clang_quoted, str_concat(" ", str_concat(ll_path, str_concat(" ", str_concat(rt_arg, str_concat(cfiles, str_concat(" -o ", str_concat(exe_path, str_concat(" -Wno-override-module", str_concat(stack_flag, str_concat(" ", str_concat(libpath_flags, str_concat(link_flags, str_concat(" > ", str_concat(log_path, " 2>&1")))))))))))))));
    let rc: i64 = system(cmd);
    print_phase_time(time_passes, "clang", now_ms() - clang_start);
    let clang_log: str = file_read_string(log_path);
    if rc != 0 {
        // T1.5d: lift link-time undefined-symbol errors into MOD-003
        // diagnostics for any symbol that matches a registered
        // private fn name. Echo the raw clang output AFTER the
        // friendly diagnostic so users see both: the spec-aligned
        // diagnostic first (for tooling), then the underlying clang
        // detail (for power users).
        let priv_reg: Vec<i32> = priv_build_global_registry(imported);
        let lifted: i64 = priv_lift_link_errors(clang_log, priv_reg);
        if str_len(clang_log) > 0 { print(clang_log); };
        let ll_check: str = file_read_string(ll_path);
        if str_len(ll_check) > 0 {
            print(str_concat("  COMPILE FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
            if lifted > 0 {
                print(str_concat("  ", str_concat(str_from_int(lifted), " MOD-003 violation(s) — see error[MOD-003] above")));
            } else {
                print("  note: LLVM IR was emitted; GPU/CUDA experiments may require manual link with CUDA libs");
            };
        } else {
            print(str_concat("  COMPILE FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
            return 1;
        };
        return 1;
    };
    if str_len(clang_log) > 0 { print(clang_log); };
    print(str_concat("  compiled: ", exe_path));
    return 0;
}

// =====================================================
// MODULE SYSTEM (imports)
// =====================================================
fn extract_dir(path: str) -> str {
    let slen: i64 = str_len(path);
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(path, i);
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_sep >= 0 { return str_substring(path, 0, last_sep + 1); };
    return "";
}

fn path_is_absolute(path: str) -> i64 {
    let slen: i64 = str_len(path);
    if slen >= 1 {
        let c0: i64 = str_char_at(path, 0);
        if c0 == 47 || c0 == 92 { return 1; };
    };
    if slen >= 2 && str_char_at(path, 1) == 58 { return 1; };
    return 0;
}

fn trim_trailing_sep(path: str) -> str {
    let mut end: i64 = str_len(path);
    while end > 0 {
        let c: i64 = str_char_at(path, end - 1);
        if c == 47 || c == 92 { end = end - 1; }
        else { return str_substring(path, 0, end); };
    };
    return "";
}

fn parent_dir(path: str) -> str {
    let trimmed: str = trim_trailing_sep(path);
    if str_len(trimmed) == 0 { return ""; };
    return extract_dir(trimmed);
}

fn resolve_import_path(base_dir: str, raw_path: str) -> str {
    if path_is_absolute(raw_path) == 1 { return sanitize(raw_path); };
    let mut search_dir: str = base_dir;
    while 1 == 1 {
        let candidate: str = sanitize(str_concat(search_dir, raw_path));
        if str_len(file_read_string(candidate)) > 0 { return candidate; };
        if str_len(search_dir) == 0 { break; };
        search_dir = parent_dir(search_dir);
    };
    let from_cwd: str = sanitize(raw_path);
    if str_len(file_read_string(from_cwd)) > 0 { return from_cwd; };
    // v0.3.122: NUC-FEEDBACK-004 — when the source file is OUTSIDE
    // the Nucleor_OSS repo (adopters using nucleor.exe as an external
    // tool), `import "stdlib/rods/jsonl.nr"` and other stdlib imports
    // silently fail to resolve via the base_dir walk above — the
    // compiler had no idea where stdlib lives. The import then
    // produces zero injected source and every `emit_json_*` (or other
    // stdlib symbol) fails at clang link with `@<name> undefined`.
    // Fix: also probe `NUCLEOR_STDLIB` env override, and the
    // `<exe_dir>/..` (i.e. OSS-root sibling of `bin/`) — same pattern
    // as resolve_toolchain_path. Both checks fail-soft via
    // file_read_string > 0, so users with custom layouts still get
    // their relative-to-source resolution from the loop above.
    let env_root: str = env_get_or("NUCLEOR_STDLIB", "");
    if str_len(env_root) > 0 {
        let from_env: str = sanitize(str_concat(env_root, str_concat("/", raw_path)));
        if str_len(file_read_string(from_env)) > 0 { return from_env; };
    };
    if args_count() > 0 {
        let exe_dir: str = extract_dir(args_get(0));
        let from_exe_dir: str = sanitize(str_concat(exe_dir, raw_path));
        if str_len(file_read_string(from_exe_dir)) > 0 { return from_exe_dir; };
        let repo_dir: str = parent_dir(exe_dir);
        let from_repo_dir: str = sanitize(str_concat(repo_dir, raw_path));
        if str_len(file_read_string(from_repo_dir)) > 0 { return from_repo_dir; };
    };
    return sanitize(str_concat(base_dir, raw_path));
}

fn module_record_add(records: Vec<i32>, path: str, raw: str) -> i64 {
    records.push(path);
    records.push(content_hash(raw));
    return 0;
}
fn module_records_serialize(records: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(records) {
        sb_append(sb, vec_get(records, i));
        sb_append(sb, "|");
        sb_append(sb, vec_get(records, i + 1));
        sb_append(sb, "\n");
        i = i + 2;
    };
    return sb_to_str(sb);
}
fn module_records_validate(manifest: str) -> Vec<i32> {
    let mut imported: Vec<i32> = Vec::new();
    if str_len(manifest) == 0 {
        let mut fail: Vec<i32> = Vec::new();
        fail.push(0);
        fail.push(imported);
        return fail;
    };
    let slen: i64 = str_len(manifest);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(manifest, eol) != 10 { eol = eol + 1; };
        if eol > p {
            let line: str = str_substring(manifest, p, eol);
            let llen: i64 = str_len(line);
            let mut sep: i64 = 0;
            while sep < llen && str_char_at(line, sep) != 124 { sep = sep + 1; };
            if sep >= llen {
                let mut fail2: Vec<i32> = Vec::new();
                fail2.push(0);
                fail2.push(imported);
                return fail2;
            };
            let path: str = str_substring(line, 0, sep);
            let expected_hash: str = str_substring(line, sep + 1, llen);
            let raw: str = file_read_string(path);
            if str_len(raw) == 0 || str_eq(content_hash(raw), expected_hash) == 0 {
                let mut fail3: Vec<i32> = Vec::new();
                fail3.push(0);
                fail3.push(imported);
                return fail3;
            };
            imported.push(path);
        };
        p = eol + 1;
    };
    let mut ok: Vec<i32> = Vec::new();
    ok.push(1);
    ok.push(imported);
    return ok;
}
fn module_graph_cache_id(src_path: str) -> str {
    // v0.3.135: NUC-FEEDBACK-007 — include compiler_version_label
    // so a binary upgrade invalidates the resolved-source cache
    // alongside the IR cache. Without this, a recompile after
    // a compiler bump would re-use cached resolved source from
    // before the lexer/parser fix landed.
    return content_hash(str_concat("module-graph-v2|", str_concat(compiler_version_label(), str_concat("|", sanitize(src_path)))));
}
fn module_graph_manifest_path(src_path: str) -> str {
    return sanitize(str_concat(".nuc_cache/modgraph_", str_concat(module_graph_cache_id(src_path), ".manifest")));
}
fn module_graph_source_path(src_path: str) -> str {
    return sanitize(str_concat(".nuc_cache/modgraph_", str_concat(module_graph_cache_id(src_path), ".resolved")));
}

// RFC-0018 phase 1: rewrite Rust-style use paths into the equivalent
// quoted-path import. Recognized prefixes:
//   use std::foo;       → import "stdlib/rods/foo.nr"
//   use std::foo::bar;  → import "stdlib/rods/foo/bar.nr"
//   use crate::path;    → import "path.nr" (relative to project root)
//   use super::path;    → import "../path.nr" (relative to base_dir)
// Trailing `as ALIAS`, `;`, and `{ ... }` glob/list forms are ignored
// for now (full resolver lands in phase 2 with name-mangling).
fn rewrite_use_path(line: str, lp: i64, prefix_len: i64, eol: i64) -> str {
    let mut qp: i64 = lp + prefix_len;
    while qp < eol && str_char_at(line, qp) == 32 { qp = qp + 1; };
    if qp >= eol { return ""; };
    let c0: i64 = str_char_at(line, qp);
    if c0 == 34 { return ""; };  // already quoted
    if is_alpha(c0) == 0 { return ""; };
    let mut path_end: i64 = qp;
    while path_end < eol {
        let pc: i64 = str_char_at(line, path_end);
        if is_alnum(pc) == 1 || pc == 58 { path_end = path_end + 1; }
        else { break; };
    };
    let raw_path: str = str_substring(line, qp, path_end);
    let plen: i64 = str_len(raw_path);
    let mut prefix: str = "";
    let mut tail_start: i64 = 0;
    if str_starts_with(raw_path, "std::") == 1 {
        prefix = "stdlib/rods/";
        tail_start = 5;
    } else if str_starts_with(raw_path, "crate::") == 1 {
        prefix = "";
        tail_start = 7;
    } else if str_starts_with(raw_path, "super::") == 1 {
        prefix = "../";
        tail_start = 7;
    } else { return ""; };
    let mut sb: i64 = sb_new();
    sb_append(sb, prefix);
    let mut i: i64 = tail_start;
    while i < plen {
        let ch: i64 = str_char_at(raw_path, i);
        if ch == 58 && i + 1 < plen && str_char_at(raw_path, i + 1) == 58 {
            sb_append(sb, "/");
            i = i + 2;
        } else {
            sb_append(sb, str_substring(raw_path, i, i + 1));
            i = i + 1;
        };
    };
    sb_append(sb, ".nr");
    return sb_to_str(sb);
}

fn resolve_source_with_records(src: str, base_dir: str, imported: Vec<i32>, module_records: Vec<i32>) -> str {
    let mut result: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(src, lp) == 32 || str_char_at(src, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = eol - lp;
        let mut prefix_len: i64 = 0;
        let mut is_mod_decl: i64 = 0;
        if line_len >= 8 && str_eq_at(src, lp, "import ") == 1 { prefix_len = 7; };
        if prefix_len == 0 && line_len >= 5 && str_eq_at(src, lp, "use ") == 1 { prefix_len = 4; };
        // RFC-0018 phase 1: `mod foo;` desugars to `import "./foo.nr"`.
        // T1.5a (v0.2.340): block-form `mod foo { ... }` is now also
        // recognized and inlined. The contents are spliced into the
        // outer source after stripping the `mod foo {` opener and the
        // matching `}` (brace-balanced scan, comment- and
        // string-literal-aware). This is the pragmatic prelude to the
        // full namespacing resolver — `mod tests { #[test] fn ... }`
        // patterns work today; visibility scoping arrives in T1.5b.
        if prefix_len == 0 && line_len >= 5 && str_eq_at(src, lp, "mod ") == 1 {
            let mut sp: i64 = lp + 4;
            while sp < eol && str_char_at(src, sp) == 32 { sp = sp + 1; };
            let mut np: i64 = sp;
            while np < eol && (is_alnum(str_char_at(src, np)) == 1) { np = np + 1; };
            // Tail after the name: `;` → file-rooted; `{` → block-form.
            let mut tp: i64 = np;
            while tp < eol && str_char_at(src, tp) == 32 { tp = tp + 1; };
            if np > sp && tp < eol && str_char_at(src, tp) == 59 {
                is_mod_decl = 1;
                prefix_len = 4;
            };
            if np > sp && tp < eol && str_char_at(src, tp) == 123 {
                // Block-form: scan brace-balanced past the `{`. Scanner
                // tracks string literals (single/double quotes) and
                // line comments so a `}` inside a string or `//` line
                // doesn't close the module prematurely.
                let body_start: i64 = tp + 1;
                let mut depth: i64 = 1;
                let mut q: i64 = body_start;
                let mut in_dquote: i64 = 0;
                let mut in_squote: i64 = 0;
                let mut in_line_comment: i64 = 0;
                while q < slen && depth > 0 {
                    let ch: i64 = str_char_at(src, q);
                    if in_line_comment == 1 {
                        if ch == 10 { in_line_comment = 0; };
                    } else if in_dquote == 1 {
                        if ch == 92 && q + 1 < slen { q = q + 1; }
                        else if ch == 34 { in_dquote = 0; };
                    } else if in_squote == 1 {
                        if ch == 92 && q + 1 < slen { q = q + 1; }
                        else if ch == 39 { in_squote = 0; };
                    } else if ch == 47 && q + 1 < slen && str_char_at(src, q + 1) == 47 {
                        in_line_comment = 1;
                        q = q + 1;
                    } else if ch == 34 {
                        in_dquote = 1;
                    } else if ch == 39 {
                        in_squote = 1;
                    } else if ch == 123 {
                        depth = depth + 1;
                    } else if ch == 125 {
                        depth = depth - 1;
                    };
                    q = q + 1;
                };
                if depth == 0 {
                    // Splice body in place; advance the outer scanner
                    // past the closing brace.
                    let body: str = str_substring(src, body_start, q - 1);
                    sb_append(result, "// mod ");
                    sb_append(result, str_substring(src, sp, np));
                    sb_append(result, " { ... } (inlined block-form)\n");
                    sb_append(result, resolve_source_with_records(body, base_dir, imported, module_records));
                    sb_append(result, "\n");
                    p = q;
                    continue;
                };
                // Unbalanced — fall through; parser will surface the error.
            };
        };
        if prefix_len > 0 {
            let mut qp: i64 = lp + prefix_len;
            while qp < eol && str_char_at(src, qp) == 32 { qp = qp + 1; };
            // RFC-0018 phase 1: Rust-style `use std::foo` / `use crate::x` /
            // `use super::x` paths get rewritten to a quoted-path equivalent.
            let mut rust_path: str = "";
            if is_mod_decl == 1 {
                let mut np: i64 = qp;
                while np < eol && is_alnum(str_char_at(src, np)) == 1 { np = np + 1; };
                if np > qp {
                    rust_path = str_concat(str_substring(src, qp, np), ".nr");
                };
            } else {
                rust_path = rewrite_use_path(src, lp, prefix_len, eol);
            };
            if str_len(rust_path) > 0 {
                let path: str = resolve_import_path(base_dir, rust_path);
                let mut already: i64 = 0;
                let mut ii: i64 = 0;
                while ii < vec_len(imported) {
                    if str_eq(vec_get(imported, ii), path) { already = 1; };
                    ii = ii + 1;
                };
                if already == 0 {
                    imported.push(path);
                    let isrc: str = file_read_string(path);
                    if str_len(isrc) > 0 {
                        let isrc_used: str = priv_apply_if_opted_in(isrc, path);
                        module_record_add(module_records, path, isrc_used);
                        let idir: str = extract_dir(path);
                        sb_append(result, resolve_source_with_records(isrc_used, idir, imported, module_records));
                        sb_append(result, "\n");
                    } else {
                        sb_append(result, str_concat("// ERROR: cannot read use path ", path));
                        sb_append(result, "\n");
                    };
                };
            } else if qp < eol && str_char_at(src, qp) == 34 {
                let ps: i64 = qp + 1;
                let mut pe: i64 = ps;
                while pe < eol && str_char_at(src, pe) != 34 { pe = pe + 1; };
                let path: str = resolve_import_path(base_dir, str_substring(src, ps, pe));
                let mut already: i64 = 0;
                let mut ii: i64 = 0;
                while ii < vec_len(imported) {
                    if str_eq(vec_get(imported, ii), path) { already = 1; };
                    ii = ii + 1;
                };
                if already == 0 {
                    imported.push(path);
                    let isrc: str = file_read_string(path);
                    if str_len(isrc) > 0 {
                        let isrc_used: str = priv_apply_if_opted_in(isrc, path);
                        module_record_add(module_records, path, isrc_used);
                        let idir: str = extract_dir(path);
                        sb_append(result, resolve_source_with_records(isrc_used, idir, imported, module_records));
                        sb_append(result, "\n");
                    } else {
                        sb_append(result, str_concat("// ERROR: cannot read import ", path));
                        sb_append(result, "\n");
                    };
                };
            } else {
                sb_append(result, str_substring(src, p, eol));
                sb_append(result, "\n");
            };
        } else if line_len >= 2 && str_char_at(src, lp) == 35 && str_char_at(src, lp + 1) != 91 {
            // Skip # directives (#link, #cfile). Rust-style outer
            // attributes `#[...]` are preserved so the diag-filter
            // (`filter_allow_suppressed`) can still see them.
            sb_append(result, "\n");
        } else {
            sb_append(result, str_substring(src, p, eol));
            sb_append(result, "\n");
        };
        p = eol + 1;
    };
    return sb_to_str(result);
}

fn resolve_source(src: str, base_dir: str, imported: Vec<i32>) -> str {
    let mut module_records: Vec<i32> = Vec::new();
    return resolve_source_with_records(src, base_dir, imported, module_records);
}
fn load_resolved_source_bundle(src_path: str, use_cache: i64) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let manifest_path: str = module_graph_manifest_path(src_path);
    let source_path: str = module_graph_source_path(src_path);
    if use_cache == 1 {
        let manifest: str = file_read_string(manifest_path);
        let cached_source: str = file_read_string(source_path);
        if str_len(manifest) > 0 && str_len(cached_source) > 0 {
            let valid: Vec<i32> = module_records_validate(manifest);
            if vec_get(valid, 0) == 1 {
                out.push(cached_source);
                out.push(vec_get(valid, 1));
                out.push(1);
                return out;
            };
        };
    };
    let raw_source: str = file_read_string(src_path);
    let mut imported: Vec<i32> = Vec::new();
    if str_len(raw_source) == 0 {
        out.push("");
        out.push(imported);
        out.push(0);
        return out;
    };
    let mut module_records: Vec<i32> = Vec::new();
    imported.push(src_path);
    module_record_add(module_records, src_path, raw_source);
    let resolved: str = resolve_source_with_records(raw_source, extract_dir(src_path), imported, module_records);
    // T2.6 (v0.2.346): expand println!/print!/format! macros AFTER all
    // imports are inlined and BEFORE caching, so the cache holds the
    // post-expansion text. Identifier-and-quote-aware so a `!` inside
    // a string literal (e.g. `"err!"`) survives untouched.
    let after_format: str = expand_format_macros(resolved);
    // T2.8 (v0.2.353): strip `async` keyword before fn + rewrite
    // `<ident>.await` to `async_await(<ident>)`. Threads-only
    // commitment per RFC-0027 phase 1.
    let after_async: str = expand_async_syntax(after_format);
    // v0.3.0 (T3.1): wrap `#[deadline = N]` fns with start-capture
    // + `deadline_check` exit hook. Aborts on overrun (RT-004).
    let after_deadline: str = expand_deadline(after_async);
    // T2.3 (v0.2.349): expand closure literals `|args| body` in
    // argument position. Synthesizes top-level fns at the head of
    // the source; replaces the closure expression with the synth fn
    // name so downstream parsing sees a normal identifier reference.
    let source: str = expand_closures(after_deadline);
    if use_cache == 1 {
        system("mkdir .nuc_cache 2>NUL");
        file_write_string(manifest_path, module_records_serialize(module_records));
        file_write_string(source_path, source);
    };
    out.push(source);
    out.push(imported);
    out.push(0);
    return out;
}

fn extract_directives(raw_source: str, base_dir: str) -> Vec<i32> {
    // Returns vec: [0] = link flags string, [1] = cfile list string, [2] = libpath flags string
    let mut links: i64 = sb_new();
    let mut cfiles: i64 = sb_new();
    let mut libpaths: i64 = sb_new();
    let slen: i64 = str_len(raw_source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw_source, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(raw_source, lp) == 32 || str_char_at(raw_source, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = eol - lp;
        if line_len >= 6 && str_char_at(raw_source, lp) == 35 {
            if line_len >= 7 && str_eq_at(raw_source, lp, "#link ") == 1 {
                let mut qp: i64 = lp + 6;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    sb_append(links, " -l"); sb_append(links, str_substring(raw_source, ps, pe));
                };
            } else if line_len >= 8 && str_eq_at(raw_source, lp, "#cfile ") == 1 {
                let mut qp: i64 = lp + 7;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    let cf_path: str = str_substring(raw_source, ps, pe);
                    let cflen: i64 = str_len(cf_path);
                    let mut cf_abs: i64 = 0;
                    if cflen >= 1 && str_char_at(cf_path, 0) == 47 { cf_abs = 1; };
                    if cflen >= 2 && str_char_at(cf_path, 1) == 58 { cf_abs = 1; };
                    sb_append(cfiles, " ");
                    if cf_abs == 1 { sb_append(cfiles, cf_path); }
                    else { sb_append(cfiles, str_concat(base_dir, cf_path)); };
                };
            } else if line_len >= 10 && str_eq_at(raw_source, lp, "#libpath ") == 1 {
                let mut qp: i64 = lp + 9;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    sb_append(libpaths, " -L"); sb_append(libpaths, str_concat(base_dir, str_substring(raw_source, ps, pe)));
                };
            };
        };
        p = eol + 1;
    };
    let mut result: Vec<i32> = Vec::new();
    result.push(sb_to_str(links));
    result.push(sb_to_str(cfiles));
    result.push(sb_to_str(libpaths));
    return result;
}

// =====================================================
// COMPILER DRIVER
// =====================================================
fn compile_file_mode(src_path: str, out_name: str, strict_mode: i64, use_cache: i64, time_passes: i64, link_native: i64) -> i64 {
    let safe_out_name: str = normalize_output_name(out_name);
    if str_len(safe_out_name) == 0 {
        print(str_concat("ERROR: invalid output name: ", out_name));
        return 1;
    };
    let total_start: i64 = now_ms();
    let resolve_start: i64 = now_ms();
    let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
    let source: str = vec_get(bundle, 0);
    let imported: Vec<i32> = vec_get(bundle, 1);
    if str_len(source) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    print(str_concat("  source: ", str_concat(src_path, str_concat(" (", str_concat(str_from_int(str_len(source)), " bytes)")))));
    if strict_mode == 0 { print("  mode: fast (ownership + type)"); };
    if link_native == 0 { print("  mode: llvm-only (--no-link)"); };
    if vec_get(bundle, 2) == 1 { print("  incremental: module graph cache hit"); };
    print_phase_time(time_passes, "resolve_source", now_ms() - resolve_start);
    let preflight_start: i64 = now_ms();
    if preflight_source_check(source) != 0 { return 1; };
    print_phase_time(time_passes, "preflight", now_ms() - preflight_start);
    let mut cache_ll_path: str = "";
    if use_cache == 1 {
        let cache_key: str = build_cache_key(source, strict_mode);
        cache_ll_path = sanitize(str_concat(".nuc_cache/", str_concat(cache_key, ".ll")));
        let cached_ll: str = file_read_string(cache_ll_path);
        if str_len(cached_ll) > 0 {
            print(str_concat("  incremental: source cache hit (", str_concat(build_mode_name(strict_mode), ")")));
            let rc_cached: i64 = link_native_module(cached_ll, safe_out_name, imported, "", link_native, time_passes);
            print_phase_time(time_passes, "total", now_ms() - total_start);
            return rc_cached;
        };
    };
    let lex_start: i64 = now_ms();
    let mut tokens: Vec<i32> = lex(source);
    print_phase_time(time_passes, "lex", now_ms() - lex_start);
    let mut pool: Vec<i32> = Vec::new();
    let parse_start: i64 = now_ms();
    let mut r: Vec<i32> = parse_program(tokens, pool);
    print_phase_time(time_passes, "parse", now_ms() - parse_start);
    let prog: i64 = pr_val(r);
    let cnt: i64 = list_len(pool, prog);

    let mut strtab: Vec<i32> = Vec::new();
    let mut fns: Vec<i32> = Vec::new();
    let mut externs: Vec<i32> = Vec::new();
    let mut structs: Vec<i32> = Vec::new();
    let mut enums: Vec<i32> = Vec::new();
    let mut globals: Vec<i32> = Vec::new();
    // v0.3.54: collect fn return-type lookup table for binop_float_type's
    // kind==7 (call) branch. Mirrors the existing structs/enums vecs.
    // Holds both regular fns (kind 30) and extern fns (kind 32) — both
    // can return f32/f64 and call sites need correct binop dispatch.
    let mut fn_decls: Vec<i32> = Vec::new();
    // Pass 1: collect structs, enums, and externs
    let collect_start: i64 = now_ms();
    let mut fi: i64 = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 32 { externs.push(fn_nid); fn_decls.push(fn_nid); }
        else if node_kind(pool, fn_nid) == 33 { structs.push(fn_nid); }
        else if node_kind(pool, fn_nid) == 36 { enums.push(fn_nid); };
        if node_kind(pool, fn_nid) == 30 { fn_decls.push(fn_nid); };
        if node_kind(pool, fn_nid) == 50 { globals.push(fn_nid); };
        fi = fi + 1;
    };
    print_phase_time(time_passes, "collect_decls", now_ms() - collect_start);
    // Pass 1.5: collect trait impls and generate mangled functions
    let mut trait_impls: Vec<i32> = Vec::new();
    let mut impl_fns: Vec<i32> = Vec::new();
    let impl_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 45 {
            let type_name: str = node_field(pool, fn_nid, 2);
            let methods: i64 = node_field(pool, fn_nid, 3);
            let mc: i64 = list_len(pool, methods);
            let mut mi: i64 = 0;
            while mi < mc {
                let method_nid: i64 = list_get(pool, methods, mi);
                let orig_name: str = node_field(pool, method_nid, 1);
                let mangled: str = str_concat(type_name, str_concat("__", orig_name));
                let new_fn: i64 = mk6(pool, 30, mangled, node_field(pool, method_nid, 2), node_field(pool, method_nid, 3), node_field(pool, method_nid, 4), node_field(pool, method_nid, 5));
                impl_fns.push(new_fn);
                // v0.3.60: also append to fn_decls so the mangled
                // trait method has an `__fnret_<MANGLED>` sym entry
                // populated by populate_fn_returns_in_sym at lower_fn
                // entry. binop_float_type's kind==8 (method call)
                // branch reads that entry to dispatch f64 ops on
                // trait-method results.
                fn_decls.push(new_fn);
                trait_impl_register(trait_impls, type_name, orig_name, mangled);
                mi = mi + 1;
            };
        };
        fi = fi + 1;
    };
    // v0.3.82: trait default method support. After collect_impls
    // registers explicit impl methods, walk every kind-45 (impl block)
    // with a non-empty trait_name and look for default methods (body
    // != -1) declared in the corresponding kind-43 trait_decl that
    // the impl did NOT override. For each such default method,
    // synthesize a mangled fn `<TypeName>__<method>` using the
    // trait's body and register it in trait_impls + fn_decls. This
    // enables the canonical Rust pattern of trait defaults that impls
    // can selectively override. Pre-v0.3.82, calling a trait method
    // not present in the impl's explicit body fell through to the
    // `vec_<mname>` fallback which failed at clang link with
    // "use of undefined value".
    fi = 0;
    while fi < cnt {
        let impl_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, impl_nid) == 45 {
            let trait_name: str = node_field(pool, impl_nid, 1);
            let type_name2: str = node_field(pool, impl_nid, 2);
            let impl_methods: i64 = node_field(pool, impl_nid, 3);
            if str_len(trait_name) > 0 {
                let mut fj: i64 = 0;
                while fj < cnt {
                    let td_nid: i64 = list_get(pool, prog, fj);
                    if node_kind(pool, td_nid) == 43 && str_eq(node_field(pool, td_nid, 1), trait_name) == 1 {
                        let trait_methods: i64 = node_field(pool, td_nid, 2);
                        let tmc: i64 = list_len(pool, trait_methods);
                        let mut tmi: i64 = 0;
                        while tmi < tmc {
                            let trait_method_nid: i64 = list_get(pool, trait_methods, tmi);
                            let tmname: str = node_field(pool, trait_method_nid, 1);
                            let tbody: i64 = node_field(pool, trait_method_nid, 4);
                            if tbody >= 0 {
                                // Trait has a default body. Check if impl overrides.
                                let imc: i64 = list_len(pool, impl_methods);
                                let mut overridden: i64 = 0;
                                let mut imi: i64 = 0;
                                while imi < imc {
                                    let im_nid: i64 = list_get(pool, impl_methods, imi);
                                    if str_eq(node_field(pool, im_nid, 1), tmname) == 1 {
                                        overridden = 1;
                                    };
                                    imi = imi + 1;
                                };
                                if overridden == 0 {
                                    // v0.3.82: build new params with "Self"
                                    // substituted for the impl's actual
                                    // type_name. Without this, the default
                                    // body's `self` has type="Self" which
                                    // doesn't resolve to a known struct in
                                    // expr_struct_type, breaking dispatch
                                    // for any nested `self.<method>()` call.
                                    let trait_params: i64 = node_field(pool, trait_method_nid, 2);
                                    let pcount: i64 = list_len(pool, trait_params);
                                    let mut new_params: Vec<i32> = Vec::new();
                                    let mut pi: i64 = 0;
                                    while pi < pcount {
                                        let pnode: i64 = list_get(pool, trait_params, pi);
                                        let pname: str = node_field(pool, pnode, 1);
                                        let ptype: str = node_field(pool, pnode, 2);
                                        let mut new_ptype: str = ptype;
                                        if str_eq(ptype, "Self") == 1 { new_ptype = type_name2; };
                                        if str_eq(ptype, "&Self") == 1 { new_ptype = str_concat("&", type_name2); };
                                        if str_eq(ptype, "&mut Self") == 1 { new_ptype = str_concat("&mut ", type_name2); };
                                        new_params.push(mk3(pool, 41, pname, new_ptype));
                                        pi = pi + 1;
                                    };
                                    // Synthesize fn using trait's default body, mangled with the impl's type name.
                                    let dm_mangled: str = str_concat(type_name2, str_concat("__", tmname));
                                    let dm_fn: i64 = mk6(pool, 30, dm_mangled, mk_list(pool, new_params), node_field(pool, trait_method_nid, 3), tbody, 0);
                                    impl_fns.push(dm_fn);
                                    fn_decls.push(dm_fn);
                                    trait_impl_register(trait_impls, type_name2, tmname, dm_mangled);
                                };
                            };
                            tmi = tmi + 1;
                        };
                    };
                    fj = fj + 1;
                };
            };
        };
        fi = fi + 1;
    };
    print_phase_time(time_passes, "collect_impls", now_ms() - impl_start);
    // Diagnostic accumulator
    let mut diags: Vec<i32> = diag_new();
    // Pass 1.7: ownership checking
    let own_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { check_fn(pool, fn_nid, structs, enums, diags, source); };
        fi = fi + 1;
    };
    let mut oi: i64 = 0;
    while oi < vec_len(impl_fns) {
        check_fn(pool, vec_get(impl_fns, oi), structs, enums, diags, source);
        oi = oi + 1;
    };
    print_phase_time(time_passes, "ownership", now_ms() - own_start);
    let type_start: i64 = now_ms();
    let type_prof: Vec<i32> = tprof_new(time_passes);
    type_check_program(pool, prog, structs, diags, source, type_prof);
    print_phase_time(time_passes, "type", now_ms() - type_start);
    tprof_dump(type_prof);
    if strict_mode == 1 {
        print_phase_time(time_passes, "source", 0);
        print_phase_time(time_passes, "collect_pure", 0);
        print_phase_time(time_passes, "effect", 0);
        print_phase_time(time_passes, "taint", 0);
    };
    // RFC-0001 phase 1 — enforce #[no_alloc] before suppression so
    // users can `#[allow(RT-001)]` if needed. enforce_no_alloc
    // appends to diags; if no #[no_alloc] attribute is present in
    // the source it's a no-op.
    diags = enforce_no_alloc(diags, source);
    // T3.2 (v0.3.1): same pattern for #[no_panic] (RT-002).
    diags = enforce_no_panic(diags, source);
    // T3.6 (v0.3.5): same pattern for #[no_dyn] (RT-003).
    diags = enforce_no_dyn(diags, source);
    // T3.8 (v0.3.7): RT-006 — RT attribute on async fn. Reads the
    // column-0 markers expand_async_strip_keyword emits, which is
    // the only way to detect this after the async keyword itself
    // has been stripped from the resolved source.
    diags = enforce_rt006_async(diags, source);
    // T3.9 (v0.3.8): RT-005 — extern fn calls from RT-marked
    // bodies break the RT contract because nothing is known about
    // the extern's allocation, panic, or timing behaviour. v1
    // warns; users suppress per-fn via #[allow(RT-005)] until the
    // #[ffi_no_*] annotation family ships in v0.4.
    diags = enforce_rt005_ffi(diags, source);
    // T3.10 (v0.3.9): RT-008 — direct self-recursion in a
    // #[deadline] fn warns. Bounded recursion opts out via
    // `#[max_depth = N]`; indirect (mutual) recursion is left
    // for the v2 AST-based check.
    diags = enforce_rt008_recursion(diags, source);
    // T3.3 (v0.3.2): static WCET estimator for #[deadline = N] fns.
    // Emits warning[RT-004] when the v1 estimate exceeds the budget.
    diags = enforce_static_wcet(diags, source);
    // T3.5 (v0.3.3): RT-007 — warn when #[deadline] is paired with
    // neither #[no_alloc] nor #[no_panic]. Either guard makes the
    // deadline reachable in the first place.
    diags = enforce_deadline_safety(diags, source);
    // T3.20 (v0.3.36): emit DIAG-001 for #[allow(_fn)] / #[deny(_fn)]
    // codes whose prefix isn't in the canonical set. Runs BEFORE the
    // suppression pass so users can `#[allow(DIAG-001)]` to silence
    // it during a noisy refactor.
    diags = emit_diag001_unknown_codes(diags, source);
    if diag_count(diags) > 0 {
        // RFC-0028 §Suppression — drop warnings the user has silenced
        // via `#[allow(CODE)]`, then promote any remaining warnings
        // whose code is named in `#[deny(CODE)]`. Errors are not
        // suppressible. Allow runs first so a deny on a previously-
        // allowed code is a no-op (the diag is gone).
        diags = filter_allow_suppressed(diags, source);
        diags = promote_denied_to_errors(diags, source);
        if diag_count(diags) > 0 {
            // Emit every (post-filter, post-promote) diagnostic, but
            // only halt the build on errors. Warnings (NUM-003 lossy
            // cast, MATCH-001/002 typecker, etc.) flow through the
            // report without blocking compilation.
            if diag_use_json() == 1 { diag_emit_json(diags); } else { diag_emit_text_with_source(diags, source); };
            if diag_count_errors(diags) > 0 { return 1; };
        };
    };
    let mut closures: Vec<i32> = Vec::new();
    let lower_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { fns.push(lower_fn(pool, fn_nid, strtab, structs, enums, globals, closures, trait_impls, fn_decls)); };
        fi = fi + 1;
    };
    let mut ii: i64 = 0;
    while ii < vec_len(impl_fns) {
        fns.push(lower_fn(pool, vec_get(impl_fns, ii), strtab, structs, enums, globals, closures, trait_impls, fn_decls));
        ii = ii + 1;
    };
    let mut ci3: i64 = 0;
    while ci3 < vec_len(closures) { fns.push(vec_get(closures, ci3)); ci3 = ci3 + 1; };
    print_phase_time(time_passes, "lower", now_ms() - lower_start);
    let opt_start: i64 = now_ms();
    let mut opt_total: i64 = 0;
    fi = 0;
    while fi < vec_len(fns) {
        opt_total = opt_total + opt_fn(vec_get(fns, fi));
        fi = fi + 1;
    };
    print_phase_time(time_passes, "opt", now_ms() - opt_start);
    print(str_concat("  functions: ", str_from_int(vec_len(fns))));
    print(str_concat("  strings: ", str_from_int(vec_len(strtab))));
    print(str_concat("  optimized: ", str_concat(str_from_int(opt_total), " instructions")));
    let emit_start: i64 = now_ms();
    let ll: str = emit_module_ext(fns, strtab, pool, externs);
    print_phase_time(time_passes, "emit", now_ms() - emit_start);
    let rc: i64 = link_native_module(ll, safe_out_name, imported, cache_ll_path, link_native, time_passes);
    print_phase_time(time_passes, "total", now_ms() - total_start);
    return rc;
}

fn compile_file(src_path: str, out_name: str) -> i64 {
    return compile_file_mode(src_path, out_name, 0, 1, 0, 1);
}

fn strip_ext(path: str) -> str {
    let slen: i64 = str_len(path);
    let mut last_dot: i64 = 0 - 1;
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(path, i);
        if c == 46 { last_dot = i; };
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_dot > last_sep + 1 { return str_substring(path, 0, last_dot); };
    return path;
}

fn basename(path: str) -> str {
    let slen: i64 = str_len(path);
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(path, i);
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_sep >= 0 { return str_substring(path, last_sep + 1, slen); };
    return path;
}
fn is_output_name_char(ch: i64) -> i64 {
    if is_alnum(ch) == 1 || ch == 95 || ch == 45 { return 1; };
    return 0;
}
fn normalize_output_name(raw: str) -> str {
    let base: str = strip_ext(basename(raw));
    let blen: i64 = str_len(base);
    if blen == 0 { return ""; };
    let mut i: i64 = 0;
    while i < blen {
        if is_output_name_char(str_char_at(base, i)) == 0 { return ""; };
        i = i + 1;
    };
    return sanitize(base);
}

// ===== v0.3.0 (T3.1): #[deadline = N] runtime check rewrite =====
//
// Wraps fns annotated `#[deadline = N]` (microseconds) into a thin
// shim that captures the start time, calls the original body via
// a synthesized inner fn, then runs `deadline_check(start, N)`
// before returning. If the elapsed time exceeded N microseconds,
// the runtime aborts with `error[RT-004]`.
//
// Approach: rather than walking the body to find every `return`
// (which would need bracket-balanced + block-aware scanning), we
// rename the user's fn to `__nuc_dl_inner_<idx>` and synthesize a
// new outer fn with the original name that does:
//   let __nuc_dl_start: i64 = time_monotonic_us();
//   let __nuc_dl_r: <ret> = __nuc_dl_inner_<idx>(<args>);
//   deadline_check(__nuc_dl_start, N);
//   return __nuc_dl_r;
//
// The runtime check runs UNCONDITIONALLY at fn exit. Static WCET
// bounds (RT-004 at compile time) ship later in v0.3.1.

fn dl_extract_int_value(line: str) -> i64 {
    // Reads `#[deadline = N]` from the line and returns N (>= 0).
    // Returns -1 if the line doesn't match the expected shape.
    let needle: str = "#[deadline";
    let pos: i64 = source_find(line, needle);
    if pos < 0 { return 0 - 1; };
    let llen: i64 = str_len(line);
    let mut p: i64 = pos + str_len(needle);
    while p < llen && (str_char_at(line, p) == 32 || str_char_at(line, p) == 9) { p = p + 1; };
    if p >= llen || str_char_at(line, p) != 61 { return 0 - 1; };
    p = p + 1;
    while p < llen && (str_char_at(line, p) == 32 || str_char_at(line, p) == 9) { p = p + 1; };
    let num_start: i64 = p;
    while p < llen && is_digit(str_char_at(line, p)) == 1 { p = p + 1; };
    if p == num_start { return 0 - 1; };
    return str_to_int(str_substring(line, num_start, p));
}

fn dl_parse_fn_signature(src: str, fn_pos: i64, slen: i64) -> Vec<i32> {
    // Given `fn ` at fn_pos, extract:
    //   [0] = fn name (str)
    //   [1] = full param decl text "a: T1, b: T2" (str)
    //   [2] = return type "i64" or "" if void
    //   [3] = comma-separated arg names "a, b" (str)
    //   [4] = position of the `{` opening the body (i64)
    //   [5] = position one past the matching `}` (i64)
    // On parse failure, returns Vec with vec_len == 0.
    let mut out: Vec<i32> = Vec::new();
    let mut p: i64 = fn_pos + 3;  // skip past "fn "
    while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
    let name_start: i64 = p;
    let mut name_done: i64 = 0;
    while p < slen && name_done == 0 {
        let c: i64 = str_char_at(src, p);
        if is_alnum(c) == 1 || c == 95 { p = p + 1; }
        else { name_done = 1; };
    };
    if p == name_start { return out; };
    let fn_name: str = str_substring(src, name_start, p);
    while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
    if p >= slen || str_char_at(src, p) != 40 { return out; };
    let params_start: i64 = p + 1;
    let mut depth: i64 = 1;
    p = params_start;
    while p < slen && depth > 0 {
        let c: i64 = str_char_at(src, p);
        if c == 40 { depth = depth + 1; }
        else if c == 41 { depth = depth - 1; };
        if depth > 0 { p = p + 1; };
    };
    if p >= slen { return out; };
    let params_text: str = str_substring(src, params_start, p);
    p = p + 1;
    while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
    let mut ret_type: str = "";
    if p + 1 < slen && str_char_at(src, p) == 45 && str_char_at(src, p + 1) == 62 {
        p = p + 2;
        while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
        let rt_start: i64 = p;
        while p < slen && str_char_at(src, p) != 32 && str_char_at(src, p) != 9 && str_char_at(src, p) != 123 { p = p + 1; };
        ret_type = str_substring(src, rt_start, p);
    };
    while p < slen && str_char_at(src, p) != 123 { p = p + 1; };
    if p >= slen { return out; };
    let body_open: i64 = p;
    let mut q: i64 = p + 1;
    let mut body_depth: i64 = 1;
    let mut in_dq: i64 = 0;
    let mut in_sq: i64 = 0;
    while q < slen && body_depth > 0 {
        let c2: i64 = str_char_at(src, q);
        if in_dq == 1 {
            if c2 == 92 && q + 1 < slen { q = q + 1; }
            else if c2 == 34 { in_dq = 0; };
        } else if in_sq == 1 {
            if c2 == 92 && q + 1 < slen { q = q + 1; }
            else if c2 == 39 { in_sq = 0; };
        } else if c2 == 47 && q + 1 < slen && str_char_at(src, q + 1) == 47 {
            while q < slen && str_char_at(src, q) != 10 { q = q + 1; };
        } else if c2 == 34 { in_dq = 1; }
        else if c2 == 39 { in_sq = 1; }
        else if c2 == 123 { body_depth = body_depth + 1; }
        else if c2 == 125 { body_depth = body_depth - 1; };
        q = q + 1;
    };
    if body_depth != 0 { return out; };
    // Extract arg names from params_text
    let mut arg_names: str = "";
    let plen: i64 = str_len(params_text);
    let mut sp: i64 = 0;
    let mut first_arg: i64 = 1;
    while sp < plen {
        while sp < plen && (str_char_at(params_text, sp) == 32 || str_char_at(params_text, sp) == 9 || str_char_at(params_text, sp) == 44 || str_char_at(params_text, sp) == 10) { sp = sp + 1; };
        if sp >= plen { sp = plen + 1; }
        else {
            let an_start: i64 = sp;
            while sp < plen && (is_alnum(str_char_at(params_text, sp)) == 1 || str_char_at(params_text, sp) == 95) { sp = sp + 1; };
            if sp == an_start { sp = sp + 1; }
            else {
                let arg_name: str = str_substring(params_text, an_start, sp);
                if first_arg == 0 { arg_names = str_concat(arg_names, ", "); };
                arg_names = str_concat(arg_names, arg_name);
                first_arg = 0;
                // Skip until next comma at depth 0
                let mut adepth: i64 = 0;
                let mut at_comma: i64 = 0;
                while sp < plen && at_comma == 0 {
                    let cc: i64 = str_char_at(params_text, sp);
                    if cc == 40 || cc == 60 || cc == 91 { adepth = adepth + 1; sp = sp + 1; }
                    else if cc == 41 || cc == 62 || cc == 93 { adepth = adepth - 1; sp = sp + 1; }
                    else if cc == 44 && adepth == 0 { at_comma = 1; }
                    else { sp = sp + 1; };
                };
            };
        };
    };
    out.push(fn_name);
    out.push(params_text);
    out.push(ret_type);
    out.push(arg_names);
    out.push(body_open);
    out.push(q);
    return out;
}

fn expand_deadline(src: str) -> str {
    // Walk source line-by-line. When we see `#[deadline = N]` (after
    // optional doc comments), find the next `fn ...` declaration and
    // wrap it. Each rewrite replaces the original fn with two fns:
    //   __nuc_dl_inner_<idx>  — the original body
    //   <name>                — the wrapper that does start-cap +
    //                           inner-call + deadline_check + return
    let slen: i64 = str_len(src);
    let mut sb: i64 = sb_new();
    let mut p: i64 = 0;
    let mut idx: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        // Skip `//` line comments — `#[deadline = N]` text inside a
        // comment must not trigger wrapping (and previously caused an
        // infinite probe loop in the give-up branch below).
        let trimmed_line: str = strip_spaces(line);
        let tllen: i64 = str_len(trimmed_line);
        if tllen >= 2 && str_char_at(trimmed_line, 0) == 47 && str_char_at(trimmed_line, 1) == 47 {
            sb_append(sb, str_substring(src, p, eol));
            if eol < slen { sb_append(sb, "\n"); };
            p = eol + 1;
            continue;
        };
        let dl_value: i64 = dl_extract_int_value(line);
        if dl_value >= 0 {
            // Scan forward past blank lines + doc comments + other
            // attribute lines for the actual fn start. Use sentinel
            // -1 = still searching, >= 0 = found, -2 = give up; only
            // -1 keeps the loop going (older `< 0` form spun forever
            // on the give-up branch since -2 is also `< 0`).
            let mut probe: i64 = eol + 1;
            let mut found_fn: i64 = 0 - 1;
            while probe < slen && found_fn == 0 - 1 {
                let mut peol: i64 = probe;
                while peol < slen && str_char_at(src, peol) != 10 { peol = peol + 1; };
                let pline: str = str_substring(src, probe, peol);
                let trimmed: str = strip_spaces(pline);
                let tlen: i64 = str_len(trimmed);
                if tlen == 0 {
                    probe = peol + 1;
                } else if tlen >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                    probe = peol + 1;
                } else if tlen >= 1 && str_char_at(trimmed, 0) == 35 {
                    // Other #[...] attribute — skip
                    probe = peol + 1;
                } else if tlen >= 2 && str_eq(str_substring(trimmed, 0, 2), "fn") == 1 {
                    let mut fnpos: i64 = probe;
                    while fnpos < peol && (str_char_at(src, fnpos) == 32 || str_char_at(src, fnpos) == 9) { fnpos = fnpos + 1; };
                    found_fn = fnpos;
                } else if tlen >= 5 && str_eq(str_substring(trimmed, 0, 5), "pub f") == 1 {
                    let mut fnpos: i64 = probe;
                    while fnpos < peol && (str_char_at(src, fnpos) == 32 || str_char_at(src, fnpos) == 9) { fnpos = fnpos + 1; };
                    if fnpos + 4 <= peol && str_eq(str_substring(src, fnpos, fnpos + 4), "pub ") == 1 {
                        fnpos = fnpos + 4;
                    };
                    found_fn = fnpos;
                } else {
                    // Anything else — give up; emit original line.
                    found_fn = 0 - 2;
                };
            };
            if found_fn >= 0 {
                let info: Vec<i32> = dl_parse_fn_signature(src, found_fn, slen);
                if vec_len(info) > 0 {
                    let fn_name: str = vec_get(info, 0);
                    let params_text: str = vec_get(info, 1);
                    let ret_type: str = vec_get(info, 2);
                    let arg_names: str = vec_get(info, 3);
                    let body_open: i64 = vec_get(info, 4);
                    let body_end: i64 = vec_get(info, 5);
                    let inner_name: str = str_concat("__nuc_dl_inner_", str_concat(content_hash(fn_name), str_concat("_", str_from_int(idx))));
                    idx = idx + 1;
                    // Drop the #[deadline = N] line itself (do nothing for it).
                    // Emit everything between the line after the attribute
                    // and the start of the fn (which is empty/doc/other attrs)
                    // verbatim — preserves doc comments and other attributes.
                    sb_append(sb, str_substring(src, eol + 1, found_fn));
                    // Emit inner fn (original body, renamed).
                    sb_append(sb, "fn ");
                    sb_append(sb, inner_name);
                    sb_append(sb, "(");
                    sb_append(sb, params_text);
                    sb_append(sb, ") ");
                    if str_len(ret_type) > 0 {
                        sb_append(sb, "-> ");
                        sb_append(sb, ret_type);
                        sb_append(sb, " ");
                    };
                    sb_append(sb, str_substring(src, body_open, body_end));
                    sb_append(sb, "\n\n");
                    // Emit outer wrapper fn with original name.
                    sb_append(sb, "fn ");
                    sb_append(sb, fn_name);
                    sb_append(sb, "(");
                    sb_append(sb, params_text);
                    sb_append(sb, ") ");
                    if str_len(ret_type) > 0 {
                        sb_append(sb, "-> ");
                        sb_append(sb, ret_type);
                        sb_append(sb, " ");
                    };
                    sb_append(sb, "{\n");
                    sb_append(sb, "    let __nuc_dl_start: i64 = time_monotonic_us();\n");
                    if str_len(ret_type) > 0 && str_eq(ret_type, "void") == 0 {
                        sb_append(sb, "    let __nuc_dl_r: ");
                        sb_append(sb, ret_type);
                        sb_append(sb, " = ");
                        sb_append(sb, inner_name);
                        sb_append(sb, "(");
                        sb_append(sb, arg_names);
                        sb_append(sb, ");\n");
                        sb_append(sb, "    deadline_check(__nuc_dl_start, ");
                        sb_append(sb, str_from_int(dl_value));
                        sb_append(sb, ");\n");
                        sb_append(sb, "    return __nuc_dl_r;\n");
                    } else {
                        sb_append(sb, "    ");
                        sb_append(sb, inner_name);
                        sb_append(sb, "(");
                        sb_append(sb, arg_names);
                        sb_append(sb, ");\n");
                        sb_append(sb, "    deadline_check(__nuc_dl_start, ");
                        sb_append(sb, str_from_int(dl_value));
                        sb_append(sb, ");\n");
                    };
                    sb_append(sb, "}\n");
                    p = body_end;
                    continue;
                };
            };
        };
        // Default: emit the line as-is.
        sb_append(sb, str_substring(src, p, eol));
        if eol < slen { sb_append(sb, "\n"); };
        p = eol + 1;
    };
    return sb_to_str(sb);
}
//
// Resolver-level rewrite of two pieces of async syntax:
//   `async fn name(...)`  → `fn name(...)` (keyword strip)
//   `<ident>.await`        → `async_await(<ident>)`
//
// The runtime is committed to threads-only (RFC-0027 phase 1):
// `async_spawn(fn_ptr, arg)` returns an opaque task handle that
// runs the fn on a real OS thread; `async_await(handle)` joins
// the thread + returns the captured i64 result. No green-thread
// scheduler, no future polling — every async fn is a thread.
//
// `.await` is restricted to the simple `<ident>.await` form
// today. Complex receivers (`call().await`, `arr[0].await`)
// require a let-binding first. T2.8b will lift that restriction
// once we have a depth-aware backwards-receiver scanner.

fn expand_async_strip_keyword(src: str) -> str {
    // Identifier-aware walk. When we find an `async` identifier
    // followed by whitespace and `fn`, we drop the `async` keyword
    // (and the whitespace between it and `fn`). Anywhere else,
    // `async` passes through as a regular identifier.
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 {
                sb_append(sb, str_substring(src, p, p + 1));
                p = p + 1;
            };
        } else if c == 34 {
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append(sb, str_substring(src, p, p + 2));
                    p = p + 2;
                } else {
                    sb_append(sb, str_substring(src, p, p + 1));
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
        } else if is_alpha(c) == 1 || c == 95 {
            let id_start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let name: str = str_substring(src, id_start, p);
            if str_eq(name, "async") == 1 {
                // Look ahead past whitespace for `fn`.
                let mut peek: i64 = p;
                while peek < slen && (str_char_at(src, peek) == 32 || str_char_at(src, peek) == 9) { peek = peek + 1; };
                if peek + 2 <= slen && str_eq(str_substring(src, peek, peek + 2), "fn") == 1 {
                    let after_fn: i64 = peek + 2;
                    let next_after_fn: i64 = if after_fn < slen { str_char_at(src, after_fn) } else { 0 };
                    if next_after_fn == 32 || next_after_fn == 9 || next_after_fn == 10 {
                        // T3.8 (v0.3.7): RT-006 — async + RT attribute is
                        // rejected. Look back from `async` for a `#[no_alloc]`,
                        // `#[no_panic]`, `#[no_dyn]`, or `#[deadline...]`
                        // attribute on a preceding line (skipping blanks +
                        // doc comments). If found, emit a marker comment
                        // the diag pass picks up after expansion strips
                        // the `async` keyword for good.
                        let mut lb: i64 = id_start - 1;
                        let mut prev_attr_found: i64 = 0;
                        let mut stop: i64 = 0;
                        while lb >= 0 && stop == 0 && prev_attr_found == 0 {
                            let mut line_start: i64 = lb;
                            while line_start > 0 && str_char_at(src, line_start - 1) != 10 {
                                line_start = line_start - 1;
                            };
                            let line_end: i64 = lb + 1;
                            let line: str = str_substring(src, line_start, line_end);
                            let trimmed: str = strip_spaces(line);
                            let tlen: i64 = str_len(trimmed);
                            if tlen == 0 {
                                lb = line_start - 2;
                            } else if tlen >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                                lb = line_start - 2;
                            } else if str_eq(trimmed, "#[no_alloc]") == 1
                                  || str_eq(trimmed, "#[no_panic]") == 1
                                  || str_eq(trimmed, "#[no_dyn]") == 1 {
                                prev_attr_found = 1;
                            } else if tlen >= 11 && str_eq(str_substring(trimmed, 0, 11), "#[deadline ") == 1 {
                                prev_attr_found = 1;
                            } else if tlen >= 11 && str_eq(str_substring(trimmed, 0, 11), "#[deadline=") == 1 {
                                prev_attr_found = 1;
                            } else if tlen >= 1 && str_char_at(trimmed, 0) == 35 {
                                // Different #[...] attribute — keep looking.
                                lb = line_start - 2;
                            } else {
                                stop = 1;
                            };
                        };
                        if prev_attr_found == 1 {
                            // Read the fn name so the diag references it.
                            let mut np: i64 = after_fn;
                            while np < slen && (str_char_at(src, np) == 32 || str_char_at(src, np) == 9) { np = np + 1; };
                            let nn_start: i64 = np;
                            while np < slen && (is_alnum(str_char_at(src, np)) == 1 || str_char_at(src, np) == 95) { np = np + 1; };
                            let async_fn_name: str = if np > nn_start { str_substring(src, nn_start, np) } else { "<unknown>" };
                            // Prefix with `\n` so the marker always starts
                            // at column 0 — the diag scanner matches on the
                            // exact byte sequence "\n//__NUC6T:" which never
                            // appears mid-line in the s1 compiler source
                            // (the literal mentions in this file are either
                            // inside string literals or mid-line in prose).
                            sb_append(sb, "\n//__NUC6T:");
                            sb_append(sb, async_fn_name);
                            sb_append(sb, "\n");
                        };
                        // Drop `async ` — emit nothing for the keyword
                        // and fast-forward past the trailing whitespace.
                        p = peek;
                        continue;
                    };
                };
                // Not `async fn` — keep `async` as a regular identifier.
                sb_append(sb, name);
            } else {
                sb_append(sb, name);
            };
        } else {
            sb_append(sb, str_substring(src, p, p + 1));
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}

fn expand_async_await(src: str) -> str {
    // Walk identifier-aware. When we see `<ident>.await` (followed by
    // a non-ident-continuation char like ` `, `;`, `)`, etc.), rewrite
    // the chunk into `async_await(<ident>)`. Other `.await`s (`obj.x
    // .await`, `f().await`, etc.) pass through unchanged today —
    // T2.8b lifts the restriction.
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 {
                sb_append(sb, str_substring(src, p, p + 1));
                p = p + 1;
            };
        } else if c == 34 {
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append(sb, str_substring(src, p, p + 2));
                    p = p + 2;
                } else {
                    sb_append(sb, str_substring(src, p, p + 1));
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
        } else if is_alpha(c) == 1 || c == 95 {
            let id_start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let name: str = str_substring(src, id_start, p);
            // Look ahead for `.await`.
            if p + 6 <= slen && str_eq(str_substring(src, p, p + 6), ".await") == 1 {
                // Confirm `await` isn't actually part of a longer ident.
                let after: i64 = p + 6;
                let after_ch: i64 = if after < slen { str_char_at(src, after) } else { 0 };
                let is_ident_cont: i64 = if is_alnum(after_ch) == 1 || after_ch == 95 { 1 } else { 0 };
                if is_ident_cont == 0 {
                    sb_append(sb, "async_await(");
                    sb_append(sb, name);
                    sb_append(sb, ")");
                    p = p + 6;
                } else {
                    sb_append(sb, name);
                };
            } else {
                sb_append(sb, name);
            };
        } else {
            sb_append(sb, str_substring(src, p, p + 1));
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}

fn expand_async_syntax(src: str) -> str {
    return expand_async_await(expand_async_strip_keyword(src));
}

// ===== T2.3 (v0.2.349): closure literals (no-capture) =====
//
// Source-level rewriting of `|args| body` closure expressions in
// argument position. Each closure is lifted into a synthesized
// top-level fn (`__closure_<hash>_<idx>`), prepended to the merged
// source, and the closure expression is replaced with a bare
// identifier reference to that fn. The Vec iterator helpers
// (T2.2 dispatch) then receive a function-pointer value through
// the existing i64-cell convention — no runtime change required.
//
// Scope: NO-CAPTURE closures only (the body must not reference
// any name that would be undefined at the top-level scope).
// Closures with captures land in T2.3b once the runtime gains
// `(fn_ptr, env_ptr)` pair-call support.
//
// Disambiguation from bitwise `|`: closures are recognized only
// when `|` appears in an expression-arg position — immediately
// preceded (after whitespace) by `(`, `,`, `=`, `=>`, `[`, or
// the start of source. A `|` between values (e.g. `a | b`) stays
// a bitwise op.

fn close_is_arg_position_char(c: i64) -> i64 {
    // v0.3.78 (T2.1/2/3 partial close): textual closure-hoisting is
    // now FULLY DISABLED. Pre-v0.3.78, this preprocessor hoisted
    // closures appearing after `(` or `,` into top-level fns, which
    // produced cryptic `@captured` link errors when the closure body
    // referenced any outer-scope variables (the textual layer has
    // no scope info to detect captures).
    //
    // The AST closure-literal path (kind 42 in lower_expr at line
    // ~9915) handles captures correctly via the v0.3.72 capture_set/
    // capture_get runtime infrastructure. Routing arg-position
    // closures through the AST path makes `v.map(|x| x * factor)`
    // work the same way as `let f = |x| x * factor; v.map(f)` —
    // the documented v1 boundary closes.
    //
    // The legacy comment about "indirect-call dispatch" no longer
    // applies — the AST kind 42 path correctly emits ir_fn_ptr +
    // capture_set sequence, which works in arg position because
    // kind 8 (trait method call) lowers each arg via lower_expr,
    // and lower_expr handles kind 42 by returning the fn pointer
    // register with capture_set already emitted into the current
    // block.
    return 0;
}

fn close_parse_arg_list(src: str, start: i64, slen: i64) -> Vec<i32> {
    // Parses `<ident>(, <ident>)*` from start. Returns
    // [end_pos_at_closing_pipe_plus_1, name1, name2, ...].
    // Returns [0 - 1] on parse error.
    let mut out: Vec<i32> = Vec::new();
    out.push(0 - 1);
    let mut p: i64 = start;
    let mut first: i64 = 1;
    while p < slen && str_char_at(src, p) != 124 {
        // skip whitespace
        while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
        if p < slen && str_char_at(src, p) == 124 { p = p; }
        else if first == 0 {
            if p < slen && str_char_at(src, p) == 44 {
                p = p + 1;
                while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
            } else {
                return out;
            };
        };
        if p < slen && (is_alpha(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) {
            let name_start: i64 = p;
            let mut name_done: i64 = 0;
            while p < slen && name_done == 0 {
                let cc: i64 = str_char_at(src, p);
                if is_alnum(cc) == 1 || cc == 95 { p = p + 1; }
                else { name_done = 1; };
            };
            out.push(str_substring(src, name_start, p));
            first = 0;
            // Optional `: type` annotation — skip over it.
            while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
            if p < slen && str_char_at(src, p) == 58 {
                p = p + 1;
                while p < slen && str_char_at(src, p) != 44 && str_char_at(src, p) != 124 { p = p + 1; };
            };
        } else if p >= slen || str_char_at(src, p) != 124 {
            return out;
        };
    };
    if p >= slen || str_char_at(src, p) != 124 { return out; };
    vec_set(out, 0, p + 1);
    return out;
}

fn close_parse_body_end(src: str, start: i64, slen: i64) -> i64 {
    // Walk forward from start. Body ends at the first `,` or `)`
    // or `]` at the same paren/bracket depth as where we started.
    // String/char literals and line comments don't count.
    let mut p: i64 = start;
    let mut depth: i64 = 0;
    let mut in_dq: i64 = 0;
    let mut in_sq: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if in_dq == 1 {
            if c == 92 && p + 1 < slen { p = p + 2; }
            else if c == 34 { in_dq = 0; p = p + 1; }
            else { p = p + 1; };
        } else if in_sq == 1 {
            if c == 92 && p + 1 < slen { p = p + 2; }
            else if c == 39 { in_sq = 0; p = p + 1; }
            else { p = p + 1; };
        } else if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        } else if c == 34 { in_dq = 1; p = p + 1; }
        else if c == 39 { in_sq = 1; p = p + 1; }
        else if c == 40 || c == 91 || c == 123 { depth = depth + 1; p = p + 1; }
        else if c == 41 || c == 93 || c == 125 {
            if depth == 0 { return p; };
            depth = depth - 1;
            p = p + 1;
        } else if c == 44 && depth == 0 { return p; }
        else { p = p + 1; };
    };
    return p;
}

fn close_synthesize_fn(name: str, args: Vec<i32>, body_text: str) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "fn ");
    sb_append(sb, name);
    sb_append(sb, "(");
    let na: i64 = vec_len(args);
    let mut i: i64 = 0;
    while i < na {
        if i > 0 { sb_append(sb, ", "); };
        sb_append(sb, vec_get(args, i));
        sb_append(sb, ": i64");
        i = i + 1;
    };
    sb_append(sb, ") -> i64 {\n    return ");
    sb_append(sb, body_text);
    sb_append(sb, ";\n}\n\n");
    return sb_to_str(sb);
}

fn expand_closures(src: str) -> str {
    let mut prepend: i64 = sb_new();
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut last_non_ws: i64 = 0;
    let mut idx: i64 = 0;
    let src_id: str = content_hash(src);
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 {
                sb_append(sb, str_substring(src, p, p + 1));
                p = p + 1;
            };
            last_non_ws = 10;
        } else if c == 34 {
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append(sb, str_substring(src, p, p + 2));
                    p = p + 2;
                } else {
                    sb_append(sb, str_substring(src, p, p + 1));
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
            last_non_ws = 34;
        } else if c == 39 {
            sb_append(sb, "'");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append(sb, str_substring(src, p, p + 2));
                    p = p + 2;
                } else {
                    sb_append(sb, str_substring(src, p, p + 1));
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "'"); p = p + 1; };
            last_non_ws = 39;
        } else if c == 124 && close_is_arg_position_char(last_non_ws) == 1 {
            // Possible closure. Parse args between `|...|`.
            let arg_parse: Vec<i32> = close_parse_arg_list(src, p + 1, slen);
            let after_args: i64 = vec_get(arg_parse, 0);
            if after_args >= 0 {
                let mut args: Vec<i32> = Vec::new();
                let mut ai: i64 = 1;
                while ai < vec_len(arg_parse) {
                    args.push(vec_get(arg_parse, ai));
                    ai = ai + 1;
                };
                // Skip whitespace before body
                let mut bp: i64 = after_args;
                while bp < slen && (str_char_at(src, bp) == 32 || str_char_at(src, bp) == 9) { bp = bp + 1; };
                let body_end: i64 = close_parse_body_end(src, bp, slen);
                let body_text: str = str_substring(src, bp, body_end);
                // Synthesize fn name + emit
                let synth_name: str = str_concat("__closure_", str_concat(src_id, str_concat("_", str_from_int(idx))));
                idx = idx + 1;
                sb_append(prepend, close_synthesize_fn(synth_name, args, body_text));
                sb_append(sb, synth_name);
                p = body_end;
                last_non_ws = if p > 0 { str_char_at(src, p - 1) } else { 0 };
                continue;
            };
            // Not a closure — emit `|` as-is.
            sb_append(sb, "|");
            p = p + 1;
            last_non_ws = 124;
        } else if is_alpha(c) == 1 || c == 95 {
            let id_start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let name: str = str_substring(src, id_start, p);
            sb_append(sb, name);
            last_non_ws = str_char_at(name, str_len(name) - 1);
        } else {
            sb_append(sb, str_substring(src, p, p + 1));
            if c != 32 && c != 9 && c != 10 && c != 13 { last_non_ws = c; };
            p = p + 1;
        };
    };
    return str_concat(sb_to_str(prepend), sb_to_str(sb));
}

// ===== T2.6 (v0.2.346): format-string macro expansion =====
//
// Source-level rewriting of `println!(fmt, args...)`,
// `print!(fmt, args...)`, and `format!(fmt, args...)` calls into
// the equivalent str_concat + print/print_raw expression chain.
// Runs in the resolver, AFTER all imports are inlined and BEFORE
// the source is cached / lexed.
//
// Format spec syntax:
//   {}    — int_to_str(arg)   (default; the most common case)
//   {:i}  — int_to_str(arg)   (explicit alias)
//   {:s}  — arg as-is         (caller-provided str)
//   {:f}  — f64_to_str(arg)
//   {:b}  — bool_to_str(arg)
//   {{ }} — literal `{` / `}` (Rust convention)
//
// Modes:
//   println!  — wraps result in `print(...)`  (adds trailing \n via runtime)
//   print!    — wraps result in `print_raw(...)` (no trailing \n)
//   format!   — bare expression, returns str
//
// The expander is identifier- and quote-aware: skips `// ...`
// line comments, `"..."` string literals, and `'X'` char literals.
// `name!` after a `.` (method call) is left alone.

fn fmt_trim_ws(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut start: i64 = 0;
    let mut start_done: i64 = 0;
    while start < slen && start_done == 0 {
        let c: i64 = str_char_at(s, start);
        if c == 32 || c == 9 || c == 10 || c == 13 { start = start + 1; }
        else { start_done = 1; };
    };
    let mut end: i64 = slen;
    let mut end_done: i64 = 0;
    while end > start && end_done == 0 {
        let c: i64 = str_char_at(s, end - 1);
        if c == 32 || c == 9 || c == 10 || c == 13 { end = end - 1; }
        else { end_done = 1; };
    };
    return str_substring(s, start, end);
}

fn fmt_split_args(args_text: str) -> Vec<i32> {
    // Depth-aware comma split: respects (), [], {}, "...", '...'
    // so commas inside nested calls / strings don't split args.
    let mut parts: Vec<i32> = Vec::new();
    let slen: i64 = str_len(args_text);
    let mut start: i64 = 0;
    let mut p: i64 = 0;
    let mut depth: i64 = 0;
    let mut in_dq: i64 = 0;
    let mut in_sq: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(args_text, p);
        if in_dq == 1 {
            if c == 92 && p + 1 < slen { p = p + 1; }
            else if c == 34 { in_dq = 0; };
        } else if in_sq == 1 {
            if c == 92 && p + 1 < slen { p = p + 1; }
            else if c == 39 { in_sq = 0; };
        } else if c == 34 { in_dq = 1; }
        else if c == 39 { in_sq = 1; }
        else if c == 40 || c == 91 || c == 123 { depth = depth + 1; }
        else if c == 41 || c == 93 || c == 125 { depth = depth - 1; }
        else if c == 44 && depth == 0 {
            let part: str = fmt_trim_ws(str_substring(args_text, start, p));
            if str_len(part) > 0 { parts.push(part); };
            start = p + 1;
        };
        p = p + 1;
    };
    let tail: str = fmt_trim_ws(str_substring(args_text, start, slen));
    if str_len(tail) > 0 { parts.push(tail); };
    return parts;
}

fn fmt_strip_outer_quotes(s: str) -> str {
    let slen: i64 = str_len(s);
    if slen < 2 { return s; };
    if str_char_at(s, 0) != 34 { return s; };
    if str_char_at(s, slen - 1) != 34 { return s; };
    return str_substring(s, 1, slen - 1);
}

fn fmt_conversion_for_spec(spec: str, arg_expr: str) -> str {
    // spec is the contents of `{...}` after the `{` and before `}`,
    // i.e. `` for `{}`, `:s` for `{:s}`, etc.
    // v0.3.131: bare `{}` heuristic dispatch for the obvious-from-
    // textual-shape cases that adopters reach for. Pre-v0.3.131 bare
    // `{}` always called int_to_str, so `println!("{}", str_var)`
    // printed the string's POINTER ADDRESS and `println!("{}", f64_var)`
    // printed the i64 BIT PATTERN — silent miscompute on the most
    // common debug pattern. The heuristic only fires when the arg
    // expression is unambiguously typed by its textual shape:
    //   - quoted string literal (`"..."`)              → :s
    //   - decimal numeric literal (contains `.`)       → :f
    //   - call to a known float-returning helper
    //     (sqrt, exp, log, tanh, pow, sin, cos,
    //      f64_*, f32_*)                               → :f
    // For any other expression (variable refs to
    // unknown-typed locals, non-float fn calls, complex exprs) the
    // default falls back to int_to_str — adopters of typed `f64`
    // variables should still write `{:f}` explicitly. Documented
    // behavior; the heuristic only corrects the obvious cases.
    if str_eq(spec, "") == 1 {
        let alen: i64 = str_len(arg_expr);
        if alen >= 2 && str_char_at(arg_expr, 0) == 34 && str_char_at(arg_expr, alen - 1) == 34 {
            return arg_expr;
        };
        let mut has_dot: i64 = 0;
        let mut has_alpha: i64 = 0;
        let mut hi: i64 = 0;
        while hi < alen {
            let hc: i64 = str_char_at(arg_expr, hi);
            if hc == 46 { has_dot = 1; };
            if (hc >= 65 && hc <= 90) || (hc >= 97 && hc <= 122) || hc == 95 || hc == 40 || hc == 91 { has_alpha = 1; };
            hi = hi + 1;
        };
        if has_dot == 1 && has_alpha == 0 {
            return str_concat("f64_to_str(", str_concat(arg_expr, ")"));
        };
        if alen >= 5 && str_eq(str_substring(arg_expr, 0, 5), "sqrt(") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        if alen >= 4 && str_eq(str_substring(arg_expr, 0, 4), "exp(") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        if alen >= 4 && str_eq(str_substring(arg_expr, 0, 4), "log(") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        if alen >= 5 && str_eq(str_substring(arg_expr, 0, 5), "tanh(") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        if alen >= 4 && str_eq(str_substring(arg_expr, 0, 4), "f64_") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        if alen >= 4 && str_eq(str_substring(arg_expr, 0, 4), "f32_") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        // v0.3.132: also handle the v0.3.127 math_typed.nr typed
        // wrappers (sqrt_f64, exp_f64, log_f64, tanh_f64, sin_f64,
        // cos_f64, pow_f64) — they all end with `_f64(` or `_f32(`.
        // Scan once for a `_f64(` / `_f32(` substring; the call form
        // means the suffix is followed by `(`.
        let mut sub_i: i64 = 0;
        let mut found_typed: i64 = 0;
        while sub_i + 5 <= alen {
            let probe: str = str_substring(arg_expr, sub_i, sub_i + 5);
            if str_eq(probe, "_f64(") == 1 || str_eq(probe, "_f32(") == 1 {
                found_typed = 1;
                sub_i = alen;
            };
            sub_i = sub_i + 1;
        };
        if found_typed == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        return str_concat("int_to_str(", str_concat(arg_expr, ")"));
    };
    if str_eq(spec, ":i") == 1 { return str_concat("int_to_str(", str_concat(arg_expr, ")")); };
    if str_eq(spec, ":s") == 1 { return arg_expr; };
    if str_eq(spec, ":f") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
    if str_eq(spec, ":b") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
    // Unknown spec — pass through int_to_str for safety.
    return str_concat("int_to_str(", str_concat(arg_expr, ")"));
}

fn fmt_build_concat_chain(segments: Vec<i32>, parities: Vec<i32>) -> str {
    // segments[i] alternates between literal text (parity 0) and
    // pre-formed expression (parity 1). Build a right-fold of
    // str_concat(...) with the literals re-quoted.
    let nseg: i64 = vec_len(segments);
    if nseg == 0 { return "\"\""; };
    let mut chain: str = "";
    let mut k: i64 = nseg - 1;
    while k >= 0 {
        let part: str = vec_get(segments, k);
        let parity: i64 = vec_get(parities, k);
        let part_text: str = if parity == 0 {
            str_concat("\"", str_concat(part, "\""))
        } else { part };
        if str_len(chain) == 0 { chain = part_text; }
        else { chain = str_concat("str_concat(", str_concat(part_text, str_concat(", ", str_concat(chain, ")")))); };
        k = k - 1;
    };
    return chain;
}

fn fmt_build_expansion(args_text: str, mode: i64) -> str {
    // mode: 0 = println! → print(...)
    //       1 = format!  → bare str expression
    //       2 = print!   → print_raw(...)
    let parts: Vec<i32> = fmt_split_args(args_text);
    if vec_len(parts) == 0 {
        if mode == 0 { return "print(\"\")"; };
        if mode == 1 { return "\"\""; };
        return "print_raw(\"\")";
    };
    let fmt_lit: str = vec_get(parts, 0);
    let body: str = fmt_strip_outer_quotes(fmt_lit);
    let blen: i64 = str_len(body);
    let n_args: i64 = vec_len(parts) - 1;
    let mut segments: Vec<i32> = Vec::new();
    let mut parities: Vec<i32> = Vec::new();
    let mut current: i64 = sb_new();
    let mut i: i64 = 0;
    let mut arg_idx: i64 = 0;
    while i < blen {
        let c: i64 = str_char_at(body, i);
        if c == 123 && i + 1 < blen && str_char_at(body, i + 1) == 123 {
            sb_append(current, "{");
            i = i + 2;
        } else if c == 125 && i + 1 < blen && str_char_at(body, i + 1) == 125 {
            sb_append(current, "}");
            i = i + 2;
        } else if c == 123 {
            let mut spec_end: i64 = i + 1;
            while spec_end < blen && str_char_at(body, spec_end) != 125 { spec_end = spec_end + 1; };
            if spec_end >= blen {
                sb_append(current, str_substring(body, i, i + 1));
                i = i + 1;
            } else {
                let spec: str = str_substring(body, i + 1, spec_end);
                segments.push(sb_to_str(current));
                parities.push(0);
                current = sb_new();
                if arg_idx < n_args {
                    let arg_expr: str = vec_get(parts, arg_idx + 1);
                    segments.push(fmt_conversion_for_spec(spec, arg_expr));
                    parities.push(1);
                    arg_idx = arg_idx + 1;
                } else {
                    segments.push("\"<MISSING>\"");
                    parities.push(1);
                };
                i = spec_end + 1;
            };
        } else {
            sb_append(current, str_substring(body, i, i + 1));
            i = i + 1;
        };
    };
    segments.push(sb_to_str(current));
    parities.push(0);
    let chain: str = fmt_build_concat_chain(segments, parities);
    if mode == 0 { return str_concat("print(", str_concat(chain, ")")); };
    if mode == 1 { return chain; };
    return str_concat("print_raw(", str_concat(chain, ")"));
}

fn expand_format_macros(src: str) -> str {
    // Top-level T2.6 entry. Walks the merged source and replaces every
    // `<name>!(...)` macro call (where name is `println`/`print`/`format`)
    // with the desugared expression. Identifier- and quote-aware so a
    // `!` inside a string literal is left alone, and `obj.println!()`
    // (method-call form, currently unsupported anyway) doesn't trip.
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut last_non_ws: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 {
                sb_append(sb, str_substring(src, p, p + 1));
                p = p + 1;
            };
            last_non_ws = 10;
        } else if c == 34 {
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append(sb, str_substring(src, p, p + 2));
                    p = p + 2;
                } else {
                    sb_append(sb, str_substring(src, p, p + 1));
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
            last_non_ws = 34;
        } else if c == 39 {
            sb_append(sb, "'");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append(sb, str_substring(src, p, p + 2));
                    p = p + 2;
                } else {
                    sb_append(sb, str_substring(src, p, p + 1));
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "'"); p = p + 1; };
            last_non_ws = 39;
        } else if is_alpha(c) == 1 || c == 95 {
            let id_start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let name: str = str_substring(src, id_start, p);
            let preceded_by_dot: i64 = if last_non_ws == 46 { 1 } else { 0 };
            let mut handled: i64 = 0;
            // v0.3.94: strip `!` from `panic!` and `assert!` macro
            // calls. Pre-v0.3.94, `panic!("msg")` was parsed as
            // `panic` (ident) `!` (negate) `("msg")` and the runtime
            // call to __nucleor_panic was never emitted, failing at
            // clang link with `@panic undefined`. Same for assert!.
            // The textual rewrite drops the `!` so the existing fn
            // call dispatch handles them via the regular runtime
            // helpers (already registered as panic / assert at
            // line 2706 / 2635).
            if preceded_by_dot == 0 && p < slen && str_char_at(src, p) == 33 && p + 1 < slen && str_char_at(src, p + 1) == 40 {
                if str_eq(name, "panic") == 1 || str_eq(name, "assert") == 1
                   || str_eq(name, "assert_eq") == 1 || str_eq(name, "assert_ne") == 1
                   || str_eq(name, "dbg") == 1 || str_eq(name, "todo") == 1
                   || str_eq(name, "unimplemented") == 1 || str_eq(name, "unreachable") == 1 {
                    sb_append(sb, name);
                    p = p + 1;
                    continue;
                };
            };
            // v0.3.99: vec![…] macro. Pre-v0.3.99 the lexer split
            // `vec![a, b, c]` as `vec` (ident) + `!` (logical-NOT) +
            // `[a, b, c]` (array-literal). The let-init bound `vec`
            // (an undefined global → clang link error `@vec undefined`)
            // and the array-literal payload became dead code. Rewrite
            // textually to a block expression that constructs a Vec
            // and pushes each element. Empty `vec![]` collapses to
            // `Vec::new()` for cleaner IR. Top-level commas split the
            // arg list; nested (), [], {}, and "/'/' string literals
            // are tracked so `vec![(1,2), [3,4]]` works.
            if preceded_by_dot == 0 && p < slen && str_char_at(src, p) == 33 && p + 1 < slen && str_char_at(src, p + 1) == 91 {
                if str_eq(name, "vec") == 1 {
                    p = p + 2;
                    let lit_start: i64 = p;
                    let mut depth: i64 = 1;
                    let mut q: i64 = lit_start;
                    let mut in_dq: i64 = 0;
                    let mut in_sq: i64 = 0;
                    while q < slen && depth > 0 {
                        let ch: i64 = str_char_at(src, q);
                        if in_dq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 34 { in_dq = 0; };
                        } else if in_sq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 39 { in_sq = 0; };
                        } else if ch == 34 { in_dq = 1; }
                        else if ch == 39 { in_sq = 1; }
                        else if ch == 91 { depth = depth + 1; }
                        else if ch == 93 { depth = depth - 1; };
                        q = q + 1;
                    };
                    if depth == 0 {
                        let lit_end: i64 = q - 1;
                        let inner: str = str_substring(src, lit_start, lit_end);
                        let inner_expanded: str = expand_format_macros(inner);
                        let mut all_ws: i64 = 1;
                        let il: i64 = str_len(inner_expanded);
                        let mut ic: i64 = 0;
                        while ic < il {
                            let cw: i64 = str_char_at(inner_expanded, ic);
                            if cw != 32 && cw != 9 && cw != 10 && cw != 13 { all_ws = 0; ic = il; };
                            ic = ic + 1;
                        };
                        if all_ws == 1 {
                            sb_append(sb, "Vec::new()");
                        } else {
                            sb_append(sb, "{ let mut __nuc_vec: Vec<i64> = Vec::new(); ");
                            let mut sd: i64 = 0;
                            let mut s_dq: i64 = 0;
                            let mut s_sq: i64 = 0;
                            let mut item_start: i64 = 0;
                            let mut idx: i64 = 0;
                            while idx < il {
                                let ch2: i64 = str_char_at(inner_expanded, idx);
                                if s_dq == 1 {
                                    if ch2 == 92 && idx + 1 < il { idx = idx + 1; }
                                    else if ch2 == 34 { s_dq = 0; };
                                } else if s_sq == 1 {
                                    if ch2 == 92 && idx + 1 < il { idx = idx + 1; }
                                    else if ch2 == 39 { s_sq = 0; };
                                } else if ch2 == 34 { s_dq = 1; }
                                else if ch2 == 39 { s_sq = 1; }
                                else if ch2 == 40 || ch2 == 91 || ch2 == 123 { sd = sd + 1; }
                                else if ch2 == 41 || ch2 == 93 || ch2 == 125 { sd = sd - 1; }
                                else if ch2 == 44 && sd == 0 {
                                    let it: str = str_substring(inner_expanded, item_start, idx);
                                    sb_append(sb, "__nuc_vec.push(");
                                    sb_append(sb, it);
                                    sb_append(sb, "); ");
                                    item_start = idx + 1;
                                };
                                idx = idx + 1;
                            };
                            let last_it: str = str_substring(inner_expanded, item_start, il);
                            let lil: i64 = str_len(last_it);
                            let mut last_ws: i64 = 1;
                            let mut lic: i64 = 0;
                            while lic < lil {
                                let cw2: i64 = str_char_at(last_it, lic);
                                if cw2 != 32 && cw2 != 9 && cw2 != 10 && cw2 != 13 { last_ws = 0; lic = lil; };
                                lic = lic + 1;
                            };
                            if last_ws == 0 {
                                sb_append(sb, "__nuc_vec.push(");
                                sb_append(sb, last_it);
                                sb_append(sb, "); ");
                            };
                            sb_append(sb, "__nuc_vec }");
                        };
                        p = q;
                        last_non_ws = 41;
                        continue;
                    };
                };
            };
            if preceded_by_dot == 0 && p < slen && str_char_at(src, p) == 33 && p + 1 < slen && str_char_at(src, p + 1) == 40 {
                let mut mode: i64 = 0 - 1;
                if str_eq(name, "println") == 1 { mode = 0; };
                if str_eq(name, "format") == 1 { mode = 1; };
                if str_eq(name, "print") == 1 { mode = 2; };
                if mode >= 0 {
                    p = p + 2;
                    let args_start: i64 = p;
                    let mut depth: i64 = 1;
                    let mut q: i64 = args_start;
                    let mut in_dq: i64 = 0;
                    let mut in_sq: i64 = 0;
                    while q < slen && depth > 0 {
                        let ch: i64 = str_char_at(src, q);
                        if in_dq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 34 { in_dq = 0; };
                        } else if in_sq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 39 { in_sq = 0; };
                        } else if ch == 34 { in_dq = 1; }
                        else if ch == 39 { in_sq = 1; }
                        else if ch == 40 { depth = depth + 1; }
                        else if ch == 41 { depth = depth - 1; };
                        q = q + 1;
                    };
                    if depth == 0 {
                        let args_end: i64 = q - 1;
                        let args_text: str = str_substring(src, args_start, args_end);
                        let inner_expanded: str = expand_format_macros(args_text);
                        let expansion: str = fmt_build_expansion(inner_expanded, mode);
                        sb_append(sb, expansion);
                        p = q;
                        last_non_ws = 41;
                        handled = 1;
                    };
                };
            };
            if handled == 0 {
                sb_append(sb, name);
                last_non_ws = str_char_at(name, str_len(name) - 1);
            };
        } else {
            sb_append(sb, str_substring(src, p, p + 1));
            if c != 32 && c != 9 && c != 10 && c != 13 { last_non_ws = c; };
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}

// ===== T1.5c (v0.2.342): resolver-layer name privatization =====
//
// Opt-in cross-module visibility enforcement. When the resolver
// inlines an imported file F, we scan F for `pub fn` declarations.
// If F has at least one `pub fn`, we identify all NON-pub `fn`
// declarations in F and rewrite their identifier occurrences within
// F's source to `__priv_<file_id>__<name>`. Cross-module callers
// (whose source is NOT rewritten) then find no symbol for the
// private name and fail with an unresolved-name error — which is
// exactly the behavior `pub` is supposed to gate.
//
// Files with ZERO `pub fn` declarations get NO rewriting (opt-out
// for back-compat with pre-T1.5 rod files that have no `pub`
// markers but whose fns are de-facto callable from any importer).
//
// The token rewriter is identifier-aware: it skips string literals,
// char literals, and `// ...` line comments, and it does NOT rewrite
// identifiers preceded by `.` (field/method access). Everything else
// is conservative — keywords and shadowed locals are not in the
// private_names list so they're never substituted.

fn priv_extract_fn_decl_info(line: str) -> Vec<i32> {
    // Returns [name, is_pub] where is_pub = 1 for `pub fn name(`
    // (or `pub pure fn name(`), 0 for `fn name(` or `pure fn name(`,
    // and name = "" if line is not an fn declaration whose `(` is
    // on the same line. Uses strip_spaces so `pub  fn  name` etc.
    // all collapse to a stable prefix shape.
    let mut out: Vec<i32> = Vec::new();
    out.push("");
    out.push(0);
    let compact: str = strip_spaces(line);
    let clen: i64 = str_len(compact);
    let mut start: i64 = 0 - 1;
    let mut is_pub: i64 = 0;
    if clen >= 9 && str_eq(str_substring(compact, 0, 9), "pubpurefn") == 1 { start = 9; is_pub = 1; }
    else if clen >= 5 && str_eq(str_substring(compact, 0, 5), "pubfn") == 1 { start = 5; is_pub = 1; }
    else if clen >= 6 && str_eq(str_substring(compact, 0, 6), "purefn") == 1 { start = 6; is_pub = 0; }
    else if clen >= 2 && str_eq(str_substring(compact, 0, 2), "fn") == 1 { start = 2; is_pub = 0; };
    if start < 0 { return out; };
    if start >= clen { return out; };
    let mut stop: i64 = start;
    let mut done: i64 = 0;
    while stop < clen && done == 0 {
        let ch: i64 = str_char_at(compact, stop);
        if is_alnum(ch) == 1 || ch == 95 { stop = stop + 1; }
        else { done = 1; };
    };
    if stop <= start { return out; };
    // Require a `(` after the name (after stripping); rejects type
    // params like `fn ` followed by something non-callable. After
    // strip_spaces the `(` is always immediately after the name.
    if stop >= clen || str_char_at(compact, stop) != 40 { return out; };
    vec_set(out, 0, str_substring(compact, start, stop));
    vec_set(out, 1, is_pub);
    return out;
}

fn priv_collect_private_fn_names(source: str) -> Vec<i32> {
    // Two-phase scan: first collect all pub fn names, then collect
    // any fn name not in the pub set. Returns the empty Vec if the
    // source has no `pub fn` declarations at all (opt-out signal —
    // files without pub markers stay flat-namespace).
    let slen: i64 = str_len(source);
    let mut pub_names: Vec<i32> = Vec::new();
    let mut all_names: Vec<i32> = Vec::new();
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let name: str = vec_get(info, 0);
        if str_len(name) > 0 {
            let is_pub: i64 = vec_get(info, 1);
            if is_pub == 1 { priv_string_vec_push_unique(pub_names, name); };
            priv_string_vec_push_unique(all_names, name);
        };
        p = eol + 1;
    };
    let mut result: Vec<i32> = Vec::new();
    if vec_len(pub_names) == 0 { return result; };
    let n: i64 = vec_len(all_names);
    let mut i: i64 = 0;
    while i < n {
        let nm: str = vec_get(all_names, i);
        if priv_string_vec_contains(pub_names, nm) == 0 {
            // Don't privatize `main` — entry points should never be
            // mangled even in opt-in files. (Imported files with main
            // are unusual but possible; the compiler's existing
            // remove_main_decl handles dedupe.)
            if str_eq(nm, "main") == 0 { result.push(nm); };
        };
        i = i + 1;
    };
    return result;
}

fn priv_string_vec_contains(v: Vec<i32>, s: str) -> i64 {
    let n: i64 = vec_len(v);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(v, i), s) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn priv_string_vec_push_unique(v: Vec<i32>, s: str) -> i64 {
    if priv_string_vec_contains(v, s) == 0 { v.push(s); };
    return 0;
}

fn priv_build_global_registry(imported: Vec<i32>) -> Vec<i32> {
    // T1.5d (v0.2.343): build a flat registry of all private fn
    // names across every imported file. Returned shape is
    // alternating pairs [name1, origin_path1, name2, origin_path2, ...]
    // so the post-link diagnostic step can map an undefined-symbol
    // error back to its origin module without re-scanning sources.
    // Re-reads each imported file (small cost, O(imports)) rather
    // than threading the registry through the resolver — keeps the
    // existing resolve_source signature stable.
    let mut reg: Vec<i32> = Vec::new();
    let n: i64 = vec_len(imported);
    let mut i: i64 = 0;
    while i < n {
        let path: str = vec_get(imported, i);
        let isrc: str = file_read_string(path);
        if str_len(isrc) > 0 {
            let priv_names: Vec<i32> = priv_collect_private_fn_names(isrc);
            let m: i64 = vec_len(priv_names);
            let mut j: i64 = 0;
            while j < m {
                reg.push(vec_get(priv_names, j));
                reg.push(path);
                j = j + 1;
            };
        };
        i = i + 1;
    };
    return reg;
}

fn priv_lookup_origin(reg: Vec<i32>, name: str) -> str {
    let n: i64 = vec_len(reg);
    let mut i: i64 = 0;
    while i + 1 < n {
        if str_eq(vec_get(reg, i), name) == 1 { return vec_get(reg, i + 1); };
        i = i + 2;
    };
    return "";
}

fn priv_lift_link_errors(clang_output: str, reg: Vec<i32>) -> i64 {
    // Scan clang's stderr/stdout for "use of undefined value '@<name>'"
    // patterns. For each match whose <name> appears in the private
    // registry, emit a friendly MOD-003 diagnostic identifying the
    // origin module and suggesting `pub`. Returns the count of MOD-003
    // diagnostics emitted (so the caller can decide whether to suppress
    // the raw clang noise).
    let needle: str = "use of undefined value '@";
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(clang_output);
    let mut p: i64 = 0;
    let mut count: i64 = 0;
    let mut seen: Vec<i32> = Vec::new();
    while p + nlen <= slen {
        let mut matched: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen && matched == 1 {
            if str_char_at(clang_output, p + k) != str_char_at(needle, k) { matched = 0; };
            k = k + 1;
        };
        if matched == 1 {
            let name_start: i64 = p + nlen;
            let mut name_end: i64 = name_start;
            while name_end < slen && str_char_at(clang_output, name_end) != 39 { name_end = name_end + 1; };
            let name: str = str_substring(clang_output, name_start, name_end);
            let origin: str = priv_lookup_origin(reg, name);
            if str_len(origin) > 0 && priv_string_vec_contains(seen, name) == 0 {
                seen.push(name);
                print(str_concat("error[MOD-003]: cannot call private fn '", str_concat(name, "' from outside its declaring module")));
                print(str_concat("  --> declared in: ", origin));
                print("  hint: add `pub` to the fn declaration to expose it cross-module");
                count = count + 1;
            };
            p = name_end + 1;
        } else {
            p = p + 1;
        };
    };
    return count;
}

fn priv_apply_if_opted_in(isrc: str, path: str) -> str {
    // Resolver's entry point into T1.5c privatization. Returns the
    // input source unchanged unless the file has at least one
    // `pub fn` (the opt-in trigger). Caller pipes the returned
    // source straight into resolve_source_with_records — the
    // mangling has already happened, so the recursive resolver
    // call sees only mangled identifiers and won't re-mangle.
    let private_names: Vec<i32> = priv_collect_private_fn_names(isrc);
    if vec_len(private_names) == 0 { return isrc; };
    let file_id: str = content_hash(path);
    return priv_mangle_private_fns(isrc, file_id, private_names);
}

fn priv_mangle_private_fns(src: str, file_id: str, private_names: Vec<i32>) -> str {
    // Token-aware identifier substitution. Walks src char-by-char,
    // identifies identifier tokens (alpha/_ followed by alnum/_),
    // and rewrites identifiers whose value is in private_names to
    // __priv_<file_id>__<name>. Skips: "..." string literals,
    // 'X' char literals, // ... line comments. Does NOT rewrite
    // identifiers preceded by `.` (field/method access).
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut last_non_ws: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            // // line comment — copy through to newline
            while p < slen && str_char_at(src, p) != 10 {
                sb_append(sb, str_substring(src, p, p + 1));
                p = p + 1;
            };
            last_non_ws = 10;
        } else if c == 34 {
            // double-quoted string literal — copy with backslash escapes
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append(sb, str_substring(src, p, p + 2));
                    p = p + 2;
                } else {
                    sb_append(sb, str_substring(src, p, p + 1));
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
            last_non_ws = 34;
        } else if c == 39 {
            // single-quoted char literal
            sb_append(sb, "'");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append(sb, str_substring(src, p, p + 2));
                    p = p + 2;
                } else {
                    sb_append(sb, str_substring(src, p, p + 1));
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "'"); p = p + 1; };
            last_non_ws = 39;
        } else if is_alpha(c) == 1 || c == 95 {
            // Identifier start — gather to the end and decide whether
            // to mangle. Also reject: numeric prefixes (handled
            // because is_alpha rejects digits; identifiers can't
            // start with digit) and identifiers preceded by `.`
            // (struct field / method access).
            let start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let name: str = str_substring(src, start, p);
            let preceded_by_dot: i64 = if last_non_ws == 46 { 1 } else { 0 };
            if preceded_by_dot == 0 && priv_string_vec_contains(private_names, name) == 1 {
                sb_append(sb, "__priv_");
                sb_append(sb, file_id);
                sb_append(sb, "__");
                sb_append(sb, name);
            } else {
                sb_append(sb, name);
            };
            last_non_ws = str_char_at(name, str_len(name) - 1);
        } else {
            sb_append(sb, str_substring(src, p, p + 1));
            // Track last non-whitespace so we can detect `.X` field
            // accesses through intervening whitespace too.
            if c != 32 && c != 9 && c != 10 && c != 13 { last_non_ws = c; };
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}

fn content_hash(s: str) -> str {
    // DJB2 hash → hex string (simple content fingerprint)
    let slen: i64 = str_len(s);
    let mut hash: i64 = 5381;
    let mut i: i64 = 0;
    while i < slen {
        hash = hash * 33 + str_char_at(s, i);
        hash = hash - (hash / 4294967296) * 4294967296;
        i = i + 1;
    };
    let mut result: str = "";
    let mut val: i64 = hash;
    if val < 0 { val = 0 - val; };
    let hex_chars: str = "0123456789abcdef";
    let mut hi: i64 = 0;
    while hi < 8 {
        let digit: i64 = val - (val / 16) * 16;
        result = str_concat(str_substring(hex_chars, digit, digit + 1), result);
        val = val / 16;
        hi = hi + 1;
    };
    return result;
}

fn compiler_version_label() -> str {
    // v0.3.134: bumped from `0.2.0-v2`. The previous string was stuck
    // pre-OSS-launch and was confusing adopters comparing against the
    // CHANGELOG / git tag stream (the s1 source had been shipping
    // v0.3.x fixes for weeks). Now mirrors the latest tag at ship
    // time. Update when cutting each new release.
    return "0.3.136";
}

fn compiler_backend_label() -> str {
    return "llvm";
}

fn compiler_identity() -> str {
    return str_concat("nucleor ", str_concat(compiler_version_label(), str_concat(" (self-hosted, ", str_concat(compiler_backend_label(), " backend)"))));
}

fn cli_is_flag(arg: str) -> i64 {
    if str_len(arg) > 0 && str_char_at(arg, 0) == 45 { return 1; };
    return 0;
}

fn cmd_accepts_source(cmd: str) -> i64 {
    if str_eq(cmd, "build") || str_eq(cmd, "build-fast") || str_eq(cmd, "build-strict") || str_eq(cmd, "build-shared") || str_eq(cmd, "run") || str_eq(cmd, "emit") || str_eq(cmd, "build-wasm") || str_eq(cmd, "build-ptx") || str_eq(cmd, "check") || str_eq(cmd, "audit") || str_eq(cmd, "policy") || str_eq(cmd, "certify") || str_eq(cmd, "translate") || str_eq(cmd, "test") || str_eq(cmd, "bench") || str_eq(cmd, "summary") || str_eq(cmd, "impact") || str_eq(cmd, "query") || str_eq(cmd, "graph") || str_eq(cmd, "perf") || str_eq(cmd, "evidence") || str_eq(cmd, "abi") {
        return 1;
    };
    return 0;
}

fn cmd_allows_output_name(cmd: str) -> i64 {
    if str_eq(cmd, "build") || str_eq(cmd, "build-fast") || str_eq(cmd, "build-strict") || str_eq(cmd, "build-shared") || str_eq(cmd, "run") || str_eq(cmd, "emit") || str_eq(cmd, "build-wasm") || str_eq(cmd, "build-ptx") || str_eq(cmd, "certify") || str_eq(cmd, "test") || str_eq(cmd, "bench") {
        return 1;
    };
    return 0;
}

fn manifest_entry_path() -> str {
    let raw: str = file_read_string("Nucleor.toml");
    if str_len(raw) == 0 { return ""; };
    let compact: str = strip_spaces(raw);
    let key: str = "entry=\"";
    let clen: i64 = str_len(compact);
    let klen: i64 = str_len(key);
    let mut p: i64 = 0;
    while p + klen <= clen {
        if str_eq_at(compact, p, key) == 1 {
            let start: i64 = p + klen;
            let mut end: i64 = start;
            while end < clen && str_char_at(compact, end) != 34 { end = end + 1; };
            return sanitize(str_substring(compact, start, end));
        };
        p = p + 1;
    };
    return "";
}

fn core_shell_quote(path: str) -> str {
    return str_concat("\"", str_concat(path, "\""));
}
fn run_external_tool(argc: i64) -> i64 {
    let raw_exe_dir: str = trim_trailing_sep(extract_dir(args_get(0)));
    let mut exe_dir: str = raw_exe_dir;
    if str_len(exe_dir) == 0 { exe_dir = "target"; };
    let tool_path: str = sanitize(str_concat(exe_dir, "\\nucleor_tools.exe"));
    let repo_tool_path: str = ".\\target\\nucleor_tools.exe";
    let local_tool_path: str = "nucleor_tools.exe";
    let mut tool_args: str = "";
    let mut i: i64 = 1;
    while i < argc {
        tool_args = str_concat(tool_args, str_concat(" ", core_shell_quote(args_get(i))));
        i = i + 1;
    };
    let mut cmd: str = str_concat("if exist ", core_shell_quote(repo_tool_path));
    cmd = str_concat(cmd, str_concat(" (", str_concat(core_shell_quote(repo_tool_path), str_concat(tool_args, ")"))));
    cmd = str_concat(cmd, str_concat(" else if exist ", core_shell_quote(local_tool_path)));
    cmd = str_concat(cmd, str_concat(" (", str_concat(core_shell_quote(local_tool_path), str_concat(tool_args, ")"))));
    cmd = str_concat(cmd, str_concat(" else (", str_concat(core_shell_quote(tool_path), str_concat(tool_args, ")"))));
    return system(cmd);
}

fn run_explain_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_bootstrap_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_stage_dump_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_build_shared_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_summary_command(src_path: str, argc: i64, arg_start: i64) -> i64 { return run_external_tool(argc); }
fn run_query_command(src_path: str) -> i64 { return run_external_tool(args_count()); }
fn run_abi_command(src_path: str, argc: i64, arg_start: i64) -> i64 { return run_external_tool(argc); }
fn run_evidence_command(src_path: str) -> i64 { return run_external_tool(args_count()); }
fn run_lock_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_publish_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_registry_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_install_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_fix_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_doc_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_impact_command(src_path: str, argc: i64, arg_start: i64) -> i64 { return run_external_tool(argc); }
fn run_graph_command(src_path: str, argc: i64, arg_start: i64) -> i64 { return run_external_tool(argc); }
fn run_profile_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_sage_command(argc: i64) -> i64 { return run_external_tool(argc); }
fn run_perf_command(src_path: str, argc: i64, arg_start: i64) -> i64 { return run_external_tool(argc); }

// T1.1 Phase 9: map a Nucleor type name to its C equivalent for
// header generation. Returns "" for types without a clear C
// mapping (caller skips those extern decls).
fn nr_type_to_c(t: str) -> str {
    let b: str = type_base_name(t);
    if str_eq(b, "i8") == 1 { return "int8_t"; };
    if str_eq(b, "i16") == 1 { return "int16_t"; };
    if str_eq(b, "i32") == 1 { return "int32_t"; };
    if str_eq(b, "i64") == 1 { return "int64_t"; };
    if str_eq(b, "isize") == 1 { return "intptr_t"; };
    if str_eq(b, "u8") == 1 { return "uint8_t"; };
    if str_eq(b, "u16") == 1 { return "uint16_t"; };
    if str_eq(b, "u32") == 1 { return "uint32_t"; };
    if str_eq(b, "u64") == 1 { return "uint64_t"; };
    if str_eq(b, "usize") == 1 { return "uintptr_t"; };
    if str_eq(b, "f32") == 1 { return "float"; };
    if str_eq(b, "f64") == 1 { return "double"; };
    if str_eq(b, "bool") == 1 { return "bool"; };
    if str_eq(b, "char") == 1 { return "uint32_t"; };
    if str_eq(b, "ptr") == 1 { return "void*"; };
    if str_eq(b, "str") == 1 { return "const char*"; };
    if str_eq(b, "void") == 1 { return "void"; };
    return "";
}

fn nr_type_to_c_with_structs(t: str, repr_c_structs: Vec<i32>) -> str {
    // T1.6 (v0.2.345): C ABI struct-by-value support. If the type
    // name matches a known #[repr(C)] struct, emit the struct name
    // directly so callers get the typedef; otherwise fall through to
    // the primitive table. Returns "" for non-repr(C) struct names
    // (caller emits CXX-004 — types crossing the bridge must have a
    // C-stable layout).
    let primitive: str = nr_type_to_c(t);
    if str_len(primitive) > 0 { return primitive; };
    let b: str = type_base_name(t);
    let n: i64 = vec_len(repr_c_structs);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(repr_c_structs, i), b) == 1 { return b; };
        i = i + 1;
    };
    return "";
}

fn collect_repr_c_structs(src: str) -> Vec<i32> {
    // T1.6 (v0.2.345): walk the source text identifying every
    // struct declaration whose IMMEDIATELY-preceding non-blank
    // line (skipping doc-comments and whitespace) is exactly
    // `#[repr(C)]`. Strict line-precedence rules out the
    // lookback false-positive in `struct_repr`, where a 200-char
    // window happily picked up the previous struct's attribute.
    // Returns a Vec<str> of struct names (no duplicates).
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    // Pre-pass: build line offsets so we can look at the previous
    // non-blank line cheaply.
    let mut line_starts: Vec<i32> = Vec::new();
    line_starts.push(0);
    let mut s: i64 = 0;
    while s < slen {
        if str_char_at(src, s) == 10 && s + 1 < slen { line_starts.push(s + 1); };
        s = s + 1;
    };
    let nlines: i64 = vec_len(line_starts);
    let mut li: i64 = 0;
    while li < nlines {
        let p: i64 = vec_get(line_starts, li);
        let next_p: i64 = if li + 1 < nlines { vec_get(line_starts, li + 1) - 1 } else { slen };
        let mut eol: i64 = if next_p < slen { next_p } else { slen };
        // strip trailing CR if present (CRLF tolerant)
        if eol > p && str_char_at(src, eol - 1) == 13 { eol = eol - 1; };
        let line: str = str_substring(src, p, eol);
        let llen: i64 = str_len(line);
        let mut lp: i64 = 0;
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        // Match `struct NAME` (optionally `pub struct NAME`)
        let mut after_kw: i64 = 0 - 1;
        if lp + 7 <= llen && str_eq_at(line, lp, "struct ") == 1 { after_kw = lp + 7; };
        if after_kw < 0 && lp + 11 <= llen && str_eq_at(line, lp, "pub struct ") == 1 { after_kw = lp + 11; };
        if after_kw >= 0 {
            let name_start: i64 = after_kw;
            let mut q: i64 = name_start;
            while q < llen && (is_alnum(str_char_at(line, q)) == 1 || str_char_at(line, q) == 95) { q = q + 1; };
            if q > name_start {
                let name: str = str_substring(line, name_start, q);
                // Look back at preceding non-blank, non-/// lines
                // until we either find an attribute or hit something
                // that decisively isn't an attribute (struct decl,
                // closing brace, source start).
                let mut prev_li: i64 = li - 1;
                let mut found: i64 = 0;
                while prev_li >= 0 && found == 0 {
                    let pp: i64 = vec_get(line_starts, prev_li);
                    let mut pend: i64 = if prev_li + 1 < nlines { vec_get(line_starts, prev_li + 1) - 1 } else { slen };
                    if pend > pp && str_char_at(src, pend - 1) == 13 { pend = pend - 1; };
                    let pline: str = str_substring(src, pp, pend);
                    let trimmed: str = strip_spaces(pline);
                    if str_len(trimmed) == 0 {
                        prev_li = prev_li - 1;
                    } else if str_len(trimmed) >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                        prev_li = prev_li - 1;
                    } else if str_eq(trimmed, "#[repr(C)]") == 1 {
                        found = 1;
                    } else {
                        // Anything else terminates the lookback —
                        // attribute didn't apply to this struct.
                        prev_li = 0 - 1;
                    };
                };
                if found == 1 {
                    let mut already: i64 = 0;
                    let mut k: i64 = 0;
                    while k < vec_len(out) {
                        if str_eq(vec_get(out, k), name) == 1 { already = 1; };
                        k = k + 1;
                    };
                    if already == 0 { out.push(name); };
                };
            };
        };
        li = li + 1;
    };
    return out;
}

fn extract_struct_fields_native(src: str, struct_name: str) -> Vec<i32> {
    // T1.6 (v0.2.345): pull the field list of a struct as alternating
    // [name1, type1, name2, type2, ...]. Uses brace-balanced source
    // scanning starting at the `struct NAME {` declaration. Returns
    // empty Vec if the struct is missing or syntactically malformed.
    let mut out: Vec<i32> = Vec::new();
    let needle: str = str_concat("struct ", struct_name);
    let pos: i64 = source_find(src, needle);
    if pos < 0 { return out; };
    let slen: i64 = str_len(src);
    let mut p: i64 = pos + str_len(needle);
    while p < slen && str_char_at(src, p) != 123 { p = p + 1; };
    if p >= slen { return out; };
    p = p + 1;
    let mut depth: i64 = 1;
    let body_start: i64 = p;
    let mut body_end: i64 = p;
    while p < slen && depth > 0 {
        let ch: i64 = str_char_at(src, p);
        if ch == 123 { depth = depth + 1; }
        else if ch == 125 { depth = depth - 1; if depth == 0 { body_end = p; }; };
        p = p + 1;
    };
    if depth != 0 { return out; };
    // Walk fields: `name: type,` (commas optional after last)
    let body: str = str_substring(src, body_start, body_end);
    let blen: i64 = str_len(body);
    let mut q: i64 = 0;
    while q < blen {
        // skip whitespace
        while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9 || str_char_at(body, q) == 10 || str_char_at(body, q) == 13) { q = q + 1; };
        if q >= blen { q = blen + 1; }
        else {
            // skip optional `pub ` field-visibility prefix
            if q + 4 <= blen && str_eq_at(body, q, "pub ") == 1 { q = q + 4; };
            while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9) { q = q + 1; };
            // field name
            let name_start: i64 = q;
            while q < blen && (is_alnum(str_char_at(body, q)) == 1 || str_char_at(body, q) == 95) { q = q + 1; };
            if q == name_start { q = blen + 1; }
            else {
                let fname: str = str_substring(body, name_start, q);
                while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9) { q = q + 1; };
                if q >= blen || str_char_at(body, q) != 58 { q = blen + 1; }
                else {
                    q = q + 1;
                    while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9) { q = q + 1; };
                    let type_start: i64 = q;
                    while q < blen && str_char_at(body, q) != 44 && str_char_at(body, q) != 10 { q = q + 1; };
                    let ftype: str = strip_spaces(str_substring(body, type_start, q));
                    if str_len(fname) > 0 && str_len(ftype) > 0 {
                        out.push(fname);
                        out.push(ftype);
                    };
                    if q < blen && str_char_at(body, q) == 44 { q = q + 1; };
                };
            };
        };
    };
    return out;
}

// T3.4 (v0.3.4): collect Nucleor fns marked `#[export]` so
// `nuc gen-headers` emits C forward declarations alongside the
// `extern fn` imports and `#[repr(C)]` typedefs. Lets external
// C/C++ code (robotics middleware, embedded firmware) call into
// Nucleor-compiled kernels through the unmangled symbol that
// the LLVM IR already emits.
//
// Returns alternating [fn_name, args_c_decl, c_rtype, ...].
// args_c_decl is the C-formatted parameter list ("int64_t a, double b")
// or "void" for no-args; c_rtype is "void" if the fn has no `-> ret`.
// Skips fns whose signature contains a non-FFI-safe type.
fn collect_export_fns_and_sigs(src: str, repr_c: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut line_starts: Vec<i32> = Vec::new();
    line_starts.push(0);
    let mut s: i64 = 0;
    while s < slen {
        if str_char_at(src, s) == 10 && s + 1 < slen { line_starts.push(s + 1); };
        s = s + 1;
    };
    let nlines: i64 = vec_len(line_starts);
    let mut li: i64 = 0;
    while li < nlines {
        let p: i64 = vec_get(line_starts, li);
        let mut eol: i64 = if li + 1 < nlines { vec_get(line_starts, li + 1) - 1 } else { slen };
        if eol > p && str_char_at(src, eol - 1) == 13 { eol = eol - 1; };
        let line: str = str_substring(src, p, eol);
        let llen: i64 = str_len(line);
        let mut lp: i64 = 0;
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        let mut after_kw: i64 = 0 - 1;
        if lp + 3 <= llen && str_eq_at(line, lp, "fn ") == 1 { after_kw = lp + 3; };
        if after_kw < 0 && lp + 7 <= llen && str_eq_at(line, lp, "pub fn ") == 1 { after_kw = lp + 7; };
        if after_kw >= 0 {
            // Look back at preceding non-blank, non-/// lines for #[export].
            let mut prev_li: i64 = li - 1;
            let mut found: i64 = 0;
            while prev_li >= 0 && found == 0 {
                let pp: i64 = vec_get(line_starts, prev_li);
                let mut pend: i64 = if prev_li + 1 < nlines { vec_get(line_starts, prev_li + 1) - 1 } else { slen };
                if pend > pp && str_char_at(src, pend - 1) == 13 { pend = pend - 1; };
                let pline: str = str_substring(src, pp, pend);
                let trimmed: str = strip_spaces(pline);
                let tlen: i64 = str_len(trimmed);
                if tlen == 0 {
                    prev_li = prev_li - 1;
                } else if tlen >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                    prev_li = prev_li - 1;
                } else if str_eq(trimmed, "#[export]") == 1 {
                    found = 1;
                } else if tlen >= 1 && str_char_at(trimmed, 0) == 35 {
                    // Other #[...] attribute (e.g. #[no_alloc], #[deadline]) — skip
                    prev_li = prev_li - 1;
                } else {
                    prev_li = 0 - 1;
                };
            };
            if found == 1 {
                // Read fn name.
                let name_start: i64 = after_kw;
                let mut q: i64 = name_start;
                while q < llen && (is_alnum(str_char_at(line, q)) == 1 || str_char_at(line, q) == 95) { q = q + 1; };
                if q > name_start {
                    let fname: str = str_substring(line, name_start, q);
                    // Expect (
                    while q < llen && str_char_at(line, q) != 40 { q = q + 1; };
                    if q < llen {
                        q = q + 1;
                        // Collect args until ).
                        let mut args_buf: i64 = sb_new();
                        let mut narg: i64 = 0;
                        let mut bad: i64 = 0;
                        while q < llen && str_char_at(line, q) != 41 && bad == 0 {
                            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9 || str_char_at(line, q) == 44) { q = q + 1; };
                            if q >= llen || str_char_at(line, q) == 41 { continue; };
                            let an_start: i64 = q;
                            while q < llen && str_char_at(line, q) != 58 && str_char_at(line, q) != 41 { q = q + 1; };
                            let an_raw: str = str_substring(line, an_start, q);
                            if q >= llen || str_char_at(line, q) != 58 { bad = 1; continue; };
                            q = q + 1;
                            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
                            let at_start: i64 = q;
                            while q < llen && str_char_at(line, q) != 44 && str_char_at(line, q) != 41 { q = q + 1; };
                            let at_raw: str = str_substring(line, at_start, q);
                            let arg_name: str = strip_spaces(an_raw);
                            let arg_type: str = strip_spaces(at_raw);
                            let c_type: str = nr_type_to_c_with_structs(arg_type, repr_c);
                            if str_len(c_type) == 0 { bad = 1; continue; };
                            if narg > 0 { sb_append(args_buf, ", "); };
                            sb_append(args_buf, c_type);
                            sb_append(args_buf, " ");
                            sb_append(args_buf, arg_name);
                            narg = narg + 1;
                        };
                        if bad == 0 {
                            if q < llen { q = q + 1; };
                            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
                            let mut rtype: str = "void";
                            if q + 1 < llen && str_char_at(line, q) == 45 && str_char_at(line, q + 1) == 62 {
                                q = q + 2;
                                while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
                                let rt_start: i64 = q;
                                while q < llen && str_char_at(line, q) != 32 && str_char_at(line, q) != 9 && str_char_at(line, q) != 123 { q = q + 1; };
                                rtype = str_substring(line, rt_start, q);
                            };
                            let c_rtype: str = nr_type_to_c_with_structs(rtype, repr_c);
                            if str_len(c_rtype) > 0 {
                                let args_str: str = if narg == 0 { "void" } else { sb_to_str(args_buf) };
                                out.push(fname);
                                out.push(args_str);
                                out.push(c_rtype);
                            };
                        };
                    };
                };
            };
        };
        li = li + 1;
    };
    return out;
}

// T1.1 Phase 9: nuc gen-headers <input.nr> [-o <out.h>]
//
// Scans an .nr source file for `extern fn` declarations and emits a
// matching C header. Useful for cross-language linking when an
// external C/C++ project wants to call Nucleor-compiled functions
// (or vice-versa) through a stable ABI.
//
// Implementation is a deliberate text-scan rather than a full
// parser invocation: keeps the subcommand standalone, lets it
// run on partial / not-yet-compilable .nr files, and matches
// the file-line convention used by the rest of the toolchain.
fn run_gen_headers_command(argc: i64) -> i64 {
    if argc < 3 {
        print("usage: nuc gen-headers <input.nr> [-o <out.h>]");
        return 1;
    };
    let in_path: str = args_get(2);
    let mut out_path: str = "";
    let mut i: i64 = 3;
    while i < argc {
        let a: str = args_get(i);
        if str_eq(a, "-o") == 1 && (i + 1) < argc {
            out_path = args_get(i + 1);
            i = i + 2;
        } else {
            i = i + 1;
        };
    };
    if str_len(out_path) == 0 {
        // Default: replace .nr with .h
        let plen: i64 = str_len(in_path);
        if plen > 3 && str_eq_at(in_path, plen - 3, ".nr") == 1 {
            out_path = str_concat(str_substring(in_path, 0, plen - 3), ".h");
        } else {
            out_path = str_concat(in_path, ".h");
        };
    };
    let src: str = file_read_string(in_path);
    if str_len(src) == 0 {
        print(str_concat("nuc gen-headers: cannot read ", in_path));
        return 1;
    };
    let mut out: i64 = sb_new();
    sb_append(out, "// Generated by `nuc gen-headers` from ");
    sb_append(out, in_path);
    sb_append(out, "\n// Edits will be lost; regenerate after extern fn / #[repr(C)] struct changes.\n");
    sb_append(out, "#ifndef NUCLEOR_GEN_HEADERS_H\n");
    sb_append(out, "#define NUCLEOR_GEN_HEADERS_H\n");
    sb_append(out, "#include <stdint.h>\n");
    sb_append(out, "#include <stdbool.h>\n\n");
    sb_append(out, "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n");

    // T1.6 (v0.2.345): emit C `typedef struct { ... } Name;`
    // declarations for every #[repr(C)] struct in the source.
    // Field types must be primitives or other repr(C) struct names —
    // otherwise we silently skip the offending field rather than
    // emit an invalid C declaration. CXX-004 fires elsewhere (in
    // strict-mode build) when a non-repr(C) struct appears in an
    // extern fn signature.
    let repr_c: Vec<i32> = collect_repr_c_structs(src);
    let mut emitted_structs: i64 = 0;
    let mut si: i64 = 0;
    while si < vec_len(repr_c) {
        let sname: str = vec_get(repr_c, si);
        let fields: Vec<i32> = extract_struct_fields_native(src, sname);
        let fc: i64 = vec_len(fields);
        if fc >= 2 {
            sb_append(out, "typedef struct ");
            sb_append(out, sname);
            sb_append(out, " {\n");
            let mut fi: i64 = 0;
            while fi + 1 < fc {
                let fname: str = vec_get(fields, fi);
                let ftype: str = vec_get(fields, fi + 1);
                let ftype_c: str = nr_type_to_c_with_structs(ftype, repr_c);
                if str_len(ftype_c) > 0 {
                    sb_append(out, "    ");
                    sb_append(out, ftype_c);
                    sb_append(out, " ");
                    sb_append(out, fname);
                    sb_append(out, ";\n");
                };
                fi = fi + 2;
            };
            sb_append(out, "} ");
            sb_append(out, sname);
            sb_append(out, ";\n\n");
            emitted_structs = emitted_structs + 1;
        };
        si = si + 1;
    };

    // Walk source line by line for `extern fn NAME(...) -> RT;`
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut emitted: i64 = 0;
    while p < slen {
        // Find end of line.
        let line_start: i64 = p;
        while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        let line: str = str_substring(src, line_start, p);
        if p < slen { p = p + 1; };
        // Skip leading whitespace for prefix check.
        let llen: i64 = str_len(line);
        let mut lstart: i64 = 0;
        while lstart < llen && (str_char_at(line, lstart) == 32 || str_char_at(line, lstart) == 9) {
            lstart = lstart + 1;
        };
        // Match prefix "extern fn ".
        if lstart + 10 > llen { continue; };
        if str_eq_at(line, lstart, "extern fn ") == 0 { continue; };
        // Parse the line.
        let mut q: i64 = lstart + 10;
        // name
        let name_start: i64 = q;
        while q < llen && (str_char_at(line, q) == 95 || is_alnum(str_char_at(line, q)) == 1) { q = q + 1; };
        let fname: str = str_substring(line, name_start, q);
        if str_len(fname) == 0 { continue; };
        // expect (
        while q < llen && str_char_at(line, q) != 40 { q = q + 1; };
        if q >= llen { continue; };
        q = q + 1; // past (
        // collect args until )
        let mut args_buf: i64 = sb_new();
        let mut narg: i64 = 0;
        let mut bad_arg: i64 = 0;
        while q < llen && str_char_at(line, q) != 41 {
            // skip whitespace, comma
            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9 || str_char_at(line, q) == 44) { q = q + 1; };
            if q >= llen || str_char_at(line, q) == 41 { continue; };
            // arg name
            let an_start: i64 = q;
            while q < llen && str_char_at(line, q) != 58 && str_char_at(line, q) != 41 { q = q + 1; };
            let an_raw: str = str_substring(line, an_start, q);
            if q >= llen || str_char_at(line, q) != 58 { bad_arg = 1; q = llen; continue; };
            q = q + 1; // past :
            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
            let at_start: i64 = q;
            while q < llen && str_char_at(line, q) != 44 && str_char_at(line, q) != 41 { q = q + 1; };
            let at_raw: str = str_substring(line, at_start, q);
            // trim trailing whitespace
            let arg_name: str = strip_spaces(an_raw);
            let arg_type: str = strip_spaces(at_raw);
            // T1.6 (v0.2.345): struct-by-value FFI — accept any
            // #[repr(C)] struct name (already collected above).
            let c_type: str = nr_type_to_c_with_structs(arg_type, repr_c);
            if str_len(c_type) == 0 { bad_arg = 1; continue; };
            if narg > 0 { sb_append(args_buf, ", "); };
            sb_append(args_buf, c_type);
            sb_append(args_buf, " ");
            sb_append(args_buf, arg_name);
            narg = narg + 1;
        };
        if bad_arg == 1 { continue; };
        if q < llen { q = q + 1; }; // past )
        // expect "-> RTYPE;"
        let mut rtype: str = "void";
        while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
        if q + 1 < llen && str_char_at(line, q) == 45 && str_char_at(line, q + 1) == 62 {
            q = q + 2;
            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
            let rt_start: i64 = q;
            while q < llen && str_char_at(line, q) != 59 && str_char_at(line, q) != 32 && str_char_at(line, q) != 9 { q = q + 1; };
            rtype = str_substring(line, rt_start, q);
        };
        let c_rtype: str = nr_type_to_c_with_structs(rtype, repr_c);
        if str_len(c_rtype) == 0 { continue; };
        sb_append(out, c_rtype);
        sb_append(out, " ");
        sb_append(out, fname);
        sb_append(out, "(");
        if narg == 0 { sb_append(out, "void"); }
        else { sb_append(out, sb_to_str(args_buf)); };
        sb_append(out, ");\n");
        emitted = emitted + 1;
    };
    // T3.4 (v0.3.4): emit C decls for `#[export]`-marked Nucleor
    // fns. The LLVM IR already uses the unmangled symbol so the
    // header is the only missing piece for C-side callers.
    let exports: Vec<i32> = collect_export_fns_and_sigs(src, repr_c);
    let exn: i64 = vec_len(exports);
    let mut emitted_exports: i64 = 0;
    let mut ei: i64 = 0;
    if exn >= 3 {
        sb_append(out, "// === #[export] — Nucleor fns callable from C ===\n");
    };
    while ei + 2 < exn {
        let xn: str = vec_get(exports, ei);
        let xa: str = vec_get(exports, ei + 1);
        let xr: str = vec_get(exports, ei + 2);
        sb_append(out, xr);
        sb_append(out, " ");
        sb_append(out, xn);
        sb_append(out, "(");
        sb_append(out, xa);
        sb_append(out, ");\n");
        emitted_exports = emitted_exports + 1;
        ei = ei + 3;
    };
    sb_append(out, "\n#ifdef __cplusplus\n}\n#endif\n");
    sb_append(out, "#endif // NUCLEOR_GEN_HEADERS_H\n");
    let _ = file_write_string(out_path, sb_to_str(out));
    let extern_count: str = str_from_int(emitted);
    let export_count: str = str_from_int(emitted_exports);
    if emitted_structs > 0 {
        print(str_concat("nuc gen-headers: wrote ", str_concat(str_from_int(emitted_structs), str_concat(" #[repr(C)] struct(s), ", str_concat(extern_count, str_concat(" extern decl(s), ", str_concat(export_count, str_concat(" #[export] decl(s) to ", out_path))))))));
    } else {
        print(str_concat("nuc gen-headers: wrote ", str_concat(extern_count, str_concat(" extern decl(s), ", str_concat(export_count, str_concat(" #[export] decl(s) to ", out_path))))));
    };
    return 0;
}

fn run_zen_command() -> i64 {
    print("The Zen of Nucleor");
    print("");
    print("Units are not optional. Ask the Mars Climate Orbiter.");
    print("Effects are declared, not discovered in production.");
    print("If it compiles, the dimensions are correct.");
    print("Governance is not overhead. Governance is the product.");
    print("Unsafe is a confession, not a feature.");
    print("Trust is earned per-session, not granted per-binary.");
    print("The audit trail is the only history that matters.");
    print("Memory is borrowed. Responsibility is owned.");
    print("A taint you can see is a taint you can fix.");
    print("Correctness is faster than debugging.");
    print("Criticality is not an accident. It is a design choice.");
    print("Know your k-effective.");
    return 0;
}

fn run_mco_command() -> i64 {
    print("  +-----------------------------------------+");
    print("  |  Mars Climate Orbiter - September 1999  |");
    print("  |                                         |");
    print("  |  Lockheed Martin: pound-force-seconds   |");
    print("  |  NASA JPL:        newton-seconds        |");
    print("  |                                         |");
    print("  |  Cost: $327,600,000                     |");
    print("  |  Root cause: unit mismatch              |");
    print("  |  Nucleor status: PREVENTED AT COMPILE   |");
    print("  |                                         |");
    print("  |  \"This is why we exist.\"                |");
    print("  +-----------------------------------------+");
    return 0;
}

fn run_clean_command() -> i64 {
    print("clean: removing build artifacts (target/, .nuc_cache/)");
    system("rmdir /S /Q target 2>nul");
    system("rmdir /S /Q .nuc_cache 2>nul");
    print("clean: done");
    return 0;
}

fn print_help() -> i64 {
    print(str_concat("Nucleor Compiler ", compiler_version_label()));
    print("The governance-native programming language");
    print("");
    print("Usage: nuc <command> [source.nr] [options]");
    print("");
    print("Build commands:");
    print("  init [name]            Scaffold a project with Nucleor.toml");
    print("  build [file]           Compile to native binary (ownership + type, cached)");
    print("  build-fast [file]      Alias of the fast core compile path");
    print("  build-strict [file]    Compile through the full delegated strict checker stack");
    print("  build-shared [file]    Compile a shared library (.dll/.lib) from `pub fn` exports");
    print("  run [file]             Compile and run");
    print("  emit [file]            Emit LLVM IR only (alias for --no-link)");
    print("  build-wasm [file]      Compile to WebAssembly (.wasm)");
    print("  build-ptx [file]       Compile to NVIDIA PTX (.ptx)");
    print("    -o, --out <name>     Set output base name");
    print("    --emit llvm          Keep the LLVM IR artifact");
    print("    --no-link            Stop after writing target/<name>.ll");
    print("    --time-passes        Print per-phase compile timings");
    print("    --no-cache           Disable the resolved-source LLVM cache");
    print("");
    print("Developer commands:");
    print("  test [file]            Build and run @test / test_* functions");
    print("    --list               List discovered tests without running them");
    print("  bench [file]           Build once and benchmark repeated runs");
    print("    --iterations <n>     Number of measured runs (default 10)");
    print("    --warmup <n>         Number of warmup runs before timing (default 1)");
    print("  perf [file]            Compile-path performance analysis");
    print("    --json               Output machine-readable perf data");
    print("  bootstrap [subcmd]     Self-host bootstrap status / corpus report");
    print("    status               Report example and runtime readiness");
    print("    dump-corpus          List .nr corpus files");
    print("    --json               Output machine-readable bootstrap data");
    print("  stage-dump <stage>     Dump compiler stage summaries");
    print("    tokens|ast|typed|ir|all");
    print("  summary [file]         Compact module interface card");
    print("    --json               Output summary lines as JSON");
    print("  query [file]           Machine-readable module interface");
    print("  abi [file]             Inspect import/export ABI for C / Rust interop");
    print("    --exports            Inspect `pub fn` export ABI instead of imports");
    print("    --json               Output machine-readable ABI data");
    print("    --c-header           Emit C declarations for the selected ABI surface");
    print("    --rust-extern        Emit Rust unsafe extern declarations for the selected ABI surface");
    print("  evidence [file]        Governance evidence report");
    print("  impact [file] <fn>     Reverse call impact for a function");
    print("    --fn <name>          Specify the target function");
    print("  graph [file]           Source-level call/effect graph");
    print("    --json               Output machine-readable graph data");
    print("  doc [file]             Render /// doc comments as Markdown (RFC-0029)");
    print("    --out <file>         Write to file instead of stdout");
    print("  profile run <binary>   Timed binary execution profile");
    print("    --iterations <n>     Repeat the profile run N times");
    print("  lock [manifest]        Write Nucleor.lock for local/workspace manifests");
    print("    --json               Output machine-readable lock status");
    print("  install [alias] <pkg>  Add a path or registry dependency and refresh Nucleor.lock");
    print("  add | remove | update  Aliases for install (RFC-0019 phase 4 ergonomics)");
    print("  publish [manifest]     Copy a package into a local registry directory");
    print("    --registry <dir>     Registry root (default: .nucleor/registry)");
    print("  registry [subcmd]      List/search/inspect packages in a local registry");
    print("    list|search|versions|verify");
    print("  sage <subcmd> <file>   Sage_NS prove / certificate / gap checks");
    print("    prove|certificate|gaps");
    print("");
    print("Analysis commands:");
    print("  check [file] [flags]   Run all checkers and report diagnostics");
    print("    --json               Output JSONL diagnostics");
    print("    --sarif              Output SARIF v2.1.0");
    print("    --check=<checkers>   Run specific checkers (ownership,type,source,taint,effect)");
    print("    --review             Enable review surface (nucleor_review.jsonl)");
    print("    --review-filter=<f>  Filter: findings, function=<name>, <checker>");
    print("  explain <NR031>        Explain a compiler error code");
    print("    --json               Output a JSON explanation object");
    print("");
    print("Governance commands:");
    print("  audit [file]           Provenance and governance report");
    print("  policy [file] [level]  Policy compliance (default, no_extern, no_system, strict)");
    print("  certify [file]         Compile + produce certification manifest");
    print("  translate [file]       Parse, validate, and summarize source");
    print("");
    print("Project utilities:");
    print("  clean                  Remove target/ and .nuc_cache/ from the project");
    print("  scram                  Alias for `clean` (emergency shutdown of build state)");
    print("  fix [--imports|--numeric] [file]  Migration linters (RFC-0015 / RFC-0018)");
    print("  zen                    The design principles of Nucleor");
    print("  mco                    Mars Climate Orbiter - why we ship dimensional analysis");
    print("");
    print("Project mode:");
    print("  If [file] is omitted and ./Nucleor.toml exists, [build].entry is used.");
    print("");
    print("Legacy: nuc <source.nr> <output_name>");
    return 0;
}

fn main() -> i64 {
    let argc: i64 = args_count();
    if argc < 2 {
        print_help();
        return 1;
    };
    let cmd: str = args_get(1);
    // --version and help
    if str_eq(cmd, "--version") || str_eq(cmd, "-v") || str_eq(cmd, "-V") || str_eq(cmd, "version") {
        print(compiler_identity());
        return 0;
    };
    if str_eq(cmd, "help") || str_eq(cmd, "--help") || str_eq(cmd, "-h") {
        print_help();
        return 0;
    };
    if str_eq(cmd, "explain") {
        return run_explain_command(argc);
    };
    if str_eq(cmd, "bootstrap") {
        return run_bootstrap_command(argc);
    };
    if str_eq(cmd, "stage-dump") {
        return run_stage_dump_command(argc);
    };
    if str_eq(cmd, "build-shared") {
        return run_build_shared_command(argc);
    };
    if str_eq(cmd, "lock") {
        return run_lock_command(argc);
    };
    if str_eq(cmd, "install") {
        return run_install_command(argc);
    };
    // RFC-0019 phase 4: ergonomic aliases over `nuc install`. The full
    // `nuc add` / `nuc remove` / `nuc update` semantics (resolver-driven
    // version bumps + lock refresh) land with the v0.5 registry; today
    // they share the install code path.
    if str_eq(cmd, "add") {
        return run_install_command(argc);
    };
    if str_eq(cmd, "remove") {
        return run_install_command(argc);
    };
    if str_eq(cmd, "update") {
        return run_install_command(argc);
    };
    if str_eq(cmd, "publish") {
        return run_publish_command(argc);
    };
    if str_eq(cmd, "registry") {
        return run_registry_command(argc);
    };
    if str_eq(cmd, "fix") {
        return run_fix_command(argc);
    };
    if str_eq(cmd, "doc") {
        return run_doc_command(argc);
    };
    if str_eq(cmd, "gen-headers") {
        return run_gen_headers_command(argc);
    };
    if str_eq(cmd, "profile") {
        return run_profile_command(argc);
    };
    if str_eq(cmd, "sage") {
        return run_sage_command(argc);
    };
    if str_eq(cmd, "zen") {
        return run_zen_command();
    };
    if str_eq(cmd, "mco") {
        return run_mco_command();
    };
    if str_eq(cmd, "clean") || str_eq(cmd, "scram") {
        return run_clean_command();
    };
    if str_eq(cmd, "init") {
        // nuc init [name] — scaffold a new project
        let mut proj_name: str = "myproject";
        if argc >= 3 { proj_name = args_get(2); };
        system(str_concat("mkdir ", proj_name));
        system(str_concat("mkdir ", str_concat(proj_name, "\\src")));
        system(str_concat("mkdir ", str_concat(proj_name, "\\target")));
        // Write Nucleor.toml
        let toml: str = str_concat("[package]\nname = \"", str_concat(proj_name, "\"\nversion = \"0.1.0\"\n\n[build]\nentry = \"src/main.nr\"\n"));
        file_write_string(str_concat(proj_name, "/Nucleor.toml"), toml);
        // Write main.nr
        file_write_string(str_concat(proj_name, "/src/main.nr"), "fn main() -> i64 {\n    print(\"Hello, Nucleor!\");\n    return 0;\n}\n");
        print(str_concat("  Created project: ", proj_name));
        print(str_concat("  ", str_concat(proj_name, "/Nucleor.toml")));
        print(str_concat("  ", str_concat(proj_name, "/src/main.nr")));
        print("");
        print(str_concat("  To build: cd ", str_concat(proj_name, str_concat(" && nuc build", ""))));
        print(str_concat("  To run:   cd ", str_concat(proj_name, str_concat(" && nuc run", ""))));
        return 0;
    };
    // Legacy mode: nuc source.nr output_name
    if argc == 3 && cmd_accepts_source(cmd) == 0 {
        return compile_file(cmd, args_get(2));
    };
    let mut src_path: str = "";
    let mut arg_start: i64 = 2;
    if cmd_accepts_source(cmd) == 1 {
        if argc >= 3 {
            let arg2: str = args_get(2);
            if cli_is_flag(arg2) == 0 {
                src_path = arg2;
                arg_start = 3;
            };
        };
        if str_len(src_path) == 0 {
            src_path = manifest_entry_path();
            if str_len(src_path) > 0 {
                print(str_concat("  manifest entry: ", src_path));
            };
        };
        if str_len(src_path) == 0 {
            print("Usage: nuc <command> <source.nr> [options]");
            print("  note: or run the command from a project directory with Nucleor.toml");
            return 1;
        };
    };
    let wants_output_name: i64 = cmd_allows_output_name(cmd);
    let mut out_name: str = "";
    if wants_output_name == 1 {
        out_name = strip_ext(basename(src_path));
        if str_eq(cmd, "test") { out_name = str_concat(out_name, "-test"); };
        if str_eq(cmd, "bench") { out_name = str_concat(out_name, "-bench"); };
    };
    let mut time_passes: i64 = 0;
    let mut use_cache: i64 = 1;
    let mut link_native: i64 = 1;
    if str_eq(cmd, "emit") { link_native = 0; };
    let mut policy_level: str = "default";
    let mut bench_iterations: i64 = 10;
    let mut bench_warmup: i64 = 1;
    let mut test_list_only: i64 = 0;
    let mut saw_output_name: i64 = 0;
    let mut argi_build: i64 = arg_start;
    while argi_build < argc {
        let flag: str = args_get(argi_build);
        if str_eq(flag, "--time-passes") { time_passes = 1; }
        else if str_eq(flag, "--no-cache") { use_cache = 0; }
        else if str_eq(cmd, "test") && str_eq(flag, "--list") { test_list_only = 1; }
        else if str_eq(cmd, "bench") && str_eq(flag, "--iterations") {
            if argi_build + 1 >= argc {
                print("ERROR: --iterations requires a value");
                return 1;
            };
            bench_iterations = str_to_int(args_get(argi_build + 1));
            argi_build = argi_build + 1;
        } else if str_eq(cmd, "bench") && str_starts_with(flag, "--iterations=") == 1 {
            bench_iterations = str_to_int(str_substring(flag, 13, str_len(flag)));
        } else if str_eq(cmd, "bench") && str_eq(flag, "--warmup") {
            if argi_build + 1 >= argc {
                print("ERROR: --warmup requires a value");
                return 1;
            };
            bench_warmup = str_to_int(args_get(argi_build + 1));
            argi_build = argi_build + 1;
        } else if str_eq(cmd, "bench") && str_starts_with(flag, "--warmup=") == 1 {
            bench_warmup = str_to_int(str_substring(flag, 9, str_len(flag)));
        }
        else if wants_output_name == 1 && (str_eq(flag, "-o") || str_eq(flag, "--out") || str_eq(flag, "--output")) {
            if argi_build + 1 >= argc {
                print("ERROR: -o requires an output name");
                return 1;
            };
            out_name = args_get(argi_build + 1);
            saw_output_name = 1;
            argi_build = argi_build + 1;
        } else if wants_output_name == 1 && str_eq(flag, "--no-link") {
            link_native = 0;
        } else if wants_output_name == 1 && str_eq(flag, "--emit=llvm") {
            // LLVM IR is always emitted; this flag is accepted for clarity.
        } else if wants_output_name == 1 && str_eq(flag, "--emit") {
            if argi_build + 1 >= argc {
                print("ERROR: --emit requires a target (llvm)");
                return 1;
            };
            let emit_target: str = args_get(argi_build + 1);
            if str_eq(emit_target, "llvm") == 0 && str_eq(emit_target, "native") == 0 {
                print(str_concat("ERROR: unsupported emit target: ", emit_target));
                return 1;
            };
            argi_build = argi_build + 1;
        } else if wants_output_name == 1 && cli_is_flag(flag) == 0 && saw_output_name == 0 {
            out_name = flag;
            saw_output_name = 1;
        } else if str_eq(cmd, "policy") && cli_is_flag(flag) == 0 {
            policy_level = flag;
        };
        argi_build = argi_build + 1;
    };
    if wants_output_name == 1 {
        out_name = normalize_output_name(out_name);
        if str_len(out_name) == 0 {
            print("ERROR: output name must contain only letters, digits, '_' or '-'");
            return 1;
        };
    };
    if str_eq(cmd, "run") && link_native == 0 {
        print("ERROR: run cannot be used with --no-link");
        return 1;
    };
    if str_eq(cmd, "summary") {
        return run_summary_command(src_path, argc, arg_start);
    } else if str_eq(cmd, "evidence") {
        return run_evidence_command(src_path);
    } else if str_eq(cmd, "query") {
        return run_query_command(src_path);
    } else if str_eq(cmd, "abi") {
        return run_abi_command(src_path, argc, arg_start);
    } else if str_eq(cmd, "impact") {
        return run_impact_command(src_path, argc, arg_start);
    } else if str_eq(cmd, "graph") {
        return run_graph_command(src_path, argc, arg_start);
    } else if str_eq(cmd, "perf") {
        return run_perf_command(src_path, argc, arg_start);
    };
    if str_eq(cmd, "build") {
        return compile_file_mode(src_path, out_name, 0, use_cache, time_passes, link_native);
    } else if str_eq(cmd, "build-fast") {
        return compile_file_mode(src_path, out_name, 0, use_cache, time_passes, link_native);
    } else if str_eq(cmd, "build-strict") {
        return run_external_tool(argc);
    } else if str_eq(cmd, "run") {
        let rc: i64 = compile_file_mode(src_path, out_name, 0, use_cache, time_passes, 1);
        if rc != 0 { return rc; };
        let exe: str = str_concat("target\\", str_concat(out_name, ".exe"));
        return system(exe);
    } else if str_eq(cmd, "build-wasm") || str_eq(cmd, "build-ptx") {
        return run_external_tool(argc);
    } else if str_eq(cmd, "emit") {
        return compile_file_mode(src_path, out_name, 0, use_cache, time_passes, 0);
    } else if str_eq(cmd, "test") || str_eq(cmd, "bench") || str_eq(cmd, "check") || str_eq(cmd, "audit") || str_eq(cmd, "policy") || str_eq(cmd, "certify") || str_eq(cmd, "translate") {
        return run_external_tool(argc);
    } else {
        // Fallback: treat as legacy
        if argc >= 3 { return compile_file(cmd, args_get(2)); };
        print(str_concat("Unknown command: ", cmd));
        return 1;
    };
}





