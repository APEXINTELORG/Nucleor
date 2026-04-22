// Minimal lexer test

const TK_EOF: i32 = 0;
const TK_INT: i32 = 1;
const TK_IDENT: i32 = 4;
const TK_FN: i32 = 10;
const TK_LPAREN: i32 = 40;
const TK_RPAREN: i32 = 41;
const TK_LBRACE: i32 = 42;
const TK_RBRACE: i32 = 43;

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn print_tokens(tokens: Vec<i32>) -> i32 {
    let total: i32 = tokens.len();
    print_int(total);
    let mut i: i32 = 0;
    while i < total {
        print_int(tokens.get(i));
        i = i + 1;
    };
    0
}

fn tokenize_simple(source: str) -> Vec<i32> {
    let len: i32 = str_len(source);
    let mut tokens: Vec<i32> = Vec::new();
    let mut pos: i32 = 0;

    while pos < len {
        let c: i32 = str_char_at(source, pos);
        if is_ws(c) {
            pos = pos + 1;
        }
        else if is_digit(c) {
            while pos < len && is_digit(str_char_at(source, pos)) {
                pos = pos + 1;
            };
            tokens.push(TK_INT);
        }
        else if is_ident_start(c) {
            let start: i32 = pos;
            while pos < len && is_ident_cont(str_char_at(source, pos)) {
                pos = pos + 1;
            };
            let word: str = str_substring(source, start, pos);
            if str_eq(word, "fn") {
                tokens.push(TK_FN);
            } else {
                tokens.push(TK_IDENT);
            };
        }
        else if c == 40 { tokens.push(TK_LPAREN); pos = pos + 1; }
        else if c == 41 { tokens.push(TK_RPAREN); pos = pos + 1; }
        else if c == 123 { tokens.push(TK_LBRACE); pos = pos + 1; }
        else if c == 125 { tokens.push(TK_RBRACE); pos = pos + 1; }
        else { pos = pos + 1; };
    };

    tokens.push(TK_EOF);
    tokens
}

fn main() -> i32 {
    let tokens: Vec<i32> = tokenize_simple("fn main() { 42 }");
    print_tokens(tokens);
    0
}
