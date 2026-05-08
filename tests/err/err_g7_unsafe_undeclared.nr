// EXPECT: UNSAFE-G7-MISSING-ALLOW unsafe { } block
// RFC-0062 G-7 Phase 4 — negative fixture. The fn contains an
// `unsafe { }` block but carries no #[effect(unsafe)] declaration
// and no #[allow_effect(unsafe)] silencer. The framework must emit
// UNSAFE-G7-MISSING-ALLOW at error severity.

#[allow_effect(unsafe)]
fn dummy_keep_gate_open(x: i32) -> i32 {
    return x;
}

fn body_with_unsafe(x: i32) -> i32 {
    let mut y: i32 = x;
    unsafe {
        y = y + 1;
    };
    return y;
}

fn main() -> i32 {
    body_with_unsafe(7);
    dummy_keep_gate_open(0);
    0
}
