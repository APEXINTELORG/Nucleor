// EXPECT: OWN-001 use of moved variable
// Variable consumed by fn call, then used again.
// Phase 2a: Move semantics — move into function parameter

struct Data { value: i32 }

fn consume(d: Data) -> i32 { d.value }

fn main() -> i32 {
    let a: Data = Data { value: 42 };
    let r: i32 = consume(a);   // a moves into consume()
    print_int(r);               // ok: r is i32 (Copy)
    print_int(a.value);         // ERROR: use of moved value 'a'
    0
}
