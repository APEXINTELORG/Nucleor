// RFC-0063 Wave 1 shared helpers.
// Imported by both compiler entrypoints to retire byte-identical local duplicates.

#[manual_drop]
fn smap_new() -> Vec<i32> {
    return smap_new_cap(64);
}

#[manual_drop]
fn is_cmp_or_logic(iop: i64) -> i64 { if iop >= 7 && iop <= 14 { return 1; }; return 0; }

#[manual_drop]
fn find_column_in_source(source: str, fn_name: str, var_name: str) -> i64 {
    return vec_get(find_linecol_in_source(source, fn_name, var_name), 1);
}

#[manual_drop]
fn own_new() -> Vec<i32> { return Vec::new(); }

#[manual_drop]
fn own_set_s_raw(o: Vec<i32>, key: str, val: str) -> i64 { return own_put_s(o, key, val); }

#[manual_drop]
fn own_mut_borrowed(o: Vec<i32>, key: str) -> i64 { return own_get_i_raw(o, str_concat("__oi_mut_", key)); }

#[manual_drop]
fn own_set(o: Vec<i32>, name: str, state: i64) -> i64 { return own_put_i(o, str_concat("__os_", name), state); }

#[manual_drop]
fn own_get(o: Vec<i32>, name: str) -> i64 {
    let v: i64 = sym_get(o, str_concat("__os_", name));
    if v < 0 { return 1; };
    return v;
}

#[manual_drop]
fn own_set_type(o: Vec<i32>, name: str, tstr: str) -> i64 { return own_put_s(o, str_concat("__ot_", name), tstr); }

#[manual_drop]
fn own_get_type(o: Vec<i32>, name: str) -> str {
    let v: i64 = sym_get(o, str_concat("__ot_", name));
    if v < 0 { return ""; };
    return v;
}

#[manual_drop]
fn own_set_i_raw(o: Vec<i32>, key: str, val: i64) -> i64 { return own_put_i(o, key, val); }

#[manual_drop]
fn own_get_i_raw(o: Vec<i32>, key: str) -> i64 {
    let v: i64 = sym_get(o, key);
    if v < 0 { return 0; };
    return v;
}

#[manual_drop]
fn own_set_i(o: Vec<i32>, key: str, val: i64) -> i64 { return own_put_i(o, str_concat("__oi_", key), val); }

#[manual_drop]
fn own_get_i(o: Vec<i32>, key: str) -> i64 {
    let v: i64 = sym_get(o, str_concat("__oi_", key));
    if v < 0 { return 0; };
    return v;
}

#[manual_drop]
fn own_get_s_raw(o: Vec<i32>, key: str) -> str {
    let v: i64 = sym_get(o, key);
    if v < 0 { return ""; };
    return v;
}

#[manual_drop]
fn own_set_s(o: Vec<i32>, key: str, val: str) -> i64 { return own_put_s(o, str_concat("__os2_", key), val); }

#[manual_drop]
fn own_get_s(o: Vec<i32>, key: str) -> str {
    let v: i64 = sym_get(o, str_concat("__os2_", key));
    if v < 0 { return ""; };
    return v;
}

#[manual_drop]
fn own_diags(o: Vec<i32>) -> Vec<i32> {
    if vec_len(o) > 1 { return vec_get(o, 1); };
    return own_get_type(o, "__diags");
}

#[manual_drop]
fn own_source(o: Vec<i32>) -> str {
    if vec_len(o) > 3 { return vec_get(o, 3); };
    return own_get_type(o, "__source");
}

#[manual_drop]
fn own_shared_keys_vec(o: Vec<i32>) -> Vec<i32> {
    if vec_len(o) > 5 { return vec_get(o, 5); };
    return own_get_type(o, "__shared_keys");
}

#[manual_drop]
fn own_mut_keys_vec(o: Vec<i32>) -> Vec<i32> {
    if vec_len(o) > 7 { return vec_get(o, 7); };
    return own_get_type(o, "__mut_keys");
}

#[manual_drop]
fn own_scope_keys_vec(o: Vec<i32>) -> Vec<i32> {
    if vec_len(o) > 9 { return vec_get(o, 9); };
    return own_get_type(o, "__scope_keys");
}

#[manual_drop]
fn own_set_mutable(o: Vec<i32>, name: str, is_mut: i64) -> i64 { return own_set_i_raw(o, str_concat("__oi_mutable_", name), is_mut); }

#[manual_drop]
fn own_track_key(o: Vec<i32>, list_key: str, name: str) -> i64 {
    let keys: Vec<i32> = if str_eq(list_key, "__shared_keys") == 1 { own_shared_keys_vec(o) } else { if str_eq(list_key, "__mut_keys") == 1 { own_mut_keys_vec(o) } else { if str_eq(list_key, "__scope_keys") == 1 { own_scope_keys_vec(o) } else { own_get_type(o, list_key) } } };
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        if str_eq(vec_get(keys, i), name) == 1 { return 0; };
        i = i + 1;
    };
    keys.push(name);
    return 0;
}

#[manual_drop]
fn own_set_scope(o: Vec<i32>, name: str, depth: i64) -> i64 {
    own_track_key(o, "__scope_keys", name);
    return own_set_i_raw(o, str_concat("__oi_scope_", name), depth);
}

#[manual_drop]
fn own_get_scope(o: Vec<i32>, name: str) -> i64 { return own_get_i_raw(o, str_concat("__oi_scope_", name)); }

#[manual_drop]
fn own_set_param(o: Vec<i32>, name: str, is_param: i64) -> i64 { return own_set_i_raw(o, str_concat("__oi_param_", name), is_param); }

#[manual_drop]
fn own_get_param(o: Vec<i32>, name: str) -> i64 { return own_get_i_raw(o, str_concat("__oi_param_", name)); }

#[manual_drop]
fn own_set_ref_target(o: Vec<i32>, name: str, target: str) -> i64 { return own_set_s_raw(o, str_concat("__os2_ref_target_", name), target); }

#[manual_drop]
fn own_get_ref_target(o: Vec<i32>, name: str) -> str { return own_get_s_raw(o, str_concat("__os2_ref_target_", name)); }

#[manual_drop]
fn own_set_ref_kind(o: Vec<i32>, name: str, kind: i64) -> i64 { return own_set_i_raw(o, str_concat("__oi_ref_kind_", name), kind); }

#[manual_drop]
fn own_get_ref_kind(o: Vec<i32>, name: str) -> i64 { return own_get_i_raw(o, str_concat("__oi_ref_kind_", name)); }

#[manual_drop]
fn own_shared_borrows(o: Vec<i32>, key: str) -> i64 { return own_get_i_raw(o, str_concat("__oi_shared_", key)); }

#[manual_drop]
fn own_inc_shared(o: Vec<i32>, key: str) -> i64 {
    own_track_key(o, "__shared_keys", key);
    return own_set_i_raw(o, str_concat("__oi_shared_", key), own_shared_borrows(o, key) + 1);
}

#[manual_drop]
fn own_dec_shared(o: Vec<i32>, key: str) -> i64 {
    let cur: i64 = own_shared_borrows(o, key);
    if cur > 0 { own_set_i_raw(o, str_concat("__oi_shared_", key), cur - 1); };
    return 0;
}

#[manual_drop]
fn own_set_mut_borrow(o: Vec<i32>, key: str, on: i64) -> i64 {
    own_track_key(o, "__mut_keys", key);
    return own_set_i_raw(o, str_concat("__oi_mut_", key), on);
}

#[manual_drop]
fn own_has_shared_overlap(o: Vec<i32>, key: str) -> i64 {
    let keys: Vec<i32> = own_shared_keys_vec(o);
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        let target: str = vec_get(keys, i);
        if own_shared_borrows(o, target) > 0 && path_overlaps(target, key) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn own_has_mut_overlap(o: Vec<i32>, key: str) -> i64 {
    let keys: Vec<i32> = own_mut_keys_vec(o);
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        let target: str = vec_get(keys, i);
        if own_mut_borrowed(o, target) == 1 && path_overlaps(target, key) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn own_release_ref(o: Vec<i32>, name: str) -> i64 {
    let target: str = own_get_ref_target(o, name);
    if str_len(target) == 0 { return 0; };
    if own_get_ref_kind(o, name) == 1 { own_set_mut_borrow(o, target, 0); }
    else { own_dec_shared(o, target); };
    own_set_ref_target(o, name, "");
    own_set_ref_kind(o, name, 0);
    return 0;
}

#[manual_drop]
fn own_release_scope(o: Vec<i32>, depth: i64) -> i64 {
    let keys: Vec<i32> = own_scope_keys_vec(o);
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        let name: str = vec_get(keys, i);
        if own_get_scope(o, name) == depth { own_release_ref(o, name); };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn own_binding_move_type(tstr: str, pool: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    if is_copy_type(tstr, pool, structs, enums) == 0 { return 1; };
    let base: str = type_base_name(tstr);
    if str_eq(base, "String") { return 1; };
    return 0;
}

#[manual_drop]
fn own_diag_ex(own: Vec<i32>, fn_name: str, code: str, message: str, symbol: str, checker: str) -> i64 {
    let src: str = own_source(own);
    let diags: Vec<i32> = own_diags(own);
    let loc: Vec<i32> = find_linecol_in_source(src, fn_name, symbol);
    diag_add_ex(diags, "error", checker, code, message, fn_name, vec_get(loc, 0), vec_get(loc, 1), "");
    return 1;
}

#[manual_drop]
fn own_diag(own: Vec<i32>, fn_name: str, code: str, message: str, symbol: str) -> i64 {
    return own_diag_ex(own, fn_name, code, message, symbol, "ownership");
}

#[manual_drop]
fn own_box_hint(own: Vec<i32>, fn_name: str, name: str) -> str {
    let cache_key: str = str_concat("__box_hint_", name);
    let cached: str = own_get_s(own, cache_key);
    if str_eq(cached, "_none_") == 1 { return ""; };
    if str_len(cached) > 0 { return cached; };
    let source_text: str = own_source(own);
    let guessed: str = source_box_binding_type(source_text, fn_name, name);
    if str_len(guessed) > 0 {
        own_set_s(own, cache_key, guessed);
        return guessed;
    };
    if line_contains_text(source_text, fn_name, name, "Box<") == 1 {
        own_set_s(own, cache_key, "Box");
        return "Box";
    };
    own_set_s(own, cache_key, "_none_");
    return "";
}

#[manual_drop]
fn own_copy_ref_binding(own: Vec<i32>, src: str, dst: str, scope_depth: i64) -> i64 {
    let target: str = own_get_ref_target(own, src);
    if str_len(target) == 0 { return 0; };
    let kind: i64 = own_get_ref_kind(own, src);
    if kind == 0 { own_inc_shared(own, target); };
    own_set_ref_target(own, dst, target);
    own_set_ref_kind(own, dst, kind);
    own_set_scope(own, dst, scope_depth);
    return 0;
}

#[manual_drop]
fn own_register_borrow_expr(pool: Vec<i32>, nid: i64, own: Vec<i32>, fn_name: str, ref_name: str, scope_depth: i64, persist: i64) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind != 90 && kind != 91 { return 0; };
    let target_expr: i64 = node_field(pool, nid, 1);
    let key: str = expr_borrow_key(pool, target_expr, own);
    let root: str = expr_root_name(pool, target_expr, own);
    if str_len(key) == 0 || str_len(root) == 0 { return 0; };
    if own_get(own, root) == 2 {
        return own_diag(own, fn_name, "OWN-002", str_concat("cannot borrow moved value '", str_concat(root, "'")), root);
    };
    if kind == 90 {
        if own_has_mut_overlap(own, key) == 1 {
            return own_diag(own, fn_name, "OWN-005", str_concat("cannot shared-borrow '", str_concat(root, "': value is mutably borrowed")), root);
        };
        own_inc_shared(own, key);
        if persist == 1 && str_len(ref_name) > 0 {
            own_set_ref_target(own, ref_name, key);
            own_set_ref_kind(own, ref_name, 0);
            own_set_scope(own, ref_name, scope_depth);
        };
        return 0;
    };
    if own_get_mutable(own, root) == 0 && own_get_param(own, root) == 0 && type_is_mut_ref(own_get_type(own, root)) == 0 {
        return own_diag(own, fn_name, "OWN-011", str_concat("cannot mutably borrow immutable value '", str_concat(root, "'")), root);
    };
    if own_has_mut_overlap(own, key) == 1 || own_has_shared_overlap(own, key) == 1 {
        return own_diag(own, fn_name, "OWN-004", str_concat("cannot mutably borrow '", str_concat(root, "': value is already borrowed")), root);
    };
    own_set_mut_borrow(own, key, 1);
    if persist == 1 && str_len(ref_name) > 0 {
        own_set_ref_target(own, ref_name, key);
        own_set_ref_kind(own, ref_name, 1);
        own_set_scope(own, ref_name, scope_depth);
    };
    return 0;
}

#[manual_drop]
fn sig_new() -> Vec<i32> { return smap_new(); }

#[manual_drop]
fn tenv_new() -> Vec<i32> { return Vec::new(); }

#[manual_drop]
fn cache_v2_meta_path(key: str) -> str {
    return sanitize(str_concat(cache_v2_meta_dir(key), "/meta.json"));
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
fn expand_async_syntax(src: str) -> str {
    return expand_async_await(expand_async_strip_keyword(src));
}
