// nucleor_interp.nr — Nucleor source interpreter
// A Nucleor program that INTERPRETS other Nucleor programs.
// Milestone: Nucleor executing Nucleor.
// Supports: let bindings, arithmetic, comparisons, if/else, while, return.
// Uses qhash() for variable name hashing (no loops in main function).

const TK_EOF: i32 = 0;
const TK_INT: i32 = 1;
const TK_IDENT: i32 = 4;
const TK_FN: i32 = 10;
const TK_LET: i32 = 11;
const TK_MUT: i32 = 12;
const TK_RETURN: i32 = 13;
const TK_IF: i32 = 14;
const TK_ELSE: i32 = 15;
const TK_WHILE: i32 = 16;
const TK_TRUE: i32 = 24;
const TK_FALSE: i32 = 25;
const TK_BREAK: i32 = 29;
const TK_LBRACE: i32 = 42;
const TK_RBRACE: i32 = 43;
const TK_PLUS: i32 = 50;
const TK_MINUS: i32 = 51;
const TK_STAR: i32 = 52;
const TK_SLASH: i32 = 53;
const TK_EQ: i32 = 55;
const TK_EQEQ: i32 = 56;
const TK_BANGEQ: i32 = 57;
const TK_AMPAMP: i32 = 59;
const TK_PIPEPIPE: i32 = 60;
const TK_ARROW: i32 = 62;
const TK_COLON: i32 = 66;
const TK_SEMICOLON: i32 = 68;
const TK_LT: i32 = 72;
const TK_GT: i32 = 73;
const TK_LTEQ: i32 = 75;
const TK_GTEQ: i32 = 76;

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn classify_kw(word: str) -> i32 {
    if str_eq(word, "fn") { TK_FN } else if str_eq(word, "let") { TK_LET }
    else if str_eq(word, "mut") { TK_MUT } else if str_eq(word, "return") { TK_RETURN }
    else if str_eq(word, "if") { TK_IF } else if str_eq(word, "else") { TK_ELSE }
    else if str_eq(word, "while") { TK_WHILE } else if str_eq(word, "true") { TK_TRUE }
    else if str_eq(word, "false") { TK_FALSE } else if str_eq(word, "break") { TK_BREAK }
    else { TK_IDENT }
}

fn is_binop(tk: i32) -> bool {
    tk == TK_PLUS || tk == TK_MINUS || tk == TK_STAR || tk == TK_SLASH ||
    tk == TK_EQEQ || tk == TK_BANGEQ || tk == TK_LT || tk == TK_GT ||
    tk == TK_LTEQ || tk == TK_GTEQ || tk == TK_AMPAMP || tk == TK_PIPEPIPE
}

fn qhash(source: str, s: i32, e: i32) -> i32 {
    let c0: i32 = str_char_at(source, s);
    let mut c1: i32 = 0;
    if s + 1 < e { c1 = str_char_at(source, s + 1); };
    let mut ce: i32 = 0;
    if e - 1 > s { ce = str_char_at(source, e - 1); };
    c0 * 10000 + c1 * 100 + ce * 10 + (e - s)
}

fn parse_int(source: str, s: i32, e: i32) -> i32 {
    let mut v: i32 = 0;
    let mut i: i32 = s;
    while i < e { v = v * 10 + (str_char_at(source, i) - 48); i = i + 1; };
    v
}

fn apply_op(op: i32, a: i32, b: i32) -> i32 {
    if op == TK_PLUS { a + b } else if op == TK_MINUS { a - b }
    else if op == TK_STAR { a * b } else if op == TK_SLASH { a / b }
    else if op == TK_EQEQ { if a == b { 1 } else { 0 } }
    else if op == TK_BANGEQ { if a != b { 1 } else { 0 } }
    else if op == TK_LT { if a < b { 1 } else { 0 } }
    else if op == TK_GT { if a > b { 1 } else { 0 } }
    else if op == TK_LTEQ { if a <= b { 1 } else { 0 } }
    else if op == TK_GTEQ { if a >= b { 1 } else { 0 } }
    else if op == TK_AMPAMP { if a != 0 && b != 0 { 1 } else { 0 } }
    else if op == TK_PIPEPIPE { if a != 0 || b != 0 { 1 } else { 0 } }
    else { 0 }
}

fn tokenize(source: str) -> Vec<i32> {
    let len: i32 = str_len(source);
    let mut t: Vec<i32> = Vec::new();
    let mut p: i32 = 0;
    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if is_digit(c) {
            let s: i32 = p;
            while p < len && is_digit(str_char_at(source, p)) { p = p + 1; };
            t.push(TK_INT); t.push(s); t.push(p);
        }
        else if is_ident_start(c) {
            let s: i32 = p;
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            t.push(classify_kw(str_substring(source, s, p))); t.push(s); t.push(p);
        }
        else if c == 61 && p + 1 < len && str_char_at(source, p + 1) == 61 { t.push(TK_EQEQ); t.push(p); p = p + 2; t.push(p); }
        else if c == 33 && p + 1 < len && str_char_at(source, p + 1) == 61 { t.push(TK_BANGEQ); t.push(p); p = p + 2; t.push(p); }
        else if c == 60 && p + 1 < len && str_char_at(source, p + 1) == 61 { t.push(TK_LTEQ); t.push(p); p = p + 2; t.push(p); }
        else if c == 62 && p + 1 < len && str_char_at(source, p + 1) == 61 { t.push(TK_GTEQ); t.push(p); p = p + 2; t.push(p); }
        else if c == 45 && p + 1 < len && str_char_at(source, p + 1) == 62 { t.push(TK_ARROW); t.push(p); p = p + 2; t.push(p); }
        else {
            let s: i32 = p;
            if c == 40 { t.push(40); } else if c == 41 { t.push(41); }
            else if c == 123 { t.push(TK_LBRACE); } else if c == 125 { t.push(TK_RBRACE); }
            else if c == 43 { t.push(TK_PLUS); } else if c == 45 { t.push(TK_MINUS); }
            else if c == 42 { t.push(TK_STAR); } else if c == 47 { t.push(TK_SLASH); }
            else if c == 59 { t.push(TK_SEMICOLON); } else if c == 61 { t.push(TK_EQ); }
            else if c == 58 { t.push(TK_COLON); } else if c == 60 { t.push(TK_LT); }
            else if c == 62 { t.push(TK_GT); }
            else { p = p + 1; };
            if c != 0 { t.push(s); p = p + 1; t.push(p); };
        };
    };
    t.push(TK_EOF); t.push(0); t.push(0);
    t
}

fn interpret(source: str) -> i32 {
    let tokens: Vec<i32> = tokenize(source);
    let tlen: i32 = tokens.len() / 3;
    let mut ti: i32 = 0;

    // Find main body
    while ti < tlen && tokens.get(ti * 3) != TK_EOF {
        if tokens.get(ti * 3) == TK_FN {
            ti = ti + 1;
            if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                if str_eq(str_substring(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2)), "main") {
                    while ti < tlen && tokens.get(ti * 3) != TK_LBRACE { ti = ti + 1; };
                    if ti < tlen { ti = ti + 1; break; };
                };
            };
        };
        ti = ti + 1;
    };

    let mut vars: Vec<i32> = Vec::new();
    let mut vc: i32 = 0;
    let mut result: i32 = 0;
    let mut done: bool = false;
    let mut depth: i32 = 1;

    while ti < tlen && depth > 0 && !done {
        let tk: i32 = tokens.get(ti * 3);
        if tk == TK_EOF { break; };

        if tk == TK_RBRACE { depth = depth - 1; ti = ti + 1; }
        else if tk == TK_LBRACE { depth = depth + 1; ti = ti + 1; }
        else if tk == TK_SEMICOLON { ti = ti + 1; }
        else if tk == TK_RETURN {
            ti = ti + 1;
            if ti < tlen {
                let rtk: i32 = tokens.get(ti * 3);
                if rtk == TK_INT { result = parse_int(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2)); }
                else if rtk == TK_TRUE { result = 1; }
                else if rtk == TK_FALSE { result = 0; }
                else if rtk == TK_IDENT {
                    let rh: i32 = qhash(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                    let mut ri: i32 = 0;
                    while ri < vc { if vars.get(ri * 2) == rh { result = vars.get(ri * 2 + 1); }; ri = ri + 1; };
                };
            };
            done = true;
        }
        else if tk == TK_LET {
            ti = ti + 1;
            if ti < tlen && tokens.get(ti * 3) == TK_MUT { ti = ti + 1; };
            let mut vh: i32 = 0;
            if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                vh = qhash(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                ti = ti + 1;
            };
            while ti < tlen && tokens.get(ti * 3) != TK_EQ && tokens.get(ti * 3) != TK_SEMICOLON { ti = ti + 1; };
            let mut lv: i32 = 0;
            if ti < tlen && tokens.get(ti * 3) == TK_EQ {
                ti = ti + 1;
                if ti < tlen {
                    if tokens.get(ti * 3) == TK_INT { lv = parse_int(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2)); ti = ti + 1; }
                    else if tokens.get(ti * 3) == TK_TRUE { lv = 1; ti = ti + 1; }
                    else if tokens.get(ti * 3) == TK_FALSE { lv = 0; ti = ti + 1; }
                    else if tokens.get(ti * 3) == TK_IDENT {
                        let lh: i32 = qhash(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                        let mut li: i32 = 0;
                        while li < vc { if vars.get(li * 2) == lh { lv = vars.get(li * 2 + 1); }; li = li + 1; };
                        ti = ti + 1;
                    };
                    if ti < tlen && is_binop(tokens.get(ti * 3)) {
                        let bop: i32 = tokens.get(ti * 3); ti = ti + 1;
                        let mut rv: i32 = 0;
                        if ti < tlen {
                            if tokens.get(ti * 3) == TK_INT { rv = parse_int(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2)); ti = ti + 1; }
                            else if tokens.get(ti * 3) == TK_IDENT {
                                let rh2: i32 = qhash(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                                let mut ri2: i32 = vc - 1;
                                while ri2 >= 0 { if vars.get(ri2 * 2) == rh2 { rv = vars.get(ri2 * 2 + 1); }; ri2 = ri2 - 1; };
                                ti = ti + 1;
                            };
                        };
                        lv = apply_op(bop, lv, rv);
                    };
                };
            };
            vars.push(vh); vars.push(lv); vc = vc + 1;
            while ti < tlen && tokens.get(ti * 3) != TK_SEMICOLON { ti = ti + 1; };
            if ti < tlen { ti = ti + 1; };
        }
        else if tk == TK_IF {
            ti = ti + 1;
            let mut cv: i32 = 0;
            if ti < tlen {
                if tokens.get(ti * 3) == TK_TRUE { cv = 1; ti = ti + 1; }
                else if tokens.get(ti * 3) == TK_FALSE { cv = 0; ti = ti + 1; }
                else if tokens.get(ti * 3) == TK_IDENT {
                    let ch: i32 = qhash(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                    let mut ci: i32 = 0;
                    while ci < vc { if vars.get(ci * 2) == ch { cv = vars.get(ci * 2 + 1); }; ci = ci + 1; };
                    ti = ti + 1;
                    if ti < tlen && is_binop(tokens.get(ti * 3)) {
                        let cop: i32 = tokens.get(ti * 3); ti = ti + 1;
                        let mut crv: i32 = 0;
                        if ti < tlen {
                            if tokens.get(ti * 3) == TK_INT { crv = parse_int(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2)); ti = ti + 1; }
                            else if tokens.get(ti * 3) == TK_IDENT {
                                let crh: i32 = qhash(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                                let mut cri: i32 = 0;
                                while cri < vc { if vars.get(cri * 2) == crh { crv = vars.get(cri * 2 + 1); }; cri = cri + 1; };
                                ti = ti + 1;
                            };
                        };
                        cv = apply_op(cop, cv, crv);
                    };
                };
            };
            if cv != 0 {
                if ti < tlen && tokens.get(ti * 3) == TK_LBRACE { depth = depth + 1; ti = ti + 1; };
            } else {
                if ti < tlen && tokens.get(ti * 3) == TK_LBRACE {
                    ti = ti + 1;
                    let mut sd: i32 = 1;
                    while ti < tlen && sd > 0 {
                        if tokens.get(ti * 3) == TK_LBRACE { sd = sd + 1; };
                        if tokens.get(ti * 3) == TK_RBRACE { sd = sd - 1; };
                        if sd > 0 { ti = ti + 1; };
                    };
                    if ti < tlen { ti = ti + 1; };
                };
                if ti < tlen && tokens.get(ti * 3) == TK_ELSE {
                    ti = ti + 1;
                    if ti < tlen && tokens.get(ti * 3) == TK_LBRACE { depth = depth + 1; ti = ti + 1; };
                };
            };
        }
        else if tk == TK_ELSE {
            ti = ti + 1;
            if ti < tlen && tokens.get(ti * 3) == TK_LBRACE {
                ti = ti + 1;
                let mut sd2: i32 = 1;
                while ti < tlen && sd2 > 0 {
                    if tokens.get(ti * 3) == TK_LBRACE { sd2 = sd2 + 1; };
                    if tokens.get(ti * 3) == TK_RBRACE { sd2 = sd2 - 1; };
                    if sd2 > 0 { ti = ti + 1; };
                };
                if ti < tlen { ti = ti + 1; };
            };
        }
        else if tk == TK_WHILE {
            let ls: i32 = ti;
            let mut running: bool = true;
            while running {
                ti = ls + 1;
                let mut wv: i32 = 0;
                if ti < tlen && tokens.get(ti * 3) == TK_IDENT {
                    let wh: i32 = qhash(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                    let mut wi: i32 = 0;
                    while wi < vc { if vars.get(wi * 2) == wh { wv = vars.get(wi * 2 + 1); }; wi = wi + 1; };
                    ti = ti + 1;
                    if ti < tlen && is_binop(tokens.get(ti * 3)) {
                        let wop: i32 = tokens.get(ti * 3); ti = ti + 1;
                        let mut wrv: i32 = 0;
                        if ti < tlen {
                            if tokens.get(ti * 3) == TK_INT { wrv = parse_int(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2)); ti = ti + 1; }
                            else if tokens.get(ti * 3) == TK_IDENT {
                                let wrh: i32 = qhash(source, tokens.get(ti * 3 + 1), tokens.get(ti * 3 + 2));
                                let mut wri: i32 = 0;
                                while wri < vc { if vars.get(wri * 2) == wrh { wrv = vars.get(wri * 2 + 1); }; wri = wri + 1; };
                                ti = ti + 1;
                            };
                        };
                        wv = apply_op(wop, wv, wrv);
                    };
                };
                if wv == 0 { running = false; }
                else if ti < tlen && tokens.get(ti * 3) == TK_LBRACE {
                    ti = ti + 1;
                    let mut wd: i32 = 1;
                    while ti < tlen && wd > 0 {
                        let wt: i32 = tokens.get(ti * 3);
                        if wt == TK_RBRACE { wd = wd - 1; ti = ti + 1; }
                        else if wt == TK_LBRACE { wd = wd + 1; ti = ti + 1; }
                        else if wt == TK_IDENT && ti + 1 < tlen && tokens.get((ti+1)*3) == TK_EQ {
                            let ah: i32 = qhash(source, tokens.get(ti*3+1), tokens.get(ti*3+2));
                            ti = ti + 2;
                            let mut av: i32 = 0;
                            if ti < tlen {
                                if tokens.get(ti*3) == TK_INT { av = parse_int(source, tokens.get(ti*3+1), tokens.get(ti*3+2)); ti = ti + 1; }
                                else if tokens.get(ti*3) == TK_IDENT {
                                    let avh: i32 = qhash(source, tokens.get(ti*3+1), tokens.get(ti*3+2));
                                    let mut avi: i32 = 0;
                                    while avi < vc { if vars.get(avi*2) == avh { av = vars.get(avi*2+1); }; avi = avi + 1; };
                                    ti = ti + 1;
                                };
                                if ti < tlen && is_binop(tokens.get(ti*3)) {
                                    let aop: i32 = tokens.get(ti*3); ti = ti + 1;
                                    let mut arv: i32 = 0;
                                    if ti < tlen {
                                        if tokens.get(ti*3) == TK_INT { arv = parse_int(source, tokens.get(ti*3+1), tokens.get(ti*3+2)); ti = ti + 1; }
                                        else if tokens.get(ti*3) == TK_IDENT {
                                            let arh: i32 = qhash(source, tokens.get(ti*3+1), tokens.get(ti*3+2));
                                            let mut ari: i32 = 0;
                                            while ari < vc { if vars.get(ari*2) == arh { arv = vars.get(ari*2+1); }; ari = ari + 1; };
                                            ti = ti + 1;
                                        };
                                    };
                                    av = apply_op(aop, av, arv);
                                };
                            };
                            vars.push(ah); vars.push(av); vc = vc + 1;
                            while ti < tlen && tokens.get(ti*3) != TK_SEMICOLON { ti = ti + 1; };
                            if ti < tlen { ti = ti + 1; };
                        }
                        else { ti = ti + 1; };
                    };
                };
            };
            while ti < tlen && tokens.get(ti * 3) != TK_LBRACE { ti = ti + 1; };
            if ti < tlen && tokens.get(ti * 3) == TK_LBRACE {
                ti = ti + 1;
                let mut sd3: i32 = 1;
                while ti < tlen && sd3 > 0 {
                    if tokens.get(ti*3) == TK_LBRACE { sd3 = sd3 + 1; };
                    if tokens.get(ti*3) == TK_RBRACE { sd3 = sd3 - 1; };
                    if sd3 > 0 { ti = ti + 1; };
                };
                if ti < tlen { ti = ti + 1; };
            };
        }
        else if tk == TK_IDENT && ti + 1 < tlen && tokens.get((ti+1)*3) == TK_EQ {
            let ah2: i32 = qhash(source, tokens.get(ti*3+1), tokens.get(ti*3+2));
            ti = ti + 2;
            let mut av2: i32 = 0;
            if ti < tlen {
                if tokens.get(ti*3) == TK_INT { av2 = parse_int(source, tokens.get(ti*3+1), tokens.get(ti*3+2)); ti = ti + 1; }
                else if tokens.get(ti*3) == TK_IDENT {
                    let avh2: i32 = qhash(source, tokens.get(ti*3+1), tokens.get(ti*3+2));
                    let mut avi2: i32 = 0;
                    while avi2 < vc { if vars.get(avi2*2) == avh2 { av2 = vars.get(avi2*2+1); }; avi2 = avi2 + 1; };
                    ti = ti + 1;
                };
                if ti < tlen && is_binop(tokens.get(ti*3)) {
                    let aop2: i32 = tokens.get(ti*3); ti = ti + 1;
                    let mut arv2: i32 = 0;
                    if ti < tlen {
                        if tokens.get(ti*3) == TK_INT { arv2 = parse_int(source, tokens.get(ti*3+1), tokens.get(ti*3+2)); ti = ti + 1; };
                    };
                    av2 = apply_op(aop2, av2, arv2);
                };
            };
            vars.push(ah2); vars.push(av2); vc = vc + 1;
            while ti < tlen && tokens.get(ti*3) != TK_SEMICOLON { ti = ti + 1; };
            if ti < tlen { ti = ti + 1; };
        }
        else if tk == TK_INT {
            result = parse_int(source, tokens.get(ti*3+1), tokens.get(ti*3+2)); ti = ti + 1;
            // Handle trailing binop: INT OP VALUE
            if ti < tlen && is_binop(tokens.get(ti*3)) {
                let top: i32 = tokens.get(ti*3); ti = ti + 1;
                let mut trv: i32 = 0;
                if ti < tlen && tokens.get(ti*3) == TK_INT { trv = parse_int(source, tokens.get(ti*3+1), tokens.get(ti*3+2)); ti = ti + 1; }
                else if ti < tlen && tokens.get(ti*3) == TK_IDENT {
                    let trh: i32 = qhash(source, tokens.get(ti*3+1), tokens.get(ti*3+2));
                    let mut tri: i32 = 0;
                    while tri < vc { if vars.get(tri*2) == trh { trv = vars.get(tri*2+1); }; tri = tri + 1; };
                    ti = ti + 1;
                };
                result = apply_op(top, result, trv);
            };
        }
        else if tk == TK_IDENT {
            let rh3: i32 = qhash(source, tokens.get(ti*3+1), tokens.get(ti*3+2));
            let mut ri3: i32 = 0;
            while ri3 < vc { if vars.get(ri3*2) == rh3 { result = vars.get(ri3*2+1); }; ri3 = ri3 + 1; };
            ti = ti + 1;
            // Handle trailing binop: IDENT OP VALUE
            if ti < tlen && is_binop(tokens.get(ti*3)) {
                let top2: i32 = tokens.get(ti*3); ti = ti + 1;
                let mut trv2: i32 = 0;
                if ti < tlen && tokens.get(ti*3) == TK_INT { trv2 = parse_int(source, tokens.get(ti*3+1), tokens.get(ti*3+2)); ti = ti + 1; }
                else if ti < tlen && tokens.get(ti*3) == TK_IDENT {
                    let trh2: i32 = qhash(source, tokens.get(ti*3+1), tokens.get(ti*3+2));
                    let mut tri2: i32 = 0;
                    while tri2 < vc { if vars.get(tri2*2) == trh2 { trv2 = vars.get(tri2*2+1); }; tri2 = tri2 + 1; };
                    ti = ti + 1;
                };
                result = apply_op(top2, result, trv2);
            };
        }
        else if tk == TK_TRUE { result = 1; ti = ti + 1; }
        else if tk == TK_FALSE { result = 0; ti = ti + 1; }
        else { ti = ti + 1; };
    };
    result
}

fn t1() -> i32 { let r: i32 = interpret("fn main() -> i32 { 42 }"); if r == 42 { print("PASS: 42"); 0 } else { print("FAIL 42"); print_int(r); 1 } }
fn t2() -> i32 { let r: i32 = interpret("fn main() -> i32 { return 99; }"); if r == 99 { print("PASS: ret 99"); 0 } else { print("FAIL ret"); 1 } }
fn t3() -> i32 { let r: i32 = interpret("fn main() -> i32 { let a: i32 = 3; let b: i32 = 4; a + b }"); if r == 7 { print("PASS: 3+4=7"); 0 } else { print("FAIL 3+4"); print_int(r); 1 } }
fn t4() -> i32 { let r: i32 = interpret("fn main() -> i32 { let x: i32 = 6; let y: i32 = 7; x * y }"); if r == 42 { print("PASS: 6*7=42"); 0 } else { print("FAIL 6*7"); print_int(r); 1 } }
fn t5() -> i32 { let r: i32 = interpret("fn main() -> i32 { if true { 1 } else { 0 } }"); if r == 1 { print("PASS: if true"); 0 } else { print("FAIL if"); 1 } }
fn t6() -> i32 { let r: i32 = interpret("fn main() -> i32 { if false { 1 } else { 0 } }"); if r == 0 { print("PASS: if false"); 0 } else { print("FAIL if"); 1 } }
fn t7() -> i32 { let r: i32 = interpret("fn main() -> i32 { let x: i32 = 5; if x > 3 { 1 } else { 0 } }"); if r == 1 { print("PASS: x>3"); 0 } else { print("FAIL x>3"); 1 } }
fn t8() -> i32 { let r: i32 = interpret("fn main() -> i32 { let mut i: i32 = 0; while i < 5 { i = i + 1; }; i }"); if r == 5 { print("PASS: while=5"); 0 } else { print("FAIL while"); print_int(r); 1 } }
fn t9() -> i32 { let r: i32 = interpret("fn main() -> i32 { let mut s: i32 = 0; let mut i: i32 = 1; while i <= 10 { s = s + i; i = i + 1; }; s }"); if r == 55 { print("PASS: sum=55"); 0 } else { print("FAIL sum"); print_int(r); 1 } }
fn t10() -> i32 { let r: i32 = interpret("fn main() -> i32 { let a: i32 = 10; let b: i32 = a - 3; b }"); if r == 7 { print("PASS: 10-3=7"); 0 } else { print("FAIL 10-3"); print_int(r); 1 } }

fn main() -> i32 {
    print("========================================");
    print("  Nucleor Interpreter (Nucleor-on-Nucleor)");
    print("========================================");
    t1(); t2(); t3(); t4(); t5(); t6(); t7(); t8(); t9(); t10();
    print("========================================");
    print("  INTERPRETER COMPLETE");
    print("========================================");
    0
}
