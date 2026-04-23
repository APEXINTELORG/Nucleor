// EXPECT: OWN-003 cannot move value that is borrowed
// Move while a borrow is outstanding.
// Phase 2b: Cannot move a value while it is borrowed

struct Widget { id: i32 }

fn consume(w: Widget) -> i32 { w.id }

fn main() -> i32 {
    let a: Widget = Widget { id: 42 };
    let r: &Widget = &a;       // borrow a
    let x: i32 = consume(a);   // ERROR: cannot move 'a' while it is borrowed
    print_int(r.id);
    print_int(x);
    0
}
