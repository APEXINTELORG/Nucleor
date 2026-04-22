// Phase 2a: Move semantics — conditional moves

struct Item { id: i32 }

fn consume(i: Item) -> i32 { i.id }

fn main() -> i32 {
    // Case 1: move in one branch — variable is conditionally moved
    let a: Item = Item { id: 1 };
    let cond: bool = true;
    if cond {
        let x: i32 = consume(a);   // a moved here
        print_int(x);
    } else {
        print_int(0);               // a NOT moved here
    };
    // a is conditionally moved — using it is an error
    print_int(a.id);                // ERROR: use of moved value 'a'
    0
}
