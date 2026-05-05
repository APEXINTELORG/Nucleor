// Helper for err_import_cycle_mod005.nr — imports back to A.
import "err_import_cycle_mod005.nr"

fn unused_b() -> i32 {
    return 1;
}
