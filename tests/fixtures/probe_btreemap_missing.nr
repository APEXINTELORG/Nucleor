// Probe: btreemap_get on missing key should PANIC by default
fn main() -> i64 {
    let m: BTreeMap<str, i64> = BTreeMap::new();
    btreemap_insert(m, "a", 1);
    let v: i64 = btreemap_get(m, "missing");
    println!("{}", v);
    return 0;
}
