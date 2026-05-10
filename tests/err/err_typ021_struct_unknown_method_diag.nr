// EXPECT: error[TYP-007] receiver type `P` has no method

struct P {
    v: i64,
}

fn main() -> i32 {
    let p: P = P { v: 5 };
    let r: i64 = p.does_not_exist();
    print_int(0);
    0
}
