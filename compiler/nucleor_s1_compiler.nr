// =====================================================
// Nucleor Stage 1 Compiler
// =====================================================
// A complete Nucleor compiler written in Nucleor.
// Reads a .nr source file, compiles it through:
//   source -> lex -> parse -> lower -> emit LLVM IR -> clang -> native exe
// Usage: nucleor_s1 <source.nr> <output_name>
// =====================================================

fn str_from_int(n: i32) -> str {
    if n == 0 { return "0"; };
    let mut val: i32 = n;
    if val < 0 { val = 0 - val; };
    let mut s: str = "";
    while val > 0 {
        let d: i32 = val - (val / 10) * 10;
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
                let frac_str: str = sb_to_str(frac_sb);
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
        else if c == 38 { tokens.push(tok_new(82, 0, p)); p = p + 1; }
        else if c == 124 && p + 1 < slen && str_char_at(src, p + 1) == 124 { tokens.push(tok_new(37, 0, p)); p = p + 2; }
        else if c == 124 { tokens.push(tok_new(65, 0, p)); p = p + 1; }
        else if c == 58 && p + 1 < slen && str_char_at(src, p + 1) == 58 { tokens.push(tok_new(46, 0, p)); p = p + 2; }
        else if c == 43 { tokens.push(tok_new(20, 0, p)); p = p + 1; }
        else if c == 45 { tokens.push(tok_new(21, 0, p)); p = p + 1; }
        else if c == 42 { tokens.push(tok_new(22, 0, p)); p = p + 1; }
        else if c == 47 { tokens.push(tok_new(23, 0, p)); p = p + 1; }
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
            if pk(tokens, cp2 + 1) == 53 || (pk(tokens, cp2 + 1) == 1 && pk(tokens, cp2 + 2) == 42) {
                return parse_struct_init(tokens, pos, pool);
            };
        };
        if pk(tokens, cp2) == 46 {
            let qname: i64 = pkv(tokens, cp2 + 1);
            if pk(tokens, cp2 + 2) == 50 {
                let mut ar: Vec<i32> = parse_args(tokens, cp2 + 3, pool);
                return pr(pr_pos(ar), mk4(pool, 12, name, qname, pr_val(ar)));
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
fn parse_cmp(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_add(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    let mut tt: i64 = pk(tokens, cp);
    while tt == 32 || tt == 33 || tt == 34 || tt == 35 {
        r = parse_add(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, tt, node, pr_val(r)); tt = pk(tokens, cp);
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
        let mut cp: i64 = p2 + 1;
        let mut inner: str = "";
        while pk(tokens, cp) != 33 && pk(tokens, cp) != 0 {
            if str_len(inner) > 0 {
                cp = expect_tok(tokens, cp, 44);
                if pk(tokens, cp) == 33 { break; };
                inner = str_concat(inner, ", ");
            };
            let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
            inner = str_concat(inner, pr_val(tr));
        };
        return pr(cp + 1, str_concat(name, str_concat("<", str_concat(inner, ">"))));
    };
    return pr(p2, name);
}

fn parse_generic_params(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    // pos points at '<', returns (pos_after_>, list of param name strings)
    let mut cp: i64 = pos + 1;
    let mut params: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 33 && pk(tokens, cp) != 0 {
        if vec_len(params) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 33 { break; };
        };
        params.push(pkv(tokens, cp));
        cp = cp + 1;
    };
    cp = cp + 1; // skip >
    return pr(cp, params);
}

fn parse_let(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut is_mut: i64 = 0; let mut cp: i64 = pos;
    if pk(tokens, cp) == 12 { is_mut = 1; cp = cp + 1; };
    let name: i64 = pkv(tokens, cp); cp = cp + 1;
    let mut tstr: str = "";
    if pk(tokens, cp) == 42 { let mut tr: Vec<i32> = parse_type(tokens, cp + 1); cp = pr_pos(tr); tstr = pr_val(tr); };
    let mut init_id: i64 = 0 - 1;
    if pk(tokens, cp) == 40 { let mut er: Vec<i32> = parse_expr(tokens, cp + 1, pool); cp = pr_pos(er); init_id = pr_val(er); };
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
        params.push(mk3(pool, 41, pn, pr_val(tr)));
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
        let fn2: i64 = pkv(tokens, cp); cp = expect_tok(tokens, cp + 1, 42);
        let mut er: Vec<i32> = parse_expr(tokens, cp, pool); cp = pr_pos(er);
        inits.push(mk3(pool, 35, fn2, pr_val(er)));
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
    cp = expect_tok(tokens, cp, 52); // {
    let mut methods: Vec<i32> = Vec::new();
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        cp = expect_tok(tokens, cp, 10); // fn
        let mname: i64 = pkv(tokens, cp); cp = cp + 1;
        cp = expect_tok(tokens, cp, 50); // (
        let mut params: Vec<i32> = Vec::new();
        while pk(tokens, cp) != 51 && pk(tokens, cp) != 0 {
            if vec_len(params) > 0 { cp = expect_tok(tokens, cp, 44); };
            let pn: i64 = pkv(tokens, cp); cp = cp + 1;
            if pk(tokens, cp) == 42 {
                cp = cp + 1;
                let mut tr: Vec<i32> = parse_type(tokens, cp); cp = pr_pos(tr);
                params.push(mk3(pool, 41, pn, pr_val(tr)));
            } else {
                params.push(mk3(pool, 41, pn, "Self"));
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
            // RFC-0023 §3.1 range patterns (`1..=9`) deferred to v0.4 with
            // generic enums — encoding LO/HI in the existing arm tuple
            // (which assumes vname:i64-or-str + binding:str semantics) is
            // too fragile without a richer arm AST node. The lower-side
            // __range / __range_bad handlers below are wired and waiting.
            ename = "__int";
            vname = pkv(tokens, cp);
            cp = cp + 1;
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
            // Enum pattern: EnumName::Variant or EnumName::Variant(binding)
            ename = pkv(tokens, cp);
            cp = expect_tok(tokens, cp + 1, 46); // ::
            vname = pkv(tokens, cp); cp = cp + 1;
            if pk(tokens, cp) == 50 {
                cp = cp + 1;
                binding = pkv(tokens, cp); cp = cp + 1;
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
        } else {
            let mut er: Vec<i32> = parse_expr(tokens, cp, pool);
            cp = pr_pos(er);
            let mut stmts: Vec<i32> = Vec::new();
            stmts.push(mk2(pool, 25, pr_val(er)));
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
    while pk(tokens, cp) != 0 {
        if pk(tokens, cp) == 72 {
            cp = cp + 1;
        }
        else if pk(tokens, cp) == 20 && pk(tokens, cp + 1) == 10 {
            // extern fn
            let mut r: Vec<i32> = parse_extern_fn(tokens, cp + 2, pool); items.push(pr_val(r)); cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 73 { let mut r: Vec<i32> = parse_const_decl(tokens, cp + 1, pool); items.push(pr_val(r)); cp = pr_pos(r); }
        else if pk(tokens, cp) == 74 { let mut r: Vec<i32> = parse_type_alias_decl(tokens, cp + 1, pool); items.push(pr_val(r)); cp = pr_pos(r); }
        else if pk(tokens, cp) == 17 { let mut r: Vec<i32> = parse_struct_decl(tokens, cp + 1, pool); items.push(pr_val(r)); cp = pr_pos(r); }
        else if pk(tokens, cp) == 62 { let mut r: Vec<i32> = parse_enum_decl(tokens, cp + 1, pool); items.push(pr_val(r)); cp = pr_pos(r); }
        else if pk(tokens, cp) == 66 { let mut r: Vec<i32> = parse_trait_decl(tokens, cp + 1, pool); items.push(pr_val(r)); cp = pr_pos(r); }
        else if pk(tokens, cp) == 67 { let mut r: Vec<i32> = parse_impl_block(tokens, cp + 1, pool); items.push(pr_val(r)); cp = pr_pos(r); }
        else if pk(tokens, cp) == 68 && pk(tokens, cp + 1) == 10 {
            // pure fn — parse as fn_decl, mark name with __pure_ prefix internally
            let mut r: Vec<i32> = parse_fn_decl(tokens, cp + 2, pool);
            let fn_nid: i64 = pr_val(r);
            if str_eq(node_field(pool, fn_nid, 1), "main") == 1 && has_main_decl(pool, items) == 1 { items = remove_main_decl(pool, items); };
            // Tag function as pure by storing a marker node (kind 46)
            items.push(mk2(pool, 46, node_field(pool, fn_nid, 1)));
            items.push(fn_nid);
            cp = pr_pos(r);
        }
        else if pk(tokens, cp) == 10 {
            let mut r: Vec<i32> = parse_fn_decl(tokens, cp + 1, pool);
            let fn_nid: i64 = pr_val(r);
            if str_eq(node_field(pool, fn_nid, 1), "main") == 1 && has_main_decl(pool, items) == 1 { items = remove_main_decl(pool, items); };
            items.push(fn_nid);
            cp = pr_pos(r);
        }
        else { cp = cp + 1; };
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
        // Fold logical: and(13), or(14)
        else if op == 13 || op == 14 {
            let a: i64 = ir_op1(inst);
            let b: i64 = ir_op2(inst);
            if cmap_has(cm, a) == 1 && cmap_has(cm, b) == 1 {
                let va: i64 = cmap_get(cm, a);
                let vb: i64 = cmap_get(cm, b);
                let mut result: i64 = 0;
                if op == 13 { if va != 0 && vb != 0 { result = 1; }; }
                else if op == 14 { if va != 0 || vb != 0 { result = 1; }; };
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
        if op >= 2 && op <= 14 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        else if op == 17 { used.push(ir_op1(inst)); }
        else if op == 18 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); }
        else if op == 20 { used.push(ir_op1(inst)); }
        else if op == 22 { used.push(ir_op1(inst)); }
        else if op == 28 { used.push(ir_op1(inst)); used.push(ir_op2(inst)); used.push(ir_extra(inst)); }
        else if op == 30 { used.push(ir_op1(inst)); let cargs: Vec<i32> = vec_get(inst, 5); let mut ci: i64 = 0; while ci < vec_len(cargs) { used.push(vec_get(cargs, ci)); ci = ci + 1; }; }
        else if op == 19 {
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
        if op == 0 || (op >= 2 && op <= 14) || op == 17 || op == 26 || op == 27 || op == 28 || op == 29 {
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
        else if op == 19 || op == 30 { sv = cmap_new(); };
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
        else if op == 19 || op == 20 || op == 21 || op == 22 || op == 30 {
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
    if str_eq(name, "file_read_string") { return "__nucleor_file_read_string"; };
    if str_eq(name, "file_write_string") { return "__nucleor_file_write_string"; };
    if str_eq(name, "system") { return "__nucleor_system"; };
    if str_eq(name, "sb_new") { return "__nucleor_sb_new"; };
    if str_eq(name, "sb_append") { return "__nucleor_sb_append"; };
    if str_eq(name, "sb_to_str") { return "__nucleor_sb_to_str"; };
    if str_eq(name, "vec_new") { return "__nucleor_vec_new"; };
    if str_eq(name, "vec_push") { return "__nucleor_vec_push"; };
    if str_eq(name, "vec_get") { return "__nucleor_vec_get"; };
    if str_eq(name, "vec_len") { return "__nucleor_vec_len"; };
    if str_eq(name, "vec_pop") { return "__nucleor_vec_pop"; };
    if str_eq(name, "vec_set") { return "__nucleor_vec_set"; };
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
    if str_eq(name, "format_str") { return "__nucleor_format_str"; };
    if str_eq(name, "format_hex") { return "__nucleor_format_hex"; };
    if str_eq(name, "format2_ii") { return "__nucleor_format2_ii"; };
    if str_eq(name, "format2_si") { return "__nucleor_format2_si"; };
    if str_eq(name, "format_f64") { return "__nucleor_format_f64"; };
    // RFC-0024 phase 1: Vec<i64> functional helpers (function-pointer args)
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
    if str_eq(name, "format_bool") { return "__nucleor_format_bool"; };
    if str_eq(name, "format3_iii") { return "__nucleor_format3_iii"; };
    if str_eq(name, "vec_avg_i64") { return "__nucleor_vec_avg_i64"; };
    if str_eq(name, "vec_dot_i64") { return "__nucleor_vec_dot_i64"; };
    if str_eq(name, "vec_count_eq_i64") { return "__nucleor_vec_count_eq_i64"; };
    if str_eq(name, "vec_any_i64") { return "__nucleor_vec_any_i64"; };
    if str_eq(name, "vec_all_i64") { return "__nucleor_vec_all_i64"; };
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
    // Typed time
    if str_eq(name, "time_monotonic_ns") { return "__nucleor_time_monotonic_ns"; };
    if str_eq(name, "time_monotonic_us") { return "__nucleor_time_monotonic_us"; };
    if str_eq(name, "time_monotonic_ms") { return "__nucleor_time_monotonic_ms"; };
    if str_eq(name, "time_wall_ns") { return "__nucleor_time_wall_ns"; };
    if str_eq(name, "time_wall_us") { return "__nucleor_time_wall_us"; };
    if str_eq(name, "time_wall_ms") { return "__nucleor_time_wall_ms"; };
    if str_eq(name, "time_wall_seconds") { return "__nucleor_time_wall_seconds"; };
    if str_eq(name, "sleep_ms") { return "__nucleor_sleep_ms"; };
    if str_eq(name, "sleep_us") { return "__nucleor_sleep_us"; };
    // Env
    if str_eq(name, "env_get") { return "__nucleor_env_get"; };
    if str_eq(name, "env_set") { return "__nucleor_env_set"; };
    if str_eq(name, "env_unset") { return "__nucleor_env_unset"; };
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
    if str_eq(name, "file_write_string") { return 1; };
    if str_eq(name, "sb_append") { return 1; };
    if str_eq(name, "vec_push") { return 1; };
    if str_eq(name, "vec_pop") { return 1; };
    if str_eq(name, "vec_set") { return 1; };
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
    return 0;
}
fn is_ptr_ret(name: str) -> i64 {
    if str_eq(name, "str_concat") { return 1; };
    if str_eq(name, "str_substring") { return 1; };
    if str_eq(name, "file_read_string") { return 1; };
    if str_eq(name, "sb_to_str") { return 1; };
    if str_eq(name, "vec_new") { return 1; };
    if str_eq(name, "args_get") { return 1; };
    if str_eq(name, "read_line") { return 1; };
    if str_eq(name, "format_i64") { return 1; };
    if str_eq(name, "format_str") { return 1; };
    if str_eq(name, "format_hex") { return 1; };
    if str_eq(name, "format2_ii") { return 1; };
    if str_eq(name, "format2_si") { return 1; };
    if str_eq(name, "format_f64") { return 1; };
    if str_eq(name, "format_bool") { return 1; };
    if str_eq(name, "format3_iii") { return 1; };
    if str_eq(name, "vec_map_i64") { return 1; };
    if str_eq(name, "vec_filter_i64") { return 1; };
    if str_eq(name, "vec_reverse_i64") { return 1; };
    if str_eq(name, "vec_sort_i64") { return 1; };
    if str_eq(name, "vec_clone_i64") { return 1; };
    if str_eq(name, "str_to_lower") { return 1; };
    if str_eq(name, "str_to_upper") { return 1; };
    if str_eq(name, "str_trim") { return 1; };
    if str_eq(name, "str_replace") { return 1; };
    if str_eq(name, "str_repeat") { return 1; };
    if str_eq(name, "str_split") { return 1; };
    if str_eq(name, "sha256") { return 1; };
    if str_eq(name, "py_eval") { return 1; };
    if str_eq(name, "chr") { return 1; };
    if str_eq(name, "getcwd") { return 1; };
    if str_eq(name, "getenv") { return 1; };
    if str_eq(name, "fs_join") { return 1; };
    if str_eq(name, "fs_basename") { return 1; };
    if str_eq(name, "fs_dirname") { return 1; };
    if str_eq(name, "fs_extension") { return 1; };
    if str_eq(name, "manifest_report") { return 1; };
    if str_eq(name, "sha256_hex") { return 1; };
    if str_eq(name, "base64_encode") { return 1; };
    if str_eq(name, "base64_decode") { return 1; };
    if str_eq(name, "uuid_v4") { return 1; };
    return 0;
}
fn is_ptr_arg(name: str, idx: i64) -> i64 {
    if str_eq(name, "print") { return 1; };
    if str_eq(name, "panic") { return 1; };
    if str_eq(name, "dbg_str") { return 1; };
    if str_eq(name, "eprint") { return 1; };
    if str_eq(name, "string_from_str") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "string_push_str") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_eq_str") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_starts_with") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_ends_with") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "string_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_insert") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_get") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_contains") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "hashmap_remove") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "env_get") { if idx == 0 { return 1; }; return 0; };
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
    if str_eq(name, "file_read_string") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "file_write_string") { return 1; };
    if str_eq(name, "system") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "sb_append") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "vec_push") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_get") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_len") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_pop") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "vec_set") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "file_append_string") { return 1; };
    if str_eq(name, "pipe_create") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "pipe_write") { if idx == 1 { return 1; }; return 0; };
    if str_eq(name, "sha256") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "profile_start") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "profile_end") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "py_eval") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "getenv") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "env_get") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "env_unset") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format_i64") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format_str") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format_hex") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format2_ii") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format2_si") { if idx == 0 || idx == 1 { return 1; }; return 0; };
    if str_eq(name, "format_f64") { if idx == 0 { return 1; }; return 0; };
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
    if str_eq(name, "str_starts_with") { return 1; };
    if str_eq(name, "str_ends_with") { return 1; };
    if str_eq(name, "str_index_of") { return 1; };
    if str_eq(name, "str_contains") { return 1; };
    if str_eq(name, "str_replace") { return 1; };
    if str_eq(name, "str_repeat") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "str_split") { return 1; };
    if str_eq(name, "format_bool") { if idx == 0 { return 1; }; return 0; };
    if str_eq(name, "format3_iii") { if idx == 0 { return 1; }; return 0; };
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
        else if c >= 32 && c <= 126 { sb_append(esb, str_substring(s, i, i + 1)); }
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
    sb_append(sb, "declare ptr @__nucleor_file_read_string(ptr)\n");
    sb_append(sb, "declare void @__nucleor_file_write_string(ptr, ptr)\n");
    sb_append(sb, "declare void @__nucleor_init_args(i32, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_system(ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_vec_new()\n");
    sb_append(sb, "declare void @__nucleor_vec_push(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_get(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_len(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_pop(ptr)\n");
    sb_append(sb, "declare void @__nucleor_vec_set(ptr, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sb_new()\n");
    sb_append(sb, "declare void @__nucleor_sb_append(i64, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_sb_to_str(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_args_count()\n");
    sb_append(sb, "declare ptr @__nucleor_args_get(i64)\n");
    sb_append(sb, "declare void @__nucleor_print_bool(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_read_line()\n");
    sb_append(sb, "declare i64 @__nucleor_read_i64()\n");
    sb_append(sb, "declare i64 @__nucleor_read_byte()\n");
    sb_append(sb, "declare ptr @__nucleor_format_i64(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format_str(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format_hex(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_ii(ptr, i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format2_si(ptr, ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format_f64(ptr, i64)\n");
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
    sb_append(sb, "declare i64 @__nucleor_str_starts_with(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_ends_with(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_index_of(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_str_contains(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_replace(ptr, ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_str_repeat(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_str_split(ptr, ptr)\n");
    sb_append(sb, "declare ptr @__nucleor_format_bool(ptr, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_format3_iii(ptr, i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_avg_i64(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_dot_i64(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_count_eq_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_any_i64(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_all_i64(ptr, i64)\n");
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
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_ns()\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_us()\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_ms()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_ns()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_us()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_ms()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_seconds()\n");
    sb_append(sb, "declare i64 @__nucleor_sleep_ms(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sleep_us(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_env_get(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_set(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_unset(ptr)\n");
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
    let mut sb: i64 = sb_new();
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
    if tok == 36 { return 13; }; if tok == 37 { return 14; }; return 0 - 1;
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
    let mut base: str = t;
    let tlen: i64 = str_len(base);
    if tlen >= 5 && str_eq(str_substring(base, 0, 5), "&mut ") == 1 { base = str_substring(base, 5, tlen); }
    else if tlen >= 1 && str_char_at(base, 0) == 38 { base = str_substring(base, 1, tlen); };
    let slen: i64 = str_len(base);
    if slen >= 4 && str_eq(str_substring(base, 0, 4), "Box<") == 1 {
        return type_base_name(str_substring(base, 4, slen - 1));
    };
    if slen >= 6 && str_eq(str_substring(base, 0, 6), "fixed<") == 1 { return "i64"; };
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

fn type_is_mut_ref(t: str) -> i64 {
    let tlen: i64 = str_len(t);
    if tlen >= 5 && str_eq(str_substring(t, 0, 5), "&mut ") == 1 { return 1; };
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
    sym_set(sym, "__etag_Result_Ok", 0);
    sym_set(sym, "__eargs_Result_Ok", 1);
    sym_set(sym, "__etag_Result_Err", 1);
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
        if str_eq(str_substring(source, i, i + tlen), target) { fn_start = i; i = slen; };
        i = i + 1;
    };
    if fn_start < 0 { out.push(0); out.push(0); return out; };
    let mut line: i64 = byte_to_line(source, fn_start);
    let mut col: i64 = 1;
    i = fn_start;
    while i < slen - vlen {
        if str_eq(str_substring(source, i, i + vlen), var_name) {
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

fn diag_emit_text(diags: Vec<i32>) -> i64 {
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
    let slen: i64 = str_len(s);
    let plen: i64 = str_len(prefix);
    if slen < plen { return 0; };
    return str_eq(str_substring(s, 0, plen), prefix);
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
    // Reset o to snap state: truncate and repopulate
    // Clear by popping all, then push from snap
    while vec_len(o) > 0 { o.pop(); };
    let mut i: i64 = 0;
    while i < vec_len(snap) {
        o.push(vec_get(snap, i)); o.push(vec_get(snap, i + 1));
        i = i + 2;
    };
    return 0;
}
fn own_merge_moved(o: Vec<i32>, a: Vec<i32>, b: Vec<i32>) -> i64 {
    // If a variable is moved in either branch, mark it moved
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
    if kind == 1 || kind == 2 || kind == 71 { return 0; }; // literals
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
    // Check if type annotation starts with "tainted"
    if str_len(tstr) >= 7 && str_eq(str_substring(tstr, 0, 7), "tainted") { return 1; };
    return 0;
}
fn taint_inner_type(t: str) -> str {
    let slen: i64 = str_len(t);
    if slen >= 9 && str_eq(str_substring(t, 0, 8), "tainted<") == 1 { return str_substring(t, 8, slen - 1); };
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
        if str_eq(str_substring(txt, i, i + tlen), text) == 1 { return 1; };
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
        if str_eq(str_substring(source, i, i + tlen), target) == 1 {
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
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < str_len(s) {
        let c: i64 = str_char_at(s, i);
        if c != 32 && c != 9 && c != 10 && c != 13 { sb_append(sb, str_substring(s, i, i + 1)); };
        i = i + 1;
    };
    return sb_to_str(sb);
}
fn type_is_unit(t: str) -> i64 {
    let slen: i64 = str_len(t);
    if slen >= 5 && str_eq(str_substring(t, 0, 5), "unit<") == 1 { return 1; };
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
            if slen >= 5 && str_eq(str_substring(inner, 0, 4), "Box<") == 1 { return str_substring(inner, 4, slen - 1); };
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
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 {
            let else_env: Vec<i32> = own_snapshot(env);
            warns = warns + type_check_stmts(pool, enode, else_env, sigs, structs, fn_name, diags, source, rtype, tprof);
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
        if str_eq(str_substring(hay, i, i + nlen), needle) == 1 { return 1; };
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
        if diag_use_json() == 1 { diag_emit_json(diags); } else { diag_emit_text(diags); };
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

fn lower_expr(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let kind: i64 = node_kind(pool, nid);
    // RFC-0015 phase 2: `as` cast. Lower inner, then call __nucleor_as_<T>
    // to actually perform width truncation / sign extension at runtime.
    if kind == 99 {
        let inner_lx: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let inner_blk: Vec<i32> = lx_blk(inner_lx);
        let inner_r: i64 = lx_reg(inner_lx);
        let target_type: str = node_field(pool, nid, 2);
        // Choose runtime helper based on target type
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
            // No-op cast for unrecognized targets (e.g., generics)
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
    if kind == 122 {
        // RFC-0016 phase 1: `?` postfix operator. Inner expression returns a
        // Result-like Vec<i32> with [0]=tag (1=Ok/0=Err) and [1]=payload.
        // Emit:
        //   let tmp = inner;
        //   if vec_get(tmp, 0) == 0 { return tmp; }
        //   vec_get(tmp, 1)            // value of the ? expression
        let inner_lx: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mut cur: Vec<i32> = lx_blk(inner_lx);
        let val_r: i64 = lx_reg(inner_lx);
        let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
        let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(val_r); tag_args.push(zero_r);
        let tag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
        let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, zero_r));
        let err_lbl: i64 = ctr_next(lbls); let ok_lbl: i64 = ctr_next(lbls);
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
        let mut lp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let lr: i64 = lx_reg(lp);
        let mut cur: Vec<i32> = lx_blk(lp);
        let mut rp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let rr: i64 = lx_reg(rp);
        cur = lx_blk(rp);
        let iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        let r: i64 = ctr_next(regs);
        if is_cmp_or_logic(iop) == 1 { ir_block_add(cur, ir_cmpop(iop, r, lr, rr)); }
        else { ir_block_add(cur, ir_binop(iop, r, lr, rr)); };
        return lx_new(r, cur);
    };
    if kind == 5 {
        let zr: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(zr, 0));
        let mut op_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let opr: i64 = lx_reg(op_p);
        let cur: Vec<i32> = lx_blk(op_p);
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_binop(3, r, zr, opr));
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
        ir_block_add(cur, ir_call_ex(r, fn_name, arg_regs));
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
            if str_len(fn_name) == 0 { fn_name = str_concat("vec_", mname); };
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
            capi = capi + 1;
        };
        let mut clo_fb: Vec<i32> = lower_stmts(pool, body_list, clo_b0, clo_regs, clo_lbls, clo_sym, clo_fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        if block_has_term(clo_fb) == 0 {
            let czr: i64 = ctr_next(clo_regs);
            ir_block_add(clo_fb, ir_const_int(czr, 0));
            ir_block_add(clo_fb, ir_ret(czr));
        };
        closures.push(clo_fir);
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
fn lower_stmt(pool: Vec<i32>, nid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let kind: i64 = node_kind(pool, nid);
    if kind == 20 {
        let ar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, ar);
        let vname: str = node_field(pool, nid, 1);
        sym_set(sym, vname, ar);
        let init: i64 = node_field(pool, nid, 4);
        let mut tstr: str = node_field(pool, nid, 3);
        if str_len(tstr) == 0 && init >= 0 {
            let ik: i64 = node_kind(pool, init);
            if ik == 34 { tstr = node_field(pool, init, 1); }
            else if ik == 12 { tstr = node_field(pool, init, 1); };
        };
        let sbase: str = type_base_name(tstr);
        if str_len(sbase) > 0 { sym_set(sym, str_concat("__type_", vname), sbase); };
        if init >= 0 {
            let mut vp: Vec<i32> = lower_expr(pool, init, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            cur = lx_blk(vp);
            let vr: i64 = lx_reg(vp);
            ir_block_add(cur, ir_store(vr, ar));
        };
        return cur;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let lhs_kind: i64 = node_kind(pool, lhs);
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

fn lower_fn(pool: Vec<i32>, fn_nid: i64, strtab: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, globals: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let blist: i64 = node_field(pool, fn_nid, 4);
    let pc: i64 = list_len(pool, plist);
    let mut regs: Vec<i32> = ctr_new();
    let mut lbls: Vec<i32> = ctr_new();
    let mut sym: Vec<i32> = sym_new();
    enum_populate_sym(pool, enums, sym);
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
    sb_append(sb, "native-cache-v4|");
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
    // Returns the clang executable name. The launcher (nuc.bat / nuc_router.ps1)
    // is responsible for ensuring clang is reachable on PATH before invoking the
    // compiler — see the launcher script for the resolution order
    // (NUCLEOR_CLANG_PATH, LLVM_SYS_180_PREFIX, default install path).
    return "clang";
}

fn link_native_module(ll: str, out_name: str, imported: Vec<i32>, cache_ll_path: str, link_native: i64, time_passes: i64) -> i64 {
    let ll_path: str = sanitize(str_concat("target/", str_concat(out_name, ".ll")));
    let exe_path: str = sanitize(str_concat("target\\", str_concat(out_name, ".exe")));
    system("mkdir target 2>NUL");
    file_write_string(ll_path, ll);
    if str_len(cache_ll_path) > 0 {
        system("mkdir .nuc_cache 2>NUL");
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
    let cmd: str = str_concat(llvm_clang_path(), str_concat(" ", str_concat(ll_path, str_concat(" ", str_concat(rt_arg, str_concat(cfiles, str_concat(" -o ", str_concat(exe_path, str_concat(" -Wno-override-module -Wl,/STACK:16777216 ", str_concat(libpath_flags, str_concat(link_flags, " 2>&1"))))))))));
    let rc: i64 = system(cmd);
    print_phase_time(time_passes, "clang", now_ms() - clang_start);
    if rc != 0 {
        let ll_check: str = file_read_string(ll_path);
        if str_len(ll_check) > 0 {
            print(str_concat("  COMPILE FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
            print("  note: LLVM IR was emitted; GPU/CUDA experiments may require manual link with CUDA libs");
        } else {
            print(str_concat("  COMPILE FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
            return 1;
        };
        return 1;
    };
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
    return content_hash(str_concat("module-graph-v1|", sanitize(src_path)));
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
    if plen >= 5 && str_eq(str_substring(raw_path, 0, 5), "std::") == 1 {
        prefix = "stdlib/rods/";
        tail_start = 5;
    } else if plen >= 7 && str_eq(str_substring(raw_path, 0, 7), "crate::") == 1 {
        prefix = "";
        tail_start = 7;
    } else if plen >= 7 && str_eq(str_substring(raw_path, 0, 7), "super::") == 1 {
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
        if line_len >= 8 && str_eq(str_substring(src, lp, lp + 7), "import ") { prefix_len = 7; };
        if prefix_len == 0 && line_len >= 5 && str_eq(str_substring(src, lp, lp + 4), "use ") { prefix_len = 4; };
        // RFC-0018 phase 1: `mod foo;` desugars to `import "./foo.nr"`.
        // Block-form `mod foo { ... }` requires a parser-level scope and
        // ships in phase 2 with the resolver.
        if prefix_len == 0 && line_len >= 5 && str_eq(str_substring(src, lp, lp + 4), "mod ") == 1 {
            let mut sp: i64 = lp + 4;
            while sp < eol && str_char_at(src, sp) == 32 { sp = sp + 1; };
            let mut np: i64 = sp;
            while np < eol && (is_alnum(str_char_at(src, np)) == 1) { np = np + 1; };
            // Require a `;` (after optional whitespace) — block-form is
            // skipped here so the parser sees the brace and rejects.
            let mut tp: i64 = np;
            while tp < eol && str_char_at(src, tp) == 32 { tp = tp + 1; };
            if np > sp && tp < eol && str_char_at(src, tp) == 59 {
                is_mod_decl = 1;
                prefix_len = 4;
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
                        module_record_add(module_records, path, isrc);
                        let idir: str = extract_dir(path);
                        sb_append(result, resolve_source_with_records(isrc, idir, imported, module_records));
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
                        module_record_add(module_records, path, isrc);
                        let idir: str = extract_dir(path);
                        sb_append(result, resolve_source_with_records(isrc, idir, imported, module_records));
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
        } else if line_len >= 2 && str_char_at(src, lp) == 35 {
            // Skip # directives (#link, #cfile)
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
    let source: str = resolve_source_with_records(raw_source, extract_dir(src_path), imported, module_records);
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
            if line_len >= 7 && str_eq(str_substring(raw_source, lp, lp + 6), "#link ") {
                let mut qp: i64 = lp + 6;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    sb_append(links, " -l"); sb_append(links, str_substring(raw_source, ps, pe));
                };
            } else if line_len >= 8 && str_eq(str_substring(raw_source, lp, lp + 7), "#cfile ") {
                let mut qp: i64 = lp + 7;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    sb_append(cfiles, " "); sb_append(cfiles, str_concat(base_dir, str_substring(raw_source, ps, pe)));
                };
            } else if line_len >= 10 && str_eq(str_substring(raw_source, lp, lp + 9), "#libpath ") {
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
    // Pass 1: collect structs, enums, and externs
    let collect_start: i64 = now_ms();
    let mut fi: i64 = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 32 { externs.push(fn_nid); }
        else if node_kind(pool, fn_nid) == 33 { structs.push(fn_nid); }
        else if node_kind(pool, fn_nid) == 36 { enums.push(fn_nid); };
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
                trait_impl_register(trait_impls, type_name, orig_name, mangled);
                mi = mi + 1;
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
    if diag_count(diags) > 0 {
        // Emit every diagnostic, but only halt the build on errors.
        // Warnings (NUM-003 lossy cast, MATCH-001/002 typecker, etc.)
        // flow through the report without blocking compilation.
        if diag_use_json() == 1 { diag_emit_json(diags); } else { diag_emit_text(diags); };
        if diag_count_errors(diags) > 0 { return 1; };
    };
    let mut closures: Vec<i32> = Vec::new();
    let lower_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { fns.push(lower_fn(pool, fn_nid, strtab, structs, enums, globals, closures, trait_impls)); };
        fi = fi + 1;
    };
    let mut ii: i64 = 0;
    while ii < vec_len(impl_fns) {
        fns.push(lower_fn(pool, vec_get(impl_fns, ii), strtab, structs, enums, globals, closures, trait_impls));
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
    return "0.2.0-v2";
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
        if str_eq(str_substring(compact, p, p + klen), key) == 1 {
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
    if str_eq(cmd, "--version") || str_eq(cmd, "-v") {
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
        } else if str_eq(cmd, "bench") && str_len(flag) > 13 && str_eq(str_substring(flag, 0, 13), "--iterations=") {
            bench_iterations = str_to_int(str_substring(flag, 13, str_len(flag)));
        } else if str_eq(cmd, "bench") && str_eq(flag, "--warmup") {
            if argi_build + 1 >= argc {
                print("ERROR: --warmup requires a value");
                return 1;
            };
            bench_warmup = str_to_int(args_get(argi_build + 1));
            argi_build = argi_build + 1;
        } else if str_eq(cmd, "bench") && str_len(flag) > 9 && str_eq(str_substring(flag, 0, 9), "--warmup=") {
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





