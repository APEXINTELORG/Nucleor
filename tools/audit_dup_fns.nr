// audit_dup_fns.nr — RFC-0063 Phase 2.0.3a signature-and-body audit.
//
// Walks compiler/nucleor_s1_compiler.nr and compiler/nucleor_tools_suite.nr,
// extracts every top-level `fn name(...)` declaration, and for every name
// declared in BOTH files emits a CSV row categorizing the duplicate.
//
// Output: tools/audit_dup_fns_report.csv with columns:
//   name,s1_args,tools_args,s1_body_lines,tools_body_lines,
//   sig_match,body_identical,category
//
// Categories:
//   IDENTICAL              — sigs match AND bodies byte-identical (safe delete)
//   SIG_MATCH_BODY_DIFFERS — sigs match, bodies differ (likely safe; use s1's)
//   SIG_DIFFERS            — arg counts differ (call sites need update)
//
// Drives the Phase 2.0.3b-z dedup ship sequencing.

// ---------- helpers ----------

// Find next occurrence of `needle` in `s` starting at `start`. Returns -1 if not found.
fn find_from(s: str, needle: str, start: i64) -> i64 {
    let n: i64 = str_len(s);
    let nl: i64 = str_len(needle);
    if nl == 0 || nl > n - start { return -1; };
    let rest: str = str_substring(s, start, n);
    let off: i64 = str_index_of(rest, needle);
    if off < 0 { return -1; };
    return start + off;
}

// Match the literal "fn " or "pub fn " prefix at line_start (column 0).
// Returns the name-start position (after "fn "), or -1 if no fn decl here.
fn fn_name_start_at(s: str, line_start: i64) -> i64 {
    let n: i64 = str_len(s);
    if line_start + 3 <= n
        && str_char_at(s, line_start) == 102      // f
        && str_char_at(s, line_start + 1) == 110  // n
        && str_char_at(s, line_start + 2) == 32 { // space
        return line_start + 3;
    };
    if line_start + 7 <= n
        && str_char_at(s, line_start) == 112      // p
        && str_char_at(s, line_start + 1) == 117  // u
        && str_char_at(s, line_start + 2) == 98   // b
        && str_char_at(s, line_start + 3) == 32   // space
        && str_char_at(s, line_start + 4) == 102  // f
        && str_char_at(s, line_start + 5) == 110  // n
        && str_char_at(s, line_start + 6) == 32 { // space
        return line_start + 7;
    };
    return -1;
}

// Identifier char predicate. lowercase / uppercase / digit / underscore.
fn is_ident_char(c: i64) -> i64 {
    if c >= 97 && c <= 122 { return 1; };  // a-z
    if c >= 65 && c <= 90  { return 1; };  // A-Z
    if c >= 48 && c <= 57  { return 1; };  // 0-9
    if c == 95 { return 1; };              // _
    return 0;
}

// Walk forward from `name_start`, collect ident chars, stop at first non-ident.
// Returns position of the char AFTER the name (typically `(`).
fn scan_ident_end(s: str, name_start: i64) -> i64 {
    let n: i64 = str_len(s);
    let mut p: i64 = name_start;
    while p < n && is_ident_char(str_char_at(s, p)) == 1 { p = p + 1; };
    return p;
}

// Count top-level commas + 1 (= number of args). Top-level means not inside
// `<...>` (generics) or nested `(...)` (default-arg expressions).
fn count_args_in(arg_str: str) -> i64 {
    let n: i64 = str_len(arg_str);
    // Trim leading + trailing whitespace
    let mut start: i64 = 0;
    while start < n {
        let c: i64 = str_char_at(arg_str, start);
        if c != 32 && c != 9 && c != 10 && c != 13 { break; };
        start = start + 1;
    };
    if start >= n { return 0; };  // empty arg list
    let mut count: i64 = 1;
    let mut angle_depth: i64 = 0;
    let mut paren_depth: i64 = 0;
    let mut i: i64 = start;
    while i < n {
        let c: i64 = str_char_at(arg_str, i);
        if c == 60 { angle_depth = angle_depth + 1; };       // <
        if c == 62 { angle_depth = angle_depth - 1; };       // >
        if c == 40 { paren_depth = paren_depth + 1; };       // (
        if c == 41 { paren_depth = paren_depth - 1; };       // )
        if c == 44 && angle_depth == 0 && paren_depth == 0 {
            count = count + 1;
        };
        i = i + 1;
    };
    return count;
}

// Generic delimiter-matcher. open_char/close_char are ASCII codes.
// Skips // line comments, "..." string literals (with \" / \\ escapes),
// and 'X' char literals. Returns position of the matching close, or -1.
fn match_delim_aware(s: str, open_pos: i64, open_char: i64, close_char: i64) -> i64 {
    let n: i64 = str_len(s);
    if open_pos >= n || str_char_at(s, open_pos) != open_char { return -1; };
    let mut depth: i64 = 1;
    let mut p: i64 = open_pos + 1;
    while p < n {
        let c: i64 = str_char_at(s, p);
        // // line comment: skip to newline
        if c == 47 && p + 1 < n && str_char_at(s, p + 1) == 47 {
            while p < n && str_char_at(s, p) != 10 { p = p + 1; };
        }
        // "..." string literal
        else if c == 34 {
            p = p + 1;
            while p < n && str_char_at(s, p) != 34 {
                if str_char_at(s, p) == 92 && p + 1 < n { p = p + 1; };
                p = p + 1;
            };
        }
        // 'X' char literal (possibly escaped)
        else if c == 39 {
            p = p + 1;
            while p < n && str_char_at(s, p) != 39 {
                if str_char_at(s, p) == 92 && p + 1 < n { p = p + 1; };
                p = p + 1;
            };
        }
        else if c == open_char {
            depth = depth + 1;
        }
        else if c == close_char {
            depth = depth - 1;
            if depth == 0 { return p; };
        };
        p = p + 1;
    };
    return -1;
}

fn match_paren(s: str, open_paren: i64) -> i64 {
    return match_delim_aware(s, open_paren, 40, 41);
}

fn match_brace(s: str, open_brace: i64) -> i64 {
    return match_delim_aware(s, open_brace, 123, 125);
}

// Find the next newline at or after p. Returns p_end (position of \n) or n if EOF.
fn line_end_from(s: str, p: i64) -> i64 {
    let n: i64 = str_len(s);
    let mut q: i64 = p;
    while q < n && str_char_at(s, q) != 10 { q = q + 1; };
    return q;
}

// Count newlines in body (= line count of body content).
fn count_lines_in(body: str) -> i64 {
    let n: i64 = str_len(body);
    let mut count: i64 = 1;
    let mut i: i64 = 0;
    while i < n {
        if str_char_at(body, i) == 10 { count = count + 1; };
        i = i + 1;
    };
    return count;
}

// CSV-escape a string: wrap in quotes if it contains comma, quote, or newline.
fn csv_escape(s: str) -> str {
    let n: i64 = str_len(s);
    let mut needs_quote: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let c: i64 = str_char_at(s, i);
        if c == 44 || c == 34 || c == 10 { needs_quote = 1; break; };
        i = i + 1;
    };
    if needs_quote == 0 { return s; };
    // Escape inner quotes by doubling
    let mut out: str = "\"";
    let mut j: i64 = 0;
    while j < n {
        let c2: i64 = str_char_at(s, j);
        if c2 == 34 { out = str_concat(out, "\"\""); }
        else { out = str_concat(out, str_substring(s, j, j + 1)); };
        j = j + 1;
    };
    out = str_concat(out, "\"");
    return out;
}

// ---------- fn-decl walker ----------

// Walks `src` and populates parallel Vec arrays with every top-level fn decl.
// names[i] = fn name (str)
// arg_counts[i] = arg count (i64, packed into i32)
// body_hashes[i] = fnv1a-64 hash of body (i64)
// body_line_counts[i] = line count of body (i64, packed into i32)
fn collect_fns(src: str, names: Vec<str>, arg_counts: Vec<i32>, body_hashes: Vec<i64>, body_line_counts: Vec<i32>) -> i64 {
    let n: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut count: i64 = 0;
    while p < n {
        // Are we at a column-0 fn decl?
        let line_is_fn_start: i64 = if p == 0 { 1 }
            else if str_char_at(src, p - 1) == 10 { 1 }
            else { 0 };
        if line_is_fn_start == 1 {
            let name_start: i64 = fn_name_start_at(src, p);
            if name_start >= 0 {
                let name_end: i64 = scan_ident_end(src, name_start);
                if name_end > name_start && name_end < n && str_char_at(src, name_end) == 40 {
                    // Found `fn name(` at column 0. Extract.
                    let fn_name: str = str_substring(src, name_start, name_end);
                    let args_close: i64 = match_paren(src, name_end);
                    if args_close > 0 {
                        let args_str: str = str_substring(src, name_end + 1, args_close);
                        let argc: i64 = count_args_in(args_str);
                        // Find `{` after args_close (skipping `-> RetType` and whitespace)
                        let body_open: i64 = find_from(src, "{", args_close);
                        if body_open > 0 {
                            let body_close: i64 = match_brace(src, body_open);
                            if body_close > 0 {
                                let body: str = str_substring(src, body_open + 1, body_close);
                                let body_lines: i64 = count_lines_in(body);
                                let body_hash: i64 = fnv1a_64_str(body);
                                vec_push(names, fn_name);
                                vec_push(arg_counts, argc as i32);
                                vec_push(body_hashes, body_hash);
                                vec_push(body_line_counts, body_lines as i32);
                                count = count + 1;
                                // Advance past body
                                p = body_close + 1;
                                continue;
                            };
                        };
                    };
                };
            };
        };
        // Advance to next line
        let eol: i64 = line_end_from(src, p);
        p = eol + 1;
    };
    return count;
}

// ---------- main ----------

fn main() -> i64 {
    let s1_path: str = "compiler/nucleor_s1_compiler.nr";
    let tools_path: str = "compiler/nucleor_tools_suite.nr";
    let out_path: str = "tools/audit_dup_fns_report.csv";

    // Compose the s1 source: main file plus every extracted module in
    // compiler/s1/*.nr. The compiler uses `import` to inline these at
    // compile time; the audit walks them explicitly so its fn count
    // continues to reflect the real s1 surface after the file split.
    let mut s1_src: str = file_read_string(s1_path);
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/ir.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/lex.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/parse.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/optim.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/builtins.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/emit.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/lower.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/diag.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/check_eff.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/check_own.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/check_type.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/cache.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/modules.nr"));
    s1_src = str_concat(s1_src, "\n"); s1_src = str_concat(s1_src, file_read_string("compiler/s1/cli.nr"));
    // Same flattening for the tools-suite after its file split. Main file
    // post-split holds only the stdlib bridge + the kept-in-place
    // compiler_version_label; the 14 module files contain everything else.
    let mut tools_src: str = file_read_string(tools_path);
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/parse.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/optim.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/builtins.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/emit.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/lower.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/diag.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/review.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/check_own.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/check_eff.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/check_taint.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/cache.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/pipeline.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/modules.nr"));
    tools_src = str_concat(tools_src, "\n"); tools_src = str_concat(tools_src, file_read_string("compiler/ts/cli.nr"));
    if str_len(s1_src) == 0 || str_len(tools_src) == 0 {
        print("ERROR: audit_dup_fns: cannot read one or both compiler files");
        return 1;
    };

    let s1_names: Vec<str> = vec_new();
    let s1_args: Vec<i32> = vec_new();
    let s1_hashes: Vec<i64> = vec_new();
    let s1_lines: Vec<i32> = vec_new();
    let s1_count: i64 = collect_fns(s1_src, s1_names, s1_args, s1_hashes, s1_lines);

    let tools_names: Vec<str> = vec_new();
    let tools_args: Vec<i32> = vec_new();
    let tools_hashes: Vec<i64> = vec_new();
    let tools_lines: Vec<i32> = vec_new();
    let tools_count: i64 = collect_fns(tools_src, tools_names, tools_args, tools_hashes, tools_lines);

    print(str_concat("s1 fns: ", int_to_str(s1_count)));
    print(str_concat("tools fns: ", int_to_str(tools_count)));

    // Build hashmap: tools_name -> tools index
    let tools_idx: i64 = hashmap_new();
    let mut k: i64 = 0;
    while k < tools_count {
        hashmap_insert(tools_idx, vec_get(tools_names, k), k);
        k = k + 1;
    };

    // Walk s1 fns; for each name also in tools, emit CSV row.
    let mut out: str = "name,s1_args,tools_args,s1_body_lines,tools_body_lines,sig_match,body_identical,category\n";
    let mut dups: i64 = 0;
    let mut cat_identical: i64 = 0;
    let mut cat_sig_match_body_differs: i64 = 0;
    let mut cat_sig_differs: i64 = 0;

    let mut i: i64 = 0;
    while i < s1_count {
        let name: str = vec_get(s1_names, i);
        if hashmap_contains(tools_idx, name) == 1 {
            let j: i64 = hashmap_get(tools_idx, name);
            let s1_a: i64 = vec_get(s1_args, i) as i64;
            let to_a: i64 = vec_get(tools_args, j) as i64;
            let s1_l: i64 = vec_get(s1_lines, i) as i64;
            let to_l: i64 = vec_get(tools_lines, j) as i64;
            let s1_h: i64 = vec_get(s1_hashes, i);
            let to_h: i64 = vec_get(tools_hashes, j);
            let sig_match: i64 = if s1_a == to_a { 1 } else { 0 };
            let body_match: i64 = if s1_h == to_h { 1 } else { 0 };
            let category: str = if sig_match == 1 && body_match == 1 { "IDENTICAL" }
                else if sig_match == 1 { "SIG_MATCH_BODY_DIFFERS" }
                else { "SIG_DIFFERS" };
            if sig_match == 1 && body_match == 1 { cat_identical = cat_identical + 1; }
            else if sig_match == 1 { cat_sig_match_body_differs = cat_sig_match_body_differs + 1; }
            else { cat_sig_differs = cat_sig_differs + 1; };
            out = str_concat(out, csv_escape(name));
            out = str_concat(out, ",");
            out = str_concat(out, int_to_str(s1_a));
            out = str_concat(out, ",");
            out = str_concat(out, int_to_str(to_a));
            out = str_concat(out, ",");
            out = str_concat(out, int_to_str(s1_l));
            out = str_concat(out, ",");
            out = str_concat(out, int_to_str(to_l));
            out = str_concat(out, ",");
            out = str_concat(out, int_to_str(sig_match));
            out = str_concat(out, ",");
            out = str_concat(out, int_to_str(body_match));
            out = str_concat(out, ",");
            out = str_concat(out, category);
            out = str_concat(out, "\n");
            dups = dups + 1;
        };
        i = i + 1;
    };

    file_write_string(out_path, out);

    print(str_concat("Wrote ", out_path));
    print(str_concat("Duplicate fns by name: ", int_to_str(dups)));
    print(str_concat("  IDENTICAL: ", int_to_str(cat_identical)));
    print(str_concat("  SIG_MATCH_BODY_DIFFERS: ", int_to_str(cat_sig_match_body_differs)));
    print(str_concat("  SIG_DIFFERS: ", int_to_str(cat_sig_differs)));
    return 0;
}
