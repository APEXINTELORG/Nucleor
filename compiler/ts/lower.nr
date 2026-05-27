// =====================================================
// LOWERING (from T29, extended for STR_LIT, METHOD, QUAL_CALL)
// =====================================================
fn sym_get(s: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = vec_len(s) - 2;
    while i >= 0 { if str_eq(vec_get(s, i), name) { return vec_get(s, i + 1); }; i = i - 2; };
    return 0 - 1;
}
fn smap_has(m: Vec<i32>, key: str) -> i64 {
    if smap_find_slot(m, key) >= 0 { return 1; };
    return 0;
}
fn smap_clone(m: Vec<i32>) -> Vec<i32> {
    let cloned: Vec<i32> = smap_new_cap(smap_slots(m));
    let mut i: i64 = 0;
    let slots: i64 = smap_slots(m);
    while i < slots {
        if smap_slot_used(m, i) == 1 {
            smap_set(cloned, smap_slot_key(m, i), smap_slot_val(m, i));
        };
        i = i + 1;
    };
    return cloned;
}
fn smap_restore(dst: Vec<i32>, src: Vec<i32>) -> i64 {
    let cloned: Vec<i32> = smap_clone(src);
    vec_set(dst, 0, vec_get(cloned, 0));
    vec_set(dst, 1, vec_get(cloned, 1));
    vec_set(dst, 2, vec_get(cloned, 2));
    vec_set(dst, 3, vec_get(cloned, 3));
    vec_set(dst, 4, vec_get(cloned, 4));
    return 0;
}
fn lower_mark_error(sym: Vec<i32>) -> i64 { sym_set(sym, "__lower_error", 1); return 0 - 1; }
fn lower_has_error(sym: Vec<i32>) -> i64 { if sym_get(sym, "__lower_error") >= 0 { return 1; }; return 0; }
// Struct registry helpers




fn sendable_first_type(t: str) -> str {
    let n: i64 = str_len(t);
    let mut p: i64 = 0;
    while p < n && str_char_at(t, p) != 60 { p = p + 1; };
    if p >= n { return ""; };
    let start: i64 = p + 1;
    p = start;
    let mut depth: i64 = 1;
    while p < n {
        let c: i64 = str_char_at(t, p);
        if c == 60 { depth = depth + 1; }
        else if c == 62 {
            depth = depth - 1;
            if depth == 0 { return str_trim(str_substring(t, start, p)); };
        }
        else if c == 44 && depth == 1 { return str_trim(str_substring(t, start, p)); };
        p = p + 1;
    };
    return "";
}

fn sendable_type_forced_not(source: str, typ: str) -> i64 {
    let base: str = type_base_name(str_trim(typ));
    let pat: str = "#[not_sendable]";
    let plen: i64 = str_len(pat);
    let mut p: i64 = 0;
    let slen: i64 = str_len(source);
    while p + plen <= slen {
        let rel: i64 = str_index_of(str_substring(source, p, slen), pat);
        if rel < 0 { return 0; };
        let hit: i64 = p + rel + plen;
        let tail: str = str_substring(source, hit, slen);
        let sp_rel: i64 = str_index_of(tail, "struct ");
        if sp_rel < 0 { return 0; };
        let mut q: i64 = hit + sp_rel + 7;
        while q < slen && is_ws(str_char_at(source, q)) == 1 { q = q + 1; };
        let ns: i64 = q;
        while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
        if q > ns && str_eq(str_substring(source, ns, q), base) == 1 { return 1; };
        p = hit;
    };
    return 0;
}

fn sendable_type_ok(source: str, typ: str) -> i64 {
    let t: str = str_trim(typ);
    if str_len(t) == 0 { return 1; };
    if str_starts_with(t, "&mut ") == 1 { return 0; };
    if str_starts_with(t, "&") == 1 {
        return sendable_type_ok(source, str_trim(str_substring(t, 1, str_len(t))));
    };
    let base: str = type_base_name(t);
    if sendable_type_forced_not(source, base) == 1 { return 0; };
    if str_eq(base, "i8") == 1 { return 1; };
    if str_eq(base, "i16") == 1 { return 1; };
    if str_eq(base, "i32") == 1 { return 1; };
    if str_eq(base, "i64") == 1 { return 1; };
    if str_eq(base, "isize") == 1 { return 1; };
    if str_eq(base, "u8") == 1 { return 1; };
    if str_eq(base, "u16") == 1 { return 1; };
    if str_eq(base, "u32") == 1 { return 1; };
    if str_eq(base, "u64") == 1 { return 1; };
    if str_eq(base, "usize") == 1 { return 1; };
    if str_eq(base, "bool") == 1 { return 1; };
    if str_eq(base, "char") == 1 { return 1; };
    if str_eq(base, "f32") == 1 { return 1; };
    if str_eq(base, "f64") == 1 { return 1; };
    if str_eq(base, "str") == 1 { return 1; };
    if str_eq(base, "String") == 1 { return 1; };
    if sendable_type_has_impl(source, base) == 1 { return 1; };
    if str_eq(base, "Vec") == 1 { return sendable_type_ok(source, sendable_first_type(t)); };
    if str_eq(base, "Option") == 1 { return sendable_type_ok(source, sendable_first_type(t)); };
    if str_eq(base, "Box") == 1 { return sendable_type_ok(source, sendable_first_type(t)); };
    if str_eq(base, "Arc") == 1 { return sendable_type_ok(source, sendable_first_type(t)); };
    if str_eq(base, "Result") == 1 {
        if sendable_type_ok(source, sendable_first_type(t)) == 0 { return 0; };
        return sendable_type_ok(source, sendable_second_type(t));
    };
    return 0;
}

fn enforce_sendable_spawn_name(diags: Vec<i32>, source: str, call_name: str) -> i64 {
    let pat: str = str_concat(call_name, "(");
    let plen: i64 = str_len(pat);
    let slen: i64 = str_len(source);
    let mut added: i64 = 0;
    let mut p: i64 = 0;
    while p + plen <= slen {
        let rel: i64 = str_index_of(str_substring(source, p, slen), pat);
        if rel < 0 { return added; };
        let hit: i64 = p + rel;
        let open_pos: i64 = hit + plen - 1;
        let close_pos: i64 = sendable_find_matching_paren(source, open_pos);
        if close_pos < 0 { return added; };
        let comma: i64 = sendable_find_top_comma(source, open_pos + 1, close_pos);
        if comma > 0 {
            let arg: str = str_trim(str_substring(source, comma + 1, close_pos));
            let mut code: str = "";
            let mut msg: str = "";
            if str_starts_with(arg, "&mut ") == 1 {
                code = "RACE-005";
                msg = str_concat("`&mut` argument `", str_concat(arg, "` crosses a thread boundary"));
            } else if str_starts_with(arg, "&") == 0 && sendable_is_bare_ident(arg) == 1 {
                let ty: str = sendable_binding_type(source, arg);
                if str_len(ty) > 0 {
                    if sendable_type_forced_not(source, ty) == 1 {
                        code = "RACE-008";
                        msg = str_concat("`#[not_sendable]` type `", str_concat(type_base_name(ty), "` used where Sendable is required"));
                    } else if sendable_type_ok(source, ty) == 0 {
                        code = "RACE-001";
                        msg = str_concat("non-Sendable value `", str_concat(arg, str_concat("` of type `", str_concat(ty, "` crosses a thread boundary"))));
                    };
                };
            };
            if str_len(code) > 0 {
                let mut lc: Vec<i32> = find_linecol_in_source(source, arg, arg);
                diag_add_ex(diags, "error", "race", code, msg, call_name, vec_get(lc, 0), vec_get(lc, 1), "");
                added = added + 1;
            };
        };
        p = close_pos + 1;
    };
    return added;
}

fn sendable_collect_actor_names(source: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let pat: str = "//__NUC35A:";
    let plen: i64 = str_len(pat);
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p + plen <= slen {
        let rel: i64 = str_index_of(str_substring(source, p, slen), pat);
        if rel < 0 { return out; };
        let mut q: i64 = p + rel + plen;
        let ns: i64 = q;
        while q < slen && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
        if q > ns { out.push(str_substring(source, ns, q)); };
        p = q;
    };
    return out;
}


fn expr_struct_type(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let stype: i64 = sym_get(sym, str_concat("__type_", node_field(pool, nid, 1)));
        if stype < 0 { return ""; };
        return stype;
    };
    if kind == 34 { return type_base_name(node_field(pool, nid, 1)); };
    if kind == 90 || kind == 91 { return expr_struct_type(pool, node_field(pool, nid, 1), sym, structs); };
    if kind == 92 { return type_base_name(expr_struct_type(pool, node_field(pool, nid, 1), sym, structs)); };
    if kind == 9 {
        let outer_type: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(outer_type) == 0 { return ""; };
        let si: i64 = struct_find_type(pool, structs, outer_type);
        if si >= 0 { return type_base_name(struct_field_type(pool, vec_get(structs, si), node_field(pool, nid, 2))); };
    };
    return "";
}

// Enum helpers: pre-populate sym with variant tags and arg counts

