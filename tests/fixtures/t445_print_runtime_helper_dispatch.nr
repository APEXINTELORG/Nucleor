// t445_print_runtime_helper_dispatch.nr -- v0.3.178 regression
// fixture.
//
// Pre-v0.3.178, print() of a direct call to a runtime helper
// (e.g. hashmap_get, vec_get, str_len) SIGSEGV'd because the
// runtime helpers have no __fnret_<name> entry in sym -- the
// kind-7 (fn call) print() dispatch fell through to print_str
// which dereferenced the i64 result as a string pointer.
//
// Similarly print() of a method call with a name not in the
// previous v0.3.168 fallback list (len/count/capacity/is_empty/
// contains/contains_key) -- e.g. h.get(k) -- SIGSEGV'd.
//
// Same hazard class as v0.3.168 (kind 8 method call fallback)
// extended to cover kind 7 direct calls and additional method
// names.
//
// Fix (v0.3.178):
//   - Kind 7 fn call: hardcoded list of well-known runtime
//     helpers with deterministic i64/bool/f64 returns
//     (hashmap_/hashset_/btreemap_/btreeset_/vecdeque_/vec_/
//     str_/tok_/sqrt_f64/exp_f64/etc.).
//   - Kind 8 method call: extended fallback with
//     get/first/last/pop/remove/front/back (i64) and
//     starts_with/ends_with (bool).

fn main() -> i64 {
    let mut h: HashMap<str, i64> = HashMap::new();
    h.insert("a", 42);
    h.insert("b", 7);
    print(hashmap_get(h, "a"));    // pre-fix SIGSEGV (kind 7)
    print(h.get("b"));              // pre-fix SIGSEGV (kind 8 method)

    let mut v: Vec<i64> = Vec::new();
    v.push(100); v.push(200);
    print(v.first());               // i64 builtin
    print(v.last());                // i64 builtin

    print(str_len("hello"));        // direct fn call

    return 42;
}
