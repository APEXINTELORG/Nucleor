// v0.8.120: Rust stdlib namespace prefix auto-strip in type-annotation position.
// `std::vec::Vec<i64>`, `core::option::Option<T>`, `alloc::vec::Vec<T>`, etc.
// Pre-v0.7.37: wrong-class NR020. v0.7.37: halt + workaround pointer.
// Now: walk past all `Ident::` segments to the final type name, resolve normally.

fn std_path_type_smoke() -> i64 {
    // two-level prefix: std::vec::Vec<i64>
    let v: std::vec::Vec<i64> = Vec::new();
    v.push(10);
    v.push(20);
    v.push(30);
    let sum: i64 = vec_get(v, 0) + vec_get(v, 1) + vec_get(v, 2);
    assert_eq!(sum, 60);

    // three-level prefix: core::option::Option<i64>
    let o: core::option::Option<i64> = Some(42);
    let ov: i64 = match o { Some(x) => x, None => 0 };
    assert_eq!(ov, 42);

    // single-level prefix: alloc::vec::Vec<str>
    let mut sv: alloc::vec::Vec<str> = Vec::new();
    sv.push("alpha");
    sv.push("beta");
    assert_eq!(vec_len(sv), 2);

    return 0;
}

fn main() -> i64 {
    let rc: i64 = std_path_type_smoke();
    if rc == 0 { print("PASS: v0.8.120 std path type auto-strip\n"); };
    return rc;
}
