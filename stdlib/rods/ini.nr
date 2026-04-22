// =====================================================
// rods/ini — INI file parsing utilities
// =====================================================
// Import: import "stdlib/rods/ini.nr"
// Provides: ini_parse_line, ini_get_key, ini_get_value,
//   ini_is_section, ini_is_comment
// =====================================================

// Check if a line is a comment (starts with ; or # after trimming)
fn ini_is_comment(line: str) -> i64 {
    let slen: i64 = str_len(line);
    // Find first non-whitespace character
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(line, i);
        if c != 32 && c != 9 { break; };
        i = i + 1;
    };
    if i >= slen { return 0; };
    let c: i64 = str_char_at(line, i);
    if c == 59 || c == 35 { return 1; };
    return 0;
}

// Check if a line is a section header [section]
fn ini_is_section(line: str) -> i64 {
    let slen: i64 = str_len(line);
    // Find first non-whitespace
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(line, i);
        if c != 32 && c != 9 { break; };
        i = i + 1;
    };
    if i >= slen { return 0; };
    if str_char_at(line, i) != 91 { return 0; };
    // Check if it ends with ]
    let mut j: i64 = slen - 1;
    while j > i {
        let c: i64 = str_char_at(line, j);
        if c != 32 && c != 9 && c != 10 && c != 13 { break; };
        j = j - 1;
    };
    if str_char_at(line, j) == 93 { return 1; };
    return 0;
}

// Parse a line and return its type and content as a Vec:
//   [0] = type: 0=empty, 1=comment, 2=section, 3=key-value
//   [1] = key or section name (str)
//   [2] = value (str, only for key-value lines)
fn ini_parse_line(line: str) -> Vec<i32> {
    let mut result: Vec<i32> = Vec::new();
    let slen: i64 = str_len(line);

    // Find first non-whitespace
    let mut start: i64 = 0;
    while start < slen {
        let c: i64 = str_char_at(line, start);
        if c != 32 && c != 9 && c != 10 && c != 13 { break; };
        start = start + 1;
    };

    // Empty line
    if start >= slen {
        result.push(0);
        result.push("");
        result.push("");
        return result;
    };

    let first: i64 = str_char_at(line, start);

    // Comment
    if first == 59 || first == 35 {
        result.push(1);
        result.push(str_substring(line, start + 1, slen));
        result.push("");
        return result;
    };

    // Section
    if first == 91 {
        // Find closing bracket
        let mut end: i64 = slen - 1;
        while end > start {
            let c: i64 = str_char_at(line, end);
            if c != 32 && c != 9 && c != 10 && c != 13 { break; };
            end = end - 1;
        };
        if str_char_at(line, end) == 93 {
            // Trim whitespace from section name
            let mut ns: i64 = start + 1;
            let mut ne: i64 = end;
            while ns < ne && (str_char_at(line, ns) == 32 || str_char_at(line, ns) == 9) { ns = ns + 1; };
            while ne > ns && (str_char_at(line, ne - 1) == 32 || str_char_at(line, ne - 1) == 9) { ne = ne - 1; };
            result.push(2);
            result.push(str_substring(line, ns, ne));
            result.push("");
            return result;
        };
    };

    // Key-value: find the '=' separator
    let mut eq_pos: i64 = 0 - 1;
    let mut i: i64 = start;
    while i < slen {
        if str_char_at(line, i) == 61 { eq_pos = i; break; };
        i = i + 1;
    };

    if eq_pos >= 0 {
        // Trim key
        let mut ke: i64 = eq_pos;
        while ke > start && (str_char_at(line, ke - 1) == 32 || str_char_at(line, ke - 1) == 9) { ke = ke - 1; };
        let key: str = str_substring(line, start, ke);

        // Trim value
        let mut vs: i64 = eq_pos + 1;
        while vs < slen && (str_char_at(line, vs) == 32 || str_char_at(line, vs) == 9) { vs = vs + 1; };
        let mut ve: i64 = slen;
        while ve > vs && (str_char_at(line, ve - 1) == 32 || str_char_at(line, ve - 1) == 9 || str_char_at(line, ve - 1) == 10 || str_char_at(line, ve - 1) == 13) { ve = ve - 1; };
        let val: str = str_substring(line, vs, ve);

        result.push(3);
        result.push(key);
        result.push(val);
        return result;
    };

    // Unknown — treat as empty
    result.push(0);
    result.push(line);
    result.push("");
    return result;
}

// Get the key from a key=value line (convenience wrapper)
fn ini_get_key(line: str) -> str {
    let parsed: Vec<i32> = ini_parse_line(line);
    if parsed.get(0) == 3 { return parsed.get(1); };
    return "";
}

// Get the value from a key=value line (convenience wrapper)
fn ini_get_value(line: str) -> str {
    let parsed: Vec<i32> = ini_parse_line(line);
    if parsed.get(0) == 3 { return parsed.get(2); };
    return "";
}
