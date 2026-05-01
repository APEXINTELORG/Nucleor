// EXPECT: ATOMIC-002 allocating call inside #[atomic] function
#[atomic]
fn bad_atomic_alloc() -> i64 {
    let mut v: Vec<i32> = Vec::new();
    v.push(1);
    return 0;
}

fn main() -> i64 {
    return bad_atomic_alloc();
}
