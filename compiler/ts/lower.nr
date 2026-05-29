// =====================================================
// LOWERING (from T29, extended for STR_LIT, METHOD, QUAL_CALL)
// =====================================================
fn smap_has(m: Vec<i32>, key: str) -> i64 {
    if smap_find_slot(m, key) >= 0 { return 1; };
    return 0;
}
fn smap_clone(m: Vec<i32>) -> Vec<i32> {
    let cloned: Vec<i32> = smap_new_cap(smap_slots(m));
    let mut i: i64 = 0;
    let slots: i64 = smap_slots(m);
    while i < slots {
        if smap_slot_used(m, i) == 1 {
            smap_set(cloned, smap_slot_key(m, i), smap_slot_val(m, i));
        };
        i = i + 1;
    };
    return cloned;
}
fn smap_restore(dst: Vec<i32>, src: Vec<i32>) -> i64 {
    let cloned: Vec<i32> = smap_clone(src);
    vec_set(dst, 0, vec_get(cloned, 0));
    vec_set(dst, 1, vec_get(cloned, 1));
    vec_set(dst, 2, vec_get(cloned, 2));
    vec_set(dst, 3, vec_get(cloned, 3));
    vec_set(dst, 4, vec_get(cloned, 4));
    return 0;
}
fn lower_mark_error(sym: Vec<i32>) -> i64 { sym_set(sym, "__lower_error", 1); return 0 - 1; }
fn lower_has_error(sym: Vec<i32>) -> i64 { if sym_get(sym, "__lower_error") >= 0 { return 1; }; return 0; }
// Struct registry helpers




fn sendable_first_type(t: str) -> str {
    let n: i64 = str_len(t);
    let mut p: i64 = 0;
    while p < n && str_char_at(t, p) != 60 { p = p + 1; };
    if p >= n { return ""; };
    let start: i64 = p + 1;
    p = start;
    let mut depth: i64 = 1;
    while p < n {
        let c: i64 = str_char_at(t, p);
        if c == 60 { depth = depth + 1; }
        else if c == 62 {
            depth = depth - 1;
            if depth == 0 { return str_trim(str_substring(t, start, p)); };
        }
        else if c == 44 && depth == 1 { return str_trim(str_substring(t, start, p)); };
        p = p + 1;
    };
    return "";
}







// Enum helpers: pre-populate sym with variant tags and arg counts

