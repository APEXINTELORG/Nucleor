// v0845 Lane 2 / Queue 2A — auxiliary lib for the positive
// cross-module requires smoke. Skipped from standalone iteration via
// the `_aux.nr$` regex in `tools/verify.sh` (TEST_SKIP_REGEX).

fn aux_io_write() -> i32 requires [io.write] {
    print("aux ok");
    return 1;
}
