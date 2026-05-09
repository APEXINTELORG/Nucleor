// EXPECT: OWN-G8-COND-MOVE
// Lane 2 audit fix (G8-B-1, 2026-05-08): field projection after
// a conditional move was silent pre-fix because the IDENT-only
// G-8 path didn't fire on field reads. Now: kind 5 (field
// access) consults __g8_cond_moved_<receiver> just like kind 3.
struct B { v: i64 }

fn consume(b: B) -> i64 { return b.v; }

fn main() -> i32 {
    let b: B = B { v: 7 };
    let cond: i64 = 1;
    if cond == 1 {
        let _r: i64 = consume(b);
    };
    let read: i32 = b.v as i32;
    read
}
