// =====================================================
// PIPELINE
// =====================================================

fn compile_and_run(ll: str, name: str) -> i64 {
    let safe_name: str = normalize_output_name(name);
    if str_len(safe_name) == 0 {
        print(str_concat("ERROR: invalid output name: ", name));
        return 1;
    };
    let lp: str = sanitize(str_concat("target/", str_concat(safe_name, ".ll")));
    let ep: str = sanitize(str_concat(str_concat("target", host_target_path_sep()), str_concat(safe_name, host_exe_suffix())));
    system(str_concat("mkdir target", host_null_redirect()));
    file_write_string(lp, ll);
    let rt_arg2: str = resolve_toolchain_path("stdlib/runtime/nucleor_llvm_rt.c");
    let mut cmd: str = llvm_clang_path();
    cmd = str_concat(cmd, " ");
    cmd = str_concat(cmd, lp);
    cmd = str_concat(cmd, " ");
    cmd = str_concat(cmd, rt_arg2);
    cmd = str_concat(cmd, " -o ");
    cmd = str_concat(cmd, ep);
    cmd = str_concat(cmd, " -Wno-override-module");
    cmd = str_concat(cmd, host_stack_link_flag());
    cmd = str_concat(cmd, " 2>&1");
    let rc: i64 = system(cmd);
    if rc != 0 { print(str_concat("  COMPILE FAIL: ", safe_name)); return 0 - 1; };
    return system(ep);
}

fn pipeline(source: str, name: str) -> i64 {
    if preflight_source_check(source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let mut r: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(r);
    let cnt: i64 = list_len(pool, prog);
    let mut strtab: Vec<i32> = Vec::new();
    let mut fns: Vec<i32> = Vec::new();
    let mut externs: Vec<i32> = Vec::new();
    let mut structs: Vec<i32> = Vec::new();
    let mut enums: Vec<i32> = Vec::new();
    let mut globals: Vec<i32> = Vec::new();
    // Pass 1: collect structs, enums, and externs
    let mut fi: i64 = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 32 { externs.push(fn_nid); }
        else if node_kind(pool, fn_nid) == 33 { structs.push(fn_nid); }
        else if node_kind(pool, fn_nid) == 36 { enums.push(fn_nid); };
        if node_kind(pool, fn_nid) == 50 { globals.push(fn_nid); };
        fi = fi + 1;
    };
    // Pass 1.5: collect trait impls and generate mangled functions
    let mut trait_impls: Vec<i32> = Vec::new();
    let mut impl_fns: Vec<i32> = Vec::new();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 45 {
            let type_name: str = node_field(pool, fn_nid, 2);
            let methods: i64 = node_field(pool, fn_nid, 3);
            let mc: i64 = list_len(pool, methods);
            let mut mi: i64 = 0;
            while mi < mc {
                let method_nid: i64 = list_get(pool, methods, mi);
                let orig_name: str = node_field(pool, method_nid, 1);
                let mangled: str = str_concat(type_name, str_concat("__", orig_name));
                let new_fn: i64 = mk6(pool, 30, mangled, node_field(pool, method_nid, 2), node_field(pool, method_nid, 3), node_field(pool, method_nid, 4), node_field(pool, method_nid, 5));
                impl_fns.push(new_fn);
                trait_impl_register(trait_impls, type_name, orig_name, mangled);
                mi = mi + 1;
            };
        };
        fi = fi + 1;
    };
    // Diagnostic accumulator
    let mut diags: Vec<i32> = diag_new();
    let review_path: str = "";
    let review_filter: str = "";
    if review_active(review_path) == 1 {
        review_emit(review_path, str_concat("{\"schema_version\":\"1.0\",\"event\":\"compile_start\",\"file\":\"", str_concat(name, "\"}")));
    }
    // Pass 1.7: ownership checking
    let mut ow_warns: i64 = 0;
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { ow_warns = ow_warns + check_fn(pool, fn_nid, structs, enums, diags, source); };
        fi = fi + 1;
    };
    let mut oi: i64 = 0;
    while oi < vec_len(impl_fns) { ow_warns = ow_warns + check_fn(pool, vec_get(impl_fns, oi), structs, enums, diags, source); oi = oi + 1; };
    let mut ty_warns: i64 = type_check_program(pool, prog, structs, diags, source, tprof_new(0));
    let mut raw_warns: i64 = source_rule_check(source, diags);
    // Pass 1.8: effect checking (pure fn)
    let mut pure_fns: Vec<i32> = Vec::new();
    let mut ef_warns: i64 = 0;
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 46 { pure_fns.push(node_field(pool, fn_nid, 1)); };
        fi = fi + 1;
    };
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 {
            let fname: str = node_field(pool, fn_nid, 1);
            let mut is_pure: i64 = 0;
            let mut pi: i64 = 0;
            while pi < vec_len(pure_fns) { if str_eq(vec_get(pure_fns, pi), fname) { is_pure = 1; pi = vec_len(pure_fns); }; pi = pi + 1; };
            if is_pure == 1 { ef_warns = ef_warns + effect_check_fn(pool, fn_nid, pure_fns, diags, source, review_path, review_filter); };
        };
        fi = fi + 1;
    };
    // Pass 1.9: taint checking (two-pass: intra-function then inter-procedural)
    let mut taint_warns: i64 = 0;
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { taint_warns = taint_warns + taint_check_fn(pool, fn_nid, diags, source, review_path, review_filter); };
        fi = fi + 1;
    };
    // Inter-procedural pass: re-check all non-main functions assuming all params tainted
    // This catches taint flows across function boundaries (e.g., user input → struct field → callee → system)
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 {
            let fname: str = node_field(pool, fn_nid, 1);
            if str_eq(fname, "main") == 0 {
                taint_warns = taint_warns + taint_check_fn_ex(pool, fn_nid, diags, source, review_path, review_filter, 1);
            };
        };
        fi = fi + 1;
    };
    // Emit diagnostics (text mode for pipeline)
    if diag_count(diags) > 0 { diag_emit_text(diags); return 1; };
    // Pass 2: lower functions
    let mut closures: Vec<i32> = Vec::new();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { fns.push(lower_fn(pool, fn_nid, strtab, structs, enums, globals, closures, trait_impls)); };
        fi = fi + 1;
    };
    // Lower impl-generated functions
    let mut ii: i64 = 0;
    while ii < vec_len(impl_fns) {
        fns.push(lower_fn(pool, vec_get(impl_fns, ii), strtab, structs, enums, globals, closures, trait_impls));
        ii = ii + 1;
    };
    // Add generated closure functions
    let mut ci: i64 = 0;
    while ci < vec_len(closures) { fns.push(vec_get(closures, ci)); ci = ci + 1; };
    let ll: str = emit_module_ext(fns, strtab, pool, externs, source);
    return compile_and_run(ll, name);
}

