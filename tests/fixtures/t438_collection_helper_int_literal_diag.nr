// t438_collection_helper_int_literal_diag.nr -- v0.3.171 regression
// fixture (positive: build succeeds with WARNING).
//
// Pre-v0.3.171, hashmap_get(42, "key") (and similar mistakes for
// hashset_*, btreemap_*, btreeset_*, vecdeque_*) compiled cleanly
// and SIGSEGV'd at runtime when the helper dereferenced the int
// as a container pointer.
//
// Same hazard class as v0.3.170 (vec_*) and v0.3.162 f64_to_str
// (int_literal). Conservative literal-only WARNING.
//
// Fix (v0.3.171): extend the literal-only check pattern to all
// container helper families. Detects callee starting with
// hashmap_/hashset_/btreemap_/btreeset_/vecdeque_; if arg-0 is
// an INT LITERAL (AST kind 1) and the helper isn't a constructor
// (excludes *_new / *_with_capacity), emit a WARNING with the
// container type label and a code suggestion.
//
// This fixture pins the well-typed case (real HashMap usage)
// to guard against regressions in legitimate use.

fn main() -> i64 {
    let mut h: HashMap<str, i64> = HashMap::new();
    h.insert("a", 1);
    h.insert("b", 2);
    let v: i64 = hashmap_get(h, "a");
    if v != 1 { return 1; };
    let n: i64 = hashmap_len(h);
    if n != 2 { return 2; };
    return 42;
}
