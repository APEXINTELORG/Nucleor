// =====================================================
// MODULE SYSTEM (imports)
// =====================================================
#[manual_drop]
fn extract_dir(path: str) -> str {
    let slen: i64 = str_len(path);
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(path, i);
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_sep >= 0 { return str_substring(path, 0, last_sep + 1); };
    return "";
}

#[manual_drop]
fn path_is_absolute(path: str) -> i64 {
    let slen: i64 = str_len(path);
    if slen >= 1 {
        let c0: i64 = str_char_at(path, 0);
        if c0 == 47 || c0 == 92 { return 1; };
    };
    if slen >= 2 && str_char_at(path, 1) == 58 { return 1; };
    return 0;
}

#[manual_drop]
fn trim_trailing_sep(path: str) -> str {
    let mut end: i64 = str_len(path);
    while end > 0 {
        let c: i64 = str_char_at(path, end - 1);
        if c == 47 || c == 92 { end = end - 1; }
        else { return str_substring(path, 0, end); };
    };
    return "";
}

#[manual_drop]
fn parent_dir(path: str) -> str {
    let trimmed: str = trim_trailing_sep(path);
    if str_len(trimmed) == 0 { return ""; };
    return extract_dir(trimmed);
}

// rewrite leading `/<drive>/...` (POSIX-form
// drive path inherited from a bash/MSYS2 parent) to `<drive>:/...`
// so Win32 file APIs accept it. No-op for paths that don't match
// that exact shape -- POSIX hosts pass through unchanged, and any
// path already in Windows form (e.g. "C:/...") is left alone.
#[manual_drop]
fn posix_drive_to_windows(p: str) -> str {
    let n: i64 = str_len(p);
    if n < 3 { return p; };
    if n >= 7
        && str_char_at(p, 0) == 47
        && str_char_at(p, 1) == 109
        && str_char_at(p, 2) == 110
        && str_char_at(p, 3) == 116
        && str_char_at(p, 4) == 47 {
        let mnt_drive: i64 = str_char_at(p, 5);
        let lower_mnt_drive: i64 = if mnt_drive >= 65 && mnt_drive <= 90 { mnt_drive + 32 } else { mnt_drive };
        if lower_mnt_drive >= 97 && lower_mnt_drive <= 122 && str_char_at(p, 6) == 47 {
            let mut msb: i64 = sb_new();
            sb_append_char(msb, lower_mnt_drive);
            sb_append_char(msb, 58);
            let mut mi: i64 = 6;
            while mi < n { sb_append_char_at(msb, p, mi); mi = mi + 1; };
            return sb_to_str(msb);
        };
    };
    if str_char_at(p, 0) != 47 { return p; };  // not leading '/'
    let drive: i64 = str_char_at(p, 1);
    let lower_drive: i64 = if drive >= 65 && drive <= 90 { drive + 32 } else { drive };
    if lower_drive < 97 || lower_drive > 122 { return p; };  // not [a-z]
    if str_char_at(p, 2) != 47 { return p; };  // no slash after drive
    // Build "<drive>:" + rest (rest starts at index 2, the second slash)
    let mut sb: i64 = sb_new();
    sb_append_char(sb, lower_drive);
    sb_append_char(sb, 58);  // ':'
    let mut i: i64 = 2;
    while i < n { sb_append_char_at(sb, p, i); i = i + 1; };
    return sb_to_str(sb);
}

#[manual_drop]
fn resolve_import_path(base_dir: str, raw_path: str) -> str {
    if path_is_absolute(raw_path) == 1 { return sanitize(raw_path); };
    let mut search_dir: str = base_dir;
    while 1 == 1 {
        let candidate: str = sanitize(str_concat(search_dir, raw_path));
        if path_exists(candidate) == 1 { return candidate; };
        if str_len(search_dir) == 0 { break; };
        search_dir = parent_dir(search_dir);
    };
    let from_cwd: str = sanitize(raw_path);
    if path_exists(from_cwd) == 1 { return from_cwd; };
    // NUC-FEEDBACK-004 — when the source file is OUTSIDE
    // the source repo (adopters using nucleor.exe as an external
    // tool), `import "stdlib/rods/jsonl.nr"` and other stdlib imports
    // silently fail to resolve via the base_dir walk above — the
    // compiler had no idea where stdlib lives. The import then
    // produces zero injected source and every `emit_json_*` (or other
    // stdlib symbol) fails at clang link with `@<name> undefined`.
    // Fix: also probe `NUCLEOR_STDLIB` env override, and the
    // `<exe_dir>/..` (i.e. OSS-root sibling of `bin/`) — same pattern
    // as resolve_toolchain_path. Both checks fail-soft via
    // file_read_string > 0, so users with custom layouts still get
    // their relative-to-source resolution from the loop above.
    let env_root_raw: str = env_get_or("NUCLEOR_STDLIB", "");
    // when NUCLEOR_STDLIB is set by a bash
    // wrapper on Windows it commonly inherits a POSIX-style path
    // like "/c/Users/.../repo". nucleor.exe runs natively under
    // Win32 file APIs which can't open that path; the env-rooted
    // probe silently misses and the fallback `base_dir + raw_path`
    // (which also doesn't have the stdlib) fires, leaving stdlib
    // imports unresolved at link time.
    // Rewrite leading `/<drive>/...` -> `<drive>:/...` so the same
    // path works under either shell. POSIX hosts are unaffected
    // (the rewrite is a no-op when the second char isn't a
    // drive-letter slash sequence).
    let env_root: str = posix_drive_to_windows(env_root_raw);
    if str_len(env_root) > 0 {
        let from_env: str = sanitize(str_concat(env_root, str_concat("/", raw_path)));
        if path_exists(from_env) == 1 { return from_env; };
    };
    if args_count() > 0 {
        let exe_path: str = posix_drive_to_windows(args_get(0));
        let exe_dir: str = extract_dir(exe_path);
        let from_exe_dir: str = sanitize(str_concat(exe_dir, raw_path));
        if path_exists(from_exe_dir) == 1 { return from_exe_dir; };
        let repo_dir: str = parent_dir(exe_dir);
        let from_repo_dir: str = sanitize(str_concat(repo_dir, raw_path));
        if path_exists(from_repo_dir) == 1 { return from_repo_dir; };
    };
    return sanitize(str_concat(base_dir, raw_path));
}

#[manual_drop]
fn module_record_add(records: Vec<i32>, path: str, raw: str) -> i64 {
    records.push(path);
    records.push(content_hash(raw));
    return 0;
}
#[manual_drop]
fn module_records_serialize(records: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(records) {
        sb_append(sb, vec_get(records, i));
        sb_append(sb, "|");
        sb_append(sb, vec_get(records, i + 1));
        sb_append(sb, "\n");
        i = i + 2;
    };
    return sb_to_str(sb);
}
#[manual_drop]
fn module_records_validate(manifest: str) -> Vec<i32> {
    let mut imported: Vec<i32> = Vec::new();
    if str_len(manifest) == 0 {
        let mut fail: Vec<i32> = Vec::new();
        fail.push(0);
        fail.push(imported);
        return fail;
    };
    let slen: i64 = str_len(manifest);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(manifest, eol) != 10 { eol = eol + 1; };
        if eol > p {
            let line: str = str_substring(manifest, p, eol);
            let llen: i64 = str_len(line);
            let mut sep: i64 = 0;
            while sep < llen && str_char_at(line, sep) != 124 { sep = sep + 1; };
            if sep >= llen {
                let mut fail2: Vec<i32> = Vec::new();
                fail2.push(0);
                fail2.push(imported);
                return fail2;
            };
            let path: str = str_substring(line, 0, sep);
            let expected_hash: str = str_substring(line, sep + 1, llen);
            let raw: str = file_read_string(path);
            if str_len(raw) == 0 || str_eq(content_hash(raw), expected_hash) == 0 {
                let mut fail3: Vec<i32> = Vec::new();
                fail3.push(0);
                fail3.push(imported);
                return fail3;
            };
            imported.push(path);
        };
        p = eol + 1;
    };
    let mut ok: Vec<i32> = Vec::new();
    ok.push(1);
    ok.push(imported);
    return ok;
}
#[manual_drop]
fn module_graph_cache_id(src_path: str) -> str {
    // NUC-FEEDBACK-007 — include compiler_version_label
    // so a binary upgrade invalidates the resolved-source cache
    // alongside the IR cache. Without this, a recompile after
    // a compiler bump would re-use cached resolved source from
    // before the lexer/parser fix landed.
    return content_hash(str_concat("module-graph-v2|", str_concat(compiler_version_label(), str_concat("|", sanitize(src_path)))));
}
#[manual_drop]
fn module_graph_manifest_path(src_path: str) -> str {
    return sanitize(str_concat(".nuc_cache/modgraph_", str_concat(module_graph_cache_id(src_path), ".manifest")));
}
#[manual_drop]
fn module_graph_source_path(src_path: str) -> str {
    return sanitize(str_concat(".nuc_cache/modgraph_", str_concat(module_graph_cache_id(src_path), ".resolved")));
}
#[manual_drop]
fn module_graph_max_depth_source_path(src_path: str) -> str {
    return sanitize(str_concat(".nuc_cache/modgraph_", str_concat(module_graph_cache_id(src_path), ".max_depth")));
}

// RFC-0018 phase 1: rewrite Rust-style use paths into the equivalent
// quoted-path import. Recognized prefixes:
//   use std::foo;       → import "stdlib/rods/foo.nr"
//   use std::foo::bar;  → import "stdlib/rods/foo/bar.nr"
//   use crate::path;    → import "path.nr" (relative to project root)
//   use super::path;    → import "../path.nr" (relative to base_dir)
// Trailing `as ALIAS`, `;`, and `{ ... }` glob/list forms are ignored
// for now (full resolver lands in phase 2 with name-mangling).
#[manual_drop]
fn rewrite_use_path(line: str, lp: i64, prefix_len: i64, eol: i64) -> str {
    let mut qp: i64 = lp + prefix_len;
    while qp < eol && str_char_at(line, qp) == 32 { qp = qp + 1; };
    if qp >= eol { return ""; };
    let c0: i64 = str_char_at(line, qp);
    if c0 == 34 { return ""; };  // already quoted
    if is_alpha(c0) == 0 { return ""; };
    let mut path_end: i64 = qp;
    while path_end < eol {
        let pc: i64 = str_char_at(line, path_end);
        if is_alnum(pc) == 1 || pc == 58 { path_end = path_end + 1; }
        else { break; };
    };
    let mut tail_v718: i64 = path_end;
    while tail_v718 < eol && str_char_at(line, tail_v718) == 32 { tail_v718 = tail_v718 + 1; };
    if tail_v718 + 2 <= eol && str_eq_at(line, tail_v718, "as") == 1 {
        print("ERROR: `use path as Alias` import aliases are not yet supported in Nucleor. Workaround: import the module path directly and call the existing exported names, or use `import \"...\"` for the current flat namespace model. Tracked for RFC-0018 resolver phase 2.");
        panic("nucleor: `use ... as ...` aliases not yet supported (see ERROR diagnostic above)");
    };
    if tail_v718 < eol && str_char_at(line, tail_v718) == 42 {
        print("ERROR: glob imports `use path::*` are not yet supported in Nucleor. Workaround: import the module path directly with `use std::foo` / `import \"...\"` and use the current flat exported names. Tracked for RFC-0018 resolver phase 2.");
        panic("nucleor: `use ...::*` glob import not yet supported (see ERROR diagnostic above)");
    };
    if tail_v718 < eol && str_char_at(line, tail_v718) == 123 {
        print("ERROR: selective import lists `use path::{a, b}` are not yet supported in Nucleor. Workaround: import the module path directly with `use std::foo` / `import \"...\"` and use the current flat exported names. Tracked for RFC-0018 resolver phase 2.");
        panic("nucleor: `use ...::{...}` selective import not yet supported (see ERROR diagnostic above)");
    };
    let raw_path: str = str_substring(line, qp, path_end);
    let plen: i64 = str_len(raw_path);
    let mut prefix: str = "";
    let mut tail_start: i64 = 0;
    if str_starts_with(raw_path, "std::") == 1 {
        prefix = "stdlib/rods/";
        tail_start = 5;
    } else if str_starts_with(raw_path, "crate::") == 1 {
        prefix = "";
        tail_start = 7;
    } else if str_starts_with(raw_path, "super::") == 1 {
        prefix = "../";
        tail_start = 7;
    } else { return ""; };
    let mut sb: i64 = sb_new();
    sb_append(sb, prefix);
    let mut i: i64 = tail_start;
    while i < plen {
        let ch: i64 = str_char_at(raw_path, i);
        if ch == 58 && i + 1 < plen && str_char_at(raw_path, i + 1) == 58 {
            sb_append(sb, "/");
            i = i + 2;
        } else {
            sb_append_char_at(sb, raw_path, i);
            i = i + 1;
        };
    };
    sb_append(sb, ".nr");
    return sb_to_str(sb);
}

#[manual_drop]
// Import-cycle detection:
// the resolver dedupes imports via the global `imported` Vec — once
// a path is in the set it's silently skipped. That makes legitimate
// dedupe (lib imported from siblings) indistinguishable from a
// cycle (A imports B imports A). Now an active-import stack
// `active_paths` tracks the in-flight recursion chain: push before
// descending into a file's content, pop after. When a `import "X"`
// hits a path already on the active stack, that's a back-edge cycle
// → emit `error[MOD-005]` and panic.
fn resolve_source_with_records(src: str, base_dir: str, imported: Vec<i32>, module_records: Vec<i32>) -> str {
    let active_paths: Vec<i32> = Vec::new();
    return resolve_source_with_records_active(src, base_dir, imported, module_records, active_paths);
}

#[manual_drop]
fn resolve_source_with_records_active(src: str, base_dir: str, imported: Vec<i32>, module_records: Vec<i32>, active_paths: Vec<i32>) -> str {
    let mut result: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(src, lp) == 32 || str_char_at(src, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = eol - lp;
        let mut prefix_len: i64 = 0;
        let mut is_mod_decl: i64 = 0;
        if line_len >= 8 && str_eq_at(src, lp, "pub use ") == 1 {
            print("ERROR: `pub use ...` re-exports are not yet supported in Nucleor. Workaround: import the target module directly at each use site or expose a `pub fn` wrapper from the module. Tracked for RFC-0018 resolver phase 2.");
            panic("nucleor: `pub use` re-export not yet supported (see ERROR diagnostic above)");
        };
        if line_len >= 8 && str_eq_at(src, lp, "import ") == 1 { prefix_len = 7; };
        if prefix_len == 0 && line_len >= 5 && str_eq_at(src, lp, "use ") == 1 { prefix_len = 4; };
        // RFC-0018 phase 1: `mod foo;` desugars to `import "./foo.nr"`.
        // T1.5a (v0.2.340): block-form `mod foo { ... }` is now also
        // recognized and inlined. The contents are spliced into the
        // outer source after stripping the `mod foo {` opener and the
        // matching `}` (brace-balanced scan, comment- and
        // string-literal-aware). This is the pragmatic prelude to the
        // full namespacing resolver — `mod tests { #[test] fn ... }`
        // patterns work today; visibility scoping arrives in T1.5b.
        if prefix_len == 0 && line_len >= 5 && str_eq_at(src, lp, "mod ") == 1 {
            let mut sp: i64 = lp + 4;
            while sp < eol && str_char_at(src, sp) == 32 { sp = sp + 1; };
            let mut np: i64 = sp;
            while np < eol && (is_alnum(str_char_at(src, np)) == 1) { np = np + 1; };
            // Tail after the name: `;` → file-rooted; `{` → block-form.
            let mut tp: i64 = np;
            while tp < eol && str_char_at(src, tp) == 32 { tp = tp + 1; };
            if np > sp && tp < eol && str_char_at(src, tp) == 59 {
                is_mod_decl = 1;
                prefix_len = 4;
            };
            if np > sp && tp < eol && str_char_at(src, tp) == 123 {
                // Block-form: scan brace-balanced past the `{`. Scanner
                // tracks string literals (single/double quotes) and
                // line comments so a `}` inside a string or `//` line
                // doesn't close the module prematurely.
                let body_start: i64 = tp + 1;
                let mut depth: i64 = 1;
                let mut q: i64 = body_start;
                let mut in_dquote: i64 = 0;
                let mut in_squote: i64 = 0;
                let mut in_line_comment: i64 = 0;
                while q < slen && depth > 0 {
                    let ch: i64 = str_char_at(src, q);
                    if in_line_comment == 1 {
                        if ch == 10 { in_line_comment = 0; };
                    } else if in_dquote == 1 {
                        if ch == 92 && q + 1 < slen { q = q + 1; }
                        else if ch == 34 { in_dquote = 0; };
                    } else if in_squote == 1 {
                        if ch == 92 && q + 1 < slen { q = q + 1; }
                        else if ch == 39 { in_squote = 0; };
                    } else if ch == 47 && q + 1 < slen && str_char_at(src, q + 1) == 47 {
                        in_line_comment = 1;
                        q = q + 1;
                    } else if ch == 34 {
                        in_dquote = 1;
                    } else if ch == 39 {
                        in_squote = 1;
                    } else if ch == 123 {
                        depth = depth + 1;
                    } else if ch == 125 {
                        depth = depth - 1;
                    };
                    q = q + 1;
                };
                if depth == 0 {
                    // Splice body in place; advance the outer scanner
                    // past the closing brace.
                    let body: str = str_substring(src, body_start, q - 1);
                    sb_append(result, "// mod ");
                    sb_append(result, str_substring(src, sp, np));
                    sb_append(result, " { ... } (inlined block-form)\n");
                    sb_append(result, resolve_source_with_records_active(body, base_dir, imported, module_records, active_paths));
                    sb_append(result, "\n");
                    p = q;
                    continue;
                };
                // Unbalanced — fall through; parser will surface the error.
            };
        };
        if prefix_len > 0 {
            let mut qp: i64 = lp + prefix_len;
            while qp < eol && str_char_at(src, qp) == 32 { qp = qp + 1; };
            // RFC-0018 phase 1: Rust-style `use std::foo` / `use crate::x` /
            // `use super::x` paths get rewritten to a quoted-path equivalent.
            let mut rust_path: str = "";
            if is_mod_decl == 1 {
                let mut np: i64 = qp;
                while np < eol && is_alnum(str_char_at(src, np)) == 1 { np = np + 1; };
                if np > qp {
                    rust_path = str_concat(str_substring(src, qp, np), ".nr");
                };
            } else {
                rust_path = rewrite_use_path(src, lp, prefix_len, eol);
            };
            if str_len(rust_path) > 0 {
                let path: str = resolve_import_path(base_dir, rust_path);
                let mut already: i64 = 0;
                let mut ii: i64 = 0;
                while ii < vec_len(imported) {
                    if str_eq(vec_get(imported, ii), path) { already = 1; };
                    ii = ii + 1;
                };
                // R12-D7 Phase 1: cycle detection. Path on active stack
                // means we're already mid-resolution of it — back-edge.
                let mut on_active_use: i64 = 0;
                let mut ai_use: i64 = 0;
                while ai_use < vec_len(active_paths) {
                    if str_eq(vec_get(active_paths, ai_use), path) { on_active_use = 1; };
                    ai_use = ai_use + 1;
                };
                if on_active_use == 1 {
                    let mut chain: str = "";
                    let mut ci: i64 = 0;
                    while ci < vec_len(active_paths) {
                        chain = str_concat(chain, vec_get(active_paths, ci));
                        chain = str_concat(chain, " -> ");
                        ci = ci + 1;
                    };
                    chain = str_concat(chain, path);
                    print(str_concat("error[MOD-005]: import cycle detected: ", chain));
                    panic("nucleor: import cycle (MOD-005); see error above");
                };
                if already == 0 {
                    imported.push(path);
                    let isrc: str = file_read_string(path);
                    source_reject_nul_truncation(path, isrc);
                    if str_len(isrc) > 0 {
                        let isrc_used: str = priv_apply_if_opted_in(isrc, path);
                        module_record_add(module_records, path, isrc_used);
                        let idir: str = extract_dir(path);
                        active_paths.push(path);
                        sb_append(result, resolve_source_with_records_active(isrc_used, idir, imported, module_records, active_paths));
                        active_paths.pop();
                        sb_append(result, "\n");
                    } else {
                        sb_append(result, str_concat("// ERROR: cannot read use path ", path));
                        sb_append(result, "\n");
                    };
                };
            } else if qp < eol && str_char_at(src, qp) == 34 {
                let ps: i64 = qp + 1;
                let mut pe: i64 = ps;
                while pe < eol && str_char_at(src, pe) != 34 { pe = pe + 1; };
                // Lane 4 / F-051: empty `import "";` silent accept.
                if pe == ps {
                    print(str_concat("error[PARSE-IMPORT-EMPTY]: empty import path `import \"\";` at byte ", str_concat(str_from_int(p), ". An import directive must name a non-empty path. Pre-fix the empty path was silently dropped.")));
                    panic("nucleor: empty import path");
                };
                let path: str = resolve_import_path(base_dir, str_substring(src, ps, pe));
                let mut already: i64 = 0;
                let mut ii: i64 = 0;
                while ii < vec_len(imported) {
                    if str_eq(vec_get(imported, ii), path) { already = 1; };
                    ii = ii + 1;
                };
                // R12-D7 Phase 1: cycle detection (mirror of `use` arm).
                let mut on_active_imp: i64 = 0;
                let mut ai_imp: i64 = 0;
                while ai_imp < vec_len(active_paths) {
                    if str_eq(vec_get(active_paths, ai_imp), path) { on_active_imp = 1; };
                    ai_imp = ai_imp + 1;
                };
                if on_active_imp == 1 {
                    let mut chain_imp: str = "";
                    let mut ci_imp: i64 = 0;
                    while ci_imp < vec_len(active_paths) {
                        chain_imp = str_concat(chain_imp, vec_get(active_paths, ci_imp));
                        chain_imp = str_concat(chain_imp, " -> ");
                        ci_imp = ci_imp + 1;
                    };
                    chain_imp = str_concat(chain_imp, path);
                    print(str_concat("error[MOD-005]: import cycle detected: ", chain_imp));
                    panic("nucleor: import cycle (MOD-005); see error above");
                };
                if already == 0 {
                    imported.push(path);
                    let isrc: str = file_read_string(path);
                    source_reject_nul_truncation(path, isrc);
                    if str_len(isrc) > 0 {
                        let isrc_used: str = priv_apply_if_opted_in(isrc, path);
                        module_record_add(module_records, path, isrc_used);
                        let idir: str = extract_dir(path);
                        active_paths.push(path);
                        sb_append(result, resolve_source_with_records_active(isrc_used, idir, imported, module_records, active_paths));
                        active_paths.pop();
                        sb_append(result, "\n");
                    } else {
                        sb_append(result, str_concat("// ERROR: cannot read import ", path));
                        sb_append(result, "\n");
                    };
                };
            } else {
                // Lane 4 / F-050: `import` without a quoted path silently
                // dropped. Rewriter only handles `use std::/crate::/super::`
                // unquoted forms; other unquoted shapes after `import ` /
                // `use ` / `mod ` fall here and were pre-fix preserved
                // verbatim into the resolved source — the parser then
                // saw `import foo;` and failed cryptically (or silently
                // accepted, since `import` isn't a parser keyword and
                // dispatched to the silent-skip catch-all). Reject early.
                if prefix_len == 7 {
                    print(str_concat("error[PARSE-IMPORT-001]: `import` requires a quoted path `import \"path/to/file.nr\";` at byte ", str_concat(str_from_int(p), ". Pre-fix unquoted forms like `import foo;` or `import stdlib/rods/strings.nr;` were silently passed through to the parser and dropped.")));
                    panic("nucleor: unquoted import path");
                };
                sb_append_range(result, src, p, eol);
                sb_append(result, "\n");
            };
        } else if line_len >= 2 && str_char_at(src, lp) == 35 && str_char_at(src, lp + 1) != 91 {
            // Skip # directives (#link, #cfile). Rust-style outer
            // attributes `#[...]` are preserved so the diag-filter
            // (`filter_allow_suppressed`) can still see them.
            sb_append(result, "\n");
        } else {
            sb_append_range(result, src, p, eol);
            sb_append(result, "\n");
        };
        p = eol + 1;
    };
    return sb_to_str(result);
}

#[manual_drop]
fn resolve_source(src: str, base_dir: str, imported: Vec<i32>) -> str {
    let mut module_records: Vec<i32> = Vec::new();
    return resolve_source_with_records(src, base_dir, imported, module_records);
}

fn source_reject_nul_truncation(path: str, source: str) -> i64 {
    let disk_size: i64 = fs_size(path);
    let visible_size: i64 = str_len(source);
    if disk_size > visible_size {
        print(str_concat("error[LEX-002]: NUL byte (0x00) in source at byte ", str_concat(str_from_int(visible_size), str_concat(" in ", str_concat(path, ". Nucleor source must not contain embedded NUL bytes; pre-fix file_read_string truncated at the first NUL and compiled only the prefix.")))));
        panic("nucleor: NUL byte in source (LEX-002)");
    };
    return 0;
}

#[manual_drop]
fn load_resolved_source_bundle(src_path: str, use_cache: i64) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let manifest_path: str = module_graph_manifest_path(src_path);
    let source_path: str = module_graph_source_path(src_path);
    let max_depth_path: str = module_graph_max_depth_source_path(src_path);
    let is_compiler_src: i64 = if str_ends_with(src_path, "nucleor_s1_compiler.nr") == 1 { 1 }
        else if str_ends_with(src_path, "nucleor_tools_suite.nr") == 1 { 1 }
        else { 0 };
    if use_cache == 1 && is_compiler_src == 0 {
        let manifest: str = file_read_string(manifest_path);
        let cached_source: str = file_read_string(source_path);
        let cached_max_depth_source: str = file_read_string(max_depth_path);
        if str_len(manifest) > 0 && str_len(cached_source) > 0 {
            let valid: Vec<i32> = module_records_validate(manifest);
            let stale_md_cache: i64 = if source_has_max_depth_attr_line(cached_source) == 1 && str_len(cached_max_depth_source) == 0 { 1 } else { 0 };
            if vec_get(valid, 0) == 1 && stale_md_cache == 0 {
                out.push(expand_actor_decl_keyword(cached_source));
                out.push(vec_get(valid, 1));
                out.push(1);
                if str_len(cached_max_depth_source) > 0 { out.push(expand_actor_decl_keyword(cached_max_depth_source)); };
                return out;
            };
        };
    };
    let raw_source: str = file_read_string(src_path);
    source_reject_nul_truncation(src_path, raw_source);
    let mut imported: Vec<i32> = Vec::new();
    if str_len(raw_source) == 0 {
        out.push("");
        out.push(imported);
        out.push(0);
        return out;
    };
    let mut module_records: Vec<i32> = Vec::new();
    imported.push(src_path);
    module_record_add(module_records, src_path, raw_source);
    // R12-D7 Phase 1 (v0.8.294): seed active_paths with src_path so a
    // child module that re-imports the entry source is detected as a
    // cycle via _active's back-edge check (otherwise `imported`
    // already contains src_path and the dedupe short-circuits).
    let mut active_paths_seed: Vec<i32> = Vec::new();
    active_paths_seed.push(src_path);
    // skip the resolve loop
    // when the source has no top-of-line `import "` / `use ` / `mod `
    // directives. resolve_source_with_records_active is a 250-line per-
    // byte/per-line walker that costs ~13 s on the 2.4 MB compiler
    // source. For directive-free sources it has no work to do but the
    // walk runs anyway. Quick gate via line-start substring presence.
    let mut resolved: str = "";
    if str_contains(raw_source, "\nimport \"") == 0 && str_contains(raw_source, "\nuse ") == 0 && str_contains(raw_source, "\nmod ") == 0 && str_contains(raw_source, "\npub use ") == 0 && str_starts_with(raw_source, "import \"") == 0 && str_starts_with(raw_source, "use ") == 0 && str_starts_with(raw_source, "mod ") == 0 && str_starts_with(raw_source, "pub use ") == 0 {
        resolved = raw_source;
    } else {
        resolved = resolve_source_with_records_active(raw_source, extract_dir(src_path), imported, module_records, active_paths_seed);
    };
    // v0.7.88 (defensive halt — Rust compile_error ! macro invocation).
    // Pre-fix the macro-call shape compile_error ! (...) was
    // silently dropped by the parser (Nucleor's `!`-after-ident
    // handling treats it as a logical-not on the args, which
    // then gets DCE'd as a discarded value), so adopters writing
    // compile_error ! ("required feature missing") got a
    // successful build instead of the explicit compile-time
    // failure they wrote to force. Detect the literal
    // compile_error+!( byte sequence in the resolved source
    // and halt cleanly (the macro is now honored as the canonical
    // build-failure trigger).
    // skip when compiling the compiler itself (self-host
    // fixed-point path). The compiler source contains the search
    // pattern in string literals and comments; the textual pre-pass
    // would fire on self-compilation — a Linux-bootstrap false-positive.
    // str_concat avoids the literal pattern appearing in source text
    // so the search string is constructed at runtime.
    // RFC-0063 Phase 2.0.3 prep: also exempt
    // nucleor_tools_suite.nr — same rationale (compiler source contains
    // the pattern in error-message strings) and the parser-unification
    // ship needs tools_suite to be able to `import "...nucleor_s1_compiler.nr"`
    // without the detector tripping on s1's strings.
    let ce_halt: str = str_concat("compile_error", "!(");
    if is_compiler_src == 0 {
        if str_contains(resolved, ce_halt) == 1 {
            print("ERROR: compile_error!(...) invocation in source. The macro is now honored: this build is failing because the adopter explicitly requested it via compile_error!.");
            print("       This is the canonical compile_error! semantic — it ALWAYS fails the build at the point of invocation. If you need conditional compile-time errors based on hardware capabilities, see RFC-0048 hardware-capability queries (Phase A landed v0.7.88) and the target_caps_* rod surface for runtime equivalents.");
            panic("nucleor: compile_error! invoked in source");
        };
    };
    // skip the format-macro and
    // async-keyword expansions for compiler self-builds. Both transforms
    // scan the entire source byte-by-byte; on the 2.4 MB compiler source
    // they cost ~13 s combined despite the source containing zero actual
    // macro / async surfaces — only error-message string literals match.
    // T2.6 (v0.2.346): expand println!/print!/format! macros AFTER all
    // imports are inlined and BEFORE caching, so the cache holds the
    // post-expansion text. Identifier-and-quote-aware so a `!` inside
    // a string literal (e.g. `"err!"`) survives untouched.
    // T2.8 (v0.2.353): strip `async` keyword before fn + rewrite
    // `<ident>.await` to `async_await(<ident>)`. Threads-only
    // commitment per RFC-0027 phase 1.
    let mut after_format: str = resolved;
    let mut after_async: str = resolved;
    if is_compiler_src == 0 {
        after_format = expand_format_macros(resolved);
        after_async = expand_async_syntax(after_format);
    } else {
        after_async = resolved;
    };
    // Compiler self-builds are not adopter code. Keep the advisory
    // audit surface active for user programs, but avoid repeatedly
    // scanning and printing the compiler's own multi-megabyte source
    // during self-host/perf gates.
    if is_compiler_src == 0 {
    // v0.8.5 (RFC-0045 Phase B step-1) — `@differentiable` audit.
    // The lex-time `@`-attribute skip (line ~247) already accepts
    // the attribute silently. Phase B-step-1 adds a build-time
    // count + one-line audit print so adopters get the
    // "Discovery: no way to grep for all differentiable fns in
    // a codebase" surface that v0.7.93 Phase A's runtime
    // registry was paired with. Phase B-step-2 (deferred) does
    // the symbol-alias emit for autodiff dispatch.
    let v085_diff_count: i64 = differentiable_audit_count(after_async);
    if v085_diff_count > 0 {
        print(str_concat("audit: @differentiable fns in build: ", str_from_int(v085_diff_count)));
        // emit the actual fn names.
        let v0815_diff_names: str = attribute_audit_fn_names(after_async, str_concat("@differen", "tiable"));
        if str_len(v0815_diff_names) > 0 {
            print(str_concat("audit:   differentiable fns: ", v0815_diff_names));
        };
    };
    // v0.8.6 (RFC-0050 Phase B step-1) — `@energy(max=...)` and
    // `@thermal(max_temp=...)` audit. Same shape as v0.8.5
    // @differentiable: lex-time `@`-attribute skip already accepts
    // these silently; this audit pass counts annotated fns and
    // emits a one-line build summary. Phase A (v0.7.89) added the
    // runtime budget registry; Phase B step-2 (deferred) parses
    // the literal value + unit and stores as fn metadata.
    let v086_energy_count: i64 = simple_attribute_audit_count(after_async, str_concat("@ene", "rgy("));
    if v086_energy_count > 0 {
        print(str_concat("audit: @energy budgets in build: ", str_from_int(v086_energy_count)));
        // emit the actual budget values.
        // @energy(max=2mJ) -> "2mJ".
        let v0811_energy_vals: str = attribute_audit_value_arg(after_async, str_concat("@ene", "rgy("));
        if str_len(v0811_energy_vals) > 0 {
            print(str_concat("audit:   energy values: ", v0811_energy_vals));
        };
    };
    let v086_thermal_count: i64 = simple_attribute_audit_count(after_async, str_concat("@therm", "al("));
    if v086_thermal_count > 0 {
        print(str_concat("audit: @thermal budgets in build: ", str_from_int(v086_thermal_count)));
        // emit the FULL multi-key range
        // for @thermal. @thermal(min_temp=-40C, max_temp=85C)
        // surfaces as "min_temp=-40C; max_temp=85C" instead of
        // just the first key (the v0.8.11 limitation).
        let v0813_thermal_vals: str = attribute_audit_all_kv_pairs(after_async, str_concat("@therm", "al("));
        if str_len(v0813_thermal_vals) > 0 {
            print(str_concat("audit:   thermal values: ", v0813_thermal_vals));
        };
    };
    // v0.8.7 (RFC-0052/53/57/60 Phase B step-1) — extended
    // attribute audit. Same shape as v0.8.5 / v0.8.6: count
    // annotated fns, emit one-line summary per attribute kind.
    let v087_photonic_count: i64 = simple_attribute_audit_count(after_async, str_concat("@photo", "nic"));
    if v087_photonic_count > 0 {
        print(str_concat("audit: @photonic fns in build: ", str_from_int(v087_photonic_count)));
        // extract device name from
        // bracket-form @photonic[device=...].
        let v0814_photo_devs: str = attribute_audit_bracket_device(after_async, str_concat("@photo", "nic["));
        if str_len(v0814_photo_devs) > 0 {
            print(str_concat("audit:   photonic devices: ", v0814_photo_devs));
        };
    };
    let v087_neuro_count: i64 = simple_attribute_audit_count(after_async, str_concat("@neuromor", "phic"));
    if v087_neuro_count > 0 {
        print(str_concat("audit: @neuromorphic fns in build: ", str_from_int(v087_neuro_count)));
        // extract device name from
        // bracket-form @neuromorphic[device=...].
        let v0814_neuro_devs: str = attribute_audit_bracket_device(after_async, str_concat("@neuromor", "phic["));
        if str_len(v0814_neuro_devs) > 0 {
            print(str_concat("audit:   neuromorphic devices: ", v0814_neuro_devs));
        };
    };
    let v087_enclave_count: i64 = simple_attribute_audit_count(after_async, str_concat("@encl", "ave("));
    if v087_enclave_count > 0 {
        print(str_concat("audit: @enclave fns in build: ", str_from_int(v087_enclave_count)));
        // list enclave engines.
        let v0810_enclave_engines: str = attribute_audit_first_ident_arg(after_async, str_concat("@encl", "ave("));
        if str_len(v0810_enclave_engines) > 0 {
            print(str_concat("audit:   engines: ", v0810_enclave_engines));
        };
    };
    let v087_attested_count: i64 = simple_attribute_audit_count(after_async, str_concat("@atte", "sted"));
    if v087_attested_count > 0 {
        print(str_concat("audit: @attested fns in build: ", str_from_int(v087_attested_count)));
        // emit the actual fn names.
        let v0815_attested_names: str = attribute_audit_fn_names(after_async, str_concat("@atte", "sted"));
        if str_len(v0815_attested_names) > 0 {
            print(str_concat("audit:   attested fns: ", v0815_attested_names));
        };
    };
    let v087_authored_count: i64 = simple_attribute_audit_count(after_async, str_concat("@auth", "ored("));
    if v087_authored_count > 0 {
        print(str_concat("audit: @authored fns in build: ", str_from_int(v087_authored_count)));
        // emit the list of authors
        // alongside the count. Adopters get the actual names
        // surfaced at build, not just a number.
        let v089_author_list: str = attribute_audit_first_str_arg(after_async, str_concat("@auth", "ored("));
        if str_len(v089_author_list) > 0 {
            print(str_concat("audit:   authors: ", v089_author_list));
        };
    };
    let v087_policy_count: i64 = simple_attribute_audit_count(after_async, str_concat("@pol", "icy("));
    if v087_policy_count > 0 {
        print(str_concat("audit: @policy decls in build: ", str_from_int(v087_policy_count)));
        // list policy names alongside
        // the count. @policy(no_unsafe) -> "no_unsafe".
        // @policy("foo") -> "foo". The ident-arg helper handles
        // the bare-ident case; the str-arg helper handles the
        // quoted-string case. We emit BOTH lists when both
        // shapes appear in the source.
        let v0810_policy_idents: str = attribute_audit_first_ident_arg(after_async, str_concat("@pol", "icy("));
        if str_len(v0810_policy_idents) > 0 {
            print(str_concat("audit:   policies: ", v0810_policy_idents));
        };
    };
    let v087_within_count: i64 = simple_attribute_audit_count(after_async, str_concat("@wit", "hin("));
    if v087_within_count > 0 {
        print(str_concat("audit: @within timing constraints in build: ", str_from_int(v087_within_count)));
        // emit the actual timing values.
        // @within(200ns) -> "200ns".
        let v0811_within_vals: str = attribute_audit_value_arg(after_async, str_concat("@wit", "hin("));
        if str_len(v0811_within_vals) > 0 {
            print(str_concat("audit:   timing values: ", v0811_within_vals));
        };
    };
    // v0.8.143 (RFC-0043 Phase B step-1, V1.12 drift restoration)
    // — `fixed<I, F>` + `ufixed<I, F>` audit. The type still
    // collapses to i64 storage at line ~9902 (Phase B step-2
    // deferred — true IrTypeFixed width tracking is the ~300 LOC
    // ship). This Phase B step-1 surfaces adopter usage by
    // counting type-position occurrences and emitting a one-line
    // build summary, matching the @differentiable / @energy /
    // @thermal pattern. Position-aware needles (`: ` and `-> `
    // prefix) avoid false positives on identifiers ending in
    // "fixed" or "ufixed".
    // gate the per-needle scans behind a single
    // cheap probe. Most builds don't contain `fixed<` or `ufixed<`
    // — without the gate this block ran 4 full-source scans
    // unconditionally on every compile. Same shape applied to the
    // other audit families below.
    if str_index_of(after_async, "fixed<") >= 0 {
        let v0143_fixed_colon: i64 = simple_attribute_audit_count(after_async, str_concat(": fix", "ed<"));
        let v0143_fixed_arrow: i64 = simple_attribute_audit_count(after_async, str_concat("-> fix", "ed<"));
        let v0143_ufixed_colon: i64 = simple_attribute_audit_count(after_async, str_concat(": ufix", "ed<"));
        let v0143_ufixed_arrow: i64 = simple_attribute_audit_count(after_async, str_concat("-> ufix", "ed<"));
        let v0143_fixed_total: i64 = v0143_fixed_colon + v0143_fixed_arrow + v0143_ufixed_colon + v0143_ufixed_arrow;
        if v0143_fixed_total > 0 {
            print(str_concat("audit: fixed<I,F>/ufixed<I,F> type-position occurrences: ", str_from_int(v0143_fixed_total)));
        };
    };
    // v0.8.173 (RFC-0044 Phase B step-1, V1.13 drift restoration)
    // — per-BinOp `OverflowMode` audit. RFC-0044 calls for two
    // surface forms:
    //   - block: `wrapping { ... }` / `saturating { ... }` / `checked { ... }`
    //   - inline-suffix: `*#wrap`, `+#sat`, `/#trap`, `as#sat`, etc.
    // V2 carried `OverflowMode` as a per-BinOp IR field; OSS retained
    // only the block form (and even that may not be implemented yet
    // in current main). Phase B step-1 (this audit) surfaces adopter
    // usage of either form so future ships can lock the block-form
    // wiring + add the inline-suffix lex extension. Phase B step-2
    // (real per-BinOp lowering) is the larger ~150 LOC compiler ship.
    if str_index_of(after_async, "wrapping ") >= 0 || str_index_of(after_async, "saturating ") >= 0 || str_index_of(after_async, "#wrap") >= 0 || str_index_of(after_async, "#sat") >= 0 || str_index_of(after_async, "#trap") >= 0 {
        let v0173_wrap_block: i64 = simple_attribute_audit_count(after_async, str_concat("wrap", "ping {"));
        let v0173_sat_block: i64 = simple_attribute_audit_count(after_async, str_concat("satur", "ating {"));
        let v0173_check_block: i64 = simple_attribute_audit_count(after_async, str_concat("check", "ed {"));
        let v0173_inline_wrap: i64 = simple_attribute_audit_count(after_async, "#wrap");
        let v0173_inline_sat: i64 = simple_attribute_audit_count(after_async, "#sat");
        let v0173_inline_trap: i64 = simple_attribute_audit_count(after_async, "#trap");
        let v0173_overflow_total: i64 = v0173_wrap_block + v0173_sat_block + v0173_check_block + v0173_inline_wrap + v0173_inline_sat + v0173_inline_trap;
        if v0173_overflow_total > 0 {
            print(str_concat("audit: per-BinOp OverflowMode usages (block + inline): ", str_from_int(v0173_overflow_total)));
        };
    };
    // v0.8.145 (RFC-0046 Phase B step-1, V2.1 frontier easy-win)
    // — `Pose<F>` + `Frame_*` marker audit. The `kinematics_frame`
    // rod already ships zero-cost marker structs (`Frame_World`,
    // `Frame_Base`, `Frame_Camera`, `Frame_Lidar`, `Frame_IMU`).
    // Adopters using these as phantom frame tags get a build-time
    // discovery counter from this audit pass. Phase B step-2 —
    // true phantom-type checking, `types_compatible(Pose<Camera>,
    // Pose<Base>) == 0` with a FRAME-001 diagnostic at let-binding
    // site — shipped v0838 (ROBO-7); see `frame_mismatch_visible`
    // and the FRAME-001 emit at the let-binding TYP-008 site.
    // Architectural pattern matches RFC-0043 fixed<I,F>.
    if str_index_of(after_async, "Pose<") >= 0 || str_index_of(after_async, "Frame_") >= 0 {
        let v0145_pose_colon: i64 = simple_attribute_audit_count(after_async, str_concat(": Po", "se<"));
        let v0145_pose_arrow: i64 = simple_attribute_audit_count(after_async, str_concat("-> Po", "se<"));
        let v0145_pose_total: i64 = v0145_pose_colon + v0145_pose_arrow;
        if v0145_pose_total > 0 {
            print(str_concat("audit: Pose<F> phantom-frame type-position occurrences: ", str_from_int(v0145_pose_total)));
        };
        let v0145_frame_marker: i64 = simple_attribute_audit_count(after_async, str_concat(": Fra", "me_"));
        if v0145_frame_marker > 0 {
            print(str_concat("audit: Frame_* marker uses (let/arg position): ", str_from_int(v0145_frame_marker)));
        };
    };
    // v0.8.146 (RFC-0047 Phase B step-1, V2.2 frontier easy-win)
    // — typed dimensional units `unit<T, [kg, m, s, A, K, mol,
    // cd]>` audit. Same architectural pattern as RFC-0046
    // Pose<F>: phantom dimensional type parameter, zero runtime
    // cost. Phase B step-2 (real dim-vector arithmetic in
    // type-check) is the ~400 LOC compiler ship per the RFC.
    // This Phase B step-1 surfaces type-position usage of
    // unit<T, [...]> + the existing dimension-aliased `Mass<>`
    // / `Length<>` / `Force<>` / `Acceleration<>` shapes that
    // adopters might already be drafting.
    if str_index_of(after_async, "unit<") >= 0 || str_index_of(after_async, "Mass<") >= 0 || str_index_of(after_async, "Length<") >= 0 || str_index_of(after_async, "Force<") >= 0 || str_index_of(after_async, "Acceleration<") >= 0 {
        let v0146_unit_colon: i64 = simple_attribute_audit_count(after_async, str_concat(": un", "it<"));
        let v0146_unit_arrow: i64 = simple_attribute_audit_count(after_async, str_concat("-> un", "it<"));
        let v0146_mass_colon: i64 = simple_attribute_audit_count(after_async, str_concat(": Ma", "ss<"));
        let v0146_length_colon: i64 = simple_attribute_audit_count(after_async, str_concat(": Len", "gth<"));
        let v0146_force_colon: i64 = simple_attribute_audit_count(after_async, str_concat(": For", "ce<"));
        let v0146_accel_colon: i64 = simple_attribute_audit_count(after_async, str_concat(": Accelera", "tion<"));
        let v0146_unit_total: i64 = v0146_unit_colon + v0146_unit_arrow + v0146_mass_colon + v0146_length_colon + v0146_force_colon + v0146_accel_colon;
        if v0146_unit_total > 0 {
            print(str_concat("audit: unit<T,[...]> typed-dim type-position occurrences: ", str_from_int(v0146_unit_total)));
        };
    };
    // v0.8.147 (RFC-0048 Phase B step-1, V2.3 frontier easy-win)
    // — hardware capability query audit. Adopters use
    // `target.has(FP4)` / `target.has(AVX512)` / `target.os(...)`
    // for compile-time-resolved kernel selection. Phase B step-2
    // (real compile-time evaluation that prunes non-target
    // branches via DCE before lowering) is the larger ship.
    // This Phase B step-1 surfaces usage by counting `target.has(`
    // and `target.os(` occurrences.
    if str_index_of(after_async, "target.") >= 0 {
        let v0147_target_has: i64 = simple_attribute_audit_count(after_async, str_concat("target.h", "as("));
        let v0147_target_os: i64 = simple_attribute_audit_count(after_async, str_concat("target.", "os("));
        let v0147_target_total: i64 = v0147_target_has + v0147_target_os;
        if v0147_target_total > 0 {
            print(str_concat("audit: target.has()/target.os() compile-time queries: ", str_from_int(v0147_target_total)));
        };
    };
    // v0.8.148 (RFC-0049 Phase B step-1, V2.4 frontier easy-win)
    // — memory-space type-tag audit. Same architectural pattern
    // as RFC-0046 Pose<F>: phantom Space parameter on Tensor.
    // Surfaces adopter usage of `Tensor<f32, MemSpace_HBM>` etc.
    // Phase B step-2 (types_compatible enforcement on Space) is
    // the real ship.
    if str_index_of(after_async, "MemSpace_") >= 0 {
        let v0148_memspace: i64 = simple_attribute_audit_count(after_async, str_concat(": MemSp", "ace_"));
        let v0148_tensor_space: i64 = simple_attribute_audit_count(after_async, str_concat(", MemSp", "ace_"));
        let v0148_memspace_total: i64 = v0148_memspace + v0148_tensor_space;
        if v0148_memspace_total > 0 {
            print(str_concat("audit: MemSpace_* type-position occurrences: ", str_from_int(v0148_memspace_total)));
        };
    };
    // v0.8.149 (RFC-0051 Phase B step-1, V2.6 frontier easy-win)
    // — Model<Arch, ...> provenance audit. Surfaces adopter
    // usage of typed foundation-model wrappers carrying
    // weights_hash / dataset_lineage / license / safety_eval /
    // quantization at the type level. Phase B step-2 (real
    // type-checked Model<...> with SPDX-validated license arg
    // etc.) is the larger ship.
    if str_index_of(after_async, "Model<") >= 0 {
        let v0149_model_colon: i64 = simple_attribute_audit_count(after_async, str_concat(": Mo", "del<"));
        let v0149_model_arrow: i64 = simple_attribute_audit_count(after_async, str_concat("-> Mo", "del<"));
        let v0149_model_total: i64 = v0149_model_colon + v0149_model_arrow;
        if v0149_model_total > 0 {
            print(str_concat("audit: Model<Arch,...> provenance type-position occurrences: ", str_from_int(v0149_model_total)));
        };
    };
    // v0.8.8 (Phase B step-1, core-attr audit) — extend the
    // discovery surface to existing core Nucleor attributes that
    // adopters use today: @hot (strict perf), @const_fn (compile-
    // time eligible), @max_depth (RFC-0014 / Track I), @deadline
    // (RT-004). The expansions for @max_depth + @deadline DO
    // produce metadata; the audit count adds a plain-language
    // build summary alongside.
    let v088_hot_count: i64 = simple_attribute_audit_count(after_async, str_concat("@h", "ot"));
    if v088_hot_count > 0 {
        print(str_concat("audit: @hot fns in build: ", str_from_int(v088_hot_count)));
        // emit the actual fn names.
        let v0815_hot_names: str = attribute_audit_fn_names(after_async, str_concat("@h", "ot"));
        if str_len(v0815_hot_names) > 0 {
            print(str_concat("audit:   hot fns: ", v0815_hot_names));
        };
    };
    let v088_const_fn_count: i64 = simple_attribute_audit_count(after_async, str_concat("@const_", "fn"));
    if v088_const_fn_count > 0 {
        print(str_concat("audit: @const_fn fns in build: ", str_from_int(v088_const_fn_count)));
        // emit the actual fn names.
        let v0815_cf_names: str = attribute_audit_fn_names(after_async, str_concat("@const_", "fn"));
        if str_len(v0815_cf_names) > 0 {
            print(str_concat("audit:   const_fn fns: ", v0815_cf_names));
        };
    };
    let v088_max_depth_count: i64 = simple_attribute_audit_count(after_async, str_concat("#[max_de", "pth"));
    if v088_max_depth_count > 0 {
        print(str_concat("audit: #[max_depth] fns in build: ", str_from_int(v088_max_depth_count)));
        // emit the actual fn names.
        let v0815_md_names: str = attribute_audit_fn_names(after_async, str_concat("#[max_de", "pth"));
        if str_len(v0815_md_names) > 0 {
            print(str_concat("audit:   max_depth fns: ", v0815_md_names));
        };
    };
    let v088_deadline_count: i64 = simple_attribute_audit_count(after_async, str_concat("#[deadl", "ine"));
    if v088_deadline_count > 0 {
        print(str_concat("audit: #[deadline] fns in build: ", str_from_int(v088_deadline_count)));
        // emit the actual fn names.
        let v0815_dl_names: str = attribute_audit_fn_names(after_async, str_concat("#[deadl", "ine"));
        if str_len(v0815_dl_names) > 0 {
            print(str_concat("audit:   deadline fns: ", v0815_dl_names));
        };
    };
    // v0.8.17 RFC-0062 G-2 Phase 1 — BR-7 lifetime parameter
    // diagnostic-only mode. Per the gap RFC §3.3 G-2 P1: emit a
    // build-time warning for every `<'a>` lifetime annotation
    // present in user code, surfacing the gap that lifetime
    // annotations parse but the borrow checker does not yet
    // enforce them. Phase 4 promotes the warning to error.
    // Detection: count occurrences of `<'` (lifetime-param-list
    // open) preceded by `fn ` or by `struct ` or by `impl `.
    // Per the gap RFC §2.2 BR-7: "the syntax `fn f<'a>(x: &'a str)
    // -> &'a str` parses cleanly. The lexer accepts the lifetime
    // tokens, the parser builds the AST, the function compiles.
    // The borrow checker does NOT actually enforce the lifetime
    // annotation."
    // collapsed 3 separate scans into 1 single-pass scan.
    let v0817_br7_total: i64 = audit_count_three_needles_total(after_async,
        str_concat("<'", "a"), str_concat("<'", "b"), str_concat("&'", "static"));
    if v0817_br7_total > 0 {
        print(str_concat("warning[BR-7]: lifetime annotations present in build: ", str_from_int(v0817_br7_total)));
        print("  Per RFC-0062 G-2 Phase 1: lifetime annotations parse cleanly but are NOT yet enforced by the borrow checker. Runtime safety is not statically guaranteed for functions / structs / impls using `<'a>` syntax. Phase 2 will add simple single-input single-output lifetime checking; Phase 4 promotes this warning to a hard error. Track via tests/err/_unimplemented/README.md once the closure-phase log lands.");
    };
    // RFC-0062 G-4 Phase 2a — OWN-012 double-free /
    // use-after-drop heuristic warning. Textual scan for
    // `vec_free(` and `hashmap_free(`. Phase 2a is a heuristic
    // pre-pass; Phase 2b will replace this with proper IR-level
    // ownership tracking. Phase 4 promotes to error.
    let v0824_vec_free_count: i64 = simple_attribute_audit_count(after_async,
        str_concat("vec_", "free("));
    let v0824_hashmap_free_count: i64 = simple_attribute_audit_count(after_async,
        str_concat("hashmap_", "free("));
    let v0824_total_free: i64 = v0824_vec_free_count + v0824_hashmap_free_count;
    if v0824_total_free > 0 {
        print(str_concat("warning[OWN-012]: explicit free calls present in build: ", str_from_int(v0824_total_free)));
        print(str_concat("  Per RFC-0062 G-4 Phase 3 (v1.0): explicit `vec_free` / `hashmap_free` are accepted but the compiler does NOT yet check that the freed binding is unused after the free call. Adopter discipline: do not access a vec/map after passing it to its free helper. IR-level use-after-drop tracking is post-v1.0 hardening. Recommended: prefer auto-drop (default-on as of v0.8.x via RFC-0042/G-1 Phase 2b-3) which inserts cleanup automatically; mark fns `#[manual_", "drop]` only when explicit lifetime control is required."));
    };
    // RFC-0062 G-5 Phase 2a — FFI null-return audit
    // info. Detects `*const c_void` and `*mut c_void` return
    // types in extern fn declarations. Phase 2a is heuristic;
    // Phase 2b will add per-fn null-check inference. Phase 4
    // promotes to lint warning when call site lacks
    // `ptr_is_null` guard.
    let v0825_extern_void_count: i64 = audit_count_three_needles_total(after_async,
        str_concat("*const ", "c_void"), str_concat("*mut ", "c_void"),
        str_concat("-> *const ", "u8"));
    if v0825_extern_void_count > 0 {
        print(str_concat("warning[FFI-NULL]: raw-pointer return types in extern fn decls: ", str_from_int(v0825_extern_void_count)));
        print("  Per RFC-0062 G-5 Phase 3 (v1.0): extern fn returning `*const c_void` / `*mut c_void` / `*const u8` may return NULL on failure (RFC-0062 §3.3 G-5 contract). The compiler does NOT yet verify the wrapping rod fn null-checks before exposing to safe code. Adopter discipline: every call site receiving a raw-pointer return must `if ptr_is_null(p) { panic(...); }` before deref. Per-fn null-check inference is post-v1.0 hardening. Reference: docs/ffi-conventions.md §1.");
    };
    // RFC-0062 G-9 Phase 2a — direct-FFI build-summary
    // info. Counts `extern fn ` declarations to surface the FFI
    // surface area at compile time. Phase 2a is heuristic;
    // Phase 2b will require `#[allow(direct_ffi)]` on calling
    // fn or `unsafe { }` block at call site. Phase 4 promotes
    // to hard error.
    let v0826_extern_count: i64 = simple_attribute_audit_count(after_async,
        str_concat("extern ", "fn "));
    if v0826_extern_count > 0 {
        print(str_concat("warning[FFI-DIRECT]: `extern fn` declarations in build: ", str_from_int(v0826_extern_count)));
        print("  Per RFC-0062 G-9 Phase 3 (v1.0): direct `extern fn` calls bypass the safe-code bounds-check insertion that wraps Nucleor index/range operations. Adopter discipline: treat every `extern fn` call site as an unsafe surface. `#[allow(direct_ffi)]` enforcement and bounds-check insertion at call sites are post-v1.0 hardening. Reference: docs/ffi-conventions.md §2.");
    };
    // RFC-0062 G-3 Phase 2a — heap-aliasing build-summary
    // info. Detects `Vec<&` patterns (Vec-of-references), the
    // primary heap-aliasing risk per RFC-0062 §3.3 G-3. The
    // syntactic borrow tracker doesn't follow elements through
    // a Vec; pushing two `&T` of the same `T` produces aliased
    // reads that today are invisible. Phase 2b adds Vec-of-ref
    // flow analysis; Phase 4 promotes to deny-by-default with
    // `#[allow(vec_of_refs)]` opt-out.
    let v0827_alias_scan: str = strip_strings_and_line_comments(after_async);
    let v0827_vof_count: i64 = simple_attribute_audit_count(v0827_alias_scan,
        str_concat("Vec", "<&"));
    if v0827_vof_count > 0 {
        print(str_concat("warning[ALIAS-G3]: Vec-of-reference patterns in build: ", str_from_int(v0827_vof_count)));
        print("  Per RFC-0062 G-3 Phase 3 (v1.0): `Vec<&T>` constructions hide aliasing from the syntactic borrow tracker. Pushing two `&T` borrows of the same `T` is invisible today. Adopter mitigation: prefer indexing — store `Vec<i64>` indexes into an owned vector rather than `Vec<&T>` borrows of separate vectors. Vec-of-reference flow analysis is post-v1.0 hardening.");
    };
    // v0.8.62 QM-8/9 + ROBO-8 Phase 1 — Wave 3 final Tier C
    // closure. v0828 closes the high-level qsim wrapper half of
    // QM-8/QM-9: qsim_cnot/CZ/CRK/CCX now update qsim_graph
    // entanglement and gate-DAG records through checked wrappers.
    // Raw runtime tracker unification remains open. QM-9: the raw
    // gate-influence DAG still caps at 4096 gates, but Nucleor callers
    // now have checked status/preflight helpers. ROBO-8: CHOMP uses approximated pre-conditioning
    // (clamp-magnitude vs full covariant A⁻¹∇F).
    let v0862_has_qsim_cnot: i64 = if str_index_of(after_async, str_concat("qsim_", "cnot")) >= 0 { 1 } else { 0 };
    let v0862_has_qsim_gate_record: i64 = if str_index_of(after_async, str_concat("qsim_gate_", "record")) >= 0 { 1 } else { 0 };
    let v0862_has_chomp: i64 = if str_index_of(after_async, str_concat("chomp", "_")) >= 0 { 1 } else { 0 };
    if v0862_has_qsim_cnot == 1 || v0862_has_qsim_gate_record == 1 || v0862_has_chomp == 1 {
        let v0862_qsim_cnot: i64 = if v0862_has_qsim_cnot == 1 { simple_attribute_audit_count(after_async, str_concat("qsim_", "cnot")) } else { 0 };
        let v0862_qsim_gate: i64 = if v0862_has_qsim_gate_record == 1 { simple_attribute_audit_count(after_async, str_concat("qsim_gate_", "record")) } else { 0 };
        let v0862_chomp: i64 = if v0862_has_chomp == 1 { simple_attribute_audit_count(after_async, str_concat("chomp", "_")) } else { 0 };
        let v0862_total: i64 = v0862_qsim_cnot + v0862_qsim_gate + v0862_chomp;
        if v0862_total > 0 {
            print(str_concat("info[QM-89-ROBO-8]: Wave 3 final Tier C surface: ", str_from_int(v0862_total)));
            print("  QM-8/QM-9 Phase 2a/2b is wired at the high-level stdlib wrapper surface: qsim_cnot/CZ/CRK/CCX call qsim_graph entanglement registration and checked gate-DAG recording in the same semantic places their trace hooks declare entanglement. Raw runtime tracker unification remains open, and raw nuc_qsim_gate_record still caps at 4096 gates; larger circuits should use qsim_gate_record_checked/preflight for explicit status. ROBO-8: CHOMP uses approximated pre-conditioning (per-step clamp-magnitude vs covariant A^-1 grad-F); convergence degrades on narrow corridors / high-DOF robots. Future work adds raw-runtime unification, overflow hardening, and full pre-conditioner.");
        };
    };
    // v0.8.61 ML-2/3/5/6/10 Phase 1 — Tensor/ML/Autodiff surface
    // info. Detects adopter use of tensor_nd or transformer rods
    // — surfaces have multiple HIGH-severity gaps: ML-2 missing
    // 2D matmul, ML-3 missing transpose, ML-5 SSM no backward,
    // ML-6 no FP8 gemv / grouped quantization, ML-10 transformer
    // no causal mask / no encoder-decoder. Phase 2b adds the
    // missing primitives.
    let v0861_has_tensor: i64 = if str_index_of(after_async, str_concat("tensor_", "nd")) >= 0 { 1 } else { 0 };
    let v0861_has_transformer: i64 = if str_index_of(after_async, str_concat("transformer", ".nr")) >= 0 { 1 } else { 0 };
    let v0861_has_ssm: i64 = if str_index_of(after_async, str_concat("nuc_", "ssm_")) >= 0 { 1 } else { 0 };
    if v0861_has_tensor == 1 || v0861_has_transformer == 1 || v0861_has_ssm == 1 {
        let v0861_tensor: i64 = if v0861_has_tensor == 1 { simple_attribute_audit_count(after_async, str_concat("tensor_", "nd")) } else { 0 };
        let v0861_transformer: i64 = if v0861_has_transformer == 1 { simple_attribute_audit_count(after_async, str_concat("transformer", ".nr")) } else { 0 };
        let v0861_ssm: i64 = if v0861_has_ssm == 1 { simple_attribute_audit_count(after_async, str_concat("nuc_", "ssm_")) } else { 0 };
        let v0861_total: i64 = v0861_tensor + v0861_transformer + v0861_ssm;
        if v0861_total > 0 {
            print(str_concat("info[ML-G2-3-5-6-10]: Tensor/ML/Autodiff rod surface in source: ", str_from_int(v0861_total)));
            print("  Tensor/ML/Autodiff caveats: tensor_nd is missing some higher-level typed shape surfaces; SSM rods have no backward / gradient paths, so autodiff via these is forward-only. Quantize lacks some grouped/FP8 surfaces. Transformer has no causal mask and no encoder-decoder path; only encoder-only attention is implemented. Adopter discipline today: verify each tensor/ML primitive exists before relying on it; check the rod source.");
        };
    };
    // v0.8.60 NUM-G2/8/9 Phase 1 — additional numeric-correctness
    // audit. Detects adopter use of math_abs (NUM-G2 i64::MIN
    // wrap), checked_* family (NUM-G8 thread-unsafe global flag),
    // @const_fn (NUM-G9 silently ignored). Phase 2b: panic-on-
    // saturate for math_abs, thread-local checked flag, real
    // comptime evaluation for @const_fn.
    let v0860_has_math_abs: i64 = if str_index_of(after_async, str_concat("math_", "abs(")) >= 0 { 1 } else { 0 };
    let v0860_has_checked: i64 = if str_index_of(after_async, str_concat("checked_", "")) >= 0 { 1 } else { 0 };
    let v0860_has_const_fn: i64 = if str_index_of(after_async, str_concat("@const_", "fn")) >= 0 { 1 } else { 0 };
    if v0860_has_math_abs == 1 || v0860_has_checked == 1 || v0860_has_const_fn == 1 {
        let v0860_math_abs: i64 = if v0860_has_math_abs == 1 { simple_attribute_audit_count(after_async, str_concat("math_", "abs(")) } else { 0 };
        let v0860_checked: i64 = if v0860_has_checked == 1 { simple_attribute_audit_count(after_async, str_concat("checked_", "")) } else { 0 };
        let v0860_const_fn: i64 = if v0860_has_const_fn == 1 { simple_attribute_audit_count(after_async, str_concat("@const_", "fn")) } else { 0 };
        let v0860_total: i64 = v0860_math_abs + v0860_checked + v0860_const_fn;
        if v0860_total > 0 {
            print(str_concat("info[NUM-G289]: numeric-correctness annotations / calls in source: ", str_from_int(v0860_total)));
            print("  Numeric-correctness caveats: math_abs(i64::MIN) returns i64::MIN in non-strict mode; checked_* uses a shared overflow flag and should not be treated as thread-safe; @const_fn is parsed but not yet a full compile-time evaluator. Future work: panic-on-saturate for math_abs, thread-local checked flags, and real comptime evaluation for @const_fn.");
        };
    };
    // v0.8.59 QM-7 / ROBO-7 Phase 1 — Tier C correctness audit-
    // pass info. Detects adopter use of the Clifford-stabilizer
    // rod (coverage still bounded; QM-7) and frame-typed
    // robotics rod. v0838 (ROBO-7 Phase B): the compiler-side
    // FRAME-001 frame-mismatch check at let-binding sites is now
    // live for `Pose<Frame_*>`-style phantom-tag annotations;
    // Frame_Unknown remains the documented migration sentinel.
    // Untagged kinematics surface (plain i64 handles, untagged
    // Pose) still bypasses the check by construction — adopter
    // opt-in via the typed annotation is the trigger.
    let v0859_has_clifford: i64 = if str_index_of(after_async, str_concat("clifford", ".nr")) >= 0 { 1 } else { 0 };
    let v0859_has_kinematics: i64 = if str_index_of(after_async, str_concat("kinematics", ".nr")) >= 0 { 1 } else { 0 };
    let v0859_has_frame: i64 = if str_index_of(after_async, str_concat("frame_", "tag")) >= 0 { 1 } else { 0 };
    if v0859_has_clifford == 1 || v0859_has_kinematics == 1 || v0859_has_frame == 1 {
        let v0859_clifford: i64 = if v0859_has_clifford == 1 { simple_attribute_audit_count(after_async, str_concat("clifford", ".nr")) } else { 0 };
        let v0859_kinematics: i64 = if v0859_has_kinematics == 1 { simple_attribute_audit_count(after_async, str_concat("kinematics", ".nr")) } else { 0 };
        let v0859_frame: i64 = if v0859_has_frame == 1 { simple_attribute_audit_count(after_async, str_concat("frame_", "tag")) } else { 0 };
        let v0859_total: i64 = v0859_clifford + v0859_kinematics + v0859_frame;
        if v0859_total > 0 {
            print(str_concat("info[QM-7-ROBO-7]: Tier C unvalidated-rod surface in source: ", str_from_int(v0859_total)));
            print("  Tier C correctness caveats: the Clifford-stabilizer rod has verify coverage for Bell/GHZ entanglement, gate identities, reset/rebuild, stabilizer-distance smoke tests, and Surface-17 smoke tests. Published weight-enumerator validation remains open until the rod exposes enumerator APIs. FRAME-001 phantom-tag mismatch checking is live for `Pose<Frame_*>` annotations; `Frame_Unknown` is the migration sentinel and untagged Pose handles bypass the check by construction. Prefer `Pose<Frame_X>`-tagged annotations over bare `Pose`.");
        };
    };
    // v0.8.58 LAW-1/2/3 Phase 1, refreshed after R14
    // `--check-laws` wiring. @law(...) is captured and reported;
    // the main compiler still does not attach it to AST/IR rewrite
    // metadata. The tools-suite test driver can generate bounded
    // integer checks for low-risk forms under `nuc test --check-laws`.
    let v0858_has_law: i64 = if str_index_of(after_async, str_concat("@law(", "")) >= 0 { 1 } else { 0 };
    if v0858_has_law == 1 {
        let v0858_count: i64 = simple_attribute_audit_count(after_async, str_concat("@law(", ""));
        if v0858_count > 0 {
            print(str_concat("info[LAW-G123]: `@law(...)` algebraic-law annotations in source: ", str_from_int(v0858_count)));
            print("  Algebraic-law caveats: @law(...) annotations are captured and reported, and `nuc test --check-laws` generates bounded integer checks for low-risk forms plus schema hard errors for deprecated aliases, unsupported forms, float/approximate modifiers, and unknown names. The IR-level rewrite pass remains gated and currently performs no broad rewrites. Use `nuc test --check-laws` for the shipped check surface.");
        };
    };
    // Algebraic-law optimizer rewrite eligibility audit.
    // The IR pass `opt_law_rewrite_block` remains a no-op (rewrites
    // do not yet fire). Phase 2-prep ships a build-time eligibility
    // gate that PROVES the proof discipline before any rewrite ever
    // runs: the optimizer can only be allowed to rewrite a law-
    // annotated fn after the user has run `nuc test --check-laws`
    // on this source, observed `test result: PASS`, and explicitly
    // opted in via two source attributes:
    //   `@audit(law_opt_required)`     — file declares it requires
    //                                    the law-rewrite audit
    //   `@audit(check_laws_passed)`    — user declares they have
    //                                    validated --check-laws PASS
    // Behaviour:
    //   - `@audit(law_opt_required)` absent → no-op (preserves
    //     pre-Phase 2-prep behaviour for every existing source).
    //   - `law_opt_required` present AND `check_laws_passed` present
    //     → emit info[LAW-AUDIT-GATE] eligibility report.
    //   - `law_opt_required` present, `check_laws_passed` missing
    //     → halt with error[LAW-003] before any IR is emitted.
    // This is the bounded slice the v0842 dispatch asked for: the
    // optimizer is moved one step closer to safe rewrite use without
    // enabling broad rewrites today. The actual `f(a, identity) → a`
    // rewrite is a Phase 2 ship that follows this gate. Float laws,
    // unbounded property generation, and broad rewrites are out of
    // scope for this Phase 2-prep slice and remain hard-blocked.
    let v0842_law_gate_source: str = strip_strings_and_line_comments(after_async);
    let v0842_law_opt_required: i64 = if str_index_of(v0842_law_gate_source, str_concat("@audit(", "law_opt_required")) >= 0 { 1 } else { 0 };
    if v0842_law_opt_required == 1 {
        let v0842_has_audit_pass: i64 = if str_index_of(v0842_law_gate_source, str_concat("@audit(", "check_laws_passed")) >= 0 { 1 } else { 0 };
        if v0842_has_audit_pass == 1 {
            let v0842_law_count_for_gate: i64 = if v0858_has_law == 1 { simple_attribute_audit_count(v0842_law_gate_source, str_concat("@law(", "")) } else { 0 };
            print(str_concat("info[LAW-AUDIT-GATE]: optimizer rewrite gate opted in (`@audit(law_opt_required)`) and proof-audit attribute present (`@audit(check_laws_passed)`); eligible @law annotations: ", str_from_int(v0842_law_count_for_gate)));
            print("  A source declaring `@audit(law_opt_required)` is asking the optimizer to use its law metadata for low-risk rewrites; the matching `@audit(check_laws_passed)` attribute declares the user has run `nuc test --check-laws` and observed PASS. Today the eligibility report fires; the IR-level rewrite pass remains a no-op, so no semantics change yet. Adopter discipline: never add `@audit(check_laws_passed)` without first running `--check-laws` and observing PASS.");
        } else {
            print("error[LAW-003]: source declares `@audit(law_opt_required)` but is missing `@audit(check_laws_passed)`; run `nuc test --check-laws`, observe PASS, then add the audit attribute before enabling the optimizer gate");
            panic("nucleor: LAW-003 optimizer rewrite gate without check-laws audit");
        };
    };
    // v0.8.57 PKG-5 Phase 1 — `@cfg(feature = "...")` gating
    // info. Today `[features]` sections in nucleor.toml parse +
    // store but no compiler path consumes them; `--features X`
    // to `nuc build` does not gate any code. Adopter using
    // @cfg(feature = "...") gets the body included regardless.
    // Phase 2b adds proper feature-gating in lower_fn.
    let v0857_has_cfg_feature: i64 = if str_index_of(after_async, str_concat("@cfg(", "feature")) >= 0 { 1 } else { 0 };
    if v0857_has_cfg_feature == 1 {
        let v0857_count: i64 = simple_attribute_audit_count(after_async, str_concat("@cfg(", "feature"));
        if v0857_count > 0 {
            print(str_concat("info[PKG-5]: `@cfg(feature = ...)` gates in source: ", str_from_int(v0857_count)));
            print("  Conditional compilation `@cfg(feature = \"X\")` is parsed but the gate is NOT honored — the body is always included regardless of the active features set. `--features hardware` to `nuc build` does not gate any code. Adopter discipline today: do NOT rely on @cfg(feature) for compile-time selection; use module-level imports or runtime checks.");
        };
    };
    // v0.8.54 RT Phase 1 — real-time/determinism partial-enforcement
    // info. Detects #[deadline], #[no_alloc], #[no_panic], #[isr]
    // annotations and warns adopters about known gaps in enforcement
    // (RT-G1 transitive callee, RT-G3 panic-check incomplete, RT-G5
    // deadline marketing-claim unbacked, RT-G6 no embedded sysroots).
    let v0854_has_deadline: i64 = if str_index_of(after_async, str_concat("#[dead", "line")) >= 0 { 1 } else { 0 };
    let v0854_has_no_alloc: i64 = if str_index_of(after_async, str_concat("#[no_", "alloc]")) >= 0 { 1 } else { 0 };
    let v0854_has_no_panic: i64 = if str_index_of(after_async, str_concat("#[no_", "panic]")) >= 0 { 1 } else { 0 };
    let v0854_has_isr: i64 = if str_index_of(after_async, str_concat("#[i", "sr]")) >= 0 { 1 } else { 0 };
    if v0854_has_deadline == 1 || v0854_has_no_alloc == 1 || v0854_has_no_panic == 1 || v0854_has_isr == 1 {
        let v0854_deadline: i64 = if v0854_has_deadline == 1 { simple_attribute_audit_count(after_async, str_concat("#[dead", "line")) } else { 0 };
        let v0854_no_alloc: i64 = if v0854_has_no_alloc == 1 { simple_attribute_audit_count(after_async, str_concat("#[no_", "alloc]")) } else { 0 };
        let v0854_no_panic: i64 = if v0854_has_no_panic == 1 { simple_attribute_audit_count(after_async, str_concat("#[no_", "panic]")) } else { 0 };
        let v0854_isr: i64 = if v0854_has_isr == 1 { simple_attribute_audit_count(after_async, str_concat("#[i", "sr]")) } else { 0 };
        let v0854_total: i64 = v0854_deadline + v0854_no_alloc + v0854_no_panic + v0854_isr;
        if v0854_total > 0 {
            print(str_concat("info[RT-G135]: real-time/determinism annotations in source: ", str_from_int(v0854_total)));
            print("  Real-time/determinism caveats: #[no_alloc] / #[no_panic] / #[isr] / #[deadline] annotations parse, but enforcement still has known false-negative surfaces. no_alloc/no_panic scan annotated bodies, tagged callees, and bounded same-file helper chains; closure escape, fn-pointer indirect calls, and deeper-than-bound paths still escape detection. #[deadline=N] installs runtime deadline context and loop polling, but RT-004 estimates remain heuristic rather than certified WCET. #[isr] runs on the host target. Do NOT rely on these annotations as complete compile-time hard guarantees.");
        };
    };
    // v0.8.50 C-1/C-2 Phase 1 — Linux concurrency surface info.
    // The concurrency.nr rod's cancel_token (C-1) and POSIX channel
    // (C-2) helpers are silently broken on Linux: cancel_token is a
    // linker bomb (extern fn declared, body absent), POSIX channel
    // is a no-op stub. Detect adopter use of the concurrency rod
    // or its functions and surface the Linux platform risk.
    let v0850_has_concurrency: i64 = if str_index_of(after_async, str_concat("concurrency", ".nr")) >= 0 { 1 } else { 0 };
    let v0850_has_cancel: i64 = if str_index_of(after_async, str_concat("cancel_", "token")) >= 0 { 1 } else { 0 };
    let v0850_has_channel: i64 = if str_index_of(after_async, str_concat("channel_", "send")) >= 0 { 1 } else { 0 };
    if v0850_has_concurrency == 1 || v0850_has_cancel == 1 || v0850_has_channel == 1 {
        let v0850_concurrency: i64 = if v0850_has_concurrency == 1 { simple_attribute_audit_count(after_async, str_concat("concurrency", ".nr")) } else { 0 };
        let v0850_cancel: i64 = if v0850_has_cancel == 1 { simple_attribute_audit_count(after_async, str_concat("cancel_", "token")) } else { 0 };
        let v0850_channel: i64 = if v0850_has_channel == 1 { simple_attribute_audit_count(after_async, str_concat("channel_", "send")) } else { 0 };
        let v0850_total: i64 = v0850_concurrency + v0850_cancel + v0850_channel;
        if v0850_total > 0 {
            print(str_concat("info[CONC-G12]: concurrency-rod surface in source: ", str_from_int(v0850_total)));
            print("  Concurrency caveats: cancel_token is not implemented on the POSIX runtime path, and POSIX channel helpers are incomplete. Programs using these on Linux can fail at link time or run with broken concurrency. Adopter discipline today: avoid these helpers if targeting Linux until the POSIX implementations are complete.");
        };
    };
    // v0.8.48 E-1/E-2/E-3 Phase 1 — effect/capability build-summary info.
    // v0.8.307/v0.8.309 later closed the direct `pure fn` build-path
    // no-signal class with EFF-001 for print/alloc/ambient capability use.
    // v0829/v0831 add bounded same-file pure-call checking for user helpers
    // whose bodies contain direct side effects, requires-row surfaces, and
    // builtin print-family I/O.
    // The remaining trust gap is the effect-row surface:
    // `requires [...]`, real block-form `restricts [...]` enforcement,
    // transitive requires-row propagation, and cross-module propagation
    // are not fully enforced by s1. Block-form `restricts [...] { ... }` now
    // fails closed with EFF-003 until that enforcement lands.
    // Phase 2b moves effect-row enforcement into the main build path.
    // Shared gate: skip if none of the three keywords are textually
    // present (most adopter code doesn't use these keywords).
    let v0848_has_pure: i64 = if str_index_of(after_async, str_concat("pure ", "fn ")) >= 0 { 1 } else { 0 };
    let v0848_has_requires_spaced: i64 = if str_index_of(after_async, str_concat("requires", " [")) >= 0 { 1 } else { 0 };
    let v0848_has_requires_compact: i64 = if str_index_of(after_async, str_concat("requires", "[")) >= 0 { 1 } else { 0 };
    let v0848_has_requires: i64 = if v0848_has_requires_spaced == 1 || v0848_has_requires_compact == 1 { 1 } else { 0 };
    let v0848_has_restricts_spaced: i64 = if str_index_of(after_async, str_concat("restricts", " [")) >= 0 { 1 } else { 0 };
    let v0848_has_restricts_compact: i64 = if str_index_of(after_async, str_concat("restricts", "[")) >= 0 { 1 } else { 0 };
    let v0848_has_restricts: i64 = if v0848_has_restricts_spaced == 1 || v0848_has_restricts_compact == 1 { 1 } else { 0 };
    if v0848_has_pure == 1 || v0848_has_requires == 1 || v0848_has_restricts == 1 {
        let v0848_pure_count: i64 = if v0848_has_pure == 1 { simple_attribute_audit_count(after_async, str_concat("pure ", "fn ")) } else { 0 };
        let v0848_requires_count: i64 = simple_attribute_audit_count(after_async, str_concat("requires", " [")) + simple_attribute_audit_count(after_async, str_concat("requires", "["));
        let v0848_restricts_count: i64 = simple_attribute_audit_count(after_async, str_concat("restricts", " [")) + simple_attribute_audit_count(after_async, str_concat("restricts", "["));
        let v0848_total: i64 = v0848_pure_count + v0848_requires_count + v0848_restricts_count;
        if v0848_total > 0 {
            print(str_concat("info[EFF-G123]: effect/capability annotations in source: ", str_from_int(v0848_total)));
            print("  Effect/capability caveats: direct `pure fn` side effects fail with EFF-001, and same-file pure calls plus bounded requires/restricts checks are enforced through known builtin effects and helper chains up to depth=8. Cross-module flat-namespace imports are handled through the resolved-source pre-pass. Remaining open surfaces include deeper chains, ambiguous same-name methods, closures and function-pointer effect capture, broader effect-row subtyping, and selective/glob import forms. Treat unvalidated rows as documentation until the broader effect-row enforcement lands.");
        };
    };
    // v0.8.46 T-3 Phase 1 — char-cast build-summary info. Counts
    // `as char` cast occurrences in source. Today, casting an int
    // to char silently accepts any value including out-of-range
    // codepoints (>0x10FFFF) and surrogate range (0xD800-0xDFFF),
    // producing invalid UTF-8 downstream. Phase 2b will add
    // codepoint validation at the cast site. Phase 4 promotes to
    // hard error for invalid codepoints.
    let v0846_has_as_char: i64 = if str_index_of(after_async, str_concat(" as ", "char")) >= 0 { 1 } else { 0 };
    if v0846_has_as_char == 1 {
        let v0846_count: i64 = simple_attribute_audit_count(after_async, str_concat(" as ", "char"));
        if v0846_count > 0 {
            print(str_concat("info[T-3-CAST]: `as char` casts in source: ", str_from_int(v0846_count)));
            print("  Type-system caveat: const-foldable `<int> as char` emits TYP-026 for invalid Unicode scalar values, and non-constant casts fail closed unless guarded by a recognized scalar-range proof in the same branch. The i64-everywhere char ABI remains open until broader char distinctness lands.");
        };
    };
    // NUM-G1 audit retired after reproduction testing. The original
    // gap-RFC claim ("f64 literals with >6 fractional digits silently
    // truncated") does NOT reproduce in v0.4.180. Probe confirmed
    // bit-identical-to-strtod values for 16-digit f64 literals.
    // The actual reproducible bug is int_part overflow at >= 1e13
    // (compile-time PANIC, not silent miscompute) — different
    // class, queued for separate Phase 1 audit. The previous
    // info[NUM-G1] would have wrong-class-flagged adopter code
    // that was actually correct. Audit and helper count_long_float_
    // literals retained for diagnostic purposes but not invoked.
    // v0.8.34 Q2 — slice-pattern diagnostic refinement.
    // Pre-existing behavior: slice match with rest element hit
    // parse_primary's token-58 panic and emitted the range-
    // expression diagnostic, wrong-class. Pre-detect the
    // textual shape (rest at slice-pattern closing bracket and
    // related sites — rare in prose) and halt cleanly.
    // Self-host safe: needles constructed via str_concat AND
    // the diagnostic message + comments avoid the literal
    // detected sequences (use spaced forms throughout).
    let v0834_has_dotdot_mid: i64 = if str_index_of(after_async, str_concat(", ..", ",")) >= 0 { 1 } else { 0 };
    let v0834_has_dotdot_close: i64 = if str_index_of(after_async, str_concat(", ..", "]")) >= 0 { 1 } else { 0 };
    let v0834_has_bracket_dotdot: i64 = if str_index_of(after_async, str_concat("[..", ",")) >= 0 { 1 } else { 0 };
    if v0834_has_dotdot_mid == 1 && v0834_has_dotdot_close == 1 {
        print("error[MATCH-009]: slice pattern contains more than one dot-dot rest marker");
        panic("nucleor: MATCH-009 slice pattern overlap");
    };
    if v0834_has_dotdot_mid == 1 || v0834_has_dotdot_close == 1 || v0834_has_bracket_dotdot == 1 {
        // Diagnostic message intentionally uses extra-spaced
        // form `[a , .. , b]` to avoid self-matching the
        // detector needles when this file gets self-host
        // compiled.
        print("ERROR: slice patterns with rest binding (the dot-dot rest element inside slice match brackets `[a , .. , b]`) are not yet supported in Nucleor. Workaround: rewrite as explicit indexing using vec_len + vec_get. Tracked for the full slice-pattern matcher with rest binding.");
        panic("nucleor: slice patterns with rest binding not yet supported (see ERROR diagnostic above)");
    };
    // RFC-0062 G-6 Phase 2a — Sendable-edge surface
    // info. Counts `HashMap<` and `RefCell<` / `Cell<` substrings.
    // Phase 2b will close the four unaudited cases per
    // Gated behind cheap
    // str_index_of pre-checks so adopter code with no
    // HashMap/Cell pays zero cost for this audit.
    let v0833_has_hm: i64 = if str_index_of(after_async, str_concat("HashMap", "<")) >= 0 { 1 } else { 0 };
    let v0833_has_cell: i64 = if str_index_of(after_async, str_concat("Cell", "<")) >= 0 { 1 } else { 0 };
    if v0833_has_hm == 1 || v0833_has_cell == 1 {
        let v0833_send_count: i64 = simple_attribute_audit_count(after_async, str_concat("HashMap", "<"))
                                  + simple_attribute_audit_count(after_async, str_concat("RefCell", "<"))
                                  + simple_attribute_audit_count(after_async, str_concat("Cell", "<"));
        if v0833_send_count > 0 {
            print(str_concat("warning[SEND-G6]: HashMap/Cell/RefCell types in build: ", str_from_int(v0833_send_count)));
            print("  Per RFC-0062 G-6 Phase 3 (v1.0): HashMap<K,V> Sendable propagation is not yet enforced — the v1.0 contract is Sendable iff K and V are Sendable AND hasher is Sendable. Cell<T> / RefCell<T> are explicit REJECTS for Sendable (interior mutability incompatible with cross-thread). spawn-call sites may silently accept these today — adopter discipline: avoid spawning with HashMap or Cell/RefCell in the spawned closure capture set. Closure capture-set audit is post-v1.0 hardening.");
        };
    };
    // RFC-0062 G-6 Phase 2a (closures) — `move |...|`
    // closure-capture surface info. Counts `move |` patterns
    // (the Rust syntax for explicit-capture closures). Phase 2b
    // will close the closure-capture-set Sendable check (closure
    // is Sendable iff every captured variable is Sendable).
    // Gated behind cheap str_index_of pre-check.
    let v0836_has_move_closure: i64 = if str_index_of(after_async, str_concat("move ", "|")) >= 0 { 1 } else { 0 };
    if v0836_has_move_closure == 1 {
        let v0836_move_count: i64 = simple_attribute_audit_count(after_async, str_concat("move ", "|"));
        if v0836_move_count > 0 {
            print(str_concat("warning[SEND-G6-CLOSURE]: `move |...|` capture closures in build: ", str_from_int(v0836_move_count)));
            print("  Per RFC-0062 G-6 Phase 3 (v1.0, closures): Rust-style explicit-capture closures (`move |args| body`) capture variables from the enclosing scope. The closure is Sendable iff every captured variable is Sendable. spawn-call sites may silently accept closures with non-Sendable captures today. Adopter discipline: at spawn boundaries, prefer concrete types in capture set (`Vec<i64>` over `Vec<T>`, no HashMap/Cell). Per-closure capture-set audit is post-v1.0 hardening.");
        };
    };
    // v1.0 RFC-0062 G-7 Phase 3 — `unsafe { }` block audit. The
    // OSS compiler self-host source contains zero unsafe blocks;
    // adopter code introducing unsafe blocks gets surfaced here
    // so reviewers can audit the surface. Phase 3 is a warning
    // (not an error) — unsafe is a legitimate language feature.
    // Phase 4 promotion (post-v1.0): require `#[allow(unsafe)]`
    // attribute on the enclosing fn.
    let v1000_unsafe_count: i64 = simple_attribute_audit_count(after_async, str_concat("unsafe ", "{"));
    if v1000_unsafe_count > 0 {
        print(str_concat("warning[UNSAFE-G7]: `unsafe { }` blocks in build: ", str_from_int(v1000_unsafe_count)));
        print("  Per RFC-0062 G-7 Phase 3 (v1.0): the OSS compiler self-host source contains zero unsafe blocks; any unsafe block in adopter code is a manual-audit surface. Each unsafe block bypasses borrow-checking, lifetime-tracking, and bounds-check insertion within its body. Adopter discipline: justify each unsafe block in a comment naming the invariant being preserved. `#[allow(unsafe)]` attribute enforcement is post-v1.0 hardening. Reference: RFC-0003 §unsafe blocks.");
    };
    // v0.8.38 G-1 Phase 2b-3 — env-gated default-flip status
    // diagnostic. Reads NUC_AUTO_DROP_DEFAULT env var. When set
    // to "1", the compiler treats auto-drop as enabled by
    // default for all fns. Adopters can opt in to test the
    // future Phase 2b-3 semantics. Default-off remains opt-in
    // via #[auto_drop].
    let v0838_flip_state: str = env_get_or(str_concat("NUC_AUTO_DROP", "_DEFAULT"), "0");
    if str_eq(v0838_flip_state, "1") == 1 {
        print("info[FLIP-G1]: NUC_AUTO_DROP_DEFAULT=1 — Phase 2b-3 default-flip ENABLED for this build.");
        print("  Per RFC-0062 G-1 Phase 2b-3 experiment: every fn auto-drops local Vec / HashMap / Box / String / VecDeque unless `#[manual_drop]` opt-out is present. Adopter discipline: this is an experimental flip mode for validating code against the future default. Remove the env var or set it to anything other than \"1\" to revert to v0.x opt-in semantics.");
        // v0.8.73 G-3 Phase 2b — strong warning when flip is on
        // and source contains handoff patterns. Catches the gap
        // identified in v0.8.71 testing: vec_push(<param>, local)
        // patterns that auto-drop would dangle.
        let v0873_vec_push_count: i64 = if str_index_of(after_async, str_concat("vec_", "push(")) >= 0 {
            simple_attribute_audit_count(after_async, str_concat("vec_", "push("))
        } else { 0 };
        let v0873_vec_set_count: i64 = if str_index_of(after_async, str_concat("vec_", "set(")) >= 0 {
            simple_attribute_audit_count(after_async, str_concat("vec_", "set("))
        } else { 0 };
        let v0873_handoff_total: i64 = v0873_vec_push_count + v0873_vec_set_count;
        if v0873_handoff_total > 0 {
            print(str_concat("warning[G3-OWNERSHIP-RISK]: vec_push / vec_set call sites in build: ", str_from_int(v0873_handoff_total)));
            print("  Under default-flip (NUC_AUTO_DROP_DEFAULT=1), local Vec values transferred via `vec_push(<receiver>, local)` or `vec_set(<receiver>, idx, local)` can be auto-dropped at fn exit, leaving the receiver with a dangling pointer. Adopter discipline today: any fn whose body contains `vec_push(<param-name>, <local-vec>)` should carry `#[manual_drop]` to suppress auto-drop on the local. Future dataflow transfer detection will automate this; until then, treat every vec_push call site as a manual review point.");
        };
    };
    // RFC-0062 G-1 Phase 2b-1 — `#[manual_drop]`
    // reserved-attribute audit. Detects adopter use of the
    // future opt-out attribute. Today the attribute is a NO-OP;
    // Phase 2b-3 (default-flip) will make it the explicit
    // opt-out from the default-on auto-drop pipeline. Adopters
    // can pre-mark code now to avoid behavior surprise at the
    // flip ship. Diagnostic is info-level (heads-up only).
    let v0831_manual_drop_count: i64 = simple_attribute_audit_count(after_async,
        str_concat("#[manual_", "drop]"));
    if v0831_manual_drop_count > 0 {
        print(str_concat("info[MANUAL-DROP-RESERVED]: `#[manual_drop]` markers in build: ", str_from_int(v0831_manual_drop_count)));
        print(str_concat("  `#[manual_drop]` is reserved for the default-on auto-drop mode. Today the attribute is a NO-OP — every fn still requires explicit `#[auto_", "drop]` to receive auto-drop semantics. After the default flip, `#[manual_drop]` becomes the opt-out for fns that need to skip auto-drop (e.g. fns that already do all-explicit `vec_free` / `hashmap_free` and want zero generated cleanup). Adopters can add the attribute today to lock semantics across the upcoming flip."));
    };
    // RFC-0062 G-8 Phase 2a — conditional-divergence
    // build-summary info. Counts `match ` keyword occurrences as a
    // coarse proxy for control-flow-with-potential-cond-
    // divergence. Phase 2b will add per-fn move-state join
    // analysis at if/else and match arms. Phase 4 promotes to
    // deny-by-default for arms with mixed move/borrow patterns.
    let v0828_match_count: i64 = simple_attribute_audit_count(after_async,
        str_concat("match ", ""));
    if v0828_match_count > 0 {
        print(str_concat("info[CFG-G8]: match expressions in build: ", str_from_int(v0828_match_count)));
        print("  Per RFC-0062 G-8 Phase 2a: match arms (and if/else expressions) can have arms that diverge in move/borrow behavior — one arm consumes a value, another borrows it. The move tracker today is conservative on simple cases but doesn't fully reason about arm-level divergence. Phase 2b adds move-state join analysis at every control-flow join point; Phase 4 promotes mixed-arm patterns to deny-by-default with `#[allow(divergent_move)]` opt-out. Adopter discipline today: keep arm-level move/borrow behavior consistent (all arms borrow, or all arms consume).");
    };
    };
    // T3.1: wrap `#[deadline = N]` fns with start-capture
    // + `deadline_check` exit hook. Aborts on overrun (RT-004).
    let after_deadline: str = expand_deadline(after_async);
    let has_md: i64 = source_has_max_depth_attr_line(after_deadline);
    let mut after_max_depth: str = after_deadline;
    if has_md == 1 { after_max_depth = expand_max_depth(after_deadline); };
    // T2.3 (v0.2.349): expand closure literals `|args| body` in
    // argument position. Synthesizes top-level fns at the head of
    // the source; replaces the closure expression with the synth fn
    // name so downstream parsing sees a normal identifier reference.
    // generate `<Name>__derived_eq(a, b) -> i64`
    // helpers for `#[derive(...PartialEq...)] struct Name { ... }`.
    // Conservative scope: skips generic structs, where-clauses, and
    // unit/empty structs. Auto-dispatch of `==`/`!=` to the generated
    // helpers is deferred to a follow-on V1.4 ship (needs lower_expr
    // binop kind-4 routing).
    let after_derive_eq: str = expand_derive_partialeq(after_max_depth);
    let after_derive_clone: str = expand_derive_clone(after_derive_eq);
    let source: str = expand_actor_decl_keyword(expand_closures(after_derive_clone));
    if use_cache == 1 && is_compiler_src == 0 {
        // Use the cross-platform builtin instead of `mkdir ... 2>NUL`,
        // which on Linux silently creates a literal file named `NUL`.
        fs_create_dir_all(".nuc_cache");
        file_write_string(manifest_path, module_records_serialize(module_records));
        file_write_string(source_path, source);
        if has_md == 1 { file_write_string(max_depth_path, expand_actor_decl_keyword(after_deadline)); }
        else { file_write_string(max_depth_path, ""); };
    };
    out.push(source);
    out.push(imported);
    out.push(0);
    if has_md == 1 { out.push(after_deadline); };
    return out;
}

#[manual_drop]
fn extract_directives(raw_source: str, base_dir: str) -> Vec<i32> {
    // Returns vec: [0] = link flags string, [1] = cfile list string, [2] = libpath flags string
    let mut links: i64 = sb_new();
    let mut cfiles: i64 = sb_new();
    let mut libpaths: i64 = sb_new();
    let slen: i64 = str_len(raw_source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw_source, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(raw_source, lp) == 32 || str_char_at(raw_source, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = eol - lp;
        if line_len >= 6 && str_char_at(raw_source, lp) == 35 {
            if line_len >= 15 && str_eq_at(raw_source, lp, "#link_windows ") == 1 {
                // Windows-only system library
                // dependency. Emitted only when targeting Windows so
                // POSIX hosts don't try to resolve -lws2_32 etc.
                let mut qp: i64 = lp + 14;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    if host_is_windows() == 1 {
                        sb_append(links, " -l"); sb_append(links, str_substring(raw_source, ps, pe));
                    };
                };
            } else if line_len >= 13 && str_eq_at(raw_source, lp, "#link_posix ") == 1 {
                // POSIX-only system library
                // dependency. Symmetric counterpart to #link_windows.
                let mut qp: i64 = lp + 12;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    if host_is_windows() == 0 {
                        sb_append(links, " -l"); sb_append(links, str_substring(raw_source, ps, pe));
                    };
                };
            } else if line_len >= 7 && str_eq_at(raw_source, lp, "#link ") == 1 {
                let mut qp: i64 = lp + 6;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    sb_append(links, " -l"); sb_append(links, str_substring(raw_source, ps, pe));
                };
            } else if line_len >= 8 && str_eq_at(raw_source, lp, "#cfile ") == 1 {
                let mut qp: i64 = lp + 7;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    let cf_path: str = str_substring(raw_source, ps, pe);
                    let cflen: i64 = str_len(cf_path);
                    let mut cf_abs: i64 = 0;
                    if cflen >= 1 && str_char_at(cf_path, 0) == 47 { cf_abs = 1; };
                    if cflen >= 2 && str_char_at(cf_path, 1) == 58 { cf_abs = 1; };
                    sb_append(cfiles, " ");
                    if cf_abs == 1 { sb_append(cfiles, cf_path); }
                    else { sb_append(cfiles, str_concat(base_dir, cf_path)); };
                };
            } else if line_len >= 10 && str_eq_at(raw_source, lp, "#libpath ") == 1 {
                let mut qp: i64 = lp + 9;
                while qp < eol && str_char_at(raw_source, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(raw_source, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(raw_source, pe) != 34 { pe = pe + 1; };
                    sb_append(libpaths, " -L"); sb_append(libpaths, str_concat(base_dir, str_substring(raw_source, ps, pe)));
                };
            };
        };
        p = eol + 1;
    };
    let mut result: Vec<i32> = Vec::new();
    result.push(sb_to_str(links));
    result.push(sb_to_str(cfiles));
    result.push(sb_to_str(libpaths));
    return result;
}

