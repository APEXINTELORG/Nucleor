// gen_helper_manifest_inventory.nr
//
// Read-only native inventory probe for tools/gen_helper_manifest.nr.
//
// This is an opt-in HERM-B first slice. It inventories the source surfaces
// consumed by the native helper-manifest generator, prints stable counts to
// stdout, and intentionally does not write docs/rfcs/helper_manifest.toml.
// The canonical drift-gated TOML writer is tools/gen_helper_manifest.nr; this
// probe stays read-only so it can classify helper-manifest source surfaces.

// ---------- generic helpers ----------

fn find_from(s: str, needle: str, start: i64) -> i64 {
    let n: i64 = str_len(s);
    let nl: i64 = str_len(needle);
    if nl == 0 { return -1; };
    if start < 0 || start >= n { return -1; };
    if nl > n - start { return -1; };
    let rest: str = str_substring(s, start, n);
    let off: i64 = str_index_of(rest, needle);
    if off < 0 { return -1; };
    return start + off;
}

fn is_ident_char(c: i64) -> i64 {
    if c >= 97 && c <= 122 { return 1; };
    if c >= 65 && c <= 90 { return 1; };
    if c >= 48 && c <= 57 { return 1; };
    if c == 95 { return 1; };
    return 0;
}

fn str_cmp_lt(a: str, b: str) -> i64 {
    let la: i64 = str_len(a);
    let lb: i64 = str_len(b);
    let mut i: i64 = 0;
    let limit: i64 = if la < lb { la } else { lb };
    while i < limit {
        let ca: i64 = str_char_at(a, i);
        let cb: i64 = str_char_at(b, i);
        if ca < cb { return 1; };
        if ca > cb { return 0; };
        i = i + 1;
    };
    if la < lb { return 1; };
    return 0;
}

fn sort_strs(v: Vec<str>) -> i64 {
    let n: i64 = vec_len(v);
    let mut i: i64 = 1;
    while i < n {
        let key: str = vec_get(v, i);
        let mut j: i64 = i - 1;
        while j >= 0 && str_cmp_lt(vec_get(v, j), key) == 0 {
            vec_set(v, j + 1, vec_get(v, j));
            j = j - 1;
        };
        vec_set(v, j + 1, key);
        i = i + 1;
    };
    return n;
}

fn sort_parallel_by_key(keys: Vec<str>, values: Vec<str>) -> i64 {
    let n: i64 = vec_len(keys);
    let mut i: i64 = 1;
    while i < n {
        let key: str = vec_get(keys, i);
        let value: str = vec_get(values, i);
        let mut j: i64 = i - 1;
        while j >= 0 && str_cmp_lt(vec_get(keys, j), key) == 0 {
            vec_set(keys, j + 1, vec_get(keys, j));
            vec_set(values, j + 1, vec_get(values, j));
            j = j - 1;
        };
        vec_set(keys, j + 1, key);
        vec_set(values, j + 1, value);
        i = i + 1;
    };
    return n;
}

fn contains_str(v: Vec<str>, value: str) -> i64 {
    let n: i64 = vec_len(v);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(v, i), value) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn push_unique(v: Vec<str>, value: str) -> i64 {
    if str_len(value) == 0 { return 0; };
    if contains_str(v, value) == 0 {
        vec_push(v, value);
        return 1;
    };
    return 0;
}

fn skip_ws(s: str, p0: i64) -> i64 {
    let n: i64 = str_len(s);
    let mut p: i64 = p0;
    while p < n {
        let c: i64 = str_char_at(s, p);
        if c != 32 && c != 9 && c != 10 && c != 13 { break; };
        p = p + 1;
    };
    return p;
}

fn match_delim_aware(s: str, open_pos: i64, open_char: i64, close_char: i64) -> i64 {
    let n: i64 = str_len(s);
    if open_pos >= n || str_char_at(s, open_pos) != open_char { return -1; };
    let mut depth: i64 = 1;
    let mut p: i64 = open_pos + 1;
    while p < n {
        let c: i64 = str_char_at(s, p);
        if c == 47 && p + 1 < n && str_char_at(s, p + 1) == 47 {
            while p < n && str_char_at(s, p) != 10 { p = p + 1; };
        }
        else if c == 34 {
            p = p + 1;
            while p < n && str_char_at(s, p) != 34 {
                if str_char_at(s, p) == 92 && p + 1 < n { p = p + 1; };
                p = p + 1;
            };
        }
        else if c == 39 {
            p = p + 1;
            while p < n && str_char_at(s, p) != 39 {
                if str_char_at(s, p) == 92 && p + 1 < n { p = p + 1; };
                p = p + 1;
            };
        }
        else if c == open_char {
            depth = depth + 1;
        }
        else if c == close_char {
            depth = depth - 1;
            if depth == 0 { return p; };
        };
        p = p + 1;
    };
    return -1;
}

fn match_brace(s: str, open_brace: i64) -> i64 {
    return match_delim_aware(s, open_brace, 123, 125);
}

fn line_end_from(s: str, p0: i64, limit: i64) -> i64 {
    let n: i64 = str_len(s);
    let mut p: i64 = p0;
    let lim: i64 = if limit < n { limit } else { n };
    while p < lim && str_char_at(s, p) != 10 { p = p + 1; };
    return p;
}

fn read_quoted_after(s: str, start: i64) -> str {
    let n: i64 = str_len(s);
    if start < 0 || start >= n { return ""; };
    if str_char_at(s, start) != 34 { return ""; };
    let close: i64 = find_from(s, "\"", start + 1);
    if close < 0 { return ""; };
    return str_substring(s, start + 1, close);
}

fn basename_no_ext(name: str) -> str {
    if str_ends_with(name, ".c") == 1 {
        return str_substring(name, 0, str_len(name) - 2);
    };
    if str_ends_with(name, ".nr") == 1 {
        return str_substring(name, 0, str_len(name) - 3);
    };
    return name;
}

fn bare_helper_name(name: str) -> str {
    let prefix: str = "__nucleor_";
    if str_starts_with(name, prefix) == 1 {
        return str_substring(name, str_len(prefix), str_len(name));
    };
    return name;
}

fn push_symbol_name_if_missing(symbols: Vec<str>, names: Vec<str>, symbol: str, name: str) -> i64 {
    if str_len(symbol) == 0 { return 0; };
    if contains_str(symbols, symbol) == 0 {
        vec_push(symbols, symbol);
        vec_push(names, name);
        return 1;
    };
    return 0;
}

fn is_digit_char(c: i64) -> i64 {
    if c >= 48 && c <= 57 { return 1; };
    return 0;
}

fn str_eq_any2(s: str, a: str, b: str) -> i64 {
    if str_eq(s, a) == 1 { return 1; };
    if str_eq(s, b) == 1 { return 1; };
    return 0;
}

fn str_eq_any3(s: str, a: str, b: str, c: str) -> i64 {
    if str_eq(s, a) == 1 { return 1; };
    if str_eq(s, b) == 1 { return 1; };
    if str_eq(s, c) == 1 { return 1; };
    return 0;
}

fn str_eq_any4(s: str, a: str, b: str, c: str, d: str) -> i64 {
    if str_eq(s, a) == 1 { return 1; };
    if str_eq(s, b) == 1 { return 1; };
    if str_eq(s, c) == 1 { return 1; };
    if str_eq(s, d) == 1 { return 1; };
    return 0;
}

fn classify_helper_name(name0: str) -> str {
    let name: str = bare_helper_name(name0);

    if str_starts_with(name, "vec_") == 1 { return "VectorOps"; };
    if str_starts_with(name, "f32x4_") == 1 { return "VectorOps"; };
    if str_starts_with(name, "i32x4_") == 1 { return "VectorOps"; };
    if str_starts_with(name, "simd_") == 1 { return "VectorOps"; };
    if str_starts_with(name, "vector_") == 1 { return "VectorOps"; };

    if str_starts_with(name, "hashmap_") == 1 { return "Collection"; };
    if str_starts_with(name, "hashset_") == 1 { return "Collection"; };
    if str_starts_with(name, "btreemap_") == 1 { return "Collection"; };
    if str_starts_with(name, "btreeset_") == 1 { return "Collection"; };
    if str_starts_with(name, "heapmap_") == 1 { return "Collection"; };
    if str_starts_with(name, "vecdeque_") == 1 { return "Collection"; };

    if str_starts_with(name, "str_") == 1 { return "StringFormat"; };
    if str_starts_with(name, "string_") == 1 { return "StringFormat"; };
    if str_starts_with(name, "sb_") == 1 { return "StringFormat"; };
    if str_starts_with(name, "format_") == 1 { return "StringFormat"; };
    if str_starts_with(name, "format") == 1 && str_len(name) > 6 && is_digit_char(str_char_at(name, 6)) == 1 { return "StringFormat"; };
    if str_eq(name, "chr") == 1 { return "StringFormat"; };
    if str_starts_with(name, "char_") == 1 { return "StringFormat"; };
    if str_eq_any4(name, "int_to_str", "int_to_hex", "int_to_bin", "int_to_oct") == 1 { return "StringFormat"; };
    if str_eq_any3(name, "int_to_hex_upper", "int_to_str_force_sign", "f64_to_str") == 1 { return "StringFormat"; };
    if str_eq(name, "bool_to_str") == 1 { return "StringFormat"; };
    if str_eq_any3(name, "str_to_i64", "str_to_f64", "str_to_bool") == 1 { return "StringFormat"; };
    if str_eq_any3(name, "str_to_i64_radix", "parse_hex", "parse_bin") == 1 { return "StringFormat"; };

    if str_starts_with(name, "fs_") == 1 { return "IO"; };
    if str_starts_with(name, "path_") == 1 { return "IO"; };
    if str_starts_with(name, "file_") == 1 { return "IO"; };
    if str_starts_with(name, "env_") == 1 { return "IO"; };
    if str_eq_any2(name, "getenv", "getcwd") == 1 { return "IO"; };
    if str_eq(name, "process_id") == 1 { return "IO"; };
    if str_starts_with(name, "os_") == 1 { return "IO"; };
    if str_eq_any4(name, "read_line", "read_int", "read_i64", "read_byte") == 1 { return "IO"; };
    if str_starts_with(name, "stdin_") == 1 { return "IO"; };
    if str_starts_with(name, "stdout_") == 1 { return "IO"; };
    if str_starts_with(name, "stderr_") == 1 { return "IO"; };
    if str_starts_with(name, "isatty_") == 1 { return "IO"; };
    if str_starts_with(name, "print") == 1 { return "IO"; };
    if str_starts_with(name, "eprint") == 1 { return "IO"; };
    if str_starts_with(name, "pipe_") == 1 { return "IO"; };
    if str_starts_with(name, "proc_") == 1 { return "IO"; };
    if str_eq(name, "system") == 1 { return "IO"; };
    if str_starts_with(name, "socket_") == 1 { return "IO"; };
    if str_starts_with(name, "http_") == 1 { return "IO"; };
    if str_starts_with(name, "tcp_") == 1 { return "IO"; };
    if str_starts_with(name, "udp_") == 1 { return "IO"; };
    if str_eq(name, "putchar") == 1 { return "IO"; };
    if str_starts_with(name, "args_") == 1 { return "IO"; };
    if str_eq(name, "init_args") == 1 { return "IO"; };
    if str_starts_with(name, "dbg_") == 1 { return "IO"; };

    if str_starts_with(name, "mutex_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "channel_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "chan_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "thread_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "rwlock_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "cancel_token_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "once_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "atomic_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "cas_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "par_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "scheduler_") == 1 { return "Concurrency"; };
    if str_starts_with(name, "ambient_scheduler") == 1 { return "Concurrency"; };
    if str_starts_with(name, "async_") == 1 { return "Concurrency"; };
    if str_eq(name, "cpu_count") == 1 { return "Concurrency"; };

    if str_starts_with(name, "rng_") == 1 { return "Random"; };
    if str_starts_with(name, "random_") == 1 { return "Random"; };
    if str_eq(name, "ambient_random") == 1 { return "Random"; };

    if str_starts_with(name, "time_") == 1 { return "Time"; };
    if str_starts_with(name, "sleep_") == 1 { return "Time"; };
    if str_starts_with(name, "now_") == 1 { return "Time"; };

    if str_eq_any3(name, "contract_require", "contract_ensure", "contract_invariant") == 1 { return "ControlFlow"; };
    if str_eq_any3(name, "deadline_check", "max_depth_enter", "max_depth_exit") == 1 { return "ControlFlow"; };

    if str_starts_with(name, "checked_") == 1 { return "PanickingArith"; };
    if str_starts_with(name, "saturating_") == 1 { return "PanickingArith"; };
    if str_starts_with(name, "wrapping_") == 1 { return "PanickingArith"; };
    if str_starts_with(name, "overflow") == 1 { return "PanickingArith"; };
    if str_starts_with(name, "panic") == 1 { return "PanickingArith"; };
    if str_starts_with(name, "trap_") == 1 { return "PanickingArith"; };
    if str_starts_with(name, "bounds_check") == 1 { return "PanickingArith"; };
    if str_starts_with(name, "stack_probe") == 1 { return "PanickingArith"; };
    if str_eq_any3(name, "assert", "sat_i32", "wrap_i32") == 1 { return "PanickingArith"; };

    if str_starts_with(name, "sizeof_") == 1 { return "Introspection"; };

    if str_starts_with(name, "option_") == 1 { return "ADT"; };
    if str_starts_with(name, "result_") == 1 { return "ADT"; };

    if str_eq_any4(name, "popcount", "leading_zeros", "trailing_zeros", "byte_swap") == 1 { return "PureMath"; };
    if str_eq_any4(name, "rotate_left", "rotate_right", "count_ones", "count_zeros") == 1 { return "PureMath"; };
    if str_starts_with(name, "i64_") == 1 { return "PureMath"; };
    if str_starts_with(name, "f64_") == 1 { return "PureMath"; };
    if str_starts_with(name, "f32_") == 1 { return "PureMath"; };
    if str_starts_with(name, "i32_") == 1 { return "PureMath"; };
    if str_starts_with(name, "f16_") == 1 { return "PureMath"; };
    if str_starts_with(name, "f8e4m3_") == 1 { return "PureMath"; };
    if str_starts_with(name, "f8e5m2_") == 1 { return "PureMath"; };
    if str_eq_any4(name, "abs", "min", "max", "clamp") == 1 { return "PureMath"; };
    if str_eq_any4(name, "sqrt", "sin", "cos", "tan") == 1 { return "PureMath"; };
    if str_eq_any4(name, "pow", "exp", "log", "floor") == 1 { return "PureMath"; };
    if str_eq_any4(name, "ceil", "round", "fabs", "fmod") == 1 { return "PureMath"; };
    if str_eq_any4(name, "sigmoid", "tanh", "relu", "gelu") == 1 { return "PureMath"; };
    if str_starts_with(name, "as_") == 1 { return "PureMath"; };
    if str_starts_with(name, "buf_read_u") == 1 { return "PureMath"; };
    if str_starts_with(name, "buf_write_u") == 1 { return "PureMath"; };

    if str_starts_with(name, "toml_") == 1 { return "DataCodec"; };
    if str_starts_with(name, "json_") == 1 { return "DataCodec"; };
    if str_starts_with(name, "csv_") == 1 { return "DataCodec"; };
    if str_starts_with(name, "ini_") == 1 { return "DataCodec"; };
    if str_starts_with(name, "base64_") == 1 { return "DataCodec"; };
    if str_starts_with(name, "msgpack_") == 1 { return "DataCodec"; };
    if str_starts_with(name, "uuid_") == 1 { return "DataCodec"; };
    if str_starts_with(name, "sha256") == 1 { return "DataCodec"; };
    if str_starts_with(name, "fnv1a") == 1 { return "DataCodec"; };
    if str_starts_with(name, "murmur3") == 1 { return "DataCodec"; };
    if str_starts_with(name, "crc32") == 1 { return "DataCodec"; };
    if str_starts_with(name, "bit_") == 1 { return "DataCodec"; };

    if str_starts_with(name, "region_") == 1 { return "Allocation"; };
    if str_starts_with(name, "arena_") == 1 { return "Allocation"; };
    if str_starts_with(name, "alloc_") == 1 { return "Allocation"; };
    if str_eq(name, "free") == 1 { return "Allocation"; };
    if str_eq(name, "realloc") == 1 { return "Allocation"; };
    if str_starts_with(name, "drop_") == 1 { return "Allocation"; };
    if str_eq(name, "malloc") == 1 { return "Allocation"; };
    if str_eq(name, "memcpy") == 1 { return "Allocation"; };
    if str_eq(name, "calloc") == 1 { return "Allocation"; };
    if str_starts_with(name, "capture_") == 1 { return "Allocation"; };
    if str_starts_with(name, "dyn_box_") == 1 { return "Allocation"; };

    if str_starts_with(name, "tensor_") == 1 { return "TensorOps"; };
    if str_starts_with(name, "matmul") == 1 { return "TensorOps"; };
    if str_starts_with(name, "conv2d") == 1 { return "TensorOps"; };
    if str_starts_with(name, "attention") == 1 { return "TensorOps"; };
    if str_starts_with(name, "cuda_") == 1 { return "TensorOps"; };
    if str_starts_with(name, "gpu_") == 1 { return "TensorOps"; };
    if str_starts_with(name, "device_") == 1 { return "TensorOps"; };
    if str_starts_with(name, "layout_") == 1 { return "TensorOps"; };
    if str_starts_with(name, "dlpack_") == 1 { return "TensorOps"; };
    if str_starts_with(name, "kvcache_") == 1 { return "TensorOps"; };
    if str_starts_with(name, "kvprefix_") == 1 { return "TensorOps"; };

    if str_starts_with(name, "plot_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "profile_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "certify_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "evidence_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "impact_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "audit_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "policy_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "doc_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "manifest_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "stage_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "bench_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "cli_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "test_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "summary_") == 1 { return "ToolingMeta"; };
    if str_eq(name, "py_eval") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "compile_src_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "str_cache_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "sym_aux_") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "infer_") == 1 && str_ends_with(name, "_cached") == 1 { return "ToolingMeta"; };
    if str_starts_with(name, "rods_f64_") == 1 { return "ToolingMeta"; };
    if str_eq_any3(name, "assert_eq", "assert_ne", "dbg") == 1 { return "ToolingMeta"; };

    if str_starts_with(name, "bf16_") == 1 { return "PureMath"; };

    return "Unclassified";
}

fn is_intentional_placeholder(symbol: str) -> i64 {
    if str_eq(symbol, "__nucleor_arena_alloc") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_arena_destroy") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_arena_new") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_arena_reset") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_region_alloc") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_region_free") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_region_new") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_region_reset") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_capture_get") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_capture_set") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_ambient_scheduler") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_cancel_token_cancel") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_cancel_token_is_cancelled") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_cancel_token_new") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_par_fold") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_par_map") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_par_reduce") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_rwlock_new") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_rwlock_read") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_rwlock_unlock") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_rwlock_write") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_iter") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_map") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_filter") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_fold") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_all") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_any") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_count") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_chain") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_skip") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_take") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vec_sum") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_ambient_random") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_device_alloc") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_device_free") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_device_transfer") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_kvcache_append") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_kvcache_compact") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_kvcache_evict") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_kvcache_free") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_kvcache_new") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_kvcache_read_prefix") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_kvprefix_free") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_center") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_clip") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_entropy") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_greedy") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_l1") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_l2") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_len") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_mad") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_median") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_minmax") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_normalize_l2") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_percentile") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_sample_eps") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_sample_gumbel") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_sample_nucleus_temp") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_sample_rank") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_sample_topk_temp") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_top2_gap") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_view") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_tensor_zscore") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_simd_add") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_simd_fma") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_simd_mul") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vector_add") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vector_broadcast") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vector_fma") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vector_mul") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vector_new") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_vector_reduce_sum") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_profile_end") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_profile_start") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_py_eval") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_rods_f64_add") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_rods_f64_div") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_rods_f64_encode") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_rods_f64_sub") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_sat_i32") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_wrap_i32") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_sha256") == 1 { return 1; };
    if str_eq(symbol, "__nucleor_putchar") == 1 { return 1; };
    return 0;
}

fn policy_result(effects: str, taint: str, proof: str) -> str {
    let left: str = str_concat(effects, "|");
    let mid: str = str_concat(taint, "|passthrough|");
    return str_concat(str_concat(left, mid), proof);
}

fn is_collection_readonly_name(name: str) -> i64 {
    let under: i64 = str_index_of(name, "_");
    if under < 0 { return 0; };
    let family: str = str_substring(name, 0, under);
    let rest: str = str_substring(name, under + 1, str_len(name));
    let family_ok: i64 =
        str_eq(family, "hashmap") == 1 || str_eq(family, "hashset") == 1 ||
        str_eq(family, "btreemap") == 1 || str_eq(family, "btreeset") == 1 ||
        str_eq(family, "vecdeque") == 1;
    if family_ok == 0 { return 0; };
    if str_eq_any4(rest, "get", "contains", "len", "capacity") == 1 { return 1; };
    if str_eq_any4(rest, "is_empty", "get_or", "key_at", "val_at") == 1 { return 1; };
    if str_eq(rest, "at") == 1 { return 1; };
    return 0;
}

fn policy_fields_for_name(name0: str, cls: str) -> str {
    let name: str = bare_helper_name(name0);

    if str_eq(name, "panic") == 1 {
        return policy_result("[\"panic\"]", "passthrough", "callsite_unreachable_or_recoverable");
    };
    if str_eq(name, "assert") == 1 {
        return policy_result("[\"panic\"]", "passthrough", "predicate_holds");
    };
    if str_eq_any2(name, "assert_eq", "assert_ne") == 1 {
        return policy_result("[\"panic\"]", "passthrough", "predicate_holds");
    };
    if str_eq(name, "dbg") == 1 {
        return policy_result("[\"io\"]", "passthrough", "io_capability_required");
    };
    if str_eq_any2(name, "manifest_report", "manifest_validate") == 1 {
        return policy_result("[\"alloc\"]", "passthrough", "none");
    };
    if str_eq_any2(name, "crc32", "crc32_update") == 1 {
        return policy_result("[]", "passthrough", "none");
    };
    if str_eq_any3(name, "fnv1a_64_i64", "fnv1a_64_str", "murmur3_64") == 1 {
        return policy_result("[]", "passthrough", "none");
    };
    if str_eq(name, "string_print") == 1 {
        return policy_result("[\"io\"]", "passthrough", "io_capability_required");
    };
    if str_eq_any3(name, "rods_f64_add", "rods_f64_sub", "rods_f64_div") == 1 {
        return policy_result("[]", "passthrough", "none");
    };
    if str_eq(name, "rods_f64_encode") == 1 {
        return policy_result("[\"alloc\"]", "passthrough", "none");
    };
    if str_eq_any2(name, "option_unwrap", "option_expect") == 1 {
        return policy_result("[\"panic\"]", "passthrough", "predicate_holds");
    };
    if str_eq_any3(name, "result_unwrap", "result_unwrap_err", "result_expect") == 1 {
        return policy_result("[\"panic\"]", "passthrough", "predicate_holds");
    };
    if str_eq_any2(name, "option_to_debug_str_i64", "result_to_debug_str_i64") == 1 {
        return policy_result("[\"alloc\"]", "passthrough", "none");
    };
    if str_eq_any2(name, "dyn_box_data", "dyn_box_type") == 1 {
        return policy_result("[]", "passthrough", "none");
    };

    if str_starts_with(name, "checked_") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_starts_with(name, "wrapping_") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_starts_with(name, "saturating_") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_eq_any2(name, "sat_i32", "wrap_i32") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_starts_with(name, "char_") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_eq(name, "chr") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_starts_with(name, "str_") == 1 {
        let rest: str = str_substring(name, 4, str_len(name));
        if str_eq_any4(rest, "eq", "contains", "count", "ends_with") == 1 { return policy_result("[]", "passthrough", "none"); };
        if str_eq_any4(rest, "starts_with", "index_of", "is_empty", "len") == 1 { return policy_result("[]", "passthrough", "none"); };
        if str_eq(rest, "char_at") == 1 { return policy_result("[]", "passthrough", "none"); };
        if str_eq_any4(rest, "to_i64", "to_f64", "to_bool", "to_i64_radix") == 1 { return policy_result("[]", "passthrough", "none"); };
    };
    if str_eq_any2(name, "parse_hex", "parse_bin") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_starts_with(name, "string_") == 1 {
        let srest: str = str_substring(name, 7, str_len(name));
        if str_eq_any4(srest, "capacity", "eq", "eq_str", "get_byte") == 1 { return policy_result("[]", "passthrough", "none"); };
        if str_eq_any4(srest, "len", "starts_with", "ends_with", "contains") == 1 { return policy_result("[]", "passthrough", "none"); };
        if str_eq(srest, "as_ptr") == 1 { return policy_result("[]", "passthrough", "none"); };
    };
    if is_collection_readonly_name(name) == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_eq_any2(name, "os_family", "os_pointer_width") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_eq_any2(name, "path_is_absolute", "path_separator") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_starts_with(name, "path_") == 1 {
        let prest: str = str_substring(name, 5, str_len(name));
        if str_eq_any4(prest, "components", "normalize", "strip_extension", "with_extension") == 1 {
            return policy_result("[\"alloc\"]", "passthrough", "none");
        };
    };
    if str_starts_with(name, "fs_") == 1 {
        let frest: str = str_substring(name, 3, str_len(name));
        if str_eq_any4(frest, "basename", "dirname", "extension", "join") == 1 {
            return policy_result("[\"alloc\"]", "passthrough", "none");
        };
        if str_eq_any4(frest, "exists", "is_dir", "is_file", "size") == 1 {
            return policy_result("[\"io\"]", "propagates", "io_capability_required");
        };
        if str_eq_any4(frest, "mtime", "list_dir", "canonicalize", "current_dir") == 1 {
            return policy_result("[\"io\"]", "propagates", "io_capability_required");
        };
        if str_eq(frest, "temp_dir") == 1 {
            return policy_result("[\"io\"]", "propagates", "io_capability_required");
        };
    };
    if str_eq_any3(name, "read_byte", "read_i64", "read_line") == 1 {
        return policy_result("[\"io\"]", "propagates", "io_capability_required");
    };
    if str_eq_any3(name, "env_get", "env_has", "env_keys") == 1 {
        return policy_result("[\"io\"]", "propagates", "io_capability_required");
    };
    if str_eq_any4(name, "getenv", "getcwd", "process_id", "system") == 1 {
        return policy_result("[\"io\"]", "propagates", "io_capability_required");
    };
    if str_starts_with(name, "isatty_") == 1 {
        return policy_result("[\"io\"]", "propagates", "io_capability_required");
    };
    if str_eq_any3(name, "args_count", "args_get", "init_args") == 1 {
        return policy_result("[\"io\"]", "propagates", "io_capability_required");
    };
    if str_starts_with(name, "file_read_") == 1 {
        return policy_result("[\"io\"]", "propagates", "io_capability_required");
    };
    if str_eq_any3(name, "toml_get_int", "toml_get_str", "toml_has") == 1 {
        return policy_result("[]", "passthrough", "none");
    };
    if str_eq(name, "toml_parse_file") == 1 {
        return policy_result("[\"io\"]", "propagates", "io_capability_required");
    };
    if str_eq(name, "uuid_v4") == 1 {
        return policy_result("[\"random\", \"alloc\"]", "passthrough", "rng_capability_required");
    };
    if str_starts_with(name, "tensor_") == 1 {
        let trest: str = str_substring(name, 7, str_len(name));
        if str_eq_any4(trest, "get", "cols", "rows", "max") == 1 { return policy_result("[]", "passthrough", "bounds_within_shape"); };
        if str_eq_any4(trest, "min", "mean", "sum", "stddev") == 1 { return policy_result("[]", "passthrough", "bounds_within_shape"); };
        if str_eq(trest, "variance") == 1 { return policy_result("[]", "passthrough", "bounds_within_shape"); };
        if str_eq_any2(trest, "set", "fill") == 1 { return policy_result("[]", "passthrough", "bounds_within_shape"); };
        if str_eq_any4(trest, "zeros", "ones", "transpose", "matmul") == 1 { return policy_result("[\"alloc\"]", "passthrough", "shape_compatible"); };
    };

    if str_eq(cls, "PureMath") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_eq(cls, "VectorOps") == 1 { return policy_result("[\"alloc\"]", "passthrough", "bounds_within_len"); };
    if str_eq(cls, "Random") == 1 { return policy_result("[\"random\"]", "passthrough", "rng_capability_required"); };
    if str_eq(cls, "Time") == 1 { return policy_result("[\"clock\"]", "passthrough", "clock_capability_required"); };
    if str_eq(cls, "Concurrency") == 1 { return policy_result("[\"sync\"]", "passthrough", "happens_before_release_acquire"); };
    if str_eq(cls, "Allocation") == 1 { return policy_result("[\"alloc\"]", "passthrough", "alloc_capability_or_arena_owned"); };
    if str_eq(cls, "StringFormat") == 1 { return policy_result("[\"alloc\"]", "passthrough", "none"); };
    if str_eq(cls, "Collection") == 1 { return policy_result("[\"alloc\"]", "passthrough", "none"); };
    if str_eq(cls, "IO") == 1 { return policy_result("[\"io\"]", "passthrough", "io_capability_required"); };
    if str_eq(cls, "DataCodec") == 1 { return policy_result("[\"alloc\"]", "passthrough", "none"); };
    if str_eq(cls, "ADT") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_eq(cls, "Introspection") == 1 { return policy_result("[]", "passthrough", "none"); };
    if str_eq(cls, "ControlFlow") == 1 { return policy_result("[\"panic\"]", "passthrough", "predicate_holds"); };
    return policy_result("TODO", "TODO", "TODO");
}

fn since_for_name(name0: str) -> str {
    let name: str = bare_helper_name(name0);

    if str_eq_any4(name, "vec_map_i64", "vec_filter_i64", "vec_fold_i64", "vec_each_i64") == 1 { return "0.2.9"; };
    if str_eq_any3(name, "vec_sum_i64", "vec_min_i64", "vec_max_i64") == 1 { return "0.2.9"; };

    if str_eq_any4(name, "vec_contains_i64", "vec_index_of_i64", "vec_reverse_i64", "vec_sort_i64") == 1 { return "0.2.10"; };
    if str_eq_any2(name, "vec_clone_i64", "vec_clear_i64") == 1 { return "0.2.10"; };

    if str_eq_any4(name, "vec_avg_i64", "vec_dot_i64", "vec_count_eq_i64", "vec_any_i64") == 1 { return "0.2.13"; };
    if str_eq_any4(name, "vec_all_i64", "vec_sum_f64", "vec_min_f64", "vec_max_f64") == 1 { return "0.2.13"; };

    if str_eq_any4(name, "char_is_alpha", "char_is_digit", "char_is_alnum", "char_is_whitespace") == 1 { return "0.2.14"; };
    if str_eq_any4(name, "char_is_upper", "char_is_lower", "char_is_hex_digit", "char_is_ascii") == 1 { return "0.2.14"; };
    if str_eq_any4(name, "char_is_punct", "char_to_upper", "char_to_lower", "char_digit_value") == 1 { return "0.2.14"; };

    if str_eq_any4(name, "rng_int", "rng_uniform", "rng_normal", "rng_bernoulli") == 1 { return "0.2.15"; };
    if str_eq_any4(name, "rng_exponential", "rng_seed", "random_uniform", "random_normal") == 1 { return "0.2.15"; };

    if str_eq_any4(name, "hashmap_keys", "hashmap_values", "time_iso_now", "time_format_iso") == 1 { return "0.2.16"; };

    if str_eq_any3(name, "fnv1a_64_str", "fnv1a_64_i64", "murmur3_64") == 1 { return "0.2.17"; };
    if str_eq_any2(name, "print_raw", "eprint_raw") == 1 { return "0.2.17"; };

    if str_eq_any4(name, "f64_abs", "f64_min", "f64_max", "f64_sign") == 1 { return "0.2.18"; };
    if str_eq_any3(name, "f64_copy_sign", "count_ones", "count_zeros") == 1 { return "0.2.18"; };

    if str_eq_any4(name, "fs_temp_dir", "fs_current_dir", "fs_remove_dir", "fs_copy_file") == 1 { return "0.2.19"; };
    if str_eq(name, "fs_canonicalize") == 1 { return "0.2.19"; };

    if str_eq_any2(name, "env_has", "env_keys") == 1 { return "0.2.20"; };
    if str_eq_any4(name, "str_is_empty", "str_count", "str_reverse", "str_trim_start") == 1 { return "0.2.20"; };
    if str_eq(name, "str_trim_end") == 1 { return "0.2.20"; };

    if str_eq_any4(name, "time_year", "time_month", "time_day", "time_hour") == 1 { return "0.2.21"; };
    if str_eq_any4(name, "time_minute", "time_second", "time_weekday", "time_day_of_year") == 1 { return "0.2.21"; };
    if str_eq(name, "time_elapsed_ms") == 1 { return "0.2.21"; };

    if str_eq_any4(name, "vec_first", "vec_last", "vec_is_empty", "vec_swap") == 1 { return "0.2.22"; };
    if str_eq_any3(name, "vec_extend", "vec_remove_at", "vec_insert_at") == 1 { return "0.2.22"; };

    if str_eq_any4(name, "path_separator", "path_is_absolute", "path_normalize", "path_with_extension") == 1 { return "0.2.23"; };
    if str_eq_any2(name, "path_strip_extension", "path_components") == 1 { return "0.2.23"; };

    if str_eq_any4(name, "str_to_i64", "str_to_f64", "str_to_bool", "int_to_str") == 1 { return "0.2.24"; };
    if str_eq_any2(name, "f64_to_str", "bool_to_str") == 1 { return "0.2.24"; };

    if str_eq_any4(name, "int_to_hex", "int_to_bin", "int_to_oct", "str_to_i64_radix") == 1 { return "0.2.25"; };
    if str_eq_any2(name, "parse_hex", "parse_bin") == 1 { return "0.2.25"; };

    if str_eq_any4(name, "str_pad_left", "str_pad_right", "str_center", "str_join") == 1 { return "0.2.26"; };
    if str_eq_any2(name, "str_lines", "str_chars") == 1 { return "0.2.26"; };

    if str_eq_any4(name, "hashmap_is_empty", "hashmap_get_or", "hashmap_merge", "hashmap_clone") == 1 { return "0.2.27"; };

    if str_eq_any4(name, "checked_div", "checked_rem", "checked_neg", "wrapping_div") == 1 { return "0.2.28"; };
    if str_eq_any3(name, "wrapping_rem", "wrapping_neg", "saturating_neg") == 1 { return "0.2.28"; };

    if str_eq_any4(name, "random_int", "random_bool", "random_choice", "vec_shuffle") == 1 { return "0.2.29"; };
    if str_eq_any2(name, "vec_sample", "random_fill") == 1 { return "0.2.29"; };

    if str_eq_any4(name, "vec_mean_f64", "vec_median_f64", "vec_variance_f64", "vec_stddev_f64") == 1 { return "0.2.30"; };
    if str_eq_any2(name, "vec_range_i64", "vec_percentile_f64") == 1 { return "0.2.30"; };

    return "0.1.0";
}

fn notes_for_row(stability: str, cls: str) -> str {
    let mut notes: str = "";
    if str_eq(stability, "unstable") == 1 {
        notes = "intentional v0.4 placeholder; declared in IR for forward compat, runtime body deferred";
    }
    else if str_eq(stability, "experimental") == 1 {
        notes = "declared in IR but no __nucleor_* definition found in stdlib/runtime/*.c (REVIEW REQUIRED)";
    };
    if str_eq(cls, "Unclassified") == 1 {
        let class_note: str = "name pattern did not match any class rule (REVIEW REQUIRED)";
        if str_len(notes) > 0 {
            notes = str_concat(notes, str_concat("; ", class_note));
        }
        else {
            notes = class_note;
        };
    };
    return notes;
}

// ---------- compiler-source inventory ----------

fn collect_get_rt_pairs(src: str, names: Vec<str>, symbols: Vec<str>) -> i64 {
    let needle: str = "if str_eq(name, \"";
    let mut p: i64 = 0;
    let mut count: i64 = 0;
    while p >= 0 {
        let hit: i64 = find_from(src, needle, p);
        if hit < 0 { break; };
        let name_start: i64 = hit + str_len(needle);
        let name_close: i64 = find_from(src, "\"", name_start);
        if name_close < 0 { break; };
        let ret_hit: i64 = find_from(src, "return \"", name_close);
        if ret_hit < 0 { p = name_close + 1; continue; };
        let sym_start: i64 = ret_hit + str_len("return \"");
        let sym_close: i64 = find_from(src, "\"", sym_start);
        if sym_close < 0 { break; };
        let name: str = str_substring(src, name_start, name_close);
        let symbol: str = str_substring(src, sym_start, sym_close);
        if str_starts_with(symbol, "__nucleor_") == 1 {
            vec_push(names, name);
            vec_push(symbols, symbol);
            count = count + 1;
        };
        p = sym_close + 1;
    };
    return count;
}

fn collect_str_eq_return_ones_in_fn(src: str, fn_name: str, out: Vec<str>) -> i64 {
    let fn_needle: str = str_concat("fn ", str_concat(fn_name, "("));
    let fn_pos: i64 = find_from(src, fn_needle, 0);
    if fn_pos < 0 { return 0; };
    let body_start: i64 = find_from(src, "{", fn_pos);
    if body_start < 0 { return 0; };
    let body_end: i64 = match_brace(src, body_start);
    if body_end < 0 { return 0; };

    let needle: str = "if str_eq(name, \"";
    let mut p: i64 = body_start;
    let mut count: i64 = 0;
    while p >= 0 && p < body_end {
        let hit: i64 = find_from(src, needle, p);
        if hit < 0 || hit >= body_end { break; };
        let name_start: i64 = hit + str_len(needle);
        let name_close: i64 = find_from(src, "\"", name_start);
        if name_close < 0 || name_close >= body_end { break; };
        let row_end: i64 = line_end_from(src, name_close, body_end);
        let row: str = str_substring(src, hit, row_end);
        let ret_hit: i64 = str_index_of(row, "return 1;");
        if ret_hit >= 0 {
            let name: str = str_substring(src, name_start, name_close);
            push_unique(out, name);
            count = count + 1;
        };
        p = name_close + 1;
    };
    sort_strs(out);
    return count;
}

fn collect_ir_declares_with_abi(src: str, symbols: Vec<str>, abis: Vec<str>) -> i64 {
    let needle: str = "sb_append(sb, \"declare ";
    let mut p: i64 = 0;
    let mut count: i64 = 0;
    while p >= 0 {
        let hit: i64 = find_from(src, needle, p);
        if hit < 0 { break; };
        let ret_start: i64 = hit + str_len(needle);
        let at_pos: i64 = find_from(src, "@", ret_start);
        if at_pos < 0 { p = hit + str_len(needle); continue; };
        let open_paren: i64 = find_from(src, "(", at_pos);
        if open_paren < 0 { p = at_pos + 1; continue; };
        let close_paren: i64 = find_from(src, ")", open_paren);
        if close_paren < 0 { p = open_paren + 1; continue; };
        let sym: str = str_substring(src, at_pos + 1, open_paren);
        let ret_end: i64 = at_pos - 1;
        let ret_ty: str = str_substring(src, ret_start, ret_end);
        let args_ty: str = str_substring(src, open_paren + 1, close_paren);
        let abi: str = str_concat(str_concat(str_concat("(", args_ty), ") -> "), ret_ty);
        if str_starts_with(sym, "__nucleor_") == 1 {
            if contains_str(symbols, sym) == 0 {
                vec_push(symbols, sym);
                vec_push(abis, abi);
            };
            count = count + 1;
        };
        p = open_paren + 1;
    };
    sort_parallel_by_key(symbols, abis);
    return count;
}

// ---------- runtime C inventory ----------

fn collect_runtime_symbol_mentions(text: str, symbols: Vec<str>) -> i64 {
    let needle: str = "__nucleor_";
    let mut p: i64 = 0;
    let mut count: i64 = 0;
    while p >= 0 {
        let hit: i64 = find_from(text, needle, p);
        if hit < 0 { break; };
        let mut endp: i64 = hit;
        while endp < str_len(text) && is_ident_char(str_char_at(text, endp)) == 1 {
            endp = endp + 1;
        };
        let after: i64 = skip_ws(text, endp);
        if after < str_len(text) && str_char_at(text, after) == 40 {
            let sym: str = str_substring(text, hit, endp);
            push_unique(symbols, sym);
            count = count + 1;
        };
        p = endp + 1;
    };
    return count;
}

fn collect_overflow_macro_defs(text: str, symbols: Vec<str>) -> i64 {
    let signed_needle: str = "NUC_DEFINE_SIGNED_OVERFLOW";
    let unsigned_needle: str = "NUC_DEFINE_UNSIGNED_OVERFLOW";
    let arith: Vec<str> = vec_new();
    vec_push(arith, "wrapping_add");
    vec_push(arith, "wrapping_sub");
    vec_push(arith, "wrapping_mul");
    vec_push(arith, "saturating_add");
    vec_push(arith, "saturating_sub");
    vec_push(arith, "saturating_mul");
    vec_push(arith, "checked_add");
    vec_push(arith, "checked_sub");
    vec_push(arith, "checked_mul");

    let mut total: i64 = 0;
    let mut pass: i64 = 0;
    while pass < 2 {
        let needle: str = if pass == 0 { signed_needle } else { unsigned_needle };
        let mut p: i64 = 0;
        while p >= 0 {
            let hit: i64 = find_from(text, needle, p);
            if hit < 0 { break; };
            let openp: i64 = find_from(text, "(", hit + str_len(needle));
            if openp < 0 { p = hit + str_len(needle); continue; };
            let width_start: i64 = skip_ws(text, openp + 1);
            let mut width_end: i64 = width_start;
            while width_end < str_len(text) && is_ident_char(str_char_at(text, width_end)) == 1 {
                width_end = width_end + 1;
            };
            let width: str = str_substring(text, width_start, width_end);
            if str_len(width) > 0 {
                let mut i: i64 = 0;
                while i < vec_len(arith) {
                    let sym: str = str_concat("__nucleor_", str_concat(vec_get(arith, i), str_concat("_", width)));
                    push_unique(symbols, sym);
                    total = total + 1;
                    i = i + 1;
                };
            };
            p = width_end + 1;
        };
        pass = pass + 1;
    };
    return total;
}

fn collect_runtime_inventory(rt_dir: str, c_files: Vec<str>, symbols: Vec<str>) -> Vec<i64> {
    let entries: Vec<str> = fs_list_dir(rt_dir);
    let mut i: i64 = 0;
    while i < vec_len(entries) {
        let name: str = vec_get(entries, i);
        if str_ends_with(name, ".c") == 1 {
            vec_push(c_files, name);
        };
        i = i + 1;
    };
    sort_strs(c_files);

    let counts: Vec<i64> = vec_new();
    let mut direct_mentions: i64 = 0;
    let mut macro_defs: i64 = 0;
    let mut k: i64 = 0;
    while k < vec_len(c_files) {
        let path: str = str_concat(rt_dir, str_concat("/", vec_get(c_files, k)));
        let text: str = file_read_string(path);
        direct_mentions = direct_mentions + collect_runtime_symbol_mentions(text, symbols);
        macro_defs = macro_defs + collect_overflow_macro_defs(text, symbols);
        k = k + 1;
    };
    sort_strs(symbols);
    vec_push(counts, direct_mentions);
    vec_push(counts, macro_defs);
    return counts;
}

fn print_first_values(label: str, values: Vec<str>, limit: i64) -> i64 {
    let n: i64 = vec_len(values);
    print(str_concat(label, str_concat("_count: ", int_to_str(n))));
    let mut shown: i64 = 0;
    let mut line: str = "";
    while shown < n && shown < limit {
        if shown > 0 { line = str_concat(line, ","); };
        line = str_concat(line, vec_get(values, shown));
        shown = shown + 1;
    };
    print(str_concat(label, str_concat("_first: ", line)));
    return shown;
}

fn print_value_lines(label: str, values: Vec<str>) -> i64 {
    let n: i64 = vec_len(values);
    let mut i: i64 = 0;
    while i < n {
        print(str_concat(label, str_concat(": ", vec_get(values, i))));
        i = i + 1;
    };
    return n;
}

fn print_pair_lines(label: str, keys: Vec<str>, values: Vec<str>) -> i64 {
    let n: i64 = vec_len(keys);
    let mut i: i64 = 0;
    while i < n {
        let line: str = str_concat(vec_get(keys, i), str_concat("|", vec_get(values, i)));
        print(str_concat(label, str_concat(": ", line)));
        i = i + 1;
    };
    return n;
}

fn print_triple_lines(label: str, a: Vec<str>, b: Vec<str>, c: Vec<str>) -> i64 {
    let n: i64 = vec_len(a);
    let mut i: i64 = 0;
    while i < n {
        let left: str = str_concat(vec_get(a, i), "|");
        let middle: str = str_concat(vec_get(b, i), "|");
        let line: str = str_concat(str_concat(left, middle), vec_get(c, i));
        print(str_concat(label, str_concat(": ", line)));
        i = i + 1;
    };
    return n;
}

// ---------- main ----------

fn main() -> i64 {
    let s1_path: str = "compiler/nucleor_s1_compiler.nr";
    let rt_dir: str = "stdlib/runtime";

    let src: str = file_read_string(s1_path);
    if str_len(src) == 0 {
        print(str_concat("ERROR: cannot read ", s1_path));
        return 1;
    };

    let rt_names: Vec<str> = vec_new();
    let rt_symbols: Vec<str> = vec_new();
    let rt_pair_count: i64 = collect_get_rt_pairs(src, rt_names, rt_symbols);

    let unique_rt_symbols: Vec<str> = vec_new();
    let mut i: i64 = 0;
    while i < vec_len(rt_symbols) {
        push_unique(unique_rt_symbols, vec_get(rt_symbols, i));
        i = i + 1;
    };
    sort_strs(unique_rt_symbols);

    let void_names: Vec<str> = vec_new();
    let ptr_ret_names: Vec<str> = vec_new();
    let ptr_arg_names: Vec<str> = vec_new();
    collect_str_eq_return_ones_in_fn(src, "is_void_ret", void_names);
    collect_str_eq_return_ones_in_fn(src, "is_ptr_ret", ptr_ret_names);
    collect_str_eq_return_ones_in_fn(src, "is_ptr_arg", ptr_arg_names);

    let ir_symbols: Vec<str> = vec_new();
    let ir_abis: Vec<str> = vec_new();
    let ir_decl_count: i64 = collect_ir_declares_with_abi(src, ir_symbols, ir_abis);

    let c_files: Vec<str> = vec_new();
    let runtime_symbols: Vec<str> = vec_new();
    let runtime_counts: Vec<i64> = collect_runtime_inventory(rt_dir, c_files, runtime_symbols);
    let runtime_direct_mentions: i64 = vec_get(runtime_counts, 0);
    let runtime_macro_defs: i64 = vec_get(runtime_counts, 1);

    let union_symbols: Vec<str> = vec_new();
    let mut u: i64 = 0;
    while u < vec_len(unique_rt_symbols) {
        push_unique(union_symbols, vec_get(unique_rt_symbols, u));
        u = u + 1;
    };
    u = 0;
    while u < vec_len(ir_symbols) {
        push_unique(union_symbols, vec_get(ir_symbols, u));
        u = u + 1;
    };
    sort_strs(union_symbols);

    let manifest_symbols: Vec<str> = vec_new();
    let manifest_names: Vec<str> = vec_new();
    let mut m: i64 = 0;
    while m < vec_len(rt_symbols) {
        push_symbol_name_if_missing(manifest_symbols, manifest_names, vec_get(rt_symbols, m), vec_get(rt_names, m));
        m = m + 1;
    };
    m = 0;
    while m < vec_len(ir_symbols) {
        let sym: str = vec_get(ir_symbols, m);
        push_symbol_name_if_missing(manifest_symbols, manifest_names, sym, bare_helper_name(sym));
        m = m + 1;
    };
    sort_parallel_by_key(manifest_symbols, manifest_names);

    let manifest_classes: Vec<str> = vec_new();
    m = 0;
    while m < vec_len(manifest_names) {
        vec_push(manifest_classes, classify_helper_name(vec_get(manifest_names, m)));
        m = m + 1;
    };

    let manifest_stability: Vec<str> = vec_new();
    let manifest_policy: Vec<str> = vec_new();
    let manifest_since: Vec<str> = vec_new();
    let manifest_notes: Vec<str> = vec_new();
    let mut stable_count: i64 = 0;
    let mut unstable_count: i64 = 0;
    let mut experimental_count: i64 = 0;
    let mut review_required_count: i64 = 0;
    let mut policy_todo_count: i64 = 0;
    let mut since_explicit_count: i64 = 0;
    let mut notes_nonempty_count: i64 = 0;
    m = 0;
    while m < vec_len(manifest_symbols) {
        let sym: str = vec_get(manifest_symbols, m);
        let name: str = vec_get(manifest_names, m);
        let cls: str = vec_get(manifest_classes, m);
        let stability: str = if contains_str(runtime_symbols, sym) == 1 {
            "stable"
        }
        else if is_intentional_placeholder(sym) == 1 {
            "unstable"
        }
        else {
            "experimental"
        };
        if str_eq(stability, "stable") == 1 { stable_count = stable_count + 1; };
        if str_eq(stability, "unstable") == 1 { unstable_count = unstable_count + 1; };
        if str_eq(stability, "experimental") == 1 { experimental_count = experimental_count + 1; };
        if str_eq(stability, "experimental") == 1 || str_eq(cls, "Unclassified") == 1 {
            review_required_count = review_required_count + 1;
        };
        vec_push(manifest_stability, stability);
        let policy: str = policy_fields_for_name(name, cls);
        if str_starts_with(policy, "TODO|") == 1 {
            policy_todo_count = policy_todo_count + 1;
        };
        vec_push(manifest_policy, policy);
        let since: str = since_for_name(name);
        if str_eq(since, "0.1.0") == 0 {
            since_explicit_count = since_explicit_count + 1;
        };
        vec_push(manifest_since, since);
        let notes: str = notes_for_row(stability, cls);
        if str_len(notes) > 0 {
            notes_nonempty_count = notes_nonempty_count + 1;
        };
        vec_push(manifest_notes, notes);
        m = m + 1;
    };

    print("helper_manifest_inventory_v8");
    print(str_concat("source: ", s1_path));
    print(str_concat("runtime_dir: ", rt_dir));
    print(str_concat("runtime_c_files: ", int_to_str(vec_len(c_files))));
    print(str_concat("get_rt_name_pairs: ", int_to_str(rt_pair_count)));
    print(str_concat("get_rt_name_unique_symbols: ", int_to_str(vec_len(unique_rt_symbols))));
    print(str_concat("is_void_ret_names: ", int_to_str(vec_len(void_names))));
    print(str_concat("is_ptr_ret_names: ", int_to_str(vec_len(ptr_ret_names))));
    print(str_concat("is_ptr_arg_names: ", int_to_str(vec_len(ptr_arg_names))));
    print(str_concat("ir_declares_seen: ", int_to_str(ir_decl_count)));
    print(str_concat("ir_declares_unique_symbols: ", int_to_str(vec_len(ir_symbols))));
    print(str_concat("runtime_direct_symbol_mentions: ", int_to_str(runtime_direct_mentions)));
    print(str_concat("runtime_macro_expanded_symbols: ", int_to_str(runtime_macro_defs)));
    print(str_concat("runtime_unique_symbols: ", int_to_str(vec_len(runtime_symbols))));
    print(str_concat("manifest_candidate_symbols: ", int_to_str(vec_len(union_symbols))));
    print(str_concat("manifest_named_symbols: ", int_to_str(vec_len(manifest_symbols))));
    print(str_concat("stability_rows: ", int_to_str(vec_len(manifest_stability))));
    print(str_concat("stable_symbols: ", int_to_str(stable_count)));
    print(str_concat("unstable_symbols: ", int_to_str(unstable_count)));
    print(str_concat("experimental_symbols: ", int_to_str(experimental_count)));
    print(str_concat("review_required_symbols: ", int_to_str(review_required_count)));
    print(str_concat("policy_rows: ", int_to_str(vec_len(manifest_policy))));
    print(str_concat("policy_todo_symbols: ", int_to_str(policy_todo_count)));
    print(str_concat("since_rows: ", int_to_str(vec_len(manifest_since))));
    print(str_concat("since_explicit_symbols: ", int_to_str(since_explicit_count)));
    print(str_concat("notes_rows: ", int_to_str(vec_len(manifest_notes))));
    print(str_concat("notes_nonempty_symbols: ", int_to_str(notes_nonempty_count)));
    print_first_values("get_rt_name_symbol", unique_rt_symbols, 12);
    print_first_values("ir_symbol", ir_symbols, 12);
    print_first_values("runtime_symbol", runtime_symbols, 12);
    print_value_lines("void_ret_name", void_names);
    print_value_lines("ptr_ret_name", ptr_ret_names);
    print_value_lines("ptr_arg_name", ptr_arg_names);
    print_pair_lines("ir_abi", ir_symbols, ir_abis);
    print_triple_lines("class_row", manifest_symbols, manifest_names, manifest_classes);
    print_pair_lines("stability_row", manifest_symbols, manifest_stability);
    print_pair_lines("policy_row", manifest_symbols, manifest_policy);
    print_pair_lines("since_row", manifest_symbols, manifest_since);
    print_pair_lines("notes_row", manifest_symbols, manifest_notes);
    print_value_lines("candidate_symbol", union_symbols);
    print("note: read-only inventory only; canonical TOML comes from tools/gen_helper_manifest.nr");
    return 0;
}
