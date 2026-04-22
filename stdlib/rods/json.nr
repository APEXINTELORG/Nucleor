// =====================================================
// rods/json — JSON parser and serializer
// =====================================================
// Import: import "stdlib/rods/json.nr"
// Depends: import "stdlib/rods/strings.nr" (for strings_char_to_str)
// Provides: json_parse, json_type, json_string, json_int, json_f64, json_bool,
//   json_array_len, json_array_get, json_object_get, json_object_keys,
//   json_stringify, json_stringify_pretty, json_null, json_from_int,
//   json_from_f64, json_from_string, json_from_bool, json_array_new,
//   json_array_push, json_object_new, json_object_set
// =====================================================

import "stdlib/rods/strings.nr"
import "stdlib/rods/fmt.nr"
import "stdlib/rods/complex.nr"

// JSON value types
// 0 = null, 1 = bool, 2 = number (i64), 3 = string, 4 = array, 5 = object,
// 6 = number (f64, bitcast as i64)

// JSON value layout (Vec<i32>):
//   [0] = type tag
//   [1] = value (i64 for number, ptr for string, Vec for array/object, 0/1 for bool)
// For objects: [1] = keys Vec<str>, [2] = values Vec<json>

fn json_new(tag: i64, val: i64) -> Vec<i32> {
    let mut v: Vec<i32> = Vec::new();
    v.push(tag);
    v.push(val);
    return v;
}

fn json_new_obj(keys: i64, vals: i64) -> Vec<i32> {
    let mut v: Vec<i32> = Vec::new();
    v.push(5);
    v.push(keys);
    v.push(vals);
    return v;
}

fn json_null() -> Vec<i32> { return json_new(0, 0); }
fn json_from_bool(b: i64) -> Vec<i32> { return json_new(1, b); }
fn json_from_int(n: i64) -> Vec<i32> { return json_new(2, n); }
fn json_from_string(s: str) -> Vec<i32> { return json_new(3, s); }
fn json_from_f64(val: i64) -> Vec<i32> { return json_new(6, val); }

fn json_array_new() -> Vec<i32> {
    let mut elems: Vec<i32> = Vec::new();
    return json_new(4, elems);
}

fn json_array_push(arr: Vec<i32>, val: Vec<i32>) {
    let elems: i64 = arr.get(1);
    vec_push(elems, val);
}

fn json_object_new() -> Vec<i32> {
    let mut keys: Vec<i32> = Vec::new();
    let mut vals: Vec<i32> = Vec::new();
    return json_new_obj(keys, vals);
}

fn json_object_set(obj: Vec<i32>, key: str, val: Vec<i32>) {
    let keys: i64 = obj.get(1);
    let vals: i64 = obj.get(2);
    let klen: i64 = vec_len(keys);
    let mut i: i64 = 0;
    while i < klen {
        if str_eq(vec_get(keys, i), key) {
            vec_set(vals, i, val);
            return;
        };
        i = i + 1;
    };
    vec_push(keys, key);
    vec_push(vals, val);
}

fn json_type(j: Vec<i32>) -> i64 { return j.get(0); }

fn json_string(j: Vec<i32>) -> str {
    if j.get(0) != 3 { return ""; };
    return j.get(1);
}

fn json_int(j: Vec<i32>) -> i64 {
    if j.get(0) != 2 { return 0; };
    return j.get(1);
}

fn json_f64(j: Vec<i32>) -> i64 {
    if j.get(0) != 6 { return f64_from_int(0); };
    return j.get(1);
}

fn json_bool(j: Vec<i32>) -> i64 {
    if j.get(0) != 1 { return 0; };
    return j.get(1);
}

fn json_array_len(j: Vec<i32>) -> i64 {
    if j.get(0) != 4 { return 0; };
    return vec_len(j.get(1));
}

fn json_array_get(j: Vec<i32>, idx: i64) -> Vec<i32> {
    if j.get(0) != 4 { return json_null(); };
    return vec_get(j.get(1), idx);
}

fn json_object_get(j: Vec<i32>, key: str) -> Vec<i32> {
    if j.get(0) != 5 { return json_null(); };
    let keys: i64 = j.get(1);
    let vals: i64 = j.get(2);
    let klen: i64 = vec_len(keys);
    let mut i: i64 = 0;
    while i < klen {
        if str_eq(vec_get(keys, i), key) { return vec_get(vals, i); };
        i = i + 1;
    };
    return json_null();
}

fn json_object_keys(j: Vec<i32>) -> Vec<i32> {
    if j.get(0) != 5 {
        let mut empty: Vec<i32> = Vec::new();
        return empty;
    };
    let keys: i64 = j.get(1);
    let mut result: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        result.push(vec_get(keys, i));
        i = i + 1;
    };
    return result;
}

// Parser state: [0] = source string, [1] = position
fn json_ps_new(src: str) -> Vec<i32> {
    let mut ps: Vec<i32> = Vec::new();
    ps.push(src);
    ps.push(0);
    return ps;
}

fn json_ps_pos(ps: Vec<i32>) -> i64 { return ps.get(1); }
fn json_ps_src(ps: Vec<i32>) -> str { return ps.get(0); }
fn json_ps_set_pos(ps: Vec<i32>, p: i64) { vec_set(ps, 1, p); }

fn json_skip_ws(ps: Vec<i32>) {
    let src: str = json_ps_src(ps);
    let slen: i64 = str_len(src);
    let mut p: i64 = json_ps_pos(ps);
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c != 32 && c != 9 && c != 10 && c != 13 { break; };
        p = p + 1;
    };
    json_ps_set_pos(ps, p);
}

fn json_parse_string_raw(ps: Vec<i32>) -> str {
    let src: str = json_ps_src(ps);
    let slen: i64 = str_len(src);
    let mut p: i64 = json_ps_pos(ps);
    if p >= slen || str_char_at(src, p) != 34 { return ""; };
    p = p + 1;
    let mut sb: i64 = sb_new();
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 34 { p = p + 1; json_ps_set_pos(ps, p); return sb_to_str(sb); };
        if c == 92 && p + 1 < slen {
            let nc: i64 = str_char_at(src, p + 1);
            if nc == 34 { sb_append(sb, "\""); }
            else if nc == 92 { sb_append(sb, "\\"); }
            else if nc == 110 { sb_append(sb, "\n"); }
            else if nc == 116 { sb_append(sb, "\t"); }
            else if nc == 114 { sb_append(sb, "\r"); }
            else if nc == 47 { sb_append(sb, "/"); }
            else { sb_append(sb, strings_char_to_str(nc)); };
            p = p + 2;
        } else {
            sb_append(sb, strings_char_to_str(c));
            p = p + 1;
        };
    };
    json_ps_set_pos(ps, p);
    return sb_to_str(sb);
}

fn json_parse_number(ps: Vec<i32>) -> i64 {
    let src: str = json_ps_src(ps);
    let slen: i64 = str_len(src);
    let mut p: i64 = json_ps_pos(ps);
    let mut neg: i64 = 0;
    if p < slen && str_char_at(src, p) == 45 { neg = 1; p = p + 1; };
    let mut val: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c < 48 || c > 57 { break; };
        val = val * 10 + (c - 48);
        p = p + 1;
    };
    // Skip decimal part (truncate to int)
    if p < slen && str_char_at(src, p) == 46 {
        p = p + 1;
        while p < slen && str_char_at(src, p) >= 48 && str_char_at(src, p) <= 57 { p = p + 1; };
    };
    // Skip exponent
    if p < slen && (str_char_at(src, p) == 101 || str_char_at(src, p) == 69) {
        p = p + 1;
        if p < slen && (str_char_at(src, p) == 43 || str_char_at(src, p) == 45) { p = p + 1; };
        while p < slen && str_char_at(src, p) >= 48 && str_char_at(src, p) <= 57 { p = p + 1; };
    };
    json_ps_set_pos(ps, p);
    if neg == 1 { return 0 - val; };
    return val;
}

fn json_parse_value(ps: Vec<i32>) -> Vec<i32> {
    json_skip_ws(ps);
    let src: str = json_ps_src(ps);
    let slen: i64 = str_len(src);
    let p: i64 = json_ps_pos(ps);
    if p >= slen { return json_null(); };
    let c: i64 = str_char_at(src, p);

    // String
    if c == 34 {
        let s: str = json_parse_string_raw(ps);
        return json_from_string(s);
    };

    // Number
    if c == 45 || (c >= 48 && c <= 57) {
        let n: i64 = json_parse_number(ps);
        return json_from_int(n);
    };

    // true
    if c == 116 && p + 3 < slen && str_eq(str_substring(src, p, p + 4), "true") {
        json_ps_set_pos(ps, p + 4);
        return json_from_bool(1);
    };

    // false
    if c == 102 && p + 4 < slen && str_eq(str_substring(src, p, p + 5), "false") {
        json_ps_set_pos(ps, p + 5);
        return json_from_bool(0);
    };

    // null
    if c == 110 && p + 3 < slen && str_eq(str_substring(src, p, p + 4), "null") {
        json_ps_set_pos(ps, p + 4);
        return json_null();
    };

    // Array
    if c == 91 {
        json_ps_set_pos(ps, p + 1);
        let mut arr: Vec<i32> = json_array_new();
        json_skip_ws(ps);
        if json_ps_pos(ps) < slen && str_char_at(src, json_ps_pos(ps)) == 93 {
            json_ps_set_pos(ps, json_ps_pos(ps) + 1);
            return arr;
        };
        let mut done: i64 = 0;
        while done == 0 {
            let elem: Vec<i32> = json_parse_value(ps);
            json_array_push(arr, elem);
            json_skip_ws(ps);
            let pp: i64 = json_ps_pos(ps);
            if pp >= slen { done = 1; }
            else if str_char_at(src, pp) == 44 { json_ps_set_pos(ps, pp + 1); }
            else { json_ps_set_pos(ps, pp + 1); done = 1; };
        };
        return arr;
    };

    // Object
    if c == 123 {
        json_ps_set_pos(ps, p + 1);
        let mut obj: Vec<i32> = json_object_new();
        json_skip_ws(ps);
        if json_ps_pos(ps) < slen && str_char_at(src, json_ps_pos(ps)) == 125 {
            json_ps_set_pos(ps, json_ps_pos(ps) + 1);
            return obj;
        };
        let mut done: i64 = 0;
        while done == 0 {
            json_skip_ws(ps);
            let key: str = json_parse_string_raw(ps);
            json_skip_ws(ps);
            let cp: i64 = json_ps_pos(ps);
            if cp < slen && str_char_at(src, cp) == 58 { json_ps_set_pos(ps, cp + 1); };
            let val: Vec<i32> = json_parse_value(ps);
            json_object_set(obj, key, val);
            json_skip_ws(ps);
            let pp: i64 = json_ps_pos(ps);
            if pp >= slen { done = 1; }
            else if str_char_at(src, pp) == 44 { json_ps_set_pos(ps, pp + 1); }
            else { json_ps_set_pos(ps, pp + 1); done = 1; };
        };
        return obj;
    };

    // Unknown — skip char
    json_ps_set_pos(ps, p + 1);
    return json_null();
}

fn json_parse(src: str) -> Vec<i32> {
    let mut ps: Vec<i32> = json_ps_new(src);
    return json_parse_value(ps);
}

// Stringify
fn json_escape_string(s: str) -> str {
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(s);
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 34 { sb_append(sb, "\\\""); }
        else if c == 92 { sb_append(sb, "\\\\"); }
        else if c == 10 { sb_append(sb, "\\n"); }
        else if c == 13 { sb_append(sb, "\\r"); }
        else if c == 9 { sb_append(sb, "\\t"); }
        else { sb_append(sb, strings_char_to_str(c)); };
        i = i + 1;
    };
    return sb_to_str(sb);
}

// Format an f64 (bitcast in i64) as a JSON-compatible decimal string.
// Uses 6 fractional digits, trimming trailing zeros while keeping at least one
// digit after the decimal point ("1.0" not "1.", "3.14" not "3.140000").
fn json_f64_to_str(val: i64) -> str {
    let zero: i64 = f64_from_int(0);
    let is_neg: i64 = f64_lt(val, zero);
    let mut av: i64 = val;
    if is_neg == 1 { av = f64_abs(val); };
    let ip: i64 = f64_to_int(f64_floor(av));
    let frac_f: i64 = f64_sub(av, f64_from_int(ip));
    let mut fs: i64 = f64_to_int(f64_floor(f64_mul(frac_f, f64_from_int(1000000))));
    let mut fstr: str = fmt_int(fs);
    while str_len(fstr) < 6 { fstr = str_concat("0", fstr); };
    // Trim trailing zeros, but keep at least one digit so output stays "1.0".
    let mut flen: i64 = str_len(fstr);
    while flen > 1 && str_char_at(fstr, flen - 1) == 48 { flen = flen - 1; };
    fstr = str_substring(fstr, 0, flen);
    let mut r: str = str_concat(fmt_int(ip), str_concat(".", fstr));
    if is_neg == 1 { r = str_concat("-", r); };
    return r;
}

fn json_stringify(j: Vec<i32>) -> str {
    let tag: i64 = j.get(0);
    if tag == 0 { return "null"; };
    if tag == 1 {
        if j.get(1) != 0 { return "true"; };
        return "false";
    };
    if tag == 2 { return fmt_int(j.get(1)); };
    if tag == 3 {
        return str_concat("\"", str_concat(json_escape_string(j.get(1)), "\""));
    };
    if tag == 6 { return json_f64_to_str(j.get(1)); };
    if tag == 4 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "[");
        let alen: i64 = json_array_len(j);
        let mut i: i64 = 0;
        while i < alen {
            if i > 0 { sb_append(sb, ","); };
            sb_append(sb, json_stringify(json_array_get(j, i)));
            i = i + 1;
        };
        sb_append(sb, "]");
        return sb_to_str(sb);
    };
    if tag == 5 {
        let keys: i64 = j.get(1);
        let vals: i64 = j.get(2);
        let klen: i64 = vec_len(keys);
        let mut sb: i64 = sb_new();
        sb_append(sb, "{");
        let mut i: i64 = 0;
        while i < klen {
            if i > 0 { sb_append(sb, ","); };
            sb_append(sb, "\"");
            sb_append(sb, json_escape_string(vec_get(keys, i)));
            sb_append(sb, "\":");
            sb_append(sb, json_stringify(vec_get(vals, i)));
            i = i + 1;
        };
        sb_append(sb, "}");
        return sb_to_str(sb);
    };
    return "null";
}

// Build a string of `n` spaces (used for pretty-print indentation).
fn json_pp_spaces(n: i64) -> str {
    let mut s: str = "";
    let mut i: i64 = 0;
    while i < n { s = str_concat(s, " "); i = i + 1; };
    return s;
}

// Recursive pretty-printer. `indent` = spaces per level, `depth` = current depth.
fn json_pp(j: Vec<i32>, indent: i64, depth: i64) -> str {
    let tag: i64 = j.get(0);
    if tag == 0 { return "null"; };
    if tag == 1 {
        if j.get(1) != 0 { return "true"; };
        return "false";
    };
    if tag == 2 { return fmt_int(j.get(1)); };
    if tag == 3 {
        return str_concat("\"", str_concat(json_escape_string(j.get(1)), "\""));
    };
    if tag == 6 { return json_f64_to_str(j.get(1)); };
    if tag == 4 {
        let alen: i64 = json_array_len(j);
        if alen == 0 { return "[]"; };
        let inner: str = json_pp_spaces((depth + 1) * indent);
        let outer: str = json_pp_spaces(depth * indent);
        let mut sb: i64 = sb_new();
        sb_append(sb, "[\n");
        let mut i: i64 = 0;
        while i < alen {
            sb_append(sb, inner);
            sb_append(sb, json_pp(json_array_get(j, i), indent, depth + 1));
            if i + 1 < alen { sb_append(sb, ","); };
            sb_append(sb, "\n");
            i = i + 1;
        };
        sb_append(sb, outer);
        sb_append(sb, "]");
        return sb_to_str(sb);
    };
    if tag == 5 {
        let keys: i64 = j.get(1);
        let vals: i64 = j.get(2);
        let klen: i64 = vec_len(keys);
        if klen == 0 { return "{}"; };
        let inner: str = json_pp_spaces((depth + 1) * indent);
        let outer: str = json_pp_spaces(depth * indent);
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\n");
        let mut i: i64 = 0;
        while i < klen {
            sb_append(sb, inner);
            sb_append(sb, "\"");
            sb_append(sb, json_escape_string(vec_get(keys, i)));
            sb_append(sb, "\": ");
            sb_append(sb, json_pp(vec_get(vals, i), indent, depth + 1));
            if i + 1 < klen { sb_append(sb, ","); };
            sb_append(sb, "\n");
            i = i + 1;
        };
        sb_append(sb, outer);
        sb_append(sb, "}");
        return sb_to_str(sb);
    };
    return "null";
}

fn json_stringify_pretty(j: Vec<i32>, indent: i64) -> str {
    return json_pp(j, indent, 0);
}
