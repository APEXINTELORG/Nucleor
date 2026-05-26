// gen_helper_manifest.nr — Native Nucleor port of tools/gen_helper_manifest.py.
//
// Walks compiler/nucleor_s1_compiler.nr (for ABI tables: get_rt_name,
// is_void_ret, is_ptr_ret, IR `declare`) and stdlib/runtime/*.c (for
// runtime symbol definitions). For every helper, classifies it via
// CLASS_RULES, resolves effect metadata via NAME_OVERRIDES →
// PATTERN_OVERRIDES → CLASS_DEFAULTS fallback chain, emits
// docs/rfcs/helper_manifest.toml.
//
// RFC-0063 Phase 5 final / Track C C6: fourth and largest port of a
// Python dev-time generator to native Nucleor (after gen_releases_index,
// gen_rod_manifest, gen_benchmark_summary). Closes the last drift-gated
// Python dependency. The former non-gated optional numerics matrix
// Python generator was retired after it fell behind the committed
// fixture tree.
//
// Output is intended to be byte-equivalent to gen_helper_manifest.py
// modulo the `.py` → `.nr` attribution line. Drift gate verifies.

// ---------- str helpers ----------

// Returns 1 if name is in `options` (Vec<str>), 0 otherwise.
fn name_in_set(name: str, options: Vec<str>) -> i64 {
    let n: i64 = vec_len(options);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(name, vec_get(options, i)) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

// Pad string `s` on the right with spaces to width `w`. If s is already >= w,
// returns s unchanged.
fn pad_right_spaces(s: str, w: i64) -> str {
    let cur: i64 = str_len(s);
    if cur >= w { return s; };
    let mut out: str = s;
    let mut k: i64 = cur;
    while k < w { out = str_concat(out, " "); k = k + 1; };
    return out;
}

// String less-than for sorting (byte-wise lexicographic). 1 if a < b, 0 otherwise.
fn str_lt(a: str, b: str) -> i64 {
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

// Sort Vec<str> ascending (insertion sort).
fn sort_strs(v: Vec<str>) -> i64 {
    let n: i64 = vec_len(v);
    let mut i: i64 = 1;
    while i < n {
        let key: str = vec_get(v, i);
        let mut j: i64 = i - 1;
        while j >= 0 && str_lt(vec_get(v, j), key) == 0 {
            vec_set(v, j + 1, vec_get(v, j));
            j = j - 1;
        };
        vec_set(v, j + 1, key);
        i = i + 1;
    };
    return n;
}

// ---------- classification ----------

// Translate Python classify(name) — applies CLASS_RULES patterns in order,
// first match wins.
fn classify(name: str) -> str {
    // Strip "__nucleor_" prefix if present (matches Python's bare-name
    // normalization for the few helpers whose get_rt_name() returns the
    // full prefixed string as both input and output).
    let bare: str = if str_starts_with(name, "__nucleor_") == 1 {
        str_substring(name, 10, str_len(name))
    } else { name };

    // VectorOps: ^vec_(?!u8|deque), ^vec_u8_, ^f32x4_, ^i32x4_, ^simd_, ^vector_
    if (str_starts_with(bare, "vec_") == 1
            && str_starts_with(bare, "vec_u8") == 0
            && str_starts_with(bare, "vec_deque") == 0)
        || str_starts_with(bare, "vec_u8_") == 1
        || str_starts_with(bare, "f32x4_") == 1
        || str_starts_with(bare, "i32x4_") == 1
        || str_starts_with(bare, "simd_") == 1
        || str_starts_with(bare, "vector_") == 1 {
        return "VectorOps";
    };

    // Collection
    if str_starts_with(bare, "hashmap_") == 1
        || str_starts_with(bare, "hashset_") == 1
        || str_starts_with(bare, "btreemap_") == 1
        || str_starts_with(bare, "btreeset_") == 1
        || str_starts_with(bare, "heapmap_") == 1
        || str_starts_with(bare, "vecdeque_") == 1 {
        return "Collection";
    };

    // StringFormat
    if str_starts_with(bare, "str_") == 1
        || str_starts_with(bare, "string_") == 1
        || str_starts_with(bare, "sb_") == 1
        || str_starts_with(bare, "format_") == 1
        || (str_starts_with(bare, "format") == 1 && str_len(bare) >= 7
            && str_char_at(bare, 6) >= 48 && str_char_at(bare, 6) <= 57)
        || str_eq(bare, "chr") == 1
        || str_starts_with(bare, "char_") == 1
        || str_eq(bare, "int_to_str") == 1 || str_eq(bare, "int_to_hex") == 1
        || str_eq(bare, "int_to_bin") == 1 || str_eq(bare, "int_to_oct") == 1
        || str_eq(bare, "int_to_hex_upper") == 1
        || str_eq(bare, "int_to_str_force_sign") == 1
        || str_eq(bare, "f64_to_str") == 1
        || str_eq(bare, "bool_to_str") == 1
        || str_eq(bare, "str_to_i64") == 1 || str_eq(bare, "str_to_f64") == 1
        || str_eq(bare, "str_to_bool") == 1
        || str_eq(bare, "str_to_i64_radix") == 1
        || str_eq(bare, "parse_hex") == 1 || str_eq(bare, "parse_bin") == 1 {
        return "StringFormat";
    };

    // IO
    if str_starts_with(bare, "fs_") == 1
        || str_starts_with(bare, "path_") == 1
        || str_starts_with(bare, "file_") == 1
        || str_starts_with(bare, "env_") == 1
        || str_eq(bare, "getenv") == 1
        || str_eq(bare, "getcwd") == 1
        || str_eq(bare, "process_id") == 1
        || str_starts_with(bare, "os_") == 1
        || str_eq(bare, "read_line") == 1 || str_eq(bare, "read_int") == 1
        || str_eq(bare, "read_i64") == 1 || str_eq(bare, "read_byte") == 1
        || str_starts_with(bare, "stdin_") == 1
        || str_starts_with(bare, "stdout_") == 1
        || str_starts_with(bare, "stderr_") == 1
        || str_starts_with(bare, "isatty_") == 1
        || str_starts_with(bare, "print") == 1
        || str_starts_with(bare, "eprint") == 1
        || str_starts_with(bare, "pipe_") == 1
        || str_starts_with(bare, "proc_") == 1
        || str_eq(bare, "system") == 1
        || str_starts_with(bare, "socket_") == 1
        || str_starts_with(bare, "http_") == 1
        || str_starts_with(bare, "tcp_") == 1
        || str_starts_with(bare, "udp_") == 1
        || str_eq(bare, "putchar") == 1
        || str_starts_with(bare, "args_") == 1
        || str_eq(bare, "init_args") == 1
        || str_starts_with(bare, "dbg_") == 1 {
        return "IO";
    };

    // Concurrency (incl. async_*)
    if str_starts_with(bare, "mutex_") == 1
        || str_starts_with(bare, "channel_") == 1
        || str_starts_with(bare, "chan_") == 1
        || str_starts_with(bare, "thread_") == 1
        || str_starts_with(bare, "rwlock_") == 1
        || str_starts_with(bare, "cancel_token_") == 1
        || str_starts_with(bare, "once_") == 1
        || str_starts_with(bare, "atomic_") == 1
        || str_starts_with(bare, "cas_") == 1
        || str_starts_with(bare, "par_") == 1
        || str_starts_with(bare, "scheduler_") == 1
        || str_starts_with(bare, "ambient_scheduler") == 1
        || str_starts_with(bare, "async_") == 1
        || str_eq(bare, "cpu_count") == 1 {
        return "Concurrency";
    };

    // Random
    if str_starts_with(bare, "rng_") == 1
        || str_starts_with(bare, "random_") == 1
        || str_eq(bare, "ambient_random") == 1 {
        return "Random";
    };

    // Time
    if str_starts_with(bare, "time_") == 1
        || str_starts_with(bare, "sleep_") == 1
        || str_starts_with(bare, "now_") == 1 {
        return "Time";
    };

    // ControlFlow
    if str_eq(bare, "contract_require") == 1
        || str_eq(bare, "contract_ensure") == 1
        || str_eq(bare, "contract_invariant") == 1
        || str_eq(bare, "deadline_check") == 1
        || str_eq(bare, "max_depth_enter") == 1
        || str_eq(bare, "max_depth_exit") == 1 {
        return "ControlFlow";
    };

    // PanickingArith
    if str_starts_with(bare, "checked_") == 1
        || str_starts_with(bare, "saturating_") == 1
        || str_starts_with(bare, "wrapping_") == 1
        || str_starts_with(bare, "overflow") == 1
        || str_starts_with(bare, "panic") == 1
        || str_starts_with(bare, "trap_") == 1
        || str_starts_with(bare, "bounds_check") == 1
        || str_starts_with(bare, "stack_probe") == 1
        || str_eq(bare, "assert") == 1
        || str_eq(bare, "sat_i32") == 1
        || str_eq(bare, "wrap_i32") == 1 {
        return "PanickingArith";
    };

    // Introspection
    if str_starts_with(bare, "sizeof_") == 1 {
        return "Introspection";
    };

    // ToolingMeta — compiler self-introspection (parse-depth recursion guard, etc.)
    if str_starts_with(bare, "parse_depth_") == 1 {
        return "ToolingMeta";
    };

    // ToolingMeta — clean compiler exit with diagnostic emission (Lane 1 F-019/F-026 path)
    if str_eq(bare, "diag_exit") == 1 {
        return "ToolingMeta";
    };

    // ADT
    if str_starts_with(bare, "option_") == 1
        || str_starts_with(bare, "result_") == 1 {
        return "ADT";
    };

    // PureMath
    if str_eq(bare, "popcount") == 1
        || str_eq(bare, "leading_zeros") == 1
        || str_eq(bare, "trailing_zeros") == 1
        || str_eq(bare, "byte_swap") == 1
        || str_eq(bare, "rotate_left") == 1
        || str_eq(bare, "rotate_right") == 1
        || str_eq(bare, "count_ones") == 1
        || str_eq(bare, "count_zeros") == 1
        || str_starts_with(bare, "i64_") == 1
        || str_starts_with(bare, "f64_") == 1
        || str_starts_with(bare, "f32_") == 1
        || str_starts_with(bare, "i32_") == 1
        || str_starts_with(bare, "f16_") == 1
        || str_eq(bare, "f8e4m2_to_f32") == 1 || str_eq(bare, "f8e4m3_to_f32") == 1
        || str_eq(bare, "f8e5m2_to_f32") == 1 || str_eq(bare, "f8e5m3_to_f32") == 1
        || str_eq(bare, "f8e4m2_from_f32") == 1 || str_eq(bare, "f8e4m3_from_f32") == 1
        || str_eq(bare, "f8e5m2_from_f32") == 1 || str_eq(bare, "f8e5m3_from_f32") == 1
        || str_eq(bare, "f8e4m2_to_str") == 1 || str_eq(bare, "f8e4m3_to_str") == 1
        || str_eq(bare, "f8e5m2_to_str") == 1 || str_eq(bare, "f8e5m3_to_str") == 1
        || str_eq(bare, "abs") == 1 || str_eq(bare, "min") == 1
        || str_eq(bare, "max") == 1 || str_eq(bare, "clamp") == 1
        || str_eq(bare, "sqrt") == 1 || str_eq(bare, "sin") == 1
        || str_eq(bare, "cos") == 1 || str_eq(bare, "tan") == 1
        || str_eq(bare, "pow") == 1 || str_eq(bare, "exp") == 1
        || str_eq(bare, "log") == 1 || str_eq(bare, "floor") == 1
        || str_eq(bare, "ceil") == 1 || str_eq(bare, "round") == 1
        || str_eq(bare, "fabs") == 1 || str_eq(bare, "fmod") == 1
        || str_eq(bare, "sigmoid") == 1 || str_eq(bare, "tanh") == 1
        || str_eq(bare, "relu") == 1 || str_eq(bare, "gelu") == 1
        || str_eq(bare, "as_f32") == 1 || str_eq(bare, "as_f64") == 1
        || str_eq(bare, "as_i8") == 1 || str_eq(bare, "as_i16") == 1
        || str_eq(bare, "as_i32") == 1 || str_eq(bare, "as_i64") == 1
        || str_eq(bare, "as_u8") == 1 || str_eq(bare, "as_u16") == 1
        || str_eq(bare, "as_u32") == 1 || str_eq(bare, "as_u64") == 1
        || str_starts_with(bare, "buf_read_u8") == 1
        || str_starts_with(bare, "buf_read_u16") == 1
        || str_starts_with(bare, "buf_read_u32") == 1
        || str_starts_with(bare, "buf_read_u64") == 1
        || str_starts_with(bare, "buf_write_u8") == 1
        || str_starts_with(bare, "buf_write_u16") == 1
        || str_starts_with(bare, "buf_write_u32") == 1
        || str_starts_with(bare, "buf_write_u64") == 1 {
        return "PureMath";
    };

    // DataCodec
    if str_starts_with(bare, "toml_") == 1
        || str_starts_with(bare, "json_") == 1
        || str_starts_with(bare, "csv_") == 1
        || str_starts_with(bare, "ini_") == 1
        || str_starts_with(bare, "base64_") == 1
        || str_starts_with(bare, "msgpack_") == 1
        || str_starts_with(bare, "uuid_") == 1
        || str_starts_with(bare, "sha256") == 1
        || str_starts_with(bare, "fnv1a") == 1
        || str_starts_with(bare, "murmur3") == 1
        || str_starts_with(bare, "crc32") == 1
        || str_starts_with(bare, "bit_") == 1 {
        return "DataCodec";
    };

    // Allocation (incl. dyn_box_*)
    if str_starts_with(bare, "region_") == 1
        || str_starts_with(bare, "arena_") == 1
        || str_starts_with(bare, "alloc_") == 1
        || str_eq(bare, "free") == 1
        || str_eq(bare, "realloc") == 1
        || str_starts_with(bare, "drop_") == 1
        || str_eq(bare, "malloc") == 1
        || str_eq(bare, "memcpy") == 1
        || str_eq(bare, "calloc") == 1
        || str_starts_with(bare, "capture_") == 1
        || str_starts_with(bare, "dyn_box_") == 1
        || str_eq(bare, "ptr_is_null") == 1 {
        return "Allocation";
    };

    // TensorOps
    if str_starts_with(bare, "tensor_") == 1
        || str_starts_with(bare, "matmul") == 1
        || str_starts_with(bare, "conv2d") == 1
        || str_starts_with(bare, "attention") == 1
        || str_starts_with(bare, "cuda_") == 1
        || str_starts_with(bare, "gpu_") == 1
        || str_starts_with(bare, "device_") == 1
        || str_starts_with(bare, "layout_") == 1
        || str_starts_with(bare, "dlpack_") == 1
        || str_starts_with(bare, "kvcache_") == 1
        || str_starts_with(bare, "kvprefix_") == 1 {
        return "TensorOps";
    };

    // ToolingMeta (incl. compile_src_*, str_cache_*, sym_aux_*, infer_*_cached)
    if str_starts_with(bare, "plot_") == 1
        || str_starts_with(bare, "profile_") == 1
        || str_starts_with(bare, "certify_") == 1
        || str_starts_with(bare, "evidence_") == 1
        || str_starts_with(bare, "impact_") == 1
        || str_starts_with(bare, "audit_") == 1
        || str_starts_with(bare, "policy_") == 1
        || str_starts_with(bare, "doc_") == 1
        || str_starts_with(bare, "manifest_") == 1
        || str_starts_with(bare, "stage_") == 1
        || str_starts_with(bare, "bench_") == 1
        || str_starts_with(bare, "cli_") == 1
        || str_starts_with(bare, "test_") == 1
        || str_starts_with(bare, "summary_") == 1
        || str_eq(bare, "py_eval") == 1
        || str_starts_with(bare, "compile_src_") == 1
        || str_starts_with(bare, "str_cache_") == 1
        || str_starts_with(bare, "sym_aux_") == 1
        || (str_starts_with(bare, "infer_") == 1 && str_ends_with(bare, "_cached") == 1)
        || str_starts_with(bare, "rods_f64_") == 1
        || str_eq(bare, "assert_eq") == 1 || str_eq(bare, "assert_ne") == 1
        || str_eq(bare, "dbg") == 1 {
        return "ToolingMeta";
    };

    // PureMath fallback for bf16
    if str_starts_with(bare, "bf16_") == 1 {
        return "PureMath";
    };

    return "Unclassified";
}

// ---------- effect resolution ----------

// Returns 1 if the helper has a NAME_OVERRIDES entry; populates the three
// out fields. Returns 0 otherwise (caller falls through to PATTERN_OVERRIDES
// then CLASS_DEFAULTS).
//
// Each branch packs (effects_csv, taint, proof). Empty effects_csv = "[]"
// effective (no effects); non-empty = comma-separated effect names.
fn name_override(name: str, eff_out: Vec<str>, taint_out: Vec<str>, proof_out: Vec<str>) -> i64 {
    let mut eff: str = "";
    let mut taint: str = "";
    let mut proof: str = "";
    let mut hit: i64 = 0;
    if str_eq(name, "panic") == 1 {
        eff = "panic"; taint = "passthrough"; proof = "callsite_unreachable_or_recoverable"; hit = 1;
    } else if str_eq(name, "assert") == 1 {
        eff = "panic"; taint = "passthrough"; proof = "predicate_holds"; hit = 1;
    } else if str_eq(name, "assert_eq") == 1 {
        eff = "panic"; taint = "passthrough"; proof = "predicate_holds"; hit = 1;
    } else if str_eq(name, "assert_ne") == 1 {
        eff = "panic"; taint = "passthrough"; proof = "predicate_holds"; hit = 1;
    } else if str_eq(name, "dbg") == 1 {
        eff = "io"; taint = "passthrough"; proof = "io_capability_required"; hit = 1;
    } else if str_eq(name, "manifest_report") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(name, "manifest_validate") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(name, "crc32") == 1 || str_eq(name, "crc32_update") == 1
            || str_eq(name, "fnv1a_64_i64") == 1 || str_eq(name, "fnv1a_64_str") == 1
            || str_eq(name, "murmur3_64") == 1 {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(name, "string_print") == 1 {
        eff = "io"; taint = "passthrough"; proof = "io_capability_required"; hit = 1;
    } else if str_eq(name, "rods_f64_add") == 1 || str_eq(name, "rods_f64_sub") == 1
            || str_eq(name, "rods_f64_div") == 1 {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(name, "rods_f64_encode") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(name, "option_unwrap") == 1 || str_eq(name, "option_expect") == 1
            || str_eq(name, "result_unwrap") == 1 || str_eq(name, "result_unwrap_err") == 1
            || str_eq(name, "result_expect") == 1 {
        eff = "panic"; taint = "passthrough"; proof = "predicate_holds"; hit = 1;
    } else if str_eq(name, "option_to_debug_str_i64") == 1
            || str_eq(name, "result_to_debug_str_i64") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(name, "dyn_box_data") == 1 || str_eq(name, "dyn_box_type") == 1 {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    }
    // VectorOps pure-read members
    // get effects=[] (and stay on bounds_within_len). Pre-fix the
    // class default `["alloc"]` was applied uniformly, masking the
    // pure-read posture and breaking @hot / @const_fn analysis.
    else if str_eq(name, "vec_get") == 1 || str_eq(name, "vec_len") == 1
            || str_eq(name, "vec_capacity") == 1 || str_eq(name, "vec_at") == 1
            || str_eq(name, "vec_is_empty") == 1 || str_eq(name, "vec_last") == 1
            || str_eq(name, "vec_index_of_i64") == 1
            || str_eq(name, "vec_contains") == 1 {
        eff = ""; taint = "passthrough"; proof = "bounds_within_len"; hit = 1;
    }
    // Lane 6 / EC2+A7: `vec_free` / `vec_*_free` carry the allocation
    // capability obligation, not bounds. Pre-fix `vec_free` shipped
    // with `bounds_within_len` (a free has no bounds).
    else if str_eq(name, "vec_free") == 1 || str_eq(name, "vec_u8_free") == 1
            || str_eq(name, "vec_f32_free") == 1 || str_eq(name, "vec_f64_free") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "alloc_capability_or_arena_owned"; hit = 1;
    }
    // Lane 6 / V3: `vec_pop` decrements length but does not allocate.
    else if str_eq(name, "vec_pop") == 1 || str_eq(name, "vec_set") == 1
            || str_eq(name, "vec_clear") == 1 {
        eff = ""; taint = "passthrough"; proof = "bounds_within_len"; hit = 1;
    };
    vec_push(eff_out, eff);
    vec_push(taint_out, taint);
    vec_push(proof_out, proof);
    return hit;
}

// PATTERN_OVERRIDES — first match wins. Returns 1 on hit.
fn pattern_override(name: str, eff_out: Vec<str>, taint_out: Vec<str>, proof_out: Vec<str>) -> i64 {
    let mut eff: str = "";
    let mut taint: str = "";
    let mut proof: str = "";
    let mut hit: i64 = 0;

    // ^(checked|wrapping|saturating)_
    if hit == 0 && (str_starts_with(name, "checked_") == 1
            || str_starts_with(name, "wrapping_") == 1
            || str_starts_with(name, "saturating_") == 1) {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^(sat|wrap)_i32$
    if hit == 0 && (str_eq(name, "sat_i32") == 1 || str_eq(name, "wrap_i32") == 1) {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^char_
    if hit == 0 && str_starts_with(name, "char_") == 1 {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^chr$
    if hit == 0 && str_eq(name, "chr") == 1 {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^str_(eq|contains|count|ends_with|starts_with|index_of|is_empty|len|char_at)$
    if hit == 0 && (str_eq(name, "str_eq") == 1 || str_eq(name, "str_contains") == 1
            || str_eq(name, "str_count") == 1 || str_eq(name, "str_ends_with") == 1
            || str_eq(name, "str_starts_with") == 1 || str_eq(name, "str_index_of") == 1
            || str_eq(name, "str_is_empty") == 1 || str_eq(name, "str_len") == 1
            || str_eq(name, "str_char_at") == 1) {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^str_to_(i64|f64|bool|i64_radix)$
    if hit == 0 && (str_eq(name, "str_to_i64") == 1 || str_eq(name, "str_to_f64") == 1
            || str_eq(name, "str_to_bool") == 1 || str_eq(name, "str_to_i64_radix") == 1) {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^parse_(hex|bin)$
    if hit == 0 && (str_eq(name, "parse_hex") == 1 || str_eq(name, "parse_bin") == 1) {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^string_(capacity|eq|eq_str|get_byte|len|starts_with|ends_with|contains|as_ptr)$
    if hit == 0 && (str_eq(name, "string_capacity") == 1 || str_eq(name, "string_eq") == 1
            || str_eq(name, "string_eq_str") == 1 || str_eq(name, "string_get_byte") == 1
            || str_eq(name, "string_len") == 1 || str_eq(name, "string_starts_with") == 1
            || str_eq(name, "string_ends_with") == 1 || str_eq(name, "string_contains") == 1
            || str_eq(name, "string_as_ptr") == 1) {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^(hashmap|hashset|btreemap|btreeset|vecdeque)_(get|contains|len|capacity|is_empty|get_or|key_at|val_at|at)$
    if hit == 0 {
        let prefixes: Vec<str> = vec_new();
        vec_push(prefixes, "hashmap_"); vec_push(prefixes, "hashset_");
        vec_push(prefixes, "btreemap_"); vec_push(prefixes, "btreeset_");
        vec_push(prefixes, "vecdeque_");
        let suffixes: Vec<str> = vec_new();
        vec_push(suffixes, "get"); vec_push(suffixes, "contains"); vec_push(suffixes, "len");
        vec_push(suffixes, "capacity"); vec_push(suffixes, "is_empty");
        vec_push(suffixes, "get_or"); vec_push(suffixes, "key_at");
        vec_push(suffixes, "val_at"); vec_push(suffixes, "at");
        let mut pi: i64 = 0;
        let mut found: i64 = 0;
        while pi < vec_len(prefixes) && found == 0 {
            let mut si: i64 = 0;
            while si < vec_len(suffixes) && found == 0 {
                let candidate: str = str_concat(vec_get(prefixes, pi), vec_get(suffixes, si));
                if str_eq(name, candidate) == 1 { found = 1; };
                si = si + 1;
            };
            pi = pi + 1;
        };
        if found == 1 { eff = ""; taint = "passthrough"; proof = "none"; hit = 1; };
    };
    // ^os_(family|pointer_width)$
    if hit == 0 && (str_eq(name, "os_family") == 1 || str_eq(name, "os_pointer_width") == 1) {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^path_(is_absolute|separator)$
    if hit == 0 && (str_eq(name, "path_is_absolute") == 1 || str_eq(name, "path_separator") == 1) {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^path_(components|normalize|strip_extension|with_extension)$
    if hit == 0 && (str_eq(name, "path_components") == 1 || str_eq(name, "path_normalize") == 1
            || str_eq(name, "path_strip_extension") == 1 || str_eq(name, "path_with_extension") == 1) {
        eff = "alloc"; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^fs_(basename|dirname|extension|join)$
    if hit == 0 && (str_eq(name, "fs_basename") == 1 || str_eq(name, "fs_dirname") == 1
            || str_eq(name, "fs_extension") == 1 || str_eq(name, "fs_join") == 1) {
        eff = "alloc"; taint = "passthrough"; proof = "none"; hit = 1;
    };
    // ^read_(byte|i64|line)$
    if hit == 0 && (str_eq(name, "read_byte") == 1 || str_eq(name, "read_i64") == 1
            || str_eq(name, "read_line") == 1) {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    // ^env_(get|has|keys)$
    if hit == 0 && (str_eq(name, "env_get") == 1 || str_eq(name, "env_has") == 1
            || str_eq(name, "env_keys") == 1) {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    if hit == 0 && str_eq(name, "getenv") == 1 {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    if hit == 0 && str_eq(name, "getcwd") == 1 {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    if hit == 0 && str_eq(name, "process_id") == 1 {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    if hit == 0 && str_starts_with(name, "isatty_") == 1 {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    // ^args_(count|get)$|^init_args$
    if hit == 0 && (str_eq(name, "args_count") == 1 || str_eq(name, "args_get") == 1
            || str_eq(name, "init_args") == 1) {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    // ^fs_(exists|is_dir|is_file|size|mtime|list_dir|canonicalize|current_dir|temp_dir)$
    if hit == 0 && (str_eq(name, "fs_exists") == 1 || str_eq(name, "fs_is_dir") == 1
            || str_eq(name, "fs_is_file") == 1 || str_eq(name, "fs_size") == 1
            || str_eq(name, "fs_mtime") == 1 || str_eq(name, "fs_list_dir") == 1
            || str_eq(name, "fs_canonicalize") == 1 || str_eq(name, "fs_current_dir") == 1
            || str_eq(name, "fs_temp_dir") == 1) {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    if hit == 0 && str_starts_with(name, "file_read_") == 1 {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    if hit == 0 && str_eq(name, "system") == 1 {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    // ^toml_(get_int|get_str|has)$
    if hit == 0 && (str_eq(name, "toml_get_int") == 1 || str_eq(name, "toml_get_str") == 1
            || str_eq(name, "toml_has") == 1) {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    if hit == 0 && str_eq(name, "toml_parse_file") == 1 {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    };
    if hit == 0 && str_eq(name, "uuid_v4") == 1 {
        eff = "random,alloc"; taint = "passthrough"; proof = "rng_capability_required"; hit = 1;
    };
    // ^tensor_(get|cols|rows|max|min|mean|sum|stddev|variance)$
    if hit == 0 && (str_eq(name, "tensor_get") == 1 || str_eq(name, "tensor_cols") == 1
            || str_eq(name, "tensor_rows") == 1 || str_eq(name, "tensor_max") == 1
            || str_eq(name, "tensor_min") == 1 || str_eq(name, "tensor_mean") == 1
            || str_eq(name, "tensor_sum") == 1 || str_eq(name, "tensor_stddev") == 1
            || str_eq(name, "tensor_variance") == 1) {
        eff = ""; taint = "passthrough"; proof = "bounds_within_shape"; hit = 1;
    };
    // ^tensor_(set|fill)$
    if hit == 0 && (str_eq(name, "tensor_set") == 1 || str_eq(name, "tensor_fill") == 1) {
        eff = ""; taint = "passthrough"; proof = "bounds_within_shape"; hit = 1;
    };
    // ^tensor_(zeros|ones|transpose|matmul)$
    if hit == 0 && (str_eq(name, "tensor_zeros") == 1 || str_eq(name, "tensor_ones") == 1
            || str_eq(name, "tensor_transpose") == 1 || str_eq(name, "tensor_matmul") == 1) {
        eff = "alloc"; taint = "passthrough"; proof = "shape_compatible"; hit = 1;
    };
    vec_push(eff_out, eff);
    vec_push(taint_out, taint);
    vec_push(proof_out, proof);
    return hit;
}

// Lane 6 / Manifest gaps: explicit ABI table for the manual extras
// added in `main()`. Returns "" if the symbol is not in this list,
// otherwise the IR-level signature string. Keep in sync with the
// rod-side `extern fn` declarations in stdlib/rods/process.nr,
// stdlib/rods/concurrency.nr.
fn lane6_manual_abi(sym: str) -> str {
    if str_eq(sym, "__nucleor_proc_run") == 1 { return "(ptr) -> i64"; };
    if str_eq(sym, "__nucleor_proc_run1") == 1 { return "(ptr, ptr) -> i64"; };
    if str_eq(sym, "__nucleor_proc_capture_stdout") == 1 { return "(ptr) -> ptr"; };
    if str_eq(sym, "__nucleor_proc_capture_status") == 1 { return "() -> i64"; };
    if str_eq(sym, "__nucleor_proc_capture_with_status") == 1 { return "(ptr) -> ptr"; };
    if str_eq(sym, "__nucleor_mutex_free") == 1 { return "(i64) -> void"; };
    if str_eq(sym, "__nucleor_mutex_free_value") == 1 { return "(i64) -> void"; };
    if str_eq(sym, "__nucleor_channel_close") == 1 { return "(i64) -> void"; };
    if str_eq(sym, "__nucleor_channel_is_closed") == 1 { return "(i64) -> i64"; };
    if str_eq(sym, "__nucleor_vec_u8_extend_from_ptr") == 1 { return "(i64, ptr, i64) -> i64"; };
    if str_eq(sym, "__nucleor_str_intern_stats") == 1 { return "() -> i64"; };
    return "";
}

// Lane 6: name overrides for the manual extras so they emit the
// correct effects/proof_obligation rather than falling to the (often
// generic) class default. proc_* are IO; mutex_free / channel_*
// are sync; vec_u8_extend_from_ptr is alloc; str_intern_stats is
// pure observability.
fn lane6_manual_name_override(name: str, eff_out: Vec<str>, taint_out: Vec<str>, proof_out: Vec<str>) -> i64 {
    let mut eff: str = ""; let mut taint: str = ""; let mut proof: str = "";
    let mut hit: i64 = 0;
    if str_eq(name, "proc_run") == 1 || str_eq(name, "proc_run1") == 1
            || str_eq(name, "proc_capture_stdout") == 1
            || str_eq(name, "proc_capture_with_status") == 1 {
        eff = "io,panic"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    } else if str_eq(name, "proc_capture_status") == 1 {
        eff = "io"; taint = "propagates"; proof = "io_capability_required"; hit = 1;
    } else if str_eq(name, "mutex_free") == 1 || str_eq(name, "mutex_free_value") == 1 {
        eff = "sync,alloc"; taint = "passthrough"; proof = "alloc_capability_or_arena_owned"; hit = 1;
    } else if str_eq(name, "channel_close") == 1 || str_eq(name, "channel_is_closed") == 1 {
        eff = "sync"; taint = "passthrough"; proof = "happens_before_release_acquire"; hit = 1;
    } else if str_eq(name, "vec_u8_extend_from_ptr") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "bounds_within_len"; hit = 1;
    } else if str_eq(name, "str_intern_stats") == 1 {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    };
    vec_push(eff_out, eff);
    vec_push(taint_out, taint);
    vec_push(proof_out, proof);
    return hit;
}

// CLASS_DEFAULTS — fallback after NAME / PATTERN overrides. Returns 1 if a
// default exists for this class, 0 if it falls through to REVIEW_REQUIRED sentinel.
fn class_default(cls: str, eff_out: Vec<str>, taint_out: Vec<str>, proof_out: Vec<str>) -> i64 {
    let mut eff: str = ""; let mut taint: str = ""; let mut proof: str = "";
    let mut hit: i64 = 0;
    if str_eq(cls, "PureMath") == 1 {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(cls, "VectorOps") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "bounds_within_len"; hit = 1;
    } else if str_eq(cls, "Random") == 1 {
        eff = "random"; taint = "passthrough"; proof = "rng_capability_required"; hit = 1;
    } else if str_eq(cls, "Time") == 1 {
        eff = "clock"; taint = "passthrough"; proof = "clock_capability_required"; hit = 1;
    } else if str_eq(cls, "Concurrency") == 1 {
        eff = "sync"; taint = "passthrough"; proof = "happens_before_release_acquire"; hit = 1;
    } else if str_eq(cls, "Allocation") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "alloc_capability_or_arena_owned"; hit = 1;
    } else if str_eq(cls, "StringFormat") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(cls, "Collection") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(cls, "IO") == 1 {
        eff = "io"; taint = "passthrough"; proof = "io_capability_required"; hit = 1;
    } else if str_eq(cls, "DataCodec") == 1 {
        eff = "alloc"; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(cls, "ADT") == 1 {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(cls, "Introspection") == 1 {
        eff = ""; taint = "passthrough"; proof = "none"; hit = 1;
    } else if str_eq(cls, "ControlFlow") == 1 {
        eff = "panic"; taint = "passthrough"; proof = "predicate_holds"; hit = 1;
    };
    vec_push(eff_out, eff);
    vec_push(taint_out, taint);
    vec_push(proof_out, proof);
    return hit;
}

// ---------- since map ----------

fn since_for(name: str) -> str {
    // v0.2.9
    if str_eq(name, "vec_map_i64") == 1 || str_eq(name, "vec_filter_i64") == 1
        || str_eq(name, "vec_fold_i64") == 1 || str_eq(name, "vec_each_i64") == 1
        || str_eq(name, "vec_sum_i64") == 1 || str_eq(name, "vec_min_i64") == 1
        || str_eq(name, "vec_max_i64") == 1 { return "0.2.9"; };
    // v0.2.10
    if str_eq(name, "vec_contains_i64") == 1 || str_eq(name, "vec_index_of_i64") == 1
        || str_eq(name, "vec_reverse_i64") == 1 || str_eq(name, "vec_sort_i64") == 1
        || str_eq(name, "vec_clone_i64") == 1 || str_eq(name, "vec_clear_i64") == 1 { return "0.2.10"; };
    // v0.2.13
    if str_eq(name, "vec_avg_i64") == 1 || str_eq(name, "vec_dot_i64") == 1
        || str_eq(name, "vec_count_eq_i64") == 1 || str_eq(name, "vec_any_i64") == 1
        || str_eq(name, "vec_all_i64") == 1 || str_eq(name, "vec_sum_f64") == 1
        || str_eq(name, "vec_min_f64") == 1 || str_eq(name, "vec_max_f64") == 1 { return "0.2.13"; };
    // v0.2.14
    if str_eq(name, "char_is_alpha") == 1 || str_eq(name, "char_is_digit") == 1
        || str_eq(name, "char_is_alnum") == 1 || str_eq(name, "char_is_whitespace") == 1
        || str_eq(name, "char_is_upper") == 1 || str_eq(name, "char_is_lower") == 1
        || str_eq(name, "char_is_hex_digit") == 1 || str_eq(name, "char_is_ascii") == 1
        || str_eq(name, "char_is_punct") == 1 || str_eq(name, "char_to_upper") == 1
        || str_eq(name, "char_to_lower") == 1 || str_eq(name, "char_digit_value") == 1 { return "0.2.14"; };
    // v0.2.15
    if str_eq(name, "rng_int") == 1 || str_eq(name, "rng_uniform") == 1
        || str_eq(name, "rng_normal") == 1 || str_eq(name, "rng_bernoulli") == 1
        || str_eq(name, "rng_exponential") == 1 || str_eq(name, "rng_seed") == 1
        || str_eq(name, "random_uniform") == 1 || str_eq(name, "random_normal") == 1 { return "0.2.15"; };
    // v0.2.16
    if str_eq(name, "hashmap_keys") == 1 || str_eq(name, "hashmap_values") == 1
        || str_eq(name, "time_iso_now") == 1 || str_eq(name, "time_format_iso") == 1 { return "0.2.16"; };
    // v0.2.17
    if str_eq(name, "fnv1a_64_str") == 1 || str_eq(name, "fnv1a_64_i64") == 1
        || str_eq(name, "murmur3_64") == 1 || str_eq(name, "print_raw") == 1
        || str_eq(name, "eprint_raw") == 1 { return "0.2.17"; };
    // v0.2.18
    if str_eq(name, "f64_abs") == 1 || str_eq(name, "f64_min") == 1
        || str_eq(name, "f64_max") == 1 || str_eq(name, "f64_sign") == 1
        || str_eq(name, "f64_copy_sign") == 1 || str_eq(name, "count_ones") == 1
        || str_eq(name, "count_zeros") == 1 { return "0.2.18"; };
    // v0.2.19
    if str_eq(name, "fs_temp_dir") == 1 || str_eq(name, "fs_current_dir") == 1
        || str_eq(name, "fs_remove_dir") == 1 || str_eq(name, "fs_copy_file") == 1
        || str_eq(name, "fs_canonicalize") == 1 { return "0.2.19"; };
    // v0.2.20
    if str_eq(name, "env_has") == 1 || str_eq(name, "env_keys") == 1
        || str_eq(name, "str_is_empty") == 1 || str_eq(name, "str_count") == 1
        || str_eq(name, "str_reverse") == 1 || str_eq(name, "str_trim_start") == 1
        || str_eq(name, "str_trim_end") == 1 { return "0.2.20"; };
    // v0.2.21
    if str_eq(name, "time_year") == 1 || str_eq(name, "time_month") == 1
        || str_eq(name, "time_day") == 1 || str_eq(name, "time_hour") == 1
        || str_eq(name, "time_minute") == 1 || str_eq(name, "time_second") == 1
        || str_eq(name, "time_weekday") == 1 || str_eq(name, "time_day_of_year") == 1
        || str_eq(name, "time_elapsed_ms") == 1 { return "0.2.21"; };
    // v0.2.22
    if str_eq(name, "vec_first") == 1 || str_eq(name, "vec_last") == 1
        || str_eq(name, "vec_is_empty") == 1 || str_eq(name, "vec_swap") == 1
        || str_eq(name, "vec_extend") == 1 || str_eq(name, "vec_remove_at") == 1
        || str_eq(name, "vec_insert_at") == 1 { return "0.2.22"; };
    // v0.2.23
    if str_eq(name, "path_separator") == 1 || str_eq(name, "path_is_absolute") == 1
        || str_eq(name, "path_normalize") == 1 || str_eq(name, "path_with_extension") == 1
        || str_eq(name, "path_strip_extension") == 1 || str_eq(name, "path_components") == 1 { return "0.2.23"; };
    // v0.2.24
    if str_eq(name, "str_to_i64") == 1 || str_eq(name, "str_to_f64") == 1
        || str_eq(name, "str_to_bool") == 1 || str_eq(name, "int_to_str") == 1
        || str_eq(name, "f64_to_str") == 1 || str_eq(name, "bool_to_str") == 1 { return "0.2.24"; };
    // v0.2.25
    if str_eq(name, "int_to_hex") == 1 || str_eq(name, "int_to_bin") == 1
        || str_eq(name, "int_to_oct") == 1 || str_eq(name, "str_to_i64_radix") == 1
        || str_eq(name, "parse_hex") == 1 || str_eq(name, "parse_bin") == 1 { return "0.2.25"; };
    // v0.2.26
    if str_eq(name, "str_pad_left") == 1 || str_eq(name, "str_pad_right") == 1
        || str_eq(name, "str_center") == 1 || str_eq(name, "str_join") == 1
        || str_eq(name, "str_lines") == 1 || str_eq(name, "str_chars") == 1 { return "0.2.26"; };
    // v0.2.27
    if str_eq(name, "hashmap_is_empty") == 1 || str_eq(name, "hashmap_get_or") == 1
        || str_eq(name, "hashmap_merge") == 1 || str_eq(name, "hashmap_clone") == 1 { return "0.2.27"; };
    // v0.2.28
    if str_eq(name, "checked_div") == 1 || str_eq(name, "checked_rem") == 1
        || str_eq(name, "checked_neg") == 1 || str_eq(name, "wrapping_div") == 1
        || str_eq(name, "wrapping_rem") == 1 || str_eq(name, "wrapping_neg") == 1
        || str_eq(name, "saturating_neg") == 1 { return "0.2.28"; };
    // v0.2.29
    if str_eq(name, "random_int") == 1 || str_eq(name, "random_bool") == 1
        || str_eq(name, "random_choice") == 1 || str_eq(name, "vec_shuffle") == 1
        || str_eq(name, "vec_sample") == 1 || str_eq(name, "random_fill") == 1 { return "0.2.29"; };
    // v0.2.30
    if str_eq(name, "vec_mean_f64") == 1 || str_eq(name, "vec_median_f64") == 1
        || str_eq(name, "vec_variance_f64") == 1 || str_eq(name, "vec_stddev_f64") == 1
        || str_eq(name, "vec_range_i64") == 1 || str_eq(name, "vec_percentile_f64") == 1 { return "0.2.30"; };
    return "0.1.0";
}

// ---------- intentional placeholder check ----------

fn is_intentional_placeholder(sym: str) -> i64 {
    // Build a hashmap on demand. For simplicity / clarity, use a chain of
    // str_eq comparisons. The set is ~50 entries.
    if str_eq(sym, "__nucleor_arena_alloc") == 1 || str_eq(sym, "__nucleor_arena_destroy") == 1
        || str_eq(sym, "__nucleor_arena_new") == 1 || str_eq(sym, "__nucleor_arena_reset") == 1
        || str_eq(sym, "__nucleor_region_alloc") == 1 || str_eq(sym, "__nucleor_region_free") == 1
        || str_eq(sym, "__nucleor_region_new") == 1 || str_eq(sym, "__nucleor_region_reset") == 1
        || str_eq(sym, "__nucleor_capture_get") == 1 || str_eq(sym, "__nucleor_capture_set") == 1
        || str_eq(sym, "__nucleor_ambient_scheduler") == 1
        || str_eq(sym, "__nucleor_cancel_token_cancel") == 1
        || str_eq(sym, "__nucleor_cancel_token_is_cancelled") == 1
        || str_eq(sym, "__nucleor_cancel_token_new") == 1
        || str_eq(sym, "__nucleor_par_fold") == 1 || str_eq(sym, "__nucleor_par_map") == 1
        || str_eq(sym, "__nucleor_par_reduce") == 1
        || str_eq(sym, "__nucleor_rwlock_new") == 1 || str_eq(sym, "__nucleor_rwlock_read") == 1
        || str_eq(sym, "__nucleor_rwlock_unlock") == 1 || str_eq(sym, "__nucleor_rwlock_write") == 1 { return 1; };
    if str_eq(sym, "__nucleor_vec_iter") == 1 || str_eq(sym, "__nucleor_vec_map") == 1
        || str_eq(sym, "__nucleor_vec_filter") == 1 || str_eq(sym, "__nucleor_vec_fold") == 1
        || str_eq(sym, "__nucleor_vec_all") == 1 || str_eq(sym, "__nucleor_vec_any") == 1
        || str_eq(sym, "__nucleor_vec_count") == 1 || str_eq(sym, "__nucleor_vec_chain") == 1
        || str_eq(sym, "__nucleor_vec_skip") == 1 || str_eq(sym, "__nucleor_vec_take") == 1
        || str_eq(sym, "__nucleor_vec_sum") == 1 { return 1; };
    if str_eq(sym, "__nucleor_ambient_random") == 1
        || str_eq(sym, "__nucleor_device_alloc") == 1 || str_eq(sym, "__nucleor_device_free") == 1
        || str_eq(sym, "__nucleor_device_transfer") == 1
        || str_eq(sym, "__nucleor_kvcache_append") == 1 || str_eq(sym, "__nucleor_kvcache_compact") == 1
        || str_eq(sym, "__nucleor_kvcache_evict") == 1 || str_eq(sym, "__nucleor_kvcache_free") == 1
        || str_eq(sym, "__nucleor_kvcache_new") == 1 || str_eq(sym, "__nucleor_kvcache_read_prefix") == 1
        || str_eq(sym, "__nucleor_kvprefix_free") == 1 { return 1; };
    if str_eq(sym, "__nucleor_tensor_center") == 1 || str_eq(sym, "__nucleor_tensor_clip") == 1
        || str_eq(sym, "__nucleor_tensor_entropy") == 1 || str_eq(sym, "__nucleor_tensor_greedy") == 1
        || str_eq(sym, "__nucleor_tensor_l1") == 1 || str_eq(sym, "__nucleor_tensor_l2") == 1
        || str_eq(sym, "__nucleor_tensor_len") == 1 || str_eq(sym, "__nucleor_tensor_mad") == 1
        || str_eq(sym, "__nucleor_tensor_median") == 1 || str_eq(sym, "__nucleor_tensor_minmax") == 1
        || str_eq(sym, "__nucleor_tensor_normalize_l2") == 1
        || str_eq(sym, "__nucleor_tensor_percentile") == 1
        || str_eq(sym, "__nucleor_tensor_sample_eps") == 1
        || str_eq(sym, "__nucleor_tensor_sample_gumbel") == 1
        || str_eq(sym, "__nucleor_tensor_sample_nucleus_temp") == 1
        || str_eq(sym, "__nucleor_tensor_sample_rank") == 1
        || str_eq(sym, "__nucleor_tensor_sample_topk_temp") == 1
        || str_eq(sym, "__nucleor_tensor_top2_gap") == 1
        || str_eq(sym, "__nucleor_tensor_view") == 1
        || str_eq(sym, "__nucleor_tensor_zscore") == 1 { return 1; };
    if str_eq(sym, "__nucleor_simd_add") == 1 || str_eq(sym, "__nucleor_simd_fma") == 1
        || str_eq(sym, "__nucleor_simd_mul") == 1
        || str_eq(sym, "__nucleor_vector_add") == 1 || str_eq(sym, "__nucleor_vector_broadcast") == 1
        || str_eq(sym, "__nucleor_vector_fma") == 1 || str_eq(sym, "__nucleor_vector_mul") == 1
        || str_eq(sym, "__nucleor_vector_new") == 1 || str_eq(sym, "__nucleor_vector_reduce_sum") == 1 { return 1; };
    if str_eq(sym, "__nucleor_profile_end") == 1 || str_eq(sym, "__nucleor_profile_start") == 1
        || str_eq(sym, "__nucleor_py_eval") == 1
        || str_eq(sym, "__nucleor_rods_f64_add") == 1 || str_eq(sym, "__nucleor_rods_f64_div") == 1
        || str_eq(sym, "__nucleor_rods_f64_encode") == 1 || str_eq(sym, "__nucleor_rods_f64_sub") == 1
        || str_eq(sym, "__nucleor_sat_i32") == 1 || str_eq(sym, "__nucleor_wrap_i32") == 1
        || str_eq(sym, "__nucleor_sha256") == 1 || str_eq(sym, "__nucleor_putchar") == 1 { return 1; };
    return 0;
}

// ---------- source parsers ----------

// Extract get_rt_name pairs from s1 source. Each match shape:
//   if str_eq(name, "X") { return "Y"; ... }
// where Y starts with "__nucleor_" (filter out non-runtime symbols).
fn parse_get_rt_name(src: str, names_out: Vec<str>, syms_out: Vec<str>) -> i64 {
    let lines: Vec<str> = str_lines(src);
    let n: i64 = vec_len(lines);
    let mut i: i64 = 0;
    while i < n {
        let line: str = vec_get(lines, i);
        let trim: str = str_trim(line);
        let needle1: str = "if str_eq(name, \"";
        let pos1: i64 = str_index_of(trim, needle1);
        if pos1 < 0 { i = i + 1; continue; };
        let after1: i64 = pos1 + str_len(needle1);
        let rest1: str = str_substring(trim, after1, str_len(trim));
        let close_q1: i64 = str_index_of(rest1, "\"");
        if close_q1 < 0 { i = i + 1; continue; };
        let nm: str = str_substring(rest1, 0, close_q1);
        let after_close: i64 = close_q1 + 1;
        let needle2: str = "return \"";
        let rest2: str = str_substring(rest1, after_close, str_len(rest1));
        let pos2: i64 = str_index_of(rest2, needle2);
        if pos2 < 0 { i = i + 1; continue; };
        let after2: i64 = pos2 + str_len(needle2);
        let rest3: str = str_substring(rest2, after2, str_len(rest2));
        let close_q2: i64 = str_index_of(rest3, "\"");
        if close_q2 < 0 { i = i + 1; continue; };
        let sym: str = str_substring(rest3, 0, close_q2);
        if str_starts_with(sym, "__nucleor_") == 1 {
            vec_push(names_out, nm);
            vec_push(syms_out, sym);
        };
        i = i + 1;
    };
    return vec_len(names_out);
}

// Extract names from a function body that match `if str_eq(name, "X") { return 1;`.
// Walks lines of `src` between fn_open_pattern and the next `^fn ` line.
// Used for is_void_ret and is_ptr_ret parsing.
fn parse_one_returner_set(src: str, fn_marker: str, out: Vec<str>) -> i64 {
    let lines: Vec<str> = str_lines(src);
    let n: i64 = vec_len(lines);
    let mut i: i64 = 0;
    let mut in_fn: i64 = 0;
    while i < n {
        let line: str = vec_get(lines, i);
        if in_fn == 0 {
            if str_index_of(line, fn_marker) >= 0 { in_fn = 1; };
            i = i + 1;
            continue;
        };
        // Stop at next fn declaration at column 0
        if str_starts_with(line, "fn ") == 1 || str_starts_with(line, "pub fn ") == 1 {
            break;
        };
        let trim: str = str_trim(line);
        let needle: str = "if str_eq(name, \"";
        let pos1: i64 = str_index_of(trim, needle);
        if pos1 < 0 { i = i + 1; continue; };
        let after1: i64 = pos1 + str_len(needle);
        let rest1: str = str_substring(trim, after1, str_len(trim));
        let close_q1: i64 = str_index_of(rest1, "\"");
        if close_q1 < 0 { i = i + 1; continue; };
        let nm: str = str_substring(rest1, 0, close_q1);
        // Verify "return 1;" follows in the same line
        if str_index_of(rest1, "return 1;") >= 0 {
            vec_push(out, nm);
        };
        i = i + 1;
    };
    return vec_len(out);
}

// Extract IR `declare RET @SYM(ARGS)` from sb_append calls.
// Each match: sb_append(sb, "declare i64 @__nucleor_foo(ptr, i64)\n");
// Returns parallel arrays: syms[i], rets[i], args_csv[i] (e.g. "ptr,i64").
fn parse_ir_declares(src: str, syms_out: Vec<str>, rets_out: Vec<str>, args_out: Vec<str>) -> i64 {
    let lines: Vec<str> = str_lines(src);
    let n: i64 = vec_len(lines);
    let mut i: i64 = 0;
    while i < n {
        let line: str = vec_get(lines, i);
        let needle: str = "sb_append(sb, \"declare ";
        let pos1: i64 = str_index_of(line, needle);
        if pos1 < 0 { i = i + 1; continue; };
        let after1: i64 = pos1 + str_len(needle);
        let rest1: str = str_substring(line, after1, str_len(line));
        // rest1 starts with "<ret> @<sym>(<args>)\\n\");"
        let space_pos: i64 = str_index_of(rest1, " ");
        if space_pos < 0 { i = i + 1; continue; };
        let ret: str = str_substring(rest1, 0, space_pos);
        let after_ret: str = str_substring(rest1, space_pos + 1, str_len(rest1));
        // after_ret starts with "@<sym>(<args>)"
        if str_starts_with(after_ret, "@") == 0 { i = i + 1; continue; };
        let sym_paren_start: i64 = 1;
        let paren_idx: i64 = str_index_of(after_ret, "(");
        if paren_idx < 0 { i = i + 1; continue; };
        let sym: str = str_substring(after_ret, sym_paren_start, paren_idx);
        let after_paren: str = str_substring(after_ret, paren_idx + 1, str_len(after_ret));
        let close_paren_idx: i64 = str_index_of(after_paren, ")");
        if close_paren_idx < 0 { i = i + 1; continue; };
        let args_raw: str = str_substring(after_paren, 0, close_paren_idx);
        // Normalize args: trim spaces, comma-join.
        let parts: Vec<str> = str_split(args_raw, ",");
        let np: i64 = vec_len(parts);
        let mut args_csv: str = "";
        let mut k: i64 = 0;
        while k < np {
            let trimmed: str = str_trim(vec_get(parts, k));
            if str_len(trimmed) > 0 {
                if str_len(args_csv) > 0 { args_csv = str_concat(args_csv, ", "); };
                args_csv = str_concat(args_csv, trimmed);
            };
            k = k + 1;
        };
        vec_push(syms_out, sym);
        vec_push(rets_out, ret);
        vec_push(args_out, args_csv);
        i = i + 1;
    };
    return vec_len(syms_out);
}

// Walk stdlib/runtime/*.c, collect __nucleor_* symbols defined as function
// bodies. Also expand NUC_DEFINE_(SIGNED|UNSIGNED)_OVERFLOW(width, ...)
// macros to their 9 generated symbols per width.
fn collect_runtime_defs(out: Vec<str>) -> i64 {
    let entries: Vec<str> = fs_list_dir("stdlib/runtime");
    let n: i64 = vec_len(entries);
    // Sort entries for deterministic order
    sort_strs(entries);
    let macro_fns: Vec<str> = vec_new();
    vec_push(macro_fns, "wrapping_add"); vec_push(macro_fns, "wrapping_sub");
    vec_push(macro_fns, "wrapping_mul"); vec_push(macro_fns, "saturating_add");
    vec_push(macro_fns, "saturating_sub"); vec_push(macro_fns, "saturating_mul");
    vec_push(macro_fns, "checked_add"); vec_push(macro_fns, "checked_sub");
    vec_push(macro_fns, "checked_mul");
    let n_mfns: i64 = vec_len(macro_fns);
    let mut i: i64 = 0;
    while i < n {
        let fname: str = vec_get(entries, i);
        if str_ends_with(fname, ".c") == 0 { i = i + 1; continue; };
        let path: str = str_concat("stdlib/runtime/", fname);
        let text: str = file_read_string(path);
        let tlen: i64 = str_len(text);
        // Direct fn defs: scan for "__nucleor_<ident>("
        let needle: str = "__nucleor_";
        let mut p: i64 = 0;
        while p < tlen {
            let off: i64 = str_index_of(str_substring(text, p, tlen), needle);
            if off < 0 { break; };
            let abs_pos: i64 = p + off;
            let start: i64 = abs_pos;
            let mut q: i64 = start + str_len(needle);
            // Walk forward over identifier chars
            while q < tlen {
                let c: i64 = str_char_at(text, q);
                let is_id: i64 = if c >= 97 && c <= 122 { 1 }
                    else if c >= 65 && c <= 90 { 1 }
                    else if c >= 48 && c <= 57 { 1 }
                    else if c == 95 { 1 }
                    else { 0 };
                if is_id == 0 { break; };
                q = q + 1;
            };
            // Require `(` immediately after to count as a function
            if q < tlen && str_char_at(text, q) == 40 {
                let sym: str = str_substring(text, start, q);
                vec_push(out, sym);
            };
            p = q;
        };
        // Macro expansions: NUC_DEFINE_SIGNED_OVERFLOW(width, ...)
        // and NUC_DEFINE_UNSIGNED_OVERFLOW(width, ...)
        let macros: Vec<str> = vec_new();
        vec_push(macros, "NUC_DEFINE_SIGNED_OVERFLOW(");
        vec_push(macros, "NUC_DEFINE_UNSIGNED_OVERFLOW(");
        let mut mi: i64 = 0;
        while mi < vec_len(macros) {
            let mac: str = vec_get(macros, mi);
            let mut mp: i64 = 0;
            while mp < tlen {
                let moff: i64 = str_index_of(str_substring(text, mp, tlen), mac);
                if moff < 0 { break; };
                let abs_mpos: i64 = mp + moff;
                let mq: i64 = abs_mpos + str_len(mac);
                // Skip whitespace, then read identifier (the width)
                let mut wp: i64 = mq;
                while wp < tlen && str_char_at(text, wp) == 32 { wp = wp + 1; };
                let wstart: i64 = wp;
                while wp < tlen {
                    let wc: i64 = str_char_at(text, wp);
                    let is_id: i64 = if wc >= 97 && wc <= 122 { 1 }
                        else if wc >= 65 && wc <= 90 { 1 }
                        else if wc >= 48 && wc <= 57 { 1 }
                        else if wc == 95 { 1 }
                        else { 0 };
                    if is_id == 0 { break; };
                    wp = wp + 1;
                };
                if wp > wstart {
                    let width: str = str_substring(text, wstart, wp);
                    let mut fi: i64 = 0;
                    while fi < n_mfns {
                        let fn_name: str = vec_get(macro_fns, fi);
                        let sym: str = str_concat("__nucleor_", str_concat(fn_name, str_concat("_", width)));
                        vec_push(out, sym);
                        fi = fi + 1;
                    };
                };
                mp = wp;
            };
            mi = mi + 1;
        };
        i = i + 1;
    };
    return vec_len(out);
}

// ---------- main ----------

fn fmt_abi(ret: str, args_csv: str) -> str {
    if str_len(ret) == 0 { return "REVIEW_REQUIRED"; };
    return str_concat("(", str_concat(args_csv, str_concat(") -> ", ret)));
}

fn main() -> i64 {
    let s1_path: str = "compiler/nucleor_s1_compiler.nr";
    let out_path: str = "docs/rfcs/helper_manifest.toml";
    let src: str = file_read_string(s1_path);
    if str_len(src) == 0 {
        print(str_concat("ERROR: gen_helper_manifest: cannot read ", s1_path));
        return 1;
    };

    // Parse rt-name pairs
    let rt_names: Vec<str> = vec_new();
    let rt_syms: Vec<str> = vec_new();
    parse_get_rt_name(src, rt_names, rt_syms);

    // Parse IR declares
    let ir_syms: Vec<str> = vec_new();
    let ir_rets: Vec<str> = vec_new();
    let ir_args: Vec<str> = vec_new();
    parse_ir_declares(src, ir_syms, ir_rets, ir_args);

    // Build sym -> ir_idx hashmap for fast lookup
    let ir_idx: i64 = hashmap_new();
    let mut ki: i64 = 0;
    while ki < vec_len(ir_syms) {
        hashmap_insert(ir_idx, vec_get(ir_syms, ki), ki);
        ki = ki + 1;
    };

    // Collect runtime defs
    let rt_defs: Vec<str> = vec_new();
    collect_runtime_defs(rt_defs);
    // Build a hashmap for membership lookup: sym -> 1
    let rt_def_set: i64 = hashmap_new();
    let mut rdi: i64 = 0;
    while rdi < vec_len(rt_defs) {
        hashmap_insert(rt_def_set, vec_get(rt_defs, rdi), 1);
        rdi = rdi + 1;
    };

    // by_symbol: dedup rt_pairs (first short name wins per symbol)
    let bs_syms: Vec<str> = vec_new();
    let bs_names: Vec<str> = vec_new();
    let bs_seen: i64 = hashmap_new();
    let mut pi: i64 = 0;
    let n_pairs: i64 = vec_len(rt_names);
    while pi < n_pairs {
        let nm: str = vec_get(rt_names, pi);
        let sym: str = vec_get(rt_syms, pi);
        if hashmap_contains(bs_seen, sym) == 0 {
            hashmap_insert(bs_seen, sym, 1);
            vec_push(bs_syms, sym);
            vec_push(bs_names, nm);
        };
        pi = pi + 1;
    };

    // Add IR-only symbols (in IR declares but no get_rt_name mapping)
    let ir_keys_sorted: Vec<str> = vec_new();
    let mut ki2: i64 = 0;
    while ki2 < vec_len(ir_syms) {
        vec_push(ir_keys_sorted, vec_get(ir_syms, ki2));
        ki2 = ki2 + 1;
    };
    sort_strs(ir_keys_sorted);
    let mut ki3: i64 = 0;
    while ki3 < vec_len(ir_keys_sorted) {
        let sym: str = vec_get(ir_keys_sorted, ki3);
        if hashmap_contains(bs_seen, sym) == 0 {
            hashmap_insert(bs_seen, sym, 1);
            // short = sym[len("__nucleor_"):] — guard against short
            // libc-style externs (e.g. `malloc`, `free`) that don't
            // carry the prefix; for those the short form is just the
            // sym itself.
            let short: str = if str_starts_with(sym, "__nucleor_") == 1 {
                str_substring(sym, 10, str_len(sym))
            } else { sym };
            vec_push(bs_syms, sym);
            vec_push(bs_names, short);
        };
        ki3 = ki3 + 1;
    };

    // Public runtime
    // surfaces called from rod-level via `extern fn` rather than
    // through the `get_rt_name` ABI table or IR declares. Pre-fix the
    // generator never saw them, so the manifest had no row for them
    // even though the linker could resolve a call. The list is
    // hand-maintained because the rod-level extern fn declarations
    // are not parsed by this generator. New entries should be added
    // here when a new `__nucleor_*` symbol is exported only via
    // `stdlib/runtime/*.c` + a rod-level `extern fn`.
    let mut manual_extras: Vec<str> = vec_new();
    vec_push(manual_extras, "__nucleor_proc_run");
    vec_push(manual_extras, "__nucleor_proc_run1");
    vec_push(manual_extras, "__nucleor_proc_capture_stdout");
    vec_push(manual_extras, "__nucleor_proc_capture_status");
    vec_push(manual_extras, "__nucleor_proc_capture_with_status");
    vec_push(manual_extras, "__nucleor_mutex_free");
    vec_push(manual_extras, "__nucleor_mutex_free_value");
    vec_push(manual_extras, "__nucleor_channel_close");
    vec_push(manual_extras, "__nucleor_channel_is_closed");
    vec_push(manual_extras, "__nucleor_vec_u8_extend_from_ptr");
    vec_push(manual_extras, "__nucleor_str_intern_stats");
    let mut me_i: i64 = 0;
    while me_i < vec_len(manual_extras) {
        let sym: str = vec_get(manual_extras, me_i);
        if hashmap_contains(bs_seen, sym) == 0 {
            hashmap_insert(bs_seen, sym, 1);
            let short: str = str_substring(sym, 10, str_len(sym));
            vec_push(bs_syms, sym);
            vec_push(bs_names, short);
        };
        me_i = me_i + 1;
    };
    // Also feed these into the rt_def_set so they are tagged
    // `stable` (definitions exist in stdlib/runtime/*.c) rather
    // than `experimental` / REVIEW REQUIRED.
    let mut me_i2: i64 = 0;
    while me_i2 < vec_len(manual_extras) {
        let sym2: str = vec_get(manual_extras, me_i2);
        if hashmap_contains(rt_def_set, sym2) == 0 {
            hashmap_insert(rt_def_set, sym2, 1);
        };
        me_i2 = me_i2 + 1;
    };

    let n_helpers: i64 = vec_len(bs_syms);

    // Build per-row data via parallel arrays.
    let row_names: Vec<str> = vec_new();
    let row_classes: Vec<str> = vec_new();
    let row_syms: Vec<str> = vec_new();
    let row_abis: Vec<str> = vec_new();
    let row_effects: Vec<str> = vec_new();   // e.g. "[]" or "[\"alloc\"]"
    let row_taints: Vec<str> = vec_new();
    let row_proofs: Vec<str> = vec_new();
    let row_stabilities: Vec<str> = vec_new();
    let row_sinces: Vec<str> = vec_new();
    let row_notes: Vec<str> = vec_new();

    let mut hi: i64 = 0;
    while hi < n_helpers {
        let sym: str = vec_get(bs_syms, hi);
        let name: str = vec_get(bs_names, hi);
        let cls: str = classify(name);
        let defined: i64 = hashmap_contains(rt_def_set, sym);
        let intentional: i64 = is_intentional_placeholder(sym);
        // stability
        let stability: str = if defined == 1 { "stable" }
            else if intentional == 1 { "unstable" }
            else { "experimental" };
        // notes
        let mut notes: str = "";
        if defined == 0 && intentional == 1 {
            notes = "intentional v0.4 placeholder; declared in IR for forward compat, runtime body deferred";
        } else if defined == 0 {
            notes = "declared in IR but no __nucleor_* definition found in stdlib/runtime/*.c (REVIEW REQUIRED)";
        };
        if str_eq(cls, "Unclassified") == 1 {
            if str_len(notes) > 0 {
                notes = str_concat(notes, "; name pattern did not match any class rule (REVIEW REQUIRED)");
            } else {
                notes = "name pattern did not match any class rule (REVIEW REQUIRED)";
            };
        };
        // effects resolution: NAME -> PATTERN -> CLASS_DEFAULTS -> REVIEW_REQUIRED
        let eff_buf: Vec<str> = vec_new();
        let taint_buf: Vec<str> = vec_new();
        let proof_buf: Vec<str> = vec_new();
        let mut resolved: i64 = 0;
        if name_override(name, eff_buf, taint_buf, proof_buf) == 1 { resolved = 1; }
        else if lane6_manual_name_override(name, eff_buf, taint_buf, proof_buf) == 1 { resolved = 1; }
        else if pattern_override(name, eff_buf, taint_buf, proof_buf) == 1 { resolved = 1; }
        else if class_default(cls, eff_buf, taint_buf, proof_buf) == 1 { resolved = 1; };
        let mut effects_field: str = "REVIEW_REQUIRED";
        let mut taint_val: str = "REVIEW_REQUIRED";
        let mut proof_val: str = "REVIEW_REQUIRED";
        if resolved == 1 {
            // Take the LAST entry pushed (each helper push in three steps)
            let last_idx: i64 = vec_len(eff_buf) - 1;
            let eff_csv: str = vec_get(eff_buf, last_idx);
            taint_val = vec_get(taint_buf, last_idx);
            proof_val = vec_get(proof_buf, last_idx);
            // Format effects as TOML array literal
            if str_len(eff_csv) == 0 {
                effects_field = "[]";
            } else {
                let parts: Vec<str> = str_split(eff_csv, ",");
                let np: i64 = vec_len(parts);
                effects_field = "[";
                let mut ei: i64 = 0;
                while ei < np {
                    if ei > 0 { effects_field = str_concat(effects_field, ", "); };
                    effects_field = str_concat(effects_field, str_concat("\"", str_concat(vec_get(parts, ei), "\"")));
                    ei = ei + 1;
                };
                effects_field = str_concat(effects_field, "]");
            };
        };
        // ABI — Lane 6 manual_extras get explicit overrides since
        // they are never declared in IR (they enter the helper set
        // via `extern fn` in rod source).
        let mut abi: str = if hashmap_contains(ir_idx, sym) == 1 {
            let idx: i64 = hashmap_get(ir_idx, sym);
            fmt_abi(vec_get(ir_rets, idx), vec_get(ir_args, idx))
        } else { "REVIEW_REQUIRED" };
        if str_eq(abi, "REVIEW_REQUIRED") == 1 {
            let m_abi: str = lane6_manual_abi(sym);
            if str_len(m_abi) > 0 { abi = m_abi; };
        };
        let since: str = since_for(name);
        vec_push(row_names, name);
        vec_push(row_classes, cls);
        vec_push(row_syms, sym);
        vec_push(row_abis, abi);
        vec_push(row_effects, effects_field);
        vec_push(row_taints, taint_val);
        vec_push(row_proofs, proof_val);
        vec_push(row_stabilities, stability);
        vec_push(row_sinces, since);
        vec_push(row_notes, notes);
        hi = hi + 1;
    };

    // Sort rows by (class, name). Pack class index + name lexicographic into
    // a sort key string: "<class>\0<name>".
    let class_name_keys: Vec<str> = vec_new();
    let mut ri: i64 = 0;
    while ri < n_helpers {
        let key: str = str_concat(vec_get(row_classes, ri),
                       str_concat("\0", vec_get(row_names, ri)));
        vec_push(class_name_keys, key);
        ri = ri + 1;
    };
    // Insertion-sort indices by class_name_keys
    let order: Vec<i64> = vec_new();
    let mut oi: i64 = 0;
    while oi < n_helpers { vec_push(order, oi); oi = oi + 1; };
    // Stable insertion sort: shift only when strictly greater (key < current).
    // Stability matters because rows with the same (class, name) — e.g.,
    // by_symbol entries that share a short name but map to different symbols
    // — must preserve insertion order to match Python's dict-iteration order.
    let mut ii: i64 = 1;
    while ii < n_helpers {
        let key_idx: i64 = vec_get(order, ii);
        let key: str = vec_get(class_name_keys, key_idx);
        let mut jj: i64 = ii - 1;
        while jj >= 0 && str_lt(key, vec_get(class_name_keys, vec_get(order, jj))) == 1 {
            vec_set(order, jj + 1, vec_get(order, jj));
            jj = jj - 1;
        };
        vec_set(order, jj + 1, key_idx);
        ii = ii + 1;
    };

    // Build review list: rows where notes contains "REVIEW REQUIRED"
    let review_indices: Vec<i64> = vec_new();
    let mut rvi: i64 = 0;
    while rvi < n_helpers {
        let oidx: i64 = vec_get(order, rvi);
        if str_index_of(vec_get(row_notes, oidx), "REVIEW REQUIRED") >= 0 {
            vec_push(review_indices, oidx);
        };
        rvi = rvi + 1;
    };
    let n_review: i64 = vec_len(review_indices);

    // Emit TOML
    let mut out: str = "";
    out = str_concat(out, "# helper_manifest.toml\n");
    out = str_concat(out, "#\n");
    out = str_concat(out, "# Source-of-truth schema map for every helper in the Nucleor distribution\n");
    out = str_concat(out, "# project. Generated by tools/gen_helper_manifest.nr from the\n");
    out = str_concat(out, "# canonical compiler ABI tables and runtime C source. Do not edit\n");
    out = str_concat(out, "# by hand — re-run the generator after adding any helper.\n");
    out = str_concat(out, "#\n");
    out = str_concat(out, "# Schema: see docs/rfcs/helper_manifest_schema.md\n");
    out = str_concat(out, "# Contract: see docs/rfcs/HELPER-CONTRACT.md\n");
    out = str_concat(out, str_concat("# Total helpers: ", str_concat(int_to_str(n_helpers), "\n")));
    out = str_concat(out, str_concat("# Of which REVIEW REQUIRED: ", str_concat(int_to_str(n_review), "\n")));
    out = str_concat(out, "\n");

    // REVIEW REQUIRED block
    out = str_concat(out, "# ============================================================\n");
    out = str_concat(out, "# REVIEW REQUIRED\n");
    out = str_concat(out, "# ============================================================\n");
    out = str_concat(out, "# These helpers need a human pass before their rows below can be\n");
    out = str_concat(out, "# considered authoritative. Two reasons trigger inclusion:\n");
    out = str_concat(out, "#  1. Declared in IR but no __nucleor_* definition found in the\n");
    out = str_concat(out, "#     runtime (latent linker gap from earlier eras OR the symbol\n");
    out = str_concat(out, "#     is generated by a runtime macro the regex didn't match).\n");
    out = str_concat(out, "#  2. Name pattern didn't match any class rule (Unclassified).\n");
    out = str_concat(out, "# Each row is still emitted below with `stability = \"experimental\"`\n");
    out = str_concat(out, "# or `class = \"Unclassified\"` so callers can find them.\n");
    out = str_concat(out, "#\n");
    let mut revi: i64 = 0;
    while revi < n_review {
        let idx: i64 = vec_get(review_indices, revi);
        let mut bits: str = "";
        if str_eq(vec_get(row_classes, idx), "Unclassified") == 1 {
            bits = "Unclassified";
        };
        if str_eq(vec_get(row_stabilities, idx), "experimental") == 1 {
            if str_len(bits) > 0 { bits = str_concat(bits, ", "); };
            bits = str_concat(bits, "undefined");
        };
        let nm_padded: str = pad_right_spaces(vec_get(row_names, idx), 40);
        out = str_concat(out, str_concat("#   ", str_concat(nm_padded, str_concat(" (", str_concat(bits, ")\n")))));
        revi = revi + 1;
    };
    out = str_concat(out, "\n");

    // Emit per-row data
    let mut last_class: str = "";
    let mut wi: i64 = 0;
    while wi < n_helpers {
        let idx: i64 = vec_get(order, wi);
        let cls: str = vec_get(row_classes, idx);
        if str_eq(cls, last_class) == 0 {
            out = str_concat(out, "\n");
            out = str_concat(out, str_concat("# ----- class: ", str_concat(cls, " -----\n")));
            out = str_concat(out, "\n");
            last_class = cls;
        };
        out = str_concat(out, "[[helper]]\n");
        out = str_concat(out, str_concat("name             = \"", str_concat(vec_get(row_names, idx), "\"\n")));
        out = str_concat(out, str_concat("class            = \"", str_concat(cls, "\"\n")));
        out = str_concat(out, str_concat("symbol           = \"", str_concat(vec_get(row_syms, idx), "\"\n")));
        out = str_concat(out, "dispatch         = \"RuntimeCall\"\n");
        out = str_concat(out, str_concat("abi              = \"", str_concat(vec_get(row_abis, idx), "\"\n")));
        let eff: str = vec_get(row_effects, idx);
        if str_starts_with(eff, "[") == 1 {
            out = str_concat(out, str_concat("effects          = ", str_concat(eff, "\n")));
        } else {
            out = str_concat(out, str_concat("effects          = \"", str_concat(eff, "\"  # review required\n")));
        };
        let taint: str = vec_get(row_taints, idx);
        if str_eq(taint, "REVIEW_REQUIRED") == 1 {
            out = str_concat(out, str_concat("taint            = \"", str_concat(taint, "\"  # verify before use\n")));
        } else {
            out = str_concat(out, str_concat("taint            = \"", str_concat(taint, "\"\n")));
        };
        out = str_concat(out, "units            = \"passthrough\"\n");
        let proof: str = vec_get(row_proofs, idx);
        if str_eq(proof, "REVIEW_REQUIRED") == 1 {
            out = str_concat(out, str_concat("proof_obligation = \"", str_concat(proof, "\"  # verify before use\n")));
        } else {
            out = str_concat(out, str_concat("proof_obligation = \"", str_concat(proof, "\"\n")));
        };
        out = str_concat(out, str_concat("stability        = \"", str_concat(vec_get(row_stabilities, idx), "\"\n")));
        out = str_concat(out, str_concat("since            = \"", str_concat(vec_get(row_sinces, idx), "\"\n")));
        let notes: str = vec_get(row_notes, idx);
        if str_len(notes) > 0 {
            out = str_concat(out, str_concat("notes            = \"", str_concat(notes, "\"\n")));
        } else {
            out = str_concat(out, "notes            = \"\"\n");
        };
        // Blank line BETWEEN helper blocks, not after the last one
        // (matches Python's "\n".join(out_lines) with trailing "" sentinel).
        if wi < n_helpers - 1 {
            out = str_concat(out, "\n");
        };
        wi = wi + 1;
    };

    file_write_string(out_path, out);

    print(str_concat("Wrote ", out_path));
    print(str_concat("Total helpers: ", int_to_str(n_helpers)));
    print(str_concat("REVIEW REQUIRED: ", int_to_str(n_review)));
    // Per-class counts
    let class_counts_keys: Vec<str> = vec_new();
    let class_counts_vals: Vec<i32> = vec_new();
    let class_counts_idx: i64 = hashmap_new();
    let mut cci: i64 = 0;
    while cci < n_helpers {
        let cls: str = vec_get(row_classes, cci);
        if hashmap_contains(class_counts_idx, cls) == 1 {
            let kix: i64 = hashmap_get(class_counts_idx, cls);
            vec_set(class_counts_vals, kix, (vec_get(class_counts_vals, kix) as i64 + 1) as i32);
        } else {
            hashmap_insert(class_counts_idx, cls, vec_len(class_counts_keys));
            vec_push(class_counts_keys, cls);
            vec_push(class_counts_vals, 1);
        };
        cci = cci + 1;
    };
    // Sort by descending count
    let n_classes: i64 = vec_len(class_counts_keys);
    let class_order: Vec<i64> = vec_new();
    let mut cco: i64 = 0;
    while cco < n_classes { vec_push(class_order, cco); cco = cco + 1; };
    let mut ci2: i64 = 1;
    while ci2 < n_classes {
        let ck: i64 = vec_get(class_order, ci2);
        let cv: i64 = vec_get(class_counts_vals, ck) as i64;
        let mut cj: i64 = ci2 - 1;
        while cj >= 0 && (vec_get(class_counts_vals, vec_get(class_order, cj)) as i64) < cv {
            vec_set(class_order, cj + 1, vec_get(class_order, cj));
            cj = cj - 1;
        };
        vec_set(class_order, cj + 1, ck);
        ci2 = ci2 + 1;
    };
    let mut cpi: i64 = 0;
    while cpi < n_classes {
        let oidx: i64 = vec_get(class_order, cpi);
        let cls: str = vec_get(class_counts_keys, oidx);
        let cnt: i64 = vec_get(class_counts_vals, oidx) as i64;
        let padded: str = pad_right_spaces(cls, 20);
        print(str_concat("  ", str_concat(padded, str_concat(" ", int_to_str(cnt)))));
        cpi = cpi + 1;
    };
    return 0;
}
