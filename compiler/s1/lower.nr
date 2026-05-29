// =====================================================
// LOWERING (from T29, extended for STR_LIT, METHOD, QUAL_CALL)
// =====================================================
#[manual_drop]
fn ctr_new() -> Vec<i32> { let mut c: Vec<i32> = Vec::new(); c.push(0); return c; }
#[manual_drop]
fn ctr_next(c: Vec<i32>) -> i64 { let v: i64 = vec_get(c, 0); vec_set(c, 0, v + 1); return v; }
#[manual_drop]
fn sym_new() -> Vec<i32> { return Vec::new(); }
#[manual_drop]
fn sym_set(s: Vec<i32>, name: str, reg: i64) -> i64 { s.push(name); s.push(reg); return 0; }

// shared fn-return-type lookup map. Built once
// per program; sym_get falls back here for `__fnret_*` and
// `__fnfulltype_*` keys instead of having every function-local sym
// pre-populate them. Cuts per-fn sym_set workload (was ~2 entries
// per declared fn × N fns = 2*N^2 sym_set calls; now ~1 sym_set
// per fn-body).
#[manual_drop]
fn fn_return_map_get(m: i64, key: str) -> i64 {
    if m <= 0 { return 0 - 1; };
    if __nucleor_hashmap_contains(m, key) == 1 { return __nucleor_hashmap_get(m, key); };
    return 0 - 1;
}

#[manual_drop]
fn sym_get(s: Vec<i32>, name: str) -> i64 {
    let n: i64 = vec_len(s);
    if n < 64 {
        if n < 2 { return 0 - 1; };
        let lhit: i64 = __nucleor_sym_linear_lookup(s, name);
        if lhit >= 0 { return lhit; };
        if str_starts_with(name, "__fnret_") == 1 || str_starts_with(name, "__fnfulltype_") == 1 {
            let ret_map1: i64 = sym_get(s, "__fn_return_map");
            if ret_map1 >= 0 { return fn_return_map_get(ret_map1, name); };
        };
        return 0 - 1;
    };
    // Large sym: warm hash path. The runtime _create returns the
    // single warm hashmap; if `s` isn't the currently-warm handle,
    // the hashmap is cleared and built_at reset to 0 so the catchup
    // loop below repopulates from this sym's vec.
    let h: i64 = __nucleor_sym_aux_create(s);
    let built: i64 = __nucleor_sym_aux_built_at(s);
    let mut i: i64 = if built < 0 { 0 } else { built };
    while i + 1 < n {
        __nucleor_hashmap_insert(h, vec_get(s, i), vec_get(s, i + 1));
        i = i + 2;
    };
    __nucleor_sym_aux_set_built_at(s, n);
    if __nucleor_hashmap_contains(h, name) == 1 { return __nucleor_hashmap_get(h, name); };
    if str_starts_with(name, "__fnret_") == 1 || str_starts_with(name, "__fnfulltype_") == 1 {
        let ret_map: i64 = sym_get(s, "__fn_return_map");
        if ret_map >= 0 { return fn_return_map_get(ret_map, name); };
    };
    return 0 - 1;
}
#[manual_drop]
fn sym_clone(s: Vec<i32>) -> Vec<i32> {
    let mut c: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    let cnt: i64 = vec_len(s);
    while i < cnt { c.push(vec_get(s, i)); i = i + 1; };
    return c;
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
fn smap_new() -> Vec<i32> {
    return smap_new_cap(64);
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
fn tok_to_ir(tok: i64) -> i64 {
    if tok == 20 { return 2; }; if tok == 21 { return 3; }; if tok == 22 { return 4; };
    if tok == 23 { return 5; }; if tok == 24 { return 6; }; if tok == 30 { return 7; };
    if tok == 31 { return 8; }; if tok == 32 { return 9; }; if tok == 33 { return 10; };
    if tok == 34 { return 11; }; if tok == 35 { return 12; };
    if tok == 36 { return 13; }; if tok == 37 { return 14; };
    // bitwise ops. Map `&` (token 82) to LLVM `and i64`
    // (iop 13 — same as `&&` since both lower to bitwise AND of i64
    // operands), `|` (token 65) to `or i64` (iop 14), and `^`
    // (token 94) to a new `xor i64` (iop 15). The parse_bitwise
    // tier between parse_eq and parse_and_expr (logical &&) ensures
    // these operators actually reach the binop chain instead of
    // dying after the LHS with a diag.
    if tok == 82 { return 13; }; if tok == 65 { return 14; }; if tok == 94 { return 15; };
    // shift ops. Token 115 = `<<` (lexer), 116 = synthetic
    // `>>` produced by parse_shift when it sees two adjacent `>`.
    // iops 16-17 are alloca/load — can't reuse. Use 23/24 (free).
    if tok == 115 { return 23; }; if tok == 116 { return 24; };
    return 0 - 1;
}
#[manual_drop]
fn is_cmp_or_logic(iop: i64) -> i64 {
    if iop >= 7 && iop <= 14 { return 1; };
    // Lane 1 audit fix (2026-05-08) — close C-001 / C-007. Unsigned
    // compare iops 38..41 (ult/ugt/ule/uge) are the u64 analogues of
    // 9..12 and must be classed alongside their signed siblings so the
    // lowering dispatch routes them through ir_cmpop / emit_cmp.
    if iop >= 38 && iop <= 41 { return 1; };
    return 0;
}

// Struct registry helpers
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
fn trait_bound_impl_key(trait_name: str, type_name: str) -> str {
    return str_concat(type_base_name(trait_name), str_concat(":", type_name));
}

#[manual_drop]
fn trait_impl_find_unique_bound_method(impls: Vec<i32>, trait_name: str, method_name: str) -> str {
    let prefix: str = str_concat(type_base_name(trait_name), ":");
    let mut found: str = "";
    let mut count: i64 = 0;
    let mut i: i64 = 0;
    while i < vec_len(impls) {
        let impl_key: str = vec_get(impls, i);
        if str_starts_with(impl_key, prefix) == 1 && str_eq(vec_get(impls, i + 1), method_name) == 1 {
            found = vec_get(impls, i + 2);
            count = count + 1;
        };
        i = i + 3;
    };
    if count == 1 { return found; };
    if count > 1 { return "__ambiguous_trait_bound_method"; };
    return "";
}

#[manual_drop]
fn from_method_key(src_err: str) -> str {
    return str_concat("__from__", src_err);
}

#[manual_drop]
fn from_impl_call_name(impls: Vec<i32>, src_err: str, dst_err: str) -> str {
    return trait_impl_find(impls, dst_err, from_method_key(src_err));
}

#[manual_drop]
fn from_impl_exists(impls: Vec<i32>, src_err: str, dst_err: str) -> i64 {
    if str_len(from_impl_call_name(impls, src_err, dst_err)) > 0 { return 1; };
    return 0;
}

#[manual_drop]
fn iter_method_for_vec(mname: str) -> i64 {
    // T2.2 (v0.2.348): method names that map to the typed
    // `vec_<name>_i64` runtime helpers in
    // stdlib/runtime/nucleor_llvm_rt.c. Used by lower_expr's
    // method-dispatch path so `v.map(f)` lowers to
    // `vec_map_i64(v, f)` instead of the unwired `vec_map`.
    // Anything not in this set falls through to the existing
    // `vec_<method>` convention — preserves backward compat with
    // current `.push`, `.pop`, `.len`, `.get`, `.set`, etc.
    // `.iter()` is an identity pass-through that lets users
    // write the Rust idiom `vec.iter().sum()`. Routes to vec_iter_i64
    // which returns the same Vec ptr. Without this, .iter() was
    // unwired and the chain failed at clang link.
    if str_eq(mname, "iter") == 1 { return 1; };
    if str_eq(mname, "map") == 1 { return 1; };
    if str_eq(mname, "filter") == 1 { return 1; };
    if str_eq(mname, "fold") == 1 { return 1; };
    if str_eq(mname, "each") == 1 { return 1; };
    if str_eq(mname, "sum") == 1 { return 1; };
    if str_eq(mname, "min") == 1 { return 1; };
    if str_eq(mname, "max") == 1 { return 1; };
    if str_eq(mname, "contains") == 1 { return 1; };
    if str_eq(mname, "index_of") == 1 { return 1; };
    if str_eq(mname, "reverse") == 1 { return 1; };
    if str_eq(mname, "sort") == 1 { return 1; };
    if str_eq(mname, "clone") == 1 { return 1; };
    if str_eq(mname, "clear") == 1 { return 1; };
    // `.collect()` is the canonical Rust terminator for an
    // iterator chain (`v.iter().map(f).collect()`). It's an identity
    // pass-through here since the prior `.map` already returns a Vec.
    if str_eq(mname, "collect") == 1 { return 1; };
    // `.count()` returns iterator length (mirrors Rust
    // Iterator::count). For Vec it's `v.len()` — runtime helper
    // is `__nucleor_vec_count_i64`, alias for vec_len in the C side.
    if str_eq(mname, "count") == 1 { return 1; };
    // take/skip return fresh Vec views; any/all are
    // boolean predicate terminators. Each routes via iter_method_for_vec
    // → vec_<name>_i64 runtime helper.
    if str_eq(mname, "take") == 1 { return 1; };
    if str_eq(mname, "skip") == 1 { return 1; };
    if str_eq(mname, "any") == 1 { return 1; };
    if str_eq(mname, "all") == 1 { return 1; };
    // `.chain`. Routes to
    // vec_chain_i64 runtime helper.
    if str_eq(mname, "chain") == 1 { return 1; };
    // extended iter surface — position/product/step_by/
    // nth/reduce. Audit doc-#1 §6 closer (still partial, no full
    // Iterator trait — these are the most-reached-for methods).
    if str_eq(mname, "position") == 1 { return 1; };
    if str_eq(mname, "product") == 1 { return 1; };
    if str_eq(mname, "step_by") == 1 { return 1; };
    if str_eq(mname, "nth") == 1 { return 1; };
    if str_eq(mname, "reduce") == 1 { return 1; };
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
fn type_base_name(t: str) -> str {
    // Hot path: this fn runs on every type comparison during type-
    // check. The prior implementation allocated 4-7 substrings per
    // call (one per prefix probe). Replaced with non-allocating
    // str_starts_with checks; the only remaining allocation is the
    // final substring(0, i) when the input contains a generic angle
    // bracket (e.g. "Vec<i32>" → "Vec"). Most calls return the input
    // unchanged or hit the early "fixed<" / scalar paths.
    let mut base: str = t;
    let tlen: i64 = str_len(base);
    if str_starts_with(base, "&mut ") == 1 { base = str_substring(base, 5, tlen); }
    else if tlen >= 1 && str_char_at(base, 0) == 38 { base = str_substring(base, 1, tlen); };
    let slen: i64 = str_len(base);
    if str_starts_with(base, "Box<") == 1 {
        let inner: str = str_substring(base, 4, slen - 1);
        let r: str = type_base_name(inner);
        return r;
    };
    if str_starts_with(base, "fixed<") == 1 { return "i64"; };
    let mut i: i64 = 0;
    while i < slen {
        if str_char_at(base, i) == 60 { return str_substring(base, 0, i); };
        i = i + 1;
    };
    return base;
}

#[manual_drop]
fn type_is_fixed_semantic(t: str) -> i64 {
    let tlen: i64 = str_len(t);
    if tlen == 0 { return 0; };
    let c0: i64 = str_char_at(t, 0);
    if c0 == 38 {
        if str_starts_with(t, "&mut ") == 1 { return type_is_fixed_semantic(str_substring(t, 5, tlen)); };
        return type_is_fixed_semantic(str_substring(t, 1, tlen));
    };
    if c0 == 102 && str_starts_with(t, "fixed<") == 1 { return 1; };
    if c0 == 117 && str_starts_with(t, "ufixed<") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn fixed_type_canonical(t: str) -> str {
    let tlen: i64 = str_len(t);
    if tlen == 0 { return ""; };
    if str_char_at(t, 0) == 38 {
        if str_starts_with(t, "&mut ") == 1 { return strip_spaces(str_substring(t, 5, tlen)); };
        return strip_spaces(str_substring(t, 1, tlen));
    };
    return strip_spaces(t);
}

#[manual_drop]
fn fixed_accepts_integer_storage(actual: str) -> i64 {
    if type_is_fixed_semantic(actual) == 1 { return 0; };
    let b: str = type_base_name(actual);
    if str_eq(b, "i8") == 1 || str_eq(b, "i16") == 1 || str_eq(b, "i32") == 1 || str_eq(b, "i64") == 1 || str_eq(b, "isize") == 1 { return 1; };
    if str_eq(b, "u8") == 1 || str_eq(b, "u16") == 1 || str_eq(b, "u32") == 1 || str_eq(b, "u64") == 1 || str_eq(b, "usize") == 1 { return 1; };
    return 0;
}

// RFC-0024 Phase 2 building block. Extract the FIRST generic
// type arg from a type string. Examples:
//   type_first_arg("Vec<i32>")        → "i32"
//   type_first_arg("Option<f64>")     → "f64"
//   type_first_arg("Result<T, E>")    → "T"   (first arg only; whitespace trimmed)
//   type_first_arg("HashMap<str,i64>")→ "str"
//   type_first_arg("Vec<Vec<i32>>")   → "Vec<i32>" (depth-tracked nesting)
//   type_first_arg("i64")             → ""    (no generic args)
//   type_first_arg("")                → ""
// Used by Phase 2 (constructor type propagation: `let x = Some(value)`
// to derive `Option<T>` where T = static type of value) and Phase 4
// (Vec<T> element type extraction for vec_get/first/last/pop dispatch).
#[manual_drop]
fn type_first_arg(t: str) -> str {
    let tlen: i64 = str_len(t);
    if tlen == 0 { return ""; };
    // Find first '<'
    let mut i: i64 = 0;
    while i < tlen && str_char_at(t, i) != 60 { i = i + 1; };
    if i >= tlen { return ""; };
    let arg_start: i64 = i + 1;
    // Walk to matching '>' or first depth-0 ',' — whichever comes first.
    let mut depth: i64 = 1;
    let mut j: i64 = arg_start;
    let mut arg_end: i64 = 0 - 1;
    while j < tlen && arg_end < 0 {
        let c: i64 = str_char_at(t, j);
        if c == 60 { depth = depth + 1; }
        else if c == 62 {
            depth = depth - 1;
            if depth == 0 { arg_end = j; };
        }
        else if c == 44 && depth == 1 { arg_end = j; };
        j = j + 1;
    };
    if arg_end < 0 { return ""; };
    // Trim leading + trailing spaces.
    let mut s: i64 = arg_start;
    while s < arg_end && str_char_at(t, s) == 32 { s = s + 1; };
    let mut e: i64 = arg_end;
    while e > s && str_char_at(t, e - 1) == 32 { e = e - 1; };
    return str_substring(t, s, e);
}

// RFC-0046 Phase B (ROBO-7) — coordinate-frame phantom-tag extraction.
// Returns the `Frame_*` tag from the FIRST generic argument of `t`, or
// "" when the type carries no recognizable frame tag. Adopters tag
// spatial values with the canonical zero-cost markers from
// `stdlib/rods/kinematics_frame.nr` (`Frame_World`, `Frame_Base`,
// `Frame_Camera`, `Frame_Lidar`, `Frame_IMU`, `Frame_Gripper`,
// `Frame_Map`, `Frame_Odom`, `Frame_Unknown`) — anything else with a
// `Frame_` prefix is also recognized so adopter-defined frames
// (`Frame_ToolTip`, `Frame_PalletA`, …) work the same way.
// Hot-path note: skipped instantly when the type has no `<` (the
// dominant case in type-check); the inner work runs only on
// generic-shaped types.
#[manual_drop]
fn type_frame_tag(t: str) -> str {
    let arg: str = type_first_arg(t);
    if str_len(arg) == 0 { return ""; };
    let s: str = strip_spaces(arg);
    if str_starts_with(s, "Frame_") == 1 { return s; };
    return "";
}

// RFC-0046 Phase B (ROBO-7) — frame-mismatch decision for the type
// checker. Returns 1 when the two types both carry distinct
// `Frame_*` phantom tags on matching base names, and neither side
// is `Frame_Unknown` (the documented migration sentinel that
// matches any frame, RFC-0046 §migration). Returns 0 in every
// other case so the existing type-check paths stay untouched for
// non-frame code.
// The match is intentionally conservative: it requires the base
// names to match (so `Pose<Frame_Camera>` vs `Vec3<Frame_Base>` is
// caught by the regular base-name path, not this one) and at least
// one explicit `Frame_*` tag on each side. This is the smallest
// possible compiler-visible enforcement — Mars-Climate-Orbiter
// frame-confusion class only — without disturbing any other
// generic compatibility rule.
#[manual_drop]
fn frame_mismatch_visible(expected: str, actual: str) -> i64 {
    let etag: str = type_frame_tag(expected);
    if str_len(etag) == 0 { return 0; };
    let atag: str = type_frame_tag(actual);
    if str_len(atag) == 0 { return 0; };
    if str_eq(etag, "Frame_Unknown") == 1 { return 0; };
    if str_eq(atag, "Frame_Unknown") == 1 { return 0; };
    if str_eq(etag, atag) == 1 { return 0; };
    if str_eq(type_base_name(expected), type_base_name(actual)) == 0 { return 0; };
    return 1;
}

#[manual_drop]
fn frame_mismatch_diag_message(action: str, expected: str, actual: str) -> str {
    let etag: str = type_frame_tag(expected);
    let atag: str = type_frame_tag(actual);
    let f1_p1: str = str_concat(action, ": declared frame `");
    let f1_p2: str = str_concat(etag, str_concat("` does not match value frame `", str_concat(atag, "` (declared type `")));
    let f1_p3: str = str_concat(expected, str_concat("` vs value type `", str_concat(actual, "`). Mixing coordinate frames at runtime is the Mars-Climate-Orbiter failure mode — apply the explicit transform (e.g. `kinematics_transform` from stdlib/rods/kinematics.nr) or annotate the binding with the source frame, and re-check.")));
    return str_concat(f1_p1, str_concat(f1_p2, f1_p3));
}

// gparam-binding extraction + substitution for generic-fn
// return-type inference regression.
// 2026-05-01-generic-T-propagation-spsc-option-str.
// Pre-fix: the kind-7 call type-check at line 14413 returned
// `vec_get(sentry, 1)` directly — the literal rtype string with
// gparam placeholders (e.g. "Option<T>") unsubstituted. The
// inferred-let binding then typed `r` as the wrapped placeholder
// rather than the concrete type, which propagated to match-arm
// bindings → TYP-006 on `print(s)` because `s: T` was treated as
// `i64` (the i64-everywhere-ABI default for unknown types).
// `gparam_extract_binding` aligns one (expected, actual) param
// pair and returns the binding (e.g. expected=`Option<T>`,
// actual=`Option<str>` → returns `str`). Returns "" if no clean
// match. Conservative: only handles the common shapes
// `T` direct, `Wrap<T>`, `&Wrap<T>`, `&mut Wrap<T>`. Nested generic
// args (e.g. `Vec<Option<T>>`) recurse via type_first_arg.
// `gparam_extract_binding` is the workhorse; the call-site loop
// builds an alternating [name, binding, ...] map.
#[manual_drop]
fn gparam_extract_binding(expected: str, actual: str, gparam_name: str) -> str {
    if str_len(gparam_name) == 0 { return ""; };
    if str_eq(expected, gparam_name) == 1 { return actual; };
    let exp_base: str = type_base_name(expected);
    let act_base: str = type_base_name(actual);
    if str_eq(exp_base, act_base) == 0 { return ""; };
    let exp_arg: str = type_first_arg(expected);
    let act_arg: str = type_first_arg(actual);
    if str_len(exp_arg) == 0 { return ""; };
    return gparam_extract_binding(exp_arg, act_arg, gparam_name);
}

// Replace whole-word occurrences of `name` in `rtype` with
// `binding`. "Whole-word" means the matched span is bounded by
// non-identifier characters (or string start/end). This is what
// distinguishes `T` from `T_` or `MyT`. Idiomatic Nucleor type
// strings have gparams like `T`, `E`, `K`, `V` — single uppercase
// letters — so a 1-char gparam in `Option<T>` aligns cleanly.
#[manual_drop]
fn substitute_gparam_in_rtype(rtype: str, name: str, binding: str) -> str {
    let nlen: i64 = str_len(name);
    if nlen == 0 || str_len(binding) == 0 { return rtype; };
    let rlen: i64 = str_len(rtype);
    let mut sb: i64 = sb_new();
    let mut p: i64 = 0;
    while p < rlen {
        if p + nlen <= rlen && str_eq_at_len(rtype, p, name, nlen) == 1 {
            let before_ok: i64 = if p == 0 { 1 } else {
                let cb: i64 = str_char_at(rtype, p - 1);
                if is_alnum(cb) == 1 || cb == 95 { 0 } else { 1 }
            };
            let after_ok: i64 = if p + nlen >= rlen { 1 } else {
                let ca: i64 = str_char_at(rtype, p + nlen);
                if is_alnum(ca) == 1 || ca == 95 { 0 } else { 1 }
            };
            if before_ok == 1 && after_ok == 1 {
                sb_append(sb, binding);
                p = p + nlen;
            } else {
                sb_append_char_at(sb, rtype, p);
                p = p + 1;
            };
        } else {
            sb_append_char_at(sb, rtype, p);
            p = p + 1;
        };
    };
    return sb_to_str(sb);
}

#[manual_drop]
fn type_arg_at(t: str, want_idx: i64) -> str {
    let tlen: i64 = str_len(t);
    if tlen == 0 || want_idx < 0 { return ""; };
    let mut lt_pos: i64 = 0 - 1;
    let mut p: i64 = 0;
    while p < tlen {
        if str_char_at(t, p) == 60 { lt_pos = p; p = tlen; };
        p = p + 1;
    };
    if lt_pos < 0 { return ""; };
    let mut depth: i64 = 0;
    let mut arg_idx: i64 = 0;
    let mut arg_start: i64 = lt_pos + 1;
    let mut q: i64 = lt_pos + 1;
    while q < tlen {
        let c: i64 = str_char_at(t, q);
        if c == 60 { depth = depth + 1; }
        else if c == 62 {
            if depth == 0 {
                if arg_idx == want_idx {
                    return strip_spaces(str_substring(t, arg_start, q));
                };
                return "";
            };
            depth = depth - 1;
        }
        else if c == 44 && depth == 0 {
            if arg_idx == want_idx {
                return strip_spaces(str_substring(t, arg_start, q));
            };
            arg_idx = arg_idx + 1;
            arg_start = q + 1;
        };
        q = q + 1;
    };
    return "";
}

#[manual_drop]
fn type_arg_count(t: str) -> i64 {
    let tlen: i64 = str_len(t);
    if tlen == 0 { return 0; };
    let mut lt_pos: i64 = 0 - 1;
    let mut p: i64 = 0;
    while p < tlen {
        if str_char_at(t, p) == 60 { lt_pos = p; p = tlen; };
        p = p + 1;
    };
    if lt_pos < 0 { return 0; };
    let mut depth: i64 = 0;
    let mut count: i64 = 1;
    let mut saw_token: i64 = 0;
    let mut q: i64 = lt_pos + 1;
    while q < tlen {
        let c: i64 = str_char_at(t, q);
        if c == 60 { depth = depth + 1; saw_token = 1; }
        else if c == 62 {
            if depth == 0 {
                if saw_token == 0 { return 0; };
                return count;
            };
            depth = depth - 1;
        }
        else if c == 44 && depth == 0 {
            count = count + 1;
        }
        else if c != 32 && c != 9 && c != 10 && c != 13 {
            saw_token = 1;
        };
        q = q + 1;
    };
    return 0;
}

#[manual_drop]
fn gparams_type_count(pool: Vec<i32>, gparams_lid: i64) -> i64 {
    if gparams_lid < 0 { return 0; };
    let gc: i64 = list_len(pool, gparams_lid);
    let mut gi: i64 = 0;
    let mut out: i64 = 0;
    while gi < gc {
        let gp: str = list_get(pool, gparams_lid, gi);
        if str_len(gp) > 0 && str_char_at(gp, 0) != 63 && str_char_at(gp, 0) != 39 {
            out = out + 1;
        };
        gi = gi + 1;
    };
    return out;
}

#[manual_drop]
fn type_contains_gparam_name(t: str, name: str) -> i64 {
    let nlen: i64 = str_len(name);
    if nlen == 0 { return 0; };
    let tlen: i64 = str_len(t);
    let mut p: i64 = 0;
    while p + nlen <= tlen {
        if str_eq_at_len(t, p, name, nlen) == 1 {
            let before_ok: i64 = if p == 0 { 1 } else {
                let cb: i64 = str_char_at(t, p - 1);
                if is_alnum(cb) == 1 || cb == 95 { 0 } else { 1 }
            };
            let after_ok: i64 = if p + nlen >= tlen { 1 } else {
                let ca: i64 = str_char_at(t, p + nlen);
                if is_alnum(ca) == 1 || ca == 95 { 0 } else { 1 }
            };
            if before_ok == 1 && after_ok == 1 { return 1; };
        };
        p = p + 1;
    };
    return 0;
}

#[manual_drop]
fn type_contains_any_type_gparam(pool: Vec<i32>, gparams_lid: i64, t: str) -> i64 {
    if gparams_lid < 0 || str_len(t) == 0 { return 0; };
    let gc: i64 = list_len(pool, gparams_lid);
    let mut gi: i64 = 0;
    while gi < gc {
        let gp: str = list_get(pool, gparams_lid, gi);
        if str_len(gp) > 0 && str_char_at(gp, 0) != 63 && str_char_at(gp, 0) != 39 {
            if type_contains_gparam_name(t, gp) == 1 { return 1; };
        };
        gi = gi + 1;
    };
    return 0;
}

#[manual_drop]
fn substitute_gparams_from_list(pool: Vec<i32>, gparams_lid: i64, inst_type: str, raw_type: str) -> str {
    if str_len(raw_type) == 0 || gparams_lid < 0 { return raw_type; };
    let mut out: str = raw_type;
    let mut concrete_idx: i64 = 0;
    let gc: i64 = list_len(pool, gparams_lid);
    let mut gi: i64 = 0;
    while gi < gc {
        let gp: str = list_get(pool, gparams_lid, gi);
        if str_len(gp) > 0 && str_char_at(gp, 0) != 63 {
            let arg: str = type_arg_at(inst_type, concrete_idx);
            if str_len(arg) > 0 {
                out = substitute_gparam_in_rtype(out, gp, arg);
            };
            concrete_idx = concrete_idx + 1;
        };
        gi = gi + 1;
    };
    return out;
}

#[manual_drop]
fn struct_field_type_for_inst(pool: Vec<i32>, struct_nid: i64, inst_type: str, fname: str) -> str {
    let raw: str = struct_field_type(pool, struct_nid, fname);
    return substitute_gparams_from_list(pool, node_field(pool, struct_nid, 3), inst_type, raw);
}

#[manual_drop]
fn enum_gparams_for_name(pool: Vec<i32>, prog: i64, enum_name: str) -> i64 {
    let cnt: i64 = list_len(pool, prog);
    let mut i: i64 = 0;
    while i < cnt {
        let nid: i64 = list_get(pool, prog, i);
        if node_kind(pool, nid) == 36 && str_eq(node_field(pool, nid, 1), enum_name) == 1 {
            return node_field(pool, nid, 3);
        };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn match_payload_type_from_scrutinee(scrut_t: str, ename: str, vname: str, bind_idx: i64) -> str {
    if bind_idx != 0 { return ""; };
    let sbase: str = type_base_name(scrut_t);
    if str_eq(sbase, "Option") == 1 && str_eq(ename, "Option") == 1 && str_eq(vname, "Some") == 1 {
        return type_first_arg(scrut_t);
    };
    if str_eq(sbase, "Result") == 1 && str_eq(ename, "Result") == 1 {
        if str_eq(vname, "Ok") == 1 { return type_first_arg(scrut_t); };
        if str_eq(vname, "Err") == 1 { return generic_second_type(scrut_t); };
    };
    return "";
}

#[manual_drop]
fn vec_element_type_is_legacy_cell(elem_t: str) -> i64 {
    if str_eq(elem_t, "i32") == 1 { return 1; };
    return 0;
}

// RFC-0015 phase 1: numeric-type lattice — width + signedness + class.
// type_width:    bit width of a numeric type (0 if non-numeric)
// type_signedness: 1 = signed int, 2 = unsigned int, 3 = float, 0 = other
// type_is_int / type_is_float / type_is_numeric: predicates
// `usize`/`isize` are treated as 64-bit on the only target Nucleor ships
// today (x86_64 Windows). The type lattice will revisit this when the
// LP64/ILP32 split arrives with cross-target sysroots.
#[manual_drop]
fn type_width(t: str) -> i64 {
    let b: str = type_base_name(t);
    if str_eq(b, "i8") == 1 || str_eq(b, "u8") == 1 { return 8; };
    if str_eq(b, "i16") == 1 || str_eq(b, "u16") == 1 { return 16; };
    if str_eq(b, "i32") == 1 || str_eq(b, "u32") == 1 { return 32; };
    if str_eq(b, "i64") == 1 || str_eq(b, "u64") == 1 { return 64; };
    if str_eq(b, "isize") == 1 || str_eq(b, "usize") == 1 { return 64; };
    if str_eq(b, "f8e4m3") == 1 || str_eq(b, "f8e5m2") == 1 { return 8; };
    if str_eq(b, "bf16") == 1 || str_eq(b, "f16") == 1 { return 16; };
    if str_eq(b, "f32") == 1 { return 32; };
    if str_eq(b, "f64") == 1 { return 64; };
    if str_eq(b, "char") == 1 { return 32; };
    if str_eq(b, "bool") == 1 { return 1; };
    return 0;
}
#[manual_drop]
fn type_signedness(t: str) -> i64 {
    let b: str = type_base_name(t);
    if str_eq(b, "i8") == 1 || str_eq(b, "i16") == 1 || str_eq(b, "i32") == 1 || str_eq(b, "i64") == 1 || str_eq(b, "isize") == 1 { return 1; };
    if str_eq(b, "u8") == 1 || str_eq(b, "u16") == 1 || str_eq(b, "u32") == 1 || str_eq(b, "u64") == 1 || str_eq(b, "usize") == 1 || str_eq(b, "char") == 1 { return 2; };
    if str_eq(b, "f8e4m3") == 1 || str_eq(b, "f8e5m2") == 1 || str_eq(b, "bf16") == 1 || str_eq(b, "f16") == 1 || str_eq(b, "f32") == 1 || str_eq(b, "f64") == 1 { return 3; };
    return 0;
}
#[manual_drop]
fn type_is_int(t: str) -> i64 {
    let s: i64 = type_signedness(t);
    if s == 1 || s == 2 { return 1; };
    return 0;
}
#[manual_drop]
fn type_is_float(t: str) -> i64 {
    if type_signedness(t) == 3 { return 1; };
    return 0;
}
#[manual_drop]
fn type_is_numeric(t: str) -> i64 {
    if type_signedness(t) > 0 { return 1; };
    return 0;
}

// T1.1 Phase 3b: byte size of a primitive type. Returns 0 for
// non-primitives (caller must handle struct/array/ref types).
#[manual_drop]
fn type_byte_size(t: str) -> i64 {
    let b: str = type_base_name(t);
    if str_eq(b, "i8") == 1 || str_eq(b, "u8") == 1 || str_eq(b, "bool") == 1 { return 1; };
    if str_eq(b, "i16") == 1 || str_eq(b, "u16") == 1 { return 2; };
    if str_eq(b, "f16") == 1 || str_eq(b, "bf16") == 1 { return 2; };
    if str_eq(b, "i32") == 1 || str_eq(b, "u32") == 1 { return 4; };
    if str_eq(b, "f32") == 1 || str_eq(b, "char") == 1 { return 4; };
    if str_eq(b, "i64") == 1 || str_eq(b, "u64") == 1 { return 8; };
    if str_eq(b, "f64") == 1 { return 8; };
    if str_eq(b, "isize") == 1 || str_eq(b, "usize") == 1 { return 8; };
    if str_eq(b, "i128") == 1 || str_eq(b, "u128") == 1 { return 16; };
    if str_eq(b, "f8e4m3") == 1 || str_eq(b, "f8e5m2") == 1 { return 1; };
    if str_eq(b, "ptr") == 1 { return 8; };
    return 0;
}

// T1.1 Phase 3b: natural alignment of a primitive type (= byte size
// for primitives). For non-primitives returns 0.
#[manual_drop]
fn type_align(t: str) -> i64 {
    return type_byte_size(t);
}

// T1.1 Phase 3b: align `offset` up to `align`. Returns the next
// multiple of `align` >= offset. Assumes align > 0.
#[manual_drop]
fn align_up(offset: i64, align: i64) -> i64 {
    if align <= 1 { return offset; };
    let rem: i64 = offset - (offset / align) * align;
    if rem == 0 { return offset; };
    return offset + (align - rem);
}

// T1.1 Phase 3b: compute byte size of a struct given its repr.
// `repr` is "C" (natural alignment), "packed" (no alignment),
// or "" / "Nucleor" (default — currently 8 bytes per field
// because Nucleor stores everything as i64 slots in a Vec<i32>).
// Returns 0 if the struct has any non-primitive field type the
// computation can't yet handle (nested struct, generic, array).
// Caller can fall back to default size in that case.
#[manual_drop]
fn struct_byte_size(pool: Vec<i32>, struct_nid: i64, repr: str) -> i64 {
    let flist: i64 = node_field(pool, struct_nid, 2);
    let cnt: i64 = list_len(pool, flist);
    if cnt == 0 { return 0; };
    let mut max_align: i64 = 1;
    let mut offset: i64 = 0;
    let is_packed: i64 = if str_eq(repr, "packed") == 1 { 1 } else { 0 };
    let is_c: i64 = if str_eq(repr, "C") == 1 { 1 } else { 0 };
    let is_natural: i64 = if (is_packed + is_c) == 0 { 1 } else { 0 };
    let mut i: i64 = 0;
    while i < cnt {
        let fnode: i64 = list_get(pool, flist, i);
        let ftype: str = node_field(pool, fnode, 2);
        let fsize: i64 = type_byte_size(ftype);
        if fsize == 0 {
            // Unknown / non-primitive field type; fall back to
            // 8 bytes per field (Nucleor's i64-slot representation).
            return cnt * 8;
        };
        if is_packed == 0 {
            let falign: i64 = type_align(ftype);
            if falign > max_align { max_align = falign; };
            offset = align_up(offset, falign);
        };
        offset = offset + fsize;
        i = i + 1;
    };
    if is_natural == 1 {
        // Default Nucleor repr — backing storage is Vec<i32> with
        // one i64 slot per field. Report that observable size.
        return cnt * 8;
    };
    if is_c == 1 {
        // Pad up to the max field alignment so arrays of this struct
        // align correctly. Standard C ABI rule.
        offset = align_up(offset, max_align);
    };
    return offset;
}

// T1.1 Phase 3b: read the `repr` attribute from a struct AST node.
// Looks at the prefix attribute list (if any) for `#[repr(C)]` /
// `#[repr(packed)]`. Returns "C", "packed", or "" if absent.
// Currently uses a source-text scan via the surrounding source —
// will be moved to proper attribute-list AST walking once the
// generic attribute storage lands.
#[manual_drop]
fn struct_repr(source: str, struct_name: str) -> str {
    if str_len(source) == 0 || str_len(struct_name) == 0 { return ""; };
    let needle: str = str_concat("struct ", struct_name);
    let pos: i64 = source_find(source, needle);
    if pos < 0 { return ""; };
    // Look back up to 200 chars for an attribute.
    let look_start: i64 = if pos > 200 { pos - 200 } else { 0 };
    let prefix: str = str_substring(source, look_start, pos);
    if source_find(prefix, "#[repr(packed)]") >= 0 { return "packed"; };
    if source_find(prefix, "#[repr(C)]") >= 0 { return "C"; };
    return "";
}

// Helper: find substring in source (returns byte offset or -1).
#[manual_drop]
fn source_find(haystack: str, needle: str) -> i64 {
    let hlen: i64 = str_len(haystack);
    let nlen: i64 = str_len(needle);
    if nlen == 0 { return 0; };
    if hlen < nlen { return 0 - 1; };
    let mut i: i64 = 0;
    while i <= hlen - nlen {
        if str_eq_at_len(haystack, i, needle, nlen) == 1 { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn type_is_mut_ref(t: str) -> i64 {
    if str_starts_with(t, "&mut ") == 1 { return 1; };
    return 0;
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
fn struct_is_tuple_style(pool: Vec<i32>, struct_nid: i64) -> i64 {
    let flist: i64 = node_field(pool, struct_nid, 2);
    let fc: i64 = list_len(pool, flist);
    if fc == 0 { return 0; };
    let mut i: i64 = 0;
    while i < fc {
        let fname: str = node_field(pool, list_get(pool, flist, i), 1);
        let fnlen: i64 = str_len(fname);
        if fnlen < 3 { return 0; };
        if str_char_at(fname, 0) != 95 { return 0; };
        if str_char_at(fname, 1) != 95 { return 0; };
        let mut di: i64 = 2;
        while di < fnlen {
            let dc: i64 = str_char_at(fname, di);
            if dc < 48 || dc > 57 { return 0; };
            di = di + 1;
        };
        i = i + 1;
    };
    return 1;
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
fn type_direct_value_base(t: str) -> str {
    let s: str = strip_spaces(t);
    let slen: i64 = str_len(s);
    if slen == 0 { return ""; };
    if str_starts_with(s, "&mut ") == 1 { return ""; };
    if str_char_at(s, 0) == 38 { return ""; };
    if str_starts_with(s, "Box<") == 1 { return ""; };
    if str_starts_with(s, "Vec<") == 1 { return ""; };
    if str_starts_with(s, "Option<Box<") == 1 { return ""; };
    if str_starts_with(s, "Option<&") == 1 { return ""; };
    return type_base_name(s);
}

#[manual_drop]
fn struct_reaches_value_cycle(pool: Vec<i32>, structs: Vec<i32>, current_name: str, target_name: str, visited: Vec<i32>, depth: i64) -> i64 {
    if depth > 64 { return 0; };
    if name_in_vec(visited, current_name) == 1 { return 0; };
    visited.push(current_name);
    let si: i64 = struct_find(pool, structs, current_name);
    if si < 0 { return 0; };
    let s_nid: i64 = vec_get(structs, si);
    let flist: i64 = node_field(pool, s_nid, 2);
    let fc: i64 = list_len(pool, flist);
    let mut fi: i64 = 0;
    while fi < fc {
        let f_nid: i64 = list_get(pool, flist, fi);
        let f_type: str = node_field(pool, f_nid, 2);
        let base: str = type_direct_value_base(f_type);
        if str_eq(base, target_name) == 1 { return 1; };
        if str_len(base) > 0 && struct_find(pool, structs, base) >= 0 {
            if struct_reaches_value_cycle(pool, structs, base, target_name, visited, depth + 1) == 1 { return 1; };
        };
        fi = fi + 1;
    };
    return 0;
}

#[manual_drop]
fn type_check_recursive_struct_cycles(pool: Vec<i32>, structs: Vec<i32>, diags: Vec<i32>, source: str) -> i64 {
    let sc: i64 = vec_len(structs);
    let mut si: i64 = 0;
    let mut warns: i64 = 0;
    while si < sc {
        let s_nid: i64 = vec_get(structs, si);
        let sname: str = node_field(pool, s_nid, 1);
        let mut visited: Vec<i32> = Vec::new();
        if struct_reaches_value_cycle(pool, structs, sname, sname, visited, 0) == 1 {
            let lc: Vec<i32> = diag_find_global_linecol(source, sname);
            let msg: str = str_concat("recursive type `", str_concat(sname, "` has infinite size through direct by-value struct fields. Use Box<T>, &T, or another indirection for at least one edge in the cycle."));
            diag_add_ex(diags, "error", "type", "NR036", msg, "<file>", vec_get(lc, 0), vec_get(lc, 1), "");
            warns = warns + 1;
        };
        vec_free(visited);
        si = si + 1;
    };
    return warns;
}

#[manual_drop]
fn expr_struct_type(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let stype: i64 = sym_get(sym, str_concat("__type_", node_field(pool, nid, 1)));
        if stype < 0 { return ""; };
        return stype;
    };
    if kind == 34 { return type_base_name(node_field(pool, nid, 1)); };
    if kind == 90 || kind == 91 { return expr_struct_type(pool, node_field(pool, nid, 1), sym, structs); };
    if kind == 92 { return type_base_name(expr_struct_type(pool, node_field(pool, nid, 1), sym, structs)); };
    if kind == 9 {
        let outer_type: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(outer_type) == 0 { return ""; };
        let si: i64 = struct_find_type(pool, structs, outer_type);
        if si >= 0 { return type_base_name(struct_field_type(pool, vec_get(structs, si), node_field(pool, nid, 2))); };
    };
    // function call result. For `make_v().x`, the
    // operand of the field access is `make_v()` (kind 7); without
    // this branch expr_struct_type returned "" and lower_expr's
    // kind==9 then errored "cannot resolve field access type".
    // Reuses the v0.3.54 __fnret_<NAME> sym entry populated by
    // populate_fn_returns_in_sym at lower_fn entry.
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        let rt: i64 = sym_get(sym, str_concat("__fnret_", fn_name));
        if rt < 0 { return ""; };
        return type_base_name(rt);
    };
    // trait method call returning a struct. For
    // `v.rotated().x` (where `rotated` returns V3), the operand
    // of the field access is `v.rotated()` (kind 8). Same shape
    // as v0.3.60 binop_float_type kind 8 — resolve receiver type,
    // construct mangled name, look up __fnret_<MANGLED>.
    if kind == 8 {
        let recv_nid: i64 = node_field(pool, nid, 1);
        let mname: str = node_field(pool, nid, 2);
        let rtype: str = expr_struct_type(pool, recv_nid, sym, structs);
        if str_len(rtype) == 0 { return ""; };
        let mangled: str = str_concat(rtype, str_concat("__", mname));
        let rt: i64 = sym_get(sym, str_concat("__fnret_", mangled));
        if rt < 0 { return ""; };
        return type_base_name(rt);
    };
    // associated-fn call returning a struct. For
    // `Counter::new().add(10)` the receiver of `.add(10)` is
    // `Counter::new()` (kind 12). The kind-8 method dispatch
    // needs the receiver's struct type to construct the mangled
    // method name; without this branch expr_struct_type returned
    // "" for kind 12 receivers and the chain fell through to
    // `vec_<method>` (clang link `@vec_add undefined`). Lookup
    // mirrors kind 7 — sym entry `__fnret_<TypeName>__<methodname>`.
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let mname12: str = node_field(pool, nid, 2);
        let mangled12: str = str_concat(tname, str_concat("__", mname12));
        let rt12: i64 = sym_get(sym, str_concat("__fnret_", mangled12));
        if rt12 < 0 { return ""; };
        return type_base_name(rt12);
    };
    // Vec indexing result. For `v[0].x` where v
    // is Vec<V3>, the operand of the field access is `v[0]`
    // (kind 10); same compile-error class as v0.3.58. Reuses
    // the v0.3.55 __fulltype_<vname> sym entry that preserves
    // the generic; extracts T from "Vec<T>" via str_substring.
    // also handles fixed-size arrays
    // `[T; N]` (mirrors v0.3.62's binop_float_type extension).
    // Production code uses fixed arrays of structs for known-
    // size pose batches / state vectors.
    if kind == 10 {
        // refactored to use indexed_element_full_type
        // which composes all four operand kinds (3, 9, 7, 10).
        // Returns the BASE name for the struct lookup (callers of
        // expr_struct_type expect the unparameterized struct name).
        let elem_full: str = indexed_element_full_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(elem_full) == 0 { return ""; };
        return type_base_name(elem_full);
    };
    return "";
}

// Enum helpers: pre-populate sym with variant tags and arg counts
#[manual_drop]
fn enum_populate_sym(pool: Vec<i32>, enums: Vec<i32>, sym: Vec<i32>) -> i64 {
    let mut ei: i64 = 0;
    while ei < vec_len(enums) {
        let e_nid: i64 = vec_get(enums, ei);
        let ename: str = node_field(pool, e_nid, 1);
        let vlist: i64 = node_field(pool, e_nid, 2);
        let vcnt: i64 = list_len(pool, vlist);
        let mut vi: i64 = 0;
        while vi < vcnt {
            let v_nid: i64 = list_get(pool, vlist, vi);
            let vname: str = node_field(pool, v_nid, 1);
            let ptypes: i64 = node_field(pool, v_nid, 2);
            let pcount: i64 = list_len(pool, ptypes);
            sym_set(sym, str_concat("__etag_", str_concat(ename, str_concat("_", vname))), vi);
            sym_set(sym, str_concat("__eargs_", str_concat(ename, str_concat("_", vname))), pcount);
            // store ALL payload types for variant-aware
            // print() dispatch. Catches `Msg::Text(s)` where Text(str)
            // and multi-payload `Variant(str, i64)` where each binding
            // gets its own type. Stored as __epayload<i>_<ename>_<vname>.
            // ptypes elements are TYPE STRINGS (per parse_enum_decl)
            // stored directly in the list -- not nodes. list_get
            // returns the string value; no node_field unwrap.
            let mut pi: i64 = 0;
            while pi < pcount {
                let pt: str = list_get(pool, ptypes, pi);
                if str_len(pt) > 0 {
                    sym_set(sym, str_concat("__epayload", str_concat(str_from_int(pi), str_concat("_", str_concat(ename, str_concat("_", vname))))), pt);
                };
                pi = pi + 1;
            };
            vi = vi + 1;
        };
        ei = ei + 1;
    };
    sym_set(sym, "__etag_Option_Some", 0);
    sym_set(sym, "__eargs_Option_Some", 1);
    sym_set(sym, "__etag_Option_None", 1);
    sym_set(sym, "__eargs_Option_None", 0);
    // revised: Result variant tags must match the stdlib
    // `result.nr` convention (Ok=1, Err=0) so the `?` operator works
    // for BOTH compiler-builtin Ok(x)/Err(x) AND
    // stdlib result_ok(x)/result_err(x) calls. Pre-revision had
    // Ok=0/Err=1, which conflicted with the stdlib (used by the
    // existing tests/lang/try_op.nr) — flipping etag tag values is
    // the correct fix; reverting the `?` lowering too. Both Result
    // construction shapes now produce Vec<i32> [tag, payload] with
    // tag=1 on Ok, tag=0 on Err.
    sym_set(sym, "__etag_Result_Ok", 1);
    sym_set(sym, "__eargs_Result_Ok", 1);
    sym_set(sym, "__etag_Result_Err", 0);
    sym_set(sym, "__eargs_Result_Err", 1);
    return 0;
}

// =====================================================================
// LOWERING (moved here from check_type.nr — DUP-5). The IR-lowering pass
// (lower_expr / lower_stmt / lower_fn + the auto-drop machinery and their
// type-resolution helpers) lived in the 10.6k-line check_type god-module;
// it now sits in lower.nr (which is named for exactly this). Same compile
// unit — cross-file calls to the type-checker resolve unchanged.
// =====================================================================
#[manual_drop]
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

// helper for enum-equality dispatch in lower_expr kind-4.
// Returns the etag (>= 0) if the node is a kind-12 associated-fn-call
// matching a registered enum variant constructor (sym key
// `__etag_<tname>_<mname>` populated at enum-collection time).
// Returns -1 otherwise.
#[manual_drop]
fn enum_etag_for_node(pool: Vec<i32>, nid: i64, sym: Vec<i32>) -> i64 {
    if node_kind(pool, nid) != 12 { return 0 - 1; };
    let tname: str = node_field(pool, nid, 1);
    let mname: str = node_field(pool, nid, 2);
    let key: str = str_concat("__etag_", str_concat(tname, str_concat("_", mname)));
    return sym_get(sym, key);
}

#[manual_drop]
fn detect_narrow_chain(pool: Vec<i32>, nid: i64, sym: Vec<i32>, fir: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let k: i64 = node_kind(pool, nid);
    if k == 3 {
        let name: str = node_field(pool, nid, 1);
        let ar: i64 = sym_get(sym, name);
        if ar < 0 { return 0; };
        return ir_fn_get_width(fir, ar);
    };
    if k == 4 {
        let iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        if iop < 2 || iop > 6 { return 0; };
        let lhs_n: i64 = node_field(pool, nid, 2);
        let rhs_n: i64 = node_field(pool, nid, 3);
        let lk: i64 = node_kind(pool, lhs_n);
        let rk: i64 = node_kind(pool, rhs_n);
        let lw: i64 = detect_narrow_chain(pool, lhs_n, sym, fir);
        let rw: i64 = detect_narrow_chain(pool, rhs_n, sym, fir);
        if lw != 0 && lw == rw { return lw; };
        if lw != 0 && rk == 1 { return lw; };
        if rw != 0 && lk == 1 { return rw; };
        return 0;
    };
    return 0;
}

#[manual_drop]
fn arith_width_helper_name(iop: i64, tw: i64, mode: i64) -> str {
    let aw: i64 = if tw > 0 { tw } else { 0 - tw };
    let mut base: str = "";
    if mode == 2 {
        if iop == 2 { base = "saturating_add"; };
        if iop == 3 { base = "saturating_sub"; };
        if iop == 4 { base = "saturating_mul"; };
    };
    if str_len(base) == 0 { return ""; };
    if tw > 0 {
        if aw == 8 { return str_concat(base, "_i8"); };
        if aw == 16 { return str_concat(base, "_i16"); };
        if aw == 32 { return str_concat(base, "_i32"); };
        if aw == 64 { return str_concat(base, "_i64"); };
    } else {
        if aw == 8 { return str_concat(base, "_u8"); };
        if aw == 16 { return str_concat(base, "_u16"); };
        if aw == 32 { return str_concat(base, "_u32"); };
        if aw == 64 { return str_concat(base, "_u64"); };
    };
    return "";
}

// emit a narrow expression chain at width `tw` (sign-
// encoded). Returns the iN result reg without sext-to-i64 wrapping;
// the caller (kind-4 outer dispatch) handles the final sext/zext.
// Pre-condition: detect_narrow_chain(pool, nid, sym, fir) returned
// the same `tw`. Caller is the only entry point — this fn does no
// re-validation.
#[manual_drop]
fn lower_expr_narrow(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, tw: i64) -> Vec<i32> {
    let aw: i64 = if tw > 0 { tw } else { 0 - tw };
    let k: i64 = node_kind(pool, nid);
    if k == 1 {
        let lit: i64 = node_field(pool, nid, 1);
        let cr64: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(cr64, lit));
        let cr: i64 = ctr_next(regs);
        ir_block_add(blk, ir_trunc(cr, cr64, aw));
        return lx_new(cr, blk);
    };
    if k == 3 {
        let name: str = node_field(pool, nid, 1);
        let ar: i64 = sym_get(sym, name);
        let lr: i64 = ctr_next(regs);
        ir_block_add(blk, ir_load_t(lr, ar, aw));
        return lx_new(lr, blk);
    };
    if k == 4 {
        let iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        let mut lp: Vec<i32> = lower_expr_narrow(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, tw);
        let lr: i64 = lx_reg(lp);
        let mut blk2: Vec<i32> = lx_blk(lp);
        let mut rp: Vec<i32> = lower_expr_narrow(pool, node_field(pool, nid, 3), blk2, regs, lbls, sym, fir, tw);
        let rr: i64 = lx_reg(rp);
        let mut blk3: Vec<i32> = lx_blk(rp);
        let nr: i64 = ctr_next(regs);
        let arith_mode: i64 = sym_get(sym, "__arith_mode");
        let sat_helper: str = arith_width_helper_name(iop, tw, arith_mode);
        let strict_intrin: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "1");
        // narrow-width signed div/rem (iop 5/6 with tw>0) routes
        // through `panic_div_iN` / `panic_rem_iN` runtime helpers so the
        // iN_MIN/-1 corner panics with a clean Nucleor message rather than
        // surfacing as Windows STATUS_INTEGER_OVERFLOW (rc=-1073741675) or
        // SIGFPE on POSIX. Mirrors the existing i64 panic_div path; closes
        // Unsigned divisions (tw < 0) keep the raw `udiv` path — there is
        // no MIN/-1 trap for unsigned widths.
        let mut narrow_div_helper: str = "";
        if (iop == 5 || iop == 6) && tw > 0 {
            if iop == 5 {
                if tw == 32 { narrow_div_helper = "panic_div_i32"; };
                if tw == 16 { narrow_div_helper = "panic_div_i16"; };
                if tw == 8 { narrow_div_helper = "panic_div_i8"; };
            } else {
                if tw == 32 { narrow_div_helper = "panic_rem_i32"; };
                if tw == 16 { narrow_div_helper = "panic_rem_i16"; };
                if tw == 8 { narrow_div_helper = "panic_rem_i8"; };
            };
        };
        if str_len(narrow_div_helper) > 0 {
            let lr64: i64 = ctr_next(regs);
            ir_block_add(blk3, ir_sext(lr64, lr, aw));
            let rr64: i64 = ctr_next(regs);
            ir_block_add(blk3, ir_sext(rr64, rr, aw));
            let mut sa: Vec<i32> = Vec::new();
            sa.push(lr64);
            sa.push(rr64);
            let hr: i64 = ctr_next(regs);
            ir_block_add(blk3, ir_call_ex(hr, narrow_div_helper, sa));
            ir_block_add(blk3, ir_trunc(nr, hr, aw));
        } else if str_len(sat_helper) > 0 {
            let lr64: i64 = ctr_next(regs);
            if tw > 0 {
                ir_block_add(blk3, ir_sext(lr64, lr, aw));
            } else {
                ir_block_add(blk3, ir_zext(lr64, lr, aw));
            };
            let rr64: i64 = ctr_next(regs);
            if tw > 0 {
                ir_block_add(blk3, ir_sext(rr64, rr, aw));
            } else {
                ir_block_add(blk3, ir_zext(rr64, rr, aw));
            };
            let mut sa: Vec<i32> = Vec::new();
            sa.push(lr64);
            sa.push(rr64);
            let hr: i64 = ctr_next(regs);
            ir_block_add(blk3, ir_call_ex(hr, sat_helper, sa));
            ir_block_add(blk3, ir_trunc(nr, hr, aw));
        } else if str_eq(strict_intrin, "1") == 1 && arith_mode <= 0 && (iop == 2 || iop == 3 || iop == 4) {
            // pass sign-encoded width `tw` (positive=signed,
            // negative=unsigned) so emit_overflow_arith picks the
            // matching s* or u* intrinsic. Pre-fix used `aw` (abs
            // width) which lost signedness; unsigned narrow arith
            // hit signed-overflow traps incorrectly.
            let trap_lbl: i64 = ctr_next(lbls);
            let cont_lbl: i64 = ctr_next(lbls);
            ir_block_add(blk3, ir_binop_overflow(iop, nr, lr, rr, tw, trap_lbl));
        } else {
            ir_block_add(blk3, ir_binop_t(iop, nr, lr, rr, aw));
        };
        return lx_new(nr, blk3);
    };
    // Unreachable if detect_narrow_chain is correct. Fail-safe: return -1.
    return lx_new(0 - 1, blk);
}

#[manual_drop]
fn lower_expr(pool: Vec<i32>, nid: i64, blk: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let kind: i64 = node_kind(pool, nid);
    // RFC-0015 phase 2: `as` cast. Lower inner, then call __nucleor_as_<T>
    // to actually perform width truncation / sign extension at runtime.
    if kind == 99 {
        let inner_nid: i64 = node_field(pool, nid, 1);
        let inner_lx: Vec<i32> = lower_expr(pool, inner_nid, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let inner_blk: Vec<i32> = lx_blk(inner_lx);
        let inner_r: i64 = lx_reg(inner_lx);
        let target_type: str = node_field(pool, nid, 2);
        // T1.1 Phase 4: full as-cast matrix. If we can detect that
        // source is a float (variable with f32/f64 type, or kind==71
        // f64 literal), dispatch to the float↔int / float↔float
        // converter helper. Otherwise fall through to the existing
        // int-only `as_<T>` mask path.
        let src_ftype: str = binop_float_type(pool, inner_nid, sym, structs);
        let mut conv_helper: str = "";
        // Float → int / float → float dispatch.
        // NUC-FEEDBACK runtime safety / Rust-semantic alignment.
        // Pre-fix `f64 as i64` (and `f64 as u64`, `f32 as i64`, `f32 as
        // u64`) fell through to the bitcast-preserving `as_i64` /
        // `as_u64` helpers. That made `1.5_f64 as i64` return the i64
        // bit pattern of 1.5_f64 (~4607182418800017408) instead of `1`
        // -- a silent miscompute when adopters copy-pasted Rust code
        // expecting numeric truncation semantics.
        // Now: f-source / i64-or-u64 target dispatches to the saturating
        // numeric-truncation helper (matches Rust `as` semantics on
        // overflow). Adopters who genuinely need bit-pattern transit
        // (e.g. pushing f32 values into a Vec<i64> for narrow storage)
        // must use the explicit reinterpret surface: f64_to_bits(x) or
        // f32_to_bits(x). That makes intent local to the call site
        // instead of relying on a non-Rust-semantic `as` quirk.
        if str_eq(src_ftype, "f32") == 1 {
            if str_eq(target_type, "i32") == 1 { conv_helper = "f32_to_i32"; };
            if str_eq(target_type, "i64") == 1 { conv_helper = "f32_to_i64"; };
            if str_eq(target_type, "isize") == 1 { conv_helper = "f32_to_i64"; };
            if str_eq(target_type, "u32") == 1 { conv_helper = "f32_to_u32"; };
            if str_eq(target_type, "u64") == 1 { conv_helper = "f32_to_u64"; };
            if str_eq(target_type, "usize") == 1 { conv_helper = "f32_to_u64"; };
            if str_eq(target_type, "f64") == 1 { conv_helper = "f32_to_f64"; };
            // Lane 1 audit fix (2026-05-08) — close F-NUM-001. Pre-fix
            // `f32 as {i8,u8,i16,u16}` fell through to the integer-mask
            // `as_<T>` path operating on the f32 bit pattern (`v as u8`
            // returned the low byte of the IEEE 754 encoding — for any
            // round f32 with mantissa-low-bits-zero, that's silently 0).
            // RFC-0015 §3.5 promises saturating-truncate semantics for
            // ALL float-to-integer casts; route the four narrow widths
            // through the new __nucleor_f32_to_{i8,u8,i16,u16} helpers.
            if str_eq(target_type, "i8")  == 1 { conv_helper = "f32_to_i8"; };
            if str_eq(target_type, "u8")  == 1 { conv_helper = "f32_to_u8"; };
            if str_eq(target_type, "i16") == 1 { conv_helper = "f32_to_i16"; };
            if str_eq(target_type, "u16") == 1 { conv_helper = "f32_to_u16"; };
        };
        if str_eq(src_ftype, "f64") == 1 {
            if str_eq(target_type, "i32") == 1 { conv_helper = "f64_to_i32"; };
            if str_eq(target_type, "i64") == 1 { conv_helper = "f64_to_i64"; };
            if str_eq(target_type, "isize") == 1 { conv_helper = "f64_to_i64"; };
            if str_eq(target_type, "u32") == 1 { conv_helper = "f64_to_u32"; };
            if str_eq(target_type, "u64") == 1 { conv_helper = "f64_to_u64"; };
            if str_eq(target_type, "usize") == 1 { conv_helper = "f64_to_u64"; };
            if str_eq(target_type, "f32") == 1 { conv_helper = "f64_to_f32"; };
            // Lane 1 audit fix (2026-05-08) — close F-NUM-001 (f64 sister
            // of the f32 narrow-cast routing above).
            if str_eq(target_type, "i8")  == 1 { conv_helper = "f64_to_i8"; };
            if str_eq(target_type, "u8")  == 1 { conv_helper = "f64_to_u8"; };
            if str_eq(target_type, "i16") == 1 { conv_helper = "f64_to_i16"; };
            if str_eq(target_type, "u16") == 1 { conv_helper = "f64_to_u16"; };
        };
        // int → float: detect if source has int type and target is float.
        if str_len(src_ftype) == 0 {
            if str_eq(target_type, "f32") == 1 { conv_helper = "i64_to_f32"; };
            if str_eq(target_type, "f64") == 1 { conv_helper = "i64_to_f64"; };
        };
        if str_len(conv_helper) > 0 {
            let mut cargs: Vec<i32> = Vec::new();
            cargs.push(inner_r);
            let r: i64 = ctr_next(regs);
            ir_block_add(inner_blk, ir_call_ex(r, conv_helper, cargs));
            return lx_new(r, inner_blk);
        };
        // Fall through to existing as_<T> mask helpers (int↔int).
        let mut helper: str = "";
        if str_eq(target_type, "i8") == 1 { helper = "as_i8"; };
        if str_eq(target_type, "i16") == 1 { helper = "as_i16"; };
        if str_eq(target_type, "i32") == 1 { helper = "as_i32"; };
        if str_eq(target_type, "i64") == 1 { helper = "as_i64"; };
        if str_eq(target_type, "isize") == 1 { helper = "as_i64"; };
        if str_eq(target_type, "u8") == 1 { helper = "as_u8"; };
        if str_eq(target_type, "u16") == 1 { helper = "as_u16"; };
        if str_eq(target_type, "u32") == 1 { helper = "as_u32"; };
        if str_eq(target_type, "u64") == 1 { helper = "as_u64"; };
        if str_eq(target_type, "usize") == 1 { helper = "as_u64"; };
        if str_eq(target_type, "f32") == 1 { helper = "as_f32"; };
        if str_eq(target_type, "f64") == 1 { helper = "as_f64"; };
        if str_eq(target_type, "char") == 1 { helper = "as_u32"; };
        if str_len(helper) == 0 {
            return inner_lx;
        };
        let mut conv_args: Vec<i32> = Vec::new();
        conv_args.push(inner_r);
        let r: i64 = ctr_next(regs);
        ir_block_add(inner_blk, ir_call_ex(r, helper, conv_args));
        return lx_new(r, inner_blk);
    };
    if kind == 1 {
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(r, node_field(pool, nid, 1)));
        return lx_new(r, blk);
    };
    if kind == 71 {
        let scaled_r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(scaled_r, node_field(pool, nid, 1)));
        let mut conv_args: Vec<i32> = Vec::new();
        conv_args.push(scaled_r);
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_call_ex(r, "f64_from_scaled", conv_args));
        return lx_new(r, blk);
    };
    // NUC-FEEDBACK-002: f32 literal (kind 73). Same scaled-int
    // encoding as kind 71 but routes through f32_from_scaled so the
    // resulting i64 is the f32 bit pattern, not the f64 one. Without
    // this, `1.0f32` stored an f64 bit pattern in `Vec<f32>` slots and
    // `vec_get` returning to an f32 consumer printed 0.
    if kind == 73 {
        let scaled_r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(scaled_r, node_field(pool, nid, 1)));
        let mut conv_args: Vec<i32> = Vec::new();
        conv_args.push(scaled_r);
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_call_ex(r, "f32_from_scaled", conv_args));
        return lx_new(r, blk);
    };
    // f64 raw-bits literal (AST kind 72). Value IS the i64
    // bit pattern of the parsed float (via str_to_f64 at lex time).
    // Lower as a direct const_int — Nucleor's f64 IS the i64 bit
    // pattern at the runtime ABI level, so no conversion needed.
    if kind == 72 {
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(r, node_field(pool, nid, 1)));
        return lx_new(r, blk);
    };
    if kind == 122 {
        // defensive halt: `?` inside a closure body.
        // Pre-fix the `?` lowering emitted `ret` from the closure function
        // on the Err/None path (correct Rust semantics — `?` in a closure
        // returns from the closure, not the outer fn). BUT Nucleor closures
        // return i64 by ABI convention, not Result<T,E>/Option<T>. So on
        // the Err/None path, the closure returned the heap-pointer of the
        // Err/None Vec as an i64 to its caller — wrong-class silent
        // miscompute: the outer fn saw a garbage integer (heap address)
        // where it expected the closure's i64 payload. Detected via
        // `__closure_id` in sym (set at closure-lowering entry, absent in
        // regular fn scope); halts cleanly with a workaround.
        if sym_get(sym, "__closure_id") >= 0 {
            print("ERROR: `?` operator inside a closure body is not yet supported in Nucleor. Workaround: pull the `?` into the outer fn with an explicit match — `let r = match inner_result() { Ok(v) => v, Err(e) => return Err(e) };` — or use `if let Err(e) = inner_result() { return Err(e); };`.");
            panic("nucleor: `?` inside closure body not yet supported (see ERROR diagnostic above)");
        };
        // RFC-0016 phase 1: `?` postfix operator.
        // tag-convention dispatch for Option vs Result.
        //   Result: Ok=1, Err=0  → tag==0 means err → early return.
        //   Option: Some=0, None=1 → tag==1 means err → early return.
        // Pre-fix used the Result convention unconditionally, so on
        // Option<T>: Some(x) (tag=0) was treated as err and early-
        // returned the whole Option Vec instead of extracting x; AND
        // None (tag=1) hit the ok-path's vec_get(_, 1) which OOB'd
        // the length-1 None Vec at runtime.
        // Regression: option vec out-of-bounds handling.
        // (v0.4.223 deferral note revisited; phase 3c revert in v0.4.224
        // cleared the bootstrap obstacle that blocked the v0.4.223 attempt).
        let inner_lx: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mut cur: Vec<i32> = lx_blk(inner_lx);
        let val_r: i64 = lx_reg(inner_lx);
        let qinner_nid: i64 = node_field(pool, nid, 1);
        let qfull: str = expr_full_type_from_sym(pool, qinner_nid, sym, structs);
        let v225_is_option: i64 = if str_eq(type_base_name(qfull), "Option") == 1 { 1 } else { 0 };
        let v225_err_tag: i64 = if v225_is_option == 1 { 1 } else { 0 };
        let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
        let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(val_r); tag_args.push(zero_r);
        let tag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
        let v225_err_tag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(v225_err_tag_r, v225_err_tag));
        let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, v225_err_tag_r));
        let err_lbl: i64 = ctr_next(lbls); let ok_lbl: i64 = ctr_next(lbls);
        // cmp_r == 1 (tag matches err sentinel) → err_lbl (return); else ok_lbl (extract payload at index 1).
        ir_block_add(cur, ir_br_cond(cmp_r, err_lbl, ok_lbl));
        let mut err_blk: Vec<i32> = ir_block_new(err_lbl); ir_fn_add_block(fir, err_blk);
        let cur_ret_id: i64 = sym_get(sym, "__current_fn_full_return");
        let mut cur_ret: str = "";
        if cur_ret_id >= 0 { cur_ret = cur_ret_id; };
        let mut ret_r: i64 = val_r;
        if str_eq(type_base_name(qfull), "Result") == 1 && str_eq(type_base_name(cur_ret), "Result") == 1 {
            let src_err: str = generic_second_type(qfull);
            let dst_err: str = generic_second_type(cur_ret);
            if str_len(src_err) > 0 && str_len(dst_err) > 0 && str_eq(src_err, dst_err) == 0 {
                let conv_fn: str = from_impl_call_name(trait_impls, src_err, dst_err);
                if str_len(conv_fn) == 0 {
                    print(str_concat("ERROR: error[TRAIT-001]: missing From<", str_concat(src_err, str_concat("> for ", str_concat(dst_err, " conversion required by `?`")))));
                    panic("nucleor: TRAIT-001 missing From conversion for question operator");
                };
                let one_err_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_const_int(one_err_r, 1));
                let mut err_pay_args: Vec<i32> = Vec::new(); err_pay_args.push(val_r); err_pay_args.push(one_err_r);
                let err_pay_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_call_ex(err_pay_r, "vec_get", err_pay_args));
                let mut conv_args: Vec<i32> = Vec::new(); conv_args.push(err_pay_r);
                let conv_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_user_call(conv_r, conv_fn, conv_args));
                let err_vec_r: i64 = ctr_next(regs);
                let mut err_vec_args: Vec<i32> = Vec::new();
                ir_block_add(err_blk, ir_call_ex(err_vec_r, "vec_new", err_vec_args));
                let zero_tag_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_const_int(zero_tag_r, 0));
                let mut push_tag_args: Vec<i32> = Vec::new(); push_tag_args.push(err_vec_r); push_tag_args.push(zero_tag_r);
                let push_tag_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_call_ex(push_tag_r, "vec_push", push_tag_args));
                let mut push_payload_args: Vec<i32> = Vec::new(); push_payload_args.push(err_vec_r); push_payload_args.push(conv_r);
                let push_payload_r: i64 = ctr_next(regs); ir_block_add(err_blk, ir_call_ex(push_payload_r, "vec_push", push_payload_args));
                ret_r = err_vec_r;
            };
        };
        ir_block_add(err_blk, ir_ret(ret_r));
        let mut ok_blk: Vec<i32> = ir_block_new(ok_lbl); ir_fn_add_block(fir, ok_blk);
        let one_r: i64 = ctr_next(regs); ir_block_add(ok_blk, ir_const_int(one_r, 1));
        let mut pay_args: Vec<i32> = Vec::new(); pay_args.push(val_r); pay_args.push(one_r);
        let pay_r: i64 = ctr_next(regs); ir_block_add(ok_blk, ir_call_ex(pay_r, "vec_get", pay_args));
        return lx_new(pay_r, ok_blk);
    };
    if kind == 2 {
        // intern via strtab_intern to dedup repeated literals.
        let idx: i64 = strtab_intern(strtab, fir, node_field(pool, nid, 1));
        let r: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_str(r, idx));
        return lx_new(r, blk);
    };
    if kind == 3 {
        let iname: str = node_field(pool, nid, 1);
        if str_eq(iname, "true") {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(r, 1));
            return lx_new(r, blk);
        };
        if str_eq(iname, "false") {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(r, 0));
            return lx_new(r, blk);
        };
        let ar: i64 = sym_get(sym, iname);
        if ar < 0 {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_fn_ptr(r, iname));
            return lx_new(r, blk);
        };
        // typed-load dispatch.
        // Width keyed by alloca-reg in fir's widths-by-reg table
        // (set at let-stmt time). Two vec_gets per read; no string
        // allocation, no sym_get hash. Sign-encoded: positive=signed
        // (sext), negative=unsigned (zext), 0=untyped (i64 fast path).
        let w_v209: i64 = ir_fn_get_width(fir, ar);
        if w_v209 == 0 {
            let r: i64 = ctr_next(regs);
            ir_block_add(blk, ir_load(r, ar));
            return lx_new(r, blk);
        };
        let aw_v209: i64 = if w_v209 > 0 { w_v209 } else { 0 - w_v209 };
        let nr_v209: i64 = ctr_next(regs);
        ir_block_add(blk, ir_load_t(nr_v209, ar, aw_v209));
        let r_v209: i64 = ctr_next(regs);
        if w_v209 > 0 {
            ir_block_add(blk, ir_sext(r_v209, nr_v209, aw_v209));
        } else {
            ir_block_add(blk, ir_zext(r_v209, nr_v209, aw_v209));
        };
        return lx_new(r_v209, blk);
    };
    if kind == 4 {
        // unified narrow-arith dispatch
        // via tree-recursive width detection. Subsumes v0.4.211 (var+
        // var same-narrow), v0.4.212 (var+literal), AND nested
        // expression chains like `(a + b) * c` where every operand
        // resolves to the same narrow width.
        // Pre-fix flow for nested narrow `(a + b) * c` (i16):
        //   inner: load i16 → sext i64; load i16 → sext i64;
        //          add i16 → sext i64;  (v0.4.211 narrow path)
        //   outer: <i64 add of inner sext + load+sext c>
        //          + call __nucleor_as_i16(i64);  (i64 fallback)
        //   trunc i16; store i16.
        // Post-fix flow (full narrow chain):
        //   load i16 a; load i16 b; add i16; (no sext)
        //   load i16 c; mul i16; (no sext, no helper)
        //   sext i16 to i64;
        //   trunc i16; store i16.
        // Drops both the inner sext/trunc roundtrip AND the outer
        // narrow_via_as helper call for chained narrow arith.
        let v213_w: i64 = detect_narrow_chain(pool, nid, sym, fir);
        if v213_w != 0 {
            let v213_aw: i64 = if v213_w > 0 { v213_w } else { 0 - v213_w };
            let mut v213_p: Vec<i32> = lower_expr_narrow(pool, nid, blk, regs, lbls, sym, fir, v213_w);
            let v213_nr: i64 = lx_reg(v213_p);
            let mut v213_blk: Vec<i32> = lx_blk(v213_p);
            let v213_wr: i64 = ctr_next(regs);
            if v213_w > 0 {
                ir_block_add(v213_blk, ir_sext(v213_wr, v213_nr, v213_aw));
            } else {
                ir_block_add(v213_blk, ir_zext(v213_wr, v213_nr, v213_aw));
            };
            return lx_new(v213_wr, v213_blk);
        };
        // enum-equality dispatch. Pre-v0.3.128, `t == Tag::A`
        // (where t is an enum value) compared the underlying Vec
        // pointers — each Tag::A constructor allocates a fresh Vec, so
        // pointer equality was always false. Silent miscompute for
        // every enum-discriminator comparison adopters wrote.
        // Detect: if BOTH operands resolve to known enum etags (the
        // sym entry `__etag_<tname>_<mname>` populated at enum
        // collection), OR if exactly one is a kind-12 enum-variant
        // constructor and the other is presumed to be an enum value
        // of the same type (var-ref / fn-call result), emit a tag
        // compare instead of pointer compare. Tag is at vec_get(_, 0).
        let bop: i64 = node_field(pool, nid, 1);
        if bop == 30 || bop == 31 {
            let lhs_n: i64 = node_field(pool, nid, 2);
            let rhs_n: i64 = node_field(pool, nid, 3);
            let lhs_etag: i64 = enum_etag_for_node(pool, lhs_n, sym);
            let rhs_etag: i64 = enum_etag_for_node(pool, rhs_n, sym);
            // At least one side is a kind-12 enum constructor with a known etag.
            // The other side is treated as an enum value (its Vec[0] is its tag).
            if lhs_etag >= 0 || rhs_etag >= 0 {
                let mut elp: Vec<i32> = lower_expr(pool, lhs_n, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let elr: i64 = lx_reg(elp);
                let mut ecur: Vec<i32> = lx_blk(elp);
                let mut erp: Vec<i32> = lower_expr(pool, rhs_n, ecur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let err: i64 = lx_reg(erp);
                ecur = lx_blk(erp);
                let zero_r: i64 = ctr_next(regs); ir_block_add(ecur, ir_const_int(zero_r, 0));
                let mut lt_args: Vec<i32> = Vec::new(); lt_args.push(elr); lt_args.push(zero_r);
                let lt_tag: i64 = ctr_next(regs); ir_block_add(ecur, ir_call_ex(lt_tag, "vec_get", lt_args));
                let mut rt_args: Vec<i32> = Vec::new(); rt_args.push(err); rt_args.push(zero_r);
                let rt_tag: i64 = ctr_next(regs); ir_block_add(ecur, ir_call_ex(rt_tag, "vec_get", rt_args));
                let er: i64 = ctr_next(regs);
                let eiop: i64 = if bop == 30 { 7 } else { 8 };
                ir_block_add(ecur, ir_cmpop(eiop, er, lt_tag, rt_tag));
                return lx_new(er, ecur);
            };
            let v085_lhs_t: str = expr_struct_type(pool, lhs_n, sym, structs);
            let v085_rhs_t: str = expr_struct_type(pool, rhs_n, sym, structs);
            if str_len(v085_lhs_t) > 0 && str_eq(strip_spaces(v085_lhs_t), strip_spaces(v085_rhs_t)) == 1 {
                let v085_struct_si: i64 = struct_find_type(pool, structs, v085_lhs_t);
                if v085_struct_si >= 0 {
                    // base-name the type for the helper lookup so
                    // generic instantiations (Pair<i64>, Pair<str>, etc.)
                    // all dispatch through the single Pair__derived_eq
                    // generic helper.
                    let v085_lhs_base: str = type_base_name(v085_lhs_t);
                    let v085_helper: str = str_concat(v085_lhs_base, "__derived_eq");
                    let v085_ret: i64 = sym_get(sym, str_concat("__fnret_", v085_helper));
                    if v085_ret >= 0 {
                        let mut v085_lp: Vec<i32> = lower_expr(pool, lhs_n, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                        let v085_lr: i64 = lx_reg(v085_lp);
                        let mut v085_cur: Vec<i32> = lx_blk(v085_lp);
                        let mut v085_rp: Vec<i32> = lower_expr(pool, rhs_n, v085_cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                        let v085_rr: i64 = lx_reg(v085_rp);
                        v085_cur = lx_blk(v085_rp);
                        let mut v085_args: Vec<i32> = Vec::new();
                        v085_args.push(v085_lr);
                        v085_args.push(v085_rr);
                        let v085_call_r: i64 = ctr_next(regs);
                        ir_block_add(v085_cur, ir_call_ex(v085_call_r, v085_helper, v085_args));
                        if bop == 30 {
                            return lx_new(v085_call_r, v085_cur);
                        } else {
                            // != is `1 - eq`.
                            let v085_one_r: i64 = ctr_next(regs);
                            ir_block_add(v085_cur, ir_const_int(v085_one_r, 1));
                            let v085_inv_r: i64 = ctr_next(regs);
                            ir_block_add(v085_cur, ir_binop_t(3, v085_inv_r, v085_one_r, v085_call_r, 64));
                            return lx_new(v085_inv_r, v085_cur);
                        };
                    };
                };
            };
            let v087_lhs_t: str = expr_struct_type(pool, lhs_n, sym, structs);
            let v087_rhs_t: str = expr_struct_type(pool, rhs_n, sym, structs);
            let v087_lb: str = type_base_name(v087_lhs_t);
            let v087_rb: str = type_base_name(v087_rhs_t);
            let mut v087_helper: str = "";
            if str_eq(v087_lb, "str") == 1 && str_eq(v087_rb, "str") == 1 { v087_helper = "str_eq"; };
            if str_eq(v087_lb, "String") == 1 && str_eq(v087_rb, "String") == 1 { v087_helper = "string_eq"; };
            if str_len(v087_helper) > 0 {
                let mut v087_lp: Vec<i32> = lower_expr(pool, lhs_n, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let v087_lr: i64 = lx_reg(v087_lp);
                let mut v087_cur: Vec<i32> = lx_blk(v087_lp);
                let mut v087_rp: Vec<i32> = lower_expr(pool, rhs_n, v087_cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let v087_rr: i64 = lx_reg(v087_rp);
                v087_cur = lx_blk(v087_rp);
                let mut v087_args: Vec<i32> = Vec::new();
                v087_args.push(v087_lr);
                v087_args.push(v087_rr);
                let v087_call_r: i64 = ctr_next(regs);
                ir_block_add(v087_cur, ir_call_ex(v087_call_r, v087_helper, v087_args));
                if bop == 30 {
                    return lx_new(v087_call_r, v087_cur);
                } else {
                    let v087_one_r: i64 = ctr_next(regs);
                    ir_block_add(v087_cur, ir_const_int(v087_one_r, 1));
                    let v087_inv_r: i64 = ctr_next(regs);
                    ir_block_add(v087_cur, ir_binop_t(3, v087_inv_r, v087_one_r, v087_call_r, 64));
                    return lx_new(v087_inv_r, v087_cur);
                };
            };
        };
        // short-circuit lowering for `&&` (op 36) and `||` (op 37).
        // Pre-v0.3.148, both lowered to bitwise `and i64` / `or i64` of
        // both operand values, evaluating the RHS unconditionally even
        // when the LHS already determined the result. The LOGIC was
        // correct for boolean (0/1) values, but any RHS with side
        // effects or pointer-deref would run when the LHS guard said
        // it shouldn't. The canonical hazard:
        //   if x != 0 && deref(x).field == y { ... }
        // pre-fix evaluates deref(x) even when x == 0, which crashes
        // for any caller relying on short-circuit safety.
        // Fix: emit branch IR. For `A && B`:
        //   1. eval A → a_r
        //   2. cmp a_r != 0 → cond
        //   3. result alloca (in entry block, hoisted via ir_fn_add_entry_alloca)
        //   4. br cond, eval_b, false_lbl
        //   eval_b: eval B → b_r ; cmp b_r != 0 → b_bool ; store b_bool, result ; br merge
        //   false_lbl: store 0, result ; br merge
        //   merge: load result → final
        // For `A || B`: invert — true branch stores 1, false branch
        // evals B and stores its truthy projection.
        // The earlier v0.3.145 attempt at this fix used `ir_block_add` for
        // the result alloca (mid-function placement), which broke stage C
        // self-host with a silent exit on large source. Stage A's compiler
        // didn't tolerate mid-function allocas in the way LLVM expected.
        let bopz: i64 = node_field(pool, nid, 1);
        if bopz == 36 {
            let mut lpz: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let lrz: i64 = lx_reg(lpz);
            let mut lcur: Vec<i32> = lx_blk(lpz);
            let res_slot: i64 = ctr_next(regs);
            ir_fn_add_entry_alloca(fir, res_slot);
            let z1: i64 = ctr_next(regs); ir_block_add(lcur, ir_const_int(z1, 0));
            let lcond: i64 = ctr_next(regs);
            ir_block_add(lcur, ir_cmpop(8, lcond, lrz, z1));
            let r_lbl_a: i64 = ctr_next(lbls);
            let f_lbl_a: i64 = ctr_next(lbls);
            let m_lbl_a: i64 = ctr_next(lbls);
            ir_block_add(lcur, ir_br_cond(lcond, r_lbl_a, f_lbl_a));
            let mut rblk_a: Vec<i32> = ir_block_new(r_lbl_a);
            ir_fn_add_block(fir, rblk_a);
            let mut rpa: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), rblk_a, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let rra: i64 = lx_reg(rpa);
            let rcur_a: Vec<i32> = lx_blk(rpa);
            let z2: i64 = ctr_next(regs); ir_block_add(rcur_a, ir_const_int(z2, 0));
            let rcond_a: i64 = ctr_next(regs);
            ir_block_add(rcur_a, ir_cmpop(8, rcond_a, rra, z2));
            ir_block_add(rcur_a, ir_store(rcond_a, res_slot));
            ir_block_add(rcur_a, ir_br(m_lbl_a));
            let mut fblk_a: Vec<i32> = ir_block_new(f_lbl_a);
            ir_fn_add_block(fir, fblk_a);
            let z3: i64 = ctr_next(regs); ir_block_add(fblk_a, ir_const_int(z3, 0));
            ir_block_add(fblk_a, ir_store(z3, res_slot));
            ir_block_add(fblk_a, ir_br(m_lbl_a));
            let mut mblk_a: Vec<i32> = ir_block_new(m_lbl_a);
            ir_fn_add_block(fir, mblk_a);
            let final_a: i64 = ctr_next(regs);
            ir_block_add(mblk_a, ir_load(final_a, res_slot));
            return lx_new(final_a, mblk_a);
        };
        if bopz == 37 {
            let mut lpo: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let lro: i64 = lx_reg(lpo);
            let mut ocur: Vec<i32> = lx_blk(lpo);
            let res_slot_o: i64 = ctr_next(regs);
            ir_fn_add_entry_alloca(fir, res_slot_o);
            let z1o: i64 = ctr_next(regs); ir_block_add(ocur, ir_const_int(z1o, 0));
            let lcond_o: i64 = ctr_next(regs);
            ir_block_add(ocur, ir_cmpop(8, lcond_o, lro, z1o));
            let t_lbl_o: i64 = ctr_next(lbls);
            let f_lbl_o: i64 = ctr_next(lbls);
            let m_lbl_o: i64 = ctr_next(lbls);
            ir_block_add(ocur, ir_br_cond(lcond_o, t_lbl_o, f_lbl_o));
            let mut tblk_o: Vec<i32> = ir_block_new(t_lbl_o);
            ir_fn_add_block(fir, tblk_o);
            let one_o: i64 = ctr_next(regs); ir_block_add(tblk_o, ir_const_int(one_o, 1));
            ir_block_add(tblk_o, ir_store(one_o, res_slot_o));
            ir_block_add(tblk_o, ir_br(m_lbl_o));
            let mut fblk_o: Vec<i32> = ir_block_new(f_lbl_o);
            ir_fn_add_block(fir, fblk_o);
            let mut rpo: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), fblk_o, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let rro: i64 = lx_reg(rpo);
            let rcur_o: Vec<i32> = lx_blk(rpo);
            let z2o: i64 = ctr_next(regs); ir_block_add(rcur_o, ir_const_int(z2o, 0));
            let rcond_o: i64 = ctr_next(regs);
            ir_block_add(rcur_o, ir_cmpop(8, rcond_o, rro, z2o));
            ir_block_add(rcur_o, ir_store(rcond_o, res_slot_o));
            ir_block_add(rcur_o, ir_br(m_lbl_o));
            let mut mblk_o: Vec<i32> = ir_block_new(m_lbl_o);
            ir_fn_add_block(fir, mblk_o);
            let final_o: i64 = ctr_next(regs);
            ir_block_add(mblk_o, ir_load(final_o, res_slot_o));
            return lx_new(final_o, mblk_o);
        };
        let mut lp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let lr: i64 = lx_reg(lp);
        let mut cur: Vec<i32> = lx_blk(lp);
        let mut rp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let rr: i64 = lx_reg(rp);
        cur = lx_blk(rp);
        let mut iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        // Lane 1 audit fix (2026-05-08) — close C-001 / C-002 / C-007.
        // Detect u64 operands BEFORE the cmp / shift dispatch so the
        // signedness-aware iops (38..41 unsigned cmp, 25 lshr) replace
        // the signed defaults (9..12 slt/sgt/sle/sge, 24 ashr). u64
        // detection is conservative — if either operand carries a u64
        // type tag (variable annotation, kind-99 cast target, etc.) the
        // compare / shift is unsigned. eq/ne (iops 7/8) and shl (iop
        // 23) are signedness-agnostic and stay unchanged. The float
        // dispatch immediately below preempts u64 handling for f32/f64
        // operands (mixed u64+float is already a separate type error
        // upstream).
        let u64_cmp_v0508: i64 = if iop >= 9 && iop <= 12 || iop == 24 {
            if binop_u64_type(pool, node_field(pool, nid, 2), sym, structs) == 1 { 1 }
            else if binop_u64_type(pool, node_field(pool, nid, 3), sym, structs) == 1 { 1 }
            else { 0 }
        } else { 0 };
        if u64_cmp_v0508 == 1 {
            if iop == 9  { iop = 38; }
            else if iop == 10 { iop = 39; }
            else if iop == 11 { iop = 40; }
            else if iop == 12 { iop = 41; }
            else if iop == 24 { iop = 25; };
        };
        let r: i64 = ctr_next(regs);
        // T1.1 Phase 5: dispatch float binop to runtime helper instead
        // of integer binop. Detection: either operand is a variable
        // declared as f32/f64, or a kind==71 float literal. The f32
        // type wins precedence (matches narrowing cast rule). Only
        // applies to + - * / and the comparison ops.
        let lt: str = binop_float_type(pool, node_field(pool, nid, 2), sym, structs);
        let rt: str = binop_float_type(pool, node_field(pool, nid, 3), sym, structs);
        let mut ftype: str = "";
        if str_eq(lt, "f32") == 1 { ftype = "f32"; }
        else if str_eq(rt, "f32") == 1 { ftype = "f32"; }
        else if str_eq(lt, "f64") == 1 { ftype = "f64"; }
        else if str_eq(rt, "f64") == 1 { ftype = "f64"; };
        let helper: str = float_binop_helper(iop, ftype);
        if str_len(helper) > 0 {
            let mut conv_args: Vec<i32> = Vec::new();
            conv_args.push(lr);
            conv_args.push(rr);
            ir_block_add(cur, ir_call_ex(r, helper, conv_args));
        } else if is_cmp_or_logic(iop) == 1 { ir_block_add(cur, ir_cmpop(iop, r, lr, rr)); }
        else {
            // NUC-FEEDBACK runtime safety -- strict-
            // arithmetic via panic_*_i64 helpers.
            // REVERTED to OPT-IN default. Strict-by-default
            // (every `+`/`-`/`*` via runtime call) caused an 8.5x
            // self-build perf regression (4-10s -> 85s) because the
            // compiler's own arithmetic loops paid the function-call
            // overhead. The safety case is real, but the perf cost
            // was unacceptable for the common adopter compile flow.
            // New default: native LLVM `add nsw` (silent wrap on
            // overflow). Opt IN to strict via NUCLEOR_INT_STRICT_ARITH=1
            // for production / safety-critical builds. Other v0.3.x
            // safety improvements (vec OOB, hashmap missing key, OOM,
            // NaN cast, etc.) stay default-on because they have
            // negligible perf impact.
            let strict_env: str = env_get_or("NUCLEOR_INT_STRICT_ARITH", "");
            let mut strict: i64 = 0;
            if str_eq(strict_env, "1") == 1 { strict = 1; };
            let mut sh: str = "";
            // Lane 1 audit fix (2026-05-08) — close C-002 / C-003. Extend
            // u64 detection beyond add/sub/mul (the v0.4.886 surface) to
            // cover div/rem and the right-shift dispatch so panic_div_u64
            // / panic_rem_u64 / panic_shr_u64 are routed instead of the
            // signed-i64 helpers. The unsigned-cmp / lshr remap upstairs
            // already handled the comparison + non-panic shift paths.
            let mut u64_binop_v886: i64 = 0;
            if iop == 2 || iop == 3 || iop == 4 || iop == 5 || iop == 6 || iop == 24 || iop == 25 {
                if binop_u64_type(pool, node_field(pool, nid, 2), sym, structs) == 1 {
                    u64_binop_v886 = 1;
                } else if binop_u64_type(pool, node_field(pool, nid, 3), sym, structs) == 1 {
                    u64_binop_v886 = 1;
                };
            };
            // Pre-existing v0.4.886 gate kept the strict + / - / * u64 helpers
            // gated on `__has_u64_v886`. The div/rem/shr routes don't need
            // that gate (they're unconditional safety helpers, not opt-in
            // strict-arith ones), but preserve the v0.4.886 sym-gate for
            // the original three operators to avoid signature drift in
            // existing fixtures.
            let strict_u64_v886: i64 = if sym_get(sym, "__has_u64_v886") == 1 && u64_binop_v886 == 1 { 1 } else { 0 };
            if strict == 1 {
                if strict_u64_v886 == 1 {
                    if iop == 2 { sh = "panic_add_u64"; };
                    if iop == 3 { sh = "panic_sub_u64"; };
                    if iop == 4 { sh = "panic_mul_u64"; };
                } else {
                    if iop == 2 { sh = "panic_add"; };
                    if iop == 3 { sh = "panic_sub"; };
                    if iop == 4 { sh = "panic_mul"; };
                };
                if iop == 5 { sh = if u64_binop_v886 == 1 { "panic_div_u64" } else { "panic_div" }; };
                if iop == 6 { sh = if u64_binop_v886 == 1 { "panic_rem_u64" } else { "panic_rem" }; };
                // shifts get the panic surface too. Iops 23 (shl)
                // and 24 (ashr) for << and >>. Pre-fix amounts >= 64 or < 0
                // produced LLVM poison (observable but not silent); now they
                // panic with operands. Lane 1 audit (2026-05-08): u64
                // right shift routes to panic_shr_u64 (logical) instead of
                // panic_shr_i64 which sign-extends. The cmp/lshr remap up
                // top promotes iop 24 → 25 for u64 LHS, so the iop==24 line
                // here only fires for signed-i64 right shift; iop==25 is
                // the new unsigned right-shift form and uses panic_shr_u64
                // when strict.
                if iop == 23 { sh = "panic_shl"; };
                if iop == 24 { sh = "panic_shr"; };
                if iop == 25 { sh = "panic_shr_u64"; };
            };
            let arith_mode_explicit: i64 = sym_get(sym, "__arith_mode");
            if arith_mode_explicit == 1 && (iop == 2 || iop == 3 || iop == 4) {
                sh = "";
            };
            // per-op saturating dispatch. When inside a
            // `saturating { ... }` block (kind-52 with mode==2 sets
            // sym["__arith_mode"]=2 in the body's sym before lowering),
            // route +/-/* to the saturating runtime helpers. Pre-fix
            // (v0.4.105 .. v0.4.152) the block clamped only its final
            // value to i32; multi-step inner arithmetic still wrapped
            // at the i64 level, so `saturating { (max + 1) - 5 }` gave
            // a wrapped value pinned to i32 instead of `max - 5`.
            if iop == 2 || iop == 3 || iop == 4 {
                if arith_mode_explicit == 2 {
                    if iop == 2 { sh = "saturating_add"; };
                    if iop == 3 { sh = "saturating_sub"; };
                    if iop == 4 { sh = "saturating_mul"; };
                };
            };
            // div/mod ALWAYS use the panic helper, regardless of
            // NUCLEOR_INT_STRICT_ARITH. Pre-fix `let z = 0; let q = 10/z;`
            // (variable divisor zero — v0.4.74's literal-only NUM-009
            // didn't catch it) emitted raw `sdiv i64 10, 0` → SIGFPE
            // → exit 127 with no error message. The panic_div_i64 helper
            // already exists with a nice message; div is rare enough in
            // hot loops that the function-call overhead is negligible
            // (the v0.3.220 perf-revert was for + - * which dominate
            // tight numeric loops, not div).
            // Lane 1 audit fix (2026-05-08) — close C-003: route u64 div
            // / rem to the unsigned helpers so high-bit-set operands are
            // not silently miscompiled by the signed `/` / `%` in the
            // i64 helper.
            if iop == 5 { sh = if u64_binop_v886 == 1 { "panic_div_u64" } else { "panic_div" }; };
            if iop == 6 { sh = if u64_binop_v886 == 1 { "panic_rem_u64" } else { "panic_rem" }; };
            // variable-RHS shifts default to checked runtime
            // helpers. Literal in-range shifts keep raw LLVM for tight
            // bit loops; non-literal RHS can be <0 or >=64 at runtime,
            // which is LLVM poison for shl/ashr. Explicit opt-out is
            // available for low-level kernels that mask externally.
            // Lane 1 audit fix (2026-05-08) — close C-002: iop 25 (lshr,
            // u64 right shift) joins the shift-panic dispatch so
            // non-literal RHS routes to panic_shr_u64 instead of leaving
            // raw LLVM that would still be lshr-correct but unguarded.
            let shift_lenient: str = env_get_or("NUCLEOR_SHIFT_LENIENT", "0");
            if str_eq(shift_lenient, "1") == 0 && (iop == 23 || iop == 24 || iop == 25) {
                let rhs_shift: i64 = node_field(pool, nid, 3);
                let shift_const: Vec<i32> = const_i64_expr(pool, rhs_shift, sym);
                let shift_have: i64 = vec_get(shift_const, 0);
                let shift_amt: i64 = vec_get(shift_const, 1);
                let shift_safe_lit: i64 = if shift_have == 1 && shift_amt >= 0 && shift_amt < 64 { 1 } else { 0 };
                if shift_safe_lit == 0 {
                    if iop == 25 { sh = "panic_shr_u64"; };
                    if iop == 23 { sh = "panic_shl"; };
                    if iop == 24 { sh = "panic_shr"; };
                };
            };
            let strict_intrin: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "1");
            if str_eq(strict_intrin, "1") == 1 && arith_mode_explicit <= 0 && (iop == 2 || iop == 3 || iop == 4) {
                let trap_lbl: i64 = ctr_next(lbls);
                let cont_lbl: i64 = ctr_next(lbls);
                let trap_width: i64 = if u64_binop_v886 == 1 { 0 - 64 } else { 0 };
                ir_block_add(cur, ir_binop_overflow(iop, r, lr, rr, trap_width, trap_lbl));
            } else if str_len(sh) > 0 {
                let mut sa: Vec<i32> = Vec::new();
                sa.push(lr); sa.push(rr);
                ir_block_add(cur, ir_call_ex(r, sh, sa));
            } else {
                ir_block_add(cur, ir_binop(iop, r, lr, rr));
            };
        };
        return lx_new(r, cur);
    };
    if kind == 5 {
        // dispatch to float-or-int subtract based on
        // operand type. Pre-v0.3.57 always used integer 0 + integer
        // sub, which mis-computed for f64 operands (subtracts the
        // f64 bit pattern as an i64 → garbage). Now: if operand
        // resolves to f32/f64 via binop_float_type, emit
        // f<T>_from_scaled(0) + f<T>_sub(zr, opr); otherwise the
        // legacy int path.
        let inner_nid: i64 = node_field(pool, nid, 1);
        let neg_ftype: str = binop_float_type(pool, inner_nid, sym, structs);
        let mut op_p: Vec<i32> = lower_expr(pool, inner_nid, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let opr: i64 = lx_reg(op_p);
        let cur: Vec<i32> = lx_blk(op_p);
        let r: i64 = ctr_next(regs);
        if str_len(neg_ftype) > 0 {
            //  pre-fix unary minus on f64/f32
            // lowered as `f<T>_sub(0.0, opr)` — IEEE 754 returns `+0.0`
            // for `0 - (-0)`, losing the sign bit. So `let z: f64 =
            // -0.0; print_f64(1.0 / z)` printed `+inf` instead of the
            // correct `-inf`.
            // Fix uses XOR with the IEEE 754 sign bit (the canonical
            // sign-bit-flip semantics of unary minus). For f64, sign
            // bit is bit 63 → mask `0x8000000000000000` = i64::MIN.
            // For f32, sign bit is bit 31 → mask `0x80000000`. The
            // i64-everywhere ABI stores the f-bit-pattern as an i64,
            // so bitwise XOR on the i64 register is the fp negation.
            // No new runtime declares (sidesteps the v0.6.48-attempt-1
            // bootstrap-cycle hole that the earlier f<T>_neg helper
            // approach hit).
            let sign_bit: i64 = if str_eq(neg_ftype, "f32") == 1 { 2147483648 } else { const_i64_min() };
            let mask_reg: i64 = ctr_next(regs);
            ir_block_add(cur, ir_const_int(mask_reg, sign_bit));
            ir_block_add(cur, ir_binop(15, r, opr, mask_reg));
        } else {
            //  canonical Rust literal
            // `-9223372036854775808` (= i64::MIN) parses as unary-minus
            // applied to the literal `9223372036854775808`. The lexer
            // wraps `2^63` to i64::MIN at storage time, so the inner
            // literal already holds i64::MIN. Without this guard, the
            // strict-intrin default sends i64::MIN through panic_neg,
            // which correctly panics on `-(i64::MIN)` — but for the
            // CANONICAL i64::MIN literal in source, that's a false-
            // panic; the user wrote the textual representation of
            // i64::MIN and means i64::MIN, not "negate the value
            // i64::MIN". Detect immediate-literal-equal-to-i64::MIN
            // and short-circuit by emitting the constant directly.
            // `-(some_var_holding_min)` still routes through panic_neg
            // because the inner is a kind-3 reference, not a kind-1
            // literal.
            if node_kind(pool, inner_nid) == 1 && node_field(pool, inner_nid, 1) == const_i64_min() {
                ir_block_add(cur, ir_const_int(r, const_i64_min()));
                return lx_new(r, cur);
            };
            // same opt-in default as binop. NUCLEOR_INT_STRICT_ARITH=1
            // routes -x for i64 through panic_neg; default is native sub.
            //  pre-fix `neg(-i64::MIN)` silently wrapped to
            // i64::MIN — asymmetric with `+`/`*` which already panic by
            // default via NUCLEOR_INT_STRICT_INTRIN=1 (line ~18724). Now
            // unary-neg also consults NUCLEOR_INT_STRICT_INTRIN with the
            // same default (`1`), so `-x` for i64 routes through
            // panic_neg by default. Setting NUCLEOR_INT_STRICT_INTRIN=0
            // restores the legacy native-sub path. NUCLEOR_INT_STRICT_ARITH
            // (the older opt-in env var) is still honored on the `=1`
            // path for backward-compat.
            let strict_env: str = env_get_or("NUCLEOR_INT_STRICT_ARITH", "");
            let strict_intrin_env: str = env_get_or("NUCLEOR_INT_STRICT_INTRIN", "1");
            let mut strict: i64 = 0;
            if str_eq(strict_env, "1") == 1 { strict = 1; };
            if str_eq(strict_intrin_env, "1") == 1 { strict = 1; };
            if strict == 1 {
                let mut na: Vec<i32> = Vec::new();
                na.push(opr);
                ir_block_add(cur, ir_call_ex(r, "panic_neg", na));
            } else {
                let zr: i64 = ctr_next(regs);
                ir_block_add(cur, ir_const_int(zr, 0));
                ir_block_add(cur, ir_binop(3, r, zr, opr));
            };
        };
        return lx_new(r, cur);
    };
    if kind == 6 {
        let mut op_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let opr: i64 = lx_reg(op_p);
        let cur: Vec<i32> = lx_blk(op_p);
        let zr: i64 = ctr_next(regs);
        ir_block_add(cur, ir_const_int(zr, 0));
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_cmpop(7, r, opr, zr));
        return lx_new(r, cur);
    };
    if kind == 90 || kind == 91 || kind == 92 {
        return lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
    };
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        let mut tup_si: i64 = 0 - 1;
        let fnlen_v074: i64 = str_len(fn_name);
        if fnlen_v074 > 0 {
            let fnc0_v074: i64 = str_char_at(fn_name, 0);
            if fnc0_v074 >= 65 && fnc0_v074 <= 90 {
                tup_si = struct_find_type(pool, structs, fn_name);
            };
        };
        if tup_si >= 0 {
            let tup_snid: i64 = vec_get(structs, tup_si);
            if struct_is_tuple_style(pool, tup_snid) == 1 {
                let tup_args: i64 = node_field(pool, nid, 2);
                let tup_argc: i64 = list_len(pool, tup_args);
                let tup_vr: i64 = ctr_next(regs);
                let mut tup_new_args: Vec<i32> = Vec::new();
                ir_block_add(blk, ir_call_ex(tup_vr, "vec_new", tup_new_args));
                let mut tup_cur: Vec<i32> = blk;
                let mut tup_i: i64 = 0;
                while tup_i < tup_argc {
                    let mut tup_vp: Vec<i32> = lower_expr(pool, list_get(pool, tup_args, tup_i), tup_cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let tup_val_r: i64 = lx_reg(tup_vp);
                    tup_cur = lx_blk(tup_vp);
                    let mut tup_push_args: Vec<i32> = Vec::new();
                    tup_push_args.push(tup_vr);
                    tup_push_args.push(tup_val_r);
                    let tup_pr: i64 = ctr_next(regs);
                    ir_block_add(tup_cur, ir_call_ex(tup_pr, "vec_push", tup_push_args));
                    tup_i = tup_i + 1;
                };
                return lx_new(tup_vr, tup_cur);
            };
        };
        // T1.1 Phase 3b: sizeof_struct(StructName) — compile-time
        // constant. Looks up the struct and returns its byte size
        // computed per its repr attribute (default Nucleor / C / packed).
        if str_eq(fn_name, "sizeof_struct") {
            let sa: i64 = node_field(pool, nid, 2);
            if list_len(pool, sa) == 1 {
                let arg_nid: i64 = list_get(pool, sa, 0);
                if node_kind(pool, arg_nid) == 3 {
                    let sname: str = node_field(pool, arg_nid, 1);
                    let si: i64 = struct_find_type(pool, structs, sname);
                    if si >= 0 {
                        let snode: i64 = vec_get(structs, si);
                        // Default Nucleor repr: backing storage is
                        // Vec<i32> with one i64 slot per field.
                        // repr(C) / repr(packed) variants land when
                        // attribute-preservation plumbing is wired.
                        let sz: i64 = struct_byte_size(pool, snode, "");
                        let r: i64 = ctr_next(regs);
                        ir_block_add(blk, ir_const_int(r, sz));
                        return lx_new(r, blk);
                    };
                };
            };
        };
        if str_eq(fn_name, "sanitize") {
            let args_list: i64 = node_field(pool, nid, 2);
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
        };
        if str_eq(fn_name, "grad") {
            let g_args: i64 = node_field(pool, nid, 2);
            if list_len(pool, g_args) >= 2 {
                let fn_arg: i64 = list_get(pool, g_args, 0);
                let mut xp: Vec<i32> = lower_expr(pool, list_get(pool, g_args, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let x_r: i64 = lx_reg(xp);
                let cur: Vec<i32> = lx_blk(xp);
                let h_ip: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(h_ip, 0));
                let h_fm: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(h_fm, 1));
                let mut h_args: Vec<i32> = Vec::new(); h_args.push(h_ip); h_args.push(h_fm);
                let h_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(h_r, "rods_f64_encode", h_args));
                let mut add_args: Vec<i32> = Vec::new(); add_args.push(x_r); add_args.push(h_r);
                let xph: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(xph, "rods_f64_add", add_args));
                let mut sub_args: Vec<i32> = Vec::new(); sub_args.push(x_r); sub_args.push(h_r);
                let xmh: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(xmh, "rods_f64_sub", sub_args));
                let target_fn: str = node_field(pool, fn_arg, 1);
                let mut fp_args: Vec<i32> = Vec::new(); fp_args.push(xph);
                let f_plus: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(f_plus, target_fn, fp_args));
                let mut fm_args: Vec<i32> = Vec::new(); fm_args.push(xmh);
                let f_minus: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(f_minus, target_fn, fm_args));
                let mut diff_args: Vec<i32> = Vec::new(); diff_args.push(f_plus); diff_args.push(f_minus);
                let diff: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(diff, "rods_f64_sub", diff_args));
                let mut twoh_args: Vec<i32> = Vec::new(); twoh_args.push(h_r); twoh_args.push(h_r);
                let two_h: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(two_h, "rods_f64_add", twoh_args));
                let mut div_args: Vec<i32> = Vec::new(); div_args.push(diff); div_args.push(two_h);
                let result: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(result, "rods_f64_div", div_args));
                return lx_new(result, cur);
            };
        };
        let args_list: i64 = node_field(pool, nid, 2);
        let argc: i64 = list_len(pool, args_list);
        let mut arg_regs: Vec<i32> = Vec::new();
        let mut ai: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while ai < argc {
            let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            arg_regs.push(lx_reg(ap));
            cur = lx_blk(ap);
            ai = ai + 1;
        };
        // NUC-FEEDBACK-008 — type-aware `print()` dispatch.
        // Pre-v0.3.143, every `print(arg)` call lowered to
        // __nucleor_print_str(arg) regardless of arg's type. When arg
        // was an i64 (e.g. a token count, a counter, a literal), the
        // string helper dereferenced the integer as a `const char *`
        // and crashed with SIGSEGV — visible to the adopter as a
        // silent program termination mid-output (exit code 1 or 139,
        // remaining prints just gone). Same hazard class as the
        // contextual-kw silent miscompiles: a real call you wrote
        // produces nothing useful and no diagnostic.
        // Fix: when the call is `print` with a single arg whose static
        // type is an int / float / bool, dispatch to the typed runtime
        // helper instead of __nucleor_print_str. Default falls through
        // to the existing __nucleor_print_str path for str / unknown.
        if str_eq(fn_name, "print") == 1 {
            // emit a diagnostic when print is called with > 1
            // argument. Pre-fix, the C ABI for the runtime helper
            // __nucleor_print_str(ptr) silently accepted extra args
            // (varargs-style behaviour) and dropped all but the first.
            // Adopters writing `print("x is", x)` got "x is" with no
            // diagnostic that x was lost. Same hazard class as the
            if argc > 1 {
                print(str_concat("ERROR: print() takes exactly 1 argument (got ", str_concat(str_from_int(argc), "). For multi-arg formatting, use print!/println! macros (e.g. println!(\"x={} y={}\", x, y)). The bare print() function lowers to __nucleor_print_str/i64/f64/bool and only consumes the first arg.")));
                // pre-fix the lowering kept going with argc==1
                // path — the second+ args were silently dropped from
                // the binary. Adopter writing `print("x is", x)` got
                // "x is" with no diagnostic that x was lost. Halt now.
                panic(str_concat("nucleor: print() takes exactly 1 arg (got ", str_concat(str_from_int(argc), ")")));
            };
            // print() with no args was silently lowered to
            // __nucleor_print_str(garbage_ptr), SIGSEGV at runtime.
            // Sister to v0.4.35 (print >1 arg): same hazard class —
            // adopter writing `print()` (likely a typo for `print("")`
            // or a leftover after deleting the arg) got a runtime
            // segfault with no compile-time signal. Halt cleanly.
            if argc == 0 {
                print("ERROR: print() takes exactly 1 argument (got 0). Use `print(\"\")` for an empty line, or supply the value to print. The bare print() function lowers to __nucleor_print_str/i64/f64/bool and consumed-zero-args produces a garbage-pointer SIGSEGV at runtime pre-v0.4.121.");
                panic("nucleor: print() takes exactly 1 arg (got 0 — pre-v0.4.121 this SIGSEGV'd at runtime with no compile-time signal)");
            };
            if argc == 1 {
                let parg_nid: i64 = list_get(pool, args_list, 0);
                let parg_kind: i64 = node_kind(pool, parg_nid);
                let mut p_helper: str = "";
                // Int literal (kind 1) and f64 literals (kinds 71/72).
                if parg_kind == 1 { p_helper = "__nucleor_print_i64"; };
                if parg_kind == 71 { p_helper = "__nucleor_print_f64"; };
                if parg_kind == 72 { p_helper = "__nucleor_print_f64"; };
                // Var ref (kind 3): look up __type_<name> in sym.
                if parg_kind == 3 {
                    let pvname: str = node_field(pool, parg_nid, 1);
                    let pvtype: i64 = sym_get(sym, str_concat("__type_", pvname));
                    if pvtype >= 0 {
                        let pvts: str = pvtype;
                        if str_eq(pvts, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pvts, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pvts, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pvts, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                    };
                };
                // Fn-call result (kind 7): look up __fnret_<name> in sym.
                if parg_kind == 7 {
                    let pfn_name: str = node_field(pool, parg_nid, 1);
                    let pfn_rt: i64 = sym_get(sym, str_concat("__fnret_", pfn_name));
                    if pfn_rt >= 0 {
                        let prts: str = pfn_rt;
                        if str_eq(prts, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(prts, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(prts, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(prts, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                    };
                    // builtin runtime helper fallback for
                    // direct calls. Mirrors the v0.3.168 fallback for
                    // method calls (kind 8). Pre-fix
                    // print(hashmap_get(h, "k")) SIGSEGV'd because no
                    // __fnret_hashmap_get entry exists. Hardcoded list
                    // of well-known runtime helpers with deterministic
                    // i64/bool return types.
                    if str_len(p_helper) == 0 {
                        // HashMap<K, V>.get / hashmap_get
                        // value-type lookup. Same hazard class as the
                        let hm_val_callee: i64 = if str_eq(pfn_name, "hashmap_get") == 1
                            || str_eq(pfn_name, "hashmap_get_or") == 1
                            || str_eq(pfn_name, "hashmap_remove") == 1
                            || str_eq(pfn_name, "btreemap_get") == 1 { 1 } else { 0 };
                        if hm_val_callee == 1 {
                            let pfn_args_h: i64 = node_field(pool, parg_nid, 2);
                            if list_len(pool, pfn_args_h) > 0 {
                                let recv_h_nid: i64 = list_get(pool, pfn_args_h, 0);
                                let mut recv_h_full: str = "";
                                if node_kind(pool, recv_h_nid) == 3 {
                                    let rh_name: str = node_field(pool, recv_h_nid, 1);
                                    let rh_t: i64 = sym_get(sym, str_concat("__fulltype_", rh_name));
                                    if rh_t >= 0 { recv_h_full = rh_t; };
                                };
                                let v_type: str = generic_second_type(recv_h_full);
                                if str_len(v_type) > 0 {
                                    let v_base: str = type_base_name(v_type);
                                    if str_eq(v_base, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(v_base, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                                    if str_eq(v_base, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                                    if str_eq(v_base, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                                    // str -> fall through to default print_str.
                                };
                            };
                        };
                    };
                    if str_len(p_helper) == 0 {
                        // NUC-FEEDBACK-006 --
                        // for vec_get/first/last/pop and similar Vec
                        // element returns, the element type comes from
                        // the receiver Vec, not a fixed i64 default.
                        // Pre-fix `print(vec_get(vec_of_str, i))` printed
                        // the str pointer as int (e.g. 2444806475504)
                        // instead of dispatching to print_str. Reuse
                        // indexed_element_full_type on args[0] to derive
                        // T from Vec<T>.
                        let vec_elem_callee: i64 = if str_eq(pfn_name, "vec_get") == 1
                            || str_eq(pfn_name, "vec_first") == 1
                            || str_eq(pfn_name, "vec_last") == 1
                            || str_eq(pfn_name, "vec_pop") == 1 { 1 } else { 0 };
                        if vec_elem_callee == 1 {
                            let pfn_args: i64 = node_field(pool, parg_nid, 2);
                            if list_len(pool, pfn_args) > 0 {
                            let recv_e_full: str = indexed_element_full_type(pool, list_get(pool, pfn_args, 0), sym, structs);
                            if str_len(recv_e_full) > 0 {
                                let recv_e_base: str = type_base_name(recv_e_full);
                                if str_eq(recv_e_base, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(recv_e_base, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                                if str_eq(recv_e_base, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                                if str_eq(recv_e_base, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                                // str element: leave p_helper empty so we
                                // fall through to the default print_str
                                // path below -- which is correct for str
                                // values.
                            };
                            };
                        };
                        // i64 returns: hashmap_get, vec_get, vec_len,
                        // vec_first, vec_last, hashmap_len,
                        // hashmap_capacity, hashset_len, btreemap_len,
                        // vecdeque_len, str_len, str_to_int,
                        // str_to_i64, tok_vocab_size, tok_vec_len,
                        // tok_vec_at, etc.
                        // hashmap_get / btreemap_get also have value-
                        // type variation but the i64 default is the
                        // historical assumption -- adopters using
                        // HashMap<K, str> will hit the same NUC-FEEDBACK-
                        // 006 hazard; queued for a follow-on if it
                        // surfaces.
                        if str_len(p_helper) == 0 {
                        if str_eq(pfn_name, "hashmap_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "hashmap_capacity") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "hashset_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "btreemap_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "btreeset_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "vecdeque_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "vec_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        };
                        if str_eq(pfn_name, "str_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_to_int") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_to_i64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_to_int_with_base") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_index_of") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_count") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_char_at") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "tok_encode") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "tok_vocab_size") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "tok_vec_len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "tok_vec_at") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "arena_alloc") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(pfn_name, "str_arena_bytes") == 1 { p_helper = "__nucleor_print_i64"; };
                        // bool returns
                        if str_eq(pfn_name, "hashmap_contains") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "hashmap_is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "hashset_contains") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "hashset_is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "btreemap_contains_key") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "btreeset_contains") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "vecdeque_is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "vec_is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_eq") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_contains") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_starts_with") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_ends_with") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(pfn_name, "str_to_bool") == 1 { p_helper = "__nucleor_print_bool"; };
                        // f64 returns (typed math wrappers from v0.3.127 math_typed.nr)
                        if str_eq(pfn_name, "sqrt_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "exp_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "log_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "tanh_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "sin_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "cos_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "pow_f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "f64_from_int") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(pfn_name, "f64_from_bits") == 1 { p_helper = "__nucleor_print_f64"; };
                        // str returns: str_concat / str_substring fall
                        // through to default print_str (correct).
                    };
                };
                // also handle struct field access (kind 9).
                // Look up the struct via expr_struct_type, then find the
                // field's type via struct_field_type. Catches the
                // canonical `print(p.x)` where p.x is f64 -- pre-fix
                // SIGSEGV'd (printed the f64 bit pattern as a string
                // pointer). For unknown field types or non-struct receivers
                // (Box<dyn Trait>, generic param, etc.) the dispatch
                // falls through to __nucleor_print_str, preserving the
                // original behavior.
                if parg_kind == 9 {
                    let outer_type: str = expr_struct_type(pool, node_field(pool, parg_nid, 1), sym, structs);
                    if str_len(outer_type) > 0 {
                        let si: i64 = struct_find_type(pool, structs, outer_type);
                        if si >= 0 {
                            let ftype: str = type_base_name(struct_field_type(pool, vec_get(structs, si), node_field(pool, parg_nid, 2)));
                            if str_eq(ftype, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(ftype, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(ftype, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(ftype, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                        };
                    };
                };
                // also handle index expressions (kind 10).
                // `print(v[0])` where v: Vec<i64> SIGSEGV'd pre-fix
                // because the dispatch fell through to print_str which
                // dereferenced the i64 element as const char *. Reuse
                // indexed_element_full_type which already knows how to
                // strip one container layer (Vec<T> -> T) for var refs,
                // struct fields, fn-call results, and nested index.
                if parg_kind == 10 {
                    let etype_full: str = indexed_element_full_type(pool, node_field(pool, parg_nid, 1), sym, structs);
                    if str_len(etype_full) > 0 {
                        let etype: str = type_base_name(etype_full);
                        if str_eq(etype, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(etype, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(etype, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(etype, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                    };
                };
                // also handle binop results (kind 4).
                // `print(a + b)` where a, b: i64 SIGSEGV'd pre-fix --
                // the dispatch fell through to print_str. Same hazard
                // class. Three buckets:
                //   - comparison/equality/logical ops (30-37) -> bool
                //   - float binop (binop_float_type returns f32/f64) -> f64
                //   - everything else -> i64 (arith on ints + bitwise)
                // The default-to-i64 is sound because Nucleor binops only
                // produce i64, f32/f64, or bool (no operator overloading;
                // str + str not supported; bool arith is TYP-002).
                if parg_kind == 4 {
                    let bop: i64 = node_field(pool, parg_nid, 1);
                    if bop == 30 || bop == 31 || bop == 32 || bop == 33 || bop == 34 || bop == 35 || bop == 36 || bop == 37 {
                        p_helper = "__nucleor_print_bool";
                    };
                    if str_len(p_helper) == 0 {
                        let bft: str = binop_float_type(pool, parg_nid, sym, structs);
                        if str_eq(bft, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                        if str_eq(bft, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                    };
                    if str_len(p_helper) == 0 {
                        p_helper = "__nucleor_print_i64";
                    };
                };
                // print(if cond { x } else { y }) -- if-expr
                // (kind 23) defaults to i64 dispatch. Pre-fix the
                // dispatch fell through to print_str and SIGSEGV'd.
                // Same hazard class as v0.3.143/163-178 print() gaps.
                // Most adopter if-exprs produce i64; complex types
                // can use let-binding to assign first.
                if parg_kind == 23 {
                    p_helper = "__nucleor_print_i64";
                };
                // print(match x { ... }) -- match-expr
                // (kind 38) and block-expr (kind 52) default to i64.
                // Same hazard class as kind 23 if-expr.
                if parg_kind == 38 {
                    p_helper = "__nucleor_print_i64";
                };
                if parg_kind == 52 {
                    p_helper = "__nucleor_print_i64";
                };
                // cast expression (kind 99). Target type is
                // stored on the node; dispatch directly. Catches
                // print(x as i64) -- pre-fix dereferenced the i64 as
                // a string pointer. (For cast-to-str the dispatch falls
                // through to the default print_str, which is correct.)
                if parg_kind == 99 {
                    let ctype: str = type_base_name(node_field(pool, parg_nid, 2));
                    if str_eq(ctype, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                    if str_eq(ctype, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                    if str_eq(ctype, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                    if str_eq(ctype, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                };
                // unary minus (kind 5) inherits operand type.
                // Reuse binop_float_type; default to i64.
                if parg_kind == 5 {
                    let inner_nid: i64 = node_field(pool, parg_nid, 1);
                    let nft: str = binop_float_type(pool, inner_nid, sym, structs);
                    if str_eq(nft, "f32") == 1 { p_helper = "__nucleor_print_f64"; }
                    else if str_eq(nft, "f64") == 1 { p_helper = "__nucleor_print_f64"; }
                    else { p_helper = "__nucleor_print_i64"; };
                };
                // unary not (kind 6) is always bool.
                if parg_kind == 6 {
                    p_helper = "__nucleor_print_bool";
                };
                // method call (kind 8) and associated fn
                // call (kind 12). Both use mangled symbol lookup
                // `__fnret_<TYPE>__<METHOD>` for typed return.
                // For kind 8, receiver is in field 1, method name
                // field 2; resolve receiver type via expr_struct_type.
                // For kind 12, struct/type name is in field 1
                // directly, method name field 2.
                if parg_kind == 8 {
                    let recv_nid: i64 = node_field(pool, parg_nid, 1);
                    let mname: str = node_field(pool, parg_nid, 2);
                    let rtype: str = expr_struct_type(pool, recv_nid, sym, structs);
                    if str_len(rtype) > 0 && str_len(mname) > 0 {
                        let mangled: str = str_concat(rtype, str_concat("__", mname));
                        let mret: i64 = sym_get(sym, str_concat("__fnret_", mangled));
                        if mret >= 0 {
                            let mt: str = type_base_name(mret);
                            if str_eq(mt, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(mt, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(mt, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                        };
                    };
                    // fallback for builtin methods that
                    // don't have __fnret_ entries (Vec::len, str::len,
                    // HashMap::is_empty, etc.). These methods have
                    // unambiguous return types by name across the
                    // stdlib container family.
                    if str_len(p_helper) == 0 && str_len(mname) > 0 {
                        // NUC-FEEDBACK-006 element-type
                        // lookup for container .get()/.first()/.last()/
                        // .pop() methods. Pre-fix v.get(i) on Vec<str>
                        // printed the str pointer as int. Reuse
                        // indexed_element_full_type on the receiver.
                        let m_elem_call: i64 = if str_eq(mname, "get") == 1
                            || str_eq(mname, "first") == 1
                            || str_eq(mname, "last") == 1
                            || str_eq(mname, "pop") == 1
                            || str_eq(mname, "front") == 1
                            || str_eq(mname, "back") == 1 { 1 } else { 0 };
                        if m_elem_call == 1 {
                            let mrecv_nid: i64 = node_field(pool, parg_nid, 1);
                            let m_e_full: str = indexed_element_full_type(pool, mrecv_nid, sym, structs);
                            if str_len(m_e_full) > 0 {
                                let m_e_base: str = type_base_name(m_e_full);
                                if str_eq(m_e_base, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                                if str_eq(m_e_base, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                                if str_eq(m_e_base, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                                if str_eq(m_e_base, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                                // str element -> fall through to default
                                // print_str path (correct for str).
                            };
                            // HashMap<K, V>.get / similar -- when
                            // indexed_element_full_type fails (it only knows
                            // Vec<T>), try generic_second_type on the
                            // receiver's full type for HashMap-style 2-arg
                            // generics. Pre-fix `print(h.get("a"))` for
                            // HashMap<str, i64> SIGSEGV'd because the
                            // method-name fallback for "get" was removed in
                            if str_len(p_helper) == 0 {
                                let mut mrecv_full: str = "";
                                if node_kind(pool, mrecv_nid) == 3 {
                                    let mrn: str = node_field(pool, mrecv_nid, 1);
                                    let mrt: i64 = sym_get(sym, str_concat("__fulltype_", mrn));
                                    if mrt >= 0 { mrecv_full = mrt; };
                                };
                                let mv_type: str = generic_second_type(mrecv_full);
                                if str_len(mv_type) > 0 {
                                    let mv_base: str = type_base_name(mv_type);
                                    if str_eq(mv_base, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                                    if str_eq(mv_base, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                                    if str_eq(mv_base, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                                    if str_eq(mv_base, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                                    // str -> fall through to default.
                                };
                            };
                        };
                        if str_len(p_helper) == 0 {
                        if str_eq(mname, "len") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(mname, "count") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(mname, "capacity") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(mname, "is_empty") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(mname, "contains") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(mname, "contains_key") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(mname, "remove") == 1 { p_helper = "__nucleor_print_i64"; };
                        if str_eq(mname, "starts_with") == 1 { p_helper = "__nucleor_print_bool"; };
                        if str_eq(mname, "ends_with") == 1 { p_helper = "__nucleor_print_bool"; };
                        };
                    };
                };
                if parg_kind == 12 {
                    let tname12: str = node_field(pool, parg_nid, 1);
                    let mname12: str = node_field(pool, parg_nid, 2);
                    if str_len(tname12) > 0 && str_len(mname12) > 0 {
                        let mangled12: str = str_concat(tname12, str_concat("__", mname12));
                        let mret12: i64 = sym_get(sym, str_concat("__fnret_", mangled12));
                        if mret12 >= 0 {
                            let mt12: str = type_base_name(mret12);
                            if str_eq(mt12, "i64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "i32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "i16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "i8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "isize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "u64") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "u32") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "u16") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "u8")  == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "usize") == 1 { p_helper = "__nucleor_print_i64"; };
                            if str_eq(mt12, "f64") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(mt12, "f32") == 1 { p_helper = "__nucleor_print_f64"; };
                            if str_eq(mt12, "bool") == 1 { p_helper = "__nucleor_print_bool"; };
                        };
                    };
                };
                if str_len(p_helper) > 0 {
                    let pr_r: i64 = ctr_next(regs);
                    ir_block_add(cur, ir_call_ex(pr_r, p_helper, arg_regs));
                    return lx_new(pr_r, cur);
                };
            };
        };
        let fn_slot: i64 = sym_get(sym, fn_name);
        if fn_slot >= 0 {
            // catch `s(args)` for `s: str` (and other
            // non-callable typed bindings) at codegen time. Pre-fix
            // the indirect-call below treated the str pointer as a
            // fn-ptr and SIGSEGV'd at runtime — adopters who typo'd
            // a fn name into a string-typed variable name (or vice
            // versa) got a runtime crash with no compile-time signal.
            // Halt cleanly when the binding's `__type_<name>` is a
            // known non-callable scalar/string type.
            let type_v122: i64 = sym_get(sym, str_concat("__type_", fn_name));
            if type_v122 >= 0 {
                let type_str: str = type_v122;
                let tbase: str = type_base_name(type_str);
                // removed i*/u* from the uncallable list. Pre-v0.4.164
                // lumping integer types into TYP-014 broke
                //   `let double: i64 = |x| x * 2;` (tests/lang/closures.nr) and
                //   `let fp: i64 = fn_ptr;` (stdlib/rods/concurrency.nr)
                // because Nucleor's pre-RFC-0025 ABI uses i64 for BOTH numeric
                // values and fn pointers — the type system can't distinguish.
                // The original v0.4.122 motivation was the STR typo case
                // (`let s: str = "x"; s(42);` → SIGSEGV); that and other
                // genuinely-non-callable types stay rejected. The narrow
                // remaining gap — `let n: i64 = 5; n(x);` typoing a numeric
                // var as a fn — returns to pre-v0.4.122 runtime SIGSEGV with
                // no compile-time signal. Acceptable trade-off until proper
                // fn-pointer types ship in RFC-0025.
                let is_uncallable: i64 = if str_eq(tbase, "str") == 1
                    || str_eq(tbase, "f32") == 1
                    || str_eq(tbase, "f64") == 1
                    || str_eq(tbase, "bool") == 1
                    || str_eq(tbase, "Vec") == 1 { 1 } else { 0 };
                if is_uncallable == 1 {
                    panic(str_concat("error[TYP-014]: cannot call `", str_concat(fn_name, str_concat("(...)` — `", str_concat(fn_name, str_concat("` is bound as type `", str_concat(type_str, "`, which is not callable. Did you mean to call a different identifier, or to access an element via `[i]` / a method via `.method(args)`?"))))))));
                };
            };
            let fp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_load(fp_r, fn_slot));
            let r: i64 = ctr_next(regs);
            ir_block_add(cur, ir_indirect_call(r, fp_r, arg_regs));
            let clo_id_meta: i64 = sym_get(sym, str_concat("__closure_id_", fn_name));
            if clo_id_meta >= 0 {
                let caps_meta: i64 = sym_get(sym, str_concat("__closure_caps_", fn_name));
                if caps_meta >= 0 {
                    let cap_names: str = caps_meta;
                    // Pass the closure-value's local slot (not the per-
                    // literal clo_id) so the writeback can read captures
                    // from the per-instance env at runtime.
                    cur = closure_writeback_captures(cap_names, fn_slot, cur, regs, sym);
                };
            };
            return lx_new(r, cur);
        };
        let r: i64 = ctr_next(regs);
        // when fn_name is a registered user fn (its return
        // type is in sym as `__fnret_<name>`), emit a USER call op
        // (31) that bypasses the runtime-helper name lookup. Without
        // this, user fns that share a name with a runtime helper
        // (e.g. user `pow(base, exp)` vs `__nucleor_pow(f64, f64)`)
        // dispatched to the runtime helper — silent miscompute since
        // the int args were treated as f64 bit patterns by the
        // float helper. Adopters writing math/utility wrappers with
        // common names hit this on the very first probe.
        let user_ret: i64 = sym_get(sym, str_concat("__fnret_", fn_name));
        if user_ret >= 0 {
            ir_block_add(cur, ir_user_call(r, fn_name, arg_regs));
        } else {
            ir_block_add(cur, ir_call_ex(r, fn_name, arg_regs));
        };
        return lx_new(r, cur);
    };
    if kind == 8 {
        let mut obj_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(obj_p);
        let mut cur: Vec<i32> = lx_blk(obj_p);
        let mname: str = node_field(pool, nid, 2);
        let args_list: i64 = node_field(pool, nid, 3);
        let argc: i64 = list_len(pool, args_list);
        let mut all_args: Vec<i32> = Vec::new();
        all_args.push(obj_r);
        let mut ai: i64 = 0;
        while ai < argc {
            let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            all_args.push(lx_reg(ap));
            cur = lx_blk(ap);
            ai = ai + 1;
        };
        let mut stype: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        let mut fn_name: str = "";
        if str_len(stype) > 0 { fn_name = trait_impl_find(trait_impls, stype, mname); };
        if str_len(fn_name) == 0 {
            let gbound_count: i64 = sym_get(sym, str_concat("__gparam_bound_count_", stype));
            if gbound_count > 0 {
                let mut gb_i: i64 = 0;
                while gb_i < gbound_count && str_len(fn_name) == 0 {
                    let gb_name: str = sym_get(sym, str_concat(str_concat("__gparam_bound_", stype), str_concat("_", str_from_int(gb_i))));
                    let gb_impl: str = trait_impl_find_unique_bound_method(trait_impls, gb_name, mname);
                    if str_eq(gb_impl, "__ambiguous_trait_bound_method") == 1 {
                        let msg_v529a: str = str_concat("error[TYP-007]: generic trait-bound method dispatch for `", str_concat(stype, str_concat(": ", str_concat(gb_name, str_concat("` method `.", str_concat(mname, "()` is ambiguous."))))));
                        let msg_v529b: str = " Nucleor currently emits one ABI-level generic fn body rather than per-call-site specializations, so a generic receiver method can only lower when the bound has exactly one concrete impl for that method. Split the generic call or use an explicit concrete helper until monomorphized trait dispatch ships.";
                        print(str_concat(msg_v529a, msg_v529b));
                        panic(str_concat("nucleor: ambiguous generic trait-bound method dispatch for ", str_concat(stype, str_concat(".", mname))));
                    };
                    if str_len(gb_impl) > 0 { fn_name = gb_impl; };
                    gb_i = gb_i + 1;
                };
            };
        };
        if str_len(fn_name) == 0 {
            if str_eq(type_base_name(stype), "Tensor") == 1 {
                fn_name = tensor_builtin_method_name(mname);
            };
            if str_len(fn_name) == 0 {
                // T2.2 (v0.2.348): iterator method dispatch on Vec.
                // `v.map(f)` / `v.filter(p)` / `v.fold(init, f)` etc.
                // route to the typed `vec_*_i64` runtime helpers
                // already wired up in stdlib/runtime/nucleor_llvm_rt.c.
                // Anything else falls through to the existing
                // `vec_<method>` convention.
                // only use the vec_*_i64 iterator dispatch
                // when the receiver IS a Vec. Pre-fix `h.contains(k)`
                // for HashMap fell through here and called
                // vec_contains_i64 instead of hashmap_contains --
                // returning the wrong answer (false on present keys).
                let stype_for_iter: str = type_base_name(stype);
                let mut recv_is_vec: i64 = if str_len(stype_for_iter) == 0
                    || str_eq(stype_for_iter, "Vec") == 1 { 1 } else { 0 };
                // also exclude Option/Result via var-ref
                // __type_<name> lookup (when stype was empty). Without
                // this, `opt.map(f)` for opt: Option<T> falls through
                // recv_is_vec==1 → vec_map_i64 which links-fails or
                // returns Vec instead of Option.
                if recv_is_vec == 1 && str_len(stype_for_iter) == 0 {
                    let recv_check_v92: i64 = node_field(pool, nid, 1);
                    if node_kind(pool, recv_check_v92) == 3 {
                        let recv_n_v92: str = node_field(pool, recv_check_v92, 1);
                        let recv_t_v92: i64 = sym_get(sym, str_concat("__type_", recv_n_v92));
                        if recv_t_v92 >= 0 {
                            let recv_b_v92: str = type_base_name(recv_t_v92);
                            if str_eq(recv_b_v92, "Option") == 1 || str_eq(recv_b_v92, "Result") == 1 {
                                recv_is_vec = 0;
                            };
                        };
                    };
                };
                // str-literal receiver (kind 2). expr_struct_type
                // returns "" for literals, so stype was empty and recv_is_vec
                // stayed 1. `"abc".len()` lowered to vec_len on the str ptr
                // (silent miscompute, returned 0); `"abc".contains("b")` and
                // friends would have routed to vec_contains_i64 (also a
                // silent miscompute reading the str header as a vec header).
                // Detect kind-2 receiver here, clear recv_is_vec, and stamp
                // stype = "str" so the existing v0.4.88 str-method dispatch
                // (str_len / str_contains / str_replace / etc.) picks it up.
                if recv_is_vec == 1 {
                    let recv_check: i64 = node_field(pool, nid, 1);
                    if node_kind(pool, recv_check) == 2 {
                        recv_is_vec = 0;
                        stype = "str";
                    };
                };
                if recv_is_vec == 1 && iter_method_for_vec(mname) == 1 {
                    fn_name = str_concat("vec_", str_concat(mname, "_i64"));
                } else {
                    // receiver-type-aware dispatch for the
                    // collection family (HashMap/HashSet/BTreeMap/
                    // BTreeSet/VecDeque). Pre-v0.3.100 the fallback
                    // was always `vec_<method>`, so a Rust-style
                    // `m.insert(k, v)` on a `HashMap<K,V>` lowered
                    // to `vec_insert(m, k, v)` — undefined symbol at
                    // clang link. The lowercase runtime helpers
                    // (`hashmap_insert`, `hashset_insert`, etc.) all
                    // exist; this is the missing surface-level
                    // dispatch from the `let m: HashMap<...>`
                    // type annotation through `expr_struct_type` to
                    // the right prefix. Falls through to `vec_*` for
                    // unknown receiver types so the existing Vec
                    // method convention still works.
                    let stype_base: str = type_base_name(stype);
                    if str_eq(stype_base, "HashMap") == 1 {
                        fn_name = str_concat("hashmap_", mname);
                    } else if str_eq(stype_base, "HashSet") == 1 {
                        fn_name = str_concat("hashset_", mname);
                    } else if str_eq(stype_base, "BTreeMap") == 1 {
                        fn_name = str_concat("btreemap_", mname);
                    } else if str_eq(stype_base, "BTreeSet") == 1 {
                        fn_name = str_concat("btreeset_", mname);
                    } else if str_eq(stype_base, "VecDeque") == 1 {
                        fn_name = str_concat("vecdeque_", mname);
                    } else if str_eq(stype_base, "Option") == 1 && (str_eq(mname, "unwrap") == 1 || str_eq(mname, "unwrap_or") == 1 || str_eq(mname, "is_some") == 1 || str_eq(mname, "is_none") == 1 || str_eq(mname, "expect") == 1 || str_eq(mname, "map") == 1 || str_eq(mname, "and_then") == 1 || str_eq(mname, "unwrap_or_else") == 1) {
                        // Option<T> method dispatch — was hitting
                        // the v0.4.53 "non-Option receiver" panic-guard
                        // even when receiver IS typed Option<T>, because
                        // no Option dispatch branch existed and the chain
                        // fell through to the user-fn lookup. Runtime
                        // helpers added in nucleor_llvm_rt.c v0.4.90.
                        fn_name = str_concat("option_", mname);
                    } else if str_eq(stype_base, "Option") == 1 && (str_eq(mname, "unwrap_or_default") == 1 || str_eq(mname, "take") == 1 || str_eq(mname, "replace") == 1 || str_eq(mname, "flatten") == 1 || str_eq(mname, "as_ref") == 1 || str_eq(mname, "as_mut") == 1 || str_eq(mname, "iter") == 1 || str_eq(mname, "ok_or") == 1 || str_eq(mname, "ok_or_else") == 1 || str_eq(mname, "cloned") == 1 || str_eq(mname, "copied") == 1) {
                        //  canonical Rust Option methods not yet in
                        // Nucleor's runtime surface (`unwrap_or_default`,
                        // `take`, `replace`, `flatten`, `as_ref`, `as_mut`,
                        // `iter`, `ok_or`, `ok_or_else`, `cloned`, `copied`)
                        // pre-fix fell through to the kind-8 catch-all
                        // `vec_<method>(receiver)` and surfaced as the
                        // wrong-class TYP-005 "Vec<T> has no method" diag.
                        // Halt now with a clean per-method workaround
                        // pointer. Tracked for forward-roadmap (extended
                        // Option/Result method surface alongside Default
                        // trait infrastructure).
                        let v083_workaround_opt: str = if str_eq(mname, "unwrap_or_default") == 1 {
                            "use `unwrap_or(<default>)` with an explicit default — Nucleor doesn't auto-derive Default per type yet"
                        } else if str_eq(mname, "take") == 1 || str_eq(mname, "replace") == 1 {
                            "mutate the binding manually: `let v: T = opt.unwrap(); opt = None;` (or assign the new Some value)"
                        } else if str_eq(mname, "flatten") == 1 {
                            "use `match opt { Some(inner) => inner, None => None }`"
                        } else if str_eq(mname, "ok_or") == 1 || str_eq(mname, "ok_or_else") == 1 {
                            "convert via `match opt { Some(v) => Ok(v), None => Err(<err_value>) }`"
                        } else {
                            "no current shorthand — destructure with `match opt { Some(v) => ..., None => ... }`"
                        };
                        print(str_concat("ERROR: `Option::", str_concat(mname, str_concat("()` is not yet implemented in Nucleor's Option/Result method surface. Workaround: ", str_concat(v083_workaround_opt, ".")))))));
                        panic(str_concat("nucleor: Option method `.", str_concat(mname, "()` not yet supported (see ERROR diagnostic above)")));
                    } else if str_eq(stype_base, "Result") == 1 && (str_eq(mname, "unwrap") == 1 || str_eq(mname, "unwrap_or") == 1 || str_eq(mname, "unwrap_err") == 1 || str_eq(mname, "is_ok") == 1 || str_eq(mname, "is_err") == 1 || str_eq(mname, "ok") == 1 || str_eq(mname, "err") == 1 || str_eq(mname, "expect") == 1 || str_eq(mname, "map") == 1 || str_eq(mname, "and_then") == 1 || str_eq(mname, "unwrap_or_else") == 1 || str_eq(mname, "or_else") == 1) {
                        // Result<T,E> method dispatch — same
                        // root cause as Option above.
                        fn_name = str_concat("result_", mname);
                    } else if str_eq(stype_base, "Result") == 1 && (str_eq(mname, "unwrap_or_default") == 1 || str_eq(mname, "as_ref") == 1 || str_eq(mname, "as_mut") == 1 || str_eq(mname, "iter") == 1 || str_eq(mname, "map_err") == 1 || str_eq(mname, "expect_err") == 1 || str_eq(mname, "cloned") == 1 || str_eq(mname, "copied") == 1) {
                        let v083_workaround_res: str = if str_eq(mname, "unwrap_or_default") == 1 {
                            "use `unwrap_or(<default>)` with an explicit default value"
                        } else if str_eq(mname, "map_err") == 1 {
                            "use `match res { Ok(v) => Ok(v), Err(e) => Err(<f>(e)) }` to transform the err arm"
                        } else if str_eq(mname, "expect_err") == 1 {
                            "use `match res { Err(e) => e, Ok(_) => panic!(\"<msg>\") }`"
                        } else {
                            "destructure with `match res { Ok(v) => ..., Err(e) => ... }`"
                        };
                        print(str_concat("ERROR: `Result::", str_concat(mname, str_concat("()` is not yet implemented in Nucleor's Option/Result method surface. Workaround: ", str_concat(v083_workaround_res, ".")))));
                        panic(str_concat("nucleor: Result method `.", str_concat(mname, "()` not yet supported (see ERROR diagnostic above)")));
                    } else if str_eq(stype_base, "String") == 1 && (str_eq(mname, "push") == 1 || str_eq(mname, "push_str") == 1 || str_eq(mname, "len") == 1 || str_eq(mname, "capacity") == 1 || str_eq(mname, "get_byte") == 1 || str_eq(mname, "clear") == 1 || str_eq(mname, "as_ptr") == 1 || str_eq(mname, "print") == 1 || str_eq(mname, "eq") == 1 || str_eq(mname, "eq_str") == 1 || str_eq(mname, "starts_with") == 1 || str_eq(mname, "ends_with") == 1 || str_eq(mname, "contains") == 1 || str_eq(mname, "clone") == 1 || str_eq(mname, "free") == 1
                        || str_eq(mname, "is_empty") == 1 || str_eq(mname, "to_uppercase") == 1 || str_eq(mname, "to_lowercase") == 1 || str_eq(mname, "trim") == 1 || str_eq(mname, "trim_start") == 1 || str_eq(mname, "trim_end") == 1 || str_eq(mname, "find") == 1 || str_eq(mname, "substring") == 1 || str_eq(mname, "char_at") == 1 || str_eq(mname, "as_str") == 1) {
                        // extended String method surface — adds
                        // is_empty / to_uppercase / to_lowercase / trim /
                        // trim_start / trim_end / find / substring /
                        // char_at / as_str. Runtime helpers landed in
                        // nucleor_llvm_rt.c v0.4.124 batch.
                        let mut sm: str = mname;
                        if str_eq(mname, "push") == 1 { sm = "push_byte"; };
                        fn_name = str_concat("string_", sm);
                    } else if str_eq(stype_base, "str") == 1 && (str_eq(mname, "len") == 1 || str_eq(mname, "contains") == 1 || str_eq(mname, "replace") == 1 || str_eq(mname, "split") == 1 || str_eq(mname, "starts_with") == 1 || str_eq(mname, "ends_with") == 1 || str_eq(mname, "to_lower") == 1 || str_eq(mname, "to_upper") == 1 || str_eq(mname, "trim") == 1 || str_eq(mname, "trim_start") == 1 || str_eq(mname, "trim_end") == 1 || str_eq(mname, "substring") == 1 || str_eq(mname, "char_at") == 1) {
                        // str method receiver-type-aware dispatch.
                        // Pre-fix `s.len()` lowered to `vec_len(s)` which
                        // reads the str pointer as if it were a Vec
                        // header — silent miscompute, returned garbage
                        // like 1684828783 instead of byte length.
                        // Same hazard for `s.contains/replace/split/
                        // starts_with/ends_with` which failed at clang
                        // link with `undefined value '@vec_contains'`
                        // etc. Mirrors the v0.3.100 HashMap/HashSet
                        // receiver-type-aware pattern; the runtime
                        // helpers (str_len, str_contains, str_replace,
                        // str_split, str_starts_with, str_ends_with)
                        // all exist.
                        fn_name = str_concat("str_", mname);
                    } else {
                        // user-defined inherent-impl method
                        // dispatch via mangled name. Pre-v0.3.123 the
                        // fallback was always `vec_<method>`, so a
                        // chained inherent fn call like
                        // `Counter::new().add(10).add(5)` lowered the
                        // SECOND `.add(...)` to `vec_add(...)` —
                        // undefined symbol at clang link. The kind-12
                        // path (Counter::new) was fixed in v0.3.111
                        // via the same `__fnret_<mangled>` lookup;
                        // mirror that here for instance-method chains.
                        // Falls through to `vec_<method>` for receiver
                        // types that aren't registered impl methods,
                        // preserving the existing Vec convention.
                        let user_mangled: str = str_concat(stype_base, str_concat("__", mname));
                        let user_ret: i64 = sym_get(sym, str_concat("__fnret_", user_mangled));
                        if user_ret >= 0 {
                            fn_name = user_mangled;
                        } else {
                            // NUC-FEEDBACK silent-undefined-symbol guard.
                            // Pre-fix `x.unwrap()` (and .expect, .ok, .err,
                            // .unwrap_or) on a non-Option/Result receiver
                            // (e.g. bare i64) lowered to `vec_unwrap(x)`,
                            // which is not a runtime helper. Build failed
                            // late at clang link with `undefined value
                            // '@vec_unwrap'`. Adopters got a confusing
                            // LLVM-IR error pointing at compiler-emitted
                            // text rather than their source. Halt now with
                            // a clear diagnostic naming the call.
                            let bad_on_vec: i64 = if str_eq(mname, "unwrap") == 1
                                || str_eq(mname, "expect") == 1
                                || str_eq(mname, "unwrap_or") == 1
                                || str_eq(mname, "unwrap_or_else") == 1
                                || str_eq(mname, "ok") == 1
                                || str_eq(mname, "err") == 1
                                || str_eq(mname, "is_ok") == 1
                                || str_eq(mname, "is_err") == 1
                                || str_eq(mname, "is_some") == 1
                                || str_eq(mname, "is_none") == 1
                                || str_eq(mname, "and_then") == 1
                                || str_eq(mname, "or_else") == 1 { 1 } else { 0 };
                            if bad_on_vec == 1 {
                                // before panicking, look up the
                                // receiver's declared __type_<name> to see
                                // if it IS Option/Result. The earlier
                                // type_base_name(stype) chain doesn't catch
                                // this because expr_struct_type returned ""
                                // for the var-ref-to-Option case in some
                                // code paths. Route to option_/result_
                                // runtime helpers (added in
                                // nucleor_llvm_rt.c v0.4.90) if so.
                                let recv_for_opt: i64 = node_field(pool, nid, 1);
                                let mut routed: i64 = 0;
                                if node_kind(pool, recv_for_opt) == 3 {
                                    let recv_name_v490: str = node_field(pool, recv_for_opt, 1);
                                    let recv_type_id: i64 = sym_get(sym, str_concat("__type_", recv_name_v490));
                                    if recv_type_id >= 0 {
                                        let recv_type_v490: str = recv_type_id;
                                        let recv_base: str = type_base_name(recv_type_v490);
                                        if str_eq(recv_base, "Option") == 1 {
                                            fn_name = str_concat("option_", mname);
                                            routed = 1;
                                        };
                                        if str_eq(recv_base, "Result") == 1 {
                                            fn_name = str_concat("result_", mname);
                                            routed = 1;
                                        };
                                    };
                                };
                                if routed == 0 {
                                    let part_a: str = str_concat("ERROR: `.", str_concat(mname, "()` is an Option/Result method, not a Vec method."));
                                    let part_b: str = str_concat(" Receiver type unknown to the type-checker; pre-v0.4.53 this lowered to `vec_", str_concat(mname, "(...)` and failed late at clang link with an undefined-symbol error."));
                                    let part_c: str = " Workaround: ensure the receiver binding is typed `Option<T>` / `Result<T,E>`, or use the explicit `match expr { Some(x) => x, None => default }` pattern.";
                                    print(str_concat(part_a, str_concat(part_b, part_c)));
                                    panic(str_concat("nucleor: Option/Result method `.", str_concat(mname, "()` called on non-Option receiver")));
                                };
                            };
                            // primitive-receiver method guard.
                            // Pre-fix `let x: i64 = 5; x.no_such_method();`
                            // fell through every receiver-typed branch
                            // and lowered to `vec_no_such_method(x)`,
                            // which the v0.4.106 lift then surfaced as
                            // `error[TYP-005]: undefined function
                            // 'vec_no_such_method()'`. Adopters had to
                            // mentally translate the `vec_` prefix back
                            // to "the type-checker thought my receiver
                            // was a Vec when it isn't" — confusing.
                            // Detect primitive receivers (i*, u*, f*,
                            // bool) here and emit a method-targeted
                            // diagnostic naming both the call site and
                            // the receiver type. str has its own
                            // receiver-type-aware dispatch above
                            // (v0.4.88) so it doesn't reach this path.
                            let stype_base: str = type_base_name(stype);
                            let is_primitive_recv: i64 = if str_eq(stype_base, "i8") == 1
                                || str_eq(stype_base, "i16") == 1
                                || str_eq(stype_base, "i32") == 1
                                || str_eq(stype_base, "i64") == 1
                                || str_eq(stype_base, "u8") == 1
                                || str_eq(stype_base, "u16") == 1
                                || str_eq(stype_base, "u32") == 1
                                || str_eq(stype_base, "u64") == 1
                                || str_eq(stype_base, "f32") == 1
                                || str_eq(stype_base, "f64") == 1
                                || str_eq(stype_base, "bool") == 1 { 1 } else { 0 };
                            if is_primitive_recv == 1 {
                                let pa: str = str_concat("error[TYP-007]: receiver type `", str_concat(stype_base, str_concat("` has no method `.", str_concat(mname, "()`."))));
                                let pb: str = str_concat(" Pre-v0.4.107 this lowered to `vec_", str_concat(mname, "(...)` and failed late at clang link with an undefined-symbol error."));
                                let pc: str = " Primitive numeric and bool types in Nucleor have no inherent methods today; use a free fn (e.g. `i64_to_str(x)`) or wrap in a struct that impls the method.";
                                print(str_concat(pa, str_concat(pb, pc)));
                                panic(str_concat("nucleor: no method `.", str_concat(mname, str_concat("()` for primitive receiver `", str_concat(stype_base, "`")))));
                            };
                            if str_len(stype_base) > 4 && str_starts_with(stype_base, "dyn ") == 1 {
                                print(str_concat("ERROR: trait-object dispatch `<", str_concat(stype_base, str_concat(">`.", str_concat(mname, "()` is not yet supported in Nucleor. Workaround: use a concrete struct type instead of `Box<dyn Trait>` — `let d: Dog = Dog {};` then call the trait method directly (`d.speak()`); or add an enum dispatch wrapper (`enum Animal { Dog(Dog), Cat(Cat) }` + match).")))));
                                panic(str_concat("nucleor: trait-object method dispatch on `Box<", str_concat(stype_base, "> not yet supported (see ERROR diagnostic above)")));
                            };
                            // borrowed-reference receiver guard.
                            // Pre-fix `r.foo()` for `r: &S` fell through every
                            // typed-receiver branch (str / Option / Result /
                            // String / HashMap / etc.) and through the
                            // user-impl `<TypeName>__<method>` lookup, which
                            // mangled to "S__foo" — not registered for
                            // free-fn `fn foo(self: &S)` patterns. The
                            // catch-all then synthesized `vec_foo(r)` and
                            // the v0.4.106/.127 lift surfaced it as
                            // `error[TYP-005]: receiver type 'Vec<T>' has no
                            // method '.foo()'` — confusing because the
                            // receiver is `&S`, not `Vec<T>`.
                            // Detect via `__fulltype_<recv>` sym entry which
                            // preserves the borrow marker (`__type_<recv>`
                            // stores only the base name post-type_base_name).
                            // Only kind-3 (var-ref) receivers are checkable
                            // this way; other receiver kinds fall through to
                            // the existing diagnostics.
                            // Regression: borrowed-ref method receiver resolution.
                            let v217_recv_node: i64 = node_field(pool, nid, 1);
                            if node_kind(pool, v217_recv_node) == 3 {
                                let v217_recv_name: str = node_field(pool, v217_recv_node, 1);
                                let v217_full_id: i64 = sym_get(sym, str_concat("__fulltype_", v217_recv_name));
                                if v217_full_id >= 0 {
                                    let v217_full: str = v217_full_id;
                                    let v217_flen: i64 = str_len(v217_full);
                                    let mut v217_is_ref: i64 = 0;
                                    if v217_flen >= 1 && str_char_at(v217_full, 0) == 38 { v217_is_ref = 1; };
                                    if v217_flen >= 5 && str_starts_with(v217_full, "&mut ") == 1 { v217_is_ref = 1; };
                                    if v217_is_ref == 1 {
                                        let v217a: str = str_concat("error[TYP-007]: receiver type `", str_concat(v217_full, str_concat("` — method dispatch on borrowed references (`.", str_concat(mname, "()` on `&T` / `&mut T`) is not supported in Nucleor today."))));
                                        let v217b: str = " Pre-v0.4.217 the kind-8 catch-all synthesized `vec_<method>(<receiver>)` and the post-link diagnostic re-cast it as `receiver type 'Vec<T>' has no method ...` — confusing because the receiver is a borrowed reference, not a Vec.";
                                        let v217c: str = str_concat(" Workaround: call the free fn directly with the reference — `", str_concat(mname, str_concat("(<receiver>)`, OR dereference the binding first (`let s_owned: ", str_concat(stype_base, " = *<receiver>;`) and call methods on the owned value. Auto-deref method dispatch through borrowed references is tracked for a later RFC."))));
                                        print(str_concat(v217a, str_concat(v217b, v217c)));
                                        panic(str_concat("nucleor: method dispatch on borrowed reference `", str_concat(v217_full, "` not supported (see TYP-007 above)")));
                                    };
                                };
                            };
                            // struct-field-as-method-call guard.
                            // Pre-fix `p.x(42)` where `x` is a STRUCT FIELD
                            // (not a method) lowered to `vec_x(p, 42)`,
                            // surfaced by my v0.4.106 lift as
                            // `error[TYP-005]: undefined function `vec_x()``
                            // — confusing because the source has nothing
                            // about Vec. Detect: receiver type is a known
                            // struct AND mname matches a field name on
                            // that struct. Emit TYP-015 with the right
                            // hint (likely `p.x = ...` or `let v = p.x;`).
                            let struct_idx: i64 = struct_find_type(pool, structs, stype);
                            if struct_idx >= 0 {
                                let struct_nid_v123: i64 = vec_get(structs, struct_idx);
                                let field_idx: i64 = struct_field_idx(pool, struct_nid_v123, mname);
                                if field_idx >= 0 {
                                    let msg15a: str = str_concat("error[TYP-015]: `.", str_concat(mname, str_concat("(args)` is invalid — `.", str_concat(mname, str_concat("` is a FIELD on struct `", str_concat(stype, "`, not a method."))))));
                                    let msg15b: str = str_concat(" Pre-v0.4.123 the call lowered to `vec_", str_concat(mname, "(...)` and surfaced as an undefined-symbol TYP-005."));
                                    let msg15c: str = " Drop the parentheses to read the field as a value, or assign with `<recv>.<field> = <value>;`.";
                                    print(str_concat(msg15a, str_concat(msg15b, msg15c)));
                                    panic(str_concat("nucleor: `.", str_concat(mname, str_concat("` is a field on `", str_concat(stype, "`, not a method")))));
                                };
                            };
                            // clean halt for `.clone()` on a user struct that
                            // does not have `#[derive(Clone)]`. Pre-fix this fell through
                            // to `vec_clone(...)` synthesis → undefined symbol TYP-005.
                            if str_eq(mname, "clone") == 1 && struct_idx >= 0 {
                                let v764_sname: str = stype_base;
                                print(str_concat("ERROR: `.clone()` called on struct `", str_concat(v764_sname, "` which does not `#[derive(Clone)]`. Workaround: add `#[derive(Clone)]` above the struct definition.")));
                                panic(str_concat("nucleor: `.clone()` on struct `", str_concat(v764_sname, "` without #[derive(Clone)] (see ERROR diagnostic above)")));
                            };
                            if struct_idx >= 0 {
                                print(str_concat("error[TYP-007]: receiver type `", str_concat(stype_base, str_concat("` has no method `.", str_concat(mname, "()`.")))));
                                print(str_concat("  Define an inherent `impl ", str_concat(stype_base, str_concat(" { fn ", str_concat(mname, "(self, ...) -> T { ... } }` method or implement a trait that provides the method. Pre-fix this fell through to `vec_", str_concat(mname, "(...)` and misreported the receiver as `Vec<T>`.")))));
                                panic(str_concat("nucleor: no method `.", str_concat(mname, str_concat("()` for struct receiver `", str_concat(stype_base, "`")))));
                            };
                            // dispatch-name drift fix. Pre-fix
                            // `v.insert(idx, val)` lowered to `vec_insert(...)`
                            // but the runtime helper is `vec_insert_at`;
                            // same for `v.remove(idx)` → `vec_remove_at`.
                            // Both failed at clang link with `undefined
                            // value '@vec_insert' / '@vec_remove'`. Add
                            // suffix here so user-side method names match
                            // Rust convention without breaking the
                            // existing helper names. Discovered as a
                            // sister bug while shipping v0.4.86's
                            // canonical Rust conversion-idiom methods
                            // (`.into()`, `.to_string()`, `.to_owned()`,
                            // `.to_vec()`, `.iter_mut()`) pre-fix fell through
                            // every receiver-typed dispatch and the catch-all
                            // synthesized `vec_<idiom>(receiver)` — failing late
                            // at clang link with the wrong-class diagnostic
                            // `error[TYP-005]: receiver type 'Vec<T>' has no
                            // method '.<idiom>()'`. Adopters writing canonical
                            // Rust got pointed at "Vec method families" which
                            // had nothing to do with the actual issue (these
                            // idioms aren't Vec methods at all — they're trait-
                            // method conversions that need From/Into / ToOwned
                            // / etc. infrastructure not yet shipped).
                            // Halt now with a clean diagnostic naming the idiom
                            // and pointing at the explicit-conversion workaround.
                            // Forward-roadmap: full Into/From/ToOwned trait
                            // infrastructure is a v1.x ship.
                            let v082_idiom: i64 = if str_eq(mname, "into") == 1
                                || str_eq(mname, "to_string") == 1
                                || str_eq(mname, "to_owned") == 1
                                || str_eq(mname, "to_vec") == 1
                                || str_eq(mname, "iter_mut") == 1
                                || str_eq(mname, "rev") == 1
                                || str_eq(mname, "enumerate") == 1
                                || str_eq(mname, "zip") == 1
                                || str_eq(mname, "windows") == 1
                                || str_eq(mname, "chunks") == 1
                                || str_eq(mname, "flat_map") == 1
                                || str_eq(mname, "flatten") == 1
                                || str_eq(mname, "peekable") == 1
                                || str_eq(mname, "fuse") == 1
                                || str_eq(mname, "abs") == 1
                                || str_eq(mname, "pow") == 1
                                || str_eq(mname, "signum") == 1
                                || str_eq(mname, "count_ones") == 1
                                || str_eq(mname, "count_zeros") == 1
                                || str_eq(mname, "leading_zeros") == 1
                                || str_eq(mname, "trailing_zeros") == 1
                                || str_eq(mname, "rotate_left") == 1
                                || str_eq(mname, "rotate_right") == 1
                                || str_eq(mname, "swap_bytes") == 1
                                || str_eq(mname, "checked_add") == 1
                                || str_eq(mname, "checked_sub") == 1
                                || str_eq(mname, "checked_mul") == 1
                                || str_eq(mname, "wrapping_add") == 1
                                || str_eq(mname, "wrapping_sub") == 1
                                || str_eq(mname, "wrapping_mul") == 1
                                || str_eq(mname, "saturating_add") == 1
                                || str_eq(mname, "saturating_sub") == 1
                                || str_eq(mname, "saturating_mul") == 1
                                || str_eq(mname, "is_alphabetic") == 1
                                || str_eq(mname, "is_numeric") == 1
                                || str_eq(mname, "is_alphanumeric") == 1
                                || str_eq(mname, "is_ascii") == 1
                                || str_eq(mname, "is_whitespace") == 1
                                || str_eq(mname, "is_lowercase") == 1
                                || str_eq(mname, "is_uppercase") == 1
                                || str_eq(mname, "is_digit") == 1
                                || str_eq(mname, "to_ascii_uppercase") == 1
                                || str_eq(mname, "to_ascii_lowercase") == 1
                                || str_eq(mname, "to_lowercase") == 1
                                || str_eq(mname, "to_uppercase") == 1
                                || str_eq(mname, "to_digit") == 1
                                || str_eq(mname, "chars") == 1
                                || str_eq(mname, "lines") == 1
                                || str_eq(mname, "bytes") == 1
                                || str_eq(mname, "as_bytes") == 1
                                || str_eq(mname, "repeat") == 1
                                || str_eq(mname, "split_whitespace") == 1
                                || str_eq(mname, "split_terminator") == 1
                                || str_eq(mname, "rsplit") == 1
                                || str_eq(mname, "splitn") == 1
                                || str_eq(mname, "char_indices") == 1
                                || str_eq(mname, "parse") == 1
                                || str_eq(mname, "dedup") == 1
                                || str_eq(mname, "retain") == 1
                                || str_eq(mname, "truncate") == 1
                                || str_eq(mname, "resize") == 1
                                || str_eq(mname, "split_at") == 1
                                || str_eq(mname, "sort_by") == 1
                                || str_eq(mname, "sort_by_key") == 1
                                || str_eq(mname, "sort_unstable") == 1
                                || str_eq(mname, "sort_unstable_by") == 1
                                || str_eq(mname, "max_by_key") == 1
                                || str_eq(mname, "min_by_key") == 1
                                || str_eq(mname, "extend_from_slice") == 1
                                || str_eq(mname, "copied") == 1
                                || str_eq(mname, "cloned") == 1
                                || str_eq(mname, "as_ref") == 1
                                || str_eq(mname, "as_mut") == 1
                                || str_eq(mname, "and_then") == 1
                                || str_eq(mname, "or_else") == 1
                                || str_eq(mname, "ok_or") == 1
                                || str_eq(mname, "ok_or_else") == 1
                                || str_eq(mname, "transpose") == 1
                                || str_eq(mname, "expect_err") == 1
                                || str_eq(mname, "iter_lines") == 1
                                || str_eq(mname, "into_iter") == 1
                                || str_eq(mname, "try_into") == 1
                                || str_eq(mname, "try_from") == 1
                                || str_eq(mname, "from") == 1
                                || str_eq(mname, "borrow") == 1
                                || str_eq(mname, "borrow_mut") == 1
                                || str_eq(mname, "into_inner") == 1
                                || str_eq(mname, "leak") == 1
                                || str_eq(mname, "as_str") == 1
                                || str_eq(mname, "as_slice") == 1
                                || str_eq(mname, "as_ptr") == 1 { 1 } else { 0 };
                            if v082_idiom == 1 {
                                let v082_workaround: str = if str_eq(mname, "into") == 1 {
                                    "no v0.6 conversion path; the From/Into trait family is not yet shipped — use an explicit named conversion fn (e.g. `i64_to_str(x)` for numeric→str)"
                                } else if str_eq(mname, "to_string") == 1 {
                                    "use `i64_to_str(x)` / `f64_to_str(x)` for numerics, or write a `<Type>_to_str(t)` helper for user types — the Display/ToString trait family is not yet shipped"
                                } else if str_eq(mname, "to_owned") == 1 {
                                    "Nucleor's i64-everywhere ABI passes most values by value already; `let owned: T = original;` is the explicit copy form. The ToOwned trait family is not yet shipped"
                                } else if str_eq(mname, "to_vec") == 1 {
                                    "build the Vec explicitly via `let mut v: Vec<T> = Vec::new(); for item in src { v.push(item); }` or use the `vec![...]` macro form for literals"
                                } else if str_eq(mname, "rev") == 1 {
                                    "iterate the Vec in reverse with an index-based loop — `let mut i: i64 = vec_len(&v) - 1; while i >= 0 { let item = vec_get(&v, i); ...; i = i - 1; }`. For in-place reversal use `.reverse()` (already supported)"
                                } else if str_eq(mname, "enumerate") == 1 {
                                    "iterate with a manual counter — `let mut idx: i64 = 0; for item in &v { ...idx, item...; idx = idx + 1; }`"
                                } else if str_eq(mname, "zip") == 1 {
                                    "iterate by index over both — `let n = vec_len(&a); let mut i: i64 = 0; while i < n { let av = vec_get(&a, i); let bv = vec_get(&b, i); ...; i = i + 1; }`"
                                } else if str_eq(mname, "windows") == 1 || str_eq(mname, "chunks") == 1 {
                                    "manual sliding-window — `let mut i: i64 = 0; while i + WIN <= vec_len(&v) { let chunk = (vec_get(&v, i), vec_get(&v, i+1), ...); ...; i = i + STRIDE; }`"
                                } else if str_eq(mname, "flat_map") == 1 || str_eq(mname, "flatten") == 1 {
                                    "fold + extend manually — `let mut out: Vec<T> = Vec::new(); for inner in &outer { for item in &inner { out.push(item); } }`"
                                } else if str_eq(mname, "abs") == 1 {
                                    "use a conditional — `let r: i64 = if x < 0 { -x } else { x };`"
                                } else if str_eq(mname, "pow") == 1 {
                                    "use a manual loop — `let mut r: i64 = 1; let mut i: i64 = 0; while i < n { r = r * base; i = i + 1; }`"
                                } else if str_eq(mname, "signum") == 1 {
                                    "use a conditional — `let s: i64 = if x > 0 { 1 } else if x < 0 { -1 } else { 0 };`"
                                } else if str_eq(mname, "count_ones") == 1 || str_eq(mname, "count_zeros") == 1 || str_eq(mname, "leading_zeros") == 1 || str_eq(mname, "trailing_zeros") == 1 || str_eq(mname, "rotate_left") == 1 || str_eq(mname, "rotate_right") == 1 || str_eq(mname, "swap_bytes") == 1 {
                                    "use the bitwise operators directly (`<<`, `>>`, `&`, `|`, `^`) — these integer-intrinsic methods need a Nucleor i64 method-table that's tracked for forward-roadmap"
                                } else if str_eq(mname, "checked_add") == 1 || str_eq(mname, "checked_sub") == 1 || str_eq(mname, "checked_mul") == 1 {
                                    "Nucleor's overflow semantics are configurable via `NUCLEOR_INT_STRICT_ARITH=1` (panic-on-overflow) — bare `+` / `-` / `*` already check for overflow under strict mode. Use that, or implement the Option<i64> wrap manually"
                                } else if str_eq(mname, "wrapping_add") == 1 || str_eq(mname, "wrapping_sub") == 1 || str_eq(mname, "wrapping_mul") == 1 {
                                    "bare `+` / `-` / `*` already wrap by default (when `NUCLEOR_INT_STRICT_ARITH` is unset). Drop the `.wrapping_*()` call"
                                } else if str_eq(mname, "saturating_add") == 1 || str_eq(mname, "saturating_sub") == 1 || str_eq(mname, "saturating_mul") == 1 {
                                    "implement manually — `let r: i64 = if a > i64::MAX - b { i64::MAX } else { a + b };`"
                                } else if str_eq(mname, "is_alphabetic") == 1 {
                                    "compare codepoint ranges — `let r: bool = (c >= 65 && c <= 90) || (c >= 97 && c <= 122);` (ASCII A-Z, a-z)"
                                } else if str_eq(mname, "is_numeric") == 1 || str_eq(mname, "is_digit") == 1 {
                                    "compare codepoint range — `let r: bool = c >= 48 && c <= 57;` (ASCII 0-9)"
                                } else if str_eq(mname, "is_alphanumeric") == 1 {
                                    "combine alphabetic + numeric checks — `let r: bool = (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122);`"
                                } else if str_eq(mname, "is_ascii") == 1 {
                                    "compare codepoint range — `let r: bool = c >= 0 && c <= 127;`"
                                } else if str_eq(mname, "is_whitespace") == 1 {
                                    "match common whitespace codepoints — `let r: bool = c == 32 || c == 9 || c == 10 || c == 13;` (space, tab, newline, CR)"
                                } else if str_eq(mname, "is_lowercase") == 1 {
                                    "compare ASCII codepoint range — `let r: bool = c >= 97 && c <= 122;` (a-z)"
                                } else if str_eq(mname, "is_uppercase") == 1 {
                                    "compare ASCII codepoint range — `let r: bool = c >= 65 && c <= 90;` (A-Z)"
                                } else if str_eq(mname, "to_ascii_uppercase") == 1 {
                                    "subtract 32 if lowercase — `let u: i64 = if c >= 97 && c <= 122 { c - 32 } else { c };`"
                                } else if str_eq(mname, "to_ascii_lowercase") == 1 {
                                    "add 32 if uppercase — `let l: i64 = if c >= 65 && c <= 90 { c + 32 } else { c };`"
                                } else if str_eq(mname, "to_lowercase") == 1 || str_eq(mname, "to_uppercase") == 1 {
                                    "the iterator-returning Unicode forms aren't supported. Use the ASCII forms `.to_ascii_lowercase()` / `.to_ascii_uppercase()` (now also halted with workarounds), or compare codepoint ranges manually"
                                } else if str_eq(mname, "to_digit") == 1 {
                                    "subtract '0' codepoint — `let d: i64 = if c >= 48 && c <= 57 { c - 48 } else { -1 };` for radix-10. For other radixes add a-f / A-F branches"
                                } else if str_eq(mname, "chars") == 1 {
                                    "iterate the string by codepoint via index-based loop — `let n: i64 = str_len(s) as i64; let mut i: i64 = 0; while i < n { let c: i64 = str_char_at(s, i); ...; i = i + 1; }`. Today this iterates byte-by-byte (ASCII safe; multi-byte UTF-8 needs a separate decoder)"
                                } else if str_eq(mname, "lines") == 1 {
                                    "split on newline manually — `let parts: Vec<str> = str_split(s, \"\\n\"); for line in &parts { ... }`. The `.lines()` form returns an iterator that the v1.x iterator-protocol substrate will support"
                                } else if str_eq(mname, "bytes") == 1 {
                                    "iterate by index — `let n: i64 = str_len(s) as i64; let mut i: i64 = 0; while i < n { let b: i64 = str_char_at(s, i); ...; i = i + 1; }`. Each `b` is the raw byte value (0..255)"
                                } else if str_eq(mname, "as_bytes") == 1 {
                                    "build a `Vec<u8>` manually — `let mut bs: Vec<u8> = Vec::new(); let n: i64 = str_len(s) as i64; let mut i: i64 = 0; while i < n { vec_u8_push(bs, str_char_at(s, i) as u8); i = i + 1; }`"
                                } else if str_eq(mname, "repeat") == 1 {
                                    "concat in a loop — `let mut out: str = \"\"; let mut i: i64 = 0; while i < n { out = str_concat(out, s); i = i + 1; }`"
                                } else if str_eq(mname, "split_whitespace") == 1 || str_eq(mname, "split_terminator") == 1 || str_eq(mname, "splitn") == 1 || str_eq(mname, "rsplit") == 1 {
                                    "use `str_split(s, sep)` (single-char delimiter) and post-process. For whitespace, use `str_split(s, \" \")` and filter empty parts. For multi-delimiter or n-split forms, the iterator-protocol substrate is forward-roadmap"
                                } else if str_eq(mname, "char_indices") == 1 {
                                    "iterate by index manually — `let n: i64 = str_len(s) as i64; let mut i: i64 = 0; while i < n { let c: i64 = str_char_at(s, i); ...; i = i + 1; }` — the index is `i` and the char is `c` (matches Rust's `(usize, char)` tuple form)"
                                } else if str_eq(mname, "parse") == 1 {
                                    "use the explicit-typed conversion fn — `str_to_int(s)` for integers, `str_to_float(s)` for floats. For Result-returning forms, check the input shape via `str_starts_with(s, \"-\")` / `str_contains(s, \".\")` first"
                                } else if str_eq(mname, "dedup") == 1 {
                                    "build a new Vec, tracking prev element — `let mut out: Vec<T> = Vec::new(); let mut prev_set: i64 = 0; let mut prev: T = ...; for x in &v { if prev_set == 0 || x != prev { out.push(x); prev = x; prev_set = 1; } }`"
                                } else if str_eq(mname, "retain") == 1 {
                                    "build a new Vec via filter loop — `let mut keep: Vec<T> = Vec::new(); for x in &v { if pred(x) { keep.push(x); } } v = keep;`. The functional `.filter(...).collect()` form (now also halted) has the same shape"
                                } else if str_eq(mname, "truncate") == 1 {
                                    "pop from the end until the desired length — `while vec_len(&v) > n { v.pop(); }`"
                                } else if str_eq(mname, "resize") == 1 {
                                    "push the default value until the desired length — `while vec_len(&v) < n { v.push(default_value); }` (combine with truncate workaround above to shrink)"
                                } else if str_eq(mname, "split_at") == 1 {
                                    "build the two halves explicitly via index loops — `let mut a: Vec<T> = Vec::new(); let mut b: Vec<T> = Vec::new(); let mut i: i64 = 0; while i < vec_len(&v) { if i < mid { a.push(vec_get(&v, i)); } else { b.push(vec_get(&v, i)); } i = i + 1; }`. Tuple-return forms (`let (a, b) = ...`) are also forward-roadmap"
                                } else if str_eq(mname, "sort_by") == 1 || str_eq(mname, "sort_unstable_by") == 1 {
                                    "Nucleor's `.sort()` uses the type's natural ordering. For custom comparators, the closure-receiving form is forward-roadmap — for now, sort then post-process if the natural order isn't what you need"
                                } else if str_eq(mname, "sort_by_key") == 1 {
                                    "build a parallel key-vec, sort indices, then re-emit — or use a struct with a key field and `.sort()` (Nucleor sorts struct values by their first field today)"
                                } else if str_eq(mname, "sort_unstable") == 1 {
                                    "use `.sort()` — Nucleor today doesn't distinguish stable vs unstable; the unstable suffix is a no-op signal in Rust meaning 'don't preserve ties' but Nucleor's sort makes no stability guarantee either way"
                                } else if str_eq(mname, "max_by_key") == 1 || str_eq(mname, "min_by_key") == 1 {
                                    "manual reduce — `let mut best_val: T = vec_get(&v, 0); let mut best_key: K = key_fn(best_val); for x in &v { let k = key_fn(x); if k > best_key { best_key = k; best_val = x; } }`. Closure-receiving iterator combinators are forward-roadmap"
                                } else if str_eq(mname, "extend_from_slice") == 1 {
                                    "loop and push — `for x in &other { v.push(x); }` (Nucleor's `.extend(...)` already supports the Vec form; the slice variant requires explicit element copy)"
                                } else if str_eq(mname, "copied") == 1 || str_eq(mname, "cloned") == 1 {
                                    "drop the call — under Nucleor's i64-everywhere ABI, iterators already yield by-value (no &T → T conversion needed). `v.iter().copied().collect()` is just `v.iter().collect()`. The Rust convention exists because .iter() yields &T; here the runtime passes everything by value already"
                                } else if str_eq(mname, "as_ref") == 1 || str_eq(mname, "as_mut") == 1 {
                                    "drop the call — Nucleor's i64-everywhere ABI passes everything by value; `Option<T>.as_ref()` (which returns `Option<&T>`) is unnecessary because Nucleor's Option already yields T by value. Use `if let Some(v) = opt { ... }` directly"
                                } else if str_eq(mname, "and_then") == 1 {
                                    "Option/Result chaining — write the explicit if-let chain — `if let Some(x) = opt { f(x) } else { None }`. Closure-receiving combinators are forward-roadmap (v1.x closure-substrate)"
                                } else if str_eq(mname, "or_else") == 1 {
                                    "Option/Result fallback — write the explicit match — `match opt { Some(x) => Some(x), None => fallback() }`"
                                } else if str_eq(mname, "ok_or") == 1 || str_eq(mname, "ok_or_else") == 1 {
                                    "Option-to-Result conversion — write the explicit match — `match opt { Some(x) => Ok(x), None => Err(err_value) }`"
                                } else if str_eq(mname, "transpose") == 1 {
                                    "manual swap — `Option<Result<T, E>>` → `Result<Option<T>, E>` via match — `match opt { Some(Ok(x)) => Ok(Some(x)), Some(Err(e)) => Err(e), None => Ok(None) }`. The unsupported nested-pattern halt may fire here; split into two-step destructure"
                                } else if str_eq(mname, "expect_err") == 1 {
                                    "manual match — `match r { Err(e) => e, Ok(_) => panic(\"expected err\") }`"
                                } else if str_eq(mname, "iter_lines") == 1 {
                                    "use `.lines()` (now also halted) workaround — `let parts: Vec<str> = str_split(s, \"\\n\");`"
                                } else if str_eq(mname, "into_iter") == 1 {
                                    "drop the call — `for x in v` already iterates by-value under the i64-everywhere ABI; `for x in v.into_iter()` is just `for x in v`. The Rust convention exists because .iter() yields &T while .into_iter() yields T; here both yield T already"
                                } else if str_eq(mname, "try_into") == 1 || str_eq(mname, "try_from") == 1 {
                                    "use an explicit conversion — for narrowing casts (`i64 -> i32`) write `x as i32` (Nucleor's bare `as` cast checks NUM-003 narrowing under strict-arith mode); for Vec-to-array, build the array manually since slices and arrays are unified as Vec<T> in Nucleor today"
                                } else if str_eq(mname, "from") == 1 {
                                    "associated From::from is not yet supported — use the explicit conversion fn (`String::from(s)` is already supported; for user types write a `<Target>_from_<Src>(x: Src) -> Target` helper). The full From/Into trait family is forward-roadmap"
                                } else if str_eq(mname, "borrow") == 1 || str_eq(mname, "borrow_mut") == 1 {
                                    "drop the call — Nucleor's i64-everywhere ABI passes by value already; the Borrow/BorrowMut trait family exists in Rust to let containers accept `&str` where `String` is stored. Here just pass the value directly"
                                } else if str_eq(mname, "into_inner") == 1 {
                                    "for `Cell<T>`/`RefCell<T>`-style wrappers, those types aren't supported (forward-roadmap, sister to v0.7.12 smart-pointer halt). For `Result<T, E>::into_ok`, use `match` instead"
                                } else if str_eq(mname, "leak") == 1 {
                                    "Box::leak / Vec::leak (intentional memory leak to obtain `&'static T`) is not supported — Nucleor doesn't expose 'static lifetime semantics. Workaround: use a top-level `const` or `static` (the latter is also forward-roadmap; see v0.6.21 halt)"
                                } else if str_eq(mname, "as_str") == 1 {
                                    "drop the call — Nucleor's i64-everywhere ABI treats `String` and `str` as the same i64-pointer at the runtime level; `s.as_str()` is just `s`"
                                } else if str_eq(mname, "as_slice") == 1 {
                                    "drop the call — Nucleor doesn't distinguish Vec from slice today; `v.as_slice()` is just `v`"
                                } else if str_eq(mname, "as_ptr") == 1 {
                                    "the raw-pointer family is not yet exposed in Nucleor's surface — sister to v0.7.3 (raw-pointer types) and v0.7.14 (raw-ref expressions) halts. Use Vec/String element access (`vec_get`, `str_char_at`) instead of pointer arithmetic"
                                } else {
                                    "use a `while i < vec_len(&v) { let item: T = vec_get(&v, i); ...; i = i + 1; }` loop with index-based access — Nucleor doesn't auto-derive iterator interior mutability today"
                                };
                                print(str_concat("ERROR: `.", str_concat(mname, str_concat("()` is a canonical Rust conversion idiom that is not yet supported in Nucleor. Pre-v0.6.82 the kind-8 method-dispatch catch-all synthesized `vec_", str_concat(mname, str_concat("(receiver)` and the post-link diag re-cast as `receiver type 'Vec<T>' has no method '.", str_concat(mname, str_concat("()` — wrong-class for adopters porting Rust code. Workaround: ", str_concat(v082_workaround, ".")))))))));
                                panic(str_concat("nucleor: Rust conversion-idiom method `.", str_concat(mname, "()` not yet supported (see ERROR diagnostic above)")));
                            };
                            // narrow-RHS check for `.insert/.set`.
                            let mut alias_mname: str = mname;
                            if str_eq(mname, "insert") == 1 { alias_mname = "insert_at"; };
                            if str_eq(mname, "remove") == 1 { alias_mname = "remove_at"; };
                            fn_name = str_concat("vec_", alias_mname);
                        };
                    };
                };
            };
        };
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(r, fn_name, all_args));
        return lx_new(r, cur);
    };
    if kind == 10 {
        // catch `s[i]` for `s: str` at codegen-time. The
        // type-check side has had a TYP-011 guard since v0.4.94 but
        // it only fires when the index expression reaches type_expr
        // via the let-stmt RHS path — fn-call args, `as` casts, and
        // anything else that uses kind 10 inside a larger expression
        // sail past it (the `if type_dynamic_helper(callee) == 1`
        // early-return at line 11297 short-circuits arg-walk for
        // every runtime helper, which is most of them). Codegen
        // path catches every kind 10 unconditionally — when the
        // receiver is a var-ref to a `__type_<name>` of `str`,
        // halt cleanly before emitting `vec_get` on the str pointer.
        let recv_v117: i64 = node_field(pool, nid, 1);
        if node_kind(pool, recv_v117) == 3 {
            let recv_n: str = node_field(pool, recv_v117, 1);
            let recv_t_v117: i64 = sym_get(sym, str_concat("__type_", recv_n));
            if recv_t_v117 >= 0 && str_eq(recv_t_v117, "str") == 1 {
                panic(str_concat("error[TYP-011]: `str` does not support direct indexing with `", str_concat(recv_n, str_concat("[i]`. The codegen would lower this to `vec_get` on the str pointer, returning garbage or OOB-panicking. Use `str_char_at(", str_concat(recv_n, ", i)` to get a byte, or `str_substring(<name>, i, j)` for a substring."))))));
            };
        };
        let mut obj_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(obj_p);
        let mut cur: Vec<i32> = lx_blk(obj_p);
        let mut idx_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let idx_r: i64 = lx_reg(idx_p);
        cur = lx_blk(idx_p);
        let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
        let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
        return lx_new(r, cur);
    };
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let mname: str = node_field(pool, nid, 2);
        let args_list: i64 = node_field(pool, nid, 3);
        if str_eq(tname, "Vec") && str_eq(mname, "new") {
            let r: i64 = ctr_next(regs);
            let mut empty_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(r, "vec_new", empty_args));
            return lx_new(r, blk);
        };
        // `Vec::with_capacity(n)`. Pre-v0.3.116 fell through
        // to the diagnostic+zero path because no kind-12 handler
        // matched. Adopters reaching for the canonical Rust pre-
        // allocation pattern (`Vec::with_capacity(N)` for known-size
        // accumulators) saw their .exe return 0 from the ctor and
        // every push silently fail. The runtime helper
        // `__nucleor_vec_with_capacity` already exists; this is purely
        // the missing surface dispatch. Lower the single arg, then
        // emit a call to the runtime helper.
        if str_eq(tname, "Vec") && str_eq(mname, "with_capacity") {
            let mut wc_cur: Vec<i32> = blk;
            let mut wc_args: Vec<i32> = Vec::new();
            if list_len(pool, args_list) >= 1 {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, 0), wc_cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                wc_args.push(lx_reg(ap));
                wc_cur = lx_blk(ap);
            };
            let r: i64 = ctr_next(regs);
            ir_block_add(wc_cur, ir_call_ex(r, "vec_with_capacity", wc_args));
            return lx_new(r, wc_cur);
        };
        if str_eq(tname, "String") && str_eq(mname, "new") {
            let r: i64 = ctr_next(regs);
            let mut empty_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(r, "string_new", empty_args));
            return lx_new(r, blk);
        };
        if str_eq(tname, "Box") && str_eq(mname, "new") {
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
            let zr: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(zr, 0));
            return lx_new(zr, blk);
        };
        // Box::leak(b) — intentional memory-leak pass-through.
        // Nucleor has no automatic drop (V1.3 RAII unshipped), so
        // Box::leak is semantically identical to Box::new in the ABI:
        // just return the inner value. Callers from Rust-ported code
        // use it to obtain a &'static mut T from a heap-allocated Box;
        // in Nucleor's i64-everywhere ABI the Box IS the inner pointer.
        if str_eq(tname, "Box") && str_eq(mname, "leak") {
            if list_len(pool, args_list) > 0 {
                return lower_expr(pool, list_get(pool, args_list, 0), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            };
            let zrl: i64 = ctr_next(regs);
            ir_block_add(blk, ir_const_int(zrl, 0));
            return lx_new(zrl, blk);
        };
        // Rust-style associated-fn aliases for the lowercase
        // collection helpers. Maps `HashMap::new()` → `hashmap_new()`,
        // `HashSet::new()` → `hashset_new()`, `BTreeMap::new()` →
        // `btreemap_new()`, `BTreeSet::new()` → `btreeset_new()`,
        // `VecDeque::new()` → `vecdeque_new()`. Without this, users
        // coming from Rust who write `let m: HashMap<K,V> = HashMap::new();`
        // hit "unhandled expr kind 12" with no diagnostic and broken
        // `%r.-1` IR. The runtime helpers themselves (__nucleor_hashmap_new
        // etc.) all exist; this is purely surface-level wiring.
        if str_eq(mname, "new") {
            let mut helper_n: str = "";
            if str_eq(tname, "HashMap") { helper_n = "hashmap_new"; };
            if str_eq(tname, "HashSet") { helper_n = "hashset_new"; };
            if str_eq(tname, "BTreeMap") { helper_n = "btreemap_new"; };
            if str_eq(tname, "BTreeSet") { helper_n = "btreeset_new"; };
            if str_eq(tname, "VecDeque") { helper_n = "vecdeque_new"; };
            if str_len(helper_n) > 0 {
                let r: i64 = ctr_next(regs);
                let mut empty_args: Vec<i32> = Vec::new();
                ir_block_add(blk, ir_call_ex(r, helper_n, empty_args));
                return lx_new(r, blk);
            };
        };
        // `with_capacity(N)` for the collection family.
        // Pre-v0.3.117 only `Vec::with_capacity` (added in v0.3.116)
        // was wired; HashMap/HashSet/BTreeMap/BTreeSet/VecDeque/String
        // all silently dispatched to the diagnostic+zero path,
        // returning an empty handle that no subsequent insert/push
        // could populate. Runtime helpers `__nucleor_<type>_with_capacity`
        // already exist for each (with v0.3.116 just adding the Vec one).
        if str_eq(mname, "with_capacity") {
            let mut wch: str = "";
            if str_eq(tname, "HashMap") { wch = "hashmap_with_capacity"; };
            if str_eq(tname, "HashSet") { wch = "hashset_with_capacity"; };
            if str_eq(tname, "VecDeque") { wch = "vecdeque_with_capacity"; };
            if str_eq(tname, "String") { wch = "string_with_capacity"; };
            if str_len(wch) > 0 {
                let mut wcc: Vec<i32> = blk;
                let mut wca: Vec<i32> = Vec::new();
                if list_len(pool, args_list) >= 1 {
                    let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, 0), wcc, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    wca.push(lx_reg(ap));
                    wcc = lx_blk(ap);
                };
                let r: i64 = ctr_next(regs);
                ir_block_add(wcc, ir_call_ex(r, wch, wca));
                return lx_new(r, wcc);
            };
        };
        if str_eq(tname, "Tensor") {
            let mut t_args: Vec<i32> = Vec::new();
            let ac: i64 = list_len(pool, args_list);
            let mut ai: i64 = 0;
            let mut cur: Vec<i32> = blk;
            while ai < ac {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                t_args.push(lx_reg(ap));
                cur = lx_blk(ap);
                ai = ai + 1;
            };
            let r: i64 = ctr_next(regs);
            if str_eq(mname, "zeros") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_zeros", t_args)); }
            else if str_eq(mname, "fill") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_fill", t_args)); }
            else if str_eq(mname, "ones") { ir_block_add(cur, ir_call_ex(r, "__nucleor_tensor_ones", t_args)); };
            return lx_new(r, cur);
        };
        let etag_key: str = str_concat("__etag_", str_concat(tname, str_concat("_", mname)));
        let etag: i64 = sym_get(sym, etag_key);
        if etag >= 0 {
            let vr: i64 = ctr_next(regs);
            let mut new_args: Vec<i32> = Vec::new();
            ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
            let tr: i64 = ctr_next(regs); ir_block_add(blk, ir_const_int(tr, etag));
            let mut push_args1: Vec<i32> = Vec::new(); push_args1.push(vr); push_args1.push(tr);
            let dr1: i64 = ctr_next(regs); ir_block_add(blk, ir_call_ex(dr1, "vec_push", push_args1));
            let argc: i64 = list_len(pool, args_list);
            let mut ai: i64 = 0;
            let mut cur: Vec<i32> = blk;
            while ai < argc {
                let mut ap: Vec<i32> = lower_expr(pool, list_get(pool, args_list, ai), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let av: i64 = lx_reg(ap);
                cur = lx_blk(ap);
                let mut pa: Vec<i32> = Vec::new(); pa.push(vr); pa.push(av);
                let dp: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dp, "vec_push", pa));
                ai = ai + 1;
            };
            return lx_new(vr, cur);
        };
        // dispatch user-defined associated fns. The impl
        // block synthesizes each method as `<TypeName>__<methodname>`
        // (mangled name registered in fn_decls / impl_fns at
        // collect_impls time). Pre-v0.3.111, `Point::new(7, 3)`
        // matched none of the built-in Type::method handlers above,
        // skipped the etag enum-variant check (Point isn't an enum),
        // hit the diagnostic, and emitted const_int 0 — silent
        // miscompute returning 0 from any user constructor.
        // Adopters reaching for the canonical `let p = Point::new(...)`
        // pattern saw a printed error but their .exe still ran with
        // wrong values. Lookup `__fnret_<mangled>` to confirm the
        // method exists; if so, lower as a normal i64 fn call with
        // the args (the function takes the args directly, not a
        // self prefix, since this is an associated fn — not an
        // instance method).
        let mangled: str = str_concat(tname, str_concat("__", mname));
        let mret: i64 = sym_get(sym, str_concat("__fnret_", mangled));
        if mret >= 0 {
            let mut maa: Vec<i32> = Vec::new();
            let mac: i64 = list_len(pool, args_list);
            let mut mai: i64 = 0;
            let mut mcur: Vec<i32> = blk;
            while mai < mac {
                let mut mp: Vec<i32> = lower_expr(pool, list_get(pool, args_list, mai), mcur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                maa.push(lx_reg(mp));
                mcur = lx_blk(mp);
                mai = mai + 1;
            };
            let mr: i64 = ctr_next(regs);
            ir_block_add(mcur, ir_call_ex(mr, mangled, maa));
            return lx_new(mr, mcur);
        };
        // defensive halt: canonical Rust path-rooted fn
        // calls `crate::foo(...)`, `super::foo(...)`, `self::foo(...)`
        // pre-fix surfaced via the generic v0.3.71 "unsupported
        // associated-fn call" diag, which mentioned only Vec/String/
        // etc. — not adopter-actionable for the path case. Detect
        // the `crate`/`super`/`self` roots and halt with a clean
        // workaround pointer (drop the path prefix — Nucleor has a
        // flat fn namespace today).
        if str_eq(tname, "crate") == 1 || str_eq(tname, "super") == 1 || str_eq(tname, "self") == 1 {
            print(str_concat("ERROR: path-rooted fn call `", str_concat(tname, str_concat("::", str_concat(mname, "(...)` is not yet supported in Nucleor. — not adopter-actionable. Nucleor has a flat fn namespace today (no `crate::` / `super::` / `self::` rooting), and the resolved fn name `", str_concat(mname, str_concat("` is callable directly. Workaround: drop the `", str_concat(tname, str_concat("::` prefix — call ", str_concat(mname, "(...) directly.")))))))))));
            panic(str_concat("nucleor: path-rooted fn call `", str_concat(tname, str_concat("::", str_concat(mname, "` not yet supported (see ERROR diagnostic above)")))));
        };
        let mut v712_smart_kind: str = "";
        if str_eq(tname, "Cell") == 1 { v712_smart_kind = "interior mutability"; };
        if str_eq(tname, "RefCell") == 1 { v712_smart_kind = "interior mutability"; };
        if str_eq(tname, "Rc") == 1 { v712_smart_kind = "shared ownership"; };
        if str_eq(tname, "Arc") == 1 { v712_smart_kind = "shared ownership (atomic)"; };
        if str_eq(tname, "Mutex") == 1 { v712_smart_kind = "thread-safe interior mutability"; };
        if str_eq(tname, "RwLock") == 1 { v712_smart_kind = "thread-safe read-write lock"; };
        if str_eq(tname, "Weak") == 1 { v712_smart_kind = "weak reference"; };
        if str_len(v712_smart_kind) > 0 {
            print("ERROR: Rust stdlib smart-pointer type is not yet supported in Nucleor.");
            print(str_concat("       Type: `", str_concat(tname, str_concat("` (", str_concat(v712_smart_kind, ")")))));
            print("       Pre-v0.7.12 surfaced via the generic 'unsupported associated-fn call' diag.");
            print("       Nucleor's i64-everywhere ABI doesn't yet have a borrow-checker, so interior-");
            print("       mutability / shared-ownership / lock wrappers are NOT NEEDED for the typical");
            print("       adopter use case.");
            print("       Workaround: use the bare type with `let mut` for mutability — `let mut x: i64 =");
            print("       42; x = 100;` (no Cell needed). For shared ownership the i64 ABI already passes");
            print("       by value (the heap pointer is copied) — no Rc/Arc needed. Real threading uses");
            print("       `async_spawn` (RFC-0027, see stdlib/rods/async.nr).");
            panic(str_concat("nucleor: smart-pointer type `", str_concat(tname, "` not yet supported (see ERROR diagnostic above)")));
        };
        // defensive halt — Default trait: canonical Rust
        // `i64::default()`, `String::default()`, `Default::default()`
        // pre-fix surfaced via the generic v0.3.71 "unsupported
        // associated-fn call" diag. Default trait isn't yet shipped
        // in Nucleor — the canonical `T::default()` pattern needs
        // per-type Default impls + a `Default::default()` ambient
        // dispatch through type inference. Halt cleanly with a
        // per-type literal-default workaround pointer.
        if str_eq(mname, "default") == 1 {
            let v076_hint: str = if str_eq(tname, "i8") == 1 || str_eq(tname, "i16") == 1 || str_eq(tname, "i32") == 1 || str_eq(tname, "i64") == 1 || str_eq(tname, "isize") == 1 || str_eq(tname, "u8") == 1 || str_eq(tname, "u16") == 1 || str_eq(tname, "u32") == 1 || str_eq(tname, "u64") == 1 || str_eq(tname, "usize") == 1 {
                "0"
            } else if str_eq(tname, "f32") == 1 || str_eq(tname, "f64") == 1 {
                "0.0"
            } else if str_eq(tname, "bool") == 1 {
                "false"
            } else if str_eq(tname, "str") == 1 {
                "\"\""
            } else if str_eq(tname, "String") == 1 {
                "String::new()"
            } else if str_eq(tname, "Vec") == 1 {
                "Vec::new()"
            } else if str_eq(tname, "HashMap") == 1 {
                "HashMap::new()"
            } else {
                "<construct the type explicitly>"
            };
            print(str_concat("ERROR: `", str_concat(tname, str_concat("::default()` (Default trait) is not yet supported in Nucleor. Workaround: use the literal default value for this type — `", str_concat(v076_hint, "`. Tracked for forward-roadmap (Default trait substrate is sister to V1.4 derive(PartialEq) — both annotation-driven trait derives).")))));
            panic(str_concat("nucleor: `", str_concat(tname, "::default()` not yet supported (see ERROR diagnostic above)")));
        };
        // surface a clear diagnostic instead of falling through
        // to the generic "unhandled expr kind 12" + broken `%r.-1` IR.
        // Production-readiness: any unsupported `Type::method(...)` shape
        // now reports the exact type and method that needs wiring.
        print(str_concat("ERROR: unsupported associated-fn call ", str_concat(tname, str_concat("::", str_concat(mname, "(...). Supported: Vec/String/Box/HashMap/HSet/BTMap/BTSet/VecDeque ::new, Tensor::{zeros,fill,ones}, enum variants. For Rust-style HashMap/etc operations, use the lowercase API (hashmap_new, hashmap_insert, ...) until method dispatch lands.")))));
        // pre-fix this lowered to `const_int(0)` and continued
        // — silent miscompute. Adopters writing
        // `let x: Foo = Bar::unknown_method()` got x = 0 in the binary
        // with no link/runtime failure. Halt the compiler now so the
        // diagnostic above is seen as a hard error, not a passing build.
        panic(str_concat("nucleor: unsupported associated-fn call ", str_concat(tname, str_concat("::", mname))));
        let zr: i64 = ctr_next(regs);
        ir_block_add(blk, ir_const_int(zr, 0));
        return lx_new(zr, blk);
    };
    if kind == 52 {
        let mode: i64 = node_field(pool, nid, 1);
        let body: i64 = node_field(pool, nid, 2);
        // for `saturating { ... }` (mode==2), set
        // __arith_mode=2 in the body's sym so the kind-4 binop
        // dispatch routes +/-/* through saturating_add/sub/mul.
        // The body's exit value is returned directly (no final
        // sat_i32 clamp — the per-op saturation handled it).
        // `wrapping { ... }` (mode==1) keeps the final wrap_i32
        // shape because Nucleor's wrapping semantics target i32
        // representation, not per-op i64 wrap (which is what raw
        // i64 arith does anyway).
        let body_sym_sat: Vec<i32> = sym_clone(sym);
        if mode == 1 { sym_set(body_sym_sat, "__arith_mode", 1); };
        if mode == 2 { sym_set(body_sym_sat, "__arith_mode", 2); };
        let mut bp: Vec<i32> = lower_if_expr_branch(pool, body, blk, regs, lbls, body_sym_sat, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mut br: i64 = lx_reg(bp);
        let mut cur: Vec<i32> = lx_blk(bp);
        if br < 0 {
            br = ctr_next(regs);
            ir_block_add(cur, ir_const_int(br, 0));
        };
        if mode == 2 { return lx_new(br, cur); };
        let mut wrap_args: Vec<i32> = Vec::new();
        wrap_args.push(br);
        let r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(r, "wrap_i32", wrap_args));
        return lx_new(r, cur);
    };
    if kind == 23 {
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        let cur: Vec<i32> = lx_blk(cp);
        let tmp: i64 = ctr_next(regs);
        ir_fn_add_entry_alloca(fir, tmp);
        let tl: i64 = ctr_next(lbls);
        let el: i64 = ctr_next(lbls);
        let ml: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br_cond(cr, tl, el));

        let mut tb: Vec<i32> = ir_block_new(tl);
        ir_fn_add_block(fir, tb);
        let mut tp: Vec<i32> = lower_if_expr_branch(pool, node_field(pool, nid, 2), tb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
        tb = lx_blk(tp);
        let tv: i64 = lx_reg(tp);
        if block_has_term(tb) == 0 {
            let mut store_tv: i64 = tv;
            if store_tv < 0 {
                let tz: i64 = ctr_next(regs);
                ir_block_add(tb, ir_const_int(tz, 0));
                store_tv = tz;
            };
            ir_block_add(tb, ir_store(store_tv, tmp));
            ir_block_add(tb, ir_br(ml));
        };

        let enode: i64 = node_field(pool, nid, 3);
        let mut eb: Vec<i32> = ir_block_new(el);
        ir_fn_add_block(fir, eb);
        if enode >= 0 {
            let mut ep: Vec<i32> = lower_if_expr_branch(pool, enode, eb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
            eb = lx_blk(ep);
            let fv: i64 = lx_reg(ep);
            if block_has_term(eb) == 0 {
                let mut store_fv: i64 = fv;
                if store_fv < 0 {
                    let ez: i64 = ctr_next(regs);
                    ir_block_add(eb, ir_const_int(ez, 0));
                    store_fv = ez;
                };
                ir_block_add(eb, ir_store(store_fv, tmp));
                ir_block_add(eb, ir_br(ml));
            };
        } else {
            let ez: i64 = ctr_next(regs);
            ir_block_add(eb, ir_const_int(ez, 0));
            ir_block_add(eb, ir_store(ez, tmp));
            ir_block_add(eb, ir_br(ml));
        };

        let mut mb: Vec<i32> = ir_block_new(ml);
        ir_fn_add_block(fir, mb);
        let r: i64 = ctr_next(regs);
        ir_block_add(mb, ir_load(r, tmp));
        return lx_new(r, mb);
    };
    if kind == 38 {
        let scrut_nid: i64 = node_field(pool, nid, 1);
        let scrut_t: str = expr_full_type_from_sym(pool, scrut_nid, sym, structs);
        let mut mp: Vec<i32> = lower_expr(pool, scrut_nid, blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mexpr_r: i64 = lx_reg(mp);
        let mut cur: Vec<i32> = lx_blk(mp);
        let mslot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, mslot);
        ir_block_add(cur, ir_store(mexpr_r, mslot));
        let tmp: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, tmp);
        let arms_list: i64 = node_field(pool, nid, 2);
        let arm_cnt: i64 = list_len(pool, arms_list);
        let ml: i64 = ctr_next(lbls);
        let mut tag_r: i64 = 0 - 1;
        let mut ci: i64 = 0;
        while ci < arm_cnt {
            let arm_nid: i64 = list_get(pool, arms_list, ci);
            let ename: str = node_field(pool, arm_nid, 1);
            let vname: str = node_field(pool, arm_nid, 2);
            let binding: str = node_field(pool, arm_nid, 3);
            let body_list: i64 = node_field(pool, arm_nid, 4);
            let guard_nid: i64 = node_field(pool, arm_nid, 5);
            let al: i64 = ctr_next(lbls);
            let nl: i64 = ctr_next(lbls);
            if str_eq(ename, "__wild") {
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    gb = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(gb) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(gb, ir_const_int(rv, 0)); };
                        ir_block_add(gb, ir_store(rv, tmp));
                        ir_block_add(gb, ir_br(ml));
                    };
                } else {
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    ab = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(ab) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                        ir_block_add(ab, ir_store(rv, tmp));
                        ir_block_add(ab, ir_br(ml));
                    };
                };
            } else if str_eq(ename, "__int") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let iv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(iv_r, vname));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, mv, iv_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else if str_eq(ename, "__range") == 1 || str_eq(ename, "__range_at") == 1 {
                // RFC-0023 §3.1: range pattern. vname = LO (i64 cell),
                // binding = str_from_int(HI) (inclusive — half-open ranges
                // were normalized at parse). Match if LO <= scrut && scrut
                // <= HI.
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let lo_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(lo_r, vname));
                let hi_s: str = str_before_char_local(binding, 124);
                let hi_n: i64 = str_to_int(hi_s);
                let hi_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(hi_r, hi_n));
                let lo_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, lo_ok, lo_r, mv));
                let hi_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, hi_ok, mv, hi_r));
                let both_r: i64 = ctr_next(regs); ir_block_add(cur, ir_binop(13, both_r, lo_ok, hi_ok));
                ir_block_add(cur, ir_br_cond(both_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let arm_sym: Vec<i32> = sym_clone(sym);
                if str_eq(ename, "__range_at") == 1 {
                    ab = match_bind_whole(str_after_char_local(binding, 124), ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else if str_eq(ename, "__range_bad") == 1 || str_eq(ename, "__range_bad_at") == 1 {
                // MATCH-007 fired by the typecker (paired pass). Lower as
                // never-match so program compiles; warning surfaces in the
                // diagnostic stream.
                ir_block_add(cur, ir_br(nl));
            } else if str_eq(ename, "__str") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                // intern via strtab_intern to dedup.
                let sidx: i64 = strtab_intern(strtab, fir, vname);
                let sv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_str(sv_r, sidx));
                let mut eq_args: Vec<i32> = Vec::new(); eq_args.push(mv); eq_args.push(sv_r);
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(cmp_r, "str_eq", eq_args));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, "str");
                };
                let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                ab = lx_blk(bp);
                let mut rv: i64 = lx_reg(bp);
                if block_has_term(ab) == 0 {
                    if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                    ir_block_add(ab, ir_store(rv, tmp));
                    ir_block_add(ab, ir_br(ml));
                };
            } else if str_eq(ename, "__struct") {
                // struct destructure with pattern guard fall-through.
                // Pre-fix the __struct arm in lower_expr (match-as-value) had
                // no guard handling — `Point { x, y } if cond => A` always
                // executed `A` regardless of guard evaluation, producing a
                // silent miscompute. Mirror the __wild guard pattern: bind
                // fields, then conditionally branch on the guard's truth.
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_struct_fields(binding, ab, regs, arm_sym, mslot, fir, structs, pool, vname, scrut_t);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    gb = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(gb) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(gb, ir_const_int(rv, 0)); };
                        ir_block_add(gb, ir_store(rv, tmp));
                        ir_block_add(gb, ir_br(ml));
                    };
                } else {
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    ab = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(ab) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                        ir_block_add(ab, ir_store(rv, tmp));
                        ir_block_add(ab, ir_br(ml));
                    };
                };
            } else if str_eq(ename, "__tuple") == 1 || str_eq(ename, "__slice") == 1 {
                // tuple/slice pattern with guard fall-through.
                // Same bug class as v0.4.202 __struct fix.
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let mut len_args: Vec<i32> = Vec::new(); len_args.push(mv);
                let len_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(len_r, "vec_len", len_args));
                let needed: i64 = pattern_list_value_count(binding);
                let needed_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(needed_r, needed));
                let cmp_r: i64 = ctr_next(regs);
                if str_eq(ename, "__slice") == 1 && pattern_list_has_rest(binding) == 1 {
                    ir_block_add(cur, ir_cmpop(11, cmp_r, needed_r, len_r));
                } else {
                    ir_block_add(cur, ir_cmpop(7, cmp_r, len_r, needed_r));
                };
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_vec_pattern(binding, ab, regs, arm_sym, mslot, fir, scrut_t, len_r);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    gb = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(gb) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(gb, ir_const_int(rv, 0)); };
                        ir_block_add(gb, ir_store(rv, tmp));
                        ir_block_add(gb, ir_br(ml));
                    };
                } else {
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    ab = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(ab) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                        ir_block_add(ab, ir_store(rv, tmp));
                        ir_block_add(ab, ir_br(ml));
                    };
                };
            } else {
                // enum-variant-with-payload pattern with guard
                // fall-through. Same bug class as v0.4.202 __struct fix.
                if tag_r < 0 {
                    let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                    let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
                    let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(mv); tag_args.push(zero_r);
                    tag_r = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
                };
                let etag_key: str = str_concat("__etag_", str_concat(ename, str_concat("_", vname)));
                let vtag: i64 = sym_get(sym, etag_key);
                let vtag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(vtag_r, vtag));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, vtag_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                let payload_binding: str = pattern_after_at_prefix(binding);
                let at_name: str = pattern_at_prefix_name(binding);
                if str_len(at_name) > 0 { ab = match_bind_whole(at_name, ab, regs, arm_sym, mslot, fir, scrut_t); };
                ab = match_bind_payloads_per_idx(payload_binding, ab, regs, arm_sym, mslot, fir, ename, vname, scrut_t);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    gb = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(gb) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(gb, ir_const_int(rv, 0)); };
                        ir_block_add(gb, ir_store(rv, tmp));
                        ir_block_add(gb, ir_br(ml));
                    };
                } else {
                    let mut bp: Vec<i32> = lower_if_expr_branch(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    ab = lx_blk(bp);
                    let mut rv: i64 = lx_reg(bp);
                    if block_has_term(ab) == 0 {
                        if rv < 0 { rv = ctr_next(regs); ir_block_add(ab, ir_const_int(rv, 0)); };
                        ir_block_add(ab, ir_store(rv, tmp));
                        ir_block_add(ab, ir_br(ml));
                    };
                };
            };
            let mut nb: Vec<i32> = ir_block_new(nl); ir_fn_add_block(fir, nb);
            cur = nb;
            ci = ci + 1;
        };
        ir_block_add(cur, ir_br(ml));
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb);
        let r: i64 = ctr_next(regs);
        ir_block_add(mb, ir_load(r, tmp));
        return lx_new(r, mb);
    };
    if kind == 47 || kind == 48 {
        let items_list: i64 = node_field(pool, nid, 1);
        let vr: i64 = ctr_next(regs);
        let mut new_args: Vec<i32> = Vec::new();
        ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
        let ic: i64 = list_len(pool, items_list);
        let mut ii: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while ii < ic {
            let mut ep: Vec<i32> = lower_expr(pool, list_get(pool, items_list, ii), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let ev: i64 = lx_reg(ep);
            cur = lx_blk(ep);
            let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(ev);
            let dr: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dr, "vec_push", push_args));
            ii = ii + 1;
        };
        return lx_new(vr, cur);
    };
    if kind == 34 {
        let sname: str = node_field(pool, nid, 1);
        let init_list: i64 = node_field(pool, nid, 2);
        let si: i64 = struct_find_type(pool, structs, sname);
        if si < 0 {
            if str_eq(sname, "Self") == 1 {
                print("ERROR: `Self { ... }` struct constructor inside `impl` blocks is not yet supported in Nucleor. Workaround: write the struct name explicitly — `impl Counter { fn make(x: i64) -> Counter { return Counter { n: x }; } }`.");
                panic("nucleor: `Self { ... }` constructor in impl block not yet supported (see ERROR diagnostic above)");
            };
            print(str_concat("ERROR: unknown struct ", sname));
            // pre-fix lowered to `lx_new(-1, blk)` which produced
            // `%r.-1` invalid IR — clang caught it but pointed at LLVM,
            // not source (NUC-FEEDBACK-010 territory). Halt at compiler
            // level so the diagnostic above is the actionable error.
            panic(str_concat("nucleor: unknown struct ", sname));
            return lx_new(0 - 1, blk);
        };
        let s_nid: i64 = vec_get(structs, si);
        let flist: i64 = node_field(pool, s_nid, 2);
        let fc: i64 = list_len(pool, flist);
        let vr: i64 = ctr_next(regs);
        let mut new_args: Vec<i32> = Vec::new();
        ir_block_add(blk, ir_call_ex(vr, "vec_new", new_args));
        let mut fi: i64 = 0;
        let mut cur: Vec<i32> = blk;
        while fi < fc {
            let decl_fname: str = node_field(pool, list_get(pool, flist, fi), 1);
            let ic: i64 = list_len(pool, init_list);
            let mut ii: i64 = 0;
            let mut found: i64 = 0;
            while ii < ic {
                let init_nid: i64 = list_get(pool, init_list, ii);
                if str_eq(node_field(pool, init_nid, 1), decl_fname) {
                    let mut vp: Vec<i32> = lower_expr(pool, node_field(pool, init_nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let val_r: i64 = lx_reg(vp);
                    cur = lx_blk(vp);
                    let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(val_r);
                    let pr2: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pr2, "vec_push", push_args));
                    found = 1; ii = ic;
                };
                ii = ii + 1;
            };
            if found == 0 {
                let zr: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zr, 0));
                let mut push_args: Vec<i32> = Vec::new(); push_args.push(vr); push_args.push(zr);
                let pr2: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(pr2, "vec_push", push_args));
            };
            fi = fi + 1;
        };
        return lx_new(vr, cur);
    };
    if kind == 9 {
        let mut op: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), blk, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let obj_r: i64 = lx_reg(op);
        let cur: Vec<i32> = lx_blk(op);
        let fname: str = node_field(pool, nid, 2);
        if str_is_digits(fname) == 1 {
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, str_to_int(fname)));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
            let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
            return lx_new(r, cur);
        };
        let stype: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        let si: i64 = struct_find_type(pool, structs, stype);
        if si >= 0 {
            let fi2: i64 = struct_field_idx(pool, vec_get(structs, si), fname);
            let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, fi2));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(obj_r); get_args.push(idx_r);
            let r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(r, "vec_get", get_args));
            return lx_new(r, cur);
        };
        // NUC-FEEDBACK-010 ask -- improve the error so
        // adopters know what to do instead of seeing the cryptic
        // downstream `use of undefined value '%r.-1'` from clang.
        // NUC-FEEDBACK-010 follow-on -- TRUE pre-IR halt.
        // Threading lower_error through ~44 lower_expr sites was the
        // architectural blocker; sidestep it by calling panic() from
        // the compiler itself. The s1 compiler IS a Nucleor program,
        // so a panic() call here invokes __nucleor_panic in the
        // compiler's own runtime, exiting the COMPILER process with
        // status 1 BEFORE clang is ever invoked. Adopters see the
        // diagnostic followed by a clean `panic` line, no `%r.-1`
        // confusion, no clang link spew.
        // defensive halt: canonical Rust complex-receiver
        // `.await` (e.g. `fetch().await`, `arr[0].await`,
        // `expr.method().await`) pre-fix surfaced as the generic
        // "cannot resolve field access .await" diag because the
        // expand_async_await textual pass only handles the simple
        // `<ident>.await` form (line ~26145). Halt cleanly here at
        // lower-time with a workaround pointer (extract the
        // expression to a let-binding first, then `.await` the
        // ident).
        if str_eq(fname, "await") == 1 {
            print("ERROR: complex-receiver `.await` (e.g. `fetch().await`, `arr[0].await`, `expr.method().await`) is not yet supported in Nucleor. Workaround: extract the expression to a let-binding first, then `.await` the ident — `let h: i64 = fetch(); let v: i64 = h.await;`.");
            panic("nucleor: complex-receiver `.await` not yet supported (see ERROR diagnostic above)");
        };
        // RFC V1.11 adopter wrong-class halt: canonical Rust
        // anonymous-tuple binding `let p: (i64, i64) = (5, 7); p.0`
        // pre-fix surfaced as the generic "cannot resolve field access"
        // diag — wrong class. Anonymous tuples are not yet supported in
        // Nucleor (V1.1 closed only NAMED tuple-struct decls). Detect
        // the parenthesized-type shape and halt with a clean workaround
        // pointer (named tuple-struct).
        if str_len(stype) >= 2 && str_char_at(stype, 0) == 40 {
            let stlen: i64 = str_len(stype);
            if str_char_at(stype, stlen - 1) == 41 {
                print(str_concat("ERROR: anonymous tuple types `(T1, T2, ...)` are not yet supported in Nucleor. Workaround: declare a named tuple-struct (V1.1, shipped v0.6.74) and use it instead — `struct Pair(i64, i64); let p: Pair = Pair(5, 7); print_int(p.0 as i32);`.", ""));
                panic("nucleor: anonymous tuple type field access not yet supported (use named tuple-struct — see ERROR diagnostic above)");
            };
        };
        print(str_concat("ERROR: cannot resolve field access type for .", fname));
        print("       Likely causes:");
        print("         (1) Receiver expression type couldn't be inferred (try");
        print("             extracting to a `let x: StructName = ...` binding first).");
        print("         (2) Field name not found in the receiver struct (check");
        print("             spelling against the struct definition).");
        print("         (3) Receiver struct was defined in a different module that");
        print("             isn't imported / publicly visible.");
        print("       If field name contains a substring matching a Nucleor keyword");
        print("       (e.g. `static`, `loop`, `as`), try renaming -- contextual-keyword");
        print("       lexer interactions are an open hazard class.");
        panic(str_concat("nucleor: cannot resolve field access .", fname));
        return lx_new(0 - 1, cur);
    };
    if kind == 42 {
        let param_list: i64 = node_field(pool, nid, 1);
        let body_list: i64 = node_field(pool, nid, 2);
        let clo_idx: i64 = vec_len(closures);
        let clo_name: str = str_concat("__closure_", str_from_int(clo_idx));
        let user_pc: i64 = list_len(pool, param_list);
        // Closure body takes a leading synthetic %p.0 = __env (the
        // unboxed environment pointer); user params shift to %p.1..N.
        let pc: i64 = user_pc + 1;
        let mut clo_regs: Vec<i32> = ctr_new();
        let mut clo_lbls: Vec<i32> = ctr_new();
        let mut clo_sym: Vec<i32> = sym_new();
        sym_set(clo_sym, "__closure_id", clo_idx);
        let mut clo_fir: Vec<i32> = ir_fn_new(clo_name, pc);
        ir_fn_set_strtab_aux(clo_fir, ir_fn_strtab_aux(fir));
        let mut clo_b0: Vec<i32> = ir_block_new(0);
        ir_fn_add_block(clo_fir, clo_b0);
        let mut captures: Vec<i32> = Vec::new();
        let bc: i64 = list_len(pool, body_list);
        let mut bi: i64 = 0;
        while bi < bc {
            closure_collect_capture_stmt(pool, list_get(pool, body_list, bi), sym, param_list, captures);
            bi = bi + 1;
        };
        // Synthetic __env param at slot 0 (the unboxed env pointer).
        // Stash the reg in clo_sym so the assign-to-capture path inside
        // the body can emit env_set_cap on the right env.
        let env_param_reg: i64 = ctr_next(clo_regs);
        ir_block_add(clo_b0, ir_param_ref(env_param_reg, 0));
        sym_set(clo_sym, "__env_reg", env_param_reg);
        let mut cpi: i64 = 0;
        while cpi < user_pc {
            let cpname: str = list_get(pool, param_list, cpi);
            let car: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_alloca(car));
            // User params shift by +1 because env occupies slot 0.
            let cpr: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_param_ref(cpr, cpi + 1));
            ir_block_add(clo_b0, ir_store(cpr, car));
            sym_set(clo_sym, cpname, car);
            sym_set(clo_sym, str_concat("__type_", cpname), "i64");
            cpi = cpi + 1;
        };
        let mut capi: i64 = 0;
        while capi < vec_len(captures) {
            let capname: str = vec_get(captures, capi);
            let car: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_alloca(car));
            // Load captured value from the per-instance env, not the
            // legacy per-literal global table.
            let cap_id_r: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_const_int(cap_id_r, capi));
            let mut get_args: Vec<i32> = Vec::new(); get_args.push(env_param_reg); get_args.push(cap_id_r);
            let cval: i64 = ctr_next(clo_regs); ir_block_add(clo_b0, ir_call_ex(cval, "nuc_closure_env_get_cap", get_args));
            ir_block_add(clo_b0, ir_store(cval, car));
            sym_set(clo_sym, capname, car);
            sym_set(clo_sym, str_concat("__capid_", capname), capi);
            // propagate the captured variable's TYPE entry
            // from the parent sym so expr_struct_type can resolve
            // field accesses inside the closure body. Pre-v0.3.129
            // the closure's clo_sym had the captured slot but no
            // `__type_<capname>` entry — `cfg.factor` (where cfg was
            // captured) failed to resolve to a struct field, lowered
            // to register -1, and clang link errored with
            // `use of undefined value '%r.-1'`. Without this entry
            // adopters couldn't access fields of any captured struct
            // inside a closure (very common pattern: closure
            // capturing a config / context struct).
            let parent_type: i64 = sym_get(sym, str_concat("__type_", capname));
            if parent_type >= 0 {
                sym_set(clo_sym, str_concat("__type_", capname), parent_type);
            };
            let parent_full: i64 = sym_get(sym, str_concat("__fulltype_", capname));
            if parent_full >= 0 {
                sym_set(clo_sym, str_concat("__fulltype_", capname), parent_full);
            };
            capi = capi + 1;
        };
        // push the closure into `closures` BEFORE lowering
        // its body. Pre-v0.3.107 the push happened AFTER body lowering,
        // so nested closures (a closure inside another closure's body)
        // queried `vec_len(closures)` at line 10541 and saw the same
        // count as the outer closure — both got `__closure_0`, which
        // hard-failed at clang link with `invalid redefinition of
        // function '__closure_0'`. Pushing first reserves the slot
        // for clo_idx (already allocated above) so nested closures
        // get the next id (1, 2, …). Safe because clo_fir is a Vec
        // reference and lower_stmts mutates it in place — the
        // closures list holds the same pointer either way.
        closures.push(clo_fir);
        // braced-body tail-expression handling. Pre-fix
        // `|y| { y + 7 }` lowered the kind-25 expr-stmt as a discard
        // (lower_stmts → kind 25 → evaluate, drop result) and then
        // synthesized `ret 0` for the missing terminator — silent
        // miscompute returning 0. The bare-expression form
        // `|y| y + 7` already worked because parse_primary wraps the
        // single body expr as kind 22 (return-with-value) directly.
        // Fix: mirror lower_fn's tail-expr handling — if the last
        // body item is a stmt that carries a tail expression value
        // (kind 25 = expr-stmt, 23 = if-expr, 38 = match-expr), lower
        // all stmts up to the last via lower_stmt, then lower the
        // last stmt's payload via lower_expr and emit `ret rv`.
        let bcnt_clo: i64 = list_len(pool, body_list);
        let mut last_kind_clo: i64 = 0 - 1;
        if bcnt_clo > 0 { last_kind_clo = node_kind(pool, list_get(pool, body_list, bcnt_clo - 1)); };
        let mut clo_fb: Vec<i32> = clo_b0;
        if bcnt_clo > 0 && (last_kind_clo == 25 || last_kind_clo == 23 || last_kind_clo == 38) {
            let mut bi_clo: i64 = 0;
            while bi_clo + 1 < bcnt_clo {
                clo_fb = lower_stmt(pool, list_get(pool, body_list, bi_clo), clo_fb, clo_regs, clo_lbls, clo_sym, clo_fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
                bi_clo = bi_clo + 1;
            };
            let last_stmt_clo: i64 = list_get(pool, body_list, bcnt_clo - 1);
            let mut expr_nid_clo: i64 = last_stmt_clo;
            if last_kind_clo == 25 { expr_nid_clo = node_field(pool, last_stmt_clo, 1); };
            let mut ep_clo: Vec<i32> = lower_expr(pool, expr_nid_clo, clo_fb, clo_regs, clo_lbls, clo_sym, clo_fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            clo_fb = lx_blk(ep_clo);
            let mut rv_clo: i64 = lx_reg(ep_clo);
            if block_has_term(clo_fb) == 0 {
                if rv_clo < 0 {
                    rv_clo = ctr_next(clo_regs);
                    ir_block_add(clo_fb, ir_const_int(rv_clo, 0));
                };
                ir_block_add(clo_fb, ir_ret(rv_clo));
            };
        } else {
            clo_fb = lower_stmts(pool, body_list, clo_b0, clo_regs, clo_lbls, clo_sym, clo_fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            if block_has_term(clo_fb) == 0 {
                let czr: i64 = ctr_next(clo_regs);
                ir_block_add(clo_fb, ir_const_int(czr, 0));
                ir_block_add(clo_fb, ir_ret(czr));
            };
        };
        let mut cur: Vec<i32> = blk;
        // Closure literal evaluation:
        //   env = nuc_closure_env_new(fn_ptr, cap_count)
        //   for each capture i: nuc_closure_env_set_cap(env, i, value)
        //   raw = nuc_closure_box(env)     ; surface i64 = env_ptr | 1
        // The closure value at the surface is `raw`, a tagged pointer
        // distinguishable from a bare fn-ptr at indirect-call sites.
        let fn_ptr_r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_fn_ptr(fn_ptr_r, clo_name));
        let cap_count_r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_const_int(cap_count_r, vec_len(captures)));
        let mut env_new_args: Vec<i32> = Vec::new();
        env_new_args.push(fn_ptr_r);
        env_new_args.push(cap_count_r);
        let env_r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(env_r, "nuc_closure_env_new", env_new_args));
        let mut capi2: i64 = 0;
        while capi2 < vec_len(captures) {
            let capname2: str = vec_get(captures, capi2);
            let capslot: i64 = sym_get(sym, capname2);
            if capslot >= 0 {
                let capv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(capv, capslot));
                let idx_r2: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r2, capi2));
                let mut set_args: Vec<i32> = Vec::new();
                set_args.push(env_r); set_args.push(idx_r2); set_args.push(capv);
                let dr: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(dr, "nuc_closure_env_set_cap", set_args));
            };
            capi2 = capi2 + 1;
        };
        let mut box_args: Vec<i32> = Vec::new();
        box_args.push(env_r);
        let boxed_r: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(boxed_r, "nuc_closure_box", box_args));
        // Stash metadata so the let-and-call writeback path can find
        // the right closure-local slot at the call site.
        sym_set(sym, "__last_closure_id", clo_idx);
        sym_set(sym, "__last_closure_caps", capture_names_to_string(captures));
        return lx_new(boxed_r, cur);
    };
    print(str_concat("ERROR: unhandled expr kind ", str_from_int(kind)));
    // pre-fix this returned `lx_new(-1, blk)` which lowered
    // downstream to `%r.-1` invalid IR — clang caught the broken IR
    // but produced a confusing "use of undefined value" message that
    // pointed at IR, not source. Halting at compiler level surfaces
    // the actual cause: an AST node kind the lowerer doesn't handle
    // (likely a new feature not yet wired or a parser/lower drift).
    panic(str_concat("nucleor: unhandled expr kind ", str_from_int(kind)));
    return lx_new(0 - 1, blk);
}
// T1.1 Phase 5: detect whether an AST expression node has a known
// float type (f32 or f64), looking through variable reads (kind==3)
// and float literals (kind==71). Returns "f32"/"f64"/"" .
// populate sym with `__fnret_NAME = rtype` entries
// for every fn declared in pool. Walks the entire pool once,
// skipping non-fn nodes. Called from lower_fn at the start of each
// fn body so binop_float_type's kind==7 (call) branch can look up
// the called fn's return type via the existing sym mechanism — no
// signature plumbing required.
// Pool walk caveat: pool nodes form a flat arena. Fn decls are
// kind 30 (regular) and kind 32 (extern). The walk uses node_kind
// at every offset and bails early once we run off the end (handled
// by node_kind returning -1 / 0 for invalid offsets in the arena).
#[manual_drop]
fn populate_fn_returns_in_sym(pool: Vec<i32>, fn_decls: Vec<i32>, sym: Vec<i32>) -> i64 {
    let n: i64 = vec_len(fn_decls);
    let mut i: i64 = 0;
    while i < n {
        let fnid: i64 = vec_get(fn_decls, i);
        let name: str = node_field(pool, fnid, 1);
        let raw_rtype: str = node_field(pool, fnid, 3);
        let rtype: str = type_base_name(raw_rtype);
        if str_len(name) > 0 && str_len(rtype) > 0 {
            sym_set(sym, str_concat("__fnret_", name), rtype);
        };
        // also store the FULL declared return type
        // (preserving generics like Vec<f64>) so kind==10 dispatch
        // can extract the element type when an indexer's operand is
        // a kind 7 (fn call). Mirrors __fulltype_ for variables.
        if str_len(name) > 0 && str_len(raw_rtype) > 0 {
            sym_set(sym, str_concat("__fnfulltype_", name), raw_rtype);
        };
        i = i + 1;
    };
    return 0;
}

// Detect whether a fn's body returns a closure value, by structural
// inspection of the top-level stmt list. Returns 1 iff:
//   - The fn has an explicit `return <expr>;` (kind 22) where <expr>
//     is a closure literal (kind 42) or a var-ref (kind 3) to a local
//     bound via `let <name>: T = <closure-literal>;` earlier in the body.
//   - Or the fn's last stmt is a tail expression (kind 25) whose value
//     is a closure literal or a closure-bound local.
// Used by fn_return_map_new to populate __fnret_closure_<name> entries
// so callers can register their let-bindings for auto-drop release.
// Scope: top-level stmts only; nested ifs/matches that return closures
// from one branch are not detected in this pass. Acceptable for v1 —
// the test surface covers the common `let g = |x|...; return g;` and
// `return |x|...;` patterns. Wider coverage is a follow-up.
#[manual_drop]
fn detect_returns_closure(pool: Vec<i32>, body_list: i64) -> i64 {
    if body_list < 0 { return 0; };
    let n: i64 = list_len(pool, body_list);
    let mut closure_locals: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    let mut found: i64 = 0;
    while i < n {
        let stmt: i64 = list_get(pool, body_list, i);
        let k: i64 = node_kind(pool, stmt);
        if k == 20 {
            // let-binding: if init is a closure literal, the lhs name
            // joins the closure-bound set.
            let init: i64 = node_field(pool, stmt, 4);
            if init >= 0 && node_kind(pool, init) == 42 {
                let lhs_name: str = node_field(pool, stmt, 1);
                if str_len(lhs_name) > 0 { closure_locals.push(lhs_name); };
            };
        };
        if k == 22 {
            // return <expr>;
            let rval: i64 = node_field(pool, stmt, 1);
            if rval >= 0 {
                let rk: i64 = node_kind(pool, rval);
                if rk == 42 { found = 1; };
                if rk == 3 {
                    let rname: str = node_field(pool, rval, 1);
                    let mut j: i64 = 0;
                    while j < vec_len(closure_locals) {
                        if str_eq(rname, vec_get(closure_locals, j)) == 1 { found = 1; };
                        j = j + 1;
                    };
                };
            };
        };
        if k == 25 && i == n - 1 {
            // tail expression (no explicit return)
            let texpr: i64 = node_field(pool, stmt, 1);
            if texpr >= 0 {
                let tk: i64 = node_kind(pool, texpr);
                if tk == 42 { found = 1; };
                if tk == 3 {
                    let tname: str = node_field(pool, texpr, 1);
                    let mut j: i64 = 0;
                    while j < vec_len(closure_locals) {
                        if str_eq(tname, vec_get(closure_locals, j)) == 1 { found = 1; };
                        j = j + 1;
                    };
                };
            };
        };
        i = i + 1;
    };
    return found;
}

// shared fn-return-map builder. Built once per
// program by emit_module_ext; passed to every lower_fn call so each
// fn's sym can reference it via __fn_return_map slot instead of
// pre-populating __fnret_/__fnfulltype_ entries per fn.
#[manual_drop]
fn fn_return_map_new(pool: Vec<i32>, fn_decls: Vec<i32>) -> i64 {
    let mut m: i64 = __nucleor_hashmap_new();
    let n: i64 = vec_len(fn_decls);
    let mut i: i64 = 0;
    while i < n {
        let fnid: i64 = vec_get(fn_decls, i);
        let name: str = node_field(pool, fnid, 1);
        let raw_rtype: str = node_field(pool, fnid, 3);
        let rtype: str = type_base_name(raw_rtype);
        if str_len(name) > 0 && str_len(rtype) > 0 {
            __nucleor_hashmap_insert(m, str_concat("__fnret_", name), rtype);
        };
        if str_len(name) > 0 && str_len(raw_rtype) > 0 {
            __nucleor_hashmap_insert(m, str_concat("__fnfulltype_", name), raw_rtype);
        };
        // Closure-returning detection: lets callers register their
        // let-binding for auto-drop release at scope end so the env
        // returned by this fn doesn't leak.
        // Closure-returning detection. Only regular fns (kind 30) have
        // a body to inspect — extern fns (kind 32) are signature-only.
        if str_len(name) > 0 && node_kind(pool, fnid) == 30 {
            let blist: i64 = node_field(pool, fnid, 4);
            if detect_returns_closure(pool, blist) == 1 {
                __nucleor_hashmap_insert(m, str_concat("__fnret_closure_", name), "1");
            };
        };
        i = i + 1;
    };
    return m;
}

// strip ONE container layer from a type
// annotation, returning the inner element type WITH generics
// preserved. Used by the kind==10 dispatchers to resolve nested
// indexing chains (`grid[i][j]` where grid: Vec<Vec<f64>>).
//   "Vec<f64>"          → "f64"
//   "Vec<Vec<f64>>"     → "Vec<f64>"
//   "[f64; 3]"          → "f64"
//   "[Vec<f64>; 4]"     → "Vec<f64>"
// Returns "" for non-container shapes.
// extract the SECOND generic parameter (the value type)
// from a HashMap<K, V> / BTreeMap<K, V> / similar two-arg generic.
// Returns "" if the type isn't a recognized two-arg generic shape.
// Used by the print() dispatch for hashmap_get etc. so
// HashMap<str, str>.get returns the str element instead of dispatching
// to print_i64 (NUC-FEEDBACK-006 follow-on).
#[manual_drop]
fn generic_second_type(t: str) -> str {
    let tlen: i64 = str_len(t);
    if tlen < 6 { return ""; };
    // Find first `<`
    let mut lt_pos: i64 = 0 - 1;
    let mut i: i64 = 0;
    while i < tlen {
        if str_char_at(t, i) == 60 { lt_pos = i; i = tlen; };
        i = i + 1;
    };
    if lt_pos < 0 { return ""; };
    if str_char_at(t, tlen - 1) != 62 { return ""; };
    // Walk inside `<...>` tracking depth; find first `,` at depth 0.
    let mut depth: i64 = 0;
    let mut comma_pos: i64 = 0 - 1;
    let mut j: i64 = lt_pos + 1;
    while j < tlen - 1 {
        let cj: i64 = str_char_at(t, j);
        if cj == 60 { depth = depth + 1; }
        else if cj == 62 { depth = depth - 1; }
        else if cj == 44 && depth == 0 { comma_pos = j; j = tlen; };
        j = j + 1;
    };
    if comma_pos < 0 { return ""; };
    let mut vs: i64 = comma_pos + 1;
    while vs < tlen - 1 && str_char_at(t, vs) == 32 { vs = vs + 1; };
    return str_substring(t, vs, tlen - 1);
}

#[manual_drop]
fn strip_container_one_level(t: str) -> str {
    let tlen: i64 = str_len(t);
    if str_starts_with(t, "Vec<") == 1 && tlen > 5 && str_char_at(t, tlen - 1) == 62 {
        return str_substring(t, 4, tlen - 1);
    };
    if tlen > 1 && str_char_at(t, 0) == 91 {
        let mut sep: i64 = 0 - 1;
        let mut k: i64 = 1;
        while k < tlen {
            let ch: i64 = str_char_at(t, k);
            if ch == 59 || ch == 44 { sep = k; k = tlen; }
            else { k = k + 1; };
        };
        if sep > 1 {
            return strip_spaces(str_substring(t, 1, sep));
        };
    };
    return "";
}

// recursively walk an indexable expression and
// return the FULL type of its element (with generics preserved).
// Composes the v0.3.55/65/66/67 operand-kind handlers — kind 3
// (var ref), kind 9 (struct field), kind 7 (fn-call), and now
// kind 10 (nested indexing) — and strips one container layer.
// Returns "" if the operand kind isn't recognized or the type
// isn't a container shape.
#[manual_drop]
fn indexed_element_full_type(pool: Vec<i32>, vexpr: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let vk: i64 = node_kind(pool, vexpr);
    let mut vtype: str = "";
    if vk == 3 {
        let vname: str = node_field(pool, vexpr, 1);
        let vt: i64 = sym_get(sym, str_concat("__fulltype_", vname));
        if vt >= 0 { vtype = vt; };
    };
    if vk == 9 {
        let parent_type: str = expr_full_type_from_sym(pool, node_field(pool, vexpr, 1), sym, structs);
        if str_len(parent_type) > 0 {
            let si: i64 = struct_find_type(pool, structs, parent_type);
            if si >= 0 {
                vtype = struct_field_type_for_inst(pool, vec_get(structs, si), parent_type, node_field(pool, vexpr, 2));
            };
        };
    };
    if vk == 7 {
        let fn_name: str = node_field(pool, vexpr, 1);
        let ft: i64 = sym_get(sym, str_concat("__fnfulltype_", fn_name));
        if ft >= 0 { vtype = ft; };
    };
    // trait-method-call (kind 8) indexed operand. Mirrors
    // the kind==7 lookup but with the trait-impl mangled name
    // (`<TYPE>__<METHOD>`) — so `s.samples()[i]` where samples
    // returns Vec<f64> resolves correctly to f64 element type.
    // Pre-v0.3.74, this fell through to "" and the outer binop
    // dispatched to integer add on packed-double bit patterns.
    if vk == 8 {
        let recv_nid: i64 = node_field(pool, vexpr, 1);
        let mname: str = node_field(pool, vexpr, 2);
        let rtype: str = expr_struct_type(pool, recv_nid, sym, structs);
        if str_len(rtype) > 0 {
            let mangled: str = str_concat(rtype, str_concat("__", mname));
            let ft: i64 = sym_get(sym, str_concat("__fnfulltype_", mangled));
            if ft >= 0 { vtype = ft; };
        };
    };
    if vk == 10 {
        // Nested indexing — recurse to get inner expr's element type,
        // which is itself a container. The outer indexing strips
        // one MORE level below.
        vtype = indexed_element_full_type(pool, node_field(pool, vexpr, 1), sym, structs);
    };
    if str_len(vtype) == 0 { return ""; };
    return strip_container_one_level(vtype);
}

#[manual_drop]
fn expr_full_type_from_sym(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 { return int_lit_type(pool, nid); };
    if kind == 71 { return "f64"; };
    if kind == 72 { return "f64"; };
    if kind == 73 { return "f32"; };
    if kind == 2 { return "str"; };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        let ft: i64 = sym_get(sym, str_concat("__fulltype_", name));
        if ft >= 0 { return ft; };
        let bt: i64 = sym_get(sym, str_concat("__type_", name));
        if bt >= 0 { return bt; };
        return "";
    };
    if kind == 9 {
        let parent_t: str = expr_full_type_from_sym(pool, node_field(pool, nid, 1), sym, structs);
        let parent_base: str = type_base_name(parent_t);
        if str_len(parent_base) > 0 {
            let si: i64 = struct_find_type(pool, structs, parent_base);
            if si >= 0 { return struct_field_type_for_inst(pool, vec_get(structs, si), parent_t, node_field(pool, nid, 2)); };
        };
        return "";
    };
    if kind == 10 { return indexed_element_full_type(pool, node_field(pool, nid, 1), sym, structs); };
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        let ft2: i64 = sym_get(sym, str_concat("__fnfulltype_", fn_name));
        if ft2 >= 0 { return ft2; };
        let rt2: i64 = sym_get(sym, str_concat("__fnret_", fn_name));
        if rt2 >= 0 { return rt2; };
        return "";
    };
    if kind == 8 {
        let recv_t: str = expr_full_type_from_sym(pool, node_field(pool, nid, 1), sym, structs);
        let mname: str = node_field(pool, nid, 2);
        if str_eq(mname, "get") == 1 || str_eq(mname, "first") == 1 || str_eq(mname, "last") == 1 || str_eq(mname, "pop") == 1 {
            let elem_t: str = strip_container_one_level(recv_t);
            if str_len(elem_t) > 0 { return elem_t; };
        };
        let recv_base: str = type_base_name(recv_t);
        if str_len(recv_base) > 0 {
            let mangled: str = str_concat(recv_base, str_concat("__", mname));
            let ft3: i64 = sym_get(sym, str_concat("__fnfulltype_", mangled));
            if ft3 >= 0 { return ft3; };
            let rt3: i64 = sym_get(sym, str_concat("__fnret_", mangled));
            if rt3 >= 0 { return rt3; };
        };
        return "";
    };
    if kind == 12 {
        let tname: str = node_field(pool, nid, 1);
        let mname12: str = node_field(pool, nid, 2);
        let args: i64 = node_field(pool, nid, 3);
        if str_eq(tname, "Option") == 1 {
            if str_eq(mname12, "Some") == 1 && list_len(pool, args) > 0 {
                let inner: str = expr_full_type_from_sym(pool, list_get(pool, args, 0), sym, structs);
                if str_len(inner) > 0 { return str_concat("Option<", str_concat(inner, ">")); };
            };
            return "Option";
        };
        if str_eq(tname, "Result") == 1 {
            if str_eq(mname12, "Ok") == 1 && list_len(pool, args) > 0 {
                let ok_t: str = expr_full_type_from_sym(pool, list_get(pool, args, 0), sym, structs);
                if str_len(ok_t) > 0 { return str_concat("Result<", str_concat(ok_t, ",_>")); };
            };
            if str_eq(mname12, "Err") == 1 && list_len(pool, args) > 0 {
                let err_t: str = expr_full_type_from_sym(pool, list_get(pool, args, 0), sym, structs);
                if str_len(err_t) > 0 { return str_concat("Result<_,", str_concat(err_t, ">")); };
            };
            return "Result";
        };
        if str_eq(tname, "Box") == 1 && list_len(pool, args) > 0 {
            let box_t: str = expr_full_type_from_sym(pool, list_get(pool, args, 0), sym, structs);
            if str_len(box_t) > 0 { return str_concat("Box<", str_concat(box_t, ">")); };
        };
        let mangled12: str = str_concat(tname, str_concat("__", mname12));
        let ft12: i64 = sym_get(sym, str_concat("__fnfulltype_", mangled12));
        if ft12 >= 0 { return ft12; };
        let rt12: i64 = sym_get(sym, str_concat("__fnret_", mangled12));
        if rt12 >= 0 { return rt12; };
        if list_len(pool, args) == 0 { return tname; };
    };
    return "";
}

#[manual_drop]
fn binop_u64_type(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 { return int_suffix_code_is_u64ish(int_lit_suffix_code(pool, nid)); };
    if kind == 3 {
        let name: str = node_field(pool, nid, 1);
        let ft: i64 = sym_get(sym, str_concat("__fulltype_", name));
        if ft >= 0 && str_eq(type_base_name(ft), "u64") == 1 { return 1; };
        let bt: i64 = sym_get(sym, str_concat("__type_", name));
        if bt >= 0 && str_eq(type_base_name(bt), "u64") == 1 { return 1; };
        return 0;
    };
    if kind == 4 {
        let iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        if is_cmp_or_logic(iop) == 1 { return 0; };
        if binop_u64_type(pool, node_field(pool, nid, 2), sym, structs) == 1 { return 1; };
        if binop_u64_type(pool, node_field(pool, nid, 3), sym, structs) == 1 { return 1; };
        return 0;
    };
    if kind == 90 || kind == 91 || kind == 92 {
        return binop_u64_type(pool, node_field(pool, nid, 1), sym, structs);
    };
    if kind == 99 {
        if str_eq(type_base_name(node_field(pool, nid, 2)), "u64") == 1 { return 1; };
        return 0;
    };
    if kind == 9 || kind == 10 || kind == 7 || kind == 8 || kind == 12 {
        let full: str = expr_full_type_from_sym(pool, nid, sym, structs);
        if str_eq(type_base_name(full), "u64") == 1 { return 1; };
    };
    return 0;
}

#[manual_drop]
fn binop_float_type(pool: Vec<i32>, nid: i64, sym: Vec<i32>, structs: Vec<i32>) -> str {
    let kind: i64 = node_kind(pool, nid);
    if kind == 3 {
        let vname: str = node_field(pool, nid, 1);
        let tstr: i64 = sym_get(sym, str_concat("__type_", vname));
        if tstr < 0 { return ""; };
        if str_eq(tstr, "f32") == 1 { return "f32"; };
        if str_eq(tstr, "f64") == 1 { return "f64"; };
        return "";
    };
    if kind == 71 { return "f64"; };
    if kind == 72 { return "f64"; };
    // NUC-FEEDBACK-002 follow-on: kind 73 is f32 literal,
    // introduced when the lexer/parser started preserving the f32 suffix.
    // Without this entry, unary minus on an f32 literal fell to the
    // integer-subtract path and `-1.5f32` evaluated to -3.0 (silent
    // miscompute caught when binop_float_type returned "" for kind 73).
    if kind == 73 { return "f32"; };
    // struct field access. Pre-v0.3.53 this fell
    // through to "" → integer binop, mis-computing inline
    // f64 ops on struct-field operands (`a.x * b.x` etc).
    // Look up the struct via expr_struct_type → struct_field_type.
    if kind == 9 {
        let outer_type: str = expr_struct_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(outer_type) == 0 { return ""; };
        let si: i64 = struct_find_type(pool, structs, outer_type);
        if si >= 0 {
            let ftype: str = type_base_name(struct_field_type(pool, vec_get(structs, si), node_field(pool, nid, 2)));
            if str_eq(ftype, "f32") == 1 { return "f32"; };
            if str_eq(ftype, "f64") == 1 { return "f64"; };
        };
        return "";
    };
    // nested binop. For `(a.x*b.x) + (a.y*b.y)`,
    // the outer + has binop operands. Recurse into each operand's
    // own binop type — f32 wins precedence, then f64 (matches the
    // outer dispatch rule). Without this, the + fell through to
    // integer add even though both halves were correctly compiled
    // as f64 muls.
    if kind == 4 {
        // regression closure
        // 2026-05-01-f64-cmp-as-i32-cast-silently-zero (CRITICAL).
        // Comparison operators (`<` `>` `<=` `>=` `==` `!=`) and
        // logical (`&&` `||`) produce a BOOL result, not a float —
        // even when the OPERANDS are f64. Pre-fix `(a < b) as i32`
        // for `a, b: f64` had binop_float_type returning "f64", which
        // then drove kind-99 (as cast) to dispatch f64_to_i32 on the
        // i64 cmp-result bit pattern (always 0 or 1) → produced 0
        // because the small-magnitude check rounded the bit pattern
        // to 0 / nonsense. Now: if the binop is a cmp/logic op, return
        // "" so the kind-99 path falls through to the int→int
        // as_i32/as_i64 helper which correctly produces 0/1.
        let cmp_iop: i64 = tok_to_ir(node_field(pool, nid, 1));
        if is_cmp_or_logic(cmp_iop) == 1 {
            return "";
        };
        let lt: str = binop_float_type(pool, node_field(pool, nid, 2), sym, structs);
        let rt: str = binop_float_type(pool, node_field(pool, nid, 3), sym, structs);
        if str_eq(lt, "f32") == 1 { return "f32"; };
        if str_eq(rt, "f32") == 1 { return "f32"; };
        if str_eq(lt, "f64") == 1 { return "f64"; };
        if str_eq(rt, "f64") == 1 { return "f64"; };
        return "";
    };
    // parenthesized expression / cast / borrow
    // wrappers preserve the inner type. Mirror the precedence
    // chain that expr_struct_type already handles.
    if kind == 90 || kind == 91 || kind == 92 {
        return binop_float_type(pool, node_field(pool, nid, 1), sym, structs);
    };
    // function call. Look up the called fn's return
    // type via the `__fnret_<NAME>` sym entry (populated by
    // populate_fn_returns_in_sym at lower_fn entry). Without this,
    // `make_one() + make_four()` (both returning f64) silently
    // fell through to integer add and miscomputed.
    if kind == 7 {
        let fn_name: str = node_field(pool, nid, 1);
        let rt: i64 = sym_get(sym, str_concat("__fnret_", fn_name));
        if rt < 0 { return ""; };
        if str_eq(rt, "f32") == 1 { return "f32"; };
        if str_eq(rt, "f64") == 1 { return "f64"; };
        return "";
    };
    // as-cast (`x as f64` is AST kind 99). The
    // target type is stored directly on the cast node (field 2).
    // Pre-v0.3.61: `(make_int() as f64) + (make_int() as f64)`
    // miscomputed because both operands were casts and neither
    // triggered the existing literal/var f-typed paths. Fix:
    // strip type_base_name in case the target carries generic
    // decorations, then return f32/f64 if matched.
    if kind == 99 {
        let target_type: str = type_base_name(node_field(pool, nid, 2));
        if str_eq(target_type, "f32") == 1 { return "f32"; };
        if str_eq(target_type, "f64") == 1 { return "f64"; };
        return "";
    };
    // trait method call (`obj.method(args)` is
    // AST kind 8). Real production case: trait method results
    // used inline in binops (`r1.area() + r2.area()`) miscompiled
    // because kind 8 wasn't in the enumeration. Resolve receiver
    // type via expr_struct_type, construct the trait_impl mangled
    // name (`<TYPE>__<METHOD>`), look up __fnret_<MANGLED>. The
    // mangling matches what compile_one's pass-1.5 (collect_impls
    // at line 11144) generates for trait methods.
    if kind == 8 {
        let recv_nid: i64 = node_field(pool, nid, 1);
        let mname: str = node_field(pool, nid, 2);
        let rtype: str = expr_struct_type(pool, recv_nid, sym, structs);
        if str_len(rtype) == 0 { return ""; };
        let mangled: str = str_concat(rtype, str_concat("__", mname));
        let rt: i64 = sym_get(sym, str_concat("__fnret_", mangled));
        if rt < 0 { return ""; };
        if str_eq(rt, "f32") == 1 { return "f32"; };
        if str_eq(rt, "f64") == 1 { return "f64"; };
        return "";
    };
    // Vec indexing (`v[i]` is AST kind 10).
    // Extract the element type from the variable's full declared
    // type (Vec<f64>) via the __fulltype_ sym entry. The existing
    // __type_ sym entry only stores the base name ("Vec") because
    // type_base_name strips generics; v0.3.55 added a parallel
    // __fulltype_ entry that preserves the generic so the kind==10
    // dispatcher can extract the element type.
    // also handles fixed-size arrays
    // `[T; N]` (parsed identically to indexing). Production code
    // uses fixed arrays for state vectors / sensor batches with
    // known length.
    if kind == 10 {
        // refactored to use indexed_element_full_type
        // which composes all four operand kinds (3, 9, 7, 10) and
        // strips one container layer per level. The element type
        // returned has generics preserved; type_base_name strips
        // the outer wrapper for the f-typed primitive check.
        let elem_full: str = indexed_element_full_type(pool, node_field(pool, nid, 1), sym, structs);
        if str_len(elem_full) == 0 { return ""; };
        let elem_base: str = type_base_name(elem_full);
        if str_eq(elem_base, "f32") == 1 { return "f32"; };
        if str_eq(elem_base, "f64") == 1 { return "f64"; };
        return "";
    };
    return "";
}

// T1.1 Phase 5: map a binop token (via tok_to_ir) and a float type
// to the corresponding runtime helper name. Returns "" if the op
// isn't a float-supported binop or the type isn't float.
// Supported ops (iop values from tok_to_ir):
//   2  + → f<T>_add        7  == → f<T>_eq
//   3  - → f<T>_sub        8  != → f<T>_ne
//   4  * → f<T>_mul        9  <  → f<T>_lt
//   5  / → f<T>_div       10  >  → f<T>_gt
//                         11  <= → f<T>_le
//                         12  >= → f<T>_ge
#[manual_drop]
fn float_binop_helper(iop: i64, ftype: str) -> str {
    if str_len(ftype) == 0 { return ""; };
    let mut suffix: str = "";
    if iop == 2 { suffix = "add"; };
    if iop == 3 { suffix = "sub"; };
    if iop == 4 { suffix = "mul"; };
    if iop == 5 { suffix = "div"; };
    if iop == 7 { suffix = "eq"; };
    if iop == 8 { suffix = "ne"; };
    if iop == 9 { suffix = "lt"; };
    if iop == 10 { suffix = "gt"; };
    if iop == 11 { suffix = "le"; };
    if iop == 12 { suffix = "ge"; };
    if str_len(suffix) == 0 { return ""; };
    if str_eq(ftype, "f32") == 1 { return str_concat("f32_", suffix); };
    if str_eq(ftype, "f64") == 1 { return str_concat("f64_", suffix); };
    return "";
}

// T1.1 Phase 1+2+3c+5: if `tstr` is a narrow numeric type, insert a
// runtime `__nucleor_as_<T>` cast so the stored value is width-
// correct (e.g. u8 wraps mod 256, i32 truncates from i64, f32
// narrows from f64). Returns the new register holding the narrowed
// value, or `vr` unchanged otherwise.
// `src_kind` is the AST kind of the init expression. For f32
// narrowing we ONLY narrow when the source is a f64 literal
// (kind == 71). If the source is already a float expression
// (e.g. result of f32 binop, another f32 variable), a second
// narrowing would corrupt the already-narrow bit-pattern. This
// guard is specific to float types; integer narrowing is always
// safe to apply.
// Phase 3c stdlib audit complete: i32/u32 narrowing is safe.
#[manual_drop]
fn narrow_via_as(blk: Vec<i32>, regs: Vec<i32>, vr: i64, tstr: str, src_kind: i64) -> i64 {
    // Defensive: a negative source register means upstream lowering failed.
    // Return it unchanged so the bad register propagates to a visible
    // diagnostic rather than getting silently wrapped in an as-cast.
    if vr < 0 { return vr; };
    if str_len(tstr) == 0 { return vr; };
    let mut helper: str = "";
    if str_eq(tstr, "i8") == 1 { helper = "as_i8"; };
    if str_eq(tstr, "i16") == 1 { helper = "as_i16"; };
    if str_eq(tstr, "i32") == 1 { helper = "as_i32"; };
    if str_eq(tstr, "u8") == 1 { helper = "as_u8"; };
    if str_eq(tstr, "u16") == 1 { helper = "as_u16"; };
    if str_eq(tstr, "u32") == 1 { helper = "as_u32"; };
    // f32 narrowing per source kind: literals get the right converter,
    // already-narrow values are left alone (avoid double-conversion).
    if str_eq(tstr, "f32") == 1 && src_kind == 71 { helper = "as_f32"; };       // f64 literal
    if str_eq(tstr, "f32") == 1 && src_kind == 1 { helper = "i64_to_f32"; };    // int literal
    // f64 from int literal: needs i64→f64 conversion (literals are
    // stored as raw i64 bit pattern, not as scaled-f64).
    if str_eq(tstr, "f64") == 1 && src_kind == 1 { helper = "i64_to_f64"; };
    if str_len(helper) == 0 { return vr; };
    let mut conv_args: Vec<i32> = Vec::new();
    conv_args.push(vr);
    let r: i64 = ctr_next(regs);
    ir_block_add(blk, ir_call_ex(r, helper, conv_args));
    return r;
}

#[manual_drop]
fn auto_drop_helper_for_type(tstr: str) -> str {
    if str_len(tstr) == 0 { return ""; };
    let base: str = type_base_name(tstr);
    if str_eq(base, "Vec") == 1 || str_starts_with(tstr, "Vec<") == 1 { return "vec_free"; };
    if str_eq(base, "HashMap") == 1 || str_starts_with(tstr, "HashMap<") == 1 { return "hashmap_free"; };
    // Internal-only type tag: closure-typed bindings (surface type i64)
    // are registered with tstr="Closure" so the auto-drop framework
    // emits nuc_closure_release_boxed at scope end. The "Closure" tag
    // never appears in source code; it's set by the let-binding lower
    // when the init is a closure literal or a closure-returning call.
    if str_eq(tstr, "Closure") == 1 { return "nuc_closure_release_boxed"; };
    return "";
}

#[manual_drop]
fn auto_drop_call_returns_borrowed(name: str) -> i64 {
    if str_eq(name, "vec_get") == 1 { return 1; };
    if str_eq(name, "tok_at") == 1 { return 1; };
    if str_eq(name, "tok_v") == 1 { return 1; };
    if str_eq(name, "node_field") == 1 { return 1; };
    if str_eq(name, "ir_block_get_inst") == 1 { return 1; };
    if str_eq(name, "ir_fn_get_block") == 1 { return 1; };
    if str_eq(name, "ir_fn_strtab_aux") == 1 { return 1; };
    if str_eq(name, "lx_blk") == 1 { return 1; };
    if str_eq(name, "diag_get") == 1 { return 1; };
    if str_eq(name, "own_diags") == 1 { return 1; };
    if str_eq(name, "own_shared_keys_vec") == 1 { return 1; };
    if str_eq(name, "own_mut_keys_vec") == 1 { return 1; };
    if str_eq(name, "own_scope_keys_vec") == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn auto_drop_init_owns_value(pool: Vec<i32>, init: i64) -> i64 {
    if init < 0 { return 0; };
    let k: i64 = node_kind(pool, init);
    if k == 3 { return 0; };
    if k == 7 {
        let fn_name: str = node_field(pool, init, 1);
        if auto_drop_call_returns_borrowed(fn_name) == 1 { return 0; };
        return 1;
    };
    if k == 8 { return 0; };
    if k == 9 { return 0; };
    if k == 10 { return 0; };
    // Constructor calls such as `Vec::new()` create owned values. The
    // registration path still gates by declared/inferred type cleanup helper.
    if k == 12 { return 1; };
    return 1;
}

#[manual_drop]
fn auto_drop_is_enabled(sym: Vec<i32>) -> i64 {
    let enabled: i64 = sym_get(sym, "__auto_drop_enabled");
    if enabled == 1 { return 1; };
    return 0;
}

#[manual_drop]
fn auto_drop_state_key(idx: i64) -> str { return str_concat("__auto_drop_state_", str_from_int(idx)); }
#[manual_drop]
fn auto_drop_name_key(idx: i64) -> str { return str_concat("__auto_drop_name_", str_from_int(idx)); }
#[manual_drop]
fn auto_drop_helper_key(idx: i64) -> str { return str_concat("__auto_drop_helper_", str_from_int(idx)); }
#[manual_drop]
fn auto_drop_alloca_key(idx: i64) -> str { return str_concat("__auto_drop_alloca_", str_from_int(idx)); }
#[manual_drop]
fn auto_drop_index_key(name: str) -> str { return str_concat("__auto_drop_index_", name); }

#[manual_drop]
fn auto_drop_register(sym: Vec<i32>, vname: str, tstr: str, ar: i64) -> i64 {
    if auto_drop_is_enabled(sym) == 0 { return 0; };
    if str_len(vname) == 0 || str_eq(vname, "_") == 1 { return 0; };
    if ar < 0 { return 0; };
    let helper: str = auto_drop_helper_for_type(tstr);
    if str_len(helper) == 0 { return 0; };
    let old_count: i64 = sym_get(sym, "__auto_drop_count");
    let idx: i64 = if old_count < 0 { 0 } else { old_count };
    sym_set(sym, auto_drop_name_key(idx), vname);
    sym_set(sym, auto_drop_helper_key(idx), helper);
    sym_set(sym, auto_drop_alloca_key(idx), ar);
    sym_set(sym, auto_drop_state_key(idx), 1);
    sym_set(sym, auto_drop_index_key(vname), idx);
    sym_set(sym, "__auto_drop_count", idx + 1);
    return 0;
}

#[manual_drop]
fn auto_drop_set_state(sym: Vec<i32>, vname: str, state: i64) -> i64 {
    if auto_drop_is_enabled(sym) == 0 { return 0; };
    if str_len(vname) == 0 { return 0; };
    let idx: i64 = sym_get(sym, auto_drop_index_key(vname));
    if idx < 0 { return 0; };
    sym_set(sym, auto_drop_state_key(idx), state);
    return 0;
}

#[manual_drop]
fn auto_drop_mark_freed(sym: Vec<i32>, vname: str) -> i64 {
    return auto_drop_set_state(sym, vname, 0);
}

#[manual_drop]
fn auto_drop_mark_live(sym: Vec<i32>, vname: str) -> i64 {
    return auto_drop_set_state(sym, vname, 1);
}

#[manual_drop]
fn auto_drop_emit_index(cur: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, idx: i64, skip_name: str) -> Vec<i32> {
    if idx < 0 { return cur; };
    let state: i64 = sym_get(sym, auto_drop_state_key(idx));
    if state != 1 { return cur; };
    let name_i: i64 = sym_get(sym, auto_drop_name_key(idx));
    if name_i < 0 { return cur; };
    let lname: str = name_i;
    if str_len(skip_name) > 0 && str_eq(lname, skip_name) == 1 { return cur; };
    let helper_i: i64 = sym_get(sym, auto_drop_helper_key(idx));
    let ar: i64 = sym_get(sym, auto_drop_alloca_key(idx));
    if helper_i < 0 || ar < 0 { return cur; };
    let helper: str = helper_i;
    let val_r: i64 = ctr_next(regs);
    ir_block_add(cur, ir_load(val_r, ar));
    let mut drop_args: Vec<i32> = Vec::new();
    drop_args.push(val_r);
    let drop_r: i64 = ctr_next(regs);
    ir_block_add(cur, ir_call_ex(drop_r, helper, drop_args));
    sym_set(sym, auto_drop_state_key(idx), 0);
    return cur;
}

#[manual_drop]
fn auto_drop_emit_named(cur: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, vname: str) -> Vec<i32> {
    if auto_drop_is_enabled(sym) == 0 { return cur; };
    let idx: i64 = sym_get(sym, auto_drop_index_key(vname));
    if idx < 0 { return cur; };
    return auto_drop_emit_index(cur, regs, sym, idx, "");
}

#[manual_drop]
fn auto_drop_emit_live(cur: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, skip_name: str) -> Vec<i32> {
    if auto_drop_is_enabled(sym) == 0 { return cur; };
    let count: i64 = sym_get(sym, "__auto_drop_count");
    if count <= 0 { return cur; };
    let mut i: i64 = count - 1;
    let mut out: Vec<i32> = cur;
    while i >= 0 {
        out = auto_drop_emit_index(out, regs, sym, i, skip_name);
        i = i - 1;
    };
    return out;
}

// ===== MEM-3: sound per-iteration drop escape analysis =====
// A loop-body-declared owned Vec/HashMap binding can be released at the END of
// each iteration (instead of leaking until fn return) IFF it provably does not
// escape the iteration. Escape routes: passed as an arg to a non-borrow call
// (ownership transfer), moved/aliased into another binding (`let w = v`),
// stored into a container slot, returned, or placed in a struct literal.
//
// The analysis is CONSERVATIVE and FAIL-SAFE: any shape it cannot positively
// prove safe is treated as an escape → the drop is SUPPRESSED (a leak, never a
// double-free). Soundness rests on three facts established in the runtime +
// lowering: (a) __nucleor_vec_free / hashmap_free are SHALLOW, so an escaped
// *element's* data is never touched; (b) candidate bindings are top-level in
// the loop body — nested-in-`if` bindings live in a cloned scope and are
// excluded here — so they are always allocated when the body-end drop runs;
// (c) loop-body bindings live in a cloned sym discarded after the loop, so the
// fn-end drop never also frees them (no double-free across scopes).
//
// `ad_is_borrow_builtin`: runtime calls that borrow their argument and neither
// free it nor retain a pointer past the call. MUST contain only true borrows.
#[manual_drop]
fn ad_is_borrow_builtin(name: str) -> i64 {
    if str_eq(name, "vec_len") == 1 || str_eq(name, "vec_get") == 1 || str_eq(name, "vec_cap") == 1
        || str_eq(name, "vec_capacity") == 1 || str_eq(name, "vec_is_empty") == 1
        || str_eq(name, "str_len") == 1 || str_eq(name, "str_char_at") == 1 || str_eq(name, "str_eq") == 1
        || str_eq(name, "str_substring") == 1 || str_eq(name, "str_index_of") == 1
        || str_eq(name, "str_contains") == 1 || str_eq(name, "str_starts_with") == 1 || str_eq(name, "str_ends_with") == 1
        || str_eq(name, "print") == 1 || str_eq(name, "println") == 1 || str_eq(name, "print_int") == 1 || str_eq(name, "print_str") == 1
        || str_eq(name, "hashmap_len") == 1 || str_eq(name, "hashmap_has") == 1 || str_eq(name, "hashmap_get") == 1
        || str_eq(name, "hashmap_contains_key") == 1 { return 1; };
    return 0;
}

// Does vname (a kind-3 var-ref) appear ANYWHERE in expr subtree `nid`?
// Fail-safe: an unrecognized expr kind returns 1 (assume present → caller
// treats it as an escape).
#[manual_drop]
fn ad_name_in_subtree(pool: Vec<i32>, nid: i64, vname: str) -> i64 {
    if nid < 0 { return 0; };
    let k: i64 = node_kind(pool, nid);
    if k == 1 || k == 2 || k == 71 || k == 72 || k == 73 { return 0; };
    if k == 3 { if str_eq(node_field(pool, nid, 1), vname) == 1 { return 1; }; return 0; };
    if k == 4 {
        if ad_name_in_subtree(pool, node_field(pool, nid, 2), vname) == 1 { return 1; };
        return ad_name_in_subtree(pool, node_field(pool, nid, 3), vname);
    };
    if k == 5 || k == 6 || k == 90 || k == 91 || k == 92 || k == 99 {
        return ad_name_in_subtree(pool, node_field(pool, nid, 1), vname);
    };
    if k == 7 { return ad_list_mentions(pool, node_field(pool, nid, 2), vname); };
    if k == 8 {
        if ad_name_in_subtree(pool, node_field(pool, nid, 1), vname) == 1 { return 1; };
        return ad_list_mentions(pool, node_field(pool, nid, 3), vname);
    };
    if k == 9 {
        // field access `base.fieldname`: field 1 = base node, field 2 = field
        // NAME (string, not a node) — recurse only the base.
        return ad_name_in_subtree(pool, node_field(pool, nid, 1), vname);
    };
    if k == 10 {
        // index `base[idx]`: both fields are nodes.
        if ad_name_in_subtree(pool, node_field(pool, nid, 1), vname) == 1 { return 1; };
        return ad_name_in_subtree(pool, node_field(pool, nid, 2), vname);
    };
    // kind 12 (UFCS/assoc call) and kind 34 (struct literal) have field
    // layouts that are not reliably node-typed at the indices we'd need;
    // probing them risks reading a string/data field as a node id (a
    // node_kind OOB). Fail safe: report "mentions vname" so any binding used
    // anywhere near one is conservatively treated as escaping (suppressed).
    if k == 12 || k == 34 { return 1; };
    return 1;
}

#[manual_drop]
fn ad_list_mentions(pool: Vec<i32>, lid: i64, vname: str) -> i64 {
    if lid < 0 { return 0; };
    let n: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    while i < n {
        if ad_name_in_subtree(pool, list_get(pool, lid, i), vname) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

// Args to a borrow builtin: a bare vname arg is safe (borrowed, not consumed);
// any other arg is recursively checked.
#[manual_drop]
fn ad_args_safe_under_borrow(pool: Vec<i32>, lid: i64, vname: str) -> i64 {
    if lid < 0 { return 1; };
    let n: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    while i < n {
        let a: i64 = list_get(pool, lid, i);
        if node_kind(pool, a) == 3 && str_eq(node_field(pool, a, 1), vname) == 1 {
            // bare vname borrowed — safe
        } else {
            if ad_expr_vname_safe(pool, a, vname) == 0 { return 0; };
        };
        i = i + 1;
    };
    return 1;
}

// Is every use of vname within expr `nid` non-escaping? Fail-safe: any context
// that mentions vname but is not positively classified safe returns 0.
#[manual_drop]
fn ad_expr_vname_safe(pool: Vec<i32>, nid: i64, vname: str) -> i64 {
    if nid < 0 { return 1; };
    if ad_name_in_subtree(pool, nid, vname) == 0 { return 1; };
    let k: i64 = node_kind(pool, nid);
    if k == 3 { return 0; };
    if k == 4 {
        if ad_expr_vname_safe(pool, node_field(pool, nid, 2), vname) == 0 { return 0; };
        return ad_expr_vname_safe(pool, node_field(pool, nid, 3), vname);
    };
    if k == 5 || k == 6 || k == 90 || k == 91 || k == 92 || k == 99 {
        return ad_expr_vname_safe(pool, node_field(pool, nid, 1), vname);
    };
    if k == 7 {
        if ad_is_borrow_builtin(node_field(pool, nid, 1)) == 1 {
            return ad_args_safe_under_borrow(pool, node_field(pool, nid, 2), vname);
        };
        if ad_list_mentions(pool, node_field(pool, nid, 2), vname) == 1 { return 0; };
        return 1;
    };
    if k == 8 {
        let recv: i64 = node_field(pool, nid, 1);
        if node_kind(pool, recv) == 3 && str_eq(node_field(pool, recv, 1), vname) == 1 {
            // receiver is the binding itself — a method does not hand off its receiver
        } else {
            if ad_expr_vname_safe(pool, recv, vname) == 0 { return 0; };
        };
        if ad_list_mentions(pool, node_field(pool, nid, 3), vname) == 1 { return 0; };
        return 1;
    };
    if k == 9 {
        // field access `base.fieldname`: field 2 is a name string, not a node.
        let base9: i64 = node_field(pool, nid, 1);
        if node_kind(pool, base9) == 3 && str_eq(node_field(pool, base9, 1), vname) == 1 {
            return 1;  // reading vname's field is a borrow — safe under shallow free
        };
        return ad_expr_vname_safe(pool, base9, vname);
    };
    if k == 10 {
        // index `base[idx]`: base@1, index@2 (both nodes).
        let base10: i64 = node_field(pool, nid, 1);
        if node_kind(pool, base10) == 3 && str_eq(node_field(pool, base10, 1), vname) == 1 {
            // indexing the binding is a read — safe under shallow free
        } else {
            if ad_expr_vname_safe(pool, base10, vname) == 0 { return 0; };
        };
        return ad_expr_vname_safe(pool, node_field(pool, nid, 2), vname);
    };
    return 0;
}

#[manual_drop]
fn ad_stmt_list_vname_safe(pool: Vec<i32>, lid: i64, vname: str) -> i64 {
    if lid < 0 { return 1; };
    let n: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    while i < n {
        if ad_stmt_vname_safe(pool, list_get(pool, lid, i), vname) == 0 { return 0; };
        i = i + 1;
    };
    return 1;
}

// Is statement `nid` free of any escaping use of vname? Handles the common
// loop-body statement kinds; any other kind that could mention vname is
// fail-safe-suppressed (return 0).
#[manual_drop]
fn ad_stmt_vname_safe(pool: Vec<i32>, nid: i64, vname: str) -> i64 {
    if nid < 0 { return 1; };
    let k: i64 = node_kind(pool, nid);
    if k == 20 { return 1; };
    if k == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        if ad_name_in_subtree(pool, lhs, vname) == 1 {
            // vname in the lvalue is only OK when it is exactly `vname = ...`
            // (declaration / reassignment); `arr[vname] = ...` etc. escapes.
            if node_kind(pool, lhs) != 3 { return 0; };
        };
        return ad_expr_vname_safe(pool, node_field(pool, nid, 2), vname);
    };
    if k == 22 {
        if ad_name_in_subtree(pool, node_field(pool, nid, 1), vname) == 1 { return 0; };
        return 1;
    };
    if k == 23 {
        if ad_expr_vname_safe(pool, node_field(pool, nid, 1), vname) == 0 { return 0; };
        if ad_stmt_list_vname_safe(pool, node_field(pool, nid, 2), vname) == 0 { return 0; };
        let en: i64 = node_field(pool, nid, 3);
        if en >= 0 { return ad_stmt_list_vname_safe(pool, en, vname); };
        return 1;
    };
    if k == 24 {
        if ad_expr_vname_safe(pool, node_field(pool, nid, 1), vname) == 0 { return 0; };
        return ad_stmt_list_vname_safe(pool, node_field(pool, nid, 2), vname);
    };
    if k == 25 { return ad_expr_vname_safe(pool, node_field(pool, nid, 1), vname); };
    if k == 28 {
        if ad_expr_vname_safe(pool, node_field(pool, nid, 2), vname) == 0 { return 0; };
        if ad_expr_vname_safe(pool, node_field(pool, nid, 3), vname) == 0 { return 0; };
        return ad_stmt_list_vname_safe(pool, node_field(pool, nid, 4), vname);
    };
    return 0;
}

// Per-loop-iteration drop emission. Releases bindings declared INSIDE the loop
// body (idx >= min_idx, i.e. above the outer-scope snapshot) at the end of each
// iteration. Always emits for closure-typed bindings (closures pass by-value
// copy of the tagged env pointer; the source retains ownership). For Vec /
// HashMap bindings it additionally requires the MEM-3 escape analysis above to
// prove the binding does not escape the iteration — otherwise the drop is
// suppressed (the binding then leaks until fn return, as before, but is never
// double-freed).
#[manual_drop]
fn auto_drop_emit_live_above_closures(cur: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>, min_idx: i64, pool: Vec<i32>, body_list: i64) -> Vec<i32> {
    if auto_drop_is_enabled(sym) == 0 { return cur; };
    let count: i64 = sym_get(sym, "__auto_drop_count");
    if count <= min_idx { return cur; };
    let mut i: i64 = count - 1;
    let mut out: Vec<i32> = cur;
    while i >= min_idx {
        let state: i64 = sym_get(sym, auto_drop_state_key(i));
        if state == 1 {
            let helper_i: i64 = sym_get(sym, auto_drop_helper_key(i));
            if helper_i >= 0 {
                let helper: str = helper_i;
                let mut do_drop: i64 = 0;
                if str_eq(helper, "nuc_closure_release_boxed") == 1 {
                    do_drop = 1;
                } else if str_eq(helper, "vec_free") == 1 || str_eq(helper, "hashmap_free") == 1 {
                    let vname: str = sym_get(sym, auto_drop_name_key(i));
                    if str_len(vname) > 0 && ad_stmt_list_vname_safe(pool, body_list, vname) == 1 {
                        do_drop = 1;
                    };
                };
                if do_drop == 1 {
                    out = auto_drop_emit_index(out, regs, sym, i, "");
                };
            };
        };
        i = i - 1;
    };
    return out;
}

#[manual_drop]
fn auto_drop_explicit_free_name(pool: Vec<i32>, expr_nid: i64) -> str {
    if expr_nid < 0 { return ""; };
    if node_kind(pool, expr_nid) != 7 { return ""; };
    let fn_name: str = node_field(pool, expr_nid, 1);
    // MEM-4: recognize the stdlib free-wrappers, not just the bare
    // intrinsics. `tok_vec_free` (rods/tokenizer) and the `nuc_*_free`
    // externs fully release the handle; without listing them auto-drop
    // would ALSO emit a vec_free for the same binding at scope end —
    // a corner double-free.
    let is_free: i64 = if str_eq(fn_name, "vec_free") == 1 || str_eq(fn_name, "str_free") == 1 || str_eq(fn_name, "hashmap_free") == 1
        || str_eq(fn_name, "tok_vec_free") == 1 || str_eq(fn_name, "nuc_tok_vec_free") == 1
        || str_eq(fn_name, "nuc_vec_free") == 1 || str_eq(fn_name, "nuc_str_free") == 1 || str_eq(fn_name, "nuc_hashmap_free") == 1 { 1 } else { 0 };
    if is_free == 0 { return ""; };
    let args_list: i64 = node_field(pool, expr_nid, 2);
    if list_len(pool, args_list) <= 0 { return ""; };
    let first_arg: i64 = list_get(pool, args_list, 0);
    if node_kind(pool, first_arg) != 3 { return ""; };
    return node_field(pool, first_arg, 1);
}

#[manual_drop]
fn auto_drop_handoff_name(pool: Vec<i32>, expr_nid: i64, sym: Vec<i32>) -> str {
    if expr_nid < 0 { return ""; };
    let ek: i64 = node_kind(pool, expr_nid);
    let mut args_list: i64 = -1;
    let mut value_idx: i64 = -1;
    if ek == 7 {
        let fn_name: str = node_field(pool, expr_nid, 1);
        value_idx = if str_eq(fn_name, "vec_push") == 1 { 1 }
                    else if str_eq(fn_name, "vec_set") == 1 { 2 }
                    else if str_eq(fn_name, "hashmap_insert") == 1 { 2 }
                    else if str_eq(fn_name, "node_add") == 1 { 1 }
                    else { -1 };
        args_list = node_field(pool, expr_nid, 2);
    } else if ek == 8 {
        let method_name: str = node_field(pool, expr_nid, 2);
        value_idx = if str_eq(method_name, "push") == 1 { 0 }
                    else if str_eq(method_name, "set") == 1 { 1 }
                    else if str_eq(method_name, "insert") == 1 { 1 }
                    else { -1 };
        args_list = node_field(pool, expr_nid, 3);
    } else {
        return "";
    };
    if value_idx < 0 { return ""; };
    if list_len(pool, args_list) <= value_idx { return ""; };
    let value_arg: i64 = list_get(pool, args_list, value_idx);
    if node_kind(pool, value_arg) != 3 { return ""; };
    let vname: str = node_field(pool, value_arg, 1);
    // Only suppress if this name was actually registered for
    // auto-drop in this fn.
    let idx: i64 = sym_get(sym, auto_drop_index_key(vname));
    if idx < 0 { return ""; };
    return vname;
}

#[manual_drop]
fn auto_drop_mark_constructor_handoffs(pool: Vec<i32>, expr_nid: i64, sym: Vec<i32>) -> i64 {
    if expr_nid < 0 { return 0; };
    if node_kind(pool, expr_nid) == 34 {
        let init_list: i64 = node_field(pool, expr_nid, 2);
        let n34: i64 = list_len(pool, init_list);
        let mut i34: i64 = 0;
        while i34 < n34 {
            let init_nid: i64 = list_get(pool, init_list, i34);
            let val_nid: i64 = node_field(pool, init_nid, 2);
            if node_kind(pool, val_nid) == 3 {
                let vname34: str = node_field(pool, val_nid, 1);
                let idx34: i64 = sym_get(sym, auto_drop_index_key(vname34));
                if idx34 >= 0 { auto_drop_mark_freed(sym, vname34); };
            } else {
                auto_drop_mark_constructor_handoffs(pool, val_nid, sym);
            };
            i34 = i34 + 1;
        };
        return 0;
    };
    // Default-flip validation: also recognize
    // kind-7 regular fn calls as handoff sites, not just kind-12 type-method
    // calls. The wrapper pattern `fn nn_X(...) -> TensorF64 { let mut data:
    // Vec<f64>; ...; return tensor_f64_from_vec(rows, cols, data); }` was
    // failing on Linux because `tensor_f64_from_vec(...)` is kind-7 and the
    // pre-fix `if != 12 return 0` bailed. The leaf `tensor_f64_from_vec`
    // body itself works because its return is a kind-34 struct literal
    // (handled above); the wrapper layer's missing case is exactly this
    // kind-7-call-as-handoff shape.
    let ek_call: i64 = node_kind(pool, expr_nid);
    let mut args_list: i64 = 0 - 1;
    if ek_call == 7 {
        args_list = node_field(pool, expr_nid, 2);
    } else if ek_call == 12 {
        args_list = node_field(pool, expr_nid, 3);
    } else {
        return 0;
    };
    let n: i64 = list_len(pool, args_list);
    let mut i: i64 = 0;
    while i < n {
        let arg: i64 = list_get(pool, args_list, i);
        if node_kind(pool, arg) == 3 {
            let vname: str = node_field(pool, arg, 1);
            let idx: i64 = sym_get(sym, auto_drop_index_key(vname));
            if idx >= 0 {
                // Closure values are NOT move-only: a closure can be
                // called multiple times from the same scope, and passing
                // it to a higher-order fn does not transfer ownership.
                // The closure literal evaluation produced one refcount
                // that the original binding owns; the callee gets a
                // value copy of the boxed pointer without taking
                // ownership of the env. Releasing the source at the
                // call site would leave the original binding pointing
                // at a freed env. Skip the handoff mark for closures.
                let helper_i: i64 = sym_get(sym, auto_drop_helper_key(idx));
                let mut is_closure: i64 = 0;
                if helper_i >= 0 {
                    let h_str: str = helper_i;
                    if str_eq(h_str, "nuc_closure_release_boxed") == 1 { is_closure = 1; };
                };
                if is_closure == 0 { auto_drop_mark_freed(sym, vname); };
            };
        } else if node_kind(pool, arg) == 7 || node_kind(pool, arg) == 12 {
            auto_drop_mark_constructor_handoffs(pool, arg, sym);
        };
        i = i + 1;
    };
    return 0;
}

#[manual_drop]
fn auto_drop_return_skip_name(pool: Vec<i32>, expr_nid: i64, sym: Vec<i32>) -> str {
    if expr_nid < 0 { return ""; };
    if node_kind(pool, expr_nid) == 3 {
        let vname: str = node_field(pool, expr_nid, 1);
        let idx: i64 = sym_get(sym, auto_drop_index_key(vname));
        if idx < 0 { return ""; };
        return vname;
    };
    return auto_drop_handoff_name(pool, expr_nid, sym);
}

#[manual_drop]
fn auto_drop_assignment_reuses_lhs(pool: Vec<i32>, rhs_nid: i64, lhs_name: str) -> i64 {
    if rhs_nid < 0 { return 0; };
    let rk: i64 = node_kind(pool, rhs_nid);
    if rk == 3 {
        let rhs_name: str = node_field(pool, rhs_nid, 1);
        if str_eq(rhs_name, lhs_name) == 1 { return 1; };
        return 0;
    };
    if rk == 7 || rk == 12 {
        let mut args_list: i64 = node_field(pool, rhs_nid, 2);
        if rk == 12 { args_list = node_field(pool, rhs_nid, 3); };
        if list_len(pool, args_list) <= 0 { return 0; };
        let first_arg: i64 = list_get(pool, args_list, 0);
        if node_kind(pool, first_arg) == 3 {
            let first_name: str = node_field(pool, first_arg, 1);
            if str_eq(first_name, lhs_name) == 1 { return 1; };
        };
        return 0;
    };
    if rk == 8 {
        let recv: i64 = node_field(pool, rhs_nid, 1);
        if node_kind(pool, recv) == 3 {
            let recv_name: str = node_field(pool, recv, 1);
            if str_eq(recv_name, lhs_name) == 1 { return 1; };
        };
    };
    return 0;
}

fn deadline_poll_emit_if_enabled(cur: Vec<i32>, regs: Vec<i32>, sym: Vec<i32>) -> Vec<i32> {
    if sym_get(sym, "__deadline_poll_enabled") == 1 {
        let args: Vec<i32> = Vec::new();
        let dr: i64 = ctr_next(regs);
        ir_block_add(cur, ir_call_ex(dr, "deadline_poll", args));
    };
    return cur;
}

#[manual_drop]
fn lower_stmt(pool: Vec<i32>, nid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let kind: i64 = node_kind(pool, nid);
    if kind == 20 {
        // shadowing fix. Pre-v0.3.76, this lowering bound the
        // new slot (sym_set) BEFORE lowering the RHS, so a shadowing
        // statement like `let x: i64 = x + 5;` resolved the inner `x`
        // to the new (uninitialized) slot and produced garbage.
        // Fix: allocate the new slot upfront, but bind sym entries
        // AFTER lowering the RHS expression so the RHS sees the OLD
        // shadowed binding (Rust shadowing semantics — the new binding
        // takes effect on the next statement, not within its own RHS).
        let vname: str = node_field(pool, nid, 1);
        let init: i64 = node_field(pool, nid, 4);
        let mut tstr: str = node_field(pool, nid, 3);
        if str_len(tstr) == 0 && init >= 0 {
            let ik: i64 = node_kind(pool, init);
            if ik == 34 { tstr = node_field(pool, init, 1); }
            else if ik == 12 {
                let ctor_t: str = expr_full_type_from_sym(pool, init, sym, structs);
                if str_len(ctor_t) > 0 { tstr = ctor_t; }
                else { tstr = node_field(pool, init, 1); };
            }
            // string-literal RHS type inference. Pre-fix `let s = "lit"` (no
            // annotation) left __type_s unregistered because `tstr` was "" and the
            // sym_set at line ~25400 is gated on `str_len(sbase) > 0`. Method calls
            // on `s` then fell through recv_is_vec==1 path, emitting vec_split /
            // vec_contains / etc. — Fix: detect
            // kind-2 (str literal) RHS and stamp tstr="str" so the type entry lands
            // and the v0.4.88 str-method dispatch picks it up correctly.
            else if ik == 2 { tstr = "str"; }
            else if ik == 3 {
                let src_name20: str = node_field(pool, init, 1);
                let src_full_i20: i64 = sym_get(sym, str_concat("__fulltype_", src_name20));
                if src_full_i20 >= 0 { tstr = src_full_i20; }
                else {
                    let src_base_i20: i64 = sym_get(sym, str_concat("__type_", src_name20));
                    if src_base_i20 >= 0 { tstr = src_base_i20; };
                };
            };
        };
        let sbase: str = type_base_name(tstr);
        if str_eq(sbase, "u64") == 1 { sym_set(sym, "__has_u64_v886", 1); };
        let sblen20: i64 = str_len(sbase);
        let mut w20: i64 = 0;
        if sblen20 == 2 {
            if str_eq(sbase, "i8") == 1 { w20 = 8; }
            else if str_eq(sbase, "u8") == 1 { w20 = 0 - 8; };
        } else if sblen20 == 3 {
            if str_eq(sbase, "i16") == 1 { w20 = 16; }
            else if str_eq(sbase, "u16") == 1 { w20 = 0 - 16; }
            else if str_eq(sbase, "i32") == 1 { w20 = 32; }
            else if str_eq(sbase, "u32") == 1 { w20 = 0 - 32; };
        };
        let aw20: i64 = if w20 >= 0 { w20 } else { 0 - w20 };
        let ar: i64 = ctr_next(regs); ir_fn_add_entry_alloca_t(fir, ar, aw20);
        // register sign-encoded width on the alloca-reg.
        // Read by lower_expr kind-3 (var-ref load) and lower_stmt
        // kind-21 (assign-store). Only sets when w20 != 0 to keep
        // the widths-by-reg table sparse.
        if w20 != 0 { ir_fn_set_width(fir, ar, w20); };
        if init >= 0 {
            // Lower RHS BEFORE rebinding sym so any reference to `vname`
            // inside the RHS resolves to the OUTER (shadowed) slot.
            let src_kind: i64 = node_kind(pool, init);
            let mut vp: Vec<i32> = lower_expr(pool, init, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            cur = lx_blk(vp);
            auto_drop_mark_constructor_handoffs(pool, init, sym);
            let vr: i64 = lx_reg(vp);
            let nvr: i64 = narrow_via_as(cur, regs, vr, sbase, src_kind);
            if aw20 == 0 {
                ir_block_add(cur, ir_store(nvr, ar));
            } else {
                let tr20: i64 = ctr_next(regs);
                ir_block_add(cur, ir_trunc(tr20, nvr, aw20));
                ir_block_add(cur, ir_store_t(tr20, ar, aw20));
            };
        };
        // Bind sym entries AFTER the RHS is lowered. Under #[auto_drop],
        // shadowing a tracked owned local ends the old binding here.
        cur = auto_drop_emit_named(cur, regs, sym, vname);
        sym_set(sym, vname, ar);
        if str_len(sbase) > 0 { sym_set(sym, str_concat("__type_", vname), sbase); };
        // also store the FULL declared type (with generics
        // like Vec<f64>) so binop_float_type can extract Vec<T>'s
        // element type for kind==10 (indexing) dispatch. type_base_name
        // strips the <T> for the existing __type_ entry.
        if str_len(tstr) > 0 { sym_set(sym, str_concat("__fulltype_", vname), tstr); };
        if init >= 0 && node_kind(pool, init) == 3 && str_len(auto_drop_helper_for_type(tstr)) > 0 {
            let transfer_src20: str = node_field(pool, init, 1);
            let transfer_idx20: i64 = sym_get(sym, auto_drop_index_key(transfer_src20));
            if transfer_idx20 >= 0 && sym_get(sym, auto_drop_state_key(transfer_idx20)) == 1 {
                auto_drop_mark_freed(sym, transfer_src20);
                auto_drop_register(sym, vname, tstr, ar);
            };
        } else if init >= 0 && auto_drop_init_owns_value(pool, init) == 1 {
            auto_drop_register(sym, vname, tstr, ar);
        };
        // Closure-aware auto-drop registration. Three paths:
        //   (a) init is a closure literal (kind 42): owns a fresh env.
        //   (b) init is a call to a fn tagged as closure-returning:
        //       owns the env returned by the callee.
        //   (c) init is a var-ref (kind 3) to a binding registered with
        //       the closure helper: transfer ownership (mark src freed,
        //       register dest).
        // Surface type stays i64; we use the internal "Closure" type tag
        // so auto_drop_helper_for_type returns nuc_closure_release_boxed.
        if init >= 0 {
            let init_k_cl: i64 = node_kind(pool, init);
            if init_k_cl == 42 {
                auto_drop_register(sym, vname, "Closure", ar);
            } else if init_k_cl == 7 {
                let callee_cl: str = node_field(pool, init, 1);
                if str_len(callee_cl) > 0 {
                    let ret_cl: i64 = sym_get(sym, str_concat("__fnret_closure_", callee_cl));
                    if ret_cl >= 0 {
                        auto_drop_register(sym, vname, "Closure", ar);
                    };
                };
            } else if init_k_cl == 3 {
                let src_cl_name: str = node_field(pool, init, 1);
                let src_cl_idx: i64 = sym_get(sym, auto_drop_index_key(src_cl_name));
                if src_cl_idx >= 0 && sym_get(sym, auto_drop_state_key(src_cl_idx)) == 1 {
                    let src_cl_helper_i: i64 = sym_get(sym, auto_drop_helper_key(src_cl_idx));
                    if src_cl_helper_i >= 0 {
                        let src_cl_helper: str = src_cl_helper_i;
                        if str_eq(src_cl_helper, "nuc_closure_release_boxed") == 1 {
                            auto_drop_mark_freed(sym, src_cl_name);
                            auto_drop_register(sym, vname, "Closure", ar);
                        };
                    };
                };
            };
        };
        if init >= 0 && node_kind(pool, init) == 42 {
            let cid_meta: i64 = sym_get(sym, "__last_closure_id");
            let caps_meta: i64 = sym_get(sym, "__last_closure_caps");
            if cid_meta >= 0 {
                sym_set(sym, str_concat("__closure_id_", vname), cid_meta);
            };
            if caps_meta >= 0 {
                let caps_s: str = caps_meta;
                if str_len(caps_s) > 0 {
                    sym_set(sym, str_concat("__closure_caps_", vname), caps_s);
                };
            };
        };
        return cur;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let lhs_kind: i64 = node_kind(pool, lhs);
        // assignment LHS shapes that lower_stmt
        // can't lower must short-circuit so we don't fall through to
        // the var-ref code path (which interprets node-id as string
        // offset and segfaults). Diagnostic was already emitted by
        // check_stmt; lower_stmt just needs to skip codegen.
        // real `v[i] = X` indexed-LHS lowering. Pre-v0.3.124
        // the kind-10 LHS shape silently dropped the assignment AND
        // its diag was informational (build still produced a .exe with
        // wrong values — the read-back of v[i] returned the original
        // value instead of the assigned X). Adopters writing
        // `v[i] = …` (a basic Rust pattern) saw silent miscomputes.
        // Fix: lower the receiver expr, the index expr, and the value
        // expr; emit `vec_set(v, i, X)`. The runtime helper exists.
        if lhs_kind == 10 {
            let mut recv_p: Vec<i32> = lower_expr(pool, node_field(pool, lhs, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let recv_r: i64 = lx_reg(recv_p);
            cur = lx_blk(recv_p);
            let mut idx_p: Vec<i32> = lower_expr(pool, node_field(pool, lhs, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let idx_r: i64 = lx_reg(idx_p);
            cur = lx_blk(idx_p);
            let mut val_p: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let val_r: i64 = lx_reg(val_p);
            cur = lx_blk(val_p);
            let mut set_args: Vec<i32> = Vec::new();
            set_args.push(recv_r);
            set_args.push(idx_r);
            set_args.push(val_r);
            let sr: i64 = ctr_next(regs);
            ir_block_add(cur, ir_call_ex(sr, "vec_set", set_args));
            return cur;
        };
        if lhs_kind != 3 && lhs_kind != 9 {
            return cur;
        };
        // nested field assignment (e.g.
        // `o.inner.val = X`) was crashing the compiler with a
        // segfault during the kind 21 / kind 9 lowering interaction.
        // The actual feature (deep field-path mutation) requires a
        // get-modify-set lowering that is multi-cycle to implement
        // correctly — copying the inner struct, mutating the copy,
        // and writing it back. Until that ships, emit a clear
        // diagnostic with the workaround so users don't hit the
        // segfault.
        if lhs_kind == 9 {
            let parent_kind: i64 = node_kind(pool, node_field(pool, lhs, 1));
            if parent_kind == 9 {
                print("ERROR: nested struct field assignment is not yet supported (e.g. `outer.inner.field = X`). Workaround: copy the inner struct to a local, mutate the local, then assign it back: `let mut tmp = outer.inner; tmp.field = X; outer.inner = tmp;`. Tracked for a future ship — get-modify-set lowering needed.");
                // pre-fix this returned `cur` silently — the
                // assignment was dropped, the build succeeded, and the
                // adopter's binary returned with the inner field
                // unchanged at runtime. Halt the compiler now.
                panic("nucleor: nested struct field assignment not supported (see ERROR diagnostic above)");
                return cur;
            };
        };
        if lhs_kind == 9 {
            let mut op: Vec<i32> = lower_expr(pool, node_field(pool, lhs, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let obj_r: i64 = lx_reg(op);
            cur = lx_blk(op);
            let fname: str = node_field(pool, lhs, 2);
            let mut vp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let vr: i64 = lx_reg(vp);
            cur = lx_blk(vp);
            let stype: str = expr_struct_type(pool, node_field(pool, lhs, 1), sym, structs);
            let si: i64 = struct_find_type(pool, structs, stype);
            if si >= 0 {
                let fi2: i64 = struct_field_idx(pool, vec_get(structs, si), fname);
                let idx_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(idx_r, fi2));
                let mut set_args: Vec<i32> = Vec::new(); set_args.push(obj_r); set_args.push(idx_r); set_args.push(vr);
                let dr: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(dr, "vec_set", set_args));
            };
            return cur;
        };
        let lhs_name: str = node_field(pool, lhs, 1);
        let ar: i64 = sym_get(sym, lhs_name);
        let rhs_nid: i64 = node_field(pool, nid, 2);
        let mut vp: Vec<i32> = lower_expr(pool, rhs_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let vr: i64 = lx_reg(vp);
        cur = lx_blk(vp);
        if auto_drop_assignment_reuses_lhs(pool, rhs_nid, lhs_name) == 0 {
            cur = auto_drop_emit_named(cur, regs, sym, lhs_name);
        };
        // typed store via
        // alloca-reg width lookup. Sign-encoded width; abs(w) for
        // memory-shape (trunc/store_t).
        let w21: i64 = ir_fn_get_width(fir, ar);
        if w21 == 0 {
            ir_block_add(cur, ir_store(vr, ar));
        } else {
            let aw21: i64 = if w21 > 0 { w21 } else { 0 - w21 };
            let tr21: i64 = ctr_next(regs);
            ir_block_add(cur, ir_trunc(tr21, vr, aw21));
            ir_block_add(cur, ir_store_t(tr21, ar, aw21));
        };
        auto_drop_mark_live(sym, lhs_name);
        let env_reg_a: i64 = sym_get(sym, "__env_reg");
        if env_reg_a >= 0 {
            let cap_id: i64 = sym_get(sym, str_concat("__capid_", lhs_name));
            if cap_id >= 0 {
                // We're inside a closure body and lhs_name is a
                // captured local — mirror the local-alloca write into
                // the env so mutations are observable post-call.
                let cap_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(cap_r, cap_id));
                let mut set_args: Vec<i32> = Vec::new();
                set_args.push(env_reg_a); set_args.push(cap_r); set_args.push(vr);
                let dr: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(dr, "nuc_closure_env_set_cap", set_args));
            };
        };
        if node_kind(pool, node_field(pool, nid, 2)) == 42 {
            let cid_meta2: i64 = sym_get(sym, "__last_closure_id");
            let caps_meta2: i64 = sym_get(sym, "__last_closure_caps");
            if cid_meta2 >= 0 {
                sym_set(sym, str_concat("__closure_id_", lhs_name), cid_meta2);
            };
            if caps_meta2 >= 0 {
                let caps_s2: str = caps_meta2;
                if str_len(caps_s2) > 0 {
                    sym_set(sym, str_concat("__closure_caps_", lhs_name), caps_s2);
                };
            };
        };
        return cur;
    };
    if kind == 85 {
        // tuple-destructure-in-let. Node layout:
        //   field 1: names_csv (str) — comma-separated binding names
        //   field 2: init node ID (i64) — the RHS expression
        // Strategy: lower the RHS into rhs_r, then for each name at
        // index i emit vec_get(rhs_r, i) and store in a fresh alloca.
        // Works for both kind-48 anonymous-tuple RHS (which kind-48
        // lowering already stores as a vec) and named-tuple-struct /
        // fn-return RHS (which is a struct vec handle).
        let names_csv85: str = node_field(pool, nid, 1);
        let init85: i64 = node_field(pool, nid, 2);
        let mut rp85: Vec<i32> = lower_expr(pool, init85, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        cur = lx_blk(rp85);
        let rhs_r85: i64 = lx_reg(rp85);
        let slen85: i64 = str_len(names_csv85);
        let mut i85: i64 = 0;
        let mut fidx85: i64 = 0;
        while i85 <= slen85 {
            let mut j85: i64 = i85;
            while j85 < slen85 && str_char_at(names_csv85, j85) != 44 { j85 = j85 + 1; };
            if j85 > i85 {
                let bname85: str = str_substring(names_csv85, i85, j85);
                let ar85: i64 = ctr_next(regs);
                ir_fn_add_entry_alloca_t(fir, ar85, 0);
                let idx_r85: i64 = ctr_next(regs);
                ir_block_add(cur, ir_const_int(idx_r85, fidx85));
                let mut ga85: Vec<i32> = Vec::new();
                ga85.push(rhs_r85);
                ga85.push(idx_r85);
                let fr85: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(fr85, "vec_get", ga85));
                ir_block_add(cur, ir_store(fr85, ar85));
                if str_eq(bname85, "_") == 0 { sym_set(sym, bname85, ar85); };
                fidx85 = fidx85 + 1;
            };
            i85 = j85 + 1;
        };
        return cur;
    };
    if kind == 22 {
        let vn: i64 = node_field(pool, nid, 1);
        let ens_stmt_nid: i64 = sym_get(sym, "__current_fn_ensure_nid");
        if vn >= 0 {
            let mut vp: Vec<i32> = lower_expr(pool, vn, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
            let vr: i64 = lx_reg(vp);
            cur = lx_blk(vp);
            // multi-ensure walk via per-index sym entries.
            let ens_stmt_count: i64 = sym_get(sym, "__current_fn_ensure_count");
            if ens_stmt_count > 0 {
                let ens_ar: i64 = ctr_next(regs);
                ir_block_add(cur, ir_alloca(ens_ar));
                ir_block_add(cur, ir_store(vr, ens_ar));
                sym_set(sym, "result", ens_ar);
                let mut ens_emit_i: i64 = 0;
                while ens_emit_i < ens_stmt_count {
                    let nid_key: str = str_concat("__current_fn_ensure_nid_", str_from_int(ens_emit_i));
                    let nid_i: i64 = sym_get(sym, nid_key);
                    if nid_i >= 0 {
                        let mut ens_lp: Vec<i32> = lower_expr(pool, nid_i, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                        let ens_pr: i64 = lx_reg(ens_lp);
                        cur = lx_blk(ens_lp);
                        let mut ens_args: Vec<i32> = Vec::new();
                        ens_args.push(ens_pr);
                        let ens_cr: i64 = ctr_next(regs);
                        ir_block_add(cur, ir_call_ex(ens_cr, "contract_ensure", ens_args));
                    };
                    ens_emit_i = ens_emit_i + 1;
                };
            } else if ens_stmt_nid >= 0 {
                // Fallback path (legacy single-nid lookup); should be
                // dead now since v0.4.254 always sets the count.
                let ens_ar: i64 = ctr_next(regs);
                ir_block_add(cur, ir_alloca(ens_ar));
                ir_block_add(cur, ir_store(vr, ens_ar));
                sym_set(sym, "result", ens_ar);
                let mut ens_lp: Vec<i32> = lower_expr(pool, ens_stmt_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let ens_pr: i64 = lx_reg(ens_lp);
                cur = lx_blk(ens_lp);
                let mut ens_args: Vec<i32> = Vec::new();
                ens_args.push(ens_pr);
                let ens_cr: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(ens_cr, "contract_ensure", ens_args));
            };
            let invx_stmt_nid: i64 = sym_get(sym, "__current_method_invariant_nid");
            if invx_stmt_nid >= 0 {
                let invx_stmt_is_ctor: i64 = sym_get(sym, "__current_method_is_ctor");
                if invx_stmt_is_ctor == 1 {
                    let self_ar_s: i64 = ctr_next(regs);
                    ir_block_add(cur, ir_alloca(self_ar_s));
                    ir_block_add(cur, ir_store(vr, self_ar_s));
                    sym_set(sym, "self", self_ar_s);
                    // Use the fn's full return type stored in sym at
                    // lower_fn entry. sym_get returns i64; in Nucleor's
                    // i64-ABI the str pointer fits in i64 directly.
                    let cur_t_s: i64 = sym_get(sym, "__current_fn_full_return");
                    if cur_t_s != 0 - 1 {
                        sym_set(sym, str_concat("__type_", "self"), cur_t_s);
                        sym_set(sym, str_concat("__fulltype_", "self"), cur_t_s);
                    };
                };
                let mut invx_lp: Vec<i32> = lower_expr(pool, invx_stmt_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let invx_pr: i64 = lx_reg(invx_lp);
                cur = lx_blk(invx_lp);
                let mut invx_args: Vec<i32> = Vec::new();
                invx_args.push(invx_pr);
                let invx_cr: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(invx_cr, "contract_invariant", invx_args));
            };
            let skip_ret_name: str = auto_drop_return_skip_name(pool, vn, sym);
            auto_drop_mark_constructor_handoffs(pool, vn, sym);
            cur = auto_drop_emit_live(cur, regs, sym, skip_ret_name);
            ir_block_add(cur, ir_ret(vr));
        } else {
            let zr: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zr, 0));
            // multi-ensure walk for bare-return path.
            let ens_bare_count: i64 = sym_get(sym, "__current_fn_ensure_count");
            if ens_bare_count > 0 {
                let ens_ar2: i64 = ctr_next(regs);
                ir_block_add(cur, ir_alloca(ens_ar2));
                ir_block_add(cur, ir_store(zr, ens_ar2));
                sym_set(sym, "result", ens_ar2);
                let mut ens_b_i: i64 = 0;
                while ens_b_i < ens_bare_count {
                    let nid_key_b: str = str_concat("__current_fn_ensure_nid_", str_from_int(ens_b_i));
                    let nid_b: i64 = sym_get(sym, nid_key_b);
                    if nid_b >= 0 {
                        let mut ens_lp_b: Vec<i32> = lower_expr(pool, nid_b, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                        let ens_pr_b: i64 = lx_reg(ens_lp_b);
                        cur = lx_blk(ens_lp_b);
                        let mut ens_args_b: Vec<i32> = Vec::new();
                        ens_args_b.push(ens_pr_b);
                        let ens_cr_b: i64 = ctr_next(regs);
                        ir_block_add(cur, ir_call_ex(ens_cr_b, "contract_ensure", ens_args_b));
                    };
                    ens_b_i = ens_b_i + 1;
                };
            } else if ens_stmt_nid >= 0 {
                let ens_ar2: i64 = ctr_next(regs);
                ir_block_add(cur, ir_alloca(ens_ar2));
                ir_block_add(cur, ir_store(zr, ens_ar2));
                sym_set(sym, "result", ens_ar2);
                let mut ens_lp2: Vec<i32> = lower_expr(pool, ens_stmt_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let ens_pr2: i64 = lx_reg(ens_lp2);
                cur = lx_blk(ens_lp2);
                let mut ens_args2: Vec<i32> = Vec::new();
                ens_args2.push(ens_pr2);
                let ens_cr2: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(ens_cr2, "contract_ensure", ens_args2));
            };
            let invx_bare_nid: i64 = sym_get(sym, "__current_method_invariant_nid");
            if invx_bare_nid >= 0 {
                let invx_bare_is_ctor: i64 = sym_get(sym, "__current_method_is_ctor");
                if invx_bare_is_ctor == 1 {
                    let self_ar_b: i64 = ctr_next(regs);
                    ir_block_add(cur, ir_alloca(self_ar_b));
                    ir_block_add(cur, ir_store(zr, self_ar_b));
                    sym_set(sym, "self", self_ar_b);
                    let cur_t_b: i64 = sym_get(sym, "__current_fn_full_return");
                    if cur_t_b != 0 - 1 {
                        sym_set(sym, str_concat("__type_", "self"), cur_t_b);
                        sym_set(sym, str_concat("__fulltype_", "self"), cur_t_b);
                    };
                };
                let mut invx_lp_b: Vec<i32> = lower_expr(pool, invx_bare_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                let invx_pr_b: i64 = lx_reg(invx_lp_b);
                cur = lx_blk(invx_lp_b);
                let mut invx_args_b: Vec<i32> = Vec::new();
                invx_args_b.push(invx_pr_b);
                let invx_cr_b: i64 = ctr_next(regs);
                ir_block_add(cur, ir_call_ex(invx_cr_b, "contract_invariant", invx_args_b));
            };
            cur = auto_drop_emit_live(cur, regs, sym, "");
            ir_block_add(cur, ir_ret(zr));
        };
        return cur;
    };
    if kind == 23 {
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        cur = lx_blk(cp);
        let tl: i64 = ctr_next(lbls); let el: i64 = ctr_next(lbls); let ml: i64 = ctr_next(lbls);
        let enode: i64 = node_field(pool, nid, 3);
        if enode < 0 { ir_block_add(cur, ir_br_cond(cr, tl, ml)); }
        else { ir_block_add(cur, ir_br_cond(cr, tl, el)); };
        let mut tb: Vec<i32> = ir_block_new(tl); ir_fn_add_block(fir, tb);
        tb = lower_stmts(pool, node_field(pool, nid, 2), tb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
        if block_has_term(tb) == 0 { ir_block_add(tb, ir_br(ml)); };
        if enode >= 0 {
            let mut eb: Vec<i32> = ir_block_new(el); ir_fn_add_block(fir, eb);
            eb = lower_stmts(pool, enode, eb, regs, lbls, sym_clone(sym), fir, strtab, lh, lx, structs, closures, trait_impls);
            if block_has_term(eb) == 0 { ir_block_add(eb, ir_br(ml)); };
        };
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb); return mb;
    };
    if kind == 24 {
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        hb = deadline_poll_emit_if_enabled(hb, regs, sym);
        let mut cp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 1), hb, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let cr: i64 = lx_reg(cp);
        hb = lx_blk(cp);
        ir_block_add(hb, ir_br_cond(cr, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        let body_sym_w: Vec<i32> = sym_clone(sym);
        // Snapshot the auto-drop count before entering the body so
        // per-iter drops only affect closure bindings declared INSIDE.
        let body_floor_w: i64 = sym_get(body_sym_w, "__auto_drop_count");
        let body_min_w: i64 = if body_floor_w < 0 { 0 } else { body_floor_w };
        bb = lower_stmts(pool, node_field(pool, nid, 2), bb, regs, lbls, body_sym_w, fir, strtab, hl, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 {
            bb = auto_drop_emit_live_above_closures(bb, regs, body_sym_w, body_min_w, pool, node_field(pool, nid, 2));
            ir_block_add(bb, ir_br(hl));
        };
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 28 {
        let name: str = node_field(pool, nid, 1);
        let ar: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, ar);
        let mut loop_sym: Vec<i32> = sym_clone(sym);
        sym_set(loop_sym, name, ar);
        // register the for-loop variable's type as i64 so
        // print(i) and other type-aware dispatches don't fall through
        // to print_str. Pre-fix `for i in 0..3 { print(i); }` SIGSEGV'd
        // because __type_i was never set, the dispatch defaulted to
        // print_str, and print_str dereferenced the i64 loop value as
        // a string pointer.
        sym_set(loop_sym, str_concat("__type_", name), "i64");
        let mut sp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let sv: i64 = lx_reg(sp);
        cur = lx_blk(sp);
        ir_block_add(cur, ir_store(sv, ar));
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls);
        let il: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        hb = deadline_poll_emit_if_enabled(hb, regs, loop_sym);
        let lv: i64 = ctr_next(regs); ir_block_add(hb, ir_load(lv, ar));
        let mut ep: Vec<i32> = lower_expr(pool, node_field(pool, nid, 3), hb, regs, lbls, loop_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let ev: i64 = lx_reg(ep);
        hb = lx_blk(ep);
        let cv: i64 = ctr_next(regs); ir_block_add(hb, ir_cmpop(9, cv, lv, ev));
        ir_block_add(hb, ir_br_cond(cv, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        let for_body_sym: Vec<i32> = sym_clone(loop_sym);
        let for_floor: i64 = sym_get(for_body_sym, "__auto_drop_count");
        let for_min: i64 = if for_floor < 0 { 0 } else { for_floor };
        bb = lower_stmts(pool, node_field(pool, nid, 4), bb, regs, lbls, for_body_sym, fir, strtab, il, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 {
            bb = auto_drop_emit_live_above_closures(bb, regs, for_body_sym, for_min, pool, node_field(pool, nid, 4));
            ir_block_add(bb, ir_br(il));
        };
        let mut ib: Vec<i32> = ir_block_new(il); ir_fn_add_block(fir, ib);
        let lv2: i64 = ctr_next(regs); ir_block_add(ib, ir_load(lv2, ar));
        let one: i64 = ctr_next(regs); ir_block_add(ib, ir_const_int(one, 1));
        let nv: i64 = ctr_next(regs); ir_block_add(ib, ir_binop(2, nv, lv2, one));
        ir_block_add(ib, ir_store(nv, ar));
        ir_block_add(ib, ir_br(hl));
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 49 {
        let name: str = node_field(pool, nid, 1);
        let item_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, item_slot);
        let iter_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, iter_slot);
        let idx_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, idx_slot);
        let mut loop_sym: Vec<i32> = sym_clone(sym);
        sym_set(loop_sym, name, item_slot);
        // register the loop item's type when the iterator
        // is a known container (Vec<T> -> T). Same fix as kind 28.
        // Falls through silently when iterator type isn't a container,
        // preserving existing behaviour.
        // also handle `for x in v.iter()` -- the iter() method
        // is identity pass-through (per t364), but indexed_element_full_type
        // doesn't recognize it. Strip the .iter() and look up the
        // receiver Vec's element type.
        let mut iter_recv_nid: i64 = node_field(pool, nid, 2);
        if node_kind(pool, iter_recv_nid) == 8 {
            let iter_mname: str = node_field(pool, iter_recv_nid, 2);
            if str_eq(iter_mname, "iter") == 1 || str_eq(iter_mname, "into_iter") == 1 {
                iter_recv_nid = node_field(pool, iter_recv_nid, 1);
            };
        };
        let iter_etype_full: str = indexed_element_full_type(pool, iter_recv_nid, sym, structs);
        if str_len(iter_etype_full) > 0 {
            let iter_etype_base: str = type_base_name(iter_etype_full);
            if str_len(iter_etype_base) > 0 {
                sym_set(loop_sym, str_concat("__type_", name), iter_etype_base);
            };
        };
        let mut sp: Vec<i32> = lower_expr(pool, node_field(pool, nid, 2), cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let sv: i64 = lx_reg(sp);
        cur = lx_blk(sp);
        ir_block_add(cur, ir_store(sv, iter_slot));
        let zero: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero, 0));
        ir_block_add(cur, ir_store(zero, idx_slot));
        // snapshot vec_len ONCE before the loop, reuse on every
        // iteration. Pre-fix the header re-read vec_len(v) on each
        // iteration. When the loop body pushed to `v`, len grew, the
        // exit check `idx < len` never became false, and memory grew
        // unboundedly (Run-Capped killed at 1 GB). The classic
        // iter-invalidation hazard, but in Nucleor's iter-by-index form
        // it manifests as silent unbounded grow rather than a borrow
        // error. Snapshot semantics: the loop iterates EXACTLY the
        // original-length elements; pushes inside the body extend the
        // Vec but are not visited. This matches Rust's
        // `for x in v.iter().take(initial_len)` shape and removes the
        // memory-blowup without needing full ownership-borrow analysis
        // (which is the canonical fix but a much larger surface).
        // Regression: push during for-iteration unbounded growth.
        let len_slot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, len_slot);
        let mut len_init_args: Vec<i32> = Vec::new(); len_init_args.push(sv);
        let len_init_v: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(len_init_v, "vec_len", len_init_args));
        ir_block_add(cur, ir_store(len_init_v, len_slot));
        let hl: i64 = ctr_next(lbls); let bl: i64 = ctr_next(lbls);
        let il: i64 = ctr_next(lbls); let xl: i64 = ctr_next(lbls);
        ir_block_add(cur, ir_br(hl));
        let mut hb: Vec<i32> = ir_block_new(hl); ir_fn_add_block(fir, hb);
        hb = deadline_poll_emit_if_enabled(hb, regs, loop_sym);
        let idx_v: i64 = ctr_next(regs); ir_block_add(hb, ir_load(idx_v, idx_slot));
        let len_v: i64 = ctr_next(regs); ir_block_add(hb, ir_load(len_v, len_slot));
        let cv: i64 = ctr_next(regs); ir_block_add(hb, ir_cmpop(9, cv, idx_v, len_v));
        ir_block_add(hb, ir_br_cond(cv, bl, xl));
        let mut bb: Vec<i32> = ir_block_new(bl); ir_fn_add_block(fir, bb);
        let iter_v2: i64 = ctr_next(regs); ir_block_add(bb, ir_load(iter_v2, iter_slot));
        let idx_v2: i64 = ctr_next(regs); ir_block_add(bb, ir_load(idx_v2, idx_slot));
        let mut get_args: Vec<i32> = Vec::new(); get_args.push(iter_v2); get_args.push(idx_v2);
        let item_v: i64 = ctr_next(regs); ir_block_add(bb, ir_call_ex(item_v, "vec_get", get_args));
        ir_block_add(bb, ir_store(item_v, item_slot));
        bb = lower_stmts(pool, node_field(pool, nid, 3), bb, regs, lbls, sym_clone(loop_sym), fir, strtab, il, xl, structs, closures, trait_impls);
        if block_has_term(bb) == 0 { ir_block_add(bb, ir_br(il)); };
        let mut ib: Vec<i32> = ir_block_new(il); ir_fn_add_block(fir, ib);
        let idx_v3: i64 = ctr_next(regs); ir_block_add(ib, ir_load(idx_v3, idx_slot));
        let one: i64 = ctr_next(regs); ir_block_add(ib, ir_const_int(one, 1));
        let next_v: i64 = ctr_next(regs); ir_block_add(ib, ir_binop(2, next_v, idx_v3, one));
        ir_block_add(ib, ir_store(next_v, idx_slot));
        ir_block_add(ib, ir_br(hl));
        let mut xb: Vec<i32> = ir_block_new(xl); ir_fn_add_block(fir, xb); return xb;
    };
    if kind == 25 {
        let expr_nid: i64 = node_field(pool, nid, 1);
        let mut ep: Vec<i32> = lower_expr(pool, expr_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let out_blk: Vec<i32> = lx_blk(ep);
        let freed_name: str = auto_drop_explicit_free_name(pool, expr_nid);
        if str_len(freed_name) > 0 { auto_drop_mark_freed(sym, freed_name); };
        // detect handoff. If the expr is a
        // vec_push/vec_set/hashmap_insert with identifier value
        // arg referencing a registered auto-drop binding, mark
        // that binding as freed (suppresses the auto-drop emit
        // at fn return).
        let handoff_name: str = auto_drop_handoff_name(pool, expr_nid, sym);
        if str_len(handoff_name) > 0 { auto_drop_mark_freed(sym, handoff_name); };
        return out_blk;
    };
    if kind == 38 {
        let scrut_nid: i64 = node_field(pool, nid, 1);
        let scrut_t: str = expr_full_type_from_sym(pool, scrut_nid, sym, structs);
        let mut mp: Vec<i32> = lower_expr(pool, scrut_nid, cur, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls);
        let mexpr_r: i64 = lx_reg(mp);
        cur = lx_blk(mp);
        let mslot: i64 = ctr_next(regs); ir_fn_add_entry_alloca(fir, mslot);
        ir_block_add(cur, ir_store(mexpr_r, mslot));
        let arms_list: i64 = node_field(pool, nid, 2);
        let arm_cnt: i64 = list_len(pool, arms_list);
        let ml: i64 = ctr_next(lbls);
        let mut tag_r: i64 = 0 - 1;
        let mut ci: i64 = 0;
        while ci < arm_cnt {
            let arm_nid: i64 = list_get(pool, arms_list, ci);
            let ename: str = node_field(pool, arm_nid, 1);
            let vname: str = node_field(pool, arm_nid, 2);
            let binding: str = node_field(pool, arm_nid, 3);
            let body_list: i64 = node_field(pool, arm_nid, 4);
            let guard_nid: i64 = node_field(pool, arm_nid, 5);
            let al: i64 = ctr_next(lbls);
            let nl: i64 = ctr_next(lbls);
            if str_eq(ename, "__wild") {
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__int") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let iv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(iv_r, vname));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, mv, iv_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__str") {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                // intern via strtab_intern to dedup.
                let sidx: i64 = strtab_intern(strtab, fir, vname);
                let sv_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_str(sv_r, sidx));
                let mut eq_args: Vec<i32> = Vec::new(); eq_args.push(mv); eq_args.push(sv_r);
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(cmp_r, "str_eq", eq_args));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                if str_len(binding) > 0 {
                    ab = match_bind_whole(binding, ab, regs, arm_sym, mslot, fir, "str");
                };
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__range") == 1 || str_eq(ename, "__range_at") == 1 {
                // range pattern in stmt-position match.
                // Mirrors the lower_expr __range arm at line 10592.
                // Pre-v0.3.118 this branch fell through to the
                // enum-tag-decode path, which treated the i64
                // scrutinee as a Vec pointer and segfaulted at runtime
                // (`vec_get(inttoptr i64_value, 0)`). HIGH-blast
                // silent miscompute → segfault for any program using
                // range patterns in statement-form match (the
                // expression-position match was already correct).
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let lo_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(lo_r, vname));
                let hi_s: str = str_before_char_local(binding, 124);
                let hi_n: i64 = str_to_int(hi_s);
                let hi_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(hi_r, hi_n));
                let lo_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, lo_ok, lo_r, mv));
                let hi_ok: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(11, hi_ok, mv, hi_r));
                let both_r: i64 = ctr_next(regs); ir_block_add(cur, ir_binop(13, both_r, lo_ok, hi_ok));
                ir_block_add(cur, ir_br_cond(both_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let arm_sym: Vec<i32> = sym_clone(sym);
                if str_eq(ename, "__range_at") == 1 {
                    ab = match_bind_whole(str_after_char_local(binding, 124), ab, regs, arm_sym, mslot, fir, scrut_t);
                };
                ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
            } else if str_eq(ename, "__range_bad") == 1 || str_eq(ename, "__range_bad_at") == 1 {
                ir_block_add(cur, ir_br(nl));
            } else if str_eq(ename, "__struct") {
                ir_block_add(cur, ir_br(al));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_struct_fields(binding, ab, regs, arm_sym, mslot, fir, structs, pool, vname, scrut_t);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else if str_eq(ename, "__tuple") == 1 || str_eq(ename, "__slice") == 1 {
                let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                let mut len_args: Vec<i32> = Vec::new(); len_args.push(mv);
                let len_r: i64 = ctr_next(regs); ir_block_add(cur, ir_call_ex(len_r, "vec_len", len_args));
                let needed: i64 = pattern_list_value_count(binding);
                let needed_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(needed_r, needed));
                let cmp_r: i64 = ctr_next(regs);
                if str_eq(ename, "__slice") == 1 && pattern_list_has_rest(binding) == 1 {
                    ir_block_add(cur, ir_cmpop(11, cmp_r, needed_r, len_r));
                } else {
                    ir_block_add(cur, ir_cmpop(7, cmp_r, len_r, needed_r));
                };
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                ab = match_bind_vec_pattern(binding, ab, regs, arm_sym, mslot, fir, scrut_t, len_r);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            } else {
                if tag_r < 0 {
                    let mv: i64 = ctr_next(regs); ir_block_add(cur, ir_load(mv, mslot));
                    let zero_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(zero_r, 0));
                    let mut tag_args: Vec<i32> = Vec::new(); tag_args.push(mv); tag_args.push(zero_r);
                    tag_r = ctr_next(regs); ir_block_add(cur, ir_call_ex(tag_r, "vec_get", tag_args));
                };
                let etag_key: str = str_concat("__etag_", str_concat(ename, str_concat("_", vname)));
                let vtag: i64 = sym_get(sym, etag_key);
                let vtag_r: i64 = ctr_next(regs); ir_block_add(cur, ir_const_int(vtag_r, vtag));
                let cmp_r: i64 = ctr_next(regs); ir_block_add(cur, ir_cmpop(7, cmp_r, tag_r, vtag_r));
                ir_block_add(cur, ir_br_cond(cmp_r, al, nl));
                let mut ab: Vec<i32> = ir_block_new(al); ir_fn_add_block(fir, ab);
                let mut arm_sym: Vec<i32> = sym_clone(sym);
                let payload_binding: str = pattern_after_at_prefix(binding);
                let at_name: str = pattern_at_prefix_name(binding);
                if str_len(at_name) > 0 { ab = match_bind_whole(at_name, ab, regs, arm_sym, mslot, fir, scrut_t); };
                ab = match_bind_payloads_per_idx(payload_binding, ab, regs, arm_sym, mslot, fir, ename, vname, scrut_t);
                if guard_nid > 0 {
                    let mut gp: Vec<i32> = lower_expr(pool, guard_nid, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    let gr: i64 = lx_reg(gp);
                    ab = lx_blk(gp);
                    let gl: i64 = ctr_next(lbls);
                    ir_block_add(ab, ir_br_cond(gr, gl, nl));
                    let mut gb: Vec<i32> = ir_block_new(gl); ir_fn_add_block(fir, gb);
                    gb = lower_stmts(pool, body_list, gb, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(gb) == 0 { ir_block_add(gb, ir_br(ml)); };
                } else {
                    ab = lower_stmts(pool, body_list, ab, regs, lbls, arm_sym, fir, strtab, lh, lx, structs, closures, trait_impls);
                    if block_has_term(ab) == 0 { ir_block_add(ab, ir_br(ml)); };
                };
            };
            let mut nb: Vec<i32> = ir_block_new(nl); ir_fn_add_block(fir, nb);
            cur = nb;
            ci = ci + 1;
        };
        ir_block_add(cur, ir_br(ml));
        let mut mb: Vec<i32> = ir_block_new(ml); ir_fn_add_block(fir, mb);
        return mb;
    };
    if kind == 26 {
        // `break` outside any loop. Pre-fix the codegen
        // silently no-op'd (the if-guard's `else` branch did
        // nothing), so `fn main() { break; 0 }` compiled to
        // `fn main() { 0 }` and exited successfully — adopters
        // typo'ing a misplaced control-flow stmt got no signal at
        // all. Halt cleanly with NR024.
        if lx < 0 {
            panic("error[NR024]: `break` outside any loop. Move the `break;` inside a `loop`/`while`/`for` body, or remove it entirely.");
        };
        ir_block_add(cur, ir_br(lx));
        return cur;
    };
    if kind == 27 {
        // `continue` outside any loop. Same hazard class
        // as the break case above.
        if lh < 0 {
            panic("error[NR024]: `continue` outside any loop. Move the `continue;` inside a `loop`/`while`/`for` body, or remove it entirely.");
        };
        ir_block_add(cur, ir_br(lh));
        return cur;
    };
    print(str_concat("ERROR: unknown stmt kind ", str_from_int(kind)));
    // pre-fix this silently returned `cur` (the current basic
    // block) — the stmt was DROPPED from the IR with no clang error.
    // Adopter binary skipped the statement entirely. Halt now.
    panic(str_concat("nucleor: unknown stmt kind ", str_from_int(kind)));
    return cur;
}
#[manual_drop]
fn lower_stmts(pool: Vec<i32>, lid: i64, cur: Vec<i32>, regs: Vec<i32>, lbls: Vec<i32>, sym: Vec<i32>, fir: Vec<i32>, strtab: Vec<i32>, lh: i64, lx: i64, structs: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>) -> Vec<i32> {
    let cnt: i64 = list_len(pool, lid); let mut i: i64 = 0; let mut b: Vec<i32> = cur;
    while i < cnt { b = lower_stmt(pool, list_get(pool, lid, i), b, regs, lbls, sym, fir, strtab, lh, lx, structs, closures, trait_impls); i = i + 1; };
    return b;
}

#[manual_drop]
fn lower_fn(pool: Vec<i32>, fn_nid: i64, strtab: Vec<i32>, strtab_aux: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, globals: Vec<i32>, closures: Vec<i32>, trait_impls: Vec<i32>, fn_decls: Vec<i32>, fn_return_map: i64, require_exprs: Vec<i32>, ensure_exprs: Vec<i32>, invariant_exprs: Vec<i32>, old_snapshots: Vec<i32>, auto_drop_fns: Vec<i32>, manual_drop_fns: Vec<i32>, suppress_auto_drop: i64) -> Vec<i32> {
    let name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let blist: i64 = node_field(pool, fn_nid, 4);
    let pc: i64 = list_len(pool, plist);
    let mut regs: Vec<i32> = ctr_new();
    let mut lbls: Vec<i32> = ctr_new();
    let mut sym: Vec<i32> = sym_new();
    if str_starts_with(name, "__nuc_dl_inner_") == 1 {
        sym_set(sym, "__deadline_poll_enabled", 1);
    };
    if suppress_auto_drop == 0
       && name_in_manual_drop(manual_drop_fns, name) == 0 {
        // 2026-05-07 Phase 2b-3 default-flip: every fn auto-drops by
        // default; #[manual_drop] opts out. Pre-flip the gate also
        // required `name_in_auto_drop(auto_drop_fns, name) == 1`,
        // i.e. opt-IN via #[auto_drop]. That meant nearly every
        // stdlib fn ran with NO drop semantics — Vec heap allocations
        // leaked, and the "move-into-struct-field" tracking in
        // auto_drop_mark_constructor_handoffs was dead code for fns
        // outside the explicit auto_drop_fns whitelist.
        // Flipping to opt-out activates the existing handoff machinery
        // (line 29045 of this file) and closes the ML fixture cluster
        // without per-fn manual_drop
        // annotations across stdlib/rods/ml/. The bug was: handoff
        // recognition logic was correct but the gate that enabled it
        // was inverted vs the comment's stated Phase 2b-3 intent.
        // #[manual_drop] still wins for fns that explicitly opt out
        // (parsers, low-level helpers, etc. — anywhere the body
        // carries explicit Vec lifetime management).
        sym_set(sym, "__auto_drop_enabled", 1);
    };
    enum_populate_sym(pool, enums, sym);
    // keep fn-return metadata in one shared map
    // instead of injecting every __fnret_/__fnfulltype_ pair into every
    // function-local sym. sym_get falls back to this map for those keys.
    sym_set(sym, "__fn_return_map", fn_return_map);
    // keep this fn's generic trait bounds available to
    // lower_expr kind-8. Generic fns are still emitted as one ABI-level
    // body, so this only enables conservative single-impl dispatch for
    // `T: Trait` receiver methods; ambiguous multi-impl bounds halt
    // instead of falling through to `vec_<method>`.
    let fn_gparams: i64 = node_field(pool, fn_nid, 5);
    if fn_gparams >= 0 {
        let mut gp_v529: i64 = 0;
        let gp_count: i64 = list_len(pool, fn_gparams);
        let mut current_gparam: str = "";
        while gp_v529 < gp_count {
            let ge_v529: str = list_get(pool, fn_gparams, gp_v529);
            if str_len(ge_v529) > 1 && str_char_at(ge_v529, 0) == 63 {
                if str_len(current_gparam) > 0 {
                    let bound_name: str = str_substring(ge_v529, 1, str_len(ge_v529));
                    let count_key: str = str_concat("__gparam_bound_count_", current_gparam);
                    let mut bound_count: i64 = sym_get(sym, count_key);
                    if bound_count < 0 { bound_count = 0; };
                    sym_set(sym, str_concat(str_concat("__gparam_bound_", current_gparam), str_concat("_", str_from_int(bound_count))), bound_name);
                    sym_set(sym, count_key, bound_count + 1);
                };
            } else {
                if str_len(ge_v529) > 0 && str_char_at(ge_v529, 0) != 39 {
                    current_gparam = ge_v529;
                    sym_set(sym, str_concat("__gparam_bound_count_", current_gparam), 0);
                } else {
                    current_gparam = "";
                };
            };
            gp_v529 = gp_v529 + 1;
        };
    };
    sym_set(sym, "__current_fn_full_return", node_field(pool, fn_nid, 3));
    if str_eq(type_base_name(node_field(pool, fn_nid, 3)), "u64") == 1 { sym_set(sym, "__has_u64_v886", 1); };
    let mut fir: Vec<i32> = ir_fn_new(name, pc);
    ir_fn_set_strtab_aux(fir, strtab_aux);
    let mut ebb0: Vec<i32> = ir_block_new(0);
    ir_fn_add_block(fir, ebb0);
    let mut pi: i64 = 0;
    while pi < pc {
        let pnid: i64 = list_get(pool, plist, pi);
        let pname: str = node_field(pool, pnid, 1);
        // phase 3c (typed param alloca) REVERTED. The
        let ptype: str = node_field(pool, pnid, 2);
        let sbase: str = type_base_name(ptype);
        if str_eq(sbase, "u64") == 1 { sym_set(sym, "__has_u64_v886", 1); };
        let pblen: i64 = str_len(sbase);
        let mut wp: i64 = 0;
        if pblen == 2 {
            if str_eq(sbase, "i8") == 1 { wp = 8; }
            else if str_eq(sbase, "u8") == 1 { wp = 0 - 8; };
        } else if pblen == 3 {
            if str_eq(sbase, "i16") == 1 { wp = 16; }
            else if str_eq(sbase, "u16") == 1 { wp = 0 - 16; }
            else if str_eq(sbase, "i32") == 1 { wp = 32; }
            else if str_eq(sbase, "u32") == 1 { wp = 0 - 32; };
        };
        let awp: i64 = if wp >= 0 { wp } else { 0 - wp };
        let ar: i64 = ctr_next(regs);
        if awp == 0 {
            ir_block_add(ebb0, ir_alloca(ar));
        } else {
            ir_block_add(ebb0, ir_alloca_t(ar, awp));
        };
        let pr2: i64 = ctr_next(regs); ir_block_add(ebb0, ir_param_ref(pr2, pi));
        if awp == 0 {
            ir_block_add(ebb0, ir_store(pr2, ar));
        } else {
            // Trunc i64 → iN and typed-store. Param arrives as i64 at
            // the fn-signature boundary; the trunc gives a clean iN
            // value for the typed alloca.
            let tpr: i64 = ctr_next(regs);
            ir_block_add(ebb0, ir_trunc(tpr, pr2, awp));
            ir_block_add(ebb0, ir_store_t(tpr, ar, awp));
        };
        sym_set(sym, pname, ar);
        if wp != 0 { ir_fn_set_width(fir, ar, wp); };
        // Track struct type for parameters (strip generic params)
        if str_len(sbase) > 0 { sym_set(sym, str_concat("__type_", pname), sbase); };
        // also store full declared type for generic-aware
        // dispatch (mirror the same change at the let binding site).
        if str_len(ptype) > 0 { sym_set(sym, str_concat("__fulltype_", pname), ptype); };
        pi = pi + 1;
    };
    let mut gi: i64 = 0;
    while gi < vec_len(globals) {
        let gnid: i64 = vec_get(globals, gi);
        let gname: str = node_field(pool, gnid, 1);
        let gar: i64 = ctr_next(regs); ir_block_add(ebb0, ir_alloca(gar));
        sym_set(sym, gname, gar);
        let ginit: i64 = node_field(pool, gnid, 3);
        let mut gp: Vec<i32> = lower_expr(pool, ginit, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        let gv: i64 = lx_reg(gp);
        ebb0 = lx_blk(gp);
        ir_block_add(ebb0, ir_store(gv, gar));
        let mut gtype: str = node_field(pool, gnid, 2);
        if str_len(gtype) == 0 && node_kind(pool, ginit) == 34 { gtype = node_field(pool, ginit, 1); }
        else if str_len(gtype) == 0 && node_kind(pool, ginit) == 12 { gtype = node_field(pool, ginit, 1); };
        let gbase: str = type_base_name(gtype);
        if str_len(gbase) > 0 { sym_set(sym, str_concat("__type_", gname), gbase); };
        // full declared type (mirror let / param sites).
        if str_len(gtype) > 0 { sym_set(sym, str_concat("__fulltype_", gname), gtype); };
        gi = gi + 1;
    };
    let mut osi: i64 = 0;
    let os_count: i64 = vec_len(old_snapshots);
    while osi + 2 < os_count {
        if str_eq(vec_get(old_snapshots, osi), name) == 1 {
            let synth_name: str = vec_get(old_snapshots, osi + 1);
            let inner_nid: i64 = vec_get(old_snapshots, osi + 2);
            let snap_ar: i64 = ctr_next(regs);
            ir_block_add(ebb0, ir_alloca(snap_ar));
            let mut snap_lp: Vec<i32> = lower_expr(pool, inner_nid, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            let snap_rr: i64 = lx_reg(snap_lp);
            ebb0 = lx_blk(snap_lp);
            ir_block_add(ebb0, ir_store(snap_rr, snap_ar));
            sym_set(sym, synth_name, snap_ar);
        };
        osi = osi + 3;
    };
    let mut ens_pre_walk: i64 = 0;
    let mut ens_pre_n: i64 = 0;
    let ens_pre_count: i64 = vec_len(ensure_exprs);
    while ens_pre_walk + 1 < ens_pre_count {
        if str_eq(vec_get(ensure_exprs, ens_pre_walk), name) == 1 {
            let ens_nid_p: i64 = vec_get(ensure_exprs, ens_pre_walk + 1);
            sym_set(sym, str_concat("__current_fn_ensure_nid_", str_from_int(ens_pre_n)), ens_nid_p);
            ens_pre_n = ens_pre_n + 1;
        };
        ens_pre_walk = ens_pre_walk + 2;
    };
    if ens_pre_n > 0 {
        sym_set(sym, "__current_fn_ensure_count", ens_pre_n);
        // Back-compat: legacy single-nid lookup still works.
        sym_set(sym, "__current_fn_ensure_nid", sym_get(sym, "__current_fn_ensure_nid_0"));
    };
    let mut req_idx: i64 = 0;
    let req_count: i64 = vec_len(require_exprs);
    while req_idx + 1 < req_count {
        let cand: str = vec_get(require_exprs, req_idx);
        if str_eq(cand, name) == 1 {
            let req_nid: i64 = vec_get(require_exprs, req_idx + 1);
            let mut req_lp: Vec<i32> = lower_expr(pool, req_nid, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            let req_rr: i64 = lx_reg(req_lp);
            ebb0 = lx_blk(req_lp);
            let mut req_args: Vec<i32> = Vec::new();
            req_args.push(req_rr);
            let req_cr: i64 = ctr_next(regs);
            ir_block_add(ebb0, ir_call_ex(req_cr, "contract_require", req_args));
        };
        req_idx = req_idx + 2;
    };
    let mut inv_split: i64 = 0;
    let inv_name_len: i64 = str_len(name);
    let mut found_split: i64 = 0;
    while inv_split + 1 < inv_name_len {
        if str_char_at(name, inv_split) == 95 && str_char_at(name, inv_split + 1) == 95 {
            found_split = 1;
            inv_split = inv_name_len;
        } else {
            inv_split = inv_split + 1;
        };
    };
    if found_split == 1 {
        // Re-walk to capture the actual split index now that we know it exists.
        let mut sp: i64 = 0;
        while sp + 1 < inv_name_len {
            if str_char_at(name, sp) == 95 && str_char_at(name, sp + 1) == 95 { break; };
            sp = sp + 1;
        };
        if sp > 0 && sp + 1 < inv_name_len {
            let inv_type: str = str_substring(name, 0, sp);
            let mut inv_idx: i64 = 0;
            let mut inv_nid: i64 = 0 - 1;
            let inv_count: i64 = vec_len(invariant_exprs);
            while inv_idx + 1 < inv_count {
                if str_eq(vec_get(invariant_exprs, inv_idx), inv_type) == 1 {
                    inv_nid = vec_get(invariant_exprs, inv_idx + 1);
                    inv_idx = inv_count;
                } else {
                    inv_idx = inv_idx + 2;
                };
            };
            if inv_nid >= 0 {
                // self-method path: first param is `self`. Entry-emit
                // the invariant predicate immediately, then stash the
                // nid for exit-emit at every return site.
                let mut is_self_method: i64 = 0;
                if pc > 0 {
                    let first_p: i64 = list_get(pool, plist, 0);
                    if str_eq(node_field(pool, first_p, 1), "self") == 1 { is_self_method = 1; };
                };
                let rtype: str = node_field(pool, fn_nid, 3);
                let mut is_ctor: i64 = 0;
                if is_self_method == 0 {
                    if str_eq(rtype, inv_type) == 1 || str_eq(rtype, "Self") == 1 { is_ctor = 1; };
                };
                if is_self_method == 1 {
                    let mut inv_lp: Vec<i32> = lower_expr(pool, inv_nid, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
                    let inv_rr: i64 = lx_reg(inv_lp);
                    ebb0 = lx_blk(inv_lp);
                    let mut inv_args: Vec<i32> = Vec::new();
                    inv_args.push(inv_rr);
                    let inv_cr: i64 = ctr_next(regs);
                    ir_block_add(ebb0, ir_call_ex(inv_cr, "contract_invariant", inv_args));
                    sym_set(sym, "__current_method_invariant_nid", inv_nid);
                } else if is_ctor == 1 {
                    sym_set(sym, "__current_method_invariant_nid", inv_nid);
                    sym_set(sym, "__current_method_is_ctor", 1);
                };
            };
        };
    };
    let bcnt: i64 = list_len(pool, blist);
    let mut fb: Vec<i32> = ebb0;
    let mut last_kind: i64 = 0 - 1;
    if bcnt > 0 { last_kind = node_kind(pool, list_get(pool, blist, bcnt - 1)); };
    if bcnt > 0 && (last_kind == 25 || last_kind == 23 || last_kind == 38) {
        let mut bi: i64 = 0;
        while bi + 1 < bcnt {
            fb = lower_stmt(pool, list_get(pool, blist, bi), fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            bi = bi + 1;
        };
        let last_stmt: i64 = list_get(pool, blist, bcnt - 1);
        let mut expr_nid: i64 = last_stmt;
        if last_kind == 25 { expr_nid = node_field(pool, last_stmt, 1); };
        let mut ep: Vec<i32> = lower_expr(pool, expr_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
        fb = lx_blk(ep);
        let mut rv: i64 = lx_reg(ep);
        let tail_freed_name: str = auto_drop_explicit_free_name(pool, expr_nid);
        if str_len(tail_freed_name) > 0 { auto_drop_mark_freed(sym, tail_freed_name); };
        if block_has_term(fb) == 0 {
            if rv < 0 {
                rv = ctr_next(regs);
                ir_block_add(fb, ir_const_int(rv, 0));
            };
            let mut ens_first_idx: i64 = 0 - 1;
            let mut ens_walk: i64 = 0;
            let ens_count: i64 = vec_len(ensure_exprs);
            while ens_walk + 1 < ens_count {
                if str_eq(vec_get(ensure_exprs, ens_walk), name) == 1 {
                    if ens_first_idx < 0 { ens_first_idx = ens_walk; };
                };
                ens_walk = ens_walk + 2;
            };
            if ens_first_idx >= 0 {
                let ens_ar: i64 = ctr_next(regs);
                ir_block_add(fb, ir_alloca(ens_ar));
                ir_block_add(fb, ir_store(rv, ens_ar));
                sym_set(sym, "result", ens_ar);
                let mut ens_emit_idx: i64 = 0;
                while ens_emit_idx + 1 < ens_count {
                    if str_eq(vec_get(ensure_exprs, ens_emit_idx), name) == 1 {
                        let ens_nid: i64 = vec_get(ensure_exprs, ens_emit_idx + 1);
                        let mut ens_lp: Vec<i32> = lower_expr(pool, ens_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
                        let ens_pr: i64 = lx_reg(ens_lp);
                        fb = lx_blk(ens_lp);
                        let mut ens_args: Vec<i32> = Vec::new();
                        ens_args.push(ens_pr);
                        let ens_cr: i64 = ctr_next(regs);
                        ir_block_add(fb, ir_call_ex(ens_cr, "contract_ensure", ens_args));
                    };
                    ens_emit_idx = ens_emit_idx + 2;
                };
            };
            let invx_nid: i64 = sym_get(sym, "__current_method_invariant_nid");
            if invx_nid >= 0 {
                let invx_is_ctor: i64 = sym_get(sym, "__current_method_is_ctor");
                if invx_is_ctor == 1 {
                    let self_ar: i64 = ctr_next(regs);
                    ir_block_add(fb, ir_alloca(self_ar));
                    ir_block_add(fb, ir_store(rv, self_ar));
                    sym_set(sym, "self", self_ar);
                    // Re-derive the inv_type from `name` (Type__method
                    // → Type) so field-access on self lowers correctly.
                    let nl_t: i64 = str_len(name);
                    let mut sp_t: i64 = 0;
                    while sp_t + 1 < nl_t {
                        if str_char_at(name, sp_t) == 95 && str_char_at(name, sp_t + 1) == 95 { break; };
                        sp_t = sp_t + 1;
                    };
                    if sp_t > 0 && sp_t + 1 < nl_t {
                        let it_ctor: str = str_substring(name, 0, sp_t);
                        sym_set(sym, str_concat("__type_", "self"), it_ctor);
                        sym_set(sym, str_concat("__fulltype_", "self"), it_ctor);
                    };
                };
                let mut invx_lp: Vec<i32> = lower_expr(pool, invx_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
                let invx_pr: i64 = lx_reg(invx_lp);
                fb = lx_blk(invx_lp);
                let mut invx_args: Vec<i32> = Vec::new();
                invx_args.push(invx_pr);
                let invx_cr: i64 = ctr_next(regs);
                ir_block_add(fb, ir_call_ex(invx_cr, "contract_invariant", invx_args));
            };
            let skip_tail_name: str = auto_drop_return_skip_name(pool, expr_nid, sym);
            auto_drop_mark_constructor_handoffs(pool, expr_nid, sym);
            fb = auto_drop_emit_live(fb, regs, sym, skip_tail_name);
            ir_block_add(fb, ir_ret(rv));
        };
        return fir;
    };
    fb = lower_stmts(pool, blist, ebb0, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
    if block_has_term(fb) == 0 {
        let zr: i64 = ctr_next(regs); ir_block_add(fb, ir_const_int(zr, 0));
        let mut ens2_first: i64 = 0 - 1;
        let mut ens2_walk: i64 = 0;
        let ens2_count: i64 = vec_len(ensure_exprs);
        while ens2_walk + 1 < ens2_count {
            if str_eq(vec_get(ensure_exprs, ens2_walk), name) == 1 {
                if ens2_first < 0 { ens2_first = ens2_walk; };
            };
            ens2_walk = ens2_walk + 2;
        };
        if ens2_first >= 0 {
            let ens2_ar: i64 = ctr_next(regs);
            ir_block_add(fb, ir_alloca(ens2_ar));
            ir_block_add(fb, ir_store(zr, ens2_ar));
            sym_set(sym, "result", ens2_ar);
            let mut ens2_emit: i64 = 0;
            while ens2_emit + 1 < ens2_count {
                if str_eq(vec_get(ensure_exprs, ens2_emit), name) == 1 {
                    let ens2_nid: i64 = vec_get(ensure_exprs, ens2_emit + 1);
                    let mut ens2_lp: Vec<i32> = lower_expr(pool, ens2_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
                    let ens2_pr: i64 = lx_reg(ens2_lp);
                    fb = lx_blk(ens2_lp);
                    let mut ens2_args: Vec<i32> = Vec::new();
                    ens2_args.push(ens2_pr);
                    let ens2_cr: i64 = ctr_next(regs);
                    ir_block_add(fb, ir_call_ex(ens2_cr, "contract_ensure", ens2_args));
                };
                ens2_emit = ens2_emit + 2;
            };
        };
        let invx2_nid: i64 = sym_get(sym, "__current_method_invariant_nid");
        if invx2_nid >= 0 {
            let invx2_is_ctor: i64 = sym_get(sym, "__current_method_is_ctor");
            if invx2_is_ctor == 1 {
                let self_ar2: i64 = ctr_next(regs);
                ir_block_add(fb, ir_alloca(self_ar2));
                ir_block_add(fb, ir_store(zr, self_ar2));
                sym_set(sym, "self", self_ar2);
                let nl2: i64 = str_len(name);
                let mut sp2: i64 = 0;
                while sp2 + 1 < nl2 {
                    if str_char_at(name, sp2) == 95 && str_char_at(name, sp2 + 1) == 95 { break; };
                    sp2 = sp2 + 1;
                };
                if sp2 > 0 && sp2 + 1 < nl2 {
                    let it2: str = str_substring(name, 0, sp2);
                    sym_set(sym, str_concat("__type_", "self"), it2);
                    sym_set(sym, str_concat("__fulltype_", "self"), it2);
                };
            };
            let mut invx2_lp: Vec<i32> = lower_expr(pool, invx2_nid, fb, regs, lbls, sym, fir, strtab, 0 - 1, 0 - 1, structs, closures, trait_impls);
            let invx2_pr: i64 = lx_reg(invx2_lp);
            fb = lx_blk(invx2_lp);
            let mut invx2_args: Vec<i32> = Vec::new();
            invx2_args.push(invx2_pr);
            let invx2_cr: i64 = ctr_next(regs);
            ir_block_add(fb, ir_call_ex(invx2_cr, "contract_invariant", invx2_args));
        };
        fb = auto_drop_emit_live(fb, regs, sym, "");
        ir_block_add(fb, ir_ret(zr));
    };
    return fir;
}
