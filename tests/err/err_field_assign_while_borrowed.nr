// EXPECT: OWN-007 cannot assign to borrowed location
// Mutating a struct field while a borrow exists violates ownership.
// Phase SAFE-P5: Borrowed fields cannot be assigned through overlapping paths

struct Pair { left: i32, right: i32 }

fn main() -> i32 {
    let mut p: Pair = Pair { left: 1, right: 2 };
    let l: &i32 = &p.left;
    p.left = 4;
    print_int(*l);
    0
}
