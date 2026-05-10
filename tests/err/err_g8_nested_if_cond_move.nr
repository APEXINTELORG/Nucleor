// EXPECT: OWN-G8-COND-MOVE
// G8-A-2: a divergent move inside a nested if must propagate to the
// outer join and reject post-join reads.
struct B { v: i64 }

fn consume(b: B) -> i64 { return b.v; }

fn main() -> i32 {
    let b: B = B { v: 7 };
    let a: i64 = 1;
    let c: i64 = 1;
    if a == 1 {
        if c == 1 {
            let _r: i64 = consume(b);
        };
    };
    let read: i32 = b.v as i32;
    read
}
