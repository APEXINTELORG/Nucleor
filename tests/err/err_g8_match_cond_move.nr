// EXPECT: OWN-G8-COND-MOVE
// Regression gate G-8 CFG join: match arms must merge move state.
// Moving a non-Copy value on one arm and preserving it on another
// makes later reads conditionally unsound.
enum Choice { TakeIt, KeepIt }
struct B { v: i64 }

fn consume(b: B) -> i64 { return b.v; }

fn main() -> i32 {
    let b: B = B { v: 7 };
    let choice: Choice = Choice::TakeIt;
    match choice {
        Choice::TakeIt => { let _x: i64 = consume(b); },
        Choice::KeepIt => { let _y: i64 = 0; },
    };
    let _z: i64 = b.v;
    return 0;
}
