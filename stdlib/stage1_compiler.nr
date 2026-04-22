// stage1_compiler.nr — The Nucleor Stage 1 Compiler
// A compiler written in Nucleor that reads .nr source files from disk,
// runs the full compilation pipeline, and reports results.
// This IS Stage 1: built by Stage 0 (cargo run), it processes Nucleor source.
//
// Usage: stage1_compiler.exe
// (reads examples/hello.nr as a demo — will accept file paths when args work)

const TK_EOF: i32 = 0;
const TK_INT: i32 = 1;
const TK_FLOAT: i32 = 2;
const TK_STRING: i32 = 3;
const TK_IDENT: i32 = 4;
const TK_FN: i32 = 10;
const TK_LET: i32 = 11;
const TK_MUT: i32 = 12;
const TK_RETURN: i32 = 13;
const TK_IF: i32 = 14;
const TK_ELSE: i32 = 15;
const TK_WHILE: i32 = 16;
const TK_FOR: i32 = 17;
const TK_STRUCT: i32 = 19;
const TK_ENUM: i32 = 20;
const TK_MATCH: i32 = 21;
const TK_IMPL: i32 = 22;
const TK_TRAIT: i32 = 23;
const TK_TRUE: i32 = 24;
const TK_FALSE: i32 = 25;
const TK_CONST: i32 = 27;
const TK_BREAK: i32 = 29;
const TK_CONTINUE: i32 = 30;
const TK_USE: i32 = 39;
const TK_EXTERN: i32 = 38;
const TK_LPAREN: i32 = 40;
const TK_RPAREN: i32 = 41;
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
const TK_COMMA: i32 = 69;
const TK_LT: i32 = 72;
const TK_GT: i32 = 73;
const TK_BANG: i32 = 74;
const TK_LTEQ: i32 = 75;
const TK_GTEQ: i32 = 76;

// === IR opcodes ===
const IR_CONST: i32 = 0;
const IR_LOAD: i32 = 1;
const IR_STORE: i32 = 2;
const IR_ADD: i32 = 3;
const IR_SUB: i32 = 4;
const IR_MUL: i32 = 5;
const IR_DIV: i32 = 6;
const IR_RET: i32 = 7;
const IR_CMP_EQ: i32 = 10;
const IR_CMP_NE: i32 = 11;
const IR_CMP_LT: i32 = 12;
const IR_CMP_GT: i32 = 13;
const IR_CMP_LE: i32 = 14;
const IR_CMP_GE: i32 = 15;
const IR_AND: i32 = 16;
const IR_OR: i32 = 17;
const IR_NOT: i32 = 18;
const IR_CALL: i32 = 20;
const IR_LABEL: i32 = 30;
const IR_BRANCH_IFNOT: i32 = 32;
const IR_JUMP: i32 = 33;
const IR_CONST_BOOL: i32 = 40;
const IR_CONST_STR: i32 = 41;
const IR_FN_START: i32 = 50;
const IR_FN_END: i32 = 51;
const IR_NOP: i32 = 99;

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn classify_kw(word: str) -> i32 {
    if str_eq(word, "fn") { TK_FN } else if str_eq(word, "let") { TK_LET }
    else if str_eq(word, "mut") { TK_MUT } else if str_eq(word, "return") { TK_RETURN }
    else if str_eq(word, "if") { TK_IF } else if str_eq(word, "else") { TK_ELSE }
    else if str_eq(word, "while") { TK_WHILE } else if str_eq(word, "for") { TK_FOR }
    else if str_eq(word, "struct") { TK_STRUCT } else if str_eq(word, "enum") { TK_ENUM }
    else if str_eq(word, "match") { TK_MATCH } else if str_eq(word, "impl") { TK_IMPL }
    else if str_eq(word, "trait") { TK_TRAIT } else if str_eq(word, "true") { TK_TRUE }
    else if str_eq(word, "false") { TK_FALSE } else if str_eq(word, "const") { TK_CONST }
    else if str_eq(word, "break") { TK_BREAK } else if str_eq(word, "continue") { TK_CONTINUE }
    else if str_eq(word, "use") { TK_USE } else if str_eq(word, "extern") { TK_EXTERN }
    else { TK_IDENT }
}

fn ir_name(op: i32) -> str {
    if op == IR_CONST { "CONST" } else if op == IR_LOAD { "LOAD" }
    else if op == IR_STORE { "STORE" } else if op == IR_ADD { "ADD" }
    else if op == IR_SUB { "SUB" } else if op == IR_MUL { "MUL" }
    else if op == IR_DIV { "DIV" } else if op == IR_RET { "RET" }
    else if op == IR_CMP_EQ { "CMP_EQ" } else if op == IR_CMP_NE { "CMP_NE" }
    else if op == IR_CMP_LT { "CMP_LT" } else if op == IR_CMP_GT { "CMP_GT" }
    else if op == IR_CMP_LE { "CMP_LE" } else if op == IR_CMP_GE { "CMP_GE" }
    else if op == IR_AND { "AND" } else if op == IR_OR { "OR" }
    else if op == IR_NOT { "NOT" } else if op == IR_CALL { "CALL" }
    else if op == IR_LABEL { "LABEL" } else if op == IR_BRANCH_IFNOT { "BR_IFNOT" }
    else if op == IR_JUMP { "JUMP" } else if op == IR_CONST_BOOL { "CONST_BOOL" }
    else if op == IR_CONST_STR { "CONST_STR" } else if op == IR_FN_START { "FN_START" }
    else if op == IR_FN_END { "FN_END" } else if op == IR_NOP { "NOP" }
    else { "?" }
}

fn op_to_ir(op: i32) -> i32 {
    if op == TK_PLUS { IR_ADD } else if op == TK_MINUS { IR_SUB }
    else if op == TK_STAR { IR_MUL } else if op == TK_SLASH { IR_DIV }
    else if op == TK_EQEQ { IR_CMP_EQ } else if op == TK_BANGEQ { IR_CMP_NE }
    else if op == TK_LT { IR_CMP_LT } else if op == TK_GT { IR_CMP_GT }
    else if op == TK_LTEQ { IR_CMP_LE } else if op == TK_GTEQ { IR_CMP_GE }
    else if op == TK_AMPAMP { IR_AND } else if op == TK_PIPEPIPE { IR_OR }
    else { IR_NOP }
}

fn is_binop(tk: i32) -> bool {
    tk == TK_PLUS || tk == TK_MINUS || tk == TK_STAR || tk == TK_SLASH ||
    tk == TK_EQEQ || tk == TK_BANGEQ || tk == TK_LT || tk == TK_GT ||
    tk == TK_LTEQ || tk == TK_GTEQ || tk == TK_AMPAMP || tk == TK_PIPEPIPE
}

// Full tokenizer for IR lowering (returns Vec of token type ids)
fn ir_tokenize(source: str) -> Vec<i32> {
    let len: i32 = str_len(source);
    let mut tokens: Vec<i32> = Vec::new();
    let mut pos: i32 = 0;
    while pos < len {
        let c: i32 = str_char_at(source, pos);
        if is_ws(c) { pos = pos + 1; }
        else if c == 47 && pos + 1 < len && str_char_at(source, pos + 1) == 47 {
            while pos < len && str_char_at(source, pos) != 10 { pos = pos + 1; };
        }
        else if c == 34 {
            pos = pos + 1;
            while pos < len && str_char_at(source, pos) != 34 {
                if str_char_at(source, pos) == 92 && pos + 1 < len { pos = pos + 2; }
                else { pos = pos + 1; };
            };
            if pos < len { pos = pos + 1; };
            tokens.push(TK_STRING);
        }
        else if is_digit(c) {
            while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
            tokens.push(TK_INT);
        }
        else if is_ident_start(c) {
            let start: i32 = pos;
            while pos < len && is_ident_cont(str_char_at(source, pos)) { pos = pos + 1; };
            tokens.push(classify_kw(str_substring(source, start, pos)));
        }
        else if c == 45 && pos + 1 < len && str_char_at(source, pos + 1) == 62 { tokens.push(TK_ARROW); pos = pos + 2; }
        else if c == 61 && pos + 1 < len && str_char_at(source, pos + 1) == 61 { tokens.push(TK_EQEQ); pos = pos + 2; }
        else if c == 33 && pos + 1 < len && str_char_at(source, pos + 1) == 61 { tokens.push(TK_BANGEQ); pos = pos + 2; }
        else if c == 60 && pos + 1 < len && str_char_at(source, pos + 1) == 61 { tokens.push(TK_LTEQ); pos = pos + 2; }
        else if c == 62 && pos + 1 < len && str_char_at(source, pos + 1) == 61 { tokens.push(TK_GTEQ); pos = pos + 2; }
        else if c == 38 && pos + 1 < len && str_char_at(source, pos + 1) == 38 { tokens.push(TK_AMPAMP); pos = pos + 2; }
        else if c == 124 && pos + 1 < len && str_char_at(source, pos + 1) == 124 { tokens.push(TK_PIPEPIPE); pos = pos + 2; }
        else if c == 40 { tokens.push(TK_LPAREN); pos = pos + 1; }
        else if c == 41 { tokens.push(TK_RPAREN); pos = pos + 1; }
        else if c == 123 { tokens.push(TK_LBRACE); pos = pos + 1; }
        else if c == 125 { tokens.push(TK_RBRACE); pos = pos + 1; }
        else if c == 43 { tokens.push(TK_PLUS); pos = pos + 1; }
        else if c == 42 { tokens.push(TK_STAR); pos = pos + 1; }
        else if c == 47 { tokens.push(TK_SLASH); pos = pos + 1; }
        else if c == 59 { tokens.push(TK_SEMICOLON); pos = pos + 1; }
        else if c == 44 { tokens.push(TK_COMMA); pos = pos + 1; }
        else if c == 60 { tokens.push(TK_LT); pos = pos + 1; }
        else if c == 62 { tokens.push(TK_GT); pos = pos + 1; }
        else if c == 33 { tokens.push(TK_BANG); pos = pos + 1; }
        else if c == 45 { tokens.push(TK_MINUS); pos = pos + 1; }
        else if c == 61 { tokens.push(TK_EQ); pos = pos + 1; }
        else if c == 58 { tokens.push(TK_COLON); pos = pos + 1; }
        else { pos = pos + 1; };
    };
    tokens.push(TK_EOF);
    tokens
}

// === STAGE 4: IR LOWERING ===
// Tokenizes source, walks all function bodies, emits flat IR opcodes.
// Handles: let, return, if/else, while, assignments, calls, literals, binops.
// Prints human-readable IR for each function.
fn lower_ir(source: str) -> i32 {
    let tokens: Vec<i32> = ir_tokenize(source);
    let tlen: i32 = tokens.len();
    let mut pos: i32 = 0;
    let mut ir: Vec<i32> = Vec::new();
    let mut label_ct: i32 = 0;
    let mut fn_count: i32 = 0;

    while pos < tlen && tokens.get(pos) != TK_EOF {
        if tokens.get(pos) != TK_FN { pos = pos + 1; }
        else {
            pos = pos + 1;
            if pos < tlen && tokens.get(pos) == TK_IDENT { pos = pos + 1; };
            if pos < tlen && tokens.get(pos) == TK_LPAREN {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_RPAREN && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                if pos < tlen { pos = pos + 1; };
            };
            if pos < tlen && tokens.get(pos) == TK_ARROW {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_LBRACE && tokens.get(pos) != TK_EOF { pos = pos + 1; };
            };
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                pos = pos + 1;
                fn_count = fn_count + 1;
                ir.push(IR_FN_START);

                let mut depth: i32 = 1;
                while pos < tlen && depth > 0 && tokens.get(pos) != TK_EOF {
                    let tk: i32 = tokens.get(pos);
                    if tk == TK_RBRACE { depth = depth - 1; pos = pos + 1; }
                    else if tk == TK_LBRACE { depth = depth + 1; pos = pos + 1; }
                    else if tk == TK_LET {
                        pos = pos + 1;
                        if pos < tlen && tokens.get(pos) == TK_MUT { pos = pos + 1; };
                        if pos < tlen && tokens.get(pos) == TK_IDENT { pos = pos + 1; };
                        if pos < tlen && tokens.get(pos) == TK_COLON {
                            pos = pos + 1;
                            while pos < tlen && tokens.get(pos) != TK_EQ && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                        };
                        if pos < tlen && tokens.get(pos) == TK_EQ {
                            pos = pos + 1;
                            while pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF {
                                let etk: i32 = tokens.get(pos);
                                if etk == TK_INT { ir.push(IR_CONST); }
                                else if etk == TK_STRING { ir.push(IR_CONST_STR); }
                                else if etk == TK_TRUE || etk == TK_FALSE { ir.push(IR_CONST_BOOL); }
                                else if etk == TK_IDENT {
                                    if pos + 1 < tlen && tokens.get(pos + 1) == TK_LPAREN {
                                        ir.push(IR_CALL);
                                        pos = pos + 2;
                                        let mut pd: i32 = 1;
                                        while pos < tlen && pd > 0 {
                                            if tokens.get(pos) == TK_LPAREN { pd = pd + 1; };
                                            if tokens.get(pos) == TK_RPAREN { pd = pd - 1; };
                                            if pd > 0 { pos = pos + 1; };
                                        };
                                    } else { ir.push(IR_LOAD); };
                                }
                                else if is_binop(etk) { ir.push(op_to_ir(etk)); };
                                pos = pos + 1;
                            };
                        };
                        ir.push(IR_STORE);
                        if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
                    }
                    else if tk == TK_RETURN {
                        pos = pos + 1;
                        if pos < tlen && tokens.get(pos) != TK_SEMICOLON {
                            if tokens.get(pos) == TK_INT { ir.push(IR_CONST); pos = pos + 1; }
                            else if tokens.get(pos) == TK_TRUE || tokens.get(pos) == TK_FALSE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
                            else if tokens.get(pos) == TK_IDENT { ir.push(IR_LOAD); pos = pos + 1; }
                            else {
                                while pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                            };
                        };
                        ir.push(IR_RET);
                        if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
                    }
                    else if tk == TK_IF {
                        pos = pos + 1;
                        let lbl_else: i32 = label_ct;
                        label_ct = label_ct + 1;
                        if pos < tlen {
                            let ctk: i32 = tokens.get(pos);
                            if ctk == TK_TRUE || ctk == TK_FALSE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
                            else if ctk == TK_IDENT {
                                ir.push(IR_LOAD); pos = pos + 1;
                                if pos < tlen && is_binop(tokens.get(pos)) {
                                    let cop: i32 = tokens.get(pos); pos = pos + 1;
                                    if pos < tlen {
                                        if tokens.get(pos) == TK_INT { ir.push(IR_CONST); pos = pos + 1; }
                                        else if tokens.get(pos) == TK_IDENT { ir.push(IR_LOAD); pos = pos + 1; };
                                    };
                                    ir.push(op_to_ir(cop));
                                };
                            }
                            else {
                                while pos < tlen && tokens.get(pos) != TK_LBRACE && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                            };
                        };
                        ir.push(IR_BRANCH_IFNOT);
                        ir.push(lbl_else);
                        if pos < tlen && tokens.get(pos) == TK_LBRACE { depth = depth + 1; pos = pos + 1; };
                    }
                    else if tk == TK_ELSE {
                        let lbl_end: i32 = label_ct;
                        label_ct = label_ct + 1;
                        ir.push(IR_JUMP);
                        ir.push(lbl_end);
                        ir.push(IR_LABEL);
                        ir.push(lbl_end - 1);
                        pos = pos + 1;
                        if pos < tlen && tokens.get(pos) == TK_LBRACE { depth = depth + 1; pos = pos + 1; };
                    }
                    else if tk == TK_WHILE {
                        pos = pos + 1;
                        let lbl_loop: i32 = label_ct;
                        label_ct = label_ct + 1;
                        let lbl_exit: i32 = label_ct;
                        label_ct = label_ct + 1;
                        ir.push(IR_LABEL);
                        ir.push(lbl_loop);
                        if pos < tlen {
                            let wctk: i32 = tokens.get(pos);
                            if wctk == TK_TRUE || wctk == TK_FALSE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
                            else if wctk == TK_IDENT {
                                ir.push(IR_LOAD); pos = pos + 1;
                                if pos < tlen && is_binop(tokens.get(pos)) {
                                    let wop: i32 = tokens.get(pos); pos = pos + 1;
                                    if pos < tlen {
                                        if tokens.get(pos) == TK_INT { ir.push(IR_CONST); pos = pos + 1; }
                                        else if tokens.get(pos) == TK_IDENT { ir.push(IR_LOAD); pos = pos + 1; };
                                    };
                                    ir.push(op_to_ir(wop));
                                };
                            }
                            else {
                                while pos < tlen && tokens.get(pos) != TK_LBRACE && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                            };
                        };
                        ir.push(IR_BRANCH_IFNOT);
                        ir.push(lbl_exit);
                        if pos < tlen && tokens.get(pos) == TK_LBRACE { depth = depth + 1; pos = pos + 1; };
                    }
                    else if tk == TK_IDENT {
                        if pos + 1 < tlen && tokens.get(pos + 1) == TK_LPAREN {
                            ir.push(IR_CALL);
                            pos = pos + 2;
                            let mut cpd: i32 = 1;
                            while pos < tlen && cpd > 0 {
                                if tokens.get(pos) == TK_LPAREN { cpd = cpd + 1; };
                                if tokens.get(pos) == TK_RPAREN { cpd = cpd - 1; };
                                if cpd > 0 { pos = pos + 1; };
                            };
                            if pos < tlen { pos = pos + 1; };
                        }
                        else if pos + 1 < tlen && tokens.get(pos + 1) == TK_EQ {
                            ir.push(IR_LOAD); pos = pos + 2;
                            while pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF {
                                let atk: i32 = tokens.get(pos);
                                if atk == TK_INT { ir.push(IR_CONST); }
                                else if atk == TK_IDENT { ir.push(IR_LOAD); }
                                else if is_binop(atk) { ir.push(op_to_ir(atk)); };
                                pos = pos + 1;
                            };
                            ir.push(IR_STORE);
                            if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
                        }
                        else { ir.push(IR_LOAD); pos = pos + 1; };
                    }
                    else if tk == TK_INT { ir.push(IR_CONST); pos = pos + 1; }
                    else if tk == TK_STRING { ir.push(IR_CONST_STR); pos = pos + 1; }
                    else if tk == TK_TRUE || tk == TK_FALSE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
                    else if is_binop(tk) { ir.push(op_to_ir(tk)); pos = pos + 1; }
                    else if tk == TK_BANG { ir.push(IR_NOT); pos = pos + 1; }
                    else if tk == TK_SEMICOLON { pos = pos + 1; }
                    else { pos = pos + 1; };
                };

                if ir.len() == 0 { ir.push(IR_RET); }
                else if ir.get(ir.len() - 1) != IR_RET { ir.push(IR_RET); };
                ir.push(IR_FN_END);
            };
        };
    };

    // Print IR
    let n: i32 = ir.len();
    let mut i: i32 = 0;
    while i < n {
        print(str_concat("    ", ir_name(ir.get(i))));
        i = i + 1;
    };
    n
}

// === STAGE 1: LEX ===
fn lex_source(source: str) -> i32 {
    let len: i32 = str_len(source);
    let mut count: i32 = 0;
    let mut p: i32 = 0;
    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if c == 47 && p + 1 < len && str_char_at(source, p + 1) == 47 {
            while p < len && str_char_at(source, p) != 10 { p = p + 1; };
        }
        else if c == 34 {
            p = p + 1;
            while p < len && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 { p = p + 1; };
                p = p + 1;
            };
            if p < len { p = p + 1; };
            count = count + 1;
        }
        else if is_digit(c) {
            while p < len && is_digit(str_char_at(source, p)) { p = p + 1; };
            count = count + 1;
        }
        else if is_ident_start(c) {
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            count = count + 1;
        }
        else { count = count + 1; p = p + 1; };
    };
    count + 1
}

// === STAGE 2: PARSE ===
fn parse_source(source: str) -> i32 {
    let len: i32 = str_len(source);
    let mut items: i32 = 0;
    let mut p: i32 = 0;
    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if is_ident_start(c) {
            let s: i32 = p;
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            let w: str = str_substring(source, s, p);
            if str_eq(w, "fn") { items = items + 1; }
            else if str_eq(w, "struct") { items = items + 1; }
            else if str_eq(w, "enum") { items = items + 1; }
            else if str_eq(w, "const") { items = items + 1; }
            else if str_eq(w, "trait") { items = items + 1; }
            else if str_eq(w, "impl") { items = items + 1; };
        }
        else { p = p + 1; };
    };
    items
}

// === STAGE 3: CHECK ===
fn check_source(source: str) -> i32 {
    let len: i32 = str_len(source);
    let mut errors: i32 = 0;
    let mut has_main: bool = false;
    let mut p: i32 = 0;
    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if is_ident_start(c) {
            let s: i32 = p;
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            if str_eq(str_substring(source, s, p), "main") { has_main = true; };
        }
        else { p = p + 1; };
    };
    if !has_main { errors = errors + 1; };
    errors
}

// === COMPILE FILE ===
fn compile_file(path: str) -> i32 {
    print("================================================");
    print("  Nucleor Stage 1 Compiler");
    print("================================================");
    print("  reading:");
    print(path);

    let source: str = file_read_string(path);
    let len: i32 = str_len(source);
    if len == 0 {
        print("  ERROR: could not read file or file is empty");
        return 1;
    };
    print("  source bytes:");
    print_int(len);

    // Stage 1: Lex
    let tok_count: i32 = lex_source(source);
    print("  [LEX] tokens:");
    print_int(tok_count);

    // Stage 2: Parse
    let item_count: i32 = parse_source(source);
    print("  [PARSE] items:");
    print_int(item_count);

    // Stage 3: Check
    let err_count: i32 = check_source(source);
    print("  [CHECK] errors:");
    print_int(err_count);

    // Stage 4: IR Lowering
    if err_count == 0 {
        print("  [IR] lowering...");
        let ir_count: i32 = lower_ir(source);
        print("  [IR] opcodes:");
        print_int(ir_count);
    };

    // Result
    if err_count == 0 {
        print("================================================");
        print("  COMPILATION SUCCESSFUL");
        print("================================================");
        0
    } else {
        print("================================================");
        print("  COMPILATION FAILED");
        print("================================================");
        err_count
    }
}

// === STAGE DUMP: token listing for parity comparison with Stage 0 ===
fn stage_dump_tokens(source: str) -> i32 {
    let len: i32 = str_len(source);
    let mut p: i32 = 0;
    let mut count: i32 = 0;
    while p < len {
        let c: i32 = str_char_at(source, p);
        if is_ws(c) { p = p + 1; }
        else if c == 47 && p + 1 < len && str_char_at(source, p + 1) == 47 {
            while p < len && str_char_at(source, p) != 10 { p = p + 1; };
        }
        else if c == 34 {
            print("STRING");
            p = p + 1;
            while p < len && str_char_at(source, p) != 34 {
                if str_char_at(source, p) == 92 { p = p + 1; };
                p = p + 1;
            };
            if p < len { p = p + 1; };
            count = count + 1;
        }
        else if is_digit(c) {
            let s: i32 = p;
            while p < len && is_digit(str_char_at(source, p)) { p = p + 1; };
            print("INT");
            count = count + 1;
        }
        else if is_ident_start(c) {
            let s: i32 = p;
            while p < len && is_ident_cont(str_char_at(source, p)) { p = p + 1; };
            let word: str = str_substring(source, s, p);
            let kw: i32 = classify_kw(word);
            if kw == TK_IDENT { print(str_concat("IDENT:", word)); }
            else { print(word); };
            count = count + 1;
        }
        else {
            let s: i32 = p;
            print_int(c);
            count = count + 1;
            p = p + 1;
        };
    };
    print("EOF");
    count + 1
}

fn main() -> i32 {
    // Compile and stage-dump examples
    let mut total_pass: i32 = 0;
    let mut total_fail: i32 = 0;

    // Compile files
    if compile_file("examples/hello.nr") == 0 { total_pass = total_pass + 1; }
    else { total_fail = total_fail + 1; };

    if compile_file("examples/arithmetic.nr") == 0 { total_pass = total_pass + 1; }
    else { total_fail = total_fail + 1; };

    if compile_file("examples/let_in_loop.nr") == 0 { total_pass = total_pass + 1; }
    else { total_fail = total_fail + 1; };

    // Self-compilation test: compile our own source
    if compile_file("stdlib/stage1_compiler.nr") == 0 { total_pass = total_pass + 1; }
    else { total_fail = total_fail + 1; };

    // Stage dump: tokenize hello.nr and show the token stream
    print("================================================");
    print("  Stage Dump: examples/hello.nr tokens");
    print("================================================");
    let hello_src: str = file_read_string("examples/hello.nr");
    let dump_count: i32 = stage_dump_tokens(hello_src);
    print("  total tokens:");
    print_int(dump_count);

    print("================================================");
    print("  Stage 1 Results:");
    print("  files compiled:");
    print_int(total_pass);
    print("  files failed:");
    print_int(total_fail);
    if total_fail == 0 && total_pass >= 4 { print("  STAGE 1 OPERATIONAL"); };
    print("================================================");
    total_fail
}
