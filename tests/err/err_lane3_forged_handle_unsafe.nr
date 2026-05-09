// EXPECT: UNSAFE-G7-MISSING-ALLOW unsafe block without effect declaration
// Lane 3 (F-CONC-016 / cross-lane probe for Lane 2): forging
// resource handles from arbitrary integers is a UAF/UB primitive.
// Until Lane 2 lands a dedicated handle-encapsulation diagnostic
// (HANDLE-FORGED, expected post-Lane-2), the lower bar is that any
// code constructing a fake handle through casts/raw arithmetic
// must at least live inside an `unsafe { }` block — and the fn
// containing the unsafe block must carry `#[effect(unsafe)]` or
// `#[allow_effect(unsafe)]` per RFC-0062 G-7 Phase 4.

#[allow_effect(unsafe)]
fn dummy_keep_gate_open(x: i32) -> i32 {
    return x;
}

// Deliberately omit #[effect(unsafe)] / #[allow_effect(unsafe)] so
// UNSAFE-G7-MISSING-ALLOW fires. Lane 2 will tighten this to a
// HANDLE-FORGED diagnostic when handle encapsulation lands.
fn use_forged_handle(x: i32) -> i32 {
    let forged: i32 = 1234567;
    let mut h: i32 = x;
    unsafe {
        // Simulate handle-forging UAF primitive: cast an arbitrary
        // int to a "handle" and consume it.
        h = forged + 1;
    };
    return h;
}

fn main() -> i32 {
    use_forged_handle(7);
    dummy_keep_gate_open(0);
    0
}
