// Nucleor stdlib: real_parser
// Recursive descent parser with shunting-yard expression precedence.
// Parses all items + statements. Expression parsing with correct operator precedence.
// Uses Vec.get() directly. All parsing in one function (Vec move constraint).

// === Token constants (match real_lexer.nr) ===
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
const TK_PERCENT: i32 = 54;
const TK_EQ: i32 = 55;
const TK_EQEQ: i32 = 56;
const TK_BANGEQ: i32 = 57;
const TK_FATARROW: i32 = 58;
const TK_AMPAMP: i32 = 59;
const TK_PIPEPIPE: i32 = 60;
const TK_PIPERIGHT: i32 = 61;
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
const TK_AT: i32 = 77;
const TK_I32: i32 = 90;
const TK_I64: i32 = 91;
const TK_U32: i32 = 92;
const TK_U64: i32 = 93;
const TK_F64: i32 = 94;
const TK_BOOL: i32 = 95;
const TK_STR: i32 = 96;
const TK_EXTERN: i32 = 38;
const TK_UNSAFE: i32 = 105;

// === Event tags (postfix output) ===
const EVT_INT_LIT: i32 = 230;
const EVT_FLOAT_LIT: i32 = 231;
const EVT_BOOL_LIT: i32 = 232;
const EVT_STRING_LIT: i32 = 233;
const EVT_IDENT: i32 = 234;
const EVT_BINOP: i32 = 235;
const EVT_UNARY: i32 = 236;
const EVT_CALL: i32 = 237;
const EVT_FIELD: i32 = 238;
const EVT_INDEX: i32 = 239;

// === Inlined lexer ===
fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_hex_digit(c: i32) -> bool { is_digit(c) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102) }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

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
    else if str_eq(word, "extern") { TK_EXTERN }
    else if str_eq(word, "i32") { TK_I32 }
    else if str_eq(word, "i64") { TK_I64 }
    else if str_eq(word, "u32") { TK_U32 }
    else if str_eq(word, "u64") { TK_U64 }
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

fn tokenize(source: str) -> Vec<i32> {
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
        else if c == 124 && pos + 1 < len && str_char_at(source, pos + 1) == 62 { tokens.push(TK_PIPERIGHT); pos = pos + 2; }
        else if c == 58 && pos + 1 < len && str_char_at(source, pos + 1) == 58 { tokens.push(66); pos = pos + 2; }
        else if c == 40 { tokens.push(TK_LPAREN); pos = pos + 1; }
        else if c == 41 { tokens.push(TK_RPAREN); pos = pos + 1; }
        else if c == 123 { tokens.push(TK_LBRACE); pos = pos + 1; }
        else if c == 125 { tokens.push(TK_RBRACE); pos = pos + 1; }
        else if c == 91 { tokens.push(TK_LBRACKET); pos = pos + 1; }
        else if c == 93 { tokens.push(TK_RBRACKET); pos = pos + 1; }
        else if c == 43 { tokens.push(TK_PLUS); pos = pos + 1; }
        else if c == 42 { tokens.push(TK_STAR); pos = pos + 1; }
        else if c == 47 { tokens.push(TK_SLASH); pos = pos + 1; }
        else if c == 37 { tokens.push(TK_PERCENT); pos = pos + 1; }
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
        else if c == 64 { tokens.push(TK_AT); pos = pos + 1; }
        else { pos = pos + 1; };
    };
    tokens.push(TK_EOF);
    tokens
}

// === Helpers (no Vec needed) ===
fn is_binary_op(tk: i32) -> bool {
    tk == TK_PLUS || tk == TK_MINUS || tk == TK_STAR || tk == TK_SLASH ||
    tk == TK_PERCENT || tk == TK_EQEQ || tk == TK_BANGEQ || tk == TK_LT ||
    tk == TK_GT || tk == TK_LTEQ || tk == TK_GTEQ || tk == TK_AMPAMP ||
    tk == TK_PIPEPIPE || tk == TK_PIPERIGHT || tk == TK_AT
}

fn op_precedence(tk: i32) -> i32 {
    if tk == TK_PIPEPIPE { 1 }
    else if tk == TK_AMPAMP { 2 }
    else if tk == TK_EQEQ || tk == TK_BANGEQ { 3 }
    else if tk == TK_LT || tk == TK_GT || tk == TK_LTEQ || tk == TK_GTEQ { 4 }
    else if tk == TK_PIPERIGHT { 5 }
    else if tk == TK_PLUS || tk == TK_MINUS { 6 }
    else if tk == TK_STAR || tk == TK_SLASH || tk == TK_PERCENT || tk == TK_AT { 7 }
    else { 0 }
}

fn is_type_start(tk: i32) -> bool {
    tk == TK_IDENT || tk == TK_I32 || tk == TK_I64 || tk == TK_U32 ||
    tk == TK_U64 || tk == TK_F64 || tk == TK_BOOL || tk == TK_STR || tk == TK_AMP
}

fn is_expr_atom(tk: i32) -> bool {
    tk == TK_INT || tk == TK_FLOAT || tk == TK_STRING || tk == TK_TRUE ||
    tk == TK_FALSE || tk == TK_IDENT || tk == TK_LPAREN || tk == TK_MINUS ||
    tk == TK_BANG || tk == TK_AMP
}

// === Parser with expression precedence ===
// Returns: items * 1000000 + stmts * 10000 + exprs * 100 + errors
fn parse_program(source: str) -> i32 {
    let tokens: Vec<i32> = tokenize(source);
    let tlen: i32 = tokens.len();
    let mut pos: i32 = 0;
    let mut errors: i32 = 0;
    let mut fn_count: i32 = 0;
    let mut struct_count: i32 = 0;
    let mut stmt_count: i32 = 0;
    let mut expr_count: i32 = 0;
    let mut binop_count: i32 = 0;
    let mut call_count: i32 = 0;
    let mut events: Vec<i32> = Vec::new();
    let mut op_stack: Vec<i32> = Vec::new();

    // === TOP LEVEL LOOP ===
    while pos < tlen && tokens.get(pos) != TK_EOF {
        let item_tk: i32 = tokens.get(pos);

        // --- fn declaration ---
        if item_tk == TK_FN {
            pos = pos + 1;
            if pos < tlen && tokens.get(pos) == TK_IDENT { pos = pos + 1; }
            else { errors = errors + 1; };
            // Params
            if pos < tlen && tokens.get(pos) == TK_LPAREN {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_RPAREN && tokens.get(pos) != TK_EOF {
                    pos = pos + 1;
                };
                if pos < tlen && tokens.get(pos) == TK_RPAREN { pos = pos + 1; };
            };
            // Return type
            if pos < tlen && tokens.get(pos) == TK_ARROW {
                pos = pos + 1;
                if pos < tlen && is_type_start(tokens.get(pos)) {
                    if tokens.get(pos) == TK_AMP { pos = pos + 1; };
                    pos = pos + 1;
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
            };
            // Body
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                pos = pos + 1;
                let mut depth: i32 = 1;

                // === STATEMENT LOOP ===
                while pos < tlen && depth > 0 && tokens.get(pos) != TK_EOF {
                    let stk: i32 = tokens.get(pos);
                    let mut do_expr: bool = false;

                    if stk == TK_RBRACE { depth = depth - 1; pos = pos + 1; }
                    else if stk == TK_LBRACE { depth = depth + 1; pos = pos + 1; }
                    // let
                    else if stk == TK_LET {
                        pos = pos + 1;
                        if pos < tlen && tokens.get(pos) == TK_MUT { pos = pos + 1; };
                        if pos < tlen && tokens.get(pos) == TK_IDENT { pos = pos + 1; };
                        // : type
                        if pos < tlen && tokens.get(pos) == TK_COLON {
                            pos = pos + 1;
                            while pos < tlen && tokens.get(pos) != TK_EQ && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF {
                                pos = pos + 1;
                            };
                        };
                        if pos < tlen && tokens.get(pos) == TK_EQ {
                            pos = pos + 1;
                            do_expr = true;
                        };
                        stmt_count = stmt_count + 1;
                    }
                    // return
                    else if stk == TK_RETURN {
                        pos = pos + 1;
                        if pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_RBRACE {
                            do_expr = true;
                        };
                        stmt_count = stmt_count + 1;
                    }
                    // break / continue
                    else if stk == TK_BREAK || stk == TK_CONTINUE {
                        pos = pos + 1;
                        if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
                        stmt_count = stmt_count + 1;
                    }
                    // if
                    else if stk == TK_IF {
                        pos = pos + 1;
                        do_expr = true; // parse condition as expression
                    }
                    // else
                    else if stk == TK_ELSE {
                        pos = pos + 1;
                        if pos < tlen && tokens.get(pos) == TK_LBRACE {
                            depth = depth + 1;
                            pos = pos + 1;
                        };
                    }
                    // while
                    else if stk == TK_WHILE {
                        pos = pos + 1;
                        do_expr = true; // parse condition as expression
                    }
                    // for
                    else if stk == TK_FOR {
                        pos = pos + 1;
                        // Skip: ident in expr { body }
                        while pos < tlen && tokens.get(pos) != TK_LBRACE && tokens.get(pos) != TK_EOF {
                            pos = pos + 1;
                        };
                        if pos < tlen && tokens.get(pos) == TK_LBRACE {
                            depth = depth + 1;
                            pos = pos + 1;
                        };
                    }
                    // match
                    else if stk == TK_MATCH {
                        pos = pos + 1;
                        do_expr = true; // parse scrutinee expression
                    }
                    // Expression or assignment
                    else if is_expr_atom(stk) {
                        do_expr = true;
                        stmt_count = stmt_count + 1;
                    }
                    else { pos = pos + 1; };

                    // === SHUNTING-YARD EXPRESSION PARSER ===
                    if do_expr {
                        let mut os_base: i32 = op_stack.len();
                        let mut es: i32 = 0; // 0=want operand, 1=got operand
                        let mut expr_done: bool = false;

                        while pos < tlen && !expr_done {
                            let etk: i32 = tokens.get(pos);

                            if es == 0 {
                                // === OPERAND position ===
                                if etk == TK_INT {
                                    events.push(EVT_INT_LIT);
                                    pos = pos + 1; es = 1;
                                }
                                else if etk == TK_FLOAT {
                                    events.push(EVT_FLOAT_LIT);
                                    pos = pos + 1; es = 1;
                                }
                                else if etk == TK_STRING {
                                    events.push(EVT_STRING_LIT);
                                    pos = pos + 1; es = 1;
                                }
                                else if etk == TK_TRUE {
                                    events.push(EVT_BOOL_LIT); events.push(1);
                                    pos = pos + 1; es = 1;
                                }
                                else if etk == TK_FALSE {
                                    events.push(EVT_BOOL_LIT); events.push(0);
                                    pos = pos + 1; es = 1;
                                }
                                else if etk == TK_IDENT {
                                    events.push(EVT_IDENT);
                                    pos = pos + 1;
                                    // Function call?
                                    if pos < tlen && tokens.get(pos) == TK_LPAREN {
                                        pos = pos + 1;
                                        let mut ac: i32 = 0;
                                        let mut pd: i32 = 1;
                                        if pos < tlen && tokens.get(pos) != TK_RPAREN { ac = 1; };
                                        while pos < tlen && pd > 0 {
                                            if tokens.get(pos) == TK_LPAREN { pd = pd + 1; };
                                            if tokens.get(pos) == TK_RPAREN { pd = pd - 1; };
                                            if tokens.get(pos) == TK_COMMA && pd == 1 { ac = ac + 1; };
                                            if pd > 0 { pos = pos + 1; };
                                        };
                                        if pos < tlen { pos = pos + 1; };
                                        events.push(EVT_CALL); events.push(ac);
                                        call_count = call_count + 1;
                                    };
                                    es = 1;
                                }
                                else if etk == TK_LPAREN {
                                    op_stack.push(TK_LPAREN);
                                    pos = pos + 1;
                                }
                                else if etk == TK_MINUS {
                                    op_stack.push(1051); // unary minus
                                    pos = pos + 1;
                                }
                                else if etk == TK_BANG {
                                    op_stack.push(1074); // unary not
                                    pos = pos + 1;
                                }
                                else if etk == TK_AMP {
                                    pos = pos + 1; // skip & (reference)
                                    if pos < tlen && tokens.get(pos) == TK_MUT { pos = pos + 1; };
                                }
                                else { expr_done = true; };
                            }
                            else {
                                // === OPERATOR position (es==1) ===
                                if is_binary_op(etk) {
                                    let prec: i32 = op_precedence(etk);
                                    // Pop higher/equal precedence
                                    while op_stack.len() > os_base {
                                        let top: i32 = op_stack.get(op_stack.len() - 1);
                                        if top == TK_LPAREN { break; };
                                        let mut tp: i32 = op_precedence(top);
                                        if top >= 1000 { tp = 100; };
                                        if tp >= prec {
                                            op_stack.pop();
                                            if top >= 1000 {
                                                events.push(EVT_UNARY); events.push(top - 1000);
                                            } else {
                                                events.push(EVT_BINOP); events.push(top);
                                                binop_count = binop_count + 1;
                                            };
                                        } else { break; };
                                    };
                                    op_stack.push(etk);
                                    pos = pos + 1;
                                    es = 0;
                                }
                                else if etk == TK_DOT {
                                    pos = pos + 1;
                                    if pos < tlen && tokens.get(pos) == TK_IDENT {
                                        pos = pos + 1;
                                        // Method call?
                                        if pos < tlen && tokens.get(pos) == TK_LPAREN {
                                            pos = pos + 1;
                                            let mut mac: i32 = 0;
                                            let mut mpd: i32 = 1;
                                            if pos < tlen && tokens.get(pos) != TK_RPAREN { mac = 1; };
                                            while pos < tlen && mpd > 0 {
                                                if tokens.get(pos) == TK_LPAREN { mpd = mpd + 1; };
                                                if tokens.get(pos) == TK_RPAREN { mpd = mpd - 1; };
                                                if tokens.get(pos) == TK_COMMA && mpd == 1 { mac = mac + 1; };
                                                if mpd > 0 { pos = pos + 1; };
                                            };
                                            if pos < tlen { pos = pos + 1; };
                                            events.push(EVT_CALL); events.push(mac);
                                            call_count = call_count + 1;
                                        } else {
                                            events.push(EVT_FIELD);
                                        };
                                    };
                                }
                                else if etk == TK_LBRACKET {
                                    pos = pos + 1;
                                    let mut bid: i32 = 1;
                                    while pos < tlen && bid > 0 {
                                        if tokens.get(pos) == TK_LBRACKET { bid = bid + 1; };
                                        if tokens.get(pos) == TK_RBRACKET { bid = bid - 1; };
                                        if bid > 0 { pos = pos + 1; };
                                    };
                                    if pos < tlen { pos = pos + 1; };
                                    events.push(EVT_INDEX);
                                }
                                else if etk == TK_RPAREN {
                                    // Close paren — pop to matching LPAREN
                                    while op_stack.len() > os_base {
                                        let top2: i32 = op_stack.get(op_stack.len() - 1);
                                        if top2 == TK_LPAREN { break; };
                                        op_stack.pop();
                                        if top2 >= 1000 {
                                            events.push(EVT_UNARY); events.push(top2 - 1000);
                                        } else {
                                            events.push(EVT_BINOP); events.push(top2);
                                            binop_count = binop_count + 1;
                                        };
                                    };
                                    if op_stack.len() > os_base { op_stack.pop(); };
                                    pos = pos + 1;
                                }
                                else if etk == TK_EQ {
                                    // Assignment: pop all ops, this becomes assign
                                    while op_stack.len() > os_base {
                                        let top3: i32 = op_stack.get(op_stack.len() - 1);
                                        op_stack.pop();
                                        if top3 >= 1000 {
                                            events.push(EVT_UNARY); events.push(top3 - 1000);
                                        } else if top3 != TK_LPAREN {
                                            events.push(EVT_BINOP); events.push(top3);
                                            binop_count = binop_count + 1;
                                        };
                                    };
                                    pos = pos + 1;
                                    es = 0; // parse RHS expression
                                }
                                else {
                                    // Expression ends: ;, }, {, etc.
                                    expr_done = true;
                                };
                            };
                        };

                        // Flush remaining ops
                        while op_stack.len() > os_base {
                            let top4: i32 = op_stack.get(op_stack.len() - 1);
                            op_stack.pop();
                            if top4 >= 1000 {
                                events.push(EVT_UNARY); events.push(top4 - 1000);
                            } else if top4 != TK_LPAREN {
                                events.push(EVT_BINOP); events.push(top4);
                                binop_count = binop_count + 1;
                            };
                        };

                        expr_count = expr_count + 1;

                        // After expression, consume ; if present
                        if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
                        // If expression ended at {, enter block
                        if pos < tlen && tokens.get(pos) == TK_LBRACE {
                            depth = depth + 1;
                            pos = pos + 1;
                        };
                    };
                };
            };
            fn_count = fn_count + 1;
        }

        // --- struct ---
        else if item_tk == TK_STRUCT {
            pos = pos + 1;
            if pos < tlen && tokens.get(pos) == TK_IDENT { pos = pos + 1; };
            if pos < tlen && tokens.get(pos) == TK_LT {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_GT && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                if pos < tlen { pos = pos + 1; };
            };
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_RBRACE && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                if pos < tlen { pos = pos + 1; };
            };
            struct_count = struct_count + 1;
        }
        // --- enum ---
        else if item_tk == TK_ENUM {
            pos = pos + 1;
            if pos < tlen && tokens.get(pos) == TK_IDENT { pos = pos + 1; };
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_RBRACE && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                if pos < tlen { pos = pos + 1; };
            };
        }
        // --- const ---
        else if item_tk == TK_CONST {
            pos = pos + 1;
            while pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF { pos = pos + 1; };
            if pos < tlen { pos = pos + 1; };
        }
        // --- impl ---
        else if item_tk == TK_IMPL {
            pos = pos + 1;
            while pos < tlen && tokens.get(pos) != TK_LBRACE && tokens.get(pos) != TK_EOF { pos = pos + 1; };
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                pos = pos + 1;
                let mut id: i32 = 1;
                while pos < tlen && id > 0 {
                    if tokens.get(pos) == TK_LBRACE { id = id + 1; };
                    if tokens.get(pos) == TK_RBRACE { id = id - 1; };
                    if id > 0 { pos = pos + 1; };
                };
                if pos < tlen { pos = pos + 1; };
            };
        }
        // --- use ---
        else if item_tk == TK_USE {
            pos = pos + 1;
            while pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF { pos = pos + 1; };
            if pos < tlen { pos = pos + 1; };
        }
        else { pos = pos + 1; };
    };

    let total_items: i32 = fn_count + struct_count;
    total_items * 1000000 + stmt_count * 10000 + expr_count * 100 + errors
}

// === Tests ===
fn test_simple_fn() -> i32 {
    print("Test 1: simple fn");
    let r: i32 = parse_program("fn main() -> i32 { 0 }");
    print_int(r / 1000000); // 1 item
    0
}

fn test_let_with_expr() -> i32 {
    print("Test 2: let with expression");
    let r: i32 = parse_program("fn main() -> i32 { let x: i32 = 1 + 2 * 3; x }");
    let items: i32 = r / 1000000;
    let stmts: i32 = (r / 10000) - (items * 100);
    let exprs: i32 = (r / 100) - (items * 10000) - (stmts * 100);
    print_int(items);  // 1
    print_int(stmts);  // 1 (let)
    print_int(exprs);  // 2 (init expr + trailing expr)
    0
}

fn test_fn_calls() -> i32 {
    print("Test 3: function calls");
    let r: i32 = parse_program("fn main() -> i32 { foo(1, 2) + bar(3) }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(r / 1000000);  // 1
    print_int(errs);          // 0
    0
}

fn test_method_calls() -> i32 {
    print("Test 4: method calls");
    let r: i32 = parse_program("fn main() -> i32 { v.push(1); v.len() }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(r / 1000000);
    print_int(errs);
    0
}

fn test_precedence() -> i32 {
    print("Test 5: operator precedence");
    // a + b * c should produce: a b c * +
    let r: i32 = parse_program("fn main() -> i32 { a + b * c }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(errs);  // 0
    0
}

fn test_comparison() -> i32 {
    print("Test 6: comparison operators");
    let r: i32 = parse_program("fn main() -> bool { x == 0 && y != 1 || z < 5 }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(errs);  // 0
    0
}

fn test_unary() -> i32 {
    print("Test 7: unary operators");
    let r: i32 = parse_program("fn main() -> i32 { -x + !flag }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(errs);  // 0
    0
}

fn test_parens() -> i32 {
    print("Test 8: parenthesized expression");
    let r: i32 = parse_program("fn main() -> i32 { (a + b) * (c - d) }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(errs);  // 0
    0
}

fn test_if_condition() -> i32 {
    print("Test 9: if with condition expr");
    let r: i32 = parse_program("fn main() -> i32 { if x > 0 { 1 } else { 0 } }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(r / 1000000);
    print_int(errs);
    0
}

fn test_while_condition() -> i32 {
    print("Test 10: while with condition");
    let r: i32 = parse_program("fn main() -> i32 { let mut i: i32 = 0; while i < 10 { i = i + 1; }; 0 }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(errs);  // 0
    0
}

fn test_complex() -> i32 {
    print("Test 11: complex program");
    let r: i32 = parse_program("struct Pt { x: i32 } fn add(a: i32, b: i32) -> i32 { a + b } fn main() -> i32 { let x: i32 = add(1, 2); let y: i32 = x * 3 + 4; y }");
    let items: i32 = r / 1000000;
    let errs: i32 = r - (r / 100) * 100;
    print_int(items); // 3 (struct + 2 fn)
    print_int(errs);  // 0
    0
}

fn test_field_access() -> i32 {
    print("Test 12: field access");
    let r: i32 = parse_program("fn main() -> i32 { p.x + p.y }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(errs);  // 0
    0
}

fn test_indexing() -> i32 {
    print("Test 13: indexing");
    let r: i32 = parse_program("fn main() -> i32 { arr[0] + arr[1] }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(errs);  // 0
    0
}

fn test_nested_calls() -> i32 {
    print("Test 14: nested calls");
    let r: i32 = parse_program("fn main() -> i32 { foo(bar(x), baz(y, z)) }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(errs);  // 0
    0
}

fn test_return_expr() -> i32 {
    print("Test 15: return with expression");
    let r: i32 = parse_program("fn main() -> i32 { return a + b * c; }");
    let errs: i32 = r - (r / 100) * 100;
    print_int(errs);  // 0
    0
}

fn test_string_bool_float() -> i32 {
    print("Test 16: all literal types");
    let r: i32 = parse_program("fn main() -> i32 { let a: i32 = 42; let b: f64 = 3.14; let c: bool = true; let d: str = \"hi\"; 0 }");
    let items: i32 = r / 1000000;
    let stmts: i32 = (r / 10000) - (items * 100);
    print_int(items); // 1
    print_int(stmts); // 4
    0
}

fn main() -> i32 {
    test_simple_fn();
    test_let_with_expr();
    test_fn_calls();
    test_method_calls();
    test_precedence();
    test_comparison();
    test_unary();
    test_parens();
    test_if_condition();
    test_while_condition();
    test_complex();
    test_field_access();
    test_indexing();
    test_nested_calls();
    test_return_expr();
    test_string_bool_float();
    print("=== PARSER TESTS COMPLETE ===");
    0
}
