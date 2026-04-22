// Nucleor stdlib: source_reader
// Source text utilities for the bootstrap lexer.
// Provides character-at-position access and span extraction.

// Character constants (ASCII)
const CH_NUL: i32 = 0;
const CH_TAB: i32 = 9;
const CH_LF: i32 = 10;
const CH_CR: i32 = 13;
const CH_SPACE: i32 = 32;
const CH_BANG: i32 = 33;
const CH_QUOTE: i32 = 34;
const CH_HASH: i32 = 35;
const CH_PERCENT: i32 = 37;
const CH_AMP: i32 = 38;
const CH_LPAREN: i32 = 40;
const CH_RPAREN: i32 = 41;
const CH_STAR: i32 = 42;
const CH_PLUS: i32 = 43;
const CH_COMMA: i32 = 44;
const CH_MINUS: i32 = 45;
const CH_DOT: i32 = 46;
const CH_SLASH: i32 = 47;
const CH_0: i32 = 48;
const CH_9: i32 = 57;
const CH_COLON: i32 = 58;
const CH_SEMICOLON: i32 = 59;
const CH_LT: i32 = 60;
const CH_EQ: i32 = 61;
const CH_GT: i32 = 62;
const CH_AT: i32 = 64;
const CH_A: i32 = 65;
const CH_Z: i32 = 90;
const CH_LBRACKET: i32 = 91;
const CH_BACKSLASH: i32 = 92;
const CH_RBRACKET: i32 = 93;
const CH_CARET: i32 = 94;
const CH_UNDERSCORE: i32 = 95;
const CH_a: i32 = 97;
const CH_z: i32 = 122;
const CH_LBRACE: i32 = 123;
const CH_PIPE: i32 = 124;
const CH_RBRACE: i32 = 125;

fn is_ascii_digit(c: i32) -> bool {
    c >= CH_0 && c <= CH_9
}

fn is_ascii_upper(c: i32) -> bool {
    c >= CH_A && c <= CH_Z
}

fn is_ascii_lower(c: i32) -> bool {
    c >= CH_a && c <= CH_z
}

fn is_ascii_alpha(c: i32) -> bool {
    is_ascii_upper(c) || is_ascii_lower(c)
}

fn is_ident_start(c: i32) -> bool {
    is_ascii_alpha(c) || c == CH_UNDERSCORE
}

fn is_ident_continue(c: i32) -> bool {
    is_ascii_alpha(c) || is_ascii_digit(c) || c == CH_UNDERSCORE
}

fn is_ws(c: i32) -> bool {
    c == CH_SPACE || c == CH_TAB || c == CH_LF || c == CH_CR
}

fn is_hex_digit(c: i32) -> bool {
    is_ascii_digit(c) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)
}

fn digit_value(c: i32) -> i32 {
    if is_ascii_digit(c) { c - CH_0 }
    else { -1 }
}

fn hex_digit_value(c: i32) -> i32 {
    if is_ascii_digit(c) { c - CH_0 }
    else if c >= 65 && c <= 70 { c - 65 + 10 }
    else if c >= 97 && c <= 102 { c - 97 + 10 }
    else { -1 }
}

fn main() -> i32 {
    // Test character classification
    print_bool(is_ascii_digit(CH_0));
    print_bool(is_ascii_digit(CH_A));
    print_bool(is_ascii_alpha(CH_a));
    print_bool(is_ident_start(CH_UNDERSCORE));
    print_bool(is_ws(CH_SPACE));
    print_bool(is_hex_digit(CH_a));

    // Test digit values
    print_int(digit_value(CH_0));
    print_int(digit_value(CH_9));
    print_int(hex_digit_value(CH_a));
    print_int(hex_digit_value(CH_A));
    0
}
