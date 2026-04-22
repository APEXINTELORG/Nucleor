// =====================================================
// rods/strings — String manipulation
// =====================================================
// Import: import "stdlib/rods/strings.nr"
// Provides: strings_contains, strings_starts_with, strings_ends_with,
//   strings_index_of, strings_split, strings_join, strings_trim,
//   strings_to_upper, strings_to_lower, strings_replace, strings_repeat,
//   strings_char_to_str, strings_pad_left, strings_pad_right
// =====================================================

fn strings_char_to_str(c: i64) -> str {
    let digits: str = "0123456789";
    let upper: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    let lower: str = "abcdefghijklmnopqrstuvwxyz";
    if c >= 48 && c <= 57 { return str_substring(digits, c - 48, c - 47); };
    if c >= 65 && c <= 90 { return str_substring(upper, c - 65, c - 64); };
    if c >= 97 && c <= 122 { return str_substring(lower, c - 97, c - 96); };
    if c == 32 { return " "; };
    if c == 10 { return "\n"; };
    if c == 9 { return "\t"; };
    if c == 13 { return "\r"; };
    if c == 33 { return "!"; };
    if c == 34 { return "\""; };
    if c == 35 { return "#"; };
    if c == 36 { return "$"; };
    if c == 37 { return "%"; };
    if c == 38 { return "&"; };
    if c == 39 { return "'"; };
    if c == 40 { return "("; };
    if c == 41 { return ")"; };
    if c == 42 { return "*"; };
    if c == 43 { return "+"; };
    if c == 44 { return ","; };
    if c == 45 { return "-"; };
    if c == 46 { return "."; };
    if c == 47 { return "/"; };
    if c == 58 { return ":"; };
    if c == 59 { return ";"; };
    if c == 60 { return "<"; };
    if c == 61 { return "="; };
    if c == 62 { return ">"; };
    if c == 63 { return "?"; };
    if c == 64 { return "@"; };
    if c == 91 { return "["; };
    if c == 92 { return "\\"; };
    if c == 93 { return "]"; };
    if c == 94 { return "^"; };
    if c == 95 { return "_"; };
    if c == 96 { return "`"; };
    if c == 123 { return "{"; };
    if c == 124 { return "|"; };
    if c == 125 { return "}"; };
    if c == 126 { return "~"; };
    return "?";
}

fn strings_contains(haystack: str, needle: str) -> i64 {
    let hlen: i64 = str_len(haystack);
    let nlen: i64 = str_len(needle);
    if nlen == 0 { return 1; };
    if nlen > hlen { return 0; };
    let mut i: i64 = 0;
    while i <= hlen - nlen {
        if str_eq(str_substring(haystack, i, i + nlen), needle) { return 1; };
        i = i + 1;
    };
    return 0;
}

fn strings_starts_with(s: str, prefix: str) -> i64 {
    let plen: i64 = str_len(prefix);
    if plen > str_len(s) { return 0; };
    return str_eq(str_substring(s, 0, plen), prefix);
}

fn strings_ends_with(s: str, suffix: str) -> i64 {
    let slen: i64 = str_len(s);
    let xlen: i64 = str_len(suffix);
    if xlen > slen { return 0; };
    return str_eq(str_substring(s, slen - xlen, slen), suffix);
}

fn strings_index_of(s: str, needle: str) -> i64 {
    let slen: i64 = str_len(s);
    let nlen: i64 = str_len(needle);
    if nlen == 0 { return 0; };
    if nlen > slen { return 0 - 1; };
    let mut i: i64 = 0;
    while i <= slen - nlen {
        if str_eq(str_substring(s, i, i + nlen), needle) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

fn strings_last_index_of(s: str, needle: str) -> i64 {
    let slen: i64 = str_len(s);
    let nlen: i64 = str_len(needle);
    if nlen == 0 { return slen; };
    if nlen > slen { return 0 - 1; };
    let mut i: i64 = slen - nlen;
    while i >= 0 {
        if str_eq(str_substring(s, i, i + nlen), needle) { return i; };
        i = i - 1;
    };
    return 0 - 1;
}

fn strings_split(s: str, delim: str) -> Vec<i32> {
    let mut parts: Vec<i32> = Vec::new();
    let slen: i64 = str_len(s);
    let dlen: i64 = str_len(delim);
    if dlen == 0 { parts.push(s); return parts; };
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= slen - dlen {
        if str_eq(str_substring(s, i, i + dlen), delim) {
            parts.push(str_substring(s, start, i));
            i = i + dlen;
            start = i;
        } else {
            i = i + 1;
        };
    };
    parts.push(str_substring(s, start, slen));
    return parts;
}

fn strings_join(parts: Vec<i32>, sep: str) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < parts.len() {
        if i > 0 { sb_append(sb, sep); };
        sb_append(sb, parts.get(i));
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn strings_trim(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut start: i64 = 0;
    while start < slen {
        let c: i64 = str_char_at(s, start);
        if c != 32 && c != 9 && c != 10 && c != 13 { break; };
        start = start + 1;
    };
    let mut end: i64 = slen;
    while end > start {
        let c: i64 = str_char_at(s, end - 1);
        if c != 32 && c != 9 && c != 10 && c != 13 { break; };
        end = end - 1;
    };
    return str_substring(s, start, end);
}

fn strings_trim_left(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut start: i64 = 0;
    while start < slen {
        let c: i64 = str_char_at(s, start);
        if c != 32 && c != 9 && c != 10 && c != 13 { break; };
        start = start + 1;
    };
    return str_substring(s, start, slen);
}

fn strings_trim_right(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut end: i64 = slen;
    while end > 0 {
        let c: i64 = str_char_at(s, end - 1);
        if c != 32 && c != 9 && c != 10 && c != 13 { break; };
        end = end - 1;
    };
    return str_substring(s, 0, end);
}

fn strings_to_upper(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c >= 97 && c <= 122 {
            sb_append(sb, strings_char_to_str(c - 32));
        } else {
            sb_append(sb, strings_char_to_str(c));
        };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn strings_to_lower(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c >= 65 && c <= 90 {
            sb_append(sb, strings_char_to_str(c + 32));
        } else {
            sb_append(sb, strings_char_to_str(c));
        };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn strings_replace(s: str, old_s: str, new_s: str) -> str {
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(s);
    let olen: i64 = str_len(old_s);
    if olen == 0 { return s; };
    let mut i: i64 = 0;
    while i < slen {
        if i <= slen - olen && str_eq(str_substring(s, i, i + olen), old_s) {
            sb_append(sb, new_s);
            i = i + olen;
        } else {
            sb_append(sb, strings_char_to_str(str_char_at(s, i)));
            i = i + 1;
        };
    };
    return sb_to_str(sb);
}

fn strings_replace_first(s: str, old_s: str, new_s: str) -> str {
    let idx: i64 = strings_index_of(s, old_s);
    if idx < 0 { return s; };
    let olen: i64 = str_len(old_s);
    return str_concat(str_substring(s, 0, idx), str_concat(new_s, str_substring(s, idx + olen, str_len(s))));
}

fn strings_repeat(s: str, n: i64) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < n { sb_append(sb, s); i = i + 1; };
    return sb_to_str(sb);
}

fn strings_pad_left(s: str, width: i64, pad_ch: str) -> str {
    let slen: i64 = str_len(s);
    if slen >= width { return s; };
    return str_concat(strings_repeat(pad_ch, width - slen), s);
}

fn strings_pad_right(s: str, width: i64, pad_ch: str) -> str {
    let slen: i64 = str_len(s);
    if slen >= width { return s; };
    return str_concat(s, strings_repeat(pad_ch, width - slen));
}

fn strings_count(s: str, needle: str) -> i64 {
    let slen: i64 = str_len(s);
    let nlen: i64 = str_len(needle);
    if nlen == 0 { return 0; };
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i <= slen - nlen {
        if str_eq(str_substring(s, i, i + nlen), needle) {
            count = count + 1;
            i = i + nlen;
        } else {
            i = i + 1;
        };
    };
    return count;
}

fn strings_is_digit(c: i64) -> i64 {
    if c >= 48 && c <= 57 { return 1; };
    return 0;
}

fn strings_is_alpha(c: i64) -> i64 {
    if c >= 65 && c <= 90 { return 1; };
    if c >= 97 && c <= 122 { return 1; };
    return 0;
}

fn strings_is_alnum(c: i64) -> i64 {
    if strings_is_alpha(c) == 1 { return 1; };
    if strings_is_digit(c) == 1 { return 1; };
    return 0;
}

fn strings_is_space(c: i64) -> i64 {
    if c == 32 || c == 9 || c == 10 || c == 13 { return 1; };
    return 0;
}
