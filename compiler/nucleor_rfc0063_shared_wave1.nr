// RFC-0063 Wave 1 shared helpers.
// Imported by both compiler entrypoints to retire byte-identical local duplicates.




















































#[manual_drop]
fn expand_async_syntax(src: str) -> str {
    return expand_async_await(expand_async_strip_keyword(src));
}
















































#[manual_drop]
fn strip_ext(path: str) -> str {
    let slen: i64 = str_len(path);
    let mut last_dot: i64 = 0 - 1;
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(path, i);
        if c == 46 { last_dot = i; };
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_dot > last_sep + 1 { return str_substring(path, 0, last_dot); };
    return path;
}

#[manual_drop]
fn basename(path: str) -> str {
    let slen: i64 = str_len(path);
    let mut last_sep: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(path, i);
        if c == 47 || c == 92 { last_sep = i; };
        i = i + 1;
    };
    if last_sep >= 0 { return str_substring(path, last_sep + 1, slen); };
    return path;
}

#[manual_drop]
fn is_output_name_char(ch: i64) -> i64 {
    if is_alnum(ch) == 1 || ch == 95 || ch == 45 { return 1; };
    return 0;
}

#[manual_drop]
fn normalize_output_name(raw: str) -> str {
    let base: str = strip_ext(basename(raw));
    let blen: i64 = str_len(base);
    if blen == 0 { return ""; };
    let mut i: i64 = 0;
    while i < blen {
        if is_output_name_char(str_char_at(base, i)) == 0 { return ""; };
        i = i + 1;
    };
    return sanitize(base);
}








































































#[manual_drop]
fn fmt_trim_ws(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut start: i64 = 0;
    let mut start_done: i64 = 0;
    while start < slen && start_done == 0 {
        let c: i64 = str_char_at(s, start);
        if c == 32 || c == 9 || c == 10 || c == 13 { start = start + 1; }
        else { start_done = 1; };
    };
    let mut end: i64 = slen;
    let mut end_done: i64 = 0;
    while end > start && end_done == 0 {
        let c: i64 = str_char_at(s, end - 1);
        if c == 32 || c == 9 || c == 10 || c == 13 { end = end - 1; }
        else { end_done = 1; };
    };
    return str_substring(s, start, end);
}

#[manual_drop]
fn fmt_strip_outer_quotes(s: str) -> str {
    let slen: i64 = str_len(s);
    if slen < 2 { return s; };
    if str_char_at(s, 0) != 34 { return s; };
    if str_char_at(s, slen - 1) != 34 { return s; };
    return str_substring(s, 1, slen - 1);
}

#[manual_drop]
fn priv_string_vec_contains(v: Vec<i32>, s: str) -> i64 {
    let n: i64 = vec_len(v);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(v, i), s) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn priv_string_vec_push_unique(v: Vec<i32>, s: str) -> i64 {
    if priv_string_vec_contains(v, s) == 0 { v.push(s); };
    return 0;
}

#[manual_drop]
fn priv_lookup_origin(reg: Vec<i32>, name: str) -> str {
    let n: i64 = vec_len(reg);
    let mut i: i64 = 0;
    while i + 1 < n {
        if str_eq(vec_get(reg, i), name) == 1 { return vec_get(reg, i + 1); };
        i = i + 2;
    };
    return "";
}

#[manual_drop]
fn content_hash(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut hash: i64 = 5381;
    let mut i: i64 = 0;
    while i < slen {
        hash = hash * 33 + str_char_at(s, i);
        hash = hash - (hash / 4294967296) * 4294967296;
        i = i + 1;
    };
    let mut result: str = "";
    let mut val: i64 = hash;
    if val < 0 { val = 0 - val; };
    let hex_chars: str = "0123456789abcdef";
    let mut hi: i64 = 0;
    while hi < 8 {
        let digit: i64 = val - (val / 16) * 16;
        result = str_concat(str_substring(hex_chars, digit, digit + 1), result);
        val = val / 16;
        hi = hi + 1;
    };
    return result;
}

#[manual_drop]
fn compiler_backend_label() -> str {
    return "llvm";
}

#[manual_drop]
fn compiler_identity() -> str {
    return str_concat("nucleor ", str_concat(compiler_version_label(), str_concat(" (self-hosted, ", str_concat(compiler_backend_label(), " backend)"))));
}

#[manual_drop]
fn cli_is_flag(arg: str) -> i64 {
    if str_len(arg) > 0 && str_char_at(arg, 0) == 45 { return 1; };
    return 0;
}

#[manual_drop]
fn run_zen_command() -> i64 {
    print("The Zen of Nucleor");
    print("");
    print("Units are not optional. Ask the Mars Climate Orbiter.");
    print("Effects are declared, not discovered in production.");
    print("If it compiles, the dimensions are correct.");
    print("Governance is not overhead. Governance is the product.");
    print("Unsafe is a confession, not a feature.");
    print("Trust is earned per-session, not granted per-binary.");
    print("The audit trail is the only history that matters.");
    print("Memory is borrowed. Responsibility is owned.");
    print("A taint you can see is a taint you can fix.");
    print("Correctness is faster than debugging.");
    print("Criticality is not an accident. It is a design choice.");
    print("Know your k-effective.");
    return 0;
}

#[manual_drop]
fn run_mco_command() -> i64 {
    print("  +-----------------------------------------+");
    print("  |  Mars Climate Orbiter - September 1999  |");
    print("  |                                         |");
    print("  |  Lockheed Martin: pound-force-seconds   |");
    print("  |  NASA JPL:        newton-seconds        |");
    print("  |                                         |");
    print("  |  Cost: $327,600,000                     |");
    print("  |  Root cause: unit mismatch              |");
    print("  |  Nucleor status: PREVENTED AT COMPILE   |");
    print("  |                                         |");
    print("  |  \"This is why we exist.\"                |");
    print("  +-----------------------------------------+");
    return 0;
}




























#[manual_drop]
fn expand_format_macros(src: str) -> str {
    return expand_format_macros_with_src(src, src);
}

#[manual_drop]
fn priv_apply_if_opted_in(isrc: str, path: str) -> str {
    let private_names: Vec<i32> = priv_collect_private_fn_names(isrc);
    if vec_len(private_names) == 0 { return isrc; };
    let file_id: str = content_hash(path);
    return priv_mangle_private_fns(isrc, file_id, private_names);
}





#[manual_drop]
fn fmt_build_concat_chain(segments: Vec<i32>, parities: Vec<i32>) -> str {
    let nseg: i64 = vec_len(segments);
    if nseg == 0 { return "\"\""; };
    let mut chain: str = "";
    let mut k: i64 = nseg - 1;
    while k >= 0 {
        let part: str = vec_get(segments, k);
        let parity: i64 = vec_get(parities, k);
        let part_text: str = if parity == 0 {
            str_concat("\"", str_concat(part, "\""))
        } else { part };
        if str_len(chain) == 0 { chain = part_text; }
        else { chain = str_concat("str_concat(", str_concat(part_text, str_concat(", ", str_concat(chain, ")")))); };
        k = k - 1;
    };
    return chain;
}


#[manual_drop]
fn priv_build_global_registry(imported: Vec<i32>) -> Vec<i32> {
    // T1.5d (v0.2.343): synced from nucleor_s1_compiler.nr.
    let mut reg: Vec<i32> = Vec::new();
    let n: i64 = vec_len(imported);
    let mut i: i64 = 0;
    while i < n {
        let path: str = vec_get(imported, i);
        let isrc: str = file_read_string(path);
        if str_len(isrc) > 0 {
            let priv_names: Vec<i32> = priv_collect_private_fn_names(isrc);
            let m: i64 = vec_len(priv_names);
            let mut j: i64 = 0;
            while j < m {
                reg.push(vec_get(priv_names, j));
                reg.push(path);
                j = j + 1;
            };
        };
        i = i + 1;
    };
    return reg;
}

#[manual_drop]
fn priv_extract_fn_decl_info(line: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push("");
    out.push(0);
    let compact: str = strip_spaces(line);
    let clen: i64 = str_len(compact);
    let mut start: i64 = 0 - 1;
    let mut is_pub: i64 = 0;
    if clen >= 9 && str_eq(str_substring(compact, 0, 9), "pubpurefn") == 1 { start = 9; is_pub = 1; }
    else if clen >= 5 && str_eq(str_substring(compact, 0, 5), "pubfn") == 1 { start = 5; is_pub = 1; }
    else if clen >= 6 && str_eq(str_substring(compact, 0, 6), "purefn") == 1 { start = 6; is_pub = 0; }
    else if clen >= 2 && str_eq(str_substring(compact, 0, 2), "fn") == 1 { start = 2; is_pub = 0; };
    if start < 0 { return out; };
    if start >= clen { return out; };
    let mut stop: i64 = start;
    let mut done: i64 = 0;
    while stop < clen && done == 0 {
        let ch: i64 = str_char_at(compact, stop);
        if is_alnum(ch) == 1 || ch == 95 { stop = stop + 1; }
        else { done = 1; };
    };
    if stop <= start { return out; };
    if stop >= clen || str_char_at(compact, stop) != 40 { return out; };
    vec_set(out, 0, str_substring(compact, start, stop));
    vec_set(out, 1, is_pub);
    return out;
}

#[manual_drop]
fn close_parse_body_end(src: str, start: i64, slen: i64) -> i64 {
    let mut p: i64 = start;
    let mut depth: i64 = 0;
    let mut in_dq: i64 = 0;
    let mut in_sq: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if in_dq == 1 {
            if c == 92 && p + 1 < slen { p = p + 2; }
            else if c == 34 { in_dq = 0; p = p + 1; }
            else { p = p + 1; };
        } else if in_sq == 1 {
            if c == 92 && p + 1 < slen { p = p + 2; }
            else if c == 39 { in_sq = 0; p = p + 1; }
            else { p = p + 1; };
        } else if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        } else if c == 34 { in_dq = 1; p = p + 1; }
        else if c == 39 { in_sq = 1; p = p + 1; }
        else if c == 40 || c == 91 || c == 123 { depth = depth + 1; p = p + 1; }
        else if c == 41 || c == 93 || c == 125 {
            if depth == 0 { return p; };
            depth = depth - 1;
            p = p + 1;
        } else if c == 44 && depth == 0 { return p; }
        else { p = p + 1; };
    };
    return p;
}


#[manual_drop]
fn fmt_split_args(args_text: str) -> Vec<i32> {
    let mut parts: Vec<i32> = Vec::new();
    let slen: i64 = str_len(args_text);
    let mut start: i64 = 0;
    let mut p: i64 = 0;
    let mut depth: i64 = 0;
    let mut in_dq: i64 = 0;
    let mut in_sq: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(args_text, p);
        if in_dq == 1 {
            if c == 92 && p + 1 < slen { p = p + 1; }
            else if c == 34 { in_dq = 0; };
        } else if in_sq == 1 {
            if c == 92 && p + 1 < slen { p = p + 1; }
            else if c == 39 { in_sq = 0; };
        } else if c == 34 { in_dq = 1; }
        else if c == 39 { in_sq = 1; }
        else if c == 40 || c == 91 || c == 123 { depth = depth + 1; }
        else if c == 41 || c == 93 || c == 125 { depth = depth - 1; }
        else if c == 44 && depth == 0 {
            let part: str = fmt_trim_ws(str_substring(args_text, start, p));
            if str_len(part) > 0 { parts.push(part); };
            start = p + 1;
        };
        p = p + 1;
    };
    let tail: str = fmt_trim_ws(str_substring(args_text, start, slen));
    if str_len(tail) > 0 { parts.push(tail); };
    return parts;
}

#[manual_drop]
fn priv_collect_private_fn_names(source: str) -> Vec<i32> {
    let slen: i64 = str_len(source);
    let mut pub_names: Vec<i32> = Vec::new();
    let mut all_names: Vec<i32> = Vec::new();
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let info: Vec<i32> = priv_extract_fn_decl_info(line);
        let name: str = vec_get(info, 0);
        if str_len(name) > 0 {
            let is_pub: i64 = vec_get(info, 1);
            if is_pub == 1 { priv_string_vec_push_unique(pub_names, name); };
            priv_string_vec_push_unique(all_names, name);
        };
        p = eol + 1;
    };
    let mut result: Vec<i32> = Vec::new();
    if vec_len(pub_names) == 0 { return result; };
    let n: i64 = vec_len(all_names);
    let mut i: i64 = 0;
    while i < n {
        let nm: str = vec_get(all_names, i);
        if priv_string_vec_contains(pub_names, nm) == 0 {
            if str_eq(nm, "main") == 0 { result.push(nm); };
        };
        i = i + 1;
    };
    return result;
}

#[manual_drop]
fn priv_lift_link_errors(clang_output: str, reg: Vec<i32>) -> i64 {
    let needle: str = "use of undefined value '@";
    let nlen: i64 = str_len(needle);
    let slen: i64 = str_len(clang_output);
    let mut p: i64 = 0;
    let mut count: i64 = 0;
    let mut seen: Vec<i32> = Vec::new();
    while p + nlen <= slen {
        let mut matched: i64 = 1;
        let mut k: i64 = 0;
        while k < nlen && matched == 1 {
            if str_char_at(clang_output, p + k) != str_char_at(needle, k) { matched = 0; };
            k = k + 1;
        };
        if matched == 1 {
            let name_start: i64 = p + nlen;
            let mut name_end: i64 = name_start;
            while name_end < slen && str_char_at(clang_output, name_end) != 39 { name_end = name_end + 1; };
            let name: str = str_substring(clang_output, name_start, name_end);
            let origin: str = priv_lookup_origin(reg, name);
            if str_len(origin) > 0 && priv_string_vec_contains(seen, name) == 0 {
                seen.push(name);
                print(str_concat("error[MOD-003]: cannot call private fn '", str_concat(name, "' from outside its declaring module")));
                print(str_concat("  --> declared in: ", origin));
                print("  hint: add `pub` to the fn declaration to expose it cross-module");
                count = count + 1;
            };
            p = name_end + 1;
        } else {
            p = p + 1;
        };
    };
    return count;
}


#[manual_drop]
fn close_parse_arg_list(src: str, start: i64, slen: i64) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push(0 - 1);
    let mut p: i64 = start;
    let mut first: i64 = 1;
    while p < slen && str_char_at(src, p) != 124 {
        while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
        if p < slen && str_char_at(src, p) == 124 { p = p; }
        else if first == 0 {
            if p < slen && str_char_at(src, p) == 44 {
                p = p + 1;
                while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
            } else {
                return out;
            };
        };
        if p < slen && (is_alpha(str_char_at(src, p)) == 1 || str_char_at(src, p) == 95) {
            let name_start: i64 = p;
            let mut name_done: i64 = 0;
            while p < slen && name_done == 0 {
                let cc: i64 = str_char_at(src, p);
                if is_alnum(cc) == 1 || cc == 95 { p = p + 1; }
                else { name_done = 1; };
            };
            out.push(str_substring(src, name_start, p));
            first = 0;
            while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
            if p < slen && str_char_at(src, p) == 58 {
                p = p + 1;
                while p < slen && str_char_at(src, p) != 44 && str_char_at(src, p) != 124 { p = p + 1; };
            };
        } else if p >= slen || str_char_at(src, p) != 124 {
            return out;
        };
    };
    if p >= slen || str_char_at(src, p) != 124 { return out; };
    vec_set(out, 0, p + 1);
    return out;
}

#[manual_drop]
fn expand_async_await(src: str) -> str {
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            let comment_start: i64 = p;
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
            sb_append_range(sb, src, comment_start, p);
        } else if c == 34 {
            let str_start: i64 = p;
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    p = p + 2;
                } else {
                    p = p + 1;
                };
            };
            if p < slen { p = p + 1; };
            sb_append_range(sb, src, str_start, p);
        } else if is_alpha(c) == 1 || c == 95 {
            let id_start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            if p + 6 <= slen && str_eq_at(src, p, ".await") == 1 {
                let after: i64 = p + 6;
                let after_ch: i64 = if after < slen { str_char_at(src, after) } else { 0 };
                let is_ident_cont: i64 = if is_alnum(after_ch) == 1 || after_ch == 95 { 1 } else { 0 };
                if is_ident_cont == 0 {
                    sb_append(sb, "async_await(");
                    sb_append_range(sb, src, id_start, p);
                    sb_append(sb, ")");
                    p = p + 6;
                } else {
                    sb_append_range(sb, src, id_start, p);
                };
            } else {
                sb_append_range(sb, src, id_start, p);
            };
        } else {
            sb_append_char_at(sb, src, p);
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}


// RFC-0063 Wave 10 shared IDENTICAL helper batch.











fn tok_int_suffix_code_at(tokens: Vec<i32>, idx: i64) -> i64 { return tok_int_suffix_code(tok_at(tokens, idx)); }













fn close_synthesize_fn(name: str, args: Vec<i32>, body_text: str) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "fn ");
    sb_append(sb, name);
    sb_append(sb, "(");
    let na: i64 = vec_len(args);
    let mut i: i64 = 0;
    while i < na {
        if i > 0 { sb_append(sb, ", "); };
        sb_append(sb, vec_get(args, i));
        sb_append(sb, ": i64");
        i = i + 1;
    };
    sb_append(sb, ") -> i64 {\n    return ");
    sb_append(sb, body_text);
    sb_append(sb, ";\n}\n\n");
    return sb_to_str(sb);
}

// RFC-0063 Wave 11 shared SIG_MATCH_BODY_DIFFERS reviewed batch.













// =================================================================
// RFC-0063 Wave 12-16: 30 IDENTICAL fns retired from
// nucleor_tools_suite.nr local copies; shared via this module.
// Mechanical
// safe-delete batch. Each fn was byte-identical between s1 and
// tools_suite per tools/audit_dup_fns_report.csv (category
// IDENTICAL). s1 retains its canonical local copies; tools_suite
// loses its locals and gets them via import.
// =================================================================






























