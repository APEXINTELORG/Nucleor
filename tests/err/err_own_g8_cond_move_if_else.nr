// EXPECT: OWN-G8-COND-MOVE conditional move of 'b'
// RFC-0062 G-8 Phase 2b/3/4 — conditional-divergence move-state
// join. The then-arm moves `b` into `consume`; the else-arm only
// reads `b.v`. After the if/else, `b` is "conditionally moved" —
// reading `b.v` on the post-join path is unsound because whether
// `b` still owns its value depends on which arm ran.
struct B { v: i64 }
fn consume(b: B) -> i64 { return b.v; }
fn main() -> i32 {
    let b: B = B { v: 7 };
    let cond: i64 = 1;
    if cond == 1 {
        let _x: i64 = consume(b);
    } else {
        let _y: i64 = b.v;
    };
    let _z: i64 = b.v;
    0
}
