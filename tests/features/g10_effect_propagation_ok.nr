// RFC-0062 G-10 Phase 2b — positive lock-in. A caller that invokes
// a fn declared with `#[effect(frees)]` propagates the `frees`
// effect transparently through one hop. The caller declares the
// same effect and the framework accepts the chain.
//
// `#[manual_drop]` on every level keeps the default-flip auto-drop
// pass off — the bottom-most fn already frees the handoff.

#[effect(frees)]
#[manual_drop]
fn release(v: Vec<i64>) -> i32 {
    vec_free(v);
    0
}

#[effect(frees)]
#[manual_drop]
fn caller(v: Vec<i64>) -> i32 {
    release(v);
    0
}

#[allow_effect(frees)]
#[manual_drop]
fn main() -> i32 {
    let mut v: Vec<i64> = Vec::new();
    vec_push(v, 7);
    caller(v);
    0
}
