// EXPECT: OWN-004 cannot mutably borrow value that is already borrowed
// Mut borrow attempted while shared borrow live.
// Phase 2c: Cannot have &T and &mut T at same time

struct Item { val: i32 }

fn main() -> i32 {
    let mut a: Item = Item { val: 5 };
    let r: &Item = &a;          // shared borrow
    let m: &mut Item = &mut a;  // ERROR: already shared-borrowed
    m.val = 99;
    print_int(r.val);
    0
}
