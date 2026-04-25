// t356_indexed_lhs_diagnostic.nr — v0.3.81 negative regression fixture.
//
// Pre-v0.3.81, writing `v[i] = X;` segfaulted the compiler with
// ACCESS_VIOLATION (exit -1073741819) — the kind-21 lowering's
// fallback path interpreted the kind-10 indexing-node as a string
// offset and crashed on garbage memory access.
//
// Post-v0.3.81: clean diagnostic in check_stmt + lower_stmt
// short-circuits to skip codegen. Build completes without segfault.

fn main() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(10); v.push(20); v.push(30);
    v[1] = 999;     // <-- pre-v0.3.81: segfault, post: clean diagnostic
    return v[1];
}
