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
// v0.7.x P2: store the shared table in a dedicated runtime hashmap.
// The original shared Vec removed the N^2 sym_set cost but still did a
// backward linear scan for every fallback lookup; caller attribution
// showed ~48M vec_get + ~48M str_eq calls here in one self-host build.
#[manual_drop]
fn fn_return_map_get(m: i64, key: str) -> i64 {
    if m <= 0 { return 0 - 1; };
    if __nucleor_hashmap_contains(m, key) == 1 { return __nucleor_hashmap_get(m, key); };
    return 0 - 1;
}

// v0.4.3 Phase B redo — hash-backed sym_get on a single warm-cache
// hashmap (one allocation total in the runtime; see nucleor_llvm_rt.c
// __nucleor_sym_aux_create comment for the design rationale).
// v0.3.237's per-sym aux model failed because sym_clone -> new aux
// per clone -> 1.8x peak-memory regression. The warm cache fixes
// that: ONE NHashMap exists in the runtime; when sym_get is called
// on a different handle than the cached one, the hashmap is cleared
// and rebuilt from the new sym. Memory cost is bounded by the size
// of the largest single sym ever cached.
// Size threshold: for small syms (< 128 pairs / 256 vec entries),
// the linear backward scan is competitive (cache-friendly, no
// hashmap touch) AND avoids warm-cache thrash on the many small
// clones that branch isolation creates. The hash path only fires
// for syms above the threshold -- in practice, the long-lived
// outer module-scope sym that linear scan was actually slow on.
// Most-recent-entry vec fast path is preserved -- the just-set
// lookup never touches the hashmap or the threshold check.
// Correctness invariants (validated by the bootstrap fixed-point
// gate -- if any of these are wrong, stage_b != stage_c IR diff
// fires):
//   sym_set: appends to vec only. Catchup loop in sym_get re-inserts;
//     hashmap_insert overwrites on duplicate key, so last-write-wins
//     gives the same answer the backward scan would.
//   own_put_i / own_put_s: in-place vec_set + hashmap_insert sync
//     IF this sym is currently the warm one. Without the sync the
//     hash would return the stale pre-update value.
//   own_restore: clears the hash if this sym is warm + resets
//     built_at = 0 so the next sym_get rebuilds from the post-
//     restore vec.
//   sym_clone: copies vec contents only. The new sym_handle is
//     different; on first sym_get against the clone, the warm
//     cache will reset and rebuild from the clone's vec.
#[manual_drop]
fn sym_get(s: Vec<i32>, name: str) -> i64 {
    let n: i64 = vec_len(s);
    // v1.1.x perf: collapse the n>=2 tail check + n<64 linear scan
    // into a single C call. Helper scans backward from tail anyway,
    // so the explicit tail check was redundant. Saves one FFI call
    // per sym_get (~9M / build).
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

// v0.6.74 RFC V1.1 step 2: tuple-struct shape detection. A struct is
// tuple-style if all field names match `__<digit>+` pattern (synthesized
// by parse_struct_decl when the decl uses paren-form). Used by
// constructor routing (kind-7 → struct ctor when callee is tuple-style)
// and field-access lowering (`p.0` → `p.__0`).
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

