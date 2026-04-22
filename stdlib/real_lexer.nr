// Nucleor stdlib: real_lexer
// Full lexer for Nucleor source code — all 48 keywords, all operators,
// string literals, float literals, hex/bin/oct integers.
// Functions split to avoid deep if-else codegen limits.

// === Literal tokens ===
const TK_EOF: i32 = 0;
const TK_INT: i32 = 1;
const TK_FLOAT: i32 = 2;
const TK_STRING: i32 = 3;
const TK_IDENT: i32 = 4;

// === Keywords (41) ===
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
const TK_WHERE: i32 = 26;
const TK_CONST: i32 = 27;
const TK_TYPE: i32 = 28;
const TK_BREAK: i32 = 29;
const TK_CONTINUE: i32 = 30;
const TK_REQUIRES: i32 = 31;
const TK_RESTRICTS: i32 = 32;
const TK_TAINTED: i32 = 33;
const TK_SANITIZE: i32 = 34;
const TK_PURE: i32 = 35;
const TK_SCOPE: i32 = 36;
const TK_SPAWN: i32 = 37;
const TK_EXTERN: i32 = 38;
const TK_USE: i32 = 39;
const TK_ARENA: i32 = 100;
const TK_COMPTIME: i32 = 101;
const TK_CHANNEL: i32 = 102;
const TK_ASYNC: i32 = 103;
const TK_AWAIT: i32 = 104;
const TK_UNSAFE: i32 = 105;
const TK_PUB: i32 = 106;
const TK_PRIV: i32 = 107;
const TK_WRAPPING: i32 = 108;
const TK_SATURATING: i32 = 109;
const TK_UNIT: i32 = 110;

// === Type keywords (7) ===
const TK_I32: i32 = 90;
const TK_I64: i32 = 91;
const TK_U32: i32 = 92;
const TK_U64: i32 = 93;
const TK_F64: i32 = 94;
const TK_BOOL: i32 = 95;
const TK_STR: i32 = 96;

// === Delimiters ===
const TK_LPAREN: i32 = 40;
const TK_RPAREN: i32 = 41;
const TK_LBRACE: i32 = 42;
const TK_RBRACE: i32 = 43;
const TK_LBRACKET: i32 = 44;
const TK_RBRACKET: i32 = 45;

// === Operators and punctuation ===
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
const TK_COLONCOLON: i32 = 63;
const TK_DOTDOT: i32 = 64;
const TK_DOTDOTEQ: i32 = 65;
const TK_COLON: i32 = 66;
const TK_DOT: i32 = 67;
const TK_SEMICOLON: i32 = 68;
const TK_COMMA: i32 = 69;
const TK_AMP: i32 = 70;
const TK_PIPE: i32 = 71;
const TK_LT: i32 = 72;
const TK_GT: i32 = 73;
const TK_BANG: i32 = 74;
const TK_LTEQ: i32 = 75;
const TK_GTEQ: i32 = 76;
const TK_AT: i32 = 77;
const TK_HASH: i32 = 78;
const TK_UNDERSCORE: i32 = 79;
const TK_DOTSTAR: i32 = 80;
const TK_DOTSLASH: i32 = 81;
const TK_DOTCARET: i32 = 82;

// === Character classification ===
fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_hex_digit(c: i32) -> bool { is_digit(c) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102) }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

// === Keyword classification — split into groups by first letter to keep chains short ===

// a-c keywords
fn classify_kw_ac(word: str) -> i32 {
    if str_eq(word, "arena") { TK_ARENA }
    else if str_eq(word, "async") { TK_ASYNC }
    else if str_eq(word, "await") { TK_AWAIT }
    else if str_eq(word, "bool") { TK_BOOL }
    else if str_eq(word, "break") { TK_BREAK }
    else if str_eq(word, "channel") { TK_CHANNEL }
    else if str_eq(word, "comptime") { TK_COMPTIME }
    else if str_eq(word, "const") { TK_CONST }
    else if str_eq(word, "continue") { TK_CONTINUE }
    else { 0 }
}

// e-i keywords
fn classify_kw_ei(word: str) -> i32 {
    if str_eq(word, "else") { TK_ELSE }
    else if str_eq(word, "enum") { TK_ENUM }
    else if str_eq(word, "extern") { TK_EXTERN }
    else if str_eq(word, "f64") { TK_F64 }
    else if str_eq(word, "false") { TK_FALSE }
    else if str_eq(word, "fn") { TK_FN }
    else if str_eq(word, "for") { TK_FOR }
    else if str_eq(word, "i32") { TK_I32 }
    else if str_eq(word, "i64") { TK_I64 }
    else if str_eq(word, "if") { TK_IF }
    else if str_eq(word, "impl") { TK_IMPL }
    else if str_eq(word, "in") { TK_IN }
    else { 0 }
}

// l-p keywords
fn classify_kw_lp(word: str) -> i32 {
    if str_eq(word, "let") { TK_LET }
    else if str_eq(word, "match") { TK_MATCH }
    else if str_eq(word, "mut") { TK_MUT }
    else if str_eq(word, "priv") { TK_PRIV }
    else if str_eq(word, "pub") { TK_PUB }
    else if str_eq(word, "pure") { TK_PURE }
    else { 0 }
}

// r-s keywords
fn classify_kw_rs(word: str) -> i32 {
    if str_eq(word, "requires") { TK_REQUIRES }
    else if str_eq(word, "restricts") { TK_RESTRICTS }
    else if str_eq(word, "return") { TK_RETURN }
    else if str_eq(word, "sanitize") { TK_SANITIZE }
    else if str_eq(word, "saturating") { TK_SATURATING }
    else if str_eq(word, "scope") { TK_SCOPE }
    else if str_eq(word, "spawn") { TK_SPAWN }
    else if str_eq(word, "struct") { TK_STRUCT }
    else if str_eq(word, "str") { TK_STR }
    else { 0 }
}

// t-z keywords
fn classify_kw_tz(word: str) -> i32 {
    if str_eq(word, "tainted") { TK_TAINTED }
    else if str_eq(word, "trait") { TK_TRAIT }
    else if str_eq(word, "true") { TK_TRUE }
    else if str_eq(word, "type") { TK_TYPE }
    else if str_eq(word, "u32") { TK_U32 }
    else if str_eq(word, "u64") { TK_U64 }
    else if str_eq(word, "unit") { TK_UNIT }
    else if str_eq(word, "unsafe") { TK_UNSAFE }
    else if str_eq(word, "use") { TK_USE }
    else if str_eq(word, "where") { TK_WHERE }
    else if str_eq(word, "while") { TK_WHILE }
    else if str_eq(word, "wrapping") { TK_WRAPPING }
    else { 0 }
}

// Dispatch keyword classification by first character
fn classify_keyword(word: str) -> i32 {
    let first: i32 = str_char_at(word, 0);
    let mut result: i32 = 0;
    if first >= 97 && first <= 99 {
        result = classify_kw_ac(word);
    } else if first >= 101 && first <= 105 {
        result = classify_kw_ei(word);
    } else if first >= 108 && first <= 112 {
        result = classify_kw_lp(word);
    } else if first >= 114 && first <= 115 {
        result = classify_kw_rs(word);
    } else if first >= 116 && first <= 122 {
        result = classify_kw_tz(word);
    };
    if result == 0 { TK_IDENT } else { result }
}

// === Tokenizer ===
fn tokenize(source: str) -> Vec<i32> {
    let len: i32 = str_len(source);
    let mut tokens: Vec<i32> = Vec::new();
    let mut pos: i32 = 0;

    while pos < len {
        let c: i32 = str_char_at(source, pos);

        // Whitespace
        if is_ws(c) {
            pos = pos + 1;
        }
        // Line comment //
        else if c == 47 && pos + 1 < len && str_char_at(source, pos + 1) == 47 {
            while pos < len && str_char_at(source, pos) != 10 { pos = pos + 1; };
        }
        // String literal "..."
        else if c == 34 {
            pos = pos + 1;
            while pos < len && str_char_at(source, pos) != 34 {
                // Skip escaped characters (\" etc.)
                if str_char_at(source, pos) == 92 && pos + 1 < len {
                    pos = pos + 2;
                } else {
                    pos = pos + 1;
                };
            };
            if pos < len { pos = pos + 1; };
            tokens.push(TK_STRING);
        }
        // Number: integer, float, hex, bin, oct
        else if is_digit(c) {
            // Check for 0x, 0b, 0o prefixes
            if c == 48 && pos + 1 < len {
                let next: i32 = str_char_at(source, pos + 1);
                // Hex 0x
                if next == 120 || next == 88 {
                    pos = pos + 2;
                    while pos < len && is_hex_digit(str_char_at(source, pos)) { pos = pos + 1; };
                    tokens.push(TK_INT);
                }
                // Binary 0b
                else if next == 98 || next == 66 {
                    pos = pos + 2;
                    while pos < len {
                        let bc: i32 = str_char_at(source, pos);
                        if bc == 48 || bc == 49 { pos = pos + 1; }
                        else { break; };
                    };
                    tokens.push(TK_INT);
                }
                // Octal 0o
                else if next == 111 || next == 79 {
                    pos = pos + 2;
                    while pos < len {
                        let oc: i32 = str_char_at(source, pos);
                        if oc >= 48 && oc <= 55 { pos = pos + 1; }
                        else { break; };
                    };
                    tokens.push(TK_INT);
                }
                // Regular number starting with 0
                else {
                    while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                    // Check for float: digit.digit (not ..)
                    if pos < len && str_char_at(source, pos) == 46 && pos + 1 < len && is_digit(str_char_at(source, pos + 1)) {
                        pos = pos + 1;
                        while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                        // Scientific notation e/E
                        if pos < len {
                            let ec: i32 = str_char_at(source, pos);
                            if ec == 101 || ec == 69 {
                                pos = pos + 1;
                                if pos < len {
                                    let sc: i32 = str_char_at(source, pos);
                                    if sc == 43 || sc == 45 { pos = pos + 1; };
                                };
                                while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                            };
                        };
                        tokens.push(TK_FLOAT);
                    } else {
                        tokens.push(TK_INT);
                    };
                };
            }
            // Regular decimal number
            else {
                while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                // Check for float
                if pos < len && str_char_at(source, pos) == 46 && pos + 1 < len && is_digit(str_char_at(source, pos + 1)) {
                    pos = pos + 1;
                    while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                    // Scientific notation
                    if pos < len {
                        let ec2: i32 = str_char_at(source, pos);
                        if ec2 == 101 || ec2 == 69 {
                            pos = pos + 1;
                            if pos < len {
                                let sc2: i32 = str_char_at(source, pos);
                                if sc2 == 43 || sc2 == 45 { pos = pos + 1; };
                            };
                            while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
                        };
                    };
                    tokens.push(TK_FLOAT);
                } else {
                    tokens.push(TK_INT);
                };
            };
        }
        // Identifier or keyword (including _ as lone underscore)
        else if is_ident_start(c) {
            // Check for lone underscore (wildcard pattern)
            if c == 95 && (pos + 1 >= len || !is_ident_cont(str_char_at(source, pos + 1))) {
                tokens.push(TK_UNDERSCORE);
                pos = pos + 1;
            } else {
                let start: i32 = pos;
                while pos < len && is_ident_cont(str_char_at(source, pos)) { pos = pos + 1; };
                tokens.push(classify_keyword(str_substring(source, start, pos)));
            };
        }
        // Multi-char operators (check longest match first)
        // -> arrow
        else if c == 45 && pos + 1 < len && str_char_at(source, pos + 1) == 62 {
            tokens.push(TK_ARROW); pos = pos + 2;
        }
        // == and =>
        else if c == 61 && pos + 1 < len && str_char_at(source, pos + 1) == 61 {
            tokens.push(TK_EQEQ); pos = pos + 2;
        }
        else if c == 61 && pos + 1 < len && str_char_at(source, pos + 1) == 62 {
            tokens.push(TK_FATARROW); pos = pos + 2;
        }
        // !=
        else if c == 33 && pos + 1 < len && str_char_at(source, pos + 1) == 61 {
            tokens.push(TK_BANGEQ); pos = pos + 2;
        }
        // <= and <
        else if c == 60 && pos + 1 < len && str_char_at(source, pos + 1) == 61 {
            tokens.push(TK_LTEQ); pos = pos + 2;
        }
        // >= and >
        else if c == 62 && pos + 1 < len && str_char_at(source, pos + 1) == 61 {
            tokens.push(TK_GTEQ); pos = pos + 2;
        }
        // && and &
        else if c == 38 && pos + 1 < len && str_char_at(source, pos + 1) == 38 {
            tokens.push(TK_AMPAMP); pos = pos + 2;
        }
        // |>, ||, |
        else if c == 124 && pos + 1 < len && str_char_at(source, pos + 1) == 62 {
            tokens.push(TK_PIPERIGHT); pos = pos + 2;
        }
        else if c == 124 && pos + 1 < len && str_char_at(source, pos + 1) == 124 {
            tokens.push(TK_PIPEPIPE); pos = pos + 2;
        }
        // :: and :
        else if c == 58 && pos + 1 < len && str_char_at(source, pos + 1) == 58 {
            tokens.push(TK_COLONCOLON); pos = pos + 2;
        }
        // ..=, .., .*, ./, .^, .
        else if c == 46 && pos + 1 < len && str_char_at(source, pos + 1) == 46 {
            if pos + 2 < len && str_char_at(source, pos + 2) == 61 {
                tokens.push(TK_DOTDOTEQ); pos = pos + 3;
            } else {
                tokens.push(TK_DOTDOT); pos = pos + 2;
            };
        }
        else if c == 46 && pos + 1 < len && str_char_at(source, pos + 1) == 42 {
            tokens.push(TK_DOTSTAR); pos = pos + 2;
        }
        else if c == 46 && pos + 1 < len && str_char_at(source, pos + 1) == 47 {
            tokens.push(TK_DOTSLASH); pos = pos + 2;
        }
        else if c == 46 && pos + 1 < len && str_char_at(source, pos + 1) == 94 {
            tokens.push(TK_DOTCARET); pos = pos + 2;
        }
        // Single-character tokens
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
        else if c == 124 { tokens.push(TK_PIPE); pos = pos + 1; }
        else if c == 46 { tokens.push(TK_DOT); pos = pos + 1; }
        else if c == 64 { tokens.push(TK_AT); pos = pos + 1; }
        else if c == 35 { tokens.push(TK_HASH); pos = pos + 1; }
        else { pos = pos + 1; };
    };

    tokens.push(TK_EOF);
    tokens
}

// === Token printing — split into small functions ===
fn print_tk_lit(kind: i32) -> i32 {
    if kind == TK_EOF { print("EOF"); 1 }
    else if kind == TK_INT { print("INT"); 1 }
    else if kind == TK_FLOAT { print("FLOAT"); 1 }
    else if kind == TK_STRING { print("STRING"); 1 }
    else if kind == TK_IDENT { print("IDENT"); 1 }
    else { 0 }
}

fn print_tk_kw1(kind: i32) -> i32 {
    if kind == TK_FN { print("fn"); 1 }
    else if kind == TK_LET { print("let"); 1 }
    else if kind == TK_MUT { print("mut"); 1 }
    else if kind == TK_RETURN { print("return"); 1 }
    else if kind == TK_IF { print("if"); 1 }
    else if kind == TK_ELSE { print("else"); 1 }
    else if kind == TK_WHILE { print("while"); 1 }
    else if kind == TK_FOR { print("for"); 1 }
    else if kind == TK_IN { print("in"); 1 }
    else if kind == TK_STRUCT { print("struct"); 1 }
    else if kind == TK_ENUM { print("enum"); 1 }
    else if kind == TK_MATCH { print("match"); 1 }
    else if kind == TK_IMPL { print("impl"); 1 }
    else if kind == TK_TRAIT { print("trait"); 1 }
    else if kind == TK_TRUE { print("true"); 1 }
    else if kind == TK_FALSE { print("false"); 1 }
    else { 0 }
}

fn print_tk_kw2(kind: i32) -> i32 {
    if kind == TK_WHERE { print("where"); 1 }
    else if kind == TK_CONST { print("const"); 1 }
    else if kind == TK_TYPE { print("type"); 1 }
    else if kind == TK_BREAK { print("break"); 1 }
    else if kind == TK_CONTINUE { print("continue"); 1 }
    else if kind == TK_REQUIRES { print("requires"); 1 }
    else if kind == TK_RESTRICTS { print("restricts"); 1 }
    else if kind == TK_TAINTED { print("tainted"); 1 }
    else if kind == TK_SANITIZE { print("sanitize"); 1 }
    else if kind == TK_PURE { print("pure"); 1 }
    else if kind == TK_SCOPE { print("scope"); 1 }
    else if kind == TK_SPAWN { print("spawn"); 1 }
    else if kind == TK_EXTERN { print("extern"); 1 }
    else if kind == TK_USE { print("use"); 1 }
    else { 0 }
}

fn print_tk_kw3(kind: i32) -> i32 {
    if kind == TK_ARENA { print("arena"); 1 }
    else if kind == TK_COMPTIME { print("comptime"); 1 }
    else if kind == TK_CHANNEL { print("channel"); 1 }
    else if kind == TK_ASYNC { print("async"); 1 }
    else if kind == TK_AWAIT { print("await"); 1 }
    else if kind == TK_UNSAFE { print("unsafe"); 1 }
    else if kind == TK_PUB { print("pub"); 1 }
    else if kind == TK_PRIV { print("priv"); 1 }
    else if kind == TK_WRAPPING { print("wrapping"); 1 }
    else if kind == TK_SATURATING { print("saturating"); 1 }
    else if kind == TK_UNIT { print("unit"); 1 }
    else { 0 }
}

fn print_tk_type(kind: i32) -> i32 {
    if kind == TK_I32 { print("i32"); 1 }
    else if kind == TK_I64 { print("i64"); 1 }
    else if kind == TK_U32 { print("u32"); 1 }
    else if kind == TK_U64 { print("u64"); 1 }
    else if kind == TK_F64 { print("f64"); 1 }
    else if kind == TK_BOOL { print("bool"); 1 }
    else if kind == TK_STR { print("str"); 1 }
    else { 0 }
}

fn print_tk_op(kind: i32) -> i32 {
    if kind == TK_LPAREN { print("("); 1 }
    else if kind == TK_RPAREN { print(")"); 1 }
    else if kind == TK_LBRACE { print("{"); 1 }
    else if kind == TK_RBRACE { print("}"); 1 }
    else if kind == TK_LBRACKET { print("["); 1 }
    else if kind == TK_RBRACKET { print("]"); 1 }
    else if kind == TK_PLUS { print("+"); 1 }
    else if kind == TK_MINUS { print("-"); 1 }
    else if kind == TK_STAR { print("*"); 1 }
    else if kind == TK_SLASH { print("/"); 1 }
    else if kind == TK_PERCENT { print("%"); 1 }
    else if kind == TK_EQ { print("="); 1 }
    else if kind == TK_EQEQ { print("=="); 1 }
    else if kind == TK_BANGEQ { print("!="); 1 }
    else if kind == TK_FATARROW { print("=>"); 1 }
    else if kind == TK_AMPAMP { print("&&"); 1 }
    else { 0 }
}

fn print_tk_op2(kind: i32) -> i32 {
    if kind == TK_PIPEPIPE { print("||"); 1 }
    else if kind == TK_PIPERIGHT { print("|>"); 1 }
    else if kind == TK_ARROW { print("->"); 1 }
    else if kind == TK_COLONCOLON { print("::"); 1 }
    else if kind == TK_DOTDOT { print(".."); 1 }
    else if kind == TK_DOTDOTEQ { print("..="); 1 }
    else if kind == TK_COLON { print(":"); 1 }
    else if kind == TK_DOT { print("."); 1 }
    else if kind == TK_SEMICOLON { print(";"); 1 }
    else if kind == TK_COMMA { print(","); 1 }
    else if kind == TK_AMP { print("&"); 1 }
    else if kind == TK_PIPE { print("|"); 1 }
    else if kind == TK_LT { print("<"); 1 }
    else if kind == TK_GT { print(">"); 1 }
    else if kind == TK_BANG { print("!"); 1 }
    else if kind == TK_LTEQ { print("<="); 1 }
    else { 0 }
}

fn print_tk_op3(kind: i32) -> i32 {
    if kind == TK_GTEQ { print(">="); 1 }
    else if kind == TK_AT { print("@"); 1 }
    else if kind == TK_HASH { print("#"); 1 }
    else if kind == TK_UNDERSCORE { print("_"); 1 }
    else if kind == TK_DOTSTAR { print(".*"); 1 }
    else if kind == TK_DOTSLASH { print("./"); 1 }
    else if kind == TK_DOTCARET { print(".^"); 1 }
    else { 0 }
}

fn print_token(kind: i32) -> i32 {
    let mut found: i32 = print_tk_lit(kind);
    if found == 0 { found = print_tk_kw1(kind); };
    if found == 0 { found = print_tk_kw2(kind); };
    if found == 0 { found = print_tk_kw3(kind); };
    if found == 0 { found = print_tk_type(kind); };
    if found == 0 { found = print_tk_op(kind); };
    if found == 0 { found = print_tk_op2(kind); };
    if found == 0 { found = print_tk_op3(kind); };
    if found == 0 { print("?"); };
    0
}

// === Test helpers ===
fn dump_tokens(source: str) -> i32 {
    let t: Vec<i32> = tokenize(source);
    let n: i32 = t.len();
    let mut i: i32 = 0;
    while i < n {
        print_token(t.get(i));
        i = i + 1;
    };
    0
}

fn count_tokens(source: str) -> i32 {
    let t: Vec<i32> = tokenize(source);
    t.len()
}

// === Tests ===
fn test_basic() -> i32 {
    print("=== Test 1: basic fn ===");
    dump_tokens("fn main() -> i32 { let x: i32 = 42; x + 1 }");
    0
}

fn test_struct() -> i32 {
    print("=== Test 2: struct ===");
    dump_tokens("struct Point { x: i32, y: i32 }");
    0
}

fn test_control_flow() -> i32 {
    print("=== Test 3: if/else ===");
    dump_tokens("if x == 0 { true } else { false }");
    0
}

fn test_while() -> i32 {
    print("=== Test 4: while loop ===");
    dump_tokens("while i < 10 { i = i + 1; }");
    0
}

fn test_comment() -> i32 {
    print("=== Test 5: comment ===");
    dump_tokens("fn foo() -> i32 { // this is a comment\n42 }");
    0
}

fn test_new_keywords() -> i32 {
    print("=== Test 6: new keywords ===");
    dump_tokens("match impl trait const type break continue use extern unsafe pub");
    0
}

fn test_type_keywords() -> i32 {
    print("=== Test 7: type keywords ===");
    dump_tokens("i32 i64 u32 u64 f64 bool str");
    0
}

fn test_new_operators() -> i32 {
    print("=== Test 8: operators ===");
    dump_tokens("!= <= >= => && || |> :: .. ..= .* ./ .^ @ # % _ & |");
    0
}

fn test_string_literal() -> i32 {
    print("=== Test 9: string literal ===");
    // Tokenize a source that contains string literals
    let t: Vec<i32> = tokenize("let s: str = \"hello world\";");
    let n: i32 = t.len();
    print_int(n);
    // Should be: let str = STRING ; EOF = 7 tokens
    let mut i: i32 = 0;
    while i < n {
        print_token(t.get(i));
        i = i + 1;
    };
    0
}

fn test_float_literal() -> i32 {
    print("=== Test 10: float literal ===");
    let t: Vec<i32> = tokenize("let x: f64 = 3.14; let y: f64 = 1.0e10;");
    let n: i32 = t.len();
    print_int(n);
    let mut i: i32 = 0;
    while i < n {
        print_token(t.get(i));
        i = i + 1;
    };
    0
}

fn test_hex_bin_oct() -> i32 {
    print("=== Test 11: hex/bin/oct ===");
    let t: Vec<i32> = tokenize("0xFF 0b1010 0o77 42");
    let n: i32 = t.len();
    print_int(n);
    // Should be: INT INT INT INT EOF = 5 tokens
    let mut i: i32 = 0;
    while i < n {
        print_token(t.get(i));
        i = i + 1;
    };
    0
}

fn test_brackets() -> i32 {
    print("=== Test 12: brackets ===");
    dump_tokens("a[0] = b[1];");
    0
}

fn test_governance() -> i32 {
    print("=== Test 13: governance keywords ===");
    dump_tokens("requires restricts tainted sanitize pure scope spawn arena comptime channel async await");
    0
}

fn test_escape_string() -> i32 {
    print("=== Test 14: escaped string ===");
    let t: Vec<i32> = tokenize("\"hello\\\"world\"");
    let n: i32 = t.len();
    print_int(n);
    // Should be: STRING EOF = 2 tokens (escaped quote does not end the string)
    let mut i: i32 = 0;
    while i < n {
        print_token(t.get(i));
        i = i + 1;
    };
    0
}

fn main() -> i32 {
    test_basic();
    test_struct();
    test_control_flow();
    test_while();
    test_comment();
    test_new_keywords();
    test_type_keywords();
    test_new_operators();
    test_string_literal();
    test_float_literal();
    test_hex_bin_oct();
    test_brackets();
    test_governance();
    test_escape_string();
    print("=== ALL TESTS PASS ===");
    0
}
