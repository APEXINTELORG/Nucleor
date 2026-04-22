// char_predicates — RFC-0017 stdlib enrichment.
//
// All take an i64 char code (ASCII subset of UTF-8) and return 0/1
// (predicates) or a transformed char code.

fn main() -> i64 {
    let mut fail: i64 = 0;

    // Alpha: A-Z, a-z; not digits or symbols.
    if char_is_alpha(65) != 1 { fail = fail + 1; print("FAIL alpha A"); };
    if char_is_alpha(97) != 1 { fail = fail + 1; print("FAIL alpha a"); };
    if char_is_alpha(48) != 0 { fail = fail + 1; print("FAIL alpha 0"); };
    if char_is_alpha(64) != 0 { fail = fail + 1; print("FAIL alpha @"); };

    // Digit: 0-9.
    if char_is_digit(48) != 1 { fail = fail + 1; print("FAIL digit 0"); };
    if char_is_digit(57) != 1 { fail = fail + 1; print("FAIL digit 9"); };
    if char_is_digit(65) != 0 { fail = fail + 1; print("FAIL digit A"); };

    // Alnum: alpha + digit.
    if char_is_alnum(65) != 1 { fail = fail + 1; print("FAIL alnum A"); };
    if char_is_alnum(48) != 1 { fail = fail + 1; print("FAIL alnum 0"); };
    if char_is_alnum(64) != 0 { fail = fail + 1; print("FAIL alnum @"); };

    // Whitespace: space/tab/CR/LF/VT/FF.
    if char_is_whitespace(32) != 1 { fail = fail + 1; print("FAIL ws SP"); };
    if char_is_whitespace(9) != 1 { fail = fail + 1; print("FAIL ws TAB"); };
    if char_is_whitespace(10) != 1 { fail = fail + 1; print("FAIL ws LF"); };
    if char_is_whitespace(65) != 0 { fail = fail + 1; print("FAIL ws A"); };

    // Case predicates.
    if char_is_upper(65) != 1 { fail = fail + 1; print("FAIL upper A"); };
    if char_is_lower(97) != 1 { fail = fail + 1; print("FAIL lower a"); };
    if char_is_upper(97) != 0 { fail = fail + 1; print("FAIL upper a"); };

    // Hex digit: 0-9, a-f, A-F.
    if char_is_hex_digit(48) != 1 { fail = fail + 1; print("FAIL hex 0"); };
    if char_is_hex_digit(70) != 1 { fail = fail + 1; print("FAIL hex F"); };
    if char_is_hex_digit(71) != 0 { fail = fail + 1; print("FAIL hex G"); };

    // Punct: ! through / and others.
    if char_is_punct(33) != 1 { fail = fail + 1; print("FAIL punct !"); };
    if char_is_punct(64) != 1 { fail = fail + 1; print("FAIL punct @"); };
    if char_is_punct(48) != 0 { fail = fail + 1; print("FAIL punct 0"); };

    // ASCII: 0..127.
    if char_is_ascii(65) != 1 { fail = fail + 1; print("FAIL ascii A"); };
    if char_is_ascii(200) != 0 { fail = fail + 1; print("FAIL ascii 200"); };

    // Case transform: identity for non-letters.
    if char_to_upper(97) != 65 { fail = fail + 1; print("FAIL toupper a"); };
    if char_to_upper(48) != 48 { fail = fail + 1; print("FAIL toupper 0"); };
    if char_to_lower(65) != 97 { fail = fail + 1; print("FAIL tolower A"); };
    if char_to_lower(48) != 48 { fail = fail + 1; print("FAIL tolower 0"); };

    // Digit value: 0-9 + a-f / A-F; else -1.
    if char_digit_value(57) != 9 { fail = fail + 1; print("FAIL digit_val 9"); };
    if char_digit_value(70) != 15 { fail = fail + 1; print("FAIL digit_val F"); };
    if char_digit_value(102) != 15 { fail = fail + 1; print("FAIL digit_val f"); };
    if char_digit_value(103) != (0 - 1) { fail = fail + 1; print("FAIL digit_val g"); };

    if fail == 0 { print("OK char_predicates"); return 0; };
    return 1;
}
