// EXPECT: EFFECT-G10-UNDECLARED produces effect `frees`
// RFC-0062 G-10 Phase 2b — negative fixture for the UNDECLARED
// arm. The fn calls `vec_free` (a leaf builtin in the `frees`
// effect) but carries no `#[effect(...)]` declaration at all and
// no `#[allow_effect(frees)]` opt-out. The framework must emit
// EFFECT-G10-UNDECLARED at error severity.
//
// Since the gate is "source contains #[effect(" or
// "#[allow_effect(", a sibling fn with #[allow_effect(frees)]
// keeps the check active for this translation unit while not
// itself producing a diagnostic.

#[allow_effect(frees)]
fn dummy_keep_gate_open(x: i32) -> i32 {
    return x;
}

fn release_undeclared(v: Vec<i64>) -> i32 {
    vec_free(v);
    0
}

fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 1);
    release_undeclared(v);
    dummy_keep_gate_open(0);
    0
}
