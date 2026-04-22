// =====================================================
// rods/fmt — String formatting
// =====================================================
// Import: import "stdlib/rods/fmt.nr"
// Depends: import "stdlib/rods/strings.nr" (for strings_char_to_str)
// Provides: fmt_int, fmt_bool, fmt_hex, fmt_oct, fmt_bin, fmt_float_approx,
//   fmt_pad_left, fmt_pad_right, fmt_format, fmt_to_int
// =====================================================

import "stdlib/rods/strings.nr"

fn fmt_to_int(s: str) -> i64 {
    let slen: i64 = str_len(s);
    let mut result: i64 = 0;
    let mut i: i64 = 0;
    let mut neg: i64 = 0;
    if slen > 0 && str_char_at(s, 0) == 45 { neg = 1; i = 1; };
    while i < slen { result = result * 10 + (str_char_at(s, i) - 48); i = i + 1; };
    if neg == 1 { return 0 - result; };
    return result;
}

fn fmt_int(n: i64) -> str {
    if n == 0 { return "0"; };
    let mut val: i64 = n;
    if val < 0 { val = 0 - val; };
    let mut sb: i64 = sb_new();
    let digits: str = "0123456789";
    let mut buf: Vec<i32> = Vec::new();
    while val > 0 {
        let d: i64 = val - (val / 10) * 10;
        buf.push(str_substring(digits, d, d + 1));
        val = val / 10;
    };
    if n < 0 { sb_append(sb, "-"); };
    let mut i: i64 = buf.len() - 1;
    while i >= 0 { sb_append(sb, buf.get(i)); i = i - 1; };
    return sb_to_str(sb);
}

fn fmt_bool(b: i64) -> str {
    if b != 0 { return "true"; };
    return "false";
}

fn fmt_hex(n: i64) -> str {
    if n == 0 { return "0x0"; };
    let hex_digits: str = "0123456789abcdef";
    let mut val: i64 = n;
    let mut neg: i64 = 0;
    if val < 0 { neg = 1; val = 0 - val; };
    let mut buf: Vec<i32> = Vec::new();
    while val > 0 {
        let d: i64 = val - (val / 16) * 16;
        buf.push(str_substring(hex_digits, d, d + 1));
        val = val / 16;
    };
    let mut sb: i64 = sb_new();
    if neg == 1 { sb_append(sb, "-"); };
    sb_append(sb, "0x");
    let mut i: i64 = buf.len() - 1;
    while i >= 0 { sb_append(sb, buf.get(i)); i = i - 1; };
    return sb_to_str(sb);
}

fn fmt_oct(n: i64) -> str {
    if n == 0 { return "0o0"; };
    let oct_digits: str = "01234567";
    let mut val: i64 = n;
    let mut neg: i64 = 0;
    if val < 0 { neg = 1; val = 0 - val; };
    let mut buf: Vec<i32> = Vec::new();
    while val > 0 {
        let d: i64 = val - (val / 8) * 8;
        buf.push(str_substring(oct_digits, d, d + 1));
        val = val / 8;
    };
    let mut sb: i64 = sb_new();
    if neg == 1 { sb_append(sb, "-"); };
    sb_append(sb, "0o");
    let mut i: i64 = buf.len() - 1;
    while i >= 0 { sb_append(sb, buf.get(i)); i = i - 1; };
    return sb_to_str(sb);
}

fn fmt_bin(n: i64) -> str {
    if n == 0 { return "0b0"; };
    let mut val: i64 = n;
    let mut neg: i64 = 0;
    if val < 0 { neg = 1; val = 0 - val; };
    let mut buf: Vec<i32> = Vec::new();
    while val > 0 {
        let d: i64 = val - (val / 2) * 2;
        if d == 0 { buf.push("0"); } else { buf.push("1"); };
        val = val / 2;
    };
    let mut sb: i64 = sb_new();
    if neg == 1 { sb_append(sb, "-"); };
    sb_append(sb, "0b");
    let mut i: i64 = buf.len() - 1;
    while i >= 0 { sb_append(sb, buf.get(i)); i = i - 1; };
    return sb_to_str(sb);
}

fn fmt_pad_left(s: str, width: i64, pad_ch: str) -> str {
    let slen: i64 = str_len(s);
    if slen >= width { return s; };
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < width - slen { sb_append(sb, pad_ch); i = i + 1; };
    sb_append(sb, s);
    return sb_to_str(sb);
}

fn fmt_pad_right(s: str, width: i64, pad_ch: str) -> str {
    let slen: i64 = str_len(s);
    if slen >= width { return s; };
    let mut sb: i64 = sb_new();
    sb_append(sb, s);
    let mut i: i64 = 0;
    while i < width - slen { sb_append(sb, pad_ch); i = i + 1; };
    return sb_to_str(sb);
}

// fmt_format: Simple template formatting
// Replaces {} placeholders with values from the args vec (as strings)
// Example: fmt_format("Hello, {}! You have {} items.", args)
//   where args = ["world", "5"] -> "Hello, world! You have 5 items."
fn fmt_format(template: str, args: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let tlen: i64 = str_len(template);
    let mut p: i64 = 0;
    let mut arg_idx: i64 = 0;
    while p < tlen {
        let c: i64 = str_char_at(template, p);
        if c == 123 && p + 1 < tlen && str_char_at(template, p + 1) == 125 {
            if arg_idx < args.len() {
                sb_append(sb, args.get(arg_idx));
                arg_idx = arg_idx + 1;
            } else {
                sb_append(sb, "{}");
            };
            p = p + 2;
        } else {
            sb_append(sb, strings_char_to_str(c));
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}
