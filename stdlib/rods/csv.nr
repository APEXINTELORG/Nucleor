// =====================================================
// rods/csv — CSV parsing and formatting
// =====================================================
// Import: import "stdlib/rods/csv.nr"
// Provides: csv_parse_field, csv_parse_line, csv_escape, csv_format_line
// =====================================================

import "stdlib/rods/strings.nr"

// Parse a single CSV field starting at position pos in the string
// Returns a Vec: [0] = parsed field value (str), [1] = new position (i64)
// Handles quoted fields with escaped quotes ("")
fn csv_parse_field(line: str, pos: i64) -> Vec<i32> {
    let mut result: Vec<i32> = Vec::new();
    let slen: i64 = str_len(line);

    if pos >= slen {
        result.push("");
        result.push(pos);
        return result;
    };

    let c: i64 = str_char_at(line, pos);

    // Quoted field
    if c == 34 {
        let mut sb: i64 = sb_new();
        let mut i: i64 = pos + 1;
        while i < slen {
            let ch: i64 = str_char_at(line, i);
            if ch == 34 {
                // Check for escaped quote ""
                if i + 1 < slen && str_char_at(line, i + 1) == 34 {
                    sb_append(sb, "\"");
                    i = i + 2;
                } else {
                    // End of quoted field
                    i = i + 1;
                    // Skip comma if present
                    if i < slen && str_char_at(line, i) == 44 { i = i + 1; };
                    result.push(sb_to_str(sb));
                    result.push(i);
                    return result;
                };
            } else {
                sb_append(sb, strings_char_to_str(ch));
                i = i + 1;
            };
        };
        result.push(sb_to_str(sb));
        result.push(i);
        return result;
    };

    // Unquoted field — read until comma or end
    let mut sb: i64 = sb_new();
    let mut i: i64 = pos;
    while i < slen {
        let ch: i64 = str_char_at(line, i);
        if ch == 44 {
            i = i + 1;
            result.push(sb_to_str(sb));
            result.push(i);
            return result;
        };
        sb_append(sb, strings_char_to_str(ch));
        i = i + 1;
    };
    result.push(sb_to_str(sb));
    result.push(i);
    return result;
}

// Parse a CSV line into a Vec of field strings
fn csv_parse_line(line: str) -> Vec<i32> {
    let mut fields: Vec<i32> = Vec::new();
    let slen: i64 = str_len(line);
    if slen == 0 { return fields; };

    let mut pos: i64 = 0;
    while pos <= slen {
        let parsed: Vec<i32> = csv_parse_field(line, pos);
        fields.push(parsed.get(0));
        let new_pos: i64 = parsed.get(1);
        if new_pos == pos && pos >= slen { break; };
        if new_pos == pos { pos = pos + 1; } else { pos = new_pos; };
        // If we consumed up to the end and last char was comma, add empty field
        if pos == slen && str_char_at(line, slen - 1) == 44 {
            fields.push("");
            break;
        };
    };
    return fields;
}

// Escape a field value for CSV output
// Wraps in quotes if the value contains comma, quote, or newline
fn csv_escape(field: str) -> str {
    let flen: i64 = str_len(field);
    let mut needs_quote: i64 = 0;
    let mut i: i64 = 0;
    while i < flen {
        let c: i64 = str_char_at(field, i);
        if c == 44 || c == 34 || c == 10 || c == 13 { needs_quote = 1; break; };
        i = i + 1;
    };
    if needs_quote == 0 { return field; };

    // Build quoted version with escaped quotes
    let mut sb: i64 = sb_new();
    sb_append(sb, "\"");
    i = 0;
    while i < flen {
        let c: i64 = str_char_at(field, i);
        if c == 34 {
            sb_append(sb, "\"\"");
        } else {
            sb_append(sb, strings_char_to_str(c));
        };
        i = i + 1;
    };
    sb_append(sb, "\"");
    return sb_to_str(sb);
}

// Format a Vec of field strings into a CSV line
fn csv_format_line(fields: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < fields.len() {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, csv_escape(fields.get(i)));
        i = i + 1;
    };
    return sb_to_str(sb);
}
