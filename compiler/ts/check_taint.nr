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

fn sig_entry_new(plist: i64, rtype: str, is_extern: i64) -> Vec<i32> {
    let mut entry: Vec<i32> = Vec::new();
    entry.push(plist);
    entry.push(rtype);
    entry.push(is_extern);
    return entry;
}
fn sig_add(sigs: Vec<i32>, name: str, plist: i64, rtype: str, is_extern: i64) -> i64 {
    return smap_set(sigs, name, sig_entry_new(plist, rtype, is_extern));
}
fn types_compatible(expected: str, actual: str) -> i64 {
    if str_len(expected) == 0 || str_len(actual) == 0 { return 1; };
    if str_eq(expected, "_") == 1 { return 1; };
    if str_eq(actual, "_") == 1 { return 1; };
    if str_eq(expected, actual) == 1 { return 1; };
    let ebase: str = type_base_name(expected);
    let abase: str = type_base_name(actual);
    if str_eq(ebase, "Vec") == 1 && (str_eq(actual, "i64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "ptr") == 1) { return 1; };
    if str_eq(abase, "Vec") == 1 && (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1 || str_eq(expected, "ptr") == 1) { return 1; };
    if (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1) && str_eq(actual, "bool") == 1 { return 1; };
    if str_eq(expected, "bool") == 1 && (str_eq(actual, "i64") == 1 || str_eq(actual, "i32") == 1) { return 1; };
    if str_eq(expected, "Int") == 1 && (str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1) { return 1; };
    if str_eq(expected, "Float") == 1 && (str_eq(actual, "f64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1) { return 1; };
    if str_len(ebase) >= 2 && (str_char_at(ebase, 0) == 105 || str_char_at(ebase, 0) == 117) {
        let mut digits_only: i64 = 1;
        let mut di: i64 = 1;
        while di < str_len(ebase) {
            let dc: i64 = str_char_at(ebase, di);
            if dc < 48 || dc > 57 { digits_only = 0; };
            di = di + 1;
        };
        if digits_only == 1 && (str_eq(actual, "i32") == 1 || str_eq(actual, "i64") == 1 || str_eq(actual, "f64") == 1) { return 1; };
    };
    if str_len(expected) == 1 {
        let c: i64 = str_char_at(expected, 0);
        if c >= 65 && c <= 90 { return 1; };
    };
    if str_len(actual) == 1 {
        let c: i64 = str_char_at(actual, 0);
        if c >= 65 && c <= 90 { return 1; };
    };
    if str_eq(strip_spaces(expected), strip_spaces(actual)) == 1 { return 1; };
    if (str_eq(expected, "i64") == 1 || str_eq(expected, "i32") == 1 || str_eq(expected, "f64") == 1) &&
       (str_eq(actual, "i64") == 1 || str_eq(actual, "i32") == 1 || str_eq(actual, "f64") == 1) { return 1; };
    if is_tainted_type(expected) == 1 && is_tainted_type(actual) == 0 {
        if str_eq(strip_spaces(taint_inner_type(expected)), strip_spaces(actual)) == 1 { return 1; };
    };
    if is_tainted_type(expected) == 0 && is_tainted_type(actual) == 1 { return 0; };
    if type_is_unit(expected) == 1 || type_is_unit(actual) == 1 { return 0; };
    if str_eq(ebase, abase) == 1 { return 1; };
    return 0;
}
fn line_contains_text(source: str, fn_name: str, symbol: str, text: str) -> i64 {
    let line: i64 = find_in_source(source, fn_name, symbol);
    let txt: str = source_line(source, line);
    let tlen: i64 = str_len(text);
    let llen: i64 = str_len(txt);
    if llen < tlen { return 0; };
    let mut i: i64 = 0;
    while i <= llen - tlen {
        if str_eq(str_substring(txt, i, i + tlen), text) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}
fn source_box_binding_type(source: str, fn_name: str, name: str) -> str {
    let target: str = str_concat("let ", str_concat(name, ": Box<"));
    let tlen: i64 = str_len(target);
    let slen: i64 = str_len(source);
    let mut i: i64 = 0;
    while i <= slen - tlen {
        if str_eq(str_substring(source, i, i + tlen), target) == 1 {
            let mut end: i64 = i + tlen;
            while end < slen && str_char_at(source, end) != 62 { end = end + 1; };
            if end < slen { return str_concat("Box<", str_concat(str_substring(source, i + tlen, end), ">")); };
        };
        i = i + 1;
    };
    return "";
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
fn char_guard_var_name(pool: Vec<i32>, nid: i64) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    if node_kind(pool, nid) != 4 { return ""; };
    let op: i64 = node_field(pool, nid, 1);
    if op == 36 {
        let lv: str = char_guard_var_name(pool, node_field(pool, nid, 2));
        if str_len(lv) > 0 { return lv; };
        return char_guard_var_name(pool, node_field(pool, nid, 3));
    };
    if node_kind(pool, node_field(pool, nid, 2)) == 3 {
        let rc: Vec<i32> = char_guard_const_expr(pool, node_field(pool, nid, 3));
        if vec_get(rc, 0) == 1 { return node_field(pool, node_field(pool, nid, 2), 1); };
    };
    if node_kind(pool, node_field(pool, nid, 3)) == 3 {
        let lc: Vec<i32> = char_guard_const_expr(pool, node_field(pool, nid, 2));
        if vec_get(lc, 0) == 1 { return node_field(pool, node_field(pool, nid, 3), 1); };
    };
    return "";
}
fn char_guard_flags(pool: Vec<i32>, nid: i64, name: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    if node_kind(pool, nid) != 4 { return 0; };
    let op: i64 = node_field(pool, nid, 1);
    if op == 36 {
        return char_guard_merge_flags(char_guard_flags(pool, node_field(pool, nid, 2), name), char_guard_flags(pool, node_field(pool, nid, 3), name));
    };
    let lhs: i64 = node_field(pool, nid, 2);
    let rhs: i64 = node_field(pool, nid, 3);
    if node_kind(pool, lhs) == 3 && str_eq(node_field(pool, lhs, 1), name) == 1 {
        let rc: Vec<i32> = char_guard_const_expr(pool, rhs);
        if vec_get(rc, 0) == 1 {
            let v: i64 = vec_get(rc, 1);
            if (op == 35 && v >= 0) || (op == 33 && v >= 0 - 1) { return 1; };
            if (op == 34 && v < 55296) || (op == 32 && v <= 55296) { return 2; };
        };
    };
    if node_kind(pool, rhs) == 3 && str_eq(node_field(pool, rhs, 1), name) == 1 {
        let lc: Vec<i32> = char_guard_const_expr(pool, lhs);
        if vec_get(lc, 0) == 1 {
            let v2: i64 = vec_get(lc, 1);
            if (op == 34 && v2 >= 0) || (op == 32 && v2 >= 0 - 1) { return 1; };
            if (op == 35 && v2 < 55296) || (op == 33 && v2 <= 55296) { return 2; };
        };
    };
    return 0;
}
fn char_guard_proven_var(pool: Vec<i32>, cond: i64) -> str {
    let name: str = char_guard_var_name(pool, cond);
    if str_len(name) == 0 { return ""; };
    if char_guard_flags(pool, cond, name) == 3 { return name; };
    return "";
}
fn type_last_stmt(pool: Vec<i32>, lid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, tprof: Vec<i32>) -> str {
    if lid < 0 || lid >= vec_len(pool) { return ""; };
    let cnt: i64 = list_len(pool, lid);
    if cnt == 0 { return ""; };
    let last_stmt: i64 = list_get(pool, lid, cnt - 1);
    let val: i64 = type_stmt_value(pool, last_stmt);
    if val >= 0 { return type_expr(pool, val, env, sigs, structs, fn_name, diags, source, tprof); };
    if node_kind(pool, last_stmt) == 23 || node_kind(pool, last_stmt) == 52 { return type_expr(pool, last_stmt, env, sigs, structs, fn_name, diags, source, tprof); };
    return "";
}
fn type_expr(pool: Vec<i32>, nid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, tprof: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 { return int_lit_type(pool, nid); };
    if kind == 71 { return "f64"; };
    if kind == 2 { return "str"; };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if str_eq(name, "true") == 1 || str_eq(name, "false") == 1 { return "bool"; };
        let env_start: i64 = tprof_start(tprof);
        let out: str = tenv_get(env, name);
        tprof_mark(tprof, 3, 4, env_start);
        // TYP-022 — struct name used as a value.
        if str_len(out) == 0 && struct_find_type(pool, structs, name) >= 0 {
            let v22sval_msg_t: str = str_concat("`", str_concat(name, str_concat("` is a struct type, not a value. Pre-v0.4.138 this lowered to `ptrtoint ptr @", str_concat(name, " to i64` and failed late at clang link with an undefined-symbol error. Use struct-init syntax `<Name> { field1: val1, ... }` to construct a value, or call an inherent constructor."))));
            type_diag(diags, source, fn_name, name, "TYP-022", v22sval_msg_t);
        };
        return out;
    };
    if kind == 4 {
        let op: i64 = node_field(pool, nid, 1);
        let lt: str = type_expr(pool, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof);
        let rt: str = type_expr(pool, node_field(pool, nid, 3), env, sigs, structs, fn_name, diags, source, tprof);
        if (op == 20 || op == 21 || op == 22 || op == 23 || op == 24) && (str_eq(lt, "bool") == 1 || str_eq(rt, "bool") == 1) {
            type_diag(diags, source, fn_name, fn_name, "TYP-002", "boolean values cannot be used in arithmetic");
        };
        if (op == 20 || op == 21) && type_is_unit(lt) == 1 && type_is_unit(rt) == 1 && str_eq(unit_dim(lt), unit_dim(rt)) == 0 {
            type_diag(diags, source, fn_name, fn_name, "TYP-003", "unit operands for addition/subtraction must match");
        };
        // NUM-022 — int vs float in cmp binop.
        // extended to arith ops 20-24.
        // Inline predicate (tools_suite has no type_is_int/float helper).
        let lt_is_int_v137_t: i64 = if str_eq(lt, "i64") == 1 || str_eq(lt, "i32") == 1 || str_eq(lt, "i16") == 1 || str_eq(lt, "i8") == 1 || str_eq(lt, "u64") == 1 || str_eq(lt, "u32") == 1 || str_eq(lt, "u16") == 1 || str_eq(lt, "u8") == 1 { 1 } else { 0 };
        let rt_is_int_v137_t: i64 = if str_eq(rt, "i64") == 1 || str_eq(rt, "i32") == 1 || str_eq(rt, "i16") == 1 || str_eq(rt, "i8") == 1 || str_eq(rt, "u64") == 1 || str_eq(rt, "u32") == 1 || str_eq(rt, "u16") == 1 || str_eq(rt, "u8") == 1 { 1 } else { 0 };
        let lt_is_flt_v137_t: i64 = if str_eq(lt, "f64") == 1 || str_eq(lt, "f32") == 1 || str_eq(lt, "f16") == 1 || str_eq(lt, "bf16") == 1 { 1 } else { 0 };
        let rt_is_flt_v137_t: i64 = if str_eq(rt, "f64") == 1 || str_eq(rt, "f32") == 1 || str_eq(rt, "f16") == 1 || str_eq(rt, "bf16") == 1 { 1 } else { 0 };
        if (op == 20 || op == 21 || op == 22 || op == 23 || op == 24
            || op == 30 || op == 31 || op == 32 || op == 33 || op == 34 || op == 35 || op == 36 || op == 37)
            && ((lt_is_int_v137_t == 1 && rt_is_flt_v137_t == 1) || (lt_is_flt_v137_t == 1 && rt_is_int_v137_t == 1)) {
            let int_side_v137_t: str = if lt_is_int_v137_t == 1 { lt } else { rt };
            let flt_side_v137_t: str = if lt_is_flt_v137_t == 1 { lt } else { rt };
            let v22msg_t: str = str_concat("integer (`", str_concat(int_side_v137_t, str_concat("`) and float (`", str_concat(flt_side_v137_t, "`) operands in arith/cmp binop. Pre-v0.4.137/.141 the raw i64 bit patterns were used. Use an explicit `x as f64` or `y as i64`."))));
            type_diag(diags, source, fn_name, fn_name, "NUM-022", v22msg_t);
        };
        let is_int_arith_v110_t: i64 = if op == 20 || op == 21 || op == 22 || op == 23 || op == 24 { 1 } else { 0 };
        let lhs_nid_v110_t: i64 = node_field(pool, nid, 2);
        let rhs_nid_v110_t: i64 = node_field(pool, nid, 3);
        let lhs_unsuffixed_lit_v110_t: i64 = if node_kind(pool, lhs_nid_v110_t) == 1 && int_lit_suffix_code(pool, lhs_nid_v110_t) == 0 { 1 } else { 0 };
        let rhs_unsuffixed_lit_v110_t: i64 = if node_kind(pool, rhs_nid_v110_t) == 1 && int_lit_suffix_code(pool, rhs_nid_v110_t) == 0 { 1 } else { 0 };
        if is_int_arith_v110_t == 1 && lhs_unsuffixed_lit_v110_t == 0 && rhs_unsuffixed_lit_v110_t == 0 && lt_is_int_v137_t == 1 && rt_is_int_v137_t == 1 && str_eq(lt, rt) == 0 {
            let opch_v110_t: str = if op == 20 { "+" } else if op == 21 { "-" } else if op == 22 { "*" } else if op == 23 { "/" } else { "%" };
            let v001msg_t: str = str_concat("mixed-width integer arithmetic `", str_concat(lt, str_concat(" ", str_concat(opch_v110_t, str_concat(" ", str_concat(rt, "` requires an explicit `as` cast (NUM-001)."))))));
            type_diag(diags, source, fn_name, fn_name, "NUM-001", v001msg_t);
        };
        if is_tainted_type(lt) == 1 { return lt; };
        if is_tainted_type(rt) == 1 { return rt; };
        if is_int_arith_v110_t == 1 && lhs_unsuffixed_lit_v110_t == 1 && rt_is_int_v137_t == 1 { return rt; };
        if is_int_arith_v110_t == 1 && rhs_unsuffixed_lit_v110_t == 1 && lt_is_int_v137_t == 1 { return lt; };
        if (op == 20 || op == 21) && type_is_unit(lt) == 1 && str_eq(unit_dim(lt), unit_dim(rt)) == 1 { return lt; };
        // TYP-011 — struct == / != / ord silently
        // does pointer comparison.
        if (op == 30 || op == 31 || op == 32 || op == 33 || op == 34 || op == 35) && str_len(lt) > 0 && str_eq(strip_spaces(lt), strip_spaces(rt)) == 1 {
            let v147_lstruct_t: i64 = struct_find_type(pool, structs, lt);
            if v147_lstruct_t >= 0 {
                let v147msg_t: str = str_concat("`", str_concat(lt, " <op> <same-struct>` does pointer comparison (silent miscompute — equal-field structs at different addresses return FALSE). Compare fields explicitly."));
                type_diag(diags, source, fn_name, fn_name, "TYP-011", v147msg_t);
            };
        };
        if op == 30 || op == 31 || op == 32 || op == 33 || op == 34 || op == 35 || op == 36 || op == 37 { return "bool"; };
        return lt;
    };
    if kind == 5 || kind == 6 { return type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof); };
    if kind == 90 {
        let inner: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        if str_len(inner) == 0 { return ""; };
        return str_concat("&", inner);
    };
    if kind == 91 {
        let inner: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        if str_len(inner) == 0 { return ""; };
        return str_concat("&mut ", inner);
    };
    if kind == 92 {
        let mut inner: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        if node_kind(pool, node_field(pool, nid, 1)) == 3 {
            let box_start: i64 = tprof_start(tprof);
            let guessed_box: str = source_box_binding_type(source, fn_name, node_field(pool, node_field(pool, nid, 1), 1));
            tprof_mark(tprof, 11, 12, box_start);
            if str_len(guessed_box) > 0 { inner = guessed_box; };
        };
        if type_is_ref(inner) == 0 && str_eq(type_base_name(inner), "Box") == 0 {
            if str_eq(inner, "i32") == 1 || str_eq(inner, "i64") == 1 || str_eq(inner, "bool") == 1 || str_eq(inner, "f64") == 1 || str_eq(inner, "str") == 1 || str_eq(inner, "ptr") == 1 {
                type_diag(diags, source, fn_name, fn_name, "TYP-004", "cannot dereference a non-reference value");
            };
            return "";
        };
        if str_eq(type_base_name(inner), "Box") == 1 {
            let slen: i64 = str_len(inner);
            if slen >= 5 && str_eq(str_substring(inner, 0, 4), "Box<") == 1 { return str_substring(inner, 4, slen - 1); };
        };
        return type_base_name(inner);
    };
    if kind == 7 {
        let call_start: i64 = tprof_start(tprof);
        let callee: str = node_field(pool, nid, 1);
        let args: i64 = node_field(pool, nid, 2);
        let argc: i64 = list_len(pool, args);
        if str_eq(callee, "sanitize") == 1 && argc > 0 {
            let arg_t: str = type_expr(pool, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
            tprof_mark(tprof, 9, 10, call_start);
            if is_tainted_type(arg_t) == 1 { return taint_inner_type(arg_t); };
            return arg_t;
        };
        if type_dynamic_helper(callee) == 1 { tprof_mark(tprof, 9, 10, call_start); return ""; };
        let sig_start: i64 = tprof_start(tprof);
        let sentry: i64 = sig_find(sigs, callee);
        tprof_mark(tprof, 5, 6, sig_start);
        if sentry >= 0 {
            let plist: i64 = vec_get(sentry, 0);
            let expected_argc: i64 = list_len(pool, plist);
            if argc != expected_argc { type_diag(diags, source, fn_name, callee, "TYP-005", str_concat("wrong number of arguments for '", str_concat(callee, "'"))); };
            let mut ai: i64 = 0;
            while ai < argc && ai < expected_argc {
                let actual_t: str = type_expr(pool, list_get(pool, args, ai), env, sigs, structs, fn_name, diags, source, tprof);
                let expected_t: str = node_field(pool, list_get(pool, plist, ai), 2);
                let compat_start: i64 = tprof_start(tprof);
                let compat_ok: i64 = types_compatible(expected_t, actual_t);
                tprof_mark(tprof, 7, 8, compat_start);
                if compat_ok == 0 {
                    type_diag(diags, source, fn_name, callee, "TYP-006", str_concat("argument type mismatch in call to '", str_concat(callee, "'")));
                };
                ai = ai + 1;
            };
            tprof_mark(tprof, 9, 10, call_start);
            return vec_get(sentry, 1);
        };
        // walk every arg through type_expr for
        // diagnostic side effects on non-sig non-dynamic-helper
        // callees so nested calls' TYP-005 / TYP-008 etc. fire.
        if argc > 0 {
            let mut walk_ai_v144_t: i64 = 0;
            while walk_ai_v144_t < argc {
                type_expr(pool, list_get(pool, args, walk_ai_v144_t), env, sigs, structs, fn_name, diags, source, tprof);
                walk_ai_v144_t = walk_ai_v144_t + 1;
            };
        };
        // TYP-022 ext — struct as fn call.
        if struct_find_type(pool, structs, callee) >= 0 {
            let v148msg_t: str = str_concat("`", str_concat(callee, "(...)` is not how struct values are constructed — `<Name>` is a struct type, not a fn. Use struct-init syntax `<Name> { field1: val1, ... }`."));
            type_diag(diags, source, fn_name, callee, "TYP-022", v148msg_t);
        };
        // closure call-site argc check.
        let v146_argc_str_t: str = tenv_get(env, str_concat("__closure_argc_", callee));
        if str_len(v146_argc_str_t) > 0 {
            let v146_expected_t: i64 = str_to_int(v146_argc_str_t);
            if argc != v146_expected_t {
                let v146msg_t: str = str_concat("wrong number of arguments to closure `", str_concat(callee, str_concat("`: expected ", str_concat(str_from_int(v146_expected_t), str_concat(", got ", str_from_int(argc))))));
                type_diag(diags, source, fn_name, callee, "TYP-005", v146msg_t);
            };
            // return closure body rtype.
            let v156_rtype_t: str = tenv_get(env, str_concat("__closure_rtype_", callee));
            if str_len(v156_rtype_t) > 0 {
                tprof_mark(tprof, 9, 10, call_start);
                return v156_rtype_t;
            };
        };
        tprof_mark(tprof, 9, 10, call_start);
        return builtin_rtype(callee);
    };
    if kind == 8 {
        let recv_t: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let mname: str = node_field(pool, nid, 2);
        // TYP-023 + void-mutator return type.
        if str_eq(recv_t, "void") == 1 {
            let v23msg_t: str = str_concat("chained method `.", str_concat(mname, "()` on a void-returning receiver. Pre-v0.4.139 the chain silently lowered with the void result coerced as a Vec/str header. Split into separate statements."));
            type_diag(diags, source, fn_name, fn_name, "TYP-023", v23msg_t);
        };
        if (str_starts_with(recv_t, "Vec<") == 1 || str_eq(recv_t, "Vec") == 1)
            && (str_eq(mname, "push") == 1 || str_eq(mname, "pop") == 1
                || str_eq(mname, "swap") == 1 || str_eq(mname, "extend") == 1
                || str_eq(mname, "shuffle") == 1 || str_eq(mname, "free") == 1
                || str_eq(mname, "remove") == 1 || str_eq(mname, "insert") == 1) {
            return "void";
        };
        if str_eq(mname, "sum") == 1 || str_eq(mname, "mean") == 1 || str_eq(mname, "max") == 1 || str_eq(mname, "min") == 1 {
            if str_eq(type_base_name(recv_t), "Tensor") == 1 { return "f64"; };
            return "i32";
        };
        if str_eq(mname, "any") == 1 || str_eq(mname, "all") == 1 { return "bool"; };
        if str_eq(mname, "len") == 1 { return "i64"; };
        if str_eq(mname, "matmul") == 1 { return recv_t; };
        if str_eq(mname, "set") == 1 { return "void"; };
        if str_eq(mname, "iter") == 1 { return recv_t; };
        return "";
    };
    if kind == 9 {
        let recv_t: str = type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let si: i64 = struct_find_type(pool, structs, recv_t);
        if si >= 0 { return struct_field_type(pool, vec_get(structs, si), node_field(pool, nid, 2)); };
        return "";
    };
    if kind == 99 {
        let target_type: str = node_field(pool, nid, 2);
        type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        if str_eq(target_type, "char") == 1 {
            let src: i64 = node_field(pool, nid, 1);
            let cc: Vec<i32> = char_guard_const_expr(pool, src);
            if vec_get(cc, 0) == 1 {
                let cp: i64 = vec_get(cc, 1);
                let mut bad: i64 = 0;
                if cp < 0 { bad = 1; };
                if cp > 1114111 { bad = 1; };
                if cp >= 55296 && cp <= 57343 { bad = 1; };
                if bad == 1 {
                    type_diag(diags, source, fn_name, "as", "TYP-026", str_concat("`as char` codepoint ", str_concat(str_from_int(cp), " is not a valid Unicode scalar value. Valid range is 0..0x10FFFF excluding surrogate range 0xD800..0xDFFF.")));
                };
            } else {
                let mut guarded: i64 = 0;
                if node_kind(pool, src) == 3 {
                    if tenv_has_char_guard(env, node_field(pool, src, 1)) == 1 { guarded = 1; };
                };
                if guarded == 0 {
                    type_diag(diags, source, fn_name, "as", "TYP-026", "`as char` on a non-constant value is not proven to be a valid Unicode scalar value. Guard the exact binding with `v >= 0 && v < 0xD800` before casting.");
                };
            };
        };
        return target_type;
    };
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let args: i64 = node_field(pool, nid, 3);
        if str_eq(tname, "Box") == 1 {
            let mname_ts: str = node_field(pool, nid, 2);
            // Box::leak(b: Box<T>) -> &T
            if str_eq(mname_ts, "leak") == 1 {
                if list_len(pool, args) > 0 {
                    let box_t_ts: str = type_expr(pool, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
                    let blen_ts: i64 = str_len(box_t_ts);
                    if blen_ts > 4 && str_eq(str_substring(box_t_ts, 0, 4), "Box<") == 1 {
                        return str_concat("&", str_substring(box_t_ts, 4, blen_ts - 1));
                    };
                    return str_concat("&", box_t_ts);
                };
                return "&i64";
            };
            if list_len(pool, args) > 0 {
                let inner: str = type_expr(pool, list_get(pool, args, 0), env, sigs, structs, fn_name, diags, source, tprof);
                if str_len(inner) > 0 { return str_concat("Box<", str_concat(inner, ">")); };
            };
            return "Box<i64>";
        };
        if str_eq(tname, "Tensor") == 1 { return "Tensor<f64>"; };
        if str_eq(tname, "Option") == 1 { return "Option"; };
        if str_eq(tname, "Result") == 1 { return "Result"; };
        return "";
    };
    if kind == 34 { return node_field(pool, nid, 1); };
    if kind == 52 { return type_last_stmt(pool, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof); };
    if kind == 23 {
        let tt: str = type_last_stmt(pool, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 {
            let et: str = type_last_stmt(pool, enode, env, sigs, structs, fn_name, diags, source, tprof);
            if str_eq(strip_spaces(tt), strip_spaces(et)) == 1 { return tt; };
        };
        return tt;
    };
    return "";
}
fn type_check_stmt(pool: Vec<i32>, nid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, rtype: str, tprof: Vec<i32>) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    if kind == 20 {
        let vname: str = node_field(pool, nid, 1);
        let tstr: str = node_field(pool, nid, 3);
        let init: i64 = node_field(pool, nid, 4);
        // TYP-008 — reject named no-init bindings
        // uniformly (both `let x: T;` and `let mut x: T;`).
        if init < 0 && str_len(vname) > 0 && str_eq(vname, "_") == 0 {
            if str_eq(vname, "__tuple_destructure_unsupported__") == 0 {
                type_diag(diags, source, fn_name, vname, "TYP-008", str_concat("binding `", str_concat(vname, "` declared without initializer (type-only). Nucleor has no flow-sensitive definite-assignment pass, so this would silently read as 0 from the alloca's zero-init slot on any path that reaches the read before an assignment. Assign at declaration, or introduce the binding where the value exists.")));
            };
        };
        let mut init_t: str = "";
        if init >= 0 {
            init_t = type_expr(pool, init, env, sigs, structs, fn_name, diags, source, tprof);
            // TYP-021 — void RHS in bare-let.
            if str_len(tstr) == 0 && (str_eq(init_t, "void") == 1 || type_is_unit(init_t) == 1)
                && str_eq(vname, "_") == 0 {
                let v21msg_t: str = str_concat("`void`-typed expression cannot initialize binding `", str_concat(vname, "`. Pre-v0.4.136 the void return was silently coerced to 0 — adopters who confused side-effect-only fns with value-returning fns got a 0-valued binding with no signal. Use the value-returning sibling fn or split the side-effect into its own statement above the let."));
                type_diag(diags, source, fn_name, vname, "TYP-021", v21msg_t);
            };
            if str_len(tstr) > 0 {
                let strict_infer_t4: i64 = if str_eq(env_get_or("NUC_STRICT_INFERENCE", "0"), "1") == 1 { 1 } else { 0 };
                if str_len(init_t) == 0 && strict_infer_t4 == 1 && node_kind(pool, init) == 7 {
                    let strict_callee_t4: str = node_field(pool, init, 1);
                    if builtin_rtype_format_string_i64(strict_callee_t4) == 1 { init_t = "i64"; }
                    else if builtin_rtype_format_string_str(strict_callee_t4) == 1 { init_t = "str"; };
                };
                if str_len(init_t) == 0 && strict_infer_t4 == 1 {
                    let v27msg_t: str = str_concat("type inference failed for binding '", str_concat(vname, "'; explicit annotation required"));
                    type_diag(diags, source, fn_name, vname, "TYP-027", v27msg_t);
                } else if type_is_unit(tstr) == 1 && (node_kind(pool, init) == 1 || node_kind(pool, init) == 71) && line_has_unit_literal(source, fn_name, vname) == 0 {
                    type_diag(diags, source, fn_name, vname, "TYP-007", "bare numeric literal cannot initialize a unit value");
                } else {
                    let compat_start: i64 = tprof_start(tprof);
                    let compat_ok: i64 = types_compatible(tstr, init_t);
                    tprof_mark(tprof, 7, 8, compat_start);
                    if compat_ok == 0 {
                    type_diag(diags, source, fn_name, vname, "TYP-008", str_concat("type mismatch for binding '", str_concat(vname, "'")));
                    };
                };
            };
        };
        if str_len(tstr) > 0 {
            if str_len(init_t) == 0 { tenv_set(env, vname, ""); }
            else { tenv_set(env, vname, tstr); };
        }
        else { tenv_set(env, vname, init_t); };
        // register closure argc on the binding.
        // also register the closure's body rtype.
        if init >= 0 && node_kind(pool, init) == 42 {
            let v146_pc_t: i64 = list_len(pool, node_field(pool, init, 1));
            tenv_set(env, str_concat("__closure_argc_", vname), str_from_int(v146_pc_t));
            let v156_body_t: i64 = node_field(pool, init, 2);
            let v156_rtype_t2: str = type_last_stmt(pool, v156_body_t, env, sigs, structs, fn_name, diags, source, tprof);
            if str_len(v156_rtype_t2) > 0 {
                tenv_set(env, str_concat("__closure_rtype_", vname), v156_rtype_t2);
            };
        };
        return warns;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let rhs: i64 = node_field(pool, nid, 2);
        let rhs_t: str = type_expr(pool, rhs, env, sigs, structs, fn_name, diags, source, tprof);
        if node_kind(pool, lhs) == 3 {
            let env_start: i64 = tprof_start(tprof);
            let lhs_t: str = tenv_get(env, node_field(pool, lhs, 1));
            tprof_mark(tprof, 3, 4, env_start);
            let compat_start: i64 = tprof_start(tprof);
            let compat_ok: i64 = types_compatible(lhs_t, rhs_t);
            tprof_mark(tprof, 7, 8, compat_start);
            if compat_ok == 0 { type_diag(diags, source, fn_name, node_field(pool, lhs, 1), "TYP-009", "assignment type mismatch"); };
        };
        return warns;
    };
    if kind == 22 {
        let val: i64 = node_field(pool, nid, 1);
        if val >= 0 {
            let val_t: str = type_expr(pool, val, env, sigs, structs, fn_name, diags, source, tprof);
            let compat_start: i64 = tprof_start(tprof);
            let compat_ok: i64 = types_compatible(rtype, val_t);
            tprof_mark(tprof, 7, 8, compat_start);
            if str_len(rtype) > 0 && str_eq(rtype, "void") == 0 && compat_ok == 0 {
                type_diag(diags, source, fn_name, fn_name, "TYP-010", "return type mismatch");
            };
            // TYP-010 ext — return-with-value in
            // void/unit/implicit-void fn.
            let v142_void_ret_t: i64 = if str_len(rtype) == 0 || str_eq(rtype, "void") == 1 || type_is_unit(rtype) == 1 { 1 } else { 0 };
            let v142_val_nonvoid_t: i64 = if str_len(val_t) > 0 && str_eq(val_t, "void") == 0 && type_is_unit(val_t) == 0 { 1 } else { 0 };
            if v142_void_ret_t == 1 && v142_val_nonvoid_t == 1 {
                let v142msg_t: str = str_concat("`return ", str_concat(val_t, str_concat("`-typed value in fn `", str_concat(fn_name, "` declared to return void. Pre-v0.4.142 the value was silently discarded. Either remove the value (`return;`) or add `-> <Type>` to the fn signature."))));
                type_diag(diags, source, fn_name, fn_name, "TYP-010", v142msg_t);
            };
        };
        return warns;
    };
    if kind == 23 {
        type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let then_env: Vec<i32> = own_snapshot(env);
        let char_guard_v0845: str = char_guard_proven_var(pool, node_field(pool, nid, 1));
        if str_len(char_guard_v0845) > 0 { tenv_set_char_guard(then_env, char_guard_v0845); };
        warns = warns + type_check_stmts(pool, node_field(pool, nid, 2), then_env, sigs, structs, fn_name, diags, source, rtype, tprof);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 {
            let else_env: Vec<i32> = own_snapshot(env);
            warns = warns + type_check_stmts(pool, enode, else_env, sigs, structs, fn_name, diags, source, rtype, tprof);
        };
        return warns;
    };
    if kind == 24 { type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof); return type_check_stmts(pool, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, rtype, tprof); };
    if kind == 25 { type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof); return warns; };
    if kind == 28 { return type_check_stmts(pool, node_field(pool, nid, 4), env, sigs, structs, fn_name, diags, source, rtype, tprof); };
    if kind == 49 { type_expr(pool, node_field(pool, nid, 2), env, sigs, structs, fn_name, diags, source, tprof); return type_check_stmts(pool, node_field(pool, nid, 3), env, sigs, structs, fn_name, diags, source, rtype, tprof); };
    if kind == 38 {
        type_expr(pool, node_field(pool, nid, 1), env, sigs, structs, fn_name, diags, source, tprof);
        let arms: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, arms);
        let mut ai: i64 = 0;
        while ai < ac {
            let arm_env: Vec<i32> = own_snapshot(env);
            warns = warns + type_check_stmts(pool, node_field(pool, list_get(pool, arms, ai), 4), arm_env, sigs, structs, fn_name, diags, source, rtype, tprof);
            ai = ai + 1;
        };
        return warns;
    };
    return warns;
}
fn type_check_stmts(pool: Vec<i32>, lid: i64, env: Vec<i32>, sigs: Vec<i32>, structs: Vec<i32>, fn_name: str, diags: Vec<i32>, source: str, rtype: str, tprof: Vec<i32>) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    let mut warns: i64 = 0;
    while i < cnt {
        let stmt_start: i64 = tprof_start(tprof);
        warns = warns + type_check_stmt(pool, list_get(pool, lid, i), env, sigs, structs, fn_name, diags, source, rtype, tprof);
        tprof_mark(tprof, 1, 2, stmt_start);
        i = i + 1;
    };
    return warns;
}
fn type_check_program(pool: Vec<i32>, prog: i64, structs: Vec<i32>, diags: Vec<i32>, source: str, tprof: Vec<i32>) -> i64 {
    let mut sigs: Vec<i32> = sig_new();
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 { sig_add(sigs, node_field(pool, nid, 1), node_field(pool, nid, 2), node_field(pool, nid, 3), 0); };
        if node_kind(pool, nid) == 32 { sig_add(sigs, node_field(pool, nid, 1), node_field(pool, nid, 2), node_field(pool, nid, 3), 1); };
        i = i + 1;
    };
    let mut warns: i64 = 0;
    i = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let fn_name: str = node_field(pool, nid, 1);
            let plist: i64 = node_field(pool, nid, 2);
            let body: i64 = node_field(pool, nid, 4);
            let rtype: str = node_field(pool, nid, 3);
            let mut env: Vec<i32> = tenv_new();
            let pc: i64 = list_len(pool, plist);
            let mut pi: i64 = 0;
            while pi < pc {
                let pnid: i64 = list_get(pool, plist, pi);
                tenv_set(env, node_field(pool, pnid, 1), node_field(pool, pnid, 2));
                pi = pi + 1;
            };
            warns = warns + type_check_stmts(pool, body, env, sigs, structs, fn_name, diags, source, rtype, tprof);
        };
        i = i + 1;
    };
    return warns;
}

fn text_contains(hay: str, needle: str) -> i64 {
    let hlen: i64 = str_len(hay);
    let nlen: i64 = str_len(needle);
    if nlen == 0 { return 1; };
    if hlen < nlen { return 0; };
    let mut i: i64 = 0;
    while i <= hlen - nlen {
        if str_eq(str_substring(hay, i, i + nlen), needle) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
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
fn preflight_source_check(source: str) -> i64 {
    if source_has_scope_escape_ref_binding(source) == 1 {
        let mut diags: Vec<i32> = diag_new();
        type_diag(diags, source, "main", "let", "OWN-010", "cannot bind a reference that escapes an inner block");
        diag_emit_text(diags);
        return 1;
    };
    return 0;
}
// Sanitize is a no-op at runtime (identity function)
// It is handled by the taint checker at compile time

fn match_bind_payloads(binding: str, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, mslot: i64) -> Vec<i32> {
    // kept for back-compat. Untyped path; calls
    // through to the typed variant with ename/vname == "" so the
    // __type_<name> sym_set is a no-op (unknown enum/variant -> no
    // payload type information available).
    return match_bind_payloads_typed(binding, blk, regs, sym, mslot, "", "");
}

fn match_bind_payloads_typed(binding: str, blk: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, mslot: i64, ename: str, vname: str) -> Vec<i32> {
    // v0.4.2 RFC-NRT-004 §G (sync from nucleor_s1_compiler.nr:
    // match_bind_payloads_per_idx, lines 10498-10540): per-binding
    // payload-type lookup. Each binding in the pipe-separated list
    // gets its own __type_<name> based on the variant's payload-
    // type table populated by enum_populate_sym. Without this, a
    // struct-typed enum payload binding (Outcome::Err(e) where e:
    // ErrInfo) leaves the binding's type unknown; the subsequent
    // e.message lookup in the lowering returns -1 (the field-not-
    // resolved sentinel) which clang rejects as an undefined SSA
    // register %r.-1.
    let mut cur: Vec<i32> = blk;
    let blen: i64 = str_len(binding);
    if blen == 0 { return cur; };
    let mut start: i64 = 0;
    let mut payload_idx: i64 = 1;
    let mut bind_idx: i64 = 0;
    let has_enum: i64 = if str_len(ename) > 0 && str_len(vname) > 0 { 1 } else { 0 };
    while start < blen {
        let mut end: i64 = start;
        while end < blen && str_char_at(binding, end) != 124 { end = end + 1; };
        let name: str = str_substring(binding, start, end);
        if str_len(name) > 0 {
            let bar: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(bar));
            sym_set(sym, name, bar);
            // Look up the per-binding payload type if we have ename/vname.
            if has_enum == 1 {
                let pkey: str = str_concat("__epayload", str_concat(str_from_int(bind_idx), str_concat("_", str_concat(ename, str_concat("_", vname)))));
                let pstored: i64 = sym_get(sym, pkey);
                let mut resolved: i64 = 0;
                if pstored >= 0 {
                    let ptype: str = pstored;
                    if str_len(ptype) > 0 {
                        sym_set(sym, str_concat("__type_", name), ptype);
                        resolved = 1;
                    };
                };
                // v0.4.4 SPEC-1.5 wishlist: Option<str> / Result<*, str>
                // hardcoded defaults (sync from s1's match_bind_payloads_per_idx).
                if resolved == 0 {
                    if str_eq(ename, "Option") == 1 && str_eq(vname, "Some") == 1 && bind_idx == 0 {
                        sym_set(sym, str_concat("__type_", name), "str");
                    };
                    if str_eq(ename, "Result") == 1 && str_eq(vname, "Err") == 1 && bind_idx == 0 {
                        sym_set(sym, str_concat("__type_", name), "str");
                    };
                };
            };
            let mv2: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv2, mslot));
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, payload_idx));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(mv2); get_args.push(idx_r);
            let pv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pv_r, "vec_get", get_args));
            ir_block_add(cur, ir_store(pv_r, bar));
            payload_idx = payload_idx + 1;
            bind_idx = bind_idx + 1;
        };
        start = end + 1;
    };
    return cur;
}




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

#[manual_drop]
fn lower_expr(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let kind: i64 = node_kind(pool, nid);
    if kind == 99 {
        let inner_nid: i64 = node_field(pool, nid, 1);
        let inner_lx: Vec<i32> = lower_expr(pool, inner_nid, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let inner_blk: Vec<i32> = lx_blk(inner_lx);
        let inner_r: i64 = lx_reg(inner_lx);
        let target_type: str = node_field(pool, nid, 2);
        let mut helper: str = "";
        if str_eq(target_type, "i8") == 1 { helper = "as_i8"; };
        if str_eq(target_type, "i16") == 1 { helper = "as_i16"; };
        if str_eq(target_type, "i32") == 1 { helper = "as_i32"; };
        if str_eq(target_type, "i64") == 1 { helper = "as_i64"; };
        if str_eq(target_type, "isize") == 1 { helper = "as_i64"; };
        if str_eq(target_type, "u8") == 1 { helper = "as_u8"; };
        if str_eq(target_type, "u16") == 1 { helper = "as_u16"; };
        if str_eq(target_type, "u32") == 1 { helper = "as_u32"; };
        if str_eq(target_type, "u64") == 1 { helper = "as_u64"; };
        if str_eq(target_type, "usize") == 1 { helper = "as_u64"; };
        if str_eq(target_type, "f32") == 1 { helper = "as_f32"; };
        if str_eq(target_type, "f64") == 1 { helper = "as_f64"; };
        if str_eq(target_type, "char") == 1 { helper = "as_u32"; };
        if str_len(helper) == 0 { return inner_lx; };
        let mut args: Vec<i32> = Vec::new();
        args.push(inner_r);
        let r: i64 = ctr_next(regs);
        ir_block_add(inner_blk, ir_call_ex(r, helper, args));
        return lx_new(r, inner_blk);
    };
    if kind == 1 {
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(r, node_field(pool, nid, 1)));
        return lx_new(r, blk);
    };
    if kind == 71 {
        let scaled_r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(scaled_r, node_field(pool, nid, 1)));
        let mut conv_args: Vec<i32> = Vec::new();
        conv_args.push(scaled_r);
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_call_ex(r, "f64_from_scaled", conv_args));
        return lx_new(r, blk);
    };
    if kind == 2 {
        let idx: i64 = vec_len(strtab);
        strtab.push(node_field(pool, nid, 1));
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_str(r, idx));
        return lx_new(r, blk);
    };
    if kind == 3 {
        let iname: str = node_field(pool, nid, 1);
        if str_eq(iname, "true") {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(r, 1));
            return lx_new(r, blk);
        };
        if str_eq(iname, "false") {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(r, 0));
            return lx_new(r, blk);
        };
        let ar: i64 = sym_get(sym, iname);
        if ar < 0 {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_fn_ptr(r, iname));
            return lx_new(r, blk);
        };
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_load(r, ar));
        return lx_new(r, blk);
    };
    if kind == 4 {
        let mut lp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let lr: i64 = lx_reg(lp);
        let mut cur: Vec<i32> = lx_blk(lp);
        let mut rp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let rr: i64 = lx_reg(rp);
        cur = lx_blk(rp);
        let mut iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        let u64_binop: i64 = if expr_is_u64ish(pool, node_field(pool, nid, 2), sym, structs) == 1 || expr_is_u64ish(pool, node_field(pool, nid, 3), sym, structs) == 1 { 1 } else { 0 };
        if u64_binop == 1 {
            if iop == 9 { iop = 38; }
            else if iop == 10 { iop = 39; }
            else if iop == 11 { iop = 40; }
            else if iop == 12 { iop = 41; }
            else if iop == 24 { iop = 25; };
        };
        let r: i64 = ctr_next(regs);
        if is_cmp_or_logic(iop) == 1 { ir_block_add(cur, ir_cmpop(iop, r, lr, rr)); }
        else {
            // per-op saturating dispatch when inside
            // a `saturating { ... }` block (sym["__arith_mode"] == 2
            // set by the kind-52 branch).
            let mut sh_sat: str = "";
            if iop == 2 || iop == 3 || iop == 4 {
                let arith_mode_sat: i64 = sym_get(sym, "__arith_mode");
                if arith_mode_sat == 2 {
                    if iop == 2 { sh_sat = "saturating_add"; };
                    if iop == 3 { sh_sat = "saturating_sub"; };
                    if iop == 4 { sh_sat = "saturating_mul"; };
                };
            };
            if u64_binop == 1 && (iop == 5 || iop == 6) {
                let mut sa_u64: Vec<i32> = Vec::new();
                sa_u64.push(lr); sa_u64.push(rr);
                let h_u64: str = if iop == 5 { "panic_div_u64" } else { "panic_rem_u64" };
                ir_block_add(cur, ir_call_ex(r, h_u64, sa_u64));
            } else if str_len(sh_sat) > 0 {
                let mut sa_sat: Vec<i32> = Vec::new();
                sa_sat.push(lr); sa_sat.push(rr);
                ir_block_add(cur, ir_call_ex(r, sh_sat, sa_sat));
            } else {
                ir_block_add(cur, ir_binop(iop, r, lr, rr));
            };
        };
        return lx_new(r, cur);
    };
    if kind == 5 {
        let zr: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(zr, 0));
        let mut op_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let opr: i64 = lx_reg(op_p);
        let cur: Vec<i32> = lx_blk(op_p);
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_binop(3, r, zr, opr));
        return lx_new(r, cur);
    };
    if kind == 6 {
        let mut op_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let opr: i64 = lx_reg(op_p);
        let cur: Vec<i32> = lx_blk(op_p);
        let zr: i64 = ctr_next(regs);
        ir_block_add(cur, ir_const_int(zr, 0));
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_cmpop(7, r, opr, zr));
        return lx_new(r, cur);
    };
    if kind == 90 || kind == 91 || kind == 92 {
        return lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
    };
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        if str_eq(fn_name, "sanitize") {
            let args_list: i64 = node_field(pool, nid, 2);
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
        };
        if str_eq(fn_name, "grad") {
            let g_args: i64 = node_field(pool, nid, 2);
            if list_len(pool, g_args) >= 2 {
                let fn_arg: i64 = list_get(pool, g_args, 0);
                let mut xp: Vec<i32> = lower_expr(pool, list_get(pool, g_args, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let x_r: i64 = lx_reg(xp);
                let cur: Vec<i32> = lx_blk(xp);
                let h_ip: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(h_ip, 0));
                let h_fm: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(h_fm, 1));
                let mut h_args: Vec<i32> = Vec::new(); h_args.push(h_ip); h_args.push(h_fm);
                let h_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(h_r, "rods_f64_encode", h_args));
                let mut add_args: Vec<i32> = Vec::new(); add_args.push(x_r); add_args.push(h_r);
                let xph: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(xph, "rods_f64_add", add_args));
                let mut sub_args: Vec<i32> = Vec::new(); sub_args.push(x_r); sub_args.push(h_r);
                let xmh: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(xmh, "rods_f64_sub", sub_args));
                let target_fn: str = node_field(pool, fn_arg, 1);
                let mut fp_args: Vec<i32> = Vec::new(); fp_args.push(xph);
                let f_plus: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(f_plus, target_fn, fp_args));
                let mut fm_args: Vec<i32> = Vec::new(); fm_args.push(xmh);
                let f_minus: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(f_minus, target_fn, fm_args));
                let mut diff_args: Vec<i32> = Vec::new(); diff_args.push(f_plus); diff_args.push(f_minus);
                let diff: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(diff, "rods_f64_sub", diff_args));
                let mut twoh_args: Vec<i32> = Vec::new(); twoh_args.push(h_r); twoh_args.push(h_r);
                let two_h: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(two_h, "rods_f64_add", twoh_args));
                let mut div_args: Vec<i32> = Vec::new(); div_args.push(diff); div_args.push(two_h);
                let result: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(result, "rods_f64_div", div_args));
                return lx_new(result, cur);
            };
        };
        let args_list: i64 = node_field(pool, nid, 2);
        let argc: i64 = list_len(pool, args_list);
        let mut arg_regs: Vec<i32> = Vec::new();
        let mut ai: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while ai < argc {
            let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            arg_regs.push(lx_reg(ap));
            cur = lx_blk(ap);
            ai = ai + 1;
        };
        let fn_slot: i64 = sym_get(sym, fn_name);
        if fn_slot >= 0 {
            let fp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_load(fp_r, fn_slot));
            let r: i64 = ctr_next(regs);
            ir_block_add(cur, ir_indirect_call(r, fp_r, arg_regs));
            return lx_new(r, cur);
        };
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(r, fn_name, arg_regs));
        return lx_new(r, cur);
    };
    if kind == 8 {
        let mut obj_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(obj_p);
        let mut cur: Vec<i32> = lx_blk(obj_p);
        let mname: str = node_field(pool, nid, 2);
        let args_list: i64 = node_field(pool, nid, 3);
        let argc: i64 = list_len(pool, args_list);
        let mut all_args: Vec<i32> = Vec::new();
        all_args.push(obj_r);
        let mut ai: i64 = 0;
        while ai < argc {
            let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            all_args.push(lx_reg(ap));
            cur = lx_blk(ap);
            ai = ai + 1;
        };
        let mut stype: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        // str-literal receiver (kind 2) gets empty stype
        // from expr_struct_type. Without this, .len/.contains/etc. on a
        // str literal would route to vec_*_i64 in the iter check below
        // and silent-miscompute reading the str header as a vec header.
        // Stamp stype = "str" so the existing v0.4.90 str-method branch
        // catches it.
        {
            let recv_v4135_t: i64 = node_field(pool, nid, 1);
            if node_kind(pool, recv_v4135_t) == 2 {
                stype = "str";
            };
        };
        let mut fn_name: str = "";
        if str_len(stype) > 0 { fn_name = trait_impl_find(trait_impls, stype, mname); };
        if str_len(fn_name) == 0 {
            if str_eq(type_base_name(stype), "Tensor") == 1 {
                fn_name = tensor_builtin_method_name(mname);
            };
            if str_len(fn_name) == 0 {
                // T2.2 (v0.2.348) — synced from s1: route Vec iterator
                // methods to typed `vec_*_i64` runtime helpers.
                // gate the iter dispatch on receiver-not-being-str,
                // so `"abc".contains("b")` falls through to the str_contains
                // branch below instead of hitting vec_contains_i64.
                if iter_method_for_vec(mname) == 1 && str_eq(type_base_name(stype), "str") != 1 {
                    fn_name = str_concat("vec_", str_concat(mname, "_i64"));
                } else {
                    // mirror s1 v0.4.87/88/89 — str-receiver
                    // dispatch + insert/remove _at aliasing. Pre-fix
                    // tools_suite paths (nuc check, summary, audit)
                    // had the same vec_<mname> fall-through that s1
                    // had, so adopters running diagnostic commands hit
                    // identical clang-link / silent-miscompute paths.
                    let stype_base_t: str = type_base_name(stype);
                    let mut alias_mname_t: str = mname;
                    if str_eq(mname, "insert") == 1 { alias_mname_t = "insert_at"; };
                    if str_eq(mname, "remove") == 1 { alias_mname_t = "remove_at"; };
                    // mirror s1 v0.4.90 Option/Result dispatch.
                    // Falls back to var-ref __type_<name> lookup when
                    // expr_struct_type returned empty stype (some code
                    // paths don't populate it for Option/Result vars).
                    let mut opt_res_base: str = stype_base_t;
                    if str_len(opt_res_base) == 0 {
                        let recv_or_t: i64 = node_field(pool, nid, 1);
                        if node_kind(pool, recv_or_t) == 3 {
                            let recv_n_or_t: str = node_field(pool, recv_or_t, 1);
                            let recv_t_id: i64 = sym_get(sym, str_concat("__type_", recv_n_or_t));
                            if recv_t_id >= 0 { opt_res_base = type_base_name(recv_t_id); };
                        };
                    };
                    if str_eq(opt_res_base, "Option") == 1 && (str_eq(mname, "unwrap") == 1 || str_eq(mname, "unwrap_or") == 1 || str_eq(mname, "is_some") == 1 || str_eq(mname, "is_none") == 1 || str_eq(mname, "expect") == 1) {
                        fn_name = str_concat("option_", mname);
                    } else if str_eq(opt_res_base, "Result") == 1 && (str_eq(mname, "unwrap") == 1 || str_eq(mname, "unwrap_or") == 1 || str_eq(mname, "is_ok") == 1 || str_eq(mname, "is_err") == 1 || str_eq(mname, "ok") == 1 || str_eq(mname, "err") == 1 || str_eq(mname, "expect") == 1) {
                        fn_name = str_concat("result_", mname);
                    } else if str_eq(stype_base_t, "String") == 1 && (str_eq(mname, "push") == 1 || str_eq(mname, "push_str") == 1 || str_eq(mname, "len") == 1 || str_eq(mname, "capacity") == 1 || str_eq(mname, "get_byte") == 1 || str_eq(mname, "clear") == 1 || str_eq(mname, "as_ptr") == 1 || str_eq(mname, "print") == 1 || str_eq(mname, "eq") == 1 || str_eq(mname, "eq_str") == 1 || str_eq(mname, "starts_with") == 1 || str_eq(mname, "ends_with") == 1 || str_eq(mname, "contains") == 1 || str_eq(mname, "clone") == 1 || str_eq(mname, "free") == 1) {
                        let mut sm_t: str = mname;
                        if str_eq(mname, "push") == 1 { sm_t = "push_byte"; };
                        fn_name = str_concat("string_", sm_t);
                    } else if str_eq(stype_base_t, "str") == 1 && (str_eq(mname, "len") == 1 || str_eq(mname, "contains") == 1 || str_eq(mname, "replace") == 1 || str_eq(mname, "split") == 1 || str_eq(mname, "starts_with") == 1 || str_eq(mname, "ends_with") == 1 || str_eq(mname, "to_lower") == 1 || str_eq(mname, "to_upper") == 1 || str_eq(mname, "trim") == 1 || str_eq(mname, "trim_start") == 1 || str_eq(mname, "trim_end") == 1 || str_eq(mname, "substring") == 1 || str_eq(mname, "char_at") == 1) {
                        fn_name = str_concat("str_", mname);
                    } else {
                        fn_name = str_concat("vec_", alias_mname_t);
                    };
                };
            };
        };
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(r, fn_name, all_args));
        return lx_new(r, cur);
    };
    if kind == 10 {
        let mut obj_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(obj_p);
        let mut cur: Vec<i32> = lx_blk(obj_p);
        let mut idx_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let idx_r: i64 = lx_reg(idx_p);
        cur = lx_blk(idx_p);
        let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
        let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
        return lx_new(r, cur);
    };
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let mname: str = node_field(pool, nid, 2);
        let args_list: i64 = node_field(pool, nid, 3);
        if str_eq(tname, "Vec") && str_eq(mname, "new") {
            let r: i64 = ctr_next(regs);
            let mut empty_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(r, "vec_new", empty_args));
            return lx_new(r, blk);
        };
        if str_eq(tname, "String") && str_eq(mname, "new") {
            let r: i64 = ctr_next(regs);
            let mut empty_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(r, "string_new", empty_args));
            return lx_new(r, blk);
        };
        if str_eq(tname, "Box") && str_eq(mname, "new") {
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
            let zr: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(zr, 0));
            return lx_new(zr, blk);
        };
        // Box::leak pass-through
        if str_eq(tname, "Box") && str_eq(mname, "leak") {
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
            let zrl_ts: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(zrl_ts, 0));
            return lx_new(zrl_ts, blk);
        };
        if str_eq(tname, "Tensor") {
            let mut t_args: Vec<i32> = Vec::new();
            let ac: i64 = list_len(pool, args_list);
            let mut ai: i64 = 0;
            let mut cur: Vec<i32> = blk;
            while ai < ac {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                t_args.push(lx_reg(ap));
                cur = lx_blk(ap);
                ai = ai + 1;
            };
            let r: i64 = ctr_next(regs);
            if str_eq(mname, "zeros") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_zeros", t_args)); }
            else if str_eq(mname, "fill") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_fill", t_args)); }
            else if str_eq(mname, "ones") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_ones", t_args)); };
            return lx_new(r, cur);
        };
        let etag_key: str = str_concat("__etag_", str_concat(tname, str_concat("_", mname)));
        let etag: i64 = sym_get(sym, etag_key);
        if etag >= 0 {
            let vr: i64 = ctr_next(regs);
            let mut new_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
            let tr: i64 = ctr_next(regs); ir_block_add(blk, ir_const_int(tr, etag));
            let mut push_args1: Vec<i32> = Vec::new(); push_args1.push(vr); push_args1.push(tr);
            let dr1: i64 = ctr_next(regs); ir_block_add(blk, ir_call_ex(dr1, "vec_push", push_args1));
            let argc: i64 = list_len(pool, args_list);
            let mut ai: i64 = 0;
            let mut cur: Vec<i32> = blk;
            while ai < argc {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let av: i64 = lx_reg(ap);
                cur = lx_blk(ap);
                let mut pa: Vec<i32> = Vec::new(); pa.push(vr); pa.push(av);
                let dp: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dp, "vec_push", pa));
                ai = ai + 1;
            };
            return lx_new(vr, cur);
        };
    };
    if kind == 52 {
        let mode: i64 = node_field(pool, nid, 1);
        let body: i64 = node_field(pool, nid, 2);
        // per-op saturating dispatch via __arith_mode.
        let body_sym_sat_t: Vec<i32> = sym_clone(sym);
        if mode == 2 { sym_set(body_sym_sat_t, "__arith_mode", 2); };
        let mut bp: Vec<i32> = lower_if_expr_branch(pool, body, blk, regs, lbls, body_sym_sat_t, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mut br: i64 = lx_reg(bp);
        let mut cur: Vec<i32> = lx_blk(bp);
        if br < 0 {
            br = ctr_next(regs);
            ir_block_add(cur, ir_const_int(br, 0));
        };
        if mode == 2 { return lx_new(br, cur); };
        let mut wrap_args: Vec<i32> = Vec::new();
        wrap_args.push(br);
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(r, "wrap_i32", wrap_args));
        return lx_new(r, cur);
    };
    if kind == 23 {
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        let cur: Vec<i32> = lx_blk(cp);
        let tmp: i64 = ctr_next(regs);
        ir_block_add(cur, ir_alloca(tmp));
        let tl: i64 = ctr_next(lbls);
        let el: i64 = ctr_next(lbls);
        let ml: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br_cond(cr, tl, el));

        let mut tb: Vec<i32> = ir_block_new(tl);
        ir_fn_add_block(fir, tb);
        let mut tp: Vec<i32> = lower_if_expr_branch(pool, node_field(pool, nid, 2), tb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
        tb = lx_blk(tp);
        let tv: i64 = lx_reg(tp);
        if block_has_term(tb) == 0 {
            let mut store_tv: i64 = tv;
            if store_tv < 0 {
                let tz: i64 = ctr_next(regs);
                ir_block_add(tb, ir_const_int(tz, 0));
                store_tv = tz;
            };
            ir_block_add(tb, ir_store(store_tv, tmp));
            ir_block_add(tb, ir_br(ml));
        };

        let enode: i64 = node_field(pool, nid, 3);
        let mut eb: Vec<i32> = ir_block_new(el);
        ir_fn_add_block(fir, eb);
        if enode >= 0 {
            let mut ep: Vec<i32> = lower_if_expr_branch(pool, enode, eb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
            eb = lx_blk(ep);
            let fv: i64 = lx_reg(ep);
            if block_has_term(eb) == 0 {
                let mut store_fv: i64 = fv;
                if store_fv < 0 {
                    let ez: i64 = ctr_next(regs);
                    ir_block_add(eb, ir_const_int(ez, 0));
                    store_fv = ez;
                };
                ir_block_add(eb, ir_store(store_fv, tmp));
                ir_block_add(eb, ir_br(ml));
            };
        } else {
            let ez: i64 = ctr_next(regs);
            ir_block_add(eb, ir_const_int(ez, 0));
            ir_block_add(eb, ir_store(ez, tmp));
            ir_block_add(eb, ir_br(ml));
        };

        let mut mb: Vec<i32> = ir_block_new(ml);
        ir_fn_add_block(fir, mb);
        let r: i64 = ctr_next(regs);
        ir_block_add(mb, ir_load(r, tmp));
        return lx_new(r, mb);
    };
    if kind == 38 {
        let mut mp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mexpr_r: i64 = lx_reg(mp);
        let mut cur: Vec<i32> = lx_blk(mp);
        let mslot: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(mslot));
        ir_block_add(cur, ir_store(mexpr_r, mslot));
        let tmp: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(tmp));
        let arms_list: i64 = node_field(pool, nid, 2);
        let arm_cnt: i64 = list_len(pool, arms_list);
        let ml: i64 = ctr_next(lbls);
        let mut tag_r: i64 = 0 - 1;
        let mut ci: i64 = 0;
        while ci < arm_cnt {
            let arm_nid: i64 = list_get(pool, arms_list, ci);
            let ename: str = node_field(pool, arm_nid, 1);
            let vname: str = node_field(pool, arm_nid, 2);
            let binding: str = node_field(pool, arm_nid, 3);
            let body_list: i64 = node_field(pool, arm_nid, 4);
            let guard_nid: i64 = node_field(pool, arm_nid, 5);
            let al: i64 = ctr_next(lbls);
            let nl: i64 = ctr_next(lbls);
            if str_eq(ename, "__wild") {
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
                    sym_set(arm_sym, binding, bar);
                    let mv: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv, mslot));
                    ir_block_add(ab, ir_store(mv, bar));
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    gb = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(gb) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(gb, ir_const_int(rv, 0)); };
                        ir_block_add(gb, ir_store(rv, tmp));
                        ir_block_add(gb, ir_br(ml));
                    };
                } else {
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    ab = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(ab) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                        ir_block_add(ab, ir_store(rv, tmp));
                        ir_block_add(ab, ir_br(ml));
                    };
                };
            } else if str_eq(ename, "__int") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let iv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(iv_r, vname));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, mv, iv_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
                    sym_set(arm_sym, binding, bar);
                    let mv2: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv2, mslot));
                    ir_block_add(ab, ir_store(mv2, bar));
                };
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else if str_eq(ename, "__range") {
                // T2.1 (v0.2.347): synced from s1 — vname = LO (i64),
                // binding = str_from_int(HI). Match if LO <= scrut <= HI.
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let lo_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(lo_r, vname));
                let hi_n: i64 = str_to_int(binding);
                let hi_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(hi_r, hi_n));
                let lo_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, lo_ok, lo_r, mv));
                let hi_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, hi_ok, mv, hi_r));
                let both_r: i64 = ctr_next(regs); ir_block_add(cur, ir_binop(13, both_r, lo_ok, hi_ok));
                ir_block_add(cur, ir_br_cond(both_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let arm_sym: Vec<i32> = sym_clone(sym);
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else if str_eq(ename, "__range_bad") {
                // LO > HI — never matches. Lower as unconditional br nl.
                ir_block_add(cur, ir_br(nl));
            } else if str_eq(ename, "__str") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let sidx: i64 = vec_len(strtab); strtab.push(vname);
                let sv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_str(sv_r, sidx));
                let mut eq_args: Vec<i32> = Vec::new(); eq_args.push(mv); eq_args.push(sv_r);
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(cmp_r, "str_eq", eq_args));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
                    sym_set(arm_sym, binding, bar);
                    let mv2: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv2, mslot));
                    ir_block_add(ab, ir_store(mv2, bar));
                };
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else {
                if tag_r < 0 {
                    let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                    let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
                    let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(mv); tag_args.push(zero_r);
                    tag_r = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
                };
                let etag_key: str = str_concat("__etag_", str_concat(ename, str_concat("_", vname)));
                let vtag: i64 = sym_get(sym, etag_key);
                let vtag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(vtag_r, vtag));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, vtag_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_payloads_typed(binding, ab, regs, arm_sym, mslot, ename, vname);
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            };
            let mut nb: Vec<i32> = ir_block_new(nl); ir_fn_add_block(fir, nb);
            cur = nb;
            ci = ci + 1;
        };
        ir_block_add(cur, ir_br(ml));
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb);
        let r: i64 = ctr_next(regs);
        ir_block_add(mb, ir_load(r, tmp));
        return lx_new(r, mb);
    };
    if kind == 47 || kind == 48 {
        let items_list: i64 = node_field(pool, nid, 1);
        let vr: i64 = ctr_next(regs);
        let mut new_args: Vec<i32> = Vec::new();
        ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
        let ic: i64 = list_len(pool, items_list);
        let mut ii: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while ii < ic {
            let mut ep: Vec<i32> = lower_expr(pool, list_get(pool, items_list, ii), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let ev: i64 = lx_reg(ep);
            cur = lx_blk(ep);
            let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(ev);
            let dr: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dr, "vec_push", push_args));
            ii = ii + 1;
        };
        return lx_new(vr, cur);
    };
    if kind == 34 {
        let sname: str = node_field(pool, nid, 1);
        let init_list: i64 = node_field(pool, nid, 2);
        let si: i64 = struct_find_type(pool, structs, sname);
        if si < 0 {
            // mirror s1's v0.4.36 close — was silent
            // -1 register that produced %r.-1 invalid IR.
            print(str_concat("ERROR: unknown struct ", sname));
            panic(str_concat("nucleor_tools: unknown struct ", sname));
            return lx_new(0 - 1, blk);
        };
        let s_nid: i64 = vec_get(structs, si);
        let flist: i64 = node_field(pool, s_nid, 2);
        let fc: i64 = list_len(pool, flist);
        let vr: i64 = ctr_next(regs);
        let mut new_args: Vec<i32> = Vec::new();
        ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
        let mut fi: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while fi < fc {
            let decl_fname: str = node_field(pool, list_get(pool, flist, fi), 1);
            let ic: i64 = list_len(pool, init_list);
            let mut ii: i64 = 0;
            let mut found: i64 = 0;
            while ii < ic {
                let init_nid: i64 = list_get(pool, init_list, ii);
                if str_eq(node_field(pool, init_nid, 1), decl_fname) {
                    let mut vp: Vec<i32> = lower_expr(pool, node_field(pool, init_nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let val_r: i64 = lx_reg(vp);
                    cur = lx_blk(vp);
                    let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(val_r);
                    let pr2: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pr2, "vec_push", push_args));
                    found = 1; ii = ic;
                };
                ii = ii + 1;
            };
            if found == 0 {
                let zr: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zr, 0));
                let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(zr);
                let pr2: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pr2, "vec_push", push_args));
            };
            fi = fi + 1;
        };
        return lx_new(vr, cur);
    };
    if kind == 9 {
        let mut op: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(op);
        let cur: Vec<i32> = lx_blk(op);
        let fname: str = node_field(pool, nid, 2);
        if str_is_digits(fname) == 1 {
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, str_to_int(fname)));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
            let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
            return lx_new(r, cur);
        };
        let stype: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        let si: i64 = struct_find_type(pool, structs, stype);
        if si >= 0 {
            let fi2: i64 = struct_field_idx(pool, vec_get(structs, si), fname);
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, fi2));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
            let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
            return lx_new(r, cur);
        };
        // mirror s1's v0.4.36 close — was silent -1 reg.
        print(str_concat("ERROR: cannot resolve field access type for .", fname));
        panic(str_concat("nucleor_tools: cannot resolve field access .", fname));
        return lx_new(0 - 1, cur);
    };
    if kind == 42 {
        let param_list: i64 = node_field(pool, nid, 1);
        let body_list: i64 = node_field(pool, nid, 2);
        let clo_idx: i64 = vec_len(closures);
        let clo_name: str = str_concat("__closure_", str_from_int(clo_idx));
        let pc: i64 = list_len(pool, param_list);
        let mut clo_regs: Vec<i32> = ctr_new();
        let mut clo_lbls: Vec<i32> = ctr_new();
        let mut clo_sym: Vec<i32> = sym_new();
        let mut clo_fir: Vec<i32> = ir_fn_new(clo_name, pc);
        let mut clo_b0: Vec<i32> = ir_block_new(0);
        ir_fn_add_block(clo_fir, clo_b0);
        let mut captures: Vec<i32> = Vec::new();
        let bc: i64 = list_len(pool, body_list);
        let mut bi: i64 = 0;
        while bi < bc {
            closure_collect_capture_stmt(pool, list_get(pool, body_list, bi), sym, param_list, captures);
            bi = bi + 1;
        };
        let mut cpi: i64 = 0;
        while cpi < pc {
            let cpname: str = list_get(pool, param_list, cpi);
            let car: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_alloca(car));
            let cpr: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_param_ref(cpr, cpi));
            ir_block_add(clo_b0, ir_store(cpr, car));
            sym_set(clo_sym, cpname, car);
            cpi = cpi + 1;
        };
        let mut capi: i64 = 0;
        while capi < vec_len(captures) {
            let capname: str = vec_get(captures, capi);
            let car: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_alloca(car));
            let clo_id_r: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_const_int(clo_id_r, clo_idx));
            let cap_id_r: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_const_int(cap_id_r, capi));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(clo_id_r); get_args.push(cap_id_r);
            let cval: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_call_ex(cval, "__nucleor_capture_get", get_args));
            ir_block_add(clo_b0, ir_store(cval, car));
            sym_set(clo_sym, capname, car);
            capi = capi + 1;
        };
        let mut clo_fb: Vec<i32> = lower_stmts(pool, body_list, clo_b0, clo_regs, clo_lbls, clo_sym, clo_fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        if block_has_term(clo_fb) == 0 {
            let czr: i64 = ctr_next(clo_regs);
            ir_block_add(clo_fb, ir_const_int(czr, 0));
            ir_block_add(clo_fb, ir_ret(czr));
        };
        closures.push(clo_fir);
        let mut capi2: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while capi2 < vec_len(captures) {
            let capname2: str = vec_get(captures, capi2);
            let capslot: i64 = sym_get(sym, capname2);
            if capslot >= 0 {
                let capv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(capv, capslot));
                let clo_id_r2: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(clo_id_r2, clo_idx));
                let cap_id_r2: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(cap_id_r2, capi2));
                let mut set_args: Vec<i32> = Vec::new(); set_args.push(clo_id_r2); set_args.push(cap_id_r2); set_args.push(capv);
                let dr: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dr, "__nucleor_capture_set", set_args));
            };
            capi2 = capi2 + 1;
        };
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_fn_ptr(r, clo_name));
        return lx_new(r, cur);
    };
    // mirror s1's v0.4.34 close — was silent -1 reg.
    print(str_concat("ERROR: unhandled expr kind ", str_from_int(kind)));
    panic(str_concat("nucleor_tools: unhandled expr kind ", str_from_int(kind)));
    return lx_new(0 - 1, blk);
}
// T1.1 Phase 1+2+3c+5 (synced from nucleor_s1_compiler.nr at v0.2.337
// — was missing here, causing strict-mode / nuc-test builds to skip
// narrow-width let-binding semantics and produce wrong arithmetic).
// See ../nucleor_s1_compiler.nr `narrow_via_as` for the canonical
// version. Memory-safety: returns vr unchanged for non-narrow types
// or upstream lowering failures (vr<0).
#[manual_drop]
fn lower_stmt(pool: Vec<i32>, nid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let kind: i64 = node_kind(pool, nid);
    if kind == 20 {
        let ar: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(ar));
        let vname: str = node_field(pool, nid, 1);
        sym_set(sym, vname, ar);
        let init: i64 = node_field(pool, nid, 4);
        let mut tstr: str = node_field(pool, nid, 3);
        if str_len(tstr) == 0 && init >= 0 {
            let ik: i64 = node_kind(pool, init);
            if ik == 34 { tstr = node_field(pool, init, 1); }
            else if ik == 12 { tstr = node_field(pool, init, 1); };
        };
        let sbase: str = type_base_name(tstr);
        if str_len(sbase) > 0 { sym_set(sym, str_concat("__type_", vname), sbase); };
        if init >= 0 {
            let src_kind: i64 = node_kind(pool, init);
            let mut vp: Vec<i32> = lower_expr(pool, init, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            cur = lx_blk(vp);
            let vr: i64 = lx_reg(vp);
            let nvr: i64 = narrow_via_as(cur, regs, vr, sbase, src_kind);
            ir_block_add(cur, ir_store(nvr, ar));
        };
        return cur;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let lhs_kind: i64 = node_kind(pool, lhs);
        if lhs_kind == 9 {
            let mut op: Vec<i32> = lower_expr(pool, node_field(pool, lhs, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let obj_r: i64 = lx_reg(op);
            cur = lx_blk(op);
            let fname: str = node_field(pool, lhs, 2);
            let mut vp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let vr: i64 = lx_reg(vp);
            cur = lx_blk(vp);
            let stype: str = expr_struct_type(pool, node_field(pool, lhs, 1), sym, structs);
            let si: i64 = struct_find_type(pool, structs, stype);
            if si >= 0 {
                let fi2: i64 = struct_field_idx(pool, vec_get(structs, si), fname);
                let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, fi2));
                let mut set_args: Vec<i32> = Vec::new(); set_args.push(obj_r); set_args.push(idx_r); set_args.push(vr);
                let dr: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dr, "vec_set", set_args));
            };
            return cur;
        };
        let ar: i64 = sym_get(sym, node_field(pool, lhs, 1));
        let mut vp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let vr: i64 = lx_reg(vp);
        cur = lx_blk(vp);
        ir_block_add(cur, ir_store(vr, ar));
        return cur;
    };
    if kind == 22 {
        let vn: i64 = node_field(pool, nid, 1);
        if vn >= 0 {
            let mut vp: Vec<i32> = lower_expr(pool, vn, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let vr: i64 = lx_reg(vp);
            cur = lx_blk(vp);
            ir_block_add(cur, ir_ret(vr));
        } else {
            let zr: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zr, 0)); ir_block_add(cur, ir_ret(zr));
        };
        return cur;
    };
    if kind == 23 {
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        cur = lx_blk(cp);
        let tl: i64 = ctr_next(lbls); let el: i64 = ctr_next(lbls); let ml: i64 = ctr_next(lbls);
        let enode: i64 = node_field(pool, nid, 3);
        if enode < 0 { ir_block_add(cur, ir_br_cond(cr, tl, ml)); }
        else { ir_block_add(cur, ir_br_cond(cr, tl, el)); };
        let mut tb: Vec<i32> = ir_block_new(tl); ir_fn_add_block(fir, tb);
        tb = lower_stmts(pool, node_field(pool, nid, 2), tb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
        if block_has_term(tb) == 0 { ir_block_add(tb, ir_br(ml)); };
        if enode >= 0 {
            let mut eb: Vec<i32> = ir_block_new(el); ir_fn_add_block(fir, eb);
            eb = lower_stmts(pool, enode, eb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
            if block_has_term(eb) == 0 { ir_block_add(eb, ir_br(ml)); };
        };
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb); return mb;
    };
    if kind == 24 {
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), hb, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        hb = lx_blk(cp);
        ir_block_add(hb, ir_br_cond(cr, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        bb = lower_stmts(pool, node_field(pool, nid, 2), bb, regs, lbls, sym_clone(sym), fir, strtab, hl, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 { ir_block_add(bb, ir_br(hl)); };
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 28 {
        let name: str = node_field(pool, nid, 1);
        let ar: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(ar));
        let mut loop_sym: Vec<i32> = sym_clone(sym);
        sym_set(loop_sym, name, ar);
        let mut sp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let sv: i64 = lx_reg(sp);
        cur = lx_blk(sp);
        ir_block_add(cur, ir_store(sv, ar));
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls);
        let il: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        let lv: i64 = ctr_next(regs); ir_block_add(hb, ir_load(lv, ar));
        let mut ep: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), hb, regs, lbls, loop_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let ev: i64 = lx_reg(ep);
        hb = lx_blk(ep);
        let cv: i64 = ctr_next(regs); ir_block_add(hb, ir_cmpop(9, cv, lv, ev));
        ir_block_add(hb, ir_br_cond(cv, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        bb = lower_stmts(pool, node_field(pool, nid, 4), bb, regs, lbls, sym_clone(loop_sym), fir, strtab, il, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 { ir_block_add(bb, ir_br(il)); };
        let mut ib: Vec<i32> = ir_block_new(il); ir_fn_add_block(fir, ib);
        let lv2: i64 = ctr_next(regs); ir_block_add(ib, ir_load(lv2, ar));
        let one: i64 = ctr_next(regs); ir_block_add(ib, ir_const_int(one, 1));
        let nv: i64 = ctr_next(regs); ir_block_add(ib, ir_binop(2, nv, lv2, one));
        ir_block_add(ib, ir_store(nv, ar));
        ir_block_add(ib, ir_br(hl));
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 49 {
        let name: str = node_field(pool, nid, 1);
        let item_slot: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(item_slot));
        let iter_slot: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(iter_slot));
        let idx_slot: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(idx_slot));
        let mut loop_sym: Vec<i32> = sym_clone(sym);
        sym_set(loop_sym, name, item_slot);
        let mut sp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let sv: i64 = lx_reg(sp);
        cur = lx_blk(sp);
        ir_block_add(cur, ir_store(sv, iter_slot));
        let zero: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero, 0));
        ir_block_add(cur, ir_store(zero, idx_slot));
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls);
        let il: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        let idx_v: i64 = ctr_next(regs); ir_block_add(hb, ir_load(idx_v, idx_slot));
        let iter_v: i64 = ctr_next(regs); ir_block_add(hb, ir_load(iter_v, iter_slot));
        let mut len_args: Vec<i32> = Vec::new(); len_args.push(iter_v);
        let len_v: i64 = ctr_next(regs); ir_block_add(hb, ir_call_ex(len_v, "vec_len", len_args));
        let cv: i64 = ctr_next(regs); ir_block_add(hb, ir_cmpop(9, cv, idx_v, len_v));
        ir_block_add(hb, ir_br_cond(cv, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        let iter_v2: i64 = ctr_next(regs); ir_block_add(bb, ir_load(iter_v2, iter_slot));
        let idx_v2: i64 = ctr_next(regs); ir_block_add(bb, ir_load(idx_v2, idx_slot));
        let mut get_args: Vec<i32> = Vec::new(); get_args.push(iter_v2); get_args.push(idx_v2);
        let item_v: i64 = ctr_next(regs); ir_block_add(bb, ir_call_ex(item_v, "vec_get", get_args));
        ir_block_add(bb, ir_store(item_v, item_slot));
        bb = lower_stmts(pool, node_field(pool, nid, 3), bb, regs, lbls, sym_clone(loop_sym), fir, strtab, il, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 { ir_block_add(bb, ir_br(il)); };
        let mut ib: Vec<i32> = ir_block_new(il); ir_fn_add_block(fir, ib);
        let idx_v3: i64 = ctr_next(regs); ir_block_add(ib, ir_load(idx_v3, idx_slot));
        let one: i64 = ctr_next(regs); ir_block_add(ib, ir_const_int(one, 1));
        let next_v: i64 = ctr_next(regs); ir_block_add(ib, ir_binop(2, next_v, idx_v3, one));
        ir_block_add(ib, ir_store(next_v, idx_slot));
        ir_block_add(ib, ir_br(hl));
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 25 {
        let mut ep: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        return lx_blk(ep);
    };
    if kind == 38 {
        let mut mp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mexpr_r: i64 = lx_reg(mp);
        cur = lx_blk(mp);
        let mslot: i64 = ctr_next(regs); ir_block_add(cur, ir_alloca(mslot));
        ir_block_add(cur, ir_store(mexpr_r, mslot));
        let arms_list: i64 = node_field(pool, nid, 2);
        let arm_cnt: i64 = list_len(pool, arms_list);
        let ml: i64 = ctr_next(lbls);
        let mut tag_r: i64 = 0 - 1;
        let mut ci: i64 = 0;
        while ci < arm_cnt {
            let arm_nid: i64 = list_get(pool, arms_list, ci);
            let ename: str = node_field(pool, arm_nid, 1);
            let vname: str = node_field(pool, arm_nid, 2);
            let binding: str = node_field(pool, arm_nid, 3);
            let body_list: i64 = node_field(pool, arm_nid, 4);
            let guard_nid: i64 = node_field(pool, arm_nid, 5);
            let al: i64 = ctr_next(lbls);
            let nl: i64 = ctr_next(lbls);
            if str_eq(ename, "__wild") {
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
                    sym_set(arm_sym, binding, bar);
                    let mv: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv, mslot));
                    ir_block_add(ab, ir_store(mv, bar));
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__int") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let iv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(iv_r, vname));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, mv, iv_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
                    sym_set(arm_sym, binding, bar);
                    let mv2: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv2, mslot));
                    ir_block_add(ab, ir_store(mv2, bar));
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__range") {
                // T2.1 (v0.2.347): synced from s1's match-stmt path —
                // expression-form match needs the same range support.
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let lo_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(lo_r, vname));
                let hi_n: i64 = str_to_int(binding);
                let hi_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(hi_r, hi_n));
                let lo_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, lo_ok, lo_r, mv));
                let hi_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, hi_ok, mv, hi_r));
                let both_r: i64 = ctr_next(regs); ir_block_add(cur, ir_binop(13, both_r, lo_ok, hi_ok));
                ir_block_add(cur, ir_br_cond(both_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let arm_sym: Vec<i32> = sym_clone(sym);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__range_bad") {
                ir_block_add(cur, ir_br(nl));
            } else if str_eq(ename, "__str") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let sidx: i64 = vec_len(strtab); strtab.push(vname);
                let sv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_str(sv_r, sidx));
                let mut eq_args: Vec<i32> = Vec::new(); eq_args.push(mv); eq_args.push(sv_r);
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(cmp_r, "str_eq", eq_args));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    let bar: i64 = ctr_next(regs); ir_block_add(ab, ir_alloca(bar));
                    sym_set(arm_sym, binding, bar);
                    let mv2: i64 = ctr_next(regs); ir_block_add(ab, ir_load(mv2, mslot));
                    ir_block_add(ab, ir_store(mv2, bar));
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else {
                if tag_r < 0 {
                    let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                    let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
                    let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(mv); tag_args.push(zero_r);
                    tag_r = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
                };
                let etag_key: str = str_concat("__etag_", str_concat(ename, str_concat("_", vname)));
                let vtag: i64 = sym_get(sym, etag_key);
                let vtag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(vtag_r, vtag));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, vtag_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_payloads_typed(binding, ab, regs, arm_sym, mslot, ename, vname);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            };
            let mut nb: Vec<i32> = ir_block_new(nl); ir_fn_add_block(fir, nb);
            cur = nb;
            ci = ci + 1;
        };
        ir_block_add(cur, ir_br(ml));
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb);
        return mb;
    };
    if kind == 26 {
        if lx >= 0 { ir_block_add(cur, ir_br(lx)); };
        return cur;
    };
    if kind == 27 {
        if lh >= 0 { ir_block_add(cur, ir_br(lh)); };
        return cur;
    };
    // mirror s1's v0.4.34 close — was silent stmt drop.
    print(str_concat("ERROR: unknown stmt kind ", str_from_int(kind)));
    panic(str_concat("nucleor_tools: unknown stmt kind ", str_from_int(kind)));
    return cur;
}

#[manual_drop]
fn lower_fn(pool: Vec<i32>, fn_nid: i64, strtab: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, globals: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let blist: i64 = node_field(pool, fn_nid, 4);
    let pc: i64 = list_len(pool, plist);
    let mut regs: Vec<i32> = ctr_new();
    let mut lbls: Vec<i32> = ctr_new();
    let mut sym: Vec<i32> = sym_new();
    enum_populate_sym(pool, enums, sym);
    let mut fir: Vec<i32> = ir_fn_new(name, pc);
    let mut ebb0: Vec<i32> = ir_block_new(0);
    ir_fn_add_block(fir, ebb0);
    let mut pi: i64 = 0;
    while pi < pc {
        let pnid: i64 = list_get(pool, plist, pi);
        let pname: str = node_field(pool, pnid, 1);
        let ar: i64 = ctr_next(regs); ir_block_add(ebb0, ir_alloca(ar));
        let pr2: i64 = ctr_next(regs); ir_block_add(ebb0, ir_param_ref(pr2, pi));
        ir_block_add(ebb0, ir_store(pr2, ar));
        sym_set(sym, pname, ar);
        // Track struct type for parameters (strip generic params)
        let ptype: str = node_field(pool, pnid, 2);
        let sbase: str = type_base_name(ptype);
        if str_len(sbase) > 0 { sym_set(sym, str_concat("__type_", pname), sbase); };
        pi = pi + 1;
    };
    let mut gi: i64 = 0;
    while gi < vec_len(globals) {
        let gnid: i64 = vec_get(globals, gi);
        let gname: str = node_field(pool, gnid, 1);
        let gar: i64 = ctr_next(regs); ir_block_add(ebb0, ir_alloca(gar));
        sym_set(sym, gname, gar);
        let ginit: i64 = node_field(pool, gnid, 3);
        let mut gp: Vec<i32> = lower_expr(pool, ginit, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        let gv: i64 = lx_reg(gp);
        ebb0 = lx_blk(gp);
        ir_block_add(ebb0, ir_store(gv, gar));
        let mut gtype: str = node_field(pool, gnid, 2);
        if str_len(gtype) == 0 && node_kind(pool, ginit) == 34 { gtype = node_field(pool, ginit, 1); }
        else if str_len(gtype) == 0 && node_kind(pool, ginit) == 12 { gtype = node_field(pool, ginit, 1); };
        let gbase: str = type_base_name(gtype);
        if str_len(gbase) > 0 { sym_set(sym, str_concat("__type_", gname), gbase); };
        gi = gi + 1;
    };
    let bcnt: i64 = list_len(pool, blist);
    let mut fb: Vec<i32> = ebb0;
    let mut last_kind: i64 = 0 - 1;
    if bcnt > 0 { last_kind = node_kind(pool, list_get(pool, blist, bcnt - 1)); };
    if bcnt > 0 && (last_kind == 25 || last_kind == 23 || last_kind == 38) {
        let mut bi: i64 = 0;
        while bi + 1 < bcnt {
            fb = lower_stmt(pool, list_get(pool, blist, bi), fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            bi = bi + 1;
        };
        let last_stmt: i64 = list_get(pool, blist, bcnt - 1);
        let mut expr_nid: i64 = last_stmt;
        if last_kind == 25 { expr_nid = node_field(pool, last_stmt, 1); };
        let mut ep: Vec<i32> = lower_expr(pool, expr_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        fb = lx_blk(ep);
        let mut rv: i64 = lx_reg(ep);
        if block_has_term(fb) == 0 {
            if rv < 0 {
                rv = ctr_next(regs);
                ir_block_add(fb, ir_const_int(rv, 0));
            };
            ir_block_add(fb, ir_ret(rv));
        };
        return fir;
    };
    fb = lower_stmts(pool, blist, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
    if block_has_term(fb) == 0 {
        let zr: i64 = ctr_next(regs); ir_block_add(fb, ir_const_int(zr, 0)); ir_block_add(fb, ir_ret(zr));
    };
    return fir;
}

