// RFC-0062 G-2 Phase 2b/3/4 — single-input lifetime check (positive
// fixture). When a fn signature has exactly one ref-typed parameter
// and the return type is a reference, the returned region must equal
// the input's region. Returning the parameter unchanged satisfies
// the rule and compiles cleanly. Lock-in for the BORROW-G2-LIFETIME
// diagnostic.

fn id_ref(x: &i32) -> &i32 {
    x
}

fn main() -> i32 {
    let v: i32 = 42;
    let r: &i32 = id_ref(&v);
    print_int(*r);
    print("OK");
    0
}
