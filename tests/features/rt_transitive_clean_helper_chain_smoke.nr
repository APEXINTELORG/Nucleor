// RT-G1/RT-G3 Phase 2b positive control: bounded same-file
// transitive scans must not reject clean helper chains.

fn add_one(x: i64) -> i64 {
    return x + 1;
}

fn add_two(x: i64) -> i64 {
    return add_one(x) + 1;
}

#[no_alloc]
#[no_panic]
fn controller_step(x: i64) -> i64 {
    return add_two(x);
}

fn main() -> i64 {
    let y: i64 = controller_step(40);
    if y != 42 { return 1; };
    return 0;
}
