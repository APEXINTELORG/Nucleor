// rods/bt — verify rod wrapper compiles + links (v0.2.244 ship).
// Build a sequence of 2 nodes (no leaf callbacks — those need
// Nucleor function pointers, non-trivial in a single test file).
// Correctness coverage in the direct C unit test (sequence + selector
// + inverter combinations).
import "stdlib/rods/bt.nr"

fn main() -> i64 {
    let mut fail: i64 = 0;
    let bt: i64 = bt_new();
    if bt == 0 { print("FAIL bt_new"); return 1; };

    let root: i64 = bt_add_sequence(bt, 0 - 1);
    if root != 0 { fail = fail + 1; print("FAIL root index"); };
    let _seq2: i64 = bt_add_selector(bt, root);
    let _par: i64 = bt_add_parallel(bt, root, 1);
    let _inv: i64 = bt_add_inverter(bt, root);

    if bt_node_count(bt) != 4 {
        fail = fail + 1; print("FAIL node count after 4 nodes");
    };

    bt_free(bt);
    if fail == 0 { print("OK bt_smoke"); };
    return fail;
}
