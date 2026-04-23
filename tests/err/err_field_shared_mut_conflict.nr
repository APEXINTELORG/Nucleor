// EXPECT: OWN-005 cannot shared-borrow value that is mutably borrowed
// Shared/mut borrow conflict at field granularity.
// Phase SAFE-P5: Overlapping field borrows remain exclusive

struct Pair { left: i32, right: i32 }

fn main() -> i32 {
    let mut p: Pair = Pair { left: 1, right: 2 };
    let l: &mut i32 = &mut p.left;
    let bad: &i32 = &p.left;
    print_int(*l);
    print_int(*bad);
    0
}
