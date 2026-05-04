// EXPECT: path type `std::<rest>` not supported in type position
// Negative fixture for v0.7.37: Rust path type in type-annotation position
// (`std::collections::HashMap<K,V>`) now produces a clean halt with an
// unqualified-name workaround pointer instead of wrong-class
// `error[NR020]: parse_primary cannot start an expression at token kind 46`.
fn main() -> i64 {
    let m: std::collections::HashMap<i64, i64> = std::collections::HashMap::new();
    return 0;
}
