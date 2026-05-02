// EXPECT: EFF-003 call to Alloc-effect function from [no_alloc] function

fn may_alloc() -> i64 with [Alloc] {
    return 1;
}

fn rt_path() -> i64 with [no_alloc] {
    return may_alloc();
}

fn main() -> i64 {
    return rt_path();
}
