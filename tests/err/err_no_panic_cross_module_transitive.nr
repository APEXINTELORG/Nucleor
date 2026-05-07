// EXPECT: error[RT-002]
// v0845 Lane 3 / Queue 3A — cross-module #[no_panic] reaches an
// imported helper whose body calls `panic(...)` directly (the
// body-substring scan in `no_panic_body_has_panic_pattern` looks for
// `panic(`, `assert_eq(`, etc.; integer `/` and `%` are RT-009
// warnings, not RT-002 errors). The resolved-source pre-pass inlines
// the aux module body before `enforce_no_panic` runs, so the
// transitive scan trips RT-002 on the cross-module reach.

import "err_no_panic_cross_module_aux.nr"

#[no_panic]
fn caller(x: i32) -> i32 {
    aux_panic_helper(x)
}

fn main() -> i32 {
    caller(5)
}
