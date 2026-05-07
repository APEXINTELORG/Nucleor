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

#[manual_drop]
fn ir_op(ii: Vec<i32>) -> i64 { return vec_get(ii, 0); }

#[manual_drop]
fn ir_dest(ii: Vec<i32>) -> i64 { return vec_get(ii, 1); }

#[manual_drop]
fn ir_op1(ii: Vec<i32>) -> i64 { return vec_get(ii, 3); }

#[manual_drop]
fn ir_op2(ii: Vec<i32>) -> i64 { return vec_get(ii, 4); }

#[manual_drop]
fn ir_extra(ii: Vec<i32>) -> i64 { return vec_get(ii, 5); }

#[manual_drop]
fn ir_const_int(d: i64, v: i64) -> Vec<i32> { return ir_inst(0, d, 0, v, 0, 0); }

#[manual_drop]
fn ir_binop(iop: i64, d: i64, a: i64, b: i64) -> Vec<i32> { return ir_inst(iop, d, 0, a, b, 0); }

#[manual_drop]
fn ir_cmpop(iop: i64, d: i64, a: i64, b: i64) -> Vec<i32> { return ir_inst(iop, d, 0, a, b, 0); }

#[manual_drop]
fn ir_alloca(d: i64) -> Vec<i32> { return ir_inst(16, d, 0, 0, 0, 0); }

#[manual_drop]
fn ir_load(d: i64, ptr: i64) -> Vec<i32> { return ir_inst(17, d, 0, ptr, 0, 0); }

#[manual_drop]
fn ir_store(v: i64, ptr: i64) -> Vec<i32> { return ir_inst(18, 0, 0, v, ptr, 0); }

#[manual_drop]
fn ir_ret(v: i64) -> Vec<i32> { return ir_inst(20, 0, 0, v, 0, 0); }

#[manual_drop]
fn ir_br(lbl: i64) -> Vec<i32> { return ir_inst(21, 0, 0, lbl, 0, 0); }

#[manual_drop]
fn ir_br_cond(cond: i64, t: i64, f: i64) -> Vec<i32> { return ir_inst(22, 0, 0, cond, t, f); }

#[manual_drop]
fn ir_param_ref(d: i64, pidx: i64) -> Vec<i32> { return ir_inst(26, d, 0, pidx, 0, 0); }

#[manual_drop]
fn ir_const_str(d: i64, str_idx: i64) -> Vec<i32> { return ir_inst(27, d, 0, str_idx, 0, 0); }

#[manual_drop]
fn ir_block_label(b: Vec<i32>) -> i64 { return vec_get(b, 0); }

#[manual_drop]
fn ir_block_add(b: Vec<i32>, inst: Vec<i32>) -> i64 { let mut insts: Vec<i32> = vec_get(b, 1); insts.push(inst); return 0; }

#[manual_drop]
fn ir_block_inst_count(b: Vec<i32>) -> i64 { let insts: Vec<i32> = vec_get(b, 1); return vec_len(insts); }

#[manual_drop]
fn ir_block_get_inst(b: Vec<i32>, idx: i64) -> Vec<i32> { let insts: Vec<i32> = vec_get(b, 1); return vec_get(insts, idx); }

#[manual_drop]
fn ir_fn_name(f: Vec<i32>) -> str { return vec_get(f, 0); }

#[manual_drop]
fn ir_fn_param_count(f: Vec<i32>) -> i64 { return vec_get(f, 1); }

#[manual_drop]
fn ir_fn_add_block(f: Vec<i32>, blk: Vec<i32>) -> i64 { let mut b: Vec<i32> = vec_get(f, 3); b.push(blk); return 0; }

#[manual_drop]
fn ir_fn_block_count(f: Vec<i32>) -> i64 { let b: Vec<i32> = vec_get(f, 3); return vec_len(b); }

#[manual_drop]
fn ir_fn_get_block(f: Vec<i32>, idx: i64) -> Vec<i32> { let b: Vec<i32> = vec_get(f, 3); return vec_get(b, idx); }

#[manual_drop]
fn target_root_name(target: str) -> str {
    let mut i: i64 = 0;
    while i < str_len(target) {
        if str_char_at(target, i) == 46 { return str_substring(target, 0, i); };
        i = i + 1;
    };
    return target;
}

#[manual_drop]
fn cache_v2_strict_intrin_flag() -> str {
    let raw: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "1");
    if str_eq(raw, "0") == 1 { return "0"; };
    return "1";
}

#[manual_drop]
fn cache_v2_dbc_flag() -> str {
    let raw: str = env_get_or("NUCLEOR_DBC_MODE", "debug");
    if str_len(raw) == 0 { return "debug"; };
    return raw;
}

#[manual_drop]
fn cache_v2_prefix(key: str) -> str {
    if str_len(key) > 12 { return str_substring(key, 0, 12); };
    return key;
}

#[manual_drop]
fn cache_v2_dir(key: str) -> str {
    return sanitize(str_concat("target/.nuc_cache_v2/", cache_v2_prefix(key)));
}

#[manual_drop]
fn cache_v2_ll_path(key: str) -> str {
    return sanitize(str_concat(cache_v2_dir(key), str_concat("/", str_concat(key, ".ll"))));
}

#[manual_drop]
fn cache_v2_meta_dir(key: str) -> str {
    return sanitize(str_concat(cache_v2_dir(key), str_concat("/", key)));
}

#[manual_drop]
fn cache_v2_size_mb(ll: str) -> i64 {
    let n: i64 = str_len(ll);
    if n <= 0 { return 0; };
    return (n + 1048575) / 1048576;
}

#[manual_drop]
fn cache_v2_stats_enabled() -> i64 {
    if str_eq(env_get_or("NUCLEOR_CACHE_STATS", "0"), "1") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn cache_v2_print_stats(hits: i64, misses: i64) {
    if cache_v2_stats_enabled() == 1 {
        print(str_concat("cache stats: hits=", str_concat(str_from_int(hits), str_concat(" misses=", str_from_int(misses)))));
    };
}

#[manual_drop]
fn cache_v2_meta_json(input_filename: str, flags: str, compiler_version: str, key: str, ll: str) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\n");
    sb_append(sb, "  \"schema\": \"nuc-cache-v2\",\n");
    sb_append(sb, "  \"input_filename\": \""); sb_append(sb, cache_v2_json_escape(input_filename)); sb_append(sb, "\",\n");
    sb_append(sb, "  \"flags\": \""); sb_append(sb, cache_v2_json_escape(flags)); sb_append(sb, "\",\n");
    sb_append(sb, "  \"compiler_version\": \""); sb_append(sb, cache_v2_json_escape(compiler_version)); sb_append(sb, "\",\n");
    sb_append(sb, "  \"sha256\": \""); sb_append(sb, key); sb_append(sb, "\",\n");
    sb_append(sb, "  \"timestamp\": \""); sb_append(sb, cache_v2_json_escape(time_iso_now())); sb_append(sb, "\",\n");
    sb_append(sb, "  \"ll_bytes\": "); sb_append(sb, str_from_int(str_len(ll))); sb_append(sb, "\n");
    sb_append(sb, "}\n");
    return sb_to_str(sb);
}

#[manual_drop]
fn host_is_windows() -> i64 {
    // Detects host OS via the path separator returned by the runtime.
    // Used by link_native_module to choose Windows-only flags (/STACK: linker
    // syntax, .exe suffix, 2>NUL stderr redirect) vs POSIX equivalents.
    let sep: str = path_separator();
    if str_len(sep) >= 1 && str_char_at(sep, 0) == 92 { return 1; };
    return 0;
}

#[manual_drop]
fn host_exe_suffix() -> str {
    if host_is_windows() == 1 { return ".exe"; };
    return "";
}

#[manual_drop]
fn host_target_path_sep() -> str {
    if host_is_windows() == 1 { return "\\"; };
    return "/";
}

#[manual_drop]
fn host_null_redirect() -> str {
    if host_is_windows() == 1 { return " 2>NUL"; };
    return " 2>/dev/null";
}

#[manual_drop]
fn host_remove_file_quiet(path: str) -> i64 {
    if host_is_windows() == 1 {
        return system(str_concat("del /F /Q ", str_concat(path, " 2>NUL")));
    };
    return system(str_concat("rm -f ", str_concat(path, " 2>/dev/null")));
}

#[manual_drop]
fn write_ll_artifact_if_needed(ll_path: str, ll: str, cache_key: str) -> i64 {
    if str_len(cache_key) > 0 {
        let stamp_path: str = str_concat(ll_path, ".cachekey");
        if fs_exists(ll_path) == 1 && str_eq(file_read_string(stamp_path), cache_key) == 1 { return 0; };
        file_write_string(ll_path, ll);
        file_write_string(stamp_path, cache_key);
        return 1;
    };
    file_write_string(ll_path, ll);
    return 1;
}

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
