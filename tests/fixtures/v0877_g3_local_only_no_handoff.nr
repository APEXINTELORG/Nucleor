// v0.8.77 RFC-0062 G-3 — local-only positive case. Auto-drop
// fires correctly when no handoff is present.
//
// Vec is created, used, never handed off. Under unconditional
// flip, auto-drop emits free at fn exit. rc=3 (the Vec has 3
// elements before auto-drop runs).

fn use_local() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(1); v.push(2); v.push(3);
    return vec_len(&v);  // 3
}

fn main() -> i64 {
    return use_local();
}
