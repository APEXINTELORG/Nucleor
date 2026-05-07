// v0845 Lane 3 / Queue 3A — positive cross-module smoke for both
// #[no_alloc] and #[no_panic]. Caller carries both attributes; the
// imported helper allocates nothing and does not panic. Build must
// succeed.

import "no_alloc_no_panic_cross_module_aux.nr"

#[no_alloc]
#[no_panic]
fn caller() -> i32 {
    aux_clean_helper()
}

fn main() -> i32 {
    let r: i32 = caller();
    if r == 42 { 0 } else { 1 }
}
