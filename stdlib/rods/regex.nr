// =====================================================
// rods/regex — Simple pattern matching utilities
// =====================================================
// Import: import "stdlib/rods/regex.nr"
// Provides: regex_match_digit, regex_match_alpha, regex_match_any,
//   regex_match_literal, regex_find_first
// =====================================================

// Check if character at position is a digit (0-9)
// Returns 1 if match, 0 if no match
fn regex_match_digit(s: str, pos: i64) -> i64 {
    if pos < 0 || pos >= str_len(s) { return 0; };
    let c: i64 = str_char_at(s, pos);
    if c >= 48 && c <= 57 { return 1; };
    return 0;
}

// Check if character at position is alphabetic (a-z, A-Z)
// Returns 1 if match, 0 if no match
fn regex_match_alpha(s: str, pos: i64) -> i64 {
    if pos < 0 || pos >= str_len(s) { return 0; };
    let c: i64 = str_char_at(s, pos);
    if c >= 65 && c <= 90 { return 1; };
    if c >= 97 && c <= 122 { return 1; };
    return 0;
}

// Match any single character at position
// Returns 1 if position is valid, 0 if out of bounds
fn regex_match_any(s: str, pos: i64) -> i64 {
    if pos < 0 || pos >= str_len(s) { return 0; };
    return 1;
}

// Match a literal substring starting at position
// Returns 1 if the literal matches at pos, 0 otherwise
fn regex_match_literal(s: str, pos: i64, literal: str) -> i64 {
    let slen: i64 = str_len(s);
    let llen: i64 = str_len(literal);
    if pos < 0 || pos + llen > slen { return 0; };
    if str_eq(str_substring(s, pos, pos + llen), literal) { return 1; };
    return 0;
}

// Find the first occurrence of a simple pattern in a string
// Pattern language:
//   \d = digit, \a = alpha, . = any char, other chars = literal
// Returns the index of the first match, or -1 if not found
fn regex_find_first(s: str, pattern: str) -> i64 {
    let slen: i64 = str_len(s);
    let plen: i64 = str_len(pattern);
    if plen == 0 { return 0; };
    if slen == 0 { return 0 - 1; };

    // Calculate effective pattern length (count of match positions needed)
    let mut eff_len: i64 = 0;
    let mut pi: i64 = 0;
    while pi < plen {
        let pc: i64 = str_char_at(pattern, pi);
        if pc == 92 && pi + 1 < plen {
            pi = pi + 2;
        } else {
            pi = pi + 1;
        };
        eff_len = eff_len + 1;
    };

    let mut i: i64 = 0;
    while i <= slen - eff_len {
        // Try to match pattern starting at position i
        let mut si: i64 = i;
        let mut pj: i64 = 0;
        let mut matched: i64 = 1;

        while pj < plen && matched == 1 {
            let pc: i64 = str_char_at(pattern, pj);
            if pc == 92 && pj + 1 < plen {
                // Escape sequence
                let ec: i64 = str_char_at(pattern, pj + 1);
                if ec == 100 {
                    // \d = digit
                    if regex_match_digit(s, si) == 0 { matched = 0; };
                } else if ec == 97 {
                    // \a = alpha
                    if regex_match_alpha(s, si) == 0 { matched = 0; };
                } else {
                    // Literal escaped char
                    if si >= slen || str_char_at(s, si) != ec { matched = 0; };
                };
                pj = pj + 2;
            } else if pc == 46 {
                // . = any character
                if regex_match_any(s, si) == 0 { matched = 0; };
                pj = pj + 1;
            } else {
                // Literal character
                if si >= slen || str_char_at(s, si) != pc { matched = 0; };
                pj = pj + 1;
            };
            si = si + 1;
        };

        if matched == 1 { return i; };
        i = i + 1;
    };
    return 0 - 1;
}
