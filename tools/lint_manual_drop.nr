// lint_manual_drop.nr — MEM-1 conservative semantic leak linter.
//
// The 958 `#[manual_drop]` markers in the compiler are trust assertions:
// the developer promises to free every owned local by hand (auto-drop is
// suppressed for these fns). Until now that promise was only *parity*-checked
// (the marker exists in both compilers), never *semantically* checked.
//
// This is the warn-only, conservative first step the punchlist calls for. For
// every `#[manual_drop]` fn it flags owned heap constructions
// (`let [mut] NAME ... = ... Vec::new() ...;`) whose binding NAME is never
// referenced again anywhere in the function body — i.e. constructed and then
// abandoned with no free, no hand-off, and no return on ANY path. That is an
// unambiguous leak (or dead allocation); any later mention of NAME (push,
// return, free, pass-through) suppresses the finding, so false positives are
// near-zero by construction. It is intentionally NOT a full path-sensitive
// dataflow analysis — that is the follow-on; this catches the clearest class
// without the bootstrap-seed risk of a new in-compiler pass.
//
// Usage:  lint_manual_drop [file.nr ...]   (defaults to the compiler sources)
// Exit:   0 = no findings, 1 = one or more findings (prints each).
// file-wide PERF-3 suppression: the textual scan calls str_substring inside
// its scan loops (bounded per-fn slices, not a per-iteration leak) — same
// rationale as the compiler's lex/parse paths.
#[allow(PERF-3)]

// ---------- textual helpers (mirrors tools/audit_dup_fns.nr) ----------

fn find_from(s: str, needle: str, start: i64) -> i64 {
    let n: i64 = str_len(s);
    let nl: i64 = str_len(needle);
    if nl == 0 || nl > n - start { return -1; };
    let rest: str = str_substring(s, start, n);
    let off: i64 = str_index_of(rest, needle);
    if off < 0 { return -1; };
    return start + off;
}

fn is_ident_char(c: i64) -> i64 {
    if c >= 97 && c <= 122 { return 1; };  // a-z
    if c >= 65 && c <= 90  { return 1; };  // A-Z
    if c >= 48 && c <= 57  { return 1; };  // 0-9
    if c == 95 { return 1; };              // _
    return 0;
}

fn scan_ident_end(s: str, name_start: i64) -> i64 {
    let n: i64 = str_len(s);
    let mut p: i64 = name_start;
    while p < n && is_ident_char(str_char_at(s, p)) == 1 { p = p + 1; };
    return p;
}

// Generic delimiter-matcher; skips // comments, "..." strings, 'x' chars.
fn match_delim_aware(s: str, open_pos: i64, open_char: i64, close_char: i64) -> i64 {
    let n: i64 = str_len(s);
    if open_pos >= n || str_char_at(s, open_pos) != open_char { return -1; };
    let mut depth: i64 = 1;
    let mut p: i64 = open_pos + 1;
    while p < n {
        let c: i64 = str_char_at(s, p);
        if c == 47 && p + 1 < n && str_char_at(s, p + 1) == 47 {
            while p < n && str_char_at(s, p) != 10 { p = p + 1; };
        }
        else if c == 34 {
            p = p + 1;
            while p < n && str_char_at(s, p) != 34 {
                if str_char_at(s, p) == 92 && p + 1 < n { p = p + 1; };
                p = p + 1;
            };
        }
        else if c == 39 {
            p = p + 1;
            while p < n && str_char_at(s, p) != 39 {
                if str_char_at(s, p) == 92 && p + 1 < n { p = p + 1; };
                p = p + 1;
            };
        }
        else if c == open_char { depth = depth + 1; }
        else if c == close_char {
            depth = depth - 1;
            if depth == 0 { return p; };
        };
        p = p + 1;
    };
    return -1;
}

fn match_paren(s: str, open_paren: i64) -> i64 { return match_delim_aware(s, open_paren, 40, 41); }
fn match_brace(s: str, open_brace: i64) -> i64 { return match_delim_aware(s, open_brace, 123, 125); }

// 1-based line number of byte position p.
fn line_of(s: str, p: i64) -> i64 {
    let mut ln: i64 = 1;
    let mut i: i64 = 0;
    while i < p && i < str_len(s) { if str_char_at(s, i) == 10 { ln = ln + 1; }; i = i + 1; };
    return ln;
}

// Whole-word search: find `name` at/after `from` with non-ident boundaries
// on both sides. Returns position or -1.
fn find_word_from(s: str, name: str, from: i64) -> i64 {
    let n: i64 = str_len(s);
    let nl: i64 = str_len(name);
    let mut p: i64 = from;
    while p >= 0 && p < n {
        let hit: i64 = find_from(s, name, p);
        if hit < 0 { return -1; };
        let mut before_ok: i64 = 1;
        if hit > 0 && is_ident_char(str_char_at(s, hit - 1)) == 1 { before_ok = 0; };
        let after_pos: i64 = hit + nl;
        let mut after_ok: i64 = 1;
        if after_pos < n && is_ident_char(str_char_at(s, after_pos)) == 1 { after_ok = 0; };
        if before_ok == 1 && after_ok == 1 { return hit; };
        p = hit + 1;
    };
    return -1;
}

// Is the "let" token at position `lp` a real statement-leading token
// (preceded by start-of-body or a non-ident char)?
fn let_is_token(body: str, lp: i64) -> i64 {
    if lp == 0 { return 1; };
    if is_ident_char(str_char_at(body, lp - 1)) == 1 { return 0; };
    return 1;
}

// Lint one #[manual_drop] fn body. file/fname for reporting, base_line = the
// file line of the body's opening brace (so findings report file-absolute
// lines). Returns finding count.
fn lint_body(file: str, fname: str, body: str, base_line: i64) -> i64 {
    let n: i64 = str_len(body);
    let mut findings: i64 = 0;
    let mut pos: i64 = 0;
    while pos < n {
        let lp: i64 = find_from(body, "let ", pos);
        if lp < 0 { break; };
        pos = lp + 1;
        if let_is_token(body, lp) == 0 { continue; };
        // name start = after "let " (+ optional "mut ")
        let mut ns: i64 = lp + 4;
        if ns + 4 <= n
            && str_char_at(body, ns) == 109 && str_char_at(body, ns + 1) == 117
            && str_char_at(body, ns + 2) == 116 && str_char_at(body, ns + 3) == 32 {
            ns = ns + 4;  // skip "mut "
        };
        let ne: i64 = scan_ident_end(body, ns);
        if ne <= ns { continue; };
        let name: str = str_substring(body, ns, ne);
        // statement end (';') and the '=' that starts the initializer
        let eq: i64 = find_from(body, "=", ne);
        let semi: i64 = find_from(body, ";", ne);
        if eq < 0 || semi < 0 || eq > semi { continue; };
        let init: str = str_substring(body, eq, semi);
        // owned heap construction?
        if find_from(init, "Vec::new()", 0) < 0 { continue; };
        // referenced again anywhere after the binding statement?
        if find_word_from(body, name, semi + 1) < 0 {
            findings = findings + 1;
            print(str_concat("LEAK ", str_concat(file, str_concat(":", str_concat(str_from_int(base_line + line_of(body, lp) - 1),
                str_concat("  fn ", str_concat(fname, str_concat(": owned binding `", str_concat(name,
                "` from Vec::new() is never freed, handed off, or returned on any path")))))))));
        };
    };
    return findings;
}

// Find the next top-level fn decl at/after position `m`. Returns the name
// start position (after "fn "/"pub fn "), or -1.
fn next_fn_decl(src: str, m: i64) -> i64 {
    let a: i64 = find_from(src, "\nfn ", m);
    let b: i64 = find_from(src, "\npub fn ", m);
    let mut chosen: i64 = -1;
    let mut after: i64 = 0;
    if a >= 0 && (b < 0 || a <= b) { chosen = a; after = 4; }
    else if b >= 0 { chosen = b; after = 8; };
    if chosen < 0 { return -1; };
    return chosen + after;
}

fn lint_source(file: str, src: str) -> i64 {
    let n: i64 = str_len(src);
    let mut findings: i64 = 0;
    let mut pos: i64 = 0;
    // Track the file line incrementally as `#[manual_drop]` markers are found
    // left-to-right (monotonic), so we never re-scan src from 0 per fn.
    let mut scan_off: i64 = 0;
    let mut line_acc: i64 = 1;
    while pos < n {
        let m: i64 = find_from(src, "#[manual_drop]", pos);
        if m < 0 { break; };
        pos = m + 1;
        let ns: i64 = next_fn_decl(src, m);
        if ns < 0 { continue; };
        let ne: i64 = scan_ident_end(src, ns);
        let fname: str = str_substring(src, ns, ne);
        // body open: first '(' after name -> match ')' -> first '{' after.
        let op: i64 = find_from(src, "(", ne);
        if op < 0 { continue; };
        let cp: i64 = match_paren(src, op);
        if cp < 0 { continue; };
        let bo: i64 = find_from(src, "{", cp);
        if bo < 0 { continue; };
        let bc: i64 = match_brace(src, bo);
        if bc < 0 { continue; };
        // advance the running line counter to the body's opening brace
        while scan_off < bo {
            if str_char_at(src, scan_off) == 10 { line_acc = line_acc + 1; };
            scan_off = scan_off + 1;
        };
        let body: str = str_substring(src, bo + 1, bc);
        findings = findings + lint_body(file, fname, body, line_acc);
    };
    return findings;
}

fn main() -> i64 {
    let argc: i64 = args_count();
    let mut total: i64 = 0;
    let mut scanned: i64 = 0;
    if argc > 1 {
        let mut i: i64 = 1;
        while i < argc {
            let path: str = args_get(i);
            let src: str = file_read_string(path);
            if str_len(src) > 0 { total = total + lint_source(path, src); scanned = scanned + 1; };
            i = i + 1;
        };
    } else {
        // default: the whole compiler surface that carries #[manual_drop].
        let files: Vec<str> = Vec::new();
        files.push("compiler/nucleor_s1_compiler.nr");
        files.push("compiler/nucleor_tools_suite.nr");
        files.push("compiler/s1/lex.nr");
        files.push("compiler/s1/parse.nr");
        files.push("compiler/s1/ir.nr");
        files.push("compiler/s1/optim.nr");
        files.push("compiler/s1/builtins.nr");
        files.push("compiler/s1/emit.nr");
        files.push("compiler/s1/lower.nr");
        files.push("compiler/s1/diag.nr");
        files.push("compiler/s1/check_eff.nr");
        files.push("compiler/s1/check_own.nr");
        files.push("compiler/s1/check_type.nr");
        files.push("compiler/s1/cache.nr");
        files.push("compiler/s1/modules.nr");
        files.push("compiler/s1/cli.nr");
        let mut i: i64 = 0;
        while i < vec_len(files) {
            let path: str = vec_get(files, i);
            let src: str = file_read_string(path);
            if str_len(src) > 0 { total = total + lint_source(path, src); scanned = scanned + 1; };
            i = i + 1;
        };
    };
    print(str_concat("lint_manual_drop: scanned ", str_concat(str_from_int(scanned),
        str_concat(" file(s), ", str_concat(str_from_int(total), " leak finding(s)")))));
    if total > 0 { return 1; };
    return 0;
}
