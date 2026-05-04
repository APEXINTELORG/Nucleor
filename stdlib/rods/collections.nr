// =====================================================
// rods/collections — HashMap and collection utilities
// =====================================================
// Import: import "stdlib/rods/collections.nr"
// Provides: map_new, map_set, map_get, map_has, map_remove, map_keys,
//   map_len, map_clear, vec_contains, vec_reverse, vec_index_of,
//   vec_clone, vec_slice, vec_swap
// =====================================================

// HashMap: open-addressing with linear probing
// Layout: 3 parallel vecs — keys (str), values (i64), occupied (0/1)
// A map handle is a Vec<i32> with: [0]=keys, [1]=values, [2]=occupied, [3]=count, [4]=capacity

fn map_hash(key: str, cap: i64) -> i64 {
    let klen: i64 = str_len(key);
    let mut h: i64 = 5381;
    let mut i: i64 = 0;
    while i < klen {
        h = h * 33 + str_char_at(key, i);
        // Keep positive
        if h < 0 { h = 0 - h; };
        i = i + 1;
    };
    let slot: i64 = h - (h / cap) * cap;
    if slot < 0 { return 0 - slot; };
    return slot;
}

fn map_new() -> Vec<i32> {
    let cap: i64 = 64;
    let mut keys: Vec<i32> = Vec::new();
    let mut vals: Vec<i32> = Vec::new();
    let mut occ: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < cap {
        keys.push("");
        vals.push(0);
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

fn map_find_slot(m: Vec<i32>, key: str) -> i64 {
    let keys: i64 = m.get(0);
    let occ: i64 = m.get(2);
    let cap: i64 = m.get(4);
    let mut slot: i64 = map_hash(key, cap);
    let mut probes: i64 = 0;
    while probes < cap {
        if vec_get(occ, slot) == 0 { return 0 - slot - 1; };
        if str_eq(vec_get(keys, slot), key) { return slot; };
        slot = slot + 1;
        if slot >= cap { slot = 0; };
        probes = probes + 1;
    };
    return 0 - 1;
}

// v0.8.41 RFC-0062 G-1: HANDOFF — new_keys/new_vals/new_occ
// are stored INTO `m` via `vec_set(m, 0/1/2, <local>)`. Default-
// flip auto-drop would dangle m's field pointers.
#[manual_drop]
fn map_grow(m: Vec<i32>) {
    let old_keys: i64 = m.get(0);
    let old_vals: i64 = m.get(1);
    let old_occ: i64 = m.get(2);
    let old_cap: i64 = m.get(4);
    let new_cap: i64 = old_cap * 2;
    let mut new_keys: Vec<i32> = Vec::new();
    let mut new_vals: Vec<i32> = Vec::new();
    let mut new_occ: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < new_cap {
        new_keys.push("");
        new_vals.push(0);
        new_occ.push(0);
        i = i + 1;
    };
    vec_set(m, 0, new_keys);
    vec_set(m, 1, new_vals);
    vec_set(m, 2, new_occ);
    vec_set(m, 3, 0);
    vec_set(m, 4, new_cap);
    i = 0;
    while i < old_cap {
        if vec_get(old_occ, i) == 1 {
            let k: str = vec_get(old_keys, i);
            let v: i64 = vec_get(old_vals, i);
            let mut slot: i64 = map_hash(k, new_cap);
            while vec_get(new_occ, slot) == 1 {
                slot = slot + 1;
                if slot >= new_cap { slot = 0; };
            };
            vec_set(new_keys, slot, k);
            vec_set(new_vals, slot, v);
            vec_set(new_occ, slot, 1);
            vec_set(m, 3, m.get(3) + 1);
        };
        i = i + 1;
    };
}

fn map_set(m: Vec<i32>, key: str, value: i64) {
    let count: i64 = m.get(3);
    let cap: i64 = m.get(4);
    if count * 2 >= cap { map_grow(m); };
    let slot: i64 = map_find_slot(m, key);
    if slot >= 0 {
        vec_set(m.get(1), slot, value);
    } else {
        let ins: i64 = 0 - slot - 1;
        vec_set(m.get(0), ins, key);
        vec_set(m.get(1), ins, value);
        vec_set(m.get(2), ins, 1);
        vec_set(m, 3, m.get(3) + 1);
    };
}

fn map_get(m: Vec<i32>, key: str) -> i64 {
    let slot: i64 = map_find_slot(m, key);
    if slot >= 0 { return vec_get(m.get(1), slot); };
    return 0;
}

fn map_has(m: Vec<i32>, key: str) -> i64 {
    let slot: i64 = map_find_slot(m, key);
    if slot >= 0 { return 1; };
    return 0;
}

fn map_remove(m: Vec<i32>, key: str) {
    let slot: i64 = map_find_slot(m, key);
    if slot >= 0 {
        vec_set(m.get(0), slot, "");
        vec_set(m.get(1), slot, 0);
        vec_set(m.get(2), slot, 0);
        vec_set(m, 3, m.get(3) - 1);
    };
}

fn map_keys(m: Vec<i32>) -> Vec<i32> {
    let mut result: Vec<i32> = Vec::new();
    let occ: i64 = m.get(2);
    let keys: i64 = m.get(0);
    let cap: i64 = m.get(4);
    let mut i: i64 = 0;
    while i < cap {
        if vec_get(occ, i) == 1 { result.push(vec_get(keys, i)); };
        i = i + 1;
    };
    return result;
}

fn map_len(m: Vec<i32>) -> i64 {
    return m.get(3);
}

fn map_clear(m: Vec<i32>) {
    let cap: i64 = m.get(4);
    let mut i: i64 = 0;
    while i < cap {
        vec_set(m.get(0), i, "");
        vec_set(m.get(1), i, 0);
        vec_set(m.get(2), i, 0);
        i = i + 1;
    };
    vec_set(m, 3, 0);
}

// Vec utilities
fn vec_contains(v: Vec<i32>, val: i64) -> i64 {
    let mut i: i64 = 0;
    while i < v.len() {
        if v.get(i) == val { return 1; };
        i = i + 1;
    };
    return 0;
}

fn vec_contains_str(v: Vec<i32>, val: str) -> i64 {
    let mut i: i64 = 0;
    while i < v.len() {
        if str_eq(v.get(i), val) { return 1; };
        i = i + 1;
    };
    return 0;
}

fn vec_index_of(v: Vec<i32>, val: i64) -> i64 {
    let mut i: i64 = 0;
    while i < v.len() {
        if v.get(i) == val { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

fn vec_index_of_str(v: Vec<i32>, val: str) -> i64 {
    let mut i: i64 = 0;
    while i < v.len() {
        if str_eq(v.get(i), val) { return i; };
        i = i + 1;
    };
    return 0 - 1;
}

fn vec_swap(v: Vec<i32>, a: i64, b: i64) {
    let tmp: i64 = v.get(a);
    vec_set(v, a, v.get(b));
    vec_set(v, b, tmp);
}

fn vec_reverse(v: Vec<i32>) {
    let vlen: i64 = v.len();
    let mut i: i64 = 0;
    while i < vlen / 2 {
        vec_swap(v, i, vlen - 1 - i);
        i = i + 1;
    };
}

fn vec_clone(v: Vec<i32>) -> Vec<i32> {
    let mut result: Vec<i32> = Vec::new();
    let mut i: i64 = 0;
    while i < v.len() { result.push(v.get(i)); i = i + 1; };
    return result;
}

fn vec_slice(v: Vec<i32>, start: i64, end: i64) -> Vec<i32> {
    let mut result: Vec<i32> = Vec::new();
    let mut i: i64 = start;
    while i < end && i < v.len() { result.push(v.get(i)); i = i + 1; };
    return result;
}

// Insertion sort (stable, good for small/nearly-sorted data)
fn vec_sort(v: Vec<i32>) {
    let vlen: i64 = v.len();
    let mut i: i64 = 1;
    while i < vlen {
        let key: i64 = v.get(i);
        let mut j: i64 = i - 1;
        while j >= 0 && v.get(j) > key {
            vec_set(v, j + 1, v.get(j));
            j = j - 1;
        };
        vec_set(v, j + 1, key);
        i = i + 1;
    };
}
