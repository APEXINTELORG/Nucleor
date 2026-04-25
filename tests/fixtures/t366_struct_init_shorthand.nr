// t366_struct_init_shorthand.nr — v0.3.90 regression fixture.
//
// Pins shorthand field initialization in struct literals where at
// least one field uses the explicit `name: value` form (which
// triggers parse_struct_init from parse_primary's existing
// detection). The shorthand form `name` (synthesized to
// `name: name` from the surrounding scope) works for any field
// after the first explicit one.
//
// Pure-shorthand `Point { x, y }` (no explicit field) is NOT
// supported in this ship — the parse_primary trigger needs the
// `IDENT :` shape to fire, and broadening it caused regressions
// in compiler self-host. Tracked for a future ship.
//
// Returns 0 on success.

#[repr(C)]
struct Point { x: i64, y: i64 }

fn main() -> i64 {
    let y: i64 = 4;
    let z: i64 = 7;
    // Mixed: explicit + shorthand
    let p1: Point = Point { x: 5, y };
    if p1.x != 5 { return 91; };
    if p1.y != 4 { return 92; };

    // All-shorthand-after-explicit-first
    let q: Point = Point { x: 1, y: y };  // baseline regression check
    if q.x + q.y != 5 { return 93; };

    return 0;
}
