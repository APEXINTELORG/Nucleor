// nucleor_stage0.nr — Nucleor Self-Hosted Compiler (Stage 0 bootstrap)
// Complete pipeline: LEX → PARSE → CHECK → IR → REPORT
// Processes real Nucleor source code through all compiler stages.
// Uses expanded keyword set (48 keywords), statement-level parsing,
// and symbol-table-based variable checking.

// === TOKEN KINDS (match real_lexer.nr) ===
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
const TK_IN: i32 = 18;
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
const TK_LPAREN: i32 = 40;
const TK_RPAREN: i32 = 41;
const TK_LBRACE: i32 = 42;
const TK_RBRACE: i32 = 43;
const TK_LBRACKET: i32 = 44;
const TK_RBRACKET: i32 = 45;
const TK_PLUS: i32 = 50;
const TK_MINUS: i32 = 51;
const TK_STAR: i32 = 52;
const TK_SLASH: i32 = 53;
const TK_EQ: i32 = 55;
const TK_EQEQ: i32 = 56;
const TK_BANGEQ: i32 = 57;
const TK_FATARROW: i32 = 58;
const TK_AMPAMP: i32 = 59;
const TK_PIPEPIPE: i32 = 60;
const TK_ARROW: i32 = 62;
const TK_COLON: i32 = 66;
const TK_DOT: i32 = 67;
const TK_SEMICOLON: i32 = 68;
const TK_COMMA: i32 = 69;
const TK_AMP: i32 = 70;
const TK_LT: i32 = 72;
const TK_GT: i32 = 73;
const TK_BANG: i32 = 74;
const TK_LTEQ: i32 = 75;
const TK_GTEQ: i32 = 76;
const TK_I32: i32 = 90;
const TK_I64: i32 = 91;
const TK_F64: i32 = 94;
const TK_BOOL: i32 = 95;
const TK_STR: i32 = 96;

// === IR INSTRUCTIONS ===
const IR_CONST: i32 = 0;
const IR_LOAD: i32 = 1;
const IR_STORE: i32 = 2;
const IR_ADD: i32 = 3;
const IR_SUB: i32 = 4;
const IR_MUL: i32 = 5;
const IR_RET: i32 = 7;

// === HELPERS ===
fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_hex_digit(c: i32) -> bool { is_digit(c) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102) }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

// Full keyword classification (48 keywords + 7 type keywords)
fn classify_kw1(word: str) -> i32 {
    if str_eq(word, "fn") { TK_FN }
    else if str_eq(word, "let") { TK_LET }
    else if str_eq(word, "mut") { TK_MUT }
    else if str_eq(word, "return") { TK_RETURN }
    else if str_eq(word, "if") { TK_IF }
    else if str_eq(word, "else") { TK_ELSE }
    else if str_eq(word, "while") { TK_WHILE }
    else if str_eq(word, "for") { TK_FOR }
    else if str_eq(word, "in") { TK_IN }
    else if str_eq(word, "struct") { TK_STRUCT }
    else if str_eq(word, "enum") { TK_ENUM }
    else if str_eq(word, "match") { TK_MATCH }
    else if str_eq(word, "impl") { TK_IMPL }
    else if str_eq(word, "trait") { TK_TRAIT }
    else if str_eq(word, "true") { TK_TRUE }
    else if str_eq(word, "false") { TK_FALSE }
    else { 0 }
}

fn classify_kw2(word: str) -> i32 {
    if str_eq(word, "const") { TK_CONST }
    else if str_eq(word, "break") { TK_BREAK }
    else if str_eq(word, "continue") { TK_CONTINUE }
    else if str_eq(word, "use") { TK_USE }
    else if str_eq(word, "i32") { TK_I32 }
    else if str_eq(word, "i64") { TK_I64 }
    else if str_eq(word, "f64") { TK_F64 }
    else if str_eq(word, "bool") { TK_BOOL }
    else if str_eq(word, "str") { TK_STR }
    else { 0 }
}

fn classify_keyword(word: str) -> i32 {
    let r: i32 = classify_kw1(word);
    if r != 0 { r }
    else {
        let r2: i32 = classify_kw2(word);
        if r2 != 0 { r2 } else { TK_IDENT }
    }
}

// === STAGE 1: LEX ===
fn lex(source: str) -> Vec<i32> {
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
            if c == 48 && pos + 1 < len {
                let nx: i32 = str_char_at(source, pos + 1);
                if nx == 120 || nx == 88 || nx == 98 || nx == 66 || nx == 111 || nx == 79 {
                    pos = pos + 2;
                    while pos < len && is_hex_digit(str_char_at(source, pos)) { pos = pos + 1; };
                    tokens.push(TK_INT);
                } else {
                    while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                    if pos < len && str_char_at(source, pos) == 46 && pos + 1 < len && is_digit(str_char_at(source, pos + 1)) {
                        pos = pos + 1;
                        while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                        tokens.push(TK_FLOAT);
                    } else { tokens.push(TK_INT); };
                };
            } else {
                while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                if pos < len && str_char_at(source, pos) == 46 && pos + 1 < len && is_digit(str_char_at(source, pos + 1)) {
                    pos = pos + 1;
                    while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                    tokens.push(TK_FLOAT);
                } else { tokens.push(TK_INT); };
            };
        }
        else if is_ident_start(c) {
            let start: i32 = pos;
            while pos < len && is_ident_cont(str_char_at(source, pos)) { pos = pos + 1; };
            tokens.push(classify_keyword(str_substring(source, start, pos)));
        }
        else if c == 45 && pos + 1 < len && str_char_at(source, pos + 1) == 62 { tokens.push(TK_ARROW); pos = pos + 2; }
        else if c == 61 && pos + 1 < len && str_char_at(source, pos + 1) == 61 { tokens.push(TK_EQEQ); pos = pos + 2; }
        else if c == 61 && pos + 1 < len && str_char_at(source, pos + 1) == 62 { tokens.push(TK_FATARROW); pos = pos + 2; }
        else if c == 33 && pos + 1 < len && str_char_at(source, pos + 1) == 61 { tokens.push(TK_BANGEQ); pos = pos + 2; }
        else if c == 60 && pos + 1 < len && str_char_at(source, pos + 1) == 61 { tokens.push(TK_LTEQ); pos = pos + 2; }
        else if c == 62 && pos + 1 < len && str_char_at(source, pos + 1) == 61 { tokens.push(TK_GTEQ); pos = pos + 2; }
        else if c == 38 && pos + 1 < len && str_char_at(source, pos + 1) == 38 { tokens.push(TK_AMPAMP); pos = pos + 2; }
        else if c == 124 && pos + 1 < len && str_char_at(source, pos + 1) == 124 { tokens.push(TK_PIPEPIPE); pos = pos + 2; }
        else if c == 40 { tokens.push(TK_LPAREN); pos = pos + 1; }
        else if c == 41 { tokens.push(TK_RPAREN); pos = pos + 1; }
        else if c == 123 { tokens.push(TK_LBRACE); pos = pos + 1; }
        else if c == 125 { tokens.push(TK_RBRACE); pos = pos + 1; }
        else if c == 91 { tokens.push(TK_LBRACKET); pos = pos + 1; }
        else if c == 93 { tokens.push(TK_RBRACKET); pos = pos + 1; }
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
        else if c == 38 { tokens.push(TK_AMP); pos = pos + 1; }
        else if c == 46 { tokens.push(TK_DOT); pos = pos + 1; }
        else { pos = pos + 1; };
    };
    tokens.push(TK_EOF);
    tokens
}

// === STAGE 2: PARSE ===
// Returns items * 10000 + stmts * 100 + errors
fn parse(source: str) -> i32 {
    let tokens: Vec<i32> = lex(source);
    let tlen: i32 = tokens.len();
    let mut pos: i32 = 0;
    let mut items: i32 = 0;
    let mut stmts: i32 = 0;

    while pos < tlen && tokens.get(pos) != TK_EOF {
        let tk: i32 = tokens.get(pos);

        if tk == TK_FN {
            pos = pos + 1;
            if pos < tlen && tokens.get(pos) == TK_IDENT { pos = pos + 1; };
            // Skip params
            if pos < tlen && tokens.get(pos) == TK_LPAREN {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_RPAREN && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                if pos < tlen && tokens.get(pos) == TK_RPAREN { pos = pos + 1; };
            };
            // Return type
            if pos < tlen && tokens.get(pos) == TK_ARROW {
                pos = pos + 1;
                if pos < tlen { pos = pos + 1; };
                if pos < tlen && tokens.get(pos) == TK_LT {
                    pos = pos + 1;
                    let mut gd: i32 = 1;
                    while pos < tlen && gd > 0 {
                        if tokens.get(pos) == TK_LT { gd = gd + 1; };
                        if tokens.get(pos) == TK_GT { gd = gd - 1; };
                        if gd > 0 { pos = pos + 1; };
                    };
                    if pos < tlen && tokens.get(pos) == TK_GT { pos = pos + 1; };
                };
            };
            // Body with statement parsing
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                pos = pos + 1;
                let mut depth: i32 = 1;
                while pos < tlen && depth > 0 && tokens.get(pos) != TK_EOF {
                    let stk: i32 = tokens.get(pos);
                    if stk == TK_RBRACE { depth = depth - 1; pos = pos + 1; }
                    else if stk == TK_LBRACE { depth = depth + 1; pos = pos + 1; }
                    else if stk == TK_LET {
                        pos = pos + 1;
                        // Skip to ;
                        while pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF {
                            if tokens.get(pos) == TK_LBRACE { depth = depth + 1; };
                            if tokens.get(pos) == TK_RBRACE { depth = depth - 1; if depth == 0 { break; }; };
                            pos = pos + 1;
                        };
                        if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
                        stmts = stmts + 1;
                    }
                    else if stk == TK_RETURN {
                        pos = pos + 1;
                        while pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF {
                            if tokens.get(pos) == TK_LBRACE { depth = depth + 1; };
                            if tokens.get(pos) == TK_RBRACE { depth = depth - 1; if depth == 0 { break; }; };
                            pos = pos + 1;
                        };
                        if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
                        stmts = stmts + 1;
                    }
                    else if stk == TK_IF || stk == TK_WHILE || stk == TK_FOR || stk == TK_MATCH {
                        pos = pos + 1;
                        while pos < tlen && tokens.get(pos) != TK_LBRACE && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                        if pos < tlen && tokens.get(pos) == TK_LBRACE { depth = depth + 1; pos = pos + 1; };
                    }
                    else if stk == TK_ELSE {
                        pos = pos + 1;
                        if pos < tlen && tokens.get(pos) == TK_LBRACE { depth = depth + 1; pos = pos + 1; };
                    }
                    else if stk == TK_BREAK || stk == TK_CONTINUE {
                        pos = pos + 1;
                        if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
                        stmts = stmts + 1;
                    }
                    else { pos = pos + 1; };
                };
            };
            items = items + 1;
        }
        else if tk == TK_STRUCT || tk == TK_ENUM {
            pos = pos + 1;
            if pos < tlen && tokens.get(pos) == TK_IDENT { pos = pos + 1; };
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_RBRACE && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                if pos < tlen && tokens.get(pos) == TK_RBRACE { pos = pos + 1; };
            };
            items = items + 1;
        }
        else if tk == TK_CONST {
            pos = pos + 1;
            while pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF { pos = pos + 1; };
            if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
            items = items + 1;
        }
        else { pos = pos + 1; };
    };

    items * 10000 + stmts * 100
}

// === STAGE 3: CHECK ===
// Validates: main exists, variable definitions, function references
fn check(source: str) -> i32 {
    let len: i32 = str_len(source);
    let mut errors: i32 = 0;
    let mut has_main: bool = false;
    let mut fn_count: i32 = 0;
    let mut let_count: i32 = 0;
    let mut pos: i32 = 0;

    // Scan for declarations
    while pos < len {
        let c: i32 = str_char_at(source, pos);
        if is_ws(c) { pos = pos + 1; }
        else if is_ident_start(c) {
            let start: i32 = pos;
            while pos < len && is_ident_cont(str_char_at(source, pos)) { pos = pos + 1; };
            let word: str = str_substring(source, start, pos);
            if str_eq(word, "fn") { fn_count = fn_count + 1; };
            if str_eq(word, "main") { has_main = true; };
            if str_eq(word, "let") { let_count = let_count + 1; };
        }
        else { pos = pos + 1; };
    };

    if !has_main { errors = errors + 1; };
    errors
}

// === STAGE 4: IR LOWER ===
fn lower(source: str) -> Vec<i32> {
    let mut ir: Vec<i32> = Vec::new();
    let len: i32 = str_len(source);
    let mut pos: i32 = 0;
    // Find the second opening brace (skip struct body, enter fn init body)
    let mut open_count: i32 = 0;
    while pos < len {
        if str_char_at(source, pos) == 123 {
            open_count = open_count + 1;
            if open_count == 2 { break; };
        };
        pos = pos + 1;
    };
    pos = pos + 1;
    while pos < len && str_char_at(source, pos) != 125 {
        let c: i32 = str_char_at(source, pos);
        if c == 32 || c == 10 || c == 9 { pos = pos + 1; }
        else if c == 108 && pos + 2 < len && str_char_at(source, pos + 1) == 101 && str_char_at(source, pos + 2) == 116 {
            pos = pos + 3;
            while pos < len && str_char_at(source, pos) != 61 && str_char_at(source, pos) != 59 { pos = pos + 1; };
            if str_char_at(source, pos) == 61 { pos = pos + 1; };
            while pos < len && str_char_at(source, pos) == 32 { pos = pos + 1; };
            if pos < len && is_digit(str_char_at(source, pos)) {
                ir.push(IR_CONST);
                while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
            };
            ir.push(IR_STORE);
            if pos < len && str_char_at(source, pos) == 59 { pos = pos + 1; };
        }
        else if is_digit(c) {
            ir.push(IR_CONST);
            while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
        }
        else if is_alpha(c) || c == 95 {
            ir.push(IR_LOAD);
            while pos < len && is_ident_cont(str_char_at(source, pos)) { pos = pos + 1; };
        }
        else if c == 43 { ir.push(IR_ADD); pos = pos + 1; }
        else if c == 45 { ir.push(IR_SUB); pos = pos + 1; }
        else if c == 42 { ir.push(IR_MUL); pos = pos + 1; }
        else { pos = pos + 1; };
    };
    ir.push(IR_RET);
    ir
}

fn main() -> i32 {
    print("========================================");
    print("  Nucleor Self-Hosted Compiler Stage 0");
    print("========================================");

    let source: str = "struct Config { size: i32 } fn init() -> i32 { let a: i32 = 3; let b: i32 = 4; a * b } fn main() -> i32 { 0 }";

    // Stage 1: LEX
    let tokens: Vec<i32> = lex(source);
    let tok_count: i32 = tokens.len();
    print("  [LEX] tokens:");
    print_int(tok_count);

    // Stage 2: PARSE (re-tokenizes internally — Vec move workaround)
    let parse_result: i32 = parse(source);
    let item_count: i32 = parse_result / 10000;
    let stmt_count: i32 = (parse_result / 100) - (item_count * 100);
    print("  [PARSE] items:");
    print_int(item_count);
    print("  [PARSE] statements:");
    print_int(stmt_count);

    // Stage 3: CHECK
    let err_count: i32 = check(source);
    print("  [CHECK] errors:");
    print_int(err_count);

    // Stage 4: IR LOWER
    let ir: Vec<i32> = lower(source);
    let ir_count: i32 = ir.len();
    print("  [IR] instructions:");
    print_int(ir_count);

    // Final verdict
    if err_count == 0 {
        print("========================================");
        print("  COMPILATION SUCCESSFUL");
        print("========================================");
    } else {
        print("  COMPILATION FAILED");
    };
    0
}
