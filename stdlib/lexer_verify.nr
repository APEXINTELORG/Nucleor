// Verify tokenizer with raw integer output (bypass token_name if-else chain)

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn classify_keyword(word: str) -> i32 {
    if str_eq(word, "fn") { 10 }
    else if str_eq(word, "let") { 11 }
    else if str_eq(word, "mut") { 12 }
    else if str_eq(word, "return") { 13 }
    else if str_eq(word, "if") { 14 }
    else if str_eq(word, "else") { 15 }
    else if str_eq(word, "while") { 16 }
    else if str_eq(word, "struct") { 19 }
    else if str_eq(word, "true") { 24 }
    else if str_eq(word, "false") { 25 }
    else { 4 }
}

fn tokenize(source: str) -> Vec<i32> {
    let len: i32 = str_len(source);
    let mut tokens: Vec<i32> = Vec::new();
    let mut pos: i32 = 0;
    while pos < len {
        let c: i32 = str_char_at(source, pos);
        if is_ws(c) { pos = pos + 1; }
        else if is_digit(c) {
            while pos < len && is_digit(str_char_at(source, pos)) { pos = pos + 1; };
            tokens.push(1);
        }
        else if is_ident_start(c) {
            let start: i32 = pos;
            while pos < len && is_ident_cont(str_char_at(source, pos)) { pos = pos + 1; };
            tokens.push(classify_keyword(str_substring(source, start, pos)));
        }
        else if c == 45 && pos + 1 < len && str_char_at(source, pos + 1) == 62 {
            tokens.push(62); pos = pos + 2;
        }
        else if c == 61 && pos + 1 < len && str_char_at(source, pos + 1) == 61 {
            tokens.push(56); pos = pos + 2;
        }
        else if c == 40 { tokens.push(40); pos = pos + 1; }
        else if c == 41 { tokens.push(41); pos = pos + 1; }
        else if c == 123 { tokens.push(42); pos = pos + 1; }
        else if c == 125 { tokens.push(43); pos = pos + 1; }
        else if c == 43 { tokens.push(50); pos = pos + 1; }
        else if c == 42 { tokens.push(52); pos = pos + 1; }
        else if c == 59 { tokens.push(68); pos = pos + 1; }
        else if c == 44 { tokens.push(69); pos = pos + 1; }
        else if c == 45 { tokens.push(51); pos = pos + 1; }
        else if c == 61 { tokens.push(55); pos = pos + 1; }
        else if c == 58 { tokens.push(66); pos = pos + 1; }
        else { pos = pos + 1; };
    };
    tokens.push(0);
    tokens
}

fn main() -> i32 {
    // Test: fn main() -> i32 { let x: i32 = 42; x + 1 }
    // Expected: 10 4 40 41 62 4 42 11 4 66 4 55 1 68 4 50 1 43 0
    let t: Vec<i32> = tokenize("fn main() -> i32 { let x: i32 = 42; x + 1 }");
    let n: i32 = t.len();
    print_int(n);
    let mut i: i32 = 0;
    while i < n {
        print_int(t.get(i));
        i = i + 1;
    };
    print("---done---");
    0
}
