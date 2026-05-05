// EXPECT: error[MOD-005]
// 3-way cycle helper B: imports C.
import "err_import_cycle_3way_c.nr"

fn helper_b() -> i32 {
    return 1;
}
