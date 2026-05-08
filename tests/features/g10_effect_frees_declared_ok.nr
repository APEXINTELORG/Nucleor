// RFC-0062 G-10 Phase 2b — positive lock-in. A fn that frees a heap
// allocation declares the `frees` effect via `#[effect(frees)]` and
// the framework accepts it. No EFFECT-G10-* diagnostic fires.
//
// `#[manual_drop]` keeps the default-flip auto-drop pass off this fn
// — `release` already frees `v` on the handoff, and we don't want
// main's auto-drop to double-free.

#[effect(frees)]
#[manual_drop]
fn release(v: Vec<i64>) -> i32 {
    vec_free(v);
    0
}

#[allow_effect(frees)]
#[manual_drop]
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    release(v);
    0
}
