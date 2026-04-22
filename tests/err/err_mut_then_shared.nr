// Phase 2c: Cannot shared-borrow while mutably borrowed

struct Item { val: i32 }

fn main() -> i32 {
    let mut a: Item = Item { val: 5 };
    let m: &mut Item = &mut a;  // mutable borrow
    let r: &Item = &a;          // ERROR: already mutably borrowed
    print_int(r.val);
    m.val = 99;
    0
}
