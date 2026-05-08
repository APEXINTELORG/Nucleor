// RFC-0062 G-10 Phase 2b — positive lock-in. A fn opts out of the
// `frees` declaration via `#[allow_effect(frees)]` (intentional
// escape hatch). The framework recognises the silencer and emits
// no EFFECT-G10-UNDECLARED diagnostic.
//
// `#[manual_drop]` keeps the default-flip auto-drop pass off the
// callee that already frees its arg, and off main which has handed
// off the value.

#[allow_effect(frees)]
#[manual_drop]
fn release_silent(v: Vec<i64>) -> i32 {
    vec_free(v);
    0
}

// release_silent's #[allow_effect(frees)] silences ITS own diagnostic;
// it does not propagate the `frees` effect upward to the caller because
// it carries no `#[effect(frees)]` declaration. So `main` here sees
// only a plain unannotated callee — no propagation, no diagnostic.
#[manual_drop]
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 42);
    release_silent(v);
    0
}
