// =====================================================
// OWNERSHIP CHECKER (S11.5)
// =====================================================
#[manual_drop]
fn own_new() -> Vec<i32> { return Vec::new(); }
#[manual_drop]
fn own_put_i(o: Vec<i32>, key: str, val: i64) -> i64 {
    return __nucleor_own_put_i_full(o, key, val);
}
#[manual_drop]
fn own_put_s(o: Vec<i32>, key: str, val: str) -> i64 {
    return __nucleor_own_put_i_full(o, key, val);
}
#[manual_drop]
fn own_set(o: Vec<i32>, name: str, state: i64) -> i64 { return own_put_i(o, str_concat("__os_", name), state); }
#[manual_drop]
fn own_get(o: Vec<i32>, name: str) -> i64 {
    let v: i64 = sym_get(o, str_concat("__os_", name));
    if v < 0 { return 1; }; // unknown variables default to alive
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
fn own_set_i(o: Vec<i32>, key: str, val: i64) -> i64 { return own_put_i(o, str_concat("__oi_", key), val); }
#[manual_drop]
fn own_get_i(o: Vec<i32>, key: str) -> i64 {
    let v: i64 = sym_get(o, str_concat("__oi_", key));
    if v < 0 { return 0; };
    return v;
}
#[manual_drop]
fn own_set_s_raw(o: Vec<i32>, key: str, val: str) -> i64 { return own_put_s(o, key, val); }
#[manual_drop]
fn own_get_s_raw(o: Vec<i32>, key: str) -> str {
    let v: i64 = sym_get(o, key);
    if v < 0 { return ""; };
    return v;
}
fn own_set_s(o: Vec<i32>, key: str, val: str) -> i64 { return own_put_s(o, str_concat("__os2_", key), val); }
#[manual_drop]
fn own_get_s(o: Vec<i32>, key: str) -> str {
    let v: i64 = sym_get(o, str_concat("__os2_", key));
    if v < 0 { return ""; };
    return v;
}
#[manual_drop]
fn own_g4_alias_root(o: Vec<i32>, name: str) -> str {
    let root: str = own_get_s_raw(o, str_concat("__g4_root_", name));
    if str_len(root) > 0 { return root; };
    return name;
}
#[manual_drop]
fn own_g4_set_alias(o: Vec<i32>, dst: str, src: str) -> i64 {
    let root: str = own_g4_alias_root(o, src);
    own_set_s_raw(o, str_concat("__g4_root_", src), root);
    own_set_s_raw(o, str_concat("__g4_root_", dst), root);
    return 0;
}
#[manual_drop]
fn own_g4_mark_freed(o: Vec<i32>, name: str, freed_by: str, state: i64) -> i64 {
    let root: str = own_g4_alias_root(o, name);
    own_set_s_raw(o, str_concat("__g4_root_", name), root);
    own_set_i_raw(o, str_concat("__g4_freed_", name), state);
    own_set_s_raw(o, str_concat("__g4_freed_by_", name), freed_by);
    if str_eq(root, name) == 0 {
        own_set_i_raw(o, str_concat("__g4_freed_", root), state);
        own_set_s_raw(o, str_concat("__g4_freed_by_", root), freed_by);
    };
    let prefix: str = "__g4_root_";
    let plen: i64 = str_len(prefix);
    let mut i: i64 = 0;
    while i + 1 < vec_len(o) {
        let key: str = vec_get(o, i);
        if str_starts_with(key, prefix) == 1 {
            let alias_root: str = vec_get(o, i + 1);
            if str_eq(alias_root, root) == 1 {
                let alias_name: str = str_substring(key, plen, str_len(key));
                own_set_i_raw(o, str_concat("__g4_freed_", alias_name), state);
                own_set_s_raw(o, str_concat("__g4_freed_by_", alias_name), freed_by);
            };
        };
        i = i + 2;
    };
    own_set_g4_flow_active(o);
    return 0;
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
fn own_cur_scope(o: Vec<i32>) -> i64 {
    if vec_len(o) > 11 { return vec_get(o, 11); };
    return own_get_i(o, "cur_scope");
}
#[manual_drop]
fn own_set_cur_scope(o: Vec<i32>, depth: i64) -> i64 {
    if vec_len(o) > 11 { vec_set(o, 11, depth); return 0; };
    return own_set_i(o, "cur_scope", depth);
}
#[manual_drop]
fn own_set_mutable(o: Vec<i32>, name: str, is_mut: i64) -> i64 { return own_set_i_raw(o, str_concat("__oi_mutable_", name), is_mut); }
#[manual_drop]
fn own_get_mutable(o: Vec<i32>, name: str) -> i64 {
    let key: str = str_concat("__oi_mutable_", name);
    let v: i64 = sym_get(o, key);
    if v >= 0 { return v; };
    // Correctness fallback for the only raw ownership metadata whose
    // stale warm-hash miss can become a false hard error: `let mut`.
    let mut i: i64 = vec_len(o) - 2;
    while i >= 0 {
        if str_eq(vec_get(o, i), key) == 1 { return vec_get(o, i + 1); };
        i = i - 2;
    };
    return 0;
}
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
fn own_init_names_vec(o: Vec<i32>) -> Vec<i32> {
    if vec_len(o) > 13 { return vec_get(o, 13); };
    return own_get_type(o, "__init_names");
}
#[manual_drop]
fn own_track_init_name(o: Vec<i32>, name: str) -> i64 {
    let keys: Vec<i32> = own_init_names_vec(o);
    let mut i: i64 = 0;
    while i < vec_len(keys) {
        if str_eq(vec_get(keys, i), name) == 1 { return 0; };
        i = i + 1;
    };
    keys.push(name);
    return 0;
}
#[manual_drop]
fn own_g4_flow_active(o: Vec<i32>) -> i64 {
    if vec_len(o) > 15 { return vec_get(o, 15); };
    return own_get_i_raw(o, "__g4_flow_active");
}
#[manual_drop]
fn own_set_g4_flow_active(o: Vec<i32>) -> i64 {
    if vec_len(o) > 15 { vec_set(o, 15, 1); return 0; };
    return own_set_i_raw(o, "__g4_flow_active", 1);
}
#[manual_drop]
fn own_g8_flow_active(o: Vec<i32>) -> i64 {
    if vec_len(o) > 17 { return vec_get(o, 17); };
    return own_get_i_raw(o, "__g8_flow_active");
}
#[manual_drop]
fn own_set_g8_flow_active(o: Vec<i32>) -> i64 {
    if vec_len(o) > 17 { vec_set(o, 17, 1); return 0; };
    return own_set_i_raw(o, "__g8_flow_active", 1);
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
fn own_mut_borrowed(o: Vec<i32>, key: str) -> i64 { return own_get_i_raw(o, str_concat("__oi_mut_", key)); }
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

// Non-allocating "is target string at source[pos..pos+len(target)]"
// check. Replaces the `str_eq(str_substring(source, pos, pos+tlen),
// target)` anti-pattern that was the dominant memory leak in the
// self-host compile (find_linecol_in_source, line_contains_text,
// source_box_binding_type, substring-search loops — each scanned
// the full source allocating a substring per byte position; for a
// 485 KB source that was ~485,000 transient allocations per
// invocation × thousands of invocations = ~9.5 GB of leaked
// transient strings during type-check).
#[manual_drop]
fn str_eq_at(source: str, pos: i64, target: str) -> i64 {
    // CRITICAL: do NOT call str_len(source) here — it's O(n) (walks
    // to the null terminator). The dominant caller (find_linecol_in_
    // source) already guarantees pos + str_len(target) <= str_len(
    // source) via its outer loop bound, so we don't need to recheck.
    // A naive bounds check made the s1 self-host compile take >5 min
    // (was ~25 s) because the per-call str_len walked the entire
    // 485 KB source for every byte position scanned.
    let tlen: i64 = str_len(target);
    let mut k: i64 = 0;
    while k < tlen {
        if str_char_at(source, pos + k) != str_char_at(target, k) { return 0; };
        k = k + 1;
    };
    return 1;
}
#[manual_drop]
fn str_eq_at_len(source: str, pos: i64, target: str, tlen: i64) -> i64 {
    let mut k: i64 = 0;
    while k < tlen {
        if str_char_at(source, pos + k) != str_char_at(target, k) { return 0; };
        k = k + 1;
    };
    return 1;
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
fn own_snapshot(o: Vec<i32>) -> Vec<i32> {
    let mut snap: Vec<i32> = Vec::with_capacity(vec_len(o));
    let mut i: i64 = 0;
    while i < vec_len(o) { snap.push(vec_get(o, i)); i = i + 1; };
    return snap;
}
#[manual_drop]
fn own_vec_has_key(o: Vec<i32>, key: str) -> i64 {
    let mut i: i64 = 0;
    while i + 1 < vec_len(o) {
        if str_eq(vec_get(o, i), key) == 1 { return 1; };
        i = i + 2;
    };
    return 0;
}
#[manual_drop]
fn own_clear_binding_flow(o: Vec<i32>, name: str) -> i64 {
    // A fresh `let name = ...` shadow or a definite assignment
    // reinitializes the slot. Stale path facts attached to an older
    // binding with the same spelling must not poison the new value.
    if vec_get(o, 15) == 0 && vec_get(o, 17) == 0 { return 0; };
    if vec_get(o, 15) == 1 {
        let g4_key: str = str_concat("__g4_freed_", name);
        if own_get_i_raw(o, g4_key) != 0 { own_set_i_raw(o, g4_key, 0); };
        let g4_by_key: str = str_concat("__g4_freed_by_", name);
        if str_len(own_get_s_raw(o, g4_by_key)) > 0 { own_set_s_raw(o, g4_by_key, ""); };
    };
    if vec_get(o, 17) == 1 {
        let g8_key: str = str_concat("__g8_cond_moved_", name);
        if own_get_i_raw(o, g8_key) != 0 { own_set_i_raw(o, g8_key, 0); };
    };
    return 0;
}
#[manual_drop]
fn own_enter_maybe_zero_loop(o: Vec<i32>) -> i64 {
    let d: i64 = own_get_i_raw(o, "__loop_maybe_zero_depth") + 1;
    own_set_i_raw(o, "__loop_maybe_zero_depth", d);
    return d;
}
#[manual_drop]
fn own_exit_maybe_zero_loop(o: Vec<i32>, depth: i64, mark_start: i64) -> i64 {
    if own_get_i_raw(o, "__loop_cond_init_count") <= mark_start {
        own_set_i_raw(o, "__loop_maybe_zero_depth", depth - 1);
        return 0;
    };
    let prefix: str = "__loop_cond_init_";
    let plen: i64 = str_len(prefix);
    let mut i: i64 = 0;
    while i + 1 < vec_len(o) {
        let key: str = vec_get(o, i);
        if str_starts_with(key, prefix) == 1 {
            let mark_depth: i64 = vec_get(o, i + 1);
            if mark_depth == depth {
                let bname: str = str_substring(key, plen, str_len(key));
                own_set_i_raw(o, str_concat("__init_", bname), 0);
                own_set_i_raw(o, key, 0);
            };
        };
        i = i + 2;
    };
    own_set_i_raw(o, "__loop_maybe_zero_depth", depth - 1);
    return 0;
}
#[manual_drop]
fn own_note_loop_cond_init(o: Vec<i32>, name: str, prev_init: i64) -> i64 {
    let depth: i64 = own_get_i_raw(o, "__loop_maybe_zero_depth");
    if depth <= 0 { return 0; };
    if prev_init != 0 { return 0; };
    if own_get_i_raw(o, str_concat("__init_seen_", name)) != 1 { return 0; };
    if own_get(o, name) != 0 { return 0; };
    let key: str = str_concat("__loop_cond_init_", name);
    if own_get_i_raw(o, key) == 0 {
        own_set_i_raw(o, key, depth);
        own_set_i_raw(o, "__loop_cond_init_count", own_get_i_raw(o, "__loop_cond_init_count") + 1);
    };
    return 0;
}
#[manual_drop]
fn own_has_uninit_binding(o: Vec<i32>) -> i64 {
    let names: Vec<i32> = own_init_names_vec(o);
    let mut i: i64 = 0;
    while i < vec_len(names) {
        let bname: str = vec_get(names, i);
        if own_get_i_raw(o, str_concat("__init_", bname)) == 0 {
            if own_get(o, bname) == 0 && own_get_i_raw(o, str_concat("__init_seen_", bname)) == 1 { return 1; };
        };
        i = i + 1;
    };
    return 0;
}
#[manual_drop]
fn own_restore(o: Vec<i32>, snap: Vec<i32>) -> i64 {
    // Reset o to snap state without dropping the whole backing store.
    // Branch isolation calls this in hot ownership paths; pop-all then
    // push-all preserved semantics but churned the Vec on every branch.
    let target_len: i64 = vec_len(snap);
    while vec_len(o) > target_len { o.pop(); };
    let mut i: i64 = 0;
    while i < target_len {
        if i < vec_len(o) { vec_set(o, i, vec_get(snap, i)); }
        else { o.push(vec_get(snap, i)); };
        i = i + 1;
    };
    // if this sym is the currently-warm one, the aux hashmap
    // holds stale entries from inside-the-branch own_put_i calls.
    // Clear it and reset built_at so the next sym_get rebuilds from
    // the post-restore vec. If it's not warm, the next sym_get will
    // rebuild anyway when it switches the warm slot.
    let h: i64 = __nucleor_sym_aux_get(o);
    if h > 0 {
        hashmap_clear(h);
        __nucleor_sym_aux_set_built_at(o, 0);
    };
    return 0;
}
#[manual_drop]
fn own_merge_state_key(o: Vec<i32>, a: Vec<i32>, b: Vec<i32>, key: str, va_in: i64, vb_in: i64) -> i64 {
    let klen_dsp: i64 = str_len(key);
    if klen_dsp >= 5 {
        let c2_dsp: i64 = str_char_at(key, 2);
        // 'g' family: __g4_*, __g8_*. Early-out for __g4_freed_by_
        // (same as pre-fix line-21780 behavior).
        if c2_dsp == 103 {
            if str_starts_with(key, "__g4_freed_by_") == 1 { return 0; };
        } else if c2_dsp != 111 && c2_dsp != 105 {
            // Not 'o', 'g', or 'i' — definitely a non-state key.
            // Apply non-state semantic and return.
            let mut va_ns: i64 = va_in;
            let mut vb_ns: i64 = vb_in;
            if va_ns < 0 { va_ns = 0; };
            if vb_ns < 0 { vb_ns = 0; };
            if va_ns == 2 || vb_ns == 2 { own_put_i(o, key, 2); };
            return 0;
        };
    };
    let mut va: i64 = va_in;
    let mut vb: i64 = vb_in;
    if va < 0 { va = 0; };
    if vb < 0 { vb = 0; };
    if str_starts_with(key, "__os_") == 1 {
        if va == 2 && vb == 2 {
            own_put_i(o, key, 2);
        } else {
            if (va == 2 && vb != 2) || (va != 2 && vb == 2) {
                let bname: str = str_substring(key, 5, str_len(key));
                if va != 2 { own_put_i(o, key, va); }
                else { own_put_i(o, key, vb); };
                own_set_i_raw(o, str_concat("__g8_cond_moved_", bname), 1);
                own_set_g8_flow_active(o);
            };
        };
        return 0;
    };
    if str_starts_with(key, "__g8_cond_moved_") == 1 {
        if va == 1 || vb == 1 {
            own_set_i_raw(o, key, 1);
            own_set_g8_flow_active(o);
        };
        return 0;
    };
    if str_starts_with(key, "__g4_freed_") == 1 {
        let g4_name: str = str_substring(key, 11, str_len(key));
        if va == 1 && vb == 1 {
            own_set_i_raw(o, key, 1);
            own_set_g4_flow_active(o);
            let g4_by_a: str = own_get_s_raw(a, str_concat("__g4_freed_by_", g4_name));
            let g4_by_b: str = own_get_s_raw(b, str_concat("__g4_freed_by_", g4_name));
            if str_len(g4_by_a) > 0 { own_set_s_raw(o, str_concat("__g4_freed_by_", g4_name), g4_by_a); }
            else if str_len(g4_by_b) > 0 { own_set_s_raw(o, str_concat("__g4_freed_by_", g4_name), g4_by_b); };
        } else {
            if va > 0 || vb > 0 {
                own_set_i_raw(o, key, 2);
                own_set_g4_flow_active(o);
                let g4c_by_a: str = own_get_s_raw(a, str_concat("__g4_freed_by_", g4_name));
                let g4c_by_b: str = own_get_s_raw(b, str_concat("__g4_freed_by_", g4_name));
                if str_len(g4c_by_a) > 0 { own_set_s_raw(o, str_concat("__g4_freed_by_", g4_name), g4c_by_a); }
                else if str_len(g4c_by_b) > 0 { own_set_s_raw(o, str_concat("__g4_freed_by_", g4_name), g4c_by_b); };
            };
        };
        return 0;
    };
    if str_starts_with(key, "__init_") == 1 && str_starts_with(key, "__init_seen_") == 0 {
        // G-11 init-state intersection.
        if va == 1 && vb == 1 { own_put_i(o, key, 1); }
        else { own_put_i(o, key, 0); };
        return 0;
    };
    if str_starts_with(key, "__init_seen_") == 1 {
        if va == 1 || vb == 1 { own_set_i_raw(o, key, 1); };
        return 0;
    };
    // Non-state key -- preserve legacy "either-moved -> moved" semantic.
    if va == 2 || vb == 2 { own_put_i(o, key, 2); };
    return 0;
}
#[manual_drop]
fn own_merge_moved(o: Vec<i32>, a: Vec<i32>, b: Vec<i32>) -> i64 {
    // RFC-0062 G-8 Phase 2b/3/4 + G-11 Phase 2b — combined merge
    // semantics at if/else joins.
    // For state keys (prefix `__os_`, G-8):
    //   both arms moved (va == vb == 2)         → state = 2 (OWN-001 catches subsequent read)
    //   exactly one arm moved (va == 2 XOR vb == 2) → state stays at pre-arm
    //     value (typically 1) and the cond-moved flag is set so
    //     subsequent reads emit OWN-G8-COND-MOVE.
    //   neither moved                           → preserve pre-arm state (no-op)
    // For init-state keys (prefix `__init_`, excluding `__init_seen_`, G-11):
    //   both arms definitely-assigned (va == 1 && vb == 1) → 1
    //   either arm not assigned                            → 0 (subsequent
    //     read emits INIT-G11-READ-BEFORE-INIT)
    // For other tracker entries: preserve the legacy "if either arm
    // has value 2, set value 2" semantic so any non-move tracker that
    // piggy-backed on this loop is unaffected.
    // Both `a` and `b` are consumed (freed) — they are then/else
    // env snapshots that no caller references after merge.
    let mut i: i64 = 0;
    while i < vec_len(a) {
        let key: str = vec_get(a, i);
        own_merge_state_key(o, a, b, key, vec_get(a, i + 1), sym_get(b, key));
        i = i + 2;
    };
    let nA: i64 = vec_len(a);
    let nB: i64 = vec_len(b);
    let use_hash: i64 = if nA >= 128 { 1 } else { 0 };
    let a_idx: i64 = if use_hash == 1 { __nucleor_hashmap_with_capacity(nA) } else { 0 - 1 };
    if use_hash == 1 {
        let mut ai: i64 = 0;
        while ai < nA {
            __nucleor_hashmap_insert(a_idx, vec_get(a, ai), vec_get(a, ai + 1));
            ai = ai + 2;
        };
    };
    let mut j: i64 = 0;
    while j < nB {
        let bkey: str = vec_get(b, j);
        let bklen: i64 = str_len(bkey);
        let mut is_state: i64 = 0;
        if bklen >= 5 {
            let c2b: i64 = str_char_at(bkey, 2);
            if c2b == 111 {
                if str_starts_with(bkey, "__os_") == 1 { is_state = 1; };
            } else if c2b == 103 {
                if str_starts_with(bkey, "__g4_freed_") == 1 { is_state = 1; }
                else if str_starts_with(bkey, "__g8_cond_moved_") == 1 { is_state = 1; };
            } else if c2b == 105 {
                if str_starts_with(bkey, "__init_") == 1 { is_state = 1; };
            };
        };
        if is_state == 1 {
            let in_a: i64 = if use_hash == 1 {
                if __nucleor_hashmap_contains(a_idx, bkey) == 1 { 1 } else { 0 }
            } else {
                if sym_get(a, bkey) >= 0 { 1 } else { 0 }
            };
            if in_a == 0 {
                own_merge_state_key(o, a, b, bkey, 0, vec_get(b, j + 1));
            };
        };
        j = j + 2;
    };
    if use_hash == 1 { __nucleor_hashmap_free(a_idx); };
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
fn g6_type_has_nonsendable(pool: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, tstr: str, depth: i64) -> i64 {
    if depth > 8 { return 0; };
    if str_len(tstr) == 0 { return 0; };
    if str_index_of(tstr, "HashMap<") >= 0 { return 1; };
    if str_index_of(tstr, "RefCell<") >= 0 { return 1; };
    if str_index_of(tstr, "Cell<") >= 0 { return 1; };
    let base: str = type_base_name(tstr);
    let sidx: i64 = struct_find_type(pool, structs, base);
    if sidx >= 0 {
        let s_nid: i64 = vec_get(structs, sidx);
        let flist: i64 = node_field(pool, s_nid, 2);
        let fc: i64 = list_len(pool, flist);
        let mut fi: i64 = 0;
        while fi < fc {
            let f_nid: i64 = list_get(pool, flist, fi);
            let f_t: str = node_field(pool, f_nid, 2);
            if g6_type_has_nonsendable(pool, structs, enums, f_t, depth + 1) == 1 { return 1; };
            fi = fi + 1;
        };
    };
    let eidx: i64 = enum_find(pool, enums, base);
    if eidx >= 0 {
        let e_nid: i64 = vec_get(enums, eidx);
        let vlist: i64 = node_field(pool, e_nid, 2);
        let vc: i64 = list_len(pool, vlist);
        let mut vi: i64 = 0;
        while vi < vc {
            let v_nid: i64 = list_get(pool, vlist, vi);
            let payload: i64 = node_field(pool, v_nid, 2);
            let pc: i64 = list_len(pool, payload);
            let mut pi: i64 = 0;
            while pi < pc {
                let p_t: str = list_get(pool, payload, pi);
                if g6_type_has_nonsendable(pool, structs, enums, p_t, depth + 1) == 1 { return 1; };
                pi = pi + 1;
            };
            vi = vi + 1;
        };
    };
    return 0;
}

// RFC-0062 G-6 Phase 3 helper — true iff `name` appears in the
// closure-param-list `cparams` (a list of name-string handles, see
// parse_primary line ~2564 / 2570: `mk_list(pool, cparams)`).
#[manual_drop]
fn g6_cparam_has(pool: Vec<i32>, cparams_lid: i64, name: str) -> i64 {
    let cnt: i64 = list_len(pool, cparams_lid);
    let mut i: i64 = 0;
    while i < cnt {
        let pname: str = list_get(pool, cparams_lid, i);
        if str_eq(pname, name) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}

// RFC-0062 G-6 Phase 3 helper — recursive walker over a closure
// body looking for any kind-3 identifier reference whose name is
// (a) not in the closure's param list and (b) registered as a
// local binding in the enclosing fn's `own` env (via
// `own_get_type` returning non-empty). A hit means the closure
// captures at least one local from the enclosing scope, which
// makes the closure non-Sendable unless every captured local is
// Sendable. Returns 1 on first hit, 0 if the walk completes with
// no captures detected. The walker is conservative on opaque
// kinds (returns 0 / false-negative) — Phase 4 promotion of
// SEND-G6-CLOSURE-CAPTURE intentionally fires only on patterns
// the walker can prove capture; bare-param-only closures (the
// `|x| x * 2` shape used by `tests/runtime/concurrency.nr`)
// correctly skip the diagnostic.
#[manual_drop]
fn g6_closure_walk_capture(pool: Vec<i32>, nid: i64, cparams_lid: i64, own: Vec<i32>) -> i64 {
    if nid < 0 { return 0; };
    if nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 || kind == 2 || kind == 71 || kind == 72 { return 0; };
    if kind == 3 {
        let vname: str = node_field(pool, nid, 1);
        if str_len(vname) == 0 { return 0; };
        if g6_cparam_has(pool, cparams_lid, vname) == 1 { return 0; };
        let vtyp: str = own_get_type(own, vname);
        if str_len(vtyp) > 0 { return 1; };
        return 0;
    };
    // Binary op / cmp: children at fields 2 & 3.
    if kind == 4 {
        if g6_closure_walk_capture(pool, node_field(pool, nid, 2), cparams_lid, own) == 1 { return 1; };
        if g6_closure_walk_capture(pool, node_field(pool, nid, 3), cparams_lid, own) == 1 { return 1; };
        return 0;
    };
    if kind == 10 {
        if g6_closure_walk_capture(pool, node_field(pool, nid, 1), cparams_lid, own) == 1 { return 1; };
        if g6_closure_walk_capture(pool, node_field(pool, nid, 2), cparams_lid, own) == 1 { return 1; };
        return 0;
    };
    // Unary / cast / borrow / deref / paren: child at field 1.
    if kind == 5 || kind == 6 || kind == 9 || kind == 22 || kind == 90 || kind == 91 || kind == 92 {
        return g6_closure_walk_capture(pool, node_field(pool, nid, 1), cparams_lid, own);
    };
    // Call kind 7: args list at field 2.
    if kind == 7 {
        let args7: i64 = node_field(pool, nid, 2);
        let ac7: i64 = list_len(pool, args7);
        let mut i7: i64 = 0;
        while i7 < ac7 {
            if g6_closure_walk_capture(pool, list_get(pool, args7, i7), cparams_lid, own) == 1 { return 1; };
            i7 = i7 + 1;
        };
        return 0;
    };
    // Method kind 8: receiver field 1 + args list at field 3.
    if kind == 8 {
        if g6_closure_walk_capture(pool, node_field(pool, nid, 1), cparams_lid, own) == 1 { return 1; };
        let args8: i64 = node_field(pool, nid, 3);
        let ac8: i64 = list_len(pool, args8);
        let mut i8: i64 = 0;
        while i8 < ac8 {
            if g6_closure_walk_capture(pool, list_get(pool, args8, i8), cparams_lid, own) == 1 { return 1; };
            i8 = i8 + 1;
        };
        return 0;
    };
    // Qualified call kind 12: args list at field 3.
    if kind == 12 {
        let args12: i64 = node_field(pool, nid, 3);
        let ac12: i64 = list_len(pool, args12);
        let mut i12: i64 = 0;
        while i12 < ac12 {
            if g6_closure_walk_capture(pool, list_get(pool, args12, i12), cparams_lid, own) == 1 { return 1; };
            i12 = i12 + 1;
        };
        return 0;
    };
    // Block kind 52 / stmts-list iteration via field 2.
    if kind == 52 {
        let stmts52: i64 = node_field(pool, nid, 2);
        let sc52: i64 = list_len(pool, stmts52);
        let mut s52: i64 = 0;
        while s52 < sc52 {
            if g6_closure_walk_capture(pool, list_get(pool, stmts52, s52), cparams_lid, own) == 1 { return 1; };
            s52 = s52 + 1;
        };
        return 0;
    };
    // Vec/array literals kind 47/48: items list at field 1.
    if kind == 47 || kind == 48 {
        let items47: i64 = node_field(pool, nid, 1);
        let ic47: i64 = list_len(pool, items47);
        let mut i47: i64 = 0;
        while i47 < ic47 {
            if g6_closure_walk_capture(pool, list_get(pool, items47, i47), cparams_lid, own) == 1 { return 1; };
            i47 = i47 + 1;
        };
        return 0;
    };
    // Conservative fallback: opaque shapes return 0 (no capture
    // detected). Phase 4 hard-fail is intentionally narrow — false
    // negatives stay silent rather than false-positive on shapes
    // the walker can't reason about (closure-of-closure, complex
    // match arms, etc.).
    return 0;
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
fn own_binding_move_type(tstr: str, pool: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    if is_copy_type(tstr, pool, structs, enums) == 0 { return 1; };
    let base: str = type_base_name(tstr);
    if str_eq(base, "String") { return 1; };
    return 0;
}

#[manual_drop]
fn expr_may_flow_change(pool: Vec<i32>, nid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 1 || kind == 2 || kind == 3 || kind == 71 || kind == 72 { return 0; };
    if kind == 4 {
        if expr_may_flow_change(pool, node_field(pool, nid, 2), own, structs, enums) == 1 { return 1; };
        if expr_may_flow_change(pool, node_field(pool, nid, 3), own, structs, enums) == 1 { return 1; };
        return 0;
    };
    if kind == 10 {
        if expr_may_flow_change(pool, node_field(pool, nid, 1), own, structs, enums) == 1 { return 1; };
        if expr_may_flow_change(pool, node_field(pool, nid, 2), own, structs, enums) == 1 { return 1; };
        return 0;
    };
    if kind == 5 || kind == 6 || kind == 9 || kind == 90 || kind == 91 || kind == 92 || kind == 99 {
        return expr_may_flow_change(pool, node_field(pool, nid, 1), own, structs, enums);
    };
    if kind == 7 || kind == 12 {
        let callee_name: str = if kind == 7 { node_field(pool, nid, 1) } else { str_concat(node_field(pool, nid, 1), str_concat("::", node_field(pool, nid, 2))) };
        if str_eq(callee_name, "vec_free") == 1 || str_eq(callee_name, "hashmap_free") == 1 || str_eq(callee_name, "str_free") == 1 { return 1; };
        let mut args: i64 = node_field(pool, nid, 2);
        if kind == 12 { args = node_field(pool, nid, 3); };
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                let atype: str = own_get_type(own, aname);
                if str_len(atype) > 0 && is_copy_type(atype, pool, structs, enums) == 0 { return 1; };
            };
            if expr_may_flow_change(pool, arg_nid, own, structs, enums) == 1 { return 1; };
            ai = ai + 1;
        };
        return 0;
    };
    if kind == 8 {
        let method_name: str = node_field(pool, nid, 2);
        if str_eq(method_name, "free") == 1 { return 1; };
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            if expr_may_flow_change(pool, list_get(pool, args, ai), own, structs, enums) == 1 { return 1; };
            ai = ai + 1;
        };
        return 0;
    };
    if kind == 34 {
        let inits: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, inits);
        let mut ii: i64 = 0;
        while ii < ic {
            let init_nid: i64 = list_get(pool, inits, ii);
            let val_nid: i64 = node_field(pool, init_nid, 2);
            if node_kind(pool, val_nid) == 3 {
                let vn: str = node_field(pool, val_nid, 1);
                let vt: str = own_get_type(own, vn);
                if own_binding_move_type(vt, pool, structs, enums) == 1 { return 1; };
            };
            if expr_may_flow_change(pool, val_nid, own, structs, enums) == 1 { return 1; };
            ii = ii + 1;
        };
        return 0;
    };
    if kind == 38 || kind == 42 { return 1; };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            if expr_may_flow_change(pool, list_get(pool, items, ii), own, structs, enums) == 1 { return 1; };
            ii = ii + 1;
        };
    };
    return 0;
}
#[manual_drop]
fn stmt_may_flow_change(pool: Vec<i32>, nid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 20 {
        let init: i64 = node_field(pool, nid, 4);
        if init >= 0 {
            if node_kind(pool, init) == 3 {
                let src: str = node_field(pool, init, 1);
                let st: str = own_get_type(own, src);
                if own_binding_move_type(st, pool, structs, enums) == 1 { return 1; };
            };
            return expr_may_flow_change(pool, init, own, structs, enums);
        };
        return 0;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        if node_kind(pool, lhs) == 3 {
            let lname: str = node_field(pool, lhs, 1);
            if own_get(own, lname) == 0 && own_get_i_raw(own, str_concat("__init_", lname)) == 0 && own_get_i_raw(own, str_concat("__init_seen_", lname)) == 1 { return 1; };
        };
        return expr_may_flow_change(pool, node_field(pool, nid, 2), own, structs, enums);
    };
    if kind == 22 || kind == 25 { return expr_may_flow_change(pool, node_field(pool, nid, 1), own, structs, enums); };
    if kind == 23 {
        if expr_may_flow_change(pool, node_field(pool, nid, 1), own, structs, enums) == 1 { return 1; };
        if stmt_list_may_flow_change(pool, node_field(pool, nid, 2), own, structs, enums) == 1 { return 1; };
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 && stmt_list_may_flow_change(pool, enode, own, structs, enums) == 1 { return 1; };
        return 0;
    };
    if kind == 24 {
        if expr_may_flow_change(pool, node_field(pool, nid, 1), own, structs, enums) == 1 { return 1; };
        return stmt_list_may_flow_change(pool, node_field(pool, nid, 2), own, structs, enums);
    };
    if kind == 28 { return stmt_list_may_flow_change(pool, node_field(pool, nid, 4), own, structs, enums); };
    if kind == 49 {
        if expr_may_flow_change(pool, node_field(pool, nid, 2), own, structs, enums) == 1 { return 1; };
        return stmt_list_may_flow_change(pool, node_field(pool, nid, 3), own, structs, enums);
    };
    if kind == 38 { return match_arms_need_flow_merge(pool, node_field(pool, nid, 2), own, structs, enums); };
    if kind == 52 { return stmt_list_may_flow_change(pool, node_field(pool, nid, 2), own, structs, enums); };
    return 0;
}
#[manual_drop]
fn stmt_list_may_flow_change(pool: Vec<i32>, lid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    while i < cnt {
        if stmt_may_flow_change(pool, list_get(pool, lid, i), own, structs, enums) == 1 { return 1; };
        i = i + 1;
    };
    return 0;
}
#[manual_drop]
fn match_arms_need_flow_merge(pool: Vec<i32>, arms: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    let ac: i64 = list_len(pool, arms);
    let mut ai: i64 = 0;
    while ai < ac {
        let arm_nid: i64 = list_get(pool, arms, ai);
        if stmt_list_may_flow_change(pool, node_field(pool, arm_nid, 4), own, structs, enums) == 1 { return 1; };
        ai = ai + 1;
    };
    return 0;
}
#[manual_drop]
fn own_apply_match_cond_inits(o: Vec<i32>, mark_start: i64) -> i64 {
    if own_get_i_raw(o, "__match_cond_init_count") <= mark_start { return 0; };
    let prefix: str = "__match_cond_init_";
    let plen: i64 = str_len(prefix);
    let mut i: i64 = 0;
    while i + 1 < vec_len(o) {
        let key: str = vec_get(o, i);
        if str_starts_with(key, prefix) == 1 {
            if vec_get(o, i + 1) == 1 {
                let bname: str = str_substring(key, plen, str_len(key));
                own_set_i_raw(o, str_concat("__init_", bname), 0);
                own_set_i_raw(o, key, 0);
            };
        };
        i = i + 2;
    };
    return 0;
}
#[manual_drop]
fn own_note_match_cond_init(o: Vec<i32>, name: str) -> i64 {
    if own_get(o, name) != 0 { return 0; };
    if own_get_i_raw(o, str_concat("__init_", name)) != 0 { return 0; };
    if own_get_i_raw(o, str_concat("__init_seen_", name)) != 1 { return 0; };
    let key: str = str_concat("__match_cond_init_", name);
    if own_get_i_raw(o, key) == 0 {
        own_set_i_raw(o, key, 1);
        own_set_i_raw(o, "__match_cond_init_count", own_get_i_raw(o, "__match_cond_init_count") + 1);
    };
    return 0;
}
#[manual_drop]
fn stmt_mark_match_init_candidates(pool: Vec<i32>, nid: i64, own: Vec<i32>) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        if node_kind(pool, lhs) == 3 { own_note_match_cond_init(own, node_field(pool, lhs, 1)); };
        return 0;
    };
    if kind == 23 {
        stmt_list_mark_match_init_candidates(pool, node_field(pool, nid, 2), own);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 { stmt_list_mark_match_init_candidates(pool, enode, own); };
        return 0;
    };
    if kind == 24 { return stmt_list_mark_match_init_candidates(pool, node_field(pool, nid, 2), own); };
    if kind == 28 { return stmt_list_mark_match_init_candidates(pool, node_field(pool, nid, 4), own); };
    if kind == 49 { return stmt_list_mark_match_init_candidates(pool, node_field(pool, nid, 3), own); };
    if kind == 52 { return stmt_list_mark_match_init_candidates(pool, node_field(pool, nid, 2), own); };
    if kind == 38 { return match_mark_match_init_candidates(pool, node_field(pool, nid, 2), own); };
    return 0;
}
#[manual_drop]
fn stmt_list_mark_match_init_candidates(pool: Vec<i32>, lid: i64, own: Vec<i32>) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    while i < cnt {
        stmt_mark_match_init_candidates(pool, list_get(pool, lid, i), own);
        i = i + 1;
    };
    return 0;
}
#[manual_drop]
fn match_mark_match_init_candidates(pool: Vec<i32>, arms: i64, own: Vec<i32>) -> i64 {
    let ac: i64 = list_len(pool, arms);
    let mut ai: i64 = 0;
    while ai < ac {
        stmt_list_mark_match_init_candidates(pool, node_field(pool, list_get(pool, arms, ai), 4), own);
        ai = ai + 1;
    };
    return 0;
}
#[manual_drop]
fn expr_mark_match_move_free(pool: Vec<i32>, nid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 7 || kind == 12 {
        let callee_name: str = if kind == 7 { node_field(pool, nid, 1) } else { str_concat(node_field(pool, nid, 1), str_concat("::", node_field(pool, nid, 2))) };
        let mut args: i64 = node_field(pool, nid, 2);
        if kind == 12 { args = node_field(pool, nid, 3); };
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                if str_eq(callee_name, "vec_free") == 1 || str_eq(callee_name, "hashmap_free") == 1 || str_eq(callee_name, "str_free") == 1 {
                    own_g4_mark_freed(own, aname, callee_name, 2);
                } else {
                    let atype: str = own_get_type(own, aname);
                    if str_len(atype) > 0 && is_copy_type(atype, pool, structs, enums) == 0 {
                        own_set_i_raw(own, str_concat("__g8_cond_moved_", aname), 1);
                        own_set_g8_flow_active(own);
                    };
                };
            };
            expr_mark_match_move_free(pool, arg_nid, own, structs, enums);
            ai = ai + 1;
        };
        return 0;
    };
    if kind == 4 {
        expr_mark_match_move_free(pool, node_field(pool, nid, 2), own, structs, enums);
        expr_mark_match_move_free(pool, node_field(pool, nid, 3), own, structs, enums);
        return 0;
    };
    if kind == 10 {
        expr_mark_match_move_free(pool, node_field(pool, nid, 1), own, structs, enums);
        expr_mark_match_move_free(pool, node_field(pool, nid, 2), own, structs, enums);
        return 0;
    };
    if kind == 5 || kind == 6 || kind == 9 || kind == 90 || kind == 91 || kind == 92 || kind == 99 {
        return expr_mark_match_move_free(pool, node_field(pool, nid, 1), own, structs, enums);
    };
    return 0;
}
#[manual_drop]
fn stmt_mark_match_move_free(pool: Vec<i32>, nid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    if kind == 20 { return expr_mark_match_move_free(pool, node_field(pool, nid, 4), own, structs, enums); };
    if kind == 21 { return expr_mark_match_move_free(pool, node_field(pool, nid, 2), own, structs, enums); };
    if kind == 22 || kind == 25 { return expr_mark_match_move_free(pool, node_field(pool, nid, 1), own, structs, enums); };
    if kind == 23 {
        stmt_list_mark_match_move_free(pool, node_field(pool, nid, 2), own, structs, enums);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 { stmt_list_mark_match_move_free(pool, enode, own, structs, enums); };
        return 0;
    };
    if kind == 24 { return stmt_list_mark_match_move_free(pool, node_field(pool, nid, 2), own, structs, enums); };
    if kind == 28 { return stmt_list_mark_match_move_free(pool, node_field(pool, nid, 4), own, structs, enums); };
    if kind == 49 { return stmt_list_mark_match_move_free(pool, node_field(pool, nid, 3), own, structs, enums); };
    if kind == 52 { return stmt_list_mark_match_move_free(pool, node_field(pool, nid, 2), own, structs, enums); };
    if kind == 38 { return match_mark_match_move_free(pool, node_field(pool, nid, 2), own, structs, enums); };
    return 0;
}
#[manual_drop]
fn stmt_list_mark_match_move_free(pool: Vec<i32>, lid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0;
    while i < cnt {
        stmt_mark_match_move_free(pool, list_get(pool, lid, i), own, structs, enums);
        i = i + 1;
    };
    return 0;
}
#[manual_drop]
fn match_mark_match_move_free(pool: Vec<i32>, arms: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>) -> i64 {
    let ac: i64 = list_len(pool, arms);
    let mut ai: i64 = 0;
    while ai < ac {
        stmt_list_mark_match_move_free(pool, node_field(pool, list_get(pool, arms, ai), 4), own, structs, enums);
        ai = ai + 1;
    };
    return 0;
}

#[manual_drop]
fn check_expr(pool: Vec<i32>, nid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, fn_name: str) -> i64 {
    if nid < 0 { return 0; };
    if nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    if kind == 1 || kind == 2 || kind == 71 || kind == 72 { return 0; }; // literals
    if kind == 3 {
        // IDENT — check for use-after-move, use-after-drop,
        // conditional-move, and read-before-init.
        let vname: str = node_field(pool, nid, 1);
        // RFC-0062 G-11 Phase 2b/3/4 — definite-assignment flow.
        // The init flag is 1 iff the binding has been definitely
        // assigned on every incoming path (initializer at decl,
        // subsequent assignment, or both arms of a join). 0 means
        // declared without initializer and either never assigned or
        // assigned on only some incoming paths. Reading the slot in
        // that state is an MS-7 hazard (alloca's zero-init slot is
        // returned silently). Emit INIT-G11-READ-BEFORE-INIT at
        // error severity. The flag is per-name on the `own` env, so
        // shadowing and scope exits behave like the rest of the
        // tracker. Skip the check for `_` placeholder reads and
        // self-method receivers (which the parser reroutes through
        // a different binding name).
        if vec_len(vec_get(own, 13)) > 0 && str_len(vname) > 0 && str_eq(vname, "_") == 0 {
            // own_get_i_raw returns 0 for keys that never existed.
            // Only fire when the key was explicitly set to 0 by the
            // let-no-init or never-assigned path; we distinguish
            // "key absent" from "key=0" by checking that the
            // binding type is registered in the env (which means
            // check_stmt kind-20 ran for it).
            let g11_init: i64 = own_get_i_raw(own, str_concat("__init_", vname));
            if g11_init == 0 {
                let g11_typ: str = own_get_type(own, vname);
                if str_len(g11_typ) > 0 {
                    // The binding is known to the env (declared
                    // somewhere). Init flag 0 means at least one
                    // incoming path didn't assign. own_get returns
                    // 1 (live) for declared bindings; if the flag
                    // is 0, that distinguishes uninit from already-
                    // moved (state=2 path below).
                    let g11_state: i64 = own_get(own, vname);
                    if g11_state != 2 {
                        // Confirm the binding was actually declared
                        // without init by checking that the let-
                        // decl path set the init flag explicitly.
                        // Bindings declared by parameters / loop
                        // vars / etc. don't go through the DA
                        // path so their init key is absent (raw
                        // returns 0). Differentiate by checking
                        // own_get_param: parameters skip DA.
                        if own_get_param(own, vname) == 0 {
                            // Final guard: only fire if a let-decl
                            // explicitly set the init key. Use a
                            // sentinel `__init_seen_<vname>` marker
                            // that check_stmt kind-20 sets on
                            // every let-decl.
                            if own_get_i_raw(own, str_concat("__init_seen_", vname)) == 1 {
                                let g11_msg_a: str = str_concat("read of '", str_concat(vname, "' before it is definitely assigned. The binding was declared without an initializer (`let mut "));
                                let g11_msg_b: str = str_concat(vname, ": T;`) and either no assignment dominates this read, or only some incoming control-flow arms assigned it. Either initialize at the declaration point (`let mut ");
                                let g11_msg_c: str = str_concat(vname, ": T = ...;`) or ensure every incoming control-flow path assigns the binding before this read.");
                                warns = warns + own_diag(own, fn_name, "INIT-G11-READ-BEFORE-INIT", str_concat(g11_msg_a, str_concat(g11_msg_b, g11_msg_c)), vname);
                                return warns;
                            };
                        };
                    };
                };
            };
        };
        // RFC-0062 G-4 Phase 2b/3/4 — IR-level use-after-drop check.
        // `Vec<T>` / `HashMap<K,V>` / `String` etc. are treated as
        // Copy by the move-state tracker (i64-everywhere ABI: the
        // binding is just an i64 handle). That means
        // `vec_free(v); v.push(7);` slips past OWN-001 today. The
        // freed flag below is set at the manual-free call site
        // (kind-7 dispatch further down); reading the slot after
        // the free emits OWN-G4-USE-AFTER-DROP at error severity.
        if vec_get(own, 15) == 1 {
            let g4_state_v: i64 = own_get_i_raw(own, str_concat("__g4_freed_", vname));
            if g4_state_v == 1 {
                let freed_by: str = own_get_s_raw(own, str_concat("__g4_freed_by_", vname));
                let mut g4_msg: str = str_concat("use of '", str_concat(vname, "' after manual free"));
                if str_len(freed_by) > 0 {
                    // Lane 3 (F-DIAG-009): the pre-fix call was
                    // `str_concat(freed_by, "(", str_concat(vname, ...))`
                    // which has THREE positional args to str_concat
                    // (which only takes 2). The third positional was
                    // silently dropped, truncating the message at
                    // "reading the binding after `". Now the post-tilde
                    // tail is built up via nested 2-arg concats so the
                    // full sentence renders.
                    let g4_freed_call: str = str_concat(freed_by, str_concat("(", str_concat(vname, ")")));
                    let g4_tail: str = str_concat(g4_freed_call, "` is undefined. Either drop the post-free use, or rely on `#[auto_drop]` (RFC-0042) for automatic cleanup at scope exit.");
                    g4_msg = str_concat(g4_msg, str_concat(" (freed by '", str_concat(freed_by, str_concat("'). The heap allocation is gone; reading the binding after `", g4_tail))));
                };
                warns = warns + own_diag(own, fn_name, "OWN-G4-USE-AFTER-DROP", g4_msg, vname);
                return warns;
            };
            if g4_state_v == 2 {
                let cfreed_by: str = own_get_s_raw(own, str_concat("__g4_freed_by_", vname));
                let mut g4c_msg: str = str_concat("conditional manual free of '", str_concat(vname, "': value is freed on one incoming control-flow path but preserved on another. Subsequent reads are unsound because the binding may point at freed storage depending on which path ran."));
                if str_len(cfreed_by) > 0 {
                    g4c_msg = str_concat(g4c_msg, str_concat(" One path freed it by '", str_concat(cfreed_by, "'.")));
                };
                warns = warns + own_diag(own, fn_name, "OWN-G4-USE-AFTER-DROP", g4c_msg, vname);
                return warns;
            };
        };
        // RFC-0062 G-8 Phase 2b/3/4 — conditional-divergence move
        // detection. The cond-moved flag is set by `own_merge_moved`
        // when a binding is moved on one arm of an if/else but not
        // the other; subsequent reads on the post-join path are
        // ambiguous (the binding may or may not still own its
        // value, depending on which arm ran). Emit OWN-G8-COND-MOVE
        // at error severity. Checked before the existing OWN-001
        // path so the precise diagnostic fires instead of the more
        // general "use of moved" classification.
        if vec_get(own, 17) == 1 && own_get_i_raw(own, str_concat("__g8_cond_moved_", vname)) == 1 {
            warns = warns + own_diag(own, fn_name, "OWN-G8-COND-MOVE", str_concat("conditional move of '", str_concat(vname, "': value is moved on one arm of the preceding if/else but not the other. Subsequent reads are unsound because the binding may no longer own its value depending on which arm ran. Either move on every arm (so the value is definitely consumed) or move on no arm (so the value is preserved on every path).")), vname);
            return warns;
        };
        let state: i64 = own_get(own, vname);
        if state == 2 {
            let source_text_move: str = own_source(own);
            let diag_vec_move: Vec<i32> = own_diags(own);
            let move_sp: i64 = node_get_span(pool, nid);
            let mut ln: i64 = 0;
            let mut col: i64 = 0;
            if move_sp >= 0 {
                let lm_om: Vec<i32> = linemap_build(source_text_move);
                ln = linemap_line(lm_om, move_sp);
                col = linemap_col(lm_om, move_sp);
            } else {
                ln = find_in_source(source_text_move, fn_name, vname);
                col = find_column_in_source(source_text_move, fn_name, vname);
            };
            // Lane 3 (F-DIAG-003): OWN-001 was emitted at "warning" severity,
            // which combined with the regex-only negative-test gate let
            // use-after-move ship a binary at RC=0 past every layer of
            let d_idx: i64 = diag_add_ex(diag_vec_move, "error", "ownership", "OWN-001", str_concat("use of moved variable '", str_concat(vname, "'")), fn_name, ln, col, "");
            // Add child note: where was it moved?
            let moved_by: str = own_get_type(own, str_concat("__moved_by_", vname));
            if str_len(moved_by) > 0 {
                let d: Vec<i32> = diag_get(diag_vec_move, d_idx - 1);
                let move_line: i64 = find_in_source(source_text_move, fn_name, moved_by);
                vec_set(d, 10, str_concat("'", str_concat(vname, str_concat("' was moved here by call to '", str_concat(moved_by, "'")))));
                vec_set(d, 11, move_line);
            };
            return 1;
        };
        return 0;
    };
    if kind == 4 {
        warns = warns + check_expr(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        warns = warns + check_expr(pool, node_field(pool, nid, 3), own, structs, enums, fn_name);
        return warns;
    };
    // Field/index access
    // (kind 5 / kind 6) on a binding that was conditionally moved
    // or manually freed must still fire the per-binding diagnostics.
    // Pre-fix the recursion descended into the receiver but the
    // receiver-name's freed/cond-moved flags were only consulted in
    // the bare-IDENT (kind 3) path. Real adopter code uses field/
    // index access far more than bare IDENT reads, so the published
    // gate covered a degenerate case.
    if kind == 5 || kind == 6 {
        let recv_root: str = expr_root_name(pool, node_field(pool, nid, 1), own);
        if str_len(recv_root) > 0 {
            if vec_get(own, 15) == 1 {
                let g4_state_recv: i64 = own_get_i_raw(own, str_concat("__g4_freed_", recv_root));
                if g4_state_recv == 1 {
                    let g4f_by: str = own_get_s_raw(own, str_concat("__g4_freed_by_", recv_root));
                    let mut g4f_msg: str = str_concat("use of '", str_concat(recv_root, "' after manual free"));
                    if str_len(g4f_by) > 0 {
                        g4f_msg = str_concat(g4f_msg, str_concat(" (freed by '", str_concat(g4f_by, "'). The heap allocation is gone; field/index access after `*_free` is undefined. Either drop the post-free use, or rely on `#[auto_drop]` (RFC-0042) for automatic cleanup at scope exit.")));
                    };
                    warns = warns + own_diag(own, fn_name, "OWN-G4-USE-AFTER-DROP", g4f_msg, recv_root);
                    return warns;
                };
                if g4_state_recv == 2 {
                    let g4cf_by: str = own_get_s_raw(own, str_concat("__g4_freed_by_", recv_root));
                    let mut g4cf_msg: str = str_concat("conditional manual free of '", str_concat(recv_root, "': value is freed on one incoming control-flow path but preserved on another. Subsequent field/index access is unsound because the binding may point at freed storage depending on which path ran."));
                    if str_len(g4cf_by) > 0 {
                        g4cf_msg = str_concat(g4cf_msg, str_concat(" One path freed it by '", str_concat(g4cf_by, "'.")));
                    };
                    warns = warns + own_diag(own, fn_name, "OWN-G4-USE-AFTER-DROP", g4cf_msg, recv_root);
                    return warns;
                };
            };
            if vec_get(own, 17) == 1 && own_get_i_raw(own, str_concat("__g8_cond_moved_", recv_root)) == 1 {
                warns = warns + own_diag(own, fn_name, "OWN-G8-COND-MOVE", str_concat("conditional move of '", str_concat(recv_root, "': value is moved on one arm of the preceding if/else but not the other. Subsequent reads (including field/index access) are unsound because the binding may no longer own its value depending on which arm ran. Either move on every arm (so the value is definitely consumed) or move on no arm (so the value is preserved on every path).")), recv_root);
                return warns;
            };
        };
        return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
    };
    if kind == 90 || kind == 91 || kind == 92 { return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name); };
    if kind == 7 {
        // CALL — check args, move Move-type idents
        let callee_name: str = node_field(pool, nid, 1);
        let args: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, args);
        // RFC-0062 G-6 Phase 3 — Sendable per-call-site classification.
        // At spawn-family call sites (`thread_spawn` / `async_spawn` /
        // `conc_spawn`), classify the offending arg shape into
        // SEND-G6-HASHMAP / SEND-G6-CLOSURE-CAPTURE / SEND-G6-TUPLE /
        // SEND-G6-ENUM. The existing RACE-001 textual pre-pass
        // (`enforce_sendable_spawn_name`) continues to fire for plain
        // non-Sendable struct args and `&mut` thread-cross; this
        // analysis adds shape-specific error codes at the per-call
        // expression site so reviewers see *why* the spawn is unsound.
        // Codes are registered in `is_error_code` and fire at error
        // severity (Phase 4 lock-in).
        let g6_is_spawn: i64 = if str_eq(callee_name, "thread_spawn") == 1 || str_eq(callee_name, "async_spawn") == 1 || str_eq(callee_name, "conc_spawn") == 1 { 1 } else { 0 };
        if g6_is_spawn == 1 {
            let mut g6_ai: i64 = 0;
            while g6_ai < ac {
                let g6_arg: i64 = list_get(pool, args, g6_ai);
                let g6_kind: i64 = node_kind(pool, g6_arg);
                if g6_kind == 42 {
                    // Only fire when the closure captures at least
                    // one local from the enclosing fn scope. A bare
                    // closure that references only its parameters
                    // (e.g. `|x| x * 2` in tests/runtime/concurrency.nr)
                    // is Sendable by construction and must not regress.
                    let g6_cparams: i64 = node_field(pool, g6_arg, 1);
                    let g6_body: i64 = node_field(pool, g6_arg, 2);
                    let g6_body_kind: i64 = node_kind(pool, g6_body);
                    let mut g6_captured: i64 = 0;
                    if g6_body_kind == 40 {
                        // body field is itself a list (parse_primary
                        // line ~2570 wraps single-expr bodies in
                        // mk_list of one return-stmt). Walk each.
                        let g6_bcnt: i64 = list_len(pool, g6_body);
                        let mut g6_bi: i64 = 0;
                        while g6_bi < g6_bcnt && g6_captured == 0 {
                            let g6_bstmt: i64 = list_get(pool, g6_body, g6_bi);
                            if g6_closure_walk_capture(pool, g6_bstmt, g6_cparams, own) == 1 {
                                g6_captured = 1;
                            };
                            g6_bi = g6_bi + 1;
                        };
                    } else {
                        if g6_closure_walk_capture(pool, g6_body, g6_cparams, own) == 1 {
                            g6_captured = 1;
                        };
                    };
                    if g6_captured == 1 {
                        warns = warns + own_diag(own, fn_name, "SEND-G6-CLOSURE-CAPTURE", str_concat("closure literal passed to spawn-family call `", str_concat(callee_name, "` captures at least one binding from the enclosing scope. Per RFC-0062 G-6 Phase 3 (v1.0): Rust-style closures are Sendable iff every captured variable is Sendable, and the per-closure capture-set audit is post-v1.0 hardening — closures with non-empty captures crossing thread boundaries cannot be proven Sendable today. Restructure the spawn argument as a named fn pointer with explicit Sendable args, or use a closure that references only its parameters.")), callee_name);
                    };
                };
                if g6_kind == 3 {
                    let g6_aname: str = node_field(pool, g6_arg, 1);
                    let g6_atype_raw: str = own_get_type(own, g6_aname);
                    // Strip leading `&` / `&mut ` from ref args so the
                    // shape detection sees the underlying container.
                    let mut g6_atype: str = g6_atype_raw;
                    if str_starts_with(g6_atype, "&mut ") == 1 { g6_atype = str_trim(str_substring(g6_atype, 5, str_len(g6_atype))); }
                    else if str_starts_with(g6_atype, "&") == 1 { g6_atype = str_trim(str_substring(g6_atype, 1, str_len(g6_atype))); };
                    if str_len(g6_atype) > 0 {
                        let g6_direct_nonsend: i64 = if str_index_of(g6_atype, "HashMap<") >= 0 || str_index_of(g6_atype, "RefCell<") >= 0 || str_index_of(g6_atype, "Cell<") >= 0 { 1 } else { 0 };
                        let g6_has_nonsend: i64 = g6_type_has_nonsendable(pool, structs, enums, g6_atype, 0);
                        let g6_is_tuple: i64 = if str_starts_with(g6_atype, "(") == 1 { 1 } else { 0 };
                        let g6_base: str = type_base_name(g6_atype);
                        let g6_eidx: i64 = enum_find(pool, enums, g6_base);
                        if g6_is_tuple == 1 && g6_has_nonsend == 1 {
                            warns = warns + own_diag(own, fn_name, "SEND-G6-TUPLE", str_concat("tuple type `", str_concat(g6_atype, str_concat("` of binding `", str_concat(g6_aname, "` crosses a thread boundary at this spawn-family call with at least one non-Sendable element (HashMap / Cell / RefCell). Per RFC-0062 G-6 Phase 3 (v1.0): a tuple is Sendable iff every element type is Sendable. Reshape the spawn payload to a tuple of Sendable elements only (primitives, Vec<Sendable>, struct with `impl Sendable`).")))), g6_aname);
                        } else if g6_direct_nonsend == 1 {
                            warns = warns + own_diag(own, fn_name, "SEND-G6-HASHMAP", str_concat("non-Sendable container type `", str_concat(g6_atype, str_concat("` of binding `", str_concat(g6_aname, "` crosses a thread boundary at this spawn-family call. Per RFC-0062 G-6 Phase 3 (v1.0): HashMap<K,V> is Sendable iff K, V, and the hasher are Sendable (today's HashMap is unaudited and must be treated as non-Sendable across spawn). Cell<T> / RefCell<T> are explicit REJECTS for Sendable (interior mutability incompatible with cross-thread). Restructure the spawn argument as a Sendable handle (Vec<i64>, primitives, structs with `impl Sendable`).")))), g6_aname);
                        } else if g6_eidx >= 0 && g6_has_nonsend == 1 {
                            warns = warns + own_diag(own, fn_name, "SEND-G6-ENUM", str_concat("enum type `", str_concat(g6_base, str_concat("` of binding `", str_concat(g6_aname, "` crosses a thread boundary at this spawn-family call with at least one non-Sendable variant payload (HashMap / Cell / RefCell). Per RFC-0062 G-6 Phase 3 (v1.0): an enum is Sendable iff every variant's payload types are Sendable. Either restructure the offending variant's payload to Sendable types or pass an i64 handle instead of the enum at the spawn boundary.")))), g6_aname);
                        } else if g6_has_nonsend == 1 {
                            warns = warns + own_diag(own, fn_name, "SEND-G6-HASHMAP", str_concat("non-Sendable struct type `", str_concat(g6_atype, str_concat("` of binding `", str_concat(g6_aname, "` crosses a thread boundary at this spawn-family call because at least one transitive field contains HashMap / Cell / RefCell. Per RFC-0062 G-6 Phase 3 (v1.0): a struct is Sendable iff every field is Sendable. Reshape the spawn payload to contain only Sendable fields or pass an explicit handle with audited synchronization.")))), g6_aname);
                        } else {
                        };
                    };
                };
                g6_ai = g6_ai + 1;
            };
        };
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            warns = warns + check_expr(pool, arg_nid, own, structs, enums, fn_name);
            if node_kind(pool, arg_nid) == 90 || node_kind(pool, arg_nid) == 91 {
                warns = warns + own_register_borrow_expr(pool, arg_nid, own, fn_name, "", 0, 0);
                let key: str = expr_borrow_key(pool, node_field(pool, arg_nid, 1), own);
                if node_kind(pool, arg_nid) == 90 { own_dec_shared(own, key); }
                else { own_set_mut_borrow(own, key, 0); };
            };
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                let atype: str = own_get_type(own, aname);
                if type_is_mut_ref(atype) == 1 {
                    ai = ai + 1;
                    continue;
                };
                if str_eq(callee_name, "arena_destroy") == 1 {
                    let arena_key: str = str_concat("@arena:", aname);
                    if own_has_shared_overlap(own, arena_key) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-012", str_concat("cannot destroy arena '", str_concat(aname, "': live arena references still exist")), aname);
                    };
                };
                // RFC-0062 G-3 Phase 3 — heap-aliasing per-fn analysis.
                // ALIAS-G3-VEC-OF-REFS: Vec mutators into a
                // binding declared as Vec<&T> (or Vec<&mut T>) hides
                // aliasing from the syntactic borrow tracker — the
                // tracker doesn't follow elements through Vec<&...>,
                // so two pushes can leave aliased &T pointing at the
                // same T. Fire at the call site with the binding name.
                if str_eq(callee_name, "vec_push") == 1
                    || str_eq(callee_name, "vec_insert") == 1
                    || str_eq(callee_name, "vec_insert_at") == 1
                    || str_eq(callee_name, "vec_extend") == 1
                    || str_eq(callee_name, "vec_set") == 1 {
                    if ai == 0 && str_index_of(atype, "Vec<&") >= 0 {
                        warns = warns + own_diag(own, fn_name, "ALIAS-G3-VEC-OF-REFS", str_concat("`", str_concat(callee_name, str_concat("` into binding `", str_concat(aname, str_concat("` of type `", str_concat(atype, "` installs a borrow into a Vec-of-references. Per RFC-0062 G-3 Phase 3 (v1.0): the syntactic borrow tracker does not follow elements through `Vec<&T>`, so two pushes of borrows aliasing the same `T` are invisible. Prefer indexing — store `Vec<i64>` indexes into an owned vector instead of `Vec<&T>` borrows of separate vectors.")))))), aname);
                    };
                };
                // ALIAS-G3-HASHMAP-REHASH: hashmap_insert / hashmap_remove
                // / hashmap_clear / hashmap_free while a live shared
                // borrow of the same map binding exists. Mutations rehash
                // or invalidate held references.
                // Include `hashmap_free`
                // in the borrow-invalidation guard set. Strictly
                // worse than rehash — free DEFINITELY invalidates
                // every live borrow into the map. Same hazard for
                // `vec_free` against a `Vec<&T>` and `str_free`
                // against a substring borrow.
                if str_eq(callee_name, "hashmap_insert") == 1 || str_eq(callee_name, "hashmap_remove") == 1 || str_eq(callee_name, "hashmap_clear") == 1 || str_eq(callee_name, "hashmap_free") == 1 || str_eq(callee_name, "vec_free") == 1 || str_eq(callee_name, "str_free") == 1 {
                    if ai == 0 && own_has_shared_overlap(own, aname) == 1 {
                        warns = warns + own_diag(own, fn_name, "ALIAS-G3-HASHMAP-REHASH", str_concat("`", str_concat(callee_name, str_concat("` on binding `", str_concat(aname, "` while a live shared borrow of the same collection exists. Per RFC-0062 G-3 Phase 3 (v1.0): mutating or freeing a collection while a borrow into it is alive invalidates the borrow. `*_free` definitely invalidates every outstanding borrow; `hashmap_insert`/`remove`/`clear` may rehash storage. Either drop the borrow before mutating/freeing, or restructure to compute the mutation key/value before taking the borrow.")))), aname);
                    };
                };
                // RFC-0062 G-4 Phase 2b/3/4 — mark the arg's slot
                // freed so subsequent reads emit OWN-G4-USE-AFTER-DROP.
                // `Vec` / `HashMap` / `String` are Copy at the
                // move-state tracker (line ~19431), so this manual
                // tracking is independent of OWN-001's state == 2.
                // Double-free (`vec_free(v); vec_free(v);`) is also
                // caught: the second call's check_expr arg-walk hits
                // the freed flag in the kind-3 path above and fires
                // OWN-G4-USE-AFTER-DROP before this set runs again.
                if str_eq(callee_name, "vec_free") == 1 || str_eq(callee_name, "hashmap_free") == 1 || str_eq(callee_name, "str_free") == 1 {
                    own_g4_mark_freed(own, aname, callee_name, 1);
                };
                if is_copy_type(atype, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, aname) == 1 || own_has_mut_overlap(own, aname) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(aname, "': value is borrowed")), aname);
                    } else {
                        // suppress the move
                        // mark when the callee's idx-th param is `&T` / `&mut T`.
                        // OWN-001's move-on-call is correct for by-value params
                        // but mis-fires on by-reference accessors (the rod
                        // surface uses `&Schedule` / `&LogicalQubit` etc.). The
                        // callee sig is the source of truth; consult it.
                            let arg_src: str = own_source(own);
                            if str_len(arg_src) > 0 && fn_callee_param_is_borrow(arg_src, callee_name, ai) == 1 {
                            // borrow — no move
                        } else {
                            own_set(own, aname, 2); own_set_type(own, str_concat("__moved_by_", aname), callee_name);
                        };
                    };
                };
            };
            ai = ai + 1;
        };
        return warns;
    };
    if kind == 8 {
        // METHOD — check receiver (don't move it) and args
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        let method_name: str = node_field(pool, nid, 2);
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        // Method-form free
        // (`v.free()` / `m.free()` / `s.free()`) must mark the
        // receiver's slot as freed, mirroring the kind-7 free-fn
        // detection. Without this, if the rod stdlib ever exposes
        // `Vec::free()` / `HashMap::free()` as a method, G-4
        // collapses to no-op for the method form.
        if str_eq(method_name, "free") == 1 {
            let recv_root_f: str = expr_root_name(pool, node_field(pool, nid, 1), own);
            if str_len(recv_root_f) > 0 {
                let rt_f: str = own_get_type(own, recv_root_f);
                // Only stamp on heap-collection types; plain i64 etc.
                // shouldn't trigger the G-4 pattern.
                if str_starts_with(rt_f, "Vec") == 1 || str_starts_with(rt_f, "HashMap") == 1 || str_eq(rt_f, "str") == 1 || str_eq(rt_f, "String") == 1 {
                    own_g4_mark_freed(own, recv_root_f, str_concat(method_name, "() method"), 1);
                };
            };
        };
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            warns = warns + check_expr(pool, arg_nid, own, structs, enums, fn_name);
            if node_kind(pool, arg_nid) == 90 || node_kind(pool, arg_nid) == 91 {
                warns = warns + own_register_borrow_expr(pool, arg_nid, own, fn_name, "", 0, 0);
                let key: str = expr_borrow_key(pool, node_field(pool, arg_nid, 1), own);
                if node_kind(pool, arg_nid) == 90 { own_dec_shared(own, key); }
                else { own_set_mut_borrow(own, key, 0); };
            };
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                let atype: str = own_get_type(own, aname);
                if type_is_mut_ref(atype) == 1 {
                    ai = ai + 1;
                    continue;
                };
                if is_copy_type(atype, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, aname) == 1 || own_has_mut_overlap(own, aname) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(aname, "': value is borrowed")), aname);
                    } else {
                        own_set(own, aname, 2); own_set_type(own, str_concat("__moved_by_", aname), method_name);
                    };
                };
            };
            ai = ai + 1;
        };
        return warns;
    };
    if kind == 9 { return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name); };
    // RFC-0062 G-4/G-8/G-11 Lane 2 fix: cast wrapper (`expr as T`,
    // AST kind 99 from parse_unary line ~2808) must walk the operand
    // so use-after-drop / cond-move / read-before-init checks fire
    // when the unsafe read is wrapped in a cast. Pre-fix:
    //   vec_free(v); let n: i32 = vec_get(v, 0) as i32;     // CLEAN
    //   if cond { x = 7; }; return x as i32;                // CLEAN
    // Audit reproducers in audit_scratch_memsafe/G4 / G11.
    if kind == 99 { return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name); };
    if kind == 10 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        warns = warns + check_expr(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        return warns;
    };
    if kind == 47 || kind == 48 {
        let items: i64 = node_field(pool, nid, 1);
        let ic: i64 = list_len(pool, items);
        let mut ii: i64 = 0;
        while ii < ic {
            warns = warns + check_expr(pool, list_get(pool, items, ii), own, structs, enums, fn_name);
            ii = ii + 1;
        };
        return warns;
    };
    if kind == 12 {
        let qual_name: str = str_concat(node_field(pool, nid, 1), str_concat("::", node_field(pool, nid, 2)));
        let args: i64 = node_field(pool, nid, 3);
        let ac: i64 = list_len(pool, args);
        let mut ai: i64 = 0;
        while ai < ac {
            let arg_nid: i64 = list_get(pool, args, ai);
            warns = warns + check_expr(pool, arg_nid, own, structs, enums, fn_name);
            if node_kind(pool, arg_nid) == 90 || node_kind(pool, arg_nid) == 91 {
                warns = warns + own_register_borrow_expr(pool, arg_nid, own, fn_name, "", 0, 0);
                let key: str = expr_borrow_key(pool, node_field(pool, arg_nid, 1), own);
                if node_kind(pool, arg_nid) == 90 { own_dec_shared(own, key); }
                else { own_set_mut_borrow(own, key, 0); };
            };
            if node_kind(pool, arg_nid) == 3 {
                let aname: str = node_field(pool, arg_nid, 1);
                let atype: str = own_get_type(own, aname);
                if type_is_mut_ref(atype) == 1 {
                    ai = ai + 1;
                    continue;
                };
                if is_copy_type(atype, pool, structs, enums) == 0 {
                    if own_has_shared_overlap(own, aname) == 1 || own_has_mut_overlap(own, aname) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(aname, "': value is borrowed")), aname);
                    } else {
                        own_set(own, aname, 2); own_set_type(own, str_concat("__moved_by_", aname), qual_name);
                    };
                };
            };
            ai = ai + 1;
        };
        return warns;
    };
    if kind == 34 {
        // STRUCT_INIT — check field init exprs
        let source_text: str = own_source(own);
        let diag_vec: Vec<i32> = own_diags(own);
        let inits: i64 = node_field(pool, nid, 2);
        let ic: i64 = list_len(pool, inits);
        let mut ii: i64 = 0;
        while ii < ic {
            let init_nid: i64 = list_get(pool, inits, ii);
            let val_nid: i64 = node_field(pool, init_nid, 2);
            warns = warns + check_expr(pool, val_nid, own, structs, enums, fn_name);
            if node_kind(pool, val_nid) == 3 {
                let vn: str = node_field(pool, val_nid, 1);
                let vt: str = own_get_type(own, vn);
                if own_binding_move_type(vt, pool, structs, enums) == 1 { own_set(own, vn, 2); };
            };
            ii = ii + 1;
        };
        // NUC-FEEDBACK silent-default-zero close. Pre-fix
        // `Point { x: 1, y: 2 }` for a struct with 3 fields silently
        // defaulted the missing field to 0 (or ""). Adopters writing
        // the canonical Rust idiom (which errors with E0063 — missing
        // field) got a quiet wrong value. Emit TYP-012 listing the
        // missing field count when ic < struct's declared field count.
        let struct_name: str = node_field(pool, nid, 1);
        // Handle encapsulation:
        // forbid struct-literal construction of types annotated
        // `#[opaque_handle]` in their declaration. Only the
        // declaring rod's constructor fns can build the opaque
        // type — all other call sites must use the public
        // accessor fns (e.g. `atomic_i64(initial)` instead of
        // `AtomicI64 { handle: 12345 }`). Without this gate, any
        // adopter could fabricate a fake handle, pass it to the
        // load/store helpers, and crash the process via SEGV /
        // UAF. The gate is textual: the source must contain the
        // attribute pattern within ~6 lines preceding the struct
        // declaration. The list of opaque types is closed and
        // enforced by checking the canonical names below; this
        // doesn't require the struct AST to carry attribute
        // metadata. For finer-grained per-rod enforcement (e.g.
        // permitting struct literals inside the rod that defines
        // the type), see Phase B (post-v1.0).
        let g_handle_is_opaque: i64 = if str_eq(struct_name, "AtomicI64") == 1 || str_eq(struct_name, "AtomicU64") == 1 || str_eq(struct_name, "AtomicI32") == 1 || str_eq(struct_name, "AtomicU32") == 1 || str_eq(struct_name, "AtomicBool") == 1 { 1 } else { 0 };
        if g_handle_is_opaque == 1 {
            // The closed list of constructor / CAS-shim fn names
            // INSIDE the atomic rod that may construct the
            // opaque type via struct literal. All other call
            // sites (whether in atomic.nr itself or in adopter
            // code) must use the public constructor fn.
            // Detection is by exact fn name — this is robust
            // against import textual-merge edge cases that the
            // pre-fix "is the source the defining rod?" heuristic
            // got wrong (the import causes adopter source to also
            // contain the struct decl).
            let mut g_in_ctor: i64 = 0;
            if str_eq(fn_name, "atomic_i64") == 1 { g_in_ctor = 1; };
            if str_eq(fn_name, "atomic_u64") == 1 { g_in_ctor = 1; };
            if str_eq(fn_name, "atomic_i32") == 1 { g_in_ctor = 1; };
            if str_eq(fn_name, "atomic_u32") == 1 { g_in_ctor = 1; };
            if str_eq(fn_name, "atomic_bool") == 1 { g_in_ctor = 1; };
            if str_starts_with(fn_name, "atomic_compare_exchange") == 1 { g_in_ctor = 1; };
            if g_in_ctor == 0 {
                let g_h_msg: str = str_concat("forbidden struct-literal construction of opaque concurrency-handle type `", str_concat(struct_name, "`. Per RFC-0062 G-handle (Lane 2 audit fix F-CONC-001 v1.0): handles for AtomicI64 / AtomicU64 / AtomicI32 / AtomicU32 / AtomicBool are opaque — adopter code MUST use the public constructor fns (`atomic_i64(initial)`, `atomic_u64(initial)`, etc.) which return a properly initialized handle backed by a runtime allocation. Replace with `let a: AtomicI64 = atomic_i64(initial_value);`."));
                let g_h_diag_vec: Vec<i32> = own_diags(own);
                let g_h_source: str = own_source(own);
                diag_add_at_or_scan(g_h_diag_vec, g_h_source, pool, nid, struct_name, "error", "concurrency", "CONC-G6-OPAQUE-HANDLE", g_h_msg, fn_name, "");
                warns = warns + 1;
            };
        };
        let s_idx: i64 = struct_find_type(pool, structs, struct_name);
        if s_idx >= 0 {
            let s_nid: i64 = vec_get(structs, s_idx);
            let s_flist: i64 = node_field(pool, s_nid, 2);
            let expected_fc: i64 = list_len(pool, s_flist);
            if ic < expected_fc {
                let part_a: str = str_concat("missing field(s) in `", str_concat(struct_name, "` initialization: only "));
                let part_b: str = str_concat(str_from_int(ic), str_concat(" of ", str_concat(str_from_int(expected_fc), " fields supplied.")));
                let part_c: str = " List every field explicitly or use a constructor fn.";
                diag_add_at_or_scan(diag_vec, source_text, pool, nid, struct_name, "error", "type", "TYP-012", str_concat(part_a, str_concat(part_b, part_c)), fn_name, "");
                warns = warns + 1;
            };
            // NUC-FEEDBACK silent-extra-field close. Pre-fix
            // `Point { x: 1, y: 2, z: 3 }` for a 2-field Point silently
            // dropped the extra `z` field (Rust E0560 errors here).
            // Walk the init-list and check each field name against the
            // struct's declared fields via struct_field_idx; emit
            // TYP-013 for any unknown name.
            let mut fii: i64 = 0;
            while fii < ic {
                let init_check: i64 = list_get(pool, inits, fii);
                let fname: str = node_field(pool, init_check, 1);
                // TYP-017 — duplicate field in struct init.
                // Pre-fix `Pt { x: 1, y: 2, x: 3 }` silently took the
                // FIRST occurrence of `x` (=1) with no signal —
                // adopter's intent (was 3 the override?) opaque, and
                // Rust rejects this with E0062. Walk the init list
                // back from current index and check for any prior
                // entry with the same field name.
                let mut dup_chk: i64 = 0;
                while dup_chk < fii {
                    let prior_init: i64 = list_get(pool, inits, dup_chk);
                    let prior_name: str = node_field(pool, prior_init, 1);
                    if str_eq(prior_name, fname) == 1 {
                        let dp1: str = str_concat("duplicate field `", str_concat(fname, "` in `"));
                        let dp2: str = str_concat(struct_name, "` initialization. Remove one of the duplicate field assignments.");
                        diag_add_at_or_scan(diag_vec, source_text, pool, init_check, fname, "error", "type", "TYP-017", str_concat(dp1, dp2), fn_name, "");
                        warns = warns + 1;
                        dup_chk = fii;
                    };
                    dup_chk = dup_chk + 1;
                };
                let f_idx: i64 = struct_field_idx(pool, s_nid, fname);
                if f_idx < 0 {
                    let p1: str = str_concat("unknown field `", str_concat(fname, "` in `"));
                    let p2: str = str_concat(struct_name, "` initialization. Pre-v0.4.63 the extra field was silently dropped (Rust E0560 errors).");
                    diag_add_at_or_scan(diag_vec, source_text, pool, init_check, fname, "error", "type", "TYP-013", str_concat(p1, p2), fn_name, "");
                    warns = warns + 1;
                } else {
                    // TYP-008 ext — narrow struct-field type
                    // mismatch check (literal RHS only, avoids
                    // type_expr recursion which has crashed compiler
                    // self-build in prior attempts). Pre-fix `Point {
                    // x: "hello", y: 2 }` for `x: i64` silently
                    // i64-stored the str pointer; reads of p.x then
                    // produced garbage like 140700202648688. Adopters
                    // got a quiet wrong value with no diagnostic.
                    // Fires for: int-lit (kind 1) into str field;
                    // str-lit (kind 2) into int/bool field;
                    // float-lit (kind 71) into int/bool/str field.
                    let val_nid: i64 = node_field(pool, init_check, 2);
                    let val_kind: i64 = node_kind(pool, val_nid);
                    let f_param: i64 = list_get(pool, s_flist, f_idx);
                    let f_type: str = node_field(pool, f_param, 2);
                    if val_kind == 3 {
                        let val_name: str = node_field(pool, val_nid, 1);
                        let val_type: str = own_get_type(own, val_name);
                        if str_len(val_type) > 0 && frame_mismatch_visible(f_type, val_type) == 1 {
                            let f_action_struct: str = str_concat("cannot initialize field '", str_concat(struct_name, str_concat(".", str_concat(fname, "'"))));
                            diag_add_at_or_scan(diag_vec, source_text, pool, init_check, fname, "error", "type", "FRAME-001", frame_mismatch_diag_message(f_action_struct, f_type, val_type), fn_name, "");
                            warns = warns + 1;
                        };
                    };
                    let mut mismatch: i64 = 0;
                    let mut got_kind: str = "";
                    if val_kind == 1 && str_eq(f_type, "str") == 1 { mismatch = 1; got_kind = "int literal"; };
                    // int literal into bool field. Pre-fix
                    // `P { x: 5 }` for `x: bool` silently stored 5 as
                    // i64; reads of p.x evaluated truthy (5 != 0) but
                    // adopters lost the type guarantee. Rust E0308.
                    if val_kind == 1 && str_eq(f_type, "bool") == 1 { mismatch = 1; got_kind = "int literal (use `true`/`false`)"; };
                    if val_kind == 2 && (str_eq(f_type, "i64") == 1 || str_eq(f_type, "i32") == 1 || str_eq(f_type, "i16") == 1 || str_eq(f_type, "i8") == 1 || str_eq(f_type, "u64") == 1 || str_eq(f_type, "u32") == 1 || str_eq(f_type, "u16") == 1 || str_eq(f_type, "u8") == 1 || str_eq(f_type, "bool") == 1 || str_eq(f_type, "f64") == 1 || str_eq(f_type, "f32") == 1) { mismatch = 1; got_kind = "str literal"; };
                    if val_kind == 71 && (str_eq(f_type, "i64") == 1 || str_eq(f_type, "i32") == 1 || str_eq(f_type, "i16") == 1 || str_eq(f_type, "i8") == 1 || str_eq(f_type, "u64") == 1 || str_eq(f_type, "u32") == 1 || str_eq(f_type, "u16") == 1 || str_eq(f_type, "u8") == 1 || str_eq(f_type, "bool") == 1 || str_eq(f_type, "str") == 1) { mismatch = 1; got_kind = "float literal"; };
                    if mismatch == 1 {
                        let tm_msg: str = str_concat("struct-field type mismatch: `", str_concat(struct_name, str_concat(".", str_concat(fname, str_concat("` declared `", str_concat(f_type, str_concat("`, got ", str_concat(got_kind, ". Pre-v0.4.84 this silently bit-cast the value into the field's slot, producing garbage at read sites."))))))));
                        diag_add_at_or_scan(diag_vec, source_text, pool, init_check, fname, "error", "type", "TYP-008", tm_msg, fn_name, "");
                        warns = warns + 1;
                    };
                };
                fii = fii + 1;
            };
        };
        return warns;
    };
    if kind == 52 {
        let cur_scope: i64 = own_cur_scope(own);
        own_set_cur_scope(own, cur_scope + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        own_release_scope(own, cur_scope + 1);
        own_set_cur_scope(own, cur_scope);
        return warns;
    };
    if kind == 42 { return 0; }; // closure — skip for now
    if kind == 38 {
        let source_text: str = own_source(own);
        let diag_vec: Vec<i32> = own_diags(own);
        // deferred from v0.4.56: MATCH-001 in match-as-expression.
        // Pre-fix `let n: i64 = match c { Color::Red => 1 };` over a non-Red
        // value silently returned 0 because check_expr lacked a kind-38
        // handler — only check_stmt did the exhaustiveness check, so
        // matches in expression position escaped MATCH-001 entirely.
        // Mirror the check_stmt logic: walk arms, detect wildcard,
        // and if no wildcard + first arm is enum, compare ac < vcnt.
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        let arms_e: i64 = node_field(pool, nid, 2);
        let ac_e: i64 = list_len(pool, arms_e);
        let match_expr_init_mark_start_g411: i64 = own_get_i_raw(own, "__match_cond_init_count");
        let match_expr_has_init_g411: i64 = if vec_len(vec_get(own, 13)) > 0 { 1 } else { 0 };
        if match_expr_has_init_g411 == 1 { match_mark_match_init_candidates(pool, arms_e, own); };
        let expr_match_scope: i64 = own_cur_scope(own);
        let mut has_wild_e: i64 = 0;
        let mut ai_e: i64 = 0;
        while ai_e < ac_e {
            let arm_e: i64 = list_get(pool, arms_e, ai_e);
            let ename_e: str = node_field(pool, arm_e, 1);
            if str_eq(ename_e, "__wild") == 1 { has_wild_e = 1; };
            // Recurse into the arm body so use-after-move etc. fires.
            own_set_cur_scope(own, expr_match_scope + 1);
            warns = warns + check_stmts(pool, node_field(pool, arm_e, 4), own, structs, enums, fn_name);
            own_release_scope(own, expr_match_scope + 1);
            own_set_cur_scope(own, expr_match_scope);
            ai_e = ai_e + 1;
        };
        match_mark_match_move_free(pool, arms_e, own, structs, enums);
        if match_expr_has_init_g411 == 1 { own_apply_match_cond_inits(own, match_expr_init_mark_start_g411); };
        if has_wild_e == 0 && ac_e > 0 {
            let first_arm_e: i64 = list_get(pool, arms_e, 0);
            let first_ename_e: str = node_field(pool, first_arm_e, 1);
            // int/str match-as-expr without wildcard is
            // provably non-exhaustive (cannot list every i32/i64/str
            // value). Pre-fix `match x { 1 => 10, 2 => 20 }` for
            // x=5 silently returned 0 — same hazard class as the
            if (str_eq(first_ename_e, "__int") == 1 || str_eq(first_ename_e, "__str") == 1) && has_wild_e == 0 {
                let kind_label: str = if str_eq(first_ename_e, "__int") == 1 { "integer" } else { "string" };
                let msg_int_e: str = str_concat("non-exhaustive ", str_concat(kind_label, str_concat(" match (in expression context): ", str_concat(str_from_int(ac_e), " arms with no `_` wildcard. The set of values is unbounded so the unmatched case silently fell through to 0 pre-v0.4.109 — add a `_ => default_value,` arm to cover it explicitly."))));
                match_diag_at(diag_vec, source_text, pool, nid, "error", "MATCH-001", msg_int_e, fn_name);
                warns = warns + 1;
            };
            if str_eq(first_ename_e, "__int") == 0 && str_eq(first_ename_e, "__str") == 0 && str_eq(first_ename_e, "__wild") == 0 && str_eq(first_ename_e, "__range") == 0 && str_eq(first_ename_e, "__range_bad") == 0 {
                let ei_e: i64 = enum_find(pool, enums, first_ename_e);
                if ei_e >= 0 {
                    let e_nid_e: i64 = vec_get(enums, ei_e);
                    let vlist_e: i64 = node_field(pool, e_nid_e, 2);
                    let vcnt_e: i64 = list_len(pool, vlist_e);
                    if ac_e < vcnt_e {
                        let msg_e: str = str_concat("non-exhaustive match (in expression context): ", str_concat(str_from_int(ac_e), str_concat(" arms for enum with ", str_from_int(vcnt_e))));
                        let canon_e: str = str_concat(msg_e, ". Workaround: add a `_ => default_value,` arm or list every variant explicitly.");
                        // MATCH-001 only. Pre-fix emitted both TYP-001
                        // (legacy umbrella) and MATCH-001 (RFC-0016 canonical)
                        // with identical text — adopter saw the same diagnostic
                        // twice. MATCH-001 is the subsystem-specific diagnostic.
                        // MATCH-001 is the subsystem-specific code; it stays.
                        // TYP-001 is retained in the explain registry so
                        // adopters can `nuc explain TYP-001` to see it's been
                        // unified under MATCH-001.
                        match_diag_at(diag_vec, source_text, pool, nid, "error", "MATCH-001", canon_e, fn_name);
                        warns = warns + 1;
                    };
                };
            };
        };
        // bool literal match arm detection. Outside the
        // `has_wild_e == 0` gate above because the parser misparses
        // `true => ...` as `__wild` with binding="true" (silently
        // matches ANY bool, returns the body for ALL inputs —
        // `match false { true => 1 }` returns 1).
        let mut bool_arm: i64 = 0;
        let mut chk: i64 = 0;
        while chk < ac_e {
            let arm_v134: i64 = list_get(pool, arms_e, chk);
            let arm_n: str = node_field(pool, arm_v134, 1);
            let arm_b: str = node_field(pool, arm_v134, 3);
            if str_eq(arm_n, "__wild") == 1
                && (str_eq(arm_b, "true") == 1 || str_eq(arm_b, "false") == 1) {
                bool_arm = 1;
            };
            chk = chk + 1;
        };
        if bool_arm == 1 {
            let msg_b: str = "bool literal arm in `match` (`true => ...` or `false => ...`) is parsed as a wildcard binding pre-v0.4.134, not as a value comparison — `match b { true => 1 }` matches ANY bool and silently returns 1 even for b=false. Use `if cond { ... } else { ... }` for two-way bool branching, or convert the bool to i64 (`match b as i64 { 1 => ..., 0 => ..., _ => ... }`).";
            match_diag_at(diag_vec, source_text, pool, nid, "error", "MATCH-001", msg_b, fn_name);
            warns = warns + 1;
        };
        return warns;
    };
    return warns;
}

#[manual_drop]
fn check_stmt(pool: Vec<i32>, nid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, fn_name: str) -> i64 {
    if nid < 0 || nid >= vec_len(pool) { return 0; };
    let kind: i64 = node_kind(pool, nid);
    let mut warns: i64 = 0;
    let scope_depth: i64 = own_cur_scope(own);
    if kind == 20 {
        let vname: str = node_field(pool, nid, 1);
        let is_mut: i64 = node_field(pool, nid, 2);
        let mut tstr: str = node_field(pool, nid, 3);
        let init: i64 = node_field(pool, nid, 4);
        own_set_mutable(own, vname, is_mut);
        own_set_scope(own, vname, scope_depth);
        own_set_param(own, vname, 0);
        if init >= 0 {
            if str_len(tstr) == 0 && node_kind(pool, init) == 34 { tstr = node_field(pool, init, 1); };
            if str_len(tstr) == 0 && node_kind(pool, init) == 3 { tstr = own_get_type(own, node_field(pool, init, 1)); };
            warns = warns + check_expr(pool, init, own, structs, enums, fn_name);
            if type_is_ref(tstr) == 1 {
                if node_kind(pool, init) == 90 || node_kind(pool, init) == 91 {
                    warns = warns + own_register_borrow_expr(pool, init, own, fn_name, vname, scope_depth, 1);
                } else if node_kind(pool, init) == 7 && str_eq(node_field(pool, init, 1), "arena_alloc") == 1 {
                    let a_args: i64 = node_field(pool, init, 2);
                    if list_len(pool, a_args) > 0 && node_kind(pool, list_get(pool, a_args, 0)) == 3 {
                        let arena_name: str = node_field(pool, list_get(pool, a_args, 0), 1);
                        let arena_key: str = str_concat("@arena:", arena_name);
                        own_inc_shared(own, arena_key);
                        own_set_ref_target(own, vname, arena_key);
                        own_set_ref_kind(own, vname, 0);
                        own_set_scope(own, vname, scope_depth);
                    };
                } else if node_kind(pool, init) == 3 {
                    let src: str = node_field(pool, init, 1);
                    let st: str = own_get_type(own, src);
                    if type_is_ref(st) == 1 {
                        own_copy_ref_binding(own, src, vname, scope_depth);
                        if type_is_mut_ref(st) == 1 {
                            own_set_ref_target(own, src, "");
                            own_set_ref_kind(own, src, 0);
                            own_set(own, src, 2);
                        };
                    };
                };
                let escape_root: str = expr_escape_root(pool, init, own);
                if str_len(escape_root) > 0 && own_get_scope(own, escape_root) > scope_depth {
                    warns = warns + own_diag(own, fn_name, "OWN-010", str_concat("cannot let reference to inner-scope value '", str_concat(escape_root, "' escape its scope")), escape_root);
                };
            } else if node_kind(pool, init) == 3 {
                let src: str = node_field(pool, init, 1);
                let mut st: str = own_get_type(own, src);
                if str_len(st) == 0 { st = tstr; };
                if str_len(st) == 0 {
                    let hinted_box: str = own_box_hint(own, fn_name, vname);
                    if str_len(hinted_box) > 0 { st = hinted_box; };
                };
                if own_binding_move_type(st, pool, structs, enums) == 1 {
                    if own_has_shared_overlap(own, src) == 1 || own_has_mut_overlap(own, src) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(src, "': value is borrowed")), src);
                    } else {
                        own_set(own, src, 2);
                    };
                };
                // Alias-handle
                // double-free closure. When a binding is alias-
                // initialized from another (`let alias = v`) and the
                // type is a heap-collection (Vec/HashMap/String), the
                // tracker treats the source as live (i64 is Copy at
                // tracker level). If the source was previously freed,
                // propagate the freed flag onto the new binding so a
                // subsequent free of either name fires
                // OWN-G4-USE-AFTER-DROP. Same protection for the
                // `let alias: i64 = v as i64` shape — the cast walk
                // above (kind 99) recurses into the IDENT, but the
                // freed flag lives on src; without this propagation,
                // a free of alias would be silent.
                if is_heap_aliased_type(st) == 1 {
                    own_g4_set_alias(own, vname, src);
                };
                if own_get_i_raw(own, str_concat("__g4_freed_", src)) == 1 {
                    own_set_i_raw(own, str_concat("__g4_freed_", vname), 1);
                    own_set_s_raw(own, str_concat("__g4_freed_by_", vname), str_concat("alias of '", str_concat(src, "'")));
                };
            } else if node_kind(pool, init) == 99 {
                // Cast-init alias: `let alias: i64 = v as i64`
                // also propagates the freed flag from the cast
                // operand if it's a bare IDENT.
                let cast_inner: i64 = node_field(pool, init, 1);
                if node_kind(pool, cast_inner) == 3 {
                    let csrc: str = node_field(pool, cast_inner, 1);
                    if own_get_i_raw(own, str_concat("__g4_freed_", csrc)) == 1 {
                        own_set_i_raw(own, str_concat("__g4_freed_", vname), 1);
                        own_set_s_raw(own, str_concat("__g4_freed_by_", vname), str_concat("alias of '", str_concat(csrc, "'")));
                    };
                };
            };
            own_clear_binding_flow(own, vname);
            own_set(own, vname, 1);
            // RFC-0062 G-11 Phase 2b — DA flow analysis. let-with-
            // initializer = definitely assigned at this program
            // point. The seen sentinel records that this binding
            // went through the DA path (so reads can distinguish
            // params / loop vars / etc.).
            own_set_i_raw(own, str_concat("__init_", vname), 1);
            own_set_i_raw(own, str_concat("__init_seen_", vname), 1);
        } else {
            own_clear_binding_flow(own, vname);
            own_set(own, vname, 0);
            // RFC-0062 G-11 Phase 2b — DA flow analysis. let-without-
            // initializer = NOT yet assigned. Subsequent reads emit
            // INIT-G11-READ-BEFORE-INIT unless an assignment domi-
            // nates. Cooperates with own_merge_moved at if/else
            // joins via __init_* key intersection. The seen
            // sentinel scopes the diagnostic to bindings that
            // actually went through the DA-aware let-decl path.
            own_set_i_raw(own, str_concat("__init_", vname), 0);
            own_set_i_raw(own, str_concat("__init_seen_", vname), 1);
            own_track_init_name(own, vname);
        };
        own_set_type(own, vname, tstr);
        return warns;
    };
    if kind == 21 {
        let lhs: i64 = node_field(pool, nid, 1);
        let rhs: i64 = node_field(pool, nid, 2);
        warns = warns + check_expr(pool, rhs, own, structs, enums, fn_name);
        // assignment LHS shapes that aren't yet
        // supported. Pre-v0.3.81 these segfaulted the compiler with
        // ACCESS_VIOLATION because downstream code in lower_stmt
        // assumed the LHS was a var-ref (kind 3) or field-access
        // (kind 9) and treated other node-ids as string offsets.
        // Kind 10 = indexing (`v[i] = X`); other kinds = tuple/literal/
        // computed expressions that have no addressable storage.
        let lhs_kind_check: i64 = node_kind(pool, lhs);
        // kind-10 indexed assignment now lowered to vec_set
        // in lower_stmt; the prior diag-only stub here is no longer
        // needed.
        if lhs_kind_check != 3 && lhs_kind_check != 9 && lhs_kind_check != 10 {
            print("ERROR: assignment to this LHS form is not supported (only var-ref `x = ...`, field-access `obj.f = ...`, and indexed `v[i] = ...` are recognized; tuple destructuring assignment / computed-expression LHS is not). The pre-v0.3.81 compiler would segfault on this shape.");
            return warns + 1;
        };
        if node_kind(pool, lhs) == 3 {
            let lname: str = node_field(pool, lhs, 1);
            if own_get_mutable(own, lname) == 0 && own_get_param(own, lname) == 0 {
                warns = warns + own_diag(own, fn_name, "OWN-008", str_concat("cannot assign to immutable binding '", str_concat(lname, "'")), lname);
            };
            // RFC-0062 G-11 Phase 2b — DA flow analysis. Assignment
            // to a var-ref LHS marks the binding as definitely
            // assigned at this program point. Subsequent reads on
            // this path no longer fire INIT-G11-READ-BEFORE-INIT.
            own_set_i_raw(own, str_concat("__init_", lname), 1);
            own_release_ref(own, lname);
            if node_kind(pool, rhs) == 90 || node_kind(pool, rhs) == 91 {
                warns = warns + own_register_borrow_expr(pool, rhs, own, fn_name, lname, scope_depth, 1);
                let escape_root: str = expr_escape_root(pool, rhs, own);
                if str_len(escape_root) > 0 && own_get_scope(own, escape_root) > scope_depth {
                    warns = warns + own_diag(own, fn_name, "OWN-010", str_concat("cannot let reference to inner-scope value '", str_concat(escape_root, "' escape its scope")), escape_root);
                };
            } else if node_kind(pool, rhs) == 3 {
                let src: str = node_field(pool, rhs, 1);
                let mut st: str = own_get_type(own, src);
                if str_len(st) == 0 { st = own_get_type(own, lname); };
                if str_len(st) == 0 {
                    let hinted_box: str = own_box_hint(own, fn_name, lname);
                    if str_len(hinted_box) > 0 { st = hinted_box; };
                };
                if type_is_ref(st) == 1 {
                    own_copy_ref_binding(own, src, lname, scope_depth);
                    if type_is_mut_ref(st) == 1 {
                        own_set_ref_target(own, src, "");
                        own_set_ref_kind(own, src, 0);
                        own_set(own, src, 2);
                    };
                } else if own_binding_move_type(st, pool, structs, enums) == 1 {
                    if own_has_shared_overlap(own, src) == 1 || own_has_mut_overlap(own, src) == 1 {
                        warns = warns + own_diag(own, fn_name, "OWN-003", str_concat("cannot move '", str_concat(src, "': value is borrowed")), src);
                    } else {
                        own_set(own, src, 2);
                    };
                };
            };
            own_clear_binding_flow(own, lname);
            own_set(own, lname, 1);
            return warns;
        };
        if node_kind(pool, lhs) == 9 {
            let recv: i64 = node_field(pool, lhs, 1);
            // nested field assignment
            // (`outer.inner.field = X`) was crashing the compiler with
            // a segfault during the ownership/type check pass. Detect
            // the nested kind-9-on-kind-9 LHS and emit a clear
            // diagnostic instead of crashing. The actual feature
            // (deep field-path mutation) requires a get-modify-set
            // lowering tracked for a future ship.
            if node_kind(pool, recv) == 9 {
                print("ERROR: nested struct field assignment is not yet supported (e.g. `outer.inner.field = X`). Workaround: copy the inner struct to a local, mutate the local, then assign it back: `let mut tmp = outer.inner; tmp.field = X; outer.inner = tmp;`. Tracked for a future ship — get-modify-set lowering needed.");
                return warns + 1;
            };
            if node_kind(pool, recv) == 3 && type_is_shared_ref(own_get_type(own, node_field(pool, recv, 1))) == 1 {
                let rname: str = node_field(pool, recv, 1);
                warns = warns + own_diag(own, fn_name, "OWN-006", str_concat("cannot assign through shared reference '", str_concat(rname, "'")), rname);
                return warns;
            };
            let mut recv_is_mut_ref: i64 = 0;
            if node_kind(pool, recv) == 3 && type_is_mut_ref(own_get_type(own, node_field(pool, recv, 1))) == 1 { recv_is_mut_ref = 1; };
            if recv_is_mut_ref == 0 {
                let key: str = expr_borrow_key(pool, lhs, own);
                if own_has_shared_overlap(own, key) == 1 || own_has_mut_overlap(own, key) == 1 {
                    let root: str = expr_root_name(pool, lhs, own);
                    warns = warns + own_diag(own, fn_name, "OWN-007", str_concat("cannot assign to borrowed location '", str_concat(key, "'")), root);
                };
            };
        };
        return warns;
    };
    if kind == 22 {
        let val: i64 = node_field(pool, nid, 1);
        if val >= 0 {
            warns = warns + check_expr(pool, val, own, structs, enums, fn_name);
            let escape_root: str = expr_escape_root(pool, val, own);
            if str_len(escape_root) > 0 && own_get_param(own, escape_root) == 0 {
                warns = warns + own_diag(own, fn_name, "OWN-009", str_concat("cannot return reference to local value '", str_concat(escape_root, "'")), escape_root);
            };
        };
        return warns;
    };
    if kind == 23 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        let if23_snap_g411: Vec<i32> = own_snapshot(own);
        own_set_cur_scope(own, scope_depth + 1);
        warns = warns + check_stmts(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_cur_scope(own, scope_depth);
        let if23_then_state_g411: Vec<i32> = own_snapshot(own);
        own_restore(own, if23_snap_g411);
        vec_free(if23_snap_g411);
        let enode: i64 = node_field(pool, nid, 3);
        if enode >= 0 {
            own_set_cur_scope(own, scope_depth + 1);
            warns = warns + check_stmts(pool, enode, own, structs, enums, fn_name);
            own_release_scope(own, scope_depth + 1);
            own_set_cur_scope(own, scope_depth);
        };
        let if23_else_state_g411: Vec<i32> = own_snapshot(own);
        own_merge_moved(own, if23_then_state_g411, if23_else_state_g411);
        vec_free(if23_then_state_g411);
        vec_free(if23_else_state_g411);
        return warns;
    };
    if kind == 24 {
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        let while24_body_lid_g411: i64 = node_field(pool, nid, 2);
        let while24_needs_flow_g411: i64 = if own_has_uninit_binding(own) == 1 || stmt_list_may_flow_change(pool, while24_body_lid_g411, own, structs, enums) == 1 { 1 } else { 0 };
        let while24_snap_g411: Vec<i32> = if while24_needs_flow_g411 == 1 { own_snapshot(own) } else { Vec::new() };
        own_set_cur_scope(own, scope_depth + 1);
        warns = warns + check_stmts(pool, while24_body_lid_g411, own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_cur_scope(own, scope_depth);
        if while24_needs_flow_g411 == 1 {
            let while24_body_state_g411: Vec<i32> = own_snapshot(own);
            own_restore(own, while24_snap_g411);
            own_merge_moved(own, while24_snap_g411, while24_body_state_g411);
            vec_free(while24_body_state_g411);
        };
        vec_free(while24_snap_g411);
        return warns;
    };
    if kind == 25 {
        return check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
    };
    if kind == 28 {
        let loop_var: str = node_field(pool, nid, 1);
        let for28_body_lid_g411: i64 = node_field(pool, nid, 4);
        let for28_needs_flow_g411: i64 = if own_has_uninit_binding(own) == 1 || stmt_list_may_flow_change(pool, for28_body_lid_g411, own, structs, enums) == 1 { 1 } else { 0 };
        let for28_snap_g411: Vec<i32> = if for28_needs_flow_g411 == 1 { own_snapshot(own) } else { Vec::new() };
        own_set(own, loop_var, 1);
        own_set_type(own, loop_var, "i64");
        own_set_mutable(own, loop_var, 1);
        own_set_scope(own, loop_var, scope_depth + 1);
        own_set_param(own, loop_var, 0);
        own_set_cur_scope(own, scope_depth + 1);
        warns = warns + check_stmts(pool, for28_body_lid_g411, own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_cur_scope(own, scope_depth);
        if for28_needs_flow_g411 == 1 {
            let for28_body_state_g411: Vec<i32> = own_snapshot(own);
            own_restore(own, for28_snap_g411);
            own_merge_moved(own, for28_snap_g411, for28_body_state_g411);
            vec_free(for28_body_state_g411);
        };
        vec_free(for28_snap_g411);
        return warns;
    };
    if kind == 49 {
        let loop_var: str = node_field(pool, nid, 1);
        warns = warns + check_expr(pool, node_field(pool, nid, 2), own, structs, enums, fn_name);
        let foreach49_body_lid_g411: i64 = node_field(pool, nid, 3);
        let foreach49_needs_flow_g411: i64 = if own_has_uninit_binding(own) == 1 || stmt_list_may_flow_change(pool, foreach49_body_lid_g411, own, structs, enums) == 1 { 1 } else { 0 };
        let foreach49_snap_g411: Vec<i32> = if foreach49_needs_flow_g411 == 1 { own_snapshot(own) } else { Vec::new() };
        own_set(own, loop_var, 1);
        own_set_type(own, loop_var, "Vec");
        own_set_mutable(own, loop_var, 1);
        own_set_scope(own, loop_var, scope_depth + 1);
        own_set_param(own, loop_var, 0);
        own_set_cur_scope(own, scope_depth + 1);
        warns = warns + check_stmts(pool, foreach49_body_lid_g411, own, structs, enums, fn_name);
        own_release_scope(own, scope_depth + 1);
        own_set_cur_scope(own, scope_depth);
        if foreach49_needs_flow_g411 == 1 {
            let foreach49_body_state_g411: Vec<i32> = own_snapshot(own);
            own_restore(own, foreach49_snap_g411);
            own_merge_moved(own, foreach49_snap_g411, foreach49_body_state_g411);
            vec_free(foreach49_body_state_g411);
        };
        vec_free(foreach49_snap_g411);
        return warns;
    };
    if kind == 38 {
        let source_text: str = own_source(own);
        let diag_vec: Vec<i32> = own_diags(own);
        warns = warns + check_expr(pool, node_field(pool, nid, 1), own, structs, enums, fn_name);
        let arms: i64 = node_field(pool, nid, 2);
        let ac: i64 = list_len(pool, arms);
        let match38_init_mark_start_g411: i64 = own_get_i_raw(own, "__match_cond_init_count");
        let match38_has_init_g411: i64 = if vec_len(vec_get(own, 13)) > 0 { 1 } else { 0 };
        if match38_has_init_g411 == 1 { match_mark_match_init_candidates(pool, arms, own); };
        let mut has_wildcard: i64 = 0;
        let mut wildcard_idx: i64 = 0 - 1;
        let mut ai: i64 = 0;
        while ai < ac {
            let arm_nid: i64 = list_get(pool, arms, ai);
            let ename: str = node_field(pool, arm_nid, 1);
            // a `__wild` arm (`_ => ...` or var-binder
            // `x => ...`) is only an exhaustive catch-all when it
            // carries NO guard. With a guard (`x if cond => ...`)
            // the arm only matches when the guard evaluates true,
            // so following arms remain reachable for the
            // guard-fail case. Pre-fix MATCH-002 false-fired on
            // common idioms like `match n { x if x < 0 => -1, 0
            // => 0, x if x < 100 => 1, _ => 2 }` because arm 0's
            // `x if x < 0` was treated as exhaustive (wildcard
            // ename) and arms 1-3 flagged unreachable.
            // Regression: guarded match arm false positive.
            if str_eq(ename, "__wild") {
                let v215_guard: i64 = node_field(pool, arm_nid, 5);
                if v215_guard <= 0 {
                    has_wildcard = 1;
                    if wildcard_idx < 0 { wildcard_idx = ai; };
                };
            };
            // RFC-0023 §3.1 + MATCH-007: range pattern with bounds in
            // wrong order (LO > HI) — would never match.
            if str_eq(ename, "__range_bad") {
                match_diag_at(diag_vec, source_text, pool, nid, "warning", "MATCH-007", str_concat("range pattern bounds in wrong order at arm ", str_concat(str_from_int(ai + 1), " — pattern can never match")), fn_name);
                warns = warns + 1;
            };
            let binding: str = node_field(pool, arm_nid, 3);
            // For __range / __range_bad the `binding` field holds the
            // string-encoded high bound (e.g. "9"), not a variable name.
            // Skip the binding-as-variable scope setup for those arms.
            let is_range: i64 = if str_eq(ename, "__range") == 1 || str_eq(ename, "__range_bad") == 1 { 1 } else { 0 };
            if is_range == 0 && str_len(binding) > 0 {
                own_set(own, binding, 1);
                own_set_type(own, binding, "i64");
                own_set_mutable(own, binding, 0);
                own_set_scope(own, binding, scope_depth + 1);
                own_set_param(own, binding, 0);
            };
            own_set_cur_scope(own, scope_depth + 1);
            warns = warns + check_stmts(pool, node_field(pool, arm_nid, 4), own, structs, enums, fn_name);
            own_release_scope(own, scope_depth + 1);
            own_set_cur_scope(own, scope_depth);
            ai = ai + 1;
        };
        match_mark_match_move_free(pool, arms, own, structs, enums);
        if match38_has_init_g411 == 1 { own_apply_match_cond_inits(own, match38_init_mark_start_g411); };
        // RFC-0016 phase 5 — MATCH-002: any arm following a wildcard is
        // unreachable (the wildcard already captures every value).
        if wildcard_idx >= 0 && wildcard_idx < ac - 1 {
            // line+col via diag_add_ex.
            match_diag_at(diag_vec, source_text, pool, nid, "warning", "MATCH-002", str_concat("unreachable match arm after wildcard at arm ", str_concat(str_from_int(wildcard_idx + 1), str_concat(" of ", str_from_int(ac)))), fn_name);
            warns = warns + 1;
        };
        if has_wildcard == 0 && ac > 0 {
            let first_arm: i64 = list_get(pool, arms, 0);
            let first_ename: str = node_field(pool, first_arm, 1);
            // int/str match-as-stmt without wildcard.
            // Mirror of the match-as-expr check at line 9757; same
            // silent-fall-through hazard (statement form quietly did
            // nothing for unmatched values pre-v0.4.109).
            if (str_eq(first_ename, "__int") == 1 || str_eq(first_ename, "__str") == 1) && has_wildcard == 0 {
                let kind_label_s: str = if str_eq(first_ename, "__int") == 1 { "integer" } else { "string" };
                let msg_int_s: str = str_concat("non-exhaustive ", str_concat(kind_label_s, str_concat(" match: ", str_concat(str_from_int(ac), " arms with no `_` wildcard. The set of values is unbounded so unmatched cases silently no-op'd pre-v0.4.109 — add a `_ => { … }` arm to cover them explicitly."))));
                match_diag_at(diag_vec, source_text, pool, nid, "error", "MATCH-001", msg_int_s, fn_name);
                warns = warns + 1;
            };
            if str_eq(first_ename, "__int") == 0 && str_eq(first_ename, "__str") == 0 && str_eq(first_ename, "__wild") == 0 {
                let ei: i64 = enum_find(pool, enums, first_ename);
                if ei >= 0 {
                    let e_nid: i64 = vec_get(enums, ei);
                    let vlist: i64 = node_field(pool, e_nid, 2);
                    let vcnt: i64 = list_len(pool, vlist);
                    if ac < vcnt {
                        // line+col via diag_add_ex.
                        // RFC-0016 phase 5 — MATCH-001 (canonical) alongside
                        // legacy TYP-001 for backwards compatibility.
                        let msg: str = str_concat("non-exhaustive match: ", str_concat(str_from_int(ac), str_concat(" arms for enum with ", str_concat(str_from_int(vcnt), " variants"))));
                        // NUC-FEEDBACK silent-miscompute close.
                        // Pre-fix non-exhaustive match silently returned 0
                        // for unmatched scrutinee values (e.g. `match
                        // Color::Green { Color::Red => 1 }` returned 0).
                        // Adopters writing the canonical Rust idiom got
                        // a quiet wrong result. MATCH-001 was already in
                        // the error-tier code list but emitted as warning
                        // severity, so the build didn't halt. Promote
                        // both diags to "error" severity so MATCH-001
                        // halts the build like every other TYP-* error.
                        let canon_msg: str = str_concat(msg, ". Workaround: add a `_ => default_value,` arm or list every variant explicitly.");
                        // MATCH-001 only — see expression-context
                        // sister site at line ~12517 for rationale.
                        match_diag_at(diag_vec, source_text, pool, nid, "error", "MATCH-001", canon_msg, fn_name);
                        warns = warns + 1;
                    };
                };
            };
        };
        return warns;
    };
    if kind == 85 {
        // tuple-destructure-in-let ownership tracking.
        // Register each binding in own so downstream code can reference it.
        let ncv85c: str = node_field(pool, nid, 1);
        let init85c: i64 = node_field(pool, nid, 2);
        if init85c >= 0 { warns = warns + check_expr(pool, init85c, own, structs, enums, fn_name); };
        let slen85c: i64 = str_len(ncv85c);
        let mut i85c: i64 = 0;
        while i85c <= slen85c {
            let mut j85c: i64 = i85c;
            while j85c < slen85c && str_char_at(ncv85c, j85c) != 44 { j85c = j85c + 1; };
            if j85c > i85c {
                let bn85c: str = str_substring(ncv85c, i85c, j85c);
                if str_eq(bn85c, "_") == 0 {
                    own_set_mutable(own, bn85c, 0);
                    own_set_scope(own, bn85c, scope_depth);
                    own_set_param(own, bn85c, 0);
                };
            };
            i85c = j85c + 1;
        };
        return warns;
    };
    return warns;
}

#[manual_drop]
fn check_stmts(pool: Vec<i32>, lid: i64, own: Vec<i32>, structs: Vec<i32>, enums: Vec<i32>, fn_name: str) -> i64 {
    if lid < 0 || lid >= vec_len(pool) { return 0; };
    let cnt: i64 = list_len(pool, lid);
    let mut i: i64 = 0; let mut warns: i64 = 0;
    while i < cnt { warns = warns + check_stmt(pool, list_get(pool, lid, i), own, structs, enums, fn_name); i = i + 1; };
    return warns;
}

// Lane 2 audit fix (G2-A-1): extract the first lifetime label
// from a type string. Patterns:
//   `&'a T`  → "a"
//   `&'foo T` → "foo"
//   `&'a mut T` → "a"
//   `T` (no lifetime) → ""
// Used by the multi-input G-2 check to compare param-vs-return
// lifetime labels textually. Conservative — returns "" on shapes
// it doesn't recognize, which suppresses the diagnostic.
#[manual_drop]
fn g2_extract_lifetime_label(t: str) -> str {
    let tl: i64 = str_len(t);
    let mut p: i64 = 0;
    while p < tl {
        let c: i64 = str_char_at(t, p);
        if c == 39 {
            // Found `'`. Walk forward collecting alpha/digit/underscore.
            let lbl_start: i64 = p + 1;
            let mut lbl_end: i64 = lbl_start;
            while lbl_end < tl {
                let cc: i64 = str_char_at(t, lbl_end);
                let is_alpha: i64 = if (cc >= 97 && cc <= 122) || (cc >= 65 && cc <= 90) || cc == 95 { 1 } else { 0 };
                let is_digit: i64 = if cc >= 48 && cc <= 57 { 1 } else { 0 };
                if is_alpha == 0 && is_digit == 0 { break; };
                lbl_end = lbl_end + 1;
            };
            if lbl_end > lbl_start {
                return str_substring(t, lbl_start, lbl_end);
            };
        };
        p = p + 1;
    };
    return "";
}

#[manual_drop]
fn g2_find_fn_sig_pos(source: str, fn_name: str) -> i64 {
    let needle: str = str_concat("fn ", fn_name);
    let slen: i64 = str_len(source);
    let nlen: i64 = str_len(needle);
    if nlen == 0 || slen < nlen { return 0 - 1; };
    let mut i: i64 = 0;
    while i <= slen - nlen {
        if str_eq_at_len(source, i, needle, nlen) == 1 { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn g2_find_char_from(source: str, start: i64, want: i64) -> i64 {
    let slen: i64 = str_len(source);
    let mut i: i64 = start;
    while i < slen {
        if str_char_at(source, i) == want { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn g2_find_matching_paren(source: str, open_pos: i64) -> i64 {
    let slen: i64 = str_len(source);
    let mut depth: i64 = 0;
    let mut i: i64 = open_pos;
    while i < slen {
        let c: i64 = str_char_at(source, i);
        if c == 40 { depth = depth + 1; }
        else if c == 41 {
            depth = depth - 1;
            if depth == 0 { return i; };
        };
        i = i + 1;
    };
    return 0 - 1;
}

#[manual_drop]
fn g2_source_param_lifetime(source: str, fn_name: str, param_name: str) -> str {
    let sig: i64 = g2_find_fn_sig_pos(source, fn_name);
    if sig < 0 { return ""; };
    let openp: i64 = g2_find_char_from(source, sig, 40);
    if openp < 0 { return ""; };
    let closep: i64 = g2_find_matching_paren(source, openp);
    if closep < 0 { return ""; };
    let plen: i64 = str_len(param_name);
    let mut p: i64 = openp + 1;
    while p < closep {
        while p < closep && is_ws(str_char_at(source, p)) == 1 { p = p + 1; };
        let seg_start: i64 = p;
        let mut seg_end: i64 = p;
        let mut angle_depth: i64 = 0;
        let mut par_depth: i64 = 0;
        while seg_end < closep {
            let c: i64 = str_char_at(source, seg_end);
            if c == 60 { angle_depth = angle_depth + 1; }
            else if c == 62 && angle_depth > 0 { angle_depth = angle_depth - 1; }
            else if c == 40 { par_depth = par_depth + 1; }
            else if c == 41 && par_depth > 0 { par_depth = par_depth - 1; }
            else if c == 44 && angle_depth == 0 && par_depth == 0 { break; };
            seg_end = seg_end + 1;
        };
        let mut name_start: i64 = seg_start;
        while name_start < seg_end && is_ws(str_char_at(source, name_start)) == 1 { name_start = name_start + 1; };
        if name_start + plen <= seg_end && str_eq_at_len(source, name_start, param_name, plen) == 1 {
            let mut after_name: i64 = name_start + plen;
            while after_name < seg_end && is_ws(str_char_at(source, after_name)) == 1 { after_name = after_name + 1; };
            if after_name < seg_end && str_char_at(source, after_name) == 58 {
                let ty: str = str_substring(source, after_name + 1, seg_end);
                return g2_extract_lifetime_label(ty);
            };
        };
        p = seg_end + 1;
    };
    return "";
}

#[manual_drop]
fn g2_source_return_lifetime(source: str, fn_name: str) -> str {
    let sig: i64 = g2_find_fn_sig_pos(source, fn_name);
    if sig < 0 { return ""; };
    let openp: i64 = g2_find_char_from(source, sig, 40);
    if openp < 0 { return ""; };
    let closep: i64 = g2_find_matching_paren(source, openp);
    if closep < 0 { return ""; };
    let slen: i64 = str_len(source);
    let mut p: i64 = closep + 1;
    while p < slen && is_ws(str_char_at(source, p)) == 1 { p = p + 1; };
    if p + 1 >= slen || str_char_at(source, p) != 45 || str_char_at(source, p + 1) != 62 { return ""; };
    p = p + 2;
    let ret_start: i64 = p;
    let mut ret_end: i64 = p;
    while ret_end < slen {
        let c: i64 = str_char_at(source, ret_end);
        if c == 123 || c == 59 || c == 10 || c == 13 { break; };
        ret_end = ret_end + 1;
    };
    return g2_extract_lifetime_label(str_substring(source, ret_start, ret_end));
}

#[manual_drop]
fn check_fn(pool: Vec<i32>, fn_nid: i64, structs: Vec<i32>, enums: Vec<i32>, diags: Vec<i32>, source: str) -> i64 {
    let fn_name: str = node_field(pool, fn_nid, 1);
    let plist: i64 = node_field(pool, fn_nid, 2);
    let body: i64 = node_field(pool, fn_nid, 4);
    if body < 0 || body >= vec_len(pool) { return 0; };
    let pc: i64 = list_len(pool, plist);
    let mut own: Vec<i32> = own_new();
    own_set_type(own, "__diags", diags);
    own_set_type(own, "__source", source);
    own_set_type(own, "__shared_keys", Vec::new());
    own_set_type(own, "__mut_keys", Vec::new());
    own_set_type(own, "__scope_keys", Vec::new());
    own_set_i(own, "cur_scope", 0);
    own_set_type(own, "__init_names", Vec::new());
    own_set_i_raw(own, "__g4_flow_active", 0);
    own_set_i_raw(own, "__g8_flow_active", 0);
    let mut pi: i64 = 0;
    while pi < pc {
        let pnid: i64 = list_get(pool, plist, pi);
        let pname: str = node_field(pool, pnid, 1);
        let ptype: str = node_field(pool, pnid, 2);
        own_set(own, pname, 1);
        own_set_type(own, pname, ptype);
        own_set_mutable(own, pname, 0);
        own_set_scope(own, pname, 0);
        own_set_param(own, pname, 1);
        if type_is_ref(ptype) == 1 {
            own_set_ref_target(own, pname, pname);
            if type_is_mut_ref(ptype) == 1 { own_set_ref_kind(own, pname, 1); }
            else { own_set_ref_kind(own, pname, 0); };
        };
        pi = pi + 1;
    };
    let w: i64 = check_stmts(pool, body, own, structs, enums, fn_name);
    let rtype: str = node_field(pool, fn_nid, 3);
    if type_is_ref(rtype) == 1 {
        let body_cnt: i64 = list_len(pool, body);
        if body_cnt > 0 {
            let last_stmt: i64 = list_get(pool, body, body_cnt - 1);
            let last_kind: i64 = node_kind(pool, last_stmt);
            if last_kind == 25 || last_kind == 23 || last_kind == 52 {
                let mut escape_root: str = "";
                if last_kind == 25 { escape_root = expr_escape_root(pool, node_field(pool, last_stmt, 1), own); }
                else { escape_root = expr_escape_root(pool, last_stmt, own); };
                if str_len(escape_root) > 0 && own_get_param(own, escape_root) == 0 {
                    own_diag(own, fn_name, "OWN-009", str_concat("cannot return reference to local value '", str_concat(escape_root, "'")), escape_root);
                };
                // RFC-0062 G-2 Phase 2b/3/4 — single-input lifetime
                // check. When the fn signature has exactly one
                // ref-typed parameter and the return type is a
                // reference, the returned region must equal the
                // input's region. The Phase 1 BR-7 build-summary count
                // (~line 32172) surfaces the presence of `<'a>`
                // syntax; this is the structural check that enforces
                // it. Phase 4 promotion: registered in is_error_code
                // so own_diag halts compilation.
                // Conservative against false positives: emits only
                // when expr_param_root proves the return *does* trace
                // back to a parameter, but to a different one than
                // the single ref-typed input. If trace fails (returns
                // ""), no diag — that case is either OWN-009
                // (escape_root non-empty above) or an opaque return
                // we can't reason about yet. Multi-input cases are
                // skipped here; they're Phase 3 elision per the plan.
                let mut g2_ref_param_count: i64 = 0;
                let mut g2_single_ref_param: str = "";
                let mut g2_pj: i64 = 0;
                while g2_pj < pc {
                    let g2_pjnid: i64 = list_get(pool, plist, g2_pj);
                    let g2_pjtype: str = node_field(pool, g2_pjnid, 2);
                    if type_is_ref(g2_pjtype) == 1 {
                        g2_ref_param_count = g2_ref_param_count + 1;
                        if g2_ref_param_count == 1 {
                            g2_single_ref_param = node_field(pool, g2_pjnid, 1);
                        };
                    };
                    g2_pj = g2_pj + 1;
                };
                if g2_ref_param_count == 1 && str_len(escape_root) == 0 {
                    let mut g2_param_root: str = "";
                    if last_kind == 25 { g2_param_root = expr_param_root(pool, node_field(pool, last_stmt, 1), own); }
                    else { g2_param_root = expr_param_root(pool, last_stmt, own); };
                    if str_len(g2_param_root) > 0 && str_eq(g2_param_root, g2_single_ref_param) == 0 {
                        own_diag(own, fn_name, "BORROW-G2-LIFETIME", str_concat("returned reference is derived from parameter '", str_concat(g2_param_root, str_concat("' but the function's only ref-typed input is '", str_concat(g2_single_ref_param, "'. Per RFC-0062 G-2 (single-input lifetime check): the returned region must equal the input's region. Bind the return to the single ref input or restructure the signature.")))), g2_single_ref_param);
                    };
                };
                // Multi-input lifetime
                // check. Pre-fix, fns with 2+ ref params (e.g.
                // `fn pick<'a, 'b>(x: &'a i32, y: &'b i32) -> &'a i32`)
                // were skipped entirely (only Phase 1 BR-7 advisory
                // warning fired). Now: when the return traces back
                // to a specific ref param, scan the return type's
                // lifetime label and the parameter's lifetime label
                // textually; reject when they differ. The check is
                // conservative — when no lifetime labels are present
                // (Phase 3 lifetime elision), skip. When labels are
                // present and demonstrably mismatched, fire
                // BORROW-G2-LIFETIME at error severity. RFC-0062
                // §3.3 G-2 P3 schedules elision rules post-v1.0;
                // until then explicit `<'a, 'b>` shapes get the
                // honest enforcement they were missing.
                if g2_ref_param_count >= 2 && str_len(escape_root) == 0 {
                    let mut g2m_param_root: str = "";
                    if last_kind == 25 { g2m_param_root = expr_param_root(pool, node_field(pool, last_stmt, 1), own); }
                    else { g2m_param_root = expr_param_root(pool, last_stmt, own); };
                    if str_len(g2m_param_root) > 0 {
                        // Look up the param's declared type and
                        // extract the lifetime label (the substring
                        // between `&'` and the next non-alpha char,
                        // if any). Scan params again to find the
                        // root's type.
                        let mut g2m_root_type: str = "";
                        let mut g2m_pj2: i64 = 0;
                        while g2m_pj2 < pc {
                            let g2m_pjnid: i64 = list_get(pool, plist, g2m_pj2);
                            let g2m_pname: str = node_field(pool, g2m_pjnid, 1);
                            if str_eq(g2m_pname, g2m_param_root) == 1 {
                                g2m_root_type = node_field(pool, g2m_pjnid, 2);
                            };
                            g2m_pj2 = g2m_pj2 + 1;
                        };
                        // Parsed type strings deliberately erase
                        // lifetime labels (`&'a T` lowers to `&T`) so
                        // normal type compatibility stays canonical.
                        // For this explicit multi-input audit rule,
                        // recover the labels from the source signature.
                        let mut g2m_root_lt: str = g2_extract_lifetime_label(g2m_root_type);
                        if str_len(g2m_root_lt) == 0 { g2m_root_lt = g2_source_param_lifetime(source, fn_name, g2m_param_root); };
                        let mut g2m_ret_lt: str = g2_extract_lifetime_label(rtype);
                        if str_len(g2m_ret_lt) == 0 { g2m_ret_lt = g2_source_return_lifetime(source, fn_name); };
                        if str_len(g2m_root_lt) > 0 && str_len(g2m_ret_lt) > 0 && str_eq(g2m_root_lt, g2m_ret_lt) == 0 {
                            own_diag(own, fn_name, "BORROW-G2-LIFETIME", str_concat("returned reference is derived from parameter '", str_concat(g2m_param_root, str_concat("' (declared lifetime `'", str_concat(g2m_root_lt, str_concat("`) but the function's return type carries lifetime `'", str_concat(g2m_ret_lt, "`. Per RFC-0062 G-2 multi-input (Lane 2 audit fix v1.0): the returned region must equal the input's declared lifetime. Fix the lifetime label on the return type or change which parameter the return traces from.")))))), g2m_param_root);
                        };
                    };
                };
            };
        };
    };
    return w;
}
