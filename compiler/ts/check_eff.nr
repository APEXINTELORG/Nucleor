// =====================================================
// EFFECT CHECKER (S11.6)
// =====================================================
fn is_effectful_builtin(name: str) -> i64 {
    if str_eq(name, "print") { return 1; }; if str_eq(name, "print_int") { return 1; };
    if str_eq(name, "print_f64") { return 1; }; if str_eq(name, "print_bool") { return 1; };
    if str_eq(name, "putchar") { return 1; };
    if str_eq(name, "file_write_string") { return 1; }; if str_eq(name, "file_read_string") { return 1; };
    if str_eq(name, "file_append_string") { return 1; };
    if str_eq(name, "system") { return 1; }; if str_eq(name, "exit") { return 1; };
    if str_eq(name, "getenv") { return 1; }; if str_eq(name, "getcwd") { return 1; };
    return 0;
}

fn effect_check_expr(pool: Vec<i32>, nid: i64, fn_name: str, pure_fns: Vec<i32>, diags: Vec<i32>, source: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    if kind == 1 || kind == 2 || kind == 3 || kind == 71 { return 0; };
    if kind == 4 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source);
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 3), fn_name, pure_fns, diags, source);
        return warns;
    };
    if kind == 5 || kind == 6 || kind == 90 || kind == 91 || kind == 92 { return effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source); };
    if kind == 7 {
        let callee: str = node_field(pool, nid, 1);
        if is_effectful_builtin(callee) == 1 {
            // Lane 3 (F-DIAG-007): EFF-001 was emitted at "warning"
            // here while the s1_compiler path emits "error" (lines
            // 11845/11867/11890/18571/18579/19060/19069). Same code,
            // same checker, same condition class → consistent
            // severity. Adopt "error" (matches the documented
            // RFC-0032 purity contract and the s1 enforcement
            // majority).
            diag_add(diags, "error", "effect", "EFF-001", str_concat("pure function calls effectful '", str_concat(callee, "'")), fn_name, find_in_source(source, fn_name, callee));
            warns = warns + 1;
        };
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac { warns = warns + effect_check_expr(pool, list_get(pool, args, ai), fn_name, pure_fns, diags, source); ai = ai + 1; };
        return warns;
    };
    if kind == 8 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source);
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac { warns = warns + effect_check_expr(pool, list_get(pool, args, ai), fn_name, pure_fns, diags, source); ai = ai + 1; };
        return warns;
    };
    if kind == 9 { return effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source); };
    if kind == 10 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source);
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source);
        return warns;
    };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            warns = warns + effect_check_expr(pool, list_get(pool, items, ii), fn_name, pure_fns, diags, source);
            ii = ii + 1;
        };
        return warns;
    };
    if kind == 34 {
        let inits: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, inits);
        let mut ii: i64 = 0;
        while ii < ic {
            warns = warns + effect_check_expr(pool, node_field(pool, list_get(pool, inits, ii), 2), fn_name, pure_fns, diags, source);
            ii = ii + 1;
        };
        return warns;
    };
    if kind == 52 { return effect_check_stmts(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source); };
    return warns;
}

fn effect_check_stmt(pool: Vec<i32>, nid: i64, fn_name: str, pure_fns: Vec<i32>, diags: Vec<i32>, source: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    if kind == 20 { let init: i64 = node_field(pool, nid, 4); if init >= 0 { warns = warns + effect_check_expr(pool, init, fn_name, pure_fns, diags, source); }; return warns; };
    if kind == 21 { return effect_check_expr(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source); };
    if kind == 22 { let val: i64 = node_field(pool, nid, 1); if val >= 0 { return effect_check_expr(pool, val, fn_name, pure_fns, diags, source); }; return 0; };
    if kind == 23 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source);
        warns = warns + effect_check_stmts(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 { warns = warns + effect_check_stmts(pool, enode, fn_name, pure_fns, diags, source); };
        return warns;
    };
    if kind == 24 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source);
        warns = warns + effect_check_stmts(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source);
        return warns;
    };
    if kind == 25 { return effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source); };
    if kind == 28 { return effect_check_stmts(pool, node_field(pool, nid, 4), fn_name, pure_fns, diags, source); };
    if kind == 49 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 2), fn_name, pure_fns, diags, source);
        warns = warns + effect_check_stmts(pool, node_field(pool, nid, 3), fn_name, pure_fns, diags, source);
        return warns;
    };
    if kind == 38 {
        warns = warns + effect_check_expr(pool, node_field(pool, nid, 1), fn_name, pure_fns, diags, source);
        let arms: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, arms);
        let mut ai: i64 = 0;
        while ai < ac { warns = warns + effect_check_stmts(pool, node_field(pool, list_get(pool, arms, ai), 4), fn_name, pure_fns, diags, source); ai = ai + 1; };
        return warns;
    };
    return warns;
}

fn effect_check_stmts(pool: Vec<i32>, lid: i64, fn_name: str, pure_fns: Vec<i32>, diags: Vec<i32>, source: str) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0; let mut warns: i64 = 0;
    while i < cnt { warns = warns + effect_check_stmt(pool, list_get(pool, lid, i), fn_name, pure_fns, diags, source); i = i + 1; };
    return warns;
}

fn effect_check_fn(pool: Vec<i32>, fn_nid: i64, pure_fns: Vec<i32>, diags: Vec<i32>, source: str, review_path: str, review_filter: str) -> i64 {
    let fn_name: str = node_field(pool, fn_nid, 1);
    let body: i64 = node_field(pool, fn_nid, 4);
    if body < 0 || body >= vec_len(pool) { return 0; };
    review_on_checker_enter(review_path, "effect", fn_name, review_filter);
    let w: i64 = effect_check_stmts(pool, body, fn_name, pure_fns, diags, source);
    // S12b: emit effect_violation details if findings > 0 (removable)
    if w > 0 && str_len(review_path) > 0 && review_filter_allows_function(review_filter, fn_name) == 1 {
        let mut esb: i64 = sb_new();
        sb_append(esb, "{\"schema_version\":\"1.0\",\"event\":\"effect_violation\",\"checker\":\"effect\",\"function\":\"");
        sb_append(esb, fn_name); sb_append(esb, "\",\"declared_effect\":\"pure\",\"actual_effect\":\"io\",\"findings\":");
        sb_append(esb, str_from_int(w)); sb_append(esb, "}");
        review_emit(review_path, sb_to_str(esb));
    };
    review_on_checker_exit(review_path, "effect", fn_name, w, review_filter);
    return w;
}

