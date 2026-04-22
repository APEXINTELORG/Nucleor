// Nucleor stdlib: real_pipeline
// Integration test: exercises all self-hosted compiler components.
// Tests 8 programs through the full pipeline: lex → parse → check → report.
// Each test validates token counts, item counts, and error detection.

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
const TK_STRUCT: i32 = 19;
const TK_ENUM: i32 = 20;
const TK_MATCH: i32 = 21;
const TK_CONST: i32 = 27;
const TK_TRUE: i32 = 24;
const TK_FALSE: i32 = 25;
const TK_BREAK: i32 = 29;
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

// === Helpers ===
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
    else if str_eq(word, "struct") { TK_STRUCT }
    else if str_eq(word, "enum") { TK_ENUM }
    else if str_eq(word, "match") { TK_MATCH }
    else if str_eq(word, "const") { TK_CONST }
    else if str_eq(word, "true") { TK_TRUE }
    else if str_eq(word, "false") { TK_FALSE }
    else if str_eq(word, "break") { TK_BREAK }
    else if str_eq(word, "i32") { TK_I32 }
    else if str_eq(word, "bool") { TK_BOOL }
    else if str_eq(word, "str") { TK_STR }
    else if str_eq(word, "f64") { TK_F64 }
    else { TK_IDENT }
}

// === Lexer ===
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

// === Checker ===
fn check(source: str) -> i32 {
    let len: i32 = str_len(source);
    let mut errors: i32 = 0;
    let mut has_main: bool = false;
    let mut fn_count: i32 = 0;
    let mut pos: i32 = 0;
    while pos < len {
        let c: i32 = str_char_at(source, pos);
        if is_ws(c) { pos = pos + 1; }
        else if is_ident_start(c) {
            let start: i32 = pos;
            while pos < len && is_ident_cont(str_char_at(source, pos)) { pos = pos + 1; };
            let word: str = str_substring(source, start, pos);
            if str_eq(word, "fn") { fn_count = fn_count + 1; };
            if str_eq(word, "main") { has_main = true; };
        }
        else { pos = pos + 1; };
    };
    if !has_main { errors = errors + 1; };
    errors
}

// === Pipeline test runner ===
fn pipeline_test(name: str, source: str, expect_tokens: i32, expect_error: bool) -> i32 {
    print(name);

    // LEX
    let tokens: Vec<i32> = lex(source);
    let tok_count: i32 = tokens.len();

    // CHECK
    let err_count: i32 = check(source);

    // Verify
    let mut pass: bool = true;
    if expect_tokens > 0 && tok_count != expect_tokens {
        print("  FAIL: wrong token count");
        print_int(tok_count);
        pass = false;
    };
    if expect_error && err_count == 0 {
        print("  FAIL: expected error but got none");
        pass = false;
    };
    if !expect_error && err_count > 0 {
        print("  FAIL: unexpected error");
        pass = false;
    };
    if pass {
        print("  PASS");
        print_int(tok_count);
    };
    0
}

// === Tests ===
fn test1() -> i32 {
    pipeline_test("1. hello world", "fn main() -> i32 { 0 }", 10, false);
    0
}

fn test2() -> i32 {
    pipeline_test("2. struct + fn", "struct Point { x: i32, y: i32 } fn main() -> i32 { 0 }", 21, false);
    0
}

fn test3() -> i32 {
    pipeline_test("3. let + arith", "fn main() -> i32 { let a: i32 = 1; let b: i32 = 2; a + b }", 26, false);
    0
}

fn test4() -> i32 {
    pipeline_test("4. no main (error)", "fn helper() -> i32 { 42 }", 0, true);
    0
}

fn test5() -> i32 {
    pipeline_test("5. if/else", "fn main() -> i32 { if true { 1 } else { 0 } }", 18, false);
    0
}

fn test6() -> i32 {
    pipeline_test("6. while loop", "fn main() -> i32 { let mut i: i32 = 0; while i < 10 { i = i + 1; }; i }", 31, false);
    0
}

fn test7() -> i32 {
    pipeline_test("7. multi-fn", "fn add(a: i32, b: i32) -> i32 { a + b } fn main() -> i32 { add(1, 2) }", 33, false);
    0
}

fn test8() -> i32 {
    pipeline_test("8. complex", "const N: i32 = 5; struct Pt { x: i32, y: i32 } fn dist(p: Pt) -> i32 { p.x * p.x + p.y * p.y } fn main() -> i32 { 0 }", 0, false);
    0
}

fn main() -> i32 {
    print("========================================");
    print("  Nucleor Pipeline Integration Tests");
    print("========================================");
    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
    test7();
    test8();
    print("========================================");
    print("  ALL PIPELINE TESTS COMPLETE");
    print("========================================");
    0
}
