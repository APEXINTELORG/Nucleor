// RFC-0062 G-8 Phase 2b/3/4 — positive lock-in. The cond-moved
// flag fires only when ONE arm moves and the other doesn't. Two
// well-formed shapes that compile clean:
// (a) both arms move    — `b` is definitely consumed; OWN-001
//     would fire on a post-join read (which we don't write here).
// (b) neither arm moves — `b` survives the if/else; post-join
//     reads are sound.
// This fixture exercises (b) — neither arm consumes `b`, so the
// cond-moved flag stays clear and no diagnostic fires.
struct B { v: i64 }
fn main() -> i32 {
    let b: B = B { v: 7 };
    let cond: i64 = 1;
    if cond == 1 {
        let _x: i64 = b.v;
    } else {
        let _y: i64 = b.v + 1;
    };
    let z: i64 = b.v;
    print_int(z as i32);
    0
}
