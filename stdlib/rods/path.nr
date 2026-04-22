// =====================================================
// rods/path — Path manipulation utilities
// =====================================================
// Import: import "stdlib/rods/path.nr"
// Provides: path_join, path_ext, path_stem, path_parent, path_filename,
//   path_is_absolute, path_normalize
// =====================================================

import "stdlib/rods/strings.nr"

// Join two path segments with '/'
fn path_join(a: str, b: str) -> str {
    let alen: i64 = str_len(a);
    if alen == 0 { return b; };
    if str_len(b) == 0 { return a; };
    let last: i64 = str_char_at(a, alen - 1);
    // If a already ends with / or \, just concatenate
    if last == 47 || last == 92 { return str_concat(a, b); };
    return str_concat(a, str_concat("/", b));
}

// Get the file extension including the dot (e.g. ".nr")
// Returns "" if no extension
fn path_ext(p: str) -> str {
    let plen: i64 = str_len(p);
    let mut last_dot: i64 = 0 - 1;
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < plen {
        let c: i64 = str_char_at(p, i);
        if c == 46 { last_dot = i; };
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_dot > last_sep + 1 { return str_substring(p, last_dot, plen); };
    return "";
}

// Get the filename without extension (stem)
fn path_stem(p: str) -> str {
    let fname: str = path_filename(p);
    let flen: i64 = str_len(fname);
    let mut last_dot: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < flen {
        if str_char_at(fname, i) == 46 { last_dot = i; };
        i = i + 1;
    };
    if last_dot > 0 { return str_substring(fname, 0, last_dot); };
    return fname;
}

// Get the parent directory path
fn path_parent(p: str) -> str {
    let plen: i64 = str_len(p);
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < plen {
        let c: i64 = str_char_at(p, i);
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_sep >= 0 { return str_substring(p, 0, last_sep); };
    return "";
}

// Get the filename component (after last separator)
fn path_filename(p: str) -> str {
    let plen: i64 = str_len(p);
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < plen {
        let c: i64 = str_char_at(p, i);
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_sep >= 0 { return str_substring(p, last_sep + 1, plen); };
    return p;
}

// Check if a path is absolute
// On Windows: starts with X:\ or X:/ or \\ or //
// On Unix: starts with /
fn path_is_absolute(p: str) -> i64 {
    let plen: i64 = str_len(p);
    if plen == 0 { return 0; };
    let c0: i64 = str_char_at(p, 0);
    // Unix absolute: starts with /
    if c0 == 47 { return 1; };
    // UNC path: starts with \\
    if c0 == 92 && plen > 1 && str_char_at(p, 1) == 92 { return 1; };
    // Windows drive letter: X:\ or X:/
    if plen >= 3 {
        let c1: i64 = str_char_at(p, 1);
        let c2: i64 = str_char_at(p, 2);
        if c1 == 58 && (c2 == 47 || c2 == 92) {
            // Check c0 is a letter
            if (c0 >= 65 && c0 <= 90) || (c0 >= 97 && c0 <= 122) { return 1; };
        };
    };
    return 0;
}

// Normalize a path: replace backslashes with forward slashes,
// collapse consecutive slashes, remove trailing slash
fn path_normalize(p: str) -> str {
    let plen: i64 = str_len(p);
    if plen == 0 { return ""; };
    let mut sb: i64 = sb_new();
    let mut prev_slash: i64 = 0;
    let mut i: i64 = 0;
    while i < plen {
        let c: i64 = str_char_at(p, i);
        if c == 92 || c == 47 {
            if prev_slash == 0 {
                sb_append(sb, "/");
                prev_slash = 1;
            };
        } else {
            sb_append(sb, strings_char_to_str(c));
            prev_slash = 0;
        };
        i = i + 1;
    };
    let result: str = sb_to_str(sb);
    let rlen: i64 = str_len(result);
    // Remove trailing slash unless it's the root "/"
    if rlen > 1 && str_char_at(result, rlen - 1) == 47 {
        return str_substring(result, 0, rlen - 1);
    };
    return result;
}
