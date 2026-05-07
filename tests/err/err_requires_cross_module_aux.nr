// v0845 Lane 2 / Queue 2A — auxiliary lib for cross-module requires
// fixtures. Skipped from standalone iteration via the `_aux.nr$`
// regex in `tools/verify.sh` (TEST_SKIP_REGEX). Imported by:
//   - tests/err/err_requires_cross_module_direct.nr
//   - tests/err/err_requires_cross_module_transitive.nr
//   - tests/err/err_requires_cross_module_depth.nr
// Provides a rowed callee, an un-rowed helper that reaches print(),
// and a 4-hop un-rowed chain that previously fell silently through
// the depth=3 transitive bound (depth=8 since v0845 lane 2).

fn rowed_io_write() -> i32 requires [io.write] {
    print("from aux rowed");
    return 1;
}

fn unrowed_helper() -> i32 {
    print("from aux unrowed");
    return 1;
}

fn deep_hop4() -> i32 { print("aux deep"); return 0; }
fn deep_hop3() -> i32 { deep_hop4() }
fn deep_hop2() -> i32 { deep_hop3() }
fn deep_hop1() -> i32 { deep_hop2() }
