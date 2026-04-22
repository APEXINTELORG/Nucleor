// =====================================================
// rods/base64 — Base64 encoding/decoding
// =====================================================
// Import: import "stdlib/rods/base64.nr"
// Provides: b64_encode_byte, b64_decode_byte, b64_encode, b64_decode
// =====================================================

import "stdlib/rods/strings.nr"

// Returns the base64 character (as single-char string) for a 6-bit value 0..63
fn b64_encode_byte(val: i64) -> str {
    let table: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    if val < 0 || val > 63 { return "="; };
    return str_substring(table, val, val + 1);
}

// Returns the 6-bit value (0..63) for a base64 character code, or -1 for '=' or invalid
fn b64_decode_byte(c: i64) -> i64 {
    // A-Z = 65..90 -> 0..25
    if c >= 65 && c <= 90 { return c - 65; };
    // a-z = 97..122 -> 26..51
    if c >= 97 && c <= 122 { return c - 97 + 26; };
    // 0-9 = 48..57 -> 52..61
    if c >= 48 && c <= 57 { return c - 48 + 52; };
    // + = 43 -> 62
    if c == 43 { return 62; };
    // / = 47 -> 63
    if c == 47 { return 63; };
    return 0 - 1;
}

// Encode a string to base64
// Processes 3 bytes at a time into 4 base64 characters
fn b64_encode(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let b0: i64 = str_char_at(s, i);
        let mut b1: i64 = 0;
        let mut b2: i64 = 0;
        let mut pad: i64 = 0;
        if i + 1 < slen { b1 = str_char_at(s, i + 1); } else { pad = pad + 1; };
        if i + 2 < slen { b2 = str_char_at(s, i + 2); } else { pad = pad + 1; };

        // Combine 3 bytes into a 24-bit number using multiplication
        // n = b0 * 65536 + b1 * 256 + b2
        let n: i64 = b0 * 65536 + b1 * 256 + b2;

        // Extract 4 6-bit groups
        let c0: i64 = n / 262144;
        let c1: i64 = (n - c0 * 262144) / 4096;
        let c2: i64 = (n - c0 * 262144 - c1 * 4096) / 64;
        let c3: i64 = n - c0 * 262144 - c1 * 4096 - c2 * 64;

        sb_append(sb, b64_encode_byte(c0));
        sb_append(sb, b64_encode_byte(c1));
        if pad >= 2 { sb_append(sb, "="); } else { sb_append(sb, b64_encode_byte(c2)); };
        if pad >= 1 { sb_append(sb, "="); } else { sb_append(sb, b64_encode_byte(c3)); };

        i = i + 3;
    };
    return sb_to_str(sb);
}

// Decode a base64 string back to the original string
fn b64_decode(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i + 3 < slen {
        let v0: i64 = b64_decode_byte(str_char_at(s, i));
        let v1: i64 = b64_decode_byte(str_char_at(s, i + 1));
        let v2: i64 = b64_decode_byte(str_char_at(s, i + 2));
        let v3: i64 = b64_decode_byte(str_char_at(s, i + 3));

        let a: i64 = v0;
        let b: i64 = v1;
        if a < 0 || b < 0 { i = i + 4; continue; };

        // Reconstruct: n = v0 * 262144 + v1 * 4096 + v2 * 64 + v3
        let mut safe_v2: i64 = v2;
        let mut safe_v3: i64 = v3;
        if safe_v2 < 0 { safe_v2 = 0; };
        if safe_v3 < 0 { safe_v3 = 0; };
        let n: i64 = a * 262144 + b * 4096 + safe_v2 * 64 + safe_v3;

        let byte0: i64 = n / 65536;
        let byte1: i64 = (n - byte0 * 65536) / 256;
        let byte2: i64 = n - byte0 * 65536 - byte1 * 256;

        sb_append(sb, strings_char_to_str(byte0));
        if v2 >= 0 { sb_append(sb, strings_char_to_str(byte1)); };
        if v3 >= 0 { sb_append(sb, strings_char_to_str(byte2)); };

        i = i + 4;
    };
    return sb_to_str(sb);
}
