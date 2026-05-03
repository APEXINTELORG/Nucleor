// EXPECT: nucleor: tuple-destructuring in `for` head not yet supported
// v0.6.59 — for-head tuple destructure halts cleanly at parse (was wrong-class NR020)
fn main() -> i32 {
    let mut m: HashMap<str, i64> = HashMap::new();
    hashmap_insert(&mut m, "x", 1);
    for (k, v) in &m {
        print(k);
    };
    return 0;
}
