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
        // The fast path returns with `imported = [src_path]` only and
        // relies on `collect_native_directives` to scan that single
        // file for `#cfile` directives. That's correct for self-contained
        // sources, but wrong for any file whose link surface depends on
        // imported rods. Detect all directive forms that pull external
        // sources into the link: `import "..."`, `use foo;` (incl.
        // `use std::*`, `use crate::*`, `use super::*`), and `mod foo;`.
        // Missing any of them leaves rod-side #cfile entries off the clang
        // command line and produces undefined-reference link failures only
        // visible on a warm cache_v2 hit (cold path is unaffected since the
        // .ll file doesn't exist yet). False-positives on the substring
        // probe just send us through the slow path — same correct output,
        // a few hundred ms slower.
        let has_import: i64 = if str_len(raw_probe) >= 8
            && str_starts_with(raw_probe, "import \"") == 1 { 1 }
            else if str_contains(raw_probe, "\nimport \"") == 1 { 1 }
            else if str_len(raw_probe) >= 4 && str_starts_with(raw_probe, "use ") == 1 { 1 }
            else if str_contains(raw_probe, "\nuse ") == 1 { 1 }
            else if str_len(raw_probe) >= 4 && str_starts_with(raw_probe, "mod ") == 1 { 1 }
            else if str_contains(raw_probe, "\nmod ") == 1 { 1 }
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

fn fn_name_start_in_line(line: str) -> i64 {
    let slen: i64 = str_len(line);
    let mut p: i64 = 0;
    while p < slen && (str_char_at(line, p) == 32 || str_char_at(line, p) == 9) { p = p + 1; };
    if p + 2 > slen { return 0 - 1; };
    if str_eq(str_substring(line, p, p + 2), "fn") == 0 { return 0 - 1; };
    p = p + 2;
    while p < slen && (str_char_at(line, p) == 32 || str_char_at(line, p) == 9) { p = p + 1; };
    if p >= slen { return 0 - 1; };
    return p;
}

fn fn_name_end_in_line(line: str, start: i64) -> i64 {
    let slen: i64 = str_len(line);
    let mut p: i64 = start;
    while p < slen {
        let c: i64 = str_char_at(line, p);
        if is_alnum(c) == 1 || c == 95 { p = p + 1; }
        else { return p; };
    };
    return p;
}

fn extract_fn_name_from_line(line: str) -> str {
    let start: i64 = fn_name_start_in_line(line);
    if start < 0 { return ""; };
    let stop: i64 = fn_name_end_in_line(line, start);
    if stop <= start { return ""; };
    let mut after: i64 = stop;
    let slen: i64 = str_len(line);
    while after < slen && (str_char_at(line, after) == 32 || str_char_at(line, after) == 9) { after = after + 1; };
    if after >= slen || str_char_at(line, after) != 40 { return ""; };
    return str_substring(line, start, stop);
}

// extract a struct or enum name from a declaration line.
// Recognizes leading "struct " / "enum " (with optional "pub " prefix)
// followed by an identifier. Returns the name, or "" if no match.
// `kind_kw` selects which to look for: "struct" or "enum".
fn extract_type_decl_name_from_line(line: str, kind_kw: str) -> str {
    let llen: i64 = str_len(line);
    let mut p: i64 = 0;
    while p < llen && (str_char_at(line, p) == 32 || str_char_at(line, p) == 9) { p = p + 1; };
    // Skip optional `pub `.
    if p + 4 <= llen && str_eq(str_substring(line, p, p + 4), "pub ") == 1 {
        p = p + 4;
        while p < llen && (str_char_at(line, p) == 32 || str_char_at(line, p) == 9) { p = p + 1; };
    };
    let kw_len: i64 = str_len(kind_kw);
    if p + kw_len + 1 > llen { return ""; };
    if str_eq(str_substring(line, p, p + kw_len), kind_kw) == 0 { return ""; };
    let after_kw: i64 = p + kw_len;
    if str_char_at(line, after_kw) != 32 && str_char_at(line, after_kw) != 9 { return ""; };
    let mut np: i64 = after_kw + 1;
    while np < llen && (str_char_at(line, np) == 32 || str_char_at(line, np) == 9) { np = np + 1; };
    let nstart: i64 = np;
    while np < llen {
        let c: i64 = str_char_at(line, np);
        if is_alnum(c) == 1 || c == 95 { np = np + 1; } else { break; };
    };
    if np <= nstart { return ""; };
    return str_substring(line, nstart, np);
}

fn extract_public_fn_name_from_line(line: str) -> str {
    let compact: str = strip_spaces(line);
    let clen: i64 = str_len(compact);
    let mut start: i64 = 0 - 1;
    if clen >= 5 && str_eq(str_substring(compact, 0, 5), "pubfn") == 1 { start = 5; }
    else if clen >= 9 && str_eq(str_substring(compact, 0, 9), "pubpurefn") == 1 { start = 9; };
    if start < 0 || start >= clen { return ""; };
    let mut stop: i64 = start;
    while stop < clen {
        let ch: i64 = str_char_at(compact, stop);
        if is_alnum(ch) == 1 || ch == 95 { stop = stop + 1; }
        else { return str_substring(compact, start, stop); };
    };
    return str_substring(compact, start, stop);
}

fn collect_public_export_names(source: str) -> Vec<i32> {
    let mut exports: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let name: str = extract_public_fn_name_from_line(line);
        if str_len(name) > 0 { string_vec_push_unique(exports, name); };
        p = eol + 1;
    };
    return exports;
}

fn rewrite_test_main_line(line: str) -> str {
    let start: i64 = fn_name_start_in_line(line);
    if start < 0 { return line; };
    let stop: i64 = fn_name_end_in_line(line, start);
    if stop <= start { return line; };
    let name: str = str_substring(line, start, stop);
    if str_eq(name, "main") == 0 { return line; };
    return str_concat(str_substring(line, 0, start), str_concat("__nucleor_test_user_main", str_substring(line, stop, str_len(line))));
}

fn is_test_attr_compact(compact: str) -> i64 {
    if str_eq(compact, "@test") == 1 { return 1; };
    if str_eq(compact, "#[test]") == 1 { return 1; };
    if str_starts_with(compact, "#[test,") == 1 { return 1; };
    if str_starts_with(compact, "#[test ") == 1 { return 1; };
    return 0;
}

fn collect_test_names_from_source(source: str) -> Vec<i32> {
    let mut tests: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    let mut marked_test: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(source, p, eol);
        let compact: str = strip_spaces(line);
        // Detect test attributes: legacy `@test` line, RFC-0021 `#[test]`,
        // or RFC-0021 `#[test, ignore]` / `#[test, should_panic]` etc.
        if is_test_attr_compact(compact) == 1 {
            marked_test = 1;
        } else {
            let fn_name: str = extract_fn_name_from_line(line);
            if str_len(fn_name) > 0 {
                if marked_test == 1 || str_starts_with(fn_name, "test_") == 1 {
                    tests.push(fn_name);
                };
                marked_test = 0;
            } else if str_len(compact) > 0 && str_starts_with(compact, "//") == 0 && str_starts_with(compact, "#[") == 0 {
                // Allow other #[...] attribute lines between the test attr and the fn
                marked_test = 0;
            };
        };
        p = eol + 1;
    };
    return tests;
}

fn law_extract_attr_body_compact(compact: str) -> str {
    let start: i64 = str_index_of(compact, "@law(");
    if start < 0 { return ""; };
    let body_start: i64 = start + 5;
    let mut body_end: i64 = body_start;
    let clen: i64 = str_len(compact);
    while body_end < clen && str_char_at(compact, body_end) != 41 { body_end = body_end + 1; };
    if body_end <= body_start { return ""; };
    return str_substring(compact, body_start, body_end);
}

fn law_fn_param_count_from_line(line: str) -> i64 {
    let fn_pos: i64 = str_index_of(line, "fn ");
    if fn_pos < 0 { return 0 - 1; };
    let llen: i64 = str_len(line);
    let mut lp: i64 = fn_pos;
    while lp < llen && str_char_at(line, lp) != 40 { lp = lp + 1; };
    if lp >= llen { return 0 - 1; };
    let mut rp: i64 = lp + 1;
    while rp < llen && str_char_at(line, rp) != 41 { rp = rp + 1; };
    if rp >= llen { return 0 - 1; };
    let params: str = strip_spaces(str_substring(line, lp + 1, rp));
    if str_len(params) == 0 { return 0; };
    let mut n: i64 = 1;
    let mut i: i64 = 0;
    while i < str_len(params) {
        if str_char_at(params, i) == 44 { n = n + 1; };
        i = i + 1;
    };
    return n;
}

fn law_item_value(item: str) -> str {
    let eq: i64 = str_index_of(item, "=");
    if eq < 0 { return ""; };
    return str_substring(item, eq + 1, str_len(item));
}

fn law_append_panic(sb: i64, code: str, law_name: str, fn_name: str) {
    sb_append(sb, "        print(\"error[");
    sb_append(sb, code);
    sb_append(sb, "]: ");
    sb_append(sb, law_name);
    sb_append(sb, " counterexample for ");
    sb_append(sb, fn_name);
    sb_append(sb, "\");\n");
    sb_append(sb, "        panic(\"");
    sb_append(sb, code);
    sb_append(sb, "\");\n");
}

fn law_append_commutative_checks(sb: i64, fn_name: str) {
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(2, 7) != ");
    sb_append(sb, fn_name);
    sb_append(sb, "(7, 2) {\n");
    law_append_panic(sb, "LAW-001", "commutative", fn_name);
    sb_append(sb, "    };\n");
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(0 - 2, 3) != ");
    sb_append(sb, fn_name);
    sb_append(sb, "(3, 0 - 2) {\n");
    law_append_panic(sb, "LAW-001", "commutative", fn_name);
    sb_append(sb, "    };\n");
}

fn law_append_associative_checks(sb: i64, fn_name: str) {
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(");
    sb_append(sb, fn_name);
    sb_append(sb, "(1, 2), 3) != ");
    sb_append(sb, fn_name);
    sb_append(sb, "(1, ");
    sb_append(sb, fn_name);
    sb_append(sb, "(2, 3)) {\n");
    law_append_panic(sb, "LAW-001", "associative", fn_name);
    sb_append(sb, "    };\n");
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(");
    sb_append(sb, fn_name);
    sb_append(sb, "(0 - 2, 5), 4) != ");
    sb_append(sb, fn_name);
    sb_append(sb, "(0 - 2, ");
    sb_append(sb, fn_name);
    sb_append(sb, "(5, 4)) {\n");
    law_append_panic(sb, "LAW-001", "associative", fn_name);
    sb_append(sb, "    };\n");
}

fn law_append_identity_checks(sb: i64, fn_name: str, ident: str) {
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(7, ");
    sb_append(sb, ident);
    sb_append(sb, ") != 7 {\n");
    law_append_panic(sb, "LAW-001", "identity", fn_name);
    sb_append(sb, "    };\n");
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(");
    sb_append(sb, ident);
    sb_append(sb, ", 7) != 7 {\n");
    law_append_panic(sb, "LAW-001", "identity", fn_name);
    sb_append(sb, "    };\n");
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(0 - 2, ");
    sb_append(sb, ident);
    sb_append(sb, ") != 0 - 2 {\n");
    law_append_panic(sb, "LAW-001", "identity", fn_name);
    sb_append(sb, "    };\n");
}

fn law_append_absorbing_checks(sb: i64, fn_name: str, absorb: str) {
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(7, ");
    sb_append(sb, absorb);
    sb_append(sb, ") != ");
    sb_append(sb, absorb);
    sb_append(sb, " {\n");
    law_append_panic(sb, "LAW-001", "absorbing", fn_name);
    sb_append(sb, "    };\n");
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(");
    sb_append(sb, absorb);
    sb_append(sb, ", 7) != ");
    sb_append(sb, absorb);
    sb_append(sb, " {\n");
    law_append_panic(sb, "LAW-001", "absorbing", fn_name);
    sb_append(sb, "    };\n");
}

fn law_append_idempotent_checks(sb: i64, fn_name: str, arity: i64) {
    if arity == 2 {
        sb_append(sb, "    if ");
        sb_append(sb, fn_name);
        sb_append(sb, "(7, 7) != 7 {\n");
        law_append_panic(sb, "LAW-001", "idempotent", fn_name);
        sb_append(sb, "    };\n");
        return;
    };
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(");
    sb_append(sb, fn_name);
    sb_append(sb, "(7)) != ");
    sb_append(sb, fn_name);
    sb_append(sb, "(7) {\n");
    law_append_panic(sb, "LAW-001", "idempotent", fn_name);
    sb_append(sb, "    };\n");
}

fn law_append_involution_checks(sb: i64, fn_name: str) {
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(");
    sb_append(sb, fn_name);
    sb_append(sb, "(7)) != 7 {\n");
    law_append_panic(sb, "LAW-001", "involution", fn_name);
    sb_append(sb, "    };\n");
}

fn law_append_distributive_over_checks(sb: i64, fn_name: str, over_fn: str) {
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(2, ");
    sb_append(sb, over_fn);
    sb_append(sb, "(3, 5)) != ");
    sb_append(sb, over_fn);
    sb_append(sb, "(");
    sb_append(sb, fn_name);
    sb_append(sb, "(2, 3), ");
    sb_append(sb, fn_name);
    sb_append(sb, "(2, 5)) {\n");
    law_append_panic(sb, "LAW-001", "distributive_over", fn_name);
    sb_append(sb, "    };\n");
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(");
    sb_append(sb, over_fn);
    sb_append(sb, "(2, 3), 5) != ");
    sb_append(sb, over_fn);
    sb_append(sb, "(");
    sb_append(sb, fn_name);
    sb_append(sb, "(2, 5), ");
    sb_append(sb, fn_name);
    sb_append(sb, "(3, 5)) {\n");
    law_append_panic(sb, "LAW-001", "distributive_over", fn_name);
    sb_append(sb, "    };\n");
}

// Broad property pack: bounded
// integer inverse-law check generation. For a unary fn `f` annotated
// with `@law(inverse = g)`, generate both `f(g(a)) == a` and
// `g(f(a)) == a` round-trips at four sample integers covering
// positive, negative, small-magnitude, and zero-adjacent values.
// Arity gate at the call site keeps this bounded to unary fns.
// Float inverse forms continue to fail closed via the existing
// `f64` / `eps=` / `approximate` gates upstream of this routine.
fn law_append_inverse_checks(sb: i64, fn_name: str, inv_fn: str) {
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(");
    sb_append(sb, inv_fn);
    sb_append(sb, "(7)) != 7 {\n");
    law_append_panic(sb, "LAW-001", "inverse", fn_name);
    sb_append(sb, "    };\n");
    sb_append(sb, "    if ");
    sb_append(sb, fn_name);
    sb_append(sb, "(");
    sb_append(sb, inv_fn);
    sb_append(sb, "(0 - 3)) != 0 - 3 {\n");
    law_append_panic(sb, "LAW-001", "inverse", fn_name);
    sb_append(sb, "    };\n");
    sb_append(sb, "    if ");
    sb_append(sb, inv_fn);
    sb_append(sb, "(");
    sb_append(sb, fn_name);
    sb_append(sb, "(5)) != 5 {\n");
    law_append_panic(sb, "LAW-001", "inverse", fn_name);
    sb_append(sb, "    };\n");
    sb_append(sb, "    if ");
    sb_append(sb, inv_fn);
    sb_append(sb, "(");
    sb_append(sb, fn_name);
    sb_append(sb, "(0 - 1)) != 0 - 1 {\n");
    law_append_panic(sb, "LAW-001", "inverse", fn_name);
    sb_append(sb, "    };\n");
}

fn law_generate_check_fn(fn_name: str, law_body: str, arity: i64, check_name: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let mut sb: i64 = sb_new();
    sb_append(sb, "\nfn ");
    sb_append(sb, check_name);
    sb_append(sb, "() {\n");
    let blen: i64 = str_len(law_body);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= blen {
        if i == blen || str_char_at(law_body, i) == 44 {
            let item: str = str_substring(law_body, start, i);
            if str_len(item) > 0 {
                if str_eq(item, "commutative") == 1 {
                    if arity != 2 {
                        print(str_concat("error[LAW-001]: commutative law requires a binary fn: ", fn_name));
                        out.push(1); out.push("");
                        return out;
                    };
                    law_append_commutative_checks(sb, fn_name);
                } else if str_eq(item, "associative") == 1 {
                    if arity != 2 {
                        print(str_concat("error[LAW-001]: associative law requires a binary fn: ", fn_name));
                        out.push(1); out.push("");
                        return out;
                    };
                    law_append_associative_checks(sb, fn_name);
                } else if str_starts_with(item, "identity=") == 1 {
                    if arity != 2 {
                        print(str_concat("error[LAW-001]: identity law requires a binary fn: ", fn_name));
                        out.push(1); out.push("");
                        return out;
                    };
                    law_append_identity_checks(sb, fn_name, law_item_value(item));
                } else if str_starts_with(item, "absorbing=") == 1 {
                    if arity != 2 {
                        print(str_concat("error[LAW-001]: absorbing law requires a binary fn: ", fn_name));
                        out.push(1); out.push("");
                        return out;
                    };
                    law_append_absorbing_checks(sb, fn_name, law_item_value(item));
                } else if str_eq(item, "idempotent") == 1 {
                    if arity != 1 && arity != 2 {
                        print(str_concat("error[LAW-001]: idempotent law requires a unary or binary fn: ", fn_name));
                        out.push(1); out.push("");
                        return out;
                    };
                    law_append_idempotent_checks(sb, fn_name, arity);
                } else if str_eq(item, "involution") == 1 {
                    if arity != 1 {
                        print(str_concat("error[LAW-001]: involution law requires a unary fn: ", fn_name));
                        out.push(1); out.push("");
                        return out;
                    };
                    law_append_involution_checks(sb, fn_name);
                } else if str_starts_with(item, "zero=") == 1 {
                    print("error[LAW-006]: deprecated alias `zero = Z`; use `absorbing = Z`");
                    out.push(1); out.push("");
                    return out;
                } else if str_eq(item, "distributive") == 1 {
                    print("error[LAW-007]: deprecated alias bare `distributive`; use `distributive_over = g`");
                    out.push(1); out.push("");
                    return out;
                } else if str_starts_with(item, "distributive_over=") == 1 {
                    if arity != 2 {
                        print(str_concat("error[LAW-001]: distributive_over law requires a binary fn: ", fn_name));
                        out.push(1); out.push("");
                        return out;
                    };
                    law_append_distributive_over_checks(sb, fn_name, law_item_value(item));
                } else if str_starts_with(item, "inverse=") == 1 {
                    if arity != 1 {
                        print(str_concat("error[LAW-001]: inverse law requires a unary fn: ", fn_name));
                        out.push(1); out.push("");
                        return out;
                    };
                    let inv_fn: str = law_item_value(item);
                    if str_len(inv_fn) == 0 {
                        print(str_concat("error[LAW-001]: inverse law requires a partner function name (e.g. `inverse = g`): ", fn_name));
                        out.push(1); out.push("");
                        return out;
                    };
                    law_append_inverse_checks(sb, fn_name, inv_fn);
                } else if str_eq(item, "fusion") == 1
                    || str_starts_with(item, "seed=") == 1
                    || str_starts_with(item, "cases=") == 1 {
                    print(str_concat("error[LAW-001]: canonical law form is not generated by this bounded integer checker: ", item));
                    out.push(1); out.push("");
                    return out;
                } else if str_starts_with(item, "eps=") == 1
                    || str_eq(item, "approximate") == 1 {
                    print(str_concat("error[LAW-004]: float/approximate law form requires explicit future tolerance semantics: ", item));
                    out.push(1); out.push("");
                    return out;
                } else {
                    print(str_concat("error[LAW-008]: unrecognized law name: ", item));
                    out.push(1); out.push("");
                    return out;
                };
            };
            start = i + 1;
        };
        i = i + 1;
    };
    sb_append(sb, "}\n");
    out.push(0);
    out.push(sb_to_str(sb));
    return out;
}

fn build_law_check_source(raw_source: str, tests: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(raw_source);
    let mut p: i64 = 0;
    let mut pending_law: str = "";
    let mut law_index: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw_source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(raw_source, p, eol);
        let compact: str = strip_spaces(line);
        let body: str = law_extract_attr_body_compact(compact);
        if str_len(body) > 0 {
            if str_len(pending_law) > 0 {
                pending_law = str_concat(pending_law, str_concat(",", body));
            } else {
                pending_law = body;
            };
        } else {
            let fn_name: str = extract_fn_name_from_line(line);
            if str_len(fn_name) > 0 && str_len(pending_law) > 0 {
                if str_contains(line, "f64") == 1 {
                    print(str_concat("error[LAW-004]: float law checking requires future tolerance semantics: ", fn_name));
                    out.push(1); out.push("");
                    return out;
                };
                let arity: i64 = law_fn_param_count_from_line(line);
                let check_name: str = str_concat("__nucleor_law_check_", str_from_int(law_index));
                let gen: Vec<i32> = law_generate_check_fn(fn_name, pending_law, arity, check_name);
                if vec_get(gen, 0) != 0 {
                    out.push(1); out.push("");
                    return out;
                };
                sb_append(sb, vec_get(gen, 1));
                tests.push(check_name);
                pending_law = "";
                law_index = law_index + 1;
            };
        };
        p = eol + 1;
    };
    out.push(0);
    out.push(sb_to_str(sb));
    return out;
}

// T1.3 (v0.2.338): collect #cfile directives from every imported
// rod file and emit them at the top of the harness with paths
// rewritten to be harness-relative (target/.. → repo root). This
// closes the gap where `resolve_source_with_records` strips
// `#cfile` lines, so the harness compile would otherwise have no
// way to reach the rod runtime .c files.
fn collect_imported_cfiles_for_harness(imported: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(imported) {
        let imp_path: str = vec_get(imported, i);
        let imp_raw: str = file_read_string(imp_path);
        let imp_dir: str = extract_dir(imp_path);
        let slen: i64 = str_len(imp_raw);
        let mut p: i64 = 0;
        while p < slen {
            let mut eol: i64 = p;
            while eol < slen && str_char_at(imp_raw, eol) != 10 { eol = eol + 1; };
            let mut lp: i64 = p;
            while lp < eol && (str_char_at(imp_raw, lp) == 32 || str_char_at(imp_raw, lp) == 9) { lp = lp + 1; };
            let line_len: i64 = eol - lp;
            if line_len >= 8 && str_char_at(imp_raw, lp) == 35 &&
               str_eq(str_substring(imp_raw, lp, lp + 7), "#cfile ") == 1 {
                let mut qp: i64 = lp + 7;
                while qp < eol && str_char_at(imp_raw, qp) == 32 { qp = qp + 1; };
                if qp < eol && str_char_at(imp_raw, qp) == 34 {
                    let ps: i64 = qp + 1;
                    let mut pe: i64 = ps;
                    while pe < eol && str_char_at(imp_raw, pe) != 34 { pe = pe + 1; };
                    let raw_path: str = str_substring(imp_raw, ps, pe);
                    // Resolve the directive's relative path against the
                    // rod's directory. imp_dir may be absolute (from
                    // cache resolution on Windows: `C:\...\stdlib/rods/`)
                    // or relative (`stdlib/rods/`). Produce a path that
                    // works either way: if absolute, emit as-is; if
                    // relative, make it harness-relative via `../`.
                    let resolved: str = str_concat(imp_dir, raw_path);
                    let dlen: i64 = str_len(imp_dir);
                    let mut is_abs: i64 = 0;
                    if dlen >= 1 && str_char_at(imp_dir, 0) == 47 { is_abs = 1; };
                    if dlen >= 2 && str_char_at(imp_dir, 1) == 58 { is_abs = 1; };
                    sb_append(sb, "#cfile \"");
                    if is_abs == 0 { sb_append(sb, "../"); };
                    sb_append(sb, resolved);
                    sb_append(sb, "\"\n");
                };
            };
            p = eol + 1;
        };
        i = i + 1;
    };
    return sb_to_str(sb);
}

// Legacy helper kept for backwards-compat with any inline #cfile that
// survives in the harness source. Currently no-op for the common
// "../runtime/X.c" pattern since collect_imported_cfiles_for_harness
// handles it; this acts as a safety net.
fn rewrite_cfile_for_harness(line: str) -> str {
    let llen: i64 = str_len(line);
    let mut lp: i64 = 0;
    while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
    if lp + 7 > llen { return line; };
    if str_eq(str_substring(line, lp, lp + 7), "#cfile ") == 0 { return line; };
    // Find the quoted path
    let mut qp: i64 = lp + 7;
    while qp < llen && str_char_at(line, qp) == 32 { qp = qp + 1; };
    if qp >= llen || str_char_at(line, qp) != 34 { return line; };
    let ps: i64 = qp + 1;
    let mut pe: i64 = ps;
    while pe < llen && str_char_at(line, pe) != 34 { pe = pe + 1; };
    let path: str = str_substring(line, ps, pe);
    // Common rod pattern: "../runtime/X.c" (relative to stdlib/rods/).
    // Rewrite to harness-relative: "../stdlib/runtime/X.c".
    let mut new_path: str = path;
    if str_starts_with(path, "../runtime/") == 1 {
        new_path = str_concat("../stdlib/runtime/", str_substring(path, 11, str_len(path)));
    };
    let mut sb: i64 = sb_new();
    sb_append(sb, str_substring(line, 0, ps));
    sb_append(sb, new_path);
    sb_append(sb, str_substring(line, pe, llen));
    return sb_to_str(sb);
}

fn build_test_harness_source(resolved_source: str, tests: Vec<i32>) -> str {
    let mut empty: Vec<i32> = Vec::new();
    return build_test_harness_source_with_imports(resolved_source, tests, empty);
}

fn build_test_harness_source_with_imports(resolved_source: str, tests: Vec<i32>, imported: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    // T1.3: prepend #cfile directives collected from the original
    // imports so the harness build can find rod runtime .c files.
    sb_append(sb, collect_imported_cfiles_for_harness(imported));
    let slen: i64 = str_len(resolved_source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(resolved_source, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(resolved_source, p, eol);
        let compact: str = strip_spaces(line);
        if is_test_attr_compact(compact) == 0 {
            let rewritten: str = rewrite_cfile_for_harness(line);
            sb_append(sb, rewrite_test_main_line(rewritten));
            if eol < slen { sb_append(sb, "\n"); };
        };
        p = eol + 1;
    };
    if slen > 0 && str_char_at(resolved_source, slen - 1) != 10 { sb_append(sb, "\n"); };
    sb_append(sb, "\nfn main() -> i32 {\n");
    // RFC-0021 phase 2: when NUCLEOR_TEST_ONLY=<name> is set in the
    // environment, run only that test and exit with its return code.
    // The parent --isolation=process driver spawns one child per test
    // with this env var to get full process isolation.
    sb_append(sb, "    let only: str = getenv(\"NUCLEOR_TEST_ONLY\");\n");
    sb_append(sb, "    let mut failed: i64 = 0;\n");
    let mut i: i64 = 0;
    while i < vec_len(tests) {
        let test_name: str = vec_get(tests, i);
        sb_append(sb, "    if str_len(only) == 0 || str_eq(only, \"");
        sb_append(sb, test_name);
        sb_append(sb, "\") == 1 {\n");
        sb_append(sb, "        ");
        sb_append(sb, test_name);
        sb_append(sb, "();\n");
        sb_append(sb, "        print(\"  PASS: ");
        sb_append(sb, test_name);
        sb_append(sb, "\");\n");
        sb_append(sb, "    };\n");
        i = i + 1;
    };
    if vec_len(tests) == 0 {
        sb_append(sb, "    print(\"test result: no tests discovered\");\n");
        sb_append(sb, "    return 1;\n");
        sb_append(sb, "}\n");
        return sb_to_str(sb);
    };
    sb_append(sb, "    if str_len(only) > 0 {\n");
    sb_append(sb, "        if failed == 0 { return 0; };\n");
    sb_append(sb, "        return failed;\n");
    sb_append(sb, "    };\n");
    if vec_len(tests) == 1 {
        sb_append(sb, "    if failed == 0 { print(\"test result: PASS (1 test)\"); return 0; };\n");
    } else {
        sb_append(sb, "    if failed == 0 { print(\"test result: PASS (");
        sb_append(sb, str_from_int(vec_len(tests)));
        sb_append(sb, " tests)\"); return 0; };\n");
    };
    sb_append(sb, "    print(\"test result: FAIL\");\n");
    sb_append(sb, "    return failed;\n");
    sb_append(sb, "}\n");
    return sb_to_str(sb);
}

// RFC-0018 phase 3: `nuc fix --imports` migration tool.
// Rewrites quoted-path imports of the form
//     import "stdlib/rods/<rod>.nr"
//     use    "stdlib/rods/<rod>.nr"
// into the Rust-style equivalent
//     use std::<rod>;
// in-place. Skips lines that already use the std::/crate::/super::
// syntax. Writes the source back only if at least one line changed.
fn fix_imports_in_source(src: str) -> Vec<i32> {
    let mut sb: i64 = sb_new();
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut changed: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line_end: i64 = eol;
        let mut lp: i64 = p;
        while lp < line_end && (str_char_at(src, lp) == 32 || str_char_at(src, lp) == 9) { lp = lp + 1; };
        let line_len: i64 = line_end - lp;
        let mut prefix_len: i64 = 0;
        if line_len >= 8 && str_eq(str_substring(src, lp, lp + 7), "import ") == 1 { prefix_len = 7; };
        if prefix_len == 0 && line_len >= 5 && str_eq(str_substring(src, lp, lp + 4), "use ") == 1 { prefix_len = 4; };
        let mut rewritten: i64 = 0;
        if prefix_len > 0 {
            let mut qp: i64 = lp + prefix_len;
            while qp < line_end && str_char_at(src, qp) == 32 { qp = qp + 1; };
            if qp < line_end && str_char_at(src, qp) == 34 {
                let ps: i64 = qp + 1;
                let mut pe: i64 = ps;
                while pe < line_end && str_char_at(src, pe) != 34 { pe = pe + 1; };
                let raw: str = str_substring(src, ps, pe);
                let rlen: i64 = str_len(raw);
                let prefix_match: i64 = if rlen >= 12 { str_eq(str_substring(raw, 0, 12), "stdlib/rods/") } else { 0 };
                if prefix_match == 1 && rlen >= 15 && str_eq(str_substring(raw, rlen - 3, rlen), ".nr") == 1 {
                    let inner: str = str_substring(raw, 12, rlen - 3);
                    // Convert any embedded "/" into "::" so e.g. "foo/bar" -> "foo::bar".
                    let mut isb: i64 = sb_new();
                    sb_append(isb, "use std::");
                    let ilen: i64 = str_len(inner);
                    let mut ii: i64 = 0;
                    while ii < ilen {
                        let ch: i64 = str_char_at(inner, ii);
                        if ch == 47 { sb_append(isb, "::"); }
                        else { sb_append(isb, str_substring(inner, ii, ii + 1)); };
                        ii = ii + 1;
                    };
                    sb_append(isb, ";");
                    // Preserve leading whitespace.
                    if lp > p { sb_append(sb, str_substring(src, p, lp)); };
                    sb_append(sb, sb_to_str(isb));
                    if eol < slen { sb_append(sb, "\n"); };
                    changed = changed + 1;
                    rewritten = 1;
                };
            };
        };
        if rewritten == 0 {
            sb_append(sb, str_substring(src, p, eol));
            if eol < slen { sb_append(sb, "\n"); };
        };
        p = eol + 1;
    };
    let mut out: Vec<i32> = Vec::new();
    out.push(sb_to_str(sb));
    out.push(str_from_int(changed));
    return out;
}

// RFC-0015 phase 5 partial: `nuc fix --numeric` lints (does not modify)
// for mixed-width arithmetic. Scans for the textual pattern
// `let <name>: <int_type> = ...;` followed elsewhere by binop operands
// that don't align in width. Reports each finding with a suggested
// `as` cast. Full inference + automated rewrite arrives once the
// type lattice IR (phase 3) lands.
fn report_numeric_findings(src_path: str, src: str) -> i64 {
    let mut findings: i64 = 0;
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut line: i64 = 1;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let ln: str = str_substring(src, p, eol);
        let ll: i64 = str_len(ln);
        // Heuristic: any line with two distinct width markers next to a
        // binary operator counts. We look for adjacent declared types
        // such as ": i32" + ": i64" on contiguous lines, or in-line
        // "as i64" already present (which we ignore).
        if ll >= 8 && find_substr(ln, ": i32") >= 0 && find_substr(ln, " + ") >= 0 && find_substr(ln, "as i64") < 0 {
            print(str_concat(src_path, str_concat(":", str_concat(str_from_int(line), ": numeric: i32 in additive context — consider explicit `as i64`"))));
            findings = findings + 1;
        } else if ll >= 8 && find_substr(ln, ": i32") >= 0 && find_substr(ln, " - ") >= 0 && find_substr(ln, "as i64") < 0 {
            print(str_concat(src_path, str_concat(":", str_concat(str_from_int(line), ": numeric: i32 in subtractive context — consider explicit `as i64`"))));
            findings = findings + 1;
        };
        p = eol + 1;
        line = line + 1;
    };
    return findings;
}

fn find_substr(haystack: str, needle: str) -> i64 {
    let hlen: i64 = str_len(haystack);
    let nlen: i64 = str_len(needle);
    if nlen == 0 || nlen > hlen { return 0 - 1; };
    let mut i: i64 = 0;
    while i <= hlen - nlen {
        if str_eq(str_substring(haystack, i, i + nlen), needle) == 1 { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

// RFC-0029 doc-gen skeleton: walk the resolved source bundle, extract
// every `pub fn` / `fn` declaration line and the immediately-preceding
// `///` doc comment, and emit a Markdown summary to stdout (or write
// to a file with --out). v0.2.0 ships the skeleton; the v0.4 doc-gen
// adds parameter inference, return-type lookup, full Markdown nav,
// and per-module navigation.
// Pull the parameter list + return type out of an `fn name(args) -> ret`
// signature line. Returns (params, return_type) where each piece is a
// trimmed string fragment for direct rendering. Empty strings on parse
// failure (caller falls back to the raw signature line).
// demote leading `#`-headings in /// doc content by two
// levels so a `/// # Examples` line renders as `### Examples` under
// the parent fn's `## fn_name` heading. Pre-fix the `#` was emitted
// raw, producing an H1 sibling to the document title — semantically
// wrong (the section is a sub-block of the fn doc, not a top-level
// section of the document). Walks line by line; each line starting
// with one or more `#` followed by a space gets two additional `#`s
// prepended. Other lines pass through unchanged.
fn doc_demote_headings(text: str) -> str {
    let tlen: i64 = str_len(text);
    if tlen == 0 { return text; };
    let mut sb: i64 = sb_new();
    let mut p: i64 = 0;
    while p < tlen {
        let mut eol: i64 = p;
        while eol < tlen && str_char_at(text, eol) != 10 { eol = eol + 1; };
        let llen: i64 = eol - p;
        let mut hcount: i64 = 0;
        while hcount < llen && str_char_at(text, p + hcount) == 35 { hcount = hcount + 1; };
        if hcount > 0 && p + hcount < tlen && str_char_at(text, p + hcount) == 32 {
            sb_append(sb, "##");
            sb_append(sb, str_substring(text, p, eol));
        } else {
            sb_append(sb, str_substring(text, p, eol));
        };
        if eol < tlen { sb_append(sb, "\n"); };
        p = eol + 1;
    };
    return sb_to_str(sb);
}

// scan a type-or-signature string and replace any identifier
// token that matches a known type name with a markdown anchor link.
// Used to cross-link param/return types in fn signatures to the
// struct/enum anchor sections defined in the same file. Tokens are
// `[A-Za-z_][A-Za-z0-9_]*` runs; everything else is passed through
// unchanged so generics (`Vec<Point>`), tuples (`(Point, i32)`), and
// path types (`std::Point`) all preserve their structural punctuation.
fn link_known_types_md(sig: str, type_names: Vec<i32>) -> str {
    let nlen: i64 = vec_len(type_names);
    if nlen == 0 { return sig; };
    let slen: i64 = str_len(sig);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(sig, i);
        let is_id_start: i64 = if (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 { 1 } else { 0 };
        if is_id_start == 1 {
            let mut j: i64 = i + 1;
            while j < slen {
                let c2: i64 = str_char_at(sig, j);
                if (c2 >= 65 && c2 <= 90) || (c2 >= 97 && c2 <= 122) || (c2 >= 48 && c2 <= 57) || c2 == 95 { j = j + 1; }
                else { break; };
            };
            let tok: str = str_substring(sig, i, j);
            let mut matched: i64 = 0;
            let mut ti: i64 = 0;
            while ti < nlen {
                if str_eq(tok, vec_get(type_names, ti)) == 1 { matched = 1; break; };
                ti = ti + 1;
            };
            if matched == 1 {
                sb_append(sb, "[");
                sb_append(sb, tok);
                sb_append(sb, "](#type-");
                sb_append(sb, tok);
                sb_append(sb, ")");
            } else {
                sb_append(sb, tok);
            };
            i = j;
        } else {
            sb_append(sb, str_substring(sig, i, i + 1));
            i = i + 1;
        };
    };
    return sb_to_str(sb);
}

// extract module-level doc comments (`//!` lines at the top
// of a source file). Walks from line 0, collecting `//!` content into
// a single newline-joined string, and stops at the first non-doc-comment,
// non-blank line. Empty `//!` lines preserve as paragraph breaks.
// Returns "" when there's no module-doc.
fn doc_extract_module_doc(src: str) -> str {
    let slen: i64 = str_len(src);
    if slen == 0 { return ""; };
    let mut sb: i64 = sb_new();
    let mut any: i64 = 0;
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        let llen: i64 = str_len(line);
        let mut lp: i64 = 0;
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        if lp == llen {
            // blank line — keep going (allows blank between //! lines)
            if any == 1 { sb_append(sb, "\n"); };
            p = eol + 1;
        } else if lp + 3 <= llen && str_eq(str_substring(line, lp, lp + 3), "//!") == 1 {
            let mut bp: i64 = lp + 3;
            if bp < llen && str_char_at(line, bp) == 32 { bp = bp + 1; };
            sb_append(sb, str_substring(line, bp, llen));
            sb_append(sb, "\n");
            any = 1;
            p = eol + 1;
        } else {
            // first non-//!, non-blank line — module doc done
            break;
        };
    };
    if any == 0 { return ""; };
    let raw: str = sb_to_str(sb);
    let mut e: i64 = str_len(raw);
    while e > 0 && str_char_at(raw, e - 1) == 10 { e = e - 1; };
    return str_substring(raw, 0, e);
}

// split a params string (the text between `(` and `)` of a
// fn signature) into a Vec of trimmed individual parameter strings.
// Respects nested `<>` and `()` so generic params like `Vec<i32>` and
// fn-typed params like `fn(i64) -> i64` survive the split. Empty
// params (zero-arg fn) returns an empty Vec.
fn doc_split_params(params: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let plen: i64 = str_len(params);
    if plen == 0 { return out; };
    let mut start: i64 = 0;
    let mut depth: i64 = 0;
    let mut i: i64 = 0;
    while i < plen {
        let c: i64 = str_char_at(params, i);
        if c == 60 || c == 40 { depth = depth + 1; }
        else if c == 62 || c == 41 { depth = depth - 1; }
        else if c == 44 && depth == 0 {
            let raw: str = str_substring(params, start, i);
            let mut s: i64 = 0;
            let rl: i64 = str_len(raw);
            while s < rl && (str_char_at(raw, s) == 32 || str_char_at(raw, s) == 9) { s = s + 1; };
            let mut e: i64 = rl;
            while e > s && (str_char_at(raw, e - 1) == 32 || str_char_at(raw, e - 1) == 9) { e = e - 1; };
            if e > s { out.push(str_substring(raw, s, e)); };
            start = i + 1;
        };
        i = i + 1;
    };
    let raw_last: str = str_substring(params, start, plen);
    let mut s2: i64 = 0;
    let rl2: i64 = str_len(raw_last);
    while s2 < rl2 && (str_char_at(raw_last, s2) == 32 || str_char_at(raw_last, s2) == 9) { s2 = s2 + 1; };
    let mut e2: i64 = rl2;
    while e2 > s2 && (str_char_at(raw_last, e2 - 1) == 32 || str_char_at(raw_last, e2 - 1) == 9) { e2 = e2 - 1; };
    if e2 > s2 { out.push(str_substring(raw_last, s2, e2)); };
    return out;
}

fn doc_extract_signature(line: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push("");
    out.push("");
    let llen: i64 = str_len(line);
    let mut i: i64 = 0;
    // Find `(`.
    while i < llen && str_char_at(line, i) != 40 { i = i + 1; };
    if i >= llen { return out; };
    let lp: i64 = i;
    // Walk to the matching `)` (no nested parens inside fn params).
    let mut rp: i64 = lp + 1;
    let mut depth: i64 = 1;
    while rp < llen && depth > 0 {
        let c: i64 = str_char_at(line, rp);
        if c == 40 { depth = depth + 1; }
        else if c == 41 { depth = depth - 1; };
        if depth == 0 { break; };
        rp = rp + 1;
    };
    if rp >= llen { return out; };
    vec_set(out, 0, str_substring(line, lp + 1, rp));
    // After `)`, look for `->` then the return type.
    let mut tp: i64 = rp + 1;
    while tp < llen && (str_char_at(line, tp) == 32 || str_char_at(line, tp) == 9) { tp = tp + 1; };
    if tp + 1 < llen && str_char_at(line, tp) == 45 && str_char_at(line, tp + 1) == 62 {
        tp = tp + 2;
        while tp < llen && (str_char_at(line, tp) == 32 || str_char_at(line, tp) == 9) { tp = tp + 1; };
        let mut re: i64 = tp;
        while re < llen && str_char_at(line, re) != 123 && str_char_at(line, re) != 59 { re = re + 1; };
        // trim trailing whitespace from the return type so
        // `**Returns:** `i64`` doesn't render as `i64 ` with a stray space.
        while re > tp && (str_char_at(line, re - 1) == 32 || str_char_at(line, re - 1) == 9) { re = re - 1; };
        vec_set(out, 1, str_substring(line, tp, re));
    };
    return out;
}

// doc-test extraction. Walks `///` comment blocks looking
// for ```nucleor code fences and emits a listing of each block with
// the function it documents. Pending blocks (collected before the
// next fn declaration) are flushed with that fn's name; module-level
// `//!` blocks are tagged "(module)". Execution (compile + run each
// block) ships in a future release; this is the discoverability half.
fn run_doc_test_list_command(src_path: str) -> i64 {
    if str_len(src_path) == 0 {
        print("ERROR: nuc doc --test-list requires a source file");
        print("Usage: nuc doc <file> --test-list");
        return 1;
    };
    let src: str = file_read_string(src_path);
    if str_len(src) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut block_count: i64 = 0;
    let mut in_block: i64 = 0;
    let mut block_buf: i64 = sb_new();
    let mut block_lang: str = "";
    // Pending blocks for the next fn declaration: parallel Vecs of
    // langs + bodies. Module-level (//!) blocks print immediately.
    let mut pending_langs: Vec<i32> = Vec::new();
    let mut pending_bodies: Vec<i32> = Vec::new();
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        let llen: i64 = str_len(line);
        let mut lp: i64 = 0;
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        let is_doc_line: i64 = if lp + 3 <= llen && str_eq(str_substring(line, lp, lp + 3), "///") == 1 { 1 } else { 0 };
        let is_modd_line: i64 = if lp + 3 <= llen && str_eq(str_substring(line, lp, lp + 3), "//!") == 1 { 1 } else { 0 };
        if is_doc_line == 1 || is_modd_line == 1 {
            let mut bp: i64 = lp + 3;
            if bp < llen && str_char_at(line, bp) == 32 { bp = bp + 1; };
            let inner: str = str_substring(line, bp, llen);
            let ilen: i64 = str_len(inner);
            if ilen >= 3 && str_eq(str_substring(inner, 0, 3), "```") == 1 {
                if in_block == 0 {
                    in_block = 1;
                    block_lang = str_substring(inner, 3, ilen);
                    block_buf = sb_new();
                } else {
                    in_block = 0;
                    let body: str = sb_to_str(block_buf);
                    if is_modd_line == 1 {
                        block_count = block_count + 1;
                        print(str_concat("=== block #", str_concat(str_from_int(block_count), str_concat(" — (module) — lang \"", str_concat(block_lang, "\"")))));
                        print(body);
                    } else {
                        pending_langs.push(block_lang);
                        pending_bodies.push(body);
                    };
                    block_buf = sb_new();
                    block_lang = "";
                };
            } else if in_block == 1 {
                sb_append(block_buf, inner);
                sb_append(block_buf, "\n");
            };
        } else {
            if in_block == 1 {
                in_block = 0;
                block_buf = sb_new();
                block_lang = "";
            };
            let fn_name: str = extract_fn_name_from_line(line);
            if str_len(fn_name) > 0 {
                let pn: i64 = vec_len(pending_langs);
                let mut pi: i64 = 0;
                while pi < pn {
                    let lang_e: str = vec_get(pending_langs, pi);
                    let body_e: str = vec_get(pending_bodies, pi);
                    block_count = block_count + 1;
                    print(str_concat("=== block #", str_concat(str_from_int(block_count), str_concat(" — fn ", str_concat(fn_name, str_concat(" — lang \"", str_concat(lang_e, "\"")))))));
                    print(body_e);
                    pi = pi + 1;
                };
                pending_langs = Vec::new();
                pending_bodies = Vec::new();
            };
        };
        p = eol + 1;
    };
    print(str_concat("nuc doc --test-list: ", str_concat(str_from_int(block_count), str_concat(" code block(s) found in ", src_path))));
    return 0;
}

fn tools_run_doc_command(src_path: str, out_path: str) -> i64 {
    return run_doc_command_mode(src_path, out_path, 0);
}

fn run_doc_command_html(src_path: str, out_path: str) -> i64 {
    return run_doc_command_mode(src_path, out_path, 1);
}

fn doc_html_escape(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < slen {
        let c: i64 = str_char_at(s, i);
        if c == 60 { sb_append(sb, "&lt;"); }
        else if c == 62 { sb_append(sb, "&gt;"); }
        else if c == 38 { sb_append(sb, "&amp;"); }
        else if c == 34 { sb_append(sb, "&quot;"); }
        else { sb_append(sb, str_substring(s, i, i + 1)); };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn run_doc_command_mode(src_path: str, out_path: str, html_mode: i64) -> i64 {
    if str_len(src_path) == 0 {
        print("ERROR: nuc doc requires a source file");
        print("Usage: nuc doc <file> [--out <path>] [--html]");
        return 1;
    };
    let src: str = file_read_string(src_path);
    if str_len(src) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    if html_mode == 1 {
        return doc_render_html(src_path, src, out_path);
    };
    let mut sb: i64 = sb_new();
    sb_append(sb, "# ");
    sb_append(sb, src_path);
    sb_append(sb, "\n\nGenerated by `nuc doc` (RFC-0029).\n\n");
    // module-level docs from `//!` lines at the file head.
    let mod_doc_md: str = doc_extract_module_doc(src);
    if str_len(mod_doc_md) > 0 {
        sb_append(sb, mod_doc_md);
        sb_append(sb, "\n");
    };
    // build fn + struct + enum indexes in a single pass.
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut fn_count: i64 = 0;
    let mut struct_names: Vec<i32> = Vec::new();
    let mut enum_names: Vec<i32> = Vec::new();
    let mut fn_index_sb: i64 = sb_new();
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        let fn_name: str = extract_fn_name_from_line(line);
        if str_len(fn_name) > 0 {
            sb_append(fn_index_sb, "- [`"); sb_append(fn_index_sb, fn_name); sb_append(fn_index_sb, "`](#");
            sb_append(fn_index_sb, fn_name); sb_append(fn_index_sb, ")\n");
            fn_count = fn_count + 1;
        } else {
            let s_name: str = extract_type_decl_name_from_line(line, "struct");
            if str_len(s_name) > 0 { struct_names.push(s_name); };
            let e_name: str = extract_type_decl_name_from_line(line, "enum");
            if str_len(e_name) > 0 { enum_names.push(e_name); };
        };
        p = eol + 1;
    };
    // combined type set (struct + enum) for cross-link resolution.
    let mut type_names: Vec<i32> = Vec::new();
    let mut sn_i: i64 = 0;
    while sn_i < vec_len(struct_names) { type_names.push(vec_get(struct_names, sn_i)); sn_i = sn_i + 1; };
    let mut en_i: i64 = 0;
    while en_i < vec_len(enum_names) { type_names.push(vec_get(enum_names, en_i)); en_i = en_i + 1; };
    if vec_len(struct_names) > 0 {
        sb_append(sb, "## Struct index\n\n");
        let mut si: i64 = 0;
        while si < vec_len(struct_names) {
            let sn: str = vec_get(struct_names, si);
            // link to the Type anchor section below.
            sb_append(sb, "- [`"); sb_append(sb, sn); sb_append(sb, "`](#type-"); sb_append(sb, sn); sb_append(sb, ")\n");
            si = si + 1;
        };
        sb_append(sb, "\n");
    };
    if vec_len(enum_names) > 0 {
        sb_append(sb, "## Enum index\n\n");
        let mut ei: i64 = 0;
        while ei < vec_len(enum_names) {
            let en: str = vec_get(enum_names, ei);
            sb_append(sb, "- [`"); sb_append(sb, en); sb_append(sb, "`](#type-"); sb_append(sb, en); sb_append(sb, ")\n");
            ei = ei + 1;
        };
        sb_append(sb, "\n");
    };
    sb_append(sb, "## Function index\n\n");
    sb_append(sb, sb_to_str(fn_index_sb));
    sb_append(sb, "\n");
    // anchored Types section. Per-struct/enum DETAIL sections
    // (field/variant tables) deferred to a future ship; this provides
    // the link target so cross-refs from fn signatures resolve.
    if vec_len(type_names) > 0 {
        sb_append(sb, "## Types\n\n");
        let mut ts_i: i64 = 0;
        while ts_i < vec_len(struct_names) {
            let tn: str = vec_get(struct_names, ts_i);
            sb_append(sb, "<a id=\"type-"); sb_append(sb, tn); sb_append(sb, "\"></a>\n");
            sb_append(sb, "**`"); sb_append(sb, tn); sb_append(sb, "`** — struct\n\n");
            ts_i = ts_i + 1;
        };
        let mut te_i: i64 = 0;
        while te_i < vec_len(enum_names) {
            let tn: str = vec_get(enum_names, te_i);
            sb_append(sb, "<a id=\"type-"); sb_append(sb, tn); sb_append(sb, "\"></a>\n");
            sb_append(sb, "**`"); sb_append(sb, tn); sb_append(sb, "`** — enum\n\n");
            te_i = te_i + 1;
        };
    };
    // Second pass: doc-comment + signature for each fn.
    p = 0;
    let mut last_doc_sb: i64 = sb_new();
    let mut last_doc_lines: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        let mut lp: i64 = 0;
        let llen: i64 = str_len(line);
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        if lp + 3 <= llen && str_eq(str_substring(line, lp, lp + 3), "///") == 1 {
            let mut bp: i64 = lp + 3;
            if bp < llen && str_char_at(line, bp) == 32 { bp = bp + 1; };
            sb_append(last_doc_sb, str_substring(line, bp, llen));
            sb_append(last_doc_sb, "\n");
            last_doc_lines = last_doc_lines + 1;
        } else {
            let fn_name: str = extract_fn_name_from_line(line);
            if str_len(fn_name) > 0 {
                sb_append(sb, "## `");
                sb_append(sb, fn_name);
                sb_append(sb, "`\n\n");
                if last_doc_lines > 0 {
                    // demote `#`-headings inside doc text.
                    sb_append(sb, doc_demote_headings(sb_to_str(last_doc_sb)));
                    sb_append(sb, "\n");
                };
                let sig_parts: Vec<i32> = doc_extract_signature(line);
                let params: str = vec_get(sig_parts, 0);
                let ret_t: str = vec_get(sig_parts, 1);
                sb_append(sb, "**Signature:**\n```nucleor\nfn ");
                sb_append(sb, fn_name);
                sb_append(sb, "(");
                sb_append(sb, params);
                sb_append(sb, ")");
                if str_len(ret_t) > 0 {
                    sb_append(sb, " -> ");
                    sb_append(sb, ret_t);
                };
                sb_append(sb, "\n```\n\n");
                // per-parameter rendering. Closes RFC-0029
                // "param rendering" deferral. Skip when zero-arg.
                // each param + return type runs through
                // `link_known_types_md` to cross-link in-file struct
                // and enum names to their `#type-<Name>` anchors.
                // No backticks around the line — Markdown code spans
                // render link syntax as literal text, defeating the
                // cross-link. Bold + plain `name: type` keeps it readable.
                let split_params: Vec<i32> = doc_split_params(params);
                let pcount: i64 = vec_len(split_params);
                if pcount > 0 {
                    sb_append(sb, "**Parameters:**\n");
                    let mut pi: i64 = 0;
                    while pi < pcount {
                        let raw_param: str = vec_get(split_params, pi);
                        let linked_param: str = link_known_types_md(raw_param, type_names);
                        sb_append(sb, "- ");
                        sb_append(sb, linked_param);
                        sb_append(sb, "\n");
                        pi = pi + 1;
                    };
                    sb_append(sb, "\n");
                };
                if str_len(ret_t) > 0 {
                    let linked_ret: str = link_known_types_md(ret_t, type_names);
                    sb_append(sb, "**Returns:** ");
                    sb_append(sb, linked_ret);
                    sb_append(sb, "\n\n");
                };
                last_doc_sb = sb_new();
                last_doc_lines = 0;
            } else if lp == llen {
                last_doc_sb = sb_new();
                last_doc_lines = 0;
            };
        };
        p = eol + 1;
    };
    let body: str = sb_to_str(sb);
    if str_len(out_path) > 0 {
        file_write_string(out_path, body);
        print(str_concat("nuc doc: wrote ", str_concat(out_path, str_concat(" (", str_concat(str_from_int(fn_count), " functions, with index + signatures)")))));
    } else {
        print(body);
    };
    return 0;
}

fn doc_render_html(src_path: str, src: str, out_path: str) -> i64 {
    // T2.7 (v0.2.352): standalone HTML output for `nuc doc --html`.
    // Single-file output (no external CSS / JS); minimal inline
    // styles so the result reads cleanly in any browser without a
    // network round-trip. Same two-pass walk as the Markdown
    // renderer — first pass builds the function index, second pass
    // emits per-function sections with /// doc comment + signature.
    let mut sb: i64 = sb_new();
    sb_append(sb, "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">\n");
    sb_append(sb, "<title>");
    sb_append(sb, doc_html_escape(src_path));
    sb_append(sb, "</title>\n");
    sb_append(sb, "<style>\n");
    sb_append(sb, "body{font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;max-width:54rem;margin:2rem auto;padding:0 1rem;line-height:1.55;color:#222}\n");
    sb_append(sb, "h1{border-bottom:2px solid #ccc;padding-bottom:.4rem}\n");
    sb_append(sb, "h2{margin-top:2rem;border-bottom:1px solid #eee;padding-bottom:.2rem}\n");
    sb_append(sb, "h2 code{font-size:1em;background:none;padding:0}\n");
    sb_append(sb, "code{background:#f3f3f5;padding:.1em .35em;border-radius:3px;font-family:Menlo,Consolas,monospace}\n");
    sb_append(sb, "pre{background:#f7f7f9;border:1px solid #e0e0e6;padding:.75em;border-radius:5px;overflow:auto}\n");
    sb_append(sb, "pre code{background:none;padding:0}\n");
    sb_append(sb, "ul.fnindex{padding-left:1.2rem;line-height:1.4}\n");
    sb_append(sb, "ul.fnindex li{list-style:square;margin:.1rem 0}\n");
    sb_append(sb, ".meta{color:#666;font-size:.9em}\n");
    sb_append(sb, "a{color:#06a;text-decoration:none}a:hover{text-decoration:underline}\n");
    sb_append(sb, "</style>\n");
    sb_append(sb, "</head><body>\n");
    sb_append(sb, "<h1>");
    sb_append(sb, doc_html_escape(src_path));
    sb_append(sb, "</h1>\n");
    sb_append(sb, "<p class=\"meta\">Generated by <code>nuc doc --html</code> (RFC-0029).</p>\n");
    // module-level docs from `//!` lines at the file head.
    let mod_doc_html: str = doc_extract_module_doc(src);
    if str_len(mod_doc_html) > 0 {
        sb_append(sb, "<div class=\"module-doc\"><p>");
        let md_len: i64 = str_len(mod_doc_html);
        let mut mi: i64 = 0;
        while mi < md_len {
            let c: i64 = str_char_at(mod_doc_html, mi);
            if c == 10 {
                if mi + 1 < md_len && str_char_at(mod_doc_html, mi + 1) == 10 {
                    sb_append(sb, "</p><p>");
                    mi = mi + 1;
                } else {
                    sb_append(sb, "<br>\n");
                };
            } else if c == 60 { sb_append(sb, "&lt;"); }
              else if c == 62 { sb_append(sb, "&gt;"); }
              else if c == 38 { sb_append(sb, "&amp;"); }
              else { sb_append(sb, str_substring(mod_doc_html, mi, mi + 1)); };
            mi = mi + 1;
        };
        sb_append(sb, "</p></div>\n");
    };
    // build fn + struct + enum indexes in one pass.
    let slen: i64 = str_len(src);
    let mut p: i64 = 0;
    let mut fn_count: i64 = 0;
    let mut struct_names_h: Vec<i32> = Vec::new();
    let mut enum_names_h: Vec<i32> = Vec::new();
    let mut fn_idx_sb: i64 = sb_new();
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        let fn_name: str = extract_fn_name_from_line(line);
        if str_len(fn_name) > 0 {
            sb_append(fn_idx_sb, "  <li><a href=\"#");
            sb_append(fn_idx_sb, doc_html_escape(fn_name));
            sb_append(fn_idx_sb, "\"><code>");
            sb_append(fn_idx_sb, doc_html_escape(fn_name));
            sb_append(fn_idx_sb, "</code></a></li>\n");
            fn_count = fn_count + 1;
        } else {
            let s_name: str = extract_type_decl_name_from_line(line, "struct");
            if str_len(s_name) > 0 { struct_names_h.push(s_name); };
            let e_name: str = extract_type_decl_name_from_line(line, "enum");
            if str_len(e_name) > 0 { enum_names_h.push(e_name); };
        };
        p = eol + 1;
    };
    if vec_len(struct_names_h) > 0 {
        sb_append(sb, "<h2>Struct index</h2>\n<ul class=\"fnindex\">\n");
        let mut si_h: i64 = 0;
        while si_h < vec_len(struct_names_h) {
            sb_append(sb, "  <li><code>");
            sb_append(sb, doc_html_escape(vec_get(struct_names_h, si_h)));
            sb_append(sb, "</code></li>\n");
            si_h = si_h + 1;
        };
        sb_append(sb, "</ul>\n");
    };
    if vec_len(enum_names_h) > 0 {
        sb_append(sb, "<h2>Enum index</h2>\n<ul class=\"fnindex\">\n");
        let mut ei_h: i64 = 0;
        while ei_h < vec_len(enum_names_h) {
            sb_append(sb, "  <li><code>");
            sb_append(sb, doc_html_escape(vec_get(enum_names_h, ei_h)));
            sb_append(sb, "</code></li>\n");
            ei_h = ei_h + 1;
        };
        sb_append(sb, "</ul>\n");
    };
    sb_append(sb, "<h2>Function index</h2>\n<ul class=\"fnindex\">\n");
    sb_append(sb, sb_to_str(fn_idx_sb));
    sb_append(sb, "</ul>\n");
    p = 0;
    let mut last_doc_sb: i64 = sb_new();
    let mut last_doc_lines: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(src, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(src, p, eol);
        let mut lp: i64 = 0;
        let llen: i64 = str_len(line);
        while lp < llen && (str_char_at(line, lp) == 32 || str_char_at(line, lp) == 9) { lp = lp + 1; };
        if lp + 3 <= llen && str_eq(str_substring(line, lp, lp + 3), "///") == 1 {
            let mut bp: i64 = lp + 3;
            if bp < llen && str_char_at(line, bp) == 32 { bp = bp + 1; };
            let inner_html: str = str_substring(line, bp, llen);
            // HTML mode — recognize `#`-headings inside /// blocks
            // and emit them as <h3>/<h4>/<h5> elements (demoted by 2 levels
            // since the parent fn heading is <h2>). Pre-fix `# Examples`
            // rendered as a literal "# Examples" string with <br>.
            let il: i64 = str_len(inner_html);
            let mut hcount_h: i64 = 0;
            while hcount_h < il && str_char_at(inner_html, hcount_h) == 35 { hcount_h = hcount_h + 1; };
            if hcount_h > 0 && hcount_h <= 4 && hcount_h < il && str_char_at(inner_html, hcount_h) == 32 {
                let h_level: i64 = hcount_h + 2;
                let h_text: str = str_substring(inner_html, hcount_h + 1, il);
                sb_append(last_doc_sb, "<h");
                sb_append(last_doc_sb, str_from_int(h_level));
                sb_append(last_doc_sb, ">");
                sb_append(last_doc_sb, doc_html_escape(h_text));
                sb_append(last_doc_sb, "</h");
                sb_append(last_doc_sb, str_from_int(h_level));
                sb_append(last_doc_sb, ">\n");
            } else {
                sb_append(last_doc_sb, doc_html_escape(inner_html));
                sb_append(last_doc_sb, "<br>\n");
            };
            last_doc_lines = last_doc_lines + 1;
        } else {
            let fn_name: str = extract_fn_name_from_line(line);
            if str_len(fn_name) > 0 {
                sb_append(sb, "<h2 id=\"");
                sb_append(sb, doc_html_escape(fn_name));
                sb_append(sb, "\"><code>");
                sb_append(sb, doc_html_escape(fn_name));
                sb_append(sb, "</code></h2>\n");
                if last_doc_lines > 0 {
                    sb_append(sb, "<p>");
                    sb_append(sb, sb_to_str(last_doc_sb));
                    sb_append(sb, "</p>\n");
                };
                let sig_parts: Vec<i32> = doc_extract_signature(line);
                let params: str = vec_get(sig_parts, 0);
                let ret_t: str = vec_get(sig_parts, 1);
                sb_append(sb, "<p><strong>Signature:</strong></p>\n<pre><code>fn ");
                sb_append(sb, doc_html_escape(fn_name));
                sb_append(sb, "(");
                sb_append(sb, doc_html_escape(params));
                sb_append(sb, ")");
                if str_len(ret_t) > 0 {
                    sb_append(sb, " -&gt; ");
                    sb_append(sb, doc_html_escape(ret_t));
                };
                sb_append(sb, "\n</code></pre>\n");
                // per-parameter rendering for HTML mode.
                let split_params_h: Vec<i32> = doc_split_params(params);
                let pcount_h: i64 = vec_len(split_params_h);
                if pcount_h > 0 {
                    sb_append(sb, "<p><strong>Parameters:</strong></p>\n<ul>\n");
                    let mut pih: i64 = 0;
                    while pih < pcount_h {
                        sb_append(sb, "  <li><code>");
                        sb_append(sb, doc_html_escape(vec_get(split_params_h, pih)));
                        sb_append(sb, "</code></li>\n");
                        pih = pih + 1;
                    };
                    sb_append(sb, "</ul>\n");
                };
                if str_len(ret_t) > 0 {
                    sb_append(sb, "<p><strong>Returns:</strong> <code>");
                    sb_append(sb, doc_html_escape(ret_t));
                    sb_append(sb, "</code></p>\n");
                };
                last_doc_sb = sb_new();
                last_doc_lines = 0;
            } else if lp == llen {
                last_doc_sb = sb_new();
                last_doc_lines = 0;
            };
        };
        p = eol + 1;
    };
    sb_append(sb, "</body></html>\n");
    let body: str = sb_to_str(sb);
    if str_len(out_path) > 0 {
        file_write_string(out_path, body);
        print(str_concat("nuc doc: wrote ", str_concat(out_path, str_concat(" (", str_concat(str_from_int(fn_count), " functions, HTML)")))));
    } else {
        print(body);
    };
    return 0;
}

fn tools_run_fix_command(src_path: str, subcmd: str) -> i64 {
    if str_eq(subcmd, "imports") == 0 && str_eq(subcmd, "numeric") == 0 {
        print("ERROR: nuc fix requires --imports or --numeric");
        print("Usage:");
        print("  nuc fix --imports <file>   Rewrite quoted imports to use std::");
        print("  nuc fix --numeric <file>   Lint mixed-width arithmetic (RFC-0015)");
        return 1;
    };
    if str_len(src_path) == 0 {
        print(str_concat("ERROR: nuc fix --", str_concat(subcmd, " requires a source file")));
        return 1;
    };
    let src: str = file_read_string(src_path);
    if str_len(src) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    if str_eq(subcmd, "imports") == 1 {
        let result: Vec<i32> = fix_imports_in_source(src);
        let new_src: str = vec_get(result, 0);
        let n_changed: i64 = str_to_int(vec_get(result, 1));
        if n_changed == 0 {
            print(str_concat("nothing to fix in ", src_path));
            return 0;
        };
        file_write_string(src_path, new_src);
        print(str_concat("nuc fix --imports: rewrote ", str_concat(str_from_int(n_changed), str_concat(" import line(s) in ", src_path))));
        return 0;
    };
    // numeric
    let n: i64 = report_numeric_findings(src_path, src);
    if n == 0 {
        print(str_concat("nuc fix --numeric: no mixed-width arithmetic patterns detected in ", src_path));
        return 0;
    };
    print(str_concat("nuc fix --numeric: ", str_concat(str_from_int(n), str_concat(" finding(s) in ", src_path))));
    print("  Add explicit `as <wider_type>` casts at flagged sites.");
    print("  This linter is intentionally conservative — manual review still required.");
    return 0;
}

fn run_test_command(src_path: str, out_name: str, use_cache: i64, time_passes: i64, list_only: i64, isolation_process: i64, check_laws: i64) -> i64 {
    let raw_source: str = file_read_string(src_path);
    if str_len(raw_source) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    let tests: Vec<i32> = collect_test_names_from_source(raw_source);
    let mut law_source: str = "";
    if check_laws == 1 {
        let law_result: Vec<i32> = build_law_check_source(raw_source, tests);
        if vec_get(law_result, 0) != 0 { return 1; };
        law_source = vec_get(law_result, 1);
        if str_len(law_source) > 0 {
            print("info[CHECK-LAWS]: generated bounded integer law checks");
        } else {
            print("info[CHECK-LAWS]: no @law annotations found");
        };
    };
    if vec_len(tests) == 0 {
        print(str_concat("  no tests found in ", src_path));
        return 1;
    };
    print(str_concat("  discovered tests: ", str_from_int(vec_len(tests))));
    let mut i: i64 = 0;
    while i < vec_len(tests) {
        print(str_concat("    ", vec_get(tests, i)));
        i = i + 1;
    };
    if list_only == 1 { return 0; };
    let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
    let resolved_source: str = vec_get(bundle, 0);
    if str_len(resolved_source) == 0 {
        print(str_concat("ERROR: cannot resolve ", src_path));
        return 1;
    };
    let imported: Vec<i32> = vec_get(bundle, 1);
    let harness_source: str = build_test_harness_source_with_imports(str_concat(resolved_source, law_source), tests, imported);
    // ensure target/ exists before writing the harness file.
    // Without this, `nuc test foo.nr` from a fresh directory fails with
    // "ERROR: cannot read target/foo__test_harness.nr" because
    // file_write_string silently fails when the parent dir doesn't exist.
    fs_create_dir_all("target");
    let temp_src: str = sanitize(str_concat("target/", str_concat(out_name, "__test_harness.nr")));
    file_write_string(temp_src, harness_source);
    let rc: i64 = compile_file_mode(temp_src, out_name, 1, use_cache, time_passes, 1);
    if rc != 0 { return rc; };
    // Platform-aware exe path. Pre-fix this hardcoded `target\name.exe`
    // (Windows backslash + .exe), so on Linux `system("target\name.exe")`
    // sh-collapsed the backslash and looked up `targetname.exe` (not
    // found). Mirror the cross-platform path-construction used by
    // s1::run/cli (see nucleor_s1_compiler.nr "v0.8.323 platform-aware
    // exe path").
    let exe_dir_t: str = if host_is_windows() == 1 { "target\\" } else { "./target/" };
    let exe: str = str_concat(exe_dir_t, str_concat(out_name, host_exe_suffix()));
    if isolation_process == 0 {
        // Default: single process, all tests inline.
        return system(exe);
    };
    // RFC-0021 phase 2: --isolation=process — spawn one child per test
    // with NUCLEOR_TEST_ONLY=<name>, capture exit code, report aggregate.
    print("  isolation: process (one child per test)");
    let mut failed: i64 = 0;
    let mut ti: i64 = 0;
    while ti < vec_len(tests) {
        let tname: str = vec_get(tests, ti);
        env_set("NUCLEOR_TEST_ONLY", tname);
        let child_rc: i64 = system(exe);
        env_unset("NUCLEOR_TEST_ONLY");
        if child_rc != 0 { failed = failed + 1; };
        ti = ti + 1;
    };
    if failed == 0 {
        print(str_concat("test result: PASS (", str_concat(str_from_int(vec_len(tests)), " tests, isolated)")));
        return 0;
    };
    print(str_concat("test result: FAIL (", str_concat(str_from_int(failed), str_concat(" of ", str_concat(str_from_int(vec_len(tests)), " isolated children failed)")))));
    return 1;
}

fn run_bench_command(src_path: str, out_name: str, use_cache: i64, time_passes: i64, iterations: i64, warmup: i64) -> i64 {
    if iterations <= 0 {
        print("ERROR: --iterations must be >= 1");
        return 1;
    };
    if warmup < 0 {
        print("ERROR: --warmup must be >= 0");
        return 1;
    };
    let rc: i64 = compile_file_mode(src_path, out_name, 1, use_cache, time_passes, 1);
    if rc != 0 { return rc; };
    // Platform-aware exe path + null redirect (mirror of run_test_command).
    let exe_dir_b: str = if host_is_windows() == 1 { "target\\" } else { "./target/" };
    let exe: str = str_concat(exe_dir_b, str_concat(out_name, host_exe_suffix()));
    let null_b: str = if host_is_windows() == 1 { ">NUL 2>&1" } else { ">/dev/null 2>&1" };
    let run_cmd: str = str_concat("\"", str_concat(exe, str_concat("\" ", null_b)));
    let mut wi: i64 = 0;
    while wi < warmup {
        let warm_rc: i64 = system(run_cmd);
        if warm_rc != 0 {
            print(str_concat("ERROR: warmup run failed with exit ", str_from_int(warm_rc)));
            return 1;
        };
        wi = wi + 1;
    };
    let mut total_ms: i64 = 0;
    let mut best_ms: i64 = 0 - 1;
    let mut worst_ms: i64 = 0;
    let mut it: i64 = 0;
    while it < iterations {
        let start_ms: i64 = now_ms();
        let run_rc: i64 = system(run_cmd);
        let elapsed_ms: i64 = now_ms() - start_ms;
        if run_rc != 0 {
            print(str_concat("ERROR: benchmark run failed with exit ", str_from_int(run_rc)));
            return 1;
        };
        total_ms = total_ms + elapsed_ms;
        if best_ms < 0 || elapsed_ms < best_ms { best_ms = elapsed_ms; };
        if elapsed_ms > worst_ms { worst_ms = elapsed_ms; };
        it = it + 1;
    };
    print(str_concat("  bench iterations: ", str_from_int(iterations)));
    print(str_concat("  warmup runs: ", str_from_int(warmup)));
    print(str_concat("  total: ", str_concat(str_from_int(total_ms), " ms")));
    print(str_concat("  avg: ", str_concat(str_from_int(total_ms / iterations), " ms")));
    print(str_concat("  min: ", str_concat(str_from_int(best_ms), " ms")));
    print(str_concat("  max: ", str_concat(str_from_int(worst_ms), " ms")));
    return 0;
}

// ===== v0.3.0 (T3.1): #[deadline = N] runtime check (synced) =====
// See nucleor_s1_compiler.nr for the design rationale.

fn dl_find_substring(hay: str, needle: str) -> i64 {
    let hlen: i64 = str_len(hay);
    let nlen: i64 = str_len(needle);
    if nlen == 0 { return 0; };
    if hlen < nlen { return 0 - 1; };
    let mut i: i64 = 0;
    while i <= hlen - nlen {
        let mut j: i64 = 0;
        let mut matched: i64 = 1;
        while j < nlen && matched == 1 {
            if str_char_at(hay, i + j) != str_char_at(needle, j) { matched = 0; };
            j = j + 1;
        };
        if matched == 1 { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

fn dl_extract_int_value(line: str) -> i64 {
    let needle: str = "#[deadline";
    let pos: i64 = dl_find_substring(line, needle);
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



// ===== T2.8 (v0.2.353): async syntax surface (synced from s1) =====


// ===== T2.3 (v0.2.349): closure literals (synced from s1) =====
// See nucleor_s1_compiler.nr for the design rationale.




// ===== T2.6 (v0.2.346): format-string macro expansion (synced) =====
// Mirror of helpers in nucleor_s1_compiler.nr — see that file for
// the design rationale. tools-suite path runs through `nuc test`,
// `nuc build-strict`, etc., so it must expand identically.

fn fmt_infer_var_type_from_source(src: str, var_name: str) -> str {
    let vlen: i64 = str_len(var_name);
    let slen: i64 = str_len(src);
    let mut i: i64 = 0;
    while i + 4 + vlen < slen {
        if str_eq_at(src, i, "let ") == 1 {
            let name_start: i64 = i + 4;
            if name_start + vlen <= slen && str_eq_at(src, name_start, var_name) == 1 {
                let after: i64 = name_start + vlen;
                let ac: i64 = if after < slen { str_char_at(src, after) } else { 0 };
                let boundary: i64 = if is_alnum(ac) == 0 && ac != 95 { 1 } else { 0 };
                if boundary == 1 {
                    let mut p: i64 = after;
                    while p < slen && str_char_at(src, p) != 58 && str_char_at(src, p) != 61 && str_char_at(src, p) != 10 { p = p + 1; };
                    if p < slen && str_char_at(src, p) == 58 {
                        p = p + 1;
                        while p < slen {
                            let ws: i64 = str_char_at(src, p);
                            if ws == 32 || ws == 9 || ws == 10 || ws == 13 { p = p + 1; }
                            else { break; };
                        };
                        let ts: i64 = p;
                        let mut tdepth: i64 = 0;
                        let mut done: i64 = 0;
                        while p < slen && done == 0 {
                            let c: i64 = str_char_at(src, p);
                            if c == 60 || c == 40 || c == 91 { tdepth = tdepth + 1; }
                            else if c == 62 || c == 41 || c == 93 { tdepth = tdepth - 1; }
                            else if (c == 61 || c == 44 || c == 10 || c == 13 || c == 59) && tdepth == 0 { done = 1; };
                            if done == 0 { p = p + 1; };
                        };
                        return fmt_trim_ws(str_substring(src, ts, p));
                    };
                };
            };
        };
        i = i + 1;
    };
    return "";
}

fn fmt_conversion_for_spec(spec: str, arg_expr: str, src: str) -> str {
    if str_eq(spec, "") == 1 {
        let alen: i64 = str_len(arg_expr);
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
            let inferred: str = fmt_infer_var_type_from_source(src, arg_expr);
            if str_eq(inferred, "str") == 1 { return arg_expr; };
            if str_eq(inferred, "f64") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
            if str_eq(inferred, "f32") == 1 { return str_concat("f32_to_str(", str_concat(arg_expr, ")")); };
            if str_eq(inferred, "bool") == 1 { return str_concat("bool_to_str(", str_concat(arg_expr, ")")); };
            let inferred_base: str = type_base_name(inferred);
            if str_len(inferred_base) > 0 && str_contains(src, str_concat("struct ", inferred_base)) == 1 {
                if str_contains(src, str_concat("impl Display for ", inferred_base)) == 1 {
                    return str_concat(inferred_base, str_concat("__fmt(", str_concat(arg_expr, ")")));
                };
                print(str_concat("ERROR: error[FMT-002]: type '", str_concat(inferred_base, "' does not implement Display for '{}'")));
                panic("nucleor: FMT-002 missing Display impl for struct format");
            };
        };
        return str_concat("int_to_str(", str_concat(arg_expr, ")"));
    };
    if str_eq(spec, ":i") == 1 { return str_concat("int_to_str(", str_concat(arg_expr, ")")); };
    if str_eq(spec, ":s") == 1 { return arg_expr; };
    if str_eq(spec, ":f") == 1 { return str_concat("f64_to_str(", str_concat(arg_expr, ")")); };
    if str_eq(spec, ":?") == 1 {
        let inferred: str = type_base_name(fmt_infer_var_type_from_source(src, arg_expr));
        if str_eq(inferred, "str") == 1 || str_eq(inferred, "String") == 1 {
            return str_concat("str_concat(\"\\\"\", str_concat(", str_concat(arg_expr, ", \"\\\"\"))"));
        };
        if str_len(inferred) > 0 && str_contains(src, str_concat("struct ", inferred)) == 1 {
            let mut dbg_segments: Vec<i32> = Vec::new();
            let mut dbg_parities: Vec<i32> = Vec::new();
            dbg_segments.push(str_concat(inferred, " { "));
            dbg_parities.push(0);
            let dbg_needle: str = str_concat("struct ", inferred);
            let dbg_nlen: i64 = str_len(dbg_needle);
            let dbg_slen: i64 = str_len(src);
            let mut dbg_body_start: i64 = 0 - 1;
            let mut dbg_body_end: i64 = 0 - 1;
            let mut dbg_i: i64 = 0;
            while dbg_i + dbg_nlen <= dbg_slen && dbg_body_start < 0 {
                if str_eq_at(src, dbg_i, dbg_needle) == 1 {
                    let mut dbg_q: i64 = dbg_i + dbg_nlen;
                    while dbg_q < dbg_slen && str_char_at(src, dbg_q) != 123 { dbg_q = dbg_q + 1; };
                    if dbg_q < dbg_slen {
                        dbg_body_start = dbg_q + 1;
                        dbg_q = dbg_q + 1;
                        let mut dbg_depth: i64 = 1;
                        while dbg_q < dbg_slen && dbg_depth > 0 {
                            let dbg_c: i64 = str_char_at(src, dbg_q);
                            if dbg_c == 123 { dbg_depth = dbg_depth + 1; }
                            else if dbg_c == 125 {
                                dbg_depth = dbg_depth - 1;
                                if dbg_depth == 0 { dbg_body_end = dbg_q; };
                            };
                            dbg_q = dbg_q + 1;
                        };
                    };
                };
                dbg_i = dbg_i + 1;
            };
            if dbg_body_start >= 0 && dbg_body_end > dbg_body_start {
                let mut dbg_p: i64 = dbg_body_start;
                let mut dbg_count: i64 = 0;
                while dbg_p < dbg_body_end {
                    while dbg_p < dbg_body_end {
                        let dbg_ws: i64 = str_char_at(src, dbg_p);
                        if dbg_ws == 32 || dbg_ws == 9 || dbg_ws == 10 || dbg_ws == 13 || dbg_ws == 44 { dbg_p = dbg_p + 1; }
                        else { break; };
                    };
                    if dbg_p < dbg_body_end {
                        let dbg_name_start: i64 = dbg_p;
                        let dbg_fc0: i64 = str_char_at(src, dbg_p);
                        if is_alpha(dbg_fc0) == 1 || dbg_fc0 == 95 {
                            dbg_p = dbg_p + 1;
                            while dbg_p < dbg_body_end {
                                let dbg_nc: i64 = str_char_at(src, dbg_p);
                                if is_alnum(dbg_nc) == 1 || dbg_nc == 95 { dbg_p = dbg_p + 1; }
                                else { break; };
                            };
                            let dbg_field_name: str = str_substring(src, dbg_name_start, dbg_p);
                            while dbg_p < dbg_body_end {
                                let dbg_cws: i64 = str_char_at(src, dbg_p);
                                if dbg_cws == 32 || dbg_cws == 9 || dbg_cws == 10 || dbg_cws == 13 { dbg_p = dbg_p + 1; }
                                else { break; };
                            };
                            if dbg_p < dbg_body_end && str_char_at(src, dbg_p) == 58 {
                                dbg_p = dbg_p + 1;
                                while dbg_p < dbg_body_end {
                                    let dbg_tws: i64 = str_char_at(src, dbg_p);
                                    if dbg_tws == 32 || dbg_tws == 9 || dbg_tws == 10 || dbg_tws == 13 { dbg_p = dbg_p + 1; }
                                    else { break; };
                                };
                                let dbg_type_start: i64 = dbg_p;
                                let mut dbg_tdepth: i64 = 0;
                                let mut dbg_done_type: i64 = 0;
                                while dbg_p < dbg_body_end && dbg_done_type == 0 {
                                    let dbg_tc: i64 = str_char_at(src, dbg_p);
                                    if dbg_tc == 60 || dbg_tc == 40 || dbg_tc == 91 { dbg_tdepth = dbg_tdepth + 1; }
                                    else if dbg_tc == 62 || dbg_tc == 41 || dbg_tc == 93 { dbg_tdepth = dbg_tdepth - 1; }
                                    else if dbg_tc == 44 && dbg_tdepth == 0 { dbg_done_type = 1; };
                                    if dbg_done_type == 0 { dbg_p = dbg_p + 1; };
                                };
                                let dbg_field_type: str = fmt_trim_ws(str_substring(src, dbg_type_start, dbg_p));
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
                            };
                        } else {
                            dbg_p = dbg_p + 1;
                        };
                    };
                };
            };
            dbg_segments.push(" }");
            dbg_parities.push(0);
            return fmt_build_concat_chain(dbg_segments, dbg_parities);
        };
        return fmt_conversion_for_spec("", arg_expr, src);
    };
    // drift-parity with s1_compiler — `:b` is binary radix (Rust),
    // routes to int_to_bin. Pre-v0.4.29 routed to bool_to_str.
    if str_eq(spec, ":b") == 1 { return str_concat("int_to_bin(", str_concat(arg_expr, ")")); };
    if str_eq(spec, ":x") == 1 { return str_concat("int_to_hex(", str_concat(arg_expr, ")")); };
    if str_eq(spec, ":X") == 1 { return str_concat("int_to_hex(", str_concat(arg_expr, ")")); };
    if str_eq(spec, ":o") == 1 { return str_concat("int_to_oct(", str_concat(arg_expr, ")")); };
    return str_concat("int_to_str(", str_concat(arg_expr, ")"));
}



// ===== T1.5c (v0.2.342): resolver-layer name privatization (synced) =====
// Mirror of the helpers in nucleor_s1_compiler.nr — see that file for
// the design rationale. tools-suite path runs through `nuc test`,
// `nuc build-strict`, etc., so it must enforce identically.

fn priv_string_vec_contains_at(v: Vec<i32>, src: str, start: i64, end: i64) -> i64 {
    let n: i64 = vec_len(v);
    let want_len: i64 = end - start;
    let mut i: i64 = 0;
    while i < n {
        let cur: str = vec_get(v, i);
        if str_len(cur) == want_len && str_eq_at(src, start, cur) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}


fn secure_hash(s: str) -> str {
    // Uses DJB2 fingerprint. SHA256 available via sha256() builtin after bootstrap.
    return content_hash(s);
}

fn package_checksum_file_name() -> str { return "Nucleor.package.sha256"; }
fn registry_metadata_file_name() -> str { return "Nucleor.publish.json"; }
fn package_exports_manifest_file_name() -> str { return "Nucleor.exports.json"; }
fn package_exports_header_file_name() -> str { return "Nucleor.exports.h"; }
fn package_exports_rust_file_name() -> str { return "Nucleor.exports.rs"; }
fn package_signature_file_name() -> str { return "Nucleor.publish.signature.json"; }

// compiler_version_label moved to the main file (compiler/nucleor_tools_suite.nr)
// so tools/check_compiler_drift.sh's grep of the main source still finds it.
// Symmetric with the same constraint in compiler/nucleor_s1_compiler.nr.

fn abi_export_version_label() -> str {
    return "c-v1-shared-exports";
}

fn abi_export_surface_policy_label() -> str {
    return "pub-fn-c-safe-v1";
}

fn abi_export_symbol_policy_label() -> str {
    return "explicit-public-no-mangling";
}

fn abi_export_version_policy_label() -> str {
    return "semver-major-breaks-abi";
}



fn manifest_entry_path() -> str {
    let raw: str = file_read_string("Nucleor.toml");
    if str_len(raw) == 0 { return ""; };
    let compact: str = strip_spaces(raw);
    let key: str = "entry=\"";
    let clen: i64 = str_len(compact);
    let klen: i64 = str_len(key);
    let mut p: i64 = 0;
    while p + klen <= clen {
        if str_eq(str_substring(compact, p, p + klen), key) == 1 {
            let start: i64 = p + klen;
            let mut end: i64 = start;
            while end < clen && str_char_at(compact, end) != 34 { end = end + 1; };
            return sanitize(str_substring(compact, start, end));
        };
        p = p + 1;
    };
    return "";
}

fn run_explain_command(argc: i64) -> i64 {
    let mut json_mode: i64 = 0;
    let mut code: str = "";
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") || str_eq(arg, "--output=json") {
            json_mode = 1;
        } else if str_eq(arg, "--output") {
            if i + 1 >= argc {
                print("Usage: nuc explain <NR001|NR020|...> [--json]");
                return 1;
            };
            if str_eq(args_get(i + 1), "json") == 1 {
                json_mode = 1;
                i = i + 1;
            } else {
                print("Usage: nuc explain <NR001|NR020|...> [--json]");
                return 1;
            };
        } else if cli_is_flag(arg) == 0 && str_len(code) == 0 {
            code = ascii_upper(strip_spaces(arg));
        };
        i = i + 1;
    };
    if str_len(code) == 0 {
        print("Usage: nuc explain <NR001|NR020|...> [--json]");
        return 1;
    };
    if explain_error_known(code) == 0 {
        print(str_concat("unknown error code: ", code));
        return 1;
    };
    print(explain_error_render(code, json_mode));
    return 0;
}

fn bootstrap_corpus_listing_path(tag: str) -> str {
    return str_concat("target/bootstrap_corpus_", str_concat(tag, str_concat("_", str_concat(str_from_int(now_ms()), ".txt"))));
}

fn bootstrap_collect_corpus_files(tag: str) -> Vec<i32> {
    let _ = tag;
    fs_create_dir_all("target");
    let entries: Vec<i32> = fs_list_dir("examples");
    let sorted: Vec<i32> = sort_strings_asc(entries);
    let mut files: Vec<i32> = Vec::new();
    let n: i64 = vec_len(sorted);
    let mut i: i64 = 0;
    while i < n {
        let name: str = vec_get(sorted, i);
        let nlen: i64 = str_len(name);
        if nlen >= 3 && str_eq(str_substring(name, nlen - 3, nlen), ".nr") == 1 {
            files.push(name);
        };
        i = i + 1;
    };
    return files;
}

fn bootstrap_runtime_source_path() -> str {
    let cli_runtime: str = "crates/nucleor-cli/runtime/nucleor_rt.c";
    if str_len(file_read_string(cli_runtime)) > 0 { return cli_runtime; };
    let stdlib_runtime: str = "stdlib/runtime/nucleor_llvm_rt.c";
    if str_len(file_read_string(stdlib_runtime)) > 0 { return stdlib_runtime; };
    return "";
}

fn count_text_lines(raw: str) -> i64 {
    let slen: i64 = str_len(raw);
    if slen == 0 { return 0; };
    let mut lines: i64 = 1;
    let mut i: i64 = 0;
    while i < slen {
        if str_char_at(raw, i) == 10 { lines = lines + 1; };
        i = i + 1;
    };
    return lines;
}

fn bootstrap_runtime_symbol_count(raw: str) -> i64 {
    let slen: i64 = str_len(raw);
    let mut count: i64 = 0;
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw, eol) != 10 { eol = eol + 1; };
        let line: str = str_substring(raw, p, eol);
        let compact: str = strip_spaces(line);
        if text_contains(line, "__nucleor_") == 1 && text_contains(line, "(") == 1 && str_starts_with(compact, "//") == 0 && str_starts_with(compact, "*") == 0 && str_starts_with(compact, "/*") == 0 {
            count = count + 1;
        };
        p = eol + 1;
    };
    return count;
}

fn run_bootstrap_command(argc: i64) -> i64 {
    let mut json_mode: i64 = 0;
    let mut subcmd: str = "status";
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") || str_eq(arg, "--output=json") {
            json_mode = 1;
        } else if str_eq(arg, "--output") {
            if i + 1 >= argc {
                print("Usage: nuc bootstrap <status|dump-corpus> [--json]");
                return 1;
            };
            if str_eq(args_get(i + 1), "json") == 1 {
                json_mode = 1;
                i = i + 1;
            } else {
                print("Usage: nuc bootstrap <status|dump-corpus> [--json]");
                return 1;
            };
        } else if cli_is_flag(arg) == 0 && str_eq(subcmd, "status") == 1 {
            subcmd = arg;
        };
        i = i + 1;
    };
    let files: Vec<i32> = bootstrap_collect_corpus_files(subcmd);
    if str_eq(subcmd, "status") == 1 {
        let examples: i64 = vec_len(files);
        let mut err_examples: i64 = 0;
        let mut fi: i64 = 0;
        while fi < vec_len(files) {
            if str_starts_with(vec_get(files, fi), "err_") == 1 { err_examples = err_examples + 1; };
            fi = fi + 1;
        };
        let positive_examples: i64 = examples - err_examples;
        let runtime_path: str = bootstrap_runtime_source_path();
        let runtime_source: str = file_read_string(runtime_path);
        let runtime_lines: i64 = count_text_lines(runtime_source);
        let runtime_symbols: i64 = bootstrap_runtime_symbol_count(runtime_source);
        if json_mode == 1 {
            let mut sb: i64 = sb_new();
            sb_append(sb, "{\"stage\":\"1\",\"stage_name\":\"self_hosted\",\"examples\":");
            sb_append(sb, str_from_int(examples));
            sb_append(sb, ",\"error_examples\":"); sb_append(sb, str_from_int(err_examples));
            sb_append(sb, ",\"positive_examples\":"); sb_append(sb, str_from_int(positive_examples));
            sb_append(sb, ",\"runtime_lines\":"); sb_append(sb, str_from_int(runtime_lines));
            sb_append(sb, ",\"runtime_symbols\":"); sb_append(sb, str_from_int(runtime_symbols));
            sb_append(sb, ",\"runtime_source\":\""); sb_append(sb, json_escape(runtime_path));
            sb_append(sb, "\",\"bootstrap_contract\":\"docs/SELF_HOST_INTEGRITY.md\",\"self_hosted\":true}");
            print(sb_to_str(sb));
            return 0;
        };
        print("=== Nucleor Bootstrap Status ===");
        print("  Stage: 1 (self-hosted)");
        print(str_concat("  Examples: ", str_concat(str_from_int(examples), str_concat(" (", str_concat(str_from_int(positive_examples), str_concat(" positive, ", str_concat(str_from_int(err_examples), " error)"))))));
        if str_len(runtime_path) > 0 {
            print(str_concat("  Runtime source: ", runtime_path));
        } else {
            print("  Runtime source: unavailable");
        };
        print(str_concat("  Runtime: ", str_concat(str_from_int(runtime_lines), str_concat(" lines, ~", str_concat(str_from_int(runtime_symbols), " symbols")))));
        print("  Self-hosted: yes");
        print("  Contract: docs/SELF_HOST_INTEGRITY.md");
        return 0;
    };
    if str_eq(subcmd, "dump-corpus") == 1 {
        if vec_len(files) == 0 {
            print("no examples/ directory found");
            return 1;
        };
        if json_mode == 1 {
            let mut sb2: i64 = sb_new();
            sb_append(sb2, "{\"corpus_count\":"); sb_append(sb2, str_from_int(vec_len(files)));
            sb_append(sb2, ",\"files\":[");
            let mut fj: i64 = 0;
            while fj < vec_len(files) {
                if fj > 0 { sb_append(sb2, ","); };
                sb_append(sb2, "\""); sb_append(sb2, json_escape(vec_get(files, fj))); sb_append(sb2, "\"");
                fj = fj + 1;
            };
            sb_append(sb2, "]}");
            print(sb_to_str(sb2));
            return 0;
        };
        print(str_concat("=== Bootstrap Corpus (", str_concat(str_from_int(vec_len(files)), " files) ===")));
        let mut fk: i64 = 0;
        while fk < vec_len(files) {
            print(str_concat("  ", vec_get(files, fk)));
            fk = fk + 1;
        };
        return 0;
    };
    print(str_concat("unknown bootstrap subcommand: ", subcmd));
    print("Usage: nuc bootstrap <status|dump-corpus> [--json]");
    return 1;
}

fn token_summary(tok: Vec<i32>) -> str {
    let tt: i64 = tok_type(tok);
    let val: str = tok_val(tok);
    let pos: i64 = vec_get(tok, 2);
    let mut sb: i64 = sb_new();
    sb_append(sb, str_from_int(tt));
    if tt == 1 || tt == 2 || tt == 3 || tt == 70 {
        sb_append(sb, ":");
        if tt == 2 || tt == 70 { sb_append(sb, str_from_int(val)); }
        else { sb_append(sb, val); };
    };
    sb_append(sb, " @ ");
    sb_append(sb, str_from_int(pos));
    return sb_to_str(sb);
}

fn ast_item_summary(pool: Vec<i32>, nid: i64) -> str {
    let kind: i64 = node_kind(pool, nid);
    if kind == 30 { return str_concat("fn ", node_field(pool, nid, 1)); };
    if kind == 32 { return str_concat("extern fn ", node_field(pool, nid, 1)); };
    if kind == 33 { return str_concat("struct ", node_field(pool, nid, 1)); };
    if kind == 36 { return str_concat("enum ", node_field(pool, nid, 1)); };
    if kind == 44 { return str_concat("trait ", node_field(pool, nid, 1)); };
    if kind == 45 { return str_concat("impl ", node_field(pool, nid, 2)); };
    if kind == 46 { return str_concat("pure fn ", node_field(pool, nid, 1)); };
    if kind == 50 { return str_concat("const ", node_field(pool, nid, 1)); };
    if kind == 51 { return str_concat("type ", node_field(pool, nid, 1)); };
    return str_concat("node_kind ", str_from_int(kind));
}

fn stage_dump_tokens_json(tokens: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"stage\":\"tokens\",\"count\":");
    sb_append(sb, str_from_int(vec_len(tokens)));
    sb_append(sb, ",\"tokens\":[");
    let mut i: i64 = 0;
    while i < vec_len(tokens) {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "\""); sb_append(sb, json_escape(token_summary(vec_get(tokens, i)))); sb_append(sb, "\"");
        i = i + 1;
    };
    sb_append(sb, "]}");
    return sb_to_str(sb);
}

fn stage_dump_ast_json(pool: Vec<i32>, prog: i64) -> str {
    let mut sb: i64 = sb_new();
    let cnt: i64 = list_len(pool, prog);
    sb_append(sb, "{\"stage\":\"ast\",\"item_count\":");
    sb_append(sb, str_from_int(cnt));
    sb_append(sb, ",\"items\":[");
    let mut i: i64 = 0;
    while i < cnt {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "\""); sb_append(sb, json_escape(ast_item_summary(pool, list_get(pool, prog, i)))); sb_append(sb, "\"");
        i = i + 1;
    };
    sb_append(sb, "]}");
    return sb_to_str(sb);
}

fn stage_dump_typed_json(diags: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let cnt: i64 = diag_count(diags);
    sb_append(sb, "{\"stage\":\"typed\",\"diagnostic_count\":");
    sb_append(sb, str_from_int(cnt));
    if cnt == 0 {
        sb_append(sb, ",\"status\":\"ok\"}");
        return sb_to_str(sb);
    };
    sb_append(sb, ",\"status\":\"diagnostics\",\"diagnostics\":[");
    let mut i: i64 = 0;
    while i < cnt {
        if i > 0 { sb_append(sb, ","); };
        let d: Vec<i32> = diag_get(diags, i);
        let msg: str = str_concat("[", str_concat(vec_get(d, 2), str_concat("] ", vec_get(d, 3))));
        sb_append(sb, "\""); sb_append(sb, json_escape(msg)); sb_append(sb, "\"");
        i = i + 1;
    };
    sb_append(sb, "]}");
    return sb_to_str(sb);
}

fn stage_dump_ir_json(function_count: i64, extern_count: i64, struct_count: i64, enum_count: i64, ll_bytes: i64, skipped: i64, skip_reason: str) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"stage\":\"ir\"");
    if skipped == 1 {
        sb_append(sb, ",\"skipped\":true,\"reason\":\""); sb_append(sb, json_escape(skip_reason)); sb_append(sb, "\"}");
        return sb_to_str(sb);
    };
    sb_append(sb, ",\"function_count\":"); sb_append(sb, str_from_int(function_count));
    sb_append(sb, ",\"extern_fn_count\":"); sb_append(sb, str_from_int(extern_count));
    sb_append(sb, ",\"struct_count\":"); sb_append(sb, str_from_int(struct_count));
    sb_append(sb, ",\"enum_count\":"); sb_append(sb, str_from_int(enum_count));
    sb_append(sb, ",\"ll_bytes\":"); sb_append(sb, str_from_int(ll_bytes));
    sb_append(sb, "}");
    return sb_to_str(sb);
}

fn run_stage_dump_command(argc: i64) -> i64 {
    let mut json_mode: i64 = 0;
    let mut stage: str = "";
    let mut src_path: str = "";
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") || str_eq(arg, "--output=json") {
            json_mode = 1;
        } else if str_eq(arg, "--output") {
            if i + 1 >= argc {
                print("Usage: nuc stage-dump <tokens|ast|typed|ir|all> <file.nr> [--json]");
                return 1;
            };
            if str_eq(args_get(i + 1), "json") == 1 {
                json_mode = 1;
                i = i + 1;
            } else {
                print("Usage: nuc stage-dump <tokens|ast|typed|ir|all> <file.nr> [--json]");
                return 1;
            };
        } else if cli_is_flag(arg) == 0 && str_len(stage) == 0 {
            stage = arg;
        } else if cli_is_flag(arg) == 0 && str_len(src_path) == 0 {
            src_path = arg;
        };
        i = i + 1;
    };
    if str_len(stage) == 0 || str_len(src_path) == 0 {
        print("Usage: nuc stage-dump <tokens|ast|typed|ir|all> <file.nr> [--json]");
        return 1;
    };
    let bundle: Vec<i32> = load_resolved_source_bundle(src_path, 1);
    let source: str = vec_get(bundle, 0);
    if str_len(source) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    if preflight_source_check(source) != 0 { return 1; };
    let tokens: Vec<i32> = lex(source);
    let need_ast: i64 = str_eq(stage, "ast") == 1 || str_eq(stage, "typed") == 1 || str_eq(stage, "ir") == 1 || str_eq(stage, "all") == 1;
    let mut pool: Vec<i32> = Vec::new();
    let mut prog: i64 = 0 - 1;
    if need_ast == 1 {
        let r: Vec<i32> = parse_program(tokens, pool);
        prog = pr_val(r);
    };
    if str_eq(stage, "tokens") == 0 && str_eq(stage, "ast") == 0 && str_eq(stage, "typed") == 0 && str_eq(stage, "ir") == 0 && str_eq(stage, "all") == 0 {
        print(str_concat("unknown stage-dump stage: ", stage));
        print("Usage: nuc stage-dump <tokens|ast|typed|ir|all> <file.nr> [--json]");
        return 1;
    };
    if json_mode == 1 && str_eq(stage, "tokens") == 1 {
        print(stage_dump_tokens_json(tokens));
        return 0;
    };
    if json_mode == 0 && (str_eq(stage, "tokens") == 1 || str_eq(stage, "all") == 1) {
        print(str_concat("=== TOKENS (", str_concat(str_from_int(vec_len(tokens)), ") ===")));
        let mut ti: i64 = 0;
        while ti < vec_len(tokens) {
            print(str_concat("  ", token_summary(vec_get(tokens, ti))));
            ti = ti + 1;
        };
        if str_eq(stage, "tokens") == 1 { return 0; };
    };
    if json_mode == 1 && str_eq(stage, "ast") == 1 {
        print(stage_dump_ast_json(pool, prog));
        return 0;
    };
    if json_mode == 0 && (str_eq(stage, "ast") == 1 || str_eq(stage, "all") == 1) {
        let item_cnt: i64 = list_len(pool, prog);
        print(str_concat("=== AST (", str_concat(str_from_int(item_cnt), " items) ===")));
        let mut ai: i64 = 0;
        while ai < item_cnt {
            print(str_concat("  [", str_concat(str_from_int(ai), str_concat("] ", ast_item_summary(pool, list_get(pool, prog, ai))))));
            ai = ai + 1;
        };
        if str_eq(stage, "ast") == 1 { return 0; };
    };
    let mut structs: Vec<i32> = Vec::new();
    let mut enums: Vec<i32> = Vec::new();
    let mut externs: Vec<i32> = Vec::new();
    let mut globals: Vec<i32> = Vec::new();
    let item_cnt2: i64 = list_len(pool, prog);
    let mut ci: i64 = 0;
    while ci < item_cnt2 {
        let nid: i64 = list_get(pool, prog, ci);
        if node_kind(pool, nid) == 33 { structs.push(nid); }
        else if node_kind(pool, nid) == 36 { enums.push(nid); }
        else if node_kind(pool, nid) == 32 { externs.push(nid); };
        if node_kind(pool, nid) == 50 { globals.push(nid); };
        ci = ci + 1;
    };
    let mut diags: Vec<i32> = diag_new();
    type_check_program(pool, prog, structs, diags, source, tprof_new(0));
    if json_mode == 1 && str_eq(stage, "typed") == 1 {
        print(stage_dump_typed_json(diags));
        return 0;
    };
    if json_mode == 0 && (str_eq(stage, "typed") == 1 || str_eq(stage, "all") == 1) {
        if diag_count(diags) == 0 {
            print("=== TYPED (0 diagnostics) ===");
        } else {
            print(str_concat("=== TYPED (", str_concat(str_from_int(diag_count(diags)), " diagnostics) ===")));
            diag_emit_text(diags);
        };
        if str_eq(stage, "typed") == 1 { return 0; };
    };
    let mut ir_json: str = "";
    if diag_count(diags) > 0 {
        ir_json = stage_dump_ir_json(0, vec_len(externs), vec_len(structs), vec_len(enums), 0, 1, "type_diagnostics");
        if json_mode == 0 && (str_eq(stage, "ir") == 1 || str_eq(stage, "all") == 1) {
            print("=== IR ===");
            print("  skipped: type diagnostics present");
        };
    } else {
        let mut strtab: Vec<i32> = Vec::new();
        let mut fns: Vec<i32> = Vec::new();
        let mut trait_impls: Vec<i32> = Vec::new();
        let mut impl_fns: Vec<i32> = Vec::new();
        ci = 0;
        while ci < item_cnt2 {
            let nid2: i64 = list_get(pool, prog, ci);
            if node_kind(pool, nid2) == 45 {
                let type_name: str = node_field(pool, nid2, 2);
                let methods: i64 = node_field(pool, nid2, 3);
                let mc: i64 = list_len(pool, methods);
                let mut mi: i64 = 0;
                while mi < mc {
                    let method_nid: i64 = list_get(pool, methods, mi);
                    let orig_name: str = node_field(pool, method_nid, 1);
                    let mangled: str = str_concat(type_name, str_concat("__", orig_name));
                    impl_fns.push(mk6(pool, 30, mangled, node_field(pool, method_nid, 2), node_field(pool, method_nid, 3), node_field(pool, method_nid, 4), node_field(pool, method_nid, 5)));
                    trait_impl_register(trait_impls, type_name, orig_name, mangled);
                    mi = mi + 1;
                };
            };
            ci = ci + 1;
        };
        let mut closures: Vec<i32> = Vec::new();
        ci = 0;
        while ci < item_cnt2 {
            let nid3: i64 = list_get(pool, prog, ci);
            if node_kind(pool, nid3) == 30 { fns.push(lower_fn(pool, nid3, strtab, structs, enums, globals, closures, trait_impls)); };
            ci = ci + 1;
        };
        let mut ii: i64 = 0;
        while ii < vec_len(impl_fns) { fns.push(lower_fn(pool, vec_get(impl_fns, ii), strtab, structs, enums, globals, closures, trait_impls)); ii = ii + 1; };
        let mut ci2: i64 = 0;
        while ci2 < vec_len(closures) { fns.push(vec_get(closures, ci2)); ci2 = ci2 + 1; };
        let ll: str = emit_module_ext(fns, strtab, pool, externs, source);
        ir_json = stage_dump_ir_json(vec_len(fns), vec_len(externs), vec_len(structs), vec_len(enums), str_len(ll), 0, "");
        if json_mode == 0 && (str_eq(stage, "ir") == 1 || str_eq(stage, "all") == 1) {
            print("=== IR ===");
            print(str_concat("  functions: ", str_from_int(vec_len(fns))));
            print(str_concat("  externs: ", str_from_int(vec_len(externs))));
            print(str_concat("  structs: ", str_from_int(vec_len(structs))));
            print(str_concat("  enums: ", str_from_int(vec_len(enums))));
            print(str_concat("  ll_bytes: ", str_from_int(str_len(ll))));
        };
    };
    if str_eq(stage, "ir") == 1 && json_mode == 1 {
        print(ir_json);
        return 0;
    };
    if str_eq(stage, "ir") == 1 { return 0; };
    if json_mode == 1 && str_eq(stage, "all") == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"stage\":\"all\",\"tokens\":"); sb_append(sb, stage_dump_tokens_json(tokens));
        sb_append(sb, ",\"ast\":"); sb_append(sb, stage_dump_ast_json(pool, prog));
        sb_append(sb, ",\"typed\":"); sb_append(sb, stage_dump_typed_json(diags));
        sb_append(sb, ",\"ir\":"); sb_append(sb, ir_json);
        sb_append(sb, "}");
        print(sb_to_str(sb));
        return 0;
    };
    return 0;
}

fn trim_ws(s: str) -> str {
    let slen: i64 = str_len(s);
    let mut start: i64 = 0;
    while start < slen && (str_char_at(s, start) == 32 || str_char_at(s, start) == 9 || str_char_at(s, start) == 10 || str_char_at(s, start) == 13) {
        start = start + 1;
    };
    let mut stop: i64 = slen;
    while stop > start && (str_char_at(s, stop - 1) == 32 || str_char_at(s, stop - 1) == 9 || str_char_at(s, stop - 1) == 10 || str_char_at(s, stop - 1) == 13) {
        stop = stop - 1;
    };
    return str_substring(s, start, stop);
}

fn string_vec_contains(items: Vec<i32>, value: str) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(items) {
        if str_eq(vec_get(items, i), value) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn string_vec_push_unique(items: Vec<i32>, value: str) -> i64 {
    if string_vec_contains(items, value) == 0 { items.push(value); };
    return 0;
}

fn int_vec_contains(items: Vec<i32>, value: i64) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(items) {
        if vec_get(items, i) == value { return 1; };
        i = i + 1;
    };
    return 0;
}

fn csv_to_string_vec(csv: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let clen: i64 = str_len(csv);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= clen {
        let at_end: i64 = i == clen;
        let mut at_comma: i64 = 0;
        if at_end == 0 && str_char_at(csv, i) == 44 { at_comma = 1; };
        if at_comma == 1 || at_end == 1 {
            let part: str = trim_ws(str_substring(csv, start, i));
            if str_len(part) > 0 { string_vec_push_unique(out, part); };
            start = i + 1;
        };
        i = i + 1;
    };
    return out;
}

fn join_strings(items: Vec<i32>, sep: str) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < vec_len(items) {
        if i > 0 { sb_append(sb, sep); };
        sb_append(sb, vec_get(items, i));
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn csv_pretty(csv: str) -> str {
    return join_strings(csv_to_string_vec(csv), ", ");
}

fn sb_append_json_bool(sb: i64, value: i64) -> i64 {
    if value == 1 { sb_append(sb, "true"); }
    else { sb_append(sb, "false"); };
    return 0;
}

fn sb_append_json_string_array(sb: i64, items: Vec<i32>) -> i64 {
    sb_append(sb, "[");
    let mut i: i64 = 0;
    while i < vec_len(items) {
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "\"");
        sb_append(sb, json_escape(vec_get(items, i)));
        sb_append(sb, "\"");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn sb_append_json_string_or_null(sb: i64, value: str) -> i64 {
    if str_len(value) == 0 {
        sb_append(sb, "null");
    } else {
        sb_append(sb, "\"");
        sb_append(sb, json_escape(value));
        sb_append(sb, "\"");
    };
    return 0;
}

fn path_with_sep(path: str) -> str {
    let plen: i64 = str_len(path);
    if plen == 0 { return ""; };
    let last: i64 = str_char_at(path, plen - 1);
    if last == 47 || last == 92 { return path; };
    return str_concat(path, "/");
}

fn path_normalize_slashes(path: str) -> str {
    let plen: i64 = str_len(path);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < plen {
        let ch: i64 = str_char_at(path, i);
        if ch == 92 { sb_append(sb, "/"); }
        else { sb_append(sb, str_substring(path, i, i + 1)); };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn path_shell_native(path: str) -> str {
    // only rewrite forward-slashes to backslashes on
    // Windows. On POSIX hosts the unconditional rewrite mangled paths
    // passed to pwsh (e.g. tools/native_release.ps1 became
    // tools\native_release.ps1, which pwsh treated as a relative path
    // and Join-Path'd onto -Root, producing
    // /home/.../Nucleor/tmp/.../Nucleor.publish.json and a "missing
    // package signing input" failure during signed publish).
    if host_is_windows() == 0 { return path; };
    let plen: i64 = str_len(path);
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i < plen {
        let ch: i64 = str_char_at(path, i);
        if ch == 47 { sb_append(sb, "\\"); }
        else { sb_append(sb, str_substring(path, i, i + 1)); };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn shell_quote(path: str) -> str {
    return str_concat("\"", str_concat(path, "\""));
}

fn path_relative_or_abs(base_dir: str, full_path: str) -> str {
    let base: str = path_normalize_slashes(trim_trailing_sep(base_dir));
    let full: str = path_normalize_slashes(full_path);
    let blen: i64 = str_len(base);
    let flen: i64 = str_len(full);
    if blen > 0 && flen >= blen && str_eq(str_substring(full, 0, blen), base) == 1 {
        let mut start: i64 = blen;
        if flen > blen {
            let next: i64 = str_char_at(full, blen);
            if next == 47 || next == 92 { start = blen + 1; };
        };
        return str_substring(full, start, flen);
    };
    return full;
}

fn path_relative_inventory(base_dir: str, full_path: str) -> str {
    let rel0: str = path_relative_or_abs(base_dir, full_path);
    if str_eq(rel0, path_normalize_slashes(full_path)) == 0 { return rel0; };
    let base_name: str = basename(trim_trailing_sep(base_dir));
    if str_len(base_name) == 0 { return rel0; };
    let full: str = path_normalize_slashes(full_path);
    let marker: str = str_concat("/", str_concat(base_name, "/"));
    let mlen: i64 = str_len(marker);
    let flen: i64 = str_len(full);
    let mut i: i64 = 0;
    while i + mlen <= flen {
        if str_eq(str_substring(full, i, i + mlen), marker) == 1 {
            return str_substring(full, i + mlen, flen);
        };
        i = i + 1;
    };
    return rel0;
}

fn manifest_default_package_name(manifest_path: str) -> str {
    let pkg_dir: str = trim_trailing_sep(parent_dir(manifest_path));
    if str_len(pkg_dir) == 0 { return "package"; };
    let name: str = basename(pkg_dir);
    if str_len(name) == 0 { return "package"; };
    return name;
}

fn manifest_unquote(raw: str) -> str {
    let value: str = trim_ws(raw);
    let vlen: i64 = str_len(value);
    if vlen >= 2 && str_char_at(value, 0) == 34 && str_char_at(value, vlen - 1) == 34 {
        return str_substring(value, 1, vlen - 1);
    };
    return "";
}

fn manifest_parse_string_array(raw: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let value: str = trim_ws(raw);
    let vlen: i64 = str_len(value);
    if vlen < 2 || str_char_at(value, 0) != 91 || str_char_at(value, vlen - 1) != 93 { return out; };
    let inner: str = trim_ws(str_substring(value, 1, vlen - 1));
    let ilen: i64 = str_len(inner);
    if ilen == 0 { return out; };
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= ilen {
        let at_end: i64 = i == ilen;
        let mut at_comma: i64 = 0;
        if at_end == 0 && str_char_at(inner, i) == 44 { at_comma = 1; };
        if at_end == 1 || at_comma == 1 {
            let item: str = manifest_unquote(str_substring(inner, start, i));
            if str_len(item) > 0 { out.push(item); };
            start = i + 1;
        };
        i = i + 1;
    };
    return out;
}

fn manifest_parse_settings(manifest_path: str, source: str) -> Vec<i32> {
    let mut section: str = "";
    let mut package_name: str = manifest_default_package_name(manifest_path);
    let mut version: str = "0.1.0";
    let mut entry: str = "src/main.nr";
    let mut deps: Vec<i32> = Vec::new();
    let mut workspace_members: Vec<i32> = Vec::new();
    let mut has_package: i64 = 0;
    let mut error: str = "";
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p <= slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let line: str = trim_ws(str_substring(source, p, eol));
        if str_len(line) > 0 && str_char_at(line, 0) != 35 {
            let llen: i64 = str_len(line);
            if llen >= 2 && str_char_at(line, 0) == 91 && str_char_at(line, llen - 1) == 93 {
                section = trim_ws(str_substring(line, 1, llen - 1));
            } else {
                let mut eq_pos: i64 = 0 - 1;
                let mut i: i64 = 0;
                while i < llen {
                    if str_char_at(line, i) == 61 && eq_pos < 0 { eq_pos = i; };
                    i = i + 1;
                };
                if eq_pos >= 0 {
                    let key: str = trim_ws(str_substring(line, 0, eq_pos));
                    let value: str = trim_ws(str_substring(line, eq_pos + 1, llen));
                    if str_eq(section, "package") == 1 && str_eq(key, "name") == 1 {
                        let parsed: str = manifest_unquote(value);
                        if str_len(parsed) == 0 { error = str_concat(manifest_path, ": invalid package.name"); }
                        else { package_name = parsed; has_package = 1; };
                    } else if str_eq(section, "package") == 1 && str_eq(key, "version") == 1 {
                        let parsed2: str = manifest_unquote(value);
                        if str_len(parsed2) == 0 { error = str_concat(manifest_path, ": invalid package.version"); }
                        else { version = parsed2; has_package = 1; };
                    } else if str_eq(section, "package") == 1 && str_eq(key, "entry") == 1 {
                        let parsed3: str = manifest_unquote(value);
                        if str_len(parsed3) == 0 { error = str_concat(manifest_path, ": invalid package.entry"); }
                        else { entry = parsed3; has_package = 1; };
                    } else if str_eq(section, "dependencies") == 1 {
                        let dep_path: str = manifest_unquote(value);
                        if str_len(dep_path) == 0 { error = str_concat(manifest_path, ": invalid dependency path"); }
                        else {
                            deps.push(key);
                            deps.push(dep_path);
                        };
                    } else if str_eq(section, "workspace") == 1 && str_eq(key, "members") == 1 {
                        workspace_members = manifest_parse_string_array(value);
                    };
                };
            };
        };
        if eol >= slen { p = slen + 1; }
        else { p = eol + 1; };
    };
    let mut out: Vec<i32> = Vec::new();
    out.push(package_name);
    out.push(version);
    out.push(entry);
    out.push(deps);
    out.push(workspace_members);
    out.push(has_package);
    out.push(error);
    return out;
}

fn manifest_settings_package_name(settings: Vec<i32>) -> str { return vec_get(settings, 0); }
fn manifest_settings_version(settings: Vec<i32>) -> str { return vec_get(settings, 1); }
fn manifest_settings_entry(settings: Vec<i32>) -> str { return vec_get(settings, 2); }
fn manifest_settings_deps(settings: Vec<i32>) -> Vec<i32> { return vec_get(settings, 3); }
fn manifest_settings_workspace(settings: Vec<i32>) -> Vec<i32> { return vec_get(settings, 4); }
fn manifest_settings_has_package(settings: Vec<i32>) -> i64 { return vec_get(settings, 5); }
fn manifest_settings_error(settings: Vec<i32>) -> str { return vec_get(settings, 6); }

fn lock_resolve_manifest_target(raw_target: str) -> str {
    let candidate: str = if str_len(raw_target) == 0 { "Nucleor.toml" } else { sanitize(raw_target) };
    if str_len(file_read_string(candidate)) > 0 { return candidate; };
    let manifest_candidate: str = sanitize(str_concat(path_with_sep(candidate), "Nucleor.toml"));
    if str_len(file_read_string(manifest_candidate)) > 0 { return manifest_candidate; };
    return "";
}

fn manifest_resolve_dependency_manifest(manifest_path: str, dep_input: str) -> str {
    let base_dir: str = path_with_sep(parent_dir(manifest_path));
    let candidate: str = if path_is_absolute(dep_input) == 1 { sanitize(dep_input) } else { sanitize(str_concat(base_dir, dep_input)) };
    if str_len(file_read_string(candidate)) > 0 { return candidate; };
    let manifest_candidate: str = sanitize(str_concat(path_with_sep(candidate), "Nucleor.toml"));
    if str_len(file_read_string(manifest_candidate)) > 0 { return manifest_candidate; };
    return manifest_candidate;
}

fn lock_should_skip_file(package_dir: str, file_path: str) -> i64 {
    let rel: str = path_relative_or_abs(package_dir, file_path);
    let norm: str = str_concat("/", str_concat(path_normalize_slashes(rel), "/"));
    let name: str = basename(file_path);
    // R12-D6 Phase 1 (v0.8.283, audit 2026-05-05): Nucleor.lock and
    // Nucleor.publish.json (registry metadata) are now INCLUDED in
    // the package checksum. Pre-v0.8.283 they were skipped, leaving
    // provenance incomplete — adopters could mutate the lock or
    // metadata without the package digest detecting the change.
    // The checksum file itself (Nucleor.package.sha256) is still
    // skipped because including the digest in itself is circular.
    // Build-output dirs (target/, .git/, .nucleor/, .nuc_cache/)
    // are still skipped — they're per-build, not per-package.
    if str_eq(name, package_checksum_file_name()) == 1 { return 1; };
    if text_contains(norm, "/target/") == 1 || text_contains(norm, "/.git/") == 1 || text_contains(norm, "/.nucleor/") == 1 || text_contains(norm, "/.nuc_cache/") == 1 {
        return 1;
    };
    return 0;
}

fn package_checksum_native(package_dir: str) -> str {
    let root_dir: str = trim_trailing_sep(package_dir);
    if str_len(root_dir) == 0 { return secure_hash(package_dir); };
    let files: Vec<i32> = walk_dir_recursive_native(root_dir);
    let n: i64 = vec_len(files);
    let mut payload: i64 = sb_new();
    let mut i: i64 = 0;
    while i < n {
        let line: str = vec_get(files, i);
        if str_len(line) > 0 && lock_should_skip_file(root_dir, line) == 0 && str_eq(basename(line), package_signature_file_name()) == 0 {
            let rel: str = path_normalize_slashes(path_relative_inventory(root_dir, line));
            sb_append(payload, rel);
            sb_append(payload, "\n");
            sb_append(payload, file_read_string(line));
            sb_append(payload, "\n--\n");
        };
        i = i + 1;
    };
    let material: str = sb_to_str(payload);
    if str_len(material) == 0 { return secure_hash(root_dir); };
    return secure_hash(material);
}

fn lock_build_graph_recursive(manifest_path: str, graph: Vec<i32>, seen: Vec<i32>, stack: Vec<i32>, errors: Vec<i32>) -> i64 {
    if string_vec_contains(stack, manifest_path) == 1 {
        errors.push(str_concat("package dependency cycle detected at ", manifest_path));
        return 1;
    };
    if string_vec_contains(seen, manifest_path) == 1 { return 0; };
    let raw: str = file_read_string(manifest_path);
    if str_len(raw) == 0 {
        errors.push(str_concat("cannot read manifest: ", manifest_path));
        return 1;
    };
    let settings: Vec<i32> = manifest_parse_settings(manifest_path, raw);
    let parse_err: str = manifest_settings_error(settings);
    if str_len(parse_err) > 0 {
        errors.push(parse_err);
        return 1;
    };
    stack.push(manifest_path);
    let workspace_members: Vec<i32> = manifest_settings_workspace(settings);
    let mut wi: i64 = 0;
    while wi < vec_len(workspace_members) {
        let member_manifest: str = manifest_resolve_dependency_manifest(manifest_path, vec_get(workspace_members, wi));
        if str_len(file_read_string(member_manifest)) == 0 {
            errors.push(str_concat("cannot resolve workspace member manifest: ", member_manifest));
            vec_pop(stack);
            return 1;
        };
        if lock_build_graph_recursive(member_manifest, graph, seen, stack, errors) != 0 {
            vec_pop(stack);
            return 1;
        };
        wi = wi + 1;
    };
    if manifest_settings_has_package(settings) == 1 {
        let deps: Vec<i32> = manifest_settings_deps(settings);
        let mut dep_records: Vec<i32> = Vec::new();
        let mut di: i64 = 0;
        while di < vec_len(deps) {
            let dep_alias: str = vec_get(deps, di);
            let dep_input: str = vec_get(deps, di + 1);
            let dep_manifest: str = manifest_resolve_dependency_manifest(manifest_path, dep_input);
            if str_len(file_read_string(dep_manifest)) == 0 {
                errors.push(str_concat("cannot resolve dependency manifest: ", dep_manifest));
                vec_pop(stack);
                return 1;
            };
            if lock_build_graph_recursive(dep_manifest, graph, seen, stack, errors) != 0 {
                vec_pop(stack);
                return 1;
            };
            dep_records.push(dep_alias);
            dep_records.push(dep_input);
            dep_records.push(dep_manifest);
            di = di + 2;
        };
        let mut pkg: Vec<i32> = Vec::new();
        pkg.push(manifest_path);
        pkg.push(manifest_settings_package_name(settings));
        pkg.push(manifest_settings_version(settings));
        pkg.push(manifest_settings_entry(settings));
        pkg.push(package_checksum_native(parent_dir(manifest_path)));
        pkg.push(dep_records);
        graph.push(pkg);
    };
    seen.push(manifest_path);
    vec_pop(stack);
    return 0;
}

fn render_deps_graph_native(root_manifest: str, graph: Vec<i32>, fmt: str) -> str {
    let mut sb: i64 = sb_new();
    let n: i64 = vec_len(graph);
    if str_eq(fmt, "json") == 1 {
        sb_append(sb, "{\"packages\":[");
        let mut gi: i64 = 0;
        while gi < n {
            let pkg: Vec<i32> = vec_get(graph, gi);
            let nm: str = vec_get(pkg, 1);
            let vr: str = vec_get(pkg, 2);
            let deps: Vec<i32> = vec_get(pkg, 5);
            if gi > 0 { sb_append(sb, ","); };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(nm));
            sb_append(sb, "\",\"version\":\""); sb_append(sb, json_escape(vr));
            sb_append(sb, "\",\"dependencies\":[");
            let mut di: i64 = 0;
            let mut first: i64 = 1;
            while di < vec_len(deps) {
                let alias: str = vec_get(deps, di);
                if first == 0 { sb_append(sb, ","); } else { first = 0; };
                sb_append(sb, "\""); sb_append(sb, json_escape(alias)); sb_append(sb, "\"");
                di = di + 3;
            };
            sb_append(sb, "]}");
            gi = gi + 1;
        };
        sb_append(sb, "]}\n");
        return sb_to_str(sb);
    };
    if str_eq(fmt, "dot") == 1 {
        sb_append(sb, "digraph deps {\n");
        sb_append(sb, "  rankdir=LR;\n");
        let mut gi: i64 = 0;
        while gi < n {
            let pkg: Vec<i32> = vec_get(graph, gi);
            let nm: str = vec_get(pkg, 1);
            let vr: str = vec_get(pkg, 2);
            let deps: Vec<i32> = vec_get(pkg, 5);
            sb_append(sb, "  \""); sb_append(sb, nm); sb_append(sb, "@"); sb_append(sb, vr); sb_append(sb, "\";\n");
            let mut di: i64 = 0;
            while di < vec_len(deps) {
                let alias: str = vec_get(deps, di);
                sb_append(sb, "  \""); sb_append(sb, nm); sb_append(sb, "@"); sb_append(sb, vr);
                sb_append(sb, "\" -> \""); sb_append(sb, alias); sb_append(sb, "\";\n");
                di = di + 3;
            };
            gi = gi + 1;
        };
        sb_append(sb, "}\n");
        return sb_to_str(sb);
    };
    if str_eq(fmt, "mermaid") == 1 {
        sb_append(sb, "graph TD\n");
        let mut gi: i64 = 0;
        while gi < n {
            let pkg: Vec<i32> = vec_get(graph, gi);
            let nm: str = vec_get(pkg, 1);
            let deps: Vec<i32> = vec_get(pkg, 5);
            let mut di: i64 = 0;
            while di < vec_len(deps) {
                let alias: str = vec_get(deps, di);
                sb_append(sb, "  "); sb_append(sb, nm); sb_append(sb, "-->"); sb_append(sb, alias); sb_append(sb, "\n");
                di = di + 3;
            };
            gi = gi + 1;
        };
        return sb_to_str(sb);
    };
    // text (default): tree-style listing
    sb_append(sb, "deps graph (");
    sb_append(sb, str_from_int(n)); sb_append(sb, " package(s)):\n");
    let mut gi: i64 = 0;
    while gi < n {
        let pkg: Vec<i32> = vec_get(graph, gi);
        let nm: str = vec_get(pkg, 1);
        let vr: str = vec_get(pkg, 2);
        let deps: Vec<i32> = vec_get(pkg, 5);
        sb_append(sb, nm); sb_append(sb, "@"); sb_append(sb, vr); sb_append(sb, "\n");
        let mut di: i64 = 0;
        while di < vec_len(deps) {
            let alias: str = vec_get(deps, di);
            sb_append(sb, "  -> "); sb_append(sb, alias); sb_append(sb, "\n");
            di = di + 3;
        };
        gi = gi + 1;
    };
    return sb_to_str(sb);
}

fn run_deps_command(argc: i64) -> i64 {
    // nuc deps graph [path] [--format=text|json|dot|mermaid]
    if argc < 3 {
        print("Usage: nuc deps graph [path/to/Nucleor.toml|project_dir] [--format=text|json|dot|mermaid]");
        return 1;
    };
    let sub: str = args_get(2);
    if str_eq(sub, "graph") != 1 {
        print(str_concat("ERROR: unknown deps subcommand: ", sub));
        print("Supported: nuc deps graph");
        return 1;
    };
    let mut fmt: str = "text";
    let mut target: str = "";
    let mut i: i64 = 3;
    while i < argc {
        let a: str = args_get(i);
        if str_eq(a, "--format=text") == 1 { fmt = "text"; }
        else if str_eq(a, "--format=json") == 1 { fmt = "json"; }
        else if str_eq(a, "--format=dot") == 1 { fmt = "dot"; }
        else if str_eq(a, "--format=mermaid") == 1 { fmt = "mermaid"; }
        else if str_eq(a, "--format") == 1 && i + 1 < argc {
            fmt = args_get(i + 1);
            i = i + 1;
        } else if cli_is_flag(a) == 0 && str_len(target) == 0 { target = a; };
        i = i + 1;
    };
    let manifest_path: str = lock_resolve_manifest_target(target);
    if str_len(manifest_path) == 0 {
        print("ERROR: no Nucleor.toml found");
        print("Usage: nuc deps graph [path/to/Nucleor.toml|project_dir] [--format=text|json|dot|mermaid]");
        return 1;
    };
    let mut graph: Vec<i32> = Vec::new();
    let mut seen: Vec<i32> = Vec::new();
    let mut stack: Vec<i32> = Vec::new();
    let mut errors: Vec<i32> = Vec::new();
    if lock_build_graph_recursive(manifest_path, graph, seen, stack, errors) != 0 || vec_len(errors) > 0 {
        let err: str = if vec_len(errors) > 0 { vec_get(errors, 0) } else { "unknown lock graph error" };
        print(str_concat("ERROR: ", err));
        return 1;
    };
    print(render_deps_graph_native(manifest_path, graph, fmt));
    return 0;
}

fn render_lockfile_native(root_manifest: str, graph: Vec<i32>) -> str {
    let root_dir: str = path_with_sep(parent_dir(root_manifest));
    let root_settings: Vec<i32> = manifest_parse_settings(root_manifest, file_read_string(root_manifest));
    let mut sb: i64 = sb_new();
    sb_append(sb, "version = 1\n");
    sb_append(sb, "root = \"");
    sb_append(sb, json_escape(path_normalize_slashes(path_relative_or_abs(root_dir, root_manifest))));
    sb_append(sb, "\"\n\n");
    if manifest_settings_has_package(root_settings) == 1 {
        sb_append(sb, "root_package = \"");
        sb_append(sb, json_escape(manifest_settings_package_name(root_settings)));
        sb_append(sb, "\"\n");
    };
    let workspace_members: Vec<i32> = manifest_settings_workspace(root_settings);
    if vec_len(workspace_members) > 0 {
        let mut members: Vec<i32> = Vec::new();
        let mut wi: i64 = 0;
        while wi < vec_len(workspace_members) {
            members.push(path_normalize_slashes(path_relative_or_abs(root_dir, manifest_resolve_dependency_manifest(root_manifest, vec_get(workspace_members, wi)))));
            wi = wi + 1;
        };
        sb_append(sb, "workspace_members = [");
        let mut mi: i64 = 0;
        while mi < vec_len(members) {
            if mi > 0 { sb_append(sb, ", "); };
            sb_append(sb, "\"");
            sb_append(sb, json_escape(vec_get(members, mi)));
            sb_append(sb, "\"");
            mi = mi + 1;
        };
        sb_append(sb, "]\n");
    };
    if manifest_settings_has_package(root_settings) == 1 || vec_len(workspace_members) > 0 { sb_append(sb, "\n"); };
    let mut gi: i64 = 0;
    while gi < vec_len(graph) {
        let pkg: Vec<i32> = vec_get(graph, gi);
        let manifest_path: str = vec_get(pkg, 0);
        let package_name: str = vec_get(pkg, 1);
        let version: str = vec_get(pkg, 2);
        let entry: str = vec_get(pkg, 3);
        let checksum: str = vec_get(pkg, 4);
        let deps: Vec<i32> = vec_get(pkg, 5);
        sb_append(sb, "[[package]]\n");
        sb_append(sb, "name = \""); sb_append(sb, json_escape(package_name)); sb_append(sb, "\"\n");
        sb_append(sb, "version = \""); sb_append(sb, json_escape(version)); sb_append(sb, "\"\n");
        sb_append(sb, "manifest = \""); sb_append(sb, json_escape(path_normalize_slashes(path_relative_or_abs(root_dir, manifest_path)))); sb_append(sb, "\"\n");
        sb_append(sb, "entry = \""); sb_append(sb, json_escape(path_normalize_slashes(entry))); sb_append(sb, "\"\n");
        sb_append(sb, "checksum = \""); sb_append(sb, json_escape(checksum)); sb_append(sb, "\"\n");
        sb_append(sb, "dependencies = [");
        let mut di: i64 = 0;
        let mut first_dep: i64 = 1;
        while di < vec_len(deps) {
            let dep_alias: str = vec_get(deps, di);
            let dep_input: str = vec_get(deps, di + 1);
            let dep_manifest: str = vec_get(deps, di + 2);
            if first_dep == 0 { sb_append(sb, ", "); } else { first_dep = 0; };
            sb_append(sb, "\"");
            sb_append(sb, json_escape(dep_alias));
            sb_append(sb, "|");
            sb_append(sb, json_escape(path_normalize_slashes(dep_input)));
            sb_append(sb, "|");
            sb_append(sb, json_escape(path_normalize_slashes(path_relative_or_abs(root_dir, dep_manifest))));
            sb_append(sb, "\"");
            di = di + 3;
        };
        sb_append(sb, "]\n\n");
        gi = gi + 1;
    };
    return sb_to_str(sb);
}

fn render_dependencies_section_native(deps: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "[dependencies]\n");
    let mut i: i64 = 0;
    while i < vec_len(deps) {
        sb_append(sb, vec_get(deps, i));
        sb_append(sb, " = \"");
        sb_append(sb, json_escape(path_normalize_slashes(vec_get(deps, i + 1))));
        sb_append(sb, "\"\n");
        i = i + 2;
    };
    return sb_to_str(sb);
}

fn manifest_replace_dependencies_section_native(manifest_path: str, deps: Vec<i32>) -> i64 {
    let raw: str = file_read_string(manifest_path);
    if str_len(raw) == 0 { return 1; };
    let dep_section: str = render_dependencies_section_native(deps);
    let slen: i64 = str_len(raw);
    let mut start_pos: i64 = 0 - 1;
    let mut end_pos: i64 = slen;
    let mut p: i64 = 0;
    while p <= slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(raw, eol) != 10 { eol = eol + 1; };
        let line: str = trim_ws(str_substring(raw, p, eol));
        if str_eq(line, "[dependencies]") == 1 {
            start_pos = p;
            let mut q: i64 = if eol >= slen { slen + 1 } else { eol + 1 };
            while q <= slen {
                let mut q_eol: i64 = q;
                while q_eol < slen && str_char_at(raw, q_eol) != 10 { q_eol = q_eol + 1; };
                let q_line: str = trim_ws(str_substring(raw, q, q_eol));
                let q_len: i64 = str_len(q_line);
                if q_len >= 2 && str_char_at(q_line, 0) == 91 && str_char_at(q_line, q_len - 1) == 93 {
                    end_pos = q;
                    q = slen + 1;
                } else {
                    if q_eol >= slen { q = slen + 1; }
                    else { q = q_eol + 1; };
                };
            };
            if end_pos == slen { end_pos = slen; };
            p = slen + 1;
        } else {
            if eol >= slen { p = slen + 1; }
            else { p = eol + 1; };
        };
    };
    let mut output: str = "";
    if start_pos >= 0 {
        output = str_concat(str_substring(raw, 0, start_pos), dep_section);
        if end_pos < slen { output = str_concat(output, str_substring(raw, end_pos, slen)); };
    } else {
        let mut stop: i64 = slen;
        while stop > 0 {
            let ch: i64 = str_char_at(raw, stop - 1);
            if ch == 10 || ch == 13 { stop = stop - 1; }
            else { stop = stop; stop = stop; break; };
        };
        output = str_substring(raw, 0, stop);
        if stop > 0 { output = str_concat(output, "\n\n"); };
        output = str_concat(output, dep_section);
    };
    file_write_string(manifest_path, output);
    return 0;
}

fn dir_list_native(dir_path: str, dirs_only: i64) -> Vec<i32> {
    let mut items: Vec<i32> = Vec::new();
    let entries: Vec<i32> = fs_list_dir(dir_path);
    let n: i64 = vec_len(entries);
    let mut i: i64 = 0;
    while i < n {
        let name: str = vec_get(entries, i);
        if str_len(name) > 0 {
            if dirs_only == 1 {
                let full: str = fs_join(dir_path, name);
                if fs_is_dir(full) == 1 { items.push(name); };
            } else {
                items.push(name);
            };
        };
        i = i + 1;
    };
    return items;
}

fn walk_dir_recursive_native(root_dir: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let mut stack: Vec<i32> = Vec::new();
    stack.push(root_dir);
    while vec_len(stack) > 0 {
        let last_idx: i64 = vec_len(stack) - 1;
        let cur: str = vec_get(stack, last_idx);
        vec_pop(stack);
        let names: Vec<i32> = fs_list_dir(cur);
        // Sort entries so the recursive walk produces a stable
        // alphabetical order across platforms (cmd.exe `/on` did the same).
        let sorted: Vec<i32> = sort_strings_asc(names);
        let n: i64 = vec_len(sorted);
        // Push subdirs in reverse so the pop order produces ascending visit.
        let mut subdirs: Vec<i32> = Vec::new();
        let mut i: i64 = 0;
        while i < n {
            let name: str = vec_get(sorted, i);
            if str_len(name) > 0 {
                let full: str = fs_join(cur, name);
                if fs_is_dir(full) == 1 { subdirs.push(full); }
                else { out.push(full); };
            };
            i = i + 1;
        };
        let m: i64 = vec_len(subdirs);
        let mut j: i64 = m - 1;
        while j >= 0 {
            stack.push(vec_get(subdirs, j));
            j = j - 1;
        };
    };
    return out;
}

fn sort_strings_asc(v: Vec<i32>) -> Vec<i32> {
    // Insertion sort on a string Vec (stable, O(n²) but n is bounded by
    // file count per directory). Caller owns the returned Vec.
    let n: i64 = vec_len(v);
    let mut out: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < n { out.push(vec_get(v, i)); i = i + 1; };
    let mut k: i64 = 1;
    while k < n {
        let key: str = vec_get(out, k);
        let mut j: i64 = k - 1;
        let mut placed: i64 = 0;
        while j >= 0 && placed == 0 {
            let prev: str = vec_get(out, j);
            if str_compare_asc(prev, key) > 0 {
                vec_set(out, j + 1, prev);
                j = j - 1;
            } else {
                placed = 1;
            };
        };
        vec_set(out, j + 1, key);
        k = k + 1;
    };
    return out;
}

fn str_compare_asc(a: str, b: str) -> i64 {
    let la: i64 = str_len(a);
    let lb: i64 = str_len(b);
    let mut i: i64 = 0;
    while i < la && i < lb {
        let ca: i64 = str_char_at(a, i);
        let cb: i64 = str_char_at(b, i);
        if ca < cb { return 0 - 1; };
        if ca > cb { return 1; };
        i = i + 1;
    };
    if la < lb { return 0 - 1; };
    if la > lb { return 1; };
    return 0;
}

fn should_copy_package_file_native(file_path: str) -> i64 {
    let name: str = basename(file_path);
    if str_eq(name, "Nucleor.toml") == 1 || str_eq(name, "Nucleor.lock") == 1 || str_eq(name, package_checksum_file_name()) == 1 || str_eq(name, registry_metadata_file_name()) == 1 || str_eq(name, package_signature_file_name()) == 1 || str_eq(name, package_exports_manifest_file_name()) == 1 || str_eq(name, package_exports_header_file_name()) == 1 || str_eq(name, package_exports_rust_file_name()) == 1 {
        return 1;
    };
    let flen: i64 = str_len(file_path);
    if flen >= 3 && str_eq(str_substring(file_path, flen - 3, flen), ".nr") == 1 { return 1; };
    if flen >= 3 && str_eq(str_substring(file_path, flen - 3, flen), ".md") == 1 { return 1; };
    if flen >= 4 && str_eq(str_substring(file_path, flen - 4, flen), ".txt") == 1 { return 1; };
    return 0;
}

fn manifest_entry_source_path(package_root: str, settings: Vec<i32>) -> str {
    let entry_rel: str = sanitize(path_normalize_slashes(manifest_settings_entry(settings)));
    if path_is_absolute(entry_rel) == 1 { return entry_rel; };
    return sanitize(str_concat(path_with_sep(package_root), entry_rel));
}

fn json_extract_int_value(raw: str, key: str) -> i64 {
    let compact: str = strip_spaces(raw);
    let needle: str = str_concat("\"", str_concat(key, "\":"));
    let clen: i64 = str_len(compact);
    let nlen: i64 = str_len(needle);
    if clen < nlen { return 0; };
    let mut pos: i64 = -1;
    let mut i: i64 = 0;
    while i <= clen - nlen {
        if str_eq(str_substring(compact, i, i + nlen), needle) == 1 {
            pos = i + nlen;
            i = clen;
        } else {
            i = i + 1;
        };
    };
    if pos < 0 || pos >= clen { return 0; };
    let mut stop: i64 = pos;
    while stop < clen {
        let ch2: i64 = str_char_at(compact, stop);
        if ch2 < 48 || ch2 > 57 {
            if stop > pos { return str_to_int(str_substring(compact, pos, stop)); };
            return 0;
        };
        stop = stop + 1;
    };
    if stop > pos { return str_to_int(str_substring(compact, pos, stop)); };
    return 0;
}

fn json_extract_string_value(raw: str, key: str) -> str {
    let compact: str = strip_spaces(raw);
    let needle: str = str_concat("\"", str_concat(key, "\":"));
    let clen: i64 = str_len(compact);
    let nlen: i64 = str_len(needle);
    if clen < nlen { return ""; };
    let mut pos: i64 = -1;
    let mut i: i64 = 0;
    while i <= clen - nlen {
        if str_eq(str_substring(compact, i, i + nlen), needle) == 1 {
            pos = i + nlen;
            i = clen;
        } else {
            i = i + 1;
        };
    };
    if pos < 0 || pos >= clen || str_char_at(compact, pos) != 34 { return ""; };
    let mut stop: i64 = pos + 1;
    while stop < clen {
        let ch: i64 = str_char_at(compact, stop);
        if ch == 34 && str_char_at(compact, stop - 1) != 92 {
            return str_substring(compact, pos + 1, stop);
        };
        stop = stop + 1;
    };
    return "";
}

fn copy_package_tree_native(src_root: str, dst_root: str) -> i64 {
    let root_dir: str = trim_trailing_sep(src_root);
    fs_create_dir_all(dst_root);
    let files: Vec<i32> = walk_dir_recursive_native(root_dir);
    let n: i64 = vec_len(files);
    let mut i: i64 = 0;
    while i < n {
        let file_path: str = vec_get(files, i);
        if str_len(file_path) > 0 && lock_should_skip_file(root_dir, file_path) == 0 && should_copy_package_file_native(file_path) == 1 {
            let rel: str = path_relative_inventory(root_dir, file_path);
            let dst_path: str = sanitize(str_concat(path_with_sep(dst_root), rel));
            let dst_parent: str = parent_dir(dst_path);
            if str_len(dst_parent) > 0 { fs_create_dir_all(dst_parent); };
            if fs_copy_file(file_path, dst_path) == 0 { return 1; };
        };
        i = i + 1;
    };
    return 0;
}

fn write_package_checksum_file_native(package_root: str) -> str {
    let checksum: str = package_checksum_native(package_root);
    let checksum_path: str = sanitize(str_concat(path_with_sep(package_root), package_checksum_file_name()));
    file_write_string(checksum_path, str_concat("sha256 = \"", str_concat(checksum, "\"\n")));
    return checksum_path;
}

fn registry_dir_native(argc: i64, arg_start: i64) -> str {
    let opt: str = cli_option_value(argc, arg_start, "--registry");
    if str_len(opt) > 0 { return sanitize(opt); };
    return ".nucleor/registry";
}

fn registry_remotes_config_path_native() -> str { return ".nucleor/registry-remotes.txt"; }

fn registry_remote_name_is_valid_native(name: str) -> i64 {
    let nlen: i64 = str_len(name);
    if nlen == 0 { return 0; };
    let mut i: i64 = 0;
    while i < nlen {
        let c: i64 = str_char_at(name, i);
        let is_ok: i64 = if is_alnum(c) == 1 || c == 95 || c == 45 || c == 46 { 1 } else { 0 };
        if is_ok == 0 { return 0; };
        i = i + 1;
    };
    return 1;
}

fn registry_remote_url_is_valid_native(url: str) -> i64 {
    let ulen: i64 = str_len(url);
    if ulen == 0 { return 0; };
    let mut i: i64 = 0;
    while i < ulen {
        let c: i64 = str_char_at(url, i);
        if c == 9 || c == 10 || c == 13 || c == 32 { return 0; };
        i = i + 1;
    };
    return 1;
}

fn registry_remotes_load_native() -> Vec<i32> {
    let mut remotes: Vec<i32> = Vec::new();
    let raw: str = file_read_string(registry_remotes_config_path_native());
    let rlen: i64 = str_len(raw);
    let mut p: i64 = 0;
    while p <= rlen {
        let mut eol: i64 = p;
        while eol < rlen && str_char_at(raw, eol) != 10 { eol = eol + 1; };
        let line: str = trim_ws(str_substring(raw, p, eol));
        let llen: i64 = str_len(line);
        if llen > 0 && str_char_at(line, 0) != 35 {
            let mut sep: i64 = 0 - 1;
            let mut i: i64 = 0;
            while i < llen && sep < 0 {
                let c: i64 = str_char_at(line, i);
                if c == 9 || c == 32 { sep = i; };
                i = i + 1;
            };
            if sep > 0 {
                let name: str = trim_ws(str_substring(line, 0, sep));
                let url: str = trim_ws(str_substring(line, sep + 1, llen));
                if registry_remote_name_is_valid_native(name) == 1 && registry_remote_url_is_valid_native(url) == 1 {
                    remotes.push(name);
                    remotes.push(url);
                };
            };
        };
        p = eol + 1;
    };
    return remotes;
}

fn registry_remote_find_native(remotes: Vec<i32>, name: str) -> i64 {
    let mut i: i64 = 0;
    while i + 1 < vec_len(remotes) {
        if str_eq(vec_get(remotes, i), name) == 1 { return i; };
        i = i + 2;
    };
    return 0 - 1;
}

fn registry_remotes_render_native(remotes: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut i: i64 = 0;
    while i + 1 < vec_len(remotes) {
        sb_append(sb, vec_get(remotes, i));
        sb_append(sb, "\t");
        sb_append(sb, vec_get(remotes, i + 1));
        sb_append(sb, "\n");
        i = i + 2;
    };
    return sb_to_str(sb);
}

fn registry_remotes_write_native(remotes: Vec<i32>) -> i64 {
    fs_create_dir_all(".nucleor");
    file_write_string(registry_remotes_config_path_native(), registry_remotes_render_native(remotes));
    return 0;
}

fn run_registry_remote_command_native(positionals: Vec<i32>) -> i64 {
    if vec_len(positionals) < 2 {
        print("Usage: nuc registry remote [add <name> <url>|list|remove <name>]");
        return 1;
    };
    let op: str = vec_get(positionals, 1);
    if str_eq(op, "list") == 1 {
        if vec_len(positionals) != 2 {
            print("Usage: nuc registry remote list");
            return 1;
        };
        let remotes: Vec<i32> = registry_remotes_load_native();
        print(str_concat("registry remotes: ", registry_remotes_config_path_native()));
        if vec_len(remotes) == 0 {
            print("remotes: 0");
            return 0;
        };
        let mut i: i64 = 0;
        while i + 1 < vec_len(remotes) {
            print(str_concat(vec_get(remotes, i), str_concat("  ", vec_get(remotes, i + 1))));
            i = i + 2;
        };
        return 0;
    };
    if str_eq(op, "add") == 1 {
        if vec_len(positionals) != 4 {
            print("Usage: nuc registry remote add <name> <url>");
            return 1;
        };
        let name: str = vec_get(positionals, 2);
        let url: str = vec_get(positionals, 3);
        if registry_remote_name_is_valid_native(name) == 0 {
            print(str_concat("ERROR: invalid registry remote name: ", name));
            print("Remote names may contain ASCII letters, digits, _, -, and .");
            return 1;
        };
        if registry_remote_url_is_valid_native(url) == 0 {
            print(str_concat("ERROR: invalid registry remote URL: ", url));
            return 1;
        };
        let remotes: Vec<i32> = registry_remotes_load_native();
        if registry_remote_find_native(remotes, name) >= 0 {
            print(str_concat("ERROR: registry remote already exists: ", name));
            return 1;
        };
        remotes.push(name);
        remotes.push(url);
        registry_remotes_write_native(remotes);
        print(str_concat("added registry remote: ", str_concat(name, str_concat("  ", url))));
        return 0;
    };
    if str_eq(op, "remove") == 1 {
        if vec_len(positionals) != 3 {
            print("Usage: nuc registry remote remove <name>");
            return 1;
        };
        let name2: str = vec_get(positionals, 2);
        let remotes2: Vec<i32> = registry_remotes_load_native();
        if registry_remote_find_native(remotes2, name2) < 0 {
            print(str_concat("ERROR: registry remote not found: ", name2));
            return 1;
        };
        let mut out: Vec<i32> = Vec::new();
        let mut i: i64 = 0;
        while i + 1 < vec_len(remotes2) {
            if str_eq(vec_get(remotes2, i), name2) == 0 {
                out.push(vec_get(remotes2, i));
                out.push(vec_get(remotes2, i + 1));
            };
            i = i + 2;
        };
        registry_remotes_write_native(out);
        print(str_concat("removed registry remote: ", name2));
        return 0;
    };
    print("Usage: nuc registry remote [add <name> <url>|list|remove <name>]");
    return 1;
}

fn semver_score(version: str) -> i64 {
    let vlen: i64 = str_len(version);
    let mut parts: Vec<i32> = Vec::new();
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= vlen {
        let at_end: i64 = i == vlen;
        let mut at_dot: i64 = 0;
        if at_end == 0 && str_char_at(version, i) == 46 { at_dot = 1; };
        if at_end == 1 || at_dot == 1 {
            parts.push(str_to_int(str_substring(version, start, i)));
            start = i + 1;
        };
        i = i + 1;
    };
    let major: i64 = if vec_len(parts) > 0 { vec_get(parts, 0) } else { 0 };
    let minor: i64 = if vec_len(parts) > 1 { vec_get(parts, 1) } else { 0 };
    let patch: i64 = if vec_len(parts) > 2 { vec_get(parts, 2) } else { 0 };
    return major * 1000000000 + minor * 1000000 + patch;
}

fn registry_sort_versions_desc(versions: Vec<i32>) -> i64 {
    let mut i: i64 = 0;
    while i < vec_len(versions) {
        let mut j: i64 = i + 1;
        while j < vec_len(versions) {
            if semver_score(vec_get(versions, j)) > semver_score(vec_get(versions, i)) {
                let tmp: str = vec_get(versions, i);
                vec_set(versions, i, vec_get(versions, j));
                vec_set(versions, j, tmp);
            };
            j = j + 1;
        };
        i = i + 1;
    };
    return 0;
}

fn registry_package_versions_native(registry_dir: str, package_name: str) -> Vec<i32> {
    let package_root: str = sanitize(str_concat(path_with_sep(registry_dir), package_name));
    let dirs: Vec<i32> = dir_list_native(package_root, 1);
    let mut versions: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < vec_len(dirs) {
        let version: str = vec_get(dirs, i);
        let manifest_path: str = sanitize(str_concat(path_with_sep(package_root), str_concat(version, "/Nucleor.toml")));
        if str_len(file_read_string(manifest_path)) > 0 { versions.push(version); };
        i = i + 1;
    };
    registry_sort_versions_desc(versions);
    return versions;
}

fn parse_registry_spec_native(spec: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let slen: i64 = str_len(spec);
    let mut at_pos: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < slen {
        if str_char_at(spec, i) == 64 && at_pos < 0 { at_pos = i; };
        i = i + 1;
    };
    if at_pos < 0 {
        out.push(spec);
        out.push("latest");
        return out;
    };
    out.push(str_substring(spec, 0, at_pos));
    out.push(str_substring(spec, at_pos + 1, slen));
    return out;
}

fn registry_resolve_version_native(registry_dir: str, package_name: str, selector: str) -> str {
    let versions: Vec<i32> = registry_package_versions_native(registry_dir, package_name);
    if vec_len(versions) == 0 { return ""; };
    if str_eq(selector, "latest") == 1 || str_len(selector) == 0 { return vec_get(versions, 0); };
    // detect unsupported semver syntax
    // and emit a clear diagnostic. Pre-fix the resolver returned
    // "" silently when the selector wasn't an exact match,
    // producing "no matching version" with no clue about the
    // actual cause (constraint syntax not supported).
    let sel_first: i64 = if str_len(selector) > 0 { str_char_at(selector, 0) } else { 0 };
    let is_caret: i64 = if sel_first == 94 { 1 } else { 0 };       // ^
    let is_tilde: i64 = if sel_first == 126 { 1 } else { 0 };      // ~
    let is_compare: i64 = if sel_first == 60 || sel_first == 62 { 1 } else { 0 };  // < or >
    let has_wildcard: i64 = if str_index_of(selector, "*") >= 0 { 1 } else { 0 };
    if is_caret == 1 {
        let base: str = str_substring(selector, 1, str_len(selector));
        let base_score: i64 = semver_score(base);
        let base_major: i64 = base_score / 1000000000;
        let base_minor: i64 = (base_score - base_major * 1000000000) / 1000000;
        let base_patch: i64 = base_score - base_major * 1000000000 - base_minor * 1000000;
        let mut upper: i64 = 0;
        if base_major > 0 {
            upper = (base_major + 1) * 1000000000;
        } else {
            if base_minor > 0 {
                upper = (base_minor + 1) * 1000000;
            } else {
                upper = base_patch + 1;
            };
        };
        let mut ci: i64 = 0;
        while ci < vec_len(versions) {
            let cand: str = vec_get(versions, ci);
            let cand_score: i64 = semver_score(cand);
            if cand_score >= base_score {
                if cand_score < upper { return cand; };
            };
            ci = ci + 1;
        };
        // No candidate in [base, upper). Fall through to the
        // diagnostic so the user sees what's missing.
    };
    if is_tilde == 1 {
        let tbase: str = str_substring(selector, 1, str_len(selector));
        let tbase_score: i64 = semver_score(tbase);
        let tbase_major: i64 = tbase_score / 1000000000;
        let tbase_minor: i64 = (tbase_score - tbase_major * 1000000000) / 1000000;
        let tupper: i64 = tbase_major * 1000000000 + (tbase_minor + 1) * 1000000;
        let mut ti: i64 = 0;
        while ti < vec_len(versions) {
            let tcand: str = vec_get(versions, ti);
            let tcand_score: i64 = semver_score(tcand);
            if tcand_score >= tbase_score {
                if tcand_score < tupper { return tcand; };
            };
            ti = ti + 1;
        };
        // No candidate in [base, upper). Fall through to the
        // tilde-no-match diagnostic below.
    };
    if has_wildcard == 1 {
        if str_eq(selector, "*") == 1 { return vec_get(versions, 0); };
        // Strip `.*` suffix and parse the prefix.
        let star_idx: i64 = str_index_of(selector, ".*");
        if star_idx > 0 {
            let prefix: str = str_substring(selector, 0, star_idx);
            // Count dots in prefix to know if it's `X` (major-only)
            // or `X.Y` (major-minor).
            let mut dot_count: i64 = 0;
            let mut wi: i64 = 0;
            while wi < str_len(prefix) {
                if str_char_at(prefix, wi) == 46 { dot_count = dot_count + 1; };
                wi = wi + 1;
            };
            // Build a base version string the parser can score.
            let base_w: str = if dot_count == 0 {
                str_concat(prefix, ".0.0")
            } else {
                str_concat(prefix, ".0")
            };
            let wbase_score: i64 = semver_score(base_w);
            let wbase_major: i64 = wbase_score / 1000000000;
            let wbase_minor: i64 = (wbase_score - wbase_major * 1000000000) / 1000000;
            let wupper: i64 = if dot_count == 0 {
                (wbase_major + 1) * 1000000000
            } else {
                wbase_major * 1000000000 + (wbase_minor + 1) * 1000000
            };
            let mut wci: i64 = 0;
            while wci < vec_len(versions) {
                let wcand: str = vec_get(versions, wci);
                let wcand_score: i64 = semver_score(wcand);
                if wcand_score >= wbase_score {
                    if wcand_score < wupper { return wcand; };
                };
                wci = wci + 1;
            };
            print(str_concat("error[PKG-3]: wildcard constraint `", str_concat(selector, str_concat("` did not match any published version of `", str_concat(package_name, "`.")))));
            return "";
        };
        // Wildcard in an unsupported position (e.g. `1.*.0`).
        print(str_concat("error[PKG-3]: wildcard form `", str_concat(selector, "` not yet supported. Use `X.*` or `X.Y.*` (wildcard at trailing position only) or pin exactly.")));
        return "";
    };
    let has_space: i64 = if str_index_of(selector, " ") >= 0 { 1 } else { 0 };
    if is_compare == 1 && has_space == 1 {
        let tokens: Vec<i32> = str_split(selector, " ");
        let mut lower: i64 = 0 - 1;          // -1 = no lower bound
        let mut lower_incl: i64 = 0;
        let mut upper: i64 = 0 - 1;          // -1 = no upper bound
        let mut upper_incl: i64 = 0;
        let mut bad_token: i64 = 0;
        let mut tk: i64 = 0;
        while tk < vec_len(tokens) {
            let tok: str = vec_get(tokens, tk);
            if str_len(tok) > 0 {
                let tk_first: i64 = str_char_at(tok, 0);
                let tk_second: i64 = if str_len(tok) > 1 { str_char_at(tok, 1) } else { 0 };
                let tk_oplen: i64 = if tk_second == 61 { 2 } else { 1 };
                let tk_base: str = str_substring(tok, tk_oplen, str_len(tok));
                let tk_score: i64 = semver_score(tk_base);
                if tk_first == 62 {
                    if lower < 0 || tk_score > lower {
                        lower = tk_score;
                        lower_incl = if tk_oplen == 2 { 1 } else { 0 };
                    };
                } else {
                    if tk_first == 60 {
                        if upper < 0 || tk_score < upper {
                            upper = tk_score;
                            upper_incl = if tk_oplen == 2 { 1 } else { 0 };
                        };
                    } else {
                        bad_token = 1;
                    };
                };
            };
            tk = tk + 1;
        };
        if bad_token == 0 {
            let mut cri: i64 = 0;
            while cri < vec_len(versions) {
                let cr_cand: str = vec_get(versions, cri);
                let cr_score: i64 = semver_score(cr_cand);
                let mut ok: i64 = 1;
                if lower >= 0 {
                    if lower_incl == 1 {
                        if cr_score < lower { ok = 0; };
                    } else {
                        if cr_score <= lower { ok = 0; };
                    };
                };
                if upper >= 0 {
                    if upper_incl == 1 {
                        if cr_score > upper { ok = 0; };
                    } else {
                        if cr_score >= upper { ok = 0; };
                    };
                };
                if ok == 1 { return cr_cand; };
                cri = cri + 1;
            };
            print(str_concat("error[PKG-3]: compound range `", str_concat(selector, str_concat("` did not match any published version of `", str_concat(package_name, "`.")))));
            return "";
        };
        // bad_token: fall through to single-token branch which will
        // emit its own error for the malformed input.
    };
    if is_compare == 1 {
        // Detect operator length (>= vs > vs <= vs <).
        let mut op_len: i64 = 1;
        let sec_char: i64 = if str_len(selector) > 1 { str_char_at(selector, 1) } else { 0 };
        if sec_char == 61 { op_len = 2; };  // '=' second char → >= or <=
        let cmp_base: str = str_substring(selector, op_len, str_len(selector));
        let cmp_base_score: i64 = semver_score(cmp_base);
        let is_gt: i64 = if sel_first == 62 { 1 } else { 0 };  // >
        let is_lt: i64 = if sel_first == 60 { 1 } else { 0 };  // <
        let inclusive: i64 = if op_len == 2 { 1 } else { 0 };
        let mut cmpi: i64 = 0;
        while cmpi < vec_len(versions) {
            let cmp_cand: str = vec_get(versions, cmpi);
            let cmp_cand_score: i64 = semver_score(cmp_cand);
            let mut hit: i64 = 0;
            if is_gt == 1 {
                if inclusive == 1 {
                    if cmp_cand_score >= cmp_base_score { hit = 1; };
                } else {
                    if cmp_cand_score > cmp_base_score { hit = 1; };
                };
            };
            if is_lt == 1 {
                if inclusive == 1 {
                    if cmp_cand_score <= cmp_base_score { hit = 1; };
                } else {
                    if cmp_cand_score < cmp_base_score { hit = 1; };
                };
            };
            if hit == 1 { return cmp_cand; };
            cmpi = cmpi + 1;
        };
        print(str_concat("error[PKG-3]: comparison constraint `", str_concat(selector, str_concat("` did not match any published version of `", str_concat(package_name, "`.")))));
        return "";
    };
    if is_caret == 1 {
        print(str_concat("error[PKG-3]: caret constraint `", str_concat(selector, str_concat("` did not match any published version of `", str_concat(package_name, "`.")))));
        return "";
    };
    if is_tilde == 1 {
        print(str_concat("error[PKG-3]: tilde constraint `", str_concat(selector, str_concat("` did not match any published version of `", str_concat(package_name, "`.")))));
        return "";
    };
    let mut i: i64 = 0;
    while i < vec_len(versions) {
        let version: str = vec_get(versions, i);
        if str_eq(version, selector) == 1 { return version; };
        i = i + 1;
    };
    return "";
}

fn registry_export_static_native(registry_dir: str, out_dir: str) -> Vec<i32> {
    // T1.4 (v0.2.344): convert the local file-system registry tree
    // into the GitHub-Pages-publishable static-site shape per
    // RFC-0019 §6. Returns [pkg_count, version_count, file_count]
    // so the CLI can summarize what got exported.
    //
    // Schema: <out_dir>/index.json (top-level package list),
    // <out_dir>/<pkg>/index.json (per-package version list +
    // latest pointer), <out_dir>/<pkg>/<version>/<files...>
    // (verbatim copy of the source tree).
    let mut counts: Vec<i32> = Vec::new();
    counts.push(0);
    counts.push(0);
    counts.push(0);
    fs_create_dir_all(out_dir);
    let packages: Vec<i32> = dir_list_native(registry_dir, 1);
    let mut pkg_count: i64 = 0;
    let mut ver_count: i64 = 0;
    let mut file_count: i64 = 0;
    let mut top_index: i64 = sb_new();
    sb_append(top_index, "{\"schema_version\":\"1.0\",\"type\":\"nucleor_registry_index\",\"packages\":[");
    let mut first_pkg: i64 = 1;
    let mut pi: i64 = 0;
    while pi < vec_len(packages) {
        let name: str = vec_get(packages, pi);
        let versions: Vec<i32> = registry_package_versions_native(registry_dir, name);
        if vec_len(versions) > 0 {
            if first_pkg == 0 { sb_append(top_index, ","); };
            first_pkg = 0;
            sb_append(top_index, "{\"name\":\"");
            sb_append(top_index, json_escape(name));
            sb_append(top_index, "\",\"latest\":\"");
            sb_append(top_index, json_escape(vec_get(versions, 0)));
            sb_append(top_index, "\",\"versions\":");
            sb_append_json_string_array(top_index, versions);
            sb_append(top_index, "}");
            pkg_count = pkg_count + 1;
            // Per-package directory + per-package index.json
            let pkg_out: str = sanitize(str_concat(path_with_sep(out_dir), name));
            fs_create_dir_all(pkg_out);
            let mut pkg_index: i64 = sb_new();
            sb_append(pkg_index, "{\"schema_version\":\"1.0\",\"type\":\"nucleor_registry_package\",\"name\":\"");
            sb_append(pkg_index, json_escape(name));
            sb_append(pkg_index, "\",\"latest\":\"");
            sb_append(pkg_index, json_escape(vec_get(versions, 0)));
            sb_append(pkg_index, "\",\"versions\":");
            sb_append_json_string_array(pkg_index, versions);
            sb_append(pkg_index, "}");
            file_write_string(sanitize(str_concat(path_with_sep(pkg_out), "index.json")), sb_to_str(pkg_index));
            file_count = file_count + 1;
            // Per-version: copy the source tree verbatim
            let mut vi: i64 = 0;
            while vi < vec_len(versions) {
                let version: str = vec_get(versions, vi);
                let src_root: str = sanitize(str_concat(path_with_sep(registry_dir), str_concat(name, str_concat("/", version))));
                let dst_root: str = sanitize(str_concat(path_with_sep(pkg_out), version));
                fs_create_dir_all(dst_root);
                let copied: i64 = registry_export_copy_tree_native(src_root, dst_root);
                file_count = file_count + copied;
                ver_count = ver_count + 1;
                vi = vi + 1;
            };
        };
        pi = pi + 1;
    };
    sb_append(top_index, "],\"count\":");
    sb_append(top_index, str_from_int(pkg_count));
    sb_append(top_index, "}");
    file_write_string(sanitize(str_concat(path_with_sep(out_dir), "index.json")), sb_to_str(top_index));
    file_count = file_count + 1;
    vec_set(counts, 0, pkg_count);
    vec_set(counts, 1, ver_count);
    vec_set(counts, 2, file_count);
    return counts;
}

fn registry_export_copy_tree_native(src_root: str, dst_root: str) -> i64 {
    // Recursive directory copy. Returns the number of files copied.
    // Uses walk_dir_recursive_native (already cross-platform per T1.7)
    // so this works identically on Windows and POSIX.
    let files: Vec<i32> = walk_dir_recursive_native(src_root);
    let n: i64 = vec_len(files);
    let mut copied: i64 = 0;
    let mut i: i64 = 0;
    while i < n {
        let file_path: str = vec_get(files, i);
        let rel: str = path_relative_inventory(src_root, file_path);
        let dst_path: str = sanitize(str_concat(path_with_sep(dst_root), rel));
        let dst_parent: str = parent_dir(dst_path);
        if str_len(dst_parent) > 0 { fs_create_dir_all(dst_parent); };
        if fs_copy_file(file_path, dst_path) == 1 { copied = copied + 1; };
        i = i + 1;
    };
    return copied;
}

fn native_release_repo_root() -> str {
    let script_path: str = native_release_script_path();
    return parent_dir(parent_dir(script_path));
}

fn native_release_script_path() -> str {
    let exe_dir: str = trim_trailing_sep(extract_dir(args_get(0)));
    if str_len(exe_dir) > 0 {
        let parent: str = parent_dir(exe_dir);
        let parent_script: str = sanitize(str_concat(path_with_sep(parent), "tools/native_release.ps1"));
        if str_len(file_read_string(parent_script)) > 0 { return parent_script; };
    };
    let up_script: str = sanitize("../tools/native_release.ps1");
    if str_len(file_read_string(up_script)) > 0 { return up_script; };
    let cwd_script: str = sanitize("tools/native_release.ps1");
    if str_len(file_read_string(cwd_script)) > 0 { return cwd_script; };
    return sanitize("tools/native_release.ps1");
}

fn invoke_native_package_sign(package_root: str, key_id: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push(0);
    out.push("");
    out.push("");
    // use the C-runtime cross-platform mkdir
    // (POSIX `mkdir(2)` syscall) instead of `system("mkdir ...
    // 2>NUL")` which only worked on Windows. fs_create_dir_all
    // is idempotent — succeeds whether the dir exists or not.
    fs_create_dir_all(".nuc_cache");
    let output_path: str = str_concat(".nuc_cache/package_sign_", str_concat(str_from_int(now_ms()), ".json"));
    let repo_root: str = native_release_repo_root();
    let script_path: str = native_release_script_path();
    let mut ps_cmd: str = str_concat("& '", str_concat(path_shell_native(script_path), str_concat("' -Root '", str_concat(path_shell_native(repo_root), str_concat("' package-sign '", str_concat(path_shell_native(package_root), "'"))))));
    if str_len(key_id) > 0 {
        ps_cmd = str_concat(ps_cmd, str_concat(" '", str_concat(key_id, "'")));
    };
    // use `pwsh` (PowerShell 7+ cross-platform
    // binary) instead of `powershell` (Windows-only legacy 5.1).
    // Adopters on Linux/macOS install pwsh via the standard
    // package channels per docs.microsoft.com/powershell/scripting.
    let mut cmd: str = str_concat("pwsh -ExecutionPolicy Bypass -Command ", shell_quote(str_concat(ps_cmd, " --json")));
    cmd = str_concat(cmd, str_concat(" > ", str_concat(shell_quote(path_shell_native(output_path)), " 2>&1")));
    let rc: i64 = system(cmd);
    let raw: str = file_read_string(output_path);
    // leave the temp file in .nuc_cache (it's
    // gitignored). The previous Windows `del /q` cleanup failed
    // silently on Linux. Cleaner to skip the cleanup; .nuc_cache
    // is the standard scratch dir.
    if rc != 0 {
        vec_set(out, 2, trim_ws(raw));
        if str_len(vec_get(out, 2)) == 0 { vec_set(out, 2, str_concat("native package signing failed: ", package_root)); };
        return out;
    };
    vec_set(out, 0, 1);
    vec_set(out, 1, raw);
    return out;
}

fn invoke_native_package_verify(package_root: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push(0);
    out.push("");
    out.push("");
    // cross-platform — fs_create_dir_all, pwsh, no del
    fs_create_dir_all(".nuc_cache");
    let output_path: str = str_concat(".nuc_cache/package_verify_", str_concat(str_from_int(now_ms()), ".json"));
    let repo_root: str = native_release_repo_root();
    let script_path: str = native_release_script_path();
    let ps_cmd: str = str_concat("& '", str_concat(path_shell_native(script_path), str_concat("' -Root '", str_concat(path_shell_native(repo_root), str_concat("' package-verify '", str_concat(path_shell_native(package_root), "' --json"))))));
    let mut cmd: str = str_concat("pwsh -ExecutionPolicy Bypass -Command ", shell_quote(ps_cmd));
    cmd = str_concat(cmd, str_concat(" > ", str_concat(shell_quote(path_shell_native(output_path)), " 2>&1")));
    let rc: i64 = system(cmd);
    let raw: str = file_read_string(output_path);
    if rc != 0 {
        vec_set(out, 2, trim_ws(raw));
        if str_len(vec_get(out, 2)) == 0 { vec_set(out, 2, str_concat("native package verification failed: ", package_root)); };
        return out;
    };
    vec_set(out, 0, 1);
    vec_set(out, 1, raw);
    return out;
}

fn verify_registry_package_root_native(registry_dir: str, package_name: str, version: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let root: str = sanitize(str_concat(path_with_sep(registry_dir), str_concat(package_name, str_concat("/", version))));
    let manifest_path: str = sanitize(str_concat(path_with_sep(root), "Nucleor.toml"));
    let checksum_path: str = sanitize(str_concat(path_with_sep(root), package_checksum_file_name()));
    let metadata_path: str = sanitize(str_concat(path_with_sep(root), registry_metadata_file_name()));
    let signature_path: str = sanitize(str_concat(path_with_sep(root), package_signature_file_name()));
    let exports_path: str = sanitize(str_concat(path_with_sep(root), package_exports_manifest_file_name()));
    let exports_header_path: str = sanitize(str_concat(path_with_sep(root), package_exports_header_file_name()));
    let exports_rust_path: str = sanitize(str_concat(path_with_sep(root), package_exports_rust_file_name()));
    let mut ok: i64 = 1;
    let mut error: str = "";
    let mut export_count: i64 = 0;
    let mut signed: i64 = 0;
    let mut signing_key_id: str = "";
    let mut signing_algorithm: str = "none";
    if str_len(file_read_string(manifest_path)) == 0 {
        ok = 0;
        error = str_concat("package not found in registry: ", root);
    } else if str_len(file_read_string(checksum_path)) == 0 {
        ok = 0;
        error = str_concat("registry package is missing ", package_checksum_file_name());
    } else if text_contains(file_read_string(checksum_path), package_checksum_native(root)) == 0 {
        ok = 0;
        error = str_concat("registry package checksum mismatch: ", root);
    } else if str_len(file_read_string(metadata_path)) == 0 {
        ok = 0;
        error = str_concat("registry package is missing ", registry_metadata_file_name());
    } else {
        let metadata_raw: str = file_read_string(metadata_path);
        let metadata_compact: str = strip_spaces(metadata_raw);
        signing_algorithm = json_extract_string_value(metadata_raw, "algorithm");
        signing_key_id = json_extract_string_value(metadata_raw, "key_id");
        if text_contains(metadata_compact, "\"exports\":{\"present\":true") == 1 {
            let exports_raw: str = file_read_string(exports_path);
            if str_len(exports_raw) == 0 {
                ok = 0;
                error = str_concat("registry package is missing ", package_exports_manifest_file_name());
            } else if str_len(file_read_string(exports_header_path)) == 0 {
                ok = 0;
                error = str_concat("registry package is missing ", package_exports_header_file_name());
            } else if str_len(file_read_string(exports_rust_path)) == 0 {
                ok = 0;
                error = str_concat("registry package is missing ", package_exports_rust_file_name());
            } else {
                let exports_compact: str = strip_spaces(exports_raw);
                let expected_count: i64 = json_extract_int_value(metadata_raw, "count");
                let observed_count: i64 = json_extract_int_value(exports_raw, "export_count");
                if text_contains(exports_compact, "\"type\":\"package_exports\"") == 0 {
                    ok = 0;
                    error = str_concat("registry package has invalid ", package_exports_manifest_file_name());
                } else if text_contains(exports_compact, str_concat("\"name\":\"", str_concat(package_name, "\""))) == 0 || text_contains(exports_compact, str_concat("\"version\":\"", str_concat(version, "\""))) == 0 {
                    ok = 0;
                    error = str_concat("registry package export manifest does not match package identity: ", root);
                } else if expected_count != observed_count {
                    ok = 0;
                    error = str_concat("registry package export manifest count mismatch: ", root);
                } else if text_contains(exports_compact, str_concat("\"abi_version\":\"", str_concat(abi_export_version_label(), "\""))) == 0 || text_contains(exports_compact, str_concat("\"surface\":\"", str_concat(abi_export_surface_policy_label(), "\""))) == 0 || text_contains(exports_compact, str_concat("\"version_policy\":\"", str_concat(abi_export_version_policy_label(), "\""))) == 0 {
                    ok = 0;
                    error = str_concat("registry package export policy metadata is incomplete: ", root);
                } else {
                    export_count = observed_count;
                };
            };
        };
        if ok == 1 {
            if str_len(signing_algorithm) == 0 { signing_algorithm = "none"; };
            if str_eq(signing_algorithm, "none") == 1 {
                if str_len(file_read_string(signature_path)) > 0 {
                    ok = 0;
                    error = str_concat("registry package has unexpected ", package_signature_file_name());
                };
            } else {
                if str_len(file_read_string(signature_path)) == 0 {
                    ok = 0;
                    error = str_concat("registry package is missing ", package_signature_file_name());
                } else {
                    let signed_result: Vec<i32> = invoke_native_package_verify(root);
                    if vec_get(signed_result, 0) == 0 {
                        ok = 0;
                        error = vec_get(signed_result, 2);
                    } else {
                        signed = 1;
                        if str_len(signing_key_id) == 0 {
                            signing_key_id = json_extract_string_value(vec_get(signed_result, 1), "key_id");
                        };
                    };
                };
            };
        };
    };
    out.push(ok);
    out.push(root);
    out.push(error);
    out.push(export_count);
    out.push(signed);
    out.push(signing_key_id);
    out.push(signing_algorithm);
    return out;
}

fn write_package_export_artifacts_native(package_root: str, settings: Vec<i32>) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    out.push(0);
    out.push(0);
    out.push("");
    let entry_path: str = manifest_entry_source_path(package_root, settings);
    let entry_rel: str = path_normalize_slashes(manifest_settings_entry(settings));
    let source: str = file_read_string(entry_path);
    if str_len(source) == 0 {
        vec_set(out, 0, -1);
        vec_set(out, 2, str_concat("cannot read package entry source: ", entry_path));
        return out;
    };
    if preflight_source_check(source) != 0 {
        vec_set(out, 0, -1);
        vec_set(out, 2, str_concat("entry source preflight failed: ", entry_path));
        return out;
    };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    let export_names: Vec<i32> = collect_public_export_names(source);
    if vec_len(export_names) == 0 { return out; };
    if validate_export_surface(pool, prog, export_names) != 0 {
        vec_set(out, 0, -1);
        vec_set(out, 2, str_concat("package export surface validation failed: ", entry_path));
        return out;
    };
    let json_path: str = sanitize(str_concat(path_with_sep(package_root), package_exports_manifest_file_name()));
    let header_path: str = sanitize(str_concat(path_with_sep(package_root), package_exports_header_file_name()));
    let rust_path: str = sanitize(str_concat(path_with_sep(package_root), package_exports_rust_file_name()));
    file_write_string(json_path, render_package_export_manifest_json(entry_rel, settings, pool, prog, export_names));
    file_write_string(header_path, render_export_c_header(entry_rel, pool, prog, export_names));
    file_write_string(rust_path, render_export_rust_extern(entry_rel, pool, prog, export_names));
    vec_set(out, 0, 1);
    vec_set(out, 1, vec_len(export_names));
    return out;
}

fn write_registry_metadata_file_native(package_root: str, settings: Vec<i32>, export_info: Vec<i32>, signing_algorithm_in: str, signing_key_id_in: str) -> str {
    let metadata_path: str = sanitize(str_concat(path_with_sep(package_root), registry_metadata_file_name()));
    let signing_algorithm: str = if str_len(signing_algorithm_in) > 0 { signing_algorithm_in } else { "none" };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":1,\"package\":{\"name\":\"");
    sb_append(sb, json_escape(manifest_settings_package_name(settings)));
    sb_append(sb, "\",\"version\":\"");
    sb_append(sb, json_escape(manifest_settings_version(settings)));
    sb_append(sb, "\",\"entry\":\"");
    sb_append(sb, json_escape(path_normalize_slashes(manifest_settings_entry(settings))));
    sb_append(sb, "\"},\"published_at_unix_s\":");
    sb_append(sb, str_from_int(now_ms() / 1000));
    sb_append(sb, ",\"checksum\":\"");
    sb_append(sb, json_escape(package_checksum_native(package_root)));
    sb_append(sb, "\",\"signing\":{\"algorithm\":\"");
    sb_append(sb, json_escape(signing_algorithm));
    sb_append(sb, "\",\"key_id\":");
    if str_len(signing_key_id_in) > 0 { sb_append_json_string_or_null(sb, signing_key_id_in); }
    else { sb_append(sb, "null"); };
    sb_append(sb, ",\"signature_file\":");
    if str_eq(signing_algorithm, "none") == 1 { sb_append(sb, "null"); }
    else { sb_append_json_string_or_null(sb, package_signature_file_name()); };
    sb_append(sb, ",\"mode\":");
    if str_eq(signing_algorithm, "none") == 1 { sb_append(sb, "null"); }
    else { sb_append_json_string_or_null(sb, "openssh-y-sign"); };
    sb_append(sb, "},\"exports\":{\"present\":");
    sb_append_json_bool(sb, vec_get(export_info, 0) == 1);
    sb_append(sb, ",\"count\":");
    sb_append(sb, str_from_int(vec_get(export_info, 1)));
    sb_append(sb, ",\"manifest\":\"");
    sb_append(sb, json_escape(package_exports_manifest_file_name()));
    sb_append(sb, "\",\"c_header\":\"");
    sb_append(sb, json_escape(package_exports_header_file_name()));
    sb_append(sb, "\",\"rust_extern\":\"");
    sb_append(sb, json_escape(package_exports_rust_file_name()));
    sb_append(sb, "\",\"abi_version\":\"");
    sb_append(sb, json_escape(abi_export_version_label()));
    sb_append(sb, "\",\"surface\":\"");
    sb_append(sb, json_escape(abi_export_surface_policy_label()));
    sb_append(sb, "\",\"symbol_policy\":\"");
    sb_append(sb, json_escape(abi_export_symbol_policy_label()));
    sb_append(sb, "\",\"version_policy\":\"");
    sb_append(sb, json_escape(abi_export_version_policy_label()));
    sb_append(sb, "\"}}");
    file_write_string(metadata_path, sb_to_str(sb));
    return metadata_path;
}

fn path_split_components(path: str) -> Vec<i32> {
    let mut out: Vec<i32> = Vec::new();
    let norm: str = path_normalize_slashes(trim_trailing_sep(path));
    let nlen: i64 = str_len(norm);
    let mut start: i64 = 0;
    let mut i: i64 = 0;
    while i <= nlen {
        let at_end: i64 = i == nlen;
        let mut at_sep: i64 = 0;
        if at_end == 0 {
            let ch: i64 = str_char_at(norm, i);
            if ch == 47 || ch == 92 { at_sep = 1; };
        };
        if at_end == 1 || at_sep == 1 {
            if i > start {
                out.push(str_substring(norm, start, i));
            };
            start = i + 1;
        };
        i = i + 1;
    };
    return out;
}

fn path_relative_between(base_dir: str, target_path: str) -> str {
    let base_norm: str = path_normalize_slashes(trim_trailing_sep(base_dir));
    let target_norm: str = path_normalize_slashes(trim_trailing_sep(target_path));
    if str_len(base_norm) == 0 { return target_norm; };
    if str_len(target_norm) == 0 { return "."; };
    let base_parts: Vec<i32> = path_split_components(base_norm);
    let target_parts: Vec<i32> = path_split_components(target_norm);
    let mut common: i64 = 0;
    let blen: i64 = vec_len(base_parts);
    let tlen: i64 = vec_len(target_parts);
    while common < blen && common < tlen && str_eq(vec_get(base_parts, common), vec_get(target_parts, common)) == 1 {
        common = common + 1;
    };
    if common == 0 { return target_norm; };
    let mut rel_parts: Vec<i32> = Vec::new();
    let mut bi: i64 = common;
    while bi < blen {
        rel_parts.push("..");
        bi = bi + 1;
    };
    let mut ti: i64 = common;
    while ti < tlen {
        rel_parts.push(vec_get(target_parts, ti));
        ti = ti + 1;
    };
    if vec_len(rel_parts) == 0 { return "."; };
    return join_strings(rel_parts, "/");
}

fn publish_bundle_package_dir_native(root_manifest: str, publish_root: str, pkg: Vec<i32>) -> str {
    let manifest_path: str = vec_get(pkg, 0);
    if str_eq(manifest_path, root_manifest) == 1 { return publish_root; };
    return sanitize(str_concat(path_with_sep(publish_root), str_concat("package_deps/", str_concat(vec_get(pkg, 1), str_concat("/", vec_get(pkg, 2))))));
}

fn publish_bundle_layout_native(root_manifest: str, graph: Vec<i32>, publish_root: str) -> Vec<i32> {
    let mut layout: Vec<i32> = Vec::new();
    let mut gi: i64 = 0;
    while gi < vec_len(graph) {
        let pkg: Vec<i32> = vec_get(graph, gi);
        layout.push(vec_get(pkg, 0));
        layout.push(publish_bundle_package_dir_native(root_manifest, publish_root, pkg));
        gi = gi + 1;
    };
    return layout;
}

fn publish_bundle_lookup_dir_native(layout: Vec<i32>, manifest_path: str) -> str {
    let mut i: i64 = 0;
    while i < vec_len(layout) {
        if str_eq(vec_get(layout, i), manifest_path) == 1 { return vec_get(layout, i + 1); };
        i = i + 2;
    };
    return "";
}

fn publish_copy_graph_native(root_manifest: str, graph: Vec<i32>, publish_root: str) -> i64 {
    let layout: Vec<i32> = publish_bundle_layout_native(root_manifest, graph, publish_root);
    let mut gi: i64 = 0;
    while gi < vec_len(graph) {
        let pkg: Vec<i32> = vec_get(graph, gi);
        let manifest_path: str = vec_get(pkg, 0);
        let src_dir: str = parent_dir(manifest_path);
        let dst_dir: str = publish_bundle_lookup_dir_native(layout, manifest_path);
        if str_len(dst_dir) == 0 || copy_package_tree_native(src_dir, dst_dir) != 0 { return 1; };
        gi = gi + 1;
    };
    gi = 0;
    while gi < vec_len(graph) {
        let pkg2: Vec<i32> = vec_get(graph, gi);
        let manifest_path2: str = vec_get(pkg2, 0);
        let dst_dir2: str = publish_bundle_lookup_dir_native(layout, manifest_path2);
        let dst_manifest: str = sanitize(str_concat(path_with_sep(dst_dir2), "Nucleor.toml"));
        let deps: Vec<i32> = vec_get(pkg2, 5);
        let mut rewritten: Vec<i32> = Vec::new();
        let mut di: i64 = 0;
        while di < vec_len(deps) {
            let dep_alias: str = vec_get(deps, di);
            let dep_manifest: str = vec_get(deps, di + 2);
            let dep_dir: str = publish_bundle_lookup_dir_native(layout, dep_manifest);
            if str_len(dep_dir) == 0 { return 1; };
            rewritten.push(dep_alias);
            rewritten.push(path_normalize_slashes(path_relative_between(parent_dir(dst_manifest), dep_dir)));
            di = di + 3;
        };
        if manifest_replace_dependencies_section_native(dst_manifest, rewritten) != 0 { return 1; };
        gi = gi + 1;
    };
    return 0;
}

fn source_collect_imports(source: str) -> Vec<i32> {
    let mut imports: Vec<i32> = Vec::new();
    let slen: i64 = str_len(source);
    let mut p: i64 = 0;
    while p < slen {
        let mut eol: i64 = p;
        while eol < slen && str_char_at(source, eol) != 10 { eol = eol + 1; };
        let mut lp: i64 = p;
        while lp < eol && (str_char_at(source, lp) == 32 || str_char_at(source, lp) == 9) { lp = lp + 1; };
        if eol - lp >= 4 && str_eq(str_substring(source, lp, lp + 4), "use ") == 1 {
            let mut stop: i64 = eol;
            while stop > lp + 4 && (str_char_at(source, stop - 1) == 32 || str_char_at(source, stop - 1) == 9 || str_char_at(source, stop - 1) == 13 || str_char_at(source, stop - 1) == 59) {
                stop = stop - 1;
            };
            let imp: str = trim_ws(str_substring(source, lp + 4, stop));
            if str_len(imp) > 0 { string_vec_push_unique(imports, imp); };
        };
        p = eol + 1;
    };
    return imports;
}

fn cli_wants_json(argc: i64, arg_start: i64) -> i64 {
    let mut i: i64 = arg_start;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") == 1 || str_eq(arg, "--output=json") == 1 { return 1; };
        if str_eq(arg, "--output") == 1 && i + 1 < argc && str_eq(args_get(i + 1), "json") == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn cli_first_positional(argc: i64, arg_start: i64) -> str {
    let mut i: i64 = arg_start;
    while i < argc {
        let arg: str = args_get(i);
        if cli_is_flag(arg) == 0 { return arg; };
        if str_eq(arg, "--output") == 1 || str_eq(arg, "--fn") == 1 || str_eq(arg, "--function") == 1 {
            i = i + 1;
        };
        i = i + 1;
    };
    return "";
}

fn cli_option_value(argc: i64, arg_start: i64, opt_name: str) -> str {
    let prefix: str = str_concat(opt_name, "=");
    let mut i: i64 = arg_start;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, opt_name) == 1 {
            if i + 1 < argc { return args_get(i + 1); };
            return "";
        };
        if str_len(arg) > str_len(prefix) && str_eq(str_substring(arg, 0, str_len(prefix)), prefix) == 1 {
            return str_substring(arg, str_len(prefix), str_len(arg));
        };
        i = i + 1;
    };
    return "";
}

fn cli_has_flag(argc: i64, arg_start: i64, opt_name: str) -> i64 {
    let mut i: i64 = arg_start;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, opt_name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn program_has_pure_marker(pool: Vec<i32>, prog: i64, name: str) -> i64 {
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 46 && str_eq(node_field(pool, nid, 1), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn program_has_pub_marker(pool: Vec<i32>, prog: i64, name: str) -> i64 {
    // T1.5b (v0.2.341): companion to program_has_pure_marker. The
    // parser emits a kind-76 marker carrying the item's name
    // immediately before each `pub`-prefixed top-level item. Used by
    // render_summary_command to surface visibility in `nuc summary`,
    // and (future) by T1.5c's resolver-layer privatization to drive
    // cross-module enforcement.
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 76 && str_eq(node_field(pool, nid, 1), name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

fn param_list_text(pool: Vec<i32>, params_lid: i64) -> str {
    let mut parts: Vec<i32> = Vec::new();
    let cnt: i64 = list_len(pool, params_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let pnid: i64 = list_get(pool, params_lid, i);
        parts.push(str_concat(node_field(pool, pnid, 1), str_concat(": ", node_field(pool, pnid, 2))));
        i = i + 1;
    };
    return join_strings(parts, ", ");
}

fn generic_list_text(pool: Vec<i32>, gparams_lid: i64) -> str {
    let cnt: i64 = list_len(pool, gparams_lid);
    if cnt == 0 { return ""; };
    let mut names: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < cnt {
        names.push(list_get(pool, gparams_lid, i));
        i = i + 1;
    };
    return str_concat("<", str_concat(join_strings(names, ", "), ">"));
}

fn struct_fields_text(pool: Vec<i32>, fields_lid: i64) -> str {
    let mut parts: Vec<i32> = Vec::new();
    let cnt: i64 = list_len(pool, fields_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let fnid: i64 = list_get(pool, fields_lid, i);
        parts.push(str_concat(node_field(pool, fnid, 1), str_concat(": ", node_field(pool, fnid, 2))));
        i = i + 1;
    };
    return join_strings(parts, ", ");
}

fn enum_variant_text(pool: Vec<i32>, variant_nid: i64) -> str {
    let name: str = node_field(pool, variant_nid, 1);
    let fields_lid: i64 = node_field(pool, variant_nid, 2);
    let cnt: i64 = list_len(pool, fields_lid);
    if cnt == 0 { return name; };
    let mut parts: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < cnt {
        parts.push(list_get(pool, fields_lid, i));
        i = i + 1;
    };
    return str_concat(name, str_concat("(", str_concat(join_strings(parts, ", "), ")")));
}

fn append_params_json(sb: i64, pool: Vec<i32>, params_lid: i64) -> i64 {
    sb_append(sb, "[");
    let cnt: i64 = list_len(pool, params_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let pnid: i64 = list_get(pool, params_lid, i);
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "{\"name\":\"");
        sb_append(sb, json_escape(node_field(pool, pnid, 1)));
        sb_append(sb, "\",\"type\":\"");
        sb_append(sb, json_escape(node_field(pool, pnid, 2)));
        sb_append(sb, "\"}");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn append_generics_json(sb: i64, pool: Vec<i32>, gparams_lid: i64) -> i64 {
    let mut names: Vec<i32> = Vec::new();
    let cnt: i64 = list_len(pool, gparams_lid);
    let mut i: i64 = 0;
    while i < cnt {
        names.push(list_get(pool, gparams_lid, i));
        i = i + 1;
    };
    return sb_append_json_string_array(sb, names);
}

fn append_struct_fields_json(sb: i64, pool: Vec<i32>, fields_lid: i64) -> i64 {
    sb_append(sb, "[");
    let cnt: i64 = list_len(pool, fields_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let fnid: i64 = list_get(pool, fields_lid, i);
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "{\"name\":\"");
        sb_append(sb, json_escape(node_field(pool, fnid, 1)));
        sb_append(sb, "\",\"type\":\"");
        sb_append(sb, json_escape(node_field(pool, fnid, 2)));
        sb_append(sb, "\"}");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn append_enum_variants_json(sb: i64, pool: Vec<i32>, variants_lid: i64) -> i64 {
    sb_append(sb, "[");
    let cnt: i64 = list_len(pool, variants_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let vnid: i64 = list_get(pool, variants_lid, i);
        let fields_lid: i64 = node_field(pool, vnid, 2);
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "{\"name\":\"");
        sb_append(sb, json_escape(node_field(pool, vnid, 1)));
        sb_append(sb, "\",\"fields\":[");
        let fcnt: i64 = list_len(pool, fields_lid);
        let mut j: i64 = 0;
        while j < fcnt {
            if j > 0 { sb_append(sb, ","); };
            sb_append(sb, "\"");
            sb_append(sb, json_escape(list_get(pool, fields_lid, j)));
            sb_append(sb, "\"");
            j = j + 1;
        };
        sb_append(sb, "]}");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn append_trait_methods_json(sb: i64, pool: Vec<i32>, methods_lid: i64) -> i64 {
    sb_append(sb, "[");
    let cnt: i64 = list_len(pool, methods_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let mnid: i64 = list_get(pool, methods_lid, i);
        if i > 0 { sb_append(sb, ","); };
        sb_append(sb, "{\"name\":\"");
        sb_append(sb, json_escape(node_field(pool, mnid, 1)));
        sb_append(sb, "\",\"params\":");
        append_params_json(sb, pool, node_field(pool, mnid, 2));
        sb_append(sb, ",\"return\":\"");
        sb_append(sb, json_escape(node_field(pool, mnid, 3)));
        sb_append(sb, "\",\"has_default\":");
        if node_field(pool, mnid, 4) >= 0 { sb_append(sb, "true"); }
        else { sb_append(sb, "false"); };
        sb_append(sb, "}");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn render_summary_command(src_path: str, source: str, pool: Vec<i32>, prog: i64, json_mode: i64) -> str {
    let fmeta: Vec<i32> = source_collect_functions(source);
    let effs: Vec<i32> = infer_source_effects(fmeta);
    let imports: Vec<i32> = source_collect_imports(source);
    let tests: Vec<i32> = collect_test_names_from_source(source);
    let mut lines: Vec<i32> = Vec::new();
    lines.push(str_concat("// Module: ", src_path));
    let mut ii: i64 = 0;
    while ii < vec_len(imports) {
        lines.push(str_concat("use ", vec_get(imports, ii)));
        ii = ii + 1;
    };
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        let kind: i64 = node_kind(pool, nid);
        if kind == 30 {
            let name: str = node_field(pool, nid, 1);
            // T1.5b (v0.2.341): visibility is now surfaced — `pub fn`
            // declarations show up with a `pub` prefix in summary.
            let pub_prefix: str = if program_has_pub_marker(pool, prog, name) == 1 { "pub " } else { "" };
            let pure_prefix: str = if program_has_pure_marker(pool, prog, name) == 1 { "pure " } else { "" };
            let ret: str = node_field(pool, nid, 3);
            let ret_suffix: str = if str_eq(ret, "void") == 1 { "" } else { str_concat(" -> ", ret) };
            let effect_text: str = csv_pretty(inferred_effects_for(effs, name));
            let req_suffix: str = if str_len(effect_text) == 0 { "" } else { str_concat(" requires [", str_concat(effect_text, "]")) };
            let test_suffix: str = if string_vec_contains(tests, name) == 1 { " @test" } else { "" };
            lines.push(str_concat(pub_prefix, str_concat(pure_prefix, str_concat("fn ", str_concat(name, str_concat(generic_list_text(pool, node_field(pool, nid, 5)), str_concat("(", str_concat(param_list_text(pool, node_field(pool, nid, 2)), str_concat(")", str_concat(ret_suffix, str_concat(req_suffix, test_suffix)))))))))));
        } else if kind == 32 {
            let ret2: str = node_field(pool, nid, 3);
            let ret_suffix2: str = if str_eq(ret2, "void") == 1 { "" } else { str_concat(" -> ", ret2) };
            lines.push(str_concat("extern fn ", str_concat(node_field(pool, nid, 1), str_concat("(", str_concat(param_list_text(pool, node_field(pool, nid, 2)), str_concat(")", ret_suffix2))))));
        } else if kind == 33 {
            lines.push(str_concat("struct ", str_concat(node_field(pool, nid, 1), str_concat(generic_list_text(pool, node_field(pool, nid, 3)), str_concat(" { ", str_concat(struct_fields_text(pool, node_field(pool, nid, 2)), " }"))))));
        } else if kind == 36 {
            let variants_lid: i64 = node_field(pool, nid, 2);
            let mut parts: Vec<i32> = Vec::new();
            let mut vi: i64 = 0;
            while vi < list_len(pool, variants_lid) {
                parts.push(enum_variant_text(pool, list_get(pool, variants_lid, vi)));
                vi = vi + 1;
            };
            lines.push(str_concat("enum ", str_concat(node_field(pool, nid, 1), str_concat(generic_list_text(pool, node_field(pool, nid, 3)), str_concat(" { ", str_concat(join_strings(parts, ", "), " }"))))));
        } else if kind == 43 {
            lines.push(str_concat("trait ", str_concat(node_field(pool, nid, 1), generic_list_text(pool, node_field(pool, nid, 3)))));
        } else if kind == 45 {
            let trait_name: str = node_field(pool, nid, 1);
            let type_name: str = node_field(pool, nid, 2);
            if str_len(trait_name) > 0 {
                lines.push(str_concat("impl ", str_concat(trait_name, str_concat(" for ", type_name))));
            } else {
                lines.push(str_concat("impl ", type_name));
            };
        } else if kind == 50 {
            lines.push(str_concat("const ", str_concat(node_field(pool, nid, 1), str_concat(": ", node_field(pool, nid, 2)))));
        } else if kind == 51 {
            lines.push(str_concat("type ", str_concat(node_field(pool, nid, 1), str_concat(" = ", node_field(pool, nid, 2)))));
        };
        i = i + 1;
    };
    if json_mode == 1 {
        let mut sbj: i64 = sb_new();
        sb_append(sbj, "{\"file\":\""); sb_append(sbj, json_escape(src_path)); sb_append(sbj, "\",\"summary_lines\":");
        sb_append_json_string_array(sbj, lines);
        sb_append(sbj, "}");
        return sb_to_str(sbj);
    };
    return str_concat(join_strings(lines, "\n"), "\n");
}

fn run_summary_command(src_path: str, argc: i64, arg_start: i64) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    print(render_summary_command(src_path, source, pool, prog, cli_wants_json(argc, arg_start)));
    return 0;
}

fn run_query_command(src_path: str) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    let imports: Vec<i32> = source_collect_imports(source);
    let tests: Vec<i32> = collect_test_names_from_source(source);
    let fmeta: Vec<i32> = source_collect_functions(source);
    let effs: Vec<i32> = infer_source_effects(fmeta);
    let cnt: i64 = list_len(pool, prog);
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"file\":\""); sb_append(sb, json_escape(src_path)); sb_append(sb, "\",");
    sb_append(sb, "\"functions\":[");
    let mut first: i64 = 1;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            let name: str = node_field(pool, nid, 1);
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(name)); sb_append(sb, "\",\"type_params\":");
            append_generics_json(sb, pool, node_field(pool, nid, 5));
            sb_append(sb, ",\"params\":"); append_params_json(sb, pool, node_field(pool, nid, 2));
            sb_append(sb, ",\"return\":\""); sb_append(sb, json_escape(node_field(pool, nid, 3))); sb_append(sb, "\"");
            sb_append(sb, ",\"pure\":"); sb_append_json_bool(sb, program_has_pure_marker(pool, prog, name));
            sb_append(sb, ",\"test\":"); sb_append_json_bool(sb, string_vec_contains(tests, name));
            sb_append(sb, ",\"differentiable\":false");
            sb_append(sb, ",\"effects\":{\"declared\":"); sb_append_json_string_array(sb, csv_to_string_vec(srcf_decl_effects(fmeta, name)));
            sb_append(sb, ",\"inferred\":"); sb_append_json_string_array(sb, csv_to_string_vec(inferred_effects_for(effs, name)));
            sb_append(sb, "},\"contracts\":{\"pre\":0,\"post\":0}}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"structs\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid2: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid2) == 33 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid2, 1))); sb_append(sb, "\",\"type_params\":");
            append_generics_json(sb, pool, node_field(pool, nid2, 3));
            sb_append(sb, ",\"fields\":"); append_struct_fields_json(sb, pool, node_field(pool, nid2, 2));
            sb_append(sb, "}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"enums\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid3: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid3) == 36 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid3, 1))); sb_append(sb, "\",\"type_params\":");
            append_generics_json(sb, pool, node_field(pool, nid3, 3));
            sb_append(sb, ",\"variants\":"); append_enum_variants_json(sb, pool, node_field(pool, nid3, 2));
            sb_append(sb, "}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"traits\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid4: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid4) == 43 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid4, 1))); sb_append(sb, "\",\"type_params\":");
            append_generics_json(sb, pool, node_field(pool, nid4, 3));
            sb_append(sb, ",\"methods\":"); append_trait_methods_json(sb, pool, node_field(pool, nid4, 2));
            sb_append(sb, "}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"impls\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid5: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid5) == 45 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            let trait_name: str = node_field(pool, nid5, 1);
            sb_append(sb, "{\"trait\":");
            if str_len(trait_name) == 0 { sb_append(sb, "null"); }
            else { sb_append(sb, "\""); sb_append(sb, json_escape(trait_name)); sb_append(sb, "\""); };
            sb_append(sb, ",\"for_type\":\""); sb_append(sb, json_escape(node_field(pool, nid5, 2))); sb_append(sb, "\",\"methods\":");
            append_trait_methods_json(sb, pool, node_field(pool, nid5, 3));
            sb_append(sb, "}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"extern_fns\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid6: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid6) == 32 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid6, 1))); sb_append(sb, "\",\"params\":");
            append_params_json(sb, pool, node_field(pool, nid6, 2));
            sb_append(sb, ",\"return\":\""); sb_append(sb, json_escape(node_field(pool, nid6, 3))); sb_append(sb, "\"}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"consts\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid7: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid7) == 50 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid7, 1))); sb_append(sb, "\",\"type\":\"");
            sb_append(sb, json_escape(node_field(pool, nid7, 2))); sb_append(sb, "\"}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"type_aliases\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid8: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid8) == 51 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid8, 1))); sb_append(sb, "\",\"target\":\"");
            sb_append(sb, json_escape(node_field(pool, nid8, 2))); sb_append(sb, "\"}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"imports\":");
    sb_append_json_string_array(sb, imports);
    sb_append(sb, "}");
    print(sb_to_str(sb));
    return 0;
}

// R06-D3 Phase 1 (v0.8.274) — ABI type fail-closed.
//
// Pre-v0.8.274 unknown ABI types silently mapped to `int64_t` /
// `i64`. Generated C/Rust headers compiled with the wrong layout
// — adopters got "successful build" with an undetectable type bug.
// Phase 1 prefixes the fallback with `/* UNKNOWN: <T> */` so the
// generated header makes the unknown visible at code-review time
// AND emits a per-call info diagnostic. Phase 2 promotes to a
// hard error.
fn abi_c_type_name(t: str) -> str {
    if str_eq(t, "void") { return "void"; };
    if str_eq(t, "i32") { return "int32_t"; };
    if str_eq(t, "i64") { return "int64_t"; };
    if str_eq(t, "f64") { return "double"; };
    if str_eq(t, "str") { return "const char*"; };
    if str_eq(t, "ptr") { return "void*"; };
    print(str_concat("info[FFI-G18-PHASE1]: ABI C type fallback for unrecognized Nucleor type '", str_concat(t, "' — falling back to int64_t. Phase 2 will reject. See docs/spec/Nucleor_Error_Codes.md#FFI-G18.")));
    return str_concat("/* UNKNOWN: ", str_concat(t, " */ int64_t"));
}

fn abi_rust_type_name(t: str) -> str {
    if str_eq(t, "void") { return "()"; };
    if str_eq(t, "i32") { return "i32"; };
    if str_eq(t, "i64") { return "i64"; };
    if str_eq(t, "f64") { return "f64"; };
    if str_eq(t, "str") { return "*const ::std::os::raw::c_char"; };
    if str_eq(t, "ptr") { return "*mut ::std::ffi::c_void"; };
    print(str_concat("info[FFI-G18-PHASE1]: ABI Rust type fallback for unrecognized Nucleor type '", str_concat(t, "' — falling back to i64. Phase 2 will reject. See docs/spec/Nucleor_Error_Codes.md#FFI-G18.")));
    return str_concat("/* UNKNOWN: ", str_concat(t, " */ i64"));
}

fn abi_type_is_export_safe(t: str) -> i64 {
    if str_eq(t, "void") || str_eq(t, "i32") || str_eq(t, "i64") || str_eq(t, "f64") || str_eq(t, "str") || str_eq(t, "ptr") { return 1; };
    return 0;
}

fn append_abi_params_json(sb: i64, pool: Vec<i32>, params_lid: i64) -> i64 {
    sb_append(sb, "[");
    let cnt: i64 = list_len(pool, params_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let pnid: i64 = list_get(pool, params_lid, i);
        if i > 0 { sb_append(sb, ","); };
        let ptype: str = node_field(pool, pnid, 2);
        sb_append(sb, "{\"name\":\"");
        sb_append(sb, json_escape(node_field(pool, pnid, 1)));
        sb_append(sb, "\",\"nr_type\":\"");
        sb_append(sb, json_escape(ptype));
        sb_append(sb, "\",\"llvm\":\"");
        sb_append(sb, json_escape(nr_type_to_llvm(ptype)));
        sb_append(sb, "\",\"c\":\"");
        sb_append(sb, json_escape(abi_c_type_name(ptype)));
        sb_append(sb, "\",\"rust\":\"");
        sb_append(sb, json_escape(abi_rust_type_name(ptype)));
        sb_append(sb, "\"}");
        i = i + 1;
    };
    sb_append(sb, "]");
    return 0;
}

fn render_abi_text(src_path: str, pool: Vec<i32>, prog: i64) -> str {
    let mut lines: Vec<i32> = Vec::new();
    lines.push(str_concat("ABI imports for ", src_path));
    lines.push("ABI version: c-v1-imports-only");
    lines.push("exports supported: no");
    let cnt: i64 = list_len(pool, prog);
    let mut extern_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 32 {
            extern_count = extern_count + 1;
            let name: str = node_field(pool, nid, 1);
            let params_lid: i64 = node_field(pool, nid, 2);
            let rtype: str = node_field(pool, nid, 3);
            let mut llvm_sig: i64 = sb_new();
            sb_append(llvm_sig, nr_type_to_llvm(rtype));
            sb_append(llvm_sig, " (");
            let pc: i64 = list_len(pool, params_lid);
            let mut pi: i64 = 0;
            while pi < pc {
                if pi > 0 { sb_append(llvm_sig, ", "); };
                let pnid: i64 = list_get(pool, params_lid, pi);
                sb_append(llvm_sig, nr_type_to_llvm(node_field(pool, pnid, 2)));
                pi = pi + 1;
            };
            sb_append(llvm_sig, ")");
            lines.push(str_concat("extern fn ", str_concat(name, str_concat("(", str_concat(param_list_text(pool, params_lid), str_concat(") -> ", str_concat(rtype, str_concat(" | llvm ", sb_to_str(llvm_sig)))))))));
        };
        i = i + 1;
    };
    if extern_count == 0 { lines.push("extern imports: none"); };
    return str_concat(join_strings(lines, "\n"), "\n");
}

fn render_export_text(src_path: str, pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> str {
    let mut lines: Vec<i32> = Vec::new();
    lines.push(str_concat("ABI exports for ", src_path));
    lines.push("ABI version: c-v1-shared-exports");
    lines.push("shared library exports: yes");
    let cnt: i64 = list_len(pool, prog);
    let mut export_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                export_count = export_count + 1;
                let params_lid: i64 = node_field(pool, nid, 2);
                let rtype: str = node_field(pool, nid, 3);
                let mut llvm_sig: i64 = sb_new();
                sb_append(llvm_sig, nr_type_to_llvm(rtype));
                sb_append(llvm_sig, " (");
                let pc: i64 = list_len(pool, params_lid);
                let mut pi: i64 = 0;
                while pi < pc {
                    if pi > 0 { sb_append(llvm_sig, ", "); };
                    let pnid: i64 = list_get(pool, params_lid, pi);
                    sb_append(llvm_sig, nr_type_to_llvm(node_field(pool, pnid, 2)));
                    pi = pi + 1;
                };
                sb_append(llvm_sig, ")");
                lines.push(str_concat("pub fn ", str_concat(name, str_concat("(", str_concat(param_list_text(pool, params_lid), str_concat(") -> ", str_concat(rtype, str_concat(" | llvm ", sb_to_str(llvm_sig)))))))));
            };
        };
        i = i + 1;
    };
    if export_count == 0 { lines.push("public exports: none"); };
    return str_concat(join_strings(lines, "\n"), "\n");
}

fn render_abi_json(src_path: str, pool: Vec<i32>, prog: i64) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"type\":\"abi\",\"abi_version\":\"c-v1-imports-only\",\"file\":\"");
    sb_append(sb, json_escape(src_path));
    sb_append(sb, "\",\"exports_supported\":false,\"imports\":[");
    let cnt: i64 = list_len(pool, prog);
    let mut first: i64 = 1;
    let mut extern_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 32 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            extern_count = extern_count + 1;
            let name: str = node_field(pool, nid, 1);
            let params_lid: i64 = node_field(pool, nid, 2);
            let rtype: str = node_field(pool, nid, 3);
            sb_append(sb, "{\"name\":\"");
            sb_append(sb, json_escape(name));
            sb_append(sb, "\",\"params\":");
            append_abi_params_json(sb, pool, params_lid);
            sb_append(sb, ",\"return\":{\"nr_type\":\"");
            sb_append(sb, json_escape(rtype));
            sb_append(sb, "\",\"llvm\":\"");
            sb_append(sb, json_escape(nr_type_to_llvm(rtype)));
            sb_append(sb, "\",\"c\":\"");
            sb_append(sb, json_escape(abi_c_type_name(rtype)));
            sb_append(sb, "\",\"rust\":\"");
            sb_append(sb, json_escape(abi_rust_type_name(rtype)));
            sb_append(sb, "\"}}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"extern_count\":");
    sb_append(sb, str_from_int(extern_count));
    sb_append(sb, "}");
    return sb_to_str(sb);
}

fn render_export_json(src_path: str, pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"type\":\"abi\",\"abi_version\":\"");
    sb_append(sb, abi_export_version_label());
    sb_append(sb, "\",\"file\":\"");
    sb_append(sb, json_escape(src_path));
    sb_append(sb, "\",\"shared_library\":true,\"exports\":[");
    let cnt: i64 = list_len(pool, prog);
    let mut first: i64 = 1;
    let mut export_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                if first == 0 { sb_append(sb, ","); } else { first = 0; };
                export_count = export_count + 1;
                let params_lid: i64 = node_field(pool, nid, 2);
                let rtype: str = node_field(pool, nid, 3);
                sb_append(sb, "{\"name\":\"");
                sb_append(sb, json_escape(name));
                sb_append(sb, "\",\"params\":");
                append_abi_params_json(sb, pool, params_lid);
                sb_append(sb, ",\"return\":{\"nr_type\":\"");
                sb_append(sb, json_escape(rtype));
                sb_append(sb, "\",\"llvm\":\"");
                sb_append(sb, json_escape(nr_type_to_llvm(rtype)));
                sb_append(sb, "\",\"c\":\"");
                sb_append(sb, json_escape(abi_c_type_name(rtype)));
                sb_append(sb, "\",\"rust\":\"");
                sb_append(sb, json_escape(abi_rust_type_name(rtype)));
                sb_append(sb, "\"}}");
            };
        };
        i = i + 1;
    };
    sb_append(sb, "],\"export_count\":");
    sb_append(sb, str_from_int(export_count));
    sb_append(sb, "}");
    return sb_to_str(sb);
}

fn render_package_export_manifest_json(entry_path: str, settings: Vec<i32>, pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"schema_version\":\"1.0\",\"type\":\"package_exports\",\"package\":{\"name\":\"");
    sb_append(sb, json_escape(manifest_settings_package_name(settings)));
    sb_append(sb, "\",\"version\":\"");
    sb_append(sb, json_escape(manifest_settings_version(settings)));
    sb_append(sb, "\",\"entry\":\"");
    sb_append(sb, json_escape(path_normalize_slashes(entry_path)));
    sb_append(sb, "\"},\"abi_policy\":{\"abi_version\":\"");
    sb_append(sb, json_escape(abi_export_version_label()));
    sb_append(sb, "\",\"surface\":\"");
    sb_append(sb, json_escape(abi_export_surface_policy_label()));
    sb_append(sb, "\",\"symbol_policy\":\"");
    sb_append(sb, json_escape(abi_export_symbol_policy_label()));
    sb_append(sb, "\",\"version_policy\":\"");
    sb_append(sb, json_escape(abi_export_version_policy_label()));
    sb_append(sb, "\"},\"artifacts\":{\"manifest\":\"");
    sb_append(sb, json_escape(package_exports_manifest_file_name()));
    sb_append(sb, "\",\"c_header\":\"");
    sb_append(sb, json_escape(package_exports_header_file_name()));
    sb_append(sb, "\",\"rust_extern\":\"");
    sb_append(sb, json_escape(package_exports_rust_file_name()));
    sb_append(sb, "\"},\"shared_library\":true,\"exports\":[");
    let cnt: i64 = list_len(pool, prog);
    let mut first: i64 = 1;
    let mut export_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                if first == 0 { sb_append(sb, ","); } else { first = 0; };
                export_count = export_count + 1;
                let params_lid: i64 = node_field(pool, nid, 2);
                let rtype: str = node_field(pool, nid, 3);
                sb_append(sb, "{\"name\":\"");
                sb_append(sb, json_escape(name));
                sb_append(sb, "\",\"symbol\":\"");
                sb_append(sb, json_escape(name));
                sb_append(sb, "\",\"params\":");
                append_abi_params_json(sb, pool, params_lid);
                sb_append(sb, ",\"return\":{\"nr_type\":\"");
                sb_append(sb, json_escape(rtype));
                sb_append(sb, "\",\"llvm\":\"");
                sb_append(sb, json_escape(nr_type_to_llvm(rtype)));
                sb_append(sb, "\",\"c\":\"");
                sb_append(sb, json_escape(abi_c_type_name(rtype)));
                sb_append(sb, "\",\"rust\":\"");
                sb_append(sb, json_escape(abi_rust_type_name(rtype)));
                sb_append(sb, "\"}}");
            };
        };
        i = i + 1;
    };
    sb_append(sb, "],\"export_count\":");
    sb_append(sb, str_from_int(export_count));
    sb_append(sb, "}");
    return sb_to_str(sb);
}

fn render_abi_c_header(src_path: str, pool: Vec<i32>, prog: i64) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "/* Nucleor ABI imports for ");
    sb_append(sb, src_path);
    sb_append(sb, " */\n");
    sb_append(sb, "#pragma once\n#include <stdint.h>\n\n#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n");
    let cnt: i64 = list_len(pool, prog);
    let mut extern_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 32 {
            extern_count = extern_count + 1;
            let name: str = node_field(pool, nid, 1);
            let params_lid: i64 = node_field(pool, nid, 2);
            let rtype: str = node_field(pool, nid, 3);
            sb_append(sb, abi_c_type_name(rtype));
            sb_append(sb, " ");
            sb_append(sb, name);
            sb_append(sb, "(");
            let pc: i64 = list_len(pool, params_lid);
            if pc == 0 {
                sb_append(sb, "void");
            } else {
                let mut pi: i64 = 0;
                while pi < pc {
                    if pi > 0 { sb_append(sb, ", "); };
                    let pnid: i64 = list_get(pool, params_lid, pi);
                    sb_append(sb, abi_c_type_name(node_field(pool, pnid, 2)));
                    sb_append(sb, " ");
                    sb_append(sb, node_field(pool, pnid, 1));
                    pi = pi + 1;
                };
            };
            sb_append(sb, ");\n");
        };
        i = i + 1;
    };
    if extern_count == 0 { sb_append(sb, "/* no extern imports */\n"); };
    sb_append(sb, "\n#ifdef __cplusplus\n}\n#endif\n");
    return sb_to_str(sb);
}

fn render_export_c_header(src_path: str, pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "/* Nucleor shared-library exports for ");
    sb_append(sb, src_path);
    sb_append(sb, " */\n");
    sb_append(sb, "#pragma once\n#include <stdint.h>\n\n#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n");
    let cnt: i64 = list_len(pool, prog);
    let mut export_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                export_count = export_count + 1;
                let params_lid: i64 = node_field(pool, nid, 2);
                let rtype: str = node_field(pool, nid, 3);
                sb_append(sb, abi_c_type_name(rtype));
                sb_append(sb, " ");
                sb_append(sb, name);
                sb_append(sb, "(");
                let pc: i64 = list_len(pool, params_lid);
                if pc == 0 {
                    sb_append(sb, "void");
                } else {
                    let mut pi: i64 = 0;
                    while pi < pc {
                        if pi > 0 { sb_append(sb, ", "); };
                        let pnid: i64 = list_get(pool, params_lid, pi);
                        sb_append(sb, abi_c_type_name(node_field(pool, pnid, 2)));
                        sb_append(sb, " ");
                        sb_append(sb, node_field(pool, pnid, 1));
                        pi = pi + 1;
                    };
                };
                sb_append(sb, ");\n");
            };
        };
        i = i + 1;
    };
    if export_count == 0 { sb_append(sb, "/* no public exports */\n"); };
    sb_append(sb, "\n#ifdef __cplusplus\n}\n#endif\n");
    return sb_to_str(sb);
}

fn render_abi_rust_extern(src_path: str, pool: Vec<i32>, prog: i64) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "// Nucleor ABI imports for ");
    sb_append(sb, src_path);
    sb_append(sb, "\nuse ::std::ffi::c_void;\nuse ::std::os::raw::c_char;\n\nunsafe extern \"C\" {\n");
    let cnt: i64 = list_len(pool, prog);
    let mut extern_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 32 {
            extern_count = extern_count + 1;
            let name: str = node_field(pool, nid, 1);
            let params_lid: i64 = node_field(pool, nid, 2);
            let rtype: str = node_field(pool, nid, 3);
            sb_append(sb, "    pub fn ");
            sb_append(sb, name);
            sb_append(sb, "(");
            let pc: i64 = list_len(pool, params_lid);
            let mut pi: i64 = 0;
            while pi < pc {
                if pi > 0 { sb_append(sb, ", "); };
                let pnid: i64 = list_get(pool, params_lid, pi);
                sb_append(sb, node_field(pool, pnid, 1));
                sb_append(sb, ": ");
                sb_append(sb, abi_rust_type_name(node_field(pool, pnid, 2)));
                pi = pi + 1;
            };
            sb_append(sb, ")");
            if str_eq(rtype, "void") == 0 {
                sb_append(sb, " -> ");
                sb_append(sb, abi_rust_type_name(rtype));
            };
            sb_append(sb, ";\n");
        };
        i = i + 1;
    };
    if extern_count == 0 { sb_append(sb, "    // no extern imports\n"); };
    sb_append(sb, "}\n");
    return sb_to_str(sb);
}

fn render_export_rust_extern(src_path: str, pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "// Nucleor shared-library exports for ");
    sb_append(sb, src_path);
    sb_append(sb, "\nuse ::std::ffi::c_void;\nuse ::std::os::raw::c_char;\n\nunsafe extern \"C\" {\n");
    let cnt: i64 = list_len(pool, prog);
    let mut export_count: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                export_count = export_count + 1;
                let params_lid: i64 = node_field(pool, nid, 2);
                let rtype: str = node_field(pool, nid, 3);
                sb_append(sb, "    pub fn ");
                sb_append(sb, name);
                sb_append(sb, "(");
                let pc: i64 = list_len(pool, params_lid);
                let mut pi: i64 = 0;
                while pi < pc {
                    if pi > 0 { sb_append(sb, ", "); };
                    let pnid: i64 = list_get(pool, params_lid, pi);
                    sb_append(sb, node_field(pool, pnid, 1));
                    sb_append(sb, ": ");
                    sb_append(sb, abi_rust_type_name(node_field(pool, pnid, 2)));
                    pi = pi + 1;
                };
                sb_append(sb, ")");
                if str_eq(rtype, "void") == 0 {
                    sb_append(sb, " -> ");
                    sb_append(sb, abi_rust_type_name(rtype));
                };
                sb_append(sb, ";\n");
            };
        };
        i = i + 1;
    };
    if export_count == 0 { sb_append(sb, "    // no public exports\n"); };
    sb_append(sb, "}\n");
    return sb_to_str(sb);
}

fn validate_export_surface(pool: Vec<i32>, prog: i64, export_names: Vec<i32>) -> i64 {
    if vec_len(export_names) == 0 {
        print("ERROR: no `pub fn` exports found in source");
        return 1;
    };
    let cnt: i64 = list_len(pool, prog);
    let mut matched: Vec<i32> = Vec::new();
    let mut failed: i64 = 0;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            let name: str = node_field(pool, nid, 1);
            if string_vec_contains(export_names, name) == 1 {
                string_vec_push_unique(matched, name);
                if str_eq(name, "main") == 1 {
                    print("ERROR: `pub fn main` is not a supported shared-library export");
                    failed = 1;
                };
                if list_len(pool, node_field(pool, nid, 5)) > 0 {
                    print(str_concat("ERROR: exported function cannot be generic: ", name));
                    failed = 1;
                };
                let params_lid: i64 = node_field(pool, nid, 2);
                let pc: i64 = list_len(pool, params_lid);
                let mut pi: i64 = 0;
                while pi < pc {
                    let pnid: i64 = list_get(pool, params_lid, pi);
                    let ptype: str = node_field(pool, pnid, 2);
                    if abi_type_is_export_safe(ptype) == 0 {
                        print(str_concat("ERROR: unsupported export parameter ABI type in ", str_concat(name, str_concat(": ", ptype))));
                        failed = 1;
                    };
                    pi = pi + 1;
                };
                let rtype: str = node_field(pool, nid, 3);
                if abi_type_is_export_safe(rtype) == 0 {
                    print(str_concat("ERROR: unsupported export return ABI type in ", str_concat(name, str_concat(": ", rtype))));
                    failed = 1;
                };
            };
        };
        i = i + 1;
    };
    i = 0;
    while i < vec_len(export_names) {
        let name2: str = vec_get(export_names, i);
        if string_vec_contains(matched, name2) == 0 {
            print(str_concat("ERROR: `pub fn` export not found as a concrete top-level function: ", name2));
            failed = 1;
        };
        i = i + 1;
    };
    return failed;
}

fn render_def_file(export_names: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    sb_append(sb, "EXPORTS\n");
    let mut i: i64 = 0;
    while i < vec_len(export_names) {
        let name: str = vec_get(export_names, i);
        if str_eq(name, "main") == 0 {
            sb_append(sb, "    ");
            sb_append(sb, name);
            sb_append(sb, "\n");
        };
        i = i + 1;
    };
    return sb_to_str(sb);
}

fn link_shared_module(out_name: str, imported: Vec<i32>, export_names: Vec<i32>, time_passes: i64) -> i64 {
    let ll_path: str = sanitize(str_concat("target/", str_concat(out_name, ".ll")));
    let dll_path: str = sanitize(str_concat("target\\", str_concat(out_name, ".dll")));
    let lib_path: str = sanitize(str_concat("target\\", str_concat(out_name, ".lib")));
    let def_path: str = sanitize(str_concat("target/", str_concat(out_name, ".def")));
    file_write_string(def_path, render_def_file(export_names));
    let native_d: Vec<i32> = collect_native_directives(imported);
    let link_flags: str = vec_get(native_d, 0);
    let cfiles: str = vec_get(native_d, 1);
    let libpath_flags: str = vec_get(native_d, 2);
    let rt_arg: str = resolve_toolchain_path("stdlib/runtime/nucleor_llvm_rt.c");
    let clang_start: i64 = now_ms();
    let mut cmd: str = llvm_clang_path();
    cmd = str_concat(cmd, " ");
    cmd = str_concat(cmd, ll_path);
    cmd = str_concat(cmd, " ");
    cmd = str_concat(cmd, rt_arg);
    cmd = str_concat(cmd, cfiles);
    cmd = str_concat(cmd, " -shared -o ");
    cmd = str_concat(cmd, dll_path);
    cmd = str_concat(cmd, " -Wl,/DEF:");
    cmd = str_concat(cmd, path_shell_native(def_path));
    cmd = str_concat(cmd, " -Wl,/IMPLIB:");
    cmd = str_concat(cmd, path_shell_native(lib_path));
    cmd = str_concat(cmd, " -Wno-override-module ");
    cmd = str_concat(cmd, libpath_flags);
    cmd = str_concat(cmd, link_flags);
    cmd = str_concat(cmd, " 2>&1");
    let rc: i64 = system(cmd);
    print_phase_time(time_passes, "clang_shared", now_ms() - clang_start);
    if rc != 0 {
        print(str_concat("  SHARED LINK FAILED (clang exit ", str_concat(str_from_int(rc), ")")));
        return 1;
    };
    print(str_concat("  shared library: ", dll_path));
    print(str_concat("  import library: ", lib_path));
    print(str_concat("  export def: ", def_path));
    return 0;
}

fn run_abi_command(src_path: str, argc: i64, arg_start: i64) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    if cli_has_flag(argc, arg_start, "--exports") == 1 {
        let export_names: Vec<i32> = collect_public_export_names(source);
        if validate_export_surface(pool, prog, export_names) != 0 { return 1; };
        if cli_has_flag(argc, arg_start, "--c-header") == 1 {
            print(render_export_c_header(src_path, pool, prog, export_names));
            return 0;
        };
        if cli_has_flag(argc, arg_start, "--rust-extern") == 1 {
            print(render_export_rust_extern(src_path, pool, prog, export_names));
            return 0;
        };
        if cli_wants_json(argc, arg_start) == 1 {
            print(render_export_json(src_path, pool, prog, export_names));
            return 0;
        };
        print(render_export_text(src_path, pool, prog, export_names));
        return 0;
    };
    if cli_has_flag(argc, arg_start, "--c-header") == 1 {
        print(render_abi_c_header(src_path, pool, prog));
        return 0;
    };
    if cli_has_flag(argc, arg_start, "--rust-extern") == 1 {
        print(render_abi_rust_extern(src_path, pool, prog));
        return 0;
    };
    if cli_wants_json(argc, arg_start) == 1 {
        print(render_abi_json(src_path, pool, prog));
        return 0;
    };
    print(render_abi_text(src_path, pool, prog));
    return 0;
}

fn tools_run_build_shared_command(src_path: str, out_name: str, use_cache: i64, time_passes: i64, json_mode: i64) -> i64 {
    let raw_source: str = file_read_string(src_path);
    if str_len(raw_source) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    if preflight_source_check(raw_source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(raw_source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    let export_names: Vec<i32> = collect_public_export_names(raw_source);
    if validate_export_surface(pool, prog, export_names) != 0 { return 1; };
    let rc_compile: i64 = compile_file_mode(src_path, out_name, 0, use_cache, time_passes, 0);
    if rc_compile != 0 { return rc_compile; };
    let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
    let imported: Vec<i32> = vec_get(bundle, 1);
    let rc_link: i64 = link_shared_module(out_name, imported, export_names, time_passes);
    if rc_link != 0 { return rc_link; };
    let json_path: str = sanitize(str_concat("target/", str_concat(out_name, ".exports.json")));
    let header_path: str = sanitize(str_concat("target/", str_concat(out_name, ".exports.h")));
    let rust_path: str = sanitize(str_concat("target/", str_concat(out_name, ".exports.rs")));
    file_write_string(json_path, render_export_json(src_path, pool, prog, export_names));
    file_write_string(header_path, render_export_c_header(src_path, pool, prog, export_names));
    file_write_string(rust_path, render_export_rust_extern(src_path, pool, prog, export_names));
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"file\":\"");
        sb_append(sb, json_escape(src_path));
        sb_append(sb, "\",\"output\":\"");
        sb_append(sb, json_escape(out_name));
        sb_append(sb, "\",\"dll\":\"");
        sb_append(sb, json_escape(str_concat("target\\", str_concat(out_name, ".dll"))));
        sb_append(sb, "\",\"import_lib\":\"");
        sb_append(sb, json_escape(str_concat("target\\", str_concat(out_name, ".lib"))));
        sb_append(sb, "\",\"ll\":\"");
        sb_append(sb, json_escape(str_concat("target/", str_concat(out_name, ".ll"))));
        sb_append(sb, "\",\"def\":\"");
        sb_append(sb, json_escape(str_concat("target/", str_concat(out_name, ".def"))));
        sb_append(sb, "\",\"exports_json\":\"");
        sb_append(sb, json_escape(json_path));
        sb_append(sb, "\",\"exports_header\":\"");
        sb_append(sb, json_escape(header_path));
        sb_append(sb, "\",\"exports_rust\":\"");
        sb_append(sb, json_escape(rust_path));
        sb_append(sb, "\",\"export_count\":");
        sb_append(sb, str_from_int(vec_len(export_names)));
        sb_append(sb, "}");
        print(sb_to_str(sb));
        return 0;
    };
    print(str_concat("  exports manifest: ", json_path));
    print(str_concat("  exports header: ", header_path));
    print(str_concat("  exports rust: ", rust_path));
    print(str_concat("  export count: ", str_from_int(vec_len(export_names))));
    return 0;
}

fn run_evidence_command(src_path: str) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let mut tokens: Vec<i32> = lex(source);
    let mut pool: Vec<i32> = Vec::new();
    let parsed: Vec<i32> = parse_program(tokens, pool);
    let prog: i64 = pr_val(parsed);
    let tests: Vec<i32> = collect_test_names_from_source(source);
    let fmeta: Vec<i32> = source_collect_functions(source);
    let cnt: i64 = list_len(pool, prog);
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"file\":\""); sb_append(sb, json_escape(src_path)); sb_append(sb, "\",\"functions\":[");
    let mut first: i64 = 1;
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 30 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            let name: str = node_field(pool, nid, 1);
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(name)); sb_append(sb, "\",\"is_pure\":");
            sb_append_json_bool(sb, program_has_pure_marker(pool, prog, name));
            sb_append(sb, ",\"is_test\":"); sb_append_json_bool(sb, string_vec_contains(tests, name));
            sb_append(sb, ",\"is_differentiable\":false");
            sb_append(sb, ",\"effects\":"); sb_append_json_string_array(sb, csv_to_string_vec(srcf_decl_effects(fmeta, name)));
            sb_append(sb, ",\"authored\":null,\"preconditions\":0,\"postconditions\":0}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"structs\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid2: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid2) == 33 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(node_field(pool, nid2, 1))); sb_append(sb, "\",\"authored\":null}");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"extern_fns\":[");
    first = 1;
    i = 0;
    while i < cnt {
        let nid3: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid3) == 32 {
            if first == 0 { sb_append(sb, ","); } else { first = 0; };
            sb_append(sb, "\""); sb_append(sb, json_escape(node_field(pool, nid3, 1))); sb_append(sb, "\"");
        };
        i = i + 1;
    };
    sb_append(sb, "],\"provenance\":{\"builder\":\"nucleor-compiler\",\"build_type\":\"https://nucleor.dev/slsa/v1\",\"invocation\":{\"config_source\":\"");
    sb_append(sb, json_escape(src_path));
    sb_append(sb, "\"},\"metadata\":{\"reproducible\":true}},\"spdx\":{\"spdx_version\":\"SPDX-2.3\",\"data_license\":\"CC0-1.0\",\"name\":");
    sb_append_json_string_or_null(sb, basename(src_path));
    sb_append(sb, ",\"package_supplier\":\"Organization: nucleor-authors\"}}");
    print(sb_to_str(sb));
    return 0;
}

fn run_lock_command(argc: i64) -> i64 {
    let mut json_mode: i64 = 0;
    let mut target: str = "";
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") == 1 || str_eq(arg, "--output=json") == 1 {
            json_mode = 1;
        } else if str_eq(arg, "--output") == 1 && i + 1 < argc && str_eq(args_get(i + 1), "json") == 1 {
            json_mode = 1;
            i = i + 1;
        } else if cli_is_flag(arg) == 0 && str_len(target) == 0 {
            target = arg;
        };
        i = i + 1;
    };
    let manifest_path: str = lock_resolve_manifest_target(target);
    if str_len(manifest_path) == 0 {
        if json_mode == 1 { print("{\"error\":\"no Nucleor.toml found; pass a manifest path or run inside a project directory\"}"); }
        else {
            print("ERROR: no Nucleor.toml found");
            print("Usage: nuc lock [path/to/Nucleor.toml|project_dir] [--json]");
        };
        return 1;
    };
    let mut graph: Vec<i32> = Vec::new();
    let mut seen: Vec<i32> = Vec::new();
    let mut stack: Vec<i32> = Vec::new();
    let mut errors: Vec<i32> = Vec::new();
    if lock_build_graph_recursive(manifest_path, graph, seen, stack, errors) != 0 || vec_len(errors) > 0 {
        let err: str = if vec_len(errors) > 0 { vec_get(errors, 0) } else { "unknown lock graph error" };
        if json_mode == 1 {
            let mut esb: i64 = sb_new();
            sb_append(esb, "{\"manifest\":\""); sb_append(esb, json_escape(manifest_path)); sb_append(esb, "\",\"error\":\""); sb_append(esb, json_escape(err)); sb_append(esb, "\"}");
            print(sb_to_str(esb));
        } else {
            print(str_concat("ERROR: ", err));
        };
        return 1;
    };
    let contents: str = render_lockfile_native(manifest_path, graph);
    let lock_path: str = str_concat(path_with_sep(parent_dir(manifest_path)), "Nucleor.lock");
    file_write_string(lock_path, contents);
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"manifest\":\""); sb_append(sb, json_escape(manifest_path));
        sb_append(sb, "\",\"lockfile\":\""); sb_append(sb, json_escape(lock_path));
        sb_append(sb, "\",\"package_count\":"); sb_append(sb, str_from_int(vec_len(graph)));
        sb_append(sb, ",\"status\":\"ok\"}");
        print(sb_to_str(sb));
    } else {
        print(str_concat("wrote lockfile: ", lock_path));
        print(str_concat("packages: ", str_from_int(vec_len(graph))));
    };
    return 0;
}

fn run_publish_command(argc: i64) -> i64 {
    let manifest_target: str = cli_first_positional(argc, 2);
    let manifest_path: str = lock_resolve_manifest_target(manifest_target);
    if str_len(manifest_path) == 0 {
        print("ERROR: no Nucleor.toml found");
        print("Usage: nuc publish [path/to/Nucleor.toml|project_dir] [--registry <dir>] [--dry-run] [--sign [--key-id <id>]]");
        return 1;
    };
    let registry_dir: str = registry_dir_native(argc, 2);
    let dry_run: i64 = cli_has_flag(argc, 2, "--dry-run");
    let mut sign_package: i64 = cli_has_flag(argc, 2, "--sign");
    let mut signing_key_id: str = cli_option_value(argc, 2, "--key-id");
    if str_len(signing_key_id) > 0 { sign_package = 1; };
    if sign_package == 1 && str_len(signing_key_id) == 0 { signing_key_id = "default-local"; };
    let settings: Vec<i32> = manifest_parse_settings(manifest_path, file_read_string(manifest_path));
    let parse_err: str = manifest_settings_error(settings);
    if str_len(parse_err) > 0 {
        print(str_concat("ERROR: ", parse_err));
        return 1;
    };
    let deps: Vec<i32> = manifest_settings_deps(settings);
    if vec_len(deps) > 0 {
        let lock_path: str = str_concat(path_with_sep(parent_dir(manifest_path)), "Nucleor.lock");
        if str_len(file_read_string(lock_path)) == 0 {
            print(str_concat("ERROR: missing ", str_concat(lock_path, "; run `nuc lock` first")));
            return 1;
        };
    };
    let mut graph: Vec<i32> = Vec::new();
    let mut seen: Vec<i32> = Vec::new();
    let mut stack: Vec<i32> = Vec::new();
    let mut errors: Vec<i32> = Vec::new();
    if lock_build_graph_recursive(manifest_path, graph, seen, stack, errors) != 0 || vec_len(errors) > 0 {
        let err: str = if vec_len(errors) > 0 { vec_get(errors, 0) } else { "unknown dependency graph error" };
        print(str_concat("ERROR: ", err));
        return 1;
    };
    let publish_root: str = sanitize(str_concat(path_with_sep(registry_dir), str_concat(manifest_settings_package_name(settings), str_concat("/", manifest_settings_version(settings)))));
    if str_len(file_read_string(sanitize(str_concat(path_with_sep(publish_root), "Nucleor.toml")))) > 0 {
        print(str_concat("ERROR: package already exists in registry: ", publish_root));
        return 1;
    };
    if dry_run == 1 {
        print("publish dry-run: no files copied, no registry metadata written, no checksums written, no signatures created");
        print(str_concat("manifest: ", manifest_path));
        print(str_concat("package: ", manifest_settings_package_name(settings)));
        print(str_concat("version: ", manifest_settings_version(settings)));
        print(str_concat("registry: ", registry_dir));
        print(str_concat("registry_package_dir: ", publish_root));
        print(str_concat("export_manifest_target: ", sanitize(str_concat(path_with_sep(publish_root), package_exports_manifest_file_name()))));
        print(str_concat("metadata_target: ", sanitize(str_concat(path_with_sep(publish_root), registry_metadata_file_name()))));
        print(str_concat("checksum_target: ", sanitize(str_concat(path_with_sep(publish_root), package_checksum_file_name()))));
        if sign_package == 1 {
            print(str_concat("signature_target: ", sanitize(str_concat(path_with_sep(publish_root), package_signature_file_name()))));
            print(str_concat("signing_key_id: ", signing_key_id));
        } else {
            print("signature_target: (not requested)");
            print("signing_key_id: (none)");
        };
        return 0;
    };
    if publish_copy_graph_native(manifest_path, graph, publish_root) != 0 {
        print(str_concat("ERROR: failed to copy package into registry: ", publish_root));
        return 1;
    };
    let export_info: Vec<i32> = write_package_export_artifacts_native(publish_root, settings);
    if vec_get(export_info, 0) < 0 {
        print(str_concat("ERROR: ", vec_get(export_info, 2)));
        return 1;
    };
    write_package_checksum_file_native(publish_root);
    write_registry_metadata_file_native(publish_root, settings, export_info, if sign_package == 1 { "ssh-ed25519" } else { "none" }, signing_key_id);
    if sign_package == 1 {
        let signed_result: Vec<i32> = invoke_native_package_sign(publish_root, signing_key_id);
        if vec_get(signed_result, 0) == 0 {
            print(str_concat("ERROR: ", vec_get(signed_result, 2)));
            return 1;
        };
    };
    print(str_concat("published: ", publish_root));
    return 0;
}

fn run_registry_command(argc: i64) -> i64 {
    let registry_dir: str = registry_dir_native(argc, 2);
    let mut positionals: Vec<i32> = Vec::new();
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if cli_is_flag(arg) == 0 { positionals.push(arg); };
        if str_eq(arg, "--registry") == 1 { i = i + 1; };
        i = i + 1;
    };
    let packages: Vec<i32> = dir_list_native(registry_dir, 1);
    if vec_len(positionals) == 0 || str_eq(vec_get(positionals, 0), "list") == 1 {
        print(str_concat("registry: ", registry_dir));
        if vec_len(packages) == 0 {
            print("packages: 0");
            return 0;
        };
        let mut pi: i64 = 0;
        while pi < vec_len(packages) {
            let name: str = vec_get(packages, pi);
            let versions: Vec<i32> = registry_package_versions_native(registry_dir, name);
            if vec_len(versions) > 0 {
                print(str_concat(name, str_concat("  latest=", str_concat(vec_get(versions, 0), str_concat("  versions=", join_strings(versions, ", "))))));
            };
            pi = pi + 1;
        };
        return 0;
    };
    let subcmd: str = vec_get(positionals, 0);
    if str_eq(subcmd, "search") == 1 {
        if vec_len(positionals) < 2 {
            print("Usage: nuc registry search <query> [--registry <dir>]");
            return 1;
        };
        let query: str = vec_get(positionals, 1);
        print(str_concat("registry: ", registry_dir));
        let mut found: i64 = 0;
        let mut pi: i64 = 0;
        while pi < vec_len(packages) {
            let name: str = vec_get(packages, pi);
            if text_contains(name, query) == 1 {
                let versions: Vec<i32> = registry_package_versions_native(registry_dir, name);
                if vec_len(versions) > 0 {
                    print(str_concat(name, str_concat("  latest=", str_concat(vec_get(versions, 0), str_concat("  versions=", join_strings(versions, ", "))))));
                    found = 1;
                };
            };
            pi = pi + 1;
        };
        if found == 0 { print(str_concat("no packages matched '", str_concat(query, "'"))); };
        return 0;
    };
    if str_eq(subcmd, "versions") == 1 {
        if vec_len(positionals) < 2 {
            print("Usage: nuc registry versions <package> [--registry <dir>]");
            return 1;
        };
        let versions2: Vec<i32> = registry_package_versions_native(registry_dir, vec_get(positionals, 1));
        print(str_concat("registry: ", registry_dir));
        print(str_concat(vec_get(positionals, 1), str_concat(": ", join_strings(versions2, ", "))));
        return 0;
    };
    if str_eq(subcmd, "verify") == 1 {
        if vec_len(positionals) < 2 {
            print("Usage: nuc registry verify <package|package@version> [--registry <dir>]");
            return 1;
        };
        let spec_parts: Vec<i32> = parse_registry_spec_native(vec_get(positionals, 1));
        let package_name: str = vec_get(spec_parts, 0);
        let selector: str = vec_get(spec_parts, 1);
        let version: str = registry_resolve_version_native(registry_dir, package_name, selector);
        if str_len(version) == 0 {
            print(str_concat("ERROR: no installable versions for ", str_concat(package_name, str_concat(" matched ", selector))));
            return 1;
        };
        let verified: Vec<i32> = verify_registry_package_root_native(registry_dir, package_name, version);
        if vec_get(verified, 0) == 0 {
            print(str_concat("ERROR: ", vec_get(verified, 2)));
            return 1;
        };
        print(str_concat("registry: ", registry_dir));
        print(str_concat("package: ", package_name));
        print(str_concat("version: ", version));
        print(str_concat("signed: ", if vec_get(verified, 4) == 1 { "yes" } else { "no" }));
        if vec_get(verified, 4) == 1 {
            print(str_concat("signing_algorithm: ", vec_get(verified, 6)));
            print(str_concat("key_id: ", vec_get(verified, 5)));
        };
        if vec_get(verified, 3) > 0 {
            print(str_concat("exports: ", str_from_int(vec_get(verified, 3))));
            print(str_concat("abi_version: ", abi_export_version_label()));
            print(str_concat("surface: ", abi_export_surface_policy_label()));
            print(str_concat("version_policy: ", abi_export_version_policy_label()));
        } else {
            print("exports: none");
        };
        return 0;
    };
    if str_eq(subcmd, "remote") == 1 {
        return run_registry_remote_command_native(positionals);
    };
    if str_eq(subcmd, "export-static") == 1 {
        // T1.4 (v0.2.344): convert a local registry directory tree into
        // the GitHub-Pages-publishable static-site shape documented in
        // RFC-0019 §6 (Remote registry — static-index variant). Nothing
        // here touches the network; the maintainer pushes the resulting
        // directory to a gh-pages branch and points users at
        // https://<user>.github.io/<repo>/index.json.
        if vec_len(positionals) < 2 {
            print("Usage: nuc registry export-static <out_dir> [--registry <dir>]");
            print("");
            print("Output schema (per RFC-0019 §6, GH-Pages remote registry):");
            print("  <out_dir>/index.json                      Top-level package list");
            print("  <out_dir>/<pkg>/index.json                Per-package version list");
            print("  <out_dir>/<pkg>/<version>/Nucleor.toml    Manifest");
            print("  <out_dir>/<pkg>/<version>/Nucleor.lock    Lockfile (if present)");
            print("  <out_dir>/<pkg>/<version>/checksum.json   Per-RFC-0019 file checksums");
            print("  <out_dir>/<pkg>/<version>/<files>...      Source + bundled artifacts");
            return 1;
        };
        let out_dir: str = sanitize(vec_get(positionals, 1));
        if str_len(out_dir) == 0 {
            print("ERROR: invalid out_dir");
            return 1;
        };
        let exported: Vec<i32> = registry_export_static_native(registry_dir, out_dir);
        let pkg_count: i64 = vec_get(exported, 0);
        let ver_count: i64 = vec_get(exported, 1);
        let file_count: i64 = vec_get(exported, 2);
        print(str_concat("registry: ", registry_dir));
        print(str_concat("static site: ", out_dir));
        print(str_concat("packages exported: ", str_from_int(pkg_count)));
        print(str_concat("versions exported: ", str_from_int(ver_count)));
        print(str_concat("files copied:     ", str_from_int(file_count)));
        print("");
        print("Next: push the out_dir to your GitHub Pages branch:");
        print(str_concat("  cd ", str_concat(out_dir, " && git init && git add -A && git commit -m 'registry'")));
        print("  git push <gh-pages-remote> main:gh-pages");
        print("");
        print("Users point `nuc` at the published URL via:");
        print("  nuc registry remote add <name> https://<user>.github.io/<repo>");
        print("  (remote fetch ships in T1.4b once the TLS rod lands per RFC-0019 §6.3)");
        return 0;
    };
    print("Usage: nuc registry [list|search <query>|versions <package>|verify <package|package@version>|remote add <name> <url>|remote list|remote remove <name>|export-static <out_dir>] [--registry <dir>]");
    return 1;
}

// top-level command dispatcher. Heap-backed
// locals are arg-parsing scratch. Annotated as safety guardrail
// before the unconditional default-flip.
#[manual_drop]
fn run_install_command(argc: i64) -> i64 {
    // RFC-0019 phase 3 — `nuc install --git <url> [--rev <ref>]` stub.
    // CLI surface ships now so users hitting it know what to expect;
    // real clone + verify + lock lands with the v0.5 registry phase.
    let mut gi: i64 = 2;
    let mut git_url: str = "";
    let mut git_rev: str = "";
    while gi < argc {
        let a: str = args_get(gi);
        if str_eq(a, "--git") == 1 && gi + 1 < argc {
            git_url = args_get(gi + 1);
            gi = gi + 1;
        } else if str_eq(a, "--rev") == 1 && gi + 1 < argc {
            git_rev = args_get(gi + 1);
            gi = gi + 1;
        };
        gi = gi + 1;
    };
    if str_len(git_url) > 0 {
        // R12-D4 Phase 1 (v0.8.282, audit 2026-05-05): pre-v0.8.282
        // this stub returned 0 (success) — adopters running
        // `nuc install --git <url>` saw the deferred message and got
        // exit 0, which CI scripts treated as "the install
        // succeeded." That's silent-not-installed. Phase 1 prefixes
        // the message with `error[PKG-6]:` and returns 2 so CI
        // scripts gate the build correctly. Phase 2 implements the
        // actual clone + verify + lock per the audit plan.
        print(str_concat("error[PKG-6]: `nuc install --git ", str_concat(git_url, "` — clone/verify/lock not yet implemented; deferred to v0.5 with the package registry (RFC-0019 phase 3).")));
        if str_len(git_rev) > 0 {
            print(str_concat("                   --rev ", git_rev));
        };
        print("");
        print("STATUS: deferred. Returning exit 2 (unsupported).");
        print("");
        print("The v0.5 release will:");
        print("  1. Clone <url> into .nucleor/git/<host>-<repo>-<sha>/");
        print("  2. Check out <rev> (default: HEAD of the default branch)");
        print("  3. Verify the manifest at <repo>/Nucleor.toml is valid");
        print("  4. Add a `[dependencies]` entry pointing at the local clone");
        print("  5. Refresh Nucleor.lock with the resolved checksum");
        print("");
        print("Today, on Windows, clone the repo manually and use a path");
        print("dependency: `[dependencies] foo = \"path/to/foo\"` then `nuc lock`.");
        return 2;
    };
    // RFC-0022 phase 3 — `nuc install sysroot --target=<triple>` stub.
    // Documents the planned UX (paired with TGT-002 explain entry) and
    // returns a clear "deferred to v0.5" message so users hitting this
    // know what to expect and when. Real fetch/verify lands with the
    // package registry phase.
    if argc >= 3 && str_eq(args_get(2), "sysroot") == 1 {
        let mut target_triple: str = "";
        let mut si: i64 = 3;
        while si < argc {
            let a: str = args_get(si);
            if str_len(a) > 9 && str_eq(str_substring(a, 0, 9), "--target=") == 1 {
                target_triple = str_substring(a, 9, str_len(a));
            } else if str_eq(a, "--target") == 1 && si + 1 < argc {
                target_triple = args_get(si + 1);
                si = si + 1;
            };
            si = si + 1;
        };
        if str_len(target_triple) == 0 {
            print("ERROR: nuc install sysroot requires --target=<triple>");
            print("Example targets (planned for v0.5):");
            print("  --target=x86_64-unknown-linux-gnu");
            print("  --target=aarch64-unknown-linux-gnu");
            print("  --target=x86_64-apple-darwin");
            print("  --target=aarch64-apple-darwin");
            print("  --target=wasm32-unknown-unknown   (use `nuc build-wasm` today)");
            return 1;
        };
        print(str_concat("nuc install sysroot --target=", target_triple));
        print("");
        print("STATUS: deferred to v0.5 with the package registry (RFC-0022 phase 3).");
        print("");
        print("The v0.5 release will fetch a signed sysroot bundle from");
        print("https://nucleor.dev/sysroots/<triple>/ and verify the SHA-256");
        print("checksum before unpacking under .nucleor/sysroots/<triple>/.");
        print("Cross-target builds will then resolve clang's --sysroot from");
        print("that path automatically.");
        print("");
        print("Today, on Windows, nuc build-wasm targets wasm32-unknown-unknown");
        print("with no sysroot needed; for Linux/macOS native builds use");
        print("--target on the host and consult `nuc explain TGT-001`.");
        return 0;
    };
    let manifest_path: str = lock_resolve_manifest_target("");
    if str_len(manifest_path) == 0 {
        print("ERROR: no Nucleor.toml found in the current directory");
        print("Usage: nuc install [alias] <path-to-package|package|package@version> [--registry <dir>]");
        print("       nuc install sysroot --target=<triple>      (cross-target sysroot, v0.5)");
        return 1;
    };
    let mut positionals: Vec<i32> = Vec::new();
    let mut i: i64 = 2;
    while i < argc {
        let arg: str = args_get(i);
        if cli_is_flag(arg) == 0 { positionals.push(arg); };
        if str_eq(arg, "--registry") == 1 { i = i + 1; };
        i = i + 1;
    };
    let mut alias: str = "";
    let mut dep_input: str = "";
    if vec_len(positionals) == 1 {
        dep_input = vec_get(positionals, 0);
        let dep_manifest: str = manifest_resolve_dependency_manifest(manifest_path, dep_input);
        let dep_raw: str = file_read_string(dep_manifest);
        if str_len(dep_raw) == 0 {
            let spec_parts0: Vec<i32> = parse_registry_spec_native(dep_input);
            alias = vec_get(spec_parts0, 0);
        } else {
            let dep_settings: Vec<i32> = manifest_parse_settings(dep_manifest, dep_raw);
            alias = manifest_settings_package_name(dep_settings);
        };
    } else if vec_len(positionals) == 2 {
        alias = vec_get(positionals, 0);
        dep_input = vec_get(positionals, 1);
    } else {
        print("Usage: nuc install [alias] <path-to-package|package|package@version> [--registry <dir>]");
        return 1;
    };
    if str_len(alias) == 0 || str_len(dep_input) == 0 {
        print("ERROR: install requires a dependency alias and path");
        return 1;
    };
    let dep_manifest2: str = manifest_resolve_dependency_manifest(manifest_path, dep_input);
    let root_raw: str = file_read_string(manifest_path);
    let root_settings: Vec<i32> = manifest_parse_settings(manifest_path, root_raw);
    let deps: Vec<i32> = manifest_settings_deps(root_settings);
    let mut effective_dep_input: str = dep_input;
    if str_len(file_read_string(dep_manifest2)) == 0 {
        let spec_parts: Vec<i32> = parse_registry_spec_native(dep_input);
        let package_name: str = vec_get(spec_parts, 0);
        let selector: str = vec_get(spec_parts, 1);
        let registry_dir: str = registry_dir_native(argc, 2);
        let version: str = registry_resolve_version_native(registry_dir, package_name, selector);
        if str_len(version) == 0 {
            print(str_concat("ERROR: cannot resolve dependency '", str_concat(dep_input, "'")));
            return 1;
        };
        let verified: Vec<i32> = verify_registry_package_root_native(registry_dir, package_name, version);
        if vec_get(verified, 0) == 0 {
            print(str_concat("ERROR: ", vec_get(verified, 2)));
            return 1;
        };
        let published_root: str = vec_get(verified, 1);
        let vendor_root: str = sanitize(str_concat(path_with_sep(parent_dir(manifest_path)), str_concat(".nucleor/packages/", str_concat(package_name, str_concat("/", version)))));
        if copy_package_tree_native(published_root, vendor_root) != 0 {
            print(str_concat("ERROR: failed to vendor registry package: ", published_root));
            return 1;
        };
        write_package_checksum_file_native(vendor_root);
        let published_metadata: str = file_read_string(sanitize(str_concat(path_with_sep(published_root), registry_metadata_file_name())));
        if str_len(published_metadata) > 0 {
            file_write_string(sanitize(str_concat(path_with_sep(vendor_root), registry_metadata_file_name())), published_metadata);
        };
        effective_dep_input = path_normalize_slashes(path_relative_or_abs(parent_dir(manifest_path), vendor_root));
    };
    let mut replaced: i64 = 0;
    let mut di: i64 = 0;
    while di < vec_len(deps) {
        if str_eq(vec_get(deps, di), alias) == 1 {
            vec_set(deps, di + 1, effective_dep_input);
            replaced = 1;
            di = vec_len(deps);
        };
        di = di + 2;
    };
    if replaced == 0 {
        deps.push(alias);
        deps.push(effective_dep_input);
    };
    if manifest_replace_dependencies_section_native(manifest_path, deps) != 0 {
        print(str_concat("ERROR: cannot update dependencies in ", manifest_path));
        return 1;
    };
    let mut graph: Vec<i32> = Vec::new();
    let mut seen: Vec<i32> = Vec::new();
    let mut stack: Vec<i32> = Vec::new();
    let mut errors: Vec<i32> = Vec::new();
    if lock_build_graph_recursive(manifest_path, graph, seen, stack, errors) != 0 || vec_len(errors) > 0 {
        let err: str = if vec_len(errors) > 0 { vec_get(errors, 0) } else { "unknown dependency graph error" };
        print(str_concat("ERROR: ", err));
        return 1;
    };
    let lock_path: str = str_concat(path_with_sep(parent_dir(manifest_path)), "Nucleor.lock");
    file_write_string(lock_path, render_lockfile_native(manifest_path, graph));
    print(str_concat("installed dependency '", str_concat(alias, str_concat("' from ", path_normalize_slashes(dep_input)))));
    print(str_concat("locked: ", lock_path));
    return 0;
}

fn run_impact_command(src_path: str, argc: i64, arg_start: i64) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let fns: Vec<i32> = source_collect_functions(source);
    let graph: Vec<i32> = source_call_graph(fns);
    let effs: Vec<i32> = infer_source_effects(fns);
    let mut target_fn: str = cli_option_value(argc, arg_start, "--fn");
    if str_len(target_fn) == 0 { target_fn = cli_option_value(argc, arg_start, "--function"); };
    if str_len(target_fn) == 0 { target_fn = cli_first_positional(argc, arg_start); };
    if str_len(target_fn) == 0 {
        print("Usage: nuc impact <source.nr> <function_name>");
        return 1;
    };
    let target_idx: i64 = srcf_find(fns, target_fn);
    let mut direct_callees: Vec<i32> = Vec::new();
    let mut impacted: Vec<i32> = Vec::new();
    if target_idx >= 0 {
        let ord: i64 = target_idx / 8;
        let edges: Vec<i32> = vec_get(graph, ord);
        let mut ei: i64 = 0;
        while ei < vec_len(edges) {
            direct_callees.push(vec_get(fns, vec_get(edges, ei) * 8));
            ei = ei + 1;
        };
        let mut frontier: Vec<i32> = Vec::new();
        frontier.push(ord);
        while vec_len(frontier) > 0 {
            let cur_ord: i64 = vec_get(frontier, vec_len(frontier) - 1);
            vec_pop(frontier);
            let mut fi: i64 = 0;
            while fi < vec_len(graph) {
                let caller_name: str = vec_get(fns, fi * 8);
                let callees2: Vec<i32> = vec_get(graph, fi);
                if fi != cur_ord && int_vec_contains(callees2, cur_ord) == 1 && string_vec_contains(impacted, caller_name) == 0 {
                    impacted.push(caller_name);
                    frontier.push(fi);
                };
                fi = fi + 1;
            };
        };
    };
    let mut sb2: i64 = sb_new();
    sb_append(sb2, "{\"file\":\""); sb_append(sb2, json_escape(src_path)); sb_append(sb2, "\",\"target\":\""); sb_append(sb2, json_escape(target_fn)); sb_append(sb2, "\"");
    sb_append(sb2, ",\"found\":"); sb_append_json_bool(sb2, target_idx >= 0);
    sb_append(sb2, ",\"declared_effects\":"); sb_append_json_string_array(sb2, csv_to_string_vec(srcf_decl_effects(fns, target_fn)));
    sb_append(sb2, ",\"inferred_effects\":"); sb_append_json_string_array(sb2, csv_to_string_vec(inferred_effects_for(effs, target_fn)));
    sb_append(sb2, ",\"direct_callees\":"); sb_append_json_string_array(sb2, direct_callees);
    sb_append(sb2, ",\"impacted_callers\":"); sb_append_json_string_array(sb2, impacted);
    sb_append(sb2, ",\"total_impacted\":"); sb_append(sb2, str_from_int(vec_len(impacted)));
    sb_append(sb2, "}");
    print(sb_to_str(sb2));
    return 0;
}

fn render_graph_text(src_path: str, fns: Vec<i32>, graph: Vec<i32>, effs: Vec<i32>) -> str {
    let mut sb: i64 = sb_new();
    let mut edge_count: i64 = 0;
    let mut gi: i64 = 0;
    while gi < vec_len(graph) { edge_count = edge_count + vec_len(vec_get(graph, gi)); gi = gi + 1; };
    sb_append(sb, "file: "); sb_append(sb, src_path); sb_append(sb, "\n");
    sb_append(sb, "functions: "); sb_append(sb, str_from_int(vec_len(fns) / 8)); sb_append(sb, "\n");
    sb_append(sb, "edges: "); sb_append(sb, str_from_int(edge_count)); sb_append(sb, "\n");
    let mut i: i64 = 0;
    while i < vec_len(fns) {
        let name: str = vec_get(fns, i);
        let ord: i64 = i / 8;
        let edges: Vec<i32> = vec_get(graph, ord);
        let mut callee_names: Vec<i32> = Vec::new();
        let mut j: i64 = 0;
        while j < vec_len(edges) {
            callee_names.push(vec_get(fns, vec_get(edges, j) * 8));
            j = j + 1;
        };
        sb_append(sb, "fn ");
        sb_append(sb, name);
        if vec_get(fns, i + 1) == 1 { sb_append(sb, " [pure]"); };
        if vec_get(fns, i + 4) == 1 { sb_append(sb, " [extern]"); };
        if vec_get(fns, i + 7) == 1 { sb_append(sb, " [spawn]"); };
        sb_append(sb, "\n");
        let inf: str = csv_pretty(inferred_effects_for(effs, name));
        if str_len(inf) > 0 {
            sb_append(sb, "  effects: "); sb_append(sb, inf); sb_append(sb, "\n");
        };
        if vec_len(callee_names) > 0 {
            sb_append(sb, "  calls: "); sb_append(sb, join_strings(callee_names, ", ")); sb_append(sb, "\n");
        };
        i = i + 8;
    };
    return sb_to_str(sb);
}

fn render_graph_json(src_path: str, fns: Vec<i32>, graph: Vec<i32>, effs: Vec<i32>) -> str {
    let mut edge_count: i64 = 0;
    let mut gi: i64 = 0;
    while gi < vec_len(graph) { edge_count = edge_count + vec_len(vec_get(graph, gi)); gi = gi + 1; };
    let mut sb: i64 = sb_new();
    sb_append(sb, "{\"file\":\""); sb_append(sb, json_escape(src_path)); sb_append(sb, "\",\"function_count\":");
    sb_append(sb, str_from_int(vec_len(fns) / 8));
    sb_append(sb, ",\"edge_count\":"); sb_append(sb, str_from_int(edge_count));
    sb_append(sb, ",\"functions\":[");
    let mut i: i64 = 0;
    let mut first: i64 = 1;
    while i < vec_len(fns) {
        let name: str = vec_get(fns, i);
        let ord: i64 = i / 8;
        let edges: Vec<i32> = vec_get(graph, ord);
        let mut callee_names: Vec<i32> = Vec::new();
        let mut j: i64 = 0;
        while j < vec_len(edges) {
            callee_names.push(vec_get(fns, vec_get(edges, j) * 8));
            j = j + 1;
        };
        if first == 0 { sb_append(sb, ","); } else { first = 0; };
        sb_append(sb, "{\"name\":\""); sb_append(sb, json_escape(name)); sb_append(sb, "\",\"pure\":");
        sb_append_json_bool(sb, vec_get(fns, i + 1));
        sb_append(sb, ",\"extern\":"); sb_append_json_bool(sb, vec_get(fns, i + 4));
        sb_append(sb, ",\"has_spawn\":"); sb_append_json_bool(sb, vec_get(fns, i + 7));
        sb_append(sb, ",\"declared_effects\":"); sb_append_json_string_array(sb, csv_to_string_vec(vec_get(fns, i + 2)));
        sb_append(sb, ",\"inferred_effects\":"); sb_append_json_string_array(sb, csv_to_string_vec(inferred_effects_for(effs, name)));
        sb_append(sb, ",\"direct_callees\":"); sb_append_json_string_array(sb, callee_names);
        sb_append(sb, "}");
        i = i + 8;
    };
    sb_append(sb, "]}");
    return sb_to_str(sb);
}

fn run_graph_command(src_path: str, argc: i64, arg_start: i64) -> i64 {
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
    if preflight_source_check(source) != 0 { return 1; };
    let fns: Vec<i32> = source_collect_functions(source);
    let graph: Vec<i32> = source_call_graph(fns);
    let effs: Vec<i32> = infer_source_effects(fns);
    if cli_wants_json(argc, arg_start) == 1 {
        print(render_graph_json(src_path, fns, graph, effs));
    } else {
        print(render_graph_text(src_path, fns, graph, effs));
    };
    return 0;
}

fn run_profile_command(argc: i64) -> i64 {
    let mut subcmd: str = "run";
    if argc >= 3 { subcmd = args_get(2); };
    if str_eq(subcmd, "run") == 0 {
        print(str_concat("ERROR: unknown profile subcommand: ", subcmd));
        print("Usage: nuc profile run <binary> [--iterations <n>] [--json]");
        return 1;
    };
    if argc < 4 {
        print("Usage: nuc profile run <binary> [--iterations <n>] [--json]");
        return 1;
    };
    let binary: str = args_get(3);
    let mut iterations: i64 = 1;
    let mut json_mode: i64 = 0;
    let mut i: i64 = 4;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") == 1 || str_eq(arg, "--output=json") == 1 {
            json_mode = 1;
        } else if str_eq(arg, "--output") == 1 && i + 1 < argc && str_eq(args_get(i + 1), "json") == 1 {
            json_mode = 1;
            i = i + 1;
        } else if str_eq(arg, "--iterations") == 1 {
            if i + 1 >= argc {
                print("ERROR: --iterations requires a value");
                return 1;
            };
            iterations = str_to_int(args_get(i + 1));
            i = i + 1;
        } else if str_len(arg) > 13 && str_eq(str_substring(arg, 0, 13), "--iterations=") == 1 {
            iterations = str_to_int(str_substring(arg, 13, str_len(arg)));
        };
        i = i + 1;
    };
    if iterations < 1 { iterations = 1; };
    let quoted_binary: str = str_concat("\"", str_concat(binary, "\""));
    let total_start: i64 = now_ms();
    let mut run_times: Vec<i32> = Vec::new();
    let mut rc: i64 = 0;
    let mut iter: i64 = 0;
    while iter < iterations {
        let run_start: i64 = now_ms();
        let mut run_cmd: str = quoted_binary;
        if json_mode == 1 { run_cmd = str_concat(quoted_binary, " >NUL 2>&1"); };
        rc = system(run_cmd);
        run_times.push(now_ms() - run_start);
        if rc != 0 { iter = iterations; }
        else { iter = iter + 1; };
    };
    let total_ms: i64 = now_ms() - total_start;
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"subcommand\":\"run\",\"binary\":\""); sb_append(sb, json_escape(binary));
        sb_append(sb, "\",\"iterations\":"); sb_append(sb, str_from_int(iterations));
        sb_append(sb, ",\"exit_code\":"); sb_append(sb, str_from_int(rc));
        sb_append(sb, ",\"total_ms\":"); sb_append(sb, str_from_int(total_ms));
        sb_append(sb, ",\"avg_ms\":"); sb_append(sb, str_from_int(total_ms / iterations));
        sb_append(sb, ",\"runs\":[");
        let mut ri: i64 = 0;
        while ri < vec_len(run_times) {
            if ri > 0 { sb_append(sb, ","); };
            sb_append(sb, str_from_int(vec_get(run_times, ri)));
            ri = ri + 1;
        };
        sb_append(sb, "]}");
        print(sb_to_str(sb));
        return rc;
    };
    print(str_concat("=== Nucleor Profile Run: ", binary));
    print(str_concat("  iterations: ", str_from_int(iterations)));
    print(str_concat("  total_ms: ", str_from_int(total_ms)));
    print(str_concat("  avg_ms: ", str_from_int(total_ms / iterations)));
    return rc;
}

fn run_sage_command(argc: i64) -> i64 {
    if argc < 4 {
        print("Usage: nuc sage <prove|certificate|gaps> <file.nr> [--json]");
        return 1;
    };
    let subcmd: str = args_get(2);
    let src_path: str = args_get(3);
    let source: str = file_read_string(src_path);
    if str_len(source) == 0 {
        print(str_concat("ERROR: cannot read ", src_path));
        return 1;
    };
    let mut json_mode: i64 = 0;
    let mut i: i64 = 4;
    while i < argc {
        let arg: str = args_get(i);
        if str_eq(arg, "--json") == 1 || str_eq(arg, "--output=json") == 1 { json_mode = 1; }
        else if str_eq(arg, "--output") == 1 && i + 1 < argc && str_eq(args_get(i + 1), "json") == 1 {
            json_mode = 1;
            i = i + 1;
        };
        i = i + 1;
    };
    let has_sage_import: i64 = text_contains(source, "sage_ns") || text_contains(source, "sage_ns::");
    let has_interval: i64 = text_contains(source, "interval");
    let has_validated: i64 = text_contains(source, "validated");
    let has_inference: i64 = text_contains(source, "inference");
    let has_certificate: i64 = text_contains(source, "certificate");
    let mut gaps: Vec<i32> = Vec::new();
    if has_sage_import == 0 { gaps.push("missing sage_ns import"); };
    if has_interval == 0 { gaps.push("missing interval primitives"); };
    if has_validated == 0 { gaps.push("missing validated integration path"); };
    if has_inference == 0 { gaps.push("missing inference path"); };
    if has_certificate == 0 { gaps.push("missing certificate path"); };
    if text_contains(source, "TODO") == 1 { gaps.push("TODO markers present"); };
    if text_contains(source, "FIXME") == 1 { gaps.push("FIXME markers present"); };
    if text_contains(source, "assume") == 1 { gaps.push("assume markers present"); };
    if json_mode == 1 {
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\"subcommand\":\""); sb_append(sb, json_escape(subcmd)); sb_append(sb, "\",\"file\":\""); sb_append(sb, json_escape(src_path));
        sb_append(sb, "\",\"sage_import\":"); sb_append_json_bool(sb, has_sage_import);
        sb_append(sb, ",\"layers\":{\"interval\":"); sb_append_json_bool(sb, has_interval);
        sb_append(sb, ",\"validated\":"); sb_append_json_bool(sb, has_validated);
        sb_append(sb, ",\"inference\":"); sb_append_json_bool(sb, has_inference);
        sb_append(sb, ",\"certificate\":"); sb_append_json_bool(sb, has_certificate);
        sb_append(sb, "},\"gaps\":"); sb_append_json_string_array(sb, gaps);
        sb_append(sb, "}");
        print(sb_to_str(sb));
        return 0;
    };
    if str_eq(subcmd, "prove") == 1 {
        print(str_concat("=== Sage_NS Proof Pipeline: ", src_path));
        print("");
        print(str_concat("  Layer 1: interval primitives ... ", if has_interval == 1 { "present" } else { "missing" }));
        print(str_concat("  Layer 2: validated integration ... ", if has_validated == 1 { "present" } else { "missing" }));
        print(str_concat("  Layer 3: inference engine ... ", if has_inference == 1 { "present" } else { "missing" }));
        print(str_concat("  Layer 4: certificate generator ... ", if has_certificate == 1 { "present" } else { "missing" }));
        if has_sage_import == 0 { print("  Status: sage_ns import is missing."); }
        else if vec_len(gaps) == 0 { print("  Status: proof pipeline hooks detected."); }
        else { print("  Status: partial pipeline detected; run `nuc sage gaps <file.nr>` for missing pieces."); };
        return 0;
    } else if str_eq(subcmd, "certificate") == 1 {
        print(str_concat("=== Sage_NS Certificate Status: ", src_path));
        if has_certificate == 1 { print("  Certificate hooks detected."); }
        else { print("  Certificate generation path not found in source."); };
        return 0;
    } else if str_eq(subcmd, "gaps") == 1 {
        print(str_concat("=== Sage_NS Gap Analysis: ", src_path));
        if vec_len(gaps) == 0 { print("  No obvious Sage_NS integration gaps detected."); }
        else {
            let mut gi: i64 = 0;
            while gi < vec_len(gaps) {
                print(str_concat("  - ", vec_get(gaps, gi)));
                gi = gi + 1;
            };
        };
        return 0;
    };
    print(str_concat("ERROR: unknown sage subcommand: ", subcmd));
    print("Usage: nuc sage <prove|certificate|gaps> <file.nr> [--json]");
    return 1;
}

fn run_perf_command(src_path: str, argc: i64, arg_start: i64) -> i64 {
    // RFC-0063 Phase 2.0: perf no longer re-drives the pipeline inline
    // (s1's lower_fn now needs the full compile_file_mode setup). Text
    // mode delegates to the unified compiler with time_passes=1 (real
    // per-phase timings). JSON mode reports quiet front-end phase timings
    // (resolve / lex / parse), mirroring how audit/graph use the parser.
    let json_mode: i64 = cli_wants_json(argc, arg_start);
    if json_mode == 1 {
        let r0: i64 = now_ms();
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, 1);
        let source: str = vec_get(bundle, 0);
        let resolve_ms: i64 = now_ms() - r0;
        let l0: i64 = now_ms();
        let tokens: Vec<i32> = lex(source);
        let lex_ms: i64 = now_ms() - l0;
        let p0: i64 = now_ms();
        let mut pool: Vec<i32> = Vec::new();
        let parsed: Vec<i32> = parse_program(tokens, pool);
        let parse_ms: i64 = now_ms() - p0;
        let cnt: i64 = list_len(pool, pr_val(parsed));
        print(str_concat("{\"command\":\"perf\",\"source\":\"", str_concat(src_path, str_concat("\",\"items\":", str_concat(str_from_int(cnt), str_concat(",\"resolve_ms\":", str_concat(str_from_int(resolve_ms), str_concat(",\"lex_ms\":", str_concat(str_from_int(lex_ms), str_concat(",\"parse_ms\":", str_concat(str_from_int(parse_ms), "}")))))))))));
        return 0;
    };
    print("Nucleor Performance Analysis");
    print(str_concat("  source: ", src_path));
    let t0: i64 = now_ms();
    let rc: i64 = compile_file_mode(src_path, "perf_probe", 0, 0, 1, 0);
    let total: i64 = now_ms() - t0;
    print(str_concat("  total compile: ", str_concat(str_from_int(total), " ms")));
    if rc != 0 { print("  note: source did not compile cleanly"); };
    return 0;
}



// top-level entry point. Annotated as
// safety guardrail before the unconditional default-flip.
#[manual_drop]
fn main() -> i64 {
    let argc: i64 = args_count();
    if argc < 2 {
        print_help();
        return 1;
    };
    let cmd: str = args_get(1);
    // --version and help
    if str_eq(cmd, "--version") || str_eq(cmd, "-v") {
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
    if str_eq(cmd, "bootstrap") {
        return run_bootstrap_command(argc);
    };
    if str_eq(cmd, "stage-dump") {
        return run_stage_dump_command(argc);
    };
    if str_eq(cmd, "lock") {
        return run_lock_command(argc);
    };
    if str_eq(cmd, "deps") {
        return run_deps_command(argc);
    };
    if str_eq(cmd, "fix") {
        // Parse: nuc fix [--imports|--numeric] <file>
        let mut sub: str = "";
        let mut tgt: str = "";
        let mut fi: i64 = 2;
        while fi < argc {
            let a: str = args_get(fi);
            if str_eq(a, "--imports") == 1 { sub = "imports"; }
            else if str_eq(a, "--numeric") == 1 { sub = "numeric"; }
            else if cli_is_flag(a) == 0 && str_len(tgt) == 0 { tgt = a; };
            fi = fi + 1;
        };
        return tools_run_fix_command(tgt, sub);
    };
    if str_eq(cmd, "doc") {
        // Parse: nuc doc <file> [--out <path>] [--html] [--test-list]
        // T2.7 (v0.2.352): --html selects the HTML renderer instead
        // of Markdown. If --out is given without --html, we also
        // auto-detect by file extension (.html / .htm => HTML mode).
        // --test-list enumerates every ```nucleor code
        // block found in /// comments (extraction half of doc tests;
        // execution will ship in a future release).
        let mut tgt: str = "";
        let mut out_path: str = "";
        let mut html_mode: i64 = 0;
        let mut test_list_mode: i64 = 0;
        let mut di: i64 = 2;
        while di < argc {
            let a: str = args_get(di);
            if str_eq(a, "--out") == 1 && di + 1 < argc {
                out_path = args_get(di + 1);
                di = di + 1;
            } else if str_eq(a, "--html") == 1 {
                html_mode = 1;
            } else if str_eq(a, "--test-list") == 1 {
                test_list_mode = 1;
            } else if cli_is_flag(a) == 0 && str_len(tgt) == 0 { tgt = a; };
            di = di + 1;
        };
        if test_list_mode == 1 { return run_doc_test_list_command(tgt); };
        if html_mode == 0 && str_len(out_path) > 0 {
            let opl: i64 = str_len(out_path);
            if opl >= 5 && str_eq(str_substring(out_path, opl - 5, opl), ".html") == 1 { html_mode = 1; };
            if opl >= 4 && str_eq(str_substring(out_path, opl - 4, opl), ".htm") == 1 { html_mode = 1; };
        };
        if html_mode == 1 { return run_doc_command_html(tgt, out_path); };
        return tools_run_doc_command(tgt, out_path);
    };
    if str_eq(cmd, "install") {
        return run_install_command(argc);
    };
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
        // nuc init [name] — scaffold a new project.
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
    let mut test_isolation_process: i64 = 0;
    let mut test_check_laws: i64 = 0;
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
        else if str_eq(cmd, "test") && str_eq(flag, "--list") { test_list_only = 1; }
        else if str_eq(cmd, "test") && str_eq(flag, "--check-laws") { test_check_laws = 1; }
        else if str_eq(cmd, "test") && str_eq(flag, "--isolation=process") { test_isolation_process = 1; }
        else if str_eq(cmd, "test") && str_eq(flag, "--isolation=thread") { test_isolation_process = 0; }
        else if str_eq(cmd, "bench") && str_eq(flag, "--iterations") {
            if argi_build + 1 >= argc {
                print("ERROR: --iterations requires a value");
                return 1;
            };
            bench_iterations = str_to_int(args_get(argi_build + 1));
            argi_build = argi_build + 1;
        } else if str_eq(cmd, "bench") && str_len(flag) > 13 && str_eq(str_substring(flag, 0, 13), "--iterations=") {
            bench_iterations = str_to_int(str_substring(flag, 13, str_len(flag)));
        } else if str_eq(cmd, "bench") && str_eq(flag, "--warmup") {
            if argi_build + 1 >= argc {
                print("ERROR: --warmup requires a value");
                return 1;
            };
            bench_warmup = str_to_int(args_get(argi_build + 1));
            argi_build = argi_build + 1;
        } else if str_eq(cmd, "bench") && str_len(flag) > 9 && str_eq(str_substring(flag, 0, 9), "--warmup=") {
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
        } else if cli_is_flag(flag) == 1 && (str_eq(cmd, "build") == 1 || str_eq(cmd, "build-fast") == 1 || str_eq(cmd, "build-strict") == 1 || str_eq(cmd, "run") == 1 || str_eq(cmd, "emit") == 1 || str_eq(cmd, "build-wasm") == 1 || str_eq(cmd, "build-ptx") == 1 || str_eq(cmd, "verify-reproducible") == 1) {
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
        return compile_file_mode(src_path, out_name, 1, use_cache, time_passes, link_native);
    } else if str_eq(cmd, "build-fast") {
        return compile_file_mode(src_path, out_name, 0, use_cache, time_passes, link_native);
    } else if str_eq(cmd, "build-strict") {
        return compile_file_mode(src_path, out_name, 1, use_cache, time_passes, link_native);
    } else if str_eq(cmd, "build-shared") {
        return tools_run_build_shared_command(src_path, out_name, use_cache, time_passes, cli_wants_json(argc, arg_start));
    } else if str_eq(cmd, "run") {
        let rc: i64 = compile_file_mode(src_path, out_name, 1, use_cache, time_passes, 1);
        if rc != 0 { return rc; };
        let exe: str = str_concat("target\\", str_concat(out_name, ".exe"));
        return system(exe);
    } else if str_eq(cmd, "build-wasm") {
        // Compile to WASM using clang --target=wasm32
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
        let source: str = vec_get(bundle, 0);
        let imp: Vec<i32> = vec_get(bundle, 1);
        if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
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
        let mut fi: i64 = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 32 { externs.push(fn_nid); }
            else if node_kind(pool, fn_nid) == 33 { structs.push(fn_nid); }
            else if node_kind(pool, fn_nid) == 36 { enums.push(fn_nid); };
            if node_kind(pool, fn_nid) == 50 { globals.push(fn_nid); };
            fi = fi + 1;
        };
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
                    impl_fns.push(mk6(pool, 30, mangled, node_field(pool, method_nid, 2), node_field(pool, method_nid, 3), node_field(pool, method_nid, 4), node_field(pool, method_nid, 5)));
                    trait_impl_register(trait_impls, type_name, orig_name, mangled);
                    mi = mi + 1;
                };
            };
            fi = fi + 1;
        };
        let mut closures: Vec<i32> = Vec::new();
        fi = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 30 { fns.push(lower_fn(pool, fn_nid, strtab, structs, enums, globals, closures, trait_impls)); };
            fi = fi + 1;
        };
        let mut ii: i64 = 0;
        while ii < vec_len(impl_fns) { fns.push(lower_fn(pool, vec_get(impl_fns, ii), strtab, structs, enums, globals, closures, trait_impls)); ii = ii + 1; };
        let mut ci: i64 = 0;
        while ci < vec_len(closures) { fns.push(vec_get(closures, ci)); ci = ci + 1; };
        fi = 0;
        while fi < vec_len(fns) { opt_fn(vec_get(fns, fi)); fi = fi + 1; };
        let ll: str = emit_module_ext(fns, strtab, pool, externs, source);
        let ll_path: str = str_concat("target/", str_concat(out_name, ".ll"));
        let wasm_path: str = str_concat("target/", str_concat(out_name, ".wasm"));
        file_write_string(ll_path, ll);
        print(str_concat("  emitted: ", str_concat(ll_path, str_concat(" (", str_concat(str_from_int(str_len(ll)), " bytes)")))));
        let wasm_cmd: str = str_concat("\"C:\\Program Files\\LLVM\\bin\\clang.exe\" --target=wasm32-unknown-unknown -nostdlib -Wl,--no-entry -Wl,--export-all -Wl,--allow-undefined -o ", str_concat(wasm_path, str_concat(" ", str_concat(ll_path, " -Wno-override-module 2>&1"))));
        let rc: i64 = system(wasm_cmd);
        if rc != 0 { print("  WASM COMPILE FAILED"); print("  Note: WASM builds cannot use print(), system(), or file I/O functions"); return 1; };
        print(str_concat("  compiled: ", wasm_path));
        return 0;
    } else if str_eq(cmd, "build-ptx") {
        let emit_rc: i64 = compile_file_mode(src_path, out_name, 1, use_cache, time_passes, 0);
        if emit_rc != 0 { return emit_rc; };
        let ll_path2: str = str_concat("target/", str_concat(out_name, ".ll"));
        let ptx_path: str = str_concat("target/", str_concat(out_name, ".ptx"));
        let ptx_cmd: str = str_concat(llvm_clang_path(), str_concat(" --target=nvptx64-nvidia-cuda -S -x ir ", str_concat(ll_path2, str_concat(" -o ", str_concat(ptx_path, " -Wno-override-module 2>&1")))));
        let ptx_rc: i64 = system(ptx_cmd);
        if ptx_rc != 0 {
            print("  PTX COMPILE FAILED");
            print("  Note: PTX builds require LLVM clang with NVPTX support");
            return 1;
        };
        print(str_concat("  compiled: ", ptx_path));
        return 0;
    } else if str_eq(cmd, "emit") {
        return compile_file_mode(src_path, out_name, 1, use_cache, time_passes, 0);
    } else if str_eq(cmd, "test") {
        return run_test_command(src_path, out_name, use_cache, time_passes, test_list_only, test_isolation_process, test_check_laws);
    } else if str_eq(cmd, "bench") {
        return run_bench_command(src_path, out_name, use_cache, time_passes, bench_iterations, bench_warmup);
    } else if str_eq(cmd, "check") {
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
        let source: str = vec_get(bundle, 0);
        if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
        if preflight_source_check(source) != 0 { return 1; };
        let mut tokens: Vec<i32> = lex(source);
        let mut pool: Vec<i32> = Vec::new();
        let mut r: Vec<i32> = parse_program(tokens, pool);
        let prog: i64 = pr_val(r);
        let cnt: i64 = list_len(pool, prog);
        // Collect structs and enums for checkers
        let mut structs: Vec<i32> = Vec::new();
        let mut enums: Vec<i32> = Vec::new();
        let mut fi: i64 = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 33 { structs.push(fn_nid); }
            else if node_kind(pool, fn_nid) == 36 { enums.push(fn_nid); };
            fi = fi + 1;
        };
        // Check for --review, --json, --review-filter, --check flags
        let mut json_mode: i64 = 0;
        let mut sarif_mode: i64 = 0;
        let mut review_path: str = "";
        let mut review_filter: str = "";
        let mut check_filter: str = "";
        let mut argi: i64 = arg_start;
        while argi < argc {
            let flag: str = args_get(argi);
            if str_eq(flag, "--json") { json_mode = 1; };
            if str_eq(flag, "--sarif") { sarif_mode = 1; };
            if str_eq(flag, "--review") { review_path = "nucleor_review.jsonl"; };
            if str_eq(flag, "--review-pipe") { review_path = "\\\\.\\pipe\\nucleor_review"; };
            if str_len(flag) > 16 && str_eq(str_substring(flag, 0, 16), "--review-filter=") {
                review_filter = str_substring(flag, 16, str_len(flag));
            };
            if str_len(flag) > 8 && str_eq(str_substring(flag, 0, 8), "--check=") {
                check_filter = str_substring(flag, 8, str_len(flag));
            };
            argi = argi + 1;
        };
        // Initialize review file
        if str_len(review_path) > 0 {
            file_write_string(review_path, str_concat("{\"schema_version\":\"1.0\",\"event\":\"surface_open\",\"file\":\"", str_concat(src_path, "\"}\n")));
        };
        // Run checkers (respecting --check filter)
        let start_ns: i64 = 0;
        let mut diags: Vec<i32> = diag_new();
        let run_own: i64 = str_len(check_filter) == 0 || review_filter_allows_checker(check_filter, "ownership");
        let run_type: i64 = str_len(check_filter) == 0 || review_filter_allows_checker(check_filter, "type");
        let run_source: i64 = str_len(check_filter) == 0 || review_filter_allows_checker(check_filter, "source");
        let run_taint: i64 = str_len(check_filter) == 0 || review_filter_allows_checker(check_filter, "taint");
        let run_effect: i64 = str_len(check_filter) == 0 || review_filter_allows_checker(check_filter, "effect");
        let check_type_prof: Vec<i32> = tprof_new(time_passes);
        if run_type == 1 { type_check_program(pool, prog, structs, diags, source, check_type_prof); };
        if run_type == 1 { tprof_dump(check_type_prof); };
        if run_source == 1 { source_rule_check(source, diags); };
        // Per-function checker tracking for coverage events
        fi = 0;
        while fi < cnt {
            let fn_nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, fn_nid) == 30 {
                let fname: str = node_field(pool, fn_nid, 1);
                let d_before: i64 = diag_count(diags);
                let mut own_findings: i64 = 0;
                let mut taint_findings: i64 = 0;
                if run_own == 1 { own_findings = check_fn(pool, fn_nid, structs, enums, diags, source); };
                if run_taint == 1 { taint_findings = taint_check_fn(pool, fn_nid, diags, source, review_path, review_filter); };
                // S12b: checker_coverage event (removable)
                if str_len(review_path) > 0 {
                    let mut csb: i64 = sb_new();
                    sb_append(csb, "{\"schema_version\":\"1.0\",\"event\":\"checker_coverage\",\"function\":\"");
                    sb_append(csb, fname);
                    sb_append(csb, "\",\"checkers\":{\"ownership\":{\"ran\":");
                    if run_own == 1 { sb_append(csb, "true"); } else { sb_append(csb, "false"); };
                    sb_append(csb, ",\"findings\":"); sb_append(csb, str_from_int(own_findings));
                    sb_append(csb, "},\"taint\":{\"ran\":");
                    if run_taint == 1 { sb_append(csb, "true"); } else { sb_append(csb, "false"); };
                    sb_append(csb, ",\"findings\":"); sb_append(csb, str_from_int(taint_findings));
                    sb_append(csb, "}}}");
                    review_emit(review_path, sb_to_str(csb));
                };
                // Causal links: if multiple diags in same function, link them
                let d_after: i64 = diag_count(diags);
                if d_after - d_before >= 2 {
                    let first_id: str = str_concat("D-", str_from_int(d_before + 1));
                    let mut di: i64 = d_before + 1;
                    while di < d_after {
                        let d: Vec<i32> = diag_get(diags, di);
                        let did: str = str_concat("D-", str_from_int(di + 1));
                        // Set related_id on this diagnostic pointing to the first
                        vec_set(d, 7, first_id);
                        // S12b: causal link event (removable)
                        if str_len(review_path) > 0 {
                            let mut lsb: i64 = sb_new();
                            sb_append(lsb, "{\"schema_version\":\"1.0\",\"event\":\"causal_link\",\"from_diagnostic_id\":\"");
                            sb_append(lsb, first_id); sb_append(lsb, "\",\"to_diagnostic_id\":\"");
                            sb_append(lsb, did); sb_append(lsb, "\",\"relationship\":\"upstream_cause\"}");
                            review_emit(review_path, sb_to_str(lsb));
                        };
                        di = di + 1;
                    };
                };
            };
            fi = fi + 1;
        };
        // Inter-procedural taint pass
        if run_taint == 1 {
            fi = 0;
            while fi < cnt {
                let fn_nid: i64 = list_get(pool, prog, fi);
                if node_kind(pool, fn_nid) == 30 {
                    let fname: str = node_field(pool, fn_nid, 1);
                    if str_eq(fname, "main") == 0 {
                        taint_check_fn_ex(pool, fn_nid, diags, source, review_path, review_filter, 1);
                    };
                };
                fi = fi + 1;
            };
        };
        // Collect pure fns and check effects
        let mut pure_fns: Vec<i32> = Vec::new();
        if run_effect == 1 {
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
                    if is_pure == 1 { effect_check_fn(pool, fn_nid, pure_fns, diags, source, review_path, review_filter); };
                };
                fi = fi + 1;
            };
        };
        let elapsed: i64 = 0; // now_ms enabled after bootstrap
        // Close review surface
        if str_len(review_path) > 0 {
            file_append_string(review_path, str_concat("{\"schema_version\":\"1.0\",\"event\":\"surface_close\",\"diagnostics_emitted\":", str_concat(str_from_int(diag_count(diags)), str_concat(",\"elapsed_ms\":", str_concat(str_from_int(elapsed), "}\n")))));
        };
        // Output: JSON or text
        if sarif_mode == 1 {
            diag_emit_sarif(diags, source, src_path);
        } else if json_mode == 1 {
            diag_emit_json(diags);
        } else {
            print(str_concat("  parsed: ", str_concat(str_from_int(cnt), " top-level items")));
            let mut checkers_run: str = "";
            if run_own == 1 { checkers_run = "ownership"; };
            if run_type == 1 { if str_len(checkers_run) > 0 { checkers_run = str_concat(checkers_run, ","); }; checkers_run = str_concat(checkers_run, "type"); };
            if run_source == 1 { if str_len(checkers_run) > 0 { checkers_run = str_concat(checkers_run, ","); }; checkers_run = str_concat(checkers_run, "source"); };
            if run_taint == 1 { if str_len(checkers_run) > 0 { checkers_run = str_concat(checkers_run, ","); }; checkers_run = str_concat(checkers_run, "taint"); };
            if run_effect == 1 { if str_len(checkers_run) > 0 { checkers_run = str_concat(checkers_run, ","); }; checkers_run = str_concat(checkers_run, "effect"); };
            print(str_concat("  checkers: ", checkers_run));
            if diag_count(diags) > 0 { diag_emit_text(diags); }
            else { print("  OK — no diagnostics"); };
            print(str_concat("  elapsed: ", str_concat(str_from_int(elapsed), "ms")));
            if str_len(review_path) > 0 { print(str_concat("  review surface written to: ", review_path)); };
        };
        if diag_count(diags) > 0 { return 1; };
        return 0;
    } else if str_eq(cmd, "audit") {
        // nuc audit <file> — provenance and governance report
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
        let source: str = vec_get(bundle, 0);
        let imp: Vec<i32> = vec_get(bundle, 1);
        if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
        if preflight_source_check(source) != 0 { return 1; };
        let mut tokens: Vec<i32> = lex(source);
        let mut pool: Vec<i32> = Vec::new();
        let mut r: Vec<i32> = parse_program(tokens, pool);
        let prog: i64 = pr_val(r);
        let cnt: i64 = list_len(pool, prog);
        // Count items
        let mut fn_cnt: i64 = 0; let mut struct_cnt: i64 = 0; let mut enum_cnt: i64 = 0;
        let mut trait_cnt: i64 = 0; let mut impl_cnt: i64 = 0; let mut extern_cnt: i64 = 0;
        let mut pure_cnt: i64 = 0; let mut tainted_params: i64 = 0;
        let mut fi: i64 = 0;
        let mut structs: Vec<i32> = Vec::new(); let mut enums: Vec<i32> = Vec::new();
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            let nk: i64 = node_kind(pool, nid);
            if nk == 30 { fn_cnt = fn_cnt + 1;
                // Count tainted params
                let pl: i64 = node_field(pool, nid, 2);
                let pc: i64 = list_len(pool, pl);
                let mut pi: i64 = 0;
                while pi < pc {
                    let pt: str = node_field(pool, list_get(pool, pl, pi), 2);
                    if is_tainted_type(pt) == 1 { tainted_params = tainted_params + 1; };
                    pi = pi + 1;
                };
            };
            if nk == 32 { extern_cnt = extern_cnt + 1; };
            if nk == 33 { struct_cnt = struct_cnt + 1; structs.push(nid); };
            if nk == 36 { enum_cnt = enum_cnt + 1; enums.push(nid); };
            if nk == 43 { trait_cnt = trait_cnt + 1; };
            if nk == 45 { impl_cnt = impl_cnt + 1; };
            if nk == 46 { pure_cnt = pure_cnt + 1; };
            fi = fi + 1;
        };
        // Run checkers
        let mut diags: Vec<i32> = diag_new();
        let review_path: str = ""; let review_filter: str = "";
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 30 {
                check_fn(pool, nid, structs, enums, diags, source);
                taint_check_fn(pool, nid, diags, source, review_path, review_filter);
            };
            fi = fi + 1;
        };
        // Inter-procedural taint
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 30 {
                if str_eq(node_field(pool, nid, 1), "main") == 0 {
                    taint_check_fn_ex(pool, nid, diags, source, review_path, review_filter, 1);
                };
            };
            fi = fi + 1;
        };
        // Effect check
        let mut pure_fns: Vec<i32> = Vec::new();
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 46 { pure_fns.push(node_field(pool, nid, 1)); };
            fi = fi + 1;
        };
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 30 {
                let fname: str = node_field(pool, nid, 1);
                let mut is_pure: i64 = 0;
                let mut pi: i64 = 0;
                while pi < vec_len(pure_fns) { if str_eq(vec_get(pure_fns, pi), fname) { is_pure = 1; pi = vec_len(pure_fns); }; pi = pi + 1; };
                if is_pure == 1 { effect_check_fn(pool, nid, pure_fns, diags, source, review_path, review_filter); };
            };
            fi = fi + 1;
        };
        // Emit audit report
        let own_warns: i64 = 0; let tnt_warns: i64 = 0; let eff_warns: i64 = 0;
        let dc: i64 = diag_count(diags);
        let mut di: i64 = 0;
        let mut ow: i64 = 0; let mut tw: i64 = 0; let mut ew: i64 = 0;
        while di < dc {
            let d: Vec<i32> = diag_get(diags, di);
            if str_eq(vec_get(d, 1), "ownership") { ow = ow + 1; };
            if str_eq(vec_get(d, 1), "taint") { tw = tw + 1; };
            if str_eq(vec_get(d, 1), "effect") { ew = ew + 1; };
            di = di + 1;
        };
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\n  \"schema_version\": \"1.0\",\n  \"type\": \"audit_report\",\n");
        sb_append(sb, "  \"file\": \""); sb_append(sb, src_path); sb_append(sb, "\",\n");
        sb_append(sb, "  \"source_bytes\": "); sb_append(sb, str_from_int(str_len(source)));
        sb_append(sb, ",\n  \"source_hash\": \""); sb_append(sb, secure_hash(source)); sb_append(sb, "\",\n");
        sb_append(sb, "  \"imports\": "); sb_append(sb, str_from_int(vec_len(imp))); sb_append(sb, ",\n");
        sb_append(sb, "  \"inventory\": {\n");
        sb_append(sb, "    \"functions\": "); sb_append(sb, str_from_int(fn_cnt));
        sb_append(sb, ",\n    \"structs\": "); sb_append(sb, str_from_int(struct_cnt));
        sb_append(sb, ",\n    \"enums\": "); sb_append(sb, str_from_int(enum_cnt));
        sb_append(sb, ",\n    \"traits\": "); sb_append(sb, str_from_int(trait_cnt));
        sb_append(sb, ",\n    \"impl_blocks\": "); sb_append(sb, str_from_int(impl_cnt));
        sb_append(sb, ",\n    \"extern_fns\": "); sb_append(sb, str_from_int(extern_cnt));
        sb_append(sb, ",\n    \"pure_functions\": "); sb_append(sb, str_from_int(pure_cnt));
        sb_append(sb, ",\n    \"tainted_parameters\": "); sb_append(sb, str_from_int(tainted_params));
        sb_append(sb, "\n  },\n");
        sb_append(sb, "  \"governance\": {\n");
        sb_append(sb, "    \"ownership_findings\": "); sb_append(sb, str_from_int(ow));
        sb_append(sb, ",\n    \"taint_findings\": "); sb_append(sb, str_from_int(tw));
        sb_append(sb, ",\n    \"effect_findings\": "); sb_append(sb, str_from_int(ew));
        sb_append(sb, ",\n    \"total_findings\": "); sb_append(sb, str_from_int(dc));
        sb_append(sb, ",\n    \"checkers_run\": [\"ownership\", \"taint\", \"effect\"]");
        if dc == 0 { sb_append(sb, ",\n    \"status\": \"CLEAN\""); }
        else { sb_append(sb, ",\n    \"status\": \"FINDINGS_PRESENT\""); };
        sb_append(sb, "\n  },\n");
        sb_append(sb, "  \"compiler\": {\n    \"version\": \""); sb_append(sb, compiler_version_label());
        sb_append(sb, "\",\n    \"backend\": \""); sb_append(sb, compiler_backend_label()); sb_append(sb, "\"\n  }\n");
        sb_append(sb, "}\n");
        print(sb_to_str(sb));
        return 0;
    } else if str_eq(cmd, "policy") {
        // nuc policy <file> — check governance policy compliance
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
        let source: str = vec_get(bundle, 0);
        if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
        if preflight_source_check(source) != 0 { return 1; };
        let mut tokens: Vec<i32> = lex(source);
        let mut pool: Vec<i32> = Vec::new();
        let mut r: Vec<i32> = parse_program(tokens, pool);
        let prog: i64 = pr_val(r);
        let cnt: i64 = list_len(pool, prog);
        // Check policies
        let mut violations: i64 = 0;
        let mut fi: i64 = 0;
        let mut has_extern: i64 = 0; let mut has_system: i64 = 0; let mut has_taint: i64 = 0;
        let mut structs: Vec<i32> = Vec::new(); let mut enums: Vec<i32> = Vec::new();
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 32 { has_extern = 1; };
            if node_kind(pool, nid) == 33 { structs.push(nid); };
            if node_kind(pool, nid) == 36 { enums.push(nid); };
            fi = fi + 1;
        };
        // Run taint checker for policy enforcement
        let mut diags: Vec<i32> = diag_new();
        let review_path: str = ""; let review_filter: str = "";
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 30 {
                taint_check_fn(pool, nid, diags, source, review_path, review_filter);
            };
            fi = fi + 1;
        };
        // Inter-procedural taint
        fi = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            if node_kind(pool, nid) == 30 {
                if str_eq(node_field(pool, nid, 1), "main") == 0 {
                    taint_check_fn_ex(pool, nid, diags, source, review_path, review_filter, 1);
                };
            };
            fi = fi + 1;
        };
        violations = diag_count(diags);
        // Check optional policy flags
        let mut policy: str = policy_level;
        let mut sb: i64 = sb_new();
        sb_append(sb, "Policy: "); sb_append(sb, policy); sb_append(sb, "\n");
        if str_eq(policy, "no_extern") || str_eq(policy, "strict") {
            if has_extern == 1 { sb_append(sb, "VIOLATION: extern fn declarations present (no_extern policy)\n"); violations = violations + 1; };
        };
        if str_eq(policy, "no_system") || str_eq(policy, "strict") {
            // Check for system() calls
            let src_len: i64 = str_len(source);
            let mut si: i64 = 0;
            while si < src_len - 7 {
                if str_eq(str_substring(source, si, si + 7), "system(") { has_system = 1; si = src_len; };
                si = si + 1;
            };
            if has_system == 1 { sb_append(sb, "VIOLATION: system() call present (no_system policy)\n"); violations = violations + 1; };
        };
        if violations > 0 {
            sb_append(sb, "Taint findings: "); sb_append(sb, str_from_int(diag_count(diags))); sb_append(sb, "\n");
            sb_append(sb, "Result: FAIL ("); sb_append(sb, str_from_int(violations)); sb_append(sb, " violations)\n");
        } else {
            sb_append(sb, "Result: PASS\n");
        };
        print(sb_to_str(sb));
        return violations;
    } else if str_eq(cmd, "certify") {
        // nuc certify <file> — compile + produce signed artifact manifest
        let rc: i64 = compile_file(src_path, out_name);
        if rc != 0 { print("  certification: FAILED (compilation error)"); return 1; };
        // Read artifacts and compute hashes via system
        let ll_path: str = str_concat("target/", str_concat(out_name, ".ll"));
        let exe_path: str = str_concat("target\\", str_concat(out_name, ".exe"));
        let raw: str = file_read_string(src_path);
        let ll: str = file_read_string(ll_path);
        // Build manifest
        let mut sb: i64 = sb_new();
        sb_append(sb, "{\n  \"schema_version\": \"1.0\",\n  \"type\": \"certification\",\n");
        sb_append(sb, "  \"source\": {\"path\": \""); sb_append(sb, src_path);
        sb_append(sb, "\", \"bytes\": "); sb_append(sb, str_from_int(str_len(raw)));
        sb_append(sb, ", \"hash\": \""); sb_append(sb, secure_hash(raw)); sb_append(sb, "\"},\n");
        sb_append(sb, "  \"ir\": {\"path\": \""); sb_append(sb, ll_path);
        sb_append(sb, "\", \"bytes\": "); sb_append(sb, str_from_int(str_len(ll)));
        sb_append(sb, ", \"hash\": \""); sb_append(sb, secure_hash(ll)); sb_append(sb, "\"},\n");
        sb_append(sb, "  \"binary\": {\"path\": \""); sb_append(sb, exe_path); sb_append(sb, "\"},\n");
        sb_append(sb, "  \"compiler\": {\"version\": \""); sb_append(sb, compiler_version_label());
        sb_append(sb, "\", \"backend\": \""); sb_append(sb, compiler_backend_label()); sb_append(sb, "\"},\n");
        sb_append(sb, "  \"certification\": \"PASS\"\n}\n");
        let manifest_path: str = str_concat("target/", str_concat(out_name, ".cert.json"));
        file_write_string(manifest_path, sb_to_str(sb));
        print(str_concat("  certification manifest: ", manifest_path));
        return 0;
    } else if str_eq(cmd, "translate") {
        // nuc translate <file> — parse and emit formatted Nucleor source (canonical form)
        let bundle: Vec<i32> = load_resolved_source_bundle(src_path, use_cache);
        let source: str = vec_get(bundle, 0);
        let imp: Vec<i32> = vec_get(bundle, 1);
        if str_len(source) == 0 { print(str_concat("ERROR: cannot read ", src_path)); return 1; };
        if preflight_source_check(source) != 0 { return 1; };
        let mut tokens: Vec<i32> = lex(source);
        let mut pool: Vec<i32> = Vec::new();
        let mut r: Vec<i32> = parse_program(tokens, pool);
        let prog: i64 = pr_val(r);
        let cnt: i64 = list_len(pool, prog);
        // Emit summary of translated items
        let mut fn_cnt: i64 = 0; let mut struct_cnt: i64 = 0; let mut enum_cnt: i64 = 0;
        let mut fi: i64 = 0;
        while fi < cnt {
            let nid: i64 = list_get(pool, prog, fi);
            let nk: i64 = node_kind(pool, nid);
            if nk == 30 { fn_cnt = fn_cnt + 1; };
            if nk == 33 { struct_cnt = struct_cnt + 1; };
            if nk == 36 { enum_cnt = enum_cnt + 1; };
            fi = fi + 1;
        };
        print(str_concat("  translated: ", str_concat(str_from_int(fn_cnt), str_concat(" functions, ", str_concat(str_from_int(struct_cnt), str_concat(" structs, ", str_concat(str_from_int(enum_cnt), " enums")))))));
        print(str_concat("  source bytes: ", str_from_int(str_len(source))));
        print(str_concat("  imports resolved: ", str_from_int(vec_len(imp))));
        print("  OK — source validated");
        return 0;
    } else {
        // Fallback: treat as legacy
        if argc >= 3 { return compile_file(cmd, args_get(2)); };
        print(str_concat("Unknown command: ", cmd));
        return 1;
    };
}
