// =====================================================
// COMPILER DRIVER
// =====================================================
#[manual_drop]
fn compile_file_mode(src_path: str, out_name: str, strict_mode: i64, use_cache: i64, time_passes: i64, link_native: i64) -> i64 {
    let safe_out_name: str = normalize_output_name(out_name);
    if str_len(safe_out_name) == 0 {
        print(str_concat("ERROR: invalid output name: ", out_name));
        return 1;
    };
    let total_start: i64 = now_ms();
    // early raw-source cache hit.
    // Pre-fix the resolve+macro-expand pass ran on every build at ~15 s on
    // the 2.4 MB compiler source (41x regression on hot path vs v1.0
    // baseline 0.47 s). The macro/actor/async-strip transforms are pure,
    // deterministic functions of the raw source bytes (per-source — sources
    // with `import "..."` directives also depend on imported bodies, so we
    // gate the fast path on import-free sources only). Hashing the raw
    // source via the same `build_cache_key` flow gives a cache key that
    // exactly maps to the .ll cache entry produced by the slow path on
    // cache miss; cache writes always store under the raw-source key.
    let mut early_cache_key: str = "";
    let mut early_cache_ll_path: str = "";
    let mut early_imported: Vec<i32> = Vec::new();
    if use_cache == 1 {
        let raw_probe: str = file_read_string(src_path);
        source_reject_nul_truncation(src_path, raw_probe);
        // Only take fast path when source starts at column 0 with a
        // sentinel that says "no imports" — practically: scan for a
        // line-start `import "` directive. The compiler source itself
        // contains the literal "import \"" inside string literals (error
        // messages); a substring check would false-positive. We approximate
        // a line-start check by looking for a leading newline + the
        // directive. Sources legitimately starting with import on line 1
        // are caught by the missing-leading-newline branch below.
        let has_import: i64 = if str_len(raw_probe) >= 8
            && str_starts_with(raw_probe, "import \"") == 1 { 1 }
            else if str_contains(raw_probe, "\nimport \"") == 1 { 1 }
            else { 0 };
        if str_len(raw_probe) > 0 && has_import == 0 {
            early_cache_key = build_cache_key(raw_probe, strict_mode);
            early_cache_ll_path = cache_v2_ll_path(early_cache_key);
            if fs_exists(early_cache_ll_path) == 1 {
                print(str_concat("  source: ", str_concat(src_path, str_concat(" (", str_concat(str_from_int(str_len(raw_probe)), " bytes)")))));
                if strict_mode == 0 { print("  mode: fast (ownership + type)"); };
                if link_native == 0 { print("  mode: llvm-only (--no-link)"); };
                print(str_concat("cache: hit (sha=", str_concat(cache_v2_prefix(early_cache_key), str_concat(", size ", str_concat(str_from_int(cache_v2_file_size_mb(early_cache_ll_path)), " MB)")))));
                let cached_out_ll: str = sanitize(str_concat("target/", str_concat(safe_out_name, ".ll")));
                copy_ll_artifact_if_needed(early_cache_ll_path, cached_out_ll, early_cache_key);
                print(str_concat("  emitted: ", str_concat(cached_out_ll, str_concat(" (", str_concat(str_from_int(fs_size(cached_out_ll)), " bytes)")))));
                let mut rc_early: i64 = 0;
                if link_native == 0 {
                    let cached_exe_path: str = sanitize(str_concat(str_concat("target", host_target_path_sep()), str_concat(safe_out_name, host_exe_suffix())));
                    print(str_concat("  native link: skipped (use ", str_concat(cached_exe_path, " only after a linked build)")));
                } else {
                    early_imported.push(src_path);
                    rc_early = link_existing_native_module(cached_out_ll, safe_out_name, early_imported, early_cache_key, time_passes);
                };
                cache_v2_print_stats(1, 0);
                print_phase_time(time_passes, "total", now_ms() - total_start);
                return rc_early;
            };
        };
    };
    let resolve_start: i64 = now_ms();
    let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
    let source: str = vec_get(bundle, 0);
    let imported: Vec<i32> = vec_get(bundle, 1);
    let mut max_depth_source: str = source;
    if vec_len(bundle) > 3 { max_depth_source = vec_get(bundle, 3); };
    if str_len(source) == 0 {
        if fs_exists(src_path) == 1 && fs_size(src_path) == 0 {
            print(str_concat("error[NR022]: source file is empty: ", src_path));
            print("  Nucleor expects every binary build to have a `fn main() -> i32` entry point. Add a main function, or compile this file only as part of a larger imported program.");
            return 1;
        };
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    print(str_concat("  source: ", str_concat(src_path, str_concat(" (", str_concat(str_from_int(str_len(source)), " bytes)")))));
    if strict_mode == 0 { print("  mode: fast (ownership + type)"); };
    if link_native == 0 { print("  mode: llvm-only (--no-link)"); };
    if vec_get(bundle, 2) == 1 { print("  incremental: module graph cache hit"); };
    // stash the resolved source in the compile-src
    // side table so deep lowering helpers (match_bind_payloads_per_idx)
    // can do scrutinee-type inference for Option<T> / Result<T,E>
    // without threading `src` through 30+ call sites.
    __nucleor_compile_src_set(source);
    // Lane 4 / F-002: reset parse-depth counter at compile entry so
    // re-runs in the same process / repeated builds don't drift.
    __nucleor_parse_depth_reset();
    print_phase_time(time_passes, "resolve_source", now_ms() - resolve_start);
    // cache check moved AHEAD
    // of preflight_source_check. Pre-fix preflight ran a per-byte loop
    // over the entire source (12 MB s1 compiler = 12 M str_char_at calls)
    // BEFORE checking the .ll cache, costing ~20 s on every hot rebuild
    // (41x regression vs v1.0 baseline 0.47 s). The cache key is derived
    // from the source content, so a cache hit means an identical source
    // body was preflight-validated already at the time of the cache miss
    // that produced the entry; re-running preflight is redundant.
    // For sources that took the import-bearing slow path through resolve,
    // the cache key is the post-transform hash of the resolved+expanded
    // source so it correctly invalidates when an imported file changes.
    // The early raw-source fast path above is gated on import-free files
    // only.
    let mut cache_key: str = "";
    let mut cache_flags: str = "";
    let mut cache_ll_path: str = "";
    if use_cache == 1 {
        cache_flags = cache_v2_canonical_flags(strict_mode);
        cache_key = build_cache_key(source, strict_mode);
        cache_ll_path = cache_v2_ll_path(cache_key);
        if fs_exists(cache_ll_path) == 1 {
            print(str_concat("cache: hit (sha=", str_concat(cache_v2_prefix(cache_key), str_concat(", size ", str_concat(str_from_int(cache_v2_file_size_mb(cache_ll_path)), " MB)")))));
            let cached_out_ll: str = sanitize(str_concat("target/", str_concat(safe_out_name, ".ll")));
            copy_ll_artifact_if_needed(cache_ll_path, cached_out_ll, cache_key);
            print(str_concat("  emitted: ", str_concat(cached_out_ll, str_concat(" (", str_concat(str_from_int(fs_size(cached_out_ll)), " bytes)")))));
            let mut rc_cached: i64 = 0;
            if link_native == 0 {
                let cached_exe_path: str = sanitize(str_concat(str_concat("target", host_target_path_sep()), str_concat(safe_out_name, host_exe_suffix())));
                print(str_concat("  native link: skipped (use ", str_concat(cached_exe_path, " only after a linked build)")));
            } else {
                rc_cached = link_existing_native_module(cached_out_ll, safe_out_name, imported, cache_key, time_passes);
            };
            cache_v2_print_stats(1, 0);
            print_phase_time(time_passes, "total", now_ms() - total_start);
            return rc_cached;
        };
    } else {
        print("cache: disabled (sha=none, size 0 MB)");
    };
    let preflight_start: i64 = now_ms();
    if preflight_source_check(source) != 0 { return 1; };
    print_phase_time(time_passes, "preflight", now_ms() - preflight_start);
    // also write the raw-source-
    // key form of the cache entry so the early fast path will hit on
    // subsequent builds. The slow path's transform-derived `cache_key`
    // remains the primary key so import-bearing sources stay correctly
    // invalidated; the early-key alias is created opportunistically for
    // import-free sources only.
    if use_cache == 1 && str_len(early_cache_key) > 0 && str_eq(early_cache_key, cache_key) == 0 {
        cache_key = early_cache_key;
        cache_ll_path = early_cache_ll_path;
    };
    nuc_diag_set_source(source);
    let lex_start: i64 = now_ms();
    let mut tokens: Vec<i32> = lex(source);
    print_phase_time(time_passes, "lex", now_ms() - lex_start);
    let mut pool: Vec<i32> = Vec::new();
    let parse_start: i64 = now_ms();
    let mut r: Vec<i32> = parse_program(tokens, pool);
    print_phase_time(time_passes, "parse", now_ms() - parse_start);
    let prog: i64 = pr_val(r);
    let cnt: i64 = list_len(pool, prog);
    free_token_vec(tokens);
    vec_free(r);

    let mut strtab: Vec<i32> = Vec::new();
    let mut strtab_aux: Vec<i32> = Vec::new();
    strtab_aux.push(0);
    strtab_aux.push(0);
    let mut fns: Vec<i32> = Vec::new();
    let mut externs: Vec<i32> = Vec::new();
    let mut structs: Vec<i32> = Vec::new();
    let mut enums: Vec<i32> = Vec::new();
    let mut globals: Vec<i32> = Vec::new();
    // collect fn return-type lookup table for binop_float_type's
    // kind==7 (call) branch. Mirrors the existing structs/enums vecs.
    // Holds both regular fns (kind 30) and extern fns (kind 32) — both
    // can return f32/f64 and call sites need correct binop dispatch.
    let mut fn_decls: Vec<i32> = Vec::new();
    // Pass 1: collect structs, enums, and externs
    let collect_start: i64 = now_ms();
    let mut fi: i64 = 0;
    //  `struct W { … } struct W { … }` (same or
    // different fields) was silently accepted; first decl won for `W { … }`
    // initialization with the second decl's fields unreachable. Sister
    // case to enum-duplicate-variant + duplicate-pub-fn (existing).
    // Mirror Rust E0428 ("the name `W` is defined multiple times") at
    // collection time.
    let mut seen_struct_names: Vec<str> = Vec::new();
    let mut seen_enum_names: Vec<str> = Vec::new();
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 32 { externs.push(fn_nid); fn_decls.push(fn_nid); }
        else if node_kind(pool, fn_nid) == 33 {
            let sname_v062: str = node_field(pool, fn_nid, 1);
            let mut dsi: i64 = 0;
            let mut dup_hit: i64 = 0;
            while dsi < vec_len(seen_struct_names) {
                if str_eq(vec_get(seen_struct_names, dsi), sname_v062) == 1 {
                    dup_hit = 1;
                    dsi = vec_len(seen_struct_names);
                } else {
                    dsi = dsi + 1;
                };
            };
            if dup_hit == 1 {
                print(str_concat("error[TYP-041]: duplicate struct decl `", str_concat(sname_v062, "` (Rust E0428).")));
                print(str_concat("  Two `struct ", str_concat(sname_v062, "` decls in this compile unit. Nucleor's collection pass keeps both, but only the FIRST one wins for field-offset / construction; the second's fields are unreachable. Adopters refactoring across files (rename `Foo` to `Bar`, miss one) or running translators that emit duplicate decls hit silent miscompiles.")));
                print(str_concat("  Workaround: rename or remove the duplicate `struct ", str_concat(sname_v062, "`. If both shapes are needed (e.g. version-skew between modules), give them distinct names.")));
                panic(str_concat("duplicate struct decl: ", sname_v062));
            };
            seen_struct_names.push(sname_v062);
            structs.push(fn_nid);
        }
        else if node_kind(pool, fn_nid) == 36 {
            let ename_v062: str = node_field(pool, fn_nid, 1);
            let mut dei: i64 = 0;
            let mut edup_hit: i64 = 0;
            while dei < vec_len(seen_enum_names) {
                if str_eq(vec_get(seen_enum_names, dei), ename_v062) == 1 {
                    edup_hit = 1;
                    dei = vec_len(seen_enum_names);
                } else {
                    dei = dei + 1;
                };
            };
            if edup_hit == 1 {
                print(str_concat("error[TYP-041]: duplicate enum decl `", str_concat(ename_v062, "` (Rust E0428).")));
                print(str_concat("  Two `enum ", str_concat(ename_v062, "` decls in this compile unit. Same hazard as duplicate-struct: only the FIRST wins for variant resolution; the second's variants are unreachable. Sister to v0.6.27 dup-variant-within-enum check.")));
                print(str_concat("  Workaround: rename or remove the duplicate `enum ", str_concat(ename_v062, "`.")));
                panic(str_concat("duplicate enum decl: ", ename_v062));
            };
            seen_enum_names.push(ename_v062);
            enums.push(fn_nid);
        };
        if node_kind(pool, fn_nid) == 30 { fn_decls.push(fn_nid); };
        if node_kind(pool, fn_nid) == 50 { globals.push(fn_nid); };
        fi = fi + 1;
    };
    print_phase_time(time_passes, "collect_decls", now_ms() - collect_start);
    // Pass 1.5: collect trait impls and generate mangled functions
    let mut trait_impls: Vec<i32> = Vec::new();
    let mut impl_fns: Vec<i32> = Vec::new();
    let impl_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 45 {
            let trait_name: str = node_field(pool, fn_nid, 1);
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
                // also append to fn_decls so the mangled
                // trait method has an `__fnret_<MANGLED>` sym entry
                // populated by populate_fn_returns_in_sym at lower_fn
                // entry. binop_float_type's kind==8 (method call)
                // branch reads that entry to dispatch f64 ops on
                // trait-method results.
                fn_decls.push(new_fn);
                trait_impl_register(trait_impls, type_name, orig_name, mangled);
                if str_len(trait_name) > 0 {
                    trait_impl_register(trait_impls, trait_bound_impl_key(trait_name, type_name), orig_name, mangled);
                };
                if str_eq(type_base_name(trait_name), "From") == 1 && str_eq(orig_name, "from") == 1 {
                    let mut src_err: str = type_first_arg(trait_name);
                    if str_len(src_err) == 0 {
                        let params_list: i64 = node_field(pool, method_nid, 2);
                        if list_len(pool, params_list) > 0 {
                            src_err = node_field(pool, list_get(pool, params_list, 0), 2);
                        };
                    };
                    if str_len(src_err) > 0 {
                        trait_impl_register(trait_impls, type_name, from_method_key(src_err), mangled);
                    };
                };
                mi = mi + 1;
            };
        };
        fi = fi + 1;
    };
    // trait default method support. After collect_impls
    // registers explicit impl methods, walk every kind-45 (impl block)
    // with a non-empty trait_name and look for default methods (body
    // != -1) declared in the corresponding kind-43 trait_decl that
    // the impl did NOT override. For each such default method,
    // synthesize a mangled fn `<TypeName>__<method>` using the
    // trait's body and register it in trait_impls + fn_decls. This
    // enables the canonical Rust pattern of trait defaults that impls
    // can selectively override. Pre-v0.3.82, calling a trait method
    // not present in the impl's explicit body fell through to the
    // `vec_<mname>` fallback which failed at clang link with
    // "use of undefined value".
    fi = 0;
    while fi < cnt {
        let impl_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, impl_nid) == 45 {
            let trait_name: str = node_field(pool, impl_nid, 1);
            let type_name2: str = node_field(pool, impl_nid, 2);
            let impl_methods: i64 = node_field(pool, impl_nid, 3);
            if str_len(trait_name) > 0 {
                let mut fj: i64 = 0;
                while fj < cnt {
                    let td_nid: i64 = list_get(pool, prog, fj);
                    if node_kind(pool, td_nid) == 43 && str_eq(node_field(pool, td_nid, 1), trait_name) == 1 {
                        let trait_methods: i64 = node_field(pool, td_nid, 2);
                        let tmc: i64 = list_len(pool, trait_methods);
                        let mut tmi: i64 = 0;
                        while tmi < tmc {
                            let trait_method_nid: i64 = list_get(pool, trait_methods, tmi);
                            let tmname: str = node_field(pool, trait_method_nid, 1);
                            let tbody: i64 = node_field(pool, trait_method_nid, 4);
                            if tbody >= 0 {
                                // Trait has a default body. Check if impl overrides.
                                let imc: i64 = list_len(pool, impl_methods);
                                let mut overridden: i64 = 0;
                                let mut imi: i64 = 0;
                                while imi < imc {
                                    let im_nid: i64 = list_get(pool, impl_methods, imi);
                                    if str_eq(node_field(pool, im_nid, 1), tmname) == 1 {
                                        overridden = 1;
                                    };
                                    imi = imi + 1;
                                };
                                if overridden == 0 {
                                    // build new params with "Self"
                                    // substituted for the impl's actual
                                    // type_name. Without this, the default
                                    // body's `self` has type="Self" which
                                    // doesn't resolve to a known struct in
                                    // expr_struct_type, breaking dispatch
                                    // for any nested `self.<method>()` call.
                                    let trait_params: i64 = node_field(pool, trait_method_nid, 2);
                                    let pcount: i64 = list_len(pool, trait_params);
                                    let mut new_params: Vec<i32> = Vec::new();
                                    let mut pi: i64 = 0;
                                    while pi < pcount {
                                        let pnode: i64 = list_get(pool, trait_params, pi);
                                        let pname: str = node_field(pool, pnode, 1);
                                        let ptype: str = node_field(pool, pnode, 2);
                                        let mut new_ptype: str = ptype;
                                        if str_eq(ptype, "Self") == 1 { new_ptype = type_name2; };
                                        if str_eq(ptype, "&Self") == 1 { new_ptype = str_concat("&", type_name2); };
                                        if str_eq(ptype, "&mut Self") == 1 { new_ptype = str_concat("&mut ", type_name2); };
                                        new_params.push(mk3(pool, 41, pname, new_ptype));
                                        pi = pi + 1;
                                    };
                                    // Synthesize fn using trait's default body, mangled with the impl's type name.
                                    let dm_mangled: str = str_concat(type_name2, str_concat("__", tmname));
                                    let dm_fn: i64 = mk6(pool, 30, dm_mangled, mk_list(pool, new_params), node_field(pool, trait_method_nid, 3), tbody, 0);
                                    impl_fns.push(dm_fn);
                                    fn_decls.push(dm_fn);
                                    trait_impl_register(trait_impls, type_name2, tmname, dm_mangled);
                                    trait_impl_register(trait_impls, trait_bound_impl_key(trait_name, type_name2), tmname, dm_mangled);
                                };
                            };
                            tmi = tmi + 1;
                        };
                    };
                    fj = fj + 1;
                };
            };
        };
        fi = fi + 1;
    };
    print_phase_time(time_passes, "collect_impls", now_ms() - impl_start);
    // Diagnostic accumulator
    let mut diags: Vec<i32> = diag_new();
    // Pass 1.7: ownership checking
    let own_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { check_fn(pool, fn_nid, structs, enums, diags, source); };
        fi = fi + 1;
    };
    let mut oi: i64 = 0;
    while oi < vec_len(impl_fns) {
        check_fn(pool, vec_get(impl_fns, oi), structs, enums, diags, source);
        oi = oi + 1;
    };
    print_phase_time(time_passes, "ownership", now_ms() - own_start);
    let type_start: i64 = now_ms();
    let type_prof: Vec<i32> = tprof_new(time_passes);
    type_check_program(pool, prog, structs, diags, source, type_prof);
    print_phase_time(time_passes, "type", now_ms() - type_start);
    tprof_dump(type_prof);
    vec_free(type_prof);
    // v0.4.257 RFC-0006 Liskov compile-time check.
    // For each `impl Trait for Type { fn METHOD ... }` method,
    // compare its #[require] / #[ensure] count against the trait
    // declaration's count for the same method name. Liskov:
    // - impl precondition COUNT must NOT exceed trait's
    //   (CONTRACT-004 — strengthened pre).
    // - impl postcondition COUNT must NOT be below trait's
    //   (CONTRACT-005 — weakened post).
    // Count-based comparison is conservative — if the predicates
    // are textually different but semantically equivalent, this
    // check still passes. Strict semantic equality would require
    // a separate analysis pass (deferred). Accuracy: catches the
    // canonical violation classes (impl adds a require, impl
    // drops an ensure) without expensive AST equality.
    let liskov_trait_attrs: Vec<i32> = collect_trait_method_attrs(source);
    let liskov_impl_attrs: Vec<i32> = collect_impl_trait_method_attrs(source);
    let mut li: i64 = 0;
    let li_n: i64 = vec_len(liskov_impl_attrs);
    while li + 4 < li_n {
        let l_trait: str = vec_get(liskov_impl_attrs, li);
        let l_type: str = vec_get(liskov_impl_attrs, li + 1);
        let l_method: str = vec_get(liskov_impl_attrs, li + 2);
        let l_irq: i64 = str_to_int(vec_get(liskov_impl_attrs, li + 3));
        let l_ien: i64 = str_to_int(vec_get(liskov_impl_attrs, li + 4));
        let counts: Vec<i32> = lookup_trait_method_counts(liskov_trait_attrs, l_trait, l_method);
        let trait_req: i64 = vec_get(counts, 0);
        let trait_ens: i64 = vec_get(counts, 1);
        if trait_req >= 0 {
            if l_irq > trait_req {
                let msg4: str = str_concat("impl `", str_concat(l_trait, str_concat(" for ", str_concat(l_type, str_concat("` method `", str_concat(l_method, str_concat("` has more #[require(...)] preconditions (", str_concat(str_from_int(l_irq), str_concat(") than the trait declaration (", str_concat(str_from_int(trait_req), "). Liskov: subtype must not strengthen preconditions."))))))))));
                let mut lc4: Vec<i32> = find_linecol_in_source(source, l_method, l_method);
                diag_add_ex(diags, "error", "type", "CONTRACT-004", msg4, l_method, vec_get(lc4, 0), vec_get(lc4, 1), "");
            };
            if l_ien < trait_ens {
                let msg5: str = str_concat("impl `", str_concat(l_trait, str_concat(" for ", str_concat(l_type, str_concat("` method `", str_concat(l_method, str_concat("` has fewer #[ensure(...)] postconditions (", str_concat(str_from_int(l_ien), str_concat(") than the trait declaration (", str_concat(str_from_int(trait_ens), "). Liskov: subtype must not weaken postconditions."))))))))));
                let mut lc5: Vec<i32> = find_linecol_in_source(source, l_method, l_method);
                diag_add_ex(diags, "error", "type", "CONTRACT-005", msg5, l_method, vec_get(lc5, 0), vec_get(lc5, 1), "");
            };
        };
        li = li + 5;
    };
    if strict_mode == 1 {
        print_phase_time(time_passes, "source", 0);
        print_phase_time(time_passes, "collect_pure", 0);
        print_phase_time(time_passes, "effect", 0);
        print_phase_time(time_passes, "taint", 0);
    };
    // RFC-0008 first pass: #[isr] roots must be zero-arg/void,
    // inherit no_alloc/no_panic checks, and cannot be deadline-
    // wrapped. Runs before generic RT checks so hard ISR errors
    // participate in the same suppression/deny pipeline.
    diags = enforce_isr_contracts(diags, source);
    // RFC-0035 first pass: values crossing spawn-style thread
    // boundaries must be Sendable, and field-only `actor` declarations
    // reject direct external field access.
    diags = enforce_sendable_contracts(diags, source);
    // Lane 3 F-DIAG-010: TNT-001 is a real compiler diagnostic, not
    // just an `nuc explain` / suggestion-table entry. Explicit
    // `tainted<T>` symbols must be sanitized before flowing into
    // sensitive sink functions.
    diags = enforce_tnt001_tainted_sinks(diags, source);
    // RFC-0001 phase 1 — enforce #[no_alloc] before suppression so
    // users can `#[allow(RT-001)]` if needed. enforce_no_alloc
    // appends to diags; if no #[no_alloc] attribute is present in
    // the source it's a no-op.
    diags = enforce_no_alloc(diags, source);
    // T3.2 (v0.3.1): same pattern for #[no_panic] (RT-002).
    diags = enforce_no_panic(diags, source);
    // T3.6 (v0.3.5): same pattern for #[no_dyn] (RT-003).
    diags = enforce_no_dyn(diags, source);
    // RFC-0007 Track G: #[atomic] implies no blocking / no allocation /
    // no Cell-or-RefCell interior mutability, plus compile-time checks
    // for invalid literal memory-order combinations.
    diags = enforce_atomic_contracts(diags, source);
    // closures whose body calls atomic_* helpers crash
    // the compiler with `vec_get OOB` (probe-finding 2026-05-01).
    // Catch at parse time + halt with ATOMIC-006 instead of melting.
    if enforce_no_atomic_in_closure(source) == 1 {
        print("error[ATOMIC-006]: atomic helpers (atomic_load / atomic_store / atomic_fetch_* / atomic_compare_exchange) inside closure bodies are not currently supported. The closure-lowering path does not yet inherit the parent fn's enum-variant scope, so `MemOrder::SeqCst` (and similar) dispatch fails — pre-v0.4.280 this produced a misleading `vec_get OOB` compiler PANIC. Workaround: call the atomic helper directly from a regular fn body instead of wrapping it in a closure. This is a temporary limitation; full closure+atomic support lands when the closure sym-table inheritance ship goes in.");
        return 1;
    };
    // T3.8 (v0.3.7): RT-006 — RT attribute on async fn. Reads the
    // column-0 markers expand_async_strip_keyword emits, which is
    // the only way to detect this after the async keyword itself
    // has been stripped from the resolved source.
    diags = enforce_rt006_async(diags, source);
    // ASYNC-001 warning for plain `async fn` without RT attr.
    diags = enforce_async001_warning(diags, source);
    // T3.9 (v0.3.8): RT-005 — extern fn calls from RT-marked
    // bodies break the RT contract because nothing is known about
    // the extern's allocation, panic, or timing behaviour. v1
    // warns; users suppress per-fn via #[allow(RT-005)] until the
    // #[ffi_no_*] annotation family ships in v0.4.
    diags = enforce_rt005_ffi(diags, source);
    // T3.10 (v0.3.9): RT-008 — direct self-recursion in a
    // #[deadline] fn warns. Bounded recursion opts out via
    // `#[max_depth = N]`; indirect (mutual) recursion is left
    // for the v2 AST-based check.
    diags = enforce_rt008_recursion(diags, max_depth_source);
    // RFC-0014: full max_depth static validation. Runs against the
    // pre-max-depth-rewrite source so attributes and user call names
    // are still visible even when runtime wrappers have been emitted.
    diags = enforce_max_depth_static(diags, max_depth_source);
    // T3.3 (v0.3.2): static WCET estimator for #[deadline = N] fns.
    // Emits warning[RT-004] when the v1 estimate exceeds the budget.
    diags = enforce_static_wcet(diags, max_depth_source);
    // consolidated single-walk body diagnostics covering
    // NUM-009 (R09-D4 @const_fn purity), EFF-001 (R05-D1 pure fn),
    // PERF-2 (R10-D2 @hot violation), PERF-3 (R10-D2 HeapInLoop),
    // RACE-002 (R04-D3 unawaited spawn), RACE-007 (R04-D3 deadline+
    // await). Replaces 6 prior O(F·S) per-emitter walks with a single
    // O(S + ΣB) pass — ~2.6× cold compile regression resolved.
    // Measured cost (v0.8.314 --time-passes probe): 0 ms on the
    // self-host source. Not a perf concern.
    diags = enforce_body_diagnostics_unified(diags, max_depth_source);
    // R05-D3 Phase 1: direct same-file calls to a fn declared with
    // `requires [...]` must be reflected in the caller row. This is
    // intentionally one-hop only; transitive propagation and
    // cross-module rows stay queued for Phase 2b.
    diags = enforce_requires_direct_calls(diags, max_depth_source);
    // RFC-0062 G-10 Phase 2b — `#[effect(...)]` annotations framework.
    // Three diagnostics: EFFECT-G10-UNDECLARED, EFFECT-G10-MISSING-ALLOW,
    // EFFECT-G10-WRONG-ROW. Cheap-gated on the source containing the
    // attribute syntax — no perf hit for the existing fixture corpus.
    diags = enforce_g10_effects(diags, max_depth_source);
    // R05-D4 block-form
    // `restricts [...] { ... }` real enforcement first slice. Emits
    // `error[EFF-003]` when a direct call inside the block targets a
    // builtin or a same-file user fn whose declared `requires [...]`
    // row overlaps the deny row. Replaces the prior parse-time fail-
    // closed panic at parse_primary. Whole-program inference, cross-
    // module propagation, methods/closures/higher-order effects, and
    // broader RFC-0033 subtyping stay queued for Phase 2b.
    diags = enforce_restricts_block_effects(diags, max_depth_source);
    // T3.5 (v0.3.3): RT-007 — warn when #[deadline] is paired with
    // neither #[no_alloc] nor #[no_panic]. Either guard makes the
    // deadline reachable in the first place.
    diags = enforce_deadline_safety(diags, max_depth_source);
    // T3.20 (v0.3.36): emit DIAG-001 for #[allow(_fn)] / #[deny(_fn)]
    // codes whose prefix isn't in the canonical set. Runs BEFORE the
    // suppression pass so users can `#[allow(DIAG-001)]` to silence
    // it during a noisy refactor.
    diags = emit_diag001_unknown_codes(diags, source);
    if diag_count(diags) > 0 {
        // RFC-0028 §Suppression — drop warnings the user has silenced
        // via `#[allow(CODE)]`, then promote any remaining warnings
        // whose code is named in `#[deny(CODE)]`. Errors are not
        // suppressible. Allow runs first so a deny on a previously-
        // allowed code is a no-op (the diag is gone).
        diags = filter_allow_suppressed(diags, source);
        diags = promote_denied_to_errors(diags, source);
        if diag_count(diags) > 0 {
            // Emit every (post-filter, post-promote) diagnostic, but
            // only halt the build on errors. Warnings (NUM-003 lossy
            // cast, MATCH-001/002 typecker, etc.) flow through the
            // report without blocking compilation.
            if diag_use_json() == 1 { diag_emit_json(diags); } else { diag_emit_text_with_source(diags, source); };
            if diag_count_errors(diags) > 0 { return 1; };
        };
    };
    vec_free(diags);
    let mut closures: Vec<i32> = Vec::new();
    // v0.4.245 RFC-0006 — pre-process #[require(EXPR)] attributes.
    // Source-text scanner produces (fn_name, expr_text) pairs. For
    // each, lex+parse the expression text into the existing pool;
    // store (fn_name, expr_nid) for lower_fn to look up. The lex
    // and parse_expr functions are reentrant — they take a fresh
    // token stream and return an AST nid in the supplied pool.
    // v0.4.252 RFC-0006 — build-mode strip-out via NUCLEOR_DBC_MODE.
    // Per spec section 1 — "Build modes":
    //   debug (default) | unset → all contracts active
    //   safe-release → require active; ensure / invariant elided
    //   release → all contracts elided
    //   cert → all elided (statically proven elsewhere — that
    //          analysis pass is a future ship; until then cert
    //          behaves like release for runtime emit)
    // Implementation: skip the relevant pre-pass populations.
    // Empty Vecs flow through to lower_fn; the existing walk-all
    // lookups find no matches; no contract IR emits.
    let dbc_mode: str = env_get_or("NUCLEOR_DBC_MODE", "debug");
    // validate the env value. Pre-fix, any unrecognized
    // value (e.g. `off`, `disabled`,
    // `0`, `none`) silently fell into the "neither release nor
    // cert nor debug" bucket → emit_require=1 + emit_ensure_inv=0
    // (effectively `safe-release`), with no signal to the adopter
    // who likely meant `release` or `debug` and got an inconsistent
    // partial-strip. Halt cleanly with the recognized set.
    let dbc_mode_ok: i64 = if str_len(dbc_mode) == 0 { 1 }
        else if str_eq(dbc_mode, "debug") == 1 { 1 }
        else if str_eq(dbc_mode, "safe-release") == 1 { 1 }
        else if str_eq(dbc_mode, "release") == 1 { 1 }
        else if str_eq(dbc_mode, "cert") == 1 { 1 }
        else { 0 };
    if dbc_mode_ok == 0 {
        print(str_concat("error[CONTRACT-009]: NUCLEOR_DBC_MODE=`", str_concat(dbc_mode, "` is not a recognized DbC build mode. Recognized values: `debug` (default; full runtime checks), `safe-release` (require only — input validation), `release` (no checks; max perf), `cert` (no checks; reserved for future static-proof). Unset to default to `debug`.")));
        return 1;
    };
    let dbc_emit_require: i64 = if str_eq(dbc_mode, "release") == 1 || str_eq(dbc_mode, "cert") == 1 { 0 } else { 1 };
    let dbc_emit_ensure_inv: i64 = if str_eq(dbc_mode, "debug") == 1 || str_len(dbc_mode) == 0 { 1 } else { 0 };
    // v0.4.258 RFC-0006 — `#[no_check]` per-fn opt-out. Scanner
    // populates a list of fn names whose contracts should be
    // skipped (e.g. hot-path fns). Pre-passes filter their entries
    // out of require_exprs / ensure_exprs.
    let dbc_no_check: Vec<i32> = if dbc_emit_require == 1 || dbc_emit_ensure_inv == 1 { collect_no_check_fns(source) } else { Vec::new() };
    // RFC-0042 first cut — opt-in owned-local auto-drop. Empty list
    // keeps the default path bytecode-close and avoids scanning cost
    // for sources that do not mention the marker attribute.
    let auto_drop_fns: Vec<i32> = if str_index_of(source, str_concat("#[auto_", "drop]")) >= 0 { collect_auto_drop_fns(source) } else { Vec::new() };
    let manual_drop_fns: Vec<i32> = if str_index_of(source, str_concat("#[manual_", "drop]")) >= 0 { collect_manual_drop_fns(source) } else { Vec::new() };
    let req_text_pairs: Vec<i32> = if dbc_emit_require == 1 { collect_fn_requires(source) } else { Vec::new() };
    let mut require_exprs: Vec<i32> = Vec::new();
    let mut rti: i64 = 0;
    let req_text_count: i64 = vec_len(req_text_pairs);
    while rti + 1 < req_text_count {
        let req_name: str = vec_get(req_text_pairs, rti);
        if name_in_no_check(dbc_no_check, req_name) == 1 { rti = rti + 2; continue; };
        let req_text: str = vec_get(req_text_pairs, rti + 1);
        // reject `old()` in #[require]. Pre-fix,
        // `#[require(old(x) > 0)]`
        // emitted a misleading clang-link "undefined function
        // `old()`" error. `old()` is meaningful only in #[ensure]
        // (postconditions can reference fn-entry state); #[require]
        // runs BEFORE the body so there's no prior state to
        // snapshot. Halt with CONTRACT-010 naming the semantic
        // mismatch.
        if contract_text_uses_old(req_text) == 1 {
            print(str_concat("error[CONTRACT-010]: `old(...)` is not valid in `#[require(...)]` on `fn ", str_concat(req_name, "`. Preconditions run BEFORE the function body, so there is no prior state to snapshot. `old(...)` is only meaningful in `#[ensure(...)]` (postconditions reference fn-entry state). Move the check into `#[ensure]`, or compare directly against the parameter without `old()`.")));
            print(str_concat("  --> fn ", str_concat(req_name, "@<#[require] attribute>")));
            return 1;
        };
        // undefined-ident check. Pre-fix,
        // `#[require(undefined_var > 0)]`
        // surfaced a misleading clang-link "undefined function
        // `undefined_var()`" error. CONTRACT-011 halts at compile
        // time naming the actual unbound ident.
        let req_unbound: str = find_unbound_ident_in_contract(source, req_name, req_text);
        if str_len(req_unbound) > 0 {
            print(str_concat("error[CONTRACT-011]: `#[require(...)]` on `fn ", str_concat(req_name, str_concat("` references undefined identifier `", str_concat(req_unbound, "`. Pre-conditions can only reference fn parameters, module-level constants, type or enum variant names, and the DbC keywords (`true`, `false`, `null`, `Some`, `None`, `Ok`, `Err`). Check spelling, or rewrite the predicate to compare against a fn parameter.")))));
            print(str_concat("  --> fn ", str_concat(req_name, "@<#[require] attribute>")));
            return 1;
        };
        let req_tokens: Vec<i32> = lex(req_text);
        let req_parsed: Vec<i32> = parse_expr(req_tokens, 0, pool);
        let req_expr_nid: i64 = pr_val(req_parsed);
        require_exprs.push(req_name);
        require_exprs.push(req_expr_nid);
        free_token_vec(req_tokens);
        rti = rti + 2;
    };
    // v0.4.246 RFC-0006 — pre-process #[ensure(EXPR)] attributes.
    // also rewrite `old(EXPR)` patterns inside the
    // ensure expression to synthesized binding names, lex+parse
    // each inner separately, and store (fn_name, synth_name,
    // inner_nid) triples in old_snapshots for fn-entry pre-eval.
    let ens_text_pairs: Vec<i32> = if dbc_emit_ensure_inv == 1 { collect_fn_ensures(source) } else { Vec::new() };
    let mut ensure_exprs: Vec<i32> = Vec::new();
    let mut old_snapshots: Vec<i32> = Vec::new();
    let mut eti: i64 = 0;
    let ens_text_count: i64 = vec_len(ens_text_pairs);
    while eti + 1 < ens_text_count {
        let ens_name: str = vec_get(ens_text_pairs, eti);
        if name_in_no_check(dbc_no_check, ens_name) == 1 { eti = eti + 2; continue; };
        let ens_text: str = vec_get(ens_text_pairs, eti + 1);
        // reject `result` reference in #[ensure] on void fn.
        // The fn has no return value to bind to; the alloca slot
        // holds whatever was zero-initialized (or stale prior call
        // state). `result == 0` happens to pass; `result > 0` panics
        // CONTRACT-002 — both wrong-error states. Halt cleanly with
        // CONTRACT-008 naming the void fn and the fix.
        let ens_rtype: str = fn_return_type(source, ens_name);
        if str_len(ens_rtype) == 0 {
            if ensure_text_uses_result(ens_text) == 1 {
                print(str_concat("error[CONTRACT-008]: `#[ensure(...)]` on `fn ", str_concat(ens_name, str_concat("` references `result`, but `", str_concat(ens_name, "` has no return type. The fn does not produce a value to bind `result` against. Either remove the `result` reference from the ensure predicate, or add a return type to the fn (e.g. `-> i64`) if you intended the ensure to assert on the output.")))));
                print(str_concat("  --> fn ", str_concat(ens_name, "@<#[ensure] attribute>")));
                return 1;
            };
        };
        // text-level rewrite of `old(EXPR)` to synth names.
        let rewrite: Vec<i32> = rewrite_old_in_ensure(ens_text, ens_name);
        let rewritten: str = vec_get(rewrite, 0);
        let nold: i64 = str_to_int(vec_get(rewrite, 1));
        let mut roi: i64 = 0;
        while roi < nold {
            let synth: str = vec_get(rewrite, 2 + roi * 2);
            let inner_text: str = vec_get(rewrite, 2 + roi * 2 + 1);
            // heap-aliased reject. If the inner is a bare
            // ident matching a fn param of heap-aliased type
            // (Vec/String/HashMap/HashSet/BTreeMap/BTreeSet/VecDeque/Box),
            // emit CONTRACT-006 because the i64-ABI snapshots the
            // pointer, not the buffer — old(v) would alias the
            // post-mutation pointer.
            if is_bare_ident(inner_text) == 1 {
                let pty: str = fn_param_type(source, ens_name, str_trim(inner_text));
                if str_len(pty) > 0 {
                    if is_heap_aliased_type(pty) == 1 {
                        let trimmed: str = str_trim(inner_text);
                        // Print directly to mirror the existing
                        // diag-text format, then halt. Bypasses the
                        // diags-vec accumulator because the main
                        // drain has already run and re-running the
                        // filter/promote pass corrupts string state
                        // under the i64-ABI's pointer reuse.
                        print(str_concat("error[CONTRACT-006]: `old(", str_concat(trimmed, str_concat(")` over param `", str_concat(trimmed, str_concat("` of type `", str_concat(pty, "` captures the i64-ABI heap pointer, not a deep snapshot. The pointer is the same one the body mutates — so `old(...)` aliases the post-mutation value and ensure semantics are wrong. Hoist a manual snapshot before the body (e.g. `let len_initial: i64 = vec_len(v);`) and reference that scalar in the ensure predicate, or mark the fn with `#[no_check]` to opt out.")))))));
                        print(str_concat("  --> fn ", str_concat(ens_name, "@<old() arg>")));
                        return 1;
                    };
                };
            };
            let in_tokens: Vec<i32> = lex(inner_text);
            let in_parsed: Vec<i32> = parse_expr(in_tokens, 0, pool);
            let in_nid: i64 = pr_val(in_parsed);
            old_snapshots.push(ens_name);
            old_snapshots.push(synth);
            old_snapshots.push(in_nid);
            free_token_vec(in_tokens);
            roi = roi + 1;
        };
        let ens_tokens: Vec<i32> = lex(rewritten);
        let ens_parsed: Vec<i32> = parse_expr(ens_tokens, 0, pool);
        let ens_expr_nid: i64 = pr_val(ens_parsed);
        ensure_exprs.push(ens_name);
        ensure_exprs.push(ens_expr_nid);
        free_token_vec(ens_tokens);
        eti = eti + 2;
    };
    // v0.4.248 RFC-0006 — pre-process #[invariant(EXPR)] attributes
    // on inherent + trait impl blocks. Stored by TYPE name; lower_fn
    // splits the mangled method name (`Type__method`) on `__` and
    // looks up the type's invariant.
    let inv_text_pairs: Vec<i32> = if dbc_emit_ensure_inv == 1 { collect_impl_invariants(source) } else { Vec::new() };
    let mut invariant_exprs: Vec<i32> = Vec::new();
    let mut iti: i64 = 0;
    let inv_text_count: i64 = vec_len(inv_text_pairs);
    while iti + 1 < inv_text_count {
        let inv_name: str = vec_get(inv_text_pairs, iti);
        let inv_text: str = vec_get(inv_text_pairs, iti + 1);
        let inv_tokens: Vec<i32> = lex(inv_text);
        let inv_parsed: Vec<i32> = parse_expr(inv_tokens, 0, pool);
        let inv_expr_nid: i64 = pr_val(inv_parsed);
        invariant_exprs.push(inv_name);
        invariant_exprs.push(inv_expr_nid);
        free_token_vec(inv_tokens);
        iti = iti + 2;
    };
    // build the shared fn-return-map once and pass
    // it to every lower_fn call instead of injecting per-fn entries.
    let fn_return_map: i64 = fn_return_map_new(pool, fn_decls);
    let suppress_self_host_auto_drop: i64 = if str_ends_with(src_path, "nucleor_s1_compiler.nr") == 1 { 1 } else { 0 };
    let lower_start: i64 = now_ms();
    fi = 0;
    while fi < cnt {
        let fn_nid: i64 = list_get(pool, prog, fi);
        if node_kind(pool, fn_nid) == 30 { fns.push(lower_fn(pool, fn_nid, strtab, strtab_aux, structs, enums, globals, closures, trait_impls, fn_decls, fn_return_map, require_exprs, ensure_exprs, invariant_exprs, old_snapshots, auto_drop_fns, manual_drop_fns, suppress_self_host_auto_drop)); };
        fi = fi + 1;
    };
    let mut ii: i64 = 0;
    while ii < vec_len(impl_fns) {
        fns.push(lower_fn(pool, vec_get(impl_fns, ii), strtab, strtab_aux, structs, enums, globals, closures, trait_impls, fn_decls, fn_return_map, require_exprs, ensure_exprs, invariant_exprs, old_snapshots, auto_drop_fns, manual_drop_fns, suppress_self_host_auto_drop));
        ii = ii + 1;
    };
    let mut ci3: i64 = 0;
    while ci3 < vec_len(closures) { fns.push(vec_get(closures, ci3)); ci3 = ci3 + 1; };
    print_phase_time(time_passes, "lower", now_ms() - lower_start);
    let opt_start: i64 = now_ms();
    let mut opt_total: i64 = 0;
    fi = 0;
    while fi < vec_len(fns) {
        opt_total = opt_total + opt_fn(vec_get(fns, fi));
        fi = fi + 1;
    };
    print_phase_time(time_passes, "opt", now_ms() - opt_start);
    print(str_concat("  functions: ", str_from_int(vec_len(fns))));
    print(str_concat("  strings: ", str_from_int(vec_len(strtab))));
    print(str_concat("  optimized: ", str_concat(str_from_int(opt_total), " instructions")));
    let emit_start: i64 = now_ms();
    let ll: str = emit_module_ext(fns, strtab, pool, externs, source);
    print_phase_time(time_passes, "emit", now_ms() - emit_start);
    // Drop compile graph top-level Vec storage before clang so native
    // link memory does not stack on top of the full compiler state.
    vec_free(bundle);
    free_node_pool(pool);
    vec_free(strtab);
    vec_free(fns);
    vec_free(externs);
    vec_free(structs);
    vec_free(enums);
    vec_free(globals);
    vec_free(fn_decls);
    vec_free(trait_impls);
    vec_free(impl_fns);
    vec_free(closures);
    let rc: i64 = link_native_module(ll, safe_out_name, imported, cache_key, link_native, time_passes);
    if use_cache == 1 {
        if rc == 0 {
            let cache_store_ll_path: str = sanitize(str_concat("target/", str_concat(safe_out_name, ".ll")));
            cache_v2_store(cache_key, src_path, cache_flags, ll, cache_store_ll_path);
            print(str_concat("cache: miss -> stored (sha=", str_concat(cache_v2_prefix(cache_key), str_concat(", size ", str_concat(str_from_int(cache_v2_size_mb(ll)), " MB)")))));
        } else {
            print(str_concat("cache: miss -> not stored (sha=", str_concat(cache_v2_prefix(cache_key), ", size 0 MB)")));
        };
        cache_v2_print_stats(0, 1);
    } else {
        cache_v2_print_stats(0, 0);
    };
    print_phase_time(time_passes, "total", now_ms() - total_start);
    return rc;
}

#[manual_drop]
fn compile_file(src_path: str, out_name: str) -> i64 {
    return compile_file_mode_native_isolated(src_path, out_name, 0, 1, 0, 1);
}

#[manual_drop]
fn should_isolate_native_link(src_path: str) -> i64 {
    if str_contains(src_path, "compiler/nucleor_s1_compiler.nr") == 1 { return 1; };
    if str_contains(src_path, "compiler\\nucleor_s1_compiler.nr") == 1 { return 1; };
    if str_contains(src_path, "compiler/nucleor_tools_suite.nr") == 1 { return 1; };
    if str_contains(src_path, "compiler\\nucleor_tools_suite.nr") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn child_shell_quote(arg: str) -> str {
    return str_concat("\"", str_concat(arg, "\""));
}

#[manual_drop]
fn self_compiler_exe_for_child() -> str {
    let raw: str = args_get(0);
    if str_len(extract_dir(raw)) > 0 { return host_shell_path(sanitize(raw)); };
    if host_is_windows() == 1 {
        let win_dot_bin: str = ".\\bin\\nucleor.exe";
        if path_exists(win_dot_bin) == 1 { return win_dot_bin; };
        let win_bin: str = "bin\\nucleor.exe";
        if path_exists(win_bin) == 1 { return win_bin; };
    };
    let posix_bin: str = "bin/nucleor";
    if path_exists(posix_bin) == 1 { return posix_bin; };
    let posix_exe: str = "bin/nucleor.exe";
    if path_exists(posix_exe) == 1 { return posix_exe; };
    return raw;
}

#[manual_drop]
fn compile_file_mode_native_isolated(src_path: str, out_name: str, strict_mode: i64, use_cache: i64, time_passes: i64, link_native: i64) -> i64 {
    if link_native == 0 { return compile_file_mode(src_path, out_name, strict_mode, use_cache, time_passes, 0); };
    if strict_mode != 0 { return compile_file_mode(src_path, out_name, strict_mode, use_cache, time_passes, link_native); };
    if args_count() == 0 { return compile_file_mode(src_path, out_name, strict_mode, use_cache, time_passes, link_native); };
    if should_isolate_native_link(src_path) == 0 { return compile_file_mode(src_path, out_name, strict_mode, use_cache, time_passes, link_native); };
    let total_start: i64 = now_ms();
    let safe_out_name: str = normalize_output_name(out_name);
    if str_len(safe_out_name) == 0 {
        print(str_concat("ERROR: invalid output name: ", out_name));
        return 1;
    };
    let child_exe: str = self_compiler_exe_for_child();
    let mut child_cmd: str = "";
    if host_is_windows() == 1 {
        child_cmd = str_concat(child_exe, str_concat(" build ", host_shell_path(sanitize(src_path))));
        child_cmd = str_concat(child_cmd, str_concat(" -o ", safe_out_name));
    } else {
        child_cmd = str_concat(child_shell_quote(child_exe), str_concat(" build ", child_shell_quote(sanitize(src_path))));
        child_cmd = str_concat(child_cmd, str_concat(" -o ", child_shell_quote(safe_out_name)));
    };
    child_cmd = str_concat(child_cmd, " --no-link");
    if use_cache == 0 { child_cmd = str_concat(child_cmd, " --no-cache"); };
    if cache_v2_stats_enabled() == 1 { child_cmd = str_concat(child_cmd, " --cache-stats"); };
    if time_passes == 1 { child_cmd = str_concat(child_cmd, " --time-passes"); };
    let child_rc: i64 = system(child_cmd);
    if child_rc != 0 { return child_rc; };
    let ll_path: str = sanitize(str_concat("target/", str_concat(safe_out_name, ".ll")));
    if fs_exists(ll_path) == 0 || fs_size(ll_path) <= 0 {
        print(str_concat("ERROR: native link cannot read emitted IR ", ll_path));
        return 1;
    };
    let mut native_key_hint: str = "";
    if use_cache == 1 {
        let key_path: str = str_concat(ll_path, ".cachekey");
        if fs_exists(key_path) == 1 { native_key_hint = file_read_string(key_path); };
    };
    let imported: Vec<i32> = Vec::new();
    let rc: i64 = link_existing_native_module(ll_path, safe_out_name, imported, native_key_hint, time_passes);
    vec_free(imported);
    print_phase_time(time_passes, "total_native", now_ms() - total_start);
    return rc;
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

// ===== v0.3.0 (T3.1): #[deadline = N] runtime check rewrite =====
// Wraps fns annotated `#[deadline = N]` (microseconds) into a thin
// shim that captures the start time, calls the original body via
// a synthesized inner fn, then runs `deadline_check(start, N)`
// before returning. If the elapsed time exceeded N microseconds,
// the runtime aborts with `error[RT-004]`.
// Approach: rather than walking the body to find every `return`
// (which would need bracket-balanced + block-aware scanning), we
// rename the user's fn to `__nuc_dl_inner_<idx>` and synthesize a
// new outer fn with the original name that does:
//   let __nuc_dl_start: i64 = time_monotonic_us();
//   let __nuc_dl_r: <ret> = __nuc_dl_inner_<idx>(<args>);
//   deadline_check(__nuc_dl_start, N);
//   return __nuc_dl_r;
// The runtime check runs UNCONDITIONALLY at fn exit. Static WCET
// bounds (RT-004 at compile time) ship later in v0.3.1.

#[manual_drop]
fn dl_extract_int_value(line: str) -> i64 {
    // Reads `#[deadline = N]` from the line and returns N (>= 0).
    // Returns -1 if the line doesn't match the expected shape.
    let needle: str = "#[deadline";
    let pos: i64 = source_find(line, needle);
    if pos < 0 { return 0 - 1; };
    let llen: i64 = str_len(line);
    let mut p: i64 = pos + str_len(needle);
    while p < llen && (str_char_at(line, p) == 32 || str_char_at(line, p) == 9) { p = p + 1; };
    if p >= llen || str_char_at(line, p) != 61 { return 0 - 1; };
    p = p + 1;
    while p < llen && (str_char_at(line, p) == 32 || str_char_at(line, p) == 9) { p = p + 1; };
    let num_start: i64 = p;
    while p < llen && is_digit(str_char_at(line, p)) == 1 { p = p + 1; };
    if p == num_start { return 0 - 1; };
    return str_to_int(str_substring(line, num_start, p));
}

#[manual_drop]
fn dl_parse_fn_signature(src: str, fn_pos: i64, slen: i64) -> Vec<i32> {
    // Given `fn ` at fn_pos, extract:
    //   [0] = fn name (str)
    //   [1] = full param decl text "a: T1, b: T2" (str)
    //   [2] = return type "i64" or "" if void
    //   [3] = comma-separated arg names "a, b" (str)
    //   [4] = position of the `{` opening the body (i64)
    //   [5] = position one past the matching `}` (i64)
    // On parse failure, returns Vec with vec_len == 0.
    let mut out: Vec<i32> = Vec::new();
    let mut p: i64 = fn_pos + 3;  // skip past "fn "
    while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
    let name_start: i64 = p;
    let mut name_done: i64 = 0;
    while p < slen && name_done == 0 {
        let c: i64 = str_char_at(src, p);
        if is_alnum(c) == 1 || c == 95 { p = p + 1; }
        else { name_done = 1; };
    };
    if p == name_start { return out; };
    let fn_name: str = str_substring(src, name_start, p);
    while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
    if p >= slen || str_char_at(src, p) != 40 { return out; };
    let params_start: i64 = p + 1;
    let mut depth: i64 = 1;
    p = params_start;
    while p < slen && depth > 0 {
        let c: i64 = str_char_at(src, p);
        if c == 40 { depth = depth + 1; }
        else if c == 41 { depth = depth - 1; };
        if depth > 0 { p = p + 1; };
    };
    if p >= slen { return out; };
    let params_text: str = str_substring(src, params_start, p);
    p = p + 1;
    while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
    let mut ret_type: str = "";
    if p + 1 < slen && str_char_at(src, p) == 45 && str_char_at(src, p + 1) == 62 {
        p = p + 2;
        while p < slen && (str_char_at(src, p) == 32 || str_char_at(src, p) == 9) { p = p + 1; };
        let rt_start: i64 = p;
        while p < slen && str_char_at(src, p) != 32 && str_char_at(src, p) != 9 && str_char_at(src, p) != 123 { p = p + 1; };
        ret_type = str_substring(src, rt_start, p);
    };
    while p < slen && str_char_at(src, p) != 123 { p = p + 1; };
    if p >= slen { return out; };
    let body_open: i64 = p;
    let mut q: i64 = p + 1;
    let mut body_depth: i64 = 1;
    let mut in_dq: i64 = 0;
    let mut in_sq: i64 = 0;
    while q < slen && body_depth > 0 {
        let c2: i64 = str_char_at(src, q);
        if in_dq == 1 {
            if c2 == 92 && q + 1 < slen { q = q + 1; }
            else if c2 == 34 { in_dq = 0; };
        } else if in_sq == 1 {
            if c2 == 92 && q + 1 < slen { q = q + 1; }
            else if c2 == 39 { in_sq = 0; };
        } else if c2 == 47 && q + 1 < slen && str_char_at(src, q + 1) == 47 {
            while q < slen && str_char_at(src, q) != 10 { q = q + 1; };
        } else if c2 == 34 { in_dq = 1; }
        else if c2 == 39 { in_sq = 1; }
        else if c2 == 123 { body_depth = body_depth + 1; }
        else if c2 == 125 { body_depth = body_depth - 1; };
        q = q + 1;
    };
    if body_depth != 0 { return out; };
    // Extract arg names from params_text
    let mut arg_names: str = "";
    let plen: i64 = str_len(params_text);
    let mut sp: i64 = 0;
    let mut first_arg: i64 = 1;
    while sp < plen {
        while sp < plen && (str_char_at(params_text, sp) == 32 || str_char_at(params_text, sp) == 9 || str_char_at(params_text, sp) == 44 || str_char_at(params_text, sp) == 10) { sp = sp + 1; };
        if sp >= plen { sp = plen + 1; }
        else {
            while sp + 1 < plen && str_char_at(params_text, sp) == 35 && str_char_at(params_text, sp + 1) == 91 {
                sp = sp + 2;
                let mut attr_depth: i64 = 1;
                while sp < plen && attr_depth > 0 {
                    let ac: i64 = str_char_at(params_text, sp);
                    if ac == 91 { attr_depth = attr_depth + 1; }
                    else if ac == 93 { attr_depth = attr_depth - 1; };
                    sp = sp + 1;
                };
                while sp < plen && (str_char_at(params_text, sp) == 32 || str_char_at(params_text, sp) == 9 || str_char_at(params_text, sp) == 10) { sp = sp + 1; };
            };
            let an_start: i64 = sp;
            while sp < plen && (is_alnum(str_char_at(params_text, sp)) == 1 || str_char_at(params_text, sp) == 95) { sp = sp + 1; };
            if sp == an_start { sp = sp + 1; }
            else {
                let arg_name: str = str_substring(params_text, an_start, sp);
                if first_arg == 0 { arg_names = str_concat(arg_names, ", "); };
                arg_names = str_concat(arg_names, arg_name);
                first_arg = 0;
                // Skip until next comma at depth 0
                let mut adepth: i64 = 0;
                let mut at_comma: i64 = 0;
                while sp < plen && at_comma == 0 {
                    let cc: i64 = str_char_at(params_text, sp);
                    if cc == 40 || cc == 60 || cc == 91 { adepth = adepth + 1; sp = sp + 1; }
                    else if cc == 41 || cc == 62 || cc == 93 { adepth = adepth - 1; sp = sp + 1; }
                    else if cc == 44 && adepth == 0 { at_comma = 1; }
                    else { sp = sp + 1; };
                };
            };
        };
    };
    out.push(fn_name);
    out.push(params_text);
    out.push(ret_type);
    out.push(arg_names);
    out.push(body_open);
    out.push(q);
    return out;
}

// scan resolved source for the
// literal `@differentiable` byte sequence and return the count.
// Adopters tag fns with `@differentiable` (RFC-0045 syntax); the
// lex-time skip silently accepts the attribute. This audit pass
// counts occurrences so the build emits a one-line "N fns
// tagged" summary — addressing the v0.7.93 Phase A "Discovery:
// no way to grep for all differentiable fns in a codebase"
// surface gap.
// Skips the count when compiling the compiler itself (the
// pattern appears in this comment + in expand_differentiable
// dispatcher source). Same self-host guard as the v0.7.98
// compile_error pre-pass.
#[manual_drop]
fn differentiable_audit_count(src: str) -> i64 {
    let mut count: i64 = 0;
    let needle: str = str_concat("@differen", "tiable");
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    if nlen <= 0 { return 0; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            count = count + 1;
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return count;
}

// generic substring-counter for
// attribute-audit passes. Sister to differentiable_audit_count;
// extracted for reuse across @energy / @thermal / future
// @authored / @policy / etc. discoveries.
// v0.8.44 NUM-G1 — count source-level float literals with >6
// fractional digits. Walks src once; on each digit, scans forward
// to find a dot, then counts fractional digits. If >=7, increments
// counter. Self-host safe: comments and strings are scanned too,
// but most legit content doesn't have long-decimal float literals
// outside of test fixtures. Comment-text mentions like
// "3.14159265" in this file's own diagnostic message would trip
// this — kept in this file via str_concat construction below.
#[manual_drop]
fn count_long_float_literals(src: str) -> i64 {
    let slen: i64 = str_len(src);
    let mut count: i64 = 0;
    let mut p: i64 = 0;
    while p + 8 < slen {
        let c0: i64 = str_char_at(src, p);
        if c0 >= 48 && c0 <= 57 {
            // walk past leading integer-part digits
            let mut q: i64 = p + 1;
            while q < slen && str_char_at(src, q) >= 48 && str_char_at(src, q) <= 57 {
                q = q + 1;
            };
            if q < slen && str_char_at(src, q) == 46 {
                // walk past dot, count fractional digits
                let mut r: i64 = q + 1;
                while r < slen && str_char_at(src, r) >= 48 && str_char_at(src, r) <= 57 {
                    r = r + 1;
                };
                let frac: i64 = r - q - 1;
                if frac >= 7 { count = count + 1; };
                p = r;
            } else {
                p = q;
            };
        } else {
            p = p + 1;
        };
    };
    return count;
}

#[manual_drop]
fn simple_attribute_audit_count(src: str, needle: str) -> i64 {
    let mut count: i64 = 0;
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    if nlen <= 0 { return 0; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            count = count + 1;
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return count;
}

// single-pass total counter for three-needle
// audits. Walks src once; at each position checks each needle
// in turn. Returns the sum of occurrences across all three.
// ~3x cheaper than three simple_attribute_audit_count calls
// when the caller only needs the combined total (e.g. BR-7
// lifetime audit).
#[manual_drop]
fn audit_count_three_needles_total(src: str, n1: str, n2: str, n3: str) -> i64 {
    let mut count: i64 = 0;
    let slen: i64 = str_len(src);
    let l1: i64 = str_len(n1);
    let l2: i64 = str_len(n2);
    let l3: i64 = str_len(n3);
    let mut p: i64 = 0;
    while p < slen {
        if l1 > 0 && p + l1 <= slen && str_eq_at_len(src, p, n1, l1) == 1 {
            count = count + 1;
            p = p + l1;
        } else {
            if l2 > 0 && p + l2 <= slen && str_eq_at_len(src, p, n2, l2) == 1 {
                count = count + 1;
                p = p + l2;
            } else {
                if l3 > 0 && p + l3 <= slen && str_eq_at_len(src, p, n3, l3) == 1 {
                    count = count + 1;
                    p = p + l3;
                } else {
                    p = p + 1;
                };
            };
        };
    };
    return count;
}

// capture the fn names tagged with a
// given attribute. Walks each `<needle>` occurrence, skips
// past attribute args + whitespace + newlines + nested
// attribute lines, then expects `fn NAME(...)` and captures
// NAME. Returns `; `-separated list.
// Used for the audit-channel "list of tagged fns" surface across
// the remaining 6 attribute families (@differentiable, @attested,
// @hot, @const_fn, #[max_depth], #[deadline]) plus any future
// addition with no key=val args to extract.
#[manual_drop]
fn attribute_audit_fn_names(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            // Walk past attribute args (paren or bracket form),
            // newlines, additional attribute lines, doc comments,
            // and `pub` to land on `fn`.
            let mut q: i64 = p + nlen;
            // Skip optional `(...)` or `[...]` arglist.
            if q < slen && (str_char_at(src, q) == 40 || str_char_at(src, q) == 91) {
                let close_ch: i64 = if str_char_at(src, q) == 40 { 41 } else { 93 };
                let mut depth: i64 = 1;
                q = q + 1;
                while q < slen && depth > 0 {
                    let ch: i64 = str_char_at(src, q);
                    if ch == 40 || ch == 91 { depth = depth + 1; };
                    if ch == close_ch { depth = depth - 1; };
                    q = q + 1;
                };
            };
            // Skip whitespace + newlines + further attribute lines.
            let mut tries: i64 = 0;
            while tries < 16 && q < slen {
                let ch: i64 = str_char_at(src, q);
                if ch == 32 || ch == 9 || ch == 10 || ch == 13 { q = q + 1; }
                else if ch == 64 || ch == 35 {
                    // Another attribute — skip its line.
                    while q < slen && str_char_at(src, q) != 10 { q = q + 1; };
                }
                else { tries = 16; };
                tries = tries + 1;
                if tries >= 1024 { tries = 16; };
            };
            // Optional `pub` modifier.
            if q + 4 <= slen && str_eq_at(src, q, "pub ") == 1 { q = q + 4; };
            while q < slen && (str_char_at(src, q) == 32 || str_char_at(src, q) == 9) { q = q + 1; };
            // Expect `fn ` then capture ident.
            if q + 3 <= slen && str_eq_at(src, q, "fn ") == 1 {
                q = q + 3;
                while q < slen && (str_char_at(src, q) == 32 || str_char_at(src, q) == 9) { q = q + 1; };
                let r0: i64 = q;
                while q < slen && is_alnum(str_char_at(src, q)) == 1 { q = q + 1; };
                if q > r0 {
                    if emitted == 1 { out = str_concat(out, "; "); };
                    out = str_concat(out, str_substring(src, r0, q));
                    emitted = 1;
                };
            };
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return out;
}

// extract the device name from
// `@<attr>[device=<name>]` bracket-form attributes (RFC-0052
// `@photonic[device=lightmatter_x1]`, RFC-0053
// `@neuromorphic[device=loihi2]`). Captures the substring
// after `device=` up to `]`, with optional surrounding quotes
// stripped. Returns `; `-separated list across all matches.
#[manual_drop]
fn attribute_audit_bracket_device(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            let q: i64 = p + nlen;
            let dev_needle: str = str_concat("dev", "ice=");
            let dlen: i64 = str_len(dev_needle);
            // Find the closing `]` for this bracket.
            let mut close: i64 = q;
            while close < slen && str_char_at(src, close) != 93 && str_char_at(src, close) != 10 {
                close = close + 1;
            };
            // Scan q..close for `device=`.
            let mut k: i64 = q;
            let mut found: i64 = 0 - 1;
            while k + dlen <= close && found < 0 {
                if str_eq_at_len(src, k, dev_needle, dlen) == 1 { found = k + dlen; };
                k = k + 1;
            };
            if found >= 0 {
                let mut vs: i64 = found;
                while vs < close && (str_char_at(src, vs) == 32 || str_char_at(src, vs) == 9) {
                    vs = vs + 1;
                };
                let mut quoted: i64 = 0;
                if vs < close && str_char_at(src, vs) == 34 { quoted = 1; vs = vs + 1; };
                let mut ve: i64 = vs;
                while ve < close && str_char_at(src, ve) != 44 && (quoted == 0 || str_char_at(src, ve) != 34) {
                    ve = ve + 1;
                };
                if ve > vs {
                    if emitted == 1 { out = str_concat(out, "; "); };
                    out = str_concat(out, str_substring(src, vs, ve));
                    emitted = 1;
                };
            };
            p = close + 1;
        } else {
            p = p + 1;
        };
    };
    return out;
}

// capture ALL `key=value` pairs from
// each `@<attr>(...)` invocation (multi-key form). Returns a
// `; `-separated list of `key=value` strings.
// `@thermal(min_temp=-40C, max_temp=85C)` -> "min_temp=-40C; max_temp=85C"
// `@energy(max=2mJ)` -> "max=2mJ"
// Captures everything from the first non-whitespace char after
// `(` up to the matching `)`, then walks through the captured
// arg-list character-by-character, splitting on `,` (depth-0)
// and emitting trimmed pieces.
#[manual_drop]
fn attribute_audit_all_kv_pairs(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            let q: i64 = p + nlen;
            // Walk to the matching close-paren (depth aware).
            let mut depth: i64 = 1;
            let mut close: i64 = q;
            while close < slen && depth > 0 {
                let ch: i64 = str_char_at(src, close);
                if ch == 40 { depth = depth + 1; };
                if ch == 41 { depth = depth - 1; };
                if depth > 0 { close = close + 1; };
            };
            // Walk q..close, splitting on top-level `,`.
            let mut piece_start: i64 = q;
            let mut i: i64 = q;
            let mut inner_depth: i64 = 0;
            while i <= close {
                let at_close: i64 = if i == close { 1 } else { 0 };
                let ch: i64 = if i < slen { str_char_at(src, i) } else { 0 };
                let is_split: i64 = if at_close == 1 { 1 } else if ch == 44 && inner_depth == 0 { 1 } else { 0 };
                if is_split == 1 {
                    let mut s0: i64 = piece_start;
                    let mut s1: i64 = i;
                    while s0 < s1 && (str_char_at(src, s0) == 32 || str_char_at(src, s0) == 9) { s0 = s0 + 1; };
                    while s1 > s0 && (str_char_at(src, s1 - 1) == 32 || str_char_at(src, s1 - 1) == 9) { s1 = s1 - 1; };
                    if s1 > s0 {
                        if emitted == 1 { out = str_concat(out, "; "); };
                        out = str_concat(out, str_substring(src, s0, s1));
                        emitted = 1;
                    };
                    piece_start = i + 1;
                };
                if i < close {
                    if ch == 40 { inner_depth = inner_depth + 1; };
                    if ch == 41 && inner_depth > 0 { inner_depth = inner_depth - 1; };
                };
                i = i + 1;
            };
            p = close + 1;
        } else {
            p = p + 1;
        };
    };
    return out;
}

// extract numeric value+unit pairs from
// `@<attr>(<key>=<value>)` invocations like `@energy(max=2mJ)`,
// `@thermal(max_temp=85C)`, `@within(200ns)`. Captures the
// substring between `=` and the closing `)` or `,`, trimmed of
// surrounding whitespace. For `@within(200ns)` (no key=), it
// captures everything between `(` and `)`.
// Returns `; `-separated list of captured value-strings.
#[manual_drop]
fn attribute_audit_value_arg(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            // Find the start of the value: after `=` if present
            // before the close, otherwise immediately after `(`.
            let mut q: i64 = p + nlen;
            // Walk to either `=` or `)` or end-of-line.
            let mut value_start: i64 = q;
            let mut saw_eq: i64 = 0;
            let mut probe: i64 = q;
            while probe < slen && str_char_at(src, probe) != 41 && str_char_at(src, probe) != 10 {
                if str_char_at(src, probe) == 61 {
                    saw_eq = 1;
                    value_start = probe + 1;
                };
                probe = probe + 1;
            };
            if saw_eq == 0 { value_start = q; };
            // Skip leading whitespace.
            while value_start < slen && (str_char_at(src, value_start) == 32 || str_char_at(src, value_start) == 9) {
                value_start = value_start + 1;
            };
            // Capture until `,` or `)` or end-of-line.
            let mut value_end: i64 = value_start;
            while value_end < slen && str_char_at(src, value_end) != 44 && str_char_at(src, value_end) != 41 && str_char_at(src, value_end) != 10 {
                value_end = value_end + 1;
            };
            // Trim trailing whitespace.
            while value_end > value_start && (str_char_at(src, value_end - 1) == 32 || str_char_at(src, value_end - 1) == 9) {
                value_end = value_end - 1;
            };
            if value_end > value_start {
                if emitted == 1 { out = str_concat(out, "; "); };
                out = str_concat(out, str_substring(src, value_start, value_end));
                emitted = 1;
            };
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return out;
}

// extract the first BARE-IDENTIFIER
// argument from each `@<attr>(...)` invocation. Used by attrs
// like `@enclave(tdx)` / `@enclave(sev_snp)` where the
// argument is a bare ident (no quotes).
#[manual_drop]
fn attribute_audit_first_ident_arg(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            // Walk forward past `(` then optional whitespace.
            let mut q: i64 = p + nlen;
            while q < slen && (str_char_at(src, q) == 32 || str_char_at(src, q) == 9) {
                q = q + 1;
            };
            // Capture chars while is_alnum (ident class).
            let r0: i64 = q;
            while q < slen && is_alnum(str_char_at(src, q)) == 1 {
                q = q + 1;
            };
            if q > r0 {
                if emitted == 1 { out = str_concat(out, "; "); };
                out = str_concat(out, str_substring(src, r0, q));
                emitted = 1;
            };
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return out;
}

// extract the first quoted string-literal
// argument from each `@<attr>(...)` invocation in the resolved
// source. Returns a `; `-separated list of the extracted names
// (or empty string when none). Used by the @authored audit to
// emit the actual list of authors at build time, going past the
// step-1 count-only summary. Generic shape — same scan reusable
// for @policy, @photonic[device=...], etc. as those settle into
// quoted-string-arg conventions.
#[manual_drop]
fn attribute_audit_first_str_arg(src: str, needle: str) -> str {
    let slen: i64 = str_len(src);
    let nlen: i64 = str_len(needle);
    let mut out: str = "";
    let mut emitted: i64 = 0;
    if nlen <= 0 { return out; };
    let mut p: i64 = 0;
    while p + nlen <= slen {
        if str_eq_at_len(src, p, needle, nlen) == 1 {
            // Walk forward past `(`, optional whitespace, optional
            // `key=` or `device=` prefix, to the first `"`. Accept
            // chars until the next `"` or end-of-line.
            let mut q: i64 = p + nlen;
            while q < slen && str_char_at(src, q) != 34 && str_char_at(src, q) != 10 && str_char_at(src, q) != 41 {
                q = q + 1;
            };
            if q < slen && str_char_at(src, q) == 34 {
                let r0: i64 = q + 1;
                let mut r1: i64 = r0;
                while r1 < slen && str_char_at(src, r1) != 34 && str_char_at(src, r1) != 10 {
                    r1 = r1 + 1;
                };
                if r1 > r0 {
                    if emitted == 1 { out = str_concat(out, "; "); };
                    out = str_concat(out, str_substring(src, r0, r1));
                    emitted = 1;
                };
            };
            p = p + nlen;
        } else {
            p = p + 1;
        };
    };
    return out;
}

#[manual_drop]
fn expand_deadline(src: str) -> str {
    // Walk source line-by-line. When we see `#[deadline = N]` (after
    // optional doc comments), find the next `fn ...` declaration and
    // wrap it. Each rewrite replaces the original fn with two fns:
    //   __nuc_dl_inner_<idx>  — the original body
    //   <name>                — the wrapper that does start-cap +
    //                           inner-call + deadline_check + return
    let slen: i64 = str_len(src);
    let mut sb: i64 = sb_new();
    let mut p: i64 = 0;
    let mut idx: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        // Skip `//` line comments — `#[deadline = N]` text inside a
        // comment must not trigger wrapping (and previously caused an
        // infinite probe loop in the give-up branch below).
        let trimmed_line: str = strip_spaces(line);
        let tllen: i64 = str_len(trimmed_line);
        if tllen >= 2 && str_char_at(trimmed_line, 0) == 47 && str_char_at(trimmed_line, 1) == 47 {
            sb_append(sb, str_substring(src, p, eol));
            if eol < slen { sb_append(sb, "\n"); };
            p = eol + 1;
            continue;
        };
        let dl_value: i64 = dl_extract_int_value(line);
        if dl_value >= 0 {
            // Scan forward past blank lines + doc comments + other
            // attribute lines for the actual fn start. Use sentinel
            // -1 = still searching, >= 0 = found, -2 = give up; only
            // -1 keeps the loop going (older `< 0` form spun forever
            // on the give-up branch since -2 is also `< 0`).
            let mut probe: i64 = eol + 1;
            let mut found_fn: i64 = 0 - 1;
            while probe < slen && found_fn == 0 - 1 {
                let mut peol: i64 = probe;
                while peol < slen && str_char_at(src, peol) != 10 { peol = peol + 1; };
                let pline: str = str_substring(src, probe, peol);
                let trimmed: str = strip_spaces(pline);
                let tlen: i64 = str_len(trimmed);
                if tlen == 0 {
                    probe = peol + 1;
                } else if tlen >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                    probe = peol + 1;
                } else if tlen >= 1 && str_char_at(trimmed, 0) == 35 {
                    // Other #[...] attribute — skip
                    probe = peol + 1;
                } else if tlen >= 2 && str_eq(str_substring(trimmed, 0, 2), "fn") == 1 {
                    let mut fnpos: i64 = probe;
                    while fnpos < peol && (str_char_at(src, fnpos) == 32 || str_char_at(src, fnpos) == 9) { fnpos = fnpos + 1; };
                    found_fn = fnpos;
                } else if tlen >= 5 && str_eq(str_substring(trimmed, 0, 5), "pub f") == 1 {
                    let mut fnpos: i64 = probe;
                    while fnpos < peol && (str_char_at(src, fnpos) == 32 || str_char_at(src, fnpos) == 9) { fnpos = fnpos + 1; };
                    if fnpos + 4 <= peol && str_eq(str_substring(src, fnpos, fnpos + 4), "pub ") == 1 {
                        fnpos = fnpos + 4;
                    };
                    found_fn = fnpos;
                } else {
                    // Anything else — give up; emit original line.
                    found_fn = 0 - 2;
                };
            };
            if found_fn >= 0 {
                let info: Vec<i32> = dl_parse_fn_signature(src, found_fn, slen);
                if vec_len(info) > 0 {
                    let fn_name: str = vec_get(info, 0);
                    let params_text: str = vec_get(info, 1);
                    let ret_type: str = vec_get(info, 2);
                    let arg_names: str = vec_get(info, 3);
                    let body_open: i64 = vec_get(info, 4);
                    let body_end: i64 = vec_get(info, 5);
                    let inner_name: str = str_concat("__nuc_dl_inner_", str_concat(content_hash(fn_name), str_concat("_", str_from_int(idx))));
                    idx = idx + 1;
                    // Drop the #[deadline = N] line itself (do nothing for it).
                    // Emit everything between the line after the attribute
                    // and the start of the fn (which is empty/doc/other attrs)
                    // verbatim — preserves doc comments and other attributes.
                    sb_append(sb, str_substring(src, eol + 1, found_fn));
                    // Emit inner fn (original body, renamed).
                    sb_append(sb, "fn ");
                    sb_append(sb, inner_name);
                    sb_append(sb, "(");
                    sb_append(sb, params_text);
                    sb_append(sb, ") ");
                    if str_len(ret_type) > 0 {
                        sb_append(sb, "-> ");
                        sb_append(sb, ret_type);
                        sb_append(sb, " ");
                    };
                    sb_append(sb, str_substring(src, body_open, body_end));
                    sb_append(sb, "\n\n");
                    // Emit outer wrapper fn with original name.
                    sb_append(sb, "fn ");
                    sb_append(sb, fn_name);
                    sb_append(sb, "(");
                    sb_append(sb, params_text);
                    sb_append(sb, ") ");
                    if str_len(ret_type) > 0 {
                        sb_append(sb, "-> ");
                        sb_append(sb, ret_type);
                        sb_append(sb, " ");
                    };
                    sb_append(sb, "{\n");
                    sb_append(sb, "    let __nuc_dl_start: i64 = time_monotonic_us();\n");
                    sb_append(sb, "    deadline_enter(__nuc_dl_start, ");
                    sb_append(sb, str_from_int(dl_value));
                    sb_append(sb, ");\n");
                    if str_len(ret_type) > 0 && str_eq(ret_type, "void") == 0 {
                        sb_append(sb, "    let __nuc_dl_r: ");
                        sb_append(sb, ret_type);
                        sb_append(sb, " = ");
                        sb_append(sb, inner_name);
                        sb_append(sb, "(");
                        sb_append(sb, arg_names);
                        sb_append(sb, ");\n");
                        sb_append(sb, "    deadline_exit();\n");
                        sb_append(sb, "    deadline_check(__nuc_dl_start, ");
                        sb_append(sb, str_from_int(dl_value));
                        sb_append(sb, ");\n");
                        sb_append(sb, "    return __nuc_dl_r;\n");
                    } else {
                        sb_append(sb, "    ");
                        sb_append(sb, inner_name);
                        sb_append(sb, "(");
                        sb_append(sb, arg_names);
                        sb_append(sb, ");\n");
                        sb_append(sb, "    deadline_exit();\n");
                        sb_append(sb, "    deadline_check(__nuc_dl_start, ");
                        sb_append(sb, str_from_int(dl_value));
                        sb_append(sb, ");\n");
                    };
                    sb_append(sb, "}\n");
                    p = body_end;
                    continue;
                };
            };
        };
        // Default: emit the line as-is.
        sb_append(sb, str_substring(src, p, eol));
        if eol < slen { sb_append(sb, "\n"); };
        p = eol + 1;
    };
    return sb_to_str(sb);
}

// backward-scan helper for `#[max_depth = N]` impl-context.
// The wrapper-rewrite needs the enclosing impl-block's receiver type
// (e.g. "Node" for `impl Node { ... }` or `impl Trait for Node { ... }`)
// to emit `<Type>::<inner>(...)` for assoc-fn (no-self) recursion. We
// scan backwards from the attribute position, balancing braces, to find
// the most-recent unclosed `impl <Type> [for <Type2>]?\s*{`. Returns ""
// when not in an impl block (free fn at module top level).
#[manual_drop]
fn md_find_enclosing_impl_type(src: str, attr_pos: i64) -> str {
    let mut depth: i64 = 0;
    let mut p: i64 = attr_pos - 1;
    while p >= 0 {
        let c: i64 = str_char_at(src, p);
        if c == 125 { depth = depth + 1; };
        if c == 123 {
            if depth == 0 {
                let mut q: i64 = p - 1;
                while q >= 0 && (str_char_at(src, q) == 32 || str_char_at(src, q) == 9 || str_char_at(src, q) == 10 || str_char_at(src, q) == 13) { q = q - 1; };
                let name_end: i64 = q + 1;
                while q >= 0 && (is_alnum(str_char_at(src, q)) == 1 || str_char_at(src, q) == 95) { q = q - 1; };
                let name_start: i64 = q + 1;
                if name_end <= name_start { return ""; };
                let cand_name: str = str_substring(src, name_start, name_end);
                let mut r: i64 = q;
                while r >= 0 && (str_char_at(src, r) == 32 || str_char_at(src, r) == 9 || str_char_at(src, r) == 10 || str_char_at(src, r) == 13) { r = r - 1; };
                let prev_end: i64 = r + 1;
                while r >= 0 && (is_alnum(str_char_at(src, r)) == 1 || str_char_at(src, r) == 95) { r = r - 1; };
                let prev_start: i64 = r + 1;
                let prev_word: str = if prev_end > prev_start { str_substring(src, prev_start, prev_end) } else { "" };
                if str_eq(prev_word, "impl") == 1 {
                    if prev_start == 0 || str_char_at(src, prev_start - 1) == 32 || str_char_at(src, prev_start - 1) == 9 || str_char_at(src, prev_start - 1) == 10 {
                        return cand_name;
                    };
                    return "";
                };
                if str_eq(prev_word, "for") == 1 {
                    let mut s: i64 = r;
                    while s >= 0 && (str_char_at(src, s) == 32 || str_char_at(src, s) == 9 || str_char_at(src, s) == 10 || str_char_at(src, s) == 13) { s = s - 1; };
                    while s >= 0 && (is_alnum(str_char_at(src, s)) == 1 || str_char_at(src, s) == 95) { s = s - 1; };
                    while s >= 0 && (str_char_at(src, s) == 32 || str_char_at(src, s) == 9 || str_char_at(src, s) == 10 || str_char_at(src, s) == 13) { s = s - 1; };
                    let il_end: i64 = s + 1;
                    while s >= 0 && (is_alnum(str_char_at(src, s)) == 1 || str_char_at(src, s) == 95) { s = s - 1; };
                    let il_start: i64 = s + 1;
                    if il_end > il_start {
                        let il_word: str = str_substring(src, il_start, il_end);
                        if str_eq(il_word, "impl") == 1 {
                            return cand_name;
                        };
                    };
                    return "";
                };
                return "";
            };
            depth = depth - 1;
        };
        p = p - 1;
    };
    return "";
}

#[manual_drop]
fn expand_max_depth(src: str) -> str {
    // Runtime half of RFC-0014. Valid `#[max_depth = N]` fns are
    // rewritten into an inner body plus a wrapper that increments and
    // decrements a per-function depth counter. Static validation runs
    // on the pre-rewrite source so invalid attrs stay visible there.
    if source_has_max_depth_attr_line(src) == 0 { return src; };
    let slen: i64 = str_len(src);
    let mut sb: i64 = sb_new();
    let mut p: i64 = 0;
    let mut idx: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        let compact_line: str = strip_spaces(line);
        if str_starts_with(compact_line, "#[max_depth") == 1 {
            let md_value: i64 = md_extract_int_value(line);
            if md_value > 0 {
                let mut probe: i64 = eol + 1;
                let mut found_fn: i64 = 0 - 1;
                let mut gave_up: i64 = 0;
                while probe < slen && found_fn < 0 && gave_up == 0 {
                    let mut peol: i64 = probe;
                    while peol < slen && str_char_at(src, peol) != 10 { peol = peol + 1; };
                    let pline: str = str_substring(src, probe, peol);
                    let mut lp: i64 = 0;
                    let llen: i64 = str_len(pline);
                    while lp < llen && (str_char_at(pline, lp) == 32 || str_char_at(pline, lp) == 9) { lp = lp + 1; };
                    let ptrim: str = strip_spaces(pline);
                    if str_len(ptrim) == 0 {
                        probe = peol + 1;
                    } else if str_starts_with(ptrim, "///") == 1 {
                        probe = peol + 1;
                    } else if str_eq_at(pline, lp, "fn ") == 1 {
                        found_fn = probe + lp;
                    } else if str_eq_at(pline, lp, "pub fn ") == 1 {
                        found_fn = probe + lp + 4;
                    } else if lp < llen && str_char_at(pline, lp) == 35 {
                        probe = peol + 1;
                    } else {
                        gave_up = 1;
                    };
                };
                if found_fn >= 0 {
                    let info: Vec<i32> = dl_parse_fn_signature(src, found_fn, slen);
                    if vec_len(info) > 0 {
                        let fn_name: str = vec_get(info, 0);
                        let params_text: str = vec_get(info, 1);
                        let ret_type: str = vec_get(info, 2);
                        let arg_names: str = vec_get(info, 3);
                        let body_open: i64 = vec_get(info, 4);
                        let body_end: i64 = vec_get(info, 5);
                        let inner_name: str = str_concat("__nuc_md_inner_", str_concat(content_hash(fn_name), str_concat("_", str_from_int(idx))));
                        let counter_id: i64 = idx + 1;
                        idx = idx + 1;
                        sb_append(sb, str_substring(src, eol + 1, found_fn));
                        sb_append(sb, "fn ");
                        sb_append(sb, inner_name);
                        sb_append(sb, "(");
                        sb_append(sb, params_text);
                        sb_append(sb, ") ");
                        if str_len(ret_type) > 0 {
                            sb_append(sb, "-> ");
                            sb_append(sb, ret_type);
                            sb_append(sb, " ");
                        };
                        sb_append(sb, str_substring(src, body_open, body_end));
                        sb_append(sb, "\n\n");
                        sb_append(sb, "fn ");
                        sb_append(sb, fn_name);
                        sb_append(sb, "(");
                        sb_append(sb, params_text);
                        sb_append(sb, ") ");
                        if str_len(ret_type) > 0 {
                            sb_append(sb, "-> ");
                            sb_append(sb, ret_type);
                            sb_append(sb, " ");
                        };
                        sb_append(sb, "{\n");
                        sb_append(sb, "    max_depth_enter(");
                        sb_append(sb, str_from_int(counter_id));
                        sb_append(sb, ", ");
                        sb_append(sb, str_from_int(md_value));
                        sb_append(sb, ");\n");
                        // when the rewritten fn is an impl method
                        // (first param is `self`), the wrapper must call
                        // the inner via method dispatch — `self.inner(rest)`
                        // — not free-fn dispatch `inner(self, rest)`. The
                        // inner declaration sits inside the same impl
                        // block, so it's resolved as an impl method.
                        // extends to the assoc-fn (no-self) form
                        // — the inner is registered as `Type::<inner>`,
                        // so the wrapper must emit `Type::<inner>(args)`.
                        // Detection: backward-scan from the #[max_depth]
                        // line position to find the enclosing
                        // `impl <Type> { ... }` (or `impl Trait for Type
                        // { ... }`). Empty enclosing-type means the fn is
                        // free, and the original free-fn dispatch shape
                        // is correct.
                        let mut is_impl_method: i64 = 0;
                        let mut rest_args: str = arg_names;
                        let an_len: i64 = str_len(arg_names);
                        if an_len >= 4 {
                            if str_eq_at(arg_names, 0, "self") == 1 {
                                if an_len == 4 {
                                    is_impl_method = 1;
                                    rest_args = "";
                                } else if str_char_at(arg_names, 4) == 44 {
                                    is_impl_method = 1;
                                    let mut rs: i64 = 5;
                                    while rs < an_len && (str_char_at(arg_names, rs) == 32 || str_char_at(arg_names, rs) == 9) { rs = rs + 1; };
                                    rest_args = str_substring(arg_names, rs, an_len);
                                };
                            };
                        };
                        let mut enclosing_type: str = "";
                        if is_impl_method == 0 {
                            enclosing_type = md_find_enclosing_impl_type(src, p);
                        };
                        if str_len(ret_type) > 0 && str_eq(ret_type, "void") == 0 {
                            sb_append(sb, "    let __nuc_md_r: ");
                            sb_append(sb, ret_type);
                            sb_append(sb, " = ");
                            if is_impl_method == 1 {
                                sb_append(sb, "self.");
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, rest_args);
                                sb_append(sb, ");\n");
                            } else if str_len(enclosing_type) > 0 {
                                sb_append(sb, enclosing_type);
                                sb_append(sb, "::");
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, arg_names);
                                sb_append(sb, ");\n");
                            } else {
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, arg_names);
                                sb_append(sb, ");\n");
                            };
                            sb_append(sb, "    max_depth_exit(");
                            sb_append(sb, str_from_int(counter_id));
                            sb_append(sb, ");\n");
                            sb_append(sb, "    return __nuc_md_r;\n");
                        } else {
                            sb_append(sb, "    ");
                            if is_impl_method == 1 {
                                sb_append(sb, "self.");
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, rest_args);
                                sb_append(sb, ");\n");
                            } else if str_len(enclosing_type) > 0 {
                                sb_append(sb, enclosing_type);
                                sb_append(sb, "::");
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, arg_names);
                                sb_append(sb, ");\n");
                            } else {
                                sb_append(sb, inner_name);
                                sb_append(sb, "(");
                                sb_append(sb, arg_names);
                                sb_append(sb, ");\n");
                            };
                            sb_append(sb, "    max_depth_exit(");
                            sb_append(sb, str_from_int(counter_id));
                            sb_append(sb, ");\n");
                        };
                        sb_append(sb, "}\n");
                        p = body_end;
                        continue;
                    };
                };
            };
        };
        sb_append(sb, str_substring(src, p, eol));
        if eol < slen { sb_append(sb, "\n"); };
        p = eol + 1;
    };
    return sb_to_str(sb);
}
// Resolver-level rewrite of two pieces of async syntax:
//   `async fn name(...)`  → `fn name(...)` (keyword strip)
//   `<ident>.await`        → `async_await(<ident>)`
// The runtime is committed to threads-only (RFC-0027 phase 1):
// `async_spawn(fn_ptr, arg)` returns an opaque task handle that
// runs the fn on a real OS thread; `async_await(handle)` joins
// the thread + returns the captured i64 result. No green-thread
// scheduler, no future polling — every async fn is a thread.
// `.await` is restricted to the simple `<ident>.await` form
// today. Complex receivers (`call().await`, `arr[0].await`)
// require a let-binding first. T2.8b will lift that restriction
// once we have a depth-aware backwards-receiver scanner.

#[manual_drop]
fn expand_async_strip_keyword(src: str) -> str {
    // Identifier-aware walk. When we find an `async` identifier
    // followed by whitespace and `fn`, we drop the `async` keyword
    // (and the whitespace between it and `fn`). Anywhere else,
    // `async` passes through as a regular identifier.
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
            let id_len: i64 = p - id_start;
            if id_len == 5 && str_eq_at(src, id_start, "async") == 1 {
                // defensive halt: canonical Rust `async { ... }`
                // block expression pre-fix surfaced as wrong-class
                // `error[TYP-005]: undefined function async()` because
                // expand_async_strip_keyword only handles `async fn`,
                // and parse_primary then treats `async` as a fn call.
                // Halt cleanly with a workaround pointer (drop the
                // `async` — Nucleor's runtime is single-threaded, the
                // block runs synchronously).
                let mut blk_peek: i64 = p;
                while blk_peek < slen && (str_char_at(src, blk_peek) == 32 || str_char_at(src, blk_peek) == 9 || str_char_at(src, blk_peek) == 10 || str_char_at(src, blk_peek) == 13) { blk_peek = blk_peek + 1; };
                if blk_peek < slen && str_char_at(src, blk_peek) == 123 {
                    print("ERROR: `async { ... }` block expression is not yet supported in Nucleor. Workaround: drop the `async` keyword — Nucleor's runtime is single-threaded by default, so the block already runs synchronously. For threaded execution use `async_spawn(fn_ptr, arg)` (RFC-0027 phase 1, see stdlib/rods/async.nr) which returns a handle.");
                    panic("nucleor: `async { ... }` block expression not yet supported (see ERROR diagnostic above)");
                };
                // Look ahead past whitespace for `fn`.
                let mut peek: i64 = p;
                while peek < slen && (str_char_at(src, peek) == 32 || str_char_at(src, peek) == 9) { peek = peek + 1; };
                if peek + 2 <= slen && str_eq_at(src, peek, "fn") == 1 {
                    let after_fn: i64 = peek + 2;
                    let next_after_fn: i64 = if after_fn < slen { str_char_at(src, after_fn) } else { 0 };
                    if next_after_fn == 32 || next_after_fn == 9 || next_after_fn == 10 {
                        // T3.8 (v0.3.7): RT-006 — async + RT attribute is
                        // rejected. Look back from `async` for a `#[no_alloc]`,
                        // `#[no_panic]`, `#[no_dyn]`, or `#[deadline...]`
                        // attribute on a preceding line (skipping blanks +
                        // doc comments). If found, emit a marker comment
                        // the diag pass picks up after expansion strips
                        // the `async` keyword for good.
                        let mut lb: i64 = id_start - 1;
                        let mut prev_attr_found: i64 = 0;
                        let mut stop: i64 = 0;
                        while lb >= 0 && stop == 0 && prev_attr_found == 0 {
                            let mut line_start: i64 = lb;
                            while line_start > 0 && str_char_at(src, line_start - 1) != 10 {
                                line_start = line_start - 1;
                            };
                            let line_end: i64 = lb + 1;
                            let line: str = str_substring(src, line_start, line_end);
                            let trimmed: str = strip_spaces(line);
                            let tlen: i64 = str_len(trimmed);
                            if tlen == 0 {
                                lb = line_start - 2;
                            } else if tlen >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                                lb = line_start - 2;
                            } else if str_eq(trimmed, "#[no_alloc]") == 1
                                  || str_eq(trimmed, "#[no_panic]") == 1
                                  || str_eq(trimmed, "#[no_dyn]") == 1 {
                                prev_attr_found = 1;
                            } else if tlen >= 11 && str_eq(str_substring(trimmed, 0, 11), "#[deadline ") == 1 {
                                prev_attr_found = 1;
                            } else if tlen >= 11 && str_eq(str_substring(trimmed, 0, 11), "#[deadline=") == 1 {
                                prev_attr_found = 1;
                            } else if tlen >= 1 && str_char_at(trimmed, 0) == 35 {
                                // Different #[...] attribute — keep looking.
                                lb = line_start - 2;
                            } else {
                                stop = 1;
                            };
                        };
                        // Read the fn name for the marker / diag.
                        let mut np: i64 = after_fn;
                        while np < slen && (str_char_at(src, np) == 32 || str_char_at(src, np) == 9) { np = np + 1; };
                        let nn_start: i64 = np;
                        while np < slen && (is_alnum(str_char_at(src, np)) == 1 || str_char_at(src, np) == 95) { np = np + 1; };
                        let async_fn_name: str = if np > nn_start { str_substring(src, nn_start, np) } else { "<unknown>" };
                        if prev_attr_found == 1 {
                            // RT-006 path: RT attribute + async → hard error.
                            // Prefix with `\n` so the marker always starts
                            // at column 0 — the diag scanner matches on the
                            // exact byte sequence "\n//__NUC6T:" which never
                            // appears mid-line in the s1 compiler source
                            // (the literal mentions in this file are either
                            // inside string literals or mid-line in prose).
                            sb_append(sb, "\n//__NUC6T:");
                            sb_append(sb, async_fn_name);
                            sb_append(sb, "\n");
                        } else {
                            // v0.5.19 closes probe finding
                            // 2026-05-01-async-keyword-silently-stripped.
                            // Plain `async fn foo()` (no RT attribute) was
                            // silently stripped pre-fix — adopter wrote the
                            // canonical Rust async pattern, the keyword
                            // dropped, the fn ran sync, no signal. Now we
                            // emit an ASYNC-001 warning marker that the
                            // scanner picks up post-strip. Marker shape
                            // mirrors RT-006's `//__NUC6T:` for symmetry.
                            // Note: the runtime DOES support threading via
                            // async_spawn / async_await (RFC-0027 phase 1) —
                            // the warning points adopters at that, rather
                            // than halting cleanly.
                            sb_append(sb, "\n//__NUC6X:");
                            sb_append(sb, async_fn_name);
                            sb_append(sb, "\n");
                        };
                        // Drop `async ` — emit nothing for the keyword
                        // and fast-forward past the trailing whitespace.
                        p = peek;
                        continue;
                    };
                };
                // Not `async fn` — keep `async` as a regular identifier.
                sb_append(sb, "async");
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
fn expand_async_await(src: str) -> str {
    // Walk identifier-aware. When we see `<ident>.await` (followed by
    // a non-ident-continuation char like ` `, `;`, `)`, etc.), rewrite
    // the chunk into `async_await(<ident>)`. Other `.await`s (`obj.x
    // .await`, `f().await`, etc.) pass through unchanged today —
    // T2.8b lifts the restriction.
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
            // Look ahead for `.await`.
            if p + 6 <= slen && str_eq_at(src, p, ".await") == 1 {
                // Confirm `await` isn't actually part of a longer ident.
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
fn expand_async_syntax(src: str) -> str {
    return expand_async_await(expand_async_strip_keyword(src));
}

// ===== T2.3 (v0.2.349): closure literals (no-capture) =====
// Source-level rewriting of `|args| body` closure expressions in
// argument position. Each closure is lifted into a synthesized
// top-level fn (`__closure_<hash>_<idx>`), prepended to the merged
// source, and the closure expression is replaced with a bare
// identifier reference to that fn. The Vec iterator helpers
// (T2.2 dispatch) then receive a function-pointer value through
// the existing i64-cell convention — no runtime change required.
// Scope: NO-CAPTURE closures only (the body must not reference
// any name that would be undefined at the top-level scope).
// Closures with captures land in T2.3b once the runtime gains
// `(fn_ptr, env_ptr)` pair-call support.
// Disambiguation from bitwise `|`: closures are recognized only
// when `|` appears in an expression-arg position — immediately
// preceded (after whitespace) by `(`, `,`, `=`, `=>`, `[`, or
// the start of source. A `|` between values (e.g. `a | b`) stays
// a bitwise op.

#[manual_drop]
fn close_is_arg_position_char(c: i64) -> i64 {
    // T2.1/2/3 partial close: textual closure-hoisting is
    // now FULLY DISABLED. Pre-v0.3.78, this preprocessor hoisted
    // closures appearing after `(` or `,` into top-level fns, which
    // produced cryptic `@captured` link errors when the closure body
    // referenced any outer-scope variables (the textual layer has
    // no scope info to detect captures).
    // The AST closure-literal path (kind 42 in lower_expr at line
    // ~9915) handles captures correctly via the v0.3.72 capture_set/
    // capture_get runtime infrastructure. Routing arg-position
    // closures through the AST path makes `v.map(|x| x * factor)`
    // work the same way as `let f = |x| x * factor; v.map(f)` —
    // the documented v1 boundary closes.
    // The legacy comment about "indirect-call dispatch" no longer
    // applies — the AST kind 42 path correctly emits ir_fn_ptr +
    // capture_set sequence, which works in arg position because
    // kind 8 (trait method call) lowers each arg via lower_expr,
    // and lower_expr handles kind 42 by returning the fn pointer
    // register with capture_set already emitted into the current
    // block.
    return 0;
}

#[manual_drop]
fn close_parse_arg_list(src: str, start: i64, slen: i64) -> Vec<i32> {
    // Parses `<ident>(, <ident>)*` from start. Returns
    // [end_pos_at_closing_pipe_plus_1, name1, name2, ...].
    // Returns [0 - 1] on parse error.
    let mut out: Vec<i32> = Vec::new();
    out.push(0 - 1);
    let mut p: i64 = start;
    let mut first: i64 = 1;
    while p < slen && str_char_at(src, p) != 124 {
        // skip whitespace
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
            // Optional `: type` annotation — skip over it.
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
fn close_parse_body_end(src: str, start: i64, slen: i64) -> i64 {
    // Walk forward from start. Body ends at the first `,` or `)`
    // or `]` at the same paren/bracket depth as where we started.
    // String/char literals and line comments don't count.
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

#[manual_drop]
fn expand_closures(src: str) -> str {
    return src;
    let mut prepend: i64 = sb_new();
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut last_non_ws: i64 = 0;
    let mut idx: i64 = 0;
    let src_id: str = content_hash(src);
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 {
                sb_append_char_at(sb, src, p);
                p = p + 1;
            };
            last_non_ws = 10;
        } else if c == 34 {
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
            last_non_ws = 34;
        } else if c == 39 {
            sb_append(sb, "'");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "'"); p = p + 1; };
            last_non_ws = 39;
        } else if c == 124 && close_is_arg_position_char(last_non_ws) == 1 {
            // Possible closure. Parse args between `|...|`.
            let arg_parse: Vec<i32> = close_parse_arg_list(src, p + 1, slen);
            let after_args: i64 = vec_get(arg_parse, 0);
            if after_args >= 0 {
                let mut args: Vec<i32> = Vec::new();
                let mut ai: i64 = 1;
                while ai < vec_len(arg_parse) {
                    args.push(vec_get(arg_parse, ai));
                    ai = ai + 1;
                };
                // Skip whitespace before body
                let mut bp: i64 = after_args;
                while bp < slen && (str_char_at(src, bp) == 32 || str_char_at(src, bp) == 9) { bp = bp + 1; };
                let body_end: i64 = close_parse_body_end(src, bp, slen);
                let body_text: str = str_substring(src, bp, body_end);
                // Synthesize fn name + emit
                let synth_name: str = str_concat("__closure_", str_concat(src_id, str_concat("_", str_from_int(idx))));
                idx = idx + 1;
                sb_append(prepend, close_synthesize_fn(synth_name, args, body_text));
                sb_append(sb, synth_name);
                p = body_end;
                last_non_ws = if p > 0 { str_char_at(src, p - 1) } else { 0 };
                continue;
            };
            // Not a closure — emit `|` as-is.
            sb_append(sb, "|");
            p = p + 1;
            last_non_ws = 124;
        } else if is_alpha(c) == 1 || c == 95 {
            let id_start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let name: str = str_substring(src, id_start, p);
            sb_append(sb, name);
            last_non_ws = str_char_at(name, str_len(name) - 1);
        } else {
            sb_append_char_at(sb, src, p);
            if c != 32 && c != 9 && c != 10 && c != 13 { last_non_ws = c; };
            p = p + 1;
        };
    };
    return str_concat(sb_to_str(prepend), sb_to_str(sb));
}

// ===== T2.6 (v0.2.346): format-string macro expansion =====
// Source-level rewriting of `println!(fmt, args...)`,
// `print!(fmt, args...)`, and `format!(fmt, args...)` calls into
// the equivalent str_concat + print/print_raw expression chain.
// Runs in the resolver, AFTER all imports are inlined and BEFORE
// the source is cached / lexed.
// Format spec syntax:
//   {}    — int_to_str(arg)   (default; the most common case)
//   {:i}  — int_to_str(arg)   (explicit alias)
//   {:s}  — arg as-is         (caller-provided str)
//   {:f}  — f64_to_str(arg)
//   {:b}  — bool_to_str(arg)
//   {{ }} — literal `{` / `}` (Rust convention)
// Modes:
//   println!  — wraps result in `print(...)`  (adds trailing \n via runtime)
//   print!    — wraps result in `print_raw(...)` (no trailing \n)
//   format!   — bare expression, returns str
// The expander is identifier- and quote-aware: skips `// ...`
// line comments, `"..."` string literals, and `'X'` char literals.
// `name!` after a `.` (method call) is left alone.

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
fn fmt_split_args(args_text: str) -> Vec<i32> {
    // Depth-aware comma split: respects (), [], {}, "...", '...'
    // so commas inside nested calls / strings don't split args.
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
fn fmt_strip_outer_quotes(s: str) -> str {
    let slen: i64 = str_len(s);
    if slen < 2 { return s; };
    if str_char_at(s, 0) != 34 { return s; };
    if str_char_at(s, slen - 1) != 34 { return s; };
    return str_substring(s, 1, slen - 1);
}

// helper for the bare-`{}` heuristic. Scan src for ALL
// `let <name>: TYPE` and `let mut <name>: TYPE` declarations and
// return TYPE only if every declaration of <name> agrees. If the
// same name has conflicting types (e.g. `let x: str` in one fn and
// `let x: i64` in another), return "" so the heuristic falls back
// to the default int_to_str.
// Conservative-by-construction: if there's any ambiguity, do nothing.
// Worst case the adopter sees the original int-as-pointer output and
// switches to explicit `:s` / `:f` -- still a hazard but a less harmful
// one than the v0.3.152-rev1 bug where the scan picked the WRONG
// declaration and crashed (SIGSEGV when an i64 was passed to print_str).
// Also requires the matched `let` to be followed by a TYPE (not
// elision via `let x = ...;` without a type annotation) so we never
// invent a type out of thin air.
// pattern-binding type inference for user-defined enum
// variants (the existing infer_pattern_binding_type_from_source
// only handles built-in Some/Ok/Err). Scans source for arms of
// the form `<EnumName>::<VariantName>(<binding>, ...)` and locates
// `<binding>` by index. Looks up the variant's payload-i type via
// infer_enum_variant_payload_type. Conflict-detects across all
// occurrences of the same binding name.
// Conservative-by-construction: the variant-name pattern requires
// EnumName and VariantName both to start with uppercase letters,
// avoiding false-positive match on lowercase fn calls (e.g., a
// function call `foo(s, n)` is NOT misread as a variant pattern).
#[manual_drop]
fn infer_user_variant_binding_type(src: str, var_name: str) -> str {
    let slen: i64 = str_len(src);
    let vlen: i64 = str_len(var_name);
    if vlen == 0 || slen < 8 { return ""; };
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    // bound the scan to the last 256 KB. The bundled
    // source has stdlib PREpended (~700 KB+), then user code at the
    // tail. format-macro args reference user-code declarations 99%
    // of the time; full-source scan was 1.6 BILLION str_char_at
    // calls per compile (cold +1.4s vs v0.4.17). Bounded scan reduces
    // that proportionally without changing observed correctness for
    // any adopter pattern.
    let mut i: i64 = if slen > 262144 { slen - 262144 } else { 0 };
    // Scan for `::<UpperVariant>(` -- the `::` anchors the user-variant
    // shape, eliminating most false positives (function-call form
    // `foo(...)` doesn't have `::`).
    while i + 4 < slen {
        if str_char_at(src, i) == 58 && str_char_at(src, i + 1) == 58 {
            // Walk back to find the EnumName (uppercase ident).
            let mut en_end: i64 = i;
            let mut en_start: i64 = i;
            let mut walked: i64 = 0;
            while en_start > 0 && walked < 64 {
                let c: i64 = str_char_at(src, en_start - 1);
                let id_cont: i64 = if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95 { 1 } else { 0 };
                if id_cont == 0 { walked = 64; }
                else { en_start = en_start - 1; walked = walked + 1; };
            };
            if en_start < en_end {
                let first_ch: i64 = str_char_at(src, en_start);
                if first_ch >= 65 && first_ch <= 90 {
                    // Read VariantName after `::`.
                    let mut vp: i64 = i + 2;
                    let var_start: i64 = vp;
                    let mut keep_v: i64 = 1;
                    while keep_v == 1 && vp < slen {
                        let c2: i64 = str_char_at(src, vp);
                        let id_cont2: i64 = if (c2 >= 65 && c2 <= 90) || (c2 >= 97 && c2 <= 122) || (c2 >= 48 && c2 <= 57) || c2 == 95 { 1 } else { 0 };
                        if id_cont2 == 1 { vp = vp + 1; } else { keep_v = 0; };
                    };
                    let var_end: i64 = vp;
                    if var_end > var_start {
                        let v_first: i64 = str_char_at(src, var_start);
                        if v_first >= 65 && v_first <= 90 && vp < slen && str_char_at(src, vp) == 40 {
                            // Parse binding list inside `(...)` and find var_name by index.
                            let enum_name: str = str_substring(src, en_start, en_end);
                            let variant_name: str = str_substring(src, var_start, var_end);
                            let mut bp: i64 = vp + 1;
                            let mut bind_idx: i64 = 0;
                            let mut depth_b: i64 = 0;
                            let mut bind_start: i64 = bp;
                            let mut hit_idx: i64 = 0 - 1;
                            while bp < slen {
                                let bc: i64 = str_char_at(src, bp);
                                if bc == 40 || bc == 60 { depth_b = depth_b + 1; }
                                else if bc == 62 { depth_b = depth_b - 1; }
                                else if (bc == 41 || bc == 44) && depth_b == 0 {
                                    let mut bs2: i64 = bind_start;
                                    while bs2 < bp && str_char_at(src, bs2) == 32 { bs2 = bs2 + 1; };
                                    let mut be2: i64 = bp;
                                    while be2 > bs2 && str_char_at(src, be2 - 1) == 32 { be2 = be2 - 1; };
                                    let cur_name: str = str_substring(src, bs2, be2);
                                    if str_eq(cur_name, var_name) == 1 { hit_idx = bind_idx; bp = slen; };
                                    if bc == 41 { bp = slen; }
                                    else { bind_idx = bind_idx + 1; bind_start = bp + 1; };
                                };
                                bp = bp + 1;
                            };
                            if hit_idx >= 0 {
                                let candidate: str = infer_enum_variant_payload_type(src, enum_name, variant_name, hit_idx);
                                if str_len(candidate) > 0 {
                                    if str_len(found_type) == 0 { found_type = candidate; }
                                    else { if str_eq(found_type, candidate) == 0 { conflict = 1; }; };
                                };
                            };
                        };
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    return found_type;
}

// parse user-defined enum variant payload type from source.
// For `pub enum MyErr { ... BadInput(str, i64), ... }`, returns the
// idx-th payload type ("str" for idx=0, "i64" for idx=1). Returns ""
// if not found. Conflict-detects across multiple enum decls with
// the same name (rare but possible across imports).
#[manual_drop]
fn infer_enum_variant_payload_type(src: str, enum_name: str, variant_name: str, idx: i64) -> str {
    let slen: i64 = str_len(src);
    let enlen: i64 = str_len(enum_name);
    let vnlen: i64 = str_len(variant_name);
    if enlen == 0 || vnlen == 0 { return ""; };
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    // bound to last 256 KB (user-code region). User
    // enum declarations live in user code; stdlib doesn't define
    // adopter-shape enums.
    let mut i: i64 = if slen > 262144 { slen - 262144 } else { 0 };
    while i + 5 < slen {
        // "enum " = 'e','n','u','m',' ' = 101,110,117,109,32
        if str_char_at(src, i) == 101
            && str_char_at(src, i + 1) == 110
            && str_char_at(src, i + 2) == 117
            && str_char_at(src, i + 3) == 109
            && str_char_at(src, i + 4) == 32 {
            let mut bdry_ok: i64 = 1;
            if i > 0 {
                let pc: i64 = str_char_at(src, i - 1);
                if (pc >= 65 && pc <= 90) || (pc >= 97 && pc <= 122) || (pc >= 48 && pc <= 57) || pc == 95 { bdry_ok = 0; };
            };
            if bdry_ok == 1 {
                let mut p: i64 = i + 5;
                let mut k: i64 = 0;
                let mut nm_ok: i64 = 1;
                while k < enlen {
                    if p + k >= slen { nm_ok = 0; k = enlen; }
                    else if str_char_at(src, p + k) != str_char_at(enum_name, k) { nm_ok = 0; k = enlen; };
                    k = k + 1;
                };
                if nm_ok == 1 {
                    let after: i64 = p + enlen;
                    if after < slen {
                        let nc: i64 = str_char_at(src, after);
                        let id_cont: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                        if id_cont == 0 {
                            // Skip ws + optional generics + ws, expect `{`.
                            let mut q: i64 = after;
                            while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                            if q < slen && str_char_at(src, q) == 60 {
                                let mut gd: i64 = 1; q = q + 1;
                                while q < slen && gd > 0 {
                                    let gc: i64 = str_char_at(src, q);
                                    if gc == 60 { gd = gd + 1; } else { if gc == 62 { gd = gd - 1; }; };
                                    q = q + 1;
                                };
                                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                            };
                            if q < slen && str_char_at(src, q) == 123 {
                                q = q + 1;
                                let body_start: i64 = q;
                                let mut bdepth: i64 = 1;
                                while q < slen && bdepth > 0 {
                                    let bc: i64 = str_char_at(src, q);
                                    if bc == 123 { bdepth = bdepth + 1; }
                                    else { if bc == 125 { bdepth = bdepth - 1; }; };
                                    if bdepth > 0 { q = q + 1; };
                                };
                                let body_end: i64 = q;
                                // Scan body for `<variant_name>(...)` token.
                                let mut bp: i64 = body_start;
                                while bp + vnlen < body_end {
                                    let prev_c: i64 = if bp == 0 { 32 } else { str_char_at(src, bp - 1) };
                                    let prev_ok: i64 = if prev_c == 32 || prev_c == 9 || prev_c == 10 || prev_c == 13 || prev_c == 44 || prev_c == 123 { 1 } else { 0 };
                                    if prev_ok == 1 {
                                        let mut vmatched: i64 = 1;
                                        let mut vk: i64 = 0;
                                        while vk < vnlen {
                                            if bp + vk >= body_end { vmatched = 0; vk = vnlen; }
                                            else if str_char_at(src, bp + vk) != str_char_at(variant_name, vk) { vmatched = 0; vk = vnlen; };
                                            vk = vk + 1;
                                        };
                                        if vmatched == 1 {
                                            let after_v: i64 = bp + vnlen;
                                            if after_v < body_end && str_char_at(src, after_v) == 40 {
                                                // Parse comma-separated payload types until `)`.
                                                let mut pp: i64 = after_v + 1;
                                                let mut payload_idx: i64 = 0;
                                                let mut payload_start: i64 = pp;
                                                let mut depth_p: i64 = 0;
                                                let mut found_this: str = "";
                                                while pp < body_end {
                                                    let pc2: i64 = str_char_at(src, pp);
                                                    if pc2 == 60 || pc2 == 40 { depth_p = depth_p + 1; }
                                                    else if pc2 == 62 { depth_p = depth_p - 1; }
                                                    else if pc2 == 41 && depth_p == 0 {
                                                        if payload_idx == idx {
                                                            let mut ps2: i64 = payload_start;
                                                            while ps2 < pp && str_char_at(src, ps2) == 32 { ps2 = ps2 + 1; };
                                                            let mut pe2: i64 = pp;
                                                            while pe2 > ps2 && str_char_at(src, pe2 - 1) == 32 { pe2 = pe2 - 1; };
                                                            found_this = type_base_name(str_substring(src, ps2, pe2));
                                                        };
                                                        pp = body_end;
                                                    }
                                                    else if pc2 == 44 && depth_p == 0 {
                                                        if payload_idx == idx {
                                                            let mut ps2: i64 = payload_start;
                                                            while ps2 < pp && str_char_at(src, ps2) == 32 { ps2 = ps2 + 1; };
                                                            let mut pe2: i64 = pp;
                                                            while pe2 > ps2 && str_char_at(src, pe2 - 1) == 32 { pe2 = pe2 - 1; };
                                                            found_this = type_base_name(str_substring(src, ps2, pe2));
                                                            pp = body_end;
                                                        };
                                                        payload_idx = payload_idx + 1;
                                                        payload_start = pp + 1;
                                                    };
                                                    pp = pp + 1;
                                                };
                                                if str_len(found_this) > 0 {
                                                    if str_len(found_type) == 0 { found_type = found_this; }
                                                    else { if str_eq(found_type, found_this) == 0 { conflict = 1; }; };
                                                };
                                                bp = body_end;
                                            };
                                        };
                                    };
                                    bp = bp + 1;
                                };
                            };
                        };
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    return found_type;
}

// bounded backward `let <name>: T = ...` scanner. When
// the source bundle has many `let <name>: T` declarations across
// imports, the global infer_var_type_from_source returns "" on
// conflict. This bounded variant scans BACKWARD from `match_pos`
// to find the most-recent `let <name>: T` -- the closest scope-
// local declaration, which is what shadowing semantics actually
// resolve to. Limited to ~2 KB scan back.
#[manual_drop]
fn infer_var_type_local_back(src: str, var_name: str, match_pos: i64) -> str {
    let slen: i64 = str_len(src);
    let vlen: i64 = str_len(var_name);
    if vlen == 0 || match_pos <= 4 { return ""; };
    // tighter bound, was 4 KB. 1 KB is enough for nearly
    // all match scrutinee declarations (let X: T = ...; match X { ... }).
    let scan_back_limit: i64 = if match_pos > 1024 { match_pos - 1024 } else { 0 };
    let mut j: i64 = match_pos - 1;
    while j >= scan_back_limit {
        // Look for "let " at j (with optional "let mut ").
        if j + 3 < slen
            && str_char_at(src, j) == 108
            && str_char_at(src, j + 1) == 101
            && str_char_at(src, j + 2) == 116
            && str_char_at(src, j + 3) == 32 {
            // Boundary: char before `let` must not be id-continue.
            let mut bdry_ok: i64 = 1;
            if j > 0 {
                let bpc: i64 = str_char_at(src, j - 1);
                if (bpc >= 65 && bpc <= 90) || (bpc >= 97 && bpc <= 122) || (bpc >= 48 && bpc <= 57) || bpc == 95 { bdry_ok = 0; };
            };
            if bdry_ok == 1 {
                let mut p: i64 = j + 4;
                // Optional "mut ".
                if p + 4 <= slen
                    && str_char_at(src, p) == 109
                    && str_char_at(src, p + 1) == 117
                    && str_char_at(src, p + 2) == 116
                    && str_char_at(src, p + 3) == 32 {
                    p = p + 4;
                };
                // Match var_name.
                let mut k: i64 = 0;
                let mut nm_ok: i64 = 1;
                while k < vlen {
                    if p + k >= slen { nm_ok = 0; k = vlen; }
                    else if str_char_at(src, p + k) != str_char_at(var_name, k) { nm_ok = 0; k = vlen; };
                    k = k + 1;
                };
                if nm_ok == 1 {
                    let after: i64 = p + vlen;
                    if after < slen {
                        let nc: i64 = str_char_at(src, after);
                        let id_cont: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                        if id_cont == 0 {
                            // Skip whitespace; expect ":".
                            let mut q: i64 = after;
                            while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                            if q < slen && str_char_at(src, q) == 58 {
                                q = q + 1;
                                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                                let ts: i64 = q;
                                let mut gd: i64 = 0;
                                while q < slen {
                                    let tc: i64 = str_char_at(src, q);
                                    if tc == 60 { gd = gd + 1; }
                                    else if tc == 62 { gd = gd - 1; };
                                    if gd == 0 && (tc == 32 || tc == 61 || tc == 59 || tc == 10 || tc == 13) {
                                        return str_substring(src, ts, q);
                                    };
                                    q = q + 1;
                                };
                            };
                        };
                    };
                };
            };
        };
        j = j - 1;
    };
    return "";
}

// companion to infer_var_type_from_source. Scans src for
// match-arm pattern bindings of the form `Some(<var_name>)`,
// `Ok(<var_name>)`, `Err(<var_name>)`. When found, walks back to
// the enclosing `match <scrutinee>`, infers the scrutinee's type
// via infer_var_type_from_source, and extracts the generic parameter
// (T from Option<T>, T from Result<T, E> for Ok, E for Err).
// Returns "" if no match or the scrutinee type isn't recognized.
// This closes the println!/format! gap for typed Option/Result
// payload bindings: `match x { Some(s) => println!("{}", s) }`
// where `x: Option<str>` previously printed the raw pointer
// integer because the source-scanner couldn't find `let s: T = ...`
// (s is bound by a pattern, not a let). The non-macro path
// (let-assign / str_eq / field access) was closed in v0.4.4.
#[manual_drop]
fn infer_pattern_binding_type_from_source(src: str, var_name: str) -> str {
    let slen: i64 = str_len(src);
    let vlen: i64 = str_len(var_name);
    if vlen == 0 || slen < 8 { return ""; };
    // scan ALL occurrences and conflict-detect. If the same
    // binding name appears in multiple match arms with different
    // scrutinee types, return "" -- safer than picking the first one
    // (which previously miscompiled `Some(v)` for both Option<i64>
    // and Option<f64> when `v` was reused). Adopters with the same-
    // name-multi-arm shape see the conservative int_to_str default,
    // not a wrong-type guess.
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    // Look for occurrences of "Some(<var_name>)" / "Ok(<var_name>)"
    // / "Err(<var_name>)". Identifier-aware: char before the first
    // letter must not be alpha/digit/underscore, and the closing `)`
    // must immediately follow var_name (no extra args).
    // bound to last 256 KB (user code region). Pattern
    // bindings live in user match arms; stdlib doesn't define them
    // in adopter-shape ways. 4x faster scan, no observed-correctness
    // change.
    let mut i: i64 = if slen > 262144 { slen - 262144 } else { 0 };
    while i + 6 < slen {
        let mut variant_len: i64 = 0;
        let mut variant: str = "";
        // "Some(" = 83,111,109,101,40
        if str_char_at(src, i) == 83 && str_char_at(src, i+1) == 111 && str_char_at(src, i+2) == 109 && str_char_at(src, i+3) == 101 && str_char_at(src, i+4) == 40 {
            variant = "Some"; variant_len = 5;
        };
        // "Ok(" = 79,107,40
        if variant_len == 0 && i + 3 < slen && str_char_at(src, i) == 79 && str_char_at(src, i+1) == 107 && str_char_at(src, i+2) == 40 {
            variant = "Ok"; variant_len = 3;
        };
        // "Err(" = 69,114,114,40
        if variant_len == 0 && i + 4 < slen && str_char_at(src, i) == 69 && str_char_at(src, i+1) == 114 && str_char_at(src, i+2) == 114 && str_char_at(src, i+3) == 40 {
            variant = "Err"; variant_len = 4;
        };
        if variant_len > 0 {
            // Boundary check: char before `Some/Ok/Err` must not be id-continue.
            let mut bdry_ok: i64 = 1;
            if i > 0 {
                let pc: i64 = str_char_at(src, i - 1);
                if (pc >= 65 && pc <= 90) || (pc >= 97 && pc <= 122) || (pc >= 48 && pc <= 57) || pc == 95 { bdry_ok = 0; };
            };
            if bdry_ok == 1 {
                let p: i64 = i + variant_len;
                // Match var_name immediately after `(`
                let mut k: i64 = 0;
                let mut nm_match: i64 = 1;
                while k < vlen {
                    if p + k >= slen || str_char_at(src, p + k) != str_char_at(var_name, k) { nm_match = 0; k = vlen; };
                    k = k + 1;
                };
                if nm_match == 1 {
                    // Must be followed immediately by `)` (so we know we
                    // matched the whole binding name, not a prefix of a
                    // longer one or a multi-arg pattern).
                    let after: i64 = p + vlen;
                    if after < slen && str_char_at(src, after) == 41 {
                        // Walk back to find the enclosing `match <expr> {`.
                        // Look for "match " keyword. This is a heuristic
                        // limited-by-design: if the source structure is
                        // weird (commented match, nested matches), we may
                        // pick the wrong scrutinee. False positives here
                        // produce a wrong type guess; the failure mode is
                        // a wrong format helper which prints differently
                        // than expected. Conservative bound: scan back
                        // at most 2KB; if no `match ` found, give up.
                        let scan_back_limit: i64 = if i > 2048 { i - 2048 } else { 0 };
                        let mut j: i64 = i - 1;
                        let mut match_at: i64 = 0 - 1;
                        while j >= scan_back_limit {
                            // "match " = 109,97,116,99,104,32
                            if j + 5 < slen && str_char_at(src, j) == 109 && str_char_at(src, j+1) == 97 && str_char_at(src, j+2) == 116 && str_char_at(src, j+3) == 99 && str_char_at(src, j+4) == 104 && str_char_at(src, j+5) == 32 {
                                // Boundary: char before `match` must not be id-continue.
                                let mut mb_ok: i64 = 1;
                                if j > 0 {
                                    let mpc: i64 = str_char_at(src, j - 1);
                                    if (mpc >= 65 && mpc <= 90) || (mpc >= 97 && mpc <= 122) || (mpc >= 48 && mpc <= 57) || mpc == 95 { mb_ok = 0; };
                                };
                                if mb_ok == 1 { match_at = j; j = scan_back_limit - 1; };
                            };
                            j = j - 1;
                        };
                        if match_at >= 0 {
                            // Read the scrutinee identifier after "match ".
                            let mut sp: i64 = match_at + 6;
                            // Skip whitespace.
                            while sp < slen && str_char_at(src, sp) == 32 { sp = sp + 1; };
                            // Read identifier (letters / digits / `_`). Field-access
                            // scrutinees (`x.alias`) are not handled in v1 -- bail.
                            let scrut_start: i64 = sp;
                            let mut scrut_end: i64 = sp;
                            let mut keep_scan: i64 = 1;
                            while keep_scan == 1 && scrut_end < slen {
                                let sc: i64 = str_char_at(src, scrut_end);
                                let id_cont: i64 = if (sc >= 65 && sc <= 90) || (sc >= 97 && sc <= 122) || (sc >= 48 && sc <= 57) || sc == 95 { 1 } else { 0 };
                                if id_cont == 1 { scrut_end = scrut_end + 1; }
                                else { keep_scan = 0; };
                            };
                            if scrut_end > scrut_start {
                                let scrut_name: str = str_substring(src, scrut_start, scrut_end);
                                // If next non-space char is `.`, this is field access -- bail
                                // (v1 doesn't handle struct-field scrutinees).
                                let mut tp: i64 = scrut_end;
                                while tp < slen && str_char_at(src, tp) == 32 { tp = tp + 1; };
                                // handle field-access scrutinee
                                // (`match s.gap_report { Some(g) => ... }`).
                                // Look up s's struct type, then walk the
                                // struct's field declarations to find
                                // gap_report's declared type. Single-level
                                // field access only (.a.b chains are deeper
                                // structural work; defer).
                                let mut scrut_full_type: str = "";
                                if tp < slen && str_char_at(src, tp) == 46 {
                                    let fp_start: i64 = tp + 1;
                                    let mut fp_end: i64 = fp_start;
                                    let mut fp_keep: i64 = 1;
                                    while fp_keep == 1 && fp_end < slen {
                                        let fc: i64 = str_char_at(src, fp_end);
                                        let fc_ok: i64 = if (fc >= 65 && fc <= 90) || (fc >= 97 && fc <= 122) || (fc >= 48 && fc <= 57) || fc == 95 { 1 } else { 0 };
                                        if fc_ok == 1 { fp_end = fp_end + 1; }
                                        else { fp_keep = 0; };
                                    };
                                    if fp_end > fp_start {
                                        let field_name: str = str_substring(src, fp_start, fp_end);
                                        // If next is another `.`, bail
                                        // (multi-level chain).
                                        let mut tp2: i64 = fp_end;
                                        while tp2 < slen && str_char_at(src, tp2) == 32 { tp2 = tp2 + 1; };
                                        if tp2 < slen && str_char_at(src, tp2) == 46 { return ""; };
                                        // try the bounded backward
                                        // scan first (handles common-name
                                        // conflicts in big bundles), then
                                        // fall back to global scan.
                                        let mut struct_full: str = infer_var_type_local_back(src, scrut_name, match_at);
                                        if str_len(struct_full) == 0 {
                                            struct_full = infer_var_type_from_source(src, scrut_name);
                                        };
                                        let struct_name: str = type_base_name(struct_full);
                                        if str_len(struct_name) > 0 {
                                            scrut_full_type = infer_struct_field_type_from_source(src, struct_name, field_name);
                                        };
                                    };
                                } else {
                                    // same bounded-then-global chain.
                                    scrut_full_type = infer_var_type_local_back(src, scrut_name, match_at);
                                    if str_len(scrut_full_type) == 0 {
                                        scrut_full_type = infer_var_type_from_source(src, scrut_name);
                                    };
                                };
                                if str_len(scrut_full_type) > 0 {
                                    // Extract generic parameter T from Option<T>
                                    // / Result<T, E>. We just want the FIRST type
                                    // parameter for Some/Ok, the SECOND for Err.
                                    let stl: i64 = str_len(scrut_full_type);
                                    let mut lt_at: i64 = 0 - 1;
                                    let mut sj: i64 = 0;
                                    while sj < stl {
                                        if str_char_at(scrut_full_type, sj) == 60 { lt_at = sj; sj = stl; };
                                        sj = sj + 1;
                                    };
                                    if lt_at >= 0 {
                                        let base: str = str_substring(scrut_full_type, 0, lt_at);
                                        let inside_start: i64 = lt_at + 1;
                                        let inside_end: i64 = if str_char_at(scrut_full_type, stl - 1) == 62 { stl - 1 } else { stl };
                                        let inside: str = str_substring(scrut_full_type, inside_start, inside_end);
                                        let mut candidate: str = "";
                                        if str_eq(base, "Option") == 1 && str_eq(variant, "Some") == 1 {
                                            candidate = type_base_name(inside);
                                        };
                                        if str_eq(base, "Result") == 1 {
                                            // Split inside on `,` to get T and E.
                                            let inlen: i64 = str_len(inside);
                                            let mut comma_at: i64 = 0 - 1;
                                            let mut depth_lt: i64 = 0;
                                            let mut ck: i64 = 0;
                                            while ck < inlen {
                                                let cc: i64 = str_char_at(inside, ck);
                                                if cc == 60 { depth_lt = depth_lt + 1; };
                                                if cc == 62 { depth_lt = depth_lt - 1; };
                                                if cc == 44 && depth_lt == 0 { comma_at = ck; ck = inlen; };
                                                ck = ck + 1;
                                            };
                                            if comma_at > 0 {
                                                let t_part_raw: str = str_substring(inside, 0, comma_at);
                                                let mut e_start: i64 = comma_at + 1;
                                                while e_start < inlen && str_char_at(inside, e_start) == 32 { e_start = e_start + 1; };
                                                let e_part_raw: str = str_substring(inside, e_start, inlen);
                                                if str_eq(variant, "Ok") == 1 { candidate = type_base_name(t_part_raw); };
                                                if str_eq(variant, "Err") == 1 { candidate = type_base_name(e_part_raw); };
                                            } else {
                                                if str_eq(variant, "Ok") == 1 { candidate = type_base_name(inside); };
                                            };
                                        };
                                        if str_len(candidate) > 0 {
                                            if str_len(found_type) == 0 { found_type = candidate; }
                                            else { if str_eq(found_type, candidate) == 0 { conflict = 1; }; };
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    return found_type;
}

// companion to infer_var_type_from_source. Scans src for
// `fn <name>(...) -> TYPE` declarations and returns TYPE if every
// matching fn agrees. Same conflict-detection as the var version.
// Used by fmt_conversion_for_spec when arg_expr looks like a fn call
// (`<ident>(...)` shape) to dispatch the format type. Catches
// `println!("{}", make_str())` returning the pointer address pre-fix.
#[manual_drop]
fn infer_fn_return_type_from_source(src: str, fn_name: str) -> str {
    // same cached short-circuit as infer_var_type_from_source.
    let cached: str = infer_fn_return_type_cached(src, fn_name);
    if str_len(cached) > 0 { return cached; };
    let slen: i64 = str_len(src);
    let fnlen: i64 = str_len(fn_name);
    if fnlen == 0 { return ""; };
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    let mut i: i64 = 0;
    while i + 3 < slen {
        // "fn " = 'f','n',' ' = 102,110,32
        if str_char_at(src, i) == 102
            && str_char_at(src, i + 1) == 110
            && str_char_at(src, i + 2) == 32 {
            let mut p: i64 = i + 3;
            // Try to match fn_name
            let mut k: i64 = 0;
            let mut matched: i64 = 1;
            while k < fnlen {
                if p + k >= slen { matched = 0; k = fnlen; }
                else if str_char_at(src, p + k) != str_char_at(fn_name, k) { matched = 0; k = fnlen; };
                k = k + 1;
            };
            // Identifier boundary: char after fn_name must not be alpha/digit/underscore
            if matched == 1 {
                let after: i64 = p + fnlen;
                if after < slen {
                    let nc: i64 = str_char_at(src, after);
                    let is_id_continue: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                    if is_id_continue == 1 { matched = 0; };
                };
            };
            if matched == 1 {
                let after2: i64 = p + fnlen;
                let mut q: i64 = after2;
                // Skip whitespace then expect `(`
                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                if q < slen && str_char_at(src, q) == 40 {
                    // Find matching `)` by depth
                    let mut depth: i64 = 1;
                    q = q + 1;
                    while q < slen && depth > 0 {
                        let dc: i64 = str_char_at(src, q);
                        if dc == 40 { depth = depth + 1; }
                        else if dc == 41 { depth = depth - 1; };
                        q = q + 1;
                    };
                    // Now look for ` -> TYPE`
                    while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                    if q + 1 < slen && str_char_at(src, q) == 45 && str_char_at(src, q + 1) == 62 {
                        q = q + 2;
                        while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                        let ts: i64 = q;
                        while q < slen {
                            let tc: i64 = str_char_at(src, q);
                            if tc == 32 || tc == 123 || tc == 59 || tc == 60 || tc == 10 || tc == 13 {
                                let this_type: str = str_substring(src, ts, q);
                                if str_len(found_type) == 0 {
                                    found_type = this_type;
                                } else {
                                    if str_eq(found_type, this_type) == 0 {
                                        conflict = 1;
                                    };
                                };
                                q = slen;
                            };
                            q = q + 1;
                        };
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    return found_type;
}

#[manual_drop]
fn infer_var_type_from_source(src: str, var_name: str) -> str {
    // short-circuit to runtime cache. Pre-fix this
    // function re-walked the entire source for every println!/format
    // arg -- 1.26B str_char_at calls per compiler self-build. Cached
    // lookup is O(1) average; the cache is built once per source ptr.
    let cached: str = infer_var_type_cached(src, var_name);
    if str_len(cached) > 0 { return cached; };
    let slen: i64 = str_len(src);
    let vlen: i64 = str_len(var_name);
    if vlen == 0 { return ""; };
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    let mut i: i64 = 0;
    while i + 4 < slen {
        // "let " = 'l','e','t',' ' = 108,101,116,32
        if str_char_at(src, i) == 108
            && str_char_at(src, i + 1) == 101
            && str_char_at(src, i + 2) == 116
            && str_char_at(src, i + 3) == 32 {
            let mut p: i64 = i + 4;
            // Skip optional "mut "
            if p + 4 < slen
                && str_char_at(src, p) == 109
                && str_char_at(src, p + 1) == 117
                && str_char_at(src, p + 2) == 116
                && str_char_at(src, p + 3) == 32 {
                p = p + 4;
            };
            // Try to match var_name
            let mut k: i64 = 0;
            let mut matched: i64 = 1;
            while k < vlen {
                if p + k >= slen { matched = 0; k = vlen; }
                else if str_char_at(src, p + k) != str_char_at(var_name, k) { matched = 0; k = vlen; };
                k = k + 1;
            };
            // Also require the char after var_name to NOT be alpha/digit/underscore
            // -- so `foo` doesn't match `foobar`.
            if matched == 1 {
                let after: i64 = p + vlen;
                if after < slen {
                    let nc: i64 = str_char_at(src, after);
                    let is_id_continue: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                    if is_id_continue == 1 { matched = 0; };
                };
            };
            if matched == 1 {
                let after2: i64 = p + vlen;
                let mut q: i64 = after2;
                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                if q < slen && str_char_at(src, q) == 58 {
                    q = q + 1;
                    while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                    let ts: i64 = q;
                    // track <> depth so `Vec<f64>` returns
                    // "Vec<f64>" (full type), not "Vec" truncated at `<`.
                    // Existing callers checking `str_eq(inferred, "f64")`
                    // etc. are unaffected -- a generic-bearing type
                    // still doesn't match a bare scalar name.
                    let mut gd: i64 = 0;
                    while q < slen {
                        let tc: i64 = str_char_at(src, q);
                        if tc == 60 { gd = gd + 1; q = q + 1; }
                        else if tc == 62 && gd > 0 { gd = gd - 1; q = q + 1; }
                        else if gd == 0 && (tc == 32 || tc == 61 || tc == 59 || tc == 44 || tc == 10 || tc == 13) {
                            let this_type: str = str_substring(src, ts, q);
                            if str_len(found_type) == 0 {
                                found_type = this_type;
                            } else {
                                if str_eq(found_type, this_type) == 0 {
                                    conflict = 1;
                                };
                            };
                            q = slen;
                        } else { q = q + 1; };
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    if str_len(found_type) > 0 { return found_type; };
    // also check for for-loop bindings `for <var_name> in
    // <iter_expr>`. The element type is derived from the iter
    // expression: if iter_expr is `<ident>` or `<ident>.iter()`,
    // look up ident's type and strip the container layer.
    let mut i2: i64 = 0;
    while i2 + 4 < slen {
        // "for " = 'f','o','r',' ' = 102,111,114,32
        if str_char_at(src, i2) == 102
            && str_char_at(src, i2 + 1) == 111
            && str_char_at(src, i2 + 2) == 114
            && str_char_at(src, i2 + 3) == 32 {
            let mut p: i64 = i2 + 4;
            let mut k: i64 = 0;
            let mut matched: i64 = 1;
            while k < vlen {
                if p + k >= slen { matched = 0; k = vlen; }
                else if str_char_at(src, p + k) != str_char_at(var_name, k) { matched = 0; k = vlen; };
                k = k + 1;
            };
            if matched == 1 {
                let after: i64 = p + vlen;
                if after < slen {
                    let nc: i64 = str_char_at(src, after);
                    let is_id_continue: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                    if is_id_continue == 1 { matched = 0; };
                };
            };
            if matched == 1 {
                let mut q: i64 = p + vlen;
                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                // expect "in "
                if q + 3 < slen
                    && str_char_at(src, q) == 105
                    && str_char_at(src, q + 1) == 110
                    && str_char_at(src, q + 2) == 32 {
                    q = q + 3;
                    while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                    // Read iter expression up to '{' or '\n'
                    let iter_start: i64 = q;
                    while q < slen && str_char_at(src, q) != 123 && str_char_at(src, q) != 10 {
                        q = q + 1;
                    };
                    let iter_end: i64 = q;
                    let iter_expr: str = strip_spaces(str_substring(src, iter_start, iter_end));
                    // Strip trailing `.iter()` / `.into_iter()` / `.iter_mut()` if present.
                    let ielen: i64 = str_len(iter_expr);
                    let mut base_iter: str = iter_expr;
                    if ielen >= 7 && str_eq(str_substring(iter_expr, ielen - 7, ielen), ".iter()") == 1 {
                        base_iter = str_substring(iter_expr, 0, ielen - 7);
                    };
                    let belen: i64 = str_len(base_iter);
                    if belen >= 12 && str_eq(str_substring(base_iter, belen - 12, belen), ".into_iter()") == 1 {
                        base_iter = str_substring(base_iter, 0, belen - 12);
                    };
                    // Look up the receiver's full type via recursive call.
                    let recv_full: str = infer_var_type_from_source(src, base_iter);
                    if str_len(recv_full) > 0 {
                        let stripped: str = strip_container_one_level(recv_full);
                        if str_len(stripped) > 0 { return stripped; };
                    };
                };
            };
        };
        i2 = i2 + 1;
    };
    return "";
}

// companion to infer_var_type_from_source. Scans src for
// `struct STRUCT_NAME { ... field: TYPE, ... }` declarations and
// returns TYPE (with container generics intact) for the named
// field, "" if not found or conflict. Used by
// fmt_conversion_for_spec to dispatch println!("{}", p.field) for
// any field type. Conflict-detection mirrors the var/fn helpers.
#[manual_drop]
fn infer_struct_field_type_from_source(src: str, struct_name: str, field_name: str) -> str {
    let slen: i64 = str_len(src);
    let snlen: i64 = str_len(struct_name);
    let fnlen: i64 = str_len(field_name);
    if snlen == 0 || fnlen == 0 { return ""; };
    let mut found_type: str = "";
    let mut conflict: i64 = 0;
    let mut i: i64 = 0;
    while i + 7 < slen {
        // "struct " = 's','t','r','u','c','t',' ' = 115,116,114,117,99,116,32
        if str_char_at(src, i) == 115
            && str_char_at(src, i + 1) == 116
            && str_char_at(src, i + 2) == 114
            && str_char_at(src, i + 3) == 117
            && str_char_at(src, i + 4) == 99
            && str_char_at(src, i + 5) == 116
            && str_char_at(src, i + 6) == 32 {
            let mut p: i64 = i + 7;
            // Try to match struct_name
            let mut k: i64 = 0;
            let mut matched: i64 = 1;
            while k < snlen {
                if p + k >= slen { matched = 0; k = snlen; }
                else if str_char_at(src, p + k) != str_char_at(struct_name, k) { matched = 0; k = snlen; };
                k = k + 1;
            };
            // Identifier boundary
            if matched == 1 {
                let after: i64 = p + snlen;
                if after < slen {
                    let nc: i64 = str_char_at(src, after);
                    let is_id_continue: i64 = if (nc >= 65 && nc <= 90) || (nc >= 97 && nc <= 122) || (nc >= 48 && nc <= 57) || nc == 95 { 1 } else { 0 };
                    if is_id_continue == 1 { matched = 0; };
                };
            };
            if matched == 1 {
                let after2: i64 = p + snlen;
                let mut q: i64 = after2;
                // Skip whitespace, optional generics, then expect `{`
                while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                // Skip generic params if any: `<...>` -- one nesting level
                if q < slen && str_char_at(src, q) == 60 {
                    let mut gd: i64 = 1; q = q + 1;
                    while q < slen && gd > 0 {
                        let gc: i64 = str_char_at(src, q);
                        if gc == 60 { gd = gd + 1; } else if gc == 62 { gd = gd - 1; };
                        q = q + 1;
                    };
                    while q < slen && str_char_at(src, q) == 32 { q = q + 1; };
                };
                if q < slen && str_char_at(src, q) == 123 {
                    q = q + 1;
                    // Find matching `}` for the struct body
                    let body_start: i64 = q;
                    let mut bdepth: i64 = 1;
                    while q < slen && bdepth > 0 {
                        let bc: i64 = str_char_at(src, q);
                        if bc == 123 { bdepth = bdepth + 1; }
                        else if bc == 125 { bdepth = bdepth - 1; };
                        if bdepth > 0 { q = q + 1; };
                    };
                    let body_end: i64 = q;
                    // Scan body for `field_name : TYPE,` (allow whitespace)
                    let mut bp: i64 = body_start;
                    while bp + fnlen < body_end {
                        // Find start of identifier token: previous char is whitespace/comma/{
                        let prev_c: i64 = if bp == 0 { 32 } else { str_char_at(src, bp - 1) };
                        let prev_ok: i64 = if prev_c == 32 || prev_c == 9 || prev_c == 10 || prev_c == 13 || prev_c == 44 || prev_c == 123 { 1 } else { 0 };
                        if prev_ok == 1 {
                            let mut fmatched: i64 = 1;
                            let mut fk: i64 = 0;
                            while fk < fnlen {
                                if bp + fk >= body_end { fmatched = 0; fk = fnlen; }
                                else if str_char_at(src, bp + fk) != str_char_at(field_name, fk) { fmatched = 0; fk = fnlen; };
                                fk = fk + 1;
                            };
                            if fmatched == 1 {
                                let after_field: i64 = bp + fnlen;
                                if after_field < body_end {
                                    let nc2: i64 = str_char_at(src, after_field);
                                    let is_id_continue2: i64 = if (nc2 >= 65 && nc2 <= 90) || (nc2 >= 97 && nc2 <= 122) || (nc2 >= 48 && nc2 <= 57) || nc2 == 95 { 1 } else { 0 };
                                    if is_id_continue2 == 1 { fmatched = 0; };
                                };
                            };
                            if fmatched == 1 {
                                let mut fq: i64 = bp + fnlen;
                                while fq < body_end && str_char_at(src, fq) == 32 { fq = fq + 1; };
                                if fq < body_end && str_char_at(src, fq) == 58 {
                                    fq = fq + 1;
                                    while fq < body_end && str_char_at(src, fq) == 32 { fq = fq + 1; };
                                    let fts: i64 = fq;
                                    while fq < body_end {
                                        let ftc: i64 = str_char_at(src, fq);
                                        if ftc == 44 || ftc == 32 || ftc == 10 || ftc == 13 || ftc == 125 {
                                            let this_type: str = str_substring(src, fts, fq);
                                            if str_len(found_type) == 0 {
                                                found_type = this_type;
                                            } else {
                                                if str_eq(found_type, this_type) == 0 { conflict = 1; };
                                            };
                                            fq = body_end;
                                        };
                                        fq = fq + 1;
                                    };
                                };
                            };
                        };
                        bp = bp + 1;
                    };
                };
            };
        };
        i = i + 1;
    };
    if conflict == 1 { return ""; };
    return found_type;
}

#[manual_drop]
fn fmt_conversion_for_spec(spec: str, arg_expr: str, src: str) -> str {
    // spec is the contents of `{...}` after the `{` and before `}`,
    // i.e. `` for `{}`, `:s` for `{:s}`, etc.
    // bare `{}` heuristic dispatch for the obvious-from-
    // textual-shape cases that adopters reach for. Pre-v0.3.131 bare
    // `{}` always called int_to_str, so `println!("{}", str_var)`
    // printed the string's POINTER ADDRESS and `println!("{}", f64_var)`
    // printed the i64 BIT PATTERN — silent miscompute on the most
    // common debug pattern. The heuristic only fires when the arg
    // expression is unambiguously typed by its textual shape:
    //   - quoted string literal (`"..."`)              → :s
    //   - decimal numeric literal (contains `.`)       → :f
    //   - call to a known float-returning helper
    //     (sqrt, exp, log, tanh, pow, sin, cos,
    //      f64_*, f32_*)                               → :f
    // For any other expression (variable refs to
    // unknown-typed locals, non-float fn calls, complex exprs) the
    // default falls back to int_to_str — adopters of typed `f64`
    // variables should still write `{:f}` explicitly. Documented
    // behavior; the heuristic only corrects the obvious cases.
    if str_eq(spec, "") == 1 {
        let alen: i64 = str_len(arg_expr);
        // `if cond { ... } else { ... }` expression. Detect
        // by leading "if " prefix. Scan the entire expression for a
        // float-shaped substring (decimal literal, _f64(/_f32(
        // suffix). If found -> f64_to_str. Otherwise int default.
        // Catches `println!("{}", if f > 0.0 { f } else { 0.0 })`
        // which pre-fix printed the f64 bit pattern as int.
        if alen >= 3 && str_char_at(arg_expr, 0) == 105 && str_char_at(arg_expr, 1) == 102 && str_char_at(arg_expr, 2) == 32 {
            let mut has_dot: i64 = 0;
            let mut hi3: i64 = 0;
            while hi3 < alen {
                let hc3: i64 = str_char_at(arg_expr, hi3);
                if hc3 == 46 {
                    // Decimal literal candidate -- the `.` must have
                    // a digit on at least one side and not be a
                    // method-call separator. Quick heuristic: prev
                    // and next must both be digit (e.g. "0.0", "3.14").
                    let prev_c: i64 = if hi3 > 0 { str_char_at(arg_expr, hi3 - 1) } else { 32 };
                    let next_c: i64 = if hi3 + 1 < alen { str_char_at(arg_expr, hi3 + 1) } else { 32 };
                    let pd: i64 = if prev_c >= 48 && prev_c <= 57 { 1 } else { 0 };
                    let nd: i64 = if next_c >= 48 && next_c <= 57 { 1 } else { 0 };
                    if pd == 1 && nd == 1 { has_dot = 1; };
                };
                hi3 = hi3 + 1;
            };
            if has_dot == 0 {
                let mut sj4: i64 = 0;
                while sj4 + 5 <= alen {
                    let probe4: str = str_substring(arg_expr, sj4, sj4 + 5);
                    if str_eq(probe4, "_f64(") == 1 || str_eq(probe4, "_f32(") == 1 {
                        has_dot = 1; sj4 = alen;
                    };
                    sj4 = sj4 + 1;
                };
            };
            if has_dot == 1 {
                return str_concat("f64_to_str(", str_concat(arg_expr, ")"));
            };
            return str_concat("int_to_str(", str_concat(arg_expr, ")"));
        };
        // unary not (`!expr`) is always bool. Adopters
        // writing `println!("{}", !flag)` got "0"/"1" via int_to_str
        // pre-fix; should be "false"/"true" per Rust's Display.
        if alen >= 2 && str_char_at(arg_expr, 0) == 33 {
            // First char must be `!` and the next char must NOT be `=`
            // (which would make this `!=` not unary not).
            let c1: i64 = str_char_at(arg_expr, 1);
            if c1 != 61 {
                return str_concat("bool_to_str(", str_concat(arg_expr, ")"));
            };
        };
        // typed float binop. Detect top-level arithmetic
        // ops (` + `, ` - `, ` * `, ` / `, ` % `) at depth 0; if at
        // least one operand resolves to f64/f32 via existing scalar
        // helpers (decimal-literal, _f64( suffix, var lookup), use
        // f64_to_str. Pre-fix `println!("{}", a + b)` for typed f64
        // a, b printed the result's bit pattern -- silent miscompute
        // on the canonical ML adopter pattern.
        if alen >= 5 {
            let mut adepth: i64 = 0;
            let mut aii: i64 = 0;
            let mut arith_pos: i64 = 0 - 1;
            while aii + 3 <= alen && arith_pos < 0 {
                let ac: i64 = str_char_at(arg_expr, aii);
                if ac == 40 || ac == 91 { adepth = adepth + 1; }
                else if ac == 41 || ac == 93 { adepth = adepth - 1; };
                if adepth == 0 && aii > 0 && aii + 2 < alen {
                    let p0: i64 = str_char_at(arg_expr, aii);
                    let p1: i64 = str_char_at(arg_expr, aii + 1);
                    let p2: i64 = str_char_at(arg_expr, aii + 2);
                    if p0 == 32 && p2 == 32 {
                        // ` + `, ` - `, ` * `, ` / `, ` % `
                        if p1 == 43 || p1 == 45 || p1 == 42 || p1 == 47 || p1 == 37 {
                            arith_pos = aii;
                        };
                    };
                };
                aii = aii + 1;
            };
            if arith_pos > 0 {
                let lhs: str = str_substring(arg_expr, 0, arith_pos);
                let rhs: str = str_substring(arg_expr, arith_pos + 3, alen);
                let mut is_float: i64 = 0;
                // Check each operand for float shape: decimal literal,
                // _f64(/_f32( suffix, or bare ident with f-typed.
                let mut k: i64 = 0;
                while k < 2 {
                    let opnd: str = if k == 0 { lhs } else { rhs };
                    let olen: i64 = str_len(opnd);
                    let mut has_dot: i64 = 0;
                    let mut has_alpha: i64 = 0;
                    let mut oi: i64 = 0;
                    while oi < olen {
                        let oc: i64 = str_char_at(opnd, oi);
                        if oc == 46 { has_dot = 1; };
                        if (oc >= 65 && oc <= 90) || (oc >= 97 && oc <= 122) || oc == 95 || oc == 40 || oc == 91 { has_alpha = 1; };
                        oi = oi + 1;
                    };
                    if has_dot == 1 && has_alpha == 0 { is_float = 1; };
                    if olen >= 5 {
                        let mut sj: i64 = 0;
                        while sj + 5 <= olen {
                            let probe: str = str_substring(opnd, sj, sj + 5);
                            if str_eq(probe, "_f64(") == 1 || str_eq(probe, "_f32(") == 1 { is_float = 1; sj = olen; };
                            sj = sj + 1;
                        };
                    };
                    // Bare ident: look up type.
                    let mut bare: i64 = 1;
                    if olen == 0 { bare = 0; };
                    let mut bi3: i64 = 0;
                    while bi3 < olen {
                        let bc3: i64 = str_char_at(opnd, bi3);
                        let bok: i64 = if (bc3 >= 65 && bc3 <= 90) || (bc3 >= 97 && bc3 <= 122) || bc3 == 95 || ((bc3 >= 48 && bc3 <= 57) && bi3 > 0) { 1 } else { 0 };
                        if bok == 0 { bare = 0; bi3 = olen; };
                        bi3 = bi3 + 1;
                    };
                    if bare == 1 {
                        let bt: str = type_base_name(infer_var_type_from_source(src, opnd));
                        if str_eq(bt, "f64") == 1 || str_eq(bt, "f32") == 1 { is_float = 1; };
                    };
                    k = k + 1;
                };
                if is_float == 1 {
                    return str_concat("f64_to_str(", str_concat(arg_expr, ")"));
                };
            };
        };
        // detect top-level comparison/equality/logical ops
        // for bool dispatch. `println!("{}", a == b)` pre-fix printed
        // 0/1 via int_to_str (correct accidentally) but `a < b` etc.
        // do too -- adopters should see "true"/"false" instead. More
        // importantly, this catches the textual `&&`/`||` cases that
        // the lowering treats as bool. Walk the expression with paren/
        // bracket depth tracking; only fire on depth-0 matches.
        if alen >= 4 {
            let mut bdepth: i64 = 0;
            let mut bii: i64 = 0;
            let mut bool_op_found: i64 = 0;
            while bii + 4 <= alen && bool_op_found == 0 {
                let bc: i64 = str_char_at(arg_expr, bii);
                if bc == 40 || bc == 91 { bdepth = bdepth + 1; }
                else if bc == 41 || bc == 93 { bdepth = bdepth - 1; };
                if bdepth == 0 && bii > 0 && bii + 3 < alen {
                    let c0: i64 = str_char_at(arg_expr, bii);
                    let c1: i64 = str_char_at(arg_expr, bii + 1);
                    let c2: i64 = str_char_at(arg_expr, bii + 2);
                    let c3: i64 = str_char_at(arg_expr, bii + 3);
                    // Patterns: " == ", " != ", " <= ", " >= ", " && ", " || "
                    if c0 == 32 && c3 == 32 {
                        if c1 == 61 && c2 == 61 { bool_op_found = 1; };
                        if c1 == 33 && c2 == 61 { bool_op_found = 1; };
                        if c1 == 60 && c2 == 61 { bool_op_found = 1; };
                        if c1 == 62 && c2 == 61 { bool_op_found = 1; };
                        if c1 == 38 && c2 == 38 { bool_op_found = 1; };
                        if c1 == 124 && c2 == 124 { bool_op_found = 1; };
                    };
                };
                bii = bii + 1;
            };
            if bool_op_found == 1 {
                return str_concat("bool_to_str(", str_concat(arg_expr, ")"));
            };
        };
        if alen >= 2 && str_char_at(arg_expr, 0) == 34 && str_char_at(arg_expr, alen - 1) == 34 {
            return arg_expr;
        };
        let mut has_dot: i64 = 0;
        let mut has_alpha: i64 = 0;
        let mut hi: i64 = 0;
        while hi < alen {
            let hc: i64 = str_char_at(arg_expr, hi);
            if hc == 46 { has_dot = 1; };
            if (hc >= 65 && hc <= 90) || (hc >= 97 && hc <= 122) || hc == 95 || hc == 40 || hc == 91 { has_alpha = 1; };
            hi = hi + 1;
        };
        if has_dot == 1 && has_alpha == 0 {
            return str_concat("f64_to_str(", str_concat(arg_expr, ")"));
        };
        if alen >= 5 && str_eq(str_substring(arg_expr, 0, 5), "sqrt(") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        if alen >= 4 && str_eq(str_substring(arg_expr, 0, 4), "exp(") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        if alen >= 4 && str_eq(str_substring(arg_expr, 0, 4), "log(") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        if alen >= 5 && str_eq(str_substring(arg_expr, 0, 5), "tanh(") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        if alen >= 4 && str_eq(str_substring(arg_expr, 0, 4), "f64_") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        if alen >= 4 && str_eq(str_substring(arg_expr, 0, 4), "f32_") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        // also handle the v0.3.127 math_typed.nr typed
        // wrappers (sqrt_f64, exp_f64, log_f64, tanh_f64, sin_f64,
        // cos_f64, pow_f64) — they all end with `_f64(` or `_f32(`.
        // Scan once for a `_f64(` / `_f32(` substring; the call form
        // means the suffix is followed by `(`.
        let mut sub_i: i64 = 0;
        let mut found_typed: i64 = 0;
        while sub_i + 5 <= alen {
            let probe: str = str_substring(arg_expr, sub_i, sub_i + 5);
            if str_eq(probe, "_f64(") == 1 || str_eq(probe, "_f32(") == 1 {
                found_typed = 1;
                sub_i = alen;
            };
            sub_i = sub_i + 1;
        };
        if found_typed == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
        // when arg_expr is a bare identifier and the textual
        // heuristics didn't fire, try to infer its type from a `let X: TYPE`
        // declaration in src. Catches the canonical `println!("{}", f)`
        // (where `f: f64` was declared earlier) which pre-fix printed the
        // f64 BIT PATTERN as an int. Same hazard class as the v0.3.137-150
        // silent miscompiles -- a real expression you wrote produces a
        // wildly wrong number with no diagnostic. Only fires when arg_expr
        // is a single bare identifier (no parens, no dots) -- complex
        // expressions still need explicit `:s` / `:f` / `:i`.
        let mut is_bare_ident: i64 = 1;
        if alen == 0 { is_bare_ident = 0; };
        if is_bare_ident == 1 {
            let first_ident_ch: i64 = str_char_at(arg_expr, 0);
            if is_alpha(first_ident_ch) == 0 && first_ident_ch != 95 { is_bare_ident = 0; };
        };
        let mut bare_i: i64 = 1;
        while bare_i < alen && is_bare_ident == 1 {
            let bare_ch: i64 = str_char_at(arg_expr, bare_i);
            if is_alnum(bare_ch) == 0 && bare_ch != 95 { is_bare_ident = 0; };
            bare_i = bare_i + 1;
        };
        if is_bare_ident == 1 {
            let inferred: str = infer_var_type_from_source(src, arg_expr);
            if str_eq(inferred, "str") == 1 { return arg_expr; };
            if str_eq(inferred, "f64") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
            if str_eq(inferred, "f32") == 1 { return str_concat("f32_to_str(", str_concat(arg_expr, ")")); };
            if str_eq(inferred, "bool") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
            // when the let-scan returned a struct/enum
            // type (not a format-dispatch primitive), the binding
            // could shadow a same-named variant payload. Treat as
            // "no info" and try the pattern-binding fallbacks --
            // they may find a primitive answer from the variant
            // payload type. Avoids misdispatching as int_to_str
            // when one fn has `let s: Stats` and another has
            // `match e { MyErr::BadInput(s, _) => ... s }`.
            let mut try_pattern: i64 = if str_len(inferred) == 0 { 1 } else { 0 };
            if try_pattern == 0 {
                // inferred is a non-primitive type name -- treat as
                // potentially-shadowed and let pattern path also try.
                let is_int_like: i64 = if str_eq(inferred, "i64") == 1 || str_eq(inferred, "i32") == 1 || str_eq(inferred, "i16") == 1 || str_eq(inferred, "i8") == 1 || str_eq(inferred, "u64") == 1 || str_eq(inferred, "u32") == 1 || str_eq(inferred, "u16") == 1 || str_eq(inferred, "u8") == 1 || str_eq(inferred, "isize") == 1 || str_eq(inferred, "usize") == 1 { 1 } else { 0 };
                if is_int_like == 0 { try_pattern = 1; };
            };
            // pattern-binding fallback. If `let X: T = ...`
            // didn't find anything, the binding may come from a
            // match arm pattern (Some(s), Ok(s), Err(s)). Walk back
            // to the enclosing `match <scrutinee>` and infer T from
            // the scrutinee's declared Option<T> / Result<T,E>.
            if try_pattern == 1 {
                let pat_inferred: str = infer_pattern_binding_type_from_source(src, arg_expr);
                if str_eq(pat_inferred, "str") == 1 { return arg_expr; };
                if str_eq(pat_inferred, "f64") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
                if str_eq(pat_inferred, "f32") == 1 { return str_concat("f32_to_str(", str_concat(arg_expr, ")")); };
                if str_eq(pat_inferred, "bool") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                // secondary fallback for user-defined enum variant
                // bindings (MyErr::BadInput(s, n) etc).
                if str_len(pat_inferred) == 0 {
                    let user_inferred: str = infer_user_variant_binding_type(src, arg_expr);
                    if str_eq(user_inferred, "str") == 1 { return arg_expr; };
                    if str_eq(user_inferred, "f64") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(user_inferred, "f32") == 1 { return str_concat("f32_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(user_inferred, "bool") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                };
                // i*-typed bindings fall through to int_to_str default.
            };
            let inferred_base: str = type_base_name(inferred);
            if str_len(inferred_base) > 0 && str_contains(src, str_concat("struct ", inferred_base)) == 1 {
                if str_contains(src, str_concat("impl Display for ", inferred_base)) == 1 {
                    return str_concat(inferred_base, str_concat("__fmt(", str_concat(arg_expr, ")")));
                };
                print(str_concat("ERROR: error[FMT-002]: type '", str_concat(inferred_base, "' does not implement Display for '{}'")));
                panic("nucleor: FMT-002 missing Display impl for struct format");
            };
            // i8/i16/i32/i64/etc fall through to int_to_str (default).
        };
        // also try to detect fn-call shape `<ident>(...)` and
        // infer the type from `fn <ident>(...) -> TYPE` in source. Catches
        // the canonical println!("{}", make_str()) which pre-fix printed
        // the string's POINTER ADDRESS. Conservative-by-construction:
        // requires the call's identifier to be paren-bounded, the fn to
        // have a parseable return type, and all matching fn declarations
        // to agree on the type.
        if alen >= 3 && str_char_at(arg_expr, alen - 1) == 41 {
            let mut paren_at: i64 = 0 - 1;
            let mut ci: i64 = 0;
            while ci < alen {
                if str_char_at(arg_expr, ci) == 40 { paren_at = ci; ci = alen; };
                ci = ci + 1;
            };
            if paren_at > 0 {
                let head: str = str_substring(arg_expr, 0, paren_at);
                let mut head_ok: i64 = 1;
                let hlen: i64 = str_len(head);
                let mut hi2: i64 = 0;
                while hi2 < hlen {
                    let hc2: i64 = str_char_at(head, hi2);
                    let hc2_ok: i64 = if (hc2 >= 65 && hc2 <= 90) || (hc2 >= 97 && hc2 <= 122) || (hc2 >= 48 && hc2 <= 57) || hc2 == 95 { 1 } else { 0 };
                    if hi2 == 0 {
                        let first_ok: i64 = if (hc2 >= 65 && hc2 <= 90) || (hc2 >= 97 && hc2 <= 122) || hc2 == 95 { 1 } else { 0 };
                        if first_ok == 0 { head_ok = 0; hi2 = hlen; };
                    } else {
                        if hc2_ok == 0 { head_ok = 0; hi2 = hlen; };
                    };
                    hi2 = hi2 + 1;
                };
                if head_ok == 1 {
                    let fn_inferred: str = infer_fn_return_type_from_source(src, head);
                    if str_eq(fn_inferred, "str") == 1 { return arg_expr; };
                    if str_eq(fn_inferred, "f64") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(fn_inferred, "f32") == 1 { return str_concat("f32_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(fn_inferred, "bool") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    // builtin runtime-helper return-type
                    // fallback for the println! `{}` heuristic. Mirrors
                    // the v0.3.178 print() kind-7 builtin fallback.
                    // Pre-fix `println!("{}", str_concat(a, b))` printed
                    // the str pointer as int. Hardcoded list of well-
                    // known runtime helpers with deterministic returns.
                    if str_eq(head, "str_concat") == 1 { return arg_expr; };
                    if str_eq(head, "str_substring") == 1 { return arg_expr; };
                    if str_eq(head, "str_to_lower") == 1 { return arg_expr; };
                    if str_eq(head, "str_to_upper") == 1 { return arg_expr; };
                    if str_eq(head, "str_trim") == 1 { return arg_expr; };
                    if str_eq(head, "str_trim_start") == 1 { return arg_expr; };
                    if str_eq(head, "str_trim_end") == 1 { return arg_expr; };
                    if str_eq(head, "str_replace") == 1 { return arg_expr; };
                    if str_eq(head, "str_repeat") == 1 { return arg_expr; };
                    if str_eq(head, "str_reverse") == 1 { return arg_expr; };
                    if str_eq(head, "str_pad_left") == 1 { return arg_expr; };
                    if str_eq(head, "str_pad_right") == 1 { return arg_expr; };
                    if str_eq(head, "str_center") == 1 { return arg_expr; };
                    if str_eq(head, "str_intern") == 1 { return arg_expr; };
                    if str_eq(head, "str_arena_concat") == 1 { return arg_expr; };
                    if str_eq(head, "str_arena_substring") == 1 { return arg_expr; };
                    if str_eq(head, "tok_decode") == 1 { return arg_expr; };
                    if str_eq(head, "f64_to_str") == 1 { return arg_expr; };
                    if str_eq(head, "f32_to_str") == 1 { return arg_expr; };
                    if str_eq(head, "int_to_str") == 1 { return arg_expr; };
                    if str_eq(head, "bool_to_str") == 1 { return arg_expr; };
                    if str_eq(head, "getenv") == 1 { return arg_expr; };
                    // i64 returns
                    if str_eq(head, "str_len") == 1 { return str_concat("int_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "str_to_int") == 1 { return str_concat("int_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "str_to_i64") == 1 { return str_concat("int_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "str_index_of") == 1 { return str_concat("int_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "str_count") == 1 { return str_concat("int_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "vec_len") == 1 { return str_concat("int_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "hashmap_len") == 1 { return str_concat("int_to_str(", str_concat(arg_expr, ")")); };
                    // bool returns
                    if str_eq(head, "str_eq") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "str_contains") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "str_starts_with") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "str_ends_with") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "str_is_empty") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "vec_is_empty") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "hashmap_contains") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(head, "hashmap_is_empty") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    // container-element-type dispatch for the
                    // builtin getters whose return type comes from the
                    // RECEIVER's container generic, not the fn name.
                    // Parse the first arg (the receiver), look up its
                    // declared Vec<T> / HashMap<K,V> / BTreeMap<K,V>
                    // type, extract the element/value type T.
                    let mut is_container_get: i64 = 0;
                    let mut take_first_generic: i64 = 0;  // 1 = T from Vec<T>, 0 = V from K,V
                    if str_eq(head, "vec_get") == 1 { is_container_get = 1; take_first_generic = 1; };
                    if str_eq(head, "vec_first") == 1 { is_container_get = 1; take_first_generic = 1; };
                    if str_eq(head, "vec_last") == 1 { is_container_get = 1; take_first_generic = 1; };
                    if str_eq(head, "vec_pop") == 1 { is_container_get = 1; take_first_generic = 1; };
                    if str_eq(head, "hashmap_get") == 1 { is_container_get = 1; take_first_generic = 0; };
                    if str_eq(head, "hashmap_get_or") == 1 { is_container_get = 1; take_first_generic = 0; };
                    if str_eq(head, "hashmap_remove") == 1 { is_container_get = 1; take_first_generic = 0; };
                    if str_eq(head, "btreemap_get") == 1 { is_container_get = 1; take_first_generic = 0; };
                    if is_container_get == 1 {
                        // Parse the first arg by finding the outer `,` or `)`
                        // matching paren_at. Receiver runs from paren_at+1 to
                        // the comma (or to alen-1 for single-arg calls).
                        let mut arg_end: i64 = alen - 1;
                        let mut depth_p: i64 = 0;
                        let mut ap: i64 = paren_at + 1;
                        while ap < alen - 1 {
                            let apc: i64 = str_char_at(arg_expr, ap);
                            if apc == 40 || apc == 60 || apc == 91 { depth_p = depth_p + 1; }
                            else if apc == 41 || apc == 62 || apc == 93 { depth_p = depth_p - 1; }
                            else if apc == 44 && depth_p == 0 { arg_end = ap; ap = alen; };
                            ap = ap + 1;
                        };
                        let mut recv_start: i64 = paren_at + 1;
                        while recv_start < arg_end && str_char_at(arg_expr, recv_start) == 32 { recv_start = recv_start + 1; };
                        let mut recv_e: i64 = arg_end;
                        while recv_e > recv_start && str_char_at(arg_expr, recv_e - 1) == 32 { recv_e = recv_e - 1; };
                        let recv_id: str = str_substring(arg_expr, recv_start, recv_e);
                        // Recv must be a bare identifier for v1.
                        let mut rok2: i64 = 1;
                        let rlen2: i64 = str_len(recv_id);
                        if rlen2 == 0 { rok2 = 0; };
                        let mut ri2: i64 = 0;
                        while ri2 < rlen2 {
                            let rc2: i64 = str_char_at(recv_id, ri2);
                            let r_ok2: i64 = if (rc2 >= 65 && rc2 <= 90) || (rc2 >= 97 && rc2 <= 122) || rc2 == 95 || ((rc2 >= 48 && rc2 <= 57) && ri2 > 0) { 1 } else { 0 };
                            if r_ok2 == 0 { rok2 = 0; ri2 = rlen2; };
                            ri2 = ri2 + 1;
                        };
                        if rok2 == 1 {
                            let recv_full: str = infer_var_type_from_source(src, recv_id);
                            if str_len(recv_full) > 0 {
                                let elem_full: str = if take_first_generic == 1 { strip_container_one_level(recv_full) } else { generic_second_type(recv_full) };
                                let elem_type: str = type_base_name(elem_full);
                                if str_eq(elem_type, "str") == 1 { return arg_expr; };
                                if str_eq(elem_type, "f64") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
                                if str_eq(elem_type, "f32") == 1 { return str_concat("f32_to_str(", str_concat(arg_expr, ")")); };
                                if str_eq(elem_type, "bool") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                            };
                        };
                    };
                };
                // also recognize method-call shape
                // `<recv>.<method>(...)`. Treat the trailing `<method>`
                // as the fn name to look up. Catches
                // `println!("{}", s.total())` where total() returns
                // f64 -- pre-fix printed the bit pattern via int_to_str.
                // Conservative: head must split cleanly into ident + .
                // + ident.
                if head_ok == 0 {
                    // Check for `<recv>.<method>` pattern.
                    let mut last_dot: i64 = 0 - 1;
                    let mut di2: i64 = hlen - 1;
                    while di2 >= 0 {
                        if str_char_at(head, di2) == 46 { last_dot = di2; di2 = 0 - 1; };
                        di2 = di2 - 1;
                    };
                    if last_dot > 0 && last_dot < hlen - 1 {
                        let recv_h: str = str_substring(head, 0, last_dot);
                        let mname_h: str = str_substring(head, last_dot + 1, hlen);
                        // Both must be bare idents (recv may have its
                        // own `.` chain -- not handled, conservative).
                        let mut rh_ok: i64 = 1;
                        let rhl: i64 = str_len(recv_h);
                        if rhl == 0 { rh_ok = 0; };
                        let mut ri4: i64 = 0;
                        while ri4 < rhl {
                            let rc4: i64 = str_char_at(recv_h, ri4);
                            let rc4_ok: i64 = if (rc4 >= 65 && rc4 <= 90) || (rc4 >= 97 && rc4 <= 122) || rc4 == 95 || ((rc4 >= 48 && rc4 <= 57) && ri4 > 0) { 1 } else { 0 };
                            if rc4_ok == 0 { rh_ok = 0; ri4 = rhl; };
                            ri4 = ri4 + 1;
                        };
                        let mut mh_ok: i64 = 1;
                        let mhl: i64 = str_len(mname_h);
                        if mhl == 0 { mh_ok = 0; };
                        let mut mi4: i64 = 0;
                        while mi4 < mhl {
                            let mc4: i64 = str_char_at(mname_h, mi4);
                            let mc4_ok: i64 = if (mc4 >= 65 && mc4 <= 90) || (mc4 >= 97 && mc4 <= 122) || mc4 == 95 || ((mc4 >= 48 && mc4 <= 57) && mi4 > 0) { 1 } else { 0 };
                            if mc4_ok == 0 { mh_ok = 0; mi4 = mhl; };
                            mi4 = mi4 + 1;
                        };
                        if rh_ok == 1 && mh_ok == 1 {
                            // Try the existing fn-name return type
                            // helper -- works if the impl method
                            // is declared as `fn <method>(self) -> TYPE`
                            // (the helper's regex matches any `fn NAME`
                            // declaration and uses conflict-detection).
                            let m_inferred: str = infer_fn_return_type_from_source(src, mname_h);
                            if str_eq(m_inferred, "str") == 1 { return arg_expr; };
                            if str_eq(m_inferred, "f64") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
                            if str_eq(m_inferred, "f32") == 1 { return str_concat("f32_to_str(", str_concat(arg_expr, ")")); };
                            if str_eq(m_inferred, "bool") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                            // Builtin fallback for well-known method names.
                            if str_eq(mname_h, "is_empty") == 1 || str_eq(mname_h, "contains") == 1 || str_eq(mname_h, "contains_key") == 1 {
                                return str_concat("bool_to_str(", str_concat(arg_expr, ")"));
                            };
                        };
                    };
                };
            };
        };
        // cast expression `<expr> as TYPE`. The trailing
        // TYPE is unambiguous, so dispatch by the cast target. Catches
        // println!("{}", n as f64) which pre-fix printed the int as
        // its f64 bit pattern. Find the LAST " as " substring (handles
        // chained casts conservatively -- innermost wins).
        if alen >= 5 {
            let mut as_pos: i64 = 0 - 1;
            let mut sci: i64 = alen - 4;
            while sci >= 0 {
                if str_char_at(arg_expr, sci) == 32
                    && str_char_at(arg_expr, sci + 1) == 97
                    && str_char_at(arg_expr, sci + 2) == 115
                    && str_char_at(arg_expr, sci + 3) == 32 {
                    as_pos = sci;
                    sci = 0 - 1;
                };
                sci = sci - 1;
            };
            if as_pos > 0 {
                // Trailing TYPE: trim leading/trailing spaces.
                let mut ts: i64 = as_pos + 4;
                while ts < alen && str_char_at(arg_expr, ts) == 32 { ts = ts + 1; };
                let mut te: i64 = alen;
                while te > ts && str_char_at(arg_expr, te - 1) == 32 { te = te - 1; };
                if te > ts {
                    let target_type: str = type_base_name(str_substring(arg_expr, ts, te));
                    if str_eq(target_type, "f64") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(target_type, "f32") == 1 { return str_concat("f32_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(target_type, "bool") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    // i*/u* fall through to int_to_str (the default below).
                };
            };
        };
        // struct field access `<recv>.<field>`. If the
        // receiver is a bare ident with a known var type, look up the
        // field's type via infer_struct_field_type_from_source. Catches
        // println!("{}", p.x) where p.x: f64 (was printing the f64
        // bit pattern as int pre-fix). Conservative: only fires when
        // both receiver and field are simple bare identifiers.
        let mut dot_pos: i64 = 0 - 1;
        let mut dpi: i64 = alen - 1;
        while dpi >= 0 {
            if str_char_at(arg_expr, dpi) == 46 { dot_pos = dpi; dpi = 0 - 1; };
            dpi = dpi - 1;
        };
        if dot_pos > 0 && dot_pos < alen - 1 {
            let recv_str: str = str_substring(arg_expr, 0, dot_pos);
            let field_str: str = str_substring(arg_expr, dot_pos + 1, alen);
            // Both must be bare identifiers.
            let mut recv_ok: i64 = 1;
            let rlen: i64 = str_len(recv_str);
            if rlen == 0 { recv_ok = 0; };
            let mut ri: i64 = 0;
            while ri < rlen {
                let rc: i64 = str_char_at(recv_str, ri);
                let rok: i64 = if (rc >= 65 && rc <= 90) || (rc >= 97 && rc <= 122) || rc == 95 || ((rc >= 48 && rc <= 57) && ri > 0) { 1 } else { 0 };
                if rok == 0 { recv_ok = 0; ri = rlen; };
                ri = ri + 1;
            };
            let mut field_ok: i64 = 1;
            let flen: i64 = str_len(field_str);
            if flen == 0 { field_ok = 0; };
            let mut fi: i64 = 0;
            while fi < flen {
                let fc: i64 = str_char_at(field_str, fi);
                let fok: i64 = if (fc >= 65 && fc <= 90) || (fc >= 97 && fc <= 122) || fc == 95 || ((fc >= 48 && fc <= 57) && fi > 0) { 1 } else { 0 };
                if fok == 0 { field_ok = 0; fi = flen; };
                fi = fi + 1;
            };
            if recv_ok == 1 && field_ok == 1 {
                // when the receiver isn't a let-bound local
                // (returns "" from infer_var_type_from_source), fall
                // back to the pattern-binding helper -- catches the
                // `match Some(g) => println!("{}", g.message)` shape
                // where g came from an Option<MyStruct> Some payload.
                let mut recv_full: str = infer_var_type_from_source(src, recv_str);
                if str_len(recv_full) == 0 {
                    recv_full = infer_pattern_binding_type_from_source(src, recv_str);
                };
                let recv_type: str = type_base_name(recv_full);
                if str_len(recv_type) > 0 {
                    let field_type: str = type_base_name(infer_struct_field_type_from_source(src, recv_type, field_str));
                    if str_eq(field_type, "str") == 1 { return arg_expr; };
                    if str_eq(field_type, "f64") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(field_type, "f32") == 1 { return str_concat("f32_to_str(", str_concat(arg_expr, ")")); };
                    if str_eq(field_type, "bool") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                };
            };
        };
        // index expression `<recv>[<expr>]`. If receiver is
        // a bare ident with type Vec<T> (or similar container), strip
        // one container layer to get T and dispatch. Catches
        // println!("{}", v[0]) where v: Vec<f64> -- pre-fix printed
        // the f64 bit pattern as int.
        if alen >= 3 && str_char_at(arg_expr, alen - 1) == 93 {
            // Find matching `[` by depth.
            let mut bdepth: i64 = 1;
            let mut bi2: i64 = alen - 2;
            let mut br_pos: i64 = 0 - 1;
            while bi2 >= 0 && br_pos < 0 {
                let bc2: i64 = str_char_at(arg_expr, bi2);
                if bc2 == 93 { bdepth = bdepth + 1; }
                else if bc2 == 91 { bdepth = bdepth - 1; if bdepth == 0 { br_pos = bi2; }; };
                bi2 = bi2 - 1;
            };
            if br_pos > 0 {
                let recv2: str = str_substring(arg_expr, 0, br_pos);
                // Receiver must be bare ident.
                let mut r2_ok: i64 = 1;
                let r2len: i64 = str_len(recv2);
                if r2len == 0 { r2_ok = 0; };
                let mut r2i: i64 = 0;
                while r2i < r2len {
                    let r2c: i64 = str_char_at(recv2, r2i);
                    let r2ok: i64 = if (r2c >= 65 && r2c <= 90) || (r2c >= 97 && r2c <= 122) || r2c == 95 || ((r2c >= 48 && r2c <= 57) && r2i > 0) { 1 } else { 0 };
                    if r2ok == 0 { r2_ok = 0; r2i = r2len; };
                    r2i = r2i + 1;
                };
                if r2_ok == 1 {
                    let recv_full: str = infer_var_type_from_source(src, recv2);
                    if str_len(recv_full) > 0 {
                        let elem_full: str = strip_container_one_level(recv_full);
                        let elem_type: str = type_base_name(elem_full);
                        if str_eq(elem_type, "str") == 1 { return arg_expr; };
                        if str_eq(elem_type, "f64") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
                        if str_eq(elem_type, "f32") == 1 { return str_concat("f32_to_str(", str_concat(arg_expr, ")")); };
                        if str_eq(elem_type, "bool") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
                    };
                };
            };
        };
        return str_concat("int_to_str(", str_concat(arg_expr, ")"));
    };
    if str_eq(spec, ":i") == 1 { return str_concat("int_to_str(", str_concat(arg_expr, ")")); };
    if str_eq(spec, ":s") == 1 { return arg_expr; };
    if str_eq(spec, ":f") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
    // `{:?}` Debug formatter. Rust convention: same as `{}`
    // for primitives (int/float/bool); for strings, wrap in quotes.
    // Since most adopters reach for `:?` to debug a str, the quote-wrap
    // is the high-value case. Other types pass through to empty-spec
    // dispatch so the type-detection picks the right *_to_str helper.
    if str_eq(spec, ":?") == 1 {
        let inferred: str = type_base_name(infer_var_type_from_source(src, arg_expr));
        if str_eq(inferred, "str") == 1 || str_eq(inferred, "String") == 1 {
            return str_concat("str_concat(\"\\\"\", str_concat(", str_concat(arg_expr, ", \"\\\"\"))"));
        };
        // recursive Debug for Vec/Option/Result.
        // Pre-fix `println!("{:?}", v)` for v: Vec<i64> emitted the
        // pointer integer (silent miscompute). Now routes to runtime
        // helpers that produce `[1, 2, 3]` / `Some(42)` / `Err(7)`.
        // Element/payload formatted as i64 (Nucleor cell convention).
        if str_eq(inferred, "Vec") == 1 {
            // dispatch by element type for Vec<str> /
            // Vec<Option<i64>>. Default i64 for primitives.
            let inferred_full: str = infer_var_type_from_source(src, arg_expr);
            let elem_t98: str = type_first_arg(inferred_full);
            let elem_b98: str = type_base_name(elem_t98);
            if str_eq(elem_b98, "str") == 1 || str_eq(elem_b98, "String") == 1 {
                return str_concat("vec_to_debug_str_str(", str_concat(arg_expr, ")"));
            };
            if str_eq(elem_b98, "Option") == 1 {
                return str_concat("vec_to_debug_str_option_i64(", str_concat(arg_expr, ")"));
            };
            return str_concat("vec_to_debug_str_i64(", str_concat(arg_expr, ")"));
        };
        if str_eq(inferred, "Option") == 1 {
            return str_concat("option_to_debug_str_i64(", str_concat(arg_expr, ")"));
        };
        if str_eq(inferred, "Result") == 1 {
            return str_concat("result_to_debug_str_i64(", str_concat(arg_expr, ")"));
        };
        if str_len(inferred) > 0 && str_contains(src, str_concat("struct ", inferred)) == 1 {
            let mut dbg_segments: Vec<i32> = Vec::new();
            let mut dbg_parities: Vec<i32> = Vec::new();
            dbg_segments.push(str_concat(inferred, " { "));
            dbg_parities.push(0);
            let dbg_fields: Vec<i32> = extract_struct_fields_native(src, inferred);
            let mut dbg_i: i64 = 0;
            let mut dbg_count: i64 = 0;
            while dbg_i + 1 < vec_len(dbg_fields) {
                let dbg_field_name: str = vec_get(dbg_fields, dbg_i);
                let dbg_field_type: str = vec_get(dbg_fields, dbg_i + 1);
                if dbg_count > 0 {
                    dbg_segments.push(", ");
                    dbg_parities.push(0);
                };
                dbg_segments.push(str_concat(dbg_field_name, ": "));
                dbg_parities.push(0);
                let dbg_field_expr: str = str_concat(arg_expr, str_concat(".", dbg_field_name));
                let dbg_base: str = type_base_name(dbg_field_type);
                if str_eq(dbg_base, "str") == 1 || str_eq(dbg_base, "String") == 1 {
                    dbg_segments.push(str_concat("str_concat(\"\\\"\", str_concat(", str_concat(dbg_field_expr, ", \"\\\"\"))"));
                } else if str_eq(dbg_base, "f64") == 1 {
                    dbg_segments.push(str_concat("f64_to_str(", str_concat(dbg_field_expr, ")")));
                } else if str_eq(dbg_base, "f32") == 1 {
                    dbg_segments.push(str_concat("f32_to_str(", str_concat(dbg_field_expr, ")")));
                } else if str_eq(dbg_base, "bool") == 1 {
                    dbg_segments.push(str_concat("bool_to_str(", str_concat(dbg_field_expr, ")")));
                } else {
                    dbg_segments.push(str_concat("int_to_str(", str_concat(dbg_field_expr, ")")));
                };
                dbg_parities.push(1);
                dbg_count = dbg_count + 1;
                dbg_i = dbg_i + 2;
            };
            dbg_segments.push(" }");
            dbg_parities.push(0);
            return fmt_build_concat_chain(dbg_segments, dbg_parities);
        };
        // For non-str (or unknown), fall through to empty-spec dispatcher.
        return fmt_conversion_for_spec("", arg_expr, src);
    };
    // `:b` is BINARY RADIX per Rust convention — falls through to
    // the spec parser below (type_char = 'b' → int_to_bin). Pre-v0.4.29 we
    // routed this to bool_to_str which was a non-Rust dialect divergence
    // (Rust uses `:?` Debug for bool). No fixture depends on the old behavior.
    // precision + width spec dispatch.
    // Spec arrives as ":<rust-spec-body>", e.g. ":.3", ":>10", ":<10",
    // ":^10", ":08", ":>10.3", ":>10". Parse the body into:
    //   align: 0 = none, 1 = '<' left, 2 = '>' right, 3 = '^' center
    //   fill_char: ' ' or '0' (zero-pad shortcut)
    //   width: integer or 0 (unset)
    //   precision: integer or -1 (unset)
    // After the type-dispatched <type>_to_str(arg) is built, wrap with
    // the appropriate pad helper if width > 0.
    let speclen: i64 = str_len(spec);
    if speclen >= 2 && str_char_at(spec, 0) == 58 {
        let mut align: i64 = 0;
        let mut fill_char: i64 = 32;  // ' '
        let mut width: i64 = 0;
        let mut prec: i64 = 0 - 1;
        let mut type_char: i64 = 0;   // 'x','o','b','X' if set
        let mut force_sign: i64 = 0;  // '+'
        let mut alt_form: i64 = 0;    // '#' (0x/0o/0b prefix)
        let mut p: i64 = 1;  // skip ':'
        // optional fill char + align — Rust grammar is
        // [[fill]align]. Detect by looking at chars 1 and 2 of spec:
        // if spec[2] is <,>,^ then spec[1] is the fill char.
        // Standard align (no custom fill) is just spec[1] in {<,>,^}.
        let c0: i64 = if p < speclen { str_char_at(spec, p) } else { 0 };
        let c1: i64 = if p + 1 < speclen { str_char_at(spec, p + 1) } else { 0 };
        if c1 == 60 || c1 == 62 || c1 == 94 {
            // Custom fill char + align
            fill_char = c0;
            if c1 == 60 { align = 1; }
            else if c1 == 62 { align = 2; }
            else { align = 3; };
            p = p + 2;
        } else if c0 == 60 { align = 1; p = p + 1; }
        else if c0 == 62 { align = 2; p = p + 1; }
        else if c0 == 94 { align = 3; p = p + 1; };
        // Optional sign: '+' (force sign on positives)
        if p < speclen && str_char_at(spec, p) == 43 {
            force_sign = 1;
            p = p + 1;
        };
        // Optional alternate form: '#'
        if p < speclen && str_char_at(spec, p) == 35 {
            alt_form = 1;
            p = p + 1;
        };
        // Optional zero-pad shortcut: '0<width>'
        if align == 0 && p < speclen && str_char_at(spec, p) == 48 {
            let nxt: i64 = if p + 1 < speclen { str_char_at(spec, p + 1) } else { 0 };
            if nxt >= 48 && nxt <= 57 {
                fill_char = 48;  // '0'
                align = 2;       // right-align (zero-pad default)
                p = p + 1;       // consume the '0'
            };
        };
        // Width digits
        let mut width_seen: i64 = 0;
        while p < speclen {
            let dc: i64 = str_char_at(spec, p);
            if dc >= 48 && dc <= 57 {
                width = width * 10 + (dc - 48);
                width_seen = 1;
                p = p + 1;
            } else {
                p = speclen + 100;
            };
        };
        // Restore p to "after width digits" position. Recompute by
        // re-scanning from the start through the prefix segments.
        p = 1;
        if c1 == 60 || c1 == 62 || c1 == 94 { p = p + 2; }
        else if c0 == 60 || c0 == 62 || c0 == 94 { p = p + 1; };
        if force_sign == 1 { p = p + 1; };
        if alt_form == 1 { p = p + 1; };
        if fill_char == 48 && align == 2
           && c0 != 60 && c0 != 62 && c0 != 94
           && !(c1 == 60 || c1 == 62 || c1 == 94) { p = p + 1; };
        while p < speclen && str_char_at(spec, p) >= 48 && str_char_at(spec, p) <= 57 { p = p + 1; };
        // Optional precision: '.<digits>'
        // break the digit-scan loop on first non-digit WITHOUT
        // advancing p — the type char (e/E/x/o/b) sits right after the
        // precision digits and the next phase needs to see it.
        if p < speclen && str_char_at(spec, p) == 46 {
            p = p + 1;
            prec = 0;
            let mut prec_done: i64 = 0;
            while p < speclen && prec_done == 0 {
                let pc: i64 = str_char_at(spec, p);
                if pc >= 48 && pc <= 57 { prec = prec * 10 + (pc - 48); p = p + 1; }
                else { prec_done = 1; };
            };
        };
        // Optional type char (last): 'x' hex, 'X' upper hex, 'o' oct,
        // 'b' bin, 'e'/'E' scientific notation (v0.4.38).
        if p < speclen {
            let tc: i64 = str_char_at(spec, p);
            if tc == 120 || tc == 88 || tc == 111 || tc == 98 || tc == 101 || tc == 69 {
                type_char = tc;
                p = p + 1;
            };
        };
        // If we parsed a complete recognized spec, build the wrap.
        let has_format: i64 = if width_seen == 1 || prec >= 0 || align != 0
                                 || type_char != 0 || force_sign == 1 || alt_form == 1 { 1 } else { 0 };
        if has_format == 1 {
            // First produce the typed conversion; apply precision if requested
            // and arg is f32/f64.
            let plain: str = fmt_conversion_for_spec("", arg_expr, src);
            let plen: i64 = str_len(plain);
            let mut typed: str = plain;
            // if type_char is a radix (x/X/o/b), substitute the
            // int_to_<radix> helper. The arg is treated as i64 regardless
            // of what the empty-spec dispatcher picked.
            if type_char != 0 {
                // 'x' lowercase → int_to_hex; 'X' upper → int_to_hex_upper
                if type_char == 120 {
                    typed = str_concat("int_to_hex(", str_concat(arg_expr, ")"));
                } else if type_char == 88 {
                    typed = str_concat("int_to_hex_upper(", str_concat(arg_expr, ")"));
                } else if type_char == 111 {
                    typed = str_concat("int_to_oct(", str_concat(arg_expr, ")"));
                } else if type_char == 98 {
                    typed = str_concat("int_to_bin(", str_concat(arg_expr, ")"));
                };
                // 'e' / 'E' scientific notation. Routes through
                // f64-bit-pattern helpers — arg is already an i64 holding
                // the f64 bit pattern at the i64-everywhere ABI level.
                // If precision was set (e.g. {:.3e}), use the prec variant.
                if type_char == 101 {
                    if prec >= 0 {
                        let prec_s: str = str_from_int(prec);
                        typed = str_concat("f64_to_str_sci_prec(", str_concat(arg_expr, str_concat(", ", str_concat(prec_s, ")"))));
                    } else {
                        typed = str_concat("f64_to_str_sci(", str_concat(arg_expr, ")"));
                    };
                };
                if type_char == 69 {
                    if prec >= 0 {
                        let prec_s: str = str_from_int(prec);
                        typed = str_concat("f64_to_str_sci_prec_upper(", str_concat(arg_expr, str_concat(", ", str_concat(prec_s, ")"))));
                    } else {
                        typed = str_concat("f64_to_str_sci_upper(", str_concat(arg_expr, ")"));
                    };
                };
                // '#' alternate form prepends 0x/0o/0b prefix.
                if alt_form == 1 {
                    let mut prefix: str = "";
                    if type_char == 120 || type_char == 88 { prefix = "0x"; }
                    else if type_char == 111 { prefix = "0o"; }
                    else if type_char == 98 { prefix = "0b"; };
                    if str_len(prefix) > 0 {
                        typed = str_concat("str_concat(\"", str_concat(prefix, str_concat("\", ", str_concat(typed, ")"))));
                    };
                };
            };
            if prec >= 0 && type_char == 0 {
                let prec_str: str = str_from_int(prec);
                if plen >= 12 && str_eq(str_substring(plain, 0, 11), "f64_to_str(") == 1 {
                    let inner: str = str_substring(plain, 11, plen - 1);
                    typed = str_concat("f64_to_str_prec(", str_concat(inner, str_concat(", ", str_concat(prec_str, ")"))));
                } else if plen >= 12 && str_eq(str_substring(plain, 0, 11), "f32_to_str(") == 1 {
                    let inner: str = str_substring(plain, 11, plen - 1);
                    typed = str_concat("f32_to_str_prec(", str_concat(inner, str_concat(", ", str_concat(prec_str, ")"))));
                };
                // Non-float: precision silently ignored (Rust behavior).
            };
            // '+' force-sign emission via the
            // runtime helper `__nucleor_int_to_str_force_sign`. Helper
            // takes the arg ONCE and prints "+N" for non-negatives,
            // "-N" for negatives. Avoids double-evaluation that a
            // ternary lowering would cause for side-effecting fn-call
            // args. Only kicks in for plain integer dispatch (when
            // `typed` looks like `int_to_str(...)` — the empty-spec
            // result for an i64 arg). Floats / strings / bools ignore
            // force_sign (consistent with Rust: `:+` on non-numeric
            // is silently no-op).
            if force_sign == 1 {
                let tlen: i64 = str_len(typed);
                if tlen >= 12 && str_eq(str_substring(typed, 0, 11), "int_to_str(") == 1 {
                    let inner_int: str = str_substring(typed, 11, tlen - 1);
                    typed = str_concat("int_to_str_force_sign(", str_concat(inner_int, ")"));
                };
            };
            // Now apply width via str_pad_*. Numeric default-align is right.
            if width > 0 {
                let width_str: str = str_from_int(width);
                let fill_str: str = str_from_int(fill_char);
                // align == 0 means no explicit align; default right for numerics,
                // left for strings. For simplicity (and to match Rust's
                // numeric default), use right when fill is '0' or arg is
                // numeric-looking; otherwise left. Heuristic: if `typed`
                // contains "_to_str(" it's a numeric or bool conversion;
                // route to right-align. If it's just `arg_expr` (str), left.
                let mut chosen: i64 = align;
                if chosen == 0 {
                    if str_contains(typed, "_to_str(") == 1 || str_contains(typed, "_to_str_prec(") == 1 {
                        chosen = 2;  // right
                    } else {
                        chosen = 1;  // left
                    };
                };
                if chosen == 1 {
                    // left-align => content on left, padding on right => str_pad_right
                    return str_concat("str_pad_right(", str_concat(typed, str_concat(", ", str_concat(width_str, str_concat(", ", str_concat(fill_str, ")"))))));
                };
                if chosen == 3 {
                    return str_concat("str_center(", str_concat(typed, str_concat(", ", str_concat(width_str, str_concat(", ", str_concat(fill_str, ")"))))));
                };
                // right-align (default for numerics) => str_pad_left
                return str_concat("str_pad_left(", str_concat(typed, str_concat(", ", str_concat(width_str, str_concat(", ", str_concat(fill_str, ")"))))));
            };
            // Width 0 (precision-only path). Already handled by typed.
            return typed;
        };
    };
    // Unknown / unrecognized spec — recurse into empty-spec dispatcher
    // so type inference picks the right `<type>_to_str`.
    return fmt_conversion_for_spec("", arg_expr, src);
}

#[manual_drop]
fn fmt_build_concat_chain(segments: Vec<i32>, parities: Vec<i32>) -> str {
    // segments[i] alternates between literal text (parity 0) and
    // pre-formed expression (parity 1). Build a right-fold of
    // str_concat(...) with the literals re-quoted.
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
fn fmt_build_expansion(args_text: str, mode: i64, src: str) -> str {
    // mode: 0 = println!  → print(...)
    //       1 = format!   → bare str expression
    //       2 = print!    → print_raw(...)
    //       3 = eprintln! → eprint(...)        v0.5.22
    //       4 = eprint!   → eprint_raw(...)    v0.5.22
    let parts: Vec<i32> = fmt_split_args(args_text);
    // v0.7.43 (defensive halt — Rust named format-arg `format!("{x}",
    // x = 5)`). Pre-fix this surfaced as wrong-class `error[TYP-005]:
    // undefined function 'x()'` because the expander used the literal
    // expression `x = 5` as the value to format, parsed it as an
    // assignment, and `x` was undefined. Detect any arg part matching
    // `<ident>\s*=\s*<expr>` and halt cleanly. (Does NOT fire on `==`
    // / `!=` / `<=` / `>=` because those have a non-`=` second char.)
    let mut v743_idx: i64 = 1;
    while v743_idx < vec_len(parts) {
        let v743_arg: str = vec_get(parts, v743_idx);
        let v743_alen: i64 = str_len(v743_arg);
        let mut v743_ident_start: i64 = 0;
        while v743_ident_start < v743_alen && (str_char_at(v743_arg, v743_ident_start) == 32 || str_char_at(v743_arg, v743_ident_start) == 9) {
            v743_ident_start = v743_ident_start + 1;
        };
        let mut v743_ident_end: i64 = v743_ident_start;
        let mut v743_has_ident: i64 = 0;
        if v743_ident_end < v743_alen {
            let v743_c0: i64 = str_char_at(v743_arg, v743_ident_end);
            if (v743_c0 >= 65 && v743_c0 <= 90) || (v743_c0 >= 97 && v743_c0 <= 122) || v743_c0 == 95 {
                v743_has_ident = 1;
                v743_ident_end = v743_ident_end + 1;
                let mut v743_walk: i64 = 1;
                while v743_walk == 1 && v743_ident_end < v743_alen {
                    let v743_cn: i64 = str_char_at(v743_arg, v743_ident_end);
                    if (v743_cn >= 65 && v743_cn <= 90) || (v743_cn >= 97 && v743_cn <= 122) || (v743_cn >= 48 && v743_cn <= 57) || v743_cn == 95 {
                        v743_ident_end = v743_ident_end + 1;
                    } else {
                        v743_walk = 0;
                    };
                };
            };
        };
        if v743_has_ident == 1 {
            let mut v743_eq_p: i64 = v743_ident_end;
            while v743_eq_p < v743_alen && (str_char_at(v743_arg, v743_eq_p) == 32 || str_char_at(v743_arg, v743_eq_p) == 9) {
                v743_eq_p = v743_eq_p + 1;
            };
            if v743_eq_p < v743_alen && str_char_at(v743_arg, v743_eq_p) == 61 && (v743_eq_p + 1 >= v743_alen || str_char_at(v743_arg, v743_eq_p + 1) != 61) {
                let v743_name: str = str_substring(v743_arg, v743_ident_start, v743_ident_end);
                print(str_concat("ERROR: Rust named format-arg `", str_concat(v743_name, " = <expr>` (e.g. `format!(\"{x}\", x = 5)`) is not yet supported in Nucleor's textual macro layer. Pre-v0.7.43 surfaced as wrong-class `error[TYP-005]: undefined function '<name>()'` because the expander used `x = 5` as the value to format and parsed `x` as an unbound identifier.")));
                print(str_concat("       Workaround: use the explicit-positional form — `format!(\"{}\", ", str_concat(v743_name, ")` (drop the named binding; the value already has a name in the calling scope).")));
                panic(str_concat("nucleor: named format-arg `", str_concat(v743_name, " = ...` not yet supported (see ERROR diagnostic above)")));
            };
        };
        v743_idx = v743_idx + 1;
    };
    if vec_len(parts) == 0 {
        if mode == 0 { return "print(\"\")"; };
        if mode == 1 { return "\"\""; };
        if mode == 3 { return "eprint(\"\")"; };
        if mode == 4 { return "eprint_raw(\"\")"; };
        return "print_raw(\"\")";
    };
    let fmt_lit: str = vec_get(parts, 0);
    let body: str = fmt_strip_outer_quotes(fmt_lit);
    let blen: i64 = str_len(body);
    let n_args: i64 = vec_len(parts) - 1;
    let mut segments: Vec<i32> = Vec::new();
    let mut parities: Vec<i32> = Vec::new();
    let mut current: i64 = sb_new();
    let mut i: i64 = 0;
    let mut arg_idx: i64 = 0;
    while i < blen {
        let c: i64 = str_char_at(body, i);
        if c == 123 && i + 1 < blen && str_char_at(body, i + 1) == 123 {
            sb_append(current, "{");
            i = i + 2;
        } else if c == 125 && i + 1 < blen && str_char_at(body, i + 1) == 125 {
            sb_append(current, "}");
            i = i + 2;
        } else if c == 123 {
            let mut spec_end: i64 = i + 1;
            while spec_end < blen && str_char_at(body, spec_end) != 125 { spec_end = spec_end + 1; };
            if spec_end >= blen {
                sb_append_char_at(current, body, i);
                i = i + 1;
            } else {
                let spec: str = str_substring(body, i + 1, spec_end);
                segments.push(sb_to_str(current));
                parities.push(0);
                current = sb_new();
                if arg_idx < n_args {
                    let arg_expr: str = vec_get(parts, arg_idx + 1);
                    segments.push(fmt_conversion_for_spec(spec, arg_expr, src));
                    parities.push(1);
                    arg_idx = arg_idx + 1;
                } else {
                    // v0.7.41 (defensive halt — Rust 1.58+ inline format-arg
                    // placeholders `{name}` where `name` is an identifier
                    // bound in the caller's scope). Pre-fix this surfaced
                    // as the v0.4.70 generic "more `{}` than args" error
                    // even though the args ARE inline in the format string.
                    // Detect the spec being a bare identifier (no format-
                    // spec colons / dots / commas) and halt with a clear
                    // explicit-arg workaround.
                    // require the first char to be alpha or `_` so
                    // `{0}` / `{1}` (positional-arg refs, a separate Rust
                    // feature) don't collide with the v0.7.41 inline-arg
                    // halt. Digits-only specs are positional references and
                    // get a different diagnostic just below.
                    let mut v741_inline_ident: i64 = 0;
                    if str_len(spec) > 0 {
                        let v741_c0: i64 = str_char_at(spec, 0);
                        if (v741_c0 >= 65 && v741_c0 <= 90) || (v741_c0 >= 97 && v741_c0 <= 122) || v741_c0 == 95 {
                            v741_inline_ident = 1;
                            let mut v741_si: i64 = 1;
                            while v741_si < str_len(spec) && v741_inline_ident == 1 {
                                let v741_c: i64 = str_char_at(spec, v741_si);
                                let v741_is_id_char: i64 = if (v741_c >= 65 && v741_c <= 90) || (v741_c >= 97 && v741_c <= 122) || (v741_c >= 48 && v741_c <= 57) || v741_c == 95 { 1 } else { 0 };
                                if v741_is_id_char == 0 { v741_inline_ident = 0; };
                                v741_si = v741_si + 1;
                            };
                        };
                    };
                    if v741_inline_ident == 1 {
                        print(str_concat("ERROR: Rust 1.58+ inline format-arg `{", str_concat(spec, "}` (where `<name>` resolves to a binding in the calling scope) is not yet supported in Nucleor's textual macro layer. Pre-v0.7.41 surfaced as wrong-class \"format string has more `{}` placeholders than args supplied\".")));
                        print(str_concat("       Workaround: use the explicit-arg form — `format!(\"{}\", ", str_concat(spec, ")` (or `println!`/`print!`/etc.). For multiple inline args, list each as a separate trailing arg in the same order they appear in the format string.")));
                        panic(str_concat("nucleor: inline format-arg `{", str_concat(spec, "}` not yet supported (see ERROR diagnostic above)")));
                    };
                    // v0.7.42 (defensive halt — Rust positional format-arg
                    // `{0}` / `{1}` / etc.). Detect digits-only spec and
                    // halt with an explicit `{}`-only workaround pointer.
                    let mut v742_pos_arg: i64 = if str_len(spec) > 0 { 1 } else { 0 };
                    let mut v742_pi: i64 = 0;
                    while v742_pi < str_len(spec) && v742_pos_arg == 1 {
                        let v742_c: i64 = str_char_at(spec, v742_pi);
                        if v742_c < 48 || v742_c > 57 { v742_pos_arg = 0; };
                        v742_pi = v742_pi + 1;
                    };
                    if v742_pos_arg == 1 {
                        print(str_concat("ERROR: Rust positional format-arg `{", str_concat(spec, "}` (referencing arg #", str_concat(spec, " by index, allowing reuse like `{0} {1} {0}`) is not yet supported in Nucleor's textual macro layer."))));
                        print("       Workaround: write the args linearly in `{}` order — `format!(\"{} {}\", a, b)` instead of `format!(\"{0} {1}\", a, b)`. For repeated refs, write the value once and bind it: `let r = a; format!(\"{} {} {}\", r, b, r)`.");
                        panic(str_concat("nucleor: positional format-arg `{", str_concat(spec, "}` not yet supported (see ERROR diagnostic above)")));
                    };
                    // NUC-FEEDBACK silent-MISSING close (audit
                    // section 10). Pre-fix `println!("{} and {}", 42)`
                    // emitted "42 and <MISSING>" at runtime — silent
                    // wrong output. Halt at preprocess with a clear
                    // hint naming the placeholder count vs arg count.
                    print(str_concat("ERROR: format string has more `{}` placeholders than args supplied. Format body: `", str_concat(body, str_concat("`. Args supplied: ", str_concat(str_from_int(n_args), ". Pre-v0.4.70 missing args were rendered as the literal text `<MISSING>` at runtime.")))));
                    panic("nucleor: format placeholder count > arg count");
                };
                i = spec_end + 1;
            };
        } else {
            sb_append_char_at(current, body, i);
            i = i + 1;
        };
    };
    segments.push(sb_to_str(current));
    parities.push(0);
    // format extra args cannot be silently dropped.
    // Mirror direction of the v0.4.70 placeholder>args check: if the
    // adopter supplied MORE args than `{}` placeholders, the extras
    // would be silently dropped (their evaluation may even have side
    // effects). Halt cleanly with FMT-003 naming the dropped count
    // and the format body.
    if arg_idx < n_args {
        let dropped: i64 = n_args - arg_idx;
        print(str_concat("ERROR: error[FMT-003]: format string has ", str_concat(str_from_int(arg_idx), str_concat(" `{}` placeholder(s) but ", str_concat(str_from_int(n_args), str_concat(" argument(s) supplied; ", str_concat(str_from_int(dropped), str_concat(" extra argument(s) would be silently dropped. Format body: `", str_concat(body, "`. Either add `{}` placeholders for the extras or remove them from the call.")))))))));
        panic("nucleor: FMT-003 format args > placeholders (extras would be silently dropped)");
    };
    let chain: str = fmt_build_concat_chain(segments, parities);
    if mode == 0 { return str_concat("print(", str_concat(chain, ")")); };
    if mode == 1 { return chain; };
    if mode == 3 { return str_concat("eprint(", str_concat(chain, ")")); };
    if mode == 4 { return str_concat("eprint_raw(", str_concat(chain, ")")); };
    //  mode 5 = panic! — pre-fix the textual rewrite stripped `!`
    // and the `panic("got {}", x)` call dropped the args at the runtime
    // helper boundary (panic helper takes a single str). Now route
    // through the same fmt-expansion path as println — the format chain
    // becomes the single str arg to panic().
    if mode == 5 { return str_concat("panic(", str_concat(chain, ")")); };
    return str_concat("print_raw(", str_concat(chain, ")"));
}

#[manual_drop]
fn expand_format_macros(src: str) -> str {
    // Top-level T2.6 entry. At top level, the text being walked IS
    // the type-inference src (the full resolved source bundle).
    return expand_format_macros_with_src(src, src);
}
// nested format!() recursion needs the OUTER source for
// type inference, even when expanding a substring (`args_text`).
// Previously the recursive call passed args_text as both the text
// to process AND the type-inference src -- so an inner Format
// like `format!("nested:{}", inner_str)` couldn't find the
// `let inner_str: str = ...` declaration that lives in the outer
// scope, dispatched as int_to_str default, and printed the str
// pointer.
#[manual_drop]
fn expand_format_macros_with_src(src: str, type_src: str) -> str {
    // Top-level T2.6 entry. Walks the merged source and replaces every
    // `<name>!(...)` macro call (where name is `println`/`print`/`format`)
    // with the desugared expression. Identifier- and quote-aware so a
    // `!` inside a string literal is left alone, and `obj.println!()`
    // (method-call form, currently unsupported anyway) doesn't trip.
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut last_non_ws: i64 = 0;
    while p < slen {
        let c: i64 = str_char_at(src, p);
        if c == 47 && p + 1 < slen && str_char_at(src, p + 1) == 47 {
            while p < slen && str_char_at(src, p) != 10 {
                sb_append_char_at(sb, src, p);
                p = p + 1;
            };
            last_non_ws = 10;
        } else if c == 34 {
            sb_append(sb, "\"");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 34 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "\""); p = p + 1; };
            last_non_ws = 34;
        } else if c == 39 {
            sb_append(sb, "'");
            p = p + 1;
            while p < slen && str_char_at(src, p) != 39 {
                if str_char_at(src, p) == 92 && p + 1 < slen {
                    sb_append_char_at(sb, src, p); sb_append_char_at(sb, src, p + 1);
                    p = p + 2;
                } else {
                    sb_append_char_at(sb, src, p);
                    p = p + 1;
                };
            };
            if p < slen { sb_append(sb, "'"); p = p + 1; };
            last_non_ws = 39;
        } else if is_alpha(c) == 1 || c == 95 {
            let id_start: i64 = p;
            let mut id_done: i64 = 0;
            while p < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, p);
                if is_alnum(ch) == 1 || ch == 95 { p = p + 1; }
                else { id_done = 1; };
            };
            let name: str = str_substring(src, id_start, p);
            let preceded_by_dot: i64 = if last_non_ws == 46 { 1 } else { 0 };
            let mut handled: i64 = 0;
            // strip `!` from `panic!` and `assert!` macro
            // calls. Pre-v0.3.94, `panic!("msg")` was parsed as
            // `panic` (ident) `!` (negate) `("msg")` and the runtime
            // call to __nucleor_panic was never emitted, failing at
            // clang link with `@panic undefined`. Same for assert!.
            // The textual rewrite drops the `!` so the existing fn
            // call dispatch handles them via the regular runtime
            // helpers (already registered as panic / assert at
            // line 2706 / 2635).
            if preceded_by_dot == 0 && p < slen && str_char_at(src, p) == 33 && p + 1 < slen && str_char_at(src, p + 1) == 40 {
                // `panic!` no longer falls through here — it's
                // handled below as mode=5 with format-arg expansion.
                // `unreachable` removed from this strip-and-
                // continue list — the mode-5 path below now expands it
                // to `panic("internal error: entered unreachable code")`.
                // v0.6.76 RFC V1.9
                // canonical Rust `assert!(cond, "fmt {}", arg)` pre-fix
                // stripped `!` and emitted `assert(cond, "fmt {}", arg)`
                // — a 3-arg call to the 1-arg `__nucleor_assert(i64)`
                // helper. Format args dropped, `{}` stayed literal, and
                // assert(cond_truthy=1) silently passed even with broken
                // format args. v0.6.73 attempt regressed cold +1.7s due
                // to per-call comma walking; this ship limits the walk
                // to assert/assert_eq/assert_ne calls only (cheap name
                // gate), and only when 2+ (assert) / 3+ (assert_eq/ne)
                // top-level commas are present (format-arg shape).
                // Rewrite shape:
                //   assert!(c, "fmt", args)   →  if !(c) { panic("fmt-built"); };
                //   assert_eq!(a, b, "fmt", args) →  if !((a) == (b)) { panic("fmt-built"); };
                //   assert_ne!(a, b, "fmt", args) →  if !((a) != (b)) { panic("fmt-built"); };
                // The `panic("fmt-built")` part is built via mode-5
                // fmt_build_expansion — same path panic! mode-5 uses.
                let mut v076_assert_kind: i64 = 0; // 0=not, 1=assert, 2=assert_eq, 3=assert_ne
                if str_eq(name, "assert") == 1 { v076_assert_kind = 1; };
                if str_eq(name, "assert_eq") == 1 { v076_assert_kind = 2; };
                if str_eq(name, "assert_ne") == 1 { v076_assert_kind = 3; };
                if v076_assert_kind > 0 {
                    let v076_probe_start: i64 = p + 2;
                    let mut v076_probe_q: i64 = v076_probe_start;
                    let mut v076_probe_depth: i64 = 1;
                    let mut v076_probe_dq: i64 = 0;
                    let mut v076_probe_sq: i64 = 0;
                    let mut v076_comma1: i64 = 0 - 1;
                    let mut v076_comma2: i64 = 0 - 1;
                    let mut v076_comma3: i64 = 0 - 1;
                    while v076_probe_q < slen && v076_probe_depth > 0 {
                        let v076_pc: i64 = str_char_at(src, v076_probe_q);
                        if v076_probe_dq == 1 {
                            if v076_pc == 92 && v076_probe_q + 1 < slen { v076_probe_q = v076_probe_q + 1; }
                            else if v076_pc == 34 { v076_probe_dq = 0; };
                        } else if v076_probe_sq == 1 {
                            if v076_pc == 92 && v076_probe_q + 1 < slen { v076_probe_q = v076_probe_q + 1; }
                            else if v076_pc == 39 { v076_probe_sq = 0; };
                        } else if v076_pc == 34 { v076_probe_dq = 1; }
                        else if v076_pc == 39 { v076_probe_sq = 1; }
                        else if v076_pc == 40 || v076_pc == 91 || v076_pc == 123 { v076_probe_depth = v076_probe_depth + 1; }
                        else if v076_pc == 41 || v076_pc == 93 || v076_pc == 125 { v076_probe_depth = v076_probe_depth - 1; }
                        else if v076_pc == 44 && v076_probe_depth == 1 {
                            if v076_comma1 < 0 { v076_comma1 = v076_probe_q; }
                            else if v076_comma2 < 0 { v076_comma2 = v076_probe_q; }
                            else if v076_comma3 < 0 { v076_comma3 = v076_probe_q; };
                        };
                        v076_probe_q = v076_probe_q + 1;
                    };
                    let v076_close_paren: i64 = v076_probe_q - 1;
                    let mut v076_have_fmt: i64 = 0;
                    let mut v076_split_pos: i64 = 0 - 1;
                    if v076_assert_kind == 1 && v076_comma2 >= 0 { v076_split_pos = v076_comma1; };
                    if v076_assert_kind > 1 && v076_comma3 >= 0 { v076_split_pos = v076_comma2; };
                    if v076_split_pos > 0 {
                        let mut v076_sk: i64 = v076_split_pos + 1;
                        let mut v076_first_after: i64 = 0;
                        while v076_sk < v076_close_paren && v076_first_after == 0 {
                            let v076_sc: i64 = str_char_at(src, v076_sk);
                            if v076_sc == 32 || v076_sc == 9 || v076_sc == 10 || v076_sc == 13 { v076_sk = v076_sk + 1; }
                            else { v076_first_after = v076_sc; };
                        };
                        if v076_first_after == 34 { v076_have_fmt = 1; };
                    };
                    if v076_have_fmt == 1 && v076_probe_depth == 0 {
                        let v076_fmt_args: str = str_substring(src, v076_split_pos + 1, v076_close_paren);
                        let v076_inner: str = expand_format_macros_with_src(v076_fmt_args, type_src);
                        let v076_panic_call: str = fmt_build_expansion(v076_inner, 5, type_src);
                        if v076_assert_kind == 1 {
                            let v076_cond: str = str_substring(src, v076_probe_start, v076_comma1);
                            sb_append(sb, "if !(");
                            sb_append(sb, v076_cond);
                            sb_append(sb, ") { ");
                            sb_append(sb, v076_panic_call);
                            sb_append(sb, "; }");
                        } else {
                            let v076_lhs: str = str_substring(src, v076_probe_start, v076_comma1);
                            let v076_rhs: str = str_substring(src, v076_comma1 + 1, v076_comma2);
                            let v076_op: str = if v076_assert_kind == 2 { "==" } else { "!=" };
                            sb_append(sb, "if !((");
                            sb_append(sb, v076_lhs);
                            sb_append(sb, ") ");
                            sb_append(sb, v076_op);
                            sb_append(sb, " (");
                            sb_append(sb, v076_rhs);
                            sb_append(sb, ")) { ");
                            sb_append(sb, v076_panic_call);
                            sb_append(sb, "; }");
                        };
                        p = v076_probe_q;
                        last_non_ws = 125;
                        continue;
                    };
                    //  canonical Rust
                    // `assert_eq!(a, b)` / `assert_ne!(a, b)` (no format
                    // args) lower to `__nucleor_assert_eq(i64, i64)` which
                    // does pointer comparison. For str / String / derived-
                    // PartialEq struct values, this silently miscomputes —
                    // equal-content values at different heap addresses
                    // fail/pass incorrectly.
                    // Rewrite the no-fmt case to `if !((a) <op> (b)) {
                    // panic!("assertion failed: ..."); };` so the
                    // existing v0.6.85+v0.6.87 binop kind-4 auto-dispatch
                    // (which routes ==/!= for str/String/derived structs
                    // to the right runtime helper) handles correctness
                    // transparently.
                    if v076_assert_kind > 1 && v076_comma1 >= 0 && v076_comma2 < 0 && v076_probe_depth == 0 {
                        let v088_lhs: str = str_substring(src, v076_probe_start, v076_comma1);
                        let v088_rhs: str = str_substring(src, v076_comma1 + 1, v076_close_paren);
                        let v088_op: str = if v076_assert_kind == 2 { "==" } else { "!=" };
                        let v088_op_word: str = if v076_assert_kind == 2 { "assert_eq" } else { "assert_ne" };
                        sb_append(sb, "if !((");
                        sb_append(sb, v088_lhs);
                        sb_append(sb, ") ");
                        sb_append(sb, v088_op);
                        sb_append(sb, " (");
                        sb_append(sb, v088_rhs);
                        sb_append(sb, ")) { panic(\"");
                        sb_append(sb, v088_op_word);
                        sb_append(sb, "! failed\"); }");
                        p = v076_probe_q;
                        last_non_ws = 125;
                        continue;
                    };
                };
                if str_eq(name, "assert") == 1
                   || str_eq(name, "assert_eq") == 1 || str_eq(name, "assert_ne") == 1
                   || str_eq(name, "dbg") == 1 {
                    sb_append(sb, name);
                    p = p + 1;
                    continue;
                };
                // `todo` and `unimplemented` removed from the
                // strip-and-continue list — they now fall through to mode 5
                // (panic-like) below, which synthesizes the canonical Rust-
                // stdlib messages "not yet implemented" / "not implemented"
                // when called with no args. Pre-fix the strip path produced
                // a `todo()` / `unimplemented()` fn call that failed late
                // with TYP-005 "undefined function" or TYP-026 "missing
                // tail expr" depending on context — both wrong-class.
            };
            // vec![…] macro. Pre-v0.3.99 the lexer split
            // `vec![a, b, c]` as `vec` (ident) + `!` (logical-NOT) +
            // `[a, b, c]` (array-literal). The let-init bound `vec`
            // (an undefined global → clang link error `@vec undefined`)
            // and the array-literal payload became dead code. Rewrite
            // textually to a block expression that constructs a Vec
            // and pushes each element. Empty `vec![]` collapses to
            // `Vec::new()` for cleaner IR. Top-level commas split the
            // arg list; nested (), [], {}, and "/'/' string literals
            // are tracked so `vec![(1,2), [3,4]]` works.
            if preceded_by_dot == 0 && p < slen && str_char_at(src, p) == 33 && p + 1 < slen && str_char_at(src, p + 1) == 91 {
                if str_eq(name, "vec") == 1 {
                    p = p + 2;
                    let lit_start: i64 = p;
                    let mut depth: i64 = 1;
                    let mut q: i64 = lit_start;
                    let mut in_dq: i64 = 0;
                    let mut in_sq: i64 = 0;
                    while q < slen && depth > 0 {
                        let ch: i64 = str_char_at(src, q);
                        if in_dq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 34 { in_dq = 0; };
                        } else if in_sq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 39 { in_sq = 0; };
                        } else if ch == 34 { in_dq = 1; }
                        else if ch == 39 { in_sq = 1; }
                        else if ch == 91 { depth = depth + 1; }
                        else if ch == 93 { depth = depth - 1; };
                        q = q + 1;
                    };
                    if depth == 0 {
                        let lit_end: i64 = q - 1;
                        let inner: str = str_substring(src, lit_start, lit_end);
                        // pass type_src so nested fmt_conversion
                        // type-inference still sees outer-scope declarations.
                        let inner_expanded: str = expand_format_macros_with_src(inner, type_src);
                        let mut all_ws: i64 = 1;
                        let il: i64 = str_len(inner_expanded);
                        let mut ic: i64 = 0;
                        while ic < il {
                            let cw: i64 = str_char_at(inner_expanded, ic);
                            if cw != 32 && cw != 9 && cw != 10 && cw != 13 { all_ws = 0; ic = il; };
                            ic = ic + 1;
                        };
                        if all_ws == 1 {
                            sb_append(sb, "Vec::new()");
                        } else {
                            //  scan for top-level `;`
                            // first — if present, this is the Rust repeat
                            // syntax `vec![X; N]` — emit a while-loop that
                            // pushes X N times. Pre-fix the `;` was treated
                            // as part of the value expression and the count
                            // was silently dropped (`vec![7; 5]` produced a
                            // 1-element vec with value `7;5` parsed weirdly).
                            let mut semi_pos: i64 = 0 - 1;
                            let mut sd_chk: i64 = 0;
                            let mut s_dq_chk: i64 = 0;
                            let mut s_sq_chk: i64 = 0;
                            let mut chk_idx: i64 = 0;
                            while chk_idx < il {
                                let cc_v064: i64 = str_char_at(inner_expanded, chk_idx);
                                if s_dq_chk == 1 {
                                    if cc_v064 == 92 && chk_idx + 1 < il { chk_idx = chk_idx + 1; }
                                    else if cc_v064 == 34 { s_dq_chk = 0; };
                                } else if s_sq_chk == 1 {
                                    if cc_v064 == 92 && chk_idx + 1 < il { chk_idx = chk_idx + 1; }
                                    else if cc_v064 == 39 { s_sq_chk = 0; };
                                } else if cc_v064 == 34 { s_dq_chk = 1; }
                                else if cc_v064 == 39 { s_sq_chk = 1; }
                                else if cc_v064 == 40 || cc_v064 == 91 || cc_v064 == 123 { sd_chk = sd_chk + 1; }
                                else if cc_v064 == 41 || cc_v064 == 93 || cc_v064 == 125 { sd_chk = sd_chk - 1; }
                                else if cc_v064 == 59 && sd_chk == 0 {
                                    semi_pos = chk_idx;
                                    chk_idx = il;
                                };
                                chk_idx = chk_idx + 1;
                            };
                            if semi_pos >= 0 {
                                let val_text: str = str_substring(inner_expanded, 0, semi_pos);
                                let cnt_text: str = str_substring(inner_expanded, semi_pos + 1, il);
                                sb_append(sb, "{ let mut __nuc_vec: Vec<i64> = Vec::new(); let mut __nuc_repeat_i: i64 = 0; let __nuc_repeat_n: i64 = (");
                                sb_append(sb, cnt_text);
                                sb_append(sb, ") as i64; while __nuc_repeat_i < __nuc_repeat_n { __nuc_vec.push(");
                                sb_append(sb, val_text);
                                sb_append(sb, "); __nuc_repeat_i = __nuc_repeat_i + 1; }; __nuc_vec }");
                            } else {
                            sb_append(sb, "{ let mut __nuc_vec: Vec<i64> = Vec::new(); ");
                            let mut sd: i64 = 0;
                            let mut s_dq: i64 = 0;
                            let mut s_sq: i64 = 0;
                            let mut item_start: i64 = 0;
                            let mut idx: i64 = 0;
                            while idx < il {
                                let ch2: i64 = str_char_at(inner_expanded, idx);
                                if s_dq == 1 {
                                    if ch2 == 92 && idx + 1 < il { idx = idx + 1; }
                                    else if ch2 == 34 { s_dq = 0; };
                                } else if s_sq == 1 {
                                    if ch2 == 92 && idx + 1 < il { idx = idx + 1; }
                                    else if ch2 == 39 { s_sq = 0; };
                                } else if ch2 == 34 { s_dq = 1; }
                                else if ch2 == 39 { s_sq = 1; }
                                else if ch2 == 40 || ch2 == 91 || ch2 == 123 { sd = sd + 1; }
                                else if ch2 == 41 || ch2 == 93 || ch2 == 125 { sd = sd - 1; }
                                else if ch2 == 44 && sd == 0 {
                                    let it: str = str_substring(inner_expanded, item_start, idx);
                                    sb_append(sb, "__nuc_vec.push(");
                                    sb_append(sb, it);
                                    sb_append(sb, "); ");
                                    item_start = idx + 1;
                                };
                                idx = idx + 1;
                            };
                            let last_it: str = str_substring(inner_expanded, item_start, il);
                            let lil: i64 = str_len(last_it);
                            let mut last_ws: i64 = 1;
                            let mut lic: i64 = 0;
                            while lic < lil {
                                let cw2: i64 = str_char_at(last_it, lic);
                                if cw2 != 32 && cw2 != 9 && cw2 != 10 && cw2 != 13 { last_ws = 0; lic = lil; };
                                lic = lic + 1;
                            };
                            if last_ws == 0 {
                                sb_append(sb, "__nuc_vec.push(");
                                sb_append(sb, last_it);
                                sb_append(sb, "); ");
                            };
                            sb_append(sb, "__nuc_vec }");
                            };
                        };
                        p = q;
                        last_non_ws = 41;
                        continue;
                    };
                };
            };
            if preceded_by_dot == 0 && p < slen && str_char_at(src, p) == 33 && p + 1 < slen && str_char_at(src, p + 1) == 40 {
                let mut mode: i64 = 0 - 1;
                if str_eq(name, "println") == 1 { mode = 0; };
                if str_eq(name, "format") == 1 { mode = 1; };
                if str_eq(name, "print") == 1 { mode = 2; };
                // eprintln!/eprint! macro forms (probe finding
                // 2026-05-01-eprintln-eprint-macro-falls-through-to-unary-not).
                // Pre-fix these fell through to unary-NOT parsing (`eprintln`
                // ident + `!` + `("...")` — `!` on str failed TYP-002).
                // Now route to eprint(...) / eprint_raw(...) — stderr-bound
                // siblings of println / print.
                if str_eq(name, "eprintln") == 1 { mode = 3; };
                if str_eq(name, "eprint") == 1 { mode = 4; };
                //  mode 5 = panic! — route format args
                // through the same expansion path as println so
                // `panic!("got {}", x)` produces `PANIC: got 7` instead of
                // pre-fix `PANIC: got {}`.
                if str_eq(name, "panic") == 1 { mode = 5; };
                //  row): canonical Rust
                // `unreachable!()` macro pre-fix fell through to the
                // identifier-then-unary-NOT path and emitted `error[TYP-005]:
                // undefined function 'unreachable()'` — wrong-class. Now
                // expand to `panic("internal error: entered unreachable
                // code")` matching Rust's std::macros::unreachable!()
                // implementation. With args (`unreachable!("got: {}", x)`),
                // route through the panic! mode 5 expansion so format
                // args work; without args, synthesize the canonical
                // Rust-stdlib message.
                if str_eq(name, "unreachable") == 1 { mode = 5; };
                // `todo!()` and `unimplemented!()` route through
                // the panic-mode expansion just like `unreachable!()`. The
                // Rust stdlib defines them as panics with canonical messages
                // ("not yet implemented" / "not implemented"). Pre-fix the
                // `!` was stripped silently, the parser saw `todo()` /
                // `unimplemented()` as a fn call, and the user got either
                // wrong-class TYP-005 (undefined fn) or — when the call sat
                // as the last stmt of a non-void fn — wrong-class TYP-026
                // about the missing tail expression.
                if str_eq(name, "todo") == 1 { mode = 5; };
                if str_eq(name, "unimplemented") == 1 { mode = 5; };
                // v0.7.20 (defensive halt — Rust built-in macros NOT supported
                // in Nucleor's textual macro layer: file!/line!/column!/
                // module_path!/stringify!/concat!/env!/option_env!/include_str!/
                // include_bytes!). These need a const-eval pass which Nucleor
                // doesn't have yet. Pre-fix: wrong-class NR020 (zero-arg) or
                // TYP-005 (arg-bearing). v0.7.25: tightened to a single token-
                // boundary string-contains scan + one multi-line message.
                if mode == 0 - 1 && (str_eq(name, "file") == 1 || str_eq(name, "line") == 1 || str_eq(name, "column") == 1 || str_eq(name, "module_path") == 1 || str_eq(name, "stringify") == 1 || str_eq(name, "concat") == 1 || str_eq(name, "env") == 1 || str_eq(name, "option_env") == 1 || str_eq(name, "include_str") == 1 || str_eq(name, "include_bytes") == 1) {
                    print(str_concat("ERROR: Rust built-in macro `", str_concat(name, "!(...)` is not yet supported in Nucleor. These macros need a compile-time evaluation pass that Nucleor doesn't have yet (forward-roadmap).")));
                    print("       Workarounds: file!/line!/column!/module_path!/stringify! → hard-coded literal; concat! → str_concat at runtime or single literal; env!/option_env! → args_get / wrapper script; include_str!/include_bytes! → file_read_string at runtime.");
                    panic(str_concat("nucleor: built-in macro `", str_concat(name, "!(...)` not yet supported (see ERROR diagnostic above)")));
                };
                // v0.8.28 (defensive halt — user-defined / unknown macro
                // invocation `name!(args)` in expression position).
                // Pre-v0.8.28 any unrecognized `name!(args)` fell through
                // the macro expansion pass with the `!` preserved in the
                // output. The token-level parser then saw `name` (identifier)
                // followed by `!` (token 38, unary NOT) applied to `(args)`
                // (i32 / str expression) — producing wrong-class
                // `error[TYP-002]: unary \`!\` requires a \`bool\` operand
                // (got i32)`. This was the observable failure for code like
                // `square!(5)` when `macro_rules! square { ... }` had been
                // declared (but silently dropped — see the companion fix in
                // the module-level macro_rules halt above).
                if mode == 0 - 1 {
                    print(str_concat("ERROR: user-defined or unrecognized macro invocation `", str_concat(name, "!(...)` is not supported in Nucleor. Workaround: rewrite the macro body as a regular fn — replace `name!(arg)` with `name(arg)` and declare `fn name(x: T) -> R { ... }` at module scope. For zero-arg macros like `name!()`, `fn name() -> R { ... }` works directly. Nucleor's metaprogramming substrate is fn-call + the built-in macros (`print!`, `println!`, `format!`, `vec!`, `panic!`, `assert!`, etc.).")));
                    panic(str_concat("nucleor: unknown macro `", str_concat(name, "!(...)` not supported (see ERROR diagnostic above)")));
                };
                if mode >= 0 {
                    p = p + 2;
                    let args_start: i64 = p;
                    let mut depth: i64 = 1;
                    let mut q: i64 = args_start;
                    let mut in_dq: i64 = 0;
                    let mut in_sq: i64 = 0;
                    while q < slen && depth > 0 {
                        let ch: i64 = str_char_at(src, q);
                        if in_dq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 34 { in_dq = 0; };
                        } else if in_sq == 1 {
                            if ch == 92 && q + 1 < slen { q = q + 1; }
                            else if ch == 39 { in_sq = 0; };
                        } else if ch == 34 { in_dq = 1; }
                        else if ch == 39 { in_sq = 1; }
                        else if ch == 40 { depth = depth + 1; }
                        else if ch == 41 { depth = depth - 1; };
                        q = q + 1;
                    };
                    if depth == 0 {
                        let args_end: i64 = q - 1;
                        let mut args_text: str = str_substring(src, args_start, args_end);
                        // empty `unreachable!()` (no args) gets
                        // the canonical Rust-stdlib message. With args
                        // (`unreachable!("...")`) the args pass through
                        // panic-mode expansion as-is.
                        if str_eq(name, "unreachable") == 1 && str_len(args_text) == 0 {
                            args_text = "\"internal error: entered unreachable code\"";
                        };
                        // canonical Rust-stdlib messages for
                        // `todo!()` / `unimplemented!()` when called with
                        // no args (matches std::macros::todo / unimplemented).
                        if str_eq(name, "todo") == 1 && str_len(args_text) == 0 {
                            args_text = "\"not yet implemented\"";
                        };
                        if str_eq(name, "unimplemented") == 1 && str_len(args_text) == 0 {
                            args_text = "\"not implemented\"";
                        };
                        // pass type_src so nested fmt_conversion
                        // type-inference still sees outer-scope declarations.
                        let inner_expanded: str = expand_format_macros_with_src(args_text, type_src);
                        let expansion: str = fmt_build_expansion(inner_expanded, mode, type_src);
                        sb_append(sb, expansion);
                        p = q;
                        last_non_ws = 41;
                        handled = 1;
                    };
                };
            };
            if handled == 0 {
                sb_append(sb, name);
                last_non_ws = str_char_at(name, str_len(name) - 1);
            };
        } else {
            sb_append_char_at(sb, src, p);
            if c != 32 && c != 9 && c != 10 && c != 13 { last_non_ws = c; };
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}

// ===== T1.5c (v0.2.342): resolver-layer name privatization =====
// Opt-in cross-module visibility enforcement. When the resolver
// inlines an imported file F, we scan F for `pub fn` declarations.
// If F has at least one `pub fn`, we identify all NON-pub `fn`
// declarations in F and rewrite their identifier occurrences within
// F's source to `__priv_<file_id>__<name>`. Cross-module callers
// (whose source is NOT rewritten) then find no symbol for the
// private name and fail with an unresolved-name error — which is
// exactly the behavior `pub` is supposed to gate.
// Files with ZERO `pub fn` declarations get NO rewriting (opt-out
// for back-compat with pre-T1.5 rod files that have no `pub`
// markers but whose fns are de-facto callable from any importer).
// The token rewriter is identifier-aware: it skips string literals,
// char literals, and `// ...` line comments, and it does NOT rewrite
// identifiers preceded by `.` (field/method access). Everything else
// is conservative — keywords and shadowed locals are not in the
// private_names list so they're never substituted.

#[manual_drop]
fn priv_extract_fn_decl_info(line: str) -> Vec<i32> {
    // Returns [name, is_pub] where is_pub = 1 for `pub fn name(`
    // (or `pub pure fn name(`), 0 for `fn name(` or `pure fn name(`,
    // and name = "" if line is not an fn declaration whose `(` is
    // on the same line. Uses strip_spaces so `pub  fn  name` etc.
    // all collapse to a stable prefix shape.
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
    // Require a `(` after the name (after stripping); rejects type
    // params like `fn ` followed by something non-callable. After
    // strip_spaces the `(` is always immediately after the name.
    if stop >= clen || str_char_at(compact, stop) != 40 { return out; };
    vec_set(out, 0, str_substring(compact, start, stop));
    vec_set(out, 1, is_pub);
    return out;
}

#[manual_drop]
fn priv_collect_private_fn_names(source: str) -> Vec<i32> {
    // Two-phase scan: first collect all pub fn names, then collect
    // any fn name not in the pub set. Returns the empty Vec if the
    // source has no `pub fn` declarations at all (opt-out signal —
    // files without pub markers stay flat-namespace).
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
            // Don't privatize `main` — entry points should never be
            // mangled even in opt-in files. (Imported files with main
            // are unusual but possible; the compiler's existing
            // remove_main_decl handles dedupe.)
            if str_eq(nm, "main") == 0 { result.push(nm); };
        };
        i = i + 1;
    };
    return result;
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
fn priv_string_vec_contains_at(v: Vec<i32>, src: str, start: i64, end: i64) -> i64 {
    let n: i64 = vec_len(v);
    let want_len: i64 = end - start;
    let mut i: i64 = 0;
    while i < n {
        let cur: str = vec_get(v, i);
        if str_len(cur) == want_len && str_eq_at_len(src, start, cur, want_len) == 1 { return 1; };
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
fn priv_build_global_registry(imported: Vec<i32>) -> Vec<i32> {
    // T1.5d (v0.2.343): build a flat registry of all private fn
    // names across every imported file. Returned shape is
    // alternating pairs [name1, origin_path1, name2, origin_path2, ...]
    // so the post-link diagnostic step can map an undefined-symbol
    // error back to its origin module without re-scanning sources.
    // Re-reads each imported file (small cost, O(imports)) rather
    // than threading the registry through the resolver — keeps the
    // existing resolve_source signature stable.
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
fn priv_lift_link_errors(clang_output: str, reg: Vec<i32>) -> i64 {
    // Scan clang's stderr/stdout for "use of undefined value '@<name>'"
    // patterns. For each match whose <name> appears in the private
    // registry, emit a friendly MOD-003 diagnostic identifying the
    // origin module and suggesting `pub`. Returns the count of MOD-003
    // diagnostics emitted (so the caller can decide whether to suppress
    // the raw clang noise).
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
fn lift_undefined_fn_link_errors(clang_output: str, reg: Vec<i32>) -> i64 {
    // companion to priv_lift_link_errors. After MOD-003 has
    // claimed every privatization-related undefined symbol, this fn
    // scans the clang output for any REMAINING `use of undefined
    // value '@<name>'` matches and emits a clean TYP-005 error
    // for each true-undefined fn (typo, missing import, etc.).
    // Pre-fix v0.4.60 emitted TYP-005 at WARNING tier at type-check
    // time, then let clang fail with its cryptic
    //   target/foo.ll:850:23: error: use of undefined value '@bar'
    // line, leaving the user reading clang IR diagnostics. Now the
    // user gets a single readable line:
    //   error[TYP-005]: undefined function `bar()`. Check spelling
    //   or import the rod that defines it.
    // Skips compiler-generated names (`__closure_*`, `__vec_*`,
    // privatization-mangled `__priv_*`, etc.) and uppercase-leading
    // names (Type-prefixed variants — those go through their own
    // unresolved-type diagnostic path). Returns count emitted so
    // the caller can decide whether to suppress the raw clang dump.
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
            // Skip if MOD-003 already claimed it.
            let claimed_by_mod003: i64 = if str_len(priv_lookup_origin(reg, name)) > 0 { 1 } else { 0 };
            // Skip compiler-generated names (same filters as the
            // type-check warn path in type_expr kind 7).
            let clen: i64 = str_len(name);
            let mut suppress: i64 = 0;
            if claimed_by_mod003 == 1 { suppress = 1; };
            if suppress == 0 && clen >= 2 && str_char_at(name, 0) == 95 && str_char_at(name, 1) == 95 {
                suppress = 1;
            };
            if suppress == 0 && clen >= 1 {
                let c0: i64 = str_char_at(name, 0);
                if c0 >= 65 && c0 <= 90 { suppress = 1; };
            };
            if suppress == 0 && priv_string_vec_contains(seen, name) == 0 {
                seen.push(name);
                // detect synthetic `vec_<method>` names that
                // come from method-call dispatch fall-through (e.g.
                // user wrote `v.lenn()` for a Vec, the kind 8 catch-all
                // lowered to `vec_lenn(v)`). Show the user the actual
                // source-side method name with a Vec-method hint
                // instead of the confusing internal `vec_<method>`.
                if clen > 4 && str_char_at(name, 0) == 118
                    && str_char_at(name, 1) == 101
                    && str_char_at(name, 2) == 99
                    && str_char_at(name, 3) == 95 {
                    let user_method: str = str_substring(name, 4, clen);
                    //  if the user wrote fn-form
                    // `vec_<method>(&v, …)` AND `<method>` is one of the
                    // supported Vec method families, the existing diag
                    // misled — it said `no method .<method>()` even though
                    // the method DOES exist via the proper dispatch path.
                    // Detect the supported-method case and emit a fn-form-
                    // vs-method-form diag instead. The unsupported-method
                    // case still gets the original "no method" diag.
                    let mut um_supported: i64 = 0;
                    if str_eq(user_method, "contains") == 1 || str_eq(user_method, "push") == 1
                        || str_eq(user_method, "pop") == 1 || str_eq(user_method, "len") == 1
                        || str_eq(user_method, "get") == 1 || str_eq(user_method, "set") == 1
                        || str_eq(user_method, "first") == 1 || str_eq(user_method, "last") == 1
                        || str_eq(user_method, "is_empty") == 1 || str_eq(user_method, "insert_at") == 1
                        || str_eq(user_method, "remove_at") == 1 || str_eq(user_method, "iter") == 1
                        || str_eq(user_method, "map") == 1 || str_eq(user_method, "filter") == 1
                        || str_eq(user_method, "fold") == 1 || str_eq(user_method, "each") == 1
                        || str_eq(user_method, "sum") == 1 || str_eq(user_method, "min") == 1
                        || str_eq(user_method, "max") == 1 || str_eq(user_method, "index_of") == 1
                        || str_eq(user_method, "reverse") == 1 || str_eq(user_method, "sort") == 1
                        || str_eq(user_method, "clone") == 1 || str_eq(user_method, "clear") == 1 {
                        um_supported = 1;
                    };
                    if um_supported == 1 {
                        print(str_concat("error[TYP-005]: `vec_", str_concat(user_method, "(...)` is not a top-level fn — use the method form `vec.", str_concat(user_method, "(&value)` instead. The method-dispatch path resolves to the correct type-specific runtime helper (e.g. `__nucleor_vec_", str_concat(user_method, "_i64` for `Vec<i64>`); the bare fn-form bypasses that dispatch.")))));
                        print(str_concat("                Pre-v0.6.40 the diag said `no method .", str_concat(user_method, "()`, which was misleading — the method exists, only the fn-form does not.")));
                    } else {
                        print(str_concat("error[TYP-005]: receiver type `Vec<T>` has no method `.", str_concat(user_method, "()`. (Internal symbol: `vec_")));
                        print(str_concat("                ", str_concat(user_method, "`. The kind-8 method-dispatch catch-all lowered the call to a synthetic helper that doesn't exist.)")));
                        print("                Supported Vec method families: push, pop, len, get, set, first, last, is_empty, insert (insert_at), remove (remove_at), iter, map, filter, fold, each, sum, min, max, contains, index_of, reverse, sort, clone, clear, collect, count, take, skip, any, all, chain, position, product, step_by, nth, reduce.");
                    };
                } else {
                    // Lane 3 (F-DIAG-011): the pre-fix message tail
                    // claimed "type-checker emitted a TYP-005 warning
                    // earlier in this build" — false in v1.0 (the
                    // type-checker has no undefined-callee diagnostic;
                    // the only TYP-005 emit for unbound idents was
                    // this link-stage one, see F-DIAG-016). Drop the
                    // misleading parenthetical until the type-checker
                    // pre-link emit is wired (F-DIAG-016 owner).
                    print(str_concat("error[TYP-005]: undefined function `", str_concat(name, "()`. Check spelling, or import the rod that defines it. (raised at clang link.)")));
                };
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
fn lift_no_main_link_error(clang_output: str) -> i64 {
    // companion to lift_undefined_fn_link_errors. Catches
    // the no-main-fn link error class. Pre-fix a `.nr` file with no
    // `fn main` failed at clang link with the cryptic Windows
    // `LINK : fatal error LNK1561: entry point must be defined` /
    // POSIX `undefined reference to ...main` lines that adopters
    // had to know meant "your program has no entry point". Emits a
    // single readable NR022 error before suppressing the raw clang
    // dump. Returns 1 if it lifted, 0 otherwise.
    let win_marker: str = "LNK1561";
    let win_marker_lld: str = "subsystem must be defined";
    let posix_marker_a: str = "undefined reference to `main'";
    let posix_marker_b: str = "undefined reference to `_main'";
    let posix_marker_c: str = "Undefined symbols for architecture";
    let mut hit: i64 = 0;
    if str_contains(clang_output, win_marker) == 1 { hit = 1; };
    if hit == 0 && str_contains(clang_output, win_marker_lld) == 1 { hit = 1; };
    if hit == 0 && str_contains(clang_output, posix_marker_a) == 1 { hit = 1; };
    if hit == 0 && str_contains(clang_output, posix_marker_b) == 1 { hit = 1; };
    if hit == 0 && str_contains(clang_output, posix_marker_c) == 1 && str_contains(clang_output, "_main") == 1 { hit = 1; };
    if hit == 0 { return 0; };
    print("error[NR022]: no `fn main()` defined in this build unit. Nucleor expects every binary build to have a `fn main() -> i32` entry point. Either add one (`fn main() -> i32 { 0 }`), or build the file as part of a larger program that already has main, or use `nuc check` if you only want to type-check without linking.");
    return 1;
}

#[manual_drop]
fn priv_apply_if_opted_in(isrc: str, path: str) -> str {
    // Resolver's entry point into T1.5c privatization. Returns the
    // input source unchanged unless the file has at least one
    // `pub fn` (the opt-in trigger). Caller pipes the returned
    // source straight into resolve_source_with_records — the
    // mangling has already happened, so the recursive resolver
    // call sees only mangled identifiers and won't re-mangle.
    let private_names: Vec<i32> = priv_collect_private_fn_names(isrc);
    if vec_len(private_names) == 0 { return isrc; };
    let file_id: str = content_hash(path);
    return priv_mangle_private_fns(isrc, file_id, private_names);
}

#[manual_drop]
fn priv_mangle_private_fns(src: str, file_id: str, private_names: Vec<i32>) -> str {
    // Token-aware identifier substitution. Walks src char-by-char,
    // identifies identifier tokens (alpha/_ followed by alnum/_),
    // and rewrites identifiers whose value is in private_names to
    // __priv_<file_id>__<name>. Skips: "..." string literals,
    // 'X' char literals, // ... line comments. Does NOT rewrite
    // identifiers preceded by `.` (field/method access).
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut priv_pos: i64 = 0;
    let mut last_non_ws: i64 = 0;
    while priv_pos < slen {
        let c: i64 = str_char_at(src, priv_pos);
        if c == 47 && priv_pos + 1 < slen && str_char_at(src, priv_pos + 1) == 47 {
            // // line comment — copy through to newline
            let comment_start: i64 = priv_pos;
            while priv_pos < slen && str_char_at(src, priv_pos) != 10 { priv_pos = priv_pos + 1; };
            sb_append_range(sb, src, comment_start, priv_pos);
            last_non_ws = 10;
        } else if c == 34 {
            // double-quoted string literal — copy with backslash escapes
            let str_start: i64 = priv_pos;
            priv_pos = priv_pos + 1;
            while priv_pos < slen && str_char_at(src, priv_pos) != 34 {
                if str_char_at(src, priv_pos) == 92 && priv_pos + 1 < slen {
                    priv_pos = priv_pos + 2;
                } else {
                    priv_pos = priv_pos + 1;
                };
            };
            if priv_pos < slen { priv_pos = priv_pos + 1; };
            sb_append_range(sb, src, str_start, priv_pos);
            last_non_ws = 34;
        } else if c == 39 {
            // single-quoted char literal
            let char_start: i64 = priv_pos;
            priv_pos = priv_pos + 1;
            while priv_pos < slen && str_char_at(src, priv_pos) != 39 {
                if str_char_at(src, priv_pos) == 92 && priv_pos + 1 < slen {
                    priv_pos = priv_pos + 2;
                } else {
                    priv_pos = priv_pos + 1;
                };
            };
            if priv_pos < slen { priv_pos = priv_pos + 1; };
            sb_append_range(sb, src, char_start, priv_pos);
            last_non_ws = 39;
        } else if is_alpha(c) == 1 || c == 95 {
            // Identifier start — gather to the end and decide whether
            // to mangle. Also reject: numeric prefixes (handled
            // because is_alpha rejects digits; identifiers can't
            // start with digit) and identifiers preceded by `.`
            // (struct field / method access).
            let start: i64 = priv_pos;
            let mut id_done: i64 = 0;
            while priv_pos < slen && id_done == 0 {
                let ch: i64 = str_char_at(src, priv_pos);
                if is_alnum(ch) == 1 || ch == 95 { priv_pos = priv_pos + 1; }
                else { id_done = 1; };
            };
            let preceded_by_dot: i64 = if last_non_ws == 46 { 1 } else { 0 };
            if preceded_by_dot == 0 && priv_string_vec_contains_at(private_names, src, start, priv_pos) == 1 {
                sb_append(sb, "__priv_");
                sb_append(sb, file_id);
                sb_append(sb, "__");
                sb_append_range(sb, src, start, priv_pos);
            } else {
                sb_append_range(sb, src, start, priv_pos);
            };
            last_non_ws = str_char_at(src, priv_pos - 1);
        } else {
            sb_append_char_at(sb, src, priv_pos);
            // Track last non-whitespace so we can detect `.X` field
            // accesses through intervening whitespace too.
            if c != 32 && c != 9 && c != 10 && c != 13 { last_non_ws = c; };
            priv_pos = priv_pos + 1;
        };
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn content_hash(s: str) -> str {
    // DJB2 hash → hex string (simple content fingerprint)
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
fn cmd_accepts_source(cmd: str) -> i64 {
    if str_eq(cmd, "build") || str_eq(cmd, "build-fast") || str_eq(cmd, "build-strict") || str_eq(cmd, "build-shared") || str_eq(cmd, "run") || str_eq(cmd, "emit") || str_eq(cmd, "build-wasm") || str_eq(cmd, "build-ptx") || str_eq(cmd, "check") || str_eq(cmd, "audit") || str_eq(cmd, "policy") || str_eq(cmd, "certify") || str_eq(cmd, "translate") || str_eq(cmd, "test") || str_eq(cmd, "bench") || str_eq(cmd, "summary") || str_eq(cmd, "impact") || str_eq(cmd, "query") || str_eq(cmd, "graph") || str_eq(cmd, "perf") || str_eq(cmd, "evidence") || str_eq(cmd, "abi") || str_eq(cmd, "verify-reproducible") {
        return 1;
    };
    return 0;
}

#[manual_drop]
fn cmd_allows_output_name(cmd: str) -> i64 {
    if str_eq(cmd, "build") || str_eq(cmd, "build-fast") || str_eq(cmd, "build-strict") || str_eq(cmd, "build-shared") || str_eq(cmd, "run") || str_eq(cmd, "emit") || str_eq(cmd, "build-wasm") || str_eq(cmd, "build-ptx") || str_eq(cmd, "certify") || str_eq(cmd, "test") || str_eq(cmd, "bench") || str_eq(cmd, "verify-reproducible") {
        return 1;
    };
    return 0;
}

#[manual_drop]
fn manifest_entry_path() -> str {
    let raw: str = file_read_string("Nucleor.toml");
    if str_len(raw) == 0 { return ""; };
    let compact: str = strip_spaces(raw);
    let key: str = "entry=\"";
    let clen: i64 = str_len(compact);
    let klen: i64 = str_len(key);
    let mut p: i64 = 0;
    while p + klen <= clen {
        if str_eq_at_len(compact, p, key, klen) == 1 {
            let start: i64 = p + klen;
            let mut end: i64 = start;
            while end < clen && str_char_at(compact, end) != 34 { end = end + 1; };
            return sanitize(str_substring(compact, start, end));
        };
        p = p + 1;
    };
    return "";
}

#[manual_drop]
fn core_shell_quote(path: str) -> str {
    return str_concat("\"", str_concat(path, "\""));
}
#[manual_drop]
fn run_external_tool(argc: i64) -> i64 {
    let raw_exe_dir: str = trim_trailing_sep(extract_dir(posix_drive_to_windows(args_get(0))));
    let mut exe_dir: str = raw_exe_dir;
    if str_len(exe_dir) == 0 { exe_dir = "target"; };
    let tool_name: str = str_concat("nucleor_tools", host_exe_suffix());
    let tool_path: str = host_shell_path(sanitize(str_concat(str_concat(exe_dir, host_target_path_sep()), tool_name)));
    let repo_tool_path: str = host_shell_path(str_concat(str_concat(".\\target", host_target_path_sep()), tool_name));
    let repo_bin_tool_path: str = host_shell_path(str_concat(str_concat(".\\bin", host_target_path_sep()), tool_name));
    // prefix local fallback with `.\` (Windows) / `./` (POSIX)
    // so cmd.exe / sh resolve unambiguously against the current dir even
    // when the file isn't on PATH. Pre-fix on Windows, the bare quoted
    // `"nucleor_tools.exe"` failed cmd.exe's command-search and the
    // sandbox-local CLI smokes (nuc test/lock/doc) cmd.exe-error'd with
    // `'"nucleor_tools.exe"' is not recognized`.
    let local_tool_path: str = host_shell_path(str_concat(if host_is_windows() == 1 { ".\\" } else { "./" }, tool_name));
    let mut tool_args: str = "";
    let mut i: i64 = 1;
    while i < argc {
        tool_args = str_concat(tool_args, str_concat(" ", core_shell_quote(args_get(i))));
        i = i + 1;
    };
    let mut selected: str = tool_path;
    if fs_exists(repo_tool_path) == 1 { selected = repo_tool_path; }
    else if fs_exists(repo_bin_tool_path) == 1 { selected = repo_bin_tool_path; }
    else if fs_exists(local_tool_path) == 1 { selected = local_tool_path; };
    if fs_exists(selected) == 0 {
        print(str_concat("ERROR: cannot find required tools-suite binary: ", tool_name));
        print("       rebuild with: nuc build compiler/nucleor_tools_suite.nr -o nucleor_tools --no-cache");
        return 1;
    };
    let selected_cmd: str = core_shell_quote(selected);
    let cmd: str = if host_is_windows() == 1 {
        let cwd_shell: str = host_shell_path(posix_drive_to_windows(getcwd()));
        str_concat("pushd ", str_concat(core_shell_quote(cwd_shell), str_concat(" && ", str_concat(selected_cmd, tool_args))))
    } else {
        str_concat(selected_cmd, tool_args)
    };
    return system(cmd);
}

#[manual_drop]
fn run_explain_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_bootstrap_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_stage_dump_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_build_shared_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_summary_command(src_path: str, argc: i64, arg_start: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_query_command(src_path: str) -> i64 { return run_external_tool(args_count()); }
#[manual_drop]
fn run_abi_command(src_path: str, argc: i64, arg_start: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_evidence_command(src_path: str) -> i64 { return run_external_tool(args_count()); }
#[manual_drop]
fn run_lock_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_publish_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_registry_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_install_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_fix_command(argc: i64) -> i64 { return run_external_tool(argc); }

// tools registry subcommand. Distinct from
// `nuc install` (which is RFC-0019 phase-4 package management for
// stdlib rods). `nuc tools install <url>` downloads a published
// Nucleor-distributed tool binary, extracts it under $NUC_HOME/tools/
// <name>/, and writes a shim script in $NUC_HOME/bin/.
// v1 minimal scope:
//   nuc tools install <github_release_url>  [--no-verify]
//   nuc tools uninstall <name>
//   nuc tools list
//   nuc tools home          (print resolved $NUC_HOME for diagnostics)
// Direct-URL install (no central registry yet -- that's v2). Cosign
// verify is opt-in for v1; required-by-default once we publish a
// registry. Network ops shell out to curl (ubiquitous on Windows
// since 1803 and on every Unix). Extraction shells out to tar (for
// .tar.gz) or PowerShell Expand-Archive (for .zip on Windows).
#[manual_drop]
fn nuc_home_path() -> str {
    let explicit: str = env_get_or("NUC_HOME", "");
    if str_len(explicit) > 0 { return explicit; };
    // Windows: %LOCALAPPDATA%\Nucleor
    let lad: str = env_get_or("LOCALAPPDATA", "");
    if str_len(lad) > 0 { return str_concat(lad, "\\Nucleor"); };
    // Unix: $HOME/.nucleor
    let home: str = env_get_or("HOME", "");
    if str_len(home) > 0 { return str_concat(home, "/.nucleor"); };
    // Last-resort fallback
    return ".nucleor";
}

#[manual_drop]
fn tools_home() -> str {
    let h: str = nuc_home_path();
    return str_concat(h, "/tools");
}

#[manual_drop]
fn tools_bin() -> str {
    let h: str = nuc_home_path();
    return str_concat(h, "/bin");
}

#[manual_drop]
fn tools_basename_from_url(url: str) -> str {
    // Strip everything from the first ? or # onward (URL query/fragment).
    let mut end: i64 = str_len(url);
    let mut q: i64 = 0;
    while q < end {
        let c: i64 = str_char_at(url, q);
        if c == 63 || c == 35 { end = q; q = end; };
        q = q + 1;
    };
    // Walk backward from `end` to find the last `/` or `\` -- the basename
    // starts at the next char after that separator (or at 0 if none).
    let mut start: i64 = 0;
    let mut k: i64 = end - 1;
    while k >= 0 {
        let c: i64 = str_char_at(url, k);
        if c == 47 || c == 92 { start = k + 1; k = 0 - 1; };
        k = k - 1;
    };
    let raw: str = str_substring(url, start, end);
    // Strip common archive suffixes (longest match first).
    if str_ends_with(raw, ".tar.gz") == 1 { return str_substring(raw, 0, str_len(raw) - 7); };
    if str_ends_with(raw, ".tgz") == 1 { return str_substring(raw, 0, str_len(raw) - 4); };
    if str_ends_with(raw, ".zip") == 1 { return str_substring(raw, 0, str_len(raw) - 4); };
    if str_ends_with(raw, ".exe") == 1 { return str_substring(raw, 0, str_len(raw) - 4); };
    return raw;
}

#[manual_drop]
fn tools_print_help() -> i64 {
    print("Usage: nuc tools <subcommand>");
    print("");
    print("Subcommands:");
    print("  install <url> [--no-verify]   Download + extract a tool from a release URL");
    print("  uninstall <name>              Remove an installed tool");
    print("  list                          List installed tools");
    print("  home                          Print resolved $NUC_HOME");
    print("");
    print("Tools install under $NUC_HOME/tools/<name>/ and a shim is written to");
    print("$NUC_HOME/bin/<name>.cmd (Windows) or $NUC_HOME/bin/<name> (Unix).");
    print("Add $NUC_HOME/bin to PATH once and any tool installed via this command");
    print("becomes invokable as <name> in any shell.");
    print("");
    print("Default $NUC_HOME: %LOCALAPPDATA%\\Nucleor (Windows) or $HOME/.nucleor (Unix).");
    print("Override via the NUC_HOME env var.");
    return 0;
}

#[manual_drop]
fn tools_install(url: str, verify: i64) -> i64 {
    if str_len(url) == 0 {
        print("ERROR: nuc tools install requires a URL");
        return 1;
    };
    let name: str = tools_basename_from_url(url);
    if str_len(name) == 0 {
        print(str_concat("ERROR: cannot derive a tool name from URL: ", url));
        return 1;
    };
    let home: str = nuc_home_path();
    let tdir: str = str_concat(tools_home(), str_concat("/", name));
    let bdir: str = tools_bin();
    print(str_concat("nuc tools install: name = ", name));
    print(str_concat("                   url  = ", url));
    print(str_concat("                   dest = ", tdir));
    // Make dirs (mkdir -p style; use Windows-compatible commands).
    system(str_concat("powershell -NoProfile -Command \"New-Item -ItemType Directory -Force -Path '", str_concat(tdir, "' | Out-Null\"")));
    system(str_concat("powershell -NoProfile -Command \"New-Item -ItemType Directory -Force -Path '", str_concat(bdir, "' | Out-Null\"")));
    // Download via curl. curl is bundled with Windows 1803+ and every Unix.
    let archive: str = str_concat(tdir, "/.download");
    let curl_cmd: str = str_concat("curl -fsSL -o \"", str_concat(archive, str_concat("\" \"", str_concat(url, "\""))));
    print(str_concat("  fetching: curl -fsSL ", url));
    let dl_rc: i64 = system(curl_cmd);
    if dl_rc != 0 {
        print(str_concat("ERROR: download failed (curl rc=", str_concat(str_from_int(dl_rc), ")")));
        return 1;
    };
    if verify == 1 {
        // v1: cosign optional. If cosign is on PATH, run it; if not, warn.
        print("  verifying: cosign verify-blob (production releases must add this)");
        print("  NOTE: v1 of `nuc tools install` is opt-in cosign. Skipping verify for now.");
        print("        See RFC-NRT-002 for the v2 mandatory-verify roadmap.");
    } else {
        print("  verifying: SKIPPED (--no-verify)");
    };
    // Extract: detect by suffix.
    if str_ends_with(url, ".zip") == 1 {
        print(str_concat("  extracting: Expand-Archive -> ", tdir));
        let ext_cmd: str = str_concat("powershell -NoProfile -Command \"Expand-Archive -Path '", str_concat(archive, str_concat("' -DestinationPath '", str_concat(tdir, "' -Force\""))));
        let ext_rc: i64 = system(ext_cmd);
        if ext_rc != 0 {
            print(str_concat("ERROR: extraction failed (rc=", str_concat(str_from_int(ext_rc), ")")));
            return 1;
        };
    } else {
        if str_ends_with(url, ".tar.gz") == 1 || str_ends_with(url, ".tgz") == 1 {
            print(str_concat("  extracting: tar -xzf -> ", tdir));
            let ext_cmd: str = str_concat("tar -xzf \"", str_concat(archive, str_concat("\" -C \"", str_concat(tdir, "\""))));
            let ext_rc: i64 = system(ext_cmd);
            if ext_rc != 0 {
                print(str_concat("ERROR: extraction failed (rc=", str_concat(str_from_int(ext_rc), ")")));
                return 1;
            };
        } else {
            // Single-file binary install (e.g., .exe). Move into place.
            print(str_concat("  installing: single-file binary -> ", tdir));
            let mv_cmd: str = str_concat("powershell -NoProfile -Command \"Move-Item -Force -Path '", str_concat(archive, str_concat("' -Destination '", str_concat(tdir, str_concat("/", str_concat(name, ".exe' \""))))));
            let mv_rc: i64 = system(mv_cmd);
            if mv_rc != 0 {
                print(str_concat("ERROR: install failed (rc=", str_concat(str_from_int(mv_rc), ")")));
                return 1;
            };
        };
    };
    // Write shim. Look for <name>.exe first under the tdir; fallback to plain <name>.
    let target_exe: str = str_concat(tdir, str_concat("/", str_concat(name, ".exe")));
    let target_bin: str = str_concat(tdir, str_concat("/", name));
    let mut shim_target: str = "";
    if str_len(file_read_string(target_exe)) > 0 || str_ends_with(url, ".exe") == 1 {
        shim_target = target_exe;
    } else {
        shim_target = target_bin;
    };
    let shim_path: str = str_concat(bdir, str_concat("/", str_concat(name, ".cmd")));
    let shim_body: str = str_concat("@echo off\r\n\"", str_concat(shim_target, "\" %*\r\n"));
    let wr_rc: i64 = file_write_string(shim_path, shim_body);
    if wr_rc < 0 {
        print(str_concat("ERROR: failed to write shim at ", shim_path));
        return 1;
    };
    print(str_concat("  shim:   ", shim_path));
    print(str_concat("  target: ", shim_target));
    print("");
    print(str_concat("Installed `", str_concat(name, "`.")));
    print(str_concat("Add `", str_concat(bdir, "` to PATH (once) and run `", str_concat(name, " --version` from any shell."))));
    return 0;
}

#[manual_drop]
fn tools_uninstall(name: str) -> i64 {
    if str_len(name) == 0 {
        print("ERROR: nuc tools uninstall requires a tool name");
        return 1;
    };
    let tdir: str = str_concat(tools_home(), str_concat("/", name));
    let shim: str = str_concat(tools_bin(), str_concat("/", str_concat(name, ".cmd")));
    print(str_concat("nuc tools uninstall: ", name));
    print(str_concat("  removing: ", tdir));
    system(str_concat("powershell -NoProfile -Command \"Remove-Item -Recurse -Force -Path '", str_concat(tdir, "' -ErrorAction SilentlyContinue\"")));
    print(str_concat("  removing: ", shim));
    system(str_concat("powershell -NoProfile -Command \"Remove-Item -Force -Path '", str_concat(shim, "' -ErrorAction SilentlyContinue\"")));
    print(str_concat("Uninstalled `", str_concat(name, "`.")));
    return 0;
}

#[manual_drop]
fn tools_list() -> i64 {
    let tdir: str = tools_home();
    print(str_concat("Tools installed under ", tdir));
    // PowerShell list: any subdirectory under tools/.
    let cmd: str = str_concat("powershell -NoProfile -Command \"if (Test-Path '", str_concat(tdir, "') { Get-ChildItem -Directory '"));
    let cmd2: str = str_concat(cmd, str_concat(tdir, "' | ForEach-Object { '  ' + $_.Name } } else { '  (none -- tools home does not exist yet)' }\""));
    system(cmd2);
    return 0;
}

#[manual_drop]
fn run_tools_command(argc: i64) -> i64 {
    if argc < 3 {
        return tools_print_help();
    };
    let sub: str = args_get(2);
    if str_eq(sub, "help") || str_eq(sub, "--help") || str_eq(sub, "-h") {
        return tools_print_help();
    };
    if str_eq(sub, "home") {
        print(nuc_home_path());
        return 0;
    };
    if str_eq(sub, "list") {
        return tools_list();
    };
    if str_eq(sub, "uninstall") {
        if argc < 4 {
            print("ERROR: nuc tools uninstall requires a tool name");
            return 1;
        };
        return tools_uninstall(args_get(3));
    };
    if str_eq(sub, "install") {
        if argc < 4 {
            print("ERROR: nuc tools install requires a URL");
            return 1;
        };
        let url: str = args_get(3);
        let mut verify: i64 = 1;
        let mut i: i64 = 4;
        while i < argc {
            if str_eq(args_get(i), "--no-verify") == 1 { verify = 0; };
            i = i + 1;
        };
        return tools_install(url, verify);
    };
    print(str_concat("ERROR: unknown nuc tools subcommand: ", sub));
    return tools_print_help();
}
#[manual_drop]
fn run_doc_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_impact_command(src_path: str, argc: i64, arg_start: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_graph_command(src_path: str, argc: i64, arg_start: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_profile_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_sage_command(argc: i64) -> i64 { return run_external_tool(argc); }
#[manual_drop]
fn run_perf_command(src_path: str, argc: i64, arg_start: i64) -> i64 { return run_external_tool(argc); }

// T1.1 Phase 9: map a Nucleor type name to its C equivalent for
// header generation. Returns "" for types without a clear C
// mapping (caller skips those extern decls).
#[manual_drop]
fn nr_type_to_c(t: str) -> str {
    let b: str = type_base_name(t);
    if str_eq(b, "i8") == 1 { return "int8_t"; };
    if str_eq(b, "i16") == 1 { return "int16_t"; };
    if str_eq(b, "i32") == 1 { return "int32_t"; };
    if str_eq(b, "i64") == 1 { return "int64_t"; };
    if str_eq(b, "isize") == 1 { return "intptr_t"; };
    if str_eq(b, "u8") == 1 { return "uint8_t"; };
    if str_eq(b, "u16") == 1 { return "uint16_t"; };
    if str_eq(b, "u32") == 1 { return "uint32_t"; };
    if str_eq(b, "u64") == 1 { return "uint64_t"; };
    if str_eq(b, "usize") == 1 { return "uintptr_t"; };
    if str_eq(b, "f32") == 1 { return "float"; };
    if str_eq(b, "f64") == 1 { return "double"; };
    if str_eq(b, "bool") == 1 { return "bool"; };
    if str_eq(b, "char") == 1 { return "uint32_t"; };
    if str_eq(b, "ptr") == 1 { return "void*"; };
    if str_eq(b, "str") == 1 { return "const char*"; };
    if str_eq(b, "void") == 1 { return "void"; };
    return "";
}

#[manual_drop]
fn nr_type_to_c_with_structs(t: str, repr_c_structs: Vec<i32>) -> str {
    // T1.6 (v0.2.345): C ABI struct-by-value support. If the type
    // name matches a known #[repr(C)] struct, emit the struct name
    // directly so callers get the typedef; otherwise fall through to
    // the primitive table. Returns "" for non-repr(C) struct names
    // (caller emits CXX-004 — types crossing the bridge must have a
    // C-stable layout).
    let primitive: str = nr_type_to_c(t);
    if str_len(primitive) > 0 { return primitive; };
    let b: str = type_base_name(t);
    let n: i64 = vec_len(repr_c_structs);
    let mut i: i64 = 0;
    while i < n {
        if str_eq(vec_get(repr_c_structs, i), b) == 1 { return b; };
        i = i + 1;
    };
    return "";
}

#[manual_drop]
fn collect_repr_c_structs(src: str) -> Vec<i32> {
    // T1.6 (v0.2.345): walk the source text identifying every
    // struct declaration whose IMMEDIATELY-preceding non-blank
    // line (skipping doc-comments and whitespace) is exactly
    // `#[repr(C)]`. Strict line-precedence rules out the
    // lookback false-positive in `struct_repr`, where a 200-char
    // window happily picked up the previous struct's attribute.
    // Returns a Vec<str> of struct names (no duplicates).
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    // Pre-pass: build line offsets so we can look at the previous
    // non-blank line cheaply.
    let mut line_starts: Vec<i32> = Vec::new();
    line_starts.push(0);
    let mut s: i64 = 0;
    while s < slen {
        if str_char_at(src, s) == 10 && s + 1 < slen { line_starts.push(s + 1); };
        s = s + 1;
    };
    let nlines: i64 = vec_len(line_starts);
    let mut li: i64 = 0;
    while li < nlines {
        let p: i64 = vec_get(line_starts, li);
        let next_p: i64 = if li + 1 < nlines { vec_get(line_starts, li + 1) - 1 } else { slen };
        let mut eol: i64 = if next_p < slen { next_p } else { slen };
        // strip trailing CR if present (CRLF tolerant)
        if eol > p && str_char_at(src, eol - 1) == 13 { eol = eol - 1; };
        let line: str = str_substring(src, p, eol);
        let llen: i64 = str_len(line);
        let mut lp: i64 = 0;
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        // Match `struct NAME` (optionally `pub struct NAME`)
        let mut after_kw: i64 = 0 - 1;
        if lp + 7 <= llen && str_eq_at(line, lp, "struct ") == 1 { after_kw = lp + 7; };
        if after_kw < 0 && lp + 11 <= llen && str_eq_at(line, lp, "pub struct ") == 1 { after_kw = lp + 11; };
        if after_kw >= 0 {
            let name_start: i64 = after_kw;
            let mut q: i64 = name_start;
            while q < llen && (is_alnum(str_char_at(line, q)) == 1 || str_char_at(line, q) == 95) { q = q + 1; };
            if q > name_start {
                let name: str = str_substring(line, name_start, q);
                // Look back at preceding non-blank, non-/// lines
                // until we either find an attribute or hit something
                // that decisively isn't an attribute (struct decl,
                // closing brace, source start).
                let mut prev_li: i64 = li - 1;
                let mut found: i64 = 0;
                while prev_li >= 0 && found == 0 {
                    let pp: i64 = vec_get(line_starts, prev_li);
                    let mut pend: i64 = if prev_li + 1 < nlines { vec_get(line_starts, prev_li + 1) - 1 } else { slen };
                    if pend > pp && str_char_at(src, pend - 1) == 13 { pend = pend - 1; };
                    let pline: str = str_substring(src, pp, pend);
                    let trimmed: str = strip_spaces(pline);
                    if str_len(trimmed) == 0 {
                        prev_li = prev_li - 1;
                    } else if str_len(trimmed) >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                        prev_li = prev_li - 1;
                    } else if str_eq(trimmed, "#[repr(C)]") == 1 {
                        found = 1;
                    } else {
                        // Anything else terminates the lookback —
                        // attribute didn't apply to this struct.
                        prev_li = 0 - 1;
                    };
                };
                if found == 1 {
                    let mut already: i64 = 0;
                    let mut k: i64 = 0;
                    while k < vec_len(out) {
                        if str_eq(vec_get(out, k), name) == 1 { already = 1; };
                        k = k + 1;
                    };
                    if already == 0 { out.push(name); };
                };
            };
        };
        li = li + 1;
    };
    return out;
}

#[manual_drop]
fn extract_struct_fields_native(src: str, struct_name: str) -> Vec<i32> {
    // T1.6 (v0.2.345): pull the field list of a struct as alternating
    // [name1, type1, name2, type2, ...]. Uses brace-balanced source
    // scanning starting at the `struct NAME {` declaration. Returns
    // empty Vec if the struct is missing or syntactically malformed.
    let mut out: Vec<i32> = Vec::new();
    let needle: str = str_concat("struct ", struct_name);
    let pos: i64 = source_find(src, needle);
    if pos < 0 { return out; };
    let slen: i64 = str_len(src);
    let mut p: i64 = pos + str_len(needle);
    while p < slen && str_char_at(src, p) != 123 { p = p + 1; };
    if p >= slen { return out; };
    p = p + 1;
    let mut depth: i64 = 1;
    let body_start: i64 = p;
    let mut body_end: i64 = p;
    while p < slen && depth > 0 {
        let ch: i64 = str_char_at(src, p);
        if ch == 123 { depth = depth + 1; }
        else if ch == 125 { depth = depth - 1; if depth == 0 { body_end = p; }; };
        p = p + 1;
    };
    if depth != 0 { return out; };
    // Walk fields: `name: type,` (commas optional after last)
    let body: str = str_substring(src, body_start, body_end);
    let blen: i64 = str_len(body);
    let mut q: i64 = 0;
    while q < blen {
        // skip whitespace
        while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9 || str_char_at(body, q) == 10 || str_char_at(body, q) == 13) { q = q + 1; };
        if q >= blen { q = blen + 1; }
        else {
            // skip optional `pub ` field-visibility prefix
            if q + 4 <= blen && str_eq_at(body, q, "pub ") == 1 { q = q + 4; };
            while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9) { q = q + 1; };
            // field name
            let name_start: i64 = q;
            while q < blen && (is_alnum(str_char_at(body, q)) == 1 || str_char_at(body, q) == 95) { q = q + 1; };
            if q == name_start { q = blen + 1; }
            else {
                let fname: str = str_substring(body, name_start, q);
                while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9) { q = q + 1; };
                if q >= blen || str_char_at(body, q) != 58 { q = blen + 1; }
                else {
                    q = q + 1;
                    while q < blen && (str_char_at(body, q) == 32 || str_char_at(body, q) == 9) { q = q + 1; };
                    let type_start: i64 = q;
                    while q < blen && str_char_at(body, q) != 44 && str_char_at(body, q) != 10 { q = q + 1; };
                    let ftype: str = strip_spaces(str_substring(body, type_start, q));
                    if str_len(fname) > 0 && str_len(ftype) > 0 {
                        out.push(fname);
                        out.push(ftype);
                    };
                    if q < blen && str_char_at(body, q) == 44 { q = q + 1; };
                };
            };
        };
    };
    return out;
}

// T3.4 (v0.3.4): collect Nucleor fns marked `#[export]` so
// `nuc gen-headers` emits C forward declarations alongside the
// `extern fn` imports and `#[repr(C)]` typedefs. Lets external
// C/C++ code (robotics middleware, embedded firmware) call into
// Nucleor-compiled kernels through the unmangled symbol that
// the LLVM IR already emits.
// Returns alternating [fn_name, args_c_decl, c_rtype, ...].
// args_c_decl is the C-formatted parameter list ("int64_t a, double b")
// or "void" for no-args; c_rtype is "void" if the fn has no `-> ret`.
// Skips fns whose signature contains a non-FFI-safe type.
#[manual_drop]
fn collect_export_fns_and_sigs(src: str, repr_c: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(src);
    let mut line_starts: Vec<i32> = Vec::new();
    line_starts.push(0);
    let mut s: i64 = 0;
    while s < slen {
        if str_char_at(src, s) == 10 && s + 1 < slen { line_starts.push(s + 1); };
        s = s + 1;
    };
    let nlines: i64 = vec_len(line_starts);
    let mut li: i64 = 0;
    while li < nlines {
        let p: i64 = vec_get(line_starts, li);
        let mut eol: i64 = if li + 1 < nlines { vec_get(line_starts, li + 1) - 1 } else { slen };
        if eol > p && str_char_at(src, eol - 1) == 13 { eol = eol - 1; };
        let line: str = str_substring(src, p, eol);
        let llen: i64 = str_len(line);
        let mut lp: i64 = 0;
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        let mut after_kw: i64 = 0 - 1;
        if lp + 3 <= llen && str_eq_at(line, lp, "fn ") == 1 { after_kw = lp + 3; };
        if after_kw < 0 && lp + 7 <= llen && str_eq_at(line, lp, "pub fn ") == 1 { after_kw = lp + 7; };
        if after_kw >= 0 {
            // Look back at preceding non-blank, non-/// lines for #[export].
            let mut prev_li: i64 = li - 1;
            let mut found: i64 = 0;
            while prev_li >= 0 && found == 0 {
                let pp: i64 = vec_get(line_starts, prev_li);
                let mut pend: i64 = if prev_li + 1 < nlines { vec_get(line_starts, prev_li + 1) - 1 } else { slen };
                if pend > pp && str_char_at(src, pend - 1) == 13 { pend = pend - 1; };
                let pline: str = str_substring(src, pp, pend);
                let trimmed: str = strip_spaces(pline);
                let tlen: i64 = str_len(trimmed);
                if tlen == 0 {
                    prev_li = prev_li - 1;
                } else if tlen >= 3 && str_eq(str_substring(trimmed, 0, 3), "///") == 1 {
                    prev_li = prev_li - 1;
                } else if str_eq(trimmed, "#[export]") == 1 {
                    found = 1;
                } else if tlen >= 1 && str_char_at(trimmed, 0) == 35 {
                    // Other #[...] attribute (e.g. #[no_alloc], #[deadline]) — skip
                    prev_li = prev_li - 1;
                } else {
                    prev_li = 0 - 1;
                };
            };
            if found == 1 {
                // Read fn name.
                let name_start: i64 = after_kw;
                let mut q: i64 = name_start;
                while q < llen && (is_alnum(str_char_at(line, q)) == 1 || str_char_at(line, q) == 95) { q = q + 1; };
                if q > name_start {
                    let fname: str = str_substring(line, name_start, q);
                    // Expect (
                    while q < llen && str_char_at(line, q) != 40 { q = q + 1; };
                    if q < llen {
                        q = q + 1;
                        // Collect args until ).
                        let mut args_buf: i64 = sb_new();
                        let mut narg: i64 = 0;
                        let mut bad: i64 = 0;
                        while q < llen && str_char_at(line, q) != 41 && bad == 0 {
                            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9 || str_char_at(line, q) == 44) { q = q + 1; };
                            if q >= llen || str_char_at(line, q) == 41 { continue; };
                            let an_start: i64 = q;
                            while q < llen && str_char_at(line, q) != 58 && str_char_at(line, q) != 41 { q = q + 1; };
                            let an_raw: str = str_substring(line, an_start, q);
                            if q >= llen || str_char_at(line, q) != 58 { bad = 1; continue; };
                            q = q + 1;
                            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
                            let at_start: i64 = q;
                            while q < llen && str_char_at(line, q) != 44 && str_char_at(line, q) != 41 { q = q + 1; };
                            let at_raw: str = str_substring(line, at_start, q);
                            let arg_name: str = strip_spaces(an_raw);
                            let arg_type: str = strip_spaces(at_raw);
                            let c_type: str = nr_type_to_c_with_structs(arg_type, repr_c);
                            if str_len(c_type) == 0 { bad = 1; continue; };
                            if narg > 0 { sb_append(args_buf, ", "); };
                            sb_append(args_buf, c_type);
                            sb_append(args_buf, " ");
                            sb_append(args_buf, arg_name);
                            narg = narg + 1;
                        };
                        if bad == 0 {
                            if q < llen { q = q + 1; };
                            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
                            let mut rtype: str = "void";
                            if q + 1 < llen && str_char_at(line, q) == 45 && str_char_at(line, q + 1) == 62 {
                                q = q + 2;
                                while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
                                let rt_start: i64 = q;
                                while q < llen && str_char_at(line, q) != 32 && str_char_at(line, q) != 9 && str_char_at(line, q) != 123 { q = q + 1; };
                                rtype = str_substring(line, rt_start, q);
                            };
                            let c_rtype: str = nr_type_to_c_with_structs(rtype, repr_c);
                            if str_len(c_rtype) > 0 {
                                let args_str: str = if narg == 0 { "void" } else { sb_to_str(args_buf) };
                                out.push(fname);
                                out.push(args_str);
                                out.push(c_rtype);
                            };
                        };
                    };
                };
            };
        };
        li = li + 1;
    };
    return out;
}

// T1.1 Phase 9: nuc gen-headers <input.nr> [-o <out.h>]
// Scans an .nr source file for `extern fn` declarations and emits a
// matching C header. Useful for cross-language linking when an
// external C/C++ project wants to call Nucleor-compiled functions
// (or vice-versa) through a stable ABI.
// Implementation is a deliberate text-scan rather than a full
// parser invocation: keeps the subcommand standalone, lets it
// run on partial / not-yet-compilable .nr files, and matches
// the file-line convention used by the rest of the toolchain.
#[manual_drop]
fn run_gen_headers_command(argc: i64) -> i64 {
    if argc < 3 {
        print("usage: nuc gen-headers <input.nr> [-o <out.h>]");
        return 1;
    };
    let in_path: str = args_get(2);
    let mut out_path: str = "";
    let mut i: i64 = 3;
    while i < argc {
        let a: str = args_get(i);
        if str_eq(a, "-o") == 1 && (i + 1) < argc {
            out_path = args_get(i + 1);
            i = i + 2;
        } else {
            i = i + 1;
        };
    };
    if str_len(out_path) == 0 {
        // Default: replace .nr with .h
        let plen: i64 = str_len(in_path);
        if plen > 3 && str_eq_at(in_path, plen - 3, ".nr") == 1 {
            out_path = str_concat(str_substring(in_path, 0, plen - 3), ".h");
        } else {
            out_path = str_concat(in_path, ".h");
        };
    };
    let src: str = file_read_string(in_path);
    if str_len(src) == 0 {
        print(str_concat("nuc gen-headers: cannot read ", in_path));
        return 1;
    };
    let mut out: i64 = sb_new();
    sb_append(out, "// Generated by `nuc gen-headers` from ");
    sb_append(out, in_path);
    sb_append(out, "\n// Edits will be lost; regenerate after extern fn / #[repr(C)] struct changes.\n");
    sb_append(out, "#ifndef NUCLEOR_GEN_HEADERS_H\n");
    sb_append(out, "#define NUCLEOR_GEN_HEADERS_H\n");
    sb_append(out, "#include <stdint.h>\n");
    sb_append(out, "#include <stdbool.h>\n\n");
    sb_append(out, "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n");

    // T1.6 (v0.2.345): emit C `typedef struct { ... } Name;`
    // declarations for every #[repr(C)] struct in the source.
    // Field types must be primitives or other repr(C) struct names —
    // otherwise we silently skip the offending field rather than
    // emit an invalid C declaration. CXX-004 fires elsewhere (in
    // strict-mode build) when a non-repr(C) struct appears in an
    // extern fn signature.
    let repr_c: Vec<i32> = collect_repr_c_structs(src);
    let mut emitted_structs: i64 = 0;
    let mut si: i64 = 0;
    while si < vec_len(repr_c) {
        let sname: str = vec_get(repr_c, si);
        let fields: Vec<i32> = extract_struct_fields_native(src, sname);
        let fc: i64 = vec_len(fields);
        if fc >= 2 {
            sb_append(out, "typedef struct ");
            sb_append(out, sname);
            sb_append(out, " {\n");
            let mut fi: i64 = 0;
            while fi + 1 < fc {
                let fname: str = vec_get(fields, fi);
                let ftype: str = vec_get(fields, fi + 1);
                let ftype_c: str = nr_type_to_c_with_structs(ftype, repr_c);
                if str_len(ftype_c) > 0 {
                    sb_append(out, "    ");
                    sb_append(out, ftype_c);
                    sb_append(out, " ");
                    sb_append(out, fname);
                    sb_append(out, ";\n");
                };
                fi = fi + 2;
            };
            sb_append(out, "} ");
            sb_append(out, sname);
            sb_append(out, ";\n\n");
            emitted_structs = emitted_structs + 1;
        };
        si = si + 1;
    };

    // Walk source line by line for `extern fn NAME(...) -> RT;`
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut emitted: i64 = 0;
    while p < slen {
        // Find end of line.
        let line_start: i64 = p;
        while p < slen && str_char_at(src, p) != 10 { p = p + 1; };
        let line: str = str_substring(src, line_start, p);
        if p < slen { p = p + 1; };
        // Skip leading whitespace for prefix check.
        let llen: i64 = str_len(line);
        let mut lstart: i64 = 0;
        while lstart < llen && (str_char_at(line, lstart) == 32 || str_char_at(line, lstart) == 9) {
            lstart = lstart + 1;
        };
        // Match prefix "extern fn ".
        if lstart + 10 > llen { continue; };
        if str_eq_at(line, lstart, "extern fn ") == 0 { continue; };
        // Parse the line.
        let mut q: i64 = lstart + 10;
        // name
        let name_start: i64 = q;
        while q < llen && (str_char_at(line, q) == 95 || is_alnum(str_char_at(line, q)) == 1) { q = q + 1; };
        let fname: str = str_substring(line, name_start, q);
        if str_len(fname) == 0 { continue; };
        // expect (
        while q < llen && str_char_at(line, q) != 40 { q = q + 1; };
        if q >= llen { continue; };
        q = q + 1; // past (
        // collect args until )
        let mut args_buf: i64 = sb_new();
        let mut narg: i64 = 0;
        let mut bad_arg: i64 = 0;
        while q < llen && str_char_at(line, q) != 41 {
            // skip whitespace, comma
            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9 || str_char_at(line, q) == 44) { q = q + 1; };
            if q >= llen || str_char_at(line, q) == 41 { continue; };
            // arg name
            let an_start: i64 = q;
            while q < llen && str_char_at(line, q) != 58 && str_char_at(line, q) != 41 { q = q + 1; };
            let an_raw: str = str_substring(line, an_start, q);
            if q >= llen || str_char_at(line, q) != 58 { bad_arg = 1; q = llen; continue; };
            q = q + 1; // past :
            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
            let at_start: i64 = q;
            while q < llen && str_char_at(line, q) != 44 && str_char_at(line, q) != 41 { q = q + 1; };
            let at_raw: str = str_substring(line, at_start, q);
            // trim trailing whitespace
            let arg_name: str = strip_spaces(an_raw);
            let arg_type: str = strip_spaces(at_raw);
            // T1.6 (v0.2.345): struct-by-value FFI — accept any
            // #[repr(C)] struct name (already collected above).
            let c_type: str = nr_type_to_c_with_structs(arg_type, repr_c);
            if str_len(c_type) == 0 { bad_arg = 1; continue; };
            if narg > 0 { sb_append(args_buf, ", "); };
            sb_append(args_buf, c_type);
            sb_append(args_buf, " ");
            sb_append(args_buf, arg_name);
            narg = narg + 1;
        };
        if bad_arg == 1 { continue; };
        if q < llen { q = q + 1; }; // past )
        // expect "-> RTYPE;"
        let mut rtype: str = "void";
        while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
        if q + 1 < llen && str_char_at(line, q) == 45 && str_char_at(line, q + 1) == 62 {
            q = q + 2;
            while q < llen && (str_char_at(line, q) == 32 || str_char_at(line, q) == 9) { q = q + 1; };
            let rt_start: i64 = q;
            while q < llen && str_char_at(line, q) != 59 && str_char_at(line, q) != 32 && str_char_at(line, q) != 9 { q = q + 1; };
            rtype = str_substring(line, rt_start, q);
        };
        let c_rtype: str = nr_type_to_c_with_structs(rtype, repr_c);
        if str_len(c_rtype) == 0 { continue; };
        sb_append(out, c_rtype);
        sb_append(out, " ");
        sb_append(out, fname);
        sb_append(out, "(");
        if narg == 0 { sb_append(out, "void"); }
        else { sb_append(out, sb_to_str(args_buf)); };
        sb_append(out, ");\n");
        emitted = emitted + 1;
    };
    // T3.4 (v0.3.4): emit C decls for `#[export]`-marked Nucleor
    // fns. The LLVM IR already uses the unmangled symbol so the
    // header is the only missing piece for C-side callers.
    let exports: Vec<i32> = collect_export_fns_and_sigs(src, repr_c);
    let exn: i64 = vec_len(exports);
    let mut emitted_exports: i64 = 0;
    let mut ei: i64 = 0;
    if exn >= 3 {
        sb_append(out, "// === #[export] — Nucleor fns callable from C ===\n");
    };
    while ei + 2 < exn {
        let xn: str = vec_get(exports, ei);
        let xa: str = vec_get(exports, ei + 1);
        let xr: str = vec_get(exports, ei + 2);
        sb_append(out, xr);
        sb_append(out, " ");
        sb_append(out, xn);
        sb_append(out, "(");
        sb_append(out, xa);
        sb_append(out, ");\n");
        emitted_exports = emitted_exports + 1;
        ei = ei + 3;
    };
    sb_append(out, "\n#ifdef __cplusplus\n}\n#endif\n");
    sb_append(out, "#endif // NUCLEOR_GEN_HEADERS_H\n");
    let _ = file_write_string(out_path, sb_to_str(out));
    let extern_count: str = str_from_int(emitted);
    let export_count: str = str_from_int(emitted_exports);
    if emitted_structs > 0 {
        print(str_concat("nuc gen-headers: wrote ", str_concat(str_from_int(emitted_structs), str_concat(" #[repr(C)] struct(s), ", str_concat(extern_count, str_concat(" extern decl(s), ", str_concat(export_count, str_concat(" #[export] decl(s) to ", out_path))))))));
    } else {
        print(str_concat("nuc gen-headers: wrote ", str_concat(extern_count, str_concat(" extern decl(s), ", str_concat(export_count, str_concat(" #[export] decl(s) to ", out_path))))));
    };
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
fn run_clean_command(argc: i64) -> i64 {
    let mut cache_only: i64 = 0;
    let mut i: i64 = 2;
    while i < argc {
        if str_eq(args_get(i), "--cache") == 1 { cache_only = 1; };
        i = i + 1;
    };
    if cache_only == 1 {
        print("clean: removing compilation cache (target/.nuc_cache_v2/, .nuc_cache/)");
        host_remove_dir_quiet(str_concat("target", str_concat(host_target_path_sep(), ".nuc_cache_v2")));
        host_remove_dir_quiet(".nuc_cache");
        print("clean: done");
        return 0;
    };
    print("clean: removing build artifacts (target/, .nuc_cache/)");
    host_remove_dir_quiet("target");
    host_remove_dir_quiet(".nuc_cache");
    print("clean: done");
    return 0;
}

#[manual_drop]
fn print_help() -> i64 {
    print(str_concat("Nucleor Compiler ", compiler_version_label()));
    print("The governance-native programming language");
    print("");
    print("Usage: nuc <command> [source.nr] [options]");
    print("");
    print("Build commands:");
    print("  init [name]            Scaffold a project with Nucleor.toml");
    print("  build [file]           Compile to native binary (ownership + type, cached)");
    print("  build-fast [file]      Alias of the fast core compile path");
    print("  build-strict [file]    Compile through the full delegated strict checker stack");
    print("  build-shared [file]    Compile a shared library (.dll/.lib) from `pub fn` exports");
    print("  run [file]             Compile and run");
    print("  emit [file]            Emit LLVM IR only (alias for --no-link)");
    print("  build-wasm [file]      Compile to WebAssembly (.wasm)");
    print("  build-ptx [file]       Compile to NVIDIA PTX (.ptx)");
    print("  verify-reproducible [file]  Build twice with --no-cache and assert byte-identical IR (RFC-NRT-003)");
    print("    --provenance <path>  Embed a SLSA JSON attestation in the .nucprov section (RFC-NRT-001)");
    print("    -o, --out <name>     Set output base name");
    print("    --emit llvm          Keep the LLVM IR artifact");
    print("    --no-link            Stop after writing target/<name>.ll");
    print("    --time-passes        Print per-phase compile timings");
    print("    --no-cache           Disable resolved-source and content-addressed LLVM caches");
    print("    --cache-stats        Print cache hit/miss counters for this build");
    print("");
    print("Developer commands:");
    print("  test [file]            Build and run @test / test_* functions");
    print("    --list               List discovered tests without running them");
    print("    --check-laws         Generate bounded checks for low-risk integer @law annotations");
    print("  bench [file]           Build once and benchmark repeated runs");
    print("    --iterations <n>     Number of measured runs (default 10)");
    print("    --warmup <n>         Number of warmup runs before timing (default 1)");
    print("  perf [file]            Compile-path performance analysis");
    print("    --json               Output machine-readable perf data");
    print("  bootstrap [subcmd]     Self-host bootstrap status / corpus report");
    print("    status               Report example and runtime readiness");
    print("    dump-corpus          List .nr corpus files");
    print("    --json               Output machine-readable bootstrap data");
    print("  stage-dump <stage>     Dump compiler stage summaries");
    print("    tokens|ast|typed|ir|all");
    print("  summary [file]         Compact module interface card");
    print("    --json               Output summary lines as JSON");
    print("  query [file]           Machine-readable module interface");
    print("  abi [file]             Inspect import/export ABI for C / Rust interop");
    print("    --exports            Inspect `pub fn` export ABI instead of imports");
    print("    --json               Output machine-readable ABI data");
    print("    --c-header           Emit C declarations for the selected ABI surface");
    print("    --rust-extern        Emit Rust unsafe extern declarations for the selected ABI surface");
    print("  evidence [file]        Governance evidence report");
    print("  impact [file] <fn>     Reverse call impact for a function");
    print("    --fn <name>          Specify the target function");
    print("  graph [file]           Source-level call/effect graph");
    print("    --json               Output machine-readable graph data");
    print("  doc [file]             Render /// + //! doc comments as Markdown or HTML (RFC-0029)");
    print("    --out <file>         Write to file instead of stdout");
    print("    --html               Emit standalone HTML (auto-detected from .html / .htm --out)");
    print("    --test-list          Enumerate ```nucleor code blocks for doc-test discoverability");
    print("  profile run <binary>   Timed binary execution profile");
    print("    --iterations <n>     Repeat the profile run N times");
    print("  lock [manifest]        Write Nucleor.lock for local/workspace manifests");
    print("    --json               Output machine-readable lock status");
    print("  install [alias] <pkg>  Add a path or registry dependency and refresh Nucleor.lock");
    print("  publish [manifest]     Copy a package into a local registry directory");
    print("    --registry <dir>     Registry root (default: .nucleor/registry)");
    print("  registry [subcmd]      List/search/inspect packages in a local registry");
    print("    list|search|versions|verify");
    print("  sage <subcmd> <file>   Sage_NS prove / certificate / gap checks");
    print("    prove|certificate|gaps");
    print("");
    print("Analysis commands:");
    print("  check [file] [flags]   Run all checkers and report diagnostics");
    print("    --json               Output JSONL diagnostics");
    print("    --sarif              Output SARIF v2.1.0");
    print("    --check=<checkers>   Run specific checkers (ownership,type,source,taint,effect)");
    print("    --review             Enable review surface (nucleor_review.jsonl)");
    print("    --review-filter=<f>  Filter: findings, function=<name>, <checker>");
    print("  explain <CODE>         Explain a compiler error code (e.g. NR031, OWN-G4-USE-AFTER-DROP)");
    print("    --json               Output a JSON explanation object");
    print("");
    print("Governance commands:");
    print("  audit [file]           Provenance and governance report");
    print("  policy [file] [level]  Policy compliance (default, no_extern, no_system, strict)");
    print("  certify [file]         Compile + produce certification manifest");
    print("  translate [file]       Parse, validate, and summarize source");
    print("");
    print("Project utilities:");
    print("  clean                  Remove target/ and .nuc_cache/ from the project");
    print("  clean --cache          Remove target/.nuc_cache_v2/ and .nuc_cache/ only");
    print("  scram                  Alias for `clean` (emergency shutdown of build state)");
    print("  fix [--imports|--numeric] [file]  Migration linters (RFC-0015 / RFC-0018)");
    print("  gen-headers <input.nr> [-o <out.h>]  Emit C decls for #[export] / #[repr(C)] (RFC-0011)");
    print("  zen                    The design principles of Nucleor");
    print("  mco                    Mars Climate Orbiter - why we ship dimensional analysis");
    print("");
    print("Project mode:");
    print("  If [file] is omitted and ./Nucleor.toml exists, [build].entry is used.");
    print("");
    print("Legacy: nuc <source.nr> <output_name>");
    return 0;
}

// top-level entry point. Heap-backed locals
// are short-lived dispatch scratch. Annotated as safety guardrail.
#[manual_drop]
fn main() -> i64 {
    let argc: i64 = args_count();
    if argc < 2 {
        print_help();
        return 1;
    };
    let cmd: str = args_get(1);
    // --version and help
    if str_eq(cmd, "--version") || str_eq(cmd, "-v") || str_eq(cmd, "-V") || str_eq(cmd, "version") {
        print(compiler_identity());
        return 0;
    };
    if str_eq(cmd, "help") || str_eq(cmd, "--help") || str_eq(cmd, "-h") {
        print_help();
        return 0;
    };
    if str_eq(cmd, "explain") {
        return run_explain_command(argc);
    };
    // v0.8.150 V1.16 Phase A0 — `--lsp-mode` flag stub.
    // SPEC-LSP-server.md calls for ~600 LOC subprocess-mode LSP
    // daemon. Phase A0 wires the flag and emits the server-
    // capabilities advertisement as JSON-on-stdout so editor
    // extensions can probe what's supported. Phase A1 (real LSP
    // base protocol with Content-Length-framed JSON-RPC) is the
    // follow-on ship — needs raw stdin byte reads added to the
    // io_rt surface first.
    if str_eq(cmd, "--lsp-mode") {
        print("{\"server\":\"nucleor-lsp\",\"version\":\"v0.8.150\",\"phase\":\"A0\",\"capabilities\":{\"textDocumentSync\":{\"openClose\":true,\"change\":1},\"diagnosticProvider\":{\"interFileDependencies\":false,\"workspaceDiagnostics\":false},\"hoverProvider\":false,\"definitionProvider\":false,\"completionProvider\":{\"triggerCharacters\":[\".\"]},\"codeActionProvider\":true,\"documentFormattingProvider\":true},\"phaseA0\":\"capabilities-advertisement-only; real LSP base protocol lands in Phase A1 (needs raw stdin byte-read primitive)\"}");
        return 0;
    };
    if str_eq(cmd, "bootstrap") {
        return run_bootstrap_command(argc);
    };
    if str_eq(cmd, "stage-dump") {
        return run_stage_dump_command(argc);
    };
    if str_eq(cmd, "build-shared") {
        return run_build_shared_command(argc);
    };
    if str_eq(cmd, "lock") {
        return run_lock_command(argc);
    };
    if str_eq(cmd, "install") {
        return run_install_command(argc);
    };
    if str_eq(cmd, "tools") {
        return run_tools_command(argc);
    };
    // RFC-0019 phase 4: ergonomic aliases over `nuc install`. The full
    // `nuc add` / `nuc remove` / `nuc update` semantics (resolver-driven
    // version bumps + lock refresh) land with the v0.5 registry; today
    // they share the install code path.
    if str_eq(cmd, "add") {
        return run_install_command(argc);
    };
    if str_eq(cmd, "remove") {
        return run_install_command(argc);
    };
    if str_eq(cmd, "update") {
        return run_install_command(argc);
    };
    if str_eq(cmd, "publish") {
        return run_publish_command(argc);
    };
    if str_eq(cmd, "registry") {
        return run_registry_command(argc);
    };
    if str_eq(cmd, "fix") {
        return run_fix_command(argc);
    };
    if str_eq(cmd, "doc") {
        return run_doc_command(argc);
    };
    if str_eq(cmd, "gen-headers") {
        return run_gen_headers_command(argc);
    };
    if str_eq(cmd, "profile") {
        return run_profile_command(argc);
    };
    if str_eq(cmd, "sage") {
        return run_sage_command(argc);
    };
    if str_eq(cmd, "zen") {
        return run_zen_command();
    };
    if str_eq(cmd, "mco") {
        return run_mco_command();
    };
    if str_eq(cmd, "clean") || str_eq(cmd, "scram") {
        return run_clean_command(argc);
    };
    if str_eq(cmd, "init") {
        // nuc init [name] — scaffold a new project. Use the
        // cross-platform fs_create_dir_all builtin instead of
        // shell-out so the Windows-only backslash separator
        // doesn't silently no-op on Linux/macOS (was R3 in the
        // 8C transcript: file_write_string for src/main.nr
        // panicked because src/ never got created on POSIX).
        let mut proj_name: str = "myproject";
        if argc >= 3 { proj_name = args_get(2); };
        fs_create_dir_all(proj_name);
        fs_create_dir_all(str_concat(proj_name, "/src"));
        fs_create_dir_all(str_concat(proj_name, "/target"));
        // Write Nucleor.toml
        let toml: str = str_concat("[package]\nname = \"", str_concat(proj_name, "\"\nversion = \"0.1.0\"\n\n[build]\nentry = \"src/main.nr\"\n"));
        file_write_string(str_concat(proj_name, "/Nucleor.toml"), toml);
        // Write main.nr
        file_write_string(str_concat(proj_name, "/src/main.nr"), "fn main() -> i64 {\n    print(\"Hello, Nucleor!\");\n    return 0;\n}\n");
        print(str_concat("  Created project: ", proj_name));
        print(str_concat("  ", str_concat(proj_name, "/Nucleor.toml")));
        print(str_concat("  ", str_concat(proj_name, "/src/main.nr")));
        print("");
        print(str_concat("  To build: cd ", str_concat(proj_name, str_concat(" && nuc build", ""))));
        print(str_concat("  To run:   cd ", str_concat(proj_name, str_concat(" && nuc run", ""))));
        return 0;
    };
    // Legacy mode: nuc source.nr output_name
    if argc == 3 && cmd_accepts_source(cmd) == 0 {
        return compile_file(cmd, args_get(2));
    };
    let mut src_path: str = "";
    let mut arg_start: i64 = 2;
    if cmd_accepts_source(cmd) == 1 {
        if argc >= 3 {
            let arg2: str = args_get(2);
            if cli_is_flag(arg2) == 0 {
                src_path = arg2;
                arg_start = 3;
            };
        };
        if str_len(src_path) == 0 {
            src_path = manifest_entry_path();
            if str_len(src_path) > 0 {
                print(str_concat("  manifest entry: ", src_path));
            };
        };
        if str_len(src_path) == 0 {
            print("Usage: nuc <command> <source.nr> [options]");
            print("  note: or run the command from a project directory with Nucleor.toml");
            return 1;
        };
    };
    let wants_output_name: i64 = cmd_allows_output_name(cmd);
    let mut out_name: str = "";
    if wants_output_name == 1 {
        out_name = strip_ext(basename(src_path));
        if str_eq(cmd, "test") { out_name = str_concat(out_name, "-test"); };
        if str_eq(cmd, "bench") { out_name = str_concat(out_name, "-bench"); };
    };
    let mut time_passes: i64 = 0;
    let mut use_cache: i64 = 1;
    let mut link_native: i64 = 1;
    if str_eq(cmd, "emit") { link_native = 0; };
    let mut policy_level: str = "default";
    let mut bench_iterations: i64 = 10;
    let mut bench_warmup: i64 = 1;
    let mut test_list_only: i64 = 0;
    let mut saw_output_name: i64 = 0;
    let mut argi_build: i64 = arg_start;
    while argi_build < argc {
        let flag: str = args_get(argi_build);
        if str_eq(flag, "--time-passes") { time_passes = 1; }
        else if str_eq(flag, "--no-cache") { use_cache = 0; }
        else if str_eq(flag, "--cache-stats") { env_set("NUCLEOR_CACHE_STATS", "1"); }
        else if str_eq(flag, "--release") {
            env_set("NUCLEOR_LLVM_OPT", "-O3");
        } else if str_eq(flag, "--tier") {
            if argi_build + 1 >= argc {
                print("ERROR: --tier requires a value (0, 1, or 2)");
                return 1;
            };
            let tier_value: str = args_get(argi_build + 1);
            if str_eq(tier_value, "0") == 1 { env_set("NUCLEOR_LLVM_OPT", "-O0"); }
            else if str_eq(tier_value, "1") == 1 { env_set("NUCLEOR_LLVM_OPT", "-O1"); }
            else if str_eq(tier_value, "2") == 1 { env_set("NUCLEOR_LLVM_OPT", "-O3"); }
            else {
                print(str_concat("ERROR: unsupported --tier value: ", tier_value));
                print("       expected 0, 1, or 2");
                return 1;
            };
            argi_build = argi_build + 1;
        } else if str_starts_with(flag, "--tier=") == 1 {
            let tier_eq_value: str = str_substring(flag, 7, str_len(flag));
            if str_eq(tier_eq_value, "0") == 1 { env_set("NUCLEOR_LLVM_OPT", "-O0"); }
            else if str_eq(tier_eq_value, "1") == 1 { env_set("NUCLEOR_LLVM_OPT", "-O1"); }
            else if str_eq(tier_eq_value, "2") == 1 { env_set("NUCLEOR_LLVM_OPT", "-O3"); }
            else {
                print(str_concat("ERROR: unsupported --tier value: ", tier_eq_value));
                print("       expected 0, 1, or 2");
                return 1;
            };
        }
        else if str_eq(flag, "--provenance") {
            // --provenance <path> populates the
            // .nucleor_provenance section of the output binary with
            // the bytes of <path>. Without this flag the section
            // exists with a 1-byte null placeholder.
            if argi_build + 1 >= argc {
                print("ERROR: --provenance requires a path to a JSON file");
                return 1;
            };
            env_set("NUCLEOR_PROVENANCE_PATH", args_get(argi_build + 1));
            argi_build = argi_build + 1;
        } else if str_starts_with(flag, "--provenance=") == 1 {
            env_set("NUCLEOR_PROVENANCE_PATH", str_substring(flag, 13, str_len(flag)));
        }
        else if str_eq(cmd, "test") && str_eq(flag, "--list") { test_list_only = 1; }
        else if str_eq(cmd, "bench") && str_eq(flag, "--iterations") {
            if argi_build + 1 >= argc {
                print("ERROR: --iterations requires a value");
                return 1;
            };
            bench_iterations = str_to_int(args_get(argi_build + 1));
            argi_build = argi_build + 1;
        } else if str_eq(cmd, "bench") && str_starts_with(flag, "--iterations=") == 1 {
            bench_iterations = str_to_int(str_substring(flag, 13, str_len(flag)));
        } else if str_eq(cmd, "bench") && str_eq(flag, "--warmup") {
            if argi_build + 1 >= argc {
                print("ERROR: --warmup requires a value");
                return 1;
            };
            bench_warmup = str_to_int(args_get(argi_build + 1));
            argi_build = argi_build + 1;
        } else if str_eq(cmd, "bench") && str_starts_with(flag, "--warmup=") == 1 {
            bench_warmup = str_to_int(str_substring(flag, 9, str_len(flag)));
        }
        else if wants_output_name == 1 && (str_eq(flag, "-o") || str_eq(flag, "--out") || str_eq(flag, "--output")) {
            if argi_build + 1 >= argc {
                print("ERROR: -o requires an output name");
                return 1;
            };
            out_name = args_get(argi_build + 1);
            saw_output_name = 1;
            argi_build = argi_build + 1;
        } else if wants_output_name == 1 && str_eq(flag, "--no-link") {
            link_native = 0;
        } else if wants_output_name == 1 && str_eq(flag, "--emit=llvm") {
            // LLVM IR is always emitted; this flag is accepted for clarity.
        } else if wants_output_name == 1 && str_eq(flag, "--emit") {
            if argi_build + 1 >= argc {
                print("ERROR: --emit requires a target (llvm)");
                return 1;
            };
            let emit_target: str = args_get(argi_build + 1);
            if str_eq(emit_target, "llvm") == 0 && str_eq(emit_target, "native") == 0 {
                print(str_concat("ERROR: unsupported emit target: ", emit_target));
                return 1;
            };
            argi_build = argi_build + 1;
        } else if wants_output_name == 1 && cli_is_flag(flag) == 0 && saw_output_name == 0 {
            out_name = flag;
            saw_output_name = 1;
        } else if str_eq(cmd, "policy") && cli_is_flag(flag) == 0 {
            policy_level = flag;
        } else if cli_is_flag(flag) == 1 && (str_eq(cmd, "build") == 1 || str_eq(cmd, "build-fast") == 1 || str_eq(cmd, "build-strict") == 1 || str_eq(cmd, "build-shared") == 1 || str_eq(cmd, "run") == 1 || str_eq(cmd, "emit") == 1 || str_eq(cmd, "build-wasm") == 1 || str_eq(cmd, "build-ptx") == 1 || str_eq(cmd, "verify-reproducible") == 1) {
            print(str_concat("ERROR: unknown flag: ", flag));
            print("       run `nuc help` for the supported build flags");
            return 1;
        };
        argi_build = argi_build + 1;
    };
    if wants_output_name == 1 {
        out_name = normalize_output_name(out_name);
        if str_len(out_name) == 0 {
            print("ERROR: output name must contain only letters, digits, '_' or '-'");
            return 1;
        };
    };
    if str_eq(cmd, "run") && link_native == 0 {
        print("ERROR: run cannot be used with --no-link");
        return 1;
    };
    if str_eq(cmd, "summary") {
        return run_summary_command(src_path, argc, arg_start);
    } else if str_eq(cmd, "evidence") {
        return run_evidence_command(src_path);
    } else if str_eq(cmd, "query") {
        return run_query_command(src_path);
    } else if str_eq(cmd, "abi") {
        return run_abi_command(src_path, argc, arg_start);
    } else if str_eq(cmd, "impact") {
        return run_impact_command(src_path, argc, arg_start);
    } else if str_eq(cmd, "graph") {
        return run_graph_command(src_path, argc, arg_start);
    } else if str_eq(cmd, "perf") {
        return run_perf_command(src_path, argc, arg_start);
    };
    if str_eq(cmd, "build") {
        return compile_file_mode_native_isolated(src_path, out_name, 0, use_cache, time_passes, link_native);
    } else if str_eq(cmd, "build-fast") {
        return compile_file_mode_native_isolated(src_path, out_name, 0, use_cache, time_passes, link_native);
    } else if str_eq(cmd, "build-strict") {
        return run_external_tool(argc);
    } else if str_eq(cmd, "run") {
        let rc: i64 = compile_file_mode_native_isolated(src_path, out_name, 0, use_cache, time_passes, 1);
        if rc != 0 { return rc; };
        // platform-aware exe path. Pre-fix the path was
        // hardcoded as `target\<name>.exe` (Windows backslash + .exe),
        // which collapsed on POSIX shells: `system("target\foo.exe")`
        // hit `targetfoo.exe: not found` because the shell ate the
        // backslash. Closes
        // Linux path construction guard.
        // POSIX also needs the `./` prefix because /bin/sh -c does not
        // include `.` in PATH for security reasons.
        let exe_dir: str = if host_is_windows() == 1 { "target\\" } else { "./target/" };
        let exe: str = str_concat(exe_dir, str_concat(out_name, host_exe_suffix()));
        let mut run_rc: i64 = system(exe);
        // NUC-FEEDBACK-009 follow-on. ML adopters reported
        // post-compiled rc=4294967295 (= -1 = Windows spawn failure
        // even after a successful build). Retry up to 2 more times
        // on spawn failure (rc == -1 / 4294967295), preserving real
        // runtime exit codes (which are typically 0..255).
        let mut retry: i64 = 0;
        while retry < 2 && (run_rc == 0 - 1 || run_rc == 4294967295) {
            run_rc = system(exe);
            retry = retry + 1;
        };
        if run_rc != 0 {
            print(str_concat("nuc run: child exited rc=", str_concat(str_from_int(run_rc), str_concat(" from ", exe))));
            if run_rc == 0 - 1 || run_rc == 4294967295 {
                print("  note: rc=-1/4294967295 indicates the child process never started (Windows spawn failure: file-lock, antivirus, missing exe, or process-spawn failure). Retried 2 times. Try killing orphan nucleor.exe / clang.exe / <out>.exe processes and rerun.");
            };
        };
        return run_rc;
    } else if str_eq(cmd, "build-wasm") || str_eq(cmd, "build-ptx") {
        return run_external_tool(argc);
    } else if str_eq(cmd, "emit") {
        return compile_file_mode(src_path, out_name, 0, use_cache, time_passes, 0);
    } else if str_eq(cmd, "verify-reproducible") {
        // build the file twice with --no-cache,
        // hash both .ll AND .exe outputs, report pass/fail.
        // Translate SPEC-2 Task 2: now builds with link
        // ENABLED so we also catch linker-side determinism breaks
        // (the lld-link COFF timestamp issue that v0.4.10 fixed
        // with -Wl,/Brepro). IR-only check is necessary but not
        // sufficient for SLSA-Build-Level-3 attestation.
        let out_a: str = str_concat(out_name, "_repro_a");
        let out_b: str = str_concat(out_name, "_repro_b");
        let rc_a: i64 = compile_file_mode(src_path, out_a, 0, 0, 0, 1);
        if rc_a != 0 {
            print("verify-reproducible: first build failed; aborting.");
            return rc_a;
        };
        let rc_b: i64 = compile_file_mode(src_path, out_b, 0, 0, 0, 1);
        if rc_b != 0 {
            print("verify-reproducible: second build failed; aborting.");
            return rc_b;
        };
        let ll_a: str = str_concat("target/", str_concat(out_a, ".ll"));
        let ll_b: str = str_concat("target/", str_concat(out_b, ".ll"));
        // Platform-aware exe suffix: empty on POSIX, ".exe" on Windows.
        // Pre-fix this hardcoded ".exe", so verify-reproducible's EXE
        // diff always reported "DIFFER" on Linux because it compared
        // two non-existent .exe paths instead of the real ELF outputs.
        let exe_a: str = str_concat("target/", str_concat(out_a, host_exe_suffix()));
        let exe_b: str = str_concat("target/", str_concat(out_b, host_exe_suffix()));
        let ll_bytes_a: str = file_read_string(ll_a);
        let ll_bytes_b: str = file_read_string(ll_b);
        if str_len(ll_bytes_a) == 0 || str_len(ll_bytes_b) == 0 {
            print("verify-reproducible: cannot read IR outputs");
            return 1;
        };
        let ll_hash_a: str = content_hash(ll_bytes_a);
        let ll_hash_b: str = content_hash(ll_bytes_b);
        let ll_len_a: i64 = str_len(ll_bytes_a);
        let ll_len_b: i64 = str_len(ll_bytes_b);
        let mut exe_check_ran: i64 = 0;
        let mut exe_match: i64 = 0;
        // native runtime helper (TOOLCHAIN-PY-1 closed).
        // Replaces the prior shell byte-compare with one C-level path for
        // Windows and POSIX. The helper compares bytes and handles NULs.
        exe_check_ran = 1;
        if file_bytes_equal(exe_a, exe_b) == 1 { exe_match = 1; };
        print(str_concat("verify-reproducible: source = ", src_path));
        print(str_concat("  IR  build A: ", str_concat(ll_a, str_concat(" (", str_concat(str_from_int(ll_len_a), str_concat(" bytes, hash=", str_concat(ll_hash_a, ")")))))));
        print(str_concat("  IR  build B: ", str_concat(ll_b, str_concat(" (", str_concat(str_from_int(ll_len_b), str_concat(" bytes, hash=", str_concat(ll_hash_b, ")")))))));
        if exe_check_ran == 1 {
            print(str_concat("  EXE build A: ", exe_a));
            print(str_concat("  EXE build B: ", exe_b));
            if exe_match == 1 { print("  EXE diff: byte-identical"); }
            else { print("  EXE diff: DIFFER"); };
        } else {
            print("  EXE: skipped (one or both linked binaries missing)");
        };
        let ir_match: i64 = if str_eq(ll_hash_a, ll_hash_b) == 1 && ll_len_a == ll_len_b { 1 } else { 0 };
        if ir_match == 1 && (exe_check_ran == 0 || exe_match == 1) {
            print("PASS: byte-identical IR + EXE across two cold-cache builds.");
            print("  This file satisfies the RFC-NRT-003 reproducibility invariant.");
            print("  Suitable for SLSA-Build-Level-3 attestation.");
            return 0;
        };
        if ir_match == 0 {
            print("FAIL: IR outputs differ.");
            print("  Determinism break in the compiler. Common causes:");
            print("    - timestamps in cached intermediates");
            print("    - hash-table iteration order in symbol lowering");
            print("    - absolute build paths embedded in IR");
            print("    - random seeding in an optimization pass");
            return 1;
        };
        print("FAIL: IR identical but EXE outputs differ.");
        print("  Determinism break in the linker. Common causes:");
        print("    - PE/COFF timestamp not suppressed (use -Wl,/Brepro)");
        print("    - ELF build-id varies (use -Wl,--build-id=none)");
        print("    - debug info embeds absolute paths");
        return 1;
    } else if str_eq(cmd, "test") || str_eq(cmd, "bench") || str_eq(cmd, "check") || str_eq(cmd, "audit") || str_eq(cmd, "policy") || str_eq(cmd, "certify") || str_eq(cmd, "translate") {
        return run_external_tool(argc);
    } else {
        // Fallback: treat as legacy
        if argc >= 3 { return compile_file(cmd, args_get(2)); };
        print(str_concat("Unknown command: ", cmd));
        return 1;
    };
}
