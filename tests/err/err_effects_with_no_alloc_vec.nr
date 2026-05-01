// EXPECT: RT-001 allocates but `busy` is declared with [no_alloc]

fn busy() -> i64 with [no_alloc] {
    let mut v: Vec<i32> = Vec::new();
    v.push(1);
    return 0;
}

fn main() -> i64 {
    return busy();
}
