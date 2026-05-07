// v0845 Lane 2 / Queue 2A — positive cross-module requires-row smoke.
// Caller declares `requires [io.write]`, matching the imported aux
// callee's declared row. main lifts the same row up to itself. Build
// must succeed and the program must print "aux ok" then exit 0.

import "requires_cross_module_aux.nr"

fn caller() -> i32 requires [io.write] {
    aux_io_write()
}

fn main() -> i32 requires [io.write] {
    if caller() == 1 { 0 } else { 1 }
}
