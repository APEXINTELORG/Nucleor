// EXPECT: rc=0
// RT-G1/RT-G3 v0842 positive control: deeper clean helper chains
// must not trip the bounded same-file closure scanner.

fn add_one(x: i64) -> i64 {
    return x + 1;
}

fn add_two(x: i64) -> i64 {
    return add_one(x) + 1;
}

fn add_three(x: i64) -> i64 {
    return add_two(x) + 1;
}

#[no_alloc]
#[no_panic]
fn controller_step(x: i64) -> i64 {
    return add_three(x);
}

fn main() -> i64 {
    let y: i64 = controller_step(39);
    if y != 42 { return 1; };
    return 0;
}
