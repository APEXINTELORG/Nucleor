// Phase SAFE-P5: Disjoint field borrows and writes may coexist

struct Pair { left: i32, right: i32 }

fn main() -> i32 {
    let mut p: Pair = Pair { left: 1, right: 2 };
    let l: &mut i32 = &mut p.left;
    print_int(*l);
    print_int(p.right);
    p.right = 9;
    print_int(p.right);
    0
}
