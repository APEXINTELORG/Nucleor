// 3-way cycle helper C: imports back to A — closes the cycle.
import "err_import_cycle_3way_a.nr"

fn helper_c() -> i32 {
    return 2;
}
