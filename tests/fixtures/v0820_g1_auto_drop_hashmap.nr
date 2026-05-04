// v0.8.20 RFC-0062 G-1 Phase 1 — HashMap auto_drop lock-in.
// RFC-0042 lists HashMap among the drop-eligible types; this
// fixture confirms the generated cleanup runs and does not
// double-free when explicit `hashmap_free` is called. Uses str
// keys per TYP-026 (the v0.x supported key type).

#[auto_drop]
fn make_and_return_len() -> i64 {
    let mut m: HashMap<str, i64> = HashMap::new();
    m.insert("a", 10);
    m.insert("b", 20);
    return hashmap_len(&m);
}

#[auto_drop]
fn make_and_explicit_free() -> i64 {
    let mut m: HashMap<str, i64> = HashMap::new();
    m.insert("k", 70);
    let n: i64 = hashmap_len(&m);
    hashmap_free(m);  // explicit free disables generated drop
    return n;
}

fn main() -> i64 {
    let a: i64 = make_and_return_len();      // 2
    let b: i64 = make_and_explicit_free();   // 1
    return a * 10 + b;                       // 21
}
