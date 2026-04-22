// Phase 2b: Multiple shared borrows can coexist

struct Data { value: i32 }

fn main() -> i32 {
    let a: Data = Data { value: 99 };
    let r1: &Data = &a;
    let r2: &Data = &a;     // second shared borrow — allowed
    print_int(r1.value);    // read through first ref
    print_int(r2.value);    // read through second ref
    print_int(a.value);     // original still usable
    0
}
