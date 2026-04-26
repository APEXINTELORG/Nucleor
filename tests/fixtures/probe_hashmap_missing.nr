// Probe: hashmap_get on missing key should PANIC by default
fn main() -> i64 {
    let m: HashMap<str, i64> = HashMap::new();
    hashmap_insert(m, "a", 1);
    let v: i64 = hashmap_get(m, "missing");
    println!("{}", v);
    return 0;
}
