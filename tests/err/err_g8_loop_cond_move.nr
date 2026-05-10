// EXPECT: OWN-G8-COND-MOVE
// G8-A-3: a move inside a loop may or may not execute before the
// post-loop read, so the binding is conditionally moved at the join.
struct B { v: i64 }

fn consume(b: B) -> i64 { return b.v; }

fn main() -> i32 {
    let b: B = B { v: 7 };
    let mut i: i64 = 0;
    while i < 1 {
        let _r: i64 = consume(b);
        i = i + 1;
    };
    let read: i32 = b.v as i32;
    read
}
