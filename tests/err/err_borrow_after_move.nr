// Phase 2b: Cannot borrow a value that has been moved

struct Item { data: i32 }

fn consume(i: Item) -> i32 { i.data }

fn main() -> i32 {
    let a: Item = Item { data: 7 };
    let x: i32 = consume(a);   // a is moved
    let r: &Item = &a;          // ERROR: cannot borrow 'a': value has been moved
    print_int(r.data);
    print_int(x);
    0
}
