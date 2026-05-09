// EXPECT: ALIAS-G3-HASHMAP-REHASH hashmap_free
// Lane 2 audit fix (G3-X-1, 2026-05-08): hashmap_free while a
// live shared borrow exists. Pre-fix only insert/remove/clear
// were checked; free is strictly worse (DEFINITELY invalidates
// the borrow vs. rehash MAY invalidate). Now: free is in the
// guard set.
fn main() -> i32 {
    let mut m: HashMap<str, i64> = HashMap::new();
    let r: &HashMap<str, i64> = &m;
    hashmap_free(m);
    0
}
