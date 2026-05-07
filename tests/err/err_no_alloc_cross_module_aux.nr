// v0845 Lane 3 / Queue 3A — auxiliary lib for cross-module #[no_alloc]
// fixtures. Skipped from standalone iteration via the `_aux.nr$` regex
// in `tools/verify.sh` (TEST_SKIP_REGEX). Imported by:
//   - tests/err/err_no_alloc_cross_module_transitive.nr

fn aux_alloc_helper() -> i32 {
    let _v: Vec<i32> = Vec::new();
    return 0;
}
