// EXPECT: error[TYP-018] unknown field
// v0.4.129: `let y: i64 = p.y;` for a struct `P { x: i64 }` (no
// y field) silently lowered to `vec_get(p, -1)` and surfaced at
// runtime as a misleading `vec_get OOB index -1` panic — adopters
// typo'ing field names got a runtime crash with no compile-time
// signal pointing at the struct or the typo'd name. Now halts at
// type-check with TYP-018 listing the bad field name + receiver
// type.

struct P { x: i64 }

fn main() -> i32 {
    let p: P = P { x: 0 };
    let y: i64 = p.y;
    print_int(y);
    0
}
