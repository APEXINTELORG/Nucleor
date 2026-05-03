// EXPECT: TYP-026 non-str key type `i64` in keyed collection
// v0.6.51 — HashMap<i64, V> halts cleanly at compile time (was runtime crash)
fn main() -> i32 {
    let mut m: HashMap<i64, i64> = HashMap::new();
    return 0;
}
