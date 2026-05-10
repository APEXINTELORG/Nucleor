// RFC-0063 Wave 1 shared helpers.
// Imported by both compiler entrypoints to retire byte-identical local duplicates.

#[manual_drop]
fn smap_new() -> Vec<i32> {
    return smap_new_cap(64);
}

#[manual_drop]
fn is_cmp_or_logic(iop: i64) -> i64 { if iop >= 7 && iop <= 14 { return 1; }; if iop >= 38 && iop <= 41 { return 1; }; return 0; }

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
fn host_remove_dir_quiet(path: str) -> i64 {
    // Recursive directory remove that respects the host shell. Pre-fix
    // the clean command shelled out to `rmdir /S /Q ... 2>nul` on every
    // platform: on Linux that left target/.nuc_cache_v2/ untouched
    // (R4 in the 8C transcript) and leaked a literal file named `nul`
    // into the working directory because `2>nul` is cmd.exe-only
    // syntax.
    if host_is_windows() == 1 {
        return system(str_concat("rmdir /S /Q ", str_concat(path, " 2>NUL")));
    };
    return system(str_concat("rm -rf ", str_concat(path, " 2>/dev/null")));
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

#[manual_drop]
fn is_atomic_ordered_builtin(name: str) -> i64 {
    if str_starts_with(name, "atomic_i64_load_") == 1 {
        if str_ends_with(name, "_relaxed") == 1 || str_ends_with(name, "_acquire") == 1 || str_ends_with(name, "_seqcst") == 1 { return 1; };
        return 0;
    };
    if str_starts_with(name, "atomic_i64_store_") == 1 {
        if str_ends_with(name, "_relaxed") == 1 || str_ends_with(name, "_release") == 1 || str_ends_with(name, "_seqcst") == 1 { return 1; };
        return 0;
    };
    if str_starts_with(name, "atomic_i64_fetch_add_") == 1 || str_starts_with(name, "atomic_i64_fetch_sub_") == 1 || str_starts_with(name, "atomic_i64_fetch_and_") == 1 || str_starts_with(name, "atomic_i64_fetch_or_") == 1 || str_starts_with(name, "atomic_i64_fetch_xor_") == 1 {
        if str_ends_with(name, "_relaxed") == 1 || str_ends_with(name, "_acquire") == 1 || str_ends_with(name, "_release") == 1 || str_ends_with(name, "_acqrel") == 1 || str_ends_with(name, "_seqcst") == 1 { return 1; };
        return 0;
    };
    if str_starts_with(name, "atomic_i64_swap_") == 1 {
        if str_ends_with(name, "_relaxed") == 1 || str_ends_with(name, "_acquire") == 1 || str_ends_with(name, "_release") == 1 || str_ends_with(name, "_acqrel") == 1 || str_ends_with(name, "_seqcst") == 1 { return 1; };
        return 0;
    };
    if str_starts_with(name, "atomic_i64_compare_exchange_") == 1 {
        if str_ends_with(name, "_relaxed_relaxed") == 1 { return 1; };
        if str_ends_with(name, "_acquire_relaxed") == 1 || str_ends_with(name, "_acquire_acquire") == 1 { return 1; };
        if str_ends_with(name, "_release_relaxed") == 1 { return 1; };
        if str_ends_with(name, "_acqrel_relaxed") == 1 || str_ends_with(name, "_acqrel_acquire") == 1 { return 1; };
        if str_ends_with(name, "_seqcst_relaxed") == 1 || str_ends_with(name, "_seqcst_acquire") == 1 || str_ends_with(name, "_seqcst_seqcst") == 1 { return 1; };
        return 0;
    };
    return 0;
}

#[manual_drop]
fn atomic_tail_order_llvm(name: str) -> str {
    if str_contains(name, "_seqcst") == 1 { return "seq_cst"; };
    if str_contains(name, "_acqrel") == 1 { return "acq_rel"; };
    if str_contains(name, "_release") == 1 { return "release"; };
    if str_contains(name, "_acquire") == 1 { return "acquire"; };
    return "monotonic";
}

#[manual_drop]
fn atomic_cmpxchg_success_order_llvm(name: str) -> str {
    if str_contains(name, "compare_exchange_seqcst_") == 1 { return "seq_cst"; };
    if str_contains(name, "compare_exchange_acqrel_") == 1 { return "acq_rel"; };
    if str_contains(name, "compare_exchange_release_") == 1 { return "release"; };
    if str_contains(name, "compare_exchange_acquire_") == 1 { return "acquire"; };
    return "monotonic";
}

#[manual_drop]
fn atomic_cmpxchg_failure_order_llvm(name: str) -> str {
    if str_contains(name, "_seqcst_seqcst") == 1 { return "seq_cst"; };
    if str_contains(name, "_acquire_acquire") == 1 { return "acquire"; };
    if str_contains(name, "_acqrel_acquire") == 1 { return "acquire"; };
    if str_contains(name, "_seqcst_acquire") == 1 { return "acquire"; };
    return "monotonic";
}

#[manual_drop]
fn atomic_rmw_op_llvm(name: str) -> str {
    // Order matters: check `swap` before the fetch_* family. The new
    // ordered helper `atomic_i64_swap_<order>` lowers to `atomicrmw
    // xchg`. Default fall-through is `add` for fetch_add (no infix).
    if str_contains(name, "_swap_") == 1 { return "xchg"; };
    if str_contains(name, "fetch_sub") == 1 { return "sub"; };
    if str_contains(name, "fetch_and") == 1 { return "and"; };
    if str_contains(name, "fetch_or") == 1 { return "or"; };
    if str_contains(name, "fetch_xor") == 1 { return "xor"; };
    return "add";
}

#[manual_drop]
fn emit_atomic_ordered_call(sb: i64, name: str, d: i64, argc: i64, args: Vec<i32>) -> i64 {
    let ds: str = str_from_int(d);
    if argc <= 0 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
        return 0;
    };
    sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".atomic.ptr = inttoptr i64 %r.");
    sb_append(sb, str_from_int(vec_get(args, 0))); sb_append(sb, " to ptr\n");
    if str_starts_with(name, "atomic_i64_load_") == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = load atomic i64, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".atomic.ptr "); sb_append(sb, atomic_tail_order_llvm(name));
        sb_append(sb, ", align 8\n");
        return 0;
    };
    if str_starts_with(name, "atomic_i64_store_") == 1 {
        if argc > 1 {
            sb_append(sb, "  store atomic i64 %r."); sb_append(sb, str_from_int(vec_get(args, 1)));
            sb_append(sb, ", ptr %r."); sb_append(sb, ds); sb_append(sb, ".atomic.ptr ");
            sb_append(sb, atomic_tail_order_llvm(name)); sb_append(sb, ", align 8\n");
        };
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
        return 0;
    };
    if str_starts_with(name, "atomic_i64_compare_exchange_") == 1 {
        if argc >= 3 {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".atomic.pair = cmpxchg ptr %r.");
            sb_append(sb, ds); sb_append(sb, ".atomic.ptr, i64 %r.");
            sb_append(sb, str_from_int(vec_get(args, 1))); sb_append(sb, ", i64 %r.");
            sb_append(sb, str_from_int(vec_get(args, 2))); sb_append(sb, " ");
            sb_append(sb, atomic_cmpxchg_success_order_llvm(name)); sb_append(sb, " ");
            sb_append(sb, atomic_cmpxchg_failure_order_llvm(name)); sb_append(sb, "\n");
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = extractvalue { i64, i1 } %r.");
            sb_append(sb, ds); sb_append(sb, ".atomic.pair, 0\n");
        } else {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
        };
        return 0;
    };
    if argc > 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = atomicrmw ");
        sb_append(sb, atomic_rmw_op_llvm(name)); sb_append(sb, " ptr %r."); sb_append(sb, ds);
        sb_append(sb, ".atomic.ptr, i64 %r."); sb_append(sb, str_from_int(vec_get(args, 1)));
        sb_append(sb, " "); sb_append(sb, atomic_tail_order_llvm(name)); sb_append(sb, "\n");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
    };
    return 0;
}

#[manual_drop]
fn block_has_term(blk: Vec<i32>) -> i64 {
    let ic: i64 = ir_block_inst_count(blk);
    if ic == 0 { return 0; };
    let op: i64 = ir_op(ir_block_get_inst(blk, ic - 1));
    if op == 20 || op == 21 || op == 22 { return 1; }; return 0;
}

#[manual_drop]
fn cmap_new() -> Vec<i32> { let mut m: Vec<i32> = Vec::new(); return m; }

#[manual_drop]
fn cmap_set(m: Vec<i32>, reg: i64, val: i64) -> i64 {
    let mc: i64 = vec_len(m);
    let mut i: i64 = 0;
    while i < mc {
        if vec_get(m, i) == reg { vec_set(m, i + 1, val); return 0; };
        i = i + 2;
    };
    m.push(reg); m.push(val); return 0;
}

#[manual_drop]
fn cmap_get(m: Vec<i32>, reg: i64) -> i64 {
    let mc: i64 = vec_len(m);
    let mut i: i64 = 0;
    while i < mc {
        if vec_get(m, i) == reg { return vec_get(m, i + 1); };
        i = i + 2;
    };
    return 0 - 9999999;
}

#[manual_drop]
fn cmap_has(m: Vec<i32>, reg: i64) -> i64 {
    let mc: i64 = vec_len(m);
    let mut i: i64 = 0;
    while i < mc {
        if vec_get(m, i) == reg { return 1; };
        i = i + 2;
    };
    return 0;
}

#[manual_drop]
fn ctr_new() -> Vec<i32> { let mut c: Vec<i32> = Vec::new(); c.push(0); return c; }

#[manual_drop]
fn sym_new() -> Vec<i32> { return Vec::new(); }

#[manual_drop]
fn sym_set(s: Vec<i32>, name: str, reg: i64) -> i64 { s.push(name); s.push(reg); return 0; }

#[manual_drop]
fn sym_clone(s: Vec<i32>) -> Vec<i32> {
    let mut c: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    let cnt: i64 = vec_len(s);
    while i < cnt { c.push(vec_get(s, i)); i = i + 1; };
    return c;
}

#[manual_drop]
fn lx_new(reg: i64, blk: Vec<i32>) -> Vec<i32> {
    let mut p: Vec<i32> = Vec::new();
    p.push(reg);
    p.push(blk);
    return p;
}

#[manual_drop]
fn lx_reg(p: Vec<i32>) -> i64 { return vec_get(p, 0); }

#[manual_drop]
fn lx_blk(p: Vec<i32>) -> Vec<i32> { return vec_get(p, 1); }

#[manual_drop]
fn trait_impl_register(impls: Vec<i32>, type_name: str, method_name: str, mangled: str) -> i64 {
    impls.push(type_name); impls.push(method_name); impls.push(mangled); return 0;
}

#[manual_drop]
fn trait_impl_find(impls: Vec<i32>, type_name: str, method_name: str) -> str {
    let mut i: i64 = 0;
    while i < vec_len(impls) {
        if str_eq(vec_get(impls, i), type_name) == 1 && str_eq(vec_get(impls, i + 1), method_name) == 1 {
            return vec_get(impls, i + 2);
        };
        i = i + 3;
    };
    return "";
}

#[manual_drop]
fn smap_hash(key: str, cap: i64) -> i64 {
    let mut hash: i64 = 5381;
    let slen: i64 = str_len(key);
    let mut i: i64 = 0;
    while i < slen {
        hash = hash * 33 + str_char_at(key, i);
        if cap > 0 {
            hash = hash - (hash / cap) * cap;
            if hash < 0 { hash = 0 - hash; };
        };
        i = i + 1;
    };
    return hash;
}

#[manual_drop]
fn smap_new_cap(cap: i64) -> Vec<i32> {
    let mut keys: Vec<i32> = Vec::new();
    let mut vals: Vec<i32> = Vec::new();
    let mut occ: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < cap {
        keys.push("");
        vals.push(0 - 1);
        occ.push(0);
        i = i + 1;
    };
    let mut m: Vec<i32> = Vec::new();
    m.push(keys);
    m.push(vals);
    m.push(occ);
    m.push(0);
    m.push(cap);
    return m;
}

#[manual_drop]
fn smap_slots(m: Vec<i32>) -> i64 {
    return vec_get(m, 4);
}

#[manual_drop]
fn smap_slot_used(m: Vec<i32>, slot: i64) -> i64 {
    return vec_get(vec_get(m, 2), slot);
}

#[manual_drop]
fn smap_slot_key(m: Vec<i32>, slot: i64) -> str {
    return vec_get(vec_get(m, 0), slot);
}

#[manual_drop]
fn smap_slot_val(m: Vec<i32>, slot: i64) -> i64 {
    return vec_get(vec_get(m, 1), slot);
}

#[manual_drop]
fn smap_find_slot(m: Vec<i32>, key: str) -> i64 {
    let cap: i64 = smap_slots(m);
    let mut slot: i64 = smap_hash(key, cap);
    let mut probes: i64 = 0;
    while probes < cap {
        if smap_slot_used(m, slot) == 0 { return 0 - slot - 1; };
        if str_eq(smap_slot_key(m, slot), key) == 1 { return slot; };
        slot = slot + 1;
        if slot >= cap { slot = 0; };
        probes = probes + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn smap_grow(m: Vec<i32>) -> i64 {
    let old_cap: i64 = smap_slots(m);
    let grown: Vec<i32> = smap_new_cap(old_cap * 2);
    let mut i: i64 = 0;
    while i < old_cap {
        if smap_slot_used(m, i) == 1 {
            smap_set(grown, smap_slot_key(m, i), smap_slot_val(m, i));
        };
        i = i + 1;
    };
    vec_set(m, 0, vec_get(grown, 0));
    vec_set(m, 1, vec_get(grown, 1));
    vec_set(m, 2, vec_get(grown, 2));
    vec_set(m, 3, vec_get(grown, 3));
    vec_set(m, 4, vec_get(grown, 4));
    return 0;
}

#[manual_drop]
fn smap_set(m: Vec<i32>, key: str, value: i64) -> i64 {
    let count: i64 = vec_get(m, 3);
    let cap: i64 = smap_slots(m);
    if count * 2 >= cap { smap_grow(m); };
    let slot: i64 = smap_find_slot(m, key);
    if slot >= 0 {
        vec_set(vec_get(m, 1), slot, value);
        return 0;
    };
    let ins: i64 = 0 - slot - 1;
    vec_set(vec_get(m, 0), ins, str_concat("", key));
    vec_set(vec_get(m, 1), ins, value);
    vec_set(vec_get(m, 2), ins, 1);
    vec_set(m, 3, vec_get(m, 3) + 1);
    return 0;
}

#[manual_drop]
fn smap_get(m: Vec<i32>, key: str) -> i64 {
    let slot: i64 = smap_find_slot(m, key);
    if slot >= 0 { return smap_slot_val(m, slot); };
    return 0 - 1;
}

#[manual_drop]
fn struct_find(pool: Vec<i32>, structs: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(structs) {
        if str_eq(node_field(pool, vec_get(structs, i), 1), name) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn struct_find_type(pool: Vec<i32>, structs: Vec<i32>, name: str) -> i64 {
    return struct_find(pool, structs, type_base_name(name));
}

#[manual_drop]
fn struct_field_idx(pool: Vec<i32>, struct_nid: i64, fname: str) -> i64 {
    let flist: i64 = node_field(pool, struct_nid, 2);
    let cnt: i64 = list_len(pool, flist);
    let mut i: i64 = 0;
    while i < cnt {
        let fn_nid: i64 = list_get(pool, flist, i);
        if str_eq(node_field(pool, fn_nid, 1), fname) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn struct_field_type(pool: Vec<i32>, struct_nid: i64, fname: str) -> str {
    let flist: i64 = node_field(pool, struct_nid, 2);
    let cnt: i64 = list_len(pool, flist);
    let mut i: i64 = 0;
    while i < cnt {
        let fn_nid: i64 = list_get(pool, flist, i);
        if str_eq(node_field(pool, fn_nid, 1), fname) { return node_field(pool, fn_nid, 2); };
        i = i + 1;
    };
    return "";
}

#[manual_drop]
fn diag_new() -> Vec<i32> { return Vec::new(); }

#[manual_drop]
fn diag_add(diags: Vec<i32>, severity: str, checker: str, code: str, message: str, fn_name: str, line: i64) -> i64 {
    return diag_add_ex(diags, severity, checker, code, message, fn_name, line, 0, "");
}

#[manual_drop]
fn diag_count(diags: Vec<i32>) -> i64 { return vec_len(diags); }

#[manual_drop]
fn diag_get(diags: Vec<i32>, i: i64) -> Vec<i32> { return vec_get(diags, i); }

#[manual_drop]
fn byte_to_line(source: str, byte_off: i64) -> i64 {
    let slen: i64 = str_len(source);
    let mut line: i64 = 1;
    let mut i: i64 = 0;
    let limit: i64 = byte_off;
    if limit > slen { return 0; };
    while i < limit {
        if str_char_at(source, i) == 10 { line = line + 1; };
        i = i + 1;
    };
    return line;
}

#[manual_drop]
fn find_in_source(source: str, fn_name: str, var_name: str) -> i64 {
    return vec_get(find_linecol_in_source(source, fn_name, var_name), 0);
}

#[manual_drop]
fn path_overlaps(a: str, b: str) -> i64 {
    if str_len(a) == 0 || str_len(b) == 0 { return 0; };
    if str_eq(a, b) == 1 { return 1; };
    let ap: str = str_concat(a, ".");
    let bp: str = str_concat(b, ".");
    if str_starts_with(b, ap) == 1 { return 1; };
    if str_starts_with(a, bp) == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn enum_find(pool: Vec<i32>, enums: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(enums) {
        if str_eq(node_field(pool, vec_get(enums, i), 1), name) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn is_copy_type(tstr: str, pool: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    if str_len(tstr) == 0 { return 1; };
    if type_is_mut_ref(tstr) == 1 { return 0; };
    if type_is_shared_ref(tstr) == 1 { return 1; };
    if str_starts_with(tstr, "Box<") == 1 { return 0; };
    let base: str = type_base_name(tstr);
    if str_eq(base, "i64") { return 1; }; if str_eq(base, "i32") { return 1; };
    if str_eq(base, "str") { return 1; }; if str_eq(base, "bool") { return 1; };
    if str_eq(base, "f64") { return 1; }; if str_eq(base, "ptr") { return 1; };
    if str_eq(base, "void") { return 1; };
    if str_eq(base, "Vec") { return 1; }; if str_eq(base, "HashMap") { return 1; };
    if str_eq(base, "StringBuilder") { return 1; };
    if str_eq(base, "Box") { return 0; };
    if str_eq(base, "Option") { return 0; };
    if str_eq(base, "Result") { return 0; };
    if str_eq(base, "Arena") { return 1; };
    if str_eq(base, "DeviceBuffer") { return 0; };
    if str_eq(base, "RandomCap") { return 1; };
    if str_eq(base, "Tensor") { return 0; };
    // User-defined struct or enum is Move
    if struct_find(pool, structs, base) >= 0 { return 0; };
    if enum_find(pool, enums, base) >= 0 { return 0; };
    return 1; // unknown types default to Copy
}

#[manual_drop]
fn sig_find(sigs: Vec<i32>, name: str) -> i64 {
    return smap_get(sigs, name);
}

#[manual_drop]
fn sig_plist(sigs: Vec<i32>, name: str) -> i64 {
    let entry: i64 = sig_find(sigs, name);
    if entry < 0 { return 0 - 1; };
    return vec_get(entry, 0);
}

#[manual_drop]
fn sig_rtype(sigs: Vec<i32>, name: str) -> str {
    let entry: i64 = sig_find(sigs, name);
    if entry < 0 { return ""; };
    return vec_get(entry, 1);
}

#[manual_drop]
fn sig_is_extern(sigs: Vec<i32>, name: str) -> i64 {
    let entry: i64 = sig_find(sigs, name);
    if entry < 0 { return 0; };
    return vec_get(entry, 2);
}

#[manual_drop]
fn source_line(source: str, line: i64) -> str {
    let slen: i64 = str_len(source);
    let mut cur: i64 = 1;
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i < slen {
        if cur == line {
            let mut end: i64 = i;
            while end < slen && str_char_at(source, end) != 10 { end = end + 1; };
            return str_substring(source, start, end);
        };
        if str_char_at(source, i) == 10 { cur = cur + 1; start = i + 1; };
        i = i + 1;
    };
    if cur == line { return str_substring(source, start, slen); };
    return "";
}

#[manual_drop]
fn line_has_unit_literal(source: str, fn_name: str, symbol: str) -> i64 {
    let line: i64 = find_in_source(source, fn_name, symbol);
    let txt: str = source_line(source, line);
    let mut i: i64 = 0;
    while i < str_len(txt) {
        if str_char_at(txt, i) == 123 { return 1; };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn str_starts_with(s: str, prefix: str) -> i64 {
    let mut i: i64 = 0;
    while 1 == 1 {
        let pc: i64 = str_char_at(prefix, i);
        if pc == 0 { return 1; };
        let sc: i64 = str_char_at(s, i);
        if sc == 0 { return 0; };
        if sc != pc { return 0; };
        i = i + 1;
    };
    return 1;
}

#[manual_drop]
fn is_ws(c: i64) -> i64 { if c == 32 || c == 9 || c == 10 || c == 13 { return 1; }; return 0; }

#[manual_drop]
fn is_alpha(c: i64) -> i64 {
    if c >= 65 && c <= 90 { return 1; }; if c >= 97 && c <= 122 { return 1; };
    if c == 95 { return 1; }; return 0;
}

#[manual_drop]
fn is_alnum(c: i64) -> i64 { if is_alpha(c) == 1 || is_digit(c) == 1 { return 1; }; return 0; }

#[manual_drop]
fn tprof_start(prof: Vec<i32>) -> i64 {
    if tprof_enabled(prof) == 1 { return now_ms(); };
    return 0;
}

#[manual_drop]
fn tprof_mark(prof: Vec<i32>, count_idx: i64, time_idx: i64, start_ms: i64) -> i64 {
    if tprof_enabled(prof) == 1 {
        vec_set(prof, count_idx, vec_get(prof, count_idx) + 1);
        vec_set(prof, time_idx, vec_get(prof, time_idx) + (now_ms() - start_ms));
    };
    return 0;
}

#[manual_drop]
fn tprof_dump(prof: Vec<i32>) -> i64 {
    if tprof_enabled(prof) == 0 { return 0; };
    print(str_concat("  type profile stmt: ", str_concat(str_from_int(vec_get(prof, 1)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 2)), " ms")))));
    print(str_concat("  type profile env_lookup: ", str_concat(str_from_int(vec_get(prof, 3)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 4)), " ms")))));
    print(str_concat("  type profile sig_lookup: ", str_concat(str_from_int(vec_get(prof, 5)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 6)), " ms")))));
    print(str_concat("  type profile compat: ", str_concat(str_from_int(vec_get(prof, 7)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 8)), " ms")))));
    print(str_concat("  type profile call_expr: ", str_concat(str_from_int(vec_get(prof, 9)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 10)), " ms")))));
    print(str_concat("  type profile box_hint: ", str_concat(str_from_int(vec_get(prof, 11)), str_concat(" ops / ", str_concat(str_from_int(vec_get(prof, 12)), " ms")))));
    return 0;
}

#[manual_drop]
fn type_diag(diags: Vec<i32>, source: str, fn_name: str, symbol: str, code: str, message: str) -> i64 {
    let loc: Vec<i32> = find_linecol_in_source(source, fn_name, symbol);
    return diag_add_ex(diags, "error", "type", code, message, fn_name, vec_get(loc, 0), vec_get(loc, 1), "");
}

#[manual_drop]
fn tenv_set(env: Vec<i32>, name: str, tstr: str) -> i64 { env.push(name); env.push(tstr); return 0; }

#[manual_drop]
fn tenv_get(env: Vec<i32>, name: str) -> str {
    let v: i64 = sym_get(env, name);
    if v < 0 { return ""; };
    return v;
}

#[manual_drop]
fn unit_dim(t: str) -> str {
    if type_is_unit(t) == 0 { return ""; };
    let slen: i64 = str_len(t);
    let mut i: i64 = 5;
    while i < slen && str_char_at(t, i) != 44 { i = i + 1; };
    if i >= slen { return ""; };
    return strip_spaces(str_substring(t, i + 1, slen - 1));
}

#[manual_drop]
fn type_stmt_value(pool: Vec<i32>, nid: i64) -> i64 {
    let kind: i64 = node_kind(pool, nid);
    if kind == 25 || kind == 22 { return node_field(pool, nid, 1); };
    return 0 - 1;
}

#[manual_drop]
fn source_has_scope_escape_ref_binding(source: str) -> i64 {
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(source, lp) == 32 || str_char_at(source, lp) == 9) { lp = lp + 1; };
        let line: str = str_substring(source, lp, eol);
        if str_starts_with(line, "let ") == 1 && text_contains(line, ": &") == 1 && text_contains(line, "= {") == 1 { return 1; };
        p = eol + 1;
    };
    return 0;
}

#[manual_drop]
fn capture_has_name(caps: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(caps) {
        if str_eq(vec_get(caps, i), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn capture_param_has(pool: Vec<i32>, params: i64, name: str) -> i64 {
    let pc: i64 = list_len(pool, params);
    let mut i: i64 = 0;
    while i < pc {
        if str_eq(list_get(pool, params, i), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn build_mode_name(strict_mode: i64) -> str {
    if strict_mode == 1 { return "strict"; };
    return "fast";
}

#[manual_drop]
fn print_phase_time(enabled: i64, label: str, elapsed_ms: i64) {
    if enabled == 1 {
        print(str_concat("  time ", str_concat(label, str_concat(": ", str_concat(str_from_int(elapsed_ms), " ms")))));
    };
}

#[manual_drop]
fn collect_native_directives(imported: Vec<i32>) -> Vec<i32> {
    let mut all_links: i64 = sb_new();
    let mut all_cfiles: i64 = sb_new();
    let mut all_libpaths: i64 = sb_new();
    let mut di: i64 = 0;
    while di < vec_len(imported) {
        let imp_path: str = vec_get(imported, di);
        let imp_raw: str = file_read_string(imp_path);
        let imp_dir: str = extract_dir(imp_path);
        let imp_d: Vec<i32> = extract_directives(imp_raw, imp_dir);
        sb_append(all_links, vec_get(imp_d, 0));
        sb_append(all_cfiles, vec_get(imp_d, 1));
        sb_append(all_libpaths, vec_get(imp_d, 2));
        di = di + 1;
    };
    let mut out: Vec<i32> = Vec::new();
    out.push(sb_to_str(all_links));
    out.push(sb_to_str(all_cfiles));
    out.push(sb_to_str(all_libpaths));
    return out;
}

#[manual_drop]
fn path_exists(path: str) -> i64 {
    return fs_exists(sanitize(path));
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
fn opt_cse_block(blk: Vec<i32>) -> i64 {
    let insts: Vec<i32> = vec_get(blk, 1);
    let ic: i64 = vec_len(insts);
    if ic < 2 { return 0; };
    let mut seen_op: Vec<i32> = Vec::new();
    let mut seen_o1: Vec<i32> = Vec::new();
    let mut seen_o2: Vec<i32> = Vec::new();
    let mut seen_dst: Vec<i32> = Vec::new();
    let mut rewrites: i64 = 0;
    let mut i: i64 = 0;
    while i < ic {
        let inst: Vec<i32> = vec_get(insts, i);
        let op: i64 = ir_op(inst);
        let d: i64 = ir_dest(inst);
        let o1: i64 = ir_op1(inst);
        let o2: i64 = ir_op2(inst);
        if op == 0 || (op >= 2 && op <= 14) || op == 27 {
            let sc: i64 = vec_len(seen_op);
            let mut found: i64 = 0 - 1;
            let mut si: i64 = 0;
            while si < sc {
                if vec_get(seen_op, si) == op && vec_get(seen_o1, si) == o1 && vec_get(seen_o2, si) == o2 {
                    found = vec_get(seen_dst, si); si = sc;
                };
                si = si + 1;
            };
            if found >= 0 {
                // Rewrite all forward uses of d to found (opcode-aware)
                let mut j: i64 = i + 1;
                while j < ic {
                    let jinst: Vec<i32> = vec_get(insts, j);
                    let jop: i64 = ir_op(jinst);
                    if jop == 19 {
                        let args: Vec<i32> = vec_get(jinst, 5);
                        let ac: i64 = vec_len(args);
                        let mut ai: i64 = 0;
                        while ai < ac {
                            if vec_get(args, ai) == d { vec_set(args, ai, found); };
                            ai = ai + 1;
                        };
                    }
                    else if jop >= 2 && jop <= 14 {
                        // arithmetic/cmp/logic: op1 and op2 are registers
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        if ir_op2(jinst) == d { vec_set(jinst, 4, found); };
                    }
                    else if jop == 17 { if ir_op1(jinst) == d { vec_set(jinst, 3, found); }; }
                    else if jop == 18 {
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        if ir_op2(jinst) == d { vec_set(jinst, 4, found); };
                    }
                    else if jop == 20 { if ir_op1(jinst) == d { vec_set(jinst, 3, found); }; }
                    else if jop == 22 { if ir_op1(jinst) == d { vec_set(jinst, 3, found); }; }
                    else if jop == 28 {
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        if ir_op2(jinst) == d { vec_set(jinst, 4, found); };
                        if ir_extra(jinst) == d { vec_set(jinst, 5, found); };
                    }
                    else if jop == 30 {
                        if ir_op1(jinst) == d { vec_set(jinst, 3, found); };
                        let jargs: Vec<i32> = vec_get(jinst, 5);
                        let jac: i64 = vec_len(jargs);
                        let mut jai: i64 = 0;
                        while jai < jac {
                            if vec_get(jargs, jai) == d { vec_set(jargs, jai, found); };
                            jai = jai + 1;
                        };
                    };
                    // ops 0, 16, 21, 26, 27, 29: no register operands to rewrite
                    j = j + 1;
                };
                rewrites = rewrites + 1;
            } else {
                seen_op.push(op); seen_o1.push(o1); seen_o2.push(o2); seen_dst.push(d);
            };
        };
        i = i + 1;
    };
    return rewrites;
}

#[manual_drop]
fn hex_digit(v: i64) -> str {
    if v == 0 { return "0"; }; if v == 1 { return "1"; }; if v == 2 { return "2"; };
    if v == 3 { return "3"; }; if v == 4 { return "4"; }; if v == 5 { return "5"; };
    if v == 6 { return "6"; }; if v == 7 { return "7"; }; if v == 8 { return "8"; };
    if v == 9 { return "9"; }; if v == 10 { return "A"; }; if v == 11 { return "B"; };
    if v == 12 { return "C"; }; if v == 13 { return "D"; }; if v == 14 { return "E"; };
    if v == 15 { return "F"; }; return "0";
}

#[manual_drop]
fn hex_byte(v: i64) -> str {
    let hi: i64 = v / 16;
    let lo: i64 = v - hi * 16;
    return str_concat(hex_digit(hi), hex_digit(lo));
}

#[manual_drop]
fn emit_arith(sb: i64, on: str, d: i64, a: i64, b: i64) -> i64 {
    sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, " = "); sb_append(sb, on);
    sb_append(sb, " i64 %r."); sb_append(sb, str_from_int(a));
    sb_append(sb, ", %r."); sb_append(sb, str_from_int(b));
    sb_append(sb, "\n"); return 0;
}

#[manual_drop]
fn find_extern_idx(pool: Vec<i32>, externs: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(externs) {
        if str_eq(node_field(pool, vec_get(externs, i), 1), name) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn emit_extern_call(sb: i64, pool: Vec<i32>, externs: Vec<i32>, ext_idx: i64, d: i64, argc: i64, args: Vec<i32>) -> i64 {
    let nid: i64 = vec_get(externs, ext_idx);
    let name: str = node_field(pool, nid, 1);
    let plist: i64 = node_field(pool, nid, 2);
    let rtype: str = node_field(pool, nid, 3);
    let ds: str = str_from_int(d);
    let lr: str = nr_type_to_llvm(rtype);
    // Step 1: convert args from i64 to target types
    let mut ai: i64 = 0;
    while ai < argc {
        let pnid: i64 = list_get(pool, plist, ai);
        let ptype: str = node_field(pool, pnid, 2);
        let as2: str = str_from_int(ai);
        if is_ptr_type(ptype) == 1 {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, as2);
            sb_append(sb, " = inttoptr i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to ptr\n");
        } else if str_eq(ptype, "i32") {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, as2);
            sb_append(sb, " = trunc i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to i32\n");
        } else if str_eq(ptype, "f64") {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, as2);
            sb_append(sb, " = sitofp i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to double\n");
        };
        ai = ai + 1;
    };
    // Step 2: emit call
    if str_eq(lr, "void") {
        sb_append(sb, "  call void @"); sb_append(sb, name); sb_append(sb, "(");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".rv = call "); sb_append(sb, lr);
        sb_append(sb, " @"); sb_append(sb, name); sb_append(sb, "(");
    };
    // Step 3: emit args with correct types
    ai = 0;
    while ai < argc {
        if ai > 0 { sb_append(sb, ", "); };
        let pnid: i64 = list_get(pool, plist, ai);
        let ptype: str = node_field(pool, pnid, 2);
        let lt: str = nr_type_to_llvm(ptype);
        if is_ptr_type(ptype) == 1 || str_eq(ptype, "i32") || str_eq(ptype, "f64") {
            sb_append(sb, lt); sb_append(sb, " %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, str_from_int(ai));
        } else {
            sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai)));
        };
        ai = ai + 1;
    };
    sb_append(sb, ")\n");
    // Step 4: convert return from target type to i64
    if str_eq(lr, "void") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
    } else if str_eq(lr, "ptr") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = ptrtoint ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    } else if str_eq(lr, "i32") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = sext i32 %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    } else if str_eq(lr, "double") {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = fptosi double %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 %r.");
        sb_append(sb, ds); sb_append(sb, ".rv, 0\n");
    };
    return 0;
}

#[manual_drop]
fn emit_str_constants(strtab: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(strtab) {
        let s: str = vec_get(strtab, i);
        sb_append(sb, "@.str."); sb_append(sb, str_from_int(i));
        sb_append(sb, " = private unnamed_addr constant [");
        sb_append(sb, str_from_int(str_len(s) + 1));
        sb_append(sb, " x i8] c\"");
        sb_append(sb, escape_llvm_str(s));
        sb_append(sb, "\\00\"\n");
        i = i + 1;
    };
    if vec_len(strtab) > 0 { sb_append(sb, "\n"); };
    return sb_to_str(sb);
}

#[manual_drop]
fn is_ptr_type(t: str) -> i64 {
    if str_eq(t, "str") { return 1; };
    if str_eq(t, "ptr") { return 1; };
    return 0;
}

#[manual_drop]
fn tensor_builtin_method_name(mname: str) -> str {
    if str_eq(mname, "rows") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "cols") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "len") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "get") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "set") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "matmul") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "transpose") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sum") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "mean") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "max") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "min") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "variance") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "stddev") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "l1") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "l2") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "normalize_l2") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "zscore") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "clip") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "softmax_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "argmax_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "argmin_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "greedy") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "exp") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sqrt") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "abs") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "log") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sigmoid") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "tanh") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "relu") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "dot") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "reshape") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "flatten") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "add") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sub") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "mul") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "div") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "square") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "pow") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sin") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "cos") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "concat_rows") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "concat_cols") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "trace") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "outer") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "layernorm") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sum_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "mean_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "logsumexp_axis") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sample_topk_temp") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sample_nucleus_temp") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sample_eps") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sample_rank") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "sample_gumbel") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "median") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "percentile") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "mad") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "entropy") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "top2_gap") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "tile") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "repeat_rows") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "take_rows") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "drop_rows") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "minmax") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "center") == 1 { return str_concat("__nucleor_tensor_", mname); };
    if str_eq(mname, "reverse_cols") == 1 { return str_concat("__nucleor_tensor_", mname); };
    return "";
}

#[manual_drop]
fn type_is_shared_ref(t: str) -> i64 {
    let tlen: i64 = str_len(t);
    if tlen >= 1 && str_char_at(t, 0) == 38 && type_is_mut_ref(t) == 0 { return 1; };
    return 0;
}

#[manual_drop]
fn type_is_ref(t: str) -> i64 {
    if type_is_mut_ref(t) == 1 { return 1; };
    if str_len(t) >= 1 && str_char_at(t, 0) == 38 { return 1; };
    return 0;
}

#[manual_drop]
fn sendable_source_has_actor_decl(src: str) -> i64 {
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        } else if c == 34 || c == 39 {
            let quote: i64 = c;
            p = p + 1;
            while p < slen && str_char_at(src, p) != quote {
                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
        } else {
            if str_len(sendable_actor_decl_name_at(src, p)) > 0 { return 1; };
            p = p + 1;
        };
    };
    return 0;
}

#[manual_drop]
fn sendable_source_has_spawn_call(src: str) -> i64 {
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        } else if c == 34 || c == 39 {
            let quote: i64 = c;
            p = p + 1;
            while p < slen && str_char_at(src, p) != quote {
                if str_char_at(src, p) == 92 && p + 1 < slen { p = p + 2; }
                else { p = p + 1; };
            };
            if p < slen { p = p + 1; };
        } else {
            if str_eq_at(src, p, "async_spawn(") == 1 { return 1; };
            if str_eq_at(src, p, "thread_spawn(") == 1 { return 1; };
            if str_eq_at(src, p, "conc_spawn(") == 1 { return 1; };
            p = p + 1;
        };
    };
    return 0;
}

#[manual_drop]
fn sendable_is_bare_ident(text: str) -> i64 {
    let t: str = str_trim(text);
    let n: i64 = str_len(t);
    if n == 0 { return 0; };
    let mut i: i64 = 0;
    while i < n {
        let c: i64 = str_char_at(t, i);
        if i == 0 {
            if is_alpha(c) == 0 { if c != 95 { return 0; }; };
        } else {
            if is_alnum(c) == 0 { if c != 95 { return 0; }; };
        };
        i = i + 1;
    };
    return 1;
}

#[manual_drop]
fn sendable_second_type(t: str) -> str {
    let n: i64 = str_len(t);
    let mut p: i64 = 0;
    while p < n && str_char_at(t, p) != 60 { p = p + 1; };
    if p >= n { return ""; };
    p = p + 1;
    let mut depth: i64 = 1;
    let mut comma: i64 = 0 - 1;
    while p < n && comma < 0 {
        let c: i64 = str_char_at(t, p);
        if c == 60 { depth = depth + 1; }
        else if c == 62 { depth = depth - 1; }
        else if c == 44 && depth == 1 { comma = p; };
        p = p + 1;
    };
    if comma < 0 { return ""; };
    let start: i64 = comma + 1;
    let mut q: i64 = start;
    depth = 1;
    while q < n {
        let c2: i64 = str_char_at(t, q);
        if c2 == 60 { depth = depth + 1; }
        else if c2 == 62 {
            depth = depth - 1;
            if depth == 0 { return str_trim(str_substring(t, start, q)); };
        };
        q = q + 1;
    };
    return "";
}

#[manual_drop]
fn sendable_type_has_impl(source: str, typ: str) -> i64 {
    let base: str = type_base_name(str_trim(typ));
    if str_len(base) == 0 { return 0; };
    let pat: str = str_concat("impl Sendable for ", base);
    if str_index_of(source, pat) >= 0 { return 1; };
    return 0;
}

#[manual_drop]
fn sendable_binding_type(source: str, var_name: str) -> str {
    let pat1: str = str_concat("let ", str_concat(var_name, ":"));
    let pat2: str = str_concat("let mut ", str_concat(var_name, ":"));
    let mut p: i64 = str_index_of(source, pat1);
    let mut start: i64 = 0;
    if p >= 0 { start = p + str_len(pat1); }
    else {
        p = str_index_of(source, pat2);
        if p < 0 { return ""; };
        start = p + str_len(pat2);
    };
    let slen: i64 = str_len(source);
    let mut q: i64 = start;
    while q < slen {
        let c: i64 = str_char_at(source, q);
        if c == 61 || c == 59 || c == 10 || c == 13 { return str_trim(str_substring(source, start, q)); };
        q = q + 1;
    };
    return str_trim(str_substring(source, start, q));
}

#[manual_drop]
fn sendable_find_matching_paren(text: str, open_pos: i64) -> i64 {
    let n: i64 = str_len(text);
    let mut depth: i64 = 1;
    let mut p: i64 = open_pos + 1;
    while p < n {
        let c: i64 = str_char_at(text, p);
        if c == 34 {
            p = p + 1;
            while p < n && str_char_at(text, p) != 34 {
                if str_char_at(text, p) == 92 && p + 1 < n { p = p + 2; }
                else { p = p + 1; };
            };
        } else if c == 40 { depth = depth + 1; }
        else if c == 41 {
            depth = depth - 1;
            if depth == 0 { return p; };
        };
        p = p + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn sendable_find_top_comma(text: str, start: i64, end: i64) -> i64 {
    let mut depth: i64 = 0;
    let mut p: i64 = start;
    while p < end {
        let c: i64 = str_char_at(text, p);
        if c == 40 || c == 60 || c == 91 { depth = depth + 1; }
        else if c == 41 || c == 62 || c == 93 { if depth > 0 { depth = depth - 1; }; }
        else if c == 44 && depth == 0 { return p; };
        p = p + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn sendable_find_matching_brace(text: str, open_pos: i64) -> i64 {
    let n: i64 = str_len(text);
    let mut depth: i64 = 1;
    let mut p: i64 = open_pos + 1;
    while p < n {
        let c: i64 = str_char_at(text, p);
        if c == 123 { depth = depth + 1; }
        else if c == 125 {
            depth = depth - 1;
            if depth == 0 { return p; };
        };
        p = p + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn sendable_actor_fields(source: str, actor_name: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let pat: str = str_concat("struct ", str_concat(actor_name, " {"));
    let p: i64 = str_index_of(source, pat);
    if p < 0 { return out; };
    let open_pos: i64 = p + str_len(pat) - 1;
    let close_pos: i64 = sendable_find_matching_brace(source, open_pos);
    if close_pos < 0 { return out; };
    let mut q: i64 = open_pos + 1;
    while q < close_pos {
        while q < close_pos && (is_ws(str_char_at(source, q)) == 1 || str_char_at(source, q) == 44) { q = q + 1; };
        let ns: i64 = q;
        while q < close_pos && (is_alnum(str_char_at(source, q)) == 1 || str_char_at(source, q) == 95) { q = q + 1; };
        if q > ns {
            let name: str = str_substring(source, ns, q);
            while q < close_pos && is_ws(str_char_at(source, q)) == 1 { q = q + 1; };
            if q < close_pos && str_char_at(source, q) == 58 { out.push(name); };
        };
        while q < close_pos && str_char_at(source, q) != 44 && str_char_at(source, q) != 10 && str_char_at(source, q) != 13 { q = q + 1; };
        q = q + 1;
    };
    return out;
}

#[manual_drop]
fn enforce_sendable_actor_fields(diags: Vec<i32>, source: str) -> i64 {
    let actors: Vec<i32> = sendable_collect_actor_names(source);
    let mut added: i64 = 0;
    let mut ai: i64 = 0;
    while ai < vec_len(actors) {
        let actor_name: str = vec_get(actors, ai);
        let fields: Vec<i32> = sendable_actor_fields(source, actor_name);
        let vars: Vec<i32> = sendable_actor_vars(source, actor_name);
        let mut vi: i64 = 0;
        while vi < vec_len(vars) {
            let vname: str = vec_get(vars, vi);
            let mut fi: i64 = 0;
            while fi < vec_len(fields) {
                let field: str = vec_get(fields, fi);
                let pat: str = str_concat(vname, str_concat(".", field));
                if str_index_of(source, pat) >= 0 {
                    let msg: str = str_concat("actor `", str_concat(actor_name, str_concat("` field `", str_concat(field, "` cannot be accessed directly outside actor isolation"))));
                    let mut lc: Vec<i32> = find_linecol_in_source(source, pat, pat);
                    diag_add_ex(diags, "error", "race", "RACE-003", msg, actor_name, vec_get(lc, 0), vec_get(lc, 1), "");
                    added = added + 1;
                    fi = vec_len(fields);
                };
                fi = fi + 1;
            };
            vi = vi + 1;
        };
        ai = ai + 1;
    };
    return added;
}

#[manual_drop]
fn enforce_sendable_contracts(diags: Vec<i32>, source: str) -> Vec<i32> {
    let has_spawn: i64 = sendable_source_has_spawn_call(source);
    let has_actor: i64 = if str_index_of(source, "//__NUC35A:") >= 0 { 1 } else { 0 };
    if has_spawn == 0 && has_actor == 0 { return diags; };
    if has_spawn == 1 {
        enforce_sendable_spawn_name(diags, source, "async_spawn");
        enforce_sendable_spawn_name(diags, source, "thread_spawn");
        enforce_sendable_spawn_name(diags, source, "conc_spawn");
    };
    if has_actor == 1 { enforce_sendable_actor_fields(diags, source); };
    return diags;
}

#[manual_drop]
fn expr_borrow_key(pool: Vec<i32>, nid: i64, own: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if type_is_ref(own_get_type(own, name)) == 1 {
            let target: str = own_get_ref_target(own, name);
            if str_len(target) > 0 { return target; };
        };
        return name;
    };
    if kind == 9 {
        let base: str = expr_borrow_key(pool, node_field(pool, nid, 1), own);
        if str_len(base) == 0 { return ""; };
        return str_concat(base, str_concat(".", node_field(pool, nid, 2)));
    };
    if kind == 92 { return expr_borrow_key(pool, node_field(pool, nid, 1), own); };
    return "";
}

#[manual_drop]
fn expr_root_name(pool: Vec<i32>, nid: i64, own: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if type_is_ref(own_get_type(own, name)) == 1 {
            let target: str = own_get_ref_target(own, name);
            if str_len(target) > 0 {
                let mut i: i64 = 0;
                while i < str_len(target) {
                    if str_char_at(target, i) == 46 { return str_substring(target, 0, i); };
                    i = i + 1;
                };
                return target;
            };
        };
        return name;
    };
    if kind == 9 || kind == 90 || kind == 91 || kind == 92 { return expr_root_name(pool, node_field(pool, nid, 1), own); };
    return "";
}

#[manual_drop]
fn expr_escape_root(pool: Vec<i32>, nid: i64, own: Vec<i32>) -> str {
    if nid < 0 || nid >= vec_len(pool) { return ""; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 90 || kind == 91 {
        let root: str = expr_root_name(pool, node_field(pool, nid, 1), own);
        if own_get_param(own, root) == 0 { return root; };
        return "";
    };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        if type_is_ref(own_get_type(own, name)) == 1 {
            let target: str = own_get_ref_target(own, name);
            if str_len(target) > 0 {
                let root: str = target_root_name(target);
                if own_get_param(own, root) == 0 { return root; };
                return "";
            };
            if own_get_param(own, name) == 0 { return name; };
        };
        return "";
    };
    if kind == 52 {
        let body: i64 = node_field(pool, nid, 2);
        if body < 0 || body >= vec_len(pool) { return ""; };
        let cnt: i64 = list_len(pool, body);
        if cnt == 0 { return ""; };
        let last_stmt: i64 = list_get(pool, body, cnt - 1);
        let sk: i64 = node_kind(pool, last_stmt);
        if sk == 22 || sk == 25 { return expr_escape_root(pool, node_field(pool, last_stmt, 1), own); };
        if sk == 23 { return expr_escape_root(pool, last_stmt, own); };
        return "";
    };
    if kind == 23 {
        let mut root: str = expr_escape_root(pool, node_field(pool, nid, 2), own);
        if str_len(root) > 0 { return root; };
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 { return expr_escape_root(pool, enode, own); };
        return "";
    };
    return "";
}

#[manual_drop]
fn check_stmts(pool: Vec<i32>, lid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, fn_name: str) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0; let mut warns: i64 = 0;
    while i < cnt { warns = warns + check_stmt(pool, list_get(pool, lid, i), own, structs, enums, fn_name); i = i + 1; };
    return warns;
}

#[manual_drop]
fn builtin_rtype_format_string_i64(name: str) -> i64 {
    if str_eq(name, "str_eq") == 1 { return 1; };
    if str_eq(name, "str_starts_with") == 1 { return 1; };
    if str_eq(name, "str_ends_with") == 1 { return 1; };
    if str_eq(name, "str_index_of") == 1 { return 1; };
    if str_eq(name, "str_contains") == 1 { return 1; };
    if str_eq(name, "str_is_empty") == 1 { return 1; };
    if str_eq(name, "str_count") == 1 { return 1; };
    if str_eq(name, "str_to_i64") == 1 { return 1; };
    if str_eq(name, "str_to_int") == 1 { return 1; };
    if str_eq(name, "str_to_int_strict") == 1 { return 1; };
    if str_eq(name, "str_to_bool") == 1 { return 1; };
    if str_eq(name, "str_to_i64_radix") == 1 { return 1; };
    if str_eq(name, "parse_hex") == 1 { return 1; };
    if str_eq(name, "parse_bin") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn builtin_rtype_format_string_str(name: str) -> i64 {
    if str_eq(name, "str_concat") == 1 { return 1; };
    if str_eq(name, "str_to_lower") == 1 { return 1; };
    if str_eq(name, "str_to_upper") == 1 { return 1; };
    if str_eq(name, "str_replace") == 1 { return 1; };
    if str_eq(name, "str_repeat") == 1 { return 1; };
    if str_eq(name, "str_reverse") == 1 { return 1; };
    if str_eq(name, "str_pad_left") == 1 { return 1; };
    if str_eq(name, "str_pad_right") == 1 { return 1; };
    if str_eq(name, "str_center") == 1 { return 1; };
    if str_eq(name, "str_join") == 1 { return 1; };
    if str_eq(name, "int_to_str") == 1 { return 1; };
    if str_eq(name, "str_from_int") == 1 { return 1; };
    if str_eq(name, "bool_to_str") == 1 { return 1; };
    if str_eq(name, "int_to_hex") == 1 { return 1; };
    if str_eq(name, "int_to_bin") == 1 { return 1; };
    if str_eq(name, "int_to_oct") == 1 { return 1; };
    if str_eq(name, "int_to_str_force_sign") == 1 { return 1; };
    if str_eq(name, "int_to_hex_upper") == 1 { return 1; };
    if str_eq(name, "f64_to_str") == 1 { return 1; };
    if str_eq(name, "f32_to_str") == 1 { return 1; };
    if str_eq(name, "f64_to_str_prec") == 1 { return 1; };
    if str_eq(name, "f32_to_str_prec") == 1 { return 1; };
    if str_eq(name, "f64_to_str_sci") == 1 { return 1; };
    if str_eq(name, "f64_to_str_sci_upper") == 1 { return 1; };
    if str_eq(name, "f64_to_str_sci_prec") == 1 { return 1; };
    if str_eq(name, "f64_to_str_sci_prec_upper") == 1 { return 1; };
    if str_eq(name, "format_i64") == 1 { return 1; };
    if str_eq(name, "format_str") == 1 { return 1; };
    if str_eq(name, "format_hex") == 1 { return 1; };
    if str_eq(name, "format_bool") == 1 { return 1; };
    if str_eq(name, "format_f64") == 1 { return 1; };
    if str_eq(name, "format2_ii") == 1 { return 1; };
    if str_eq(name, "format2_si") == 1 { return 1; };
    if str_eq(name, "format2_ss") == 1 { return 1; };
    if str_eq(name, "format2_is") == 1 { return 1; };
    if str_eq(name, "format2_ff") == 1 { return 1; };
    if str_eq(name, "format2_fi") == 1 { return 1; };
    if str_eq(name, "format2_if") == 1 { return 1; };
    if str_eq(name, "format3_fff") == 1 { return 1; };
    if str_eq(name, "format3_iii") == 1 { return 1; };
    if str_eq(name, "format3_sii") == 1 { return 1; };
    if str_eq(name, "format3_iss") == 1 { return 1; };
    if str_eq(name, "format3_sss") == 1 { return 1; };
    if str_eq(name, "format3_ssi") == 1 { return 1; };
    if str_eq(name, "format3_sis") == 1 { return 1; };
    if str_eq(name, "format3_iis") == 1 { return 1; };
    if str_eq(name, "format3_isi") == 1 { return 1; };
    if str_eq(name, "format3_iif") == 1 { return 1; };
    if str_eq(name, "format3_iff") == 1 { return 1; };
    if str_eq(name, "format3_sff") == 1 { return 1; };
    if str_eq(name, "format3_ssf") == 1 { return 1; };
    if str_eq(name, "format3_sif") == 1 { return 1; };
    if str_eq(name, "format3_isf") == 1 { return 1; };
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
fn emit_cmp(sb: i64, cn: str, d: i64, a: i64, b: i64) -> i64 {
    sb_append(sb, "  %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, ".cmp = icmp "); sb_append(sb, cn);
    sb_append(sb, " i64 %r."); sb_append(sb, str_from_int(a));
    sb_append(sb, ", %r."); sb_append(sb, str_from_int(b));
    sb_append(sb, "\n  %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, " = zext i1 %r."); sb_append(sb, str_from_int(d));
    sb_append(sb, ".cmp to i64\n"); return 0;
}

#[manual_drop]
fn str_eq_at(source: str, pos: i64, target: str) -> i64 {
    let tlen: i64 = str_len(target);
    let mut k: i64 = 0;
    while k < tlen {
        if str_char_at(source, pos + k) != str_char_at(target, k) { return 0; };
        k = k + 1;
    };
    return 1;
}

#[manual_drop]
fn llvm_clang_path() -> str {
    let envc: str = env_get_or("NUCLEOR_CLANG", "");
    if str_len(envc) > 0 { return envc; };
    if host_is_windows() == 1 {
        let p0: str = "C:\\Progra~1\\LLVM\\bin\\clang.exe";
        if path_exists(p0) == 1 { return p0; };
        let p1: str = "C:\\Program Files\\LLVM\\bin\\clang.exe";
        if path_exists(p1) == 1 { return p1; };
        let p2: str = "C:\\msys64\\mingw64\\bin\\clang.exe";
        if path_exists(p2) == 1 { return p2; };
    };
    return "clang";
}

#[manual_drop]
fn own_merge_moved(o: Vec<i32>, a: Vec<i32>, b: Vec<i32>) -> i64 {
    // If a variable is moved in either branch, mark it moved
    let mut i: i64 = 0;
    while i < vec_len(a) {
        let key: str = vec_get(a, i);
        let va: i64 = vec_get(a, i + 1);
        if va == 2 { own_put_i(o, key, 2); }
        else {
            let vb: i64 = sym_get(b, key);
            if vb == 2 { own_put_i(o, key, 2); };
        };
        i = i + 2;
    };
    return 0;
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
fn narrow_via_as(blk: Vec<i32>, regs: Vec<i32>, vr: i64, tstr: str, src_kind: i64) -> i64 {
    if vr < 0 { return vr; };
    if str_len(tstr) == 0 { return vr; };
    let mut helper: str = "";
    if str_eq(tstr, "i8") == 1 { helper = "as_i8"; };
    if str_eq(tstr, "i16") == 1 { helper = "as_i16"; };
    if str_eq(tstr, "i32") == 1 { helper = "as_i32"; };
    if str_eq(tstr, "u8") == 1 { helper = "as_u8"; };
    if str_eq(tstr, "u16") == 1 { helper = "as_u16"; };
    if str_eq(tstr, "u32") == 1 { helper = "as_u32"; };
    if str_eq(tstr, "f32") == 1 && src_kind == 71 { helper = "as_f32"; };
    if str_eq(tstr, "f32") == 1 && src_kind == 1 { helper = "i64_to_f32"; };
    if str_eq(tstr, "f64") == 1 && src_kind == 1 { helper = "i64_to_f64"; };
    if str_len(helper) == 0 { return vr; };
    let mut conv_args: Vec<i32> = Vec::new();
    conv_args.push(vr);
    let r: i64 = ctr_next(regs);
    ir_block_add(blk, ir_call_ex(r, helper, conv_args));
    return r;
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
fn skip_compile_time_params(tokens: Vec<i32>, pos: i64) -> i64 {
    // RFC-0034 parser-only substrate; mirrors s1 and erases the ct-param
    // list until semantic environments and specialization land.
    if pk(tokens, pos) != 54 { return pos; };
    let mut cp: i64 = pos + 1;
    let mut seen: i64 = 0;
    while pk(tokens, cp) != 55 && pk(tokens, cp) != 0 {
        if seen > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 55 { break; };
        };
        if pk(tokens, cp) != 1 {
            panic("error[NR020]: expected compile-time parameter name in RFC-0034 `[]` parameter list");
        };
        cp = cp + 1;
        cp = expect_tok(tokens, cp, 42);
        let mut tr: Vec<i32> = parse_type(tokens, cp);
        let ct_ty: str = pr_val(tr);
        cp = pr_pos(tr);
        if pk(tokens, cp) == 40 {
            if ct_param_type_is_unsigned(ct_ty) == 1 && ct_param_default_is_negative_literal(tokens, cp + 1) == 1 {
                panic(str_concat("error[NR020]: negative default literal is invalid for unsigned RFC-0034 compile-time parameter type `", str_concat(ct_ty, "`. Use a non-negative default or change the parameter type to a signed integer.")));
            };
            cp = skip_compile_time_param_default(tokens, cp + 1);
        };
        seen = 1;
    };
    cp = expect_tok(tokens, cp, 55);
    return cp;
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
fn classify_kw(w: str) -> i64 {
    if str_eq(w, "fn") { return 10; }; if str_eq(w, "let") { return 11; };
    if str_eq(w, "mut") { return 12; }; if str_eq(w, "if") { return 13; };
    if str_eq(w, "else") { return 14; }; if str_eq(w, "while") { return 15; };
    if str_eq(w, "return") { return 16; }; if str_eq(w, "struct") { return 17; };
    if str_eq(w, "break") { return 18; }; if str_eq(w, "continue") { return 19; };
    if str_eq(w, "extern") { return 20; };
    if str_eq(w, "for") { return 56; }; if str_eq(w, "in") { return 57; };
    if str_eq(w, "enum") { return 62; }; if str_eq(w, "match") { return 63; };
    if str_eq(w, "trait") { return 66; }; if str_eq(w, "impl") { return 67; };
    // v0.3.137: `pure` is contextual — only kw when followed by `fn`.
    // Mirrored from compiler; user fn or call site `pure(...)` was being
    // silently miscompiled to const 0 because parse_primary fell through
    // its default int_lit branch on the unrecognised keyword token.
    if str_eq(w, "pub") { return 72; };
    if str_eq(w, "const") { return 73; };
    if str_eq(w, "type") { return 74; };
    // v0.3.139: `requires` is contextual. Mirror of compiler-side fix —
    // user fns named `requires` were silently miscompiling to 0 because
    // parse_primary fell through its int_lit 0 default on token 75. The
    // 4 fn-decl annotation checks (parse_fn_decl, parse_extern_fn,
    // parse_trait_method, parse_impl_method) now use pkv lookahead.
    // v0.3.140: removed `restricts` kw classification — mirror of
    // compiler-side fix. See nucleor_s1_compiler.nr classify_kw notes.
    // The `restricts [...] { ... }` form had zero usage anywhere; kw
    // was only causing silent miscompute for user fns named `restricts`.
    // v0.3.149: `unsafe` is contextual. Mirror of compiler-side fix --
    // see nucleor_s1_compiler classify_kw notes.
    // v0.3.150: wrapping/saturating no longer kw -- mirror of compiler-side fix.
    // v0.3.138: removed `scope`/`spawn` kw classifications. Mirror
    // of compiler-side fix — silent miscompute for user fns named
    // `scope` or `spawn` because parse_primary fell through its
    // int_lit 0 default on the unrecognised kw token.
    return 1;
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

#[manual_drop]
fn emit_builtin_call(sb: i64, name: str, rn: str, d: i64, argc: i64, args: Vec<i32>) -> i64 {
    let ds: str = str_from_int(d);
    // v0.4.22 perf: inline str_char_at as GEP+load (mirror of s1 — see
    // detailed comment in nucleor_s1_compiler.nr's emit_builtin_call).
    if str_eq(name, "str_char_at") == 1 && argc == 2 {
        let s_reg: str = str_from_int(vec_get(args, 0));
        let i_reg: str = str_from_int(vec_get(args, 1));
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".sca.ptr = inttoptr i64 %r.");
        sb_append(sb, s_reg); sb_append(sb, " to ptr\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".sca.gep = getelementptr i8, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".sca.ptr, i64 %r."); sb_append(sb, i_reg); sb_append(sb, "\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".sca.byte = load i8, ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".sca.gep\n");
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = zext i8 %r.");
        sb_append(sb, ds); sb_append(sb, ".sca.byte to i64\n");
        return 0;
    };
    // Step 1: inttoptr for ptr args
    let mut ai: i64 = 0;
    while ai < argc {
        if is_ptr_arg(name, ai) == 1 {
            sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, str_from_int(ai));
            sb_append(sb, " = inttoptr i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai))); sb_append(sb, " to ptr\n");
        };
        ai = ai + 1;
    };
    // Step 2: emit call with correct return type
    let vr: i64 = is_void_ret(name);
    let pret: i64 = is_ptr_ret(name);
    if vr == 1 {
        sb_append(sb, "  call void @"); sb_append(sb, rn); sb_append(sb, "(");
    } else if pret == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, ".rv = call ptr @"); sb_append(sb, rn); sb_append(sb, "(");
    } else {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = call i64 @"); sb_append(sb, rn); sb_append(sb, "(");
    };
    // Step 3: emit args with correct types
    ai = 0;
    while ai < argc {
        if ai > 0 { sb_append(sb, ", "); };
        if is_ptr_arg(name, ai) == 1 {
            sb_append(sb, "ptr %r."); sb_append(sb, ds); sb_append(sb, ".a"); sb_append(sb, str_from_int(ai));
        } else {
            sb_append(sb, "i64 %r."); sb_append(sb, str_from_int(vec_get(args, ai)));
        };
        ai = ai + 1;
    };
    sb_append(sb, ")\n");
    // Step 4: handle return conversion
    if vr == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = add i64 0, 0\n");
    } else if pret == 1 {
        sb_append(sb, "  %r."); sb_append(sb, ds); sb_append(sb, " = ptrtoint ptr %r.");
        sb_append(sb, ds); sb_append(sb, ".rv to i64\n");
    };
    return 0;
}

// RFC-0063 Wave 10 shared IDENTICAL helper batch.
fn str_is_digits(s: str) -> i64 {
    let slen: i64 = str_len(s);
    if slen == 0 { return 0; };
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c < 48 || c > 57 { return 0; };
        i = i + 1;
    };
    return 1;
}

fn tok_type(t: Vec<i32>) -> i64 { return vec_get(t, 0); }

fn tok_val(t: Vec<i32>) -> i64 { return vec_get(t, 1); }

fn tok_int_suffix_code(t: Vec<i32>) -> i64 {
    if vec_len(t) >= 4 { return vec_get(t, 3); };
    return 0;
}

fn int_suffix_code(suf: str) -> i64 {
    if str_eq(suf, "u64") == 1 { return 1; };
    if str_eq(suf, "usize") == 1 { return 2; };
    if str_eq(suf, "u32") == 1 { return 3; };
    if str_eq(suf, "u16") == 1 { return 4; };
    if str_eq(suf, "u8") == 1 { return 5; };
    if str_eq(suf, "i64") == 1 { return 6; };
    if str_eq(suf, "isize") == 1 { return 7; };
    if str_eq(suf, "i32") == 1 { return 8; };
    if str_eq(suf, "i16") == 1 { return 9; };
    if str_eq(suf, "i8") == 1 { return 10; };
    return 0;
}

fn int_suffix_code_type(code: i64) -> str {
    if code == 1 { return "u64"; };
    if code == 2 { return "usize"; };
    if code == 3 { return "u32"; };
    if code == 4 { return "u16"; };
    if code == 5 { return "u8"; };
    if code == 6 { return "i64"; };
    if code == 7 { return "isize"; };
    if code == 8 { return "i32"; };
    if code == 9 { return "i16"; };
    if code == 10 { return "i8"; };
    return "i32";
}

fn int_suffix_code_is_u64ish(code: i64) -> i64 {
    if code == 1 || code == 2 { return 1; };
    return 0;
}

fn is_digit(c: i64) -> i64 { if c >= 48 && c <= 57 { return 1; }; return 0; }

fn tok_at(tokens: Vec<i32>, idx: i64) -> Vec<i32> {
    if idx >= vec_len(tokens) { return tok_new(0, 0, 0); }; return vec_get(tokens, idx);
}

fn tok_type_at(tokens: Vec<i32>, idx: i64) -> i64 { return tok_type(tok_at(tokens, idx)); }

fn tok_val_at(tokens: Vec<i32>, idx: i64) -> i64 { return tok_val(tok_at(tokens, idx)); }

fn tok_int_suffix_code_at(tokens: Vec<i32>, idx: i64) -> i64 { return tok_int_suffix_code(tok_at(tokens, idx)); }

fn node_add(pool: Vec<i32>, nd: Vec<i32>) -> i64 { let nid: i64 = vec_len(pool); pool.push(nd); return nid; }

fn node_kind(pool: Vec<i32>, nid: i64) -> i64 { return nuc_node_kind(pool, nid); }

fn node_field(pool: Vec<i32>, nid: i64, idx: i64) -> i64 { return nuc_node_field(pool, nid, idx); }

fn int_lit_suffix_code(pool: Vec<i32>, nid: i64) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let nd: Vec<i32> = vec_get(pool, nid);
    if vec_len(nd) >= 3 { return vec_get(nd, 2); };
    return 0;
}

fn int_lit_type(pool: Vec<i32>, nid: i64) -> str {
    return int_suffix_code_type(int_lit_suffix_code(pool, nid));
}

fn list_len(pool: Vec<i32>, lid: i64) -> i64 { return nuc_list_len(pool, lid); }

fn list_get(pool: Vec<i32>, lid: i64, idx: i64) -> i64 { return nuc_list_get(pool, lid, idx); }

fn pr_pos(r: Vec<i32>) -> i64 { return vec_get(r, 0); }

fn pr_val(r: Vec<i32>) -> i64 { return vec_get(r, 1); }

fn pk(tokens: Vec<i32>, pos: i64) -> i64 { return tok_type_at(tokens, pos); }

fn pkv(tokens: Vec<i32>, pos: i64) -> i64 { return tok_val_at(tokens, pos); }

fn resolve_source(src: str, base_dir: str, imported: Vec<i32>) -> str {
    let mut module_records: Vec<i32> = Vec::new();
    return resolve_source_with_records(src, base_dir, imported, module_records);
}

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
#[manual_drop]
fn tok_new(tt: i64, v: i64, p: i64) -> Vec<i32> {
    let mut t: Vec<i32> = Vec::with_capacity(3); t.push(tt); t.push(v); t.push(p); return t;
}

#[manual_drop]
fn mk2(pool: Vec<i32>, k: i64, a: i64) -> i64 { let mut n: Vec<i32> = Vec::with_capacity(2); n.push(k); n.push(a); return node_add(pool, n); }

#[manual_drop]
fn mk3(pool: Vec<i32>, k: i64, a: i64, b: i64) -> i64 { let mut n: Vec<i32> = Vec::with_capacity(3); n.push(k); n.push(a); n.push(b); return node_add(pool, n); }

#[manual_drop]
fn mk4(pool: Vec<i32>, k: i64, a: i64, b: i64, c: i64) -> i64 { let mut n: Vec<i32> = Vec::with_capacity(4); n.push(k); n.push(a); n.push(b); n.push(c); return node_add(pool, n); }

#[manual_drop]
fn mk5(pool: Vec<i32>, k: i64, a: i64, b: i64, c: i64, d: i64) -> i64 { let mut n: Vec<i32> = Vec::with_capacity(5); n.push(k); n.push(a); n.push(b); n.push(c); n.push(d); return node_add(pool, n); }

#[manual_drop]
fn mk6(pool: Vec<i32>, k: i64, a: i64, b: i64, c: i64, d: i64, e: i64) -> i64 { let mut n: Vec<i32> = Vec::with_capacity(6); n.push(k); n.push(a); n.push(b); n.push(c); n.push(d); n.push(e); return node_add(pool, n); }

#[manual_drop]
fn mk_list(pool: Vec<i32>, items: Vec<i32>) -> i64 {
    let mut n: Vec<i32> = Vec::with_capacity(vec_len(items) + 1); n.push(40);
    let mut i: i64 = 0; while i < vec_len(items) { n.push(vec_get(items, i)); i = i + 1; };
    return node_add(pool, n);
}

#[manual_drop]
fn pr(p: i64, v: i64) -> Vec<i32> { let mut r: Vec<i32> = Vec::with_capacity(2); r.push(p); r.push(v); return r; }

#[manual_drop]
fn ir_inst(op: i64, d: i64, tid: i64, o1: i64, o2: i64, ex: i64) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::with_capacity(6); ii.push(op); ii.push(d); ii.push(tid); ii.push(o1); ii.push(o2); ii.push(ex); return ii;
}

#[manual_drop]
fn ir_call_ex(d: i64, fn_name: str, args: Vec<i32>) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::with_capacity(6);
    ii.push(19); ii.push(d); ii.push(0); ii.push(fn_name); ii.push(vec_len(args)); ii.push(args);
    return ii;
}

#[manual_drop]
fn ir_fn_ptr(d: i64, fn_name: str) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::with_capacity(6);
    ii.push(29); ii.push(d); ii.push(0); ii.push(fn_name); ii.push(0); ii.push(0);
    return ii;
}

#[manual_drop]
fn ir_indirect_call(d: i64, closure_reg: i64, args: Vec<i32>) -> Vec<i32> {
    let mut ii: Vec<i32> = Vec::with_capacity(6);
    ii.push(30); ii.push(d); ii.push(0); ii.push(closure_reg); ii.push(vec_len(args)); ii.push(args);
    return ii;
}

#[manual_drop]
fn ir_block_new(lbl: i64) -> Vec<i32> {
    let mut b: Vec<i32> = Vec::with_capacity(2); b.push(lbl);
    let mut insts: Vec<i32> = Vec::new(); b.push(insts); return b;
}

// =================================================================
// RFC-0063 Wave 12-16: 30 IDENTICAL fns retired from
// nucleor_tools_suite.nr local copies; shared via this module.
// Per CLOUD_AGENT_V1_FINISH_BRIEF_2026-05-07.md Q5 — mechanical
// safe-delete batch. Each fn was byte-identical between s1 and
// tools_suite per tools/audit_dup_fns_report.csv (category
// IDENTICAL). s1 retains its canonical local copies; tools_suite
// loses its locals and gets them via import.
// =================================================================

fn str_from_int(n: i64) -> str {
    return str_from_i64(n);
}

fn parse_args(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut args: Vec<i32> = Vec::new();
    let mut cp: i64 = pos;
    if pk(tokens, cp) != 51 {
        let mut r: Vec<i32> = parse_expr(tokens, cp, pool);
        args.push(pr_val(r)); cp = pr_pos(r);
        while pk(tokens, cp) == 44 {
            if pk(tokens, cp + 1) == 51 { cp = cp + 1; }
            else {
                r = parse_expr(tokens, cp + 1, pool); args.push(pr_val(r)); cp = pr_pos(r);
            };
        };
    };
    return pr(cp + 1, mk_list(pool, args));
}

fn skip_bracket_list(tokens: Vec<i32>, pos: i64) -> i64 {
    let mut cp: i64 = expect_tok(tokens, pos, 54);
    let mut depth: i64 = 1;
    while depth > 0 && pk(tokens, cp) != 0 {
        if pk(tokens, cp) == 54 { depth = depth + 1; }
        else if pk(tokens, cp) == 55 { depth = depth - 1; };
        cp = cp + 1;
    };
    return cp;
}

fn skip_compile_time_param_default(tokens: Vec<i32>, pos: i64) -> i64 {
    let mut cp: i64 = pos;
    let mut paren_depth: i64 = 0;
    let mut bracket_depth: i64 = 0;
    let mut angle_depth: i64 = 0;
    while pk(tokens, cp) != 0 {
        let tt: i64 = pk(tokens, cp);
        if paren_depth == 0 {
            if bracket_depth == 0 {
                if angle_depth == 0 {
                    if tt == 44 || tt == 55 { return cp; };
                };
            };
        };
        if tt == 50 { paren_depth = paren_depth + 1; }
        else if tt == 51 {
            if paren_depth > 0 { paren_depth = paren_depth - 1; };
        } else if tt == 54 {
            bracket_depth = bracket_depth + 1;
        } else if tt == 55 {
            if bracket_depth == 0 { return cp; };
            bracket_depth = bracket_depth - 1;
        } else if tt == 32 {
            angle_depth = angle_depth + 1;
        } else if tt == 33 {
            if angle_depth > 0 { angle_depth = angle_depth - 1; };
        };
        cp = cp + 1;
    };
    return cp;
}

fn ct_param_type_is_unsigned(t: str) -> i64 {
    if str_eq(t, "u8") == 1 { return 1; };
    if str_eq(t, "u16") == 1 { return 1; };
    if str_eq(t, "u32") == 1 { return 1; };
    if str_eq(t, "u64") == 1 { return 1; };
    if str_eq(t, "usize") == 1 { return 1; };
    return 0;
}

fn ct_param_default_is_negative_literal(tokens: Vec<i32>, pos: i64) -> i64 {
    if pk(tokens, pos) == 21 && pk(tokens, pos + 1) == 2 { return 1; };
    return 0;
}

fn skip_angle_group(tokens: Vec<i32>, pos: i64) -> i64 {
    if pk(tokens, pos) != 32 { return pos; };
    let mut cp: i64 = pos + 1;
    let mut depth: i64 = 1;
    while depth > 0 && pk(tokens, cp) != 0 {
        let tt: i64 = pk(tokens, cp);
        if depth == 1 {
            if tt == 2 || tt == 3 || tt == 40 || tt == 41 || tt == 43 || tt == 52 || tt == 53 || tt == 54 || tt == 55 || tt == 64 { return pos; };
            if tt == 30 || tt == 31 || tt == 34 || tt == 35 || tt == 36 || tt == 37 || tt == 38 || tt == 39 { return pos; };
        };
        if tt == 32 { depth = depth + 1; }
        else if tt == 33 { depth = depth - 1; };
        cp = cp + 1;
    };
    if depth != 0 { return pos; };
    if pk(tokens, cp) == 50 || pk(tokens, cp) == 52 || pk(tokens, cp) == 46 { return cp; };
    return pos;
}

fn skip_where_clause(tokens: Vec<i32>, pos: i64) -> i64 {
    let mut cp: i64 = pos;
    if pk(tokens, cp) == 1 && str_eq(pkv(tokens, cp), "where") == 1 {
        cp = cp + 1;
        while pk(tokens, cp) != 52 && pk(tokens, cp) != 43 && pk(tokens, cp) != 0 {
            cp = cp + 1;
        };
    };
    return cp;
}

fn parse_match_binding_block(tokens: Vec<i32>, pos: i64) -> Vec<i32> {
    let mut cp: i64 = pos;
    let mut binding: str = "";
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        if str_len(binding) > 0 {
            cp = expect_tok(tokens, cp, 44);
            if pk(tokens, cp) == 53 { break; };
            binding = str_concat(binding, "|");
        };
        let mut name: str = pkv(tokens, cp);
        cp = cp + 1;
        if pk(tokens, cp) == 42 {
            cp = cp + 1;
            name = pkv(tokens, cp);
            cp = cp + 1;
        };
        binding = str_concat(binding, name);
    };
    cp = expect_tok(tokens, cp, 53);
    return pr(cp, binding);
}

fn mk_passthrough_block_expr(pool: Vec<i32>, body: i64) -> i64 {
    return mk4(pool, 23, mk2(pool, 1, 1), body, 0 - 1);
}

fn parse_passthrough_block_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut cp: i64 = expect_tok(tokens, pos, 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    return pr(cp, mk_passthrough_block_expr(pool, pr_val(br)));
}

fn parse_wrapped_block_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>, mode: i64) -> Vec<i32> {
    let mut cp: i64 = expect_tok(tokens, pos, 52);
    let mut br: Vec<i32> = parse_stmts(tokens, cp, pool);
    cp = expect_tok(tokens, pr_pos(br), 53);
    return pr(cp, mk3(pool, 52, mode, pr_val(br)));
}

fn parse_mul(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_unary(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 22 || pk(tokens, cp) == 23 || pk(tokens, cp) == 24 {
        let op: i64 = pk(tokens, cp); r = parse_unary(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, op, node, pr_val(r));
    };
    return pr(cp, node);
}

fn parse_add(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_mul(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 20 || pk(tokens, cp) == 21 {
        let op: i64 = pk(tokens, cp); r = parse_mul(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, op, node, pr_val(r));
    };
    return pr(cp, node);
}

fn parse_eq(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_cmp(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 30 || pk(tokens, cp) == 31 {
        let op: i64 = pk(tokens, cp); r = parse_cmp(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, op, node, pr_val(r));
    };
    return pr(cp, node);
}

fn parse_and_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_eq(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 36 { r = parse_eq(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, 36, node, pr_val(r)); };
    return pr(cp, node);
}

fn parse_or_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_and_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r); let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 37 { r = parse_and_expr(tokens, cp + 1, pool); cp = pr_pos(r); node = mk4(pool, 4, 37, node, pr_val(r)); };
    return pr(cp, node);
}

fn parse_pipe_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut r: Vec<i32> = parse_or_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(r);
    let mut node: i64 = pr_val(r);
    while pk(tokens, cp) == 65 && pk(tokens, cp + 1) == 33 {
        let rp: i64 = cp + 2;
        if pk(tokens, rp) != 1 { return pr(rp, node); };
        let fname: str = pkv(tokens, rp);
        let rp2: i64 = rp + 1;
        let rp3: i64 = skip_angle_group(tokens, rp2);
        let mut piped_args: Vec<i32> = Vec::new();
        piped_args.push(node);
        if pk(tokens, rp3) == 50 {
            let mut ar: Vec<i32> = parse_args(tokens, rp3 + 1, pool);
            let alist: i64 = pr_val(ar);
            let ac: i64 = list_len(pool, alist);
            let mut ai: i64 = 0;
            while ai < ac {
                piped_args.push(list_get(pool, alist, ai));
                ai = ai + 1;
            };
            cp = pr_pos(ar);
        } else {
            cp = rp3;
        };
        node = mk3(pool, 7, fname, mk_list(pool, piped_args));
    };
    return pr(cp, node);
}

fn parse_expr(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> { return parse_pipe_expr(tokens, pos, pool); }

fn parse_type_alias_decl(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let name: i64 = pkv(tokens, pos);
    let mut cp: i64 = expect_tok(tokens, pos + 1, 40);
    let mut tr: Vec<i32> = parse_type(tokens, cp);
    cp = pr_pos(tr);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk3(pool, 51, name, pr_val(tr)));
}

fn parse_return_stmt(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    if pk(tokens, pos) == 43 { return pr(pos + 1, mk2(pool, 22, 0 - 1)); };
    let mut er: Vec<i32> = parse_expr(tokens, pos, pool);
    let mut cp: i64 = pr_pos(er);
    if pk(tokens, cp) == 43 { cp = cp + 1; };
    return pr(cp, mk2(pool, 22, pr_val(er)));
}

fn parse_stmts(tokens: Vec<i32>, pos: i64, pool: Vec<i32>) -> Vec<i32> {
    let mut items: Vec<i32> = Vec::new(); let mut cp: i64 = pos;
    while pk(tokens, cp) != 53 && pk(tokens, cp) != 0 {
        let mut r: Vec<i32> = parse_stmt(tokens, cp, pool); items.push(pr_val(r)); cp = pr_pos(r);
    };
    return pr(cp, mk_list(pool, items));
}

fn has_main_decl(pool: Vec<i32>, items: Vec<i32>) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(items) {
        let nid: i64 = vec_get(items, i);
        if node_kind(pool, nid) == 30 && str_eq(node_field(pool, nid, 1), "main") { return 1; };
        i = i + 1;
    };
    return 0;
}

fn remove_main_decl(pool: Vec<i32>, items: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(items) {
        let nid: i64 = vec_get(items, i);
        let mut keep: i64 = 1;
        if node_kind(pool, nid) == 30 && str_eq(node_field(pool, nid, 1), "main") { keep = 0; };
        if node_kind(pool, nid) == 46 && str_eq(node_field(pool, nid, 1), "main") { keep = 0; };
        if keep == 1 { out.push(nid); };
        i = i + 1;
    };
    return out;
}

fn char_guard_key(name: str) -> str {
    return str_concat("__char_guard:", name);
}

fn tenv_set_char_guard(env: Vec<i32>, name: str) -> i64 {
    return tenv_set(env, char_guard_key(name), "1");
}

fn tenv_has_char_guard(env: Vec<i32>, name: str) -> i64 {
    if str_eq(tenv_get(env, char_guard_key(name)), "1") == 1 { return 1; };
    return 0;
}

fn char_guard_merge_flags(a: i64, b: i64) -> i64 {
    let mut low: i64 = 0;
    let mut high: i64 = 0;
    if a == 1 || a == 3 || b == 1 || b == 3 { low = 1; };
    if a == 2 || a == 3 || b == 2 || b == 3 { high = 1; };
    return low + high * 2;
}

fn lower_if_expr_branch(pool: Vec<i32>, lid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    let mut b: Vec<i32> = cur;
    while i < cnt {
        let stmt: i64 = list_get(pool, lid, i);
        let sk: i64 = node_kind(pool, stmt);
        if i == cnt - 1 {
            if sk == 25 {
                return lower_expr(pool, node_field(pool, stmt, 1), b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
            if sk == 23 {
                return lower_expr(pool, stmt, b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
        };
        b = lower_stmt(pool, stmt, b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        if block_has_term(b) == 1 { return lx_new(0 - 1, b); };
        i = i + 1;
    };
    let zr: i64 = ctr_next(regs);
    ir_block_add(b, ir_const_int(zr, 0));
    return lx_new(zr, b);
}

#[manual_drop]
fn lower_stmts(pool: Vec<i32>, lid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let cnt: i64 = list_len(pool, lid); let mut i: i64 = 0; let mut b: Vec<i32> = cur;
    while i < cnt { b = lower_stmt(pool, list_get(pool, lid, i), b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls); i = i + 1; };
    return b;
}
