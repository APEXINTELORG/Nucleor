// RFC-0062 G-7 Phase 4 — positive lock-in. A fn that contains an
// `unsafe { }` block declares the `unsafe` effect via #[effect(unsafe)]
// and the framework accepts it. No UNSAFE-G7-* diagnostic fires.

#[effect(unsafe)]
fn body_with_unsafe(x: i32) -> i32 {
    let mut y: i32 = x;
    unsafe {
        y = y + 1;
    };
    return y;
}

#[allow_effect(unsafe)]
fn main() -> i32 {
    body_with_unsafe(7);
    0
}
