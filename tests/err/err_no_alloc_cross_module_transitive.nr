// EXPECT: error[RT-001]
// v0845 Lane 3 / Queue 3A — cross-module #[no_alloc] reaches an
// imported helper that allocates Vec::new(). The resolved-source
// pre-pass inlines aux module bodies before `enforce_no_alloc` runs,
// so `collect_allocating_same_file_fns` includes `aux_alloc_helper`
// and the transitive scan trips RT-001.

import "err_no_alloc_cross_module_aux.nr"

#[no_alloc]
fn caller() -> i32 {
    aux_alloc_helper()
}

fn main() -> i32 {
    caller()
}
