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
