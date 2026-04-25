// EXPECT: RT-002 — #[no_panic] fn calls a panic-prone helper.
// T3.2 (v0.3.1) — source-level v1 check fires on the literal
// `<name>(` pattern; here `assert_eq(...)` appears inside the
// body of `bad_op` which is annotated `#[no_panic]`. Same
// scanner shape as the existing #[no_alloc] enforcement.
#[no_panic]
fn bad_op(x: i64) -> i64 {
    assert_eq(x, 42);
    return x;
}

fn main() -> i64 {
    return bad_op(0);
}
