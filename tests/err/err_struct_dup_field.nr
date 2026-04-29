// EXPECT: error[TYP-017] duplicate field
// v0.4.128: `Pt { x: 1, y: 2, x: 3 }` silently took the FIRST
// occurrence of `x` (=1) with no signal — Rust rejects this with
// E0062. Adopter intent (was 3 the override?) was opaque. Same
// silent-miscompute family as v0.4.62 missing-field (TYP-012)
// and v0.4.63 unknown-field (TYP-013) closes; this one fills
// the gap for duplicate-name init lists.

struct Pt { x: i64, y: i64 }

fn main() -> i32 {
    let p: Pt = Pt { x: 1, y: 2, x: 3 };
    print_int(p.x);
    0
}
