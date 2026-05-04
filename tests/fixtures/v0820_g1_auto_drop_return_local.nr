// v0.8.20 RFC-0062 G-1 Phase 1 — return-by-bare-name skip-drop
// lock-in. Per RFC-0042 Spike Semantics: "Returning a tracked
// local by bare name skips dropping that local on that return
// path." If generated cleanup ran here, it would double-free
// since the caller takes ownership of the returned Vec and
// will free it on its own auto_drop pass.

#[auto_drop]
fn build_vec(n: i64) -> Vec<i64> {
    let mut v: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < n {
        v.push(i);
        i = i + 1;
    }
    return v;  // bare-name return; generated drop skipped
}

#[auto_drop]
fn caller() -> i64 {
    let v: Vec<i64> = build_vec(4);
    return vec_len(&v);  // generated drop on `v` runs here
}

fn main() -> i64 {
    return caller();  // 4
}
