// Nucleor stdlib: real_ir_lowering
// Expanded IR lowering for self-hosted compiler.
// Handles: let, return, if/else, while, function calls,
// all arithmetic/comparison/boolean operators, multiple functions.
// Uses token-based approach with full tokenizer.

// === Token constants ===
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
const TK_TRUE: i32 = 24;
const TK_FALSE: i32 = 25;
const TK_BREAK: i32 = 29;
const TK_CONTINUE: i32 = 30;
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

// === IR opcodes ===
const IR_CONST: i32 = 0;
const IR_LOAD: i32 = 1;
const IR_STORE: i32 = 2;
const IR_ADD: i32 = 3;
const IR_SUB: i32 = 4;
const IR_MUL: i32 = 5;
const IR_DIV: i32 = 6;
const IR_RET: i32 = 7;
const IR_MOD: i32 = 8;
const IR_CMP_EQ: i32 = 10;
const IR_CMP_NE: i32 = 11;
const IR_CMP_LT: i32 = 12;
const IR_CMP_GT: i32 = 13;
const IR_CMP_LE: i32 = 14;
const IR_CMP_GE: i32 = 15;
const IR_AND: i32 = 16;
const IR_OR: i32 = 17;
const IR_NOT: i32 = 18;
const IR_NEG: i32 = 19;
const IR_CALL: i32 = 20;
const IR_LABEL: i32 = 30;
const IR_BRANCH_IF: i32 = 31;
const IR_BRANCH_IFNOT: i32 = 32;
const IR_JUMP: i32 = 33;
const IR_CONST_BOOL: i32 = 40;
const IR_CONST_STR: i32 = 41;
const IR_CONST_FLOAT: i32 = 42;
const IR_FN_START: i32 = 50;
const IR_FN_END: i32 = 51;
const IR_VEC_NEW: i32 = 60;
const IR_VEC_PUSH: i32 = 61;
const IR_VEC_GET: i32 = 62;
const IR_VEC_LEN: i32 = 63;
const IR_VEC_POP: i32 = 64;
const IR_NOP: i32 = 99;

// === Helpers ===
fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
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
    else if str_eq(word, "true") { TK_TRUE }
    else if str_eq(word, "false") { TK_FALSE }
    else if str_eq(word, "break") { TK_BREAK }
    else if str_eq(word, "continue") { TK_CONTINUE }
    else if str_eq(word, "i32") { TK_I32 }
    else if str_eq(word, "bool") { TK_BOOL }
    else if str_eq(word, "str") { TK_STR }
    else { TK_IDENT }
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
            while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
            if pos < len && str_char_at(source, pos) == 46 && pos + 1 < len && is_digit(str_char_at(source, pos + 1)) {
                pos = pos + 1;
                while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                tokens.push(TK_FLOAT);
            } else { tokens.push(TK_INT); };
        }
        else if is_ident_start(c) {
            let start: i32 = pos;
            while pos < len && is_ident_cont(str_char_at(source, pos)) { pos = pos + 1; };
            tokens.push(classify_kw1(str_substring(source, start, pos)));
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
        else { pos = pos + 1; };
    };
    tokens.push(TK_EOF);
    tokens
}

fn op_to_ir(op: i32) -> i32 {
    if op == TK_PLUS { IR_ADD }
    else if op == TK_MINUS { IR_SUB }
    else if op == TK_STAR { IR_MUL }
    else if op == TK_SLASH { IR_DIV }
    else if op == TK_PERCENT { IR_MOD }
    else if op == TK_EQEQ { IR_CMP_EQ }
    else if op == TK_BANGEQ { IR_CMP_NE }
    else if op == TK_LT { IR_CMP_LT }
    else if op == TK_GT { IR_CMP_GT }
    else if op == TK_LTEQ { IR_CMP_LE }
    else if op == TK_GTEQ { IR_CMP_GE }
    else if op == TK_AMPAMP { IR_AND }
    else if op == TK_PIPEPIPE { IR_OR }
    else { IR_NOP }
}

fn is_binop(tk: i32) -> bool {
    tk == TK_PLUS || tk == TK_MINUS || tk == TK_STAR || tk == TK_SLASH ||
    tk == TK_PERCENT || tk == TK_EQEQ || tk == TK_BANGEQ || tk == TK_LT ||
    tk == TK_GT || tk == TK_LTEQ || tk == TK_GTEQ || tk == TK_AMPAMP ||
    tk == TK_PIPEPIPE
}

fn op_prec(tk: i32) -> i32 {
    if tk == TK_PIPEPIPE { 1 }
    else if tk == TK_AMPAMP { 2 }
    else if tk == TK_EQEQ || tk == TK_BANGEQ { 3 }
    else if tk == TK_LT || tk == TK_GT || tk == TK_LTEQ || tk == TK_GTEQ { 4 }
    else if tk == TK_PLUS || tk == TK_MINUS { 5 }
    else if tk == TK_STAR || tk == TK_SLASH || tk == TK_PERCENT { 6 }
    else { 0 }
}

// === IR Lowering ===
// Single function: tokenizes and lowers first function body to IR.
// Handles: let, return, if/else, while, break, continue,
// all binary ops, unary ops, function calls, literals.
// Produces Vec<i32> of IR opcodes.
fn lower_program(source: str) -> i32 {
    let tokens: Vec<i32> = tokenize(source);
    let tlen: i32 = tokens.len();
    let mut pos: i32 = 0;
    let mut ir: Vec<i32> = Vec::new();
    let mut op_stack: Vec<i32> = Vec::new();
    let mut label_counter: i32 = 0;
    let mut fn_count: i32 = 0;

    // Lower ALL function bodies
    while pos < tlen && tokens.get(pos) != TK_EOF {
        if tokens.get(pos) != TK_FN { pos = pos + 1; }
        else {
            pos = pos + 1;
            // Skip name
            if pos < tlen && tokens.get(pos) == TK_IDENT { pos = pos + 1; };
            // Skip params
            if pos < tlen && tokens.get(pos) == TK_LPAREN {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_RPAREN && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                if pos < tlen { pos = pos + 1; };
            };
            // Skip return type
            if pos < tlen && tokens.get(pos) == TK_ARROW {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_LBRACE && tokens.get(pos) != TK_EOF { pos = pos + 1; };
            };
            // Body
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                pos = pos + 1;
                fn_count = fn_count + 1;
                ir.push(IR_FN_START);
                ir.push(fn_count);

    let mut depth: i32 = 1;
    while pos < tlen && depth > 0 && tokens.get(pos) != TK_EOF {
        let tk: i32 = tokens.get(pos);

        if tk == TK_RBRACE { depth = depth - 1; pos = pos + 1; }
        else if tk == TK_LBRACE { depth = depth + 1; pos = pos + 1; }
        // let statement
        else if tk == TK_LET {
            pos = pos + 1;
            if pos < tlen && tokens.get(pos) == TK_MUT { pos = pos + 1; };
            if pos < tlen && tokens.get(pos) == TK_IDENT { pos = pos + 1; };
            // Skip : type
            if pos < tlen && tokens.get(pos) == TK_COLON {
                pos = pos + 1;
                while pos < tlen && tokens.get(pos) != TK_EQ && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF { pos = pos + 1; };
            };
            if pos < tlen && tokens.get(pos) == TK_EQ {
                pos = pos + 1;
                // Lower init expression using shunting-yard
                let mut os_base: i32 = op_stack.len();
                let mut es: i32 = 0;
                while pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF {
                    let etk: i32 = tokens.get(pos);
                    if es == 0 {
                        if etk == TK_INT { ir.push(IR_CONST); pos = pos + 1; es = 1; }
                        else if etk == TK_FLOAT { ir.push(IR_CONST_FLOAT); pos = pos + 1; es = 1; }
                        else if etk == TK_STRING { ir.push(IR_CONST_STR); pos = pos + 1; es = 1; }
                        else if etk == TK_TRUE { ir.push(IR_CONST_BOOL); pos = pos + 1; es = 1; }
                        else if etk == TK_FALSE { ir.push(IR_CONST_BOOL); pos = pos + 1; es = 1; }
                        else if etk == TK_IDENT {
                            // Check for function call
                            if pos + 1 < tlen && tokens.get(pos + 1) == TK_LPAREN {
                                ir.push(IR_CALL);
                                pos = pos + 2;
                                let mut pd: i32 = 1;
                                while pos < tlen && pd > 0 {
                                    if tokens.get(pos) == TK_LPAREN { pd = pd + 1; };
                                    if tokens.get(pos) == TK_RPAREN { pd = pd - 1; };
                                    if pd > 0 { pos = pos + 1; };
                                };
                                if pos < tlen { pos = pos + 1; };
                            } else {
                                ir.push(IR_LOAD);
                                pos = pos + 1;
                            };
                            es = 1;
                        }
                        else if etk == TK_LPAREN { op_stack.push(TK_LPAREN); pos = pos + 1; }
                        else if etk == TK_MINUS { op_stack.push(1051); pos = pos + 1; }
                        else if etk == TK_BANG { op_stack.push(1074); pos = pos + 1; }
                        else { pos = pos + 1; };
                    } else {
                        if is_binop(etk) {
                            let prec: i32 = op_prec(etk);
                            while op_stack.len() > os_base {
                                let top: i32 = op_stack.get(op_stack.len() - 1);
                                if top == TK_LPAREN { break; };
                                let mut tp: i32 = op_prec(top);
                                if top >= 1000 { tp = 100; };
                                if tp >= prec {
                                    op_stack.pop();
                                    if top >= 1000 {
                                        if top == 1051 { ir.push(IR_NEG); }
                                        else if top == 1074 { ir.push(IR_NOT); };
                                    } else { ir.push(op_to_ir(top)); };
                                } else { break; };
                            };
                            op_stack.push(etk);
                            pos = pos + 1;
                            es = 0;
                        }
                        else if etk == TK_RPAREN {
                            while op_stack.len() > os_base {
                                let top2: i32 = op_stack.get(op_stack.len() - 1);
                                if top2 == TK_LPAREN { break; };
                                op_stack.pop();
                                if top2 >= 1000 {
                                    if top2 == 1051 { ir.push(IR_NEG); }
                                    else { ir.push(IR_NOT); };
                                } else { ir.push(op_to_ir(top2)); };
                            };
                            if op_stack.len() > os_base { op_stack.pop(); };
                            pos = pos + 1;
                        }
                        else if etk == TK_DOT {
                            pos = pos + 1;
                            if pos < tlen && tokens.get(pos) == TK_IDENT {
                                // Check for known Vec methods
                                let mstart: i32 = pos;
                                pos = pos + 1;
                                if pos < tlen && tokens.get(pos) == TK_LPAREN {
                                    pos = pos + 1;
                                    let mut mpd: i32 = 1;
                                    while pos < tlen && mpd > 0 {
                                        if tokens.get(pos) == TK_LPAREN { mpd = mpd + 1; };
                                        if tokens.get(pos) == TK_RPAREN { mpd = mpd - 1; };
                                        if mpd > 0 { pos = pos + 1; };
                                    };
                                    if pos < tlen { pos = pos + 1; };
                                    ir.push(IR_CALL);
                                } else {
                                    ir.push(IR_LOAD);
                                };
                            };
                        }
                        else { break; };
                    };
                };
                // Flush remaining ops
                while op_stack.len() > os_base {
                    let top3: i32 = op_stack.get(op_stack.len() - 1);
                    op_stack.pop();
                    if top3 >= 1000 {
                        if top3 == 1051 { ir.push(IR_NEG); }
                        else { ir.push(IR_NOT); };
                    } else if top3 != TK_LPAREN { ir.push(op_to_ir(top3)); };
                };
            };
            ir.push(IR_STORE);
            if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
        }
        // return statement
        else if tk == TK_RETURN {
            pos = pos + 1;
            // Lower return expression (simplified: single value)
            if pos < tlen && tokens.get(pos) != TK_SEMICOLON {
                if tokens.get(pos) == TK_INT { ir.push(IR_CONST); pos = pos + 1; }
                else if tokens.get(pos) == TK_TRUE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
                else if tokens.get(pos) == TK_FALSE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
                else if tokens.get(pos) == TK_IDENT { ir.push(IR_LOAD); pos = pos + 1; }
                else {
                    while pos < tlen && tokens.get(pos) != TK_SEMICOLON && tokens.get(pos) != TK_EOF { pos = pos + 1; };
                };
            };
            ir.push(IR_RET);
            if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
        }
        // if statement
        else if tk == TK_IF {
            pos = pos + 1;
            let mut lbl_else: i32 = label_counter;
            label_counter = label_counter + 1;
            let mut lbl_end: i32 = label_counter;
            label_counter = label_counter + 1;
            // Lower condition (simplified: single comparison or ident)
            if pos < tlen {
                let ctk: i32 = tokens.get(pos);
                if ctk == TK_TRUE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
                else if ctk == TK_FALSE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
                else if ctk == TK_IDENT {
                    ir.push(IR_LOAD);
                    pos = pos + 1;
                    // Check for comparison
                    if pos < tlen && is_binop(tokens.get(pos)) {
                        let cop: i32 = tokens.get(pos);
                        pos = pos + 1;
                        if pos < tlen {
                            if tokens.get(pos) == TK_INT { ir.push(IR_CONST); pos = pos + 1; }
                            else if tokens.get(pos) == TK_IDENT { ir.push(IR_LOAD); pos = pos + 1; }
                            else { pos = pos + 1; };
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
            // then block
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                depth = depth + 1;
                pos = pos + 1;
            };
        }
        // else
        else if tk == TK_ELSE {
            // Jump past else block
            let mut lbl_end2: i32 = label_counter;
            label_counter = label_counter + 1;
            ir.push(IR_JUMP);
            ir.push(lbl_end2);
            // Label for else entry
            ir.push(IR_LABEL);
            ir.push(lbl_end2 - 1);
            pos = pos + 1;
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                depth = depth + 1;
                pos = pos + 1;
            };
        }
        // while loop
        else if tk == TK_WHILE {
            pos = pos + 1;
            let mut lbl_loop: i32 = label_counter;
            label_counter = label_counter + 1;
            let mut lbl_exit: i32 = label_counter;
            label_counter = label_counter + 1;
            ir.push(IR_LABEL);
            ir.push(lbl_loop);
            // Lower condition
            if pos < tlen {
                let wctk: i32 = tokens.get(pos);
                if wctk == TK_TRUE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
                else if wctk == TK_FALSE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
                else if wctk == TK_IDENT {
                    ir.push(IR_LOAD);
                    pos = pos + 1;
                    if pos < tlen && is_binop(tokens.get(pos)) {
                        let wop: i32 = tokens.get(pos);
                        pos = pos + 1;
                        if pos < tlen {
                            if tokens.get(pos) == TK_INT { ir.push(IR_CONST); pos = pos + 1; }
                            else if tokens.get(pos) == TK_IDENT { ir.push(IR_LOAD); pos = pos + 1; }
                            else { pos = pos + 1; };
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
            if pos < tlen && tokens.get(pos) == TK_LBRACE {
                depth = depth + 1;
                pos = pos + 1;
            };
        }
        // break/continue
        else if tk == TK_BREAK {
            ir.push(IR_JUMP);
            ir.push(0);
            pos = pos + 1;
            if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
        }
        else if tk == TK_CONTINUE {
            ir.push(IR_JUMP);
            ir.push(0);
            pos = pos + 1;
            if pos < tlen && tokens.get(pos) == TK_SEMICOLON { pos = pos + 1; };
        }
        // Expression: literal, ident, or call
        else if tk == TK_INT { ir.push(IR_CONST); pos = pos + 1; }
        else if tk == TK_FLOAT { ir.push(IR_CONST_FLOAT); pos = pos + 1; }
        else if tk == TK_STRING { ir.push(IR_CONST_STR); pos = pos + 1; }
        else if tk == TK_TRUE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
        else if tk == TK_FALSE { ir.push(IR_CONST_BOOL); pos = pos + 1; }
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
                // Assignment: ident = expr;
                ir.push(IR_LOAD);
                pos = pos + 2;
                // Lower RHS (simplified)
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
            else {
                ir.push(IR_LOAD);
                pos = pos + 1;
            };
        }
        // Operators
        else if is_binop(tk) { ir.push(op_to_ir(tk)); pos = pos + 1; }
        else if tk == TK_BANG { ir.push(IR_NOT); pos = pos + 1; }
        // Skip other tokens
        else if tk == TK_SEMICOLON { pos = pos + 1; }
        else { pos = pos + 1; };
    };

    // Close function
    if ir.len() == 0 { ir.push(IR_RET); }
    else if ir.get(ir.len() - 1) != IR_RET { ir.push(IR_RET); };
    ir.push(IR_FN_END);
    ir.push(fn_count);
            };
        };
    };

    // Print results
    let n: i32 = ir.len();
    print_int(n);
    let mut i: i32 = 0;
    while i < n { print_int(ir.get(i)); i = i + 1; };
    n
}

// === Tests ===
fn test_const() -> i32 {
    print("=== IR: { 42 } ===");
    lower_program("fn f() -> i32 { 42 }");
    0
}

fn test_let() -> i32 {
    print("=== IR: let + expr ===");
    lower_program("fn f() -> i32 { let x: i32 = 10; x }");
    0
}

fn test_binop() -> i32 {
    print("=== IR: a + b * c ===");
    lower_program("fn f() -> i32 { let a: i32 = 3; let b: i32 = 4; a * b }");
    0
}

fn test_comparison() -> i32 {
    print("=== IR: comparison ===");
    lower_program("fn f() -> bool { let x: i32 = 5; x == 5 }");
    0
}

fn test_if_else() -> i32 {
    print("=== IR: if/else ===");
    lower_program("fn f() -> i32 { if true { 1 } else { 0 } }");
    0
}

fn test_while() -> i32 {
    print("=== IR: while loop ===");
    lower_program("fn f() -> i32 { let mut i: i32 = 0; while i < 10 { i = i + 1; }; i }");
    0
}

fn test_call() -> i32 {
    print("=== IR: function call ===");
    lower_program("fn f() -> i32 { let x: i32 = foo(1, 2); x }");
    0
}

fn test_return() -> i32 {
    print("=== IR: return ===");
    lower_program("fn f() -> i32 { return 42; }");
    0
}

fn test_bool_ops() -> i32 {
    print("=== IR: bool ops ===");
    lower_program("fn f() -> bool { true && false || true }");
    0
}

fn test_complex() -> i32 {
    print("=== IR: complex ===");
    lower_program("fn f() -> i32 { let a: i32 = 3; let b: i32 = 4; let c: i32 = a + b * 2; c }");
    0
}

fn test_multi_fn() -> i32 {
    print("=== IR: multiple functions ===");
    lower_program("fn add(a: i32, b: i32) -> i32 { a + b } fn main() -> i32 { add(1, 2) }");
    0
}

fn test_method_calls() -> i32 {
    print("=== IR: method calls ===");
    lower_program("fn f() -> i32 { let mut v: Vec<i32> = Vec::new(); v.push(42); v.len() }");
    0
}

fn main() -> i32 {
    test_const();
    test_let();
    test_binop();
    test_comparison();
    test_if_else();
    test_while();
    test_call();
    test_return();
    test_bool_ops();
    test_complex();
    test_multi_fn();
    test_method_calls();
    print("=== IR LOWERING COMPLETE ===");
    0
}
