// EXPECT: error[EFF-001]
// v0845 Lane 2 / Queue 2A — cross-module direct requires-row mismatch.
// Caller declares `requires [net]`; calls `rowed_io_write()` from the
// imported aux module, which declares `requires [io.write]`. Disjoint
// rows. The resolved-source pre-pass inlines the aux module before
// `enforce_requires_direct_calls` runs, so EFF-001 fires on the
// caller's body line — same diagnostic as a same-file mismatch.

import "err_requires_cross_module_aux.nr"

fn caller() -> i32 requires [net] {
    rowed_io_write()
}

fn main() -> i32 requires [net] {
    caller()
}
