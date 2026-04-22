// Phase 2b: Comprehensive shared borrow test

struct Vec2 { x: i32, y: i32 }

fn magnitude_sq(v: &Vec2) -> i32 {
    v.x * v.x + v.y * v.y
}

fn add_refs(a: &i32, b: &i32) -> i32 {
    *a + *b
}

fn main() -> i32 {
    // 1. Borrow struct, read fields through ref
    let p: Vec2 = Vec2 { x: 3, y: 4 };
    let r: &Vec2 = &p;
    print_int(r.x);        // 3
    print_int(r.y);        // 4

    // 2. Pass &T to function
    let msq: i32 = magnitude_sq(&p);
    print_int(msq);        // 25

    // 3. Multiple shared borrows coexist
    let r1: &Vec2 = &p;
    let r2: &Vec2 = &p;
    print_int(r1.x);       // 3
    print_int(r2.y);       // 4

    // 4. Original still usable after borrow
    print_int(p.x);        // 3

    // 5. Primitive references with deref
    let a: i32 = 100;
    let b: i32 = 200;
    let sum: i32 = add_refs(&a, &b);
    print_int(sum);         // 300

    // 6. Copy types still work (no interference)
    let c: i32 = 7;
    let d: i32 = c;
    print_int(c);           // 7
    print_int(d);           // 7

    // 7. Shared ref is Copy — pass same ref twice
    let rv: &Vec2 = &p;
    let m1: i32 = magnitude_sq(rv);
    let m2: i32 = magnitude_sq(rv);
    print_int(m1);          // 25
    print_int(m2);          // 25

    0
}
