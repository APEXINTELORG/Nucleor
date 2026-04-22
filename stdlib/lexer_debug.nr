// Debug: full tokenizer that returns Vec

fn is_digit(c: i32) -> bool { c >= 48 && c <= 57 }
fn is_alpha(c: i32) -> bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
fn is_ident_start(c: i32) -> bool { is_alpha(c) || c == 95 }
fn is_ident_cont(c: i32) -> bool { is_alpha(c) || is_digit(c) || c == 95 }
fn is_ws(c: i32) -> bool { c == 32 || c == 10 || c == 13 || c == 9 }

fn tokenize(source: str) -> Vec<i32> {
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
            tokens.push(1);
        }
        else if is_ident_start(c) {
            let start: i32 = pos;
            while pos < len && is_ident_cont(str_char_at(source, pos)) {
                pos = pos + 1;
            };
            let word: str = str_substring(source, start, pos);
            if str_eq(word, "fn") { tokens.push(10); }
            else { tokens.push(4); };
        }
        else if c == 40 { tokens.push(40); pos = pos + 1; }
        else if c == 41 { tokens.push(41); pos = pos + 1; }
        else if c == 123 { tokens.push(42); pos = pos + 1; }
        else if c == 125 { tokens.push(43); pos = pos + 1; }
        else { pos = pos + 1; };
    };
    tokens.push(0);
    tokens
}

fn main() -> i32 {
    let tokens: Vec<i32> = tokenize("fn main() { 42 }");
    let n: i32 = tokens.len();
    print_int(n);
    let mut i: i32 = 0;
    while i < n {
        print_int(tokens.get(i));
        i = i + 1;
    };
    print("done");
    0
}
