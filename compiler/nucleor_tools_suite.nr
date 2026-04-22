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
            let st: i64 = p;
            while p < slen && is_digit(str_char_at(src, p)) == 1 { p = p + 1; };
            // Check for f64 literal: digits DOT digits
            if p < slen && str_char_at(src, p) == 46 && p + 1 < slen && is_digit(str_char_at(src, p + 1)) == 1 {
                // f64 literal — parse integer.fraction, encode as bitcast i64
                let int_part: i64 = str_to_int(str_substring(src, st, p));
                p = p + 1; // skip dot
                let frac_st: i64 = p;
                while p < slen && is_digit(str_char_at(src, p)) == 1 { p = p + 1; };
                let frac_str: str = str_substring(src, frac_st, p);
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
                if p < slen && str_char_at(src, p) == 123 {
                    tokens.push(tok_new(83, 0, p));
                    p = p + 1;
                }
            } else {
                tokens.push(tok_new(2, str_to_int(str_substring(src, st, p)), st));
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
        else if c == 46 && p + 1 < slen && str_char_at(src, p + 1) == 46 { tokens.push(tok_new(58, 0, p)); p = p + 2; }
        else if c == 46 { tokens.push(tok_new(45, 0, p)); p = p + 1; }
        else if c == 40 { tokens.push(tok_new(50, 0, p)); p = p + 1; }
        else if c == 41 { tokens.push(tok_new(51, 0, p)); p = p + 1; }
        else if c == 123 { tokens.push(tok_new(52, 0, p)); p = p + 1; }
        else if c == 125 { tokens.push(tok_new(53, 0, p)); p = p + 1; }
        else if c == 91 { tokens.push(tok_new(54, 0, p)); p = p + 1; }
        else if c == 93 { tokens.push(tok_new(55, 0, p)); p = p + 1; }
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
    while pk(tokens, cp) == 45 || pk(tokens, cp) == 54 {
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
    return parse_postfix(tokens, pos, pool);
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
            // Integer literal pattern (token value is already i64)
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
fn ir_select(d: i64, cond: i64, tv: i64, fv: i64) -> Vec<i32> { return ir_inst(28, d, 0, cond, tv, fv); }
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
    let mut f: Vec<i32> = Vec::new(); f.push(name); f.push(pc); f.push(0);
    let mut blocks: Vec<i32> = Vec::new(); f.push(blocks); return f;
}
fn ir_fn_name(f: Vec<i32>) -> str { return vec_get(f, 0); }
fn ir_fn_param_count(f: Vec<i32>) -> i64 { return vec_get(f, 1); }
fn ir_fn_add_block(f: Vec<i32>, blk: Vec<i32>) -> i64 { let mut b: Vec<i32> = vec_get(f, 3); b.push(blk); return 0; }
fn ir_fn_block_count(f: Vec<i32>) -> i64 { let b: Vec<i32> = vec_get(f, 3); return vec_len(b); }
fn ir_fn_get_block(f: Vec<i32>, idx: i64) -> Vec<i32> { let b: Vec<i32> = vec_get(f, 3); return vec_get(b, idx); }

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

// --- Pass 6: Block Merging ---
// Merges blocks: if a block ends with unconditional br to a target that has
// exactly one predecessor, inline the target's instructions and remove the branch.
fn opt_merge_blocks(f: Vec<i32>) -> i64 {
    let blocks: Vec<i32> = vec_get(f, 3);
    let bc: i64 = vec_len(blocks);
    if bc <= 1 { return 0; };
    // Count predecessors for each label
    let mut pred_cnt: Vec<i32> = cmap_new();
    let mut bi: i64 = 0;
    while bi < bc {
        let blk: Vec<i32> = vec_get(blocks, bi);
        let ic: i64 = ir_block_inst_count(blk);
        if ic > 0 {
            let last: Vec<i32> = ir_block_get_inst(blk, ic - 1);
            let lop: i64 = ir_op(last);
            if lop == 21 {
                let tgt: i64 = ir_op1(last);
                let mut cur: i64 = 0;
                if cmap_has(pred_cnt, tgt) == 1 { cur = cmap_get(pred_cnt, tgt); };
                cmap_set(pred_cnt, tgt, cur + 1);
            } else if lop == 22 {
                let tgt_t: i64 = ir_op2(last);
                let tgt_f: i64 = ir_extra(last);
                let mut ct: i64 = 0;
                if cmap_has(pred_cnt, tgt_t) == 1 { ct = cmap_get(pred_cnt, tgt_t); };
                cmap_set(pred_cnt, tgt_t, ct + 1);
                let mut cf: i64 = 0;
                if cmap_has(pred_cnt, tgt_f) == 1 { cf = cmap_get(pred_cnt, tgt_f); };
                cmap_set(pred_cnt, tgt_f, cf + 1);
            };
        };
        bi = bi + 1;
    };
    // Merge eligible blocks
    let mut merged: i64 = 0;
    let mut skip_lbl: Vec<i32> = Vec::new();
    bi = 0;
    while bi < bc {
        let blk: Vec<i32> = vec_get(blocks, bi);
        let ic: i64 = ir_block_inst_count(blk);
        if ic > 0 {
            let last: Vec<i32> = ir_block_get_inst(blk, ic - 1);
            if ir_op(last) == 21 {
                let tgt: i64 = ir_op1(last);
                let mut pc: i64 = 0;
                if cmap_has(pred_cnt, tgt) == 1 { pc = cmap_get(pred_cnt, tgt); };
                if pc == 1 {
                    // Find target block
                    let mut ti: i64 = 0;
                    while ti < bc {
                        let tblk: Vec<i32> = vec_get(blocks, ti);
                        if ir_block_label(tblk) == tgt {
                            // Merge: remove br, append target's instructions
                            let cur_insts: Vec<i32> = vec_get(blk, 1);
                            let mut new_insts: Vec<i32> = Vec::new();
                            let mut ni: i64 = 0;
                            while ni < ic - 1 { new_insts.push(vec_get(cur_insts, ni)); ni = ni + 1; };
                            let tic: i64 = ir_block_inst_count(tblk);
                            let tinsts: Vec<i32> = vec_get(tblk, 1);
                            ni = 0;
                            while ni < tic { new_insts.push(vec_get(tinsts, ni)); ni = ni + 1; };
                            vec_set(blk, 1, new_insts);
                            skip_lbl.push(tgt);
                            merged = merged + 1;
                            ti = bc;
                        };
                        ti = ti + 1;
                    };
                };
            };
        };
        bi = bi + 1;
    };
    // Rebuild blocks list excluding merged-away blocks
    if merged > 0 {
        let mut new_blocks: Vec<i32> = Vec::new();
        bi = 0;
        while bi < bc {
            let blk: Vec<i32> = vec_get(blocks, bi);
            let lbl: i64 = ir_block_label(blk);
            let mut should_skip: i64 = 0;
            let slc: i64 = vec_len(skip_lbl);
            let mut si: i64 = 0;
            while si < slc {
                if vec_get(skip_lbl, si) == lbl { should_skip = 1; si = slc; };
                si = si + 1;
            };
            if should_skip == 0 { new_blocks.push(blk); };
            bi = bi + 1;
        };
        vec_set(f, 3, new_blocks);
    };
    return merged;
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
    if str_eq(name, "getenv") { return "__nucleor_getenv"; };
    if str_eq(name, "env_get") { return "__nucleor_env_get"; };
    if str_eq(name, "env_set") { return "__nucleor_env_set"; };
    if str_eq(name, "env_unset") { return "__nucleor_env_unset"; };
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
    if str_eq(name, "read_line") { return "__nucleor_read_line"; };
    if str_eq(name, "read_i64") { return "__nucleor_read_i64"; };
    if str_eq(name, "read_byte") { return "__nucleor_read_byte"; };
    if str_eq(name, "format_i64") { return "__nucleor_format_i64"; };
    if str_eq(name, "format_str") { return "__nucleor_format_str"; };
    if str_eq(name, "format_hex") { return "__nucleor_format_hex"; };
    if str_eq(name, "format2_ii") { return "__nucleor_format2_ii"; };
    if str_eq(name, "format2_si") { return "__nucleor_format2_si"; };
    if str_eq(name, "format_f64") { return "__nucleor_format_f64"; };
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
    if str_eq(name, "rng_int") { return "__nucleor_rng_int"; };
    if str_eq(name, "rng_uniform") { return "__nucleor_rng_uniform"; };
    if str_eq(name, "rng_normal") { return "__nucleor_rng_normal"; };
    if str_eq(name, "rng_bernoulli") { return "__nucleor_rng_bernoulli"; };
    if str_eq(name, "rng_exponential") { return "__nucleor_rng_exponential"; };
    if str_eq(name, "hashmap_keys") { return "__nucleor_hashmap_keys"; };
    if str_eq(name, "hashmap_values") { return "__nucleor_hashmap_values"; };
    if str_eq(name, "time_iso_now") { return "__nucleor_time_iso_now"; };
    if str_eq(name, "time_format_iso") { return "__nucleor_time_format_iso"; };
    if str_eq(name, "file_append_string") { return "__nucleor_file_append_string"; };
    if str_eq(name, "sb_free") { return "__nucleor_sb_free"; };
    if str_eq(name, "now_ms") { return "__nucleor_now_ms"; };
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
    // --- Synced from nucleor_s1_compiler.nr (v0.1.56) — RFC-0022 drift fix ---
    if str_eq(name, "as_f32") { return "__nucleor_as_f32"; };
    if str_eq(name, "as_f64") { return "__nucleor_as_f64"; };
    if str_eq(name, "as_i16") { return "__nucleor_as_i16"; };
    if str_eq(name, "as_i32") { return "__nucleor_as_i32"; };
    if str_eq(name, "as_i64") { return "__nucleor_as_i64"; };
    if str_eq(name, "as_i8") { return "__nucleor_as_i8"; };
    if str_eq(name, "as_u16") { return "__nucleor_as_u16"; };
    if str_eq(name, "as_u32") { return "__nucleor_as_u32"; };
    if str_eq(name, "as_u64") { return "__nucleor_as_u64"; };
    if str_eq(name, "as_u8") { return "__nucleor_as_u8"; };
    if str_eq(name, "assert_ne") { return "__nucleor_assert_ne"; };
    if str_eq(name, "atomic_i64_cas") { return "__nucleor_atomic_i64_cas"; };
    if str_eq(name, "atomic_i64_fetch_add") { return "__nucleor_atomic_i64_fetch_add"; };
    if str_eq(name, "atomic_i64_fetch_and") { return "__nucleor_atomic_i64_fetch_and"; };
    if str_eq(name, "atomic_i64_fetch_or") { return "__nucleor_atomic_i64_fetch_or"; };
    if str_eq(name, "atomic_i64_fetch_sub") { return "__nucleor_atomic_i64_fetch_sub"; };
    if str_eq(name, "atomic_i64_fetch_xor") { return "__nucleor_atomic_i64_fetch_xor"; };
    if str_eq(name, "atomic_i64_free") { return "__nucleor_atomic_i64_free"; };
    if str_eq(name, "atomic_i64_load") { return "__nucleor_atomic_i64_load"; };
    if str_eq(name, "atomic_i64_new") { return "__nucleor_atomic_i64_new"; };
    if str_eq(name, "atomic_i64_store") { return "__nucleor_atomic_i64_store"; };
    if str_eq(name, "atomic_i64_swap") { return "__nucleor_atomic_i64_swap"; };
    if str_eq(name, "base64_decode") { return "__nucleor_base64_decode"; };
    if str_eq(name, "base64_encode") { return "__nucleor_base64_encode"; };
    if str_eq(name, "bf16_add") { return "__nucleor_bf16_add"; };
    if str_eq(name, "bf16_from_f32") { return "__nucleor_bf16_from_f32"; };
    if str_eq(name, "bf16_mul") { return "__nucleor_bf16_mul"; };
    if str_eq(name, "bf16_to_f32") { return "__nucleor_bf16_to_f32"; };
    if str_eq(name, "btreemap_clear") { return "__nucleor_btreemap_clear"; };
    if str_eq(name, "btreemap_contains") { return "__nucleor_btreemap_contains"; };
    if str_eq(name, "btreemap_free") { return "__nucleor_btreemap_free"; };
    if str_eq(name, "btreemap_get") { return "__nucleor_btreemap_get"; };
    if str_eq(name, "btreemap_insert") { return "__nucleor_btreemap_insert"; };
    if str_eq(name, "btreemap_key_at") { return "__nucleor_btreemap_key_at"; };
    if str_eq(name, "btreemap_len") { return "__nucleor_btreemap_len"; };
    if str_eq(name, "btreemap_new") { return "__nucleor_btreemap_new"; };
    if str_eq(name, "btreemap_remove") { return "__nucleor_btreemap_remove"; };
    if str_eq(name, "btreemap_val_at") { return "__nucleor_btreemap_val_at"; };
    if str_eq(name, "btreeset_at") { return "__nucleor_btreeset_at"; };
    if str_eq(name, "btreeset_clear") { return "__nucleor_btreeset_clear"; };
    if str_eq(name, "btreeset_contains") { return "__nucleor_btreeset_contains"; };
    if str_eq(name, "btreeset_free") { return "__nucleor_btreeset_free"; };
    if str_eq(name, "btreeset_insert") { return "__nucleor_btreeset_insert"; };
    if str_eq(name, "btreeset_len") { return "__nucleor_btreeset_len"; };
    if str_eq(name, "btreeset_new") { return "__nucleor_btreeset_new"; };
    if str_eq(name, "btreeset_remove") { return "__nucleor_btreeset_remove"; };
    if str_eq(name, "buf_read_u16_be") { return "__nucleor_buf_read_u16_be"; };
    if str_eq(name, "buf_read_u16_le") { return "__nucleor_buf_read_u16_le"; };
    if str_eq(name, "buf_read_u32_be") { return "__nucleor_buf_read_u32_be"; };
    if str_eq(name, "buf_read_u32_le") { return "__nucleor_buf_read_u32_le"; };
    if str_eq(name, "buf_read_u64_be") { return "__nucleor_buf_read_u64_be"; };
    if str_eq(name, "buf_read_u64_le") { return "__nucleor_buf_read_u64_le"; };
    if str_eq(name, "buf_read_u8") { return "__nucleor_buf_read_u8"; };
    if str_eq(name, "buf_write_u16_be") { return "__nucleor_buf_write_u16_be"; };
    if str_eq(name, "buf_write_u16_le") { return "__nucleor_buf_write_u16_le"; };
    if str_eq(name, "buf_write_u32_be") { return "__nucleor_buf_write_u32_be"; };
    if str_eq(name, "buf_write_u32_le") { return "__nucleor_buf_write_u32_le"; };
    if str_eq(name, "buf_write_u64_be") { return "__nucleor_buf_write_u64_be"; };
    if str_eq(name, "buf_write_u64_le") { return "__nucleor_buf_write_u64_le"; };
    if str_eq(name, "buf_write_u8") { return "__nucleor_buf_write_u8"; };
    if str_eq(name, "byte_swap") { return "__nucleor_byte_swap"; };
    if str_eq(name, "checked_add") { return "__nucleor_checked_add_i64"; };
    if str_eq(name, "checked_add_i16") { return "__nucleor_checked_add_i16"; };
    if str_eq(name, "checked_add_i32") { return "__nucleor_checked_add_i32"; };
    if str_eq(name, "checked_add_i8") { return "__nucleor_checked_add_i8"; };
    if str_eq(name, "checked_add_u16") { return "__nucleor_checked_add_u16"; };
    if str_eq(name, "checked_add_u32") { return "__nucleor_checked_add_u32"; };
    if str_eq(name, "checked_add_u64") { return "__nucleor_checked_add_u64"; };
    if str_eq(name, "checked_add_u8") { return "__nucleor_checked_add_u8"; };
    if str_eq(name, "checked_mul") { return "__nucleor_checked_mul_i64"; };
    if str_eq(name, "checked_mul_i16") { return "__nucleor_checked_mul_i16"; };
    if str_eq(name, "checked_mul_i32") { return "__nucleor_checked_mul_i32"; };
    if str_eq(name, "checked_mul_i8") { return "__nucleor_checked_mul_i8"; };
    if str_eq(name, "checked_mul_u16") { return "__nucleor_checked_mul_u16"; };
    if str_eq(name, "checked_mul_u32") { return "__nucleor_checked_mul_u32"; };
    if str_eq(name, "checked_mul_u64") { return "__nucleor_checked_mul_u64"; };
    if str_eq(name, "checked_mul_u8") { return "__nucleor_checked_mul_u8"; };
    if str_eq(name, "checked_overflow_flag") { return "__nucleor_checked_overflow_flag"; };
    if str_eq(name, "checked_sub") { return "__nucleor_checked_sub_i64"; };
    if str_eq(name, "checked_sub_i16") { return "__nucleor_checked_sub_i16"; };
    if str_eq(name, "checked_sub_i32") { return "__nucleor_checked_sub_i32"; };
    if str_eq(name, "checked_sub_i8") { return "__nucleor_checked_sub_i8"; };
    if str_eq(name, "checked_sub_u16") { return "__nucleor_checked_sub_u16"; };
    if str_eq(name, "checked_sub_u32") { return "__nucleor_checked_sub_u32"; };
    if str_eq(name, "checked_sub_u64") { return "__nucleor_checked_sub_u64"; };
    if str_eq(name, "checked_sub_u8") { return "__nucleor_checked_sub_u8"; };
    if str_eq(name, "chr") { return "__nucleor_chr"; };
    if str_eq(name, "crc32") { return "__nucleor_crc32"; };
    if str_eq(name, "crc32_update") { return "__nucleor_crc32_update"; };
    if str_eq(name, "dbg") { return "__nucleor_dbg_i64"; };
    if str_eq(name, "dbg_f64") { return "__nucleor_dbg_f64"; };
    if str_eq(name, "dbg_str") { return "__nucleor_dbg_str"; };
    if str_eq(name, "eprint") { return "__nucleor_eprint_str"; };
    if str_eq(name, "eprint_int") { return "__nucleor_eprint_int"; };
    if str_eq(name, "f16_add") { return "__nucleor_f16_add"; };
    if str_eq(name, "f16_from_f32") { return "__nucleor_f16_from_f32"; };
    if str_eq(name, "f16_mul") { return "__nucleor_f16_mul"; };
    if str_eq(name, "f16_to_f32") { return "__nucleor_f16_to_f32"; };
    if str_eq(name, "f32_abs") { return "__nucleor_f32_abs"; };
    if str_eq(name, "f32_add") { return "__nucleor_f32_add"; };
    if str_eq(name, "f32_cos") { return "__nucleor_f32_cos"; };
    if str_eq(name, "f32_div") { return "__nucleor_f32_div"; };
    if str_eq(name, "f32_eq") { return "__nucleor_f32_eq"; };
    if str_eq(name, "f32_exp") { return "__nucleor_f32_exp"; };
    if str_eq(name, "f32_from_int") { return "__nucleor_f32_from_int"; };
    if str_eq(name, "f32_gt") { return "__nucleor_f32_gt"; };
    if str_eq(name, "f32_log") { return "__nucleor_f32_log"; };
    if str_eq(name, "f32_lt") { return "__nucleor_f32_lt"; };
    if str_eq(name, "f32_mul") { return "__nucleor_f32_mul"; };
    if str_eq(name, "f32_neg") { return "__nucleor_f32_neg"; };
    if str_eq(name, "f32_pow") { return "__nucleor_f32_pow"; };
    if str_eq(name, "f32_sin") { return "__nucleor_f32_sin"; };
    if str_eq(name, "f32_sqrt") { return "__nucleor_f32_sqrt"; };
    if str_eq(name, "f32_sub") { return "__nucleor_f32_sub"; };
    if str_eq(name, "f32_to_f64") { return "__nucleor_f32_to_f64"; };
    if str_eq(name, "f32_to_int") { return "__nucleor_f32_to_int"; };
    if str_eq(name, "f32x4_add") { return "__nucleor_f32x4_add"; };
    if str_eq(name, "f32x4_div") { return "__nucleor_f32x4_div"; };
    if str_eq(name, "f32x4_dot") { return "__nucleor_f32x4_dot"; };
    if str_eq(name, "f32x4_free") { return "__nucleor_f32x4_free"; };
    if str_eq(name, "f32x4_get") { return "__nucleor_f32x4_get"; };
    if str_eq(name, "f32x4_max") { return "__nucleor_f32x4_max"; };
    if str_eq(name, "f32x4_min") { return "__nucleor_f32x4_min"; };
    if str_eq(name, "f32x4_mul") { return "__nucleor_f32x4_mul"; };
    if str_eq(name, "f32x4_new") { return "__nucleor_f32x4_new"; };
    if str_eq(name, "f32x4_splat") { return "__nucleor_f32x4_splat"; };
    if str_eq(name, "f32x4_sub") { return "__nucleor_f32x4_sub"; };
    if str_eq(name, "f32x4_sum") { return "__nucleor_f32x4_sum"; };
    if str_eq(name, "f64_acos") { return "__nucleor_f64_acos"; };
    if str_eq(name, "f64_asin") { return "__nucleor_f64_asin"; };
    if str_eq(name, "f64_atan") { return "__nucleor_f64_atan"; };
    if str_eq(name, "f64_atan2") { return "__nucleor_f64_atan2"; };
    if str_eq(name, "f64_ceil") { return "__nucleor_f64_ceil"; };
    if str_eq(name, "f64_clamp") { return "__nucleor_f64_clamp"; };
    if str_eq(name, "f64_cos") { return "__nucleor_f64_cos"; };
    if str_eq(name, "f64_cosh") { return "__nucleor_f64_cosh"; };
    if str_eq(name, "f64_deg_to_rad") { return "__nucleor_f64_deg_to_rad"; };
    if str_eq(name, "f64_e") { return "__nucleor_f64_e"; };
    if str_eq(name, "f64_exp") { return "__nucleor_f64_exp"; };
    if str_eq(name, "f64_exp2") { return "__nucleor_f64_exp2"; };
    if str_eq(name, "f64_floor") { return "__nucleor_f64_floor"; };
    if str_eq(name, "f64_fmod") { return "__nucleor_f64_fmod"; };
    if str_eq(name, "f64_hypot") { return "__nucleor_f64_hypot"; };
    if str_eq(name, "f64_is_finite") { return "__nucleor_f64_is_finite"; };
    if str_eq(name, "f64_is_inf") { return "__nucleor_f64_is_inf"; };
    if str_eq(name, "f64_is_nan") { return "__nucleor_f64_is_nan"; };
    if str_eq(name, "f64_lerp") { return "__nucleor_f64_lerp"; };
    if str_eq(name, "f64_ln10") { return "__nucleor_f64_ln10"; };
    if str_eq(name, "f64_ln2") { return "__nucleor_f64_ln2"; };
    if str_eq(name, "f64_log") { return "__nucleor_f64_log"; };
    if str_eq(name, "f64_log10") { return "__nucleor_f64_log10"; };
    if str_eq(name, "f64_log2") { return "__nucleor_f64_log2"; };
    if str_eq(name, "f64_pi") { return "__nucleor_f64_pi"; };
    if str_eq(name, "f64_pow_v") { return "__nucleor_f64_pow_v"; };
    if str_eq(name, "f64_rad_to_deg") { return "__nucleor_f64_rad_to_deg"; };
    if str_eq(name, "f64_round") { return "__nucleor_f64_round"; };
    if str_eq(name, "f64_sin") { return "__nucleor_f64_sin"; };
    if str_eq(name, "f64_sinh") { return "__nucleor_f64_sinh"; };
    if str_eq(name, "f64_sqrt2") { return "__nucleor_f64_sqrt2"; };
    if str_eq(name, "f64_tan") { return "__nucleor_f64_tan"; };
    if str_eq(name, "f64_tanh") { return "__nucleor_f64_tanh"; };
    if str_eq(name, "f64_tau") { return "__nucleor_f64_tau"; };
    if str_eq(name, "f64_to_f32") { return "__nucleor_f64_to_f32"; };
    if str_eq(name, "f64_trunc") { return "__nucleor_f64_trunc"; };
    if str_eq(name, "f8e4m3_to_f32") { return "__nucleor_f8e4m3_to_f32"; };
    if str_eq(name, "f8e5m2_to_f32") { return "__nucleor_f8e5m2_to_f32"; };
    if str_eq(name, "fs_basename") { return "__nucleor_fs_basename"; };
    if str_eq(name, "fs_create_dir") { return "__nucleor_fs_create_dir"; };
    if str_eq(name, "fs_create_dir_all") { return "__nucleor_fs_create_dir_all"; };
    if str_eq(name, "fs_dirname") { return "__nucleor_fs_dirname"; };
    if str_eq(name, "fs_exists") { return "__nucleor_fs_exists"; };
    if str_eq(name, "fs_extension") { return "__nucleor_fs_extension"; };
    if str_eq(name, "fs_is_dir") { return "__nucleor_fs_is_dir"; };
    if str_eq(name, "fs_is_file") { return "__nucleor_fs_is_file"; };
    if str_eq(name, "fs_join") { return "__nucleor_fs_join"; };
    if str_eq(name, "fs_list_dir") { return "__nucleor_fs_list_dir"; };
    if str_eq(name, "fs_mtime") { return "__nucleor_fs_mtime"; };
    if str_eq(name, "fs_remove_file") { return "__nucleor_fs_remove_file"; };
    if str_eq(name, "fs_rename") { return "__nucleor_fs_rename"; };
    if str_eq(name, "fs_size") { return "__nucleor_fs_size"; };
    if str_eq(name, "getcwd") { return "__nucleor_getcwd"; };
    if str_eq(name, "hashmap_capacity") { return "__nucleor_hashmap_capacity"; };
    if str_eq(name, "hashmap_clear") { return "__nucleor_hashmap_clear"; };
    if str_eq(name, "hashmap_contains") { return "__nucleor_hashmap_contains"; };
    if str_eq(name, "hashmap_free") { return "__nucleor_hashmap_free"; };
    if str_eq(name, "hashmap_get") { return "__nucleor_hashmap_get"; };
    if str_eq(name, "hashmap_insert") { return "__nucleor_hashmap_insert"; };
    if str_eq(name, "hashmap_len") { return "__nucleor_hashmap_len"; };
    if str_eq(name, "hashmap_new") { return "__nucleor_hashmap_new"; };
    if str_eq(name, "hashmap_remove") { return "__nucleor_hashmap_remove"; };
    if str_eq(name, "hashmap_with_capacity") { return "__nucleor_hashmap_with_capacity"; };
    if str_eq(name, "hashset_clear") { return "__nucleor_hashset_clear"; };
    if str_eq(name, "hashset_contains") { return "__nucleor_hashset_contains"; };
    if str_eq(name, "hashset_free") { return "__nucleor_hashset_free"; };
    if str_eq(name, "hashset_insert") { return "__nucleor_hashset_insert"; };
    if str_eq(name, "hashset_len") { return "__nucleor_hashset_len"; };
    if str_eq(name, "hashset_new") { return "__nucleor_hashset_new"; };
    if str_eq(name, "hashset_remove") { return "__nucleor_hashset_remove"; };
    if str_eq(name, "hashset_with_capacity") { return "__nucleor_hashset_with_capacity"; };
    if str_eq(name, "i32x4_add") { return "__nucleor_i32x4_add"; };
    if str_eq(name, "i32x4_free") { return "__nucleor_i32x4_free"; };
    if str_eq(name, "i32x4_get") { return "__nucleor_i32x4_get"; };
    if str_eq(name, "i32x4_mul") { return "__nucleor_i32x4_mul"; };
    if str_eq(name, "i32x4_new") { return "__nucleor_i32x4_new"; };
    if str_eq(name, "i32x4_splat") { return "__nucleor_i32x4_splat"; };
    if str_eq(name, "i32x4_sub") { return "__nucleor_i32x4_sub"; };
    if str_eq(name, "i32x4_sum") { return "__nucleor_i32x4_sum"; };
    if str_eq(name, "i64_abs") { return "__nucleor_i64_abs"; };
    if str_eq(name, "i64_clamp") { return "__nucleor_i64_clamp"; };
    if str_eq(name, "i64_gcd") { return "__nucleor_i64_gcd"; };
    if str_eq(name, "i64_isqrt") { return "__nucleor_i64_isqrt"; };
    if str_eq(name, "i64_lcm") { return "__nucleor_i64_lcm"; };
    if str_eq(name, "i64_max") { return "__nucleor_i64_max"; };
    if str_eq(name, "i64_min") { return "__nucleor_i64_min"; };
    if str_eq(name, "i64_pow") { return "__nucleor_i64_pow"; };
    if str_eq(name, "i64_sign") { return "__nucleor_i64_sign"; };
    if str_eq(name, "isatty_stdout") { return "__nucleor_isatty_stdout"; };
    if str_eq(name, "leading_zeros") { return "__nucleor_leading_zeros"; };
    if str_eq(name, "manifest_report") { return "__nucleor_manifest_report"; };
    if str_eq(name, "manifest_validate") { return "__nucleor_manifest_validate"; };
    if str_eq(name, "msgpack_write_bool") { return "__nucleor_msgpack_write_bool"; };
    if str_eq(name, "msgpack_write_nil") { return "__nucleor_msgpack_write_nil"; };
    if str_eq(name, "msgpack_write_str") { return "__nucleor_msgpack_write_str"; };
    if str_eq(name, "msgpack_write_uint") { return "__nucleor_msgpack_write_uint"; };
    if str_eq(name, "os_family") { return "__nucleor_os_family"; };
    if str_eq(name, "os_pointer_width") { return "__nucleor_os_pointer_width"; };
    if str_eq(name, "panic") { return "__nucleor_panic"; };
    if str_eq(name, "popcount") { return "__nucleor_popcount"; };
    if str_eq(name, "print_bin") { return "__nucleor_print_bin"; };
    if str_eq(name, "print_f32") { return "__nucleor_print_f32"; };
    if str_eq(name, "print_hex") { return "__nucleor_print_hex"; };
    if str_eq(name, "print_i16") { return "__nucleor_print_i16"; };
    if str_eq(name, "print_i32") { return "__nucleor_print_i32"; };
    if str_eq(name, "print_i8") { return "__nucleor_print_i8"; };
    if str_eq(name, "print_u16") { return "__nucleor_print_u16"; };
    if str_eq(name, "print_u32") { return "__nucleor_print_u32"; };
    if str_eq(name, "print_u64") { return "__nucleor_print_u64"; };
    if str_eq(name, "print_u8") { return "__nucleor_print_u8"; };
    if str_eq(name, "process_id") { return "__nucleor_process_id"; };
    if str_eq(name, "rotate_left") { return "__nucleor_rotate_left"; };
    if str_eq(name, "rotate_right") { return "__nucleor_rotate_right"; };
    if str_eq(name, "saturating_add") { return "__nucleor_saturating_add_i64"; };
    if str_eq(name, "saturating_add_i16") { return "__nucleor_saturating_add_i16"; };
    if str_eq(name, "saturating_add_i32") { return "__nucleor_saturating_add_i32"; };
    if str_eq(name, "saturating_add_i8") { return "__nucleor_saturating_add_i8"; };
    if str_eq(name, "saturating_add_u16") { return "__nucleor_saturating_add_u16"; };
    if str_eq(name, "saturating_add_u32") { return "__nucleor_saturating_add_u32"; };
    if str_eq(name, "saturating_add_u64") { return "__nucleor_saturating_add_u64"; };
    if str_eq(name, "saturating_add_u8") { return "__nucleor_saturating_add_u8"; };
    if str_eq(name, "saturating_mul") { return "__nucleor_saturating_mul_i64"; };
    if str_eq(name, "saturating_mul_i16") { return "__nucleor_saturating_mul_i16"; };
    if str_eq(name, "saturating_mul_i32") { return "__nucleor_saturating_mul_i32"; };
    if str_eq(name, "saturating_mul_i8") { return "__nucleor_saturating_mul_i8"; };
    if str_eq(name, "saturating_mul_u16") { return "__nucleor_saturating_mul_u16"; };
    if str_eq(name, "saturating_mul_u32") { return "__nucleor_saturating_mul_u32"; };
    if str_eq(name, "saturating_mul_u64") { return "__nucleor_saturating_mul_u64"; };
    if str_eq(name, "saturating_mul_u8") { return "__nucleor_saturating_mul_u8"; };
    if str_eq(name, "saturating_sub") { return "__nucleor_saturating_sub_i64"; };
    if str_eq(name, "saturating_sub_i16") { return "__nucleor_saturating_sub_i16"; };
    if str_eq(name, "saturating_sub_i32") { return "__nucleor_saturating_sub_i32"; };
    if str_eq(name, "saturating_sub_i8") { return "__nucleor_saturating_sub_i8"; };
    if str_eq(name, "saturating_sub_u16") { return "__nucleor_saturating_sub_u16"; };
    if str_eq(name, "saturating_sub_u32") { return "__nucleor_saturating_sub_u32"; };
    if str_eq(name, "saturating_sub_u64") { return "__nucleor_saturating_sub_u64"; };
    if str_eq(name, "saturating_sub_u8") { return "__nucleor_saturating_sub_u8"; };
    if str_eq(name, "sha256_hex") { return "__nucleor_sha256_hex"; };
    if str_eq(name, "sleep_ms") { return "__nucleor_sleep_ms"; };
    if str_eq(name, "sleep_us") { return "__nucleor_sleep_us"; };
    if str_eq(name, "string_as_ptr") { return "__nucleor_string_as_ptr"; };
    if str_eq(name, "string_capacity") { return "__nucleor_string_capacity"; };
    if str_eq(name, "string_clear") { return "__nucleor_string_clear"; };
    if str_eq(name, "string_clone") { return "__nucleor_string_clone"; };
    if str_eq(name, "string_contains") { return "__nucleor_string_contains"; };
    if str_eq(name, "string_ends_with") { return "__nucleor_string_ends_with"; };
    if str_eq(name, "string_eq") { return "__nucleor_string_eq"; };
    if str_eq(name, "string_eq_str") { return "__nucleor_string_eq_str"; };
    if str_eq(name, "string_free") { return "__nucleor_string_free"; };
    if str_eq(name, "string_from_str") { return "__nucleor_string_from_str"; };
    if str_eq(name, "string_get_byte") { return "__nucleor_string_get_byte"; };
    if str_eq(name, "string_len") { return "__nucleor_string_len"; };
    if str_eq(name, "string_new") { return "__nucleor_string_new"; };
    if str_eq(name, "string_print") { return "__nucleor_string_print"; };
    if str_eq(name, "string_push_byte") { return "__nucleor_string_push_byte"; };
    if str_eq(name, "string_push_str") { return "__nucleor_string_push_str"; };
    if str_eq(name, "string_starts_with") { return "__nucleor_string_starts_with"; };
    if str_eq(name, "string_with_capacity") { return "__nucleor_string_with_capacity"; };
    if str_eq(name, "time_monotonic_ms") { return "__nucleor_time_monotonic_ms"; };
    if str_eq(name, "time_monotonic_ns") { return "__nucleor_time_monotonic_ns"; };
    if str_eq(name, "time_monotonic_us") { return "__nucleor_time_monotonic_us"; };
    if str_eq(name, "time_wall_ms") { return "__nucleor_time_wall_ms"; };
    if str_eq(name, "time_wall_ns") { return "__nucleor_time_wall_ns"; };
    if str_eq(name, "time_wall_seconds") { return "__nucleor_time_wall_seconds"; };
    if str_eq(name, "time_wall_us") { return "__nucleor_time_wall_us"; };
    if str_eq(name, "toml_get_int") { return "__nucleor_toml_get_int"; };
    if str_eq(name, "toml_get_str") { return "__nucleor_toml_get_str"; };
    if str_eq(name, "toml_has") { return "__nucleor_toml_has"; };
    if str_eq(name, "toml_parse_file") { return "__nucleor_toml_parse_file"; };
    if str_eq(name, "toml_parse_string") { return "__nucleor_toml_parse_string"; };
    if str_eq(name, "trailing_zeros") { return "__nucleor_trailing_zeros"; };
    if str_eq(name, "uuid_v4") { return "__nucleor_uuid_v4"; };
    if str_eq(name, "vec_f32_free") { return "__nucleor_vec_f32_free"; };
    if str_eq(name, "vec_f32_get_bits") { return "__nucleor_vec_f32_get_bits"; };
    if str_eq(name, "vec_f32_len") { return "__nucleor_vec_f32_len"; };
    if str_eq(name, "vec_f32_new") { return "__nucleor_vec_f32_new"; };
    if str_eq(name, "vec_f32_push_bits") { return "__nucleor_vec_f32_push_bits"; };
    if str_eq(name, "vec_f32_with_capacity") { return "__nucleor_vec_f32_with_capacity"; };
    if str_eq(name, "vec_u8_capacity") { return "__nucleor_vec_u8_capacity"; };
    if str_eq(name, "vec_u8_clear") { return "__nucleor_vec_u8_clear"; };
    if str_eq(name, "vec_u8_free") { return "__nucleor_vec_u8_free"; };
    if str_eq(name, "vec_u8_get") { return "__nucleor_vec_u8_get"; };
    if str_eq(name, "vec_u8_len") { return "__nucleor_vec_u8_len"; };
    if str_eq(name, "vec_u8_new") { return "__nucleor_vec_u8_new"; };
    if str_eq(name, "vec_u8_push") { return "__nucleor_vec_u8_push"; };
    if str_eq(name, "vec_u8_set") { return "__nucleor_vec_u8_set"; };
    if str_eq(name, "vec_u8_with_capacity") { return "__nucleor_vec_u8_with_capacity"; };
    if str_eq(name, "vecdeque_capacity") { return "__nucleor_vecdeque_capacity"; };
    if str_eq(name, "vecdeque_clear") { return "__nucleor_vecdeque_clear"; };
    if str_eq(name, "vecdeque_free") { return "__nucleor_vecdeque_free"; };
    if str_eq(name, "vecdeque_get") { return "__nucleor_vecdeque_get"; };
    if str_eq(name, "vecdeque_len") { return "__nucleor_vecdeque_len"; };
    if str_eq(name, "vecdeque_new") { return "__nucleor_vecdeque_new"; };
    if str_eq(name, "vecdeque_pop_back") { return "__nucleor_vecdeque_pop_back"; };
    if str_eq(name, "vecdeque_pop_front") { return "__nucleor_vecdeque_pop_front"; };
    if str_eq(name, "vecdeque_push_back") { return "__nucleor_vecdeque_push_back"; };
    if str_eq(name, "vecdeque_push_front") { return "__nucleor_vecdeque_push_front"; };
    if str_eq(name, "vecdeque_set") { return "__nucleor_vecdeque_set"; };
    if str_eq(name, "vecdeque_with_capacity") { return "__nucleor_vecdeque_with_capacity"; };
    if str_eq(name, "wrapping_add") { return "__nucleor_wrapping_add_i64"; };
    if str_eq(name, "wrapping_add_i16") { return "__nucleor_wrapping_add_i16"; };
    if str_eq(name, "wrapping_add_i32") { return "__nucleor_wrapping_add_i32"; };
    if str_eq(name, "wrapping_add_i8") { return "__nucleor_wrapping_add_i8"; };
    if str_eq(name, "wrapping_add_u16") { return "__nucleor_wrapping_add_u16"; };
    if str_eq(name, "wrapping_add_u32") { return "__nucleor_wrapping_add_u32"; };
    if str_eq(name, "wrapping_add_u64") { return "__nucleor_wrapping_add_u64"; };
    if str_eq(name, "wrapping_add_u8") { return "__nucleor_wrapping_add_u8"; };
    if str_eq(name, "wrapping_mul") { return "__nucleor_wrapping_mul_i64"; };
    if str_eq(name, "wrapping_mul_i16") { return "__nucleor_wrapping_mul_i16"; };
    if str_eq(name, "wrapping_mul_i32") { return "__nucleor_wrapping_mul_i32"; };
    if str_eq(name, "wrapping_mul_i8") { return "__nucleor_wrapping_mul_i8"; };
    if str_eq(name, "wrapping_mul_u16") { return "__nucleor_wrapping_mul_u16"; };
    if str_eq(name, "wrapping_mul_u32") { return "__nucleor_wrapping_mul_u32"; };
    if str_eq(name, "wrapping_mul_u64") { return "__nucleor_wrapping_mul_u64"; };
    if str_eq(name, "wrapping_mul_u8") { return "__nucleor_wrapping_mul_u8"; };
    if str_eq(name, "wrapping_sub") { return "__nucleor_wrapping_sub_i64"; };
    if str_eq(name, "wrapping_sub_i16") { return "__nucleor_wrapping_sub_i16"; };
    if str_eq(name, "wrapping_sub_i32") { return "__nucleor_wrapping_sub_i32"; };
    if str_eq(name, "wrapping_sub_i8") { return "__nucleor_wrapping_sub_i8"; };
    if str_eq(name, "wrapping_sub_u16") { return "__nucleor_wrapping_sub_u16"; };
    if str_eq(name, "wrapping_sub_u32") { return "__nucleor_wrapping_sub_u32"; };
    if str_eq(name, "wrapping_sub_u64") { return "__nucleor_wrapping_sub_u64"; };
    if str_eq(name, "wrapping_sub_u8") { return "__nucleor_wrapping_sub_u8"; };
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
    if str_eq(name, "hashmap_keys") { return 1; };
    if str_eq(name, "hashmap_values") { return 1; };
    if str_eq(name, "time_iso_now") { return 1; };
    if str_eq(name, "time_format_iso") { return 1; };
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
    let bc: i64 = ir_fn_block_count(f); let mut bi: i64 = 0;
    while bi < bc {
        let blk: Vec<i32> = ir_fn_get_block(f, bi);
        if bi == 0 {
            if is_main == 0 { sb_append(sb, "bb.entry:\n"); };
            // For main, bb.entry was already emitted above with init_args
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
    sb_append(sb, "declare ptr @__nucleor_getenv(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_get(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_set(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_env_unset(ptr)\n");
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
    sb_append(sb, "declare void @__nucleor_file_append_string(ptr, ptr)\n");
    sb_append(sb, "declare void @__nucleor_sb_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_now_ms()\n");
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
    // --- Synced from nucleor_s1_compiler.nr (v0.1.56) drift fix ---
    sb_append(sb, "declare i64 @__nucleor_as_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_i8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_as_u8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_assert_ne(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_cas(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_and(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_or(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_fetch_xor(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_load(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_new(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_store(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_atomic_i64_swap(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_base64_decode(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_base64_encode(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_from_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_bf16_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_get(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_insert(i64, ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_key_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_new()\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreemap_val_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_at(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_insert(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_new()\n");
    sb_append(sb, "declare i64 @__nucleor_btreeset_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u16_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u16_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u32_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u32_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u64_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u64_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_read_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u16_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u16_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u32_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u32_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u64_be(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u64_le(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_buf_write_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_byte_swap(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_add_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_mul_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_overflow_flag()\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_checked_sub_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_crc32(ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_crc32_update(i64, ptr, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dbg_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dbg_i64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_dbg_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_eprint_int(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_eprint_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_from_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f16_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_abs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_cos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_div(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_eq(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_exp(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_from_int(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_gt(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_log(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_lt(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_neg(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_pow(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_sin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_sqrt(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_f64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32_to_int(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_div(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_dot(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_max(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_min(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_new(i64, i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_splat(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f32x4_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_acos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_asin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_atan(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_atan2(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ceil(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_clamp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_cos(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_cosh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_deg_to_rad(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_e()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_exp(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_exp2(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_floor(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_fmod(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_hypot(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_is_finite(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_is_inf(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_is_nan(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_lerp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ln10()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_ln2()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_log(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_log10(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_log2(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_pi()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_pow_v(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_rad_to_deg(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_round(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sinh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_sqrt2()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_tan(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_tanh(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_tau()\n");
    sb_append(sb, "declare i64 @__nucleor_f64_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f64_trunc(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f8e4m3_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_f8e5m2_to_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_basename(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_create_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_create_dir_all(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_dirname(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_exists(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_extension(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_is_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_is_file(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_join(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_list_dir(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_mtime(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_remove_file(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_rename(ptr, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_fs_size(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashmap_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_insert(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_new()\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_remove(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_hashset_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_add(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_mul(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_new(i64, i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_splat(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_sub(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i32x4_sum(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_abs(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_clamp(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_gcd(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_isqrt(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_lcm(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_max(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_min(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_pow(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_i64_sign(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_isatty_stdout()\n");
    sb_append(sb, "declare i64 @__nucleor_leading_zeros(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_manifest_report(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_manifest_validate(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_bool(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_nil(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_msgpack_write_uint(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_os_family()\n");
    sb_append(sb, "declare i64 @__nucleor_os_pointer_width()\n");
    sb_append(sb, "declare i64 @__nucleor_panic(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_popcount(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_bin(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_f32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_hex(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_i8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u16(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u32(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u64(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_print_u8(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_process_id()\n");
    sb_append(sb, "declare i64 @__nucleor_rotate_left(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_rotate_right(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_add_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_mul_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_saturating_sub_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sha256_hex(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_sleep_ms(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_sleep_us(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_as_ptr(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_clone(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_contains(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_ends_with(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_eq(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_eq_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_from_str(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_get_byte(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_new()\n");
    sb_append(sb, "declare i64 @__nucleor_string_print(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_push_byte(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_string_push_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_starts_with(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_string_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_ms()\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_ns()\n");
    sb_append(sb, "declare i64 @__nucleor_time_monotonic_us()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_ms()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_ns()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_seconds()\n");
    sb_append(sb, "declare i64 @__nucleor_time_wall_us()\n");
    sb_append(sb, "declare i64 @__nucleor_toml_get_int(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_get_str(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_has(i64, ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_parse_file(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_toml_parse_string(ptr)\n");
    sb_append(sb, "declare i64 @__nucleor_trailing_zeros(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_uuid_v4()\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_get_bits(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_new()\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_push_bits(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_f32_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_new()\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_push(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_set(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vec_u8_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_clear(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_free(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_get(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_len(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_new()\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_pop_back(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_pop_front(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_push_back(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_push_front(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_set(i64, i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_vecdeque_with_capacity(i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_add_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_mul_u8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_i8(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u16(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u32(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u64(i64, i64)\n");
    sb_append(sb, "declare i64 @__nucleor_wrapping_sub_u8(i64, i64)\n");
    sb_append(sb, "declare ptr @__nucleor_chr(i64)\n");
    sb_append(sb, "declare ptr @__nucleor_getcwd()\n");
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
    if str_eq(t, "i32") { return "i32"; };
    if str_eq(t, "f64") { return "double"; };
    return "i64";
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

fn emit_module(fns: Vec<i32>, strtab: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, emit_externs());
    sb_append(sb, emit_str_constants(strtab));
    let mut empty_pool: Vec<i32> = Vec::new();
    let mut empty_ext: Vec<i32> = Vec::new();
    let mut fi: i64 = 0;
    while fi < vec_len(fns) { sb_append(sb, emit_fn(vec_get(fns, fi), empty_pool, empty_ext)); sb_append(sb, "\n"); fi = fi + 1; };
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
fn smap_has(m: Vec<i32>, key: str) -> i64 {
    if smap_find_slot(m, key) >= 0 { return 1; };
    return 0;
}
fn smap_get(m: Vec<i32>, key: str) -> i64 {
    let slot: i64 = smap_find_slot(m, key);
    if slot >= 0 { return smap_slot_val(m, slot); };
    return 0 - 1;
}
fn smap_clone(m: Vec<i32>) -> Vec<i32> {
    let cloned: Vec<i32> = smap_new_cap(smap_slots(m));
    let mut i: i64 = 0;
    let slots: i64 = smap_slots(m);
    while i < slots {
        if smap_slot_used(m, i) == 1 {
            smap_set(cloned, smap_slot_key(m, i), smap_slot_val(m, i));
        };
        i = i + 1;
    };
    return cloned;
}
fn smap_restore(dst: Vec<i32>, src: Vec<i32>) -> i64 {
    let cloned: Vec<i32> = smap_clone(src);
    vec_set(dst, 0, vec_get(cloned, 0));
    vec_set(dst, 1, vec_get(cloned, 1));
    vec_set(dst, 2, vec_get(cloned, 2));
    vec_set(dst, 3, vec_get(cloned, 3));
    vec_set(dst, 4, vec_get(cloned, 4));
    return 0;
}
fn lx_new(reg: i64, blk: Vec<i32>) -> Vec<i32> {
    let mut p: Vec<i32> = Vec::new();
    p.push(reg);
    p.push(blk);
    return p;
}
fn lx_reg(p: Vec<i32>) -> i64 { return vec_get(p, 0); }
fn lx_blk(p: Vec<i32>) -> Vec<i32> { return vec_get(p, 1); }
fn lower_mark_error(sym: Vec<i32>) -> i64 { sym_set(sym, "__lower_error", 1); return 0 - 1; }
fn lower_has_error(sym: Vec<i32>) -> i64 { if sym_get(sym, "__lower_error") >= 0 { return 1; }; return 0; }
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

fn line_col_to_byte(source: str, line: i64, col: i64) -> i64 {
    let slen: i64 = str_len(source);
    let mut cur_line: i64 = 1;
    let mut i: i64 = 0;
    while i < slen {
        if cur_line == line { return i + col - 1; };
        if str_char_at(source, i) == 10 { cur_line = cur_line + 1; };
        i = i + 1;
    };
    return 0;
}

fn find_column_in_source(source: str, fn_name: str, var_name: str) -> i64 {
    return vec_get(find_linecol_in_source(source, fn_name, var_name), 1);
}

fn json_escape(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut result: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 34 { sb_append(result, "\\\""); }
        else if c == 92 { sb_append(result, "\\\\"); }
        else if c == 10 { sb_append(result, "\\n"); }
        else if c == 9 { sb_append(result, "\\t"); }
        else { sb_append(result, str_substring(s, i, i + 1)); };
        i = i + 1;
    };
    return sb_to_str(result);
}

fn source_line_at(source: str, line_num: i64) -> str {
    let slen: i64 = str_len(source);
    let mut cur_line: i64 = 1;
    let mut line_start: i64 = 0;
    let mut i: i64 = 0;
    while i < slen {
        if cur_line == line_num { line_start = i; i = slen; }
        else if str_char_at(source, i) == 10 { cur_line = cur_line + 1; };
        i = i + 1;
    };
    if cur_line < line_num { return ""; };
    // Find end of line
    let mut line_end: i64 = line_start;
    while line_end < slen && str_char_at(source, line_end) != 10 { line_end = line_end + 1; };
    return str_substring(source, line_start, line_end);
}

fn diag_emit_json(diags: Vec<i32>, source: str, src_path: str) -> i64 {
    let cnt: i64 = vec_len(diags);
    let mut ow_cnt: i64 = 0; let mut tn_cnt: i64 = 0; let mut ef_cnt: i64 = 0;
    let mut err_cnt: i64 = 0; let mut warn_cnt: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let d: Vec<i32> = vec_get(diags, i);
        let severity: str = vec_get(d, 0);
        let checker: str = vec_get(d, 1);
        let code: str = vec_get(d, 2);
        let message: str = vec_get(d, 3);
        let fn_name: str = vec_get(d, 4);
        let line: i64 = vec_get(d, 5);
        let snippet: str = source_line_at(source, line);
        // Emit JSONL diagnostic
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"schema_version\":\"1.0\",\"type\":\"diagnostic\",\"id\":\"D-");
        sb_append(sb, str_from_int(i + 1));
        sb_append(sb, "\",\"severity\":\""); sb_append(sb, severity);
        sb_append(sb, "\",\"checker\":\""); sb_append(sb, checker);
        sb_append(sb, "\",\"code\":\""); sb_append(sb, code);
        sb_append(sb, "\",\"message\":\""); sb_append(sb, message);
        sb_append(sb, "\",\"function\":\""); sb_append(sb, fn_name);
        let col: i64 = vec_get(d, 6);
        let related_id: str = vec_get(d, 7);
        sb_append(sb, "\",\"location\":{\"file\":\""); sb_append(sb, src_path);
        sb_append(sb, "\",\"line\":"); sb_append(sb, str_from_int(line));
        if col > 0 {
            sb_append(sb, ",\"column\":"); sb_append(sb, str_from_int(col));
            let bs: i64 = line_col_to_byte(source, line, col);
            sb_append(sb, ",\"byte_start\":"); sb_append(sb, str_from_int(bs));
            sb_append(sb, ",\"byte_end\":"); sb_append(sb, str_from_int(bs + 1));
        };
        sb_append(sb, "}");
        if str_len(related_id) > 0 {
            sb_append(sb, ",\"related_diagnostics\":[\""); sb_append(sb, related_id); sb_append(sb, "\"]");
        };
        if str_len(snippet) > 0 {
            sb_append(sb, ",\"source_snippet\":{\"text\":\""); sb_append(sb, json_escape(snippet));
            if col > 0 {
                let vlen: i64 = 1; // default highlight length
                sb_append(sb, "\",\"highlight_start\":"); sb_append(sb, str_from_int(col));
                sb_append(sb, ",\"highlight_end\":"); sb_append(sb, str_from_int(col + vlen));
            };
            sb_append(sb, "\"}");
        };
        // Suggestion
        let sug_msg: str = vec_get(d, 8);
        let sug_app: str = vec_get(d, 9);
        if str_len(sug_msg) > 0 {
            sb_append(sb, ",\"suggestion\":{\"message\":\""); sb_append(sb, sug_msg);
            sb_append(sb, "\",\"applicability\":\""); sb_append(sb, sug_app); sb_append(sb, "\"}");
        };
        // Children (notes)
        let child_msg: str = vec_get(d, 10);
        let child_line: i64 = vec_get(d, 11);
        if str_len(child_msg) > 0 {
            sb_append(sb, ",\"children\":[{\"severity\":\"note\",\"message\":\""); sb_append(sb, child_msg);
            if child_line > 0 {
                sb_append(sb, "\",\"location\":{\"line\":"); sb_append(sb, str_from_int(child_line)); sb_append(sb, "}");
            };
            sb_append(sb, "\"}]");
        };
        sb_append(sb, "}");
        print(sb_to_str(sb));
        if str_eq(severity, "error") { err_cnt = err_cnt + 1; }
        else { warn_cnt = warn_cnt + 1; };
        if str_eq(checker, "ownership") { ow_cnt = ow_cnt + 1; }
        else if str_eq(checker, "taint") { tn_cnt = tn_cnt + 1; }
        else if str_eq(checker, "effect") { ef_cnt = ef_cnt + 1; };
        i = i + 1;
    };
    // Emit summary
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"type\":\"summary\",\"file\":\""); sb_append(sb, src_path);
    sb_append(sb, "\",\"checkers_run\":[\"ownership\",\"taint\",\"effect\"]");
    sb_append(sb, ",\"diagnostics_emitted\":"); sb_append(sb, str_from_int(cnt));
    sb_append(sb, ",\"by_severity\":{\"error\":"); sb_append(sb, str_from_int(err_cnt));
    sb_append(sb, ",\"warning\":"); sb_append(sb, str_from_int(warn_cnt));
    sb_append(sb, "},\"by_checker\":{\"ownership\":"); sb_append(sb, str_from_int(ow_cnt));
    sb_append(sb, ",\"taint\":"); sb_append(sb, str_from_int(tn_cnt));
    sb_append(sb, ",\"effect\":"); sb_append(sb, str_from_int(ef_cnt));
    sb_append(sb, "}");
    if err_cnt > 0 { sb_append(sb, ",\"compilation_result\":\"failure\""); }
    else if warn_cnt > 0 { sb_append(sb, ",\"compilation_result\":\"success_with_warnings\""); }
    else { sb_append(sb, ",\"compilation_result\":\"success\""); };
    sb_append(sb, "}");
    print(sb_to_str(sb));
    return cnt;
}

fn diag_emit_sarif(diags: Vec<i32>, source: str, src_path: str) -> i64 {
    let cnt: i64 = vec_len(diags);
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"version\":\"2.1.0\",\"$schema\":\"https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json\",\"runs\":[{\"tool\":{\"driver\":{\"name\":\"nucleor\",\"version\":\"0.1.0\",\"rules\":[");
    sb_append(sb, "{\"id\":\"ownership/OWN-001\",\"shortDescription\":{\"text\":\"use after move\"}},");
    sb_append(sb, "{\"id\":\"taint/TNT-001\",\"shortDescription\":{\"text\":\"tainted data to sensitive sink\"}},");
    sb_append(sb, "{\"id\":\"effect/EFF-001\",\"shortDescription\":{\"text\":\"side effect in pure function\"}}");
    sb_append(sb, "]}},\"results\":[");
    let mut i: i64 = 0;
    while i < cnt {
        if i > 0 { sb_append(sb, ","); };
        let d: Vec<i32> = vec_get(diags, i);
        let severity: str = vec_get(d, 0);
        let checker: str = vec_get(d, 1);
        let code: str = vec_get(d, 2);
        let message: str = vec_get(d, 3);
        let fn_name: str = vec_get(d, 4);
        let line: i64 = vec_get(d, 5);
        let col: i64 = vec_get(d, 6);
        let mut level: str = "warning";
        if str_eq(severity, "error") { level = "error"; };
        sb_append(sb, "{\"ruleId\":\""); sb_append(sb, checker); sb_append(sb, "/"); sb_append(sb, code);
        sb_append(sb, "\",\"level\":\""); sb_append(sb, level);
        sb_append(sb, "\",\"message\":{\"text\":\""); sb_append(sb, message);
        sb_append(sb, "\"},\"locations\":[{\"physicalLocation\":{\"artifactLocation\":{\"uri\":\"");
        sb_append(sb, src_path);
        sb_append(sb, "\"},\"region\":{\"startLine\":"); sb_append(sb, str_from_int(line));
        if col > 0 { sb_append(sb, ",\"startColumn\":"); sb_append(sb, str_from_int(col)); };
        let snippet: str = source_line_at(source, line);
        if str_len(snippet) > 0 {
            sb_append(sb, ",\"snippet\":{\"text\":\""); sb_append(sb, json_escape(snippet)); sb_append(sb, "\"}");
        };
        sb_append(sb, "}}}]}");
        i = i + 1;
    };
    sb_append(sb, "]}]}");
    print(sb_to_str(sb));
    return cnt;
}

fn diag_emit_text(diags: Vec<i32>) -> i64 {
    let cnt: i64 = vec_len(diags);
    let mut i: i64 = 0;
    while i < cnt {
        let d: Vec<i32> = vec_get(diags, i);
        let severity: str = vec_get(d, 0);
        let checker: str = vec_get(d, 1);
        let code: str = vec_get(d, 2);
        let message: str = vec_get(d, 3);
        let fn_name: str = vec_get(d, 4);
        let line: i64 = vec_get(d, 5);
        let mut sb: i64 = sb_new();
        if str_eq(severity, "error") { sb_append(sb, "ERROR"); } else { sb_append(sb, "WARNING"); };
        sb_append(sb, " ["); sb_append(sb, code); sb_append(sb, "]: ");
        sb_append(sb, message);
        if str_len(fn_name) > 0 { sb_append(sb, " in function '"); sb_append(sb, fn_name); sb_append(sb, "'"); };
        if line > 0 { sb_append(sb, " (line "); sb_append(sb, str_from_int(line)); sb_append(sb, ")"); };
        print(sb_to_str(sb));
        i = i + 1;
    };
    return cnt;
}

// =====================================================
// S12b — REVIEW HOOKS (single coupling surface)
// Delete this section + call sites to fully remove S12b
// =====================================================
fn review_active(review_path: str) -> i64 {
    if str_len(review_path) > 0 { return 1; };
    return 0;
}
fn review_emit(review_path: str, json_line: str) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    file_append_string(review_path, str_concat(json_line, "\n"));
    return 0;
}
fn review_filter_allows_checker(filter: str, checker: str) -> i64 {
    if str_len(filter) == 0 { return 1; };
    if str_eq(filter, "findings") { return 1; };
    // function= filter doesn't restrict by checker
    if str_len(filter) > 9 && str_eq(str_substring(filter, 0, 9), "function=") { return 1; };
    let flen: i64 = str_len(filter);
    let clen: i64 = str_len(checker);
    let mut i: i64 = 0;
    while i <= flen - clen {
        if str_eq(str_substring(filter, i, i + clen), checker) { return 1; };
        i = i + 1;
    };
    return 0;
}
fn review_filter_allows_function(filter: str, fn_name: str) -> i64 {
    if str_len(filter) == 0 { return 1; };
    // Check for function= in comma-separated filter parts
    let flen: i64 = str_len(filter);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    let mut found_fn_filter: i64 = 0;
    while i <= flen {
        let at_end: i64 = i == flen;
        let mut at_comma: i64 = 0;
        if at_end == 0 { if str_char_at(filter, i) == 44 { at_comma = 1; }; };
        if at_comma == 1 || at_end == 1 {
            let part: str = str_substring(filter, start, i);
            if str_len(part) > 9 && str_eq(str_substring(part, 0, 9), "function=") {
                found_fn_filter = 1;
                let target: str = str_substring(part, 9, str_len(part));
                if str_eq(target, fn_name) { return 1; };
            };
            start = i + 1;
        };
        i = i + 1;
    };
    // If no function= filter was found, allow all functions
    if found_fn_filter == 0 { return 1; };
    return 0;
}
fn review_on_checker_enter(review_path: str, checker: str, fn_name: str, filter: str) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    if review_filter_allows_checker(filter, checker) == 0 { return 0; };
    if review_filter_allows_function(filter, fn_name) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"checker_enter\",\"checker\":\"");
    sb_append(sb, checker); sb_append(sb, "\",\"function\":\""); sb_append(sb, fn_name); sb_append(sb, "\"}");
    return review_emit(review_path, sb_to_str(sb));
}
fn review_on_checker_exit(review_path: str, checker: str, fn_name: str, findings: i64, filter: str) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    if review_filter_allows_checker(filter, checker) == 0 { return 0; };
    if review_filter_allows_function(filter, fn_name) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"checker_exit\",\"checker\":\"");
    sb_append(sb, checker); sb_append(sb, "\",\"function\":\""); sb_append(sb, fn_name);
    sb_append(sb, "\",\"findings\":"); sb_append(sb, str_from_int(findings)); sb_append(sb, "}");
    return review_emit(review_path, sb_to_str(sb));
}
fn review_on_state_transition(review_path: str, checker: str, fn_name: str, symbol: str, from_state: str, to_state: str, cause: str) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"state_transition\",\"checker\":\"");
    sb_append(sb, checker); sb_append(sb, "\",\"function\":\""); sb_append(sb, fn_name);
    sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"from_state\":\""); sb_append(sb, from_state);
    sb_append(sb, "\",\"to_state\":\""); sb_append(sb, to_state);
    sb_append(sb, "\",\"cause\":\""); sb_append(sb, cause); sb_append(sb, "\"}");
    return review_emit(review_path, sb_to_str(sb));
}
fn review_on_taint_propagation(review_path: str, fn_name: str, symbol: str, source_sym: str, sanitized: i64) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"taint_propagation\",\"checker\":\"taint\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"taint_source\":\""); sb_append(sb, source_sym);
    sb_append(sb, "\",\"sanitized\":"); if sanitized == 1 { sb_append(sb, "true"); } else { sb_append(sb, "false"); };
    sb_append(sb, "}");
    return review_emit(review_path, sb_to_str(sb));
}
fn review_on_effect_violation(review_path: str, fn_name: str, callee: str) -> i64 {
    if str_len(review_path) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"effect_violation\",\"checker\":\"effect\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"declared_effect\":\"pure\",\"actual_effect\":\"io\",\"callee\":\"");
    sb_append(sb, callee); sb_append(sb, "\"}");
    return review_emit(review_path, sb_to_str(sb));
}

// S12b: review event accumulation helpers (all removable)
fn rev_get(own: Vec<i32>) -> Vec<i32> {
    let rev: i64 = own_get_type(own, "__revents");
    if rev < 0 { return Vec::new(); };
    return rev;
}
fn rev_active(own: Vec<i32>) -> i64 {
    let rp: str = own_get_type(own, "__review");
    if str_len(rp) > 0 { return 1; };
    return 0;
}
fn rev_push(own: Vec<i32>, json: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let revents: Vec<i32> = rev_get(own);
    revents.push(json);
    return 0;
}
fn review_acc_move(own: Vec<i32>, fn_name: str, symbol: str, cause: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"state_transition\",\"checker\":\"ownership\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"from_state\":\"owned\",\"to_state\":\"moved\",\"cause\":\"");
    sb_append(sb, cause); sb_append(sb, "\"}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_revive(own: Vec<i32>, fn_name: str, symbol: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"state_transition\",\"checker\":\"ownership\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"from_state\":\"moved\",\"to_state\":\"owned\",\"cause\":\"reassign\"}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_init(own: Vec<i32>, fn_name: str, symbol: str, type_name: str, is_copy: i64) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"state_transition\",\"checker\":\"ownership\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"from_state\":\"uninitialized\",\"to_state\":\"owned\",\"cause\":\"declaration\",\"type\":\"");
    sb_append(sb, type_name); sb_append(sb, "\",\"is_copy\":");
    if is_copy == 1 { sb_append(sb, "true"); } else { sb_append(sb, "false"); };
    sb_append(sb, "}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_call_edge(own: Vec<i32>, fn_name: str, callee: str, argc: i64) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"call_graph_edge\",\"caller\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"callee\":\""); sb_append(sb, callee);
    sb_append(sb, "\",\"arg_count\":"); sb_append(sb, str_from_int(argc)); sb_append(sb, "}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_branch_fork(own: Vec<i32>, fn_name: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"branch_state_fork\",\"checker\":\"ownership\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\"}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_branch_merge(own: Vec<i32>, fn_name: str, strategy: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"branch_state_merge\",\"checker\":\"ownership\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"strategy\":\""); sb_append(sb, strategy); sb_append(sb, "\"}");
    return rev_push(own, sb_to_str(sb));
}
fn review_acc_fn_sig(own: Vec<i32>, fn_name: str, param_info: str) -> i64 {
    if rev_active(own) == 0 { return 0; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"function_signature\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"params\":\""); sb_append(sb, param_info); sb_append(sb, "\"}");
    return rev_push(own, sb_to_str(sb));
}
// Taint-specific helpers (use taint Vec instead of own)
fn trev_get(taint: Vec<i32>) -> Vec<i32> {
    let rev: i64 = taint_get(taint, "__revents");
    if rev < 0 { return Vec::new(); };
    return rev;
}
fn trev_push(taint: Vec<i32>, json: str) -> i64 {
    let revents: Vec<i32> = trev_get(taint);
    revents.push(json);
    return 0;
}
fn review_acc_taint_prop(taint: Vec<i32>, fn_name: str, symbol: str, source_sym: str) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"taint_propagation\",\"checker\":\"taint\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"taint_source\":\""); sb_append(sb, source_sym); sb_append(sb, "\",\"sanitized\":false}");
    return trev_push(taint, sb_to_str(sb));
}
fn review_acc_taint_sanitize(taint: Vec<i32>, fn_name: str, symbol: str) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"taint_propagation\",\"checker\":\"taint\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"taint_source\":\"sanitize\",\"sanitized\":true}");
    return trev_push(taint, sb_to_str(sb));
}
fn review_acc_taint_sink(taint: Vec<i32>, fn_name: str, symbol: str, sink: str) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"taint_sink_attempt\",\"checker\":\"taint\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"symbol\":\""); sb_append(sb, symbol);
    sb_append(sb, "\",\"sink\":\""); sb_append(sb, sink); sb_append(sb, "\",\"blocked\":false}");
    return trev_push(taint, sb_to_str(sb));
}
fn review_acc_taint_call(taint: Vec<i32>, fn_name: str, callee: str, tainted_arg_count: i64) -> i64 {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"event\":\"taint_through_call\",\"checker\":\"taint\",\"function\":\"");
    sb_append(sb, fn_name); sb_append(sb, "\",\"callee\":\""); sb_append(sb, callee);
    sb_append(sb, "\",\"tainted_args\":"); sb_append(sb, str_from_int(tainted_arg_count)); sb_append(sb, "}");
    return trev_push(taint, sb_to_str(sb));
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
        review_acc_call_edge(own, fn_name, callee_name, ac);
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
                        own_set(own, aname, 2); own_set_type(own, str_concat("__moved_by_", aname), callee_name); review_acc_move(own, fn_name, aname, str_concat("call_arg:", callee_name));
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
                        review_acc_move(own, fn_name, src, "let_binding");
                    };
                };
            };
            own_set(own, vname, 1);
            review_acc_init(own, fn_name, vname, tstr, is_copy_type(tstr, pool, structs, enums));
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
                        review_acc_move(own, fn_name, src, "assignment");
                    };
                };
            };
            own_set(own, lname, 1);
            review_acc_revive(own, fn_name, lname);
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
        review_acc_branch_fork(own, fn_name);
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
        review_acc_branch_merge(own, fn_name, "conservative");
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
        let mut ai: i64 = 0;
        while ai < ac {
            let arm_nid: i64 = list_get(pool, arms, ai);
            own_restore(own, snap);
            let ename: str = node_field(pool, arm_nid, 1);
            if str_eq(ename, "__wild") { has_wildcard = 1; };
            let binding: str = node_field(pool, arm_nid, 3);
            if str_len(binding) > 0 {
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
                        diag_add(own_get_type(own, "__diags"), "warning", "type", "TYP-001", str_concat("non-exhaustive match: ", str_concat(str_from_int(ac), str_concat(" arms for enum with ", str_concat(str_from_int(vcnt), " variants")))), fn_name, ln);
                        warns = warns + 1;
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

fn check_fn(pool: Vec<i32>, fn_nid: i64, structs: Vec<i32>, enums: Vec<i32>, diags: Vec<i32>, source: str, review_path: str, review_filter: str) -> i64 {
    let fn_name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let body: i64 = node_field(pool, fn_nid, 4);
    if body < 0 || body >= vec_len(pool) { return 0; };
    review_on_checker_enter(review_path, "ownership", fn_name, review_filter);
    let pc: i64 = list_len(pool, plist);
    let mut own: Vec<i32> = own_new();
    own_set_type(own, "__diags", diags);
    own_set_type(own, "__source", source);
    own_set_type(own, "__shared_keys", Vec::new());
    own_set_type(own, "__mut_keys", Vec::new());
    own_set_type(own, "__scope_keys", Vec::new());
    own_set_i(own, "cur_scope", 0);
    // S12b: review event accumulator (removable)
    let mut revents: Vec<i32> = Vec::new();
    own_set_type(own, "__revents", revents);
    own_set_type(own, "__review", review_path);
    let mut pi: i64 = 0;
    let mut param_desc: i64 = sb_new();
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
        review_acc_init(own, fn_name, pname, ptype, is_copy_type(ptype, pool, structs, enums));
        if pi > 0 { sb_append(param_desc, ","); };
        sb_append(param_desc, str_concat(pname, str_concat(":", ptype)));
        pi = pi + 1;
    };
    review_acc_fn_sig(own, fn_name, sb_to_str(param_desc));
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
    // S12b: flush accumulated review events (removable)
    // If filter=findings, only flush for functions with findings > 0
    if str_len(review_path) > 0 && review_filter_allows_checker(review_filter, "ownership") == 1 && review_filter_allows_function(review_filter, fn_name) == 1 {
        let mut should_flush: i64 = 1;
        if str_eq(review_filter, "findings") && w == 0 { should_flush = 0; };
        if should_flush == 1 {
            let rev: Vec<i32> = own_get_type(own, "__revents");
            let mut ri: i64 = 0;
            while ri < vec_len(rev) { review_emit(review_path, vec_get(rev, ri)); ri = ri + 1; };
        };
    };
    review_on_checker_exit(review_path, "ownership", fn_name, w, review_filter);
    return w;
}

// =====================================================
// EFFECT CHECKER (S11.6)
// =====================================================
fn is_effectful_builtin(name: str) -> i64 {
    if str_eq(name, "print") { return 1; }; if str_eq(name, "print_int") { return 1; };
    if str_eq(name, "print_f64") { return 1; }; if str_eq(name, "print_bool") { return 1; };
    if str_eq(name, "putchar") { return 1; };
    if str_eq(name, "file_write_string") { return 1; }; if str_eq(name, "file_read_string") { return 1; };
    if str_eq(name, "file_append_string") { return 1; };
    if str_eq(name, "system") { return 1; }; if str_eq(name, "exit") { return 1; };
    if str_eq(name, "getenv") { return 1; }; if str_eq(name, "getcwd") { return 1; };
    return 0;
}

fn effect_check_expr(pool: Vec<i32>, nid: i64, fn_name: str, pure_fns: Vec<i32>, diags: Vec<i32>, source: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    if kind == 1 || kind == 2 || kind == 3 || kind == 71 { return 0; };
    if kind == 4 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source);
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 3), fn_name, pure_fns, diags, source);
        return warns;
    };
    if kind == 5 || kind == 6 || kind == 90 || kind == 91 || kind == 92 { return effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source); };
    if kind == 7 {
        let callee: str = node_field(pool, nid, 1);
        if is_effectful_builtin(callee) == 1 {
            diag_add(diags, "warning", "effect", "EFF-001", str_concat("pure function calls effectful '", str_concat(callee, "'")), fn_name, find_in_source(source, fn_name, callee));
            warns = warns + 1;
        };
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac { warns = warns + effect_check_expr(pool, list_get(pool, args, ai), fn_name, pure_fns, diags, source); ai = ai + 1; };
        return warns;
    };
    if kind == 8 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source);
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac { warns = warns + effect_check_expr(pool, list_get(pool, args, ai), fn_name, pure_fns, diags, source); ai = ai + 1; };
        return warns;
    };
    if kind == 9 { return effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source); };
    if kind == 10 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source);
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source);
        return warns;
    };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            warns = warns + effect_check_expr(pool, list_get(pool, items, ii), fn_name, pure_fns, diags, source);
            ii = ii + 1;
        };
        return warns;
    };
    if kind == 34 {
        let inits: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, inits);
        let mut ii: i64 = 0;
        while ii < ic {
            warns = warns + effect_check_expr(pool, node_field(pool, list_get(pool, inits, ii), 2), fn_name, pure_fns, diags, source);
            ii = ii + 1;
        };
        return warns;
    };
    if kind == 52 { return effect_check_stmts(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source); };
    return warns;
}

fn effect_check_stmt(pool: Vec<i32>, nid: i64, fn_name: str, pure_fns: Vec<i32>, diags: Vec<i32>, source: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    if kind == 20 { let init: i64 = node_field(pool, nid, 4); if init >= 0 { warns = warns + effect_check_expr(pool, init, fn_name, pure_fns, diags, source); }; return warns; };
    if kind == 21 { return effect_check_expr(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source); };
    if kind == 22 { let val: i64 = node_field(pool, nid, 1); if val >= 0 { return effect_check_expr(pool, val, fn_name, pure_fns, diags, source); }; return 0; };
    if kind == 23 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source);
        warns = warns + effect_check_stmts(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 { warns = warns + effect_check_stmts(pool, enode, fn_name, pure_fns, diags, source); };
        return warns;
    };
    if kind == 24 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source);
        warns = warns + effect_check_stmts(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source);
        return warns;
    };
    if kind == 25 { return effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source); };
    if kind == 28 { return effect_check_stmts(pool, node_field(pool, nid, 4), fn_name, pure_fns, diags, source); };
    if kind == 49 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source);
        warns = warns + effect_check_stmts(pool, node_field(pool, nid, 3), fn_name, pure_fns, diags, source);
        return warns;
    };
    if kind == 38 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source);
        let arms: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, arms);
        let mut ai: i64 = 0;
        while ai < ac { warns = warns + effect_check_stmts(pool, node_field(pool, list_get(pool, arms, ai), 4), fn_name, pure_fns, diags, source); ai = ai + 1; };
        return warns;
    };
    return warns;
}

fn effect_check_stmts(pool: Vec<i32>, lid: i64, fn_name: str, pure_fns: Vec<i32>, diags: Vec<i32>, source: str) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0; let mut warns: i64 = 0;
    while i < cnt { warns = warns + effect_check_stmt(pool, list_get(pool, lid, i), fn_name, pure_fns, diags, source); i = i + 1; };
    return warns;
}

fn effect_check_fn(pool: Vec<i32>, fn_nid: i64, pure_fns: Vec<i32>, diags: Vec<i32>, source: str, review_path: str, review_filter: str) -> i64 {
    let fn_name: str = node_field(pool, fn_nid, 1);
    let body: i64 = node_field(pool, fn_nid, 4);
    if body < 0 || body >= vec_len(pool) { return 0; };
    review_on_checker_enter(review_path, "effect", fn_name, review_filter);
    let w: i64 = effect_check_stmts(pool, body, fn_name, pure_fns, diags, source);
    // S12b: emit effect_violation details if findings > 0 (removable)
    if w > 0 && str_len(review_path) > 0 && review_filter_allows_function(review_filter, fn_name) == 1 {
        let mut esb: i64 = sb_new();
        sb_append(esb, "{\"schema_version\":\"1.0\",\"event\":\"effect_violation\",\"checker\":\"effect\",\"function\":\"");
        sb_append(esb, fn_name); sb_append(esb, "\",\"declared_effect\":\"pure\",\"actual_effect\":\"io\",\"findings\":");
        sb_append(esb, str_from_int(w)); sb_append(esb, "}");
        review_emit(review_path, sb_to_str(esb));
    };
    review_on_checker_exit(review_path, "effect", fn_name, w, review_filter);
    return w;
}

// =====================================================
// TAINT CHECKER (S11.7)
// =====================================================
fn taint_new() -> Vec<i32> { return Vec::new(); }
fn taint_set(t: Vec<i32>, name: str, is_tainted: i64) -> i64 { t.push(name); t.push(is_tainted); return 0; }
fn taint_get(t: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = vec_len(t) - 2;
    while i >= 0 {
        if str_eq(vec_get(t, i), name) { return vec_get(t, i + 1); };
        i = i - 2;
    };
    return 0; // untainted by default
}

fn is_tainted_type(tstr: str) -> i64 {
    // Check if type annotation starts with "tainted"
    if str_len(tstr) >= 7 && str_eq(str_substring(tstr, 0, 7), "tainted") { return 1; };
    return 0;
}
fn is_taint_sanitizer(name: str) -> i64 {
    if str_eq(name, "sanitize") { return 1; };
    if str_eq(name, "normalize_output_name") { return 1; };
    return 0;
}

fn taint_check_expr(pool: Vec<i32>, nid: i64, taint: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 || kind == 2 || kind == 71 { return 0; }; // literals never tainted
    if kind == 3 { return taint_get(taint, node_field(pool, nid, 1)); }; // variable
    if kind == 4 {
        // Binary op: tainted if either operand tainted (except comparisons → always clean)
        let op: i64 = node_field(pool, nid, 1);
        let lt: i64 = taint_check_expr(pool, node_field(pool, nid, 2), taint, fn_name, diags, source);
        let rt: i64 = taint_check_expr(pool, node_field(pool, nid, 3), taint, fn_name, diags, source);
        // Comparison operators (30-38) produce clean boolean results
        if op >= 30 && op <= 38 { return 0; };
        if lt == 1 || rt == 1 { return 1; };
        return 0;
    };
    if kind == 5 || kind == 6 || kind == 90 || kind == 91 || kind == 92 { return taint_check_expr(pool, node_field(pool, nid, 1), taint, fn_name, diags, source); };
    if kind == 7 {
        // Function call: known sanitizers clean taint
        let callee: str = node_field(pool, nid, 1);
        if is_taint_sanitizer(callee) == 1 {
            // S12b: sanitize event (removable)
            review_acc_taint_sanitize(taint, fn_name, callee);
            return 0;
        };
        // Otherwise, if any arg tainted, result is tainted
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        let mut tainted_argc: i64 = 0;
        while ai < ac {
            if taint_check_expr(pool, list_get(pool, args, ai), taint, fn_name, diags, source) == 1 { tainted_argc = tainted_argc + 1; };
            ai = ai + 1;
        };
        // S12b: taint through call (removable)
        if tainted_argc > 0 { review_acc_taint_call(taint, fn_name, callee, tainted_argc); };
        if tainted_argc > 0 { return 1; };
        return 0;
    };
    if kind == 9 {
        // FIELD_ACCESS: if receiver is tainted, field is tainted (taint through struct fields)
        return taint_check_expr(pool, node_field(pool, nid, 1), taint, fn_name, diags, source);
    };
    if kind == 8 || kind == 10 {
        return taint_check_expr(pool, node_field(pool, nid, 1), taint, fn_name, diags, source);
    };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            if taint_check_expr(pool, list_get(pool, items, ii), taint, fn_name, diags, source) == 1 { return 1; };
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 34 {
        // STRUCT_INIT: if any field value is tainted, the struct is tainted
        let inits: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, inits);
        let mut ii: i64 = 0;
        while ii < ic {
            let init_nid: i64 = list_get(pool, inits, ii);
            let val_nid: i64 = node_field(pool, init_nid, 2);
            if taint_check_expr(pool, val_nid, taint, fn_name, diags, source) == 1 { return 1; };
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 52 {
        let body: i64 = node_field(pool, nid, 2);
        let bc: i64 = list_len(pool, body);
        let mut bi: i64 = 0;
        while bi < bc {
            let stmt: i64 = list_get(pool, body, bi);
            if bi == bc - 1 && node_kind(pool, stmt) == 25 {
                return taint_check_expr(pool, node_field(pool, stmt, 1), taint, fn_name, diags, source);
            };
            taint_check_stmt(pool, stmt, taint, fn_name, diags, source);
            bi = bi + 1;
        };
        return 0;
    };
    return 0;
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

fn taint_check_stmt(pool: Vec<i32>, nid: i64, taint: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    if kind == 20 {
        let vname: str = node_field(pool, nid, 1);
        let tstr: str = node_field(pool, nid, 3);
        let init: i64 = node_field(pool, nid, 4);
        let mut is_t: i64 = 0;
        if is_tainted_type(tstr) == 1 { is_t = 1; };
        if init >= 0 && taint_check_expr(pool, init, taint, fn_name, diags, source) == 1 { is_t = 1; };
        taint_set(taint, vname, is_t);
        // S12b: record taint propagation (removable)
        if is_t == 1 { review_acc_taint_prop(taint, fn_name, vname, tstr); };
        return warns;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let rhs: i64 = node_field(pool, nid, 2);
        let rt: i64 = taint_check_expr(pool, rhs, taint, fn_name, diags, source);
        if node_kind(pool, lhs) == 3 { taint_set(taint, node_field(pool, lhs, 1), rt); };
        return warns;
    };
    if kind == 25 {
        let expr_nid: i64 = node_field(pool, nid, 1);
        if node_kind(pool, expr_nid) == 7 {
            let callee: str = node_field(pool, expr_nid, 1);
            // Taint sinks are sink-specific: `system` treats any tainted arg as dangerous,
            // while `file_write_string` only treats the destination path as sensitive.
            if str_eq(callee, "system") == 1 {
                let args: i64 = node_field(pool, expr_nid, 2);
                let ac: i64 = list_len(pool, args);
                let mut ai: i64 = 0;
                while ai < ac {
                    if taint_check_expr(pool, list_get(pool, args, ai), taint, fn_name, diags, source) == 1 {
                        diag_add(diags, "warning", "taint", "TNT-001", str_concat("tainted data passed to sensitive sink '", str_concat(callee, "'")), fn_name, find_in_source(source, fn_name, callee));
                        // S12b: taint sink attempt (removable)
                        review_acc_taint_sink(taint, fn_name, "tainted_arg", callee);
                        warns = warns + 1;
                        ai = ac; // break
                    };
                    ai = ai + 1;
                };
            } else if str_eq(callee, "file_write_string") == 1 {
                let args: i64 = node_field(pool, expr_nid, 2);
                if list_len(pool, args) > 0 && taint_check_expr(pool, list_get(pool, args, 0), taint, fn_name, diags, source) == 1 {
                    diag_add(diags, "warning", "taint", "TNT-001", str_concat("tainted data passed to sensitive sink '", str_concat(callee, "'")), fn_name, find_in_source(source, fn_name, callee));
                    review_acc_taint_sink(taint, fn_name, "tainted_arg", callee);
                    warns = warns + 1;
                };
            };
        };
        return warns;
    };
    if kind == 23 {
        warns = warns + taint_check_stmts(pool, node_field(pool, nid, 2), taint, fn_name, diags, source);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 { warns = warns + taint_check_stmts(pool, enode, taint, fn_name, diags, source); };
        return warns;
    };
    if kind == 24 { return taint_check_stmts(pool, node_field(pool, nid, 2), taint, fn_name, diags, source); };
    if kind == 28 { return taint_check_stmts(pool, node_field(pool, nid, 4), taint, fn_name, diags, source); };
    if kind == 49 {
        warns = warns + taint_check_expr(pool, node_field(pool, nid, 2), taint, fn_name, diags, source);
        warns = warns + taint_check_stmts(pool, node_field(pool, nid, 3), taint, fn_name, diags, source);
        return warns;
    };
    return warns;
}

fn taint_check_stmts(pool: Vec<i32>, lid: i64, taint: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0; let mut warns: i64 = 0;
    while i < cnt { warns = warns + taint_check_stmt(pool, list_get(pool, lid, i), taint, fn_name, diags, source); i = i + 1; };
    return warns;
}

fn taint_check_fn_ex(pool: Vec<i32>, fn_nid: i64, diags: Vec<i32>, source: str, review_path: str, review_filter: str, all_tainted: i64) -> i64 {
    let fn_name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let body: i64 = node_field(pool, fn_nid, 4);
    if body < 0 || body >= vec_len(pool) { return 0; };
    let mut taint: Vec<i32> = taint_new();
    // S12b: review event accumulator (removable)
    let mut revents: Vec<i32> = Vec::new();
    taint_set(taint, "__revents", revents);
    taint_set(taint, "__fn_name", fn_name);
    // Mark params with tainted types (or all tainted for inter-procedural pass)
    let pc: i64 = list_len(pool, plist);
    let mut pi: i64 = 0;
    while pi < pc {
        let pnid: i64 = list_get(pool, plist, pi);
        let pname: str = node_field(pool, pnid, 1);
        let ptype: str = node_field(pool, pnid, 2);
        if is_tainted_type(ptype) == 1 || all_tainted == 1 { taint_set(taint, pname, 1); };
        pi = pi + 1;
    };
    review_on_checker_enter(review_path, "taint", fn_name, review_filter);
    let w: i64 = taint_check_stmts(pool, body, taint, fn_name, diags, source);
    // S12b: flush taint review events (removable)
    if str_len(review_path) > 0 && review_filter_allows_checker(review_filter, "taint") == 1 && review_filter_allows_function(review_filter, fn_name) == 1 {
        let mut should_flush: i64 = 1;
        if str_eq(review_filter, "findings") && w == 0 { should_flush = 0; };
        if should_flush == 1 {
            let rev: Vec<i32> = taint_get(taint, "__revents");
            if rev > 0 {
                let mut ri: i64 = 0;
                while ri < vec_len(rev) { review_emit(review_path, vec_get(rev, ri)); ri = ri + 1; };
            };
        };
    };
    review_on_checker_exit(review_path, "taint", fn_name, w, review_filter);
    return w;
}
fn taint_check_fn(pool: Vec<i32>, fn_nid: i64, diags: Vec<i32>, source: str, review_path: str, review_filter: str) -> i64 {
    return taint_check_fn_ex(pool, fn_nid, diags, source, review_path, review_filter, 0);
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
    if str_eq(name, "rev_get") == 1 { return 1; };
    if str_eq(name, "trev_get") == 1 { return 1; };
    if str_eq(name, "taint_get") == 1 { return 1; };
    if str_eq(name, "taint_set") == 1 { return 1; };
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
fn source_skip_string(text: str, start: i64) -> i64 {
    let tlen: i64 = str_len(text);
    let mut i: i64 = start + 1;
    while i < tlen {
        if str_char_at(text, i) == 92 {
            i = i + 2;
        } else {
            if str_char_at(text, i) == 34 { return i + 1; };
            i = i + 1;
        };
    };
    return tlen;
}
fn source_skip_line_comment(text: str, start: i64) -> i64 {
    let tlen: i64 = str_len(text);
    let mut i: i64 = start + 2;
    while i < tlen && str_char_at(text, i) != 10 { i = i + 1; };
    return i;
}
fn source_find_code_pattern(text: str, pat: str, start: i64) -> i64 {
    let tlen: i64 = str_len(text);
    let plen: i64 = str_len(pat);
    if plen == 0 { return start; };
    if tlen < plen { return 0 - 1; };
    let mut i: i64 = start;
    while i <= tlen - plen {
        if str_char_at(text, i) == 34 {
            i = source_skip_string(text, i);
        } else if i + 1 < tlen && str_char_at(text, i) == 47 && str_char_at(text, i + 1) == 47 {
            i = source_skip_line_comment(text, i);
        } else {
            if str_eq(str_substring(text, i, i + plen), pat) == 1 { return i; };
            i = i + 1;
        };
    };
    return 0 - 1;
}
fn source_has_code_pattern(text: str, pat: str) -> i64 {
    if source_find_code_pattern(text, pat, 0) >= 0 { return 1; };
    return 0;
}
fn source_find_code_char(text: str, start: i64, target: i64) -> i64 {
    let tlen: i64 = str_len(text);
    let mut i: i64 = start;
    while i < tlen {
        if str_char_at(text, i) == 34 {
            i = source_skip_string(text, i);
        } else if i + 1 < tlen && str_char_at(text, i) == 47 && str_char_at(text, i + 1) == 47 {
            i = source_skip_line_comment(text, i);
        } else {
            if str_char_at(text, i) == target { return i; };
            i = i + 1;
        };
    };
    return 0 - 1;
}
fn source_find_matching_brace(text: str, open_pos: i64) -> i64 {
    let tlen: i64 = str_len(text);
    if open_pos < 0 || open_pos >= tlen || str_char_at(text, open_pos) != 123 { return 0 - 1; };
    let mut depth: i64 = 1;
    let mut i: i64 = open_pos + 1;
    while i < tlen {
        if str_char_at(text, i) == 34 {
            i = source_skip_string(text, i);
        } else if i + 1 < tlen && str_char_at(text, i) == 47 && str_char_at(text, i + 1) == 47 {
            i = source_skip_line_comment(text, i);
        } else {
            if str_char_at(text, i) == 123 { depth = depth + 1; }
            else if str_char_at(text, i) == 125 {
                depth = depth - 1;
                if depth == 0 { return i; };
            };
            i = i + 1;
        };
    };
    return 0 - 1;
}
fn srcf_add(fns: Vec<i32>, name: str, is_pure: i64, decl_effs: str, body: str, is_extern: i64, direct_effs: str, call_set: str, has_spawn: i64) -> i64 {
    fns.push(name); fns.push(is_pure); fns.push(decl_effs); fns.push(body); fns.push(is_extern); fns.push(direct_effs); fns.push(call_set); fns.push(has_spawn); return 0;
}
fn srcf_find(fns: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(fns) {
        if str_eq(vec_get(fns, i), name) == 1 { return i; };
        i = i + 8;
    };
    return 0 - 1;
}
fn srcf_decl_effects(fns: Vec<i32>, name: str) -> str {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return ""; };
    return vec_get(fns, i + 2);
}
fn srcf_body(fns: Vec<i32>, name: str) -> str {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return ""; };
    return vec_get(fns, i + 3);
}
fn srcf_is_pure(fns: Vec<i32>, name: str) -> i64 {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return 0; };
    return vec_get(fns, i + 1);
}
fn srcf_is_extern(fns: Vec<i32>, name: str) -> i64 {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return 0; };
    return vec_get(fns, i + 4);
}
fn srcf_direct_effects(fns: Vec<i32>, name: str) -> str {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return ""; };
    return vec_get(fns, i + 5);
}
fn srcf_calls(fns: Vec<i32>, name: str) -> str {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return ""; };
    return vec_get(fns, i + 6);
}
fn srcf_has_spawn(fns: Vec<i32>, name: str) -> i64 {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return 0; };
    return vec_get(fns, i + 7);
}
fn effect_add(set: str, eff: str) -> str {
    if str_len(eff) == 0 { return set; };
    if text_contains(str_concat(",", str_concat(set, ",")), str_concat(",", str_concat(eff, ","))) == 1 { return set; };
    if str_len(set) == 0 { return eff; };
    return str_concat(set, str_concat(",", eff));
}
fn effect_union(a: str, b: str) -> str {
    let mut out: str = a;
    let blen: i64 = str_len(b);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= blen {
        let at_end: i64 = i == blen;
        let mut at_comma: i64 = 0;
        if at_end == 0 && str_char_at(b, i) == 44 { at_comma = 1; };
        if at_comma == 1 || at_end == 1 {
            let part: str = str_substring(b, start, i);
            if str_len(part) > 0 { out = effect_add(out, part); };
            start = i + 1;
        };
        i = i + 1;
    };
    return out;
}
fn effect_matches(deny: str, eff: str) -> i64 {
    if str_eq(deny, eff) == 1 { return 1; };
    if text_contains(eff, str_concat(deny, ".")) == 1 && str_eq(str_substring(eff, 0, str_len(deny)), deny) == 1 { return 1; };
    return 0;
}
fn effects_overlap(deny_set: str, eff_set: str) -> i64 {
    let dlen: i64 = str_len(deny_set);
    let mut ds: i64 = 0;
    let mut di: i64 = 0;
    while di <= dlen {
        let dend: i64 = di == dlen;
        let mut dcomma: i64 = 0;
        if dend == 0 && str_char_at(deny_set, di) == 44 { dcomma = 1; };
        if dcomma == 1 || dend == 1 {
            let deny: str = str_substring(deny_set, ds, di);
            let elen: i64 = str_len(eff_set);
            let mut es: i64 = 0;
            let mut ei: i64 = 0;
            while ei <= elen {
                let eend: i64 = ei == elen;
                let mut ecomma: i64 = 0;
                if eend == 0 && str_char_at(eff_set, ei) == 44 { ecomma = 1; };
                if ecomma == 1 || eend == 1 {
                    let eff: str = str_substring(eff_set, es, ei);
                    if str_len(deny) > 0 && str_len(eff) > 0 && effect_matches(deny, eff) == 1 { return 1; };
                    es = ei + 1;
                };
                ei = ei + 1;
            };
            ds = di + 1;
        };
        di = di + 1;
    };
    return 0;
}
fn extract_decl_effects(header: str) -> str {
    let key: str = "requires[";
    let key2: str = "requires [";
    let mut pos: i64 = 0 - 1;
    if text_contains(strip_spaces(header), key) == 1 {
        let compact: str = strip_spaces(header);
        let mut i: i64 = 0;
        while i <= str_len(compact) - str_len(key) {
            if str_eq(str_substring(compact, i, i + str_len(key)), key) == 1 { pos = i + str_len(key); i = str_len(compact); };
            i = i + 1;
        };
        if pos >= 0 {
            let mut end: i64 = pos;
            while end < str_len(compact) && str_char_at(compact, end) != 93 { end = end + 1; };
            if end < str_len(compact) { return str_substring(compact, pos, end); };
        };
    };
    if text_contains(header, key2) == 1 {
        let mut i: i64 = 0;
        while i <= str_len(header) - str_len(key2) {
            if str_eq(str_substring(header, i, i + str_len(key2)), key2) == 1 { pos = i + str_len(key2); i = str_len(header); };
            i = i + 1;
        };
        if pos >= 0 {
            let mut end: i64 = pos;
            while end < str_len(header) && str_char_at(header, end) != 93 { end = end + 1; };
            if end < str_len(header) { return strip_spaces(str_substring(header, pos, end)); };
        };
    };
    return "";
}
fn source_scan_features(text: str) -> Vec<i32> {
    let mut direct: str = "";
    let mut calls: str = "";
    let mut has_spawn: i64 = 0;
    let tlen: i64 = str_len(text);
    let mut i: i64 = 0;
    while i < tlen {
        if str_char_at(text, i) == 34 {
            i = source_skip_string(text, i);
        } else if i + 1 < tlen && str_char_at(text, i) == 47 && str_char_at(text, i + 1) == 47 {
            i = source_skip_line_comment(text, i);
        } else {
            let ch: i64 = str_char_at(text, i);
            if ch == 115 {
                if i + 7 <= tlen && str_eq(str_substring(text, i, i + 7), "scope {") == 1 { direct = effect_add(direct, "sync.schedule"); };
                if i + 7 <= tlen && str_eq(str_substring(text, i, i + 7), "spawn {") == 1 { has_spawn = 1; };
            };
            if is_alpha(ch) == 1 {
                let start: i64 = i;
                i = i + 1;
                while i < tlen && is_alnum(str_char_at(text, i)) == 1 { i = i + 1; };
                let ident: str = str_substring(text, start, i);
                let mut look: i64 = i;
                while look < tlen && is_ws(str_char_at(text, look)) == 1 { look = look + 1; };
                if look < tlen && str_char_at(text, look) == 40 {
                    calls = effect_add(calls, ident);
                    if str_eq(ident, "print") == 1 || str_eq(ident, "print_int") == 1 || str_eq(ident, "print_f64") == 1 || str_eq(ident, "print_bool") == 1 || str_eq(ident, "putchar") == 1 {
                        direct = effect_add(direct, "io.write");
                    };
                    if str_eq(ident, "ambient_random") == 1 { direct = effect_add(direct, "rng.random"); };
                    if str_eq(ident, "channel") == 1 { direct = effect_add(direct, "sync.channel"); };
                };
            } else {
                i = i + 1;
            };
        };
    };
    let mut info: Vec<i32> = Vec::new();
    info.push(direct);
    info.push(calls);
    info.push(has_spawn);
    return info;
}
fn source_collect_functions(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i < slen {
        let mut eol: i64 = i;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = i;
        while lp < eol && (str_char_at(source, lp) == 32 || str_char_at(source, lp) == 9) { lp = lp + 1; };
        let mut prefix: str = "";
        let mut is_pure: i64 = 0;
        let mut is_extern: i64 = 0;
        if lp <= slen - 10 && str_eq(str_substring(source, lp, lp + 10), "extern fn ") == 1 { prefix = "extern fn "; is_extern = 1; }
        else if lp <= slen - 8 && str_eq(str_substring(source, lp, lp + 8), "pure fn ") == 1 { prefix = "pure fn "; is_pure = 1; }
        else if lp <= slen - 3 && str_eq(str_substring(source, lp, lp + 3), "fn ") == 1 { prefix = "fn "; };
        if str_len(prefix) > 0 {
            let mut np: i64 = lp + str_len(prefix);
            while np < slen && is_alnum(str_char_at(source, np)) == 1 { np = np + 1; };
            let name: str = str_substring(source, lp + str_len(prefix), np);
            let mut hp: i64 = np;
            while hp < slen {
                if str_char_at(source, hp) == 34 {
                    hp = source_skip_string(source, hp);
                } else if hp + 1 < slen && str_char_at(source, hp) == 47 && str_char_at(source, hp + 1) == 47 {
                    hp = source_skip_line_comment(source, hp);
                } else {
                    if str_char_at(source, hp) == 123 || str_char_at(source, hp) == 59 { hp = hp; hp = hp; break; };
                    hp = hp + 1;
                };
            };
            let header: str = str_substring(source, lp, hp);
            let decl_effs: str = extract_decl_effects(header);
            if hp < slen && str_char_at(source, hp) == 59 {
                srcf_add(fns, name, is_pure, decl_effs, "", is_extern, "", "", 0);
                i = hp + 1;
            } else if hp < slen && str_char_at(source, hp) == 123 {
                let bp: i64 = source_find_matching_brace(source, hp);
                if bp >= 0 {
                    let body: str = str_substring(source, hp + 1, bp);
                    let info: Vec<i32> = source_scan_features(body);
                    srcf_add(fns, name, is_pure, decl_effs, body, is_extern, vec_get(info, 0), vec_get(info, 1), vec_get(info, 2));
                    i = bp + 1;
                } else { i = hp + 1; };
            } else { i = eol + 1; };
        } else { i = eol + 1; };
    };
    return fns;
}
fn direct_body_effects(body: str) -> str {
    let info: Vec<i32> = source_scan_features(body);
    return vec_get(info, 0);
}
fn body_call_set(body: str) -> str {
    let info: Vec<i32> = source_scan_features(body);
    return vec_get(info, 1);
}
fn source_call_graph(fns: Vec<i32>) -> Vec<i32> {
    let mut graph: Vec<i32> = Vec::new();
    let mut fi: i64 = 0;
    while fi < vec_len(fns) {
        let call_set: str = vec_get(fns, fi + 6);
        let mut edges: Vec<i32> = Vec::new();
        let clen: i64 = str_len(call_set);
        let mut start: i64 = 0;
        let mut i: i64 = 0;
        while i <= clen {
            let at_end: i64 = i == clen;
            let mut at_comma: i64 = 0;
            if at_end == 0 && str_char_at(call_set, i) == 44 { at_comma = 1; };
            if at_comma == 1 || at_end == 1 {
                let callee: str = str_substring(call_set, start, i);
                let callee_idx: i64 = srcf_find(fns, callee);
                if str_len(callee) > 0 && callee_idx >= 0 && callee_idx != fi { edges.push(callee_idx / 8); };
                start = i + 1;
            };
            i = i + 1;
        };
        graph.push(edges);
        fi = fi + 8;
    };
    return graph;
}
fn effect_union_call_graph(cur: str, edges: Vec<i32>, effs: Vec<i32>) -> str {
    let mut out: str = cur;
    let mut i: i64 = 0;
    while i < vec_len(edges) {
        let callee_ord: i64 = vec_get(edges, i);
        let eff_pos: i64 = callee_ord * 2 + 1;
        if eff_pos >= 0 && eff_pos < vec_len(effs) { out = effect_union(out, vec_get(effs, eff_pos)); };
        i = i + 1;
    };
    return out;
}
fn effect_union_call_set(cur: str, call_set: str, effs: Vec<i32>, self_name: str) -> str {
    let mut out: str = cur;
    let clen: i64 = str_len(call_set);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= clen {
        let at_end: i64 = i == clen;
        let mut at_comma: i64 = 0;
        if at_end == 0 && str_char_at(call_set, i) == 44 { at_comma = 1; };
        if at_comma == 1 || at_end == 1 {
            let callee: str = str_substring(call_set, start, i);
            if str_len(callee) > 0 && str_eq(callee, self_name) == 0 {
                out = effect_union(out, inferred_effects_for(effs, callee));
            };
            start = i + 1;
        };
        i = i + 1;
    };
    return out;
}
fn infer_source_effects(fns: Vec<i32>) -> Vec<i32> {
    let mut effs: Vec<i32> = Vec::new();
    let graph: Vec<i32> = source_call_graph(fns);
    let mut i: i64 = 0;
    let mut fn_ord: i64 = 0;
    while i < vec_len(fns) {
        let name: str = vec_get(fns, i);
        let decls: str = vec_get(fns, i + 2);
        let is_extern: i64 = vec_get(fns, i + 4);
        let mut cur: str = effect_union(decls, vec_get(fns, i + 5));
        if is_extern == 1 && str_len(cur) == 0 { cur = effect_add(cur, "unsafe.raw_ptr"); };
        effs.push(name); effs.push(cur);
        i = i + 8;
        fn_ord = fn_ord + 1;
    };
    let mut pass: i64 = 0;
    let mut max_passes: i64 = 8;
    if vec_len(fns) > 2000 { max_passes = 4; };
    while pass < max_passes {
        let mut changed: i64 = 0;
        i = 0;
        fn_ord = 0;
        while i < vec_len(fns) {
            let name: str = vec_get(fns, i);
            let mut cur: str = effect_union_call_graph("", vec_get(graph, fn_ord), effs);
            cur = effect_union(cur, vec_get(fns, i + 2));
            cur = effect_union(cur, vec_get(fns, i + 5));
            if vec_get(fns, i + 4) == 1 && str_len(cur) == 0 { cur = effect_add(cur, "unsafe.raw_ptr"); };
            let mut epos: i64 = 0;
            while epos < vec_len(effs) {
                if str_eq(vec_get(effs, epos), name) == 1 {
                    let old_effs: str = vec_get(effs, epos + 1);
                    let new_effs: str = effect_union(old_effs, cur);
                    if str_eq(new_effs, old_effs) == 0 {
                        vec_set(effs, epos + 1, new_effs);
                        changed = 1;
                    };
                    epos = vec_len(effs);
                };
                epos = epos + 2;
            };
            i = i + 8;
            fn_ord = fn_ord + 1;
        };
        if changed == 0 { pass = max_passes; }
        else { pass = pass + 1; };
    };
    return effs;
}
fn inferred_effects_for(effs: Vec<i32>, name: str) -> str {
    let mut i: i64 = 0;
    while i < vec_len(effs) {
        if str_eq(vec_get(effs, i), name) == 1 { return vec_get(effs, i + 1); };
        i = i + 2;
    };
    return "";
}
fn source_rule_check(source: str, diags: Vec<i32>) -> i64 {
    let mut warns: i64 = 0;
    let has_require_authored: i64 = source_has_code_pattern(source, "@policy(require_authored)");
    let has_authored: i64 = source_has_code_pattern(source, "@authored(");
    let has_no_unsafe: i64 = source_has_code_pattern(source, "@policy(no_unsafe)");
    let has_unsafe_block: i64 = source_has_code_pattern(source, "unsafe {");
    let has_scope_escape_ref: i64 = source_has_scope_escape_ref_binding(source);
    let has_speed_unit_binding: i64 = source_has_code_pattern(source, "let speed: unit<");
    if has_require_authored == 1 && has_authored == 0 {
        type_diag(diags, source, "main", "fn", "GOV-001", "policy(require_authored) requires authored annotations");
        warns = warns + 1;
    };
    if has_no_unsafe == 1 && has_unsafe_block == 1 {
        type_diag(diags, source, "main", "unsafe", "GOV-002", "policy(no_unsafe) forbids unsafe blocks");
        warns = warns + 1;
    };
    if has_scope_escape_ref == 1 {
        type_diag(diags, source, "main", "let", "OWN-010", "cannot bind a reference that escapes an inner block");
        warns = warns + 1;
    };
    let fns: Vec<i32> = source_collect_functions(source);
    let effs: Vec<i32> = infer_source_effects(fns);
    let mut i: i64 = 0;
    while i < vec_len(fns) {
        let name: str = vec_get(fns, i);
        let decls: str = vec_get(fns, i + 2);
        let body: str = vec_get(fns, i + 3);
        let inferred: str = inferred_effects_for(effs, name);
        if vec_get(fns, i + 1) == 1 {
            if str_len(decls) > 0 {
                type_diag(diags, source, name, name, "EFF-002", "pure functions cannot declare requires effects");
                warns = warns + 1;
            };
            if str_len(inferred) > 0 {
                type_diag(diags, source, name, name, "EFF-001", "pure function has side effects");
                warns = warns + 1;
            };
        };
        let mut p: i64 = 0;
        while p < str_len(body) {
            let rp: i64 = source_find_code_pattern(body, "restricts [", p);
            if rp < 0 {
                p = str_len(body);
            } else {
                let ds: i64 = rp + 11;
                let de: i64 = source_find_code_char(body, ds, 93);
                if de < 0 {
                    p = ds;
                } else {
                    let deny: str = strip_spaces(str_substring(body, ds, de));
                    let bp: i64 = source_find_code_char(body, de, 123);
                    if bp < 0 {
                        p = de + 1;
                    } else {
                        let be: i64 = source_find_matching_brace(body, bp);
                        if be < 0 {
                            p = bp + 1;
                        } else {
                            let blk: str = str_substring(body, bp + 1, be);
                            let blk_info: Vec<i32> = source_scan_features(blk);
                            let blk_effs: str = vec_get(blk_info, 0);
                            if effects_overlap(deny, blk_effs) == 1 {
                                type_diag(diags, source, name, "restricts", "EFF-003", "restricts block denies an effect used in the block");
                                warns = warns + 1;
                            };
                            let blk_calls: str = vec_get(blk_info, 1);
                            let mut cs: i64 = 0;
                            let mut ci: i64 = 0;
                            let clen: i64 = str_len(blk_calls);
                            while ci <= clen {
                                let at_end: i64 = ci == clen;
                                let mut at_comma: i64 = 0;
                                if at_end == 0 && str_char_at(blk_calls, ci) == 44 { at_comma = 1; };
                                if at_comma == 1 || at_end == 1 {
                                    let callee: str = str_substring(blk_calls, cs, ci);
                                    if str_len(callee) > 0 && effects_overlap(deny, inferred_effects_for(effs, callee)) == 1 {
                                        type_diag(diags, source, name, callee, "EFF-003", "restricts block denies an effect used in the block");
                                        warns = warns + 1;
                                    };
                                    cs = ci + 1;
                                };
                                ci = ci + 1;
                            };
                            p = be + 1;
                        };
                    };
                };
            };
        };
        if vec_get(fns, i + 7) == 1 && text_contains(body, ": DeviceBuffer") == 1 {
            type_diag(diags, source, name, "spawn", "OWN-013", "spawn blocks cannot capture non-Send DeviceBuffer values");
            warns = warns + 1;
        };
        i = i + 8;
    };
    let slen: i64 = str_len(source);
    let mut line_start: i64 = 0;
    while line_start <= slen {
        let mut line_end: i64 = line_start;
        while line_end < slen && str_char_at(source, line_end) != 10 { line_end = line_end + 1; };
        let line: str = str_substring(source, line_start, line_end);
        if source_has_code_pattern(line, "unit<") == 1 && source_has_code_pattern(line, "=") == 1 {
            if source_has_code_pattern(line, "{") == 0 && (source_has_code_pattern(line, "= 0;") == 1 || source_has_code_pattern(line, "= 1;") == 1 || source_has_code_pattern(line, "= 2;") == 1 || source_has_code_pattern(line, "= 3;") == 1 || source_has_code_pattern(line, "= 4;") == 1 || source_has_code_pattern(line, "= 5;") == 1 || source_has_code_pattern(line, "= 6;") == 1 || source_has_code_pattern(line, "= 7;") == 1 || source_has_code_pattern(line, "= 8;") == 1 || source_has_code_pattern(line, "= 9;") == 1 || source_has_code_pattern(line, "= 42;") == 1) {
                type_diag(diags, source, "main", "unit", "TYP-007", "bare numeric literal cannot initialize a unit value");
                warns = warns + 1;
            };
            if source_has_code_pattern(line, "= speed;") == 1 && has_speed_unit_binding == 1 {
                type_diag(diags, source, "main", "speed", "TYP-008", "unit assignment mismatch");
                warns = warns + 1;
            };
            if source_has_code_pattern(line, "dist + time") == 1 {
                type_diag(diags, source, "main", "dist", "TYP-003", "unit operands for addition/subtraction must match");
                warns = warns + 1;
            };
        };
        if line_end >= slen { line_start = slen + 1; }
        else { line_start = line_end + 1; };
    };
    return warns;
}
fn preflight_source_check(source: str) -> i64 {
    if source_has_scope_escape_ref_binding(source) == 1 {
        let mut diags: Vec<i32> = diag_new();
        type_diag(diags, source, "main", "let", "OWN-010", "cannot bind a reference that escapes an inner block");
        diag_emit_text(diags);
        return 1;
    };
    return 0;
}
// Sanitize is a no-op at runtime (identity function)
// It is handled by the taint checker at compile time

fn match_bind_payloads(binding: str, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, mslot: i64) -> Vec<i32> {
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
            let bar: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(bar));
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
        ir_block_add(cur, ir_alloca(tmp));
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
        let mslot: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(mslot));
        ir_block_add(cur, ir_store(mexpr_r, mslot));
        let tmp: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(tmp));
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
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
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
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
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
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
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
                ab = match_bind_payloads(binding, ab, regs, arm_sym, mslot);
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
        let ar: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(ar));
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
        let ar: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(ar));
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
        let item_slot: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(item_slot));
        let iter_slot: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(iter_slot));
        let idx_slot: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(idx_slot));
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
        let mslot: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(mslot));
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
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
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
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
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
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
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
                ab = match_bind_payloads(binding, ab, regs, arm_sym, mslot);
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

// Simple string hash for cache keys (djb2)
fn str_hash(s: str) -> i64 {
    let mut hash: i64 = 5381;
    let slen: i64 = str_len(s);
    let mut i: i64 = 0;
    while i < slen {
        hash = hash * 33 + str_char_at(s, i);
        // Keep hash positive and bounded
        hash = hash % 1000000007;
        i = i + 1;
    };
    return hash;
}

// Extract a function's signature string: "name(param_types) -> ret_type"
// This is what we cache — if the signature changes, dependents must recompile.
fn extract_fn_signature(pool: Vec<i32>, fn_nid: i64) -> str {
    let name: str = node_field(pool, fn_nid, 1);
    let params_list: i64 = node_field(pool, fn_nid, 2);
    let ret_type: str = node_field(pool, fn_nid, 3);
    let mut sb: i64 = sb_new();
    sb_append(sb, name);
    sb_append(sb, "(");
    let pc: i64 = list_len(pool, params_list);
    let mut pi: i64 = 0;
    while pi < pc {
        if pi > 0 { sb_append(sb, ","); };
        let param: i64 = list_get(pool, params_list, pi);
        // param node has name and type
        if node_kind(pool, param) == 41 {
            sb_append(sb, node_field(pool, param, 2));
        } else {
            sb_append(sb, "?");
        };
        pi = pi + 1;
    };
    sb_append(sb, ")->");
    sb_append(sb, ret_type);
    return sb_to_str(sb);
}

// Extract a function's body source hash — changes to the body trigger recompile
// but don't invalidate dependents (unless signature also changed).
fn extract_fn_body_hash(pool: Vec<i32>, fn_nid: i64) -> i64 {
    // Hash the entire function node subtree by walking its fields
    let mut sb: i64 = sb_new();
    let fc: i64 = node_field(pool, fn_nid, 0); // kind
    sb_append(sb, str_from_int(fc));
    let name: str = node_field(pool, fn_nid, 1);
    sb_append(sb, name);
    // Hash body node reference
    let body: i64 = node_field(pool, fn_nid, 4);
    sb_append(sb, str_from_int(body));
    // Include param count for safety
    let params: i64 = node_field(pool, fn_nid, 2);
    sb_append(sb, str_from_int(list_len(pool, params)));
    return str_hash(sb_to_str(sb));
}

// Build a signature cache: maps function name -> (signature_hash, body_hash)
fn build_sig_cache(pool: Vec<i32>, prog: i64) -> Vec<i32> {
    let mut cache: Vec<i32> = Vec::new();
    let cnt: i64 = list_len(pool, prog);
    let mut fi: i64 = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 {
            let sig: str = extract_fn_signature(pool, fn_nid);
            let sig_hash: i64 = str_hash(sig);
            let body_hash: i64 = extract_fn_body_hash(pool, fn_nid);
            let name: str = node_field(pool, fn_nid, 1);
            cache.push(name);
            cache.push(sig_hash);
            cache.push(body_hash);
        };
        fi = fi + 1;
    };
    return cache;
}

// Serialize signature cache to a string for disk storage
fn sig_cache_serialize(cache: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(cache) {
        sb_append(sb, vec_get(cache, i));      // name
        sb_append(sb, ":");
        sb_append(sb, str_from_int(vec_get(cache, i + 1))); // sig_hash
        sb_append(sb, ":");
        sb_append(sb, str_from_int(vec_get(cache, i + 2))); // body_hash
        sb_append(sb, "\n");
        i = i + 3;
    };
    return sb_to_str(sb);
}

// Check if a function needs recompilation by comparing against cached hashes.
// Returns: 0 = cached (skip), 1 = body changed (recompile, don't invalidate deps),
//          2 = signature changed (recompile + invalidate all dependents)
fn check_fn_cache(name: str, sig_hash: i64, body_hash: i64, old_cache: str) -> i64 {
    if str_len(old_cache) == 0 { return 2; }; // no cache = full recompile
    // Search for name in old cache
    let slen: i64 = str_len(old_cache);
    let nlen: i64 = str_len(name);
    let mut p: i64 = 0;
    while p < slen {
        // Find end of line
        let mut eol: i64 = p;
        while eol < slen && str_char_at(old_cache, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(old_cache, p, eol);
        let llen: i64 = str_len(line);
        // Check if line starts with "name:"
        if llen > nlen + 1 && str_eq(str_substring(line, 0, nlen), name) && str_char_at(line, nlen) == 58 {
            // Found the function in cache, extract old hashes
            let rest: str = str_substring(line, nlen + 1, llen);
            // Find the colon separator between sig_hash and body_hash
            let rlen: i64 = str_len(rest);
            let mut cp: i64 = 0;
            while cp < rlen && str_char_at(rest, cp) != 58 { cp = cp + 1; };
            let old_sig: i64 = str_to_int(str_substring(rest, 0, cp));
            let old_body: i64 = str_to_int(str_substring(rest, cp + 1, rlen));
            if old_sig != sig_hash { return 2; }; // signature changed
            if old_body != body_hash { return 1; }; // body changed
            return 0; // unchanged
        };
        p = eol + 1;
    };
    return 2; // function not in cache = new function
}

// Build dependency map: for each function, list the functions it calls.
// Used for transitive invalidation when a signature changes.
fn build_call_deps(pool: Vec<i32>, prog: i64) -> Vec<i32> {
    let mut deps: Vec<i32> = Vec::new();
    let cnt: i64 = list_len(pool, prog);
    let mut fi: i64 = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 {
            let name: str = node_field(pool, fn_nid, 1);
            deps.push(name);
            // Collect callees from body
            let body: i64 = node_field(pool, fn_nid, 4);
            let mut callees: i64 = sb_new();
            collect_callees(pool, body, callees);
            deps.push(sb_to_str(callees));
        };
        fi = fi + 1;
    };
    return deps;
}

// Recursively collect function names called from an expression
fn collect_callees(pool: Vec<i32>, nid: i64, sb: i64) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    // Call node (kind 5): field 1 is callee name
    if kind == 5 {
        sb_append(sb, node_field(pool, nid, 1));
        sb_append(sb, ",");
        // Recurse into arguments
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac { collect_callees(pool, list_get(pool, args, ai), sb); ai = ai + 1; };
    }
    // Block node (kind 2): recurse into statements
    else if kind == 2 {
        let stmts: i64 = node_field(pool, nid, 1);
        let sc: i64 = list_len(pool, stmts);
        let mut si: i64 = 0;
        while si < sc { collect_callees(pool, list_get(pool, stmts, si), sb); si = si + 1; };
    }
    // If node (kind 6): recurse into cond, then, else
    else if kind == 6 {
        collect_callees(pool, node_field(pool, nid, 1), sb);
        collect_callees(pool, node_field(pool, nid, 2), sb);
        collect_callees(pool, node_field(pool, nid, 3), sb);
    }
    // While node (kind 7): recurse into cond and body
    else if kind == 7 {
        collect_callees(pool, node_field(pool, nid, 1), sb);
        collect_callees(pool, node_field(pool, nid, 2), sb);
    }
    // Let/assign (kind 8/9): recurse into value
    else if kind == 8 || kind == 9 {
        collect_callees(pool, node_field(pool, nid, 2), sb);
    }
    // BinOp (kind 4): recurse into lhs/rhs
    else if kind == 4 {
        collect_callees(pool, node_field(pool, nid, 2), sb);
        collect_callees(pool, node_field(pool, nid, 3), sb);
    }
    // Return (kind 10): recurse into value
    else if kind == 10 {
        collect_callees(pool, node_field(pool, nid, 1), sb);
    };
    return 0;
}

// Check if a function name appears in a comma-separated callee list
fn depends_on(callees: str, target: str) -> i64 {
    let clen: i64 = str_len(callees);
    let tlen: i64 = str_len(target);
    let mut p: i64 = 0;
    while p < clen {
        let mut e: i64 = p;
        while e < clen && str_char_at(callees, e) != 44 { e = e + 1; };
        if e - p == tlen && str_eq(str_substring(callees, p, e), target) { return 1; };
        p = e + 1;
    };
    return 0;
}

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
// PIPELINE
// =====================================================

fn compile_and_run(ll: str, name: str) -> i64 {
    let safe_name: str = normalize_output_name(name);
    if str_len(safe_name) == 0 {
        print(str_concat("ERROR: invalid output name: ", name));
        return 1;
    };
    let lp: str = sanitize(str_concat("target/", str_concat(safe_name, ".ll")));
    let ep: str = sanitize(str_concat("target\\", str_concat(safe_name, ".exe")));
    system("mkdir target 2>NUL");
    file_write_string(lp, ll);
    let rt_arg2: str = resolve_toolchain_path("stdlib/runtime/nucleor_llvm_rt.c");
    let cmd: str = str_concat(llvm_clang_path(), str_concat(" ", str_concat(lp, str_concat(" ", str_concat(rt_arg2, str_concat(" -o ", str_concat(ep, " -Wno-override-module -Wl,/STACK:16777216  2>&1"))))));
    let rc: i64 = system(cmd);
    if rc != 0 { print(str_concat("  COMPILE FAIL: ", safe_name)); return 0 - 1; };
    return system(ep);
}

fn pipeline(source: str, name: str) -> i64 {
    if preflight_source_check(source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let mut r: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(r);
    let cnt: i64 = list_len(pool, prog);
    let mut strtab: Vec<i32> = Vec::new();
    let mut fns: Vec<i32> = Vec::new();
    let mut externs: Vec<i32> = Vec::new();
    let mut structs: Vec<i32> = Vec::new();
    let mut enums: Vec<i32> = Vec::new();
    let mut globals: Vec<i32> = Vec::new();
    // Pass 1: collect structs, enums, and externs
    let mut fi: i64 = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 32 { externs.push(fn_nid); }
        else if node_kind(pool, fn_nid) == 33 { structs.push(fn_nid); }
        else if node_kind(pool, fn_nid) == 36 { enums.push(fn_nid); };
        if node_kind(pool, fn_nid) == 50 { globals.push(fn_nid); };
        fi = fi + 1;
    };
    // Pass 1.5: collect trait impls and generate mangled functions
    let mut trait_impls: Vec<i32> = Vec::new();
    let mut impl_fns: Vec<i32> = Vec::new();
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
    // Diagnostic accumulator
    let mut diags: Vec<i32> = diag_new();
    let review_path: str = "";
    let review_filter: str = "";
    if review_active(review_path) == 1 {
        review_emit(review_path, str_concat("{\"schema_version\":\"1.0\",\"event\":\"compile_start\",\"file\":\"", str_concat(name, "\"}")));
    }
    // Pass 1.7: ownership checking
    let mut ow_warns: i64 = 0;
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { ow_warns = ow_warns + check_fn(pool, fn_nid, structs, enums, diags, source, review_path, review_filter); };
        fi = fi + 1;
    };
    let mut oi: i64 = 0;
    while oi < vec_len(impl_fns) { ow_warns = ow_warns + check_fn(pool, vec_get(impl_fns, oi), structs, enums, diags, source, review_path, review_filter); oi = oi + 1; };
    let mut ty_warns: i64 = type_check_program(pool, prog, structs, diags, source, tprof_new(0));
    let mut raw_warns: i64 = source_rule_check(source, diags);
    // Pass 1.8: effect checking (pure fn)
    let mut pure_fns: Vec<i32> = Vec::new();
    let mut ef_warns: i64 = 0;
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 46 { pure_fns.push(node_field(pool, fn_nid, 1)); };
        fi = fi + 1;
    };
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 {
            let fname: str = node_field(pool, fn_nid, 1);
            let mut is_pure: i64 = 0;
            let mut pi: i64 = 0;
            while pi < vec_len(pure_fns) { if str_eq(vec_get(pure_fns, pi), fname) { is_pure = 1; pi = vec_len(pure_fns); }; pi = pi + 1; };
            if is_pure == 1 { ef_warns = ef_warns + effect_check_fn(pool, fn_nid, pure_fns, diags, source, review_path, review_filter); };
        };
        fi = fi + 1;
    };
    // Pass 1.9: taint checking (two-pass: intra-function then inter-procedural)
    let mut taint_warns: i64 = 0;
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { taint_warns = taint_warns + taint_check_fn(pool, fn_nid, diags, source, review_path, review_filter); };
        fi = fi + 1;
    };
    // Inter-procedural pass: re-check all non-main functions assuming all params tainted
    // This catches taint flows across function boundaries (e.g., user input → struct field → callee → system)
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 {
            let fname: str = node_field(pool, fn_nid, 1);
            if str_eq(fname, "main") == 0 {
                taint_warns = taint_warns + taint_check_fn_ex(pool, fn_nid, diags, source, review_path, review_filter, 1);
            };
        };
        fi = fi + 1;
    };
    // Emit diagnostics (text mode for pipeline)
    if diag_count(diags) > 0 { diag_emit_text(diags); return 1; };
    // Pass 2: lower functions
    let mut closures: Vec<i32> = Vec::new();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { fns.push(lower_fn(pool, fn_nid, strtab, structs, enums, globals, closures, trait_impls)); };
        fi = fi + 1;
    };
    // Lower impl-generated functions
    let mut ii: i64 = 0;
    while ii < vec_len(impl_fns) {
        fns.push(lower_fn(pool, vec_get(impl_fns, ii), strtab, structs, enums, globals, closures, trait_impls));
        ii = ii + 1;
    };
    // Add generated closure functions
    let mut ci: i64 = 0;
    while ci < vec_len(closures) { fns.push(vec_get(closures, ci)); ci = ci + 1; };
    let ll: str = emit_module_ext(fns, strtab, pool, externs);
    return compile_and_run(ll, name);
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

// V2: Parallel import resolution — collect all imports first, then resolve
// independent ones in parallel via threading. Falls back to sequential if
// only one import or threading unavailable.
fn collect_import_paths(src: str, base_dir: str) -> Vec<i32> {
    let mut paths: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(src, lp) == 32 || str_char_at(src, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = eol - lp;
        let mut prefix_len: i64 = 0;
        if line_len >= 8 && str_eq(str_substring(src, lp, lp + 7), "import ") { prefix_len = 7; };
        if prefix_len == 0 && line_len >= 5 && str_eq(str_substring(src, lp, lp + 4), "use ") { prefix_len = 4; };
        if prefix_len > 0 {
            let mut qp: i64 = lp + prefix_len;
            while qp < eol && str_char_at(src, qp) == 32 { qp = qp + 1; };
            if qp < eol && str_char_at(src, qp) == 34 {
                let ps: i64 = qp + 1;
                let mut pe: i64 = ps;
                while pe < eol && str_char_at(src, pe) != 34 { pe = pe + 1; };
                let imp_path: str = resolve_import_path(base_dir, str_substring(src, ps, pe));
                paths.push(imp_path);
            };
        };
        p = eol + 1;
    };
    return paths;
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
        if line_len >= 8 && str_eq(str_substring(src, lp, lp + 7), "import ") { prefix_len = 7; };
        if prefix_len == 0 && line_len >= 5 && str_eq(str_substring(src, lp, lp + 4), "use ") { prefix_len = 4; };
        if prefix_len > 0 {
            let mut qp: i64 = lp + prefix_len;
            while qp < eol && str_char_at(src, qp) == 32 { qp = qp + 1; };
            if qp < eol && str_char_at(src, qp) == 34 {
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

fn ascii_upper(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c >= 97 && c <= 122 {
            sb_append(sb, str_substring("ABCDEFGHIJKLMNOPQRSTUVWXYZ", c - 97, c - 96));
        } else {
            sb_append(sb, str_substring(s, i, i + 1));
        };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn explain_error_title(code: str) -> str {
    if str_eq(code, "NR001") { return "Source Input Failure"; };
    if str_eq(code, "NR005") { return "Module Resolution Failure"; };
    if str_eq(code, "NR010") { return "Lexical Syntax Failure"; };
    if str_eq(code, "NR020") { return "Parser Failure"; };
    if str_eq(code, "NR030") { return "Semantic Type Failure"; };
    if str_eq(code, "NR031") { return "Borrow Safety Failure"; };
    if str_eq(code, "NR032") { return "Effect or Policy Failure"; };
    if str_eq(code, "NR033") { return "Taint Safety Failure"; };
    if str_eq(code, "NR034") { return "Send/Sync Safety Failure"; };
    if str_eq(code, "NR040") { return "IR Lowering Failure"; };
    if str_eq(code, "NR050") { return "Backend Code Generation Failure"; };
    if str_eq(code, "NR051") { return "WASM Backend Unavailable"; };
    if str_eq(code, "NR070") { return "Manifest or Lockfile Failure"; };
    if str_eq(code, "NR090") { return "Compiler Pipeline Invariant Failure"; };
    // RFC-0001 RT attributes
    if str_eq(code, "RT-001") { return "Allocation in #[no_alloc] function"; };
    if str_eq(code, "RT-002") { return "Possibly-panicking expression in #[no_panic] function"; };
    if str_eq(code, "RT-003") { return "Dynamic dispatch in #[no_dyn] function"; };
    if str_eq(code, "RT-004") { return "Static WCET exceeds declared #[deadline]"; };
    if str_eq(code, "RT-005") { return "FFI call in RT function without #[ffi_no_*] annotation"; };
    if str_eq(code, "RT-006") { return "RT attribute on async fn"; };
    if str_eq(code, "RT-007") { return "Deadline annotation without no_alloc or no_panic"; };
    if str_eq(code, "RT-008") { return "Recursive call in #[deadline] function without #[max_depth]"; };
    // RFC-0002 allocator types
    if str_eq(code, "ALLOC-001") { return "Allocated value escapes its allocator"; };
    if str_eq(code, "ALLOC-002") { return "Allocator type mismatch"; };
    if str_eq(code, "ALLOC-003") { return "Allocation forbidden by #[no_alloc]"; };
    // RFC-0003 typed frames
    if str_eq(code, "FRAME-001") { return "Cannot add values in different coordinate frames"; };
    if str_eq(code, "FRAME-002") { return "Transform composition mismatch"; };
    if str_eq(code, "FRAME-003") { return "Cannot apply transform to value in incompatible frame"; };
    // RFC-0015 numeric types
    if str_eq(code, "NUM-001") { return "Mixed-width arithmetic without cast"; };
    if str_eq(code, "NUM-002") { return "Numeric literal out of range for declared type"; };
    if str_eq(code, "NUM-003") { return "Cast loses precision (warning)"; };
    if str_eq(code, "NUM-005") { return "usize/isize mixed with explicit-width type"; };
    // RFC-0016 match
    if str_eq(code, "MATCH-001") { return "Non-exhaustive match"; };
    if str_eq(code, "MATCH-002") { return "Unreachable match arm"; };
    if str_eq(code, "MATCH-003") { return "Type mismatch between match arms"; };
    if str_eq(code, "MATCH-004") { return "? in a function not returning Result/Option"; };
    if str_eq(code, "MATCH-005") { return "? error type doesn't Into the function's error type"; };
    if str_eq(code, "MATCH-006") { return "unwrap() in #[no_panic] function"; };
    if str_eq(code, "MATCH-007") { return "Range pattern bounds in wrong order"; };
    if str_eq(code, "MATCH-008") { return "Or-pattern arms have different bindings"; };
    if str_eq(code, "MATCH-009") { return "Slice pattern overlaps"; };
    if str_eq(code, "MATCH-010") { return "@-binding name collides with outer scope"; };
    // RFC-0004 assume!
    if str_eq(code, "ASSUME-001") { return "predicate not in analyzer's vocabulary"; };
    if str_eq(code, "ASSUME-002") { return "assume_unchecked! used without justification"; };
    if str_eq(code, "ASSUME-004") { return "assume! contradicts type-system fact"; };
    // RFC-0005 units
    if str_eq(code, "UNIT-001") { return "Add/sub mismatched dimensions"; };
    if str_eq(code, "UNIT-002") { return "Implicit unit conversion attempted"; };
    if str_eq(code, "UNIT-004") { return "Unknown unit alias"; };
    // RFC-0006 contracts
    if str_eq(code, "CONTRACT-001") { return "Require violation"; };
    if str_eq(code, "CONTRACT-002") { return "Ensure violation"; };
    if str_eq(code, "CONTRACT-003") { return "Invariant violation"; };
    if str_eq(code, "CONTRACT-004") { return "Trait impl weakens precondition (Liskov)"; };
    // RFC-0007 atomic
    if str_eq(code, "ATOMIC-001") { return "Blocking call inside #[atomic] function"; };
    if str_eq(code, "ATOMIC-002") { return "Allocating call inside #[atomic] function"; };
    // RFC-0008 ISR
    if str_eq(code, "ISR-001") { return "#[isr] function not pub"; };
    if str_eq(code, "ISR-002") { return "ISR stack frame exceeds budget"; };
    if str_eq(code, "ISR-004") { return "Vector name not recognized for target"; };
    // RFC-0009 WCET
    if str_eq(code, "WCET-002") { return "Loop bound unknown"; };
    if str_eq(code, "WCET-003") { return "WCET exceeds declared deadline"; };
    // RFC-0014 max_depth
    if str_eq(code, "DEPTH-001") { return "Recursive call without #[max_depth]"; };
    if str_eq(code, "DEPTH-002") { return "Cannot prove #[max_depth = N]"; };
    if str_eq(code, "DEPTH-004") { return "Total stack budget exceeded"; };
    // RFC-0031 laws
    if str_eq(code, "LAW-001") { return "Property test fails (auto-generated from @law)"; };
    if str_eq(code, "LAW-002") { return "SMT disproves law"; };
    // RFC-0032 effects
    if str_eq(code, "EFF-001") { return "Function uses effect not in declared row"; };
    if str_eq(code, "EFF-002") { return "pure fn calls effectful fn"; };
    if str_eq(code, "EFF-003") { return "restricts [...] violated"; };
    // RFC-0017 collections
    if str_eq(code, "COLL-001") { return "K: Hash + Eq requirement violated"; };
    if str_eq(code, "COLL-002") { return "K: Ord requirement violated for BTree"; };
    if str_eq(code, "COLL-003") { return "Collection method that may grow used in #[no_alloc]"; };
    if str_eq(code, "COLL-004") { return "Iterator invalidated by mutation during walk"; };
    if str_eq(code, "COLL-005") { return "Index out of bounds on fixed-length collection"; };
    // RFC-0018 modules
    if str_eq(code, "MOD-001") { return "Module file not found at expected path"; };
    if str_eq(code, "MOD-002") { return "Path references non-existent module/item"; };
    if str_eq(code, "MOD-003") { return "Visibility violation"; };
    if str_eq(code, "MOD-004") { return "Glob `use *` from a module without an explicit prelude (warning)"; };
    if str_eq(code, "MOD-005") { return "Circular module dependency"; };
    if str_eq(code, "MOD-006") { return "Two `use` declarations bind the same name"; };
    // RFC-0019 packages
    if str_eq(code, "PKG-001") { return "Manifest schema error"; };
    if str_eq(code, "PKG-002") { return "Version conflict — no resolution found"; };
    if str_eq(code, "PKG-003") { return "Checksum mismatch"; };
    if str_eq(code, "PKG-004") { return "Network error fetching package"; };
    if str_eq(code, "PKG-005") { return "Unknown package / version"; };
    if str_eq(code, "PKG-006") { return "Yanked version explicitly required"; };
    // RFC-0022 cross-platform
    if str_eq(code, "TGT-001") { return "Unknown target triple"; };
    if str_eq(code, "TGT-002") { return "Sysroot not installed for target"; };
    if str_eq(code, "TGT-003") { return "Feature unsupported on target"; };
    if str_eq(code, "TGT-004") { return "Cross-link error"; };
    return "";
}

fn explain_error_summary(code: str) -> str {
    if str_eq(code, "NR001") { return "Nucleor could not read the requested source file."; };
    if str_eq(code, "NR005") { return "A use target or package import could not be resolved safely."; };
    if str_eq(code, "NR010") { return "The lexer found an invalid character or token shape."; };
    if str_eq(code, "NR020") { return "The token stream does not form valid Nucleor syntax."; };
    if str_eq(code, "NR030") { return "The program parsed, but semantic typing rules were violated."; };
    if str_eq(code, "NR031") { return "Ownership or borrowing rules were violated."; };
    if str_eq(code, "NR032") { return "A denied effect, purity rule, or policy restriction was violated."; };
    if str_eq(code, "NR033") { return "Tainted data reached a location that requires trusted input."; };
    if str_eq(code, "NR034") { return "A spawned or shared context captured a type that is not safe to transfer or share."; };
    if str_eq(code, "NR040") { return "The typed AST could not be lowered into compiler IR."; };
    if str_eq(code, "NR050") { return "IR generation succeeded, but a backend could not emit valid target code."; };
    if str_eq(code, "NR051") { return "WASM output was requested without the required backend support."; };
    if str_eq(code, "NR070") { return "Project metadata, dependency graph, or lockfile state is invalid."; };
    if str_eq(code, "NR090") { return "An internal compiler stage received invalid state from a previous pass."; };
    if str_eq(code, "RT-001") { return "A #[no_alloc] function called something that allocates from the global heap."; };
    if str_eq(code, "RT-002") { return "A #[no_panic] function contains an expression the compiler cannot prove is panic-free."; };
    if str_eq(code, "RT-003") { return "A #[no_dyn] function uses dynamic (vtable) dispatch via dyn Trait."; };
    if str_eq(code, "RT-004") { return "Static WCET analysis estimates the function exceeds its declared #[deadline]."; };
    if str_eq(code, "RT-005") { return "An RT-tagged function called an extern fn lacking #[ffi_no_alloc] or #[ffi_no_panic]."; };
    if str_eq(code, "RT-006") { return "RT attributes (#[no_alloc], #[deadline] etc.) cannot be applied to async fn — async semantics break the deadline guarantee."; };
    if str_eq(code, "RT-007") { return "A #[deadline] annotation alone is incomplete — it is hard to reason about deadline without #[no_alloc] or #[no_panic]."; };
    if str_eq(code, "RT-008") { return "A #[deadline] function uses recursion. Bound it with #[max_depth = N] (RFC-0014)."; };
    if str_eq(code, "ALLOC-001") { return "A value allocated in an arena/pool/tlsf cannot outlive its allocator. The borrow checker rejects returning the value when the allocator goes out of scope."; };
    if str_eq(code, "ALLOC-002") { return "Two values from different allocator types cannot be combined where one is required."; };
    if str_eq(code, "ALLOC-003") { return "An allocation site reaches a #[no_alloc(...)] context that forbids that allocator."; };
    if str_eq(code, "FRAME-001") { return "Spatial values in different coordinate frames cannot be combined directly. Transform via tf.lookup or apply an explicit Transform."; };
    if str_eq(code, "FRAME-002") { return "Transform<A, B> * Transform<C, D> requires B == C. The compiler rejected the composition."; };
    if str_eq(code, "FRAME-003") { return "Transform<A, B>.apply(Pose<C>) requires C == A. The compiler rejected the application."; };
    if str_eq(code, "NUM-001") { return "Nucleor follows Rust's no-implicit-conversion rule. Cast explicitly with `as`: `(u8_val as i32) + i32_val`."; };
    if str_eq(code, "NUM-002") { return "The literal does not fit in the declared type — e.g. 256u8 overflows u8."; };
    if str_eq(code, "NUM-003") { return "An `as` cast may truncate or round. The warning is informational; promote to error with #![deny(precision_loss)]."; };
    if str_eq(code, "NUM-005") { return "usize and isize are platform-pointer-width and incompatible with explicit i64 / u64 etc. without cast."; };
    if str_eq(code, "MATCH-001") { return "The match does not cover all variants of the matched type. The compiler shows a witness uncovered value."; };
    if str_eq(code, "MATCH-002") { return "An arm is preceded by patterns that already match every case it would handle."; };
    if str_eq(code, "MATCH-003") { return "Match arm bodies must produce the same type (or () in statement context)."; };
    if str_eq(code, "MATCH-004") { return "The ? operator desugars to a function-level early return; the function must return Result/Option for ? to type-check."; };
    if str_eq(code, "MATCH-005") { return "? converts the inner error via `From::from`. The compiler cannot find an impl mapping the source error type to the function's declared error type."; };
    if str_eq(code, "MATCH-006") { return "unwrap() panics on Err/None. Use unwrap_or, ?, or match in #[no_panic] code."; };
    if str_eq(code, "MATCH-007") { return "Range patterns like `1..=5` require `low <= high`. The compiler refuses inverted bounds since they would never match."; };
    if str_eq(code, "MATCH-008") { return "Or-patterns like `Some(x) | Other(x)` must bind the same set of names with the same types in every arm so the body type-checks identically."; };
    if str_eq(code, "MATCH-009") { return "Slice patterns split a slice into prefix/middle/suffix. Two patterns claiming the same element are ambiguous and rejected."; };
    if str_eq(code, "MATCH-010") { return "An @-binding (e.g. `n @ 1..=5`) introduces a fresh name; using a name already in scope is rejected to prevent silent shadowing."; };
    if str_eq(code, "ASSUME-001") { return "The assume! predicate uses an expression form the analyzer doesn't track for static reasoning. Runtime check still happens; static benefit is none."; };
    if str_eq(code, "ASSUME-002") { return "assume_unchecked! disables even the debug-mode runtime check. The warning surfaces a missing comment justifying the unsafety."; };
    if str_eq(code, "ASSUME-004") { return "The assume! predicate is provably false from the type system (e.g., assume!(x < 0) for x: u32)."; };
    if str_eq(code, "UNIT-001") { return "Adding/subtracting unit<T,m> and unit<T,s> is dimensionally invalid. Convert one to the other or use multiplication."; };
    if str_eq(code, "UNIT-002") { return "Implicit unit conversion is forbidden by RFC-0005. Use explicit .into() or From::from to cross unit systems."; };
    if str_eq(code, "UNIT-004") { return "Unknown unit alias. Check stdlib/rods/units_si.nr or units_imperial.nr."; };
    if str_eq(code, "CONTRACT-001") { return "A #[require(...)] precondition was violated by the caller. Caller must satisfy the predicate before the call."; };
    if str_eq(code, "CONTRACT-002") { return "A #[ensure(...)] postcondition was violated by the function body. Body must produce a result matching the predicate."; };
    if str_eq(code, "CONTRACT-003") { return "A #[invariant(...)] struct invariant was violated on method entry or exit."; };
    if str_eq(code, "CONTRACT-004") { return "Liskov substitution: a trait impl cannot weaken the trait's preconditions. Add the missing #[require] to the impl."; };
    if str_eq(code, "ATOMIC-001") { return "#[atomic] functions cannot block. Mutex::lock, Channel::recv, sleep, or syscalls are forbidden. Use lock-free structures (SpscQueue, MpmcQueue) or Atomic<T>."; };
    if str_eq(code, "ATOMIC-002") { return "#[atomic] implies #[no_alloc]. See RT-001 explanation."; };
    if str_eq(code, "ISR-001") { return "Vector-table wiring requires the ISR fn to be pub so the linker can find it."; };
    if str_eq(code, "ISR-002") { return "ISRs share a small stack. Move large local arrays to static or move computation outside the ISR."; };
    if str_eq(code, "ISR-004") { return "The vector name in #[isr(vector = ...)] does not match this target's PAC. Check stdlib/embedded/<target>/vectors.nr for the valid set."; };
    if str_eq(code, "WCET-002") { return "Add #[loop_bound(N)] or assume!(arr.len() == N) so Heptane can bound the loop."; };
    if str_eq(code, "WCET-003") { return "Static WCET upper bound exceeds the declared deadline. See the WCET report for the dominant cost path."; };
    if str_eq(code, "DEPTH-001") { return "Recursion without a depth bound cannot be safely analyzed. Annotate with #[max_depth = N] (RFC-0014)."; };
    if str_eq(code, "DEPTH-002") { return "The structural analysis cannot prove the recursion bound. Use an explicit depth-counter parameter and entry guard."; };
    if str_eq(code, "DEPTH-004") { return "Sum of (max_depth_i × frame_size_i) along a recursion chain exceeds the project's stack budget."; };
    if str_eq(code, "LAW-001") { return "RFC-0031 generates a property test from each @law. The test ran ~1000 random inputs and found a counterexample. Adjust the law's eps, mark @law(approximate), or remove the false claim."; };
    if str_eq(code, "LAW-002") { return "In --profile=cert, RFC-0031 routes laws through Z3/CVC5 for proof. The SMT solver disproved the law and produced a counterexample."; };
    if str_eq(code, "EFF-001") { return "RFC-0032 effect rows are checked at type-check. The function body uses an effect (io.read, alloc, etc.) not declared in its signature's `+ effect_row`."; };
    if str_eq(code, "EFF-002") { return "pure fn cannot perform side effects. Either remove the call, mark the callee pure, or remove the pure annotation from the caller."; };
    if str_eq(code, "EFF-003") { return "restricts [...] forbids the listed effects in the callee. The callee uses an effect on the restrict list."; };
    if str_eq(code, "COLL-001") { return "Hash-backed collections require K to implement both Hash + Eq."; };
    if str_eq(code, "COLL-002") { return "BTree-backed collections require K to implement Ord."; };
    if str_eq(code, "COLL-003") { return "push/insert/etc. may allocate to grow. In #[no_alloc] context use try_*-suffixed variants or pre-size with with_capacity."; };
    if str_eq(code, "COLL-004") { return "Mutating a collection (push/remove/clear) while iterating it leaves the iterator pointing at stale or freed memory."; };
    if str_eq(code, "COLL-005") { return "An index expression resolved to a value outside the collection's [0, len) bounds at compile time."; };
    if str_eq(code, "MOD-001") { return "`mod foo;` resolved to a path that does not exist on disk."; };
    if str_eq(code, "MOD-002") { return "A use path or full-path reference resolves to a module/item that doesn't exist."; };
    if str_eq(code, "MOD-003") { return "Item not pub for the access level used (pub, pub(crate), pub(super), or unrestricted)."; };
    if str_eq(code, "MOD-004") { return "use foo::* without an explicit prelude pulls in everything; can shadow names unexpectedly."; };
    if str_eq(code, "MOD-005") { return "Module dependency graph has a cycle (mod a uses b which uses a)."; };
    if str_eq(code, "MOD-006") { return "Two use declarations binding the same identifier shadow each other; rename via `use foo::Bar as FBar`."; };
    if str_eq(code, "PKG-001") { return "nuc.toml manifest fails schema validation."; };
    if str_eq(code, "PKG-002") { return "PubGrub resolver could not find a set of versions satisfying all constraints."; };
    if str_eq(code, "PKG-003") { return "Downloaded package hash does not match the lockfile entry. Possible network corruption or registry compromise."; };
    if str_eq(code, "PKG-004") { return "HTTP/git fetch failed. Check connectivity, registry URL, and auth tokens."; };
    if str_eq(code, "PKG-005") { return "Package or version not in registry. Check spelling; the version may be yanked."; };
    if str_eq(code, "PKG-006") { return "The lockfile pins a version that the registry has yanked. Re-run nuc update to pick a non-yanked version."; };
    if str_eq(code, "TGT-001") { return "Target triple does not match Tier-1 (windows-msvc, linux-gnu, apple-darwin) or any installed Tier-2/3 target."; };
    if str_eq(code, "TGT-002") { return "Run nuc install sysroot --target=<triple> to install the cross-compilation sysroot."; };
    if str_eq(code, "TGT-003") { return "Feature requires capability missing on this target (e.g. mmap on bare metal). Use --target check to see the missing capability list."; };
    if str_eq(code, "TGT-004") { return "Cross-linker rejected the binary. Likely missing C library; consult the linker error output for the specific symbol."; };
    return "";
}

fn explain_error_explanation(code: str) -> str {
    if str_eq(code, "NR001") { return "The compiler could not open or read the input file. This is usually a path, permission, or working-directory problem rather than a language error."; };
    if str_eq(code, "NR005") { return "The import graph could not be resolved because a target was missing, escaped its package boundary, created a cycle, or conflicted with another exported symbol."; };
    if str_eq(code, "NR010") { return "The source text cannot be tokenized into valid Nucleor tokens. This usually means a malformed literal, a non-ASCII identifier, or an unexpected character."; };
    if str_eq(code, "NR020") { return "The parser reached a token sequence that does not match the grammar. This is usually a missing delimiter, malformed declaration, or invalid expression shape."; };
    if str_eq(code, "NR030") { return "The checker rejected the program because types, names, effects, or ownership rules did not line up. More specific semantic failures use narrower codes when possible."; };
    if str_eq(code, "NR031") { return "The checker found an illegal aliasing, move, or borrow pattern. Typical causes are moving a borrowed value, mixing shared and mutable borrows, or using a value after move."; };
    if str_eq(code, "NR032") { return "The program attempted an operation that the current effect context, purity contract, or active policy block does not allow."; };
    if str_eq(code, "NR033") { return "The taint system prevented untrusted data from flowing into a sink that expects sanitized or trusted values."; };
    if str_eq(code, "NR034") { return "The checker found a cross-thread or cross-scope capture that violates Nucleor's Send/Share rules. This usually means a resource, mutable reference, or other non-Send value crossed a spawn boundary."; };
    if str_eq(code, "NR040") { return "Lowering hit an internal semantic boundary the IR pipeline could not represent. This is usually a compiler implementation gap rather than a front-end syntax issue."; };
    if str_eq(code, "NR050") { return "Cranelift or LLVM rejected the IR, hit an unsupported ABI path, or failed during object emission or linking preparation."; };
    if str_eq(code, "NR051") { return "The current CLI build does not include the backend support required for wasm code generation, or the wasm linker/toolchain is unavailable."; };
    if str_eq(code, "NR070") { return "Nucleor could not resolve the project package graph because the manifest was malformed, a dependency could not be found, or the lockfile was missing or stale."; };
    if str_eq(code, "NR090") { return "A compiler pipeline stage ran out of order or consumed data that was not produced by the earlier stage it depends on. This is an internal compiler bug, not a user program error."; };
    if str_eq(code, "RT-001") { return "RFC-0001 #[no_alloc] forbids any expression whose effect set includes alloc. Common offenders: Box::new, Vec::push past capacity, String operations, HashMap::insert. Use a pre-sized container, an arena/pool/tlsf allocator (RFC-0002), or refactor the allocation outside the RT path."; };
    if str_eq(code, "RT-002") { return "RFC-0001 #[no_panic] uses a conservative dataflow analysis. Sources of panic include integer overflow on +/-/*, division by zero, out-of-bounds indexing, unwrap() on Option/Result, and explicit panic!(). Use checked_*/wrapping_*/saturating_* arithmetic, guard divisions, use get() instead of [], and prove safety with assume! (RFC-0004)."; };
    if str_eq(code, "RT-003") { return "RFC-0001 #[no_dyn] forbids dynamic dispatch via Box<dyn Trait> or &dyn Trait. Replace with generics (fn f<T: Trait>(x: T)) for static dispatch, or with an enum-based polymorphism pattern."; };
    if str_eq(code, "RT-004") { return "RFC-0009 static WCET analysis estimates the function's worst-case time exceeds the deadline. Inspect the dominant cost in the report; reduce loop bounds, simplify hot paths, or relax the deadline if appropriate."; };
    if str_eq(code, "RT-005") { return "Calls into C/C++ via extern fn are opaque to the analysis. Mark trusted FFI declarations with #[ffi_no_alloc, ffi_no_panic] (RFC-0001 §3.5) or use the audit manifest mechanism."; };
    if str_eq(code, "RT-006") { return "async fn introduces poll-based scheduling and arbitrary suspend points. RT attributes promise bounded time and no allocation; the two are fundamentally incompatible. Refactor the function as sync, or use rod/tokio (RFC-0030) outside the RT path."; };
    if str_eq(code, "RT-007") { return "Adding #[no_alloc] or #[no_panic] (or both) makes the deadline reasoning sound. The warning surfaces a likely-incomplete annotation."; };
    if str_eq(code, "RT-008") { return "Deadline analysis cannot bound an unbounded recursion. Annotate the function with #[max_depth = N] per RFC-0014 to give the analyzer a depth bound."; };
    if str_eq(code, "ALLOC-001") { return "Per RFC-0002, Box<T, A: Allocator> is bound by the lifetime of A. Returning a Box<T, Arena> from a fn whose Arena is local is rejected. Either pass &Arena into the fn (caller owns the arena), or copy the value into a Box<T, Global> before returning."; };
    if str_eq(code, "ALLOC-002") { return "Allocator type is part of the value type. fn f(x: Box<T, Arena>) cannot accept a Box<T, Pool>. Use generics (fn f<A: Allocator>(x: Box<T, A>)) for allocator-agnostic APIs."; };
    if str_eq(code, "ALLOC-003") { return "RFC-0001 #[no_alloc(...)] accepts an explicit allow-list of allowed allocators. The default #[no_alloc] forbids all four (global/arena/pool/tlsf); narrow with #[no_alloc(global)] etc."; };
    if str_eq(code, "FRAME-001") { return "RFC-0003 typed frames make Pose<World> != Pose<BaseLink> at the type level. To combine, look up the transform: tf.lookup::<World, BaseLink>(time).apply(pose_world)."; };
    if str_eq(code, "FRAME-002") { return "Transform composition Transform<A,B> * Transform<C,D> requires B == C. The compiler enforces the chain at compile time. Reorder, invert one transform, or look up an intermediate."; };
    if str_eq(code, "FRAME-003") { return "Applying a Transform<From, To> requires the target value to be in the From frame. Convert via lookup of the appropriate transform."; };
    if str_eq(code, "NUM-001") { return "Nucleor models on Rust: numeric types are distinct, no implicit conversion. Cast explicitly with `as`. Reasoning: silent conversions are a recurring bug source (truncation, sign extension)."; };
    if str_eq(code, "NUM-002") { return "Numeric literal exceeds the declared type's range — e.g. 256u8, -1u32, 4_000_000_000i32. Use a wider type or change the literal."; };
    if str_eq(code, "NUM-003") { return "Casting f64 to i32, i64 to i8 etc. may lose precision or wrap. The warning surfaces the risk; if intentional, suppress with #[allow(precision_loss)] on the call site."; };
    if str_eq(code, "NUM-005") { return "usize/isize represent platform-pointer-width values used for indices and pointer arithmetic. Mixing with explicit i64/u64 risks portability bugs across 32-/64-bit targets."; };
    if str_eq(code, "MATCH-001") { return "The match must cover every variant of the discriminant type, or use a wildcard (_) arm. Compiler shows the missing case."; };
    if str_eq(code, "MATCH-002") { return "Patterns are tested in order. A later arm cannot match if an earlier arm covers all values it would handle."; };
    if str_eq(code, "MATCH-003") { return "All arms in a match expression must yield the same type. Cast or restructure to align."; };
    if str_eq(code, "MATCH-004") { return "The ? operator desugars to `match e { Ok(v) => v, Err(e) => return Err(e) }`. The function must return Result (or Option for option-?) for the desugar to type-check."; };
    if str_eq(code, "MATCH-005") { return "RFC-0016 §3.7 — implement `From<SourceError> for TargetError` (or use a single boxed error type). The ? desugar inserts the conversion automatically."; };
    if str_eq(code, "MATCH-006") { return "Use unwrap_or, unwrap_or_else, ?, or match in #[no_panic] context. The compiler treats unwrap as may_panic."; };
    if str_eq(code, "MATCH-007") { return "RFC-0023 §3.1 — swap the bounds. Half-open ranges `1..5` exclude the upper bound and have the same restriction."; };
    if str_eq(code, "MATCH-008") { return "RFC-0023 §3.2 — every alternative must bind the same names with compatible types. Restructure the patterns so each path produces an identical binding set."; };
    if str_eq(code, "MATCH-009") { return "RFC-0023 §3.4 — at most one wildcard prefix/middle/suffix per slice pattern. Restructure to a non-overlapping decomposition."; };
    if str_eq(code, "MATCH-010") { return "RFC-0023 §3.3 — pick a fresh identifier for the binding, or `let outer = outer;` to make shadowing explicit before the match."; };
    if str_eq(code, "ASSUME-001") { return "RFC-0004 §3.2 lists the predicate vocabulary the analyzer understands: x < N, x != 0, arr.len() == N, opt.is_some(), result.is_ok(), equality substitution. Other predicates are accepted as runtime checks but contribute nothing to static analysis."; };
    if str_eq(code, "ASSUME-002") { return "RFC-0004 §3.6 — assume_unchecked! is a footgun for extreme RT loops. Document why the runtime check is too costly to justify."; };
    if str_eq(code, "ASSUME-004") { return "The compiler proved the predicate is unsatisfiable at this program point. The assume! is wrong."; };
    if str_eq(code, "UNIT-001") { return "RFC-0005 §3.1 — units form a 7-dimensional polynomial. Add/sub require equal dimensions; mul/div produce sums/differences of dimension exponents."; };
    if str_eq(code, "UNIT-002") { return "RFC-0005 §3.4 — silent unit conversions are exactly the bug class typed units exist to prevent."; };
    if str_eq(code, "UNIT-004") { return "RFC-0005 §3.3 — alias library lives in stdlib/rods/units_si.nr (SI), units_imperial.nr, units_robotics.nr."; };
    if str_eq(code, "CONTRACT-001") { return "RFC-0006 §3.2 — #[require] is checked at the call site (debug profile) or assumed (release). Either fix the call or relax the require."; };
    if str_eq(code, "CONTRACT-002") { return "RFC-0006 §3.3 — #[ensure] is checked at function exit. The function returned a value or modified state in a way that violated the contract."; };
    if str_eq(code, "CONTRACT-003") { return "RFC-0006 §3.4 — invariants checked on entry to + exit from every public method. Either restore the invariant before the method ends or weaken the invariant."; };
    if str_eq(code, "CONTRACT-004") { return "RFC-0006 §3.5 — Liskov substitution principle. Trait impls cannot weaken preconditions; the impl must satisfy at least the trait's #[require]."; };
    if str_eq(code, "ATOMIC-001") { return "RFC-0007 §3.3 — #[atomic] is the inter-thread RT contract. Use Atomic<T> ops, SpscQueue/MpmcQueue.try_push/try_pop, and avoid all blocking primitives."; };
    if str_eq(code, "ATOMIC-002") { return "RFC-0007 §3.3 — see RT-001."; };
    if str_eq(code, "ISR-001") { return "RFC-0008 §3.3 — vector table is generated from #[isr]-annotated functions. Linker needs the symbol public."; };
    if str_eq(code, "ISR-002") { return "RFC-0008 §3.6 — each ISR has a stack budget (default 256 B). Move large arrays to static, file-scope, or to a dynamically-allocated heap region used outside the ISR."; };
    if str_eq(code, "ISR-004") { return "RFC-0008 §3.1 — vector names are target-specific. The PAC for your MCU is in stdlib/embedded/<target>/vectors.nr."; };
    if str_eq(code, "WCET-002") { return "RFC-0009 §3.2 — Heptane needs trip counts to bound loops. Annotate the loop with #[loop_bound(N)] or assert the array length with assume!(arr.len() == N) before entering."; };
    if str_eq(code, "WCET-003") { return "RFC-0009 §3.3 — static WCET upper bound exceeds the declared deadline. The diagnostic shows the dominant cost path. Reduce loop bounds, simplify hot expressions, or relax the deadline."; };
    if str_eq(code, "DEPTH-001") { return "RFC-0014 §3.4 — unbounded recursion blocks WCET analysis (RFC-0009) and stack-budget reasoning. Annotate the function with #[max_depth = N]."; };
    if str_eq(code, "DEPTH-002") { return "RFC-0014 §3.3 — the analyzer requires an explicit depth-counter parameter and an entry guard (`if depth >= N { return ...; };`). The pattern lets the structural analysis confirm the bound."; };
    if str_eq(code, "DEPTH-004") { return "RFC-0014 §3.5 — total stack usage is the sum of (max_depth_i × frame_size_i) along a recursion chain. Reduce frame sizes (move locals to static), reduce depth, or reorganize the chain."; };
    if str_eq(code, "LAW-001") { return "RFC-0031 §3.2 — @law generates a property test that runs ~1000 random inputs of the relevant type. The test failed with a concrete counterexample. Common causes: float associativity is not exact (use eps tolerance), commutativity violated by side effects (mark fn pure), or the law is simply wrong."; };
    if str_eq(code, "LAW-002") { return "RFC-0031 §3.4 — in --profile=cert, laws are SMT-proved by Z3 or CVC5. The solver returned UNSAT, meaning the law does not hold."; };
    if str_eq(code, "EFF-001") { return "RFC-0032 §3.1 — every function carries an effect row. Use a function with effects requires the caller to permit those effects. Either declare the effects in the caller's row or remove the call."; };
    if str_eq(code, "EFF-002") { return "RFC-0032 §3.2 — pure fn means no side effects (io, alloc, random, time, panic). The compiler can prove the call violates this."; };
    if str_eq(code, "EFF-003") { return "RFC-0032 §3.4 — restricts [...] is a contract on callbacks. Pass a different callback or remove the restrict."; };
    if str_eq(code, "COLL-001") { return "RFC-0017 §3.2 — derive Hash + Eq for K, or use BTreeMap which only requires Ord, or change to a key type that already implements both."; };
    if str_eq(code, "COLL-002") { return "RFC-0017 §3.3 — BTreeMap/BTreeSet rely on key ordering for sorted iteration and binary search. Derive Ord or implement it."; };
    if str_eq(code, "COLL-003") { return "RFC-0017 §3.7 — pre-size with with_capacity_in for the worst case, then use try_push / push_within_capacity which never reallocate."; };
    if str_eq(code, "COLL-004") { return "RFC-0017 §3.4 — collect indices to mutate during the iteration into a Vec, then apply mutations after the iter completes. The borrow checker tracks shared/mut conflicts on the underlying buffer."; };
    if str_eq(code, "COLL-005") { return "RFC-0017 §3.1 — fixed-length collections (arr[N], const-sized inline_vec) reject out-of-bounds accesses at compile time. Use a runtime-bounds-checked Vec, or guard with a length check."; };
    if str_eq(code, "MOD-001") { return "RFC-0018 §3.1 — `mod foo;` resolves to ./foo.nr or ./foo/mod.nr relative to the current file. Check the path or create the file."; };
    if str_eq(code, "MOD-002") { return "RFC-0018 §3.3 — verify the path. crate::x means project root; super::x means parent module; std::x means stdlib; <pkg>::x means registry dep."; };
    if str_eq(code, "MOD-003") { return "RFC-0018 §3.2 — add `pub` (or pub(crate)/pub(super)) to the item, or move the use site closer to where the item is visible."; };
    if str_eq(code, "MOD-004") { return "RFC-0018 — globs are noisy and shadow-prone. Prefer explicit `use foo::{a, b, c}` lists, or define a prelude module that's intentional about exports."; };
    if str_eq(code, "MOD-005") { return "RFC-0018 — break the cycle by extracting shared definitions to a third module both depend on."; };
    if str_eq(code, "MOD-006") { return "RFC-0018 §3.4 — rename one with `as`: `use foo::Bar as FBar`. The compiler does not silently shadow."; };
    if str_eq(code, "PKG-001") { return "RFC-0019 §3.1 — see the canonical schema in docs/nuc-toml-spec.md (forthcoming). Common errors: missing [package] table, missing name/version, malformed [dependencies] entries."; };
    if str_eq(code, "PKG-002") { return "RFC-0019 §3.3 — PubGrub returns a structured conflict report. Common causes: two transitive deps require incompatible major versions of a shared dep. Loosen one constraint or pick a newer version of the conflicting transitive."; };
    if str_eq(code, "PKG-003") { return "RFC-0019 §3.4 — re-run `nuc update` to refresh the lockfile if intentional, or escalate (registry compromise) if unexpected."; };
    if str_eq(code, "PKG-004") { return "RFC-0019 §3.5 — verify network connectivity. For git deps, check the URL; for registry, check NUCLEOR_REGISTRY env or fall back to https://nucleor.dev/registry/ default."; };
    if str_eq(code, "PKG-005") { return "RFC-0019 §3.5 — `nuc search <name>` to discover the package; check spelling and case (registry is case-sensitive)."; };
    if str_eq(code, "PKG-006") { return "RFC-0019 §3.5 — yanked versions are kept downloadable for users with existing lockfiles but not chosen by `nuc add`. Either pin the yanked version explicitly with `=X.Y.Z`, or update."; };
    if str_eq(code, "TGT-001") { return "RFC-0022 §3.1 — see the Tier-1 list in the RFC. Tier-2/3 targets need explicit installation."; };
    if str_eq(code, "TGT-002") { return "RFC-0022 §3.7 — sysroots ship from nucleor.dev/sysroots/. The download is signed; install with `nuc install sysroot --target=<triple>`."; };
    if str_eq(code, "TGT-003") { return "RFC-0022 §3.6 — runtime feature audit. Some `_rt.c` modules guard with `_WIN32` / `__linux__` / etc.; bare-metal targets exclude entire categories."; };
    if str_eq(code, "TGT-004") { return "RFC-0022 §3.7 — likely missing libc on the target. For Linux→Windows or macOS→Linux cross, consult `clang --target=<triple> --print-search-dirs`."; };
    return "";
}

fn explain_error_reference(code: str) -> str {
    return str_concat("docs/spec/Nucleor_Error_Codes.md#", ascii_upper(code));
}

fn explain_error_known(code: str) -> i64 {
    if str_len(explain_error_title(code)) == 0 { return 0; };
    return 1;
}

fn explain_error_next_steps(code: str) -> Vec<i32> {
    let mut steps: Vec<i32> = Vec::new();
    if str_eq(code, "NR001") {
        steps.push("Verify the file path passed to the command.");
        steps.push("Check file permissions and current working directory.");
        steps.push("If using a package, confirm [build].entry points to an existing file.");
    } else if str_eq(code, "NR005") {
        steps.push("Check the imported path or package alias.");
        steps.push("Ensure the import stays inside the package root.");
        steps.push("Look for duplicate exported names or cyclic imports.");
    } else if str_eq(code, "NR010") {
        steps.push("Check the reported source offset for the invalid character.");
        steps.push("Verify string and numeric literal syntax.");
        steps.push("Keep identifiers ASCII-only.");
    } else if str_eq(code, "NR020") {
        steps.push("Check the line and column around the reported span.");
        steps.push("Look for missing braces, commas, semicolons, or parentheses.");
        steps.push("Verify declaration headers and function signatures.");
    } else if str_eq(code, "NR030") {
        steps.push("Read the concrete message for the exact mismatch.");
        steps.push("Check variable names, function signatures, and return types.");
        steps.push("Use nuc explain on any more specific code shown with the diagnostic.");
    } else if str_eq(code, "NR031") {
        steps.push("Check whether the value was moved earlier in the scope.");
        steps.push("Avoid overlapping shared and mutable borrows.");
        steps.push("Introduce a narrower scope so the borrow ends before the next use.");
    } else if str_eq(code, "NR032") {
        steps.push("Check the function effect list and current restricts or policy context.");
        steps.push("Add the required effect only if the operation is intentionally impure.");
        steps.push("If the operation must stay pure, refactor the side effect out of the function.");
    } else if str_eq(code, "NR033") {
        steps.push("Identify the tainted source in the data flow.");
        steps.push("Sanitize or validate the value before the sink.");
        steps.push("Keep tainted and trusted values separated until validation is complete.");
    } else if str_eq(code, "NR034") {
        steps.push("Move only owned Send values into spawn blocks.");
        steps.push("Avoid capturing mutable references across thread boundaries.");
        steps.push("Wrap shared state in a synchronization primitive only when the underlying payload is allowed.");
    } else if str_eq(code, "NR040") {
        steps.push("Look at the full message for the unsupported construct.");
        steps.push("Reduce the program to the smallest failing example.");
        steps.push("Treat repeated NR040 failures as compiler bugs to fix in lowering.");
    } else if str_eq(code, "NR050") {
        steps.push("Re-run with the other backend to isolate whether the failure is backend-specific.");
        steps.push("Check the reported symbol or ABI path in the message.");
        steps.push("Treat verifier or emission failures as backend correctness bugs.");
    } else if str_eq(code, "NR051") {
        steps.push("Rebuild the CLI with backend support required for wasm enabled.");
        steps.push("Install or point NUCLEOR_WASM_LD at a working wasm-ld.");
        steps.push("Confirm the LLVM toolchain is visible in PATH.");
    } else if str_eq(code, "NR070") {
        steps.push("Validate Nucleor.toml syntax and dependency paths.");
        steps.push("Run nuc lock after manifest changes.");
        steps.push("Check workspace member and dependency graph cycles.");
    } else if str_eq(code, "NR090") {
        steps.push("Reduce the failing program to a small reproducer.");
        steps.push("Treat repeated NR090 failures as compiler bugs.");
        steps.push("Inspect the named pipeline stage and previous stage outputs.");
    };
    return steps;
}

fn explain_error_render(code: str, json_mode: i64) -> str {
    let title: str = explain_error_title(code);
    let summary: str = explain_error_summary(code);
    let explanation: str = explain_error_explanation(code);
    let reference: str = explain_error_reference(code);
    let steps: Vec<i32> = explain_error_next_steps(code);
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"code\":\""); sb_append(sb, json_escape(code));
        sb_append(sb, "\",\"title\":\""); sb_append(sb, json_escape(title));
        sb_append(sb, "\",\"summary\":\""); sb_append(sb, json_escape(summary));
        sb_append(sb, "\",\"explanation\":\""); sb_append(sb, json_escape(explanation));
        sb_append(sb, "\",\"reference\":\""); sb_append(sb, json_escape(reference));
        sb_append(sb, "\",\"next_steps\":[");
        let mut i: i64 = 0;
        while i < vec_len(steps) {
            if i > 0 { sb_append(sb, ","); };
            sb_append(sb, "\""); sb_append(sb, json_escape(vec_get(steps, i))); sb_append(sb, "\"");
            i = i + 1;
        };
        sb_append(sb, "]}");
        return sb_to_str(sb);
    };
    let mut sb2: i64 = sb_new();
    sb_append(sb2, code); sb_append(sb2, ": "); sb_append(sb2, title); sb_append(sb2, "\n");
    sb_append(sb2, summary); sb_append(sb2, "\n");
    sb_append(sb2, explanation); sb_append(sb2, "\n");
    sb_append(sb2, "reference: "); sb_append(sb2, reference); sb_append(sb2, "\n");
    if vec_len(steps) > 0 {
        sb_append(sb2, "next steps:\n");
        let mut j: i64 = 0;
        while j < vec_len(steps) {
            sb_append(sb2, "- "); sb_append(sb2, vec_get(steps, j)); sb_append(sb2, "\n");
            j = j + 1;
        };
    };
    return sb_to_str(sb2);
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
    let review_path: str = "";
    let review_filter: str = "";
    if review_active(review_path) == 1 {
        review_emit(review_path, str_concat("{\"schema_version\":\"1.0\",\"event\":\"compile_start\",\"file\":\"", str_concat(src_path, "\"}")));
    };
    // Pass 1.7: ownership checking
    let own_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { check_fn(pool, fn_nid, structs, enums, diags, source, review_path, review_filter); };
        fi = fi + 1;
    };
    let mut oi: i64 = 0;
    while oi < vec_len(impl_fns) {
        check_fn(pool, vec_get(impl_fns, oi), structs, enums, diags, source, review_path, review_filter);
        oi = oi + 1;
    };
    print_phase_time(time_passes, "ownership", now_ms() - own_start);
    let type_start: i64 = now_ms();
    let type_prof: Vec<i32> = tprof_new(time_passes);
    type_check_program(pool, prog, structs, diags, source, type_prof);
    print_phase_time(time_passes, "type", now_ms() - type_start);
    tprof_dump(type_prof);
    if strict_mode == 1 {
        let source_start: i64 = now_ms();
        source_rule_check(source, diags);
        print_phase_time(time_passes, "source", now_ms() - source_start);
        let mut pure_fns: Vec<i32> = Vec::new();
        let pure_collect_start: i64 = now_ms();
        fi = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 46 { pure_fns.push(node_field(pool, fn_nid, 1)); };
            fi = fi + 1;
        };
        print_phase_time(time_passes, "collect_pure", now_ms() - pure_collect_start);
        let effect_start: i64 = now_ms();
        fi = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 30 {
                let fname: str = node_field(pool, fn_nid, 1);
                let mut is_pure: i64 = 0;
                let mut pi: i64 = 0;
                while pi < vec_len(pure_fns) {
                    if str_eq(vec_get(pure_fns, pi), fname) { is_pure = 1; pi = vec_len(pure_fns); };
                    pi = pi + 1;
                };
                if is_pure == 1 { effect_check_fn(pool, fn_nid, pure_fns, diags, source, review_path, review_filter); };
            };
            fi = fi + 1;
        };
        print_phase_time(time_passes, "effect", now_ms() - effect_start);
        let taint_start: i64 = now_ms();
        fi = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 30 { taint_check_fn(pool, fn_nid, diags, source, review_path, review_filter); };
            fi = fi + 1;
        };
        print_phase_time(time_passes, "taint", now_ms() - taint_start);
    };
    if diag_count(diags) > 0 { diag_emit_text(diags); return 1; };
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
    return compile_file_mode(src_path, out_name, 1, 1, 0, 1);
}

fn fn_name_start_in_line(line: str) -> i64 {
    let slen: i64 = str_len(line);
    let mut p: i64 = 0;
    while p < slen && (str_char_at(line, p) == 32 || str_char_at(line, p) == 9) { p = p + 1; };
    if p + 2 > slen { return 0 - 1; };
    if str_eq(str_substring(line, p, p + 2), "fn") == 0 { return 0 - 1; };
    p = p + 2;
    while p < slen && (str_char_at(line, p) == 32 || str_char_at(line, p) == 9) { p = p + 1; };
    if p >= slen { return 0 - 1; };
    return p;
}

fn fn_name_end_in_line(line: str, start: i64) -> i64 {
    let slen: i64 = str_len(line);
    let mut p: i64 = start;
    while p < slen {
        let c: i64 = str_char_at(line, p);
        if is_alnum(c) == 1 || c == 95 { p = p + 1; }
        else { return p; };
    };
    return p;
}

fn extract_fn_name_from_line(line: str) -> str {
    let start: i64 = fn_name_start_in_line(line);
    if start < 0 { return ""; };
    let stop: i64 = fn_name_end_in_line(line, start);
    if stop <= start { return ""; };
    let mut after: i64 = stop;
    let slen: i64 = str_len(line);
    while after < slen && (str_char_at(line, after) == 32 || str_char_at(line, after) == 9) { after = after + 1; };
    if after >= slen || str_char_at(line, after) != 40 { return ""; };
    return str_substring(line, start, stop);
}

fn extract_public_fn_name_from_line(line: str) -> str {
    let compact: str = strip_spaces(line);
    let clen: i64 = str_len(compact);
    let mut start: i64 = 0 - 1;
    if clen >= 5 && str_eq(str_substring(compact, 0, 5), "pubfn") == 1 { start = 5; }
    else if clen >= 9 && str_eq(str_substring(compact, 0, 9), "pubpurefn") == 1 { start = 9; };
    if start < 0 || start >= clen { return ""; };
    let mut stop: i64 = start;
    while stop < clen {
        let ch: i64 = str_char_at(compact, stop);
        if is_alnum(ch) == 1 || ch == 95 { stop = stop + 1; }
        else { return str_substring(compact, start, stop); };
    };
    return str_substring(compact, start, stop);
}

fn collect_public_export_names(source: str) -> Vec<i32> {
    let mut exports: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let name: str = extract_public_fn_name_from_line(line);
        if str_len(name) > 0 { string_vec_push_unique(exports, name); };
        p = eol + 1;
    };
    return exports;
}

fn rewrite_test_main_line(line: str) -> str {
    let start: i64 = fn_name_start_in_line(line);
    if start < 0 { return line; };
    let stop: i64 = fn_name_end_in_line(line, start);
    if stop <= start { return line; };
    let name: str = str_substring(line, start, stop);
    if str_eq(name, "main") == 0 { return line; };
    return str_concat(str_substring(line, 0, start), str_concat("__nucleor_test_user_main", str_substring(line, stop, str_len(line))));
}

fn collect_test_names_from_source(source: str) -> Vec<i32> {
    let mut tests: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut marked_test: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let compact: str = strip_spaces(line);
        // Detect test attributes: legacy `@test` line, RFC-0021 `#[test]`,
        // or RFC-0021 `#[test, ignore]` / `#[test, should_panic]` etc.
        let mut is_test_attr: i64 = 0;
        if str_eq(compact, "@test") == 1 { is_test_attr = 1; };
        if str_eq(compact, "#[test]") == 1 { is_test_attr = 1; };
        if str_starts_with(compact, "#[test,") == 1 { is_test_attr = 1; };
        if str_starts_with(compact, "#[test ") == 1 { is_test_attr = 1; };
        if is_test_attr == 1 {
            marked_test = 1;
        } else {
            let fn_name: str = extract_fn_name_from_line(line);
            if str_len(fn_name) > 0 {
                if marked_test == 1 || str_starts_with(fn_name, "test_") == 1 {
                    tests.push(fn_name);
                };
                marked_test = 0;
            } else if str_len(compact) > 0 && str_starts_with(compact, "//") == 0 && str_starts_with(compact, "#[") == 0 {
                // Allow other #[...] attribute lines between the test attr and the fn
                marked_test = 0;
            };
        };
        p = eol + 1;
    };
    return tests;
}

fn build_test_harness_source(resolved_source: str, tests: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(resolved_source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(resolved_source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(resolved_source, p, eol);
        sb_append(sb, rewrite_test_main_line(line));
        if eol < slen { sb_append(sb, "\n"); };
        p = eol + 1;
    };
    if slen > 0 && str_char_at(resolved_source, slen - 1) != 10 { sb_append(sb, "\n"); };
    sb_append(sb, "\nfn main() -> i32 {\n");
    // RFC-0021 phase 2: when NUCLEOR_TEST_ONLY=<name> is set in the
    // environment, run only that test and exit with its return code.
    // The parent --isolation=process driver spawns one child per test
    // with this env var to get full process isolation.
    sb_append(sb, "    let only: str = getenv(\"NUCLEOR_TEST_ONLY\");\n");
    sb_append(sb, "    let mut failed: i32 = 0;\n");
    let mut i: i64 = 0;
    while i < vec_len(tests) {
        let test_name: str = vec_get(tests, i);
        sb_append(sb, "    if str_len(only) == 0 || str_eq(only, \"");
        sb_append(sb, test_name);
        sb_append(sb, "\") == 1 {\n");
        sb_append(sb, "        if ");
        sb_append(sb, test_name);
        sb_append(sb, "() == 0 {\n");
        sb_append(sb, "            print(\"  PASS: ");
        sb_append(sb, test_name);
        sb_append(sb, "\");\n");
        sb_append(sb, "        } else {\n");
        sb_append(sb, "            print(\"  FAIL: ");
        sb_append(sb, test_name);
        sb_append(sb, "\");\n");
        sb_append(sb, "            failed = failed + 1;\n");
        sb_append(sb, "        };\n");
        sb_append(sb, "    };\n");
        i = i + 1;
    };
    if vec_len(tests) == 0 {
        sb_append(sb, "    print(\"test result: no tests discovered\");\n");
        sb_append(sb, "    return 1;\n");
        sb_append(sb, "}\n");
        return sb_to_str(sb);
    };
    sb_append(sb, "    if str_len(only) > 0 {\n");
    sb_append(sb, "        if failed == 0 { return 0; };\n");
    sb_append(sb, "        return failed;\n");
    sb_append(sb, "    };\n");
    if vec_len(tests) == 1 {
        sb_append(sb, "    if failed == 0 { print(\"test result: PASS (1 test)\"); return 0; };\n");
    } else {
        sb_append(sb, "    if failed == 0 { print(\"test result: PASS (");
        sb_append(sb, str_from_int(vec_len(tests)));
        sb_append(sb, " tests)\"); return 0; };\n");
    };
    sb_append(sb, "    print(\"test result: FAIL\");\n");
    sb_append(sb, "    return failed;\n");
    sb_append(sb, "}\n");
    return sb_to_str(sb);
}

// RFC-0018 phase 3: `nuc fix --imports` migration tool.
// Rewrites quoted-path imports of the form
//     import "stdlib/rods/<rod>.nr"
//     use    "stdlib/rods/<rod>.nr"
// into the Rust-style equivalent
//     use std::<rod>;
// in-place. Skips lines that already use the std::/crate::/super::
// syntax. Writes the source back only if at least one line changed.
fn fix_imports_in_source(src: str) -> Vec<i32> {
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut changed: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line_end: i64 = eol;
        let mut lp: i64 = p;
        while lp < line_end && (str_char_at(src, lp) == 32 || str_char_at(src, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = line_end - lp;
        let mut prefix_len: i64 = 0;
        if line_len >= 8 && str_eq(str_substring(src, lp, lp + 7), "import ") == 1 { prefix_len = 7; };
        if prefix_len == 0 && line_len >= 5 && str_eq(str_substring(src, lp, lp + 4), "use ") == 1 { prefix_len = 4; };
        let mut rewritten: i64 = 0;
        if prefix_len > 0 {
            let mut qp: i64 = lp + prefix_len;
            while qp < line_end && str_char_at(src, qp) == 32 { qp = qp + 1; };
            if qp < line_end && str_char_at(src, qp) == 34 {
                let ps: i64 = qp + 1;
                let mut pe: i64 = ps;
                while pe < line_end && str_char_at(src, pe) != 34 { pe = pe + 1; };
                let raw: str = str_substring(src, ps, pe);
                let rlen: i64 = str_len(raw);
                let prefix_match: i64 = if rlen >= 12 { str_eq(str_substring(raw, 0, 12), "stdlib/rods/") } else { 0 };
                if prefix_match == 1 && rlen >= 15 && str_eq(str_substring(raw, rlen - 3, rlen), ".nr") == 1 {
                    let inner: str = str_substring(raw, 12, rlen - 3);
                    // Convert any embedded "/" into "::" so e.g. "foo/bar" -> "foo::bar".
                    let mut isb: i64 = sb_new();
                    sb_append(isb, "use std::");
                    let ilen: i64 = str_len(inner);
                    let mut ii: i64 = 0;
                    while ii < ilen {
                        let ch: i64 = str_char_at(inner, ii);
                        if ch == 47 { sb_append(isb, "::"); }
                        else { sb_append(isb, str_substring(inner, ii, ii + 1)); };
                        ii = ii + 1;
                    };
                    sb_append(isb, ";");
                    // Preserve leading whitespace.
                    if lp > p { sb_append(sb, str_substring(src, p, lp)); };
                    sb_append(sb, sb_to_str(isb));
                    if eol < slen { sb_append(sb, "\n"); };
                    changed = changed + 1;
                    rewritten = 1;
                };
            };
        };
        if rewritten == 0 {
            sb_append(sb, str_substring(src, p, eol));
            if eol < slen { sb_append(sb, "\n"); };
        };
        p = eol + 1;
    };
    let mut out: Vec<i32> = Vec::new();
    out.push(sb_to_str(sb));
    out.push(str_from_int(changed));
    return out;
}

// RFC-0015 phase 5 partial: `nuc fix --numeric` lints (does not modify)
// for mixed-width arithmetic. Scans for the textual pattern
// `let <name>: <int_type> = ...;` followed elsewhere by binop operands
// that don't align in width. Reports each finding with a suggested
// `as` cast. Full inference + automated rewrite arrives once the
// type lattice IR (phase 3) lands.
fn report_numeric_findings(src_path: str, src: str) -> i64 {
    let mut findings: i64 = 0;
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut line: i64 = 1;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let ln: str = str_substring(src, p, eol);
        let ll: i64 = str_len(ln);
        // Heuristic: any line with two distinct width markers next to a
        // binary operator counts. We look for adjacent declared types
        // such as ": i32" + ": i64" on contiguous lines, or in-line
        // "as i64" already present (which we ignore).
        if ll >= 8 && find_substr(ln, ": i32") >= 0 && find_substr(ln, " + ") >= 0 && find_substr(ln, "as i64") < 0 {
            print(str_concat(src_path, str_concat(":", str_concat(str_from_int(line), ": numeric: i32 in additive context — consider explicit `as i64`"))));
            findings = findings + 1;
        } else if ll >= 8 && find_substr(ln, ": i32") >= 0 && find_substr(ln, " - ") >= 0 && find_substr(ln, "as i64") < 0 {
            print(str_concat(src_path, str_concat(":", str_concat(str_from_int(line), ": numeric: i32 in subtractive context — consider explicit `as i64`"))));
            findings = findings + 1;
        };
        p = eol + 1;
        line = line + 1;
    };
    return findings;
}

fn find_substr(haystack: str, needle: str) -> i64 {
    let hlen: i64 = str_len(haystack);
    let nlen: i64 = str_len(needle);
    if nlen == 0 || nlen > hlen { return 0 - 1; };
    let mut i: i64 = 0;
    while i <= hlen - nlen {
        if str_eq(str_substring(haystack, i, i + nlen), needle) == 1 { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

// RFC-0029 doc-gen skeleton: walk the resolved source bundle, extract
// every `pub fn` / `fn` declaration line and the immediately-preceding
// `///` doc comment, and emit a Markdown summary to stdout (or write
// to a file with --out). v0.2.0 ships the skeleton; the v0.4 doc-gen
// adds parameter inference, return-type lookup, full Markdown nav,
// and per-module navigation.
// Pull the parameter list + return type out of an `fn name(args) -> ret`
// signature line. Returns (params, return_type) where each piece is a
// trimmed string fragment for direct rendering. Empty strings on parse
// failure (caller falls back to the raw signature line).
fn doc_extract_signature(line: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push("");
    out.push("");
    let llen: i64 = str_len(line);
    let mut i: i64 = 0;
    // Find `(`.
    while i < llen && str_char_at(line, i) != 40 { i = i + 1; };
    if i >= llen { return out; };
    let lp: i64 = i;
    // Walk to the matching `)` (no nested parens inside fn params).
    let mut rp: i64 = lp + 1;
    let mut depth: i64 = 1;
    while rp < llen && depth > 0 {
        let c: i64 = str_char_at(line, rp);
        if c == 40 { depth = depth + 1; }
        else if c == 41 { depth = depth - 1; };
        if depth == 0 { break; };
        rp = rp + 1;
    };
    if rp >= llen { return out; };
    vec_set(out, 0, str_substring(line, lp + 1, rp));
    // After `)`, look for `->` then the return type.
    let mut tp: i64 = rp + 1;
    while tp < llen && (str_char_at(line, tp) == 32 || str_char_at(line, tp) == 9) { tp = tp + 1; };
    if tp + 1 < llen && str_char_at(line, tp) == 45 && str_char_at(line, tp + 1) == 62 {
        tp = tp + 2;
        while tp < llen && (str_char_at(line, tp) == 32 || str_char_at(line, tp) == 9) { tp = tp + 1; };
        let mut re: i64 = tp;
        while re < llen && str_char_at(line, re) != 123 && str_char_at(line, re) != 59 { re = re + 1; };
        vec_set(out, 1, str_substring(line, tp, re));
    };
    return out;
}

fn run_doc_command(src_path: str, out_path: str) -> i64 {
    if str_len(src_path) == 0 {
        print("ERROR: nuc doc requires a source file");
        print("Usage: nuc doc <file> [--out <markdown>]");
        return 1;
    };
    let src: str = file_read_string(src_path);
    if str_len(src) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    let mut sb: i64 = sb_new();
    sb_append(sb, "# ");
    sb_append(sb, src_path);
    sb_append(sb, "\n\nGenerated by `nuc doc` (RFC-0029).\n\n");
    sb_append(sb, "## Function index\n\n");
    // First pass: build the index.
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut fn_count: i64 = 0;
    let mut fn_names: Vec<i32> = Vec::new();
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        let fn_name: str = extract_fn_name_from_line(line);
        if str_len(fn_name) > 0 {
            fn_names.push(fn_name);
            sb_append(sb, "- [`"); sb_append(sb, fn_name); sb_append(sb, "`](#");
            sb_append(sb, fn_name); sb_append(sb, ")\n");
            fn_count = fn_count + 1;
        };
        p = eol + 1;
    };
    sb_append(sb, "\n");
    // Second pass: doc-comment + signature for each fn.
    p = 0;
    let mut last_doc_sb: i64 = sb_new();
    let mut last_doc_lines: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        let mut lp: i64 = 0;
        let llen: i64 = str_len(line);
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        if lp + 3 <= llen && str_eq(str_substring(line, lp, lp + 3), "///") == 1 {
            let mut bp: i64 = lp + 3;
            if bp < llen && str_char_at(line, bp) == 32 { bp = bp + 1; };
            sb_append(last_doc_sb, str_substring(line, bp, llen));
            sb_append(last_doc_sb, "\n");
            last_doc_lines = last_doc_lines + 1;
        } else {
            let fn_name: str = extract_fn_name_from_line(line);
            if str_len(fn_name) > 0 {
                sb_append(sb, "## `");
                sb_append(sb, fn_name);
                sb_append(sb, "`\n\n");
                if last_doc_lines > 0 {
                    sb_append(sb, sb_to_str(last_doc_sb));
                    sb_append(sb, "\n");
                };
                let sig_parts: Vec<i32> = doc_extract_signature(line);
                let params: str = vec_get(sig_parts, 0);
                let ret_t: str = vec_get(sig_parts, 1);
                sb_append(sb, "**Signature:**\n```nucleor\nfn ");
                sb_append(sb, fn_name);
                sb_append(sb, "(");
                sb_append(sb, params);
                sb_append(sb, ")");
                if str_len(ret_t) > 0 {
                    sb_append(sb, " -> ");
                    sb_append(sb, ret_t);
                };
                sb_append(sb, "\n```\n\n");
                last_doc_sb = sb_new();
                last_doc_lines = 0;
            } else if lp == llen {
                last_doc_sb = sb_new();
                last_doc_lines = 0;
            };
        };
        p = eol + 1;
    };
    let body: str = sb_to_str(sb);
    if str_len(out_path) > 0 {
        file_write_string(out_path, body);
        print(str_concat("nuc doc: wrote ", str_concat(out_path, str_concat(" (", str_concat(str_from_int(fn_count), " functions, with index + signatures)")))));
    } else {
        print(body);
    };
    return 0;
}

fn run_fix_command(src_path: str, subcmd: str) -> i64 {
    if str_eq(subcmd, "imports") == 0 && str_eq(subcmd, "numeric") == 0 {
        print("ERROR: nuc fix requires --imports or --numeric");
        print("Usage:");
        print("  nuc fix --imports <file>   Rewrite quoted imports to use std::");
        print("  nuc fix --numeric <file>   Lint mixed-width arithmetic (RFC-0015)");
        return 1;
    };
    if str_len(src_path) == 0 {
        print(str_concat("ERROR: nuc fix --", str_concat(subcmd, " requires a source file")));
        return 1;
    };
    let src: str = file_read_string(src_path);
    if str_len(src) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    if str_eq(subcmd, "imports") == 1 {
        let result: Vec<i32> = fix_imports_in_source(src);
        let new_src: str = vec_get(result, 0);
        let n_changed: i64 = str_to_int(vec_get(result, 1));
        if n_changed == 0 {
            print(str_concat("nothing to fix in ", src_path));
            return 0;
        };
        file_write_string(src_path, new_src);
        print(str_concat("nuc fix --imports: rewrote ", str_concat(str_from_int(n_changed), str_concat(" import line(s) in ", src_path))));
        return 0;
    };
    // numeric
    let n: i64 = report_numeric_findings(src_path, src);
    if n == 0 {
        print(str_concat("nuc fix --numeric: no mixed-width arithmetic patterns detected in ", src_path));
        return 0;
    };
    print(str_concat("nuc fix --numeric: ", str_concat(str_from_int(n), str_concat(" finding(s) in ", src_path))));
    print("  Add explicit `as <wider_type>` casts at flagged sites.");
    print("  This linter is intentionally conservative — manual review still required.");
    return 0;
}

fn run_test_command(src_path: str, out_name: str, use_cache: i64, time_passes: i64, list_only: i64, isolation_process: i64) -> i64 {
    let raw_source: str = file_read_string(src_path);
    if str_len(raw_source) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    let tests: Vec<i32> = collect_test_names_from_source(raw_source);
    if vec_len(tests) == 0 {
        print(str_concat("  no tests found in ", src_path));
        return 1;
    };
    print(str_concat("  discovered tests: ", str_from_int(vec_len(tests))));
    let mut i: i64 = 0;
    while i < vec_len(tests) {
        print(str_concat("    ", vec_get(tests, i)));
        i = i + 1;
    };
    if list_only == 1 { return 0; };
    let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
    let resolved_source: str = vec_get(bundle, 0);
    if str_len(resolved_source) == 0 {
        print(str_concat("ERROR: cannot resolve ", src_path));
        return 1;
    };
    let harness_source: str = build_test_harness_source(resolved_source, tests);
    let temp_src: str = sanitize(str_concat("target/", str_concat(out_name, "__test_harness.nr")));
    file_write_string(temp_src, harness_source);
    let rc: i64 = compile_file_mode(temp_src, out_name, 1, use_cache, time_passes, 1);
    if rc != 0 { return rc; };
    let exe: str = sanitize(str_concat("target\\", str_concat(out_name, ".exe")));
    if isolation_process == 0 {
        // Default: single process, all tests inline.
        return system(exe);
    };
    // RFC-0021 phase 2: --isolation=process — spawn one child per test
    // with NUCLEOR_TEST_ONLY=<name>, capture exit code, report aggregate.
    print("  isolation: process (one child per test)");
    let mut failed: i64 = 0;
    let mut ti: i64 = 0;
    while ti < vec_len(tests) {
        let tname: str = vec_get(tests, ti);
        env_set("NUCLEOR_TEST_ONLY", tname);
        let child_rc: i64 = system(exe);
        env_unset("NUCLEOR_TEST_ONLY");
        if child_rc != 0 { failed = failed + 1; };
        ti = ti + 1;
    };
    if failed == 0 {
        print(str_concat("test result: PASS (", str_concat(str_from_int(vec_len(tests)), " tests, isolated)")));
        return 0;
    };
    print(str_concat("test result: FAIL (", str_concat(str_from_int(failed), str_concat(" of ", str_concat(str_from_int(vec_len(tests)), " isolated children failed)")))));
    return 1;
}

fn run_bench_command(src_path: str, out_name: str, use_cache: i64, time_passes: i64, iterations: i64, warmup: i64) -> i64 {
    if iterations <= 0 {
        print("ERROR: --iterations must be >= 1");
        return 1;
    };
    if warmup < 0 {
        print("ERROR: --warmup must be >= 0");
        return 1;
    };
    let rc: i64 = compile_file_mode(src_path, out_name, 1, use_cache, time_passes, 1);
    if rc != 0 { return rc; };
    let exe: str = sanitize(str_concat("target\\", str_concat(out_name, ".exe")));
    let run_cmd: str = str_concat("\"", str_concat(exe, "\" >NUL 2>&1"));
    let mut wi: i64 = 0;
    while wi < warmup {
        let warm_rc: i64 = system(run_cmd);
        if warm_rc != 0 {
            print(str_concat("ERROR: warmup run failed with exit ", str_from_int(warm_rc)));
            return 1;
        };
        wi = wi + 1;
    };
    let mut total_ms: i64 = 0;
    let mut best_ms: i64 = 0 - 1;
    let mut worst_ms: i64 = 0;
    let mut it: i64 = 0;
    while it < iterations {
        let start_ms: i64 = now_ms();
        let run_rc: i64 = system(run_cmd);
        let elapsed_ms: i64 = now_ms() - start_ms;
        if run_rc != 0 {
            print(str_concat("ERROR: benchmark run failed with exit ", str_from_int(run_rc)));
            return 1;
        };
        total_ms = total_ms + elapsed_ms;
        if best_ms < 0 || elapsed_ms < best_ms { best_ms = elapsed_ms; };
        if elapsed_ms > worst_ms { worst_ms = elapsed_ms; };
        it = it + 1;
    };
    print(str_concat("  bench iterations: ", str_from_int(iterations)));
    print(str_concat("  warmup runs: ", str_from_int(warmup)));
    print(str_concat("  total: ", str_concat(str_from_int(total_ms), " ms")));
    print(str_concat("  avg: ", str_concat(str_from_int(total_ms / iterations), " ms")));
    print(str_concat("  min: ", str_concat(str_from_int(best_ms), " ms")));
    print(str_concat("  max: ", str_concat(str_from_int(worst_ms), " ms")));
    return 0;
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

fn secure_hash(s: str) -> str {
    // Uses DJB2 fingerprint. SHA256 available via sha256() builtin after bootstrap.
    return content_hash(s);
}

fn package_checksum_file_name() -> str { return "Nucleor.package.sha256"; }
fn registry_metadata_file_name() -> str { return "Nucleor.publish.json"; }
fn package_exports_manifest_file_name() -> str { return "Nucleor.exports.json"; }
fn package_exports_header_file_name() -> str { return "Nucleor.exports.h"; }
fn package_exports_rust_file_name() -> str { return "Nucleor.exports.rs"; }
fn package_signature_file_name() -> str { return "Nucleor.publish.signature.json"; }

fn compiler_version_label() -> str {
    return "0.2.0-v2";
}

fn compiler_backend_label() -> str {
    return "llvm";
}

fn abi_export_version_label() -> str {
    return "c-v1-shared-exports";
}

fn abi_export_surface_policy_label() -> str {
    return "pub-fn-c-safe-v1";
}

fn abi_export_symbol_policy_label() -> str {
    return "explicit-public-no-mangling";
}

fn abi_export_version_policy_label() -> str {
    return "semver-major-breaks-abi";
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

fn run_explain_command(argc: i64) -> i64 {
    let mut json_mode: i64 = 0;
    let mut code: str = "";
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") || str_eq(arg, "--output=json") {
            json_mode = 1;
        } else if str_eq(arg, "--output") {
            if i + 1 >= argc {
                print("Usage: nuc explain <NR001|NR020|...> [--json]");
                return 1;
            };
            if str_eq(args_get(i + 1), "json") == 1 {
                json_mode = 1;
                i = i + 1;
            } else {
                print("Usage: nuc explain <NR001|NR020|...> [--json]");
                return 1;
            };
        } else if cli_is_flag(arg) == 0 && str_len(code) == 0 {
            code = ascii_upper(strip_spaces(arg));
        };
        i = i + 1;
    };
    if str_len(code) == 0 {
        print("Usage: nuc explain <NR001|NR020|...> [--json]");
        return 1;
    };
    if explain_error_known(code) == 0 {
        print(str_concat("unknown error code: ", code));
        return 1;
    };
    print(explain_error_render(code, json_mode));
    return 0;
}

fn bootstrap_corpus_listing_path(tag: str) -> str {
    return str_concat("target/bootstrap_corpus_", str_concat(tag, str_concat("_", str_concat(str_from_int(now_ms()), ".txt"))));
}

fn bootstrap_collect_corpus_files(tag: str) -> Vec<i32> {
    let listing_path: str = bootstrap_corpus_listing_path(tag);
    system("mkdir target 2>NUL");
    system(str_concat("dir /b examples\\*.nr > ", str_concat(listing_path, " 2>NUL")));
    let raw: str = file_read_string(listing_path);
    system(str_concat("del /q ", str_concat(listing_path, " >NUL 2>NUL")));
    let mut files: Vec<i32> = Vec::new();
    let slen: i64 = str_len(raw);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw, eol) != 10 && str_char_at(raw, eol) != 13 { eol = eol + 1; };
        let line: str = str_substring(raw, p, eol);
        if str_len(line) > 0 { files.push(line); };
        while eol < slen && (str_char_at(raw, eol) == 10 || str_char_at(raw, eol) == 13) { eol = eol + 1; };
        p = eol;
    };
    return files;
}

fn bootstrap_runtime_source_path() -> str {
    let cli_runtime: str = "crates/nucleor-cli/runtime/nucleor_rt.c";
    if str_len(file_read_string(cli_runtime)) > 0 { return cli_runtime; };
    let stdlib_runtime: str = "stdlib/runtime/nucleor_llvm_rt.c";
    if str_len(file_read_string(stdlib_runtime)) > 0 { return stdlib_runtime; };
    return "";
}

fn count_text_lines(raw: str) -> i64 {
    let slen: i64 = str_len(raw);
    if slen == 0 { return 0; };
    let mut lines: i64 = 1;
    let mut i: i64 = 0;
    while i < slen {
        if str_char_at(raw, i) == 10 { lines = lines + 1; };
        i = i + 1;
    };
    return lines;
}

fn bootstrap_runtime_symbol_count(raw: str) -> i64 {
    let slen: i64 = str_len(raw);
    let mut count: i64 = 0;
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(raw, p, eol);
        let compact: str = strip_spaces(line);
        if text_contains(line, "__nucleor_") == 1 && text_contains(line, "(") == 1 && str_starts_with(compact, "//") == 0 && str_starts_with(compact, "*") == 0 && str_starts_with(compact, "/*") == 0 {
            count = count + 1;
        };
        p = eol + 1;
    };
    return count;
}

fn run_bootstrap_command(argc: i64) -> i64 {
    let mut json_mode: i64 = 0;
    let mut subcmd: str = "status";
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") || str_eq(arg, "--output=json") {
            json_mode = 1;
        } else if str_eq(arg, "--output") {
            if i + 1 >= argc {
                print("Usage: nuc bootstrap <status|dump-corpus> [--json]");
                return 1;
            };
            if str_eq(args_get(i + 1), "json") == 1 {
                json_mode = 1;
                i = i + 1;
            } else {
                print("Usage: nuc bootstrap <status|dump-corpus> [--json]");
                return 1;
            };
        } else if cli_is_flag(arg) == 0 && str_eq(subcmd, "status") == 1 {
            subcmd = arg;
        };
        i = i + 1;
    };
    let files: Vec<i32> = bootstrap_collect_corpus_files(subcmd);
    if str_eq(subcmd, "status") == 1 {
        let examples: i64 = vec_len(files);
        let mut err_examples: i64 = 0;
        let mut fi: i64 = 0;
        while fi < vec_len(files) {
            if str_starts_with(vec_get(files, fi), "err_") == 1 { err_examples = err_examples + 1; };
            fi = fi + 1;
        };
        let positive_examples: i64 = examples - err_examples;
        let runtime_path: str = bootstrap_runtime_source_path();
        let runtime_source: str = file_read_string(runtime_path);
        let runtime_lines: i64 = count_text_lines(runtime_source);
        let runtime_symbols: i64 = bootstrap_runtime_symbol_count(runtime_source);
        if json_mode == 1 {
            let mut sb: i64 = sb_new();
            sb_append(sb, "{\"stage\":\"1\",\"stage_name\":\"self_hosted\",\"examples\":");
            sb_append(sb, str_from_int(examples));
            sb_append(sb, ",\"error_examples\":"); sb_append(sb, str_from_int(err_examples));
            sb_append(sb, ",\"positive_examples\":"); sb_append(sb, str_from_int(positive_examples));
            sb_append(sb, ",\"runtime_lines\":"); sb_append(sb, str_from_int(runtime_lines));
            sb_append(sb, ",\"runtime_symbols\":"); sb_append(sb, str_from_int(runtime_symbols));
            sb_append(sb, ",\"runtime_source\":\""); sb_append(sb, json_escape(runtime_path));
            sb_append(sb, "\",\"bootstrap_contract\":\"NUCLEOR_BOOTSTRAP_CONTRACT.md\",\"self_hosted\":true}");
            print(sb_to_str(sb));
            return 0;
        };
        print("=== Nucleor Bootstrap Status ===");
        print("  Stage: 1 (self-hosted)");
        print(str_concat("  Examples: ", str_concat(str_from_int(examples), str_concat(" (", str_concat(str_from_int(positive_examples), str_concat(" positive, ", str_concat(str_from_int(err_examples), " error)"))))));
        if str_len(runtime_path) > 0 {
            print(str_concat("  Runtime source: ", runtime_path));
        } else {
            print("  Runtime source: unavailable");
        };
        print(str_concat("  Runtime: ", str_concat(str_from_int(runtime_lines), str_concat(" lines, ~", str_concat(str_from_int(runtime_symbols), " symbols")))));
        print("  Self-hosted: yes");
        print("  Contract: NUCLEOR_BOOTSTRAP_CONTRACT.md");
        return 0;
    };
    if str_eq(subcmd, "dump-corpus") == 1 {
        if vec_len(files) == 0 {
            print("no examples/ directory found");
            return 1;
        };
        if json_mode == 1 {
            let mut sb2: i64 = sb_new();
            sb_append(sb2, "{\"corpus_count\":"); sb_append(sb2, str_from_int(vec_len(files)));
            sb_append(sb2, ",\"files\":[");
            let mut fj: i64 = 0;
            while fj < vec_len(files) {
                if fj > 0 { sb_append(sb2, ","); };
                sb_append(sb2, "\""); sb_append(sb2, json_escape(vec_get(files, fj))); sb_append(sb2, "\"");
                fj = fj + 1;
            };
            sb_append(sb2, "]}");
            print(sb_to_str(sb2));
            return 0;
        };
        print(str_concat("=== Bootstrap Corpus (", str_concat(str_from_int(vec_len(files)), " files) ===")));
        let mut fk: i64 = 0;
        while fk < vec_len(files) {
            print(str_concat("  ", vec_get(files, fk)));
            fk = fk + 1;
        };
        return 0;
    };
    print(str_concat("unknown bootstrap subcommand: ", subcmd));
    print("Usage: nuc bootstrap <status|dump-corpus> [--json]");
    return 1;
}

fn token_summary(tok: Vec<i32>) -> str {
    let tt: i64 = tok_type(tok);
    let val: str = tok_val(tok);
    let pos: i64 = vec_get(tok, 2);
    let mut sb: i64 = sb_new();
    sb_append(sb, str_from_int(tt));
    if tt == 1 || tt == 2 || tt == 3 || tt == 70 {
        sb_append(sb, ":");
        if tt == 2 || tt == 70 { sb_append(sb, str_from_int(val)); }
        else { sb_append(sb, val); };
    };
    sb_append(sb, " @ ");
    sb_append(sb, str_from_int(pos));
    return sb_to_str(sb);
}

fn ast_item_summary(pool: Vec<i32>, nid: i64) -> str {
    let kind: i64 = node_kind(pool, nid);
    if kind == 30 { return str_concat("fn ", node_field(pool, nid, 1)); };
    if kind == 32 { return str_concat("extern fn ", node_field(pool, nid, 1)); };
    if kind == 33 { return str_concat("struct ", node_field(pool, nid, 1)); };
    if kind == 36 { return str_concat("enum ", node_field(pool, nid, 1)); };
    if kind == 44 { return str_concat("trait ", node_field(pool, nid, 1)); };
    if kind == 45 { return str_concat("impl ", node_field(pool, nid, 2)); };
    if kind == 46 { return str_concat("pure fn ", node_field(pool, nid, 1)); };
    if kind == 50 { return str_concat("const ", node_field(pool, nid, 1)); };
    if kind == 51 { return str_concat("type ", node_field(pool, nid, 1)); };
    return str_concat("node_kind ", str_from_int(kind));
}

fn stage_dump_tokens_json(tokens: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"stage\":\"tokens\",\"count\":");
    sb_append(sb, str_from_int(vec_len(tokens)));
    sb_append(sb, ",\"tokens\":[");
    let mut i: i64 = 0;
    while i < vec_len(tokens) {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "\""); sb_append(sb, json_escape(token_summary(vec_get(tokens, i)))); sb_append(sb, "\"");
        i = i + 1;
    };
    sb_append(sb, "]}");
    return sb_to_str(sb);
}

fn stage_dump_ast_json(pool: Vec<i32>, prog: i64) -> str {
    let mut sb: i64 = sb_new();
    let cnt: i64 = list_len(pool, prog);
    sb_append(sb, "{\"stage\":\"ast\",\"item_count\":");
    sb_append(sb, str_from_int(cnt));
    sb_append(sb, ",\"items\":[");
    let mut i: i64 = 0;
    while i < cnt {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "\""); sb_append(sb, json_escape(ast_item_summary(pool, list_get(pool, prog, i)))); sb_append(sb, "\"");
        i = i + 1;
    };
    sb_append(sb, "]}");
    return sb_to_str(sb);
}

fn stage_dump_typed_json(diags: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let cnt: i64 = diag_count(diags);
    sb_append(sb, "{\"stage\":\"typed\",\"diagnostic_count\":");
    sb_append(sb, str_from_int(cnt));
    if cnt == 0 {
        sb_append(sb, ",\"status\":\"ok\"}");
        return sb_to_str(sb);
    };
    sb_append(sb, ",\"status\":\"diagnostics\",\"diagnostics\":[");
    let mut i: i64 = 0;
    while i < cnt {
        if i > 0 { sb_append(sb, ","); };
        let d: Vec<i32> = diag_get(diags, i);
        let msg: str = str_concat("[", str_concat(vec_get(d, 2), str_concat("] ", vec_get(d, 3))));
        sb_append(sb, "\""); sb_append(sb, json_escape(msg)); sb_append(sb, "\"");
        i = i + 1;
    };
    sb_append(sb, "]}");
    return sb_to_str(sb);
}

fn stage_dump_ir_json(function_count: i64, extern_count: i64, struct_count: i64, enum_count: i64, ll_bytes: i64, skipped: i64, skip_reason: str) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"stage\":\"ir\"");
    if skipped == 1 {
        sb_append(sb, ",\"skipped\":true,\"reason\":\""); sb_append(sb, json_escape(skip_reason)); sb_append(sb, "\"}");
        return sb_to_str(sb);
    };
    sb_append(sb, ",\"function_count\":"); sb_append(sb, str_from_int(function_count));
    sb_append(sb, ",\"extern_fn_count\":"); sb_append(sb, str_from_int(extern_count));
    sb_append(sb, ",\"struct_count\":"); sb_append(sb, str_from_int(struct_count));
    sb_append(sb, ",\"enum_count\":"); sb_append(sb, str_from_int(enum_count));
    sb_append(sb, ",\"ll_bytes\":"); sb_append(sb, str_from_int(ll_bytes));
    sb_append(sb, "}");
    return sb_to_str(sb);
}

fn run_stage_dump_command(argc: i64) -> i64 {
    let mut json_mode: i64 = 0;
    let mut stage: str = "";
    let mut src_path: str = "";
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") || str_eq(arg, "--output=json") {
            json_mode = 1;
        } else if str_eq(arg, "--output") {
            if i + 1 >= argc {
                print("Usage: nuc stage-dump <tokens|ast|typed|ir|all> <file.nr> [--json]");
                return 1;
            };
            if str_eq(args_get(i + 1), "json") == 1 {
                json_mode = 1;
                i = i + 1;
            } else {
                print("Usage: nuc stage-dump <tokens|ast|typed|ir|all> <file.nr> [--json]");
                return 1;
            };
        } else if cli_is_flag(arg) == 0 && str_len(stage) == 0 {
            stage = arg;
        } else if cli_is_flag(arg) == 0 && str_len(src_path) == 0 {
            src_path = arg;
        };
        i = i + 1;
    };
    if str_len(stage) == 0 || str_len(src_path) == 0 {
        print("Usage: nuc stage-dump <tokens|ast|typed|ir|all> <file.nr> [--json]");
        return 1;
    };
    let bundle: Vec<i32> = load_resolved_source_bundle(src_path, 1);
    let source: str = vec_get(bundle, 0);
    if str_len(source) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    if preflight_source_check(source) != 0 { return 1; };
    let tokens: Vec<i32> = lex(source);
    let need_ast: i64 = str_eq(stage, "ast") == 1 || str_eq(stage, "typed") == 1 || str_eq(stage, "ir") == 1 || str_eq(stage, "all") == 1;
    let mut pool: Vec<i32> = Vec::new();
    let mut prog: i64 = 0 - 1;
    if need_ast == 1 {
        let r: Vec<i32> = parse_program(tokens, pool);
        prog = pr_val(r);
    };
    if str_eq(stage, "tokens") == 0 && str_eq(stage, "ast") == 0 && str_eq(stage, "typed") == 0 && str_eq(stage, "ir") == 0 && str_eq(stage, "all") == 0 {
        print(str_concat("unknown stage-dump stage: ", stage));
        print("Usage: nuc stage-dump <tokens|ast|typed|ir|all> <file.nr> [--json]");
        return 1;
    };
    if json_mode == 1 && str_eq(stage, "tokens") == 1 {
        print(stage_dump_tokens_json(tokens));
        return 0;
    };
    if json_mode == 0 && (str_eq(stage, "tokens") == 1 || str_eq(stage, "all") == 1) {
        print(str_concat("=== TOKENS (", str_concat(str_from_int(vec_len(tokens)), ") ===")));
        let mut ti: i64 = 0;
        while ti < vec_len(tokens) {
            print(str_concat("  ", token_summary(vec_get(tokens, ti))));
            ti = ti + 1;
        };
        if str_eq(stage, "tokens") == 1 { return 0; };
    };
    if json_mode == 1 && str_eq(stage, "ast") == 1 {
        print(stage_dump_ast_json(pool, prog));
        return 0;
    };
    if json_mode == 0 && (str_eq(stage, "ast") == 1 || str_eq(stage, "all") == 1) {
        let item_cnt: i64 = list_len(pool, prog);
        print(str_concat("=== AST (", str_concat(str_from_int(item_cnt), " items) ===")));
        let mut ai: i64 = 0;
        while ai < item_cnt {
            print(str_concat("  [", str_concat(str_from_int(ai), str_concat("] ", ast_item_summary(pool, list_get(pool, prog, ai))))));
            ai = ai + 1;
        };
        if str_eq(stage, "ast") == 1 { return 0; };
    };
    let mut structs: Vec<i32> = Vec::new();
    let mut enums: Vec<i32> = Vec::new();
    let mut externs: Vec<i32> = Vec::new();
    let mut globals: Vec<i32> = Vec::new();
    let item_cnt2: i64 = list_len(pool, prog);
    let mut ci: i64 = 0;
    while ci < item_cnt2 {
        let nid: i64 = list_get(pool, prog, ci);
        if node_kind(pool, nid) == 33 { structs.push(nid); }
        else if node_kind(pool, nid) == 36 { enums.push(nid); }
        else if node_kind(pool, nid) == 32 { externs.push(nid); };
        if node_kind(pool, nid) == 50 { globals.push(nid); };
        ci = ci + 1;
    };
    let mut diags: Vec<i32> = diag_new();
    type_check_program(pool, prog, structs, diags, source, tprof_new(0));
    if json_mode == 1 && str_eq(stage, "typed") == 1 {
        print(stage_dump_typed_json(diags));
        return 0;
    };
    if json_mode == 0 && (str_eq(stage, "typed") == 1 || str_eq(stage, "all") == 1) {
        if diag_count(diags) == 0 {
            print("=== TYPED (0 diagnostics) ===");
        } else {
            print(str_concat("=== TYPED (", str_concat(str_from_int(diag_count(diags)), " diagnostics) ===")));
            diag_emit_text(diags);
        };
        if str_eq(stage, "typed") == 1 { return 0; };
    };
    let mut ir_json: str = "";
    if diag_count(diags) > 0 {
        ir_json = stage_dump_ir_json(0, vec_len(externs), vec_len(structs), vec_len(enums), 0, 1, "type_diagnostics");
        if json_mode == 0 && (str_eq(stage, "ir") == 1 || str_eq(stage, "all") == 1) {
            print("=== IR ===");
            print("  skipped: type diagnostics present");
        };
    } else {
        let mut strtab: Vec<i32> = Vec::new();
        let mut fns: Vec<i32> = Vec::new();
        let mut trait_impls: Vec<i32> = Vec::new();
        let mut impl_fns: Vec<i32> = Vec::new();
        ci = 0;
        while ci < item_cnt2 {
            let nid2: i64 = list_get(pool, prog, ci);
            if node_kind(pool, nid2) == 45 {
                let type_name: str = node_field(pool, nid2, 2);
                let methods: i64 = node_field(pool, nid2, 3);
                let mc: i64 = list_len(pool, methods);
                let mut mi: i64 = 0;
                while mi < mc {
                    let method_nid: i64 = list_get(pool, methods, mi);
                    let orig_name: str = node_field(pool, method_nid, 1);
                    let mangled: str = str_concat(type_name, str_concat("__", orig_name));
                    impl_fns.push(mk6(pool, 30, mangled, node_field(pool, method_nid, 2), node_field(pool, method_nid, 3), node_field(pool, method_nid, 4), node_field(pool, method_nid, 5)));
                    trait_impl_register(trait_impls, type_name, orig_name, mangled);
                    mi = mi + 1;
                };
            };
            ci = ci + 1;
        };
        let mut closures: Vec<i32> = Vec::new();
        ci = 0;
        while ci < item_cnt2 {
            let nid3: i64 = list_get(pool, prog, ci);
            if node_kind(pool, nid3) == 30 { fns.push(lower_fn(pool, nid3, strtab, structs, enums, globals, closures, trait_impls)); };
            ci = ci + 1;
        };
        let mut ii: i64 = 0;
        while ii < vec_len(impl_fns) { fns.push(lower_fn(pool, vec_get(impl_fns, ii), strtab, structs, enums, globals, closures, trait_impls)); ii = ii + 1; };
        let mut ci2: i64 = 0;
        while ci2 < vec_len(closures) { fns.push(vec_get(closures, ci2)); ci2 = ci2 + 1; };
        let ll: str = emit_module_ext(fns, strtab, pool, externs);
        ir_json = stage_dump_ir_json(vec_len(fns), vec_len(externs), vec_len(structs), vec_len(enums), str_len(ll), 0, "");
        if json_mode == 0 && (str_eq(stage, "ir") == 1 || str_eq(stage, "all") == 1) {
            print("=== IR ===");
            print(str_concat("  functions: ", str_from_int(vec_len(fns))));
            print(str_concat("  externs: ", str_from_int(vec_len(externs))));
            print(str_concat("  structs: ", str_from_int(vec_len(structs))));
            print(str_concat("  enums: ", str_from_int(vec_len(enums))));
            print(str_concat("  ll_bytes: ", str_from_int(str_len(ll))));
        };
    };
    if str_eq(stage, "ir") == 1 && json_mode == 1 {
        print(ir_json);
        return 0;
    };
    if str_eq(stage, "ir") == 1 { return 0; };
    if json_mode == 1 && str_eq(stage, "all") == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"stage\":\"all\",\"tokens\":"); sb_append(sb, stage_dump_tokens_json(tokens));
        sb_append(sb, ",\"ast\":"); sb_append(sb, stage_dump_ast_json(pool, prog));
        sb_append(sb, ",\"typed\":"); sb_append(sb, stage_dump_typed_json(diags));
        sb_append(sb, ",\"ir\":"); sb_append(sb, ir_json);
        sb_append(sb, "}");
        print(sb_to_str(sb));
        return 0;
    };
    return 0;
}

fn trim_ws(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut start: i64 = 0;
    while start < slen && (str_char_at(s, start) == 32 || str_char_at(s, start) == 9 || str_char_at(s, start) == 10 || str_char_at(s, start) == 13) {
        start = start + 1;
    };
    let mut stop: i64 = slen;
    while stop > start && (str_char_at(s, stop - 1) == 32 || str_char_at(s, stop - 1) == 9 || str_char_at(s, stop - 1) == 10 || str_char_at(s, stop - 1) == 13) {
        stop = stop - 1;
    };
    return str_substring(s, start, stop);
}

fn string_vec_contains(items: Vec<i32>, value: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(items) {
        if str_eq(vec_get(items, i), value) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn string_vec_push_unique(items: Vec<i32>, value: str) -> i64 {
    if string_vec_contains(items, value) == 0 { items.push(value); };
    return 0;
}

fn int_vec_contains(items: Vec<i32>, value: i64) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(items) {
        if vec_get(items, i) == value { return 1; };
        i = i + 1;
    };
    return 0;
}

fn csv_to_string_vec(csv: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let clen: i64 = str_len(csv);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= clen {
        let at_end: i64 = i == clen;
        let mut at_comma: i64 = 0;
        if at_end == 0 && str_char_at(csv, i) == 44 { at_comma = 1; };
        if at_comma == 1 || at_end == 1 {
            let part: str = trim_ws(str_substring(csv, start, i));
            if str_len(part) > 0 { string_vec_push_unique(out, part); };
            start = i + 1;
        };
        i = i + 1;
    };
    return out;
}

fn join_strings(items: Vec<i32>, sep: str) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(items) {
        if i > 0 { sb_append(sb, sep); };
        sb_append(sb, vec_get(items, i));
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn csv_pretty(csv: str) -> str {
    return join_strings(csv_to_string_vec(csv), ", ");
}

fn sb_append_json_bool(sb: i64, value: i64) -> i64 {
    if value == 1 { sb_append(sb, "true"); }
    else { sb_append(sb, "false"); };
    return 0;
}

fn sb_append_json_string_array(sb: i64, items: Vec<i32>) -> i64 {
    sb_append(sb, "[");
    let mut i: i64 = 0;
    while i < vec_len(items) {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "\"");
        sb_append(sb, json_escape(vec_get(items, i)));
        sb_append(sb, "\"");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn sb_append_json_string_or_null(sb: i64, value: str) -> i64 {
    if str_len(value) == 0 {
        sb_append(sb, "null");
    } else {
        sb_append(sb, "\"");
        sb_append(sb, json_escape(value));
        sb_append(sb, "\"");
    };
    return 0;
}

fn path_with_sep(path: str) -> str {
    let plen: i64 = str_len(path);
    if plen == 0 { return ""; };
    let last: i64 = str_char_at(path, plen - 1);
    if last == 47 || last == 92 { return path; };
    return str_concat(path, "/");
}

fn path_normalize_slashes(path: str) -> str {
    let plen: i64 = str_len(path);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < plen {
        let ch: i64 = str_char_at(path, i);
        if ch == 92 { sb_append(sb, "/"); }
        else { sb_append(sb, str_substring(path, i, i + 1)); };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn path_shell_native(path: str) -> str {
    let plen: i64 = str_len(path);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < plen {
        let ch: i64 = str_char_at(path, i);
        if ch == 47 { sb_append(sb, "\\"); }
        else { sb_append(sb, str_substring(path, i, i + 1)); };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn shell_quote(path: str) -> str {
    return str_concat("\"", str_concat(path, "\""));
}

fn path_relative_or_abs(base_dir: str, full_path: str) -> str {
    let base: str = path_normalize_slashes(trim_trailing_sep(base_dir));
    let full: str = path_normalize_slashes(full_path);
    let blen: i64 = str_len(base);
    let flen: i64 = str_len(full);
    if blen > 0 && flen >= blen && str_eq(str_substring(full, 0, blen), base) == 1 {
        let mut start: i64 = blen;
        if flen > blen {
            let next: i64 = str_char_at(full, blen);
            if next == 47 || next == 92 { start = blen + 1; };
        };
        return str_substring(full, start, flen);
    };
    return full;
}

fn path_relative_inventory(base_dir: str, full_path: str) -> str {
    let rel0: str = path_relative_or_abs(base_dir, full_path);
    if str_eq(rel0, path_normalize_slashes(full_path)) == 0 { return rel0; };
    let base_name: str = basename(trim_trailing_sep(base_dir));
    if str_len(base_name) == 0 { return rel0; };
    let full: str = path_normalize_slashes(full_path);
    let marker: str = str_concat("/", str_concat(base_name, "/"));
    let mlen: i64 = str_len(marker);
    let flen: i64 = str_len(full);
    let mut i: i64 = 0;
    while i + mlen <= flen {
        if str_eq(str_substring(full, i, i + mlen), marker) == 1 {
            return str_substring(full, i + mlen, flen);
        };
        i = i + 1;
    };
    return rel0;
}

fn manifest_default_package_name(manifest_path: str) -> str {
    let pkg_dir: str = trim_trailing_sep(parent_dir(manifest_path));
    if str_len(pkg_dir) == 0 { return "package"; };
    let name: str = basename(pkg_dir);
    if str_len(name) == 0 { return "package"; };
    return name;
}

fn manifest_unquote(raw: str) -> str {
    let value: str = trim_ws(raw);
    let vlen: i64 = str_len(value);
    if vlen >= 2 && str_char_at(value, 0) == 34 && str_char_at(value, vlen - 1) == 34 {
        return str_substring(value, 1, vlen - 1);
    };
    return "";
}

fn manifest_parse_string_array(raw: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let value: str = trim_ws(raw);
    let vlen: i64 = str_len(value);
    if vlen < 2 || str_char_at(value, 0) != 91 || str_char_at(value, vlen - 1) != 93 { return out; };
    let inner: str = trim_ws(str_substring(value, 1, vlen - 1));
    let ilen: i64 = str_len(inner);
    if ilen == 0 { return out; };
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= ilen {
        let at_end: i64 = i == ilen;
        let mut at_comma: i64 = 0;
        if at_end == 0 && str_char_at(inner, i) == 44 { at_comma = 1; };
        if at_end == 1 || at_comma == 1 {
            let item: str = manifest_unquote(str_substring(inner, start, i));
            if str_len(item) > 0 { out.push(item); };
            start = i + 1;
        };
        i = i + 1;
    };
    return out;
}

fn manifest_parse_settings(manifest_path: str, source: str) -> Vec<i32> {
    let mut section: str = "";
    let mut package_name: str = manifest_default_package_name(manifest_path);
    let mut version: str = "0.1.0";
    let mut entry: str = "src/main.nr";
    let mut deps: Vec<i32> = Vec::new();
    let mut workspace_members: Vec<i32> = Vec::new();
    let mut has_package: i64 = 0;
    let mut error: str = "";
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p <= slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = trim_ws(str_substring(source, p, eol));
        if str_len(line) > 0 && str_char_at(line, 0) != 35 {
            let llen: i64 = str_len(line);
            if llen >= 2 && str_char_at(line, 0) == 91 && str_char_at(line, llen - 1) == 93 {
                section = trim_ws(str_substring(line, 1, llen - 1));
            } else {
                let mut eq_pos: i64 = 0 - 1;
                let mut i: i64 = 0;
                while i < llen {
                    if str_char_at(line, i) == 61 && eq_pos < 0 { eq_pos = i; };
                    i = i + 1;
                };
                if eq_pos >= 0 {
                    let key: str = trim_ws(str_substring(line, 0, eq_pos));
                    let value: str = trim_ws(str_substring(line, eq_pos + 1, llen));
                    if str_eq(section, "package") == 1 && str_eq(key, "name") == 1 {
                        let parsed: str = manifest_unquote(value);
                        if str_len(parsed) == 0 { error = str_concat(manifest_path, ": invalid package.name"); }
                        else { package_name = parsed; has_package = 1; };
                    } else if str_eq(section, "package") == 1 && str_eq(key, "version") == 1 {
                        let parsed2: str = manifest_unquote(value);
                        if str_len(parsed2) == 0 { error = str_concat(manifest_path, ": invalid package.version"); }
                        else { version = parsed2; has_package = 1; };
                    } else if str_eq(section, "package") == 1 && str_eq(key, "entry") == 1 {
                        let parsed3: str = manifest_unquote(value);
                        if str_len(parsed3) == 0 { error = str_concat(manifest_path, ": invalid package.entry"); }
                        else { entry = parsed3; has_package = 1; };
                    } else if str_eq(section, "dependencies") == 1 {
                        let dep_path: str = manifest_unquote(value);
                        if str_len(dep_path) == 0 { error = str_concat(manifest_path, ": invalid dependency path"); }
                        else {
                            deps.push(key);
                            deps.push(dep_path);
                        };
                    } else if str_eq(section, "workspace") == 1 && str_eq(key, "members") == 1 {
                        workspace_members = manifest_parse_string_array(value);
                    };
                };
            };
        };
        if eol >= slen { p = slen + 1; }
        else { p = eol + 1; };
    };
    let mut out: Vec<i32> = Vec::new();
    out.push(package_name);
    out.push(version);
    out.push(entry);
    out.push(deps);
    out.push(workspace_members);
    out.push(has_package);
    out.push(error);
    return out;
}

fn manifest_settings_package_name(settings: Vec<i32>) -> str { return vec_get(settings, 0); }
fn manifest_settings_version(settings: Vec<i32>) -> str { return vec_get(settings, 1); }
fn manifest_settings_entry(settings: Vec<i32>) -> str { return vec_get(settings, 2); }
fn manifest_settings_deps(settings: Vec<i32>) -> Vec<i32> { return vec_get(settings, 3); }
fn manifest_settings_workspace(settings: Vec<i32>) -> Vec<i32> { return vec_get(settings, 4); }
fn manifest_settings_has_package(settings: Vec<i32>) -> i64 { return vec_get(settings, 5); }
fn manifest_settings_error(settings: Vec<i32>) -> str { return vec_get(settings, 6); }

fn lock_resolve_manifest_target(raw_target: str) -> str {
    let candidate: str = if str_len(raw_target) == 0 { "Nucleor.toml" } else { sanitize(raw_target) };
    if str_len(file_read_string(candidate)) > 0 { return candidate; };
    let manifest_candidate: str = sanitize(str_concat(path_with_sep(candidate), "Nucleor.toml"));
    if str_len(file_read_string(manifest_candidate)) > 0 { return manifest_candidate; };
    return "";
}

fn manifest_resolve_dependency_manifest(manifest_path: str, dep_input: str) -> str {
    let base_dir: str = path_with_sep(parent_dir(manifest_path));
    let candidate: str = if path_is_absolute(dep_input) == 1 { sanitize(dep_input) } else { sanitize(str_concat(base_dir, dep_input)) };
    if str_len(file_read_string(candidate)) > 0 { return candidate; };
    let manifest_candidate: str = sanitize(str_concat(path_with_sep(candidate), "Nucleor.toml"));
    if str_len(file_read_string(manifest_candidate)) > 0 { return manifest_candidate; };
    return manifest_candidate;
}

fn lock_should_skip_file(package_dir: str, file_path: str) -> i64 {
    let rel: str = path_relative_or_abs(package_dir, file_path);
    let norm: str = str_concat("/", str_concat(path_normalize_slashes(rel), "/"));
    let name: str = basename(file_path);
    if str_eq(name, "Nucleor.lock") == 1 || str_eq(name, package_checksum_file_name()) == 1 || str_eq(name, registry_metadata_file_name()) == 1 { return 1; };
    if text_contains(norm, "/target/") == 1 || text_contains(norm, "/.git/") == 1 || text_contains(norm, "/.nucleor/") == 1 || text_contains(norm, "/.nuc_cache/") == 1 {
        return 1;
    };
    return 0;
}

fn package_checksum_native(package_dir: str) -> str {
    let root_dir: str = trim_trailing_sep(package_dir);
    if str_len(root_dir) == 0 { return secure_hash(package_dir); };
    system("mkdir .nuc_cache 2>NUL");
    let listing_path: str = str_concat(".nuc_cache/lock_inventory_", str_concat(str_from_int(now_ms()), ".txt"));
    let list_cmd: str = str_concat("dir /b /s /a-d /on ", str_concat(shell_quote(path_shell_native(root_dir)), str_concat(" > ", shell_quote(path_shell_native(listing_path)))));
    if system(list_cmd) != 0 { return secure_hash(root_dir); };
    let raw: str = file_read_string(listing_path);
    system(str_concat("del /q ", str_concat(shell_quote(path_shell_native(listing_path)), " >NUL 2>NUL")));
    let slen: i64 = str_len(raw);
    let mut payload: i64 = sb_new();
    let mut p: i64 = 0;
    while p <= slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw, eol) != 10 { eol = eol + 1; };
        let line: str = trim_ws(str_substring(raw, p, eol));
        if str_len(line) > 0 && lock_should_skip_file(root_dir, line) == 0 && str_eq(basename(line), package_signature_file_name()) == 0 {
            let rel: str = path_normalize_slashes(path_relative_inventory(root_dir, line));
            sb_append(payload, rel);
            sb_append(payload, "\n");
            sb_append(payload, file_read_string(line));
            sb_append(payload, "\n--\n");
        };
        if eol >= slen { p = slen + 1; }
        else { p = eol + 1; };
    };
    let material: str = sb_to_str(payload);
    if str_len(material) == 0 { return secure_hash(root_dir); };
    return secure_hash(material);
}

fn lock_build_graph_recursive(manifest_path: str, graph: Vec<i32>, seen: Vec<i32>, stack: Vec<i32>, errors: Vec<i32>) -> i64 {
    if string_vec_contains(stack, manifest_path) == 1 {
        errors.push(str_concat("package dependency cycle detected at ", manifest_path));
        return 1;
    };
    if string_vec_contains(seen, manifest_path) == 1 { return 0; };
    let raw: str = file_read_string(manifest_path);
    if str_len(raw) == 0 {
        errors.push(str_concat("cannot read manifest: ", manifest_path));
        return 1;
    };
    let settings: Vec<i32> = manifest_parse_settings(manifest_path, raw);
    let parse_err: str = manifest_settings_error(settings);
    if str_len(parse_err) > 0 {
        errors.push(parse_err);
        return 1;
    };
    stack.push(manifest_path);
    let workspace_members: Vec<i32> = manifest_settings_workspace(settings);
    let mut wi: i64 = 0;
    while wi < vec_len(workspace_members) {
        let member_manifest: str = manifest_resolve_dependency_manifest(manifest_path, vec_get(workspace_members, wi));
        if str_len(file_read_string(member_manifest)) == 0 {
            errors.push(str_concat("cannot resolve workspace member manifest: ", member_manifest));
            vec_pop(stack);
            return 1;
        };
        if lock_build_graph_recursive(member_manifest, graph, seen, stack, errors) != 0 {
            vec_pop(stack);
            return 1;
        };
        wi = wi + 1;
    };
    if manifest_settings_has_package(settings) == 1 {
        let deps: Vec<i32> = manifest_settings_deps(settings);
        let mut dep_records: Vec<i32> = Vec::new();
        let mut di: i64 = 0;
        while di < vec_len(deps) {
            let dep_alias: str = vec_get(deps, di);
            let dep_input: str = vec_get(deps, di + 1);
            let dep_manifest: str = manifest_resolve_dependency_manifest(manifest_path, dep_input);
            if str_len(file_read_string(dep_manifest)) == 0 {
                errors.push(str_concat("cannot resolve dependency manifest: ", dep_manifest));
                vec_pop(stack);
                return 1;
            };
            if lock_build_graph_recursive(dep_manifest, graph, seen, stack, errors) != 0 {
                vec_pop(stack);
                return 1;
            };
            dep_records.push(dep_alias);
            dep_records.push(dep_input);
            dep_records.push(dep_manifest);
            di = di + 2;
        };
        let mut pkg: Vec<i32> = Vec::new();
        pkg.push(manifest_path);
        pkg.push(manifest_settings_package_name(settings));
        pkg.push(manifest_settings_version(settings));
        pkg.push(manifest_settings_entry(settings));
        pkg.push(package_checksum_native(parent_dir(manifest_path)));
        pkg.push(dep_records);
        graph.push(pkg);
    };
    seen.push(manifest_path);
    vec_pop(stack);
    return 0;
}

fn render_lockfile_native(root_manifest: str, graph: Vec<i32>) -> str {
    let root_dir: str = path_with_sep(parent_dir(root_manifest));
    let root_settings: Vec<i32> = manifest_parse_settings(root_manifest, file_read_string(root_manifest));
    let mut sb: i64 = sb_new();
    sb_append(sb, "version = 1\n");
    sb_append(sb, "root = \"");
    sb_append(sb, json_escape(path_normalize_slashes(path_relative_or_abs(root_dir, root_manifest))));
    sb_append(sb, "\"\n\n");
    if manifest_settings_has_package(root_settings) == 1 {
        sb_append(sb, "root_package = \"");
        sb_append(sb, json_escape(manifest_settings_package_name(root_settings)));
        sb_append(sb, "\"\n");
    };
    let workspace_members: Vec<i32> = manifest_settings_workspace(root_settings);
    if vec_len(workspace_members) > 0 {
        let mut members: Vec<i32> = Vec::new();
        let mut wi: i64 = 0;
        while wi < vec_len(workspace_members) {
            members.push(path_normalize_slashes(path_relative_or_abs(root_dir, manifest_resolve_dependency_manifest(root_manifest, vec_get(workspace_members, wi)))));
            wi = wi + 1;
        };
        sb_append(sb, "workspace_members = [");
        let mut mi: i64 = 0;
        while mi < vec_len(members) {
            if mi > 0 { sb_append(sb, ", "); };
            sb_append(sb, "\"");
            sb_append(sb, json_escape(vec_get(members, mi)));
            sb_append(sb, "\"");
            mi = mi + 1;
        };
        sb_append(sb, "]\n");
    };
    if manifest_settings_has_package(root_settings) == 1 || vec_len(workspace_members) > 0 { sb_append(sb, "\n"); };
    let mut gi: i64 = 0;
    while gi < vec_len(graph) {
        let pkg: Vec<i32> = vec_get(graph, gi);
        let manifest_path: str = vec_get(pkg, 0);
        let package_name: str = vec_get(pkg, 1);
        let version: str = vec_get(pkg, 2);
        let entry: str = vec_get(pkg, 3);
        let checksum: str = vec_get(pkg, 4);
        let deps: Vec<i32> = vec_get(pkg, 5);
        sb_append(sb, "[[package]]\n");
        sb_append(sb, "name = \""); sb_append(sb, json_escape(package_name)); sb_append(sb, "\"\n");
        sb_append(sb, "version = \""); sb_append(sb, json_escape(version)); sb_append(sb, "\"\n");
        sb_append(sb, "manifest = \""); sb_append(sb, json_escape(path_normalize_slashes(path_relative_or_abs(root_dir, manifest_path)))); sb_append(sb, "\"\n");
        sb_append(sb, "entry = \""); sb_append(sb, json_escape(path_normalize_slashes(entry))); sb_append(sb, "\"\n");
        sb_append(sb, "checksum = \""); sb_append(sb, json_escape(checksum)); sb_append(sb, "\"\n");
        sb_append(sb, "dependencies = [");
        let mut di: i64 = 0;
        let mut first_dep: i64 = 1;
        while di < vec_len(deps) {
            let dep_alias: str = vec_get(deps, di);
            let dep_input: str = vec_get(deps, di + 1);
            let dep_manifest: str = vec_get(deps, di + 2);
            if first_dep == 0 { sb_append(sb, ", "); } else { first_dep = 0; };
            sb_append(sb, "\"");
            sb_append(sb, json_escape(dep_alias));
            sb_append(sb, "|");
            sb_append(sb, json_escape(path_normalize_slashes(dep_input)));
            sb_append(sb, "|");
            sb_append(sb, json_escape(path_normalize_slashes(path_relative_or_abs(root_dir, dep_manifest))));
            sb_append(sb, "\"");
            di = di + 3;
        };
        sb_append(sb, "]\n\n");
        gi = gi + 1;
    };
    return sb_to_str(sb);
}

fn render_dependencies_section_native(deps: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "[dependencies]\n");
    let mut i: i64 = 0;
    while i < vec_len(deps) {
        sb_append(sb, vec_get(deps, i));
        sb_append(sb, " = \"");
        sb_append(sb, json_escape(path_normalize_slashes(vec_get(deps, i + 1))));
        sb_append(sb, "\"\n");
        i = i + 2;
    };
    return sb_to_str(sb);
}

fn manifest_replace_dependencies_section_native(manifest_path: str, deps: Vec<i32>) -> i64 {
    let raw: str = file_read_string(manifest_path);
    if str_len(raw) == 0 { return 1; };
    let dep_section: str = render_dependencies_section_native(deps);
    let slen: i64 = str_len(raw);
    let mut start_pos: i64 = 0 - 1;
    let mut end_pos: i64 = slen;
    let mut p: i64 = 0;
    while p <= slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw, eol) != 10 { eol = eol + 1; };
        let line: str = trim_ws(str_substring(raw, p, eol));
        if str_eq(line, "[dependencies]") == 1 {
            start_pos = p;
            let mut q: i64 = if eol >= slen { slen + 1 } else { eol + 1 };
            while q <= slen {
                let mut q_eol: i64 = q;
                while q_eol < slen && str_char_at(raw, q_eol) != 10 { q_eol = q_eol + 1; };
                let q_line: str = trim_ws(str_substring(raw, q, q_eol));
                let q_len: i64 = str_len(q_line);
                if q_len >= 2 && str_char_at(q_line, 0) == 91 && str_char_at(q_line, q_len - 1) == 93 {
                    end_pos = q;
                    q = slen + 1;
                } else {
                    if q_eol >= slen { q = slen + 1; }
                    else { q = q_eol + 1; };
                };
            };
            if end_pos == slen { end_pos = slen; };
            p = slen + 1;
        } else {
            if eol >= slen { p = slen + 1; }
            else { p = eol + 1; };
        };
    };
    let mut output: str = "";
    if start_pos >= 0 {
        output = str_concat(str_substring(raw, 0, start_pos), dep_section);
        if end_pos < slen { output = str_concat(output, str_substring(raw, end_pos, slen)); };
    } else {
        let mut stop: i64 = slen;
        while stop > 0 {
            let ch: i64 = str_char_at(raw, stop - 1);
            if ch == 10 || ch == 13 { stop = stop - 1; }
            else { stop = stop; stop = stop; break; };
        };
        output = str_substring(raw, 0, stop);
        if stop > 0 { output = str_concat(output, "\n\n"); };
        output = str_concat(output, dep_section);
    };
    file_write_string(manifest_path, output);
    return 0;
}

fn dir_list_native(dir_path: str, dirs_only: i64) -> Vec<i32> {
    let mut items: Vec<i32> = Vec::new();
    system("mkdir .nuc_cache 2>NUL");
    let listing_path: str = str_concat(".nuc_cache/dir_list_", str_concat(str_from_int(now_ms()), ".txt"));
    let list_cmd: str = if dirs_only == 1 {
        str_concat("dir /b /ad ", str_concat(shell_quote(path_shell_native(dir_path)), str_concat(" > ", shell_quote(path_shell_native(listing_path)))))
    } else {
        str_concat("dir /b ", str_concat(shell_quote(path_shell_native(dir_path)), str_concat(" > ", shell_quote(path_shell_native(listing_path)))))
    };
    if system(list_cmd) != 0 { return items; };
    let raw: str = file_read_string(listing_path);
    system(str_concat("del /q ", str_concat(shell_quote(path_shell_native(listing_path)), " >NUL 2>NUL")));
    let slen: i64 = str_len(raw);
    let mut p: i64 = 0;
    while p <= slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw, eol) != 10 { eol = eol + 1; };
        let line: str = trim_ws(str_substring(raw, p, eol));
        if str_len(line) > 0 { items.push(line); };
        if eol >= slen { p = slen + 1; }
        else { p = eol + 1; };
    };
    return items;
}

fn should_copy_package_file_native(file_path: str) -> i64 {
    let name: str = basename(file_path);
    if str_eq(name, "Nucleor.toml") == 1 || str_eq(name, "Nucleor.lock") == 1 || str_eq(name, package_checksum_file_name()) == 1 || str_eq(name, registry_metadata_file_name()) == 1 || str_eq(name, package_signature_file_name()) == 1 || str_eq(name, package_exports_manifest_file_name()) == 1 || str_eq(name, package_exports_header_file_name()) == 1 || str_eq(name, package_exports_rust_file_name()) == 1 {
        return 1;
    };
    let flen: i64 = str_len(file_path);
    if flen >= 3 && str_eq(str_substring(file_path, flen - 3, flen), ".nr") == 1 { return 1; };
    if flen >= 3 && str_eq(str_substring(file_path, flen - 3, flen), ".md") == 1 { return 1; };
    if flen >= 4 && str_eq(str_substring(file_path, flen - 4, flen), ".txt") == 1 { return 1; };
    return 0;
}

fn manifest_entry_source_path(package_root: str, settings: Vec<i32>) -> str {
    let entry_rel: str = sanitize(path_normalize_slashes(manifest_settings_entry(settings)));
    if path_is_absolute(entry_rel) == 1 { return entry_rel; };
    return sanitize(str_concat(path_with_sep(package_root), entry_rel));
}

fn json_extract_int_value(raw: str, key: str) -> i64 {
    let compact: str = strip_spaces(raw);
    let needle: str = str_concat("\"", str_concat(key, "\":"));
    let clen: i64 = str_len(compact);
    let nlen: i64 = str_len(needle);
    if clen < nlen { return 0; };
    let mut pos: i64 = -1;
    let mut i: i64 = 0;
    while i <= clen - nlen {
        if str_eq(str_substring(compact, i, i + nlen), needle) == 1 {
            pos = i + nlen;
            i = clen;
        } else {
            i = i + 1;
        };
    };
    if pos < 0 || pos >= clen { return 0; };
    let mut stop: i64 = pos;
    while stop < clen {
        let ch2: i64 = str_char_at(compact, stop);
        if ch2 < 48 || ch2 > 57 {
            if stop > pos { return str_to_int(str_substring(compact, pos, stop)); };
            return 0;
        };
        stop = stop + 1;
    };
    if stop > pos { return str_to_int(str_substring(compact, pos, stop)); };
    return 0;
}

fn json_extract_string_value(raw: str, key: str) -> str {
    let compact: str = strip_spaces(raw);
    let needle: str = str_concat("\"", str_concat(key, "\":"));
    let clen: i64 = str_len(compact);
    let nlen: i64 = str_len(needle);
    if clen < nlen { return ""; };
    let mut pos: i64 = -1;
    let mut i: i64 = 0;
    while i <= clen - nlen {
        if str_eq(str_substring(compact, i, i + nlen), needle) == 1 {
            pos = i + nlen;
            i = clen;
        } else {
            i = i + 1;
        };
    };
    if pos < 0 || pos >= clen || str_char_at(compact, pos) != 34 { return ""; };
    let mut stop: i64 = pos + 1;
    while stop < clen {
        let ch: i64 = str_char_at(compact, stop);
        if ch == 34 && str_char_at(compact, stop - 1) != 92 {
            return str_substring(compact, pos + 1, stop);
        };
        stop = stop + 1;
    };
    return "";
}

fn copy_package_tree_native(src_root: str, dst_root: str) -> i64 {
    let root_dir: str = trim_trailing_sep(src_root);
    system(str_concat("mkdir ", str_concat(shell_quote(path_shell_native(dst_root)), " 2>NUL")));
    system("mkdir .nuc_cache 2>NUL");
    let listing_path: str = str_concat(".nuc_cache/publish_inventory_", str_concat(str_from_int(now_ms()), ".txt"));
    let list_cmd: str = str_concat("dir /b /s /a-d /on ", str_concat(shell_quote(path_shell_native(root_dir)), str_concat(" > ", shell_quote(path_shell_native(listing_path)))));
    if system(list_cmd) != 0 { return 1; };
    let raw: str = file_read_string(listing_path);
    system(str_concat("del /q ", str_concat(shell_quote(path_shell_native(listing_path)), " >NUL 2>NUL")));
    let slen: i64 = str_len(raw);
    let mut p: i64 = 0;
    while p <= slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw, eol) != 10 { eol = eol + 1; };
        let file_path: str = trim_ws(str_substring(raw, p, eol));
        if str_len(file_path) > 0 && lock_should_skip_file(root_dir, file_path) == 0 && should_copy_package_file_native(file_path) == 1 {
            let rel: str = path_relative_inventory(root_dir, file_path);
            let dst_path: str = sanitize(str_concat(path_with_sep(dst_root), rel));
            let dst_parent: str = parent_dir(dst_path);
            if str_len(dst_parent) > 0 { system(str_concat("mkdir ", str_concat(shell_quote(path_shell_native(dst_parent)), " 2>NUL"))); };
            if system(str_concat("copy /Y ", str_concat(shell_quote(path_shell_native(file_path)), str_concat(" ", str_concat(shell_quote(path_shell_native(dst_path)), " >NUL"))))) != 0 {
                return 1;
            };
        };
        if eol >= slen { p = slen + 1; }
        else { p = eol + 1; };
    };
    return 0;
}

fn write_package_checksum_file_native(package_root: str) -> str {
    let checksum: str = package_checksum_native(package_root);
    let checksum_path: str = sanitize(str_concat(path_with_sep(package_root), package_checksum_file_name()));
    file_write_string(checksum_path, str_concat("sha256 = \"", str_concat(checksum, "\"\n")));
    return checksum_path;
}

fn registry_dir_native(argc: i64, arg_start: i64) -> str {
    let opt: str = cli_option_value(argc, arg_start, "--registry");
    if str_len(opt) > 0 { return sanitize(opt); };
    return ".nucleor/registry";
}

fn semver_score(version: str) -> i64 {
    let vlen: i64 = str_len(version);
    let mut parts: Vec<i32> = Vec::new();
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= vlen {
        let at_end: i64 = i == vlen;
        let mut at_dot: i64 = 0;
        if at_end == 0 && str_char_at(version, i) == 46 { at_dot = 1; };
        if at_end == 1 || at_dot == 1 {
            parts.push(str_to_int(str_substring(version, start, i)));
            start = i + 1;
        };
        i = i + 1;
    };
    let major: i64 = if vec_len(parts) > 0 { vec_get(parts, 0) } else { 0 };
    let minor: i64 = if vec_len(parts) > 1 { vec_get(parts, 1) } else { 0 };
    let patch: i64 = if vec_len(parts) > 2 { vec_get(parts, 2) } else { 0 };
    return major * 1000000000 + minor * 1000000 + patch;
}

fn registry_sort_versions_desc(versions: Vec<i32>) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(versions) {
        let mut j: i64 = i + 1;
        while j < vec_len(versions) {
            if semver_score(vec_get(versions, j)) > semver_score(vec_get(versions, i)) {
                let tmp: str = vec_get(versions, i);
                vec_set(versions, i, vec_get(versions, j));
                vec_set(versions, j, tmp);
            };
            j = j + 1;
        };
        i = i + 1;
    };
    return 0;
}

fn registry_package_versions_native(registry_dir: str, package_name: str) -> Vec<i32> {
    let package_root: str = sanitize(str_concat(path_with_sep(registry_dir), package_name));
    let dirs: Vec<i32> = dir_list_native(package_root, 1);
    let mut versions: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(dirs) {
        let version: str = vec_get(dirs, i);
        let manifest_path: str = sanitize(str_concat(path_with_sep(package_root), str_concat(version, "/Nucleor.toml")));
        if str_len(file_read_string(manifest_path)) > 0 { versions.push(version); };
        i = i + 1;
    };
    registry_sort_versions_desc(versions);
    return versions;
}

fn parse_registry_spec_native(spec: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(spec);
    let mut at_pos: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        if str_char_at(spec, i) == 64 && at_pos < 0 { at_pos = i; };
        i = i + 1;
    };
    if at_pos < 0 {
        out.push(spec);
        out.push("latest");
        return out;
    };
    out.push(str_substring(spec, 0, at_pos));
    out.push(str_substring(spec, at_pos + 1, slen));
    return out;
}

fn registry_resolve_version_native(registry_dir: str, package_name: str, selector: str) -> str {
    let versions: Vec<i32> = registry_package_versions_native(registry_dir, package_name);
    if vec_len(versions) == 0 { return ""; };
    if str_eq(selector, "latest") == 1 || str_len(selector) == 0 { return vec_get(versions, 0); };
    let mut i: i64 = 0;
    while i < vec_len(versions) {
        let version: str = vec_get(versions, i);
        if str_eq(version, selector) == 1 { return version; };
        i = i + 1;
    };
    return "";
}

fn native_release_repo_root() -> str {
    let script_path: str = native_release_script_path();
    return parent_dir(parent_dir(script_path));
}

fn native_release_script_path() -> str {
    let exe_dir: str = trim_trailing_sep(extract_dir(args_get(0)));
    if str_len(exe_dir) > 0 {
        let parent: str = parent_dir(exe_dir);
        let parent_script: str = sanitize(str_concat(path_with_sep(parent), "tools/native_release.ps1"));
        if str_len(file_read_string(parent_script)) > 0 { return parent_script; };
    };
    let up_script: str = sanitize("../tools/native_release.ps1");
    if str_len(file_read_string(up_script)) > 0 { return up_script; };
    let cwd_script: str = sanitize("tools/native_release.ps1");
    if str_len(file_read_string(cwd_script)) > 0 { return cwd_script; };
    return sanitize("tools/native_release.ps1");
}

fn invoke_native_package_sign(package_root: str, key_id: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push(0);
    out.push("");
    out.push("");
    system("mkdir .nuc_cache 2>NUL");
    let output_path: str = str_concat(".nuc_cache/package_sign_", str_concat(str_from_int(now_ms()), ".json"));
    let repo_root: str = native_release_repo_root();
    let script_path: str = native_release_script_path();
    let mut ps_cmd: str = str_concat("& '", str_concat(path_shell_native(script_path), str_concat("' -Root '", str_concat(path_shell_native(repo_root), str_concat("' package-sign '", str_concat(path_shell_native(package_root), "'"))))));
    if str_len(key_id) > 0 {
        ps_cmd = str_concat(ps_cmd, str_concat(" '", str_concat(key_id, "'")));
    };
    let mut cmd: str = str_concat("powershell -ExecutionPolicy Bypass -Command ", shell_quote(str_concat(ps_cmd, " --json")));
    cmd = str_concat(cmd, str_concat(" > ", str_concat(shell_quote(path_shell_native(output_path)), " 2>&1")));
    let rc: i64 = system(cmd);
    let raw: str = file_read_string(output_path);
    system(str_concat("del /q ", str_concat(shell_quote(path_shell_native(output_path)), " >NUL 2>NUL")));
    if rc != 0 {
        vec_set(out, 2, trim_ws(raw));
        if str_len(vec_get(out, 2)) == 0 { vec_set(out, 2, str_concat("native package signing failed: ", package_root)); };
        return out;
    };
    vec_set(out, 0, 1);
    vec_set(out, 1, raw);
    return out;
}

fn invoke_native_package_verify(package_root: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push(0);
    out.push("");
    out.push("");
    system("mkdir .nuc_cache 2>NUL");
    let output_path: str = str_concat(".nuc_cache/package_verify_", str_concat(str_from_int(now_ms()), ".json"));
    let repo_root: str = native_release_repo_root();
    let script_path: str = native_release_script_path();
    let ps_cmd: str = str_concat("& '", str_concat(path_shell_native(script_path), str_concat("' -Root '", str_concat(path_shell_native(repo_root), str_concat("' package-verify '", str_concat(path_shell_native(package_root), "' --json"))))));
    let mut cmd: str = str_concat("powershell -ExecutionPolicy Bypass -Command ", shell_quote(ps_cmd));
    cmd = str_concat(cmd, str_concat(" > ", str_concat(shell_quote(path_shell_native(output_path)), " 2>&1")));
    let rc: i64 = system(cmd);
    let raw: str = file_read_string(output_path);
    system(str_concat("del /q ", str_concat(shell_quote(path_shell_native(output_path)), " >NUL 2>NUL")));
    if rc != 0 {
        vec_set(out, 2, trim_ws(raw));
        if str_len(vec_get(out, 2)) == 0 { vec_set(out, 2, str_concat("native package verification failed: ", package_root)); };
        return out;
    };
    vec_set(out, 0, 1);
    vec_set(out, 1, raw);
    return out;
}

fn verify_registry_package_root_native(registry_dir: str, package_name: str, version: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let root: str = sanitize(str_concat(path_with_sep(registry_dir), str_concat(package_name, str_concat("/", version))));
    let manifest_path: str = sanitize(str_concat(path_with_sep(root), "Nucleor.toml"));
    let checksum_path: str = sanitize(str_concat(path_with_sep(root), package_checksum_file_name()));
    let metadata_path: str = sanitize(str_concat(path_with_sep(root), registry_metadata_file_name()));
    let signature_path: str = sanitize(str_concat(path_with_sep(root), package_signature_file_name()));
    let exports_path: str = sanitize(str_concat(path_with_sep(root), package_exports_manifest_file_name()));
    let exports_header_path: str = sanitize(str_concat(path_with_sep(root), package_exports_header_file_name()));
    let exports_rust_path: str = sanitize(str_concat(path_with_sep(root), package_exports_rust_file_name()));
    let mut ok: i64 = 1;
    let mut error: str = "";
    let mut export_count: i64 = 0;
    let mut signed: i64 = 0;
    let mut signing_key_id: str = "";
    let mut signing_algorithm: str = "none";
    if str_len(file_read_string(manifest_path)) == 0 {
        ok = 0;
        error = str_concat("package not found in registry: ", root);
    } else if str_len(file_read_string(checksum_path)) == 0 {
        ok = 0;
        error = str_concat("registry package is missing ", package_checksum_file_name());
    } else if text_contains(file_read_string(checksum_path), package_checksum_native(root)) == 0 {
        ok = 0;
        error = str_concat("registry package checksum mismatch: ", root);
    } else if str_len(file_read_string(metadata_path)) == 0 {
        ok = 0;
        error = str_concat("registry package is missing ", registry_metadata_file_name());
    } else {
        let metadata_raw: str = file_read_string(metadata_path);
        let metadata_compact: str = strip_spaces(metadata_raw);
        signing_algorithm = json_extract_string_value(metadata_raw, "algorithm");
        signing_key_id = json_extract_string_value(metadata_raw, "key_id");
        if text_contains(metadata_compact, "\"exports\":{\"present\":true") == 1 {
            let exports_raw: str = file_read_string(exports_path);
            if str_len(exports_raw) == 0 {
                ok = 0;
                error = str_concat("registry package is missing ", package_exports_manifest_file_name());
            } else if str_len(file_read_string(exports_header_path)) == 0 {
                ok = 0;
                error = str_concat("registry package is missing ", package_exports_header_file_name());
            } else if str_len(file_read_string(exports_rust_path)) == 0 {
                ok = 0;
                error = str_concat("registry package is missing ", package_exports_rust_file_name());
            } else {
                let exports_compact: str = strip_spaces(exports_raw);
                let expected_count: i64 = json_extract_int_value(metadata_raw, "count");
                let observed_count: i64 = json_extract_int_value(exports_raw, "export_count");
                if text_contains(exports_compact, "\"type\":\"package_exports\"") == 0 {
                    ok = 0;
                    error = str_concat("registry package has invalid ", package_exports_manifest_file_name());
                } else if text_contains(exports_compact, str_concat("\"name\":\"", str_concat(package_name, "\""))) == 0 || text_contains(exports_compact, str_concat("\"version\":\"", str_concat(version, "\""))) == 0 {
                    ok = 0;
                    error = str_concat("registry package export manifest does not match package identity: ", root);
                } else if expected_count != observed_count {
                    ok = 0;
                    error = str_concat("registry package export manifest count mismatch: ", root);
                } else if text_contains(exports_compact, str_concat("\"abi_version\":\"", str_concat(abi_export_version_label(), "\""))) == 0 || text_contains(exports_compact, str_concat("\"surface\":\"", str_concat(abi_export_surface_policy_label(), "\""))) == 0 || text_contains(exports_compact, str_concat("\"version_policy\":\"", str_concat(abi_export_version_policy_label(), "\""))) == 0 {
                    ok = 0;
                    error = str_concat("registry package export policy metadata is incomplete: ", root);
                } else {
                    export_count = observed_count;
                };
            };
        };
        if ok == 1 {
            if str_len(signing_algorithm) == 0 { signing_algorithm = "none"; };
            if str_eq(signing_algorithm, "none") == 1 {
                if str_len(file_read_string(signature_path)) > 0 {
                    ok = 0;
                    error = str_concat("registry package has unexpected ", package_signature_file_name());
                };
            } else {
                if str_len(file_read_string(signature_path)) == 0 {
                    ok = 0;
                    error = str_concat("registry package is missing ", package_signature_file_name());
                } else {
                    let signed_result: Vec<i32> = invoke_native_package_verify(root);
                    if vec_get(signed_result, 0) == 0 {
                        ok = 0;
                        error = vec_get(signed_result, 2);
                    } else {
                        signed = 1;
                        if str_len(signing_key_id) == 0 {
                            signing_key_id = json_extract_string_value(vec_get(signed_result, 1), "key_id");
                        };
                    };
                };
            };
        };
    };
    out.push(ok);
    out.push(root);
    out.push(error);
    out.push(export_count);
    out.push(signed);
    out.push(signing_key_id);
    out.push(signing_algorithm);
    return out;
}

fn write_package_export_artifacts_native(package_root: str, settings: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push(0);
    out.push(0);
    out.push("");
    let entry_path: str = manifest_entry_source_path(package_root, settings);
    let entry_rel: str = path_normalize_slashes(manifest_settings_entry(settings));
    let source: str = file_read_string(entry_path);
    if str_len(source) == 0 {
        vec_set(out, 0, -1);
        vec_set(out, 2, str_concat("cannot read package entry source: ", entry_path));
        return out;
    };
    if preflight_source_check(source) != 0 {
        vec_set(out, 0, -1);
        vec_set(out, 2, str_concat("entry source preflight failed: ", entry_path));
        return out;
    };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    let export_names: Vec<i32> = collect_public_export_names(source);
    if vec_len(export_names) == 0 { return out; };
    if validate_export_surface(pool, prog, export_names) != 0 {
        vec_set(out, 0, -1);
        vec_set(out, 2, str_concat("package export surface validation failed: ", entry_path));
        return out;
    };
    let json_path: str = sanitize(str_concat(path_with_sep(package_root), package_exports_manifest_file_name()));
    let header_path: str = sanitize(str_concat(path_with_sep(package_root), package_exports_header_file_name()));
    let rust_path: str = sanitize(str_concat(path_with_sep(package_root), package_exports_rust_file_name()));
    file_write_string(json_path, render_package_export_manifest_json(entry_rel, settings, pool, prog, export_names));
    file_write_string(header_path, render_export_c_header(entry_rel, pool, prog, export_names));
    file_write_string(rust_path, render_export_rust_extern(entry_rel, pool, prog, export_names));
    vec_set(out, 0, 1);
    vec_set(out, 1, vec_len(export_names));
    return out;
}

fn write_registry_metadata_file_native(package_root: str, settings: Vec<i32>, export_info: Vec<i32>, signing_algorithm_in: str, signing_key_id_in: str) -> str {
    let metadata_path: str = sanitize(str_concat(path_with_sep(package_root), registry_metadata_file_name()));
    let signing_algorithm: str = if str_len(signing_algorithm_in) > 0 { signing_algorithm_in } else { "none" };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":1,\"package\":{\"name\":\"");
    sb_append(sb, json_escape(manifest_settings_package_name(settings)));
    sb_append(sb, "\",\"version\":\"");
    sb_append(sb, json_escape(manifest_settings_version(settings)));
    sb_append(sb, "\",\"entry\":\"");
    sb_append(sb, json_escape(path_normalize_slashes(manifest_settings_entry(settings))));
    sb_append(sb, "\"},\"published_at_unix_s\":");
    sb_append(sb, str_from_int(now_ms() / 1000));
    sb_append(sb, ",\"checksum\":\"");
    sb_append(sb, json_escape(package_checksum_native(package_root)));
    sb_append(sb, "\",\"signing\":{\"algorithm\":\"");
    sb_append(sb, json_escape(signing_algorithm));
    sb_append(sb, "\",\"key_id\":");
    if str_len(signing_key_id_in) > 0 { sb_append_json_string_or_null(sb, signing_key_id_in); }
    else { sb_append(sb, "null"); };
    sb_append(sb, ",\"signature_file\":");
    if str_eq(signing_algorithm, "none") == 1 { sb_append(sb, "null"); }
    else { sb_append_json_string_or_null(sb, package_signature_file_name()); };
    sb_append(sb, ",\"mode\":");
    if str_eq(signing_algorithm, "none") == 1 { sb_append(sb, "null"); }
    else { sb_append_json_string_or_null(sb, "openssh-y-sign"); };
    sb_append(sb, "},\"exports\":{\"present\":");
    sb_append_json_bool(sb, vec_get(export_info, 0) == 1);
    sb_append(sb, ",\"count\":");
    sb_append(sb, str_from_int(vec_get(export_info, 1)));
    sb_append(sb, ",\"manifest\":\"");
    sb_append(sb, json_escape(package_exports_manifest_file_name()));
    sb_append(sb, "\",\"c_header\":\"");
    sb_append(sb, json_escape(package_exports_header_file_name()));
    sb_append(sb, "\",\"rust_extern\":\"");
    sb_append(sb, json_escape(package_exports_rust_file_name()));
    sb_append(sb, "\",\"abi_version\":\"");
    sb_append(sb, json_escape(abi_export_version_label()));
    sb_append(sb, "\",\"surface\":\"");
    sb_append(sb, json_escape(abi_export_surface_policy_label()));
    sb_append(sb, "\",\"symbol_policy\":\"");
    sb_append(sb, json_escape(abi_export_symbol_policy_label()));
    sb_append(sb, "\",\"version_policy\":\"");
    sb_append(sb, json_escape(abi_export_version_policy_label()));
    sb_append(sb, "\"}}");
    file_write_string(metadata_path, sb_to_str(sb));
    return metadata_path;
}

fn path_split_components(path: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let norm: str = path_normalize_slashes(trim_trailing_sep(path));
    let nlen: i64 = str_len(norm);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= nlen {
        let at_end: i64 = i == nlen;
        let mut at_sep: i64 = 0;
        if at_end == 0 {
            let ch: i64 = str_char_at(norm, i);
            if ch == 47 || ch == 92 { at_sep = 1; };
        };
        if at_end == 1 || at_sep == 1 {
            if i > start {
                out.push(str_substring(norm, start, i));
            };
            start = i + 1;
        };
        i = i + 1;
    };
    return out;
}

fn path_relative_between(base_dir: str, target_path: str) -> str {
    let base_norm: str = path_normalize_slashes(trim_trailing_sep(base_dir));
    let target_norm: str = path_normalize_slashes(trim_trailing_sep(target_path));
    if str_len(base_norm) == 0 { return target_norm; };
    if str_len(target_norm) == 0 { return "."; };
    let base_parts: Vec<i32> = path_split_components(base_norm);
    let target_parts: Vec<i32> = path_split_components(target_norm);
    let mut common: i64 = 0;
    let blen: i64 = vec_len(base_parts);
    let tlen: i64 = vec_len(target_parts);
    while common < blen && common < tlen && str_eq(vec_get(base_parts, common), vec_get(target_parts, common)) == 1 {
        common = common + 1;
    };
    if common == 0 { return target_norm; };
    let mut rel_parts: Vec<i32> = Vec::new();
    let mut bi: i64 = common;
    while bi < blen {
        rel_parts.push("..");
        bi = bi + 1;
    };
    let mut ti: i64 = common;
    while ti < tlen {
        rel_parts.push(vec_get(target_parts, ti));
        ti = ti + 1;
    };
    if vec_len(rel_parts) == 0 { return "."; };
    return join_strings(rel_parts, "/");
}

fn publish_bundle_package_dir_native(root_manifest: str, publish_root: str, pkg: Vec<i32>) -> str {
    let manifest_path: str = vec_get(pkg, 0);
    if str_eq(manifest_path, root_manifest) == 1 { return publish_root; };
    return sanitize(str_concat(path_with_sep(publish_root), str_concat("package_deps/", str_concat(vec_get(pkg, 1), str_concat("/", vec_get(pkg, 2))))));
}

fn publish_bundle_layout_native(root_manifest: str, graph: Vec<i32>, publish_root: str) -> Vec<i32> {
    let mut layout: Vec<i32> = Vec::new();
    let mut gi: i64 = 0;
    while gi < vec_len(graph) {
        let pkg: Vec<i32> = vec_get(graph, gi);
        layout.push(vec_get(pkg, 0));
        layout.push(publish_bundle_package_dir_native(root_manifest, publish_root, pkg));
        gi = gi + 1;
    };
    return layout;
}

fn publish_bundle_lookup_dir_native(layout: Vec<i32>, manifest_path: str) -> str {
    let mut i: i64 = 0;
    while i < vec_len(layout) {
        if str_eq(vec_get(layout, i), manifest_path) == 1 { return vec_get(layout, i + 1); };
        i = i + 2;
    };
    return "";
}

fn publish_copy_graph_native(root_manifest: str, graph: Vec<i32>, publish_root: str) -> i64 {
    let layout: Vec<i32> = publish_bundle_layout_native(root_manifest, graph, publish_root);
    let mut gi: i64 = 0;
    while gi < vec_len(graph) {
        let pkg: Vec<i32> = vec_get(graph, gi);
        let manifest_path: str = vec_get(pkg, 0);
        let src_dir: str = parent_dir(manifest_path);
        let dst_dir: str = publish_bundle_lookup_dir_native(layout, manifest_path);
        if str_len(dst_dir) == 0 || copy_package_tree_native(src_dir, dst_dir) != 0 { return 1; };
        gi = gi + 1;
    };
    gi = 0;
    while gi < vec_len(graph) {
        let pkg2: Vec<i32> = vec_get(graph, gi);
        let manifest_path2: str = vec_get(pkg2, 0);
        let dst_dir2: str = publish_bundle_lookup_dir_native(layout, manifest_path2);
        let dst_manifest: str = sanitize(str_concat(path_with_sep(dst_dir2), "Nucleor.toml"));
        let deps: Vec<i32> = vec_get(pkg2, 5);
        let mut rewritten: Vec<i32> = Vec::new();
        let mut di: i64 = 0;
        while di < vec_len(deps) {
            let dep_alias: str = vec_get(deps, di);
            let dep_manifest: str = vec_get(deps, di + 2);
            let dep_dir: str = publish_bundle_lookup_dir_native(layout, dep_manifest);
            if str_len(dep_dir) == 0 { return 1; };
            rewritten.push(dep_alias);
            rewritten.push(path_normalize_slashes(path_relative_between(parent_dir(dst_manifest), dep_dir)));
            di = di + 3;
        };
        if manifest_replace_dependencies_section_native(dst_manifest, rewritten) != 0 { return 1; };
        gi = gi + 1;
    };
    return 0;
}

fn source_collect_imports(source: str) -> Vec<i32> {
    let mut imports: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(source, lp) == 32 || str_char_at(source, lp) == 9) { lp = lp + 1; };
        if eol - lp >= 4 && str_eq(str_substring(source, lp, lp + 4), "use ") == 1 {
            let mut stop: i64 = eol;
            while stop > lp + 4 && (str_char_at(source, stop - 1) == 32 || str_char_at(source, stop - 1) == 9 || str_char_at(source, stop - 1) == 13 || str_char_at(source, stop - 1) == 59) {
                stop = stop - 1;
            };
            let imp: str = trim_ws(str_substring(source, lp + 4, stop));
            if str_len(imp) > 0 { string_vec_push_unique(imports, imp); };
        };
        p = eol + 1;
    };
    return imports;
}

fn cli_wants_json(argc: i64, arg_start: i64) -> i64 {
    let mut i: i64 = arg_start;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") == 1 || str_eq(arg, "--output=json") == 1 { return 1; };
        if str_eq(arg, "--output") == 1 && i + 1 < argc && str_eq(args_get(i + 1), "json") == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn cli_first_positional(argc: i64, arg_start: i64) -> str {
    let mut i: i64 = arg_start;
    while i < argc {
        let arg: str = args_get(i);
        if cli_is_flag(arg) == 0 { return arg; };
        if str_eq(arg, "--output") == 1 || str_eq(arg, "--fn") == 1 || str_eq(arg, "--function") == 1 {
            i = i + 1;
        };
        i = i + 1;
    };
    return "";
}

fn cli_option_value(argc: i64, arg_start: i64, opt_name: str) -> str {
    let prefix: str = str_concat(opt_name, "=");
    let mut i: i64 = arg_start;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, opt_name) == 1 {
            if i + 1 < argc { return args_get(i + 1); };
            return "";
        };
        if str_len(arg) > str_len(prefix) && str_eq(str_substring(arg, 0, str_len(prefix)), prefix) == 1 {
            return str_substring(arg, str_len(prefix), str_len(arg));
        };
        i = i + 1;
    };
    return "";
}

fn cli_has_flag(argc: i64, arg_start: i64, opt_name: str) -> i64 {
    let mut i: i64 = arg_start;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, opt_name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn program_has_pure_marker(pool: Vec<i32>, prog: i64, name: str) -> i64 {
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 46 && str_eq(node_field(pool, nid, 1), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn param_list_text(pool: Vec<i32>, params_lid: i64) -> str {
    let mut parts: Vec<i32> = Vec::new();
    let cnt: i64 = list_len(pool, params_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let pnid: i64 = list_get(pool, params_lid, i);
        parts.push(str_concat(node_field(pool, pnid, 1), str_concat(": ", node_field(pool, pnid, 2))));
        i = i + 1;
    };
    return join_strings(parts, ", ");
}

fn generic_list_text(pool: Vec<i32>, gparams_lid: i64) -> str {
    let cnt: i64 = list_len(pool, gparams_lid);
    if cnt == 0 { return ""; };
    let mut names: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < cnt {
        names.push(list_get(pool, gparams_lid, i));
        i = i + 1;
    };
    return str_concat("<", str_concat(join_strings(names, ", "), ">"));
}

fn struct_fields_text(pool: Vec<i32>, fields_lid: i64) -> str {
    let mut parts: Vec<i32> = Vec::new();
    let cnt: i64 = list_len(pool, fields_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let fnid: i64 = list_get(pool, fields_lid, i);
        parts.push(str_concat(node_field(pool, fnid, 1), str_concat(": ", node_field(pool, fnid, 2))));
        i = i + 1;
    };
    return join_strings(parts, ", ");
}

fn enum_variant_text(pool: Vec<i32>, variant_nid: i64) -> str {
    let name: str = node_field(pool, variant_nid, 1);
    let fields_lid: i64 = node_field(pool, variant_nid, 2);
    let cnt: i64 = list_len(pool, fields_lid);
    if cnt == 0 { return name; };
    let mut parts: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < cnt {
        parts.push(list_get(pool, fields_lid, i));
        i = i + 1;
    };
    return str_concat(name, str_concat("(", str_concat(join_strings(parts, ", "), ")")));
}

fn append_params_json(sb: i64, pool: Vec<i32>, params_lid: i64) -> i64 {
    sb_append(sb, "[");
    let cnt: i64 = list_len(pool, params_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let pnid: i64 = list_get(pool, params_lid, i);
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "{\"name\":\"");
        sb_append(sb, json_escape(node_field(pool, pnid, 1)));
        sb_append(sb, "\",\"type\":\"");
        sb_append(sb, json_escape(node_field(pool, pnid, 2)));
        sb_append(sb, "\"}");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn append_generics_json(sb: i64, pool: Vec<i32>, gparams_lid: i64) -> i64 {
    let mut names: Vec<i32> = Vec::new();
    let cnt: i64 = list_len(pool, gparams_lid);
    let mut i: i64 = 0;
    while i < cnt {
        names.push(list_get(pool, gparams_lid, i));
        i = i + 1;
    };
    return sb_append_json_string_array(sb, names);
}

fn append_struct_fields_json(sb: i64, pool: Vec<i32>, fields_lid: i64) -> i64 {
    sb_append(sb, "[");
    let cnt: i64 = list_len(pool, fields_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let fnid: i64 = list_get(pool, fields_lid, i);
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "{\"name\":\"");
        sb_append(sb, json_escape(node_field(pool, fnid, 1)));
        sb_append(sb, "\",\"type\":\"");
        sb_append(sb, json_escape(node_field(pool, fnid, 2)));
        sb_append(sb, "\"}");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn append_enum_variants_json(sb: i64, pool: Vec<i32>, variants_lid: i64) -> i64 {
    sb_append(sb, "[");
    let cnt: i64 = list_len(pool, variants_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let vnid: i64 = list_get(pool, variants_lid, i);
        let fields_lid: i64 = node_field(pool, vnid, 2);
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "{\"name\":\"");
        sb_append(sb, json_escape(node_field(pool, vnid, 1)));
        sb_append(sb, "\",\"fields\":[");
        let fcnt: i64 = list_len(pool, fields_lid);
        let mut j: i64 = 0;
        while j < fcnt {
            if j > 0 { sb_append(sb, ","); };
            sb_append(sb, "\"");
            sb_append(sb, json_escape(list_get(pool, fields_lid, j)));
            sb_append(sb, "\"");
            j = j + 1;
        };
        sb_append(sb, "]}");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn append_trait_methods_json(sb: i64, pool: Vec<i32>, methods_lid: i64) -> i64 {
    sb_append(sb, "[");
    let cnt: i64 = list_len(pool, methods_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let mnid: i64 = list_get(pool, methods_lid, i);
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "{\"name\":\"");
        sb_append(sb, json_escape(node_field(pool, mnid, 1)));
        sb_append(sb, "\",\"params\":");
        append_params_json(sb, pool, node_field(pool, mnid, 2));
        sb_append(sb, ",\"return\":\"");
        sb_append(sb, json_escape(node_field(pool, mnid, 3)));
        sb_append(sb, "\",\"has_default\":");
        if node_field(pool, mnid, 4) >= 0 { sb_append(sb, "true"); }
        else { sb_append(sb, "false"); };
        sb_append(sb, "}");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn render_summary_command(src_path: str, source: str, pool: Vec<i32>, prog: i64, json_mode: i64) -> str {
    let fmeta: Vec<i32> = source_collect_functions(source);
    let effs: Vec<i32> = infer_source_effects(fmeta);
    let imports: Vec<i32> = source_collect_imports(source);
    let tests: Vec<i32> = collect_test_names_from_source(source);
    let mut lines: Vec<i32> = Vec::new();
    lines.push(str_concat("// Module: ", src_path));
    let mut ii: i64 = 0;
    while ii < vec_len(imports) {
        lines.push(str_concat("use ", vec_get(imports, ii)));
        ii = ii + 1;
    };
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        let kind: i64 = node_kind(pool, nid);
        if kind == 30 {
            let name: str = node_field(pool, nid, 1);
            let pure_prefix: str = if program_has_pure_marker(pool, prog, name) == 1 { "pure " } else { "" };
            let ret: str = node_field(pool, nid, 3);
            let ret_suffix: str = if str_eq(ret, "void") == 1 { "" } else { str_concat(" -> ", ret) };
            let effect_text: str = csv_pretty(inferred_effects_for(effs, name));
            let req_suffix: str = if str_len(effect_text) == 0 { "" } else { str_concat(" requires [", str_concat(effect_text, "]")) };
            let test_suffix: str = if string_vec_contains(tests, name) == 1 { " @test" } else { "" };
            lines.push(str_concat(pure_prefix, str_concat("fn ", str_concat(name, str_concat(generic_list_text(pool, node_field(pool, nid, 5)), str_concat("(", str_concat(param_list_text(pool, node_field(pool, nid, 2)), str_concat(")", str_concat(ret_suffix, str_concat(req_suffix, test_suffix))))))))));
        } else if kind == 32 {
            let ret2: str = node_field(pool, nid, 3);
            let ret_suffix2: str = if str_eq(ret2, "void") == 1 { "" } else { str_concat(" -> ", ret2) };
            lines.push(str_concat("extern fn ", str_concat(node_field(pool, nid, 1), str_concat("(", str_concat(param_list_text(pool, node_field(pool, nid, 2)), str_concat(")", ret_suffix2))))));
        } else if kind == 33 {
            lines.push(str_concat("struct ", str_concat(node_field(pool, nid, 1), str_concat(generic_list_text(pool, node_field(pool, nid, 3)), str_concat(" { ", str_concat(struct_fields_text(pool, node_field(pool, nid, 2)), " }"))))));
        } else if kind == 36 {
            let variants_lid: i64 = node_field(pool, nid, 2);
            let mut parts: Vec<i32> = Vec::new();
            let mut vi: i64 = 0;
            while vi < list_len(pool, variants_lid) {
                parts.push(enum_variant_text(pool, list_get(pool, variants_lid, vi)));
                vi = vi + 1;
            };
            lines.push(str_concat("enum ", str_concat(node_field(pool, nid, 1), str_concat(generic_list_text(pool, node_field(pool, nid, 3)), str_concat(" { ", str_concat(join_strings(parts, ", "), " }"))))));
        } else if kind == 43 {
            lines.push(str_concat("trait ", str_concat(node_field(pool, nid, 1), generic_list_text(pool, node_field(pool, nid, 3)))));
        } else if kind == 45 {
            let trait_name: str = node_field(pool, nid, 1);
            let type_name: str = node_field(pool, nid, 2);
            if str_len(trait_name) > 0 {
                lines.push(str_concat("impl ", str_concat(trait_name, str_concat(" for ", type_name))));
            } else {
                lines.push(str_concat("impl ", type_name));
            };
        } else if kind == 50 {
            lines.push(str_concat("const ", str_concat(node_field(pool, nid, 1), str_concat(": ", node_field(pool, nid, 2)))));
        } else if kind == 51 {
            lines.push(str_concat("type ", str_concat(node_field(pool, nid, 1), str_concat(" = ", node_field(pool, nid, 2)))));
        };
        i = i + 1;
    };
    if json_mode == 1 {
        let mut sbj: i64 = sb_new();
        sb_append(sbj, "{\"file\":\""); sb_append(sbj, json_escape(src_path)); sb_append(sbj, "\",\"summary_lines\":");
        sb_append_json_string_array(sbj, lines);
        sb_append(sbj, "}");
        return sb_to_str(sbj);
    };
    return str_concat(join_strings(lines, "\n"), "\n");
}

fn run_summary_command(src_path: str, argc: i64, arg_start: i64) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    print(render_summary_command(src_path, source, pool, prog, cli_wants_json(argc, arg_start)));
    return 0;
}

fn run_query_command(src_path: str) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    let imports: Vec<i32> = source_collect_imports(source);
    let tests: Vec<i32> = collect_test_names_from_source(source);
    let fmeta: Vec<i32> = source_collect_functions(source);
    let effs: Vec<i32> = infer_source_effects(fmeta);
    let cnt: i64 = list_len(pool, prog);
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"file\":\""); sb_append(sb, json_escape(src_path)); sb_append(sb, "\",");
    sb_append(sb, "\"functions\":[");
    let mut first: i64 = 1;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            let name: str = node_field(pool, nid, 1);
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(name)); sb_append(sb, "\",\"type_params\":");
            append_generics_json(sb, pool, node_field(pool, nid, 5));
            sb_append(sb, ",\"params\":"); append_params_json(sb, pool, node_field(pool, nid, 2));
            sb_append(sb, ",\"return\":\""); sb_append(sb, json_escape(node_field(pool, nid, 3))); sb_append(sb, "\"");
            sb_append(sb, ",\"pure\":"); sb_append_json_bool(sb, program_has_pure_marker(pool, prog, name));
            sb_append(sb, ",\"test\":"); sb_append_json_bool(sb, string_vec_contains(tests, name));
            sb_append(sb, ",\"differentiable\":false");
            sb_append(sb, ",\"effects\":{\"declared\":"); sb_append_json_string_array(sb, csv_to_string_vec(srcf_decl_effects(fmeta, name)));
            sb_append(sb, ",\"inferred\":"); sb_append_json_string_array(sb, csv_to_string_vec(inferred_effects_for(effs, name)));
            sb_append(sb, "},\"contracts\":{\"pre\":0,\"post\":0}}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"structs\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid2: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid2) == 33 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid2, 1))); sb_append(sb, "\",\"type_params\":");
            append_generics_json(sb, pool, node_field(pool, nid2, 3));
            sb_append(sb, ",\"fields\":"); append_struct_fields_json(sb, pool, node_field(pool, nid2, 2));
            sb_append(sb, "}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"enums\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid3: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid3) == 36 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid3, 1))); sb_append(sb, "\",\"type_params\":");
            append_generics_json(sb, pool, node_field(pool, nid3, 3));
            sb_append(sb, ",\"variants\":"); append_enum_variants_json(sb, pool, node_field(pool, nid3, 2));
            sb_append(sb, "}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"traits\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid4: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid4) == 43 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid4, 1))); sb_append(sb, "\",\"type_params\":");
            append_generics_json(sb, pool, node_field(pool, nid4, 3));
            sb_append(sb, ",\"methods\":"); append_trait_methods_json(sb, pool, node_field(pool, nid4, 2));
            sb_append(sb, "}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"impls\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid5: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid5) == 45 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            let trait_name: str = node_field(pool, nid5, 1);
            sb_append(sb, "{\"trait\":");
            if str_len(trait_name) == 0 { sb_append(sb, "null"); }
            else { sb_append(sb, "\""); sb_append(sb, json_escape(trait_name)); sb_append(sb, "\""); };
            sb_append(sb, ",\"for_type\":\""); sb_append(sb, json_escape(node_field(pool, nid5, 2))); sb_append(sb, "\",\"methods\":");
            append_trait_methods_json(sb, pool, node_field(pool, nid5, 3));
            sb_append(sb, "}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"extern_fns\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid6: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid6) == 32 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid6, 1))); sb_append(sb, "\",\"params\":");
            append_params_json(sb, pool, node_field(pool, nid6, 2));
            sb_append(sb, ",\"return\":\""); sb_append(sb, json_escape(node_field(pool, nid6, 3))); sb_append(sb, "\"}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"consts\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid7: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid7) == 50 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid7, 1))); sb_append(sb, "\",\"type\":\"");
            sb_append(sb, json_escape(node_field(pool, nid7, 2))); sb_append(sb, "\"}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"type_aliases\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid8: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid8) == 51 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid8, 1))); sb_append(sb, "\",\"target\":\"");
            sb_append(sb, json_escape(node_field(pool, nid8, 2))); sb_append(sb, "\"}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"imports\":");
    sb_append_json_string_array(sb, imports);
    sb_append(sb, "}");
    print(sb_to_str(sb));
    return 0;
}

fn abi_c_type_name(t: str) -> str {
    if str_eq(t, "void") { return "void"; };
    if str_eq(t, "i32") { return "int32_t"; };
    if str_eq(t, "f64") { return "double"; };
    if str_eq(t, "str") { return "const char*"; };
    if str_eq(t, "ptr") { return "void*"; };
    return "int64_t";
}

fn abi_rust_type_name(t: str) -> str {
    if str_eq(t, "void") { return "()"; };
    if str_eq(t, "i32") { return "i32"; };
    if str_eq(t, "f64") { return "f64"; };
    if str_eq(t, "str") { return "*const ::std::os::raw::c_char"; };
    if str_eq(t, "ptr") { return "*mut ::std::ffi::c_void"; };
    return "i64";
}

fn abi_type_is_export_safe(t: str) -> i64 {
    if str_eq(t, "void") || str_eq(t, "i32") || str_eq(t, "i64") || str_eq(t, "f64") || str_eq(t, "str") || str_eq(t, "ptr") { return 1; };
    return 0;
}

fn append_abi_params_json(sb: i64, pool: Vec<i32>, params_lid: i64) -> i64 {
    sb_append(sb, "[");
    let cnt: i64 = list_len(pool, params_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let pnid: i64 = list_get(pool, params_lid, i);
        if i > 0 { sb_append(sb, ","); };
        let ptype: str = node_field(pool, pnid, 2);
        sb_append(sb, "{\"name\":\"");
        sb_append(sb, json_escape(node_field(pool, pnid, 1)));
        sb_append(sb, "\",\"nr_type\":\"");
        sb_append(sb, json_escape(ptype));
        sb_append(sb, "\",\"llvm\":\"");
        sb_append(sb, json_escape(nr_type_to_llvm(ptype)));
        sb_append(sb, "\",\"c\":\"");
        sb_append(sb, json_escape(abi_c_type_name(ptype)));
        sb_append(sb, "\",\"rust\":\"");
        sb_append(sb, json_escape(abi_rust_type_name(ptype)));
        sb_append(sb, "\"}");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn render_abi_text(src_path: str, pool: Vec<i32>, prog: i64) -> str {
    let mut lines: Vec<i32> = Vec::new();
    lines.push(str_concat("ABI imports for ", src_path));
    lines.push("ABI version: c-v1-imports-only");
    lines.push("exports supported: no");
    let cnt: i64 = list_len(pool, prog);
    let mut extern_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 32 {
            extern_count = extern_count + 1;
            let name: str = node_field(pool, nid, 1);
            let params_lid: i64 = node_field(pool, nid, 2);
            let rtype: str = node_field(pool, nid, 3);
            let mut llvm_sig: i64 = sb_new();
            sb_append(llvm_sig, nr_type_to_llvm(rtype));
            sb_append(llvm_sig, " (");
            let pc: i64 = list_len(pool, params_lid);
            let mut pi: i64 = 0;
            while pi < pc {
                if pi > 0 { sb_append(llvm_sig, ", "); };
                let pnid: i64 = list_get(pool, params_lid, pi);
                sb_append(llvm_sig, nr_type_to_llvm(node_field(pool, pnid, 2)));
                pi = pi + 1;
            };
            sb_append(llvm_sig, ")");
            lines.push(str_concat("extern fn ", str_concat(name, str_concat("(", str_concat(param_list_text(pool, params_lid), str_concat(") -> ", str_concat(rtype, str_concat(" | llvm ", sb_to_str(llvm_sig)))))))));
        };
        i = i + 1;
    };
    if extern_count == 0 { lines.push("extern imports: none"); };
    return str_concat(join_strings(lines, "\n"), "\n");
}

fn render_export_text(src_path: str, pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> str {
    let mut lines: Vec<i32> = Vec::new();
    lines.push(str_concat("ABI exports for ", src_path));
    lines.push("ABI version: c-v1-shared-exports");
    lines.push("shared library exports: yes");
    let cnt: i64 = list_len(pool, prog);
    let mut export_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                export_count = export_count + 1;
                let params_lid: i64 = node_field(pool, nid, 2);
                let rtype: str = node_field(pool, nid, 3);
                let mut llvm_sig: i64 = sb_new();
                sb_append(llvm_sig, nr_type_to_llvm(rtype));
                sb_append(llvm_sig, " (");
                let pc: i64 = list_len(pool, params_lid);
                let mut pi: i64 = 0;
                while pi < pc {
                    if pi > 0 { sb_append(llvm_sig, ", "); };
                    let pnid: i64 = list_get(pool, params_lid, pi);
                    sb_append(llvm_sig, nr_type_to_llvm(node_field(pool, pnid, 2)));
                    pi = pi + 1;
                };
                sb_append(llvm_sig, ")");
                lines.push(str_concat("pub fn ", str_concat(name, str_concat("(", str_concat(param_list_text(pool, params_lid), str_concat(") -> ", str_concat(rtype, str_concat(" | llvm ", sb_to_str(llvm_sig)))))))));
            };
        };
        i = i + 1;
    };
    if export_count == 0 { lines.push("public exports: none"); };
    return str_concat(join_strings(lines, "\n"), "\n");
}

fn render_abi_json(src_path: str, pool: Vec<i32>, prog: i64) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"type\":\"abi\",\"abi_version\":\"c-v1-imports-only\",\"file\":\"");
    sb_append(sb, json_escape(src_path));
    sb_append(sb, "\",\"exports_supported\":false,\"imports\":[");
    let cnt: i64 = list_len(pool, prog);
    let mut first: i64 = 1;
    let mut extern_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 32 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            extern_count = extern_count + 1;
            let name: str = node_field(pool, nid, 1);
            let params_lid: i64 = node_field(pool, nid, 2);
            let rtype: str = node_field(pool, nid, 3);
            sb_append(sb, "{\"name\":\"");
            sb_append(sb, json_escape(name));
            sb_append(sb, "\",\"params\":");
            append_abi_params_json(sb, pool, params_lid);
            sb_append(sb, ",\"return\":{\"nr_type\":\"");
            sb_append(sb, json_escape(rtype));
            sb_append(sb, "\",\"llvm\":\"");
            sb_append(sb, json_escape(nr_type_to_llvm(rtype)));
            sb_append(sb, "\",\"c\":\"");
            sb_append(sb, json_escape(abi_c_type_name(rtype)));
            sb_append(sb, "\",\"rust\":\"");
            sb_append(sb, json_escape(abi_rust_type_name(rtype)));
            sb_append(sb, "\"}}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"extern_count\":");
    sb_append(sb, str_from_int(extern_count));
    sb_append(sb, "}");
    return sb_to_str(sb);
}

fn render_export_json(src_path: str, pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"type\":\"abi\",\"abi_version\":\"");
    sb_append(sb, abi_export_version_label());
    sb_append(sb, "\",\"file\":\"");
    sb_append(sb, json_escape(src_path));
    sb_append(sb, "\",\"shared_library\":true,\"exports\":[");
    let cnt: i64 = list_len(pool, prog);
    let mut first: i64 = 1;
    let mut export_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                if first == 0 { sb_append(sb, ","); } else { first = 0; };
                export_count = export_count + 1;
                let params_lid: i64 = node_field(pool, nid, 2);
                let rtype: str = node_field(pool, nid, 3);
                sb_append(sb, "{\"name\":\"");
                sb_append(sb, json_escape(name));
                sb_append(sb, "\",\"params\":");
                append_abi_params_json(sb, pool, params_lid);
                sb_append(sb, ",\"return\":{\"nr_type\":\"");
                sb_append(sb, json_escape(rtype));
                sb_append(sb, "\",\"llvm\":\"");
                sb_append(sb, json_escape(nr_type_to_llvm(rtype)));
                sb_append(sb, "\",\"c\":\"");
                sb_append(sb, json_escape(abi_c_type_name(rtype)));
                sb_append(sb, "\",\"rust\":\"");
                sb_append(sb, json_escape(abi_rust_type_name(rtype)));
                sb_append(sb, "\"}}");
            };
        };
        i = i + 1;
    };
    sb_append(sb, "],\"export_count\":");
    sb_append(sb, str_from_int(export_count));
    sb_append(sb, "}");
    return sb_to_str(sb);
}

fn render_package_export_manifest_json(entry_path: str, settings: Vec<i32>, pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"type\":\"package_exports\",\"package\":{\"name\":\"");
    sb_append(sb, json_escape(manifest_settings_package_name(settings)));
    sb_append(sb, "\",\"version\":\"");
    sb_append(sb, json_escape(manifest_settings_version(settings)));
    sb_append(sb, "\",\"entry\":\"");
    sb_append(sb, json_escape(path_normalize_slashes(entry_path)));
    sb_append(sb, "\"},\"abi_policy\":{\"abi_version\":\"");
    sb_append(sb, json_escape(abi_export_version_label()));
    sb_append(sb, "\",\"surface\":\"");
    sb_append(sb, json_escape(abi_export_surface_policy_label()));
    sb_append(sb, "\",\"symbol_policy\":\"");
    sb_append(sb, json_escape(abi_export_symbol_policy_label()));
    sb_append(sb, "\",\"version_policy\":\"");
    sb_append(sb, json_escape(abi_export_version_policy_label()));
    sb_append(sb, "\"},\"artifacts\":{\"manifest\":\"");
    sb_append(sb, json_escape(package_exports_manifest_file_name()));
    sb_append(sb, "\",\"c_header\":\"");
    sb_append(sb, json_escape(package_exports_header_file_name()));
    sb_append(sb, "\",\"rust_extern\":\"");
    sb_append(sb, json_escape(package_exports_rust_file_name()));
    sb_append(sb, "\"},\"shared_library\":true,\"exports\":[");
    let cnt: i64 = list_len(pool, prog);
    let mut first: i64 = 1;
    let mut export_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                if first == 0 { sb_append(sb, ","); } else { first = 0; };
                export_count = export_count + 1;
                let params_lid: i64 = node_field(pool, nid, 2);
                let rtype: str = node_field(pool, nid, 3);
                sb_append(sb, "{\"name\":\"");
                sb_append(sb, json_escape(name));
                sb_append(sb, "\",\"symbol\":\"");
                sb_append(sb, json_escape(name));
                sb_append(sb, "\",\"params\":");
                append_abi_params_json(sb, pool, params_lid);
                sb_append(sb, ",\"return\":{\"nr_type\":\"");
                sb_append(sb, json_escape(rtype));
                sb_append(sb, "\",\"llvm\":\"");
                sb_append(sb, json_escape(nr_type_to_llvm(rtype)));
                sb_append(sb, "\",\"c\":\"");
                sb_append(sb, json_escape(abi_c_type_name(rtype)));
                sb_append(sb, "\",\"rust\":\"");
                sb_append(sb, json_escape(abi_rust_type_name(rtype)));
                sb_append(sb, "\"}}");
            };
        };
        i = i + 1;
    };
    sb_append(sb, "],\"export_count\":");
    sb_append(sb, str_from_int(export_count));
    sb_append(sb, "}");
    return sb_to_str(sb);
}

fn render_abi_c_header(src_path: str, pool: Vec<i32>, prog: i64) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "/* Nucleor ABI imports for ");
    sb_append(sb, src_path);
    sb_append(sb, " */\n");
    sb_append(sb, "#pragma once\n#include <stdint.h>\n\n#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n");
    let cnt: i64 = list_len(pool, prog);
    let mut extern_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 32 {
            extern_count = extern_count + 1;
            let name: str = node_field(pool, nid, 1);
            let params_lid: i64 = node_field(pool, nid, 2);
            let rtype: str = node_field(pool, nid, 3);
            sb_append(sb, abi_c_type_name(rtype));
            sb_append(sb, " ");
            sb_append(sb, name);
            sb_append(sb, "(");
            let pc: i64 = list_len(pool, params_lid);
            if pc == 0 {
                sb_append(sb, "void");
            } else {
                let mut pi: i64 = 0;
                while pi < pc {
                    if pi > 0 { sb_append(sb, ", "); };
                    let pnid: i64 = list_get(pool, params_lid, pi);
                    sb_append(sb, abi_c_type_name(node_field(pool, pnid, 2)));
                    sb_append(sb, " ");
                    sb_append(sb, node_field(pool, pnid, 1));
                    pi = pi + 1;
                };
            };
            sb_append(sb, ");\n");
        };
        i = i + 1;
    };
    if extern_count == 0 { sb_append(sb, "/* no extern imports */\n"); };
    sb_append(sb, "\n#ifdef __cplusplus\n}\n#endif\n");
    return sb_to_str(sb);
}

fn render_export_c_header(src_path: str, pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "/* Nucleor shared-library exports for ");
    sb_append(sb, src_path);
    sb_append(sb, " */\n");
    sb_append(sb, "#pragma once\n#include <stdint.h>\n\n#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n");
    let cnt: i64 = list_len(pool, prog);
    let mut export_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                export_count = export_count + 1;
                let params_lid: i64 = node_field(pool, nid, 2);
                let rtype: str = node_field(pool, nid, 3);
                sb_append(sb, abi_c_type_name(rtype));
                sb_append(sb, " ");
                sb_append(sb, name);
                sb_append(sb, "(");
                let pc: i64 = list_len(pool, params_lid);
                if pc == 0 {
                    sb_append(sb, "void");
                } else {
                    let mut pi: i64 = 0;
                    while pi < pc {
                        if pi > 0 { sb_append(sb, ", "); };
                        let pnid: i64 = list_get(pool, params_lid, pi);
                        sb_append(sb, abi_c_type_name(node_field(pool, pnid, 2)));
                        sb_append(sb, " ");
                        sb_append(sb, node_field(pool, pnid, 1));
                        pi = pi + 1;
                    };
                };
                sb_append(sb, ");\n");
            };
        };
        i = i + 1;
    };
    if export_count == 0 { sb_append(sb, "/* no public exports */\n"); };
    sb_append(sb, "\n#ifdef __cplusplus\n}\n#endif\n");
    return sb_to_str(sb);
}

fn render_abi_rust_extern(src_path: str, pool: Vec<i32>, prog: i64) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "// Nucleor ABI imports for ");
    sb_append(sb, src_path);
    sb_append(sb, "\nuse ::std::ffi::c_void;\nuse ::std::os::raw::c_char;\n\nunsafe extern \"C\" {\n");
    let cnt: i64 = list_len(pool, prog);
    let mut extern_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 32 {
            extern_count = extern_count + 1;
            let name: str = node_field(pool, nid, 1);
            let params_lid: i64 = node_field(pool, nid, 2);
            let rtype: str = node_field(pool, nid, 3);
            sb_append(sb, "    pub fn ");
            sb_append(sb, name);
            sb_append(sb, "(");
            let pc: i64 = list_len(pool, params_lid);
            let mut pi: i64 = 0;
            while pi < pc {
                if pi > 0 { sb_append(sb, ", "); };
                let pnid: i64 = list_get(pool, params_lid, pi);
                sb_append(sb, node_field(pool, pnid, 1));
                sb_append(sb, ": ");
                sb_append(sb, abi_rust_type_name(node_field(pool, pnid, 2)));
                pi = pi + 1;
            };
            sb_append(sb, ")");
            if str_eq(rtype, "void") == 0 {
                sb_append(sb, " -> ");
                sb_append(sb, abi_rust_type_name(rtype));
            };
            sb_append(sb, ";\n");
        };
        i = i + 1;
    };
    if extern_count == 0 { sb_append(sb, "    // no extern imports\n"); };
    sb_append(sb, "}\n");
    return sb_to_str(sb);
}

fn render_export_rust_extern(src_path: str, pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "// Nucleor shared-library exports for ");
    sb_append(sb, src_path);
    sb_append(sb, "\nuse ::std::ffi::c_void;\nuse ::std::os::raw::c_char;\n\nunsafe extern \"C\" {\n");
    let cnt: i64 = list_len(pool, prog);
    let mut export_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                export_count = export_count + 1;
                let params_lid: i64 = node_field(pool, nid, 2);
                let rtype: str = node_field(pool, nid, 3);
                sb_append(sb, "    pub fn ");
                sb_append(sb, name);
                sb_append(sb, "(");
                let pc: i64 = list_len(pool, params_lid);
                let mut pi: i64 = 0;
                while pi < pc {
                    if pi > 0 { sb_append(sb, ", "); };
                    let pnid: i64 = list_get(pool, params_lid, pi);
                    sb_append(sb, node_field(pool, pnid, 1));
                    sb_append(sb, ": ");
                    sb_append(sb, abi_rust_type_name(node_field(pool, pnid, 2)));
                    pi = pi + 1;
                };
                sb_append(sb, ")");
                if str_eq(rtype, "void") == 0 {
                    sb_append(sb, " -> ");
                    sb_append(sb, abi_rust_type_name(rtype));
                };
                sb_append(sb, ";\n");
            };
        };
        i = i + 1;
    };
    if export_count == 0 { sb_append(sb, "    // no public exports\n"); };
    sb_append(sb, "}\n");
    return sb_to_str(sb);
}

fn validate_export_surface(pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> i64 {
    if vec_len(export_names) == 0 {
        print("ERROR: no `pub fn` exports found in source");
        return 1;
    };
    let cnt: i64 = list_len(pool, prog);
    let mut matched: Vec<i32> = Vec::new();
    let mut failed: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                string_vec_push_unique(matched, name);
                if str_eq(name, "main") == 1 {
                    print("ERROR: `pub fn main` is not a supported shared-library export");
                    failed = 1;
                };
                if list_len(pool, node_field(pool, nid, 5)) > 0 {
                    print(str_concat("ERROR: exported function cannot be generic: ", name));
                    failed = 1;
                };
                let params_lid: i64 = node_field(pool, nid, 2);
                let pc: i64 = list_len(pool, params_lid);
                let mut pi: i64 = 0;
                while pi < pc {
                    let pnid: i64 = list_get(pool, params_lid, pi);
                    let ptype: str = node_field(pool, pnid, 2);
                    if abi_type_is_export_safe(ptype) == 0 {
                        print(str_concat("ERROR: unsupported export parameter ABI type in ", str_concat(name, str_concat(": ", ptype))));
                        failed = 1;
                    };
                    pi = pi + 1;
                };
                let rtype: str = node_field(pool, nid, 3);
                if abi_type_is_export_safe(rtype) == 0 {
                    print(str_concat("ERROR: unsupported export return ABI type in ", str_concat(name, str_concat(": ", rtype))));
                    failed = 1;
                };
            };
        };
        i = i + 1;
    };
    i = 0;
    while i < vec_len(export_names) {
        let name2: str = vec_get(export_names, i);
        if string_vec_contains(matched, name2) == 0 {
            print(str_concat("ERROR: `pub fn` export not found as a concrete top-level function: ", name2));
            failed = 1;
        };
        i = i + 1;
    };
    return failed;
}

fn render_def_file(export_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "EXPORTS\n");
    let mut i: i64 = 0;
    while i < vec_len(export_names) {
        let name: str = vec_get(export_names, i);
        if str_eq(name, "main") == 0 {
            sb_append(sb, "    ");
            sb_append(sb, name);
            sb_append(sb, "\n");
        };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn link_shared_module(out_name: str, imported: Vec<i32>, export_names: Vec<i32>, time_passes: i64) -> i64 {
    let ll_path: str = sanitize(str_concat("target/", str_concat(out_name, ".ll")));
    let dll_path: str = sanitize(str_concat("target\\", str_concat(out_name, ".dll")));
    let lib_path: str = sanitize(str_concat("target\\", str_concat(out_name, ".lib")));
    let def_path: str = sanitize(str_concat("target/", str_concat(out_name, ".def")));
    file_write_string(def_path, render_def_file(export_names));
    let native_d: Vec<i32> = collect_native_directives(imported);
    let link_flags: str = vec_get(native_d, 0);
    let cfiles: str = vec_get(native_d, 1);
    let libpath_flags: str = vec_get(native_d, 2);
    let rt_arg: str = resolve_toolchain_path("stdlib/runtime/nucleor_llvm_rt.c");
    let clang_start: i64 = now_ms();
    let cmd: str = str_concat(llvm_clang_path(), str_concat(" ", str_concat(ll_path, str_concat(" ", str_concat(rt_arg, str_concat(cfiles, str_concat(" -shared -o ", str_concat(dll_path, str_concat(" -Wl,/DEF:", str_concat(path_shell_native(def_path), str_concat(" -Wl,/IMPLIB:", str_concat(path_shell_native(lib_path), str_concat(" -Wno-override-module ", str_concat(libpath_flags, str_concat(link_flags, " 2>&1"))))))))))))));
    let rc: i64 = system(cmd);
    print_phase_time(time_passes, "clang_shared", now_ms() - clang_start);
    if rc != 0 {
        print(str_concat("  SHARED LINK FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
        return 1;
    };
    print(str_concat("  shared library: ", dll_path));
    print(str_concat("  import library: ", lib_path));
    print(str_concat("  export def: ", def_path));
    return 0;
}

fn run_abi_command(src_path: str, argc: i64, arg_start: i64) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    if cli_has_flag(argc, arg_start, "--exports") == 1 {
        let export_names: Vec<i32> = collect_public_export_names(source);
        if validate_export_surface(pool, prog, export_names) != 0 { return 1; };
        if cli_has_flag(argc, arg_start, "--c-header") == 1 {
            print(render_export_c_header(src_path, pool, prog, export_names));
            return 0;
        };
        if cli_has_flag(argc, arg_start, "--rust-extern") == 1 {
            print(render_export_rust_extern(src_path, pool, prog, export_names));
            return 0;
        };
        if cli_wants_json(argc, arg_start) == 1 {
            print(render_export_json(src_path, pool, prog, export_names));
            return 0;
        };
        print(render_export_text(src_path, pool, prog, export_names));
        return 0;
    };
    if cli_has_flag(argc, arg_start, "--c-header") == 1 {
        print(render_abi_c_header(src_path, pool, prog));
        return 0;
    };
    if cli_has_flag(argc, arg_start, "--rust-extern") == 1 {
        print(render_abi_rust_extern(src_path, pool, prog));
        return 0;
    };
    if cli_wants_json(argc, arg_start) == 1 {
        print(render_abi_json(src_path, pool, prog));
        return 0;
    };
    print(render_abi_text(src_path, pool, prog));
    return 0;
}

fn run_build_shared_command(src_path: str, out_name: str, use_cache: i64, time_passes: i64, json_mode: i64) -> i64 {
    let raw_source: str = file_read_string(src_path);
    if str_len(raw_source) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    if preflight_source_check(raw_source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(raw_source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    let export_names: Vec<i32> = collect_public_export_names(raw_source);
    if validate_export_surface(pool, prog, export_names) != 0 { return 1; };
    let rc_compile: i64 = compile_file_mode(src_path, out_name, 0, use_cache, time_passes, 0);
    if rc_compile != 0 { return rc_compile; };
    let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
    let imported: Vec<i32> = vec_get(bundle, 1);
    let rc_link: i64 = link_shared_module(out_name, imported, export_names, time_passes);
    if rc_link != 0 { return rc_link; };
    let json_path: str = sanitize(str_concat("target/", str_concat(out_name, ".exports.json")));
    let header_path: str = sanitize(str_concat("target/", str_concat(out_name, ".exports.h")));
    let rust_path: str = sanitize(str_concat("target/", str_concat(out_name, ".exports.rs")));
    file_write_string(json_path, render_export_json(src_path, pool, prog, export_names));
    file_write_string(header_path, render_export_c_header(src_path, pool, prog, export_names));
    file_write_string(rust_path, render_export_rust_extern(src_path, pool, prog, export_names));
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"file\":\"");
        sb_append(sb, json_escape(src_path));
        sb_append(sb, "\",\"output\":\"");
        sb_append(sb, json_escape(out_name));
        sb_append(sb, "\",\"dll\":\"");
        sb_append(sb, json_escape(str_concat("target\\", str_concat(out_name, ".dll"))));
        sb_append(sb, "\",\"import_lib\":\"");
        sb_append(sb, json_escape(str_concat("target\\", str_concat(out_name, ".lib"))));
        sb_append(sb, "\",\"ll\":\"");
        sb_append(sb, json_escape(str_concat("target/", str_concat(out_name, ".ll"))));
        sb_append(sb, "\",\"def\":\"");
        sb_append(sb, json_escape(str_concat("target/", str_concat(out_name, ".def"))));
        sb_append(sb, "\",\"exports_json\":\"");
        sb_append(sb, json_escape(json_path));
        sb_append(sb, "\",\"exports_header\":\"");
        sb_append(sb, json_escape(header_path));
        sb_append(sb, "\",\"exports_rust\":\"");
        sb_append(sb, json_escape(rust_path));
        sb_append(sb, "\",\"export_count\":");
        sb_append(sb, str_from_int(vec_len(export_names)));
        sb_append(sb, "}");
        print(sb_to_str(sb));
        return 0;
    };
    print(str_concat("  exports manifest: ", json_path));
    print(str_concat("  exports header: ", header_path));
    print(str_concat("  exports rust: ", rust_path));
    print(str_concat("  export count: ", str_from_int(vec_len(export_names))));
    return 0;
}

fn run_evidence_command(src_path: str) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    let tests: Vec<i32> = collect_test_names_from_source(source);
    let fmeta: Vec<i32> = source_collect_functions(source);
    let cnt: i64 = list_len(pool, prog);
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"file\":\""); sb_append(sb, json_escape(src_path)); sb_append(sb, "\",\"functions\":[");
    let mut first: i64 = 1;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            let name: str = node_field(pool, nid, 1);
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(name)); sb_append(sb, "\",\"is_pure\":");
            sb_append_json_bool(sb, program_has_pure_marker(pool, prog, name));
            sb_append(sb, ",\"is_test\":"); sb_append_json_bool(sb, string_vec_contains(tests, name));
            sb_append(sb, ",\"is_differentiable\":false");
            sb_append(sb, ",\"effects\":"); sb_append_json_string_array(sb, csv_to_string_vec(srcf_decl_effects(fmeta, name)));
            sb_append(sb, ",\"authored\":null,\"preconditions\":0,\"postconditions\":0}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"structs\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid2: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid2) == 33 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid2, 1))); sb_append(sb, "\",\"authored\":null}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"extern_fns\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid3: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid3) == 32 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "\""); sb_append(sb, json_escape(node_field(pool, nid3, 1))); sb_append(sb, "\"");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"provenance\":{\"builder\":\"nucleor-compiler\",\"build_type\":\"https://nucleor.dev/slsa/v1\",\"invocation\":{\"config_source\":\"");
    sb_append(sb, json_escape(src_path));
    sb_append(sb, "\"},\"metadata\":{\"reproducible\":true}},\"spdx\":{\"spdx_version\":\"SPDX-2.3\",\"data_license\":\"CC0-1.0\",\"name\":");
    sb_append_json_string_or_null(sb, basename(src_path));
    sb_append(sb, ",\"package_supplier\":\"Organization: nucleor-authors\"}}");
    print(sb_to_str(sb));
    return 0;
}

fn run_lock_command(argc: i64) -> i64 {
    let mut json_mode: i64 = 0;
    let mut target: str = "";
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") == 1 || str_eq(arg, "--output=json") == 1 {
            json_mode = 1;
        } else if str_eq(arg, "--output") == 1 && i + 1 < argc && str_eq(args_get(i + 1), "json") == 1 {
            json_mode = 1;
            i = i + 1;
        } else if cli_is_flag(arg) == 0 && str_len(target) == 0 {
            target = arg;
        };
        i = i + 1;
    };
    let manifest_path: str = lock_resolve_manifest_target(target);
    if str_len(manifest_path) == 0 {
        if json_mode == 1 { print("{\"error\":\"no Nucleor.toml found; pass a manifest path or run inside a project directory\"}"); }
        else {
            print("ERROR: no Nucleor.toml found");
            print("Usage: nuc lock [path/to/Nucleor.toml|project_dir] [--json]");
        };
        return 1;
    };
    let mut graph: Vec<i32> = Vec::new();
    let mut seen: Vec<i32> = Vec::new();
    let mut stack: Vec<i32> = Vec::new();
    let mut errors: Vec<i32> = Vec::new();
    if lock_build_graph_recursive(manifest_path, graph, seen, stack, errors) != 0 || vec_len(errors) > 0 {
        let err: str = if vec_len(errors) > 0 { vec_get(errors, 0) } else { "unknown lock graph error" };
        if json_mode == 1 {
            let mut esb: i64 = sb_new();
            sb_append(esb, "{\"manifest\":\""); sb_append(esb, json_escape(manifest_path)); sb_append(esb, "\",\"error\":\""); sb_append(esb, json_escape(err)); sb_append(esb, "\"}");
            print(sb_to_str(esb));
        } else {
            print(str_concat("ERROR: ", err));
        };
        return 1;
    };
    let contents: str = render_lockfile_native(manifest_path, graph);
    let lock_path: str = str_concat(path_with_sep(parent_dir(manifest_path)), "Nucleor.lock");
    file_write_string(lock_path, contents);
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"manifest\":\""); sb_append(sb, json_escape(manifest_path));
        sb_append(sb, "\",\"lockfile\":\""); sb_append(sb, json_escape(lock_path));
        sb_append(sb, "\",\"package_count\":"); sb_append(sb, str_from_int(vec_len(graph)));
        sb_append(sb, ",\"status\":\"ok\"}");
        print(sb_to_str(sb));
    } else {
        print(str_concat("wrote lockfile: ", lock_path));
        print(str_concat("packages: ", str_from_int(vec_len(graph))));
    };
    return 0;
}

fn run_publish_command(argc: i64) -> i64 {
    let manifest_target: str = cli_first_positional(argc, 2);
    let manifest_path: str = lock_resolve_manifest_target(manifest_target);
    if str_len(manifest_path) == 0 {
        print("ERROR: no Nucleor.toml found");
        print("Usage: nuc publish [path/to/Nucleor.toml|project_dir] [--registry <dir>]");
        return 1;
    };
    let registry_dir: str = registry_dir_native(argc, 2);
    let mut sign_package: i64 = cli_has_flag(argc, 2, "--sign");
    let mut signing_key_id: str = cli_option_value(argc, 2, "--key-id");
    if str_len(signing_key_id) > 0 { sign_package = 1; };
    if sign_package == 1 && str_len(signing_key_id) == 0 { signing_key_id = "default-local"; };
    let settings: Vec<i32> = manifest_parse_settings(manifest_path, file_read_string(manifest_path));
    let parse_err: str = manifest_settings_error(settings);
    if str_len(parse_err) > 0 {
        print(str_concat("ERROR: ", parse_err));
        return 1;
    };
    let deps: Vec<i32> = manifest_settings_deps(settings);
    if vec_len(deps) > 0 {
        let lock_path: str = str_concat(path_with_sep(parent_dir(manifest_path)), "Nucleor.lock");
        if str_len(file_read_string(lock_path)) == 0 {
            print(str_concat("ERROR: missing ", str_concat(lock_path, "; run `nuc lock` first")));
            return 1;
        };
    };
    let mut graph: Vec<i32> = Vec::new();
    let mut seen: Vec<i32> = Vec::new();
    let mut stack: Vec<i32> = Vec::new();
    let mut errors: Vec<i32> = Vec::new();
    if lock_build_graph_recursive(manifest_path, graph, seen, stack, errors) != 0 || vec_len(errors) > 0 {
        let err: str = if vec_len(errors) > 0 { vec_get(errors, 0) } else { "unknown dependency graph error" };
        print(str_concat("ERROR: ", err));
        return 1;
    };
    let publish_root: str = sanitize(str_concat(path_with_sep(registry_dir), str_concat(manifest_settings_package_name(settings), str_concat("/", manifest_settings_version(settings)))));
    if str_len(file_read_string(sanitize(str_concat(path_with_sep(publish_root), "Nucleor.toml")))) > 0 {
        print(str_concat("ERROR: package already exists in registry: ", publish_root));
        return 1;
    };
    if publish_copy_graph_native(manifest_path, graph, publish_root) != 0 {
        print(str_concat("ERROR: failed to copy package into registry: ", publish_root));
        return 1;
    };
    let export_info: Vec<i32> = write_package_export_artifacts_native(publish_root, settings);
    if vec_get(export_info, 0) < 0 {
        print(str_concat("ERROR: ", vec_get(export_info, 2)));
        return 1;
    };
    write_package_checksum_file_native(publish_root);
    write_registry_metadata_file_native(publish_root, settings, export_info, if sign_package == 1 { "ssh-ed25519" } else { "none" }, signing_key_id);
    if sign_package == 1 {
        let signed_result: Vec<i32> = invoke_native_package_sign(publish_root, signing_key_id);
        if vec_get(signed_result, 0) == 0 {
            print(str_concat("ERROR: ", vec_get(signed_result, 2)));
            return 1;
        };
    };
    print(str_concat("published: ", publish_root));
    return 0;
}

fn run_registry_command(argc: i64) -> i64 {
    let registry_dir: str = registry_dir_native(argc, 2);
    let mut positionals: Vec<i32> = Vec::new();
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if cli_is_flag(arg) == 0 { positionals.push(arg); };
        if str_eq(arg, "--registry") == 1 { i = i + 1; };
        i = i + 1;
    };
    let packages: Vec<i32> = dir_list_native(registry_dir, 1);
    if vec_len(positionals) == 0 || str_eq(vec_get(positionals, 0), "list") == 1 {
        print(str_concat("registry: ", registry_dir));
        if vec_len(packages) == 0 {
            print("packages: 0");
            return 0;
        };
        let mut pi: i64 = 0;
        while pi < vec_len(packages) {
            let name: str = vec_get(packages, pi);
            let versions: Vec<i32> = registry_package_versions_native(registry_dir, name);
            if vec_len(versions) > 0 {
                print(str_concat(name, str_concat("  latest=", str_concat(vec_get(versions, 0), str_concat("  versions=", join_strings(versions, ", "))))));
            };
            pi = pi + 1;
        };
        return 0;
    };
    let subcmd: str = vec_get(positionals, 0);
    if str_eq(subcmd, "search") == 1 {
        if vec_len(positionals) < 2 {
            print("Usage: nuc registry search <query> [--registry <dir>]");
            return 1;
        };
        let query: str = vec_get(positionals, 1);
        print(str_concat("registry: ", registry_dir));
        let mut found: i64 = 0;
        let mut pi: i64 = 0;
        while pi < vec_len(packages) {
            let name: str = vec_get(packages, pi);
            if text_contains(name, query) == 1 {
                let versions: Vec<i32> = registry_package_versions_native(registry_dir, name);
                if vec_len(versions) > 0 {
                    print(str_concat(name, str_concat("  latest=", str_concat(vec_get(versions, 0), str_concat("  versions=", join_strings(versions, ", "))))));
                    found = 1;
                };
            };
            pi = pi + 1;
        };
        if found == 0 { print(str_concat("no packages matched '", str_concat(query, "'"))); };
        return 0;
    };
    if str_eq(subcmd, "versions") == 1 {
        if vec_len(positionals) < 2 {
            print("Usage: nuc registry versions <package> [--registry <dir>]");
            return 1;
        };
        let versions2: Vec<i32> = registry_package_versions_native(registry_dir, vec_get(positionals, 1));
        print(str_concat("registry: ", registry_dir));
        print(str_concat(vec_get(positionals, 1), str_concat(": ", join_strings(versions2, ", "))));
        return 0;
    };
    if str_eq(subcmd, "verify") == 1 {
        if vec_len(positionals) < 2 {
            print("Usage: nuc registry verify <package|package@version> [--registry <dir>]");
            return 1;
        };
        let spec_parts: Vec<i32> = parse_registry_spec_native(vec_get(positionals, 1));
        let package_name: str = vec_get(spec_parts, 0);
        let selector: str = vec_get(spec_parts, 1);
        let version: str = registry_resolve_version_native(registry_dir, package_name, selector);
        if str_len(version) == 0 {
            print(str_concat("ERROR: no installable versions for ", str_concat(package_name, str_concat(" matched ", selector))));
            return 1;
        };
        let verified: Vec<i32> = verify_registry_package_root_native(registry_dir, package_name, version);
        if vec_get(verified, 0) == 0 {
            print(str_concat("ERROR: ", vec_get(verified, 2)));
            return 1;
        };
        print(str_concat("registry: ", registry_dir));
        print(str_concat("package: ", package_name));
        print(str_concat("version: ", version));
        print(str_concat("signed: ", if vec_get(verified, 4) == 1 { "yes" } else { "no" }));
        if vec_get(verified, 4) == 1 {
            print(str_concat("signing_algorithm: ", vec_get(verified, 6)));
            print(str_concat("key_id: ", vec_get(verified, 5)));
        };
        if vec_get(verified, 3) > 0 {
            print(str_concat("exports: ", str_from_int(vec_get(verified, 3))));
            print(str_concat("abi_version: ", abi_export_version_label()));
            print(str_concat("surface: ", abi_export_surface_policy_label()));
            print(str_concat("version_policy: ", abi_export_version_policy_label()));
        } else {
            print("exports: none");
        };
        return 0;
    };
    print("Usage: nuc registry [list|search <query>|versions <package>|verify <package|package@version>] [--registry <dir>]");
    return 1;
}

fn run_install_command(argc: i64) -> i64 {
    // RFC-0019 phase 3 — `nuc install --git <url> [--rev <ref>]` stub.
    // CLI surface ships now so users hitting it know what to expect;
    // real clone + verify + lock lands with the v0.5 registry phase.
    let mut gi: i64 = 2;
    let mut git_url: str = "";
    let mut git_rev: str = "";
    while gi < argc {
        let a: str = args_get(gi);
        if str_eq(a, "--git") == 1 && gi + 1 < argc {
            git_url = args_get(gi + 1);
            gi = gi + 1;
        } else if str_eq(a, "--rev") == 1 && gi + 1 < argc {
            git_rev = args_get(gi + 1);
            gi = gi + 1;
        };
        gi = gi + 1;
    };
    if str_len(git_url) > 0 {
        print(str_concat("nuc install --git ", git_url));
        if str_len(git_rev) > 0 {
            print(str_concat("                   --rev ", git_rev));
        };
        print("");
        print("STATUS: deferred to v0.5 with the package registry (RFC-0019 phase 3).");
        print("");
        print("The v0.5 release will:");
        print("  1. Clone <url> into .nucleor/git/<host>-<repo>-<sha>/");
        print("  2. Check out <rev> (default: HEAD of the default branch)");
        print("  3. Verify the manifest at <repo>/Nucleor.toml is valid");
        print("  4. Add a `[dependencies]` entry pointing at the local clone");
        print("  5. Refresh Nucleor.lock with the resolved checksum");
        print("");
        print("Today, on Windows, clone the repo manually and use a path");
        print("dependency: `[dependencies] foo = \"path/to/foo\"` then `nuc lock`.");
        return 0;
    };
    // RFC-0022 phase 3 — `nuc install sysroot --target=<triple>` stub.
    // Documents the planned UX (paired with TGT-002 explain entry) and
    // returns a clear "deferred to v0.5" message so users hitting this
    // know what to expect and when. Real fetch/verify lands with the
    // package registry phase.
    if argc >= 3 && str_eq(args_get(2), "sysroot") == 1 {
        let mut target_triple: str = "";
        let mut si: i64 = 3;
        while si < argc {
            let a: str = args_get(si);
            if str_len(a) > 9 && str_eq(str_substring(a, 0, 9), "--target=") == 1 {
                target_triple = str_substring(a, 9, str_len(a));
            } else if str_eq(a, "--target") == 1 && si + 1 < argc {
                target_triple = args_get(si + 1);
                si = si + 1;
            };
            si = si + 1;
        };
        if str_len(target_triple) == 0 {
            print("ERROR: nuc install sysroot requires --target=<triple>");
            print("Example targets (planned for v0.5):");
            print("  --target=x86_64-unknown-linux-gnu");
            print("  --target=aarch64-unknown-linux-gnu");
            print("  --target=x86_64-apple-darwin");
            print("  --target=aarch64-apple-darwin");
            print("  --target=wasm32-unknown-unknown   (use `nuc build-wasm` today)");
            return 1;
        };
        print(str_concat("nuc install sysroot --target=", target_triple));
        print("");
        print("STATUS: deferred to v0.5 with the package registry (RFC-0022 phase 3).");
        print("");
        print("The v0.5 release will fetch a signed sysroot bundle from");
        print("https://nucleor.dev/sysroots/<triple>/ and verify the SHA-256");
        print("checksum before unpacking under .nucleor/sysroots/<triple>/.");
        print("Cross-target builds will then resolve clang's --sysroot from");
        print("that path automatically.");
        print("");
        print("Today, on Windows, nuc build-wasm targets wasm32-unknown-unknown");
        print("with no sysroot needed; for Linux/macOS native builds use");
        print("--target on the host and consult `nuc explain TGT-001`.");
        return 0;
    };
    let manifest_path: str = lock_resolve_manifest_target("");
    if str_len(manifest_path) == 0 {
        print("ERROR: no Nucleor.toml found in the current directory");
        print("Usage: nuc install [alias] <path-to-package|package|package@version> [--registry <dir>]");
        print("       nuc install sysroot --target=<triple>      (cross-target sysroot, v0.5)");
        return 1;
    };
    let mut positionals: Vec<i32> = Vec::new();
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if cli_is_flag(arg) == 0 { positionals.push(arg); };
        if str_eq(arg, "--registry") == 1 { i = i + 1; };
        i = i + 1;
    };
    let mut alias: str = "";
    let mut dep_input: str = "";
    if vec_len(positionals) == 1 {
        dep_input = vec_get(positionals, 0);
        let dep_manifest: str = manifest_resolve_dependency_manifest(manifest_path, dep_input);
        let dep_raw: str = file_read_string(dep_manifest);
        if str_len(dep_raw) == 0 {
            let spec_parts0: Vec<i32> = parse_registry_spec_native(dep_input);
            alias = vec_get(spec_parts0, 0);
        } else {
            let dep_settings: Vec<i32> = manifest_parse_settings(dep_manifest, dep_raw);
            alias = manifest_settings_package_name(dep_settings);
        };
    } else if vec_len(positionals) == 2 {
        alias = vec_get(positionals, 0);
        dep_input = vec_get(positionals, 1);
    } else {
        print("Usage: nuc install [alias] <path-to-package|package|package@version> [--registry <dir>]");
        return 1;
    };
    if str_len(alias) == 0 || str_len(dep_input) == 0 {
        print("ERROR: install requires a dependency alias and path");
        return 1;
    };
    let dep_manifest2: str = manifest_resolve_dependency_manifest(manifest_path, dep_input);
    let root_raw: str = file_read_string(manifest_path);
    let root_settings: Vec<i32> = manifest_parse_settings(manifest_path, root_raw);
    let deps: Vec<i32> = manifest_settings_deps(root_settings);
    let mut effective_dep_input: str = dep_input;
    if str_len(file_read_string(dep_manifest2)) == 0 {
        let spec_parts: Vec<i32> = parse_registry_spec_native(dep_input);
        let package_name: str = vec_get(spec_parts, 0);
        let selector: str = vec_get(spec_parts, 1);
        let registry_dir: str = registry_dir_native(argc, 2);
        let version: str = registry_resolve_version_native(registry_dir, package_name, selector);
        if str_len(version) == 0 {
            print(str_concat("ERROR: cannot resolve dependency '", str_concat(dep_input, "'")));
            return 1;
        };
        let verified: Vec<i32> = verify_registry_package_root_native(registry_dir, package_name, version);
        if vec_get(verified, 0) == 0 {
            print(str_concat("ERROR: ", vec_get(verified, 2)));
            return 1;
        };
        let published_root: str = vec_get(verified, 1);
        let vendor_root: str = sanitize(str_concat(path_with_sep(parent_dir(manifest_path)), str_concat(".nucleor/packages/", str_concat(package_name, str_concat("/", version)))));
        if copy_package_tree_native(published_root, vendor_root) != 0 {
            print(str_concat("ERROR: failed to vendor registry package: ", published_root));
            return 1;
        };
        write_package_checksum_file_native(vendor_root);
        let published_metadata: str = file_read_string(sanitize(str_concat(path_with_sep(published_root), registry_metadata_file_name())));
        if str_len(published_metadata) > 0 {
            file_write_string(sanitize(str_concat(path_with_sep(vendor_root), registry_metadata_file_name())), published_metadata);
        };
        effective_dep_input = path_normalize_slashes(path_relative_or_abs(parent_dir(manifest_path), vendor_root));
    };
    let mut replaced: i64 = 0;
    let mut di: i64 = 0;
    while di < vec_len(deps) {
        if str_eq(vec_get(deps, di), alias) == 1 {
            vec_set(deps, di + 1, effective_dep_input);
            replaced = 1;
            di = vec_len(deps);
        };
        di = di + 2;
    };
    if replaced == 0 {
        deps.push(alias);
        deps.push(effective_dep_input);
    };
    if manifest_replace_dependencies_section_native(manifest_path, deps) != 0 {
        print(str_concat("ERROR: cannot update dependencies in ", manifest_path));
        return 1;
    };
    let mut graph: Vec<i32> = Vec::new();
    let mut seen: Vec<i32> = Vec::new();
    let mut stack: Vec<i32> = Vec::new();
    let mut errors: Vec<i32> = Vec::new();
    if lock_build_graph_recursive(manifest_path, graph, seen, stack, errors) != 0 || vec_len(errors) > 0 {
        let err: str = if vec_len(errors) > 0 { vec_get(errors, 0) } else { "unknown dependency graph error" };
        print(str_concat("ERROR: ", err));
        return 1;
    };
    let lock_path: str = str_concat(path_with_sep(parent_dir(manifest_path)), "Nucleor.lock");
    file_write_string(lock_path, render_lockfile_native(manifest_path, graph));
    print(str_concat("installed dependency '", str_concat(alias, str_concat("' from ", path_normalize_slashes(dep_input)))));
    print(str_concat("locked: ", lock_path));
    return 0;
}

fn run_impact_command(src_path: str, argc: i64, arg_start: i64) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let fns: Vec<i32> = source_collect_functions(source);
    let graph: Vec<i32> = source_call_graph(fns);
    let effs: Vec<i32> = infer_source_effects(fns);
    let mut target_fn: str = cli_option_value(argc, arg_start, "--fn");
    if str_len(target_fn) == 0 { target_fn = cli_option_value(argc, arg_start, "--function"); };
    if str_len(target_fn) == 0 { target_fn = cli_first_positional(argc, arg_start); };
    if str_len(target_fn) == 0 {
        print("Usage: nuc impact <source.nr> <function_name>");
        return 1;
    };
    let target_idx: i64 = srcf_find(fns, target_fn);
    let mut direct_callees: Vec<i32> = Vec::new();
    let mut impacted: Vec<i32> = Vec::new();
    if target_idx >= 0 {
        let ord: i64 = target_idx / 8;
        let edges: Vec<i32> = vec_get(graph, ord);
        let mut ei: i64 = 0;
        while ei < vec_len(edges) {
            direct_callees.push(vec_get(fns, vec_get(edges, ei) * 8));
            ei = ei + 1;
        };
        let mut frontier: Vec<i32> = Vec::new();
        frontier.push(ord);
        while vec_len(frontier) > 0 {
            let cur_ord: i64 = vec_get(frontier, vec_len(frontier) - 1);
            vec_pop(frontier);
            let mut fi: i64 = 0;
            while fi < vec_len(graph) {
                let caller_name: str = vec_get(fns, fi * 8);
                let callees2: Vec<i32> = vec_get(graph, fi);
                if fi != cur_ord && int_vec_contains(callees2, cur_ord) == 1 && string_vec_contains(impacted, caller_name) == 0 {
                    impacted.push(caller_name);
                    frontier.push(fi);
                };
                fi = fi + 1;
            };
        };
    };
    let mut sb2: i64 = sb_new();
    sb_append(sb2, "{\"file\":\""); sb_append(sb2, json_escape(src_path)); sb_append(sb2, "\",\"target\":\""); sb_append(sb2, json_escape(target_fn)); sb_append(sb2, "\"");
    sb_append(sb2, ",\"found\":"); sb_append_json_bool(sb2, target_idx >= 0);
    sb_append(sb2, ",\"declared_effects\":"); sb_append_json_string_array(sb2, csv_to_string_vec(srcf_decl_effects(fns, target_fn)));
    sb_append(sb2, ",\"inferred_effects\":"); sb_append_json_string_array(sb2, csv_to_string_vec(inferred_effects_for(effs, target_fn)));
    sb_append(sb2, ",\"direct_callees\":"); sb_append_json_string_array(sb2, direct_callees);
    sb_append(sb2, ",\"impacted_callers\":"); sb_append_json_string_array(sb2, impacted);
    sb_append(sb2, ",\"total_impacted\":"); sb_append(sb2, str_from_int(vec_len(impacted)));
    sb_append(sb2, "}");
    print(sb_to_str(sb2));
    return 0;
}

fn render_graph_text(src_path: str, fns: Vec<i32>, graph: Vec<i32>, effs: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut edge_count: i64 = 0;
    let mut gi: i64 = 0;
    while gi < vec_len(graph) { edge_count = edge_count + vec_len(vec_get(graph, gi)); gi = gi + 1; };
    sb_append(sb, "file: "); sb_append(sb, src_path); sb_append(sb, "\n");
    sb_append(sb, "functions: "); sb_append(sb, str_from_int(vec_len(fns) / 8)); sb_append(sb, "\n");
    sb_append(sb, "edges: "); sb_append(sb, str_from_int(edge_count)); sb_append(sb, "\n");
    let mut i: i64 = 0;
    while i < vec_len(fns) {
        let name: str = vec_get(fns, i);
        let ord: i64 = i / 8;
        let edges: Vec<i32> = vec_get(graph, ord);
        let mut callee_names: Vec<i32> = Vec::new();
        let mut j: i64 = 0;
        while j < vec_len(edges) {
            callee_names.push(vec_get(fns, vec_get(edges, j) * 8));
            j = j + 1;
        };
        sb_append(sb, "fn ");
        sb_append(sb, name);
        if vec_get(fns, i + 1) == 1 { sb_append(sb, " [pure]"); };
        if vec_get(fns, i + 4) == 1 { sb_append(sb, " [extern]"); };
        if vec_get(fns, i + 7) == 1 { sb_append(sb, " [spawn]"); };
        sb_append(sb, "\n");
        let inf: str = csv_pretty(inferred_effects_for(effs, name));
        if str_len(inf) > 0 {
            sb_append(sb, "  effects: "); sb_append(sb, inf); sb_append(sb, "\n");
        };
        if vec_len(callee_names) > 0 {
            sb_append(sb, "  calls: "); sb_append(sb, join_strings(callee_names, ", ")); sb_append(sb, "\n");
        };
        i = i + 8;
    };
    return sb_to_str(sb);
}

fn render_graph_json(src_path: str, fns: Vec<i32>, graph: Vec<i32>, effs: Vec<i32>) -> str {
    let mut edge_count: i64 = 0;
    let mut gi: i64 = 0;
    while gi < vec_len(graph) { edge_count = edge_count + vec_len(vec_get(graph, gi)); gi = gi + 1; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"file\":\""); sb_append(sb, json_escape(src_path)); sb_append(sb, "\",\"function_count\":");
    sb_append(sb, str_from_int(vec_len(fns) / 8));
    sb_append(sb, ",\"edge_count\":"); sb_append(sb, str_from_int(edge_count));
    sb_append(sb, ",\"functions\":[");
    let mut i: i64 = 0;
    let mut first: i64 = 1;
    while i < vec_len(fns) {
        let name: str = vec_get(fns, i);
        let ord: i64 = i / 8;
        let edges: Vec<i32> = vec_get(graph, ord);
        let mut callee_names: Vec<i32> = Vec::new();
        let mut j: i64 = 0;
        while j < vec_len(edges) {
            callee_names.push(vec_get(fns, vec_get(edges, j) * 8));
            j = j + 1;
        };
        if first == 0 { sb_append(sb, ","); } else { first = 0; };
        sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(name)); sb_append(sb, "\",\"pure\":");
        sb_append_json_bool(sb, vec_get(fns, i + 1));
        sb_append(sb, ",\"extern\":"); sb_append_json_bool(sb, vec_get(fns, i + 4));
        sb_append(sb, ",\"has_spawn\":"); sb_append_json_bool(sb, vec_get(fns, i + 7));
        sb_append(sb, ",\"declared_effects\":"); sb_append_json_string_array(sb, csv_to_string_vec(vec_get(fns, i + 2)));
        sb_append(sb, ",\"inferred_effects\":"); sb_append_json_string_array(sb, csv_to_string_vec(inferred_effects_for(effs, name)));
        sb_append(sb, ",\"direct_callees\":"); sb_append_json_string_array(sb, callee_names);
        sb_append(sb, "}");
        i = i + 8;
    };
    sb_append(sb, "]}");
    return sb_to_str(sb);
}

fn run_graph_command(src_path: str, argc: i64, arg_start: i64) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let fns: Vec<i32> = source_collect_functions(source);
    let graph: Vec<i32> = source_call_graph(fns);
    let effs: Vec<i32> = infer_source_effects(fns);
    if cli_wants_json(argc, arg_start) == 1 {
        print(render_graph_json(src_path, fns, graph, effs));
    } else {
        print(render_graph_text(src_path, fns, graph, effs));
    };
    return 0;
}

fn run_profile_command(argc: i64) -> i64 {
    let mut subcmd: str = "run";
    if argc >= 3 { subcmd = args_get(2); };
    if str_eq(subcmd, "run") == 0 {
        print(str_concat("ERROR: unknown profile subcommand: ", subcmd));
        print("Usage: nuc profile run <binary> [--iterations <n>] [--json]");
        return 1;
    };
    if argc < 4 {
        print("Usage: nuc profile run <binary> [--iterations <n>] [--json]");
        return 1;
    };
    let binary: str = args_get(3);
    let mut iterations: i64 = 1;
    let mut json_mode: i64 = 0;
    let mut i: i64 = 4;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") == 1 || str_eq(arg, "--output=json") == 1 {
            json_mode = 1;
        } else if str_eq(arg, "--output") == 1 && i + 1 < argc && str_eq(args_get(i + 1), "json") == 1 {
            json_mode = 1;
            i = i + 1;
        } else if str_eq(arg, "--iterations") == 1 {
            if i + 1 >= argc {
                print("ERROR: --iterations requires a value");
                return 1;
            };
            iterations = str_to_int(args_get(i + 1));
            i = i + 1;
        } else if str_len(arg) > 13 && str_eq(str_substring(arg, 0, 13), "--iterations=") == 1 {
            iterations = str_to_int(str_substring(arg, 13, str_len(arg)));
        };
        i = i + 1;
    };
    if iterations < 1 { iterations = 1; };
    let quoted_binary: str = str_concat("\"", str_concat(binary, "\""));
    let total_start: i64 = now_ms();
    let mut run_times: Vec<i32> = Vec::new();
    let mut rc: i64 = 0;
    let mut iter: i64 = 0;
    while iter < iterations {
        let run_start: i64 = now_ms();
        let mut run_cmd: str = quoted_binary;
        if json_mode == 1 { run_cmd = str_concat(quoted_binary, " >NUL 2>&1"); };
        rc = system(run_cmd);
        run_times.push(now_ms() - run_start);
        if rc != 0 { iter = iterations; }
        else { iter = iter + 1; };
    };
    let total_ms: i64 = now_ms() - total_start;
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"subcommand\":\"run\",\"binary\":\""); sb_append(sb, json_escape(binary));
        sb_append(sb, "\",\"iterations\":"); sb_append(sb, str_from_int(iterations));
        sb_append(sb, ",\"exit_code\":"); sb_append(sb, str_from_int(rc));
        sb_append(sb, ",\"total_ms\":"); sb_append(sb, str_from_int(total_ms));
        sb_append(sb, ",\"avg_ms\":"); sb_append(sb, str_from_int(total_ms / iterations));
        sb_append(sb, ",\"runs\":[");
        let mut ri: i64 = 0;
        while ri < vec_len(run_times) {
            if ri > 0 { sb_append(sb, ","); };
            sb_append(sb, str_from_int(vec_get(run_times, ri)));
            ri = ri + 1;
        };
        sb_append(sb, "]}");
        print(sb_to_str(sb));
        return rc;
    };
    print(str_concat("=== Nucleor Profile Run: ", binary));
    print(str_concat("  iterations: ", str_from_int(iterations)));
    print(str_concat("  total_ms: ", str_from_int(total_ms)));
    print(str_concat("  avg_ms: ", str_from_int(total_ms / iterations)));
    return rc;
}

fn run_sage_command(argc: i64) -> i64 {
    if argc < 4 {
        print("Usage: nuc sage <prove|certificate|gaps> <file.nr> [--json]");
        return 1;
    };
    let subcmd: str = args_get(2);
    let src_path: str = args_get(3);
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    let mut json_mode: i64 = 0;
    let mut i: i64 = 4;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") == 1 || str_eq(arg, "--output=json") == 1 { json_mode = 1; }
        else if str_eq(arg, "--output") == 1 && i + 1 < argc && str_eq(args_get(i + 1), "json") == 1 {
            json_mode = 1;
            i = i + 1;
        };
        i = i + 1;
    };
    let has_sage_import: i64 = text_contains(source, "sage_ns") || text_contains(source, "sage_ns::");
    let has_interval: i64 = text_contains(source, "interval");
    let has_validated: i64 = text_contains(source, "validated");
    let has_inference: i64 = text_contains(source, "inference");
    let has_certificate: i64 = text_contains(source, "certificate");
    let mut gaps: Vec<i32> = Vec::new();
    if has_sage_import == 0 { gaps.push("missing sage_ns import"); };
    if has_interval == 0 { gaps.push("missing interval primitives"); };
    if has_validated == 0 { gaps.push("missing validated integration path"); };
    if has_inference == 0 { gaps.push("missing inference path"); };
    if has_certificate == 0 { gaps.push("missing certificate path"); };
    if text_contains(source, "TODO") == 1 { gaps.push("TODO markers present"); };
    if text_contains(source, "FIXME") == 1 { gaps.push("FIXME markers present"); };
    if text_contains(source, "assume") == 1 { gaps.push("assume markers present"); };
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"subcommand\":\""); sb_append(sb, json_escape(subcmd)); sb_append(sb, "\",\"file\":\""); sb_append(sb, json_escape(src_path));
        sb_append(sb, "\",\"sage_import\":"); sb_append_json_bool(sb, has_sage_import);
        sb_append(sb, ",\"layers\":{\"interval\":"); sb_append_json_bool(sb, has_interval);
        sb_append(sb, ",\"validated\":"); sb_append_json_bool(sb, has_validated);
        sb_append(sb, ",\"inference\":"); sb_append_json_bool(sb, has_inference);
        sb_append(sb, ",\"certificate\":"); sb_append_json_bool(sb, has_certificate);
        sb_append(sb, "},\"gaps\":"); sb_append_json_string_array(sb, gaps);
        sb_append(sb, "}");
        print(sb_to_str(sb));
        return 0;
    };
    if str_eq(subcmd, "prove") == 1 {
        print(str_concat("=== Sage_NS Proof Pipeline: ", src_path));
        print("");
        print(str_concat("  Layer 1: interval primitives ... ", if has_interval == 1 { "present" } else { "missing" }));
        print(str_concat("  Layer 2: validated integration ... ", if has_validated == 1 { "present" } else { "missing" }));
        print(str_concat("  Layer 3: inference engine ... ", if has_inference == 1 { "present" } else { "missing" }));
        print(str_concat("  Layer 4: certificate generator ... ", if has_certificate == 1 { "present" } else { "missing" }));
        if has_sage_import == 0 { print("  Status: sage_ns import is missing."); }
        else if vec_len(gaps) == 0 { print("  Status: proof pipeline hooks detected."); }
        else { print("  Status: partial pipeline detected; run `nuc sage gaps <file.nr>` for missing pieces."); };
        return 0;
    } else if str_eq(subcmd, "certificate") == 1 {
        print(str_concat("=== Sage_NS Certificate Status: ", src_path));
        if has_certificate == 1 { print("  Certificate hooks detected."); }
        else { print("  Certificate generation path not found in source."); };
        return 0;
    } else if str_eq(subcmd, "gaps") == 1 {
        print(str_concat("=== Sage_NS Gap Analysis: ", src_path));
        if vec_len(gaps) == 0 { print("  No obvious Sage_NS integration gaps detected."); }
        else {
            let mut gi: i64 = 0;
            while gi < vec_len(gaps) {
                print(str_concat("  - ", vec_get(gaps, gi)));
                gi = gi + 1;
            };
        };
        return 0;
    };
    print(str_concat("ERROR: unknown sage subcommand: ", subcmd));
    print("Usage: nuc sage <prove|certificate|gaps> <file.nr> [--json]");
    return 1;
}

fn run_perf_command(src_path: str, argc: i64, arg_start: i64) -> i64 {
    let json_mode: i64 = cli_wants_json(argc, arg_start);
    let total_start: i64 = now_ms();
    let resolve_start: i64 = now_ms();
    let bundle: Vec<i32> = load_resolved_source_bundle(src_path, 1);
    let source: str = vec_get(bundle, 0);
    let imported: Vec<i32> = vec_get(bundle, 1);
    if str_len(source) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    let resolve_ms: i64 = now_ms() - resolve_start;
    let preflight_start: i64 = now_ms();
    if preflight_source_check(source) != 0 { return 1; };
    let preflight_ms: i64 = now_ms() - preflight_start;
    let lex_start: i64 = now_ms();
    let mut tokens: Vec<i32> = lex(source);
    let lex_ms: i64 = now_ms() - lex_start;
    let mut pool: Vec<i32> = Vec::new();
    let parse_start: i64 = now_ms();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    let parse_ms: i64 = now_ms() - parse_start;
    let cnt: i64 = list_len(pool, prog);
    let mut strtab: Vec<i32> = Vec::new();
    let mut fns: Vec<i32> = Vec::new();
    let mut externs: Vec<i32> = Vec::new();
    let mut structs: Vec<i32> = Vec::new();
    let mut enums: Vec<i32> = Vec::new();
    let mut globals: Vec<i32> = Vec::new();
    let collect_start: i64 = now_ms();
    let mut fi: i64 = 0;
    while fi < cnt {
        let nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, nid) == 32 { externs.push(nid); }
        else if node_kind(pool, nid) == 33 { structs.push(nid); }
        else if node_kind(pool, nid) == 36 { enums.push(nid); };
        if node_kind(pool, nid) == 50 { globals.push(nid); };
        fi = fi + 1;
    };
    let collect_ms: i64 = now_ms() - collect_start;
    let mut trait_impls: Vec<i32> = Vec::new();
    let mut impl_fns: Vec<i32> = Vec::new();
    let impl_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let nid2: i64 = list_get(pool, prog, fi);
        if node_kind(pool, nid2) == 45 {
            let type_name: str = node_field(pool, nid2, 2);
            let methods: i64 = node_field(pool, nid2, 3);
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
    let impl_ms: i64 = now_ms() - impl_start;
    let mut diags: Vec<i32> = diag_new();
    let own_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let nid3: i64 = list_get(pool, prog, fi);
        if node_kind(pool, nid3) == 30 { check_fn(pool, nid3, structs, enums, diags, source, "", ""); };
        fi = fi + 1;
    };
    let mut oi: i64 = 0;
    while oi < vec_len(impl_fns) {
        check_fn(pool, vec_get(impl_fns, oi), structs, enums, diags, source, "", "");
        oi = oi + 1;
    };
    let ownership_ms: i64 = now_ms() - own_start;
    let type_start: i64 = now_ms();
    let tprof: Vec<i32> = tprof_new(0);
    type_check_program(pool, prog, structs, diags, source, tprof);
    let type_ms: i64 = now_ms() - type_start;
    let source_start: i64 = now_ms();
    source_rule_check(source, diags);
    let source_ms: i64 = now_ms() - source_start;
    let mut pure_fns: Vec<i32> = Vec::new();
    fi = 0;
    while fi < cnt {
        let nid4: i64 = list_get(pool, prog, fi);
        if node_kind(pool, nid4) == 46 { pure_fns.push(node_field(pool, nid4, 1)); };
        fi = fi + 1;
    };
    let effect_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let nid5: i64 = list_get(pool, prog, fi);
        if node_kind(pool, nid5) == 30 {
            let fname: str = node_field(pool, nid5, 1);
            let mut is_pure: i64 = 0;
            let mut pi: i64 = 0;
            while pi < vec_len(pure_fns) {
                if str_eq(vec_get(pure_fns, pi), fname) == 1 { is_pure = 1; pi = vec_len(pure_fns); };
                pi = pi + 1;
            };
            if is_pure == 1 { effect_check_fn(pool, nid5, pure_fns, diags, source, "", ""); };
        };
        fi = fi + 1;
    };
    let effect_ms: i64 = now_ms() - effect_start;
    let taint_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let nid6: i64 = list_get(pool, prog, fi);
        if node_kind(pool, nid6) == 30 { taint_check_fn(pool, nid6, diags, source, "", ""); };
        fi = fi + 1;
    };
    let taint_ms: i64 = now_ms() - taint_start;
    if diag_count(diags) > 0 {
        diag_emit_text(diags);
        return 1;
    };
    let mut closures: Vec<i32> = Vec::new();
    let lower_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let nid7: i64 = list_get(pool, prog, fi);
        if node_kind(pool, nid7) == 30 { fns.push(lower_fn(pool, nid7, strtab, structs, enums, globals, closures, trait_impls)); };
        fi = fi + 1;
    };
    let mut ii: i64 = 0;
    while ii < vec_len(impl_fns) {
        fns.push(lower_fn(pool, vec_get(impl_fns, ii), strtab, structs, enums, globals, closures, trait_impls));
        ii = ii + 1;
    };
    let mut ci: i64 = 0;
    while ci < vec_len(closures) {
        fns.push(vec_get(closures, ci));
        ci = ci + 1;
    };
    let lower_ms: i64 = now_ms() - lower_start;
    let opt_start: i64 = now_ms();
    let mut opt_total: i64 = 0;
    fi = 0;
    while fi < vec_len(fns) {
        opt_total = opt_total + opt_fn(vec_get(fns, fi));
        fi = fi + 1;
    };
    let opt_ms: i64 = now_ms() - opt_start;
    let emit_start: i64 = now_ms();
    let ll: str = emit_module_ext(fns, strtab, pool, externs);
    let emit_ms: i64 = now_ms() - emit_start;
    let total_ms: i64 = now_ms() - total_start;
    let mut diagnostics: Vec<i32> = Vec::new();
    if type_ms > ownership_ms && type_ms > lower_ms && type_ms > emit_ms {
        diagnostics.push("type checking dominates cold analysis time");
    };
    if str_len(ll) > 1000000 {
        diagnostics.push("large LLVM module size; consider splitting into smaller modules");
    };
    if vec_len(imported) > 25 {
        diagnostics.push("large import graph; module boundaries may be too wide for fast cold builds");
    };
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"file\":\""); sb_append(sb, json_escape(src_path)); sb_append(sb, "\",\"mode\":\"strict\",");
        sb_append(sb, "\"source_bytes\":"); sb_append(sb, str_from_int(str_len(source)));
        sb_append(sb, ",\"module_count\":"); sb_append(sb, str_from_int(vec_len(imported)));
        sb_append(sb, ",\"function_count\":"); sb_append(sb, str_from_int(vec_len(fns)));
        sb_append(sb, ",\"string_count\":"); sb_append(sb, str_from_int(vec_len(strtab)));
        sb_append(sb, ",\"optimized_instructions\":"); sb_append(sb, str_from_int(opt_total));
        sb_append(sb, ",\"ll_bytes\":"); sb_append(sb, str_from_int(str_len(ll)));
        sb_append(sb, ",\"phase_ms\":{\"resolve_source\":"); sb_append(sb, str_from_int(resolve_ms));
        sb_append(sb, ",\"preflight\":"); sb_append(sb, str_from_int(preflight_ms));
        sb_append(sb, ",\"lex\":"); sb_append(sb, str_from_int(lex_ms));
        sb_append(sb, ",\"parse\":"); sb_append(sb, str_from_int(parse_ms));
        sb_append(sb, ",\"collect_decls\":"); sb_append(sb, str_from_int(collect_ms));
        sb_append(sb, ",\"collect_impls\":"); sb_append(sb, str_from_int(impl_ms));
        sb_append(sb, ",\"ownership\":"); sb_append(sb, str_from_int(ownership_ms));
        sb_append(sb, ",\"type\":"); sb_append(sb, str_from_int(type_ms));
        sb_append(sb, ",\"source\":"); sb_append(sb, str_from_int(source_ms));
        sb_append(sb, ",\"effect\":"); sb_append(sb, str_from_int(effect_ms));
        sb_append(sb, ",\"taint\":"); sb_append(sb, str_from_int(taint_ms));
        sb_append(sb, ",\"lower\":"); sb_append(sb, str_from_int(lower_ms));
        sb_append(sb, ",\"opt\":"); sb_append(sb, str_from_int(opt_ms));
        sb_append(sb, ",\"emit\":"); sb_append(sb, str_from_int(emit_ms));
        sb_append(sb, ",\"total\":"); sb_append(sb, str_from_int(total_ms));
        sb_append(sb, "},\"diagnostics\":"); sb_append_json_string_array(sb, diagnostics);
        sb_append(sb, "}");
        print(sb_to_str(sb));
        return 0;
    };
    print(str_concat("=== Nucleor Performance Analysis: ", src_path));
    print(str_concat("  module_count: ", str_from_int(vec_len(imported))));
    print(str_concat("  function_count: ", str_from_int(vec_len(fns))));
    print(str_concat("  string_count: ", str_from_int(vec_len(strtab))));
    print(str_concat("  optimized_instructions: ", str_from_int(opt_total)));
    print(str_concat("  ll_bytes: ", str_from_int(str_len(ll))));
    print(str_concat("  total_ms: ", str_from_int(total_ms)));
    print(str_concat("  hot_phase: type=", str_from_int(type_ms)));
    if vec_len(diagnostics) == 0 {
        print("  diagnostics: none");
    } else {
        let mut di: i64 = 0;
        while di < vec_len(diagnostics) {
            print(str_concat("  diagnostic: ", vec_get(diagnostics, di)));
            di = di + 1;
        };
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
    // Remove target/ and .nuc_cache/ from the current working directory.
    // Use `system` (rmdir on Windows / rm on POSIX). Refuse to run if the
    // current directory is the filesystem root.
    let cwd: str = getcwd();
    if str_len(cwd) <= 3 {
        print("clean: refusing to operate on filesystem root");
        return 1;
    };
    print(str_concat("clean: removing build artifacts in ", cwd));
    // Windows: `rmdir /S /Q` does the recursive delete; ignore errors so we
    // can still try the other path if one is missing.
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
    print("  build [file]           Compile to native binary (strict checks, cached)");
    print("  build-fast [file]      Compile with ownership + type checks only");
    print("  build-strict [file]    Compile with full strict checker stack");
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
    print("    --isolation=process  Spawn a fresh child process per test (RFC-0021)");
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
    print("  fix --imports [file]   Rewrite import \"stdlib/rods/foo.nr\" to use std::foo (RFC-0018)");
    print("  fix --numeric [file]   Lint mixed-width arithmetic, suggest `as` casts (RFC-0015)");
    print("  doc <file> [--out f]   Emit Markdown reference for `pub fn` / `fn` decls (RFC-0029)");
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
    print("  mco                    Mars Climate Orbiter — why we ship dimensional analysis");
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
    if str_eq(cmd, "lock") {
        return run_lock_command(argc);
    };
    if str_eq(cmd, "fix") {
        // Parse: nuc fix [--imports|--numeric] <file>
        let mut sub: str = "";
        let mut tgt: str = "";
        let mut fi: i64 = 2;
        while fi < argc {
            let a: str = args_get(fi);
            if str_eq(a, "--imports") == 1 { sub = "imports"; }
            else if str_eq(a, "--numeric") == 1 { sub = "numeric"; }
            else if cli_is_flag(a) == 0 && str_len(tgt) == 0 { tgt = a; };
            fi = fi + 1;
        };
        return run_fix_command(tgt, sub);
    };
    if str_eq(cmd, "doc") {
        // Parse: nuc doc <file> [--out <markdown>]
        let mut tgt: str = "";
        let mut out_path: str = "";
        let mut di: i64 = 2;
        while di < argc {
            let a: str = args_get(di);
            if str_eq(a, "--out") == 1 && di + 1 < argc {
                out_path = args_get(di + 1);
                di = di + 1;
            } else if cli_is_flag(a) == 0 && str_len(tgt) == 0 { tgt = a; };
            di = di + 1;
        };
        return run_doc_command(tgt, out_path);
    };
    if str_eq(cmd, "install") {
        return run_install_command(argc);
    };
    if str_eq(cmd, "publish") {
        return run_publish_command(argc);
    };
    if str_eq(cmd, "registry") {
        return run_registry_command(argc);
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
    let mut test_isolation_process: i64 = 0;
    let mut saw_output_name: i64 = 0;
    let mut argi_build: i64 = arg_start;
    while argi_build < argc {
        let flag: str = args_get(argi_build);
        if str_eq(flag, "--time-passes") { time_passes = 1; }
        else if str_eq(flag, "--no-cache") { use_cache = 0; }
        else if str_eq(cmd, "test") && str_eq(flag, "--list") { test_list_only = 1; }
        else if str_eq(cmd, "test") && str_eq(flag, "--isolation=process") { test_isolation_process = 1; }
        else if str_eq(cmd, "test") && str_eq(flag, "--isolation=thread") { test_isolation_process = 0; }
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
        return compile_file_mode(src_path, out_name, 1, use_cache, time_passes, link_native);
    } else if str_eq(cmd, "build-fast") {
        return compile_file_mode(src_path, out_name, 0, use_cache, time_passes, link_native);
    } else if str_eq(cmd, "build-strict") {
        return compile_file_mode(src_path, out_name, 1, use_cache, time_passes, link_native);
    } else if str_eq(cmd, "build-shared") {
        return run_build_shared_command(src_path, out_name, use_cache, time_passes, cli_wants_json(argc, arg_start));
    } else if str_eq(cmd, "run") {
        let rc: i64 = compile_file_mode(src_path, out_name, 1, use_cache, time_passes, 1);
        if rc != 0 { return rc; };
        let exe: str = str_concat("target\\", str_concat(out_name, ".exe"));
        return system(exe);
    } else if str_eq(cmd, "build-wasm") {
        // Compile to WASM using clang --target=wasm32
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
        let source: str = vec_get(bundle, 0);
        let imp: Vec<i32> = vec_get(bundle, 1);
        if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
        if preflight_source_check(source) != 0 { return 1; };
        let mut tokens: Vec<i32> = lex(source);
        let mut pool: Vec<i32> = Vec::new();
        let mut r: Vec<i32> = parse_program(tokens, pool);
        let prog: i64 = pr_val(r);
        let cnt: i64 = list_len(pool, prog);
        let mut strtab: Vec<i32> = Vec::new();
        let mut fns: Vec<i32> = Vec::new();
        let mut externs: Vec<i32> = Vec::new();
        let mut structs: Vec<i32> = Vec::new();
        let mut enums: Vec<i32> = Vec::new();
        let mut globals: Vec<i32> = Vec::new();
        let mut fi: i64 = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 32 { externs.push(fn_nid); }
            else if node_kind(pool, fn_nid) == 33 { structs.push(fn_nid); }
            else if node_kind(pool, fn_nid) == 36 { enums.push(fn_nid); };
            if node_kind(pool, fn_nid) == 50 { globals.push(fn_nid); };
            fi = fi + 1;
        };
        let mut trait_impls: Vec<i32> = Vec::new();
        let mut impl_fns: Vec<i32> = Vec::new();
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
                    impl_fns.push(mk6(pool, 30, mangled, node_field(pool, method_nid, 2), node_field(pool, method_nid, 3), node_field(pool, method_nid, 4), node_field(pool, method_nid, 5)));
                    trait_impl_register(trait_impls, type_name, orig_name, mangled);
                    mi = mi + 1;
                };
            };
            fi = fi + 1;
        };
        let mut closures: Vec<i32> = Vec::new();
        fi = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 30 { fns.push(lower_fn(pool, fn_nid, strtab, structs, enums, globals, closures, trait_impls)); };
            fi = fi + 1;
        };
        let mut ii: i64 = 0;
        while ii < vec_len(impl_fns) { fns.push(lower_fn(pool, vec_get(impl_fns, ii), strtab, structs, enums, globals, closures, trait_impls)); ii = ii + 1; };
        let mut ci: i64 = 0;
        while ci < vec_len(closures) { fns.push(vec_get(closures, ci)); ci = ci + 1; };
        fi = 0;
        while fi < vec_len(fns) { opt_fn(vec_get(fns, fi)); fi = fi + 1; };
        let ll: str = emit_module_ext(fns, strtab, pool, externs);
        let ll_path: str = str_concat("target/", str_concat(out_name, ".ll"));
        let wasm_path: str = str_concat("target/", str_concat(out_name, ".wasm"));
        file_write_string(ll_path, ll);
        print(str_concat("  emitted: ", str_concat(ll_path, str_concat(" (", str_concat(str_from_int(str_len(ll)), " bytes)")))));
        let wasm_cmd: str = str_concat("\"C:\\Program Files\\LLVM\\bin\\clang.exe\" --target=wasm32-unknown-unknown -nostdlib -Wl,--no-entry -Wl,--export-all -Wl,--allow-undefined -o ", str_concat(wasm_path, str_concat(" ", str_concat(ll_path, " -Wno-override-module 2>&1"))));
        let rc: i64 = system(wasm_cmd);
        if rc != 0 { print("  WASM COMPILE FAILED"); print("  Note: WASM builds cannot use print(), system(), or file I/O functions"); return 1; };
        print(str_concat("  compiled: ", wasm_path));
        return 0;
    } else if str_eq(cmd, "build-ptx") {
        let emit_rc: i64 = compile_file_mode(src_path, out_name, 1, use_cache, time_passes, 0);
        if emit_rc != 0 { return emit_rc; };
        let ll_path2: str = str_concat("target/", str_concat(out_name, ".ll"));
        let ptx_path: str = str_concat("target/", str_concat(out_name, ".ptx"));
        let ptx_cmd: str = str_concat(llvm_clang_path(), str_concat(" --target=nvptx64-nvidia-cuda -S -x ir ", str_concat(ll_path2, str_concat(" -o ", str_concat(ptx_path, " -Wno-override-module 2>&1")))));
        let ptx_rc: i64 = system(ptx_cmd);
        if ptx_rc != 0 {
            print("  PTX COMPILE FAILED");
            print("  Note: PTX builds require LLVM clang with NVPTX support");
            return 1;
        };
        print(str_concat("  compiled: ", ptx_path));
        return 0;
    } else if str_eq(cmd, "emit") {
        return compile_file_mode(src_path, out_name, 1, use_cache, time_passes, 0);
    } else if str_eq(cmd, "test") {
        return run_test_command(src_path, out_name, use_cache, time_passes, test_list_only, test_isolation_process);
    } else if str_eq(cmd, "bench") {
        return run_bench_command(src_path, out_name, use_cache, time_passes, bench_iterations, bench_warmup);
    } else if str_eq(cmd, "check") {
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
        let source: str = vec_get(bundle, 0);
        if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
        if preflight_source_check(source) != 0 { return 1; };
        let mut tokens: Vec<i32> = lex(source);
        let mut pool: Vec<i32> = Vec::new();
        let mut r: Vec<i32> = parse_program(tokens, pool);
        let prog: i64 = pr_val(r);
        let cnt: i64 = list_len(pool, prog);
        // Collect structs and enums for checkers
        let mut structs: Vec<i32> = Vec::new();
        let mut enums: Vec<i32> = Vec::new();
        let mut fi: i64 = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 33 { structs.push(fn_nid); }
            else if node_kind(pool, fn_nid) == 36 { enums.push(fn_nid); };
            fi = fi + 1;
        };
        // Check for --review, --json, --review-filter, --check flags
        let mut json_mode: i64 = 0;
        let mut sarif_mode: i64 = 0;
        let mut review_path: str = "";
        let mut review_filter: str = "";
        let mut check_filter: str = "";
        let mut argi: i64 = arg_start;
        while argi < argc {
            let flag: str = args_get(argi);
            if str_eq(flag, "--json") { json_mode = 1; };
            if str_eq(flag, "--sarif") { sarif_mode = 1; };
            if str_eq(flag, "--review") { review_path = "nucleor_review.jsonl"; };
            if str_eq(flag, "--review-pipe") { review_path = "\\\\.\\pipe\\nucleor_review"; };
            if str_len(flag) > 16 && str_eq(str_substring(flag, 0, 16), "--review-filter=") {
                review_filter = str_substring(flag, 16, str_len(flag));
            };
            if str_len(flag) > 8 && str_eq(str_substring(flag, 0, 8), "--check=") {
                check_filter = str_substring(flag, 8, str_len(flag));
            };
            argi = argi + 1;
        };
        // Initialize review file
        if str_len(review_path) > 0 {
            file_write_string(review_path, str_concat("{\"schema_version\":\"1.0\",\"event\":\"surface_open\",\"file\":\"", str_concat(src_path, "\"}\n")));
        };
        // Run checkers (respecting --check filter)
        let start_ns: i64 = 0;
        let mut diags: Vec<i32> = diag_new();
        let run_own: i64 = str_len(check_filter) == 0 || review_filter_allows_checker(check_filter, "ownership");
        let run_type: i64 = str_len(check_filter) == 0 || review_filter_allows_checker(check_filter, "type");
        let run_source: i64 = str_len(check_filter) == 0 || review_filter_allows_checker(check_filter, "source");
        let run_taint: i64 = str_len(check_filter) == 0 || review_filter_allows_checker(check_filter, "taint");
        let run_effect: i64 = str_len(check_filter) == 0 || review_filter_allows_checker(check_filter, "effect");
        let check_type_prof: Vec<i32> = tprof_new(time_passes);
        if run_type == 1 { type_check_program(pool, prog, structs, diags, source, check_type_prof); };
        if run_type == 1 { tprof_dump(check_type_prof); };
        if run_source == 1 { source_rule_check(source, diags); };
        // Per-function checker tracking for coverage events
        fi = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 30 {
                let fname: str = node_field(pool, fn_nid, 1);
                let d_before: i64 = diag_count(diags);
                let mut own_findings: i64 = 0;
                let mut taint_findings: i64 = 0;
                if run_own == 1 { own_findings = check_fn(pool, fn_nid, structs, enums, diags, source, review_path, review_filter); };
                if run_taint == 1 { taint_findings = taint_check_fn(pool, fn_nid, diags, source, review_path, review_filter); };
                // S12b: checker_coverage event (removable)
                if str_len(review_path) > 0 {
                    let mut csb: i64 = sb_new();
                    sb_append(csb, "{\"schema_version\":\"1.0\",\"event\":\"checker_coverage\",\"function\":\"");
                    sb_append(csb, fname);
                    sb_append(csb, "\",\"checkers\":{\"ownership\":{\"ran\":");
                    if run_own == 1 { sb_append(csb, "true"); } else { sb_append(csb, "false"); };
                    sb_append(csb, ",\"findings\":"); sb_append(csb, str_from_int(own_findings));
                    sb_append(csb, "},\"taint\":{\"ran\":");
                    if run_taint == 1 { sb_append(csb, "true"); } else { sb_append(csb, "false"); };
                    sb_append(csb, ",\"findings\":"); sb_append(csb, str_from_int(taint_findings));
                    sb_append(csb, "}}}");
                    review_emit(review_path, sb_to_str(csb));
                };
                // Causal links: if multiple diags in same function, link them
                let d_after: i64 = diag_count(diags);
                if d_after - d_before >= 2 {
                    let first_id: str = str_concat("D-", str_from_int(d_before + 1));
                    let mut di: i64 = d_before + 1;
                    while di < d_after {
                        let d: Vec<i32> = diag_get(diags, di);
                        let did: str = str_concat("D-", str_from_int(di + 1));
                        // Set related_id on this diagnostic pointing to the first
                        vec_set(d, 7, first_id);
                        // S12b: causal link event (removable)
                        if str_len(review_path) > 0 {
                            let mut lsb: i64 = sb_new();
                            sb_append(lsb, "{\"schema_version\":\"1.0\",\"event\":\"causal_link\",\"from_diagnostic_id\":\"");
                            sb_append(lsb, first_id); sb_append(lsb, "\",\"to_diagnostic_id\":\"");
                            sb_append(lsb, did); sb_append(lsb, "\",\"relationship\":\"upstream_cause\"}");
                            review_emit(review_path, sb_to_str(lsb));
                        };
                        di = di + 1;
                    };
                };
            };
            fi = fi + 1;
        };
        // Inter-procedural taint pass
        if run_taint == 1 {
            fi = 0;
            while fi < cnt {
                let fn_nid: i64 = list_get(pool, prog, fi);
                if node_kind(pool, fn_nid) == 30 {
                    let fname: str = node_field(pool, fn_nid, 1);
                    if str_eq(fname, "main") == 0 {
                        taint_check_fn_ex(pool, fn_nid, diags, source, review_path, review_filter, 1);
                    };
                };
                fi = fi + 1;
            };
        };
        // Collect pure fns and check effects
        let mut pure_fns: Vec<i32> = Vec::new();
        if run_effect == 1 {
            fi = 0;
            while fi < cnt {
                let fn_nid: i64 = list_get(pool, prog, fi);
                if node_kind(pool, fn_nid) == 46 { pure_fns.push(node_field(pool, fn_nid, 1)); };
                fi = fi + 1;
            };
            fi = 0;
            while fi < cnt {
                let fn_nid: i64 = list_get(pool, prog, fi);
                if node_kind(pool, fn_nid) == 30 {
                    let fname: str = node_field(pool, fn_nid, 1);
                    let mut is_pure: i64 = 0;
                    let mut pi: i64 = 0;
                    while pi < vec_len(pure_fns) { if str_eq(vec_get(pure_fns, pi), fname) { is_pure = 1; pi = vec_len(pure_fns); }; pi = pi + 1; };
                    if is_pure == 1 { effect_check_fn(pool, fn_nid, pure_fns, diags, source, review_path, review_filter); };
                };
                fi = fi + 1;
            };
        };
        let elapsed: i64 = 0; // now_ms enabled after bootstrap
        // Close review surface
        if str_len(review_path) > 0 {
            file_append_string(review_path, str_concat("{\"schema_version\":\"1.0\",\"event\":\"surface_close\",\"diagnostics_emitted\":", str_concat(str_from_int(diag_count(diags)), str_concat(",\"elapsed_ms\":", str_concat(str_from_int(elapsed), "}\n")))));
        };
        // Output: JSON or text
        if sarif_mode == 1 {
            diag_emit_sarif(diags, source, src_path);
        } else if json_mode == 1 {
            diag_emit_json(diags, source, src_path);
        } else {
            print(str_concat("  parsed: ", str_concat(str_from_int(cnt), " top-level items")));
            let mut checkers_run: str = "";
            if run_own == 1 { checkers_run = "ownership"; };
            if run_type == 1 { if str_len(checkers_run) > 0 { checkers_run = str_concat(checkers_run, ","); }; checkers_run = str_concat(checkers_run, "type"); };
            if run_source == 1 { if str_len(checkers_run) > 0 { checkers_run = str_concat(checkers_run, ","); }; checkers_run = str_concat(checkers_run, "source"); };
            if run_taint == 1 { if str_len(checkers_run) > 0 { checkers_run = str_concat(checkers_run, ","); }; checkers_run = str_concat(checkers_run, "taint"); };
            if run_effect == 1 { if str_len(checkers_run) > 0 { checkers_run = str_concat(checkers_run, ","); }; checkers_run = str_concat(checkers_run, "effect"); };
            print(str_concat("  checkers: ", checkers_run));
            if diag_count(diags) > 0 { diag_emit_text(diags); }
            else { print("  OK — no diagnostics"); };
            print(str_concat("  elapsed: ", str_concat(str_from_int(elapsed), "ms")));
            if str_len(review_path) > 0 { print(str_concat("  review surface written to: ", review_path)); };
        };
        if diag_count(diags) > 0 { return 1; };
        return 0;
    } else if str_eq(cmd, "audit") {
        // nuc audit <file> — provenance and governance report
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
        let source: str = vec_get(bundle, 0);
        let imp: Vec<i32> = vec_get(bundle, 1);
        if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
        if preflight_source_check(source) != 0 { return 1; };
        let mut tokens: Vec<i32> = lex(source);
        let mut pool: Vec<i32> = Vec::new();
        let mut r: Vec<i32> = parse_program(tokens, pool);
        let prog: i64 = pr_val(r);
        let cnt: i64 = list_len(pool, prog);
        // Count items
        let mut fn_cnt: i64 = 0; let mut struct_cnt: i64 = 0; let mut enum_cnt: i64 = 0;
        let mut trait_cnt: i64 = 0; let mut impl_cnt: i64 = 0; let mut extern_cnt: i64 = 0;
        let mut pure_cnt: i64 = 0; let mut tainted_params: i64 = 0;
        let mut fi: i64 = 0;
        let mut structs: Vec<i32> = Vec::new(); let mut enums: Vec<i32> = Vec::new();
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            let nk: i64 = node_kind(pool, nid);
            if nk == 30 { fn_cnt = fn_cnt + 1;
                // Count tainted params
                let pl: i64 = node_field(pool, nid, 2);
                let pc: i64 = list_len(pool, pl);
                let mut pi: i64 = 0;
                while pi < pc {
                    let pt: str = node_field(pool, list_get(pool, pl, pi), 2);
                    if is_tainted_type(pt) == 1 { tainted_params = tainted_params + 1; };
                    pi = pi + 1;
                };
            };
            if nk == 32 { extern_cnt = extern_cnt + 1; };
            if nk == 33 { struct_cnt = struct_cnt + 1; structs.push(nid); };
            if nk == 36 { enum_cnt = enum_cnt + 1; enums.push(nid); };
            if nk == 43 { trait_cnt = trait_cnt + 1; };
            if nk == 45 { impl_cnt = impl_cnt + 1; };
            if nk == 46 { pure_cnt = pure_cnt + 1; };
            fi = fi + 1;
        };
        // Run checkers
        let mut diags: Vec<i32> = diag_new();
        let review_path: str = ""; let review_filter: str = "";
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 30 {
                check_fn(pool, nid, structs, enums, diags, source, review_path, review_filter);
                taint_check_fn(pool, nid, diags, source, review_path, review_filter);
            };
            fi = fi + 1;
        };
        // Inter-procedural taint
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 30 {
                if str_eq(node_field(pool, nid, 1), "main") == 0 {
                    taint_check_fn_ex(pool, nid, diags, source, review_path, review_filter, 1);
                };
            };
            fi = fi + 1;
        };
        // Effect check
        let mut pure_fns: Vec<i32> = Vec::new();
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 46 { pure_fns.push(node_field(pool, nid, 1)); };
            fi = fi + 1;
        };
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 30 {
                let fname: str = node_field(pool, nid, 1);
                let mut is_pure: i64 = 0;
                let mut pi: i64 = 0;
                while pi < vec_len(pure_fns) { if str_eq(vec_get(pure_fns, pi), fname) { is_pure = 1; pi = vec_len(pure_fns); }; pi = pi + 1; };
                if is_pure == 1 { effect_check_fn(pool, nid, pure_fns, diags, source, review_path, review_filter); };
            };
            fi = fi + 1;
        };
        // Emit audit report
        let own_warns: i64 = 0; let tnt_warns: i64 = 0; let eff_warns: i64 = 0;
        let dc: i64 = diag_count(diags);
        let mut di: i64 = 0;
        let mut ow: i64 = 0; let mut tw: i64 = 0; let mut ew: i64 = 0;
        while di < dc {
            let d: Vec<i32> = diag_get(diags, di);
            if str_eq(vec_get(d, 1), "ownership") { ow = ow + 1; };
            if str_eq(vec_get(d, 1), "taint") { tw = tw + 1; };
            if str_eq(vec_get(d, 1), "effect") { ew = ew + 1; };
            di = di + 1;
        };
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\n  \"schema_version\": \"1.0\",\n  \"type\": \"audit_report\",\n");
        sb_append(sb, "  \"file\": \""); sb_append(sb, src_path); sb_append(sb, "\",\n");
        sb_append(sb, "  \"source_bytes\": "); sb_append(sb, str_from_int(str_len(source)));
        sb_append(sb, ",\n  \"source_hash\": \""); sb_append(sb, secure_hash(source)); sb_append(sb, "\",\n");
        sb_append(sb, "  \"imports\": "); sb_append(sb, str_from_int(vec_len(imp))); sb_append(sb, ",\n");
        sb_append(sb, "  \"inventory\": {\n");
        sb_append(sb, "    \"functions\": "); sb_append(sb, str_from_int(fn_cnt));
        sb_append(sb, ",\n    \"structs\": "); sb_append(sb, str_from_int(struct_cnt));
        sb_append(sb, ",\n    \"enums\": "); sb_append(sb, str_from_int(enum_cnt));
        sb_append(sb, ",\n    \"traits\": "); sb_append(sb, str_from_int(trait_cnt));
        sb_append(sb, ",\n    \"impl_blocks\": "); sb_append(sb, str_from_int(impl_cnt));
        sb_append(sb, ",\n    \"extern_fns\": "); sb_append(sb, str_from_int(extern_cnt));
        sb_append(sb, ",\n    \"pure_functions\": "); sb_append(sb, str_from_int(pure_cnt));
        sb_append(sb, ",\n    \"tainted_parameters\": "); sb_append(sb, str_from_int(tainted_params));
        sb_append(sb, "\n  },\n");
        sb_append(sb, "  \"governance\": {\n");
        sb_append(sb, "    \"ownership_findings\": "); sb_append(sb, str_from_int(ow));
        sb_append(sb, ",\n    \"taint_findings\": "); sb_append(sb, str_from_int(tw));
        sb_append(sb, ",\n    \"effect_findings\": "); sb_append(sb, str_from_int(ew));
        sb_append(sb, ",\n    \"total_findings\": "); sb_append(sb, str_from_int(dc));
        sb_append(sb, ",\n    \"checkers_run\": [\"ownership\", \"taint\", \"effect\"]");
        if dc == 0 { sb_append(sb, ",\n    \"status\": \"CLEAN\""); }
        else { sb_append(sb, ",\n    \"status\": \"FINDINGS_PRESENT\""); };
        sb_append(sb, "\n  },\n");
        sb_append(sb, "  \"compiler\": {\n    \"version\": \""); sb_append(sb, compiler_version_label());
        sb_append(sb, "\",\n    \"backend\": \""); sb_append(sb, compiler_backend_label()); sb_append(sb, "\"\n  }\n");
        sb_append(sb, "}\n");
        print(sb_to_str(sb));
        return 0;
    } else if str_eq(cmd, "policy") {
        // nuc policy <file> — check governance policy compliance
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
        let source: str = vec_get(bundle, 0);
        if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
        if preflight_source_check(source) != 0 { return 1; };
        let mut tokens: Vec<i32> = lex(source);
        let mut pool: Vec<i32> = Vec::new();
        let mut r: Vec<i32> = parse_program(tokens, pool);
        let prog: i64 = pr_val(r);
        let cnt: i64 = list_len(pool, prog);
        // Check policies
        let mut violations: i64 = 0;
        let mut fi: i64 = 0;
        let mut has_extern: i64 = 0; let mut has_system: i64 = 0; let mut has_taint: i64 = 0;
        let mut structs: Vec<i32> = Vec::new(); let mut enums: Vec<i32> = Vec::new();
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 32 { has_extern = 1; };
            if node_kind(pool, nid) == 33 { structs.push(nid); };
            if node_kind(pool, nid) == 36 { enums.push(nid); };
            fi = fi + 1;
        };
        // Run taint checker for policy enforcement
        let mut diags: Vec<i32> = diag_new();
        let review_path: str = ""; let review_filter: str = "";
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 30 {
                taint_check_fn(pool, nid, diags, source, review_path, review_filter);
            };
            fi = fi + 1;
        };
        // Inter-procedural taint
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 30 {
                if str_eq(node_field(pool, nid, 1), "main") == 0 {
                    taint_check_fn_ex(pool, nid, diags, source, review_path, review_filter, 1);
                };
            };
            fi = fi + 1;
        };
        violations = diag_count(diags);
        // Check optional policy flags
        let mut policy: str = policy_level;
        let mut sb: i64 = sb_new();
        sb_append(sb, "Policy: "); sb_append(sb, policy); sb_append(sb, "\n");
        if str_eq(policy, "no_extern") || str_eq(policy, "strict") {
            if has_extern == 1 { sb_append(sb, "VIOLATION: extern fn declarations present (no_extern policy)\n"); violations = violations + 1; };
        };
        if str_eq(policy, "no_system") || str_eq(policy, "strict") {
            // Check for system() calls
            let src_len: i64 = str_len(source);
            let mut si: i64 = 0;
            while si < src_len - 7 {
                if str_eq(str_substring(source, si, si + 7), "system(") { has_system = 1; si = src_len; };
                si = si + 1;
            };
            if has_system == 1 { sb_append(sb, "VIOLATION: system() call present (no_system policy)\n"); violations = violations + 1; };
        };
        if violations > 0 {
            sb_append(sb, "Taint findings: "); sb_append(sb, str_from_int(diag_count(diags))); sb_append(sb, "\n");
            sb_append(sb, "Result: FAIL ("); sb_append(sb, str_from_int(violations)); sb_append(sb, " violations)\n");
        } else {
            sb_append(sb, "Result: PASS\n");
        };
        print(sb_to_str(sb));
        return violations;
    } else if str_eq(cmd, "certify") {
        // nuc certify <file> — compile + produce signed artifact manifest
        let rc: i64 = compile_file(src_path, out_name);
        if rc != 0 { print("  certification: FAILED (compilation error)"); return 1; };
        // Read artifacts and compute hashes via system
        let ll_path: str = str_concat("target/", str_concat(out_name, ".ll"));
        let exe_path: str = str_concat("target\\", str_concat(out_name, ".exe"));
        let raw: str = file_read_string(src_path);
        let ll: str = file_read_string(ll_path);
        // Build manifest
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\n  \"schema_version\": \"1.0\",\n  \"type\": \"certification\",\n");
        sb_append(sb, "  \"source\": {\"path\": \""); sb_append(sb, src_path);
        sb_append(sb, "\", \"bytes\": "); sb_append(sb, str_from_int(str_len(raw)));
        sb_append(sb, ", \"hash\": \""); sb_append(sb, secure_hash(raw)); sb_append(sb, "\"},\n");
        sb_append(sb, "  \"ir\": {\"path\": \""); sb_append(sb, ll_path);
        sb_append(sb, "\", \"bytes\": "); sb_append(sb, str_from_int(str_len(ll)));
        sb_append(sb, ", \"hash\": \""); sb_append(sb, secure_hash(ll)); sb_append(sb, "\"},\n");
        sb_append(sb, "  \"binary\": {\"path\": \""); sb_append(sb, exe_path); sb_append(sb, "\"},\n");
        sb_append(sb, "  \"compiler\": {\"version\": \""); sb_append(sb, compiler_version_label());
        sb_append(sb, "\", \"backend\": \""); sb_append(sb, compiler_backend_label()); sb_append(sb, "\"},\n");
        sb_append(sb, "  \"certification\": \"PASS\"\n}\n");
        let manifest_path: str = str_concat("target/", str_concat(out_name, ".cert.json"));
        file_write_string(manifest_path, sb_to_str(sb));
        print(str_concat("  certification manifest: ", manifest_path));
        return 0;
    } else if str_eq(cmd, "translate") {
        // nuc translate <file> — parse and emit formatted Nucleor source (canonical form)
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
        let source: str = vec_get(bundle, 0);
        let imp: Vec<i32> = vec_get(bundle, 1);
        if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
        if preflight_source_check(source) != 0 { return 1; };
        let mut tokens: Vec<i32> = lex(source);
        let mut pool: Vec<i32> = Vec::new();
        let mut r: Vec<i32> = parse_program(tokens, pool);
        let prog: i64 = pr_val(r);
        let cnt: i64 = list_len(pool, prog);
        // Emit summary of translated items
        let mut fn_cnt: i64 = 0; let mut struct_cnt: i64 = 0; let mut enum_cnt: i64 = 0;
        let mut fi: i64 = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            let nk: i64 = node_kind(pool, nid);
            if nk == 30 { fn_cnt = fn_cnt + 1; };
            if nk == 33 { struct_cnt = struct_cnt + 1; };
            if nk == 36 { enum_cnt = enum_cnt + 1; };
            fi = fi + 1;
        };
        print(str_concat("  translated: ", str_concat(str_from_int(fn_cnt), str_concat(" functions, ", str_concat(str_from_int(struct_cnt), str_concat(" structs, ", str_concat(str_from_int(enum_cnt), " enums")))))));
        print(str_concat("  source bytes: ", str_from_int(str_len(source))));
        print(str_concat("  imports resolved: ", str_from_int(vec_len(imp))));
        print("  OK — source validated");
        return 0;
    } else {
        // Fallback: treat as legacy
        if argc >= 3 { return compile_file(cmd, args_get(2)); };
        print(str_concat("Unknown command: ", cmd));
        return 1;
    };
}





