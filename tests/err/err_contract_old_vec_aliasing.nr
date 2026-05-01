// EXPECT: build fails with CONTRACT-006.
// RFC-0006 — `old()` over heap-aliased types must reject at compile time.
// EXPECT: build fails with CONTRACT-006.
//
// v0.4.271 closes the silent-miscompute filed by the probe agent
// 2026-05-01: under the i64-everywhere ABI, Vec/String/HashMap/
// HashSet/BTreeMap/BTreeSet/VecDeque/Box are i64 pointers. `old(v)`
// for `v: Vec<T>` snapshots the POINTER VALUE — not the buffer
// contents — so it aliases the post-mutation pointer and ensure
// semantics are wrong.
//
// Compile-time reject (CONTRACT-006) avoids the silent miscompute.
// Adopters get a clear diagnostic naming the type and the fix:
// hoist a scalar snapshot before the body (e.g. `let len: i64 =
// vec_len(v);`) and reference that scalar in the ensure.
//
#[ensure(vec_len(result) == vec_len(old(v)) + 1)]
fn append(v: Vec<i64>, x: i64) -> Vec<i64> {
    let mut w: Vec<i64> = v;
    vec_push(w, x);
    w
}

fn main() -> i32 {
    let v: Vec<i64> = vec![1, 2, 3];
    let v2: Vec<i64> = append(v, 4);
    print_int(vec_len(v2) as i32);
    0
}
