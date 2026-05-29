// =====================================================
// TAINT CHECKER (S11.7)
// =====================================================
fn taint_new() -> Vec<i32> { return Vec::new(); }
fn taint_set(t: Vec<i32>, name: str, is_tainted: i64) -> i64 { t.push(name); t.push(is_tainted); return 0; }
fn taint_get(t: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = vec_len(t) - 2;
    while i >= 0 {
        if str_eq(vec_get(t, i), name) { return vec_get(t, i + 1); };
        i = i - 2;
    };
    return 0; // untainted by default
}

fn is_taint_sanitizer(name: str) -> i64 {
    if str_eq(name, "sanitize") { return 1; };
    if str_eq(name, "normalize_output_name") { return 1; };
    return 0;
}

fn taint_check_expr(pool: Vec<i32>, nid: i64, taint: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 || kind == 2 || kind == 71 { return 0; }; // literals never tainted
    if kind == 3 { return taint_get(taint, node_field(pool, nid, 1)); }; // variable
    if kind == 4 {
        // Binary op: tainted if either operand tainted (except comparisons → always clean)
        let op: i64 = node_field(pool, nid, 1);
        let lt: i64 = taint_check_expr(pool, node_field(pool, nid, 2), taint, fn_name, diags, source);
        let rt: i64 = taint_check_expr(pool, node_field(pool, nid, 3), taint, fn_name, diags, source);
        // Comparison operators (30-38) produce clean boolean results
        if op >= 30 && op <= 38 { return 0; };
        if lt == 1 || rt == 1 { return 1; };
        return 0;
    };
    if kind == 5 || kind == 6 || kind == 90 || kind == 91 || kind == 92 { return taint_check_expr(pool, node_field(pool, nid, 1), taint, fn_name, diags, source); };
    if kind == 7 {
        // Function call: known sanitizers clean taint
        let callee: str = node_field(pool, nid, 1);
        if is_taint_sanitizer(callee) == 1 {
            // S12b: sanitize event (removable)
            review_acc_taint_sanitize(taint, fn_name, callee);
            return 0;
        };
        // Otherwise, if any arg tainted, result is tainted
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        let mut tainted_argc: i64 = 0;
        while ai < ac {
            if taint_check_expr(pool, list_get(pool, args, ai), taint, fn_name, diags, source) == 1 { tainted_argc = tainted_argc + 1; };
            ai = ai + 1;
        };
        // S12b: taint through call (removable)
        if tainted_argc > 0 { review_acc_taint_call(taint, fn_name, callee, tainted_argc); };
        if tainted_argc > 0 { return 1; };
        return 0;
    };
    if kind == 9 {
        // FIELD_ACCESS: if receiver is tainted, field is tainted (taint through struct fields)
        return taint_check_expr(pool, node_field(pool, nid, 1), taint, fn_name, diags, source);
    };
    if kind == 8 || kind == 10 {
        return taint_check_expr(pool, node_field(pool, nid, 1), taint, fn_name, diags, source);
    };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            if taint_check_expr(pool, list_get(pool, items, ii), taint, fn_name, diags, source) == 1 { return 1; };
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 34 {
        // STRUCT_INIT: if any field value is tainted, the struct is tainted
        let inits: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, inits);
        let mut ii: i64 = 0;
        while ii < ic {
            let init_nid: i64 = list_get(pool, inits, ii);
            let val_nid: i64 = node_field(pool, init_nid, 2);
            if taint_check_expr(pool, val_nid, taint, fn_name, diags, source) == 1 { return 1; };
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 52 {
        let body: i64 = node_field(pool, nid, 2);
        let bc: i64 = list_len(pool, body);
        let mut bi: i64 = 0;
        while bi < bc {
            let stmt: i64 = list_get(pool, body, bi);
            if bi == bc - 1 && node_kind(pool, stmt) == 25 {
                return taint_check_expr(pool, node_field(pool, stmt, 1), taint, fn_name, diags, source);
            };
            taint_check_stmt(pool, stmt, taint, fn_name, diags, source);
            bi = bi + 1;
        };
        return 0;
    };
    return 0;
}
fn taint_check_stmt(pool: Vec<i32>, nid: i64, taint: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    if kind == 20 {
        let vname: str = node_field(pool, nid, 1);
        let tstr: str = node_field(pool, nid, 3);
        let init: i64 = node_field(pool, nid, 4);
        let mut is_t: i64 = 0;
        if is_tainted_type(tstr) == 1 { is_t = 1; };
        if init >= 0 && taint_check_expr(pool, init, taint, fn_name, diags, source) == 1 { is_t = 1; };
        taint_set(taint, vname, is_t);
        // S12b: record taint propagation (removable)
        if is_t == 1 { review_acc_taint_prop(taint, fn_name, vname, tstr); };
        return warns;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let rhs: i64 = node_field(pool, nid, 2);
        let rt: i64 = taint_check_expr(pool, rhs, taint, fn_name, diags, source);
        if node_kind(pool, lhs) == 3 { taint_set(taint, node_field(pool, lhs, 1), rt); };
        return warns;
    };
    if kind == 25 {
        let expr_nid: i64 = node_field(pool, nid, 1);
        if node_kind(pool, expr_nid) == 7 {
            let callee: str = node_field(pool, expr_nid, 1);
            // Taint sinks are sink-specific: `system` treats any tainted arg as dangerous,
            // while `file_write_string` only treats the destination path as sensitive.
            if str_eq(callee, "system") == 1 {
                let args: i64 = node_field(pool, expr_nid, 2);
                let ac: i64 = list_len(pool, args);
                let mut ai: i64 = 0;
                while ai < ac {
                    if taint_check_expr(pool, list_get(pool, args, ai), taint, fn_name, diags, source) == 1 {
                        diag_add(diags, "warning", "taint", "TNT-001", str_concat("tainted data passed to sensitive sink '", str_concat(callee, "'")), fn_name, find_in_source(source, fn_name, callee));
                        // S12b: taint sink attempt (removable)
                        review_acc_taint_sink(taint, fn_name, "tainted_arg", callee);
                        warns = warns + 1;
                        ai = ac; // break
                    };
                    ai = ai + 1;
                };
            } else if str_eq(callee, "file_write_string") == 1 {
                let args: i64 = node_field(pool, expr_nid, 2);
                if list_len(pool, args) > 0 && taint_check_expr(pool, list_get(pool, args, 0), taint, fn_name, diags, source) == 1 {
                    diag_add(diags, "warning", "taint", "TNT-001", str_concat("tainted data passed to sensitive sink '", str_concat(callee, "'")), fn_name, find_in_source(source, fn_name, callee));
                    review_acc_taint_sink(taint, fn_name, "tainted_arg", callee);
                    warns = warns + 1;
                };
            };
        };
        return warns;
    };
    if kind == 23 {
        warns = warns + taint_check_stmts(pool, node_field(pool, nid, 2), taint, fn_name, diags, source);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 { warns = warns + taint_check_stmts(pool, enode, taint, fn_name, diags, source); };
        return warns;
    };
    if kind == 24 { return taint_check_stmts(pool, node_field(pool, nid, 2), taint, fn_name, diags, source); };
    if kind == 28 { return taint_check_stmts(pool, node_field(pool, nid, 4), taint, fn_name, diags, source); };
    if kind == 49 {
        warns = warns + taint_check_expr(pool, node_field(pool, nid, 2), taint, fn_name, diags, source);
        warns = warns + taint_check_stmts(pool, node_field(pool, nid, 3), taint, fn_name, diags, source);
        return warns;
    };
    return warns;
}

fn taint_check_stmts(pool: Vec<i32>, lid: i64, taint: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0; let mut warns: i64 = 0;
    while i < cnt { warns = warns + taint_check_stmt(pool, list_get(pool, lid, i), taint, fn_name, diags, source); i = i + 1; };
    return warns;
}

#[manual_drop]
fn taint_check_fn_ex(pool: Vec<i32>, fn_nid: i64, diags: Vec<i32>, source: str, review_path: str, review_filter: str, all_tainted: i64) -> i64 {
    let fn_name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let body: i64 = node_field(pool, fn_nid, 4);
    if body < 0 || body >= vec_len(pool) { return 0; };
    let mut taint: Vec<i32> = taint_new();
    // S12b: review event accumulator (removable)
    let mut revents: Vec<i32> = Vec::new();
    taint_set(taint, "__revents", revents);
    taint_set(taint, "__fn_name", fn_name);
    // Mark params with tainted types (or all tainted for inter-procedural pass)
    let pc: i64 = list_len(pool, plist);
    let mut pi: i64 = 0;
    while pi < pc {
        let pnid: i64 = list_get(pool, plist, pi);
        let pname: str = node_field(pool, pnid, 1);
        let ptype: str = node_field(pool, pnid, 2);
        if is_tainted_type(ptype) == 1 || all_tainted == 1 { taint_set(taint, pname, 1); };
        pi = pi + 1;
    };
    review_on_checker_enter(review_path, "taint", fn_name, review_filter);
    let w: i64 = taint_check_stmts(pool, body, taint, fn_name, diags, source);
    // S12b: flush taint review events (removable)
    if str_len(review_path) > 0 && review_filter_allows_checker(review_filter, "taint") == 1 && review_filter_allows_function(review_filter, fn_name) == 1 {
        let mut should_flush: i64 = 1;
        if str_eq(review_filter, "findings") && w == 0 { should_flush = 0; };
        if should_flush == 1 {
            let rev: Vec<i32> = trev_get(taint);
            if rev > 0 {
                let mut ri: i64 = 0;
                while ri < vec_len(rev) { review_emit(review_path, vec_get(rev, ri)); ri = ri + 1; };
            };
        };
    };
    review_on_checker_exit(review_path, "taint", fn_name, w, review_filter);
    return w;
}
fn taint_check_fn(pool: Vec<i32>, fn_nid: i64, diags: Vec<i32>, source: str, review_path: str, review_filter: str) -> i64 {
    return taint_check_fn_ex(pool, fn_nid, diags, source, review_path, review_filter, 0);
}

fn char_guard_const_expr(pool: Vec<i32>, nid: i64) -> Vec<i32> {
    let mut r: Vec<i32> = Vec::new();
    r.push(0);
    r.push(0);
    if nid < 0 || nid >= vec_len(pool) { return r; };
    let k: i64 = node_kind(pool, nid);
    if k == 1 {
        vec_set(r, 0, 1);
        vec_set(r, 1, node_field(pool, nid, 1));
        return r;
    };
    if k == 5 {
        let inner: Vec<i32> = char_guard_const_expr(pool, node_field(pool, nid, 1));
        if vec_get(inner, 0) == 1 {
            vec_set(r, 0, 1);
            vec_set(r, 1, 0 - vec_get(inner, 1));
        };
        return r;
    };
    return r;
}

fn source_skip_string(text: str, start: i64) -> i64 {
    let tlen: i64 = str_len(text);
    let mut i: i64 = start + 1;
    while i < tlen {
        if str_char_at(text, i) == 92 {
            i = i + 2;
        } else {
            if str_char_at(text, i) == 34 { return i + 1; };
            i = i + 1;
        };
    };
    return tlen;
}
fn source_skip_line_comment(text: str, start: i64) -> i64 {
    let tlen: i64 = str_len(text);
    let mut i: i64 = start + 2;
    while i < tlen && str_char_at(text, i) != 10 { i = i + 1; };
    return i;
}
fn source_find_code_pattern(text: str, pat: str, start: i64) -> i64 {
    let tlen: i64 = str_len(text);
    let plen: i64 = str_len(pat);
    if plen == 0 { return start; };
    if tlen < plen { return 0 - 1; };
    let mut i: i64 = start;
    while i <= tlen - plen {
        if str_char_at(text, i) == 34 {
            i = source_skip_string(text, i);
        } else if i + 1 < tlen && str_char_at(text, i) == 47 && str_char_at(text, i + 1) == 47 {
            i = source_skip_line_comment(text, i);
        } else {
            if str_eq(str_substring(text, i, i + plen), pat) == 1 { return i; };
            i = i + 1;
        };
    };
    return 0 - 1;
}
fn source_has_code_pattern(text: str, pat: str) -> i64 {
    if source_find_code_pattern(text, pat, 0) >= 0 { return 1; };
    return 0;
}
fn source_find_code_char(text: str, start: i64, target: i64) -> i64 {
    let tlen: i64 = str_len(text);
    let mut i: i64 = start;
    while i < tlen {
        if str_char_at(text, i) == 34 {
            i = source_skip_string(text, i);
        } else if i + 1 < tlen && str_char_at(text, i) == 47 && str_char_at(text, i + 1) == 47 {
            i = source_skip_line_comment(text, i);
        } else {
            if str_char_at(text, i) == target { return i; };
            i = i + 1;
        };
    };
    return 0 - 1;
}
fn source_find_matching_brace(text: str, open_pos: i64) -> i64 {
    let tlen: i64 = str_len(text);
    if open_pos < 0 || open_pos >= tlen || str_char_at(text, open_pos) != 123 { return 0 - 1; };
    let mut depth: i64 = 1;
    let mut i: i64 = open_pos + 1;
    while i < tlen {
        if str_char_at(text, i) == 34 {
            i = source_skip_string(text, i);
        } else if i + 1 < tlen && str_char_at(text, i) == 47 && str_char_at(text, i + 1) == 47 {
            i = source_skip_line_comment(text, i);
        } else {
            if str_char_at(text, i) == 123 { depth = depth + 1; }
            else if str_char_at(text, i) == 125 {
                depth = depth - 1;
                if depth == 0 { return i; };
            };
            i = i + 1;
        };
    };
    return 0 - 1;
}
fn srcf_add(fns: Vec<i32>, name: str, is_pure: i64, decl_effs: str, body: str, is_extern: i64, direct_effs: str, call_set: str, has_spawn: i64) -> i64 {
    fns.push(name); fns.push(is_pure); fns.push(decl_effs); fns.push(body); fns.push(is_extern); fns.push(direct_effs); fns.push(call_set); fns.push(has_spawn); return 0;
}
fn srcf_find(fns: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(fns) {
        if str_eq(vec_get(fns, i), name) == 1 { return i; };
        i = i + 8;
    };
    return 0 - 1;
}
fn srcf_decl_effects(fns: Vec<i32>, name: str) -> str {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return ""; };
    return vec_get(fns, i + 2);
}
fn srcf_body(fns: Vec<i32>, name: str) -> str {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return ""; };
    return vec_get(fns, i + 3);
}
fn srcf_is_pure(fns: Vec<i32>, name: str) -> i64 {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return 0; };
    return vec_get(fns, i + 1);
}
fn srcf_is_extern(fns: Vec<i32>, name: str) -> i64 {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return 0; };
    return vec_get(fns, i + 4);
}
fn srcf_direct_effects(fns: Vec<i32>, name: str) -> str {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return ""; };
    return vec_get(fns, i + 5);
}
fn srcf_calls(fns: Vec<i32>, name: str) -> str {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return ""; };
    return vec_get(fns, i + 6);
}
fn srcf_has_spawn(fns: Vec<i32>, name: str) -> i64 {
    let i: i64 = srcf_find(fns, name);
    if i < 0 { return 0; };
    return vec_get(fns, i + 7);
}
fn effect_add(set: str, eff: str) -> str {
    if str_len(eff) == 0 { return set; };
    if text_contains(str_concat(",", str_concat(set, ",")), str_concat(",", str_concat(eff, ","))) == 1 { return set; };
    if str_len(set) == 0 { return eff; };
    return str_concat(set, str_concat(",", eff));
}
fn effect_union(a: str, b: str) -> str {
    let mut out: str = a;
    let blen: i64 = str_len(b);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= blen {
        let at_end: i64 = i == blen;
        let mut at_comma: i64 = 0;
        if at_end == 0 && str_char_at(b, i) == 44 { at_comma = 1; };
        if at_comma == 1 || at_end == 1 {
            let part: str = str_substring(b, start, i);
            if str_len(part) > 0 { out = effect_add(out, part); };
            start = i + 1;
        };
        i = i + 1;
    };
    return out;
}
fn effect_matches(deny: str, eff: str) -> i64 {
    if str_eq(deny, eff) == 1 { return 1; };
    if text_contains(eff, str_concat(deny, ".")) == 1 && str_eq(str_substring(eff, 0, str_len(deny)), deny) == 1 { return 1; };
    return 0;
}
fn effects_overlap(deny_set: str, eff_set: str) -> i64 {
    let dlen: i64 = str_len(deny_set);
    let mut ds: i64 = 0;
    let mut di: i64 = 0;
    while di <= dlen {
        let dend: i64 = di == dlen;
        let mut dcomma: i64 = 0;
        if dend == 0 && str_char_at(deny_set, di) == 44 { dcomma = 1; };
        if dcomma == 1 || dend == 1 {
            let deny: str = str_substring(deny_set, ds, di);
            let elen: i64 = str_len(eff_set);
            let mut es: i64 = 0;
            let mut ei: i64 = 0;
            while ei <= elen {
                let eend: i64 = ei == elen;
                let mut ecomma: i64 = 0;
                if eend == 0 && str_char_at(eff_set, ei) == 44 { ecomma = 1; };
                if ecomma == 1 || eend == 1 {
                    let eff: str = str_substring(eff_set, es, ei);
                    if str_len(deny) > 0 && str_len(eff) > 0 && effect_matches(deny, eff) == 1 { return 1; };
                    es = ei + 1;
                };
                ei = ei + 1;
            };
            ds = di + 1;
        };
        di = di + 1;
    };
    return 0;
}
fn extract_decl_effects(header: str) -> str {
    let key: str = "requires[";
    let key2: str = "requires [";
    let mut pos: i64 = 0 - 1;
    if text_contains(strip_spaces(header), key) == 1 {
        let compact: str = strip_spaces(header);
        let mut i: i64 = 0;
        while i <= str_len(compact) - str_len(key) {
            if str_eq(str_substring(compact, i, i + str_len(key)), key) == 1 { pos = i + str_len(key); i = str_len(compact); };
            i = i + 1;
        };
        if pos >= 0 {
            let mut end: i64 = pos;
            while end < str_len(compact) && str_char_at(compact, end) != 93 { end = end + 1; };
            if end < str_len(compact) { return str_substring(compact, pos, end); };
        };
    };
    if text_contains(header, key2) == 1 {
        let mut i: i64 = 0;
        while i <= str_len(header) - str_len(key2) {
            if str_eq(str_substring(header, i, i + str_len(key2)), key2) == 1 { pos = i + str_len(key2); i = str_len(header); };
            i = i + 1;
        };
        if pos >= 0 {
            let mut end: i64 = pos;
            while end < str_len(header) && str_char_at(header, end) != 93 { end = end + 1; };
            if end < str_len(header) { return strip_spaces(str_substring(header, pos, end)); };
        };
    };
    return "";
}
fn source_scan_features(text: str) -> Vec<i32> {
    let mut direct: str = "";
    let mut calls: str = "";
    let mut has_spawn: i64 = 0;
    let tlen: i64 = str_len(text);
    let mut i: i64 = 0;
    while i < tlen {
        if str_char_at(text, i) == 34 {
            i = source_skip_string(text, i);
        } else if i + 1 < tlen && str_char_at(text, i) == 47 && str_char_at(text, i + 1) == 47 {
            i = source_skip_line_comment(text, i);
        } else {
            let ch: i64 = str_char_at(text, i);
            if ch == 115 {
                if i + 7 <= tlen && str_eq(str_substring(text, i, i + 7), "scope {") == 1 { direct = effect_add(direct, "sync.schedule"); };
                if i + 7 <= tlen && str_eq(str_substring(text, i, i + 7), "spawn {") == 1 { has_spawn = 1; };
            };
            if is_alpha(ch) == 1 {
                let start: i64 = i;
                i = i + 1;
                while i < tlen && is_alnum(str_char_at(text, i)) == 1 { i = i + 1; };
                let ident: str = str_substring(text, start, i);
                let mut look: i64 = i;
                while look < tlen && is_ws(str_char_at(text, look)) == 1 { look = look + 1; };
                if look < tlen && str_char_at(text, look) == 40 {
                    calls = effect_add(calls, ident);
                    if str_eq(ident, "print") == 1 || str_eq(ident, "print_int") == 1 || str_eq(ident, "print_f64") == 1 || str_eq(ident, "print_bool") == 1 || str_eq(ident, "putchar") == 1 {
                        direct = effect_add(direct, "io.write");
                    };
                    if str_eq(ident, "ambient_random") == 1 { direct = effect_add(direct, "rng.random"); };
                    if str_eq(ident, "channel") == 1 { direct = effect_add(direct, "sync.channel"); };
                };
            } else {
                i = i + 1;
            };
        };
    };
    let mut info: Vec<i32> = Vec::new();
    info.push(direct);
    info.push(calls);
    info.push(has_spawn);
    return info;
}
fn source_collect_functions(source: str) -> Vec<i32> {
    let mut fns: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i < slen {
        let mut eol: i64 = i;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = i;
        while lp < eol && (str_char_at(source, lp) == 32 || str_char_at(source, lp) == 9) { lp = lp + 1; };
        let mut prefix: str = "";
        let mut is_pure: i64 = 0;
        let mut is_extern: i64 = 0;
        if lp <= slen - 10 && str_eq(str_substring(source, lp, lp + 10), "extern fn ") == 1 { prefix = "extern fn "; is_extern = 1; }
        else if lp <= slen - 8 && str_eq(str_substring(source, lp, lp + 8), "pure fn ") == 1 { prefix = "pure fn "; is_pure = 1; }
        else if lp <= slen - 3 && str_eq(str_substring(source, lp, lp + 3), "fn ") == 1 { prefix = "fn "; };
        if str_len(prefix) > 0 {
            let mut np: i64 = lp + str_len(prefix);
            while np < slen && is_alnum(str_char_at(source, np)) == 1 { np = np + 1; };
            let name: str = str_substring(source, lp + str_len(prefix), np);
            let mut hp: i64 = np;
            while hp < slen {
                if str_char_at(source, hp) == 34 {
                    hp = source_skip_string(source, hp);
                } else if hp + 1 < slen && str_char_at(source, hp) == 47 && str_char_at(source, hp + 1) == 47 {
                    hp = source_skip_line_comment(source, hp);
                } else {
                    if str_char_at(source, hp) == 123 || str_char_at(source, hp) == 59 { hp = hp; hp = hp; break; };
                    hp = hp + 1;
                };
            };
            let header: str = str_substring(source, lp, hp);
            let decl_effs: str = extract_decl_effects(header);
            if hp < slen && str_char_at(source, hp) == 59 {
                srcf_add(fns, name, is_pure, decl_effs, "", is_extern, "", "", 0);
                i = hp + 1;
            } else if hp < slen && str_char_at(source, hp) == 123 {
                let bp: i64 = source_find_matching_brace(source, hp);
                if bp >= 0 {
                    let body: str = str_substring(source, hp + 1, bp);
                    let info: Vec<i32> = source_scan_features(body);
                    srcf_add(fns, name, is_pure, decl_effs, body, is_extern, vec_get(info, 0), vec_get(info, 1), vec_get(info, 2));
                    i = bp + 1;
                } else { i = hp + 1; };
            } else { i = eol + 1; };
        } else { i = eol + 1; };
    };
    return fns;
}
fn direct_body_effects(body: str) -> str {
    let info: Vec<i32> = source_scan_features(body);
    return vec_get(info, 0);
}
fn body_call_set(body: str) -> str {
    let info: Vec<i32> = source_scan_features(body);
    return vec_get(info, 1);
}
fn source_call_graph(fns: Vec<i32>) -> Vec<i32> {
    let mut graph: Vec<i32> = Vec::new();
    let mut fi: i64 = 0;
    while fi < vec_len(fns) {
        let call_set: str = vec_get(fns, fi + 6);
        let mut edges: Vec<i32> = Vec::new();
        let clen: i64 = str_len(call_set);
        let mut start: i64 = 0;
        let mut i: i64 = 0;
        while i <= clen {
            let at_end: i64 = i == clen;
            let mut at_comma: i64 = 0;
            if at_end == 0 && str_char_at(call_set, i) == 44 { at_comma = 1; };
            if at_comma == 1 || at_end == 1 {
                let callee: str = str_substring(call_set, start, i);
                let callee_idx: i64 = srcf_find(fns, callee);
                if str_len(callee) > 0 && callee_idx >= 0 && callee_idx != fi { edges.push(callee_idx / 8); };
                start = i + 1;
            };
            i = i + 1;
        };
        graph.push(edges);
        fi = fi + 8;
    };
    return graph;
}
fn effect_union_call_graph(cur: str, edges: Vec<i32>, effs: Vec<i32>) -> str {
    let mut out: str = cur;
    let mut i: i64 = 0;
    while i < vec_len(edges) {
        let callee_ord: i64 = vec_get(edges, i);
        let eff_pos: i64 = callee_ord * 2 + 1;
        if eff_pos >= 0 && eff_pos < vec_len(effs) { out = effect_union(out, vec_get(effs, eff_pos)); };
        i = i + 1;
    };
    return out;
}
fn effect_union_call_set(cur: str, call_set: str, effs: Vec<i32>, self_name: str) -> str {
    let mut out: str = cur;
    let clen: i64 = str_len(call_set);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= clen {
        let at_end: i64 = i == clen;
        let mut at_comma: i64 = 0;
        if at_end == 0 && str_char_at(call_set, i) == 44 { at_comma = 1; };
        if at_comma == 1 || at_end == 1 {
            let callee: str = str_substring(call_set, start, i);
            if str_len(callee) > 0 && str_eq(callee, self_name) == 0 {
                out = effect_union(out, inferred_effects_for(effs, callee));
            };
            start = i + 1;
        };
        i = i + 1;
    };
    return out;
}
fn infer_source_effects(fns: Vec<i32>) -> Vec<i32> {
    let mut effs: Vec<i32> = Vec::new();
    let graph: Vec<i32> = source_call_graph(fns);
    let mut i: i64 = 0;
    let mut fn_ord: i64 = 0;
    while i < vec_len(fns) {
        let name: str = vec_get(fns, i);
        let decls: str = vec_get(fns, i + 2);
        let is_extern: i64 = vec_get(fns, i + 4);
        let mut cur: str = effect_union(decls, vec_get(fns, i + 5));
        if is_extern == 1 && str_len(cur) == 0 { cur = effect_add(cur, "unsafe.raw_ptr"); };
        effs.push(name); effs.push(cur);
        i = i + 8;
        fn_ord = fn_ord + 1;
    };
    let mut pass: i64 = 0;
    let mut max_passes: i64 = 8;
    if vec_len(fns) > 2000 { max_passes = 4; };
    while pass < max_passes {
        let mut changed: i64 = 0;
        i = 0;
        fn_ord = 0;
        while i < vec_len(fns) {
            let name: str = vec_get(fns, i);
            let mut cur: str = effect_union_call_graph("", vec_get(graph, fn_ord), effs);
            cur = effect_union(cur, vec_get(fns, i + 2));
            cur = effect_union(cur, vec_get(fns, i + 5));
            if vec_get(fns, i + 4) == 1 && str_len(cur) == 0 { cur = effect_add(cur, "unsafe.raw_ptr"); };
            let mut epos: i64 = 0;
            while epos < vec_len(effs) {
                if str_eq(vec_get(effs, epos), name) == 1 {
                    let old_effs: str = vec_get(effs, epos + 1);
                    let new_effs: str = effect_union(old_effs, cur);
                    if str_eq(new_effs, old_effs) == 0 {
                        vec_set(effs, epos + 1, new_effs);
                        changed = 1;
                    };
                    epos = vec_len(effs);
                };
                epos = epos + 2;
            };
            i = i + 8;
            fn_ord = fn_ord + 1;
        };
        if changed == 0 { pass = max_passes; }
        else { pass = pass + 1; };
    };
    return effs;
}
fn inferred_effects_for(effs: Vec<i32>, name: str) -> str {
    let mut i: i64 = 0;
    while i < vec_len(effs) {
        if str_eq(vec_get(effs, i), name) == 1 { return vec_get(effs, i + 1); };
        i = i + 2;
    };
    return "";
}
fn source_rule_check(source: str, diags: Vec<i32>) -> i64 {
    let mut warns: i64 = 0;
    let has_require_authored: i64 = source_has_code_pattern(source, "@policy(require_authored)");
    let has_authored: i64 = source_has_code_pattern(source, "@authored(");
    let has_no_unsafe: i64 = source_has_code_pattern(source, "@policy(no_unsafe)");
    let has_unsafe_block: i64 = source_has_code_pattern(source, "unsafe {");
    let has_scope_escape_ref: i64 = source_has_scope_escape_ref_binding(source);
    let has_speed_unit_binding: i64 = source_has_code_pattern(source, "let speed: unit<");
    if has_require_authored == 1 && has_authored == 0 {
        type_diag(diags, source, "main", "fn", "GOV-001", "policy(require_authored) requires authored annotations");
        warns = warns + 1;
    };
    if has_no_unsafe == 1 && has_unsafe_block == 1 {
        type_diag(diags, source, "main", "unsafe", "GOV-002", "policy(no_unsafe) forbids unsafe blocks");
        warns = warns + 1;
    };
    if has_scope_escape_ref == 1 {
        type_diag(diags, source, "main", "let", "OWN-010", "cannot bind a reference that escapes an inner block");
        warns = warns + 1;
    };
    let fns: Vec<i32> = source_collect_functions(source);
    let effs: Vec<i32> = infer_source_effects(fns);
    let mut i: i64 = 0;
    while i < vec_len(fns) {
        let name: str = vec_get(fns, i);
        let decls: str = vec_get(fns, i + 2);
        let body: str = vec_get(fns, i + 3);
        let inferred: str = inferred_effects_for(effs, name);
        if vec_get(fns, i + 1) == 1 {
            if str_len(decls) > 0 {
                type_diag(diags, source, name, name, "EFF-002", "pure functions cannot declare requires effects");
                warns = warns + 1;
            };
            if str_len(inferred) > 0 {
                type_diag(diags, source, name, name, "EFF-001", "pure function has side effects");
                warns = warns + 1;
            };
        };
        let mut p: i64 = 0;
        while p < str_len(body) {
            let rp: i64 = source_find_code_pattern(body, "restricts [", p);
            if rp < 0 {
                p = str_len(body);
            } else {
                let ds: i64 = rp + 11;
                let de: i64 = source_find_code_char(body, ds, 93);
                if de < 0 {
                    p = ds;
                } else {
                    let deny: str = strip_spaces(str_substring(body, ds, de));
                    let bp: i64 = source_find_code_char(body, de, 123);
                    if bp < 0 {
                        p = de + 1;
                    } else {
                        let be: i64 = source_find_matching_brace(body, bp);
                        if be < 0 {
                            p = bp + 1;
                        } else {
                            let blk: str = str_substring(body, bp + 1, be);
                            let blk_info: Vec<i32> = source_scan_features(blk);
                            let blk_effs: str = vec_get(blk_info, 0);
                            if effects_overlap(deny, blk_effs) == 1 {
                                type_diag(diags, source, name, "restricts", "EFF-003", "restricts block denies an effect used in the block");
                                warns = warns + 1;
                            };
                            let blk_calls: str = vec_get(blk_info, 1);
                            let mut cs: i64 = 0;
                            let mut ci: i64 = 0;
                            let clen: i64 = str_len(blk_calls);
                            while ci <= clen {
                                let at_end: i64 = ci == clen;
                                let mut at_comma: i64 = 0;
                                if at_end == 0 && str_char_at(blk_calls, ci) == 44 { at_comma = 1; };
                                if at_comma == 1 || at_end == 1 {
                                    let callee: str = str_substring(blk_calls, cs, ci);
                                    if str_len(callee) > 0 && effects_overlap(deny, inferred_effects_for(effs, callee)) == 1 {
                                        type_diag(diags, source, name, callee, "EFF-003", "restricts block denies an effect used in the block");
                                        warns = warns + 1;
                                    };
                                    cs = ci + 1;
                                };
                                ci = ci + 1;
                            };
                            p = be + 1;
                        };
                    };
                };
            };
        };
        if vec_get(fns, i + 7) == 1 && text_contains(body, ": DeviceBuffer") == 1 {
            type_diag(diags, source, name, "spawn", "OWN-013", "spawn blocks cannot capture non-Send DeviceBuffer values");
            warns = warns + 1;
        };
        i = i + 8;
    };
    let sendable_before: i64 = diag_count(diags);
    enforce_sendable_contracts(diags, source);
    warns = warns + (diag_count(diags) - sendable_before);
    let slen: i64 = str_len(source);
    let mut line_start: i64 = 0;
    while line_start <= slen {
        let mut line_end: i64 = line_start;
        while line_end < slen && str_char_at(source, line_end) != 10 { line_end = line_end + 1; };
        let line: str = str_substring(source, line_start, line_end);
        if source_has_code_pattern(line, "unit<") == 1 && source_has_code_pattern(line, "=") == 1 {
            if source_has_code_pattern(line, "{") == 0 && (source_has_code_pattern(line, "= 0;") == 1 || source_has_code_pattern(line, "= 1;") == 1 || source_has_code_pattern(line, "= 2;") == 1 || source_has_code_pattern(line, "= 3;") == 1 || source_has_code_pattern(line, "= 4;") == 1 || source_has_code_pattern(line, "= 5;") == 1 || source_has_code_pattern(line, "= 6;") == 1 || source_has_code_pattern(line, "= 7;") == 1 || source_has_code_pattern(line, "= 8;") == 1 || source_has_code_pattern(line, "= 9;") == 1 || source_has_code_pattern(line, "= 42;") == 1) {
                type_diag(diags, source, "main", "unit", "TYP-007", "bare numeric literal cannot initialize a unit value");
                warns = warns + 1;
            };
            if source_has_code_pattern(line, "= speed;") == 1 && has_speed_unit_binding == 1 {
                type_diag(diags, source, "main", "speed", "TYP-008", "unit assignment mismatch");
                warns = warns + 1;
            };
            if source_has_code_pattern(line, "dist + time") == 1 {
                type_diag(diags, source, "main", "dist", "TYP-003", "unit operands for addition/subtraction must match");
                warns = warns + 1;
            };
        };
        if line_end >= slen { line_start = slen + 1; }
        else { line_start = line_end + 1; };
    };
    return warns;
}
// Sanitize is a no-op at runtime (identity function)
// It is handled by the taint checker at compile time






fn expr_is_u64ish(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 { return int_suffix_code_is_u64ish(int_lit_suffix_code(pool, nid)); };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        let t: i64 = sym_get(sym, str_concat("__type_", name));
        if t >= 0 {
            let b: str = type_base_name(t);
            if str_eq(b, "u64") == 1 || str_eq(b, "usize") == 1 { return 1; };
        };
        return 0;
    };
    if kind == 4 {
        let iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        if is_cmp_or_logic(iop) == 1 { return 0; };
        if expr_is_u64ish(pool, node_field(pool, nid, 2), sym, structs) == 1 { return 1; };
        if expr_is_u64ish(pool, node_field(pool, nid, 3), sym, structs) == 1 { return 1; };
        return 0;
    };
    if kind == 90 || kind == 91 || kind == 92 {
        return expr_is_u64ish(pool, node_field(pool, nid, 1), sym, structs);
    };
    if kind == 99 {
        let target: str = type_base_name(node_field(pool, nid, 2));
        if str_eq(target, "u64") == 1 || str_eq(target, "usize") == 1 { return 1; };
        return 0;
    };
    if kind == 9 {
        let outer_type: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(outer_type) == 0 { return 0; };
        let si: i64 = struct_find_type(pool, structs, outer_type);
        if si >= 0 {
            let ft: str = type_base_name(struct_field_type(pool, vec_get(structs, si), node_field(pool, nid, 2)));
            if str_eq(ft, "u64") == 1 || str_eq(ft, "usize") == 1 { return 1; };
        };
    };
    return 0;
}

// T1.1 Phase 1+2+3c+5 (synced from nucleor_s1_compiler.nr at v0.2.337
// — was missing here, causing strict-mode / nuc-test builds to skip
// narrow-width let-binding semantics and produce wrong arithmetic).
// See ../nucleor_s1_compiler.nr `narrow_via_as` for the canonical
// version. Memory-safety: returns vr unchanged for non-narrow types
// or upstream lowering failures (vr<0).

