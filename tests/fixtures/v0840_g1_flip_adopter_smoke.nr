// v0.8.40 G-1 Phase 2b-3 — env-gated flip adopter smoke.
// Adopter sets NUC_AUTO_DROP_DEFAULT=1; this fixture exercises
// the auto-drop pipeline on a Vec without explicit free.
//
// Without the env var: vec_free count = 1 (declaration only)
// With the env var:    vec_free count = 2 (decl + auto-emit)
//
// Smoke result: rc=3 (the Vec contains 3 elements before drop).

fn build_then_use() -> i64 {
    let mut v: Vec<i64> = Vec::new();
    v.push(10); v.push(20); v.push(30);
    return vec_len(&v);
}

fn main() -> i64 {
    return build_then_use();  // 3
}
