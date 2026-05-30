// t448_print_hashmap_value_dispatch.nr -- v0.3.182 regression
// fixture.
//
// Follow-on to v0.3.181 (NUC-FEEDBACK-006 parallel pass).
// HashMap<K, V>.get / hashmap_get / btreemap_get / hashmap_remove
// were still defaulting to print_i64 in the v0.3.178 hardcoded
// fallback list. For HashMap<str, str>, that printed the str
// pointer as int (e.g. 140695322076274) instead of the string.
//
// Same hazard class as v0.3.181 -- adopters using HashMap with
// str values get pointer addresses with no diagnostic.
//
// Fix (v0.3.182):
//   1. New helper generic_second_type(t: str) extracts V from
//      "HashMap<K, V>" / "BTreeMap<K, V>" / similar two-arg
//      generics by paren-balanced comma splitting.
//   2. Kind 7 print() dispatch for hashmap_get / hashmap_get_or /
//      hashmap_remove / btreemap_get parses the receiver's
//      __fulltype_<name> entry, extracts V via the new helper,
//      and dispatches by V's type. str -> fall through to
//      print_str (correct).
//   3. Removed hashmap_get / hashmap_get_or / hashmap_remove /
//      btreemap_get from the v0.3.178 hardcoded i64 fallback
//      (the new value-type lookup supersedes it).

fn main() -> i64 {
    let mut h: HashMap<str, str> = HashMap::new();
    h.insert("a", "alpha");
    h.insert("b", "beta");
    print(hashmap_get(h, "a"));   // expected "alpha", pre-fix pointer int
    print(hashmap_get(h, "b"));   // expected "beta"

    let mut h2: HashMap<str, i64> = HashMap::new();
    h2.insert("k", 42);
    print(hashmap_get(h2, "k"));  // expected "42" (i64 dispatch still works)

    return 42;
}
