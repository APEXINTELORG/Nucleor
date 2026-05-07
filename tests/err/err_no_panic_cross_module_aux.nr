// v0845 Lane 3 / Queue 3A — auxiliary lib for cross-module #[no_panic]
// fixture. Helper calls `panic(...)` directly so
// `no_panic_body_has_panic_pattern` registers it as a same-file
// panicking fn (the body-substring scan looks for `panic(`,
// `assert_eq(`, etc. — `/` and `%` operators are RT-009 warnings,
// not RT-002 errors). Skipped from standalone iteration via the
// `_aux.nr$` regex in `tools/verify.sh`.

fn aux_panic_helper(x: i32) -> i32 {
    if x < 0 {
        panic("aux negative");
    };
    return x;
}
