// Probe sym-aux runtime helpers (Phase A smoke).

fn main() -> i64 {
    let s: Vec<i32> = Vec::new();
    s.push("alpha"); s.push(1);
    s.push("beta");  s.push(2);
    s.push("gamma"); s.push(3);

    let h: i64 = __nucleor_sym_aux_create(s);
    if h <= 0 { println!("FAIL: aux create"); return 1; };

    // sync the aux from the vec
    let n: i64 = vec_len(s);
    let mut i: i64 = 0;
    while i + 1 < n {
        __nucleor_hashmap_insert(h, vec_get(s, i), vec_get(s, i + 1));
        i = i + 2;
    };
    __nucleor_sym_aux_set_built_at(s, n);

    // probe
    if __nucleor_hashmap_contains(h, "alpha") == 0 { println!("FAIL: contains alpha"); return 1; };
    if __nucleor_hashmap_get(h, "alpha") != 1 { println!("FAIL: alpha=1"); return 1; };
    if __nucleor_hashmap_get(h, "beta")  != 2 { println!("FAIL: beta=2");  return 1; };
    if __nucleor_hashmap_get(h, "gamma") != 3 { println!("FAIL: gamma=3"); return 1; };
    if __nucleor_hashmap_contains(h, "delta") == 1 { println!("FAIL: spurious delta"); return 1; };

    // built_at should match vec_len
    if __nucleor_sym_aux_built_at(s) != n { println!("FAIL: built_at"); return 1; };

    // get returns same handle on second call
    let h2: i64 = __nucleor_sym_aux_get(s);
    if h2 != h { println!("FAIL: aux_get != create"); return 1; };

    println!("ok");
    return 0;
}
