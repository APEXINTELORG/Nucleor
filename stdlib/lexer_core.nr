// Nucleor stdlib: lexer_core
// Bootstrap lexer for the Nucleor-in-Nucleor compiler.
// Note: token constants inlined here for standalone compilation.
// In the real bootstrap, these come from token_core.nr via import.

const TK_FN: i32 = 10;
const TK_IF: i32 = 14;
const TK_IN: i32 = 18;
const TK_LET: i32 = 11;
const TK_MUT: i32 = 12;
const TK_FOR: i32 = 17;
const TK_USE: i32 = 27;
const TK_IDENT: i32 = 4;

fn is_digit(c: i32) -> bool {
    c >= 48 && c <= 57
}

fn is_alpha(c: i32) -> bool {
    (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
}

fn is_alpha_or_underscore(c: i32) -> bool {
    is_alpha(c) || c == 95
}

fn is_alnum_or_underscore(c: i32) -> bool {
    is_alpha(c) || is_digit(c) || c == 95
}

fn is_whitespace(c: i32) -> bool {
    c == 32 || c == 10 || c == 13 || c == 9
}

fn classify_keyword_2(c0: i32, c1: i32) -> i32 {
    if c0 == 102 && c1 == 110 { TK_FN }
    else if c0 == 105 && c1 == 102 { TK_IF }
    else if c0 == 105 && c1 == 110 { TK_IN }
    else { TK_IDENT }
}

fn classify_keyword_3(c0: i32, c1: i32, c2: i32) -> i32 {
    if c0 == 108 && c1 == 101 && c2 == 116 { TK_LET }
    else if c0 == 109 && c1 == 117 && c2 == 116 { TK_MUT }
    else if c0 == 102 && c1 == 111 && c2 == 114 { TK_FOR }
    else if c0 == 117 && c1 == 115 && c2 == 101 { TK_USE }
    else { TK_IDENT }
}

fn main() -> i32 {
    print_bool(is_digit(48));
    print_bool(is_digit(65));
    print_bool(is_alpha(65));
    print_bool(is_whitespace(32));
    print_int(classify_keyword_2(102, 110));
    print_int(classify_keyword_3(108, 101, 116));
    0
}
