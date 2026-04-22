// =====================================================
// rods/sort — Sorting algorithms
// =====================================================
// Import: import "stdlib/rods/sort.nr"
// Provides: sort_ints, sort_strings, sort_by, is_sorted
// =====================================================

// Insertion sort for a Vec of integers (in-place, ascending)
fn sort_ints(v: Vec<i32>) {
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

// Insertion sort for a Vec of strings (in-place, lexicographic ascending)
// Compares character by character
fn sort_strings(v: Vec<i32>) {
    let vlen: i64 = v.len();
    let mut i: i64 = 1;
    while i < vlen {
        let key: str = v.get(i);
        let mut j: i64 = i - 1;
        while j >= 0 && sort_str_cmp(v.get(j), key) > 0 {
            vec_set(v, j + 1, v.get(j));
            j = j - 1;
        };
        vec_set(v, j + 1, key);
        i = i + 1;
    };
}

// String comparison: returns <0, 0, or >0
// Negative if a < b, zero if a == b, positive if a > b
fn sort_str_cmp(a: str, b: str) -> i64 {
    let alen: i64 = str_len(a);
    let blen: i64 = str_len(b);
    let mut min_len: i64 = alen;
    if blen < min_len { min_len = blen; };
    let mut i: i64 = 0;
    while i < min_len {
        let ca: i64 = str_char_at(a, i);
        let cb: i64 = str_char_at(b, i);
        if ca != cb { return ca - cb; };
        i = i + 1;
    };
    return alen - blen;
}

// Sort a Vec of integers using a comparator Vec as a parallel key array
// The comparator vec holds the sort keys (integers); v is reordered to match
// This sorts v based on the values in keys (ascending)
fn sort_by(v: Vec<i32>, keys: Vec<i32>) {
    let vlen: i64 = v.len();
    let mut i: i64 = 1;
    while i < vlen {
        let k_key: i64 = keys.get(i);
        let v_val: i64 = v.get(i);
        let mut j: i64 = i - 1;
        while j >= 0 && keys.get(j) > k_key {
            vec_set(keys, j + 1, keys.get(j));
            vec_set(v, j + 1, v.get(j));
            j = j - 1;
        };
        vec_set(keys, j + 1, k_key);
        vec_set(v, j + 1, v_val);
        i = i + 1;
    };
}

// Check if a Vec of integers is sorted in ascending order
fn is_sorted(v: Vec<i32>) -> i64 {
    let vlen: i64 = v.len();
    if vlen <= 1 { return 1; };
    let mut i: i64 = 1;
    while i < vlen {
        if v.get(i) < v.get(i - 1) { return 0; };
        i = i + 1;
    };
    return 1;
}
