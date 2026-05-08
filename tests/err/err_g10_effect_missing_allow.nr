// EXPECT: EFFECT-G10-MISSING-ALLOW missing from the `#[effect(...)]` row
// RFC-0062 G-10 Phase 2b — negative fixture for the MISSING-ALLOW
// arm. The fn declares `#[effect(direct_ffi)]` but the body calls
// `vec_free` (which produces the `frees` effect, not in the row)
// and there is no `#[allow_effect(frees)]` silencer. The framework
// must emit EFFECT-G10-MISSING-ALLOW.

#[effect(direct_ffi)]
fn release_wrong_effect(v: Vec<i64>) -> i32 {
    vec_free(v);
    0
}

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    release_wrong_effect(v);
    0
}
