// v0845 Lane 2 / Queue 2A — auxiliary lib for cross-module restricts
// fixtures. Skipped from standalone iteration via the `_aux.nr$`
// regex in `tools/verify.sh` (TEST_SKIP_REGEX). Imported by:
//   - tests/err/err_restricts_cross_module_transitive.nr
// Provides an un-rowed helper whose body performs an io.write effect
// via print().

fn lib_emit() -> i32 {
    print("aux emit");
    return 0;
}
