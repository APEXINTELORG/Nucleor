// T3.7 (v0.3.6) smoke: confirms the v1 RT-001/002/003 checkers
// strip string literals + `// ...` line comments before scanning,
// so a forbidden name appearing inside a quoted/commented region
// no longer false-triggers.

#[no_alloc]
fn alloc_name_in_string(x: i64) -> i64 {
    let label: str = "uses Vec::new() and vec_push() at boot";
    return x + 1;
}

#[no_panic]
fn panic_name_in_comment(x: i64) -> i64 {
    // legacy code used .unwrap() here; rewrote to fallible ladder
    return x * 2;
}

#[no_dyn]
fn dyn_token_in_string(x: i64) -> i64 {
    let mode: str = "dyn dispatch is enabled in the legacy build";
    return x - 1;
}

#[test]
fn test_alloc_name_in_string_compiles() {
    assert_eq(alloc_name_in_string(10), 11);
}

#[test]
fn test_panic_name_in_comment_compiles() {
    assert_eq(panic_name_in_comment(7), 14);
}

#[test]
fn test_dyn_token_in_string_compiles() {
    assert_eq(dyn_token_in_string(5), 4);
}
