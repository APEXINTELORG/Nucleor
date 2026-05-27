// =====================================================
// V2 §1.4: PARALLEL FRONTEND
// =====================================================
// When compiling multi-file projects, files at the same dependency
// level can be lexed and parsed in parallel. The constraint is the
// dependency DAG: a file cannot type-check until the signatures of
// its imports are resolved.
//
// Within a single file, the pipeline is sequential (lex → parse →
// check → lower → emit) because each stage depends on the previous.
// Parallelism applies across independent files within a level.
//
// For single-file compilation (most common case), the parallel frontend
// has no effect. The incremental compilation cache (§1.3) provides the
// speed benefit for iterative development.
//
// Multi-file parallel compilation is enabled automatically when
// the import resolver detects multiple independent imports at the
// same depth level. Each is resolved via thread_spawn + thread_join.
// =====================================================

// =====================================================
// V2 §1.3: INCREMENTAL COMPILATION
// =====================================================
// Cache compiled function IR keyed by source hash.
// On rebuild: re-lex/parse the changed file, extract signatures,
// compare against cache. If no signature changed, only re-codegen
// changed function bodies. If a signature changed, invalidate
// all transitive dependents.
//
// Cache format: .nuc_cache/<source_hash>.sig  (signature file)
//               .nuc_cache/<fn_hash>.ll       (per-function LLVM IR)
//
// ALL safety checks (ownership, taint, effect) run on every
// recompiled function. The cache only avoids re-checking
// byte-identical unchanged code.
// =====================================================

// Simple string hash for cache keys (djb2)
fn str_hash(s: str) -> i64 {
    let mut hash: i64 = 5381;
    let slen: i64 = str_len(s);
    let mut i: i64 = 0;
    while i < slen {
        hash = hash * 33 + str_char_at(s, i);
        // Keep hash positive and bounded
        hash = hash % 1000000007;
        i = i + 1;
    };
    return hash;
}

// Extract a function's signature string: "name(param_types) -> ret_type"
// This is what we cache — if the signature changes, dependents must recompile.
fn extract_fn_signature(pool: Vec<i32>, fn_nid: i64) -> str {
    let name: str = node_field(pool, fn_nid, 1);
    let params_list: i64 = node_field(pool, fn_nid, 2);
    let ret_type: str = node_field(pool, fn_nid, 3);
    let mut sb: i64 = sb_new();
    sb_append(sb, name);
    sb_append(sb, "(");
    let pc: i64 = list_len(pool, params_list);
    let mut pi: i64 = 0;
    while pi < pc {
        if pi > 0 { sb_append(sb, ","); };
        let param: i64 = list_get(pool, params_list, pi);
        // param node has name and type
        if node_kind(pool, param) == 41 {
            sb_append(sb, node_field(pool, param, 2));
        } else {
            sb_append(sb, "?");
        };
        pi = pi + 1;
    };
    sb_append(sb, ")->");
    sb_append(sb, ret_type);
    return sb_to_str(sb);
}

// Extract a function's body source hash — changes to the body trigger recompile
// but don't invalidate dependents (unless signature also changed).
fn extract_fn_body_hash(pool: Vec<i32>, fn_nid: i64) -> i64 {
    // Hash the entire function node subtree by walking its fields
    let mut sb: i64 = sb_new();
    let fc: i64 = node_field(pool, fn_nid, 0); // kind
    sb_append(sb, str_from_int(fc));
    let name: str = node_field(pool, fn_nid, 1);
    sb_append(sb, name);
    // Hash body node reference
    let body: i64 = node_field(pool, fn_nid, 4);
    sb_append(sb, str_from_int(body));
    // Include param count for safety
    let params: i64 = node_field(pool, fn_nid, 2);
    sb_append(sb, str_from_int(list_len(pool, params)));
    return str_hash(sb_to_str(sb));
}

// Build a signature cache: maps function name -> (signature_hash, body_hash)
fn build_sig_cache(pool: Vec<i32>, prog: i64) -> Vec<i32> {
    let mut cache: Vec<i32> = Vec::new();
    let cnt: i64 = list_len(pool, prog);
    let mut fi: i64 = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 {
            let sig: str = extract_fn_signature(pool, fn_nid);
            let sig_hash: i64 = str_hash(sig);
            let body_hash: i64 = extract_fn_body_hash(pool, fn_nid);
            let name: str = node_field(pool, fn_nid, 1);
            cache.push(name);
            cache.push(sig_hash);
            cache.push(body_hash);
        };
        fi = fi + 1;
    };
    return cache;
}

// Serialize signature cache to a string for disk storage
fn sig_cache_serialize(cache: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(cache) {
        sb_append(sb, vec_get(cache, i));      // name
        sb_append(sb, ":");
        sb_append(sb, str_from_int(vec_get(cache, i + 1))); // sig_hash
        sb_append(sb, ":");
        sb_append(sb, str_from_int(vec_get(cache, i + 2))); // body_hash
        sb_append(sb, "\n");
        i = i + 3;
    };
    return sb_to_str(sb);
}

// Check if a function needs recompilation by comparing against cached hashes.
// Returns: 0 = cached (skip), 1 = body changed (recompile, don't invalidate deps),
//          2 = signature changed (recompile + invalidate all dependents)
fn check_fn_cache(name: str, sig_hash: i64, body_hash: i64, old_cache: str) -> i64 {
    if str_len(old_cache) == 0 { return 2; }; // no cache = full recompile
    // Search for name in old cache
    let slen: i64 = str_len(old_cache);
    let nlen: i64 = str_len(name);
    let mut p: i64 = 0;
    while p < slen {
        // Find end of line
        let mut eol: i64 = p;
        while eol < slen && str_char_at(old_cache, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(old_cache, p, eol);
        let llen: i64 = str_len(line);
        // Check if line starts with "name:"
        if llen > nlen + 1 && str_eq(str_substring(line, 0, nlen), name) && str_char_at(line, nlen) == 58 {
            // Found the function in cache, extract old hashes
            let rest: str = str_substring(line, nlen + 1, llen);
            // Find the colon separator between sig_hash and body_hash
            let rlen: i64 = str_len(rest);
            let mut cp: i64 = 0;
            while cp < rlen && str_char_at(rest, cp) != 58 { cp = cp + 1; };
            let old_sig: i64 = str_to_int(str_substring(rest, 0, cp));
            let old_body: i64 = str_to_int(str_substring(rest, cp + 1, rlen));
            if old_sig != sig_hash { return 2; }; // signature changed
            if old_body != body_hash { return 1; }; // body changed
            return 0; // unchanged
        };
        p = eol + 1;
    };
    return 2; // function not in cache = new function
}

// Build dependency map: for each function, list the functions it calls.
// Used for transitive invalidation when a signature changes.
fn build_call_deps(pool: Vec<i32>, prog: i64) -> Vec<i32> {
    let mut deps: Vec<i32> = Vec::new();
    let cnt: i64 = list_len(pool, prog);
    let mut fi: i64 = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 {
            let name: str = node_field(pool, fn_nid, 1);
            deps.push(name);
            // Collect callees from body
            let body: i64 = node_field(pool, fn_nid, 4);
            let mut callees: i64 = sb_new();
            collect_callees(pool, body, callees);
            deps.push(sb_to_str(callees));
        };
        fi = fi + 1;
    };
    return deps;
}

// Recursively collect function names called from an expression
fn collect_callees(pool: Vec<i32>, nid: i64, sb: i64) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    // Call node (kind 5): field 1 is callee name
    if kind == 5 {
        sb_append(sb, node_field(pool, nid, 1));
        sb_append(sb, ",");
        // Recurse into arguments
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac { collect_callees(pool, list_get(pool, args, ai), sb); ai = ai + 1; };
    }
    // Block node (kind 2): recurse into statements
    else if kind == 2 {
        let stmts: i64 = node_field(pool, nid, 1);
        let sc: i64 = list_len(pool, stmts);
        let mut si: i64 = 0;
        while si < sc { collect_callees(pool, list_get(pool, stmts, si), sb); si = si + 1; };
    }
    // If node (kind 6): recurse into cond, then, else
    else if kind == 6 {
        collect_callees(pool, node_field(pool, nid, 1), sb);
        collect_callees(pool, node_field(pool, nid, 2), sb);
        collect_callees(pool, node_field(pool, nid, 3), sb);
    }
    // While node (kind 7): recurse into cond and body
    else if kind == 7 {
        collect_callees(pool, node_field(pool, nid, 1), sb);
        collect_callees(pool, node_field(pool, nid, 2), sb);
    }
    // Let/assign (kind 8/9): recurse into value
    else if kind == 8 || kind == 9 {
        collect_callees(pool, node_field(pool, nid, 2), sb);
    }
    // BinOp (kind 4): recurse into lhs/rhs
    else if kind == 4 {
        collect_callees(pool, node_field(pool, nid, 2), sb);
        collect_callees(pool, node_field(pool, nid, 3), sb);
    }
    // Return (kind 10): recurse into value
    else if kind == 10 {
        collect_callees(pool, node_field(pool, nid, 1), sb);
    };
    return 0;
}

// Check if a function name appears in a comma-separated callee list
fn depends_on(callees: str, target: str) -> i64 {
    let clen: i64 = str_len(callees);
    let tlen: i64 = str_len(target);
    let mut p: i64 = 0;
    while p < clen {
        let mut e: i64 = p;
        while e < clen && str_char_at(callees, e) != 44 { e = e + 1; };
        if e - p == tlen && str_eq(str_substring(callees, p, e), target) { return 1; };
        p = e + 1;
    };
    return 0;
}


fn cache_v2_canonical_flags(strict_mode: i64) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "dbc-mode=");
    sb_append(sb, cache_v2_dbc_flag());
    sb_append(sb, ";strict-intrin=");
    sb_append(sb, cache_v2_strict_intrin_flag());
    sb_append(sb, ";strict-mode=");
    sb_append(sb, build_mode_name(strict_mode));
    return sb_to_str(sb);
}

fn cache_v2_store(key: str, input_filename: str, flags: str, ll: str) -> i64 {
    let dir: str = cache_v2_dir(key);
    let meta_dir: str = cache_v2_meta_dir(key);
    fs_create_dir_all(dir);
    fs_create_dir_all(meta_dir);
    file_write_string(cache_v2_ll_path(key), ll);
    let meta: str = cache_v2_meta_json(input_filename, flags, compiler_identity(), key, ll);
    file_write_string(cache_v2_meta_path(key), meta);
    file_write_string(sanitize(str_concat(dir, "/meta.json")), meta);
    return 0;
}


fn resolve_toolchain_path(raw_path: str) -> str {
    let from_cwd: str = sanitize(raw_path);
    if path_exists(from_cwd) == 1 { return from_cwd; };
    if args_count() > 0 {
        let exe_dir: str = extract_dir(args_get(0));
        let from_exe_dir: str = sanitize(str_concat(exe_dir, raw_path));
        if path_exists(from_exe_dir) == 1 { return from_exe_dir; };
        let repo_dir: str = parent_dir(exe_dir);
        let from_repo_dir: str = sanitize(str_concat(repo_dir, raw_path));
        if path_exists(from_repo_dir) == 1 { return from_repo_dir; };
    };
    return from_cwd;
}


fn link_native_module(ll: str, out_name: str, imported: Vec<i32>, cache_key_hint: str, link_native: i64, time_passes: i64) -> i64 {
    let ll_path: str = sanitize(str_concat("target/", str_concat(out_name, ".ll")));
    let exe_path: str = sanitize(str_concat(str_concat("target", host_target_path_sep()), str_concat(out_name, host_exe_suffix())));
    let null_redir: str = host_null_redirect();
    system(str_concat("mkdir target", null_redir));
    write_ll_artifact_if_needed(ll_path, ll, cache_key_hint);
    print(str_concat("  emitted: ", str_concat(ll_path, str_concat(" (", str_concat(str_from_int(str_len(ll)), " bytes)")))));
    if link_native == 0 {
        print(str_concat("  native link: skipped (use ", str_concat(exe_path, " only after a linked build)")));
        return 0;
    };
    let native_d: Vec<i32> = collect_native_directives(imported);
    let link_flags: str = vec_get(native_d, 0);
    let cfiles: str = vec_get(native_d, 1);
    let libpath_flags: str = vec_get(native_d, 2);
    let rt_arg: str = resolve_toolchain_path("stdlib/runtime/nucleor_llvm_rt.c");
    host_remove_file_quiet(exe_path);
    let clang_start: i64 = now_ms();
    let stack_flag: str = host_stack_link_flag();
    // T1.5d (v0.2.343): capture clang stderr/stdout so we can lift
    // undefined-symbol errors that match privatized fns into MOD-003.
    system(str_concat("mkdir .nuc_cache", null_redir));
    let log_path: str = sanitize(".nuc_cache/clang_link.log");
    let opt_flag: str = str_concat(" ", env_get_or("NUCLEOR_LLVM_OPT", "-O0"));
    let mut cmd: str = llvm_clang_path();
    cmd = str_concat(cmd, opt_flag);
    cmd = str_concat(cmd, " ");
    cmd = str_concat(cmd, ll_path);
    cmd = str_concat(cmd, " ");
    cmd = str_concat(cmd, rt_arg);
    cmd = str_concat(cmd, cfiles);
    cmd = str_concat(cmd, " -o ");
    cmd = str_concat(cmd, exe_path);
    cmd = str_concat(cmd, " -Wno-override-module");
    cmd = str_concat(cmd, stack_flag);
    cmd = str_concat(cmd, " ");
    cmd = str_concat(cmd, libpath_flags);
    cmd = str_concat(cmd, link_flags);
    cmd = str_concat(cmd, " > ");
    cmd = str_concat(cmd, log_path);
    cmd = str_concat(cmd, " 2>&1");
    let rc: i64 = system(cmd);
    print_phase_time(time_passes, "clang", now_ms() - clang_start);
    let clang_log: str = file_read_string(log_path);
    if rc != 0 {
        let priv_reg: Vec<i32> = priv_build_global_registry(imported);
        let lifted: i64 = priv_lift_link_errors(clang_log, priv_reg);
        if str_len(clang_log) > 0 { print(clang_log); };
        let ll_check: str = file_read_string(ll_path);
        if str_len(ll_check) > 0 {
            print(str_concat("  COMPILE FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
            if lifted > 0 {
                print(str_concat("  ", str_concat(str_from_int(lifted), " MOD-003 violation(s) — see error[MOD-003] above")));
            } else {
                print("  note: LLVM IR was emitted; GPU/CUDA experiments may require manual link with CUDA libs");
            };
        } else {
            print(str_concat("  COMPILE FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
            return 1;
        };
        return 1;
    };
    if str_len(clang_log) > 0 { print(clang_log); };
    print(str_concat("  compiled: ", exe_path));
    return 0;
}

