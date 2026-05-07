// EXPECT: error[EFF-001]
// v0845 Lane 2 / Queue 2A — cross-module transitive requires-row
// mismatch. Caller declares `requires [net]`; calls `unrowed_helper()`
// from the aux module. unrowed_helper has no row but its body calls
// `print()` (io.write). The resolved-source pre-pass + bounded
// transitive scan in `requires_transitive_missing` now reports
// EFF-001 with "call chain ... reaches effect ... transitive" via
// the depth=8 budget.

import "err_requires_cross_module_aux.nr"

fn caller() -> i32 requires [net] {
    unrowed_helper()
}

fn main() -> i32 requires [net] {
    caller()
}
