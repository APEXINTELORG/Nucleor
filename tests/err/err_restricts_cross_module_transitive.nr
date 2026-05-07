// EXPECT: error[EFF-003]
// v0845 Lane 2 / Queue 2A — cross-module restricts-block transitive
// enforcement. `restricts [io.write] { lib_emit(); }` where lib_emit is
// imported from the aux module and its body calls `print()` (io.write).
// The resolved-source pre-pass inlines the aux module before
// `enforce_restricts_block_effects` runs, so the deny row trips on the
// transitive io.write reach and emits EFF-003 with the "via call chain
// ending in `print()`" trailer.

import "err_restricts_cross_module_aux.nr"

fn main() -> i32 {
    restricts [io.write] {
        let _r: i32 = lib_emit();
    };
    return 0;
}
